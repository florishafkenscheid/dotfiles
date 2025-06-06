#!/bin/sh
hyprctl monitors -j | jq '.[] | select(.focused==true) | .id'
