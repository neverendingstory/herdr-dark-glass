#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

if not __debug__:
    raise RuntimeError("dark glass asset tests require assertions; do not use PYTHONOPTIMIZE")

ROOT = Path(__file__).resolve().parents[1]
PROFILES_DIR = ROOT / "profiles"
GENERATOR = ROOT / "tools/build-terminal-profile.py"
PROFILE_LEVELS = {
    "Herdr Dark Glass": 0.46,
    "Herdr Dark Glass Glass": 0.46,
    "Herdr Dark Glass Clear": 0.60,
    "Herdr Dark Glass Read": 0.74,
    "Herdr Dark Glass Focus": 0.88,
}
PROFILE_PATHS = {name: PROFILES_DIR / f"{name}.terminal" for name in PROFILE_LEVELS}


def archived_components(value: bytes) -> tuple[float, ...]:
    archive = plistlib.loads(value)
    assert archive["$archiver"] == "NSKeyedArchiver"
    assert archive["$top"]["root"] == plistlib.UID(1)
    color = archive["$objects"][1]
    assert color["$class"] == plistlib.UID(2)
    color_class = archive["$objects"][2]
    assert color_class["$classname"] == "NSColor"
    assert color_class["$classes"] == ["NSColor", "NSObject"]
    raw = color.get("NSRGB", color.get("NSComponents"))
    if not isinstance(raw, bytes):
        raise AssertionError("archived color has no byte component payload")
    return tuple(float(item) for item in raw.rstrip(b"\0").split())


def assert_components(actual: tuple[float, ...], expected: tuple[float, ...]) -> None:
    assert len(actual) == len(expected)
    for observed, wanted in zip(actual, expected):
        assert math.isclose(observed, wanted, abs_tol=1e-9)


def rgb(value: tuple[int, int, int]) -> tuple[float, float, float]:
    return tuple(channel / 255 for channel in value)


