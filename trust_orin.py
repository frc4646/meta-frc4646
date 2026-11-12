#!/usr/bin/env python3
"""Trusts an Orin's robot CA on this computer.

So browsers and Foxglove can connect to the Orin over https and wss://.
Runs on macOS, Linux and Windows with Python 3.8 or newer and nothing else
from outside the standard library.

The CA is one of two kinds:

* A team CA (make_team_ca.sh, put on each Orin with install_team_ca.sh).  It
  covers one or more team numbers: orin-<team>-0 to 9.local and the team's
  10.TE.AM.0/24 for each.
* An Orin's own CA, which an Orin without a team CA makes for itself
  (aos_make_tls_cert in the image).  It covers <hostname>.local and the
  Orin's address.

This installs the CA only if its name constraints permit exactly one of
those shapes, and it is limited to TLS servers.  So even a CA swapped in on
the way here can't be used to impersonate any other site.

    trust_orin.py orin-1868-1             fetch the CA from the Orin and trust it
    trust_orin.py orin-1868-1 ca.crt      trust the CA in ca.crt
    trust_orin.py --remove orin-1868-1    stop trusting it

The address follows change_hostname.sh: orin-TTTT-N is 10.TT.TT.(100 + N).
"""

import argparse
import base64
import glob
import hashlib
import ipaddress
import os
import re
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile

PORT = int(os.environ.get("FOXGLOVE_PORT", "8765"))

OID_CN = "2.5.4.3"
OID_BASIC_CONSTRAINTS = "2.5.29.19"
OID_EXTENDED_KEY_USAGE = "2.5.29.37"
OID_NAME_CONSTRAINTS = "2.5.29.30"
OID_SERVER_AUTH = "1.3.6.1.5.5.7.3.1"

TEAM_CN = re.compile(r"[A-Za-z0-9_-]+ team robot CA")
ORIN_NAME = re.compile(r"orin-([0-9]+)-([0-9])\.local")
ALL_IPV6 = ipaddress.ip_network("::/0")


class Refused(Exception):
    """The CA could vouch for more than it should."""


def team_subnet(team):
    """10.TE.AM.0/24 for team TEAM, as change_hostname.sh numbers it."""
    m = re.fullmatch(r"([1-9][0-9]{0,2})([0-9]{2})", team)
    if not m or int(m.group(1)) > 255:
        raise Refused(f"{team} isn't a team number")
    return ipaddress.ip_network(f"10.{int(m.group(1))}.{int(m.group(2))}.0/24")


# A minimal DER reader: just enough of X.509 to read the subject's common
# name and three extensions.


def der(data, pos=0):
    """Returns (tag, contents, end) of the element at pos."""
    tag = data[pos]
    length = data[pos + 1]
    pos += 2
    if length & 0x80:
        n = length & 0x7F
        if n == 0 or n > 4:
            raise Refused("malformed certificate")
        length = int.from_bytes(data[pos:pos + n], "big")
        pos += n
    if pos + length > len(data):
        raise Refused("malformed certificate")
    return tag, data[pos:pos + length], pos + length


def children(contents):
    """The (tag, contents) elements inside a constructed element."""
    pos = 0
    while pos < len(contents):
        tag, value, pos = der(contents, pos)
        yield tag, value


def oid(value):
    first, rest = divmod(value[0], 40)
    parts = [min(first, 2), rest if first < 2 else value[0] - 80]
    n = 0
    for b in value[1:]:
        n = (n << 7) | (b & 0x7F)
        if not b & 0x80:
            parts.append(n)
            n = 0
    return ".".join(str(p) for p in parts)


class Certificate:

    def __init__(self, der_bytes):
        self.der = der_bytes
        tag, cert, _ = der(der_bytes)
        tbs = list(children(cert))[0][1]
        fields = list(children(tbs))
        if fields[0][0] == 0xA0:  # [0] version
            fields = fields[1:]
        # serial, signature, issuer, validity, subject, subjectPublicKeyInfo
        self.common_names = []
        for _, rdn in children(fields[4][1]):
            for _, attribute in children(rdn):
                (_, attr_oid), (_, attr_value) = children(attribute)
                if oid(attr_oid) == OID_CN:
                    self.common_names.append(attr_value.decode())
        # oid -> (critical, value)
        self.extensions = {}
        for tag, value in fields[6:]:
            if tag != 0xA3:  # [3] extensions
                continue
            for _, extension in children(list(children(value))[0][1]):
                parts = list(children(extension))
                critical = len(parts) == 3 and parts[1][1] != b"\x00"
                key = oid(parts[0][1])
                if key in self.extensions:
                    raise Refused(f"it has two {key} extensions")
                self.extensions[key] = (critical, parts[-1][1])

    def fingerprint(self):
        digest = hashlib.sha256(self.der).hexdigest().upper()
        return ":".join(digest[i:i + 2] for i in range(0, len(digest), 2))


