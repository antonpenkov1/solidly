#!/usr/bin/env python3
"""Checks a built archive against the things App Store Connect rejects on upload.

    xcodebuild -project Spoonlet.xcodeproj -scheme Spoonlet -configuration Release \\
      -destination 'generic/platform=iOS' -archivePath build/Spoonlet.xcarchive archive
    python3 Tools/preflight.py

Every check here exists because the failure is silent until the upload bounces, and the
turnaround on a bounced upload is far longer than the check. Exits non-zero on any problem.
"""
import plistlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "build" / "Spoonlet.xcarchive"
APP = ARCHIVE / "Products/Applications/Spoonlet.app"
WIDGET = APP / "PlugIns/SpoonletWidget.appex"

passed: list[str] = []
failed: list[str] = []


def check(condition: bool, good: str, bad: str) -> None:
    (passed if condition else failed).append(good if condition else bad)


def load(path: Path) -> dict:
    with open(path, "rb") as handle:
        return plistlib.load(handle)


def main() -> int:
    if not APP.exists():
        raise SystemExit(f"no archive at {ARCHIVE} — build one first (see the docstring)")

    app = load(APP / "Info.plist")
    widget = load(WIDGET / "Info.plist")

    # ITMS-90713. actool writes CFBundleIconName only *nested* inside CFBundleIcons when the
    # icon comes from a layered .icon bundle, so the top-level key must be stated explicitly
    # in the Info.plist. This one cost a bounced upload to discover.
    check(app.get("CFBundleIconName") == "AppIcon",
          "CFBundleIconName present at the top level",
          "CFBundleIconName missing at the top level — upload rejected as ITMS-90713")

    check(app.get("ITSAppUsesNonExemptEncryption") is False,
          "export compliance answered in the plist",
          "ITSAppUsesNonExemptEncryption missing — every upload will ask")

    check(app.get("CFBundleShortVersionString") == widget.get("CFBundleShortVersionString"),
          f"app and widget share version {app.get('CFBundleShortVersionString')}",
          f"version mismatch: app {app.get('CFBundleShortVersionString')} "
          f"vs widget {widget.get('CFBundleShortVersionString')}")

    check(app.get("CFBundleVersion") == widget.get("CFBundleVersion"),
          f"app and widget share build {app.get('CFBundleVersion')}",
          f"build mismatch: app {app.get('CFBundleVersion')} "
          f"vs widget {widget.get('CFBundleVersion')}")

    families = app.get("UIDeviceFamily", [])
    check(1 in families and 2 in families,
          "iPhone and iPad both claimed",
          f"UIDeviceFamily is {families} — screenshots must match what is claimed")

    check("UISupportedInterfaceOrientations~ipad" in app,
          "iPad orientations declared",
          "no iPad orientations — a portrait-locked tablet app invites a design rejection")

    check(bool(app.get("CFBundleURLTypes")),
          "spoonlet:// URL scheme registered",
          "no CFBundleURLTypes — the widget's deep links will not open")

    catalogue = subprocess.run(["xcrun", "assetutil", "--info", str(APP / "Assets.car")],
                               capture_output=True, text=True).stdout
    check("AppIcon1024x1024_UIAppearanceAny" in catalogue,
          "1024 marketing icon compiled in",
          "no 1024 marketing icon — upload rejected")
    check("ISAppearanceTintable" in catalogue,
          "tinted icon appearance generated",
          "no tinted icon variant — the layered icon did not compile as Liquid Glass")

    dsyms = list((ARCHIVE / "dSYMs").glob("*.dSYM")) if (ARCHIVE / "dSYMs").exists() else []
    check(len(dsyms) >= 2,
          f"{len(dsyms)} dSYM bundles present",
          "missing dSYMs — crash reports will be unreadable")

    for kind, size in [("iphone", (1320, 2868)), ("ipad", (2064, 2752))]:
        shots = sorted((ROOT / "AppStore" / "screenshots" / kind).rglob("*.png"))
        check(len(shots) == 12,
              f"{kind}: 12 screenshots ({size[0]}x{size[1]})",
              f"{kind}: {len(shots)} screenshots, expected 12 — regenerate with "
              f"Tools/screenshots.py --device {kind}")

    print("PASSED")
    for line in passed:
        print("  ✓", line)
    if failed:
        print("\nPROBLEMS")
        for line in failed:
            print("  ✗", line)
        return 1
    print("\nNothing blocking. The upload itself still needs an Apple ID.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