def relative_luminance(color: tuple[float, float, float]) -> float:
    linear = tuple(
        channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
        for channel in color
    )
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast_ratio(foreground: tuple[float, float, float], background: tuple[float, float, float]) -> float:
    lighter, darker = sorted((relative_luminance(foreground), relative_luminance(background)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def composited_over_white(color: tuple[float, float, float], alpha: float) -> tuple[float, float, float]:
    return tuple(channel * alpha + (1 - alpha) for channel in color)


assert GENERATOR.is_file()
for profile_path in PROFILE_PATHS.values():
    assert profile_path.is_file(), profile_path

ANSI_COLORS = {
    "ANSIBlackColor": (8, 14, 20),
    "ANSIRedColor": (231, 130, 132),
    "ANSIGreenColor": (166, 209, 137),
    "ANSIYellowColor": (229, 200, 144),
    "ANSIBlueColor": (139, 213, 255),
    "ANSIMagentaColor": (196, 167, 231),
    "ANSICyanColor": (131, 197, 190),
    "ANSIWhiteColor": (213, 216, 212),
    "ANSIBrightBlackColor": (185, 190, 185),
    "ANSIBrightRedColor": (231, 130, 132),
    "ANSIBrightGreenColor": (183, 214, 163),
    "ANSIBrightYellowColor": (229, 200, 144),
    "ANSIBrightBlueColor": (139, 213, 255),
    "ANSIBrightMagentaColor": (196, 167, 231),
    "ANSIBrightCyanColor": (139, 213, 255),
    "ANSIBrightWhiteColor": (255, 255, 255),
}

for profile_name, opacity in PROFILE_LEVELS.items():
    with PROFILE_PATHS[profile_name].open("rb") as handle:
        profile = plistlib.load(handle)

    assert profile["name"] == profile_name
    assert profile["type"] == "Window Settings"
    assert math.isclose(profile["ProfileCurrentVersion"], 2.09, abs_tol=1e-9)
    assert math.isclose(profile["BackgroundBlur"], 0.24, abs_tol=1e-9)
    assert math.isclose(profile["BackgroundBlurInactive"], 0.24, abs_tol=1e-9)
    assert profile["BackgroundSettingsForInactiveWindows"] is False
    assert profile["FontAntialias"] is True
    assert math.isclose(profile["FontHeightSpacing"], 1.0, abs_tol=1e-9)
    assert profile["FontWidthSpacing"] == 1
    assert profile["columnCount"] == 120
    assert profile["rowCount"] == 30
    assert profile["useOptionAsMetaKey"] is True

    font = plistlib.loads(profile["Font"])
    assert font["$archiver"] == "NSKeyedArchiver"
    assert font["$top"]["root"] == plistlib.UID(1)
    assert font["$objects"][3]["$classname"] == "NSFont"
    assert font["$objects"][3]["$classes"] == ["NSFont", "NSObject"]
    assert font["$objects"][2] == "SFMonoTerminal-Regular"
    assert math.isclose(font["$objects"][1]["NSSize"], 12.0, abs_tol=1e-9)

    assert_components(archived_components(profile["BackgroundColor"]), (*rgb((8, 14, 20)), opacity))
    assert_components(archived_components(profile["TextColor"]), rgb((245, 243, 237)))
    assert_components(archived_components(profile["TextBoldColor"]), (1.0, 1.0, 1.0))
    assert_components(archived_components(profile["CursorColor"]), rgb((183, 214, 163)))
    assert_components(archived_components(profile["SelectionColor"]), rgb((41, 51, 45)))
    for key, value in ANSI_COLORS.items():
        assert_components(archived_components(profile[key]), rgb(value))

with tempfile.TemporaryDirectory() as directory:
    output_dir = Path(directory) / "generated"
    subprocess.run([sys.executable, str(GENERATOR), "--all", str(output_dir)], check=True)
    for profile_name, profile_path in PROFILE_PATHS.items():
        rebuilt = output_dir / f"{profile_name}.terminal"
        assert rebuilt.read_bytes() == profile_path.read_bytes()

    rebuilt_legacy = Path(directory) / "legacy.terminal"
    subprocess.run([sys.executable, str(GENERATOR), str(rebuilt_legacy)], check=True)
    assert rebuilt_legacy.read_bytes() == PROFILE_PATHS["Herdr Dark Glass"].read_bytes()

background = rgb((8, 14, 20))
primary = rgb((245, 243, 237))
muted = rgb((185, 190, 185))
assert contrast_ratio(primary, composited_over_white(background, PROFILE_LEVELS["Herdr Dark Glass Read"])) >= 7.0
assert contrast_ratio(muted, composited_over_white(background, PROFILE_LEVELS["Herdr Dark Glass Read"])) >= 4.5
assert contrast_ratio(muted, composited_over_white(background, PROFILE_LEVELS["Herdr Dark Glass Focus"])) >= 7.0

OPENCODE_THEME = ROOT / "integrations/opencode/herdr-dark-glass.json"
with OPENCODE_THEME.open(encoding="utf-8") as handle:
    opencode = json.load(handle)

assert opencode["$schema"] == "https://opencode.ai/theme.json"
defs = opencode["defs"]
assert defs == {
    "accent": "#B7D6A3",
    "blue": "#8BD5FF",
    "green": "#A6D189",
    "yellow": "#E5C890",
    "red": "#E78284",
    "purple": "#C4A7E7",
    "text": "#F5F3ED",
    "muted": "#B9BEB9",
    "overlay": "#87918C",
    "border": "#6C7770",
    "subtle": "#48524D",
}
theme = opencode["theme"]
assert theme["primary"] == "accent"
assert theme["secondary"] == "blue"
assert theme["accent"] == "accent"
assert theme["text"] == "text"
assert theme["textMuted"] == "muted"
for key in (
    "background",
    "backgroundPanel",
    "backgroundElement",
    "diffAddedBg",
    "diffRemovedBg",
    "diffContextBg",
    "diffAddedLineNumberBg",
    "diffRemovedLineNumberBg",
):
    assert theme[key] == "none"

print("dark glass generated and integration assets: ok")
