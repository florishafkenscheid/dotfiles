#!/usr/bin/env python3

import json
import os
import re
from pathlib import Path


SUPPORTED_ICON_SUFFIXES = (".svg", ".png", ".webp", ".jpg", ".jpeg")
MINECRAFT_VERSION_PATTERN = re.compile(
    r"/com/mojang/minecraft/([^/:\s]+)/"
)


def instance_value(config_path, key):
    prefix = f"{key}="
    try:
        for line in config_path.read_text(errors="replace").splitlines():
            if line.startswith(prefix):
                return line[len(prefix) :].strip()
    except OSError:
        pass
    return ""


def find_icon(icons_dir, icon_key):
    if not icon_key or icon_key == "default":
        return None

    for suffix in SUPPORTED_ICON_SUFFIXES:
        candidate = icons_dir / f"{icon_key}{suffix}"
        if candidate.is_file():
            return candidate
    return None


def running_instances(instances_dir, instance_icons):
    process_icons = {}
    versions = {}
    instance_prefix = f"{instances_dir.resolve()}/"

    for process_dir in Path("/proc").iterdir():
        if not process_dir.name.isdigit():
            continue

        try:
            command = (
                (process_dir / "cmdline")
                .read_bytes()
                .replace(b"\0", b" ")
                .decode(errors="replace")
            )
        except OSError:
            continue

        prefix_offset = command.find(instance_prefix)
        if prefix_offset < 0:
            continue

        instance_path = command[prefix_offset + len(instance_prefix) :]
        instance_id = instance_path.split("/", 1)[0].casefold()
        icon_url = instance_icons.get(instance_id)
        if not icon_url:
            continue

        process_icons[process_dir.name] = icon_url
        version_match = MINECRAFT_VERSION_PATTERN.search(command)
        if version_match:
            version = version_match.group(1).casefold()
            versions.setdefault(version, {})[instance_id] = icon_url

    unique_versions = {
        version: next(iter(candidates.values()))
        for version, candidates in versions.items()
        if len(candidates) == 1
    }
    return process_icons, unique_versions


def main():
    data_home = Path(
        os.environ.get(
            "XDG_DATA_HOME",
            Path.home() / ".local" / "share",
        )
    )
    prism_dir = data_home / "PrismLauncher"
    instances_dir = prism_dir / "instances"
    icons_dir = prism_dir / "icons"
    instance_icons = {}

    if instances_dir.is_dir():
        for instance_dir in sorted(instances_dir.iterdir()):
            config_path = instance_dir / "instance.cfg"
            if not instance_dir.is_dir() or not config_path.is_file():
                continue

            icon_key = instance_value(config_path, "iconKey")
            icon_path = find_icon(icons_dir, icon_key)
            if icon_path is None:
                minecraft_icon = instance_dir / "minecraft" / "icon.png"
                if minecraft_icon.is_file():
                    icon_path = minecraft_icon
            if icon_path is None:
                continue

            icon_url = icon_path.resolve().as_uri()
            instance_icons[instance_dir.name.casefold()] = icon_url

    process_icons, version_icons = running_instances(
        instances_dir,
        instance_icons,
    )
    print(
        json.dumps(
            {
                "processes": process_icons,
                "versions": version_icons,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
