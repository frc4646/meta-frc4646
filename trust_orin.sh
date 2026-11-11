#!/bin/bash
# Trusts one Orin's robot CA on this computer, so Foxglove can connect to it
# over wss://.  Runs on macOS, Linux and Windows (Git Bash), and needs
# openssl.
#
# The Orin makes its own CA (make_tls_cert.sh in the image).  This installs
# it only if it can vouch for nothing but that Orin: its name constraints must
# permit just <hostname>.local and the Orin's fixed address, and it must be
# limited to TLS servers.  So even a CA swapped in on the way here can't be
# used to impersonate any other site.
#
# Usage: trust_orin.sh HOSTNAME [CA_FILE]   e.g. trust_orin.sh orin-1868-1
#        trust_orin.sh --remove HOSTNAME
# Without CA_FILE, the CA is fetched from the Orin's Foxglove server, which
# sends it after its own certificate.
#
# The address follows change_hostname.sh: orin-TTTT-N is 10.TT.TT.(100 + N).

set -euo pipefail

usage() {
  echo "usage: $0 HOSTNAME [CA_FILE] | --remove HOSTNAME" >&2
  exit 2
}

remove=0
if [[ "${1:-}" == "--remove" ]]; then
  remove=1
  shift
fi
[[ $# -ge 1 && $# -le 2 ]] || usage

HOST="${1%.local}"
if [[ ! "${HOST}" =~ ^orin-([0-9]+)([0-9][0-9])-([0-9])$ ]]; then
  echo "${HOST} isn't an Orin name (orin-<team>-<n>)" >&2
  exit 1
fi
NAME="${HOST}.local"
IP="10.${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((100 + BASH_REMATCH[3]))"
CN="${NAME} robot CA"
PORT="${FOXGLOVE_PORT:-8765}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# The places each OS keeps trusted CAs for browsers and Foxglove.
nss_dbs() {
  local d
  for d in "${HOME}/.pki/nssdb" \
           "${HOME}"/.mozilla/firefox/*/ \
           "${HOME}"/snap/firefox/common/.mozilla/firefox/*/; do
    if [[ -e "${d%/}/cert9.db" ]]; then
      echo "${d%/}"
    fi
  done
}

uninstall() {
  case "$(uname -s)" in
    Darwin)
      while security find-certificate -c "${CN}" \
          "${HOME}/Library/Keychains/login.keychain-db" > /dev/null 2>&1; do
        security delete-certificate -t -c "${CN}" \
          "${HOME}/Library/Keychains/login.keychain-db"
      done
      ;;
    Linux)
      local db
      while read -r db; do
        while certutil -d "sql:${db}" -L -n "${CN}" > /dev/null 2>&1; do
          certutil -d "sql:${db}" -D -n "${CN}"
        done
      done < <(nss_dbs)
      ;;
    MINGW* | MSYS* | CYGWIN*)
      certutil.exe -user -delstore Root "${CN}" > /dev/null || true
      ;;
  esac
}

if [[ "${remove}" == 1 ]]; then
  uninstall
  echo "Removed ${CN}."
  exit 0
fi

CA="${TMP}/ca.crt"
if [[ $# == 2 ]]; then
  openssl x509 -in "$2" -out "${CA}"
else
  echo "Fetching the CA from ${IP}:${PORT}"
  openssl s_client -connect "${IP}:${PORT}" -servername "${NAME}" -showcerts \
    < /dev/null 2> /dev/null |
    awk '/-BEGIN CERTIFICATE-/ {c = ""} {c = c $0 "\n"}
         /-END CERTIFICATE-/ {last = c} END {printf "%s", last}' > "${TMP}/last.pem"
  if ! openssl x509 -in "${TMP}/last.pem" -out "${CA}" 2> /dev/null; then
    echo "Couldn't get a certificate from ${IP}:${PORT}." >&2
    exit 1
  fi
fi

# Everything below must hold, or the CA could vouch for something other
# than this Orin.
TEXT="$(openssl x509 -in "${CA}" -noout -text)"
fail() {
  echo "Not installing: $1" >&2
  echo "${TEXT}" | sed -n '/X509v3 extensions/,/Signature Algorithm/p' >&2
  exit 1
}
# The lines under an extension's heading, without indentation.
ext() {
  echo "${TEXT}" | awk -v h="$1" '
    index($0, h) { on = 1; next }
    on && (/^ *X509v3 / || /^ *Signature Algorithm/ || /^ *[A-Z][A-Za-z ]*:$/ && !/^ *(Permitted|Excluded):$/) { on = 0 }
    on { sub(/^ +/, ""); sub(/ +$/, ""); if ($0 != "") print }'
}

[[ "$(openssl x509 -in "${CA}" -noout -subject)" == *"CN = ${CN}"* ||
   "$(openssl x509 -in "${CA}" -noout -subject)" == *"CN=${CN}"* ]] ||
  fail "its name isn't \"${CN}\""
echo "${TEXT}" | grep -q 'X509v3 Basic Constraints: critical' ||
  fail "basic constraints aren't critical"
[[ "$(ext 'X509v3 Basic Constraints')" == "CA:TRUE, pathlen:0" ]] ||
  fail "it isn't a CA limited to signing server certificates directly"
[[ "$(ext 'X509v3 Extended Key Usage')" == "TLS Web Server Authentication" ]] ||
  fail "it isn't limited to TLS servers"
echo "${TEXT}" | grep -q 'X509v3 Name Constraints: critical' ||
  fail "it has no critical name constraints"
WANT="Permitted:
DNS:${NAME}
IP:${IP}/255.255.255.255
Excluded:"
NC="$(ext 'X509v3 Name Constraints')"
case "${NC}" in
  "${WANT}"$'\n'"IP:0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0" | \
  "${WANT}"$'\n'"IP:::/::") ;;
  *) fail "its name constraints allow more than ${NAME} and ${IP}" ;;
esac

echo "${CN} can only vouch for ${NAME} and ${IP}."
openssl x509 -in "${CA}" -noout -fingerprint -sha256

uninstall
case "$(uname -s)" in
  Darwin)
    # Asks for your password, to change your login keychain's trust settings.
    security add-trusted-cert -r trustRoot -p ssl \
      -k "${HOME}/Library/Keychains/login.keychain-db" "${CA}"
    echo "Firefox also needs security.enterprise_roots.enabled in about:config."
    ;;
  Linux)
    if ! command -v certutil > /dev/null; then
      echo "Needs certutil: sudo apt install libnss3-tools" >&2
      exit 1
    fi
    if [[ ! -e "${HOME}/.pki/nssdb/cert9.db" ]]; then
      mkdir -p "${HOME}/.pki/nssdb"
      certutil -d "sql:${HOME}/.pki/nssdb" -N --empty-password
    fi
    # Chrome, Foxglove and each Firefox profile; "C,," trusts it for TLS only.
    while read -r db; do
      certutil -d "sql:${db}" -A -n "${CN}" -t "C,," -i "${CA}"
      echo "Added to ${db}"
    done < <(nss_dbs)
    ;;
  MINGW* | MSYS* | CYGWIN*)
    # Windows asks to confirm.
    certutil.exe -user -addstore Root "$(cygpath -w "${CA}")"
    echo "Firefox also needs security.enterprise_roots.enabled in about:config."
    ;;
  *)
    echo "Don't know how to trust a CA on $(uname -s)." >&2
    exit 1
    ;;
esac
echo "Trusted ${CN}.  Connect Foxglove to wss://${NAME}:${PORT}"
