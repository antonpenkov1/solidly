#!/usr/bin/env python3
"""Captures the App Store screenshot sets, in both locales.

    python3 Tools/screenshots.py                     # iPhone 6.9", both locales
    python3 Tools/screenshots.py --device iphone65   # iPhone 6.5", both locales
    python3 Tools/screenshots.py --device ipad       # iPad 13", both locales
    python3 Tools/screenshots.py ru                  # one locale

Writes AppStore/screenshots/<device>/<locale>/NN-<name>.png and fails loudly if any shot
is not the exact size App Store Connect expects for that slot. Every shot is driven by a
DEBUG launch argument rather than by tapping, so the set is reproducible and does not drift
when the layout changes.

Both device sets are required: the app claims iPhone and iPad, and a version cannot be
submitted with an empty slot.
"""
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = "com.antonpenkov.spoonlet"

# App Store Connect wants one slot per device class the app claims, and it validates the
# exact pixel size per slot — a 6.9" shot dropped into the 6.5" slot is rejected outright.
# Spoonlet claims iPhone and iPad, and App Store Connect still shows a 6.5" iPhone slot, so
# all three sets are kept.
DEVICES = {
    "iphone": ("iPhone 17 Pro Max", (1320, 2868)),      # 6.9" slot
    "iphone65": ("iPhone 13 Pro Max", (1284, 2778)),    # 6.5" slot (1242x2688 also accepted)
    "ipad": ("iPad Pro 13-inch (M5)", (2064, 2752)),    # 13" slot
}

# (order, name, extra launch arguments)
SHOTS = [
    ("01", "today", ["-OpenTab", "0"]),
    ("02", "food-detail", ["-OpenTab", "2", "-OpenFood", "peanut"]),
    ("03", "foods", ["-OpenTab", "2"]),
    ("04", "plan", ["-OpenTab", "3", "-DemoOverrides", "1"]),
    ("05", "growth", ["-OpenTab", "4"]),
    ("06", "sources", ["-OpenTab", "3", "-OpenSources", "1"]),
]

LOCALES = {
    "en": ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"],
    "ru": ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"],
}


def run(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs)


def device_udid(name: str) -> str:
    # Device names contain brackets of their own — "iPad Pro 13-inch (M5) (UDID)" — so the
    # UDID has to be matched by shape rather than by taking the first bracketed group.
    pattern = re.compile(r"\(([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})\)")
    out = run(["xcrun", "simctl", "list", "devices", "available"]).stdout
    for line in out.splitlines():
        if line.strip().startswith(name + " ("):
            match = pattern.search(line)
            if match:
                return match.group(1)
    raise SystemExit(f"simulator '{name}' not found — check `xcrun simctl list devices`")


def build(device: str) -> str:
    print("building…")
    subprocess.run([
        "xcodebuild", "-project", str(ROOT / "Spoonlet.xcodeproj"), "-scheme", "Spoonlet",
        "-destination", f"platform=iOS Simulator,name={device}",
        "-configuration", "Debug", "build",
    ], check=True, capture_output=True, text=True)

    settings = subprocess.run([
        "xcodebuild", "-project", str(ROOT / "Spoonlet.xcodeproj"), "-scheme", "Spoonlet",
        "-destination", f"platform=iOS Simulator,name={device}",
        "-configuration", "Debug", "-showBuildSettings",
    ], check=True, capture_output=True, text=True).stdout

    products = name = None
    for line in settings.splitlines():
        if " BUILT_PRODUCTS_DIR = " in line:
            products = line.split(" = ", 1)[1].strip()
        elif " FULL_PRODUCT_NAME = " in line:
            name = line.split(" = ", 1)[1].strip()
    if not products or not name:
        raise SystemExit("could not read build settings")
    return f"{products}/{name}"


def capture(udid: str, app: str, locale: str, locale_args: list[str], kind: str, expected) -> None:
    out_dir = ROOT / "AppStore" / "screenshots" / kind / locale
    out_dir.mkdir(parents=True, exist_ok=True)

    # Seed once per locale, then reuse the same data for every shot so the numbers on the
    # Today screen match the entries in the Log screenshot.
    first = True
    for order, name, extra in SHOTS:
        subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE],
                       capture_output=True, text=True)
        seed = ["-DemoSeed", "1"] + (["-DemoReset", "1"] if first else [])
        first = False
        run(["xcrun", "simctl", "launch", udid, BUNDLE] + seed + extra + locale_args)
        time.sleep(4)

        path = out_dir / f"{order}-{name}.png"
        run(["xcrun", "simctl", "io", udid, "screenshot", str(path)])
        print(f"  {locale}/{path.name}")

    verify(out_dir, expected)


def verify(out_dir: Path, expected) -> None:
    try:
        from PIL import Image
    except ImportError:
        print("  (install Pillow to verify screenshot dimensions)")
        return
    for path in sorted(out_dir.glob("*.png")):
        with Image.open(path) as image:
            if image.size != expected:
                raise SystemExit(
                    f"{path.name} is {image.size[0]}x{image.size[1]}, "
                    f"App Store Connect wants {expected[0]}x{expected[1]}"
                )
            # The buffer is the right size even when the content inside it is sideways, so
            # size alone is not enough: check that the status bar runs along the top.
            top = image.crop((0, 0, image.width, 60)).convert("L")
            left = image.crop((0, 0, 60, image.height)).convert("L")
            dark_top = sum(1 for pixel in top.getdata() if pixel < 120)
            dark_left = sum(1 for pixel in left.getdata() if pixel < 120)
            if dark_top <= dark_left:
                raise SystemExit(
                    f"{path.name} looks rotated — the status bar is down the side. "
                    "Shut the simulator down and re-run."
                )
    print(f"  all {len(list(out_dir.glob('*.png')))} shots are {expected[0]}x{expected[1]}, upright")


def main() -> int:
    args = sys.argv[1:]
    kind = "iphone"
    if "--device" in args:
        index = args.index("--device")
        kind = args[index + 1]
        del args[index:index + 2]
    if kind not in DEVICES:
        raise SystemExit(f"unknown device '{kind}' — expected one of {list(DEVICES)}")

    name, expected = DEVICES[kind]
    wanted = args or list(LOCALES)
    udid = device_udid(name)
    print(f"{name}: {udid}")

    # A simulator remembers the orientation it was left in, and simctl has no way to set it.
    # A shutdown/boot cycle resets it to portrait — without this an iPad left in landscape
    # silently produces sideways screenshots inside a portrait buffer, which App Store
    # Connect rejects.
    subprocess.run(["xcrun", "simctl", "shutdown", udid], capture_output=True, text=True)
    time.sleep(3)
    subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True, text=True)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], capture_output=True, text=True)
    subprocess.run(["xcrun", "simctl", "ui", udid, "appearance", "light"],
                   capture_output=True, text=True)

    app = build(name)
    subprocess.run(["xcrun", "simctl", "uninstall", udid, BUNDLE], capture_output=True, text=True)
    run(["xcrun", "simctl", "install", udid, app])

    for locale in wanted:
        if locale not in LOCALES:
            raise SystemExit(f"unknown locale '{locale}' — expected one of {list(LOCALES)}")
        print(f"capturing {locale}…")
        capture(udid, app, locale, LOCALES[locale], kind, expected)

    print("done →", ROOT / "AppStore" / "screenshots" / kind)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
