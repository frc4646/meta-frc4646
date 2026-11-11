#!/bin/bash
# Makes a robot CA for one or more team numbers (real or made up to tell
# robots apart): one that can only vouch for those teams' Orins,
# orin-<team>-0 to 9.local and 10.TE.AM.0/24, and only as TLS servers.  Run
# it once, keep ca.key private (not in a public repository), and put the CA
# on each Orin after flashing with install_team_ca.sh.  Laptops trust it with
# trust_orin.py.
#
# Usage: make_team_ca.sh LABEL OUTDIR TEAM...
#   e.g. make_team_ca.sh frc1868 ~/robot-ca 1868 9968 9969
# The CA is named "<LABEL> team robot CA".

set -xeuo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 LABEL OUTDIR TEAM..." >&2
  exit 2
fi
LABEL="$1"
OUT="$2"
shift 2

if [[ ! "${LABEL}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "Invalid label ${LABEL}: letters, digits, - and _ only" >&2
  exit 1
fi
mkdir -p "${OUT}"
if [[ -e "${OUT}/ca.key" ]]; then
  echo "${OUT}/ca.key already exists." >&2
  exit 1
fi

NC="critical"
IPS=""
for TEAM in "$@"; do
  # The same address scheme change_hostname.sh uses: team TTTT is 10.TT.TT.
  if [[ ! "${TEAM}" =~ ^([1-9][0-9]{0,2})([0-9][0-9])$ ||
        "${BASH_REMATCH[1]}" -gt 255 ]]; then
    echo "Invalid team number ${TEAM}" >&2
    exit 1
  fi
  for i in 0 1 2 3 4 5 6 7 8 9; do
    NC+=", permitted;DNS:orin-${TEAM}-${i}.local"
  done
  IPS+=", permitted;IP:10.${BASH_REMATCH[1]}.$((10#${BASH_REMATCH[2]})).0/255.255.255.0"
done
NC+="${IPS}, excluded;IP:::/::"

umask 077
openssl req -x509 -new -days 7300 \
  -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
  -keyout "${OUT}/ca.key" -out "${OUT}/ca.crt" \
  -config /dev/stdin <<EOF
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext

[dn]
CN = ${LABEL} team robot CA

[ext]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
# Name constraints don't cover email or code signing; this does.
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
nameConstraints = ${NC}
EOF
chmod 0644 "${OUT}/ca.crt"

openssl x509 -in "${OUT}/ca.crt" -noout -subject -fingerprint -sha256