def subtrees(value):
    """The names in a GeneralSubtrees: ("DNS", name) or ("IP", network)."""
    names = []
    for _, subtree in children(value):
        parts = list(children(subtree))
        if len(parts) != 1:
            raise Refused("its name constraints have minimums or maximums")
        tag, name = parts[0]
        if tag == 0x82:  # dNSName
            names.append(("DNS", name.decode("ascii").lower()))
        elif tag == 0x87 and len(name) in (8, 32):  # iPAddress
            half = len(name) // 2
            mask = int.from_bytes(name[half:], "big")
            prefix = bin(mask).count("1")
            if mask != ((1 << prefix) - 1) << (half * 8 - prefix):
                raise Refused("its name constraints have a non-contiguous mask")
            address = ipaddress.ip_address(name[:half])
            names.append(
                ("IP", ipaddress.ip_network(f"{address}/{prefix}", strict=True)))
        else:
            raise Refused("its name constraints name something other than "
                          "hosts and addresses")
    if len(set(names)) != len(names):
        raise Refused("its name constraints list a name twice")
    return set(names)


def check(cert, host):
    """Returns (common name, what it vouches for), or raises Refused."""
    m = re.fullmatch(r"orin-(([1-9][0-9]{0,2})([0-9]{2}))-([0-9])", host)
    if not m:
        raise Refused(f"{host} isn't an Orin name (orin-<team>-<n>)")
    team = m.group(1)
    name = f"{host}.local"
    address = team_subnet(team)[100 + int(m.group(4))]

    if len(cert.common_names) != 1:
        raise Refused("it doesn't have exactly one name")
    cn = cert.common_names[0]

    critical, value = cert.extensions.get(OID_BASIC_CONSTRAINTS, (False, b""))
    parts = list(children(der(value)[1])) if value else []
    if not (critical and len(parts) == 2 and parts[0] == (0x01, b"\xff") and
            parts[1] == (0x02, b"\x00")):
        raise Refused("it isn't a CA limited to signing server certificates "
                      "directly (critical CA:TRUE, pathlen:0)")

    _, value = cert.extensions.get(OID_EXTENDED_KEY_USAGE, (False, b""))
    usages = [oid(v) for _, v in children(der(value)[1])] if value else []
    if usages != [OID_SERVER_AUTH]:
        raise Refused("it isn't limited to TLS servers")

    critical, value = cert.extensions.get(OID_NAME_CONSTRAINTS, (False, b""))
    if not critical:
        raise Refused("it has no critical name constraints")
    permitted = excluded = None
    for tag, trees in children(der(value)[1]):
        if tag == 0xA0:
            permitted = subtrees(trees)
        elif tag == 0xA1:
            excluded = subtrees(trees)
    if excluded != {("IP", ALL_IPV6)}:
        raise Refused("its name constraints don't exclude all of IPv6")

    if TEAM_CN.fullmatch(cn):
        teams = {}
        for kind, value in permitted or ():
            if kind != "DNS":
                continue
            m = ORIN_NAME.fullmatch(value)
            if not m:
                raise Refused(f"it can vouch for {value}, not an Orin")
            teams.setdefault(m.group(1), set()).add(m.group(2))
        want = set()
        for t in teams:
            want |= {("DNS", f"orin-{t}-{i}.local") for i in "0123456789"}
            want.add(("IP", team_subnet(t)))
        if permitted != want:
            raise Refused("its name constraints aren't exactly orin-<team>-0 "
                          "to 9.local and 10.TE.AM.0/24 for each team")
        if team not in teams:
            raise Refused(f"it can't vouch for {host}")
        listed = ", ".join(sorted(teams, key=int))
        return cn, f"the Orins of team numbers {listed}"

    if cn == f"{name} robot CA":
        if permitted != {("DNS", name), ("IP", ipaddress.ip_network(address))}:
            raise Refused(f"its name constraints allow more than {name} and "
                          f"{address}")
        return cn, f"{name} and {address}"

    raise Refused(f'its name is "{cn}", not "{name} robot CA" or '
                  '"<label> team robot CA"')


def fetch(host, address):
    """The last certificate the Orin's TLS server sends: its CA."""
    if sys.version_info >= (3, 13):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        with socket.create_connection((str(address), PORT), timeout=10) as s:
            with context.wrap_socket(s, server_hostname=f"{host}.local") as t:
                chain = t.get_unverified_chain()
        last = chain[-1]
        return last if isinstance(last, bytes) else last.public_bytes(
            ssl.ENCODING_DER)
    # Older Pythons can't see the rest of the chain.
    out = subprocess.run(
        ["openssl", "s_client", "-connect", f"{address}:{PORT}",
         "-servername", f"{host}.local", "-showcerts"],
        stdin=subprocess.DEVNULL, capture_output=True, text=True,
        timeout=20).stdout
    pems = re.findall(r"-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----",
                      out, re.S)
    if not pems:
        raise Refused(f"couldn't get a certificate from {address}:{PORT}")
    return base64.b64decode(pems[-1])


def read(path):
    with open(path, "rb") as f:
        data = f.read()
    m = re.search(rb"-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----",
                  data, re.S)
    return base64.b64decode(m.group(1)) if m else data


