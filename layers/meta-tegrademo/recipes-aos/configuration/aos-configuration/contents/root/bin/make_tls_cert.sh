#!/bin/bash
# Makes the certificate AOS's servers use for https and wss://, from a CA
# that can only vouch for this team's Orins.
#
# Normally that's the team CA, which install_team_ca.sh puts here after
# flashing (with a "team" file next to it).  Its name constraints permit
# orin-<team>-0 to 9.local and the team's 10.TE.AM.0/24, so a laptop trusts
# the whole team once, and renaming or reflashing an Orin doesn't change it.
# Without one, this makes a CA for this Orin alone: <hostname>.local and
# eth0's fixed address.  Either way a laptop that trusts the CA trusts
# nothing else, and trust_orin.py checks that before installing it.
#
# Usage: make_tls_cert.sh [--new-ca]
# aos-tls.service runs it at every boot, and change_hostname.sh after
# changing the hostname and address.  It makes an Orin CA if there is no CA,
# or there is an Orin CA for another name or address, and a server
# certificate if there is none, it isn't valid for them under the current CA,
# or it expires within 60 days.  --new-ca replaces the CA, team or not, with
# a new Orin CA; every laptop then has to trust it.

set -xeuo pipefail

# ROOT lets the tests run this outside /.
ROOT="${ROOT:-}"
DIR="${ROOT}/etc/aos/tls"

NAME="$(cat "${ROOT}/etc/hostname").local"
IP="$(sed -n 's|^Address=\([0-9.]*\)/.*|\1|p' "${ROOT}/etc/systemd/network/eth0.network")"

mkdir -p -m 0755 "${DIR}"
umask 077
NEW="$(mktemp -d "${DIR}/.new.XXXXXX")"
trap 'rm -rf "${NEW}"' EXIT

new_ca=0
if [[ "${1:-}" == "--new-ca" || ! -s "${DIR}/ca.crt" || ! -s "${DIR}/ca.key" ]] ||
   [[ ! -e "${DIR}/team" && "$(cat "${DIR}/name" 2>/dev/null)" != "${NAME} ${IP}" ]]; then
  new_ca=1
  cat > "${NEW}/ca.cnf" <<EOF
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext

[dn]
CN = ${NAME} robot CA

[ext]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
# Name constraints don't cover email or code signing; this does.
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
nameConstraints = critical, permitted;DNS:${NAME}, permitted;IP:${IP}/255.255.255.255, excluded;IP:::/::
EOF
  openssl req -x509 -new -config "${NEW}/ca.cnf" -days 7300 \
    -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
    -keyout "${NEW}/ca.key" -out "${NEW}/ca.crt"
  echo "${NAME} ${IP}" > "${NEW}/name"
fi

if [[ "${new_ca}" == 1 || ! -s "${DIR}/server.key" ]] ||
   ! openssl verify -CAfile "${DIR}/ca.crt" -verify_hostname "${NAME}" \
       -verify_ip "${IP}" "${DIR}/server.crt" ||
   ! openssl x509 -in "${DIR}/server.crt" -noout -checkend $((60 * 86400)); then
  CA_DIR="${DIR}"
  [[ "${new_ca}" == 1 ]] && CA_DIR="${NEW}"
  cat > "${NEW}/server.ext" <<EOF
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = DNS:${NAME}, IP:${IP}
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
EOF
  openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
    -subj "/CN=${NAME}" -keyout "${NEW}/server.key" -out "${NEW}/server.csr"
  # macOS refuses TLS certificates valid for more than 825 days.
  openssl x509 -req -in "${NEW}/server.csr" -days 397 \
    -CA "${CA_DIR}/ca.crt" -CAkey "${CA_DIR}/ca.key" \
    -extfile "${NEW}/server.ext" -out "${NEW}/server.crt"
  # A team CA can only vouch for its own team's names and addresses.
  if ! openssl verify -CAfile "${CA_DIR}/ca.crt" -verify_hostname "${NAME}" \
      -verify_ip "${IP}" "${NEW}/server.crt"; then
    echo "${DIR}/ca.crt can't vouch for ${NAME} and ${IP}." >&2
    exit 1
  fi
  # The server sends the CA along, so trust_orin.py can fetch it from there.
  cat "${NEW}/server.crt" "${CA_DIR}/ca.crt" > "${NEW}/server-chain.crt"
  # AOS runs the Foxglove server as pi.
  if getent group pi > /dev/null; then
    chgrp pi "${NEW}/server.key"
  fi
  chmod 0640 "${NEW}/server.key"
  chmod 0644 "${NEW}/server.crt" "${NEW}/server-chain.crt"
fi

if [[ "${new_ca}" == 1 ]]; then
  chmod 0644 "${NEW}/ca.crt" "${NEW}/name"
  rm -f "${DIR}/team"
  mv -f "${NEW}/ca.key" "${NEW}/ca.crt" "${NEW}/name" "${DIR}/"
fi
for f in server.key server.crt server-chain.crt; do
  if [[ -e "${NEW}/${f}" ]]; then
    mv -f "${NEW}/${f}" "${DIR}/"
  fi
done

openssl x509 -in "${DIR}/ca.crt" -noout -subject -fingerprint -sha256
