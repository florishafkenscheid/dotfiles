#!/usr/bin/env python3
import fcntl
import json
import os
import sys
import time
from pathlib import Path


VENDOR_ID = "373e"
PRODUCT_IDS = {"001e": "wireless", "001c": "wired"}
FEATURE_LEN = 65


def ioc(direction, request_type, nr, size):
    nr_bits = 8
    type_bits = 8
    size_bits = 14
    nr_shift = 0
    type_shift = nr_shift + nr_bits
    size_shift = type_shift + type_bits
    direction_shift = size_shift + size_bits
    return (
        (direction << direction_shift)
        | (size << size_shift)
        | (ord(request_type) << type_shift)
        | (nr << nr_shift)
    )


def hid_iocgfeature(size):
    # HIDIOCGFEATURE(size) from linux/hidraw.h.
    return ioc(3, "H", 0x07, size)


def hid_iocsfeature(size):
    # HIDIOCSFEATURE(size) from linux/hidraw.h. This is read/write, not write-only.
    return ioc(3, "H", 0x06, size)


def icon_for_percent(percent):
    if percent <= 10:
        return "󰁺"
    if percent <= 25:
        return "󰁻"
    if percent <= 50:
        return "󰁾"
    if percent <= 75:
        return "󰂁"
    return "󰁹"


def class_for_percent(percent):
    if percent <= 20:
        return "low"
    if percent <= 40:
        return "medium"
    return "high"


def read_uevent(path):
    values = {}
    try:
        for line in path.read_text().splitlines():
            key, _, value = line.partition("=")
            values[key] = value
    except OSError:
        pass
    return values


def is_lamzu_maya(uevent):
    hid_id = uevent.get("HID_ID", "").lower()
    vendor = f"{int(VENDOR_ID, 16):08x}"
    return any(f"{vendor}:{int(product, 16):08x}" in hid_id for product in PRODUCT_IDS)


def connection_for_device(path):
    uevent = read_uevent(path / "device" / "uevent")
    hid_id = uevent.get("HID_ID", "").lower()

    for product, connection in PRODUCT_IDS.items():
        if f"{int(product, 16):08x}" in hid_id:
            return connection

    return "unknown"


def is_control_endpoint(report_descriptor):
    # Maya X control endpoint: vendor page 0xffff, one 64-byte feature report.
    return b"\x06\xff\xff" in report_descriptor and b"\x95\x40\xb1\x02" in report_descriptor


def sysfs_for_hidraw(path):
    return Path("/sys/class/hidraw") / path.name


def dev_for_hidraw(path):
    return Path("/dev") / path.name


def discover_hidraw():
    override = os.environ.get("LAMZU_HIDRAW")
    if override:
        override_path = Path(override)
        if override_path.parent == Path("/dev"):
            return sysfs_for_hidraw(override_path)
        return override_path

    candidates = []
    for hidraw in sorted(Path("/sys/class/hidraw").glob("hidraw*")):
        uevent = read_uevent(hidraw / "device" / "uevent")
        if not is_lamzu_maya(uevent):
            continue

        try:
            descriptor = (hidraw / "device" / "report_descriptor").read_bytes()
        except OSError:
            descriptor = b""

        score = 1 if is_control_endpoint(descriptor) else 0
        readable = os.access(dev_for_hidraw(hidraw), os.R_OK | os.W_OK)
        candidates.append((score, int(readable), str(hidraw), hidraw))

    if not candidates:
        raise RuntimeError("Lamzu Maya X hidraw device not found")

    return sorted(candidates, reverse=True)[0][3]


def read_battery(hidraw):
    path = dev_for_hidraw(hidraw)
    connection = connection_for_device(hidraw)
    fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    try:
        # Aurora Web Driver getBatPer(): payload[2]=2, payload[3]=2, payload[5]=131.
        # hidraw ioctls include a leading report ID byte; the Maya X feature report is unnumbered.
        request = bytearray(FEATURE_LEN)
        request[3] = 2
        request[4] = 2
        request[6] = 131
        fcntl.ioctl(fd, hid_iocsfeature(FEATURE_LEN), request, True)
        time.sleep(0.1)

        response = bytearray(FEATURE_LEN)
        response[0] = 0
        fcntl.ioctl(fd, hid_iocgfeature(FEATURE_LEN), response, True)

        if response[1] == 0xA1 and response[4] == 2 and response[6] == 131:
            raw_mode = response[7]
            percent = response[8]
        elif response[0] == 0xA1 and response[3] == 2 and response[5] == 131:
            raw_mode = response[6]
            percent = response[7]
        else:
            raise RuntimeError(f"unexpected response header: {response[:10].hex()}")

        if percent > 100:
            raise RuntimeError(f"implausible battery percent: {percent}")

        return {
            "available": True,
            "path": str(path),
            "connection": connection,
            "percent": percent,
            "millivolts": 0,
            "raw_mode": raw_mode,
            "raw_status": percent,
            "icon": icon_for_percent(percent),
            "class": class_for_percent(percent),
        }
    finally:
        os.close(fd)


def unavailable(error):
    return {
        "available": False,
        "path": "",
        "connection": "unknown",
        "percent": 0,
        "millivolts": 0,
        "icon": "󰂑",
        "class": "unavailable",
        "error": str(error),
    }


def main():
    try:
        result = read_battery(discover_hidraw())
    except Exception as exc:
        result = unavailable(exc)

    if os.environ.get("LAMZU_BATTERY_PLAIN") == "1":
        if result["available"]:
            print(result["percent"])
        else:
            print("")
    else:
        print(json.dumps(result, separators=(",", ":")))

    return 0


if __name__ == "__main__":
    sys.exit(main())
