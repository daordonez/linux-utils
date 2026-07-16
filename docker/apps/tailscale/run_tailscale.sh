#!/usr/bin/env bash
set -euo pipefail

readonly APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${APP_DIR}/../../lib/terminal_input.sh"

#verify docker compose version on this host
if docker compose version >/dev/null 2>&1; then
    DC="docker compose"
elif docker-compose version >/dev/null 2>&1; then
    DC="docker-compose"
else
    echo "No docker compose found"
    exit 1
fi

#Verify TS_AUTHKEY variable whether if it's on env variables or ask for it
if [[ -z "${TS_AUTHKEY:-}" ]]; then
    echo "Tailscale setup: paste the auth key now; each character will appear as an asterisk." >&2
    printf 'Enter TS_AUTHKEY: ' >&2
    read_masked_value
    TS_AUTHKEY="${REPLY}"
fi

#Verify TS_AUTHKEY ok
if [[ -z "${TS_AUTHKEY}" ]]; then
    echo "TS_AUTHKEY cannot be null or empty"
    exit 1
fi

#deploying headscale stack inyection env var

HOSTNAME="$(hostname)" TS_AUTHKEY="${TS_AUTHKEY}" ${DC} up -d

echo "headscale client deployment success. See logs with ${DC} logs -f tailscale-client"
