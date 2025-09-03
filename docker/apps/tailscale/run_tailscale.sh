#!/usr/bin/env bash
set -euo pipefail

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
    echo -n "Enter TS_AUTHKEY: "
    read -r -s TS_AUTHKEY
    echo
fi

#Verify TS_AUTHKEY ok
if [[ -z "${TS_AUTHKEY}" ]]; then
    echo "TS_AUTHKEY cannot be null or empty"
    exit 1
fi

#deploying headscale stack inyection env var
TS_AUTHKEY="${TS_AUTHKEY}" ${DC} up -d

echo "headscale client deployment success. See logs with ${} logs -f tailscale-client"