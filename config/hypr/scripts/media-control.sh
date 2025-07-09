#!/bin/sh

ACTION=$1

if playerctl -l | grep -q "spotify"; then
    playerctl -p spotify "$ACTION"
else
    playerctl "$ACTION"
fi
