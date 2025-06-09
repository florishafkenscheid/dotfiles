#!/bin/sh

ACTION=$1

if playerctl -l | grep -q "spotify_player"; then
    playerctl -p spotify_player "$ACTION"
else
    playerctl "$ACTION"
fi
