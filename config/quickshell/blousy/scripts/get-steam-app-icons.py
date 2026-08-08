#!/usr/bin/env python3

import json
from pathlib import Path


APP_ID_KEYS = (
    b"SteamAppId",
    b"SteamGameId",
    b"STEAM_COMPAT_APP_ID",
    b"SteamOverlayGameId",
)


def steam_app_id(process_dir):
    try:
        entries = (process_dir / "environ").read_bytes().split(b"\0")
    except OSError:
        return None

    variables = {}
    for entry in entries:
        key, separator, value = entry.partition(b"=")
        if separator:
            variables[key] = value

    for key in APP_ID_KEYS:
        value = variables.get(key, b"")
        if value.isdigit() and int(value) > 0:
            return value.decode("ascii")
    return None


def main():
    icons = {}
    for process_dir in Path("/proc").iterdir():
        if not process_dir.name.isdigit():
            continue

        app_id = steam_app_id(process_dir)
        if app_id:
            icons[process_dir.name] = f"steam_icon_{app_id}"

    print(json.dumps(icons, sort_keys=True))


if __name__ == "__main__":
    main()
