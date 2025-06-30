#!/bin/sh
#
# SPDX-License-Identifier: Apache-2.0
#
set -euo pipefail

: "${CORE_PEER_TLS_ENABLED:=false}"
: "${DEBUG:=false}"

if [ "${DEBUG}" = "true" ]; then
  echo "[INFO] Starting Go chaincode in debug mode..."
  exec /chaincode
elif [ "${CORE_PEER_TLS_ENABLED}" = "true" ]; then
  echo "[INFO] Starting Go chaincode with TLS enabled..."
  exec /chaincode
else
  echo "[INFO] Starting Go chaincode..."
  exec /chaincode
fi
