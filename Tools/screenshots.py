#!/usr/bin/env python3
"""Captures App Store screenshots on the 6.9" simulator, in both locales.

    python3 Tools/screenshots.py            # both locales
    python3 Tools/screenshots.py ru         # one locale

Writes AppStore/screenshots/<locale>/NN-<name>.png at 1320 x 2868, which is the size App
Store Connect wants for the 6.9" iPhone slot. Every shot is driven by a DEBUG launch
argument rather than by tapping, so the set is reproducible and does not drift when the
layout changes.
"""
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEVICE = "iPhone 17 Pro Max"
BUNDLE = "com.antonpenkov.tummi"
EXPECTED_SIZE = (1320, 2868)

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


def device_udid() -> str:
    out = run(["xcrun", "simctl", "list", "devices", "available"]).stdout
    for line in out.splitlines():
        if line.strip().startswith(DEVICE + " ("):
            return line.split("(")[1].split(")")[0]
    raise SystemExit(f"simulator '{DEVICE}' not found — check `xcrun simctl list devices`")


def build() -> str:
    print("building…")
    subprocess.run([
        "xcodebuild", "-project", str(ROOT / "Tummi.xcodeproj"), "-scheme", "Tummi",
        "-destination", f"platform=iOS Simulator,name={DEVICE}",
        "-configuration", "Debug", "build",
    ], check=True, capture_output=True, text=True)

    settings = subprocess.run([
        "xcodebuild", "-project", str(ROOT / "Tummi.xcodeproj"), "-scheme", "Tummi",
        "-destination", f"platform=iOS Simulator,name={DEVICE}",
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


def capture(udid: str, app: str, locale: str, locale_args: list[str]) -> None:
    out_dir = ROOT / "AppStore" / "screenshots" / locale
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

    verify(out_dir)


def verify(out_dir: Path) -> None:
    try:
        from PIL import Image
    except ImportError:
        print("  (install Pillow to verify screenshot dimensions)")
        return
    for path in sorted(out_dir.glob("*.png")):
        with Image.open(path) as image:
            if image.size != EXPECTED_SIZE:
                raise SystemExit(
                    f"{path.name} is {image.size[0]}x{image.size[1]}, "
                    f"App Store Connect wants {EXPECTED_SIZE[0]}x{EXPECTED_SIZE[1]}"
                )
    print(f"  all {len(list(out_dir.glob('*.png')))} shots are {EXPECTED_SIZE[0]}x{EXPECTED_SIZE[1]}")


def main() -> int:
    wanted = sys.argv[1:] or list(LOCALES)
    udid = device_udid()
    print(f"{DEVICE}: {udid}")

    subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True, text=True)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], capture_output=True, text=True)
    subprocess.run(["xcrun", "simctl", "ui", udid, "appearance", "light"],
                   capture_output=True, text=True)

    app = build()
    subprocess.run(["xcrun", "simctl", "uninstall", udid, BUNDLE], capture_output=True, text=True)
    run(["xcrun", "simctl", "install", udid, app])

    for locale in wanted:
        if locale not in LOCALES:
            raise SystemExit(f"unknown locale '{locale}' — expected one of {list(LOCALES)}")
        print(f"capturing {locale}…")
        capture(udid, app, locale, LOCALES[locale])

    print("done →", ROOT / "AppStore" / "screenshots")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
