#!/bin/bash
# Puts a team's robot CA (from make_team_ca.sh) on an Orin, after flashing,
# and makes its server certificate from it.  The Orin keeps it across
# reboots and renames within the team; flashing erases it.
#
# Usage: install_team_ca.sh SSH_DESTINATION CA_DIR
#   e.g. install_team_ca.sh pi@orin-1868-1.local ~/team-ca

set -xeuo pipefail

DEST="$1"
CA_DIR="$2"

openssl x509 -in "${CA_DIR}/ca.crt" -noout -subject -fingerprint -sha256

tar -C "${CA_DIR}" -c ca.crt ca.key | ssh "${DEST}" '
  set -xeuo pipefail
  T=/etc/aos/tls
  sudo mkdir -p -m 0755 "${T}"
  NEW="$(sudo mktemp -d "${T}/.new.XXXXXX")"
  sudo tar -x -C "${NEW}" --no-same-owner
  sudo chown root:root "${NEW}/ca.crt" "${NEW}/ca.key"
  sudo chmod 0644 "${NEW}/ca.crt"
  sudo chmod 0600 "${NEW}/ca.key"
  sudo mv -f "${NEW}/ca.key" "${NEW}/ca.crt" "${T}/"
  sudo touch "${T}/team"
  sudo rm -f "${T}/name"
  sudo rmdir "${NEW}"
  sudo /root/bin/make_tls_cert.sh
'
