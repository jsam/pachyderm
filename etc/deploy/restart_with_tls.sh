#!/bin/bash

eval "set -- $( getopt -l "key:,cert:" "--" "${0}" "${@}" )"
while true; do
  case "${1}" in
    --cert)
      export PACH_CA_CERTS="${2}"
      shift 2
      ;;
    --key)
      PACH_TLS_KEY="${2}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
  esac
done

# Turn down old pachd deployment, so that new (TLS-enabled) pachd doesn't try to connect to old, non-TLS pods
# I'm not sure why this is necessary -- pachd should communicate with itself via an unencrypted, internal port
# Empirically, though, the new pachd pod crashloops if I don't do this (2018/6/22)
pachctl undeploy

# Re-deploy pachd with new mount containing TLS key
pachctl deploy local -d --tls="${PACH_CA_CERTS},${PACH_TLS_KEY}" --dry-run | kubectl apply -f -


# Wait for new pachd pod to start
echo "Waiting for old pachd to go down..."
WHEEL='\|/-'
retries=5
while pachctl version &>/dev/null && (( retries-- > 0 )); do
  echo -en "\e[G${WHEEL::1} (retries: ${retries})"
  WHEEL="${WHEEL:1}${WHEEL::1}"
  sleep 1
done
echo

# Wait one minute for pachd to come up
echo "Waiting for new pachd to come up..."
retries=20
until pachctl version &>/dev/null || (( retries-- == 0 )); do
  echo -en "\e[G${WHEEL::1} (retries: ${retries})"
  WHEEL="${WHEEL:1}${WHEEL::1}"
  sleep 3
done
echo