# Where each OS keeps the CAs browsers and Foxglove trust.

KEYCHAIN = os.path.expanduser("~/Library/Keychains/login.keychain-db")


def nss_databases():
    home = os.path.expanduser("~")
    for d in ([os.path.join(home, ".pki/nssdb")] +
              glob.glob(os.path.join(home, ".mozilla/firefox/*")) +
              glob.glob(os.path.join(home, "snap/firefox/common/.mozilla/firefox/*"))):
        if os.path.exists(os.path.join(d, "cert9.db")):
            yield d


def windows():
    return sys.platform in ("win32", "cygwin", "msys")


def run(*args, check=True):
    print("+", " ".join(args))
    return subprocess.run(args, check=check)


def uninstall(cn):
    if sys.platform == "darwin":
        while subprocess.run(["security", "find-certificate", "-c", cn, KEYCHAIN],
                             capture_output=True).returncode == 0:
            run("security", "delete-certificate", "-t", "-c", cn, KEYCHAIN)
    elif windows():
        run("certutil.exe", "-user", "-delstore", "Root", cn, check=False)
    elif shutil.which("certutil"):
        for db in nss_databases():
            while subprocess.run(["certutil", "-d", f"sql:{db}", "-L", "-n", cn],
                                 capture_output=True).returncode == 0:
                run("certutil", "-d", f"sql:{db}", "-D", "-n", cn)


def install(cn, der_bytes):
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "ca.crt")
        with open(path, "w") as f:
            f.write("-----BEGIN CERTIFICATE-----\n")
            f.write(base64.encodebytes(der_bytes).decode())
            f.write("-----END CERTIFICATE-----\n")
        if sys.platform == "darwin":
            # Asks for your password, to change your keychain's trust settings.
            run("security", "add-trusted-cert", "-r", "trustRoot", "-p", "ssl",
                "-k", KEYCHAIN, path)
            print("Firefox also needs security.enterprise_roots.enabled in "
                  "about:config.")
        elif windows():
            # The CA's own extended key usage limits it to TLS servers here.
            # Windows asks to confirm.
            run("certutil.exe", "-user", "-addstore", "Root", path)
            print("Firefox also needs security.enterprise_roots.enabled in "
                  "about:config.")
        elif sys.platform.startswith("linux"):
            if not shutil.which("certutil"):
                sys.exit("Needs certutil: sudo apt install libnss3-tools")
            nssdb = os.path.expanduser("~/.pki/nssdb")
            if not os.path.exists(os.path.join(nssdb, "cert9.db")):
                os.makedirs(nssdb, exist_ok=True)
                run("certutil", "-d", f"sql:{nssdb}", "-N", "--empty-password")
            # Chrome, Foxglove and each Firefox profile.  "C,," trusts it to
            # issue TLS server certificates and nothing else.
            for db in nss_databases():
                run("certutil", "-d", f"sql:{db}", "-A", "-n", cn, "-t", "C,,",
                    "-i", path)
        else:
            sys.exit(f"Don't know how to trust a CA on {sys.platform}.")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("host", help="the Orin, e.g. orin-1868-1")
    parser.add_argument("ca_file", nargs="?",
                        help="the CA certificate; fetched from the Orin if not given")
    parser.add_argument("--remove", action="store_true",
                        help="stop trusting the Orin's CA")
    parser.add_argument("--check", action="store_true",
                        help="only check the CA; don't install it")
    parser.add_argument("--yes", action="store_true",
                        help="don't ask before trusting a team CA")
    args = parser.parse_args()
    host = re.sub(r"\.local$", "", args.host.lower())

    try:
        m = re.fullmatch(r"orin-([0-9]+)-([0-9])", host)
        if not m:
            raise Refused(f"{host} isn't an Orin name (orin-<team>-<n>)")
        address = team_subnet(m.group(1))[100 + int(m.group(2))]
        if args.remove:
            uninstall(f"{host}.local robot CA")
        try:
            cert = Certificate(read(args.ca_file) if args.ca_file else
                               fetch(host, address))
        except (OSError, subprocess.SubprocessError) as e:
            if args.remove:
                print(f"Couldn't get the CA ({e}), so a team CA isn't removed.")
                return
            raise Refused(f"couldn't get the CA: {e}")
        cn, scope = check(cert, host)
    except Refused as e:
        sys.exit(f"Not trusting it: {e}.")

    if args.remove:
        uninstall(cn)
        print(f"Removed {cn}.")
        return
    print(f"{cn} can only vouch for {scope}.")
    print(f"SHA-256 fingerprint {cert.fingerprint()}")
    if args.check:
        return
    if TEAM_CN.fullmatch(cn) and not args.yes:
        if input("Trust it? [y/N] ").strip().lower() not in ("y", "yes"):
            return
    uninstall(cn)
    install(cn, cert.der)
    print(f"Trusted {cn}.  Foxglove: wss://{host}.local:{PORT}")


if __name__ == "__main__":
    main()
