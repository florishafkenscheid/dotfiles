#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EWW_CONFIG_DIR=$(dirname -- "$SCRIPT_DIR")

MULLVAD_STATUS=$(mullvad status -j | jq -r '.state')

if [ "$MULLVAD_STATUS" = "connected" ]; then
    mullvad lockdown-mode set off
    mullvad disconnect
else
    mullvad lockdown-mode set on
    mullvad connect
fi

UPDATED_STATUS=$(mullvad status -j | jq -r '.state')

if [ -n "${EWW_CMD:-}" ]; then
    $EWW_CMD update mullvad_status="$UPDATED_STATUS" >/dev/null 2>&1 || true
else
    eww --config "$EWW_CONFIG_DIR" update mullvad_status="$UPDATED_STATUS" >/dev/null 2>&1 || true
fi
