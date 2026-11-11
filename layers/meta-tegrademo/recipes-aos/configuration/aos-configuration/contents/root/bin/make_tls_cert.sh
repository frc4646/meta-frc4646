#!/bin/bash
# Makes the certificates AOS's Foxglove server uses for wss://, from a CA
# that can only vouch for this Orin.
#
# The CA's name constraints permit just <hostname>.local and eth0's fixed
# address, so a laptop that trusts it trusts nothing else; trust_orin.sh
# checks that before installing it.  The CA's key is then worth no more than
# the server's: either only impersonates this Orin.
#
# Usage: make_tls_cert.sh [--new-ca]
# aos-tls.service runs it at every boot.  It makes a CA if there is none or
# the hostname or address changed (change_hostname.sh changes both), and a
# server certificate if there is none, it isn't valid for them under the
# current CA, or it expires within 60 days.  --new-ca replaces the CA
# regardless; every laptop then has to trust the new one.

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
if [[ "${1:-}" == "--new-ca" || ! -s "${DIR}/ca.crt" || ! -s "${DIR}/ca.key" ||
      "$(cat "${DIR}/name" 2>/dev/null)" != "${NAME} ${IP}" ]]; then
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
  # The server sends the CA along, so trust_orin.sh can fetch it from there.
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
  mv -f "${NEW}/ca.key" "${NEW}/ca.crt" "${NEW}/name" "${DIR}/"
fi
for f in server.key server.crt server-chain.crt; do
  if [[ -e "${NEW}/${f}" ]]; then
    mv -f "${NEW}/${f}" "${DIR}/"
  fi
done

openssl x509 -in "${DIR}/ca.crt" -noout -subject -fingerprint -sha256
