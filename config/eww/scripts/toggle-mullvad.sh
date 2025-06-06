#!/bin/sh
MULLVAD_STATUS=$(mullvad status -j | jq -r '.state')

if [ "$MULLVAD_STATUS" = "connected" ]; then
    mullvad lockdown-mode set off
    mullvad disconnect
else
    mullvad lockdown-mode set on
    mullvad connect
fi
