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
PROFILE = ROOT / "profiles/Herdr Dark Glass.terminal"
GENERATOR = ROOT / "tools/build-terminal-profile.py"


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


assert GENERATOR.is_file()
assert PROFILE.is_file()

with PROFILE.open("rb") as handle:
    profile = plistlib.load(handle)

assert profile["name"] == "Herdr Dark Glass"
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

assert_components(
    archived_components(profile["BackgroundColor"]),
    (*rgb((8, 14, 20)), 0.46),
)
assert_components(archived_components(profile["TextColor"]), rgb((245, 243, 237)))
assert_components(archived_components(profile["TextBoldColor"]), (1.0, 1.0, 1.0))
assert_components(archived_components(profile["CursorColor"]), rgb((183, 214, 163)))
assert_components(archived_components(profile["SelectionColor"]), rgb((41, 51, 45)))

ANSI_COLORS = {
    "ANSIBlackColor": (8, 14, 20),
    "ANSIRedColor": (231, 130, 132),
    "ANSIGreenColor": (166, 209, 137),
    "ANSIYellowColor": (229, 200, 144),
    "ANSIBlueColor": (139, 213, 255),
    "ANSIMagentaColor": (196, 167, 231),
    "ANSICyanColor": (131, 197, 190),
    "ANSIWhiteColor": (213, 216, 212),
    "ANSIBrightBlackColor": (72, 82, 77),
    "ANSIBrightRedColor": (231, 130, 132),
    "ANSIBrightGreenColor": (183, 214, 163),
    "ANSIBrightYellowColor": (229, 200, 144),
    "ANSIBrightBlueColor": (139, 213, 255),
    "ANSIBrightMagentaColor": (196, 167, 231),
    "ANSIBrightCyanColor": (139, 213, 255),
    "ANSIBrightWhiteColor": (255, 255, 255),
}
for key, value in ANSI_COLORS.items():
    assert_components(archived_components(profile[key]), rgb(value))

with tempfile.TemporaryDirectory() as directory:
    rebuilt = Path(directory) / "generated" / PROFILE.name
    subprocess.run([sys.executable, str(GENERATOR), str(rebuilt)], check=True)
    assert rebuilt.read_bytes() == PROFILE.read_bytes()

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
expected_theme = {
    "primary": "accent", "secondary": "blue", "accent": "accent", "error": "red",
    "warning": "yellow", "success": "green", "info": "blue", "text": "text",
    "textMuted": "muted", "background": "none", "backgroundPanel": "none",
    "backgroundElement": "none", "border": "border", "borderActive": "accent",
    "borderSubtle": "subtle", "diffAdded": "green", "diffRemoved": "red",
    "diffContext": "muted", "diffHunkHeader": "blue", "diffHighlightAdded": "green",
    "diffHighlightRemoved": "red", "diffAddedBg": "none", "diffRemovedBg": "none",
    "diffContextBg": "none", "diffLineNumber": "overlay",
    "diffAddedLineNumberBg": "none", "diffRemovedLineNumberBg": "none",
    "markdownText": "text", "markdownHeading": "accent", "markdownLink": "blue",
    "markdownLinkText": "blue", "markdownCode": "green", "markdownBlockQuote": "muted",
    "markdownEmph": "purple", "markdownStrong": "text", "markdownHorizontalRule": "border",
    "markdownListItem": "accent", "markdownListEnumeration": "blue", "markdownImage": "purple",
    "markdownImageText": "muted", "markdownCodeBlock": "text", "syntaxComment": "overlay",
    "syntaxKeyword": "purple", "syntaxFunction": "blue", "syntaxVariable": "text",
    "syntaxString": "green", "syntaxNumber": "yellow", "syntaxType": "accent",
    "syntaxOperator": "blue", "syntaxPunctuation": "muted",
}
required_keys = set(expected_theme)
assert required_keys == theme.keys()
assert {key: theme[key] for key in expected_theme} == expected_theme


def resolved(value: str) -> str:
    return defs.get(value, value)


expected_resolved_theme = {
    "primary": "#B7D6A3", "secondary": "#8BD5FF", "accent": "#B7D6A3", "error": "#E78284",
    "warning": "#E5C890", "success": "#A6D189", "info": "#8BD5FF", "text": "#F5F3ED",
    "textMuted": "#B9BEB9", "background": "none", "backgroundPanel": "none",
    "backgroundElement": "none", "border": "#6C7770", "borderActive": "#B7D6A3",
    "borderSubtle": "#48524D", "diffAdded": "#A6D189", "diffRemoved": "#E78284",
    "diffContext": "#B9BEB9", "diffHunkHeader": "#8BD5FF", "diffHighlightAdded": "#A6D189",
    "diffHighlightRemoved": "#E78284", "diffAddedBg": "none", "diffRemovedBg": "none",
    "diffContextBg": "none", "diffLineNumber": "#87918C",
    "diffAddedLineNumberBg": "none", "diffRemovedLineNumberBg": "none",
    "markdownText": "#F5F3ED", "markdownHeading": "#B7D6A3", "markdownLink": "#8BD5FF",
    "markdownLinkText": "#8BD5FF", "markdownCode": "#A6D189", "markdownBlockQuote": "#B9BEB9",
    "markdownEmph": "#C4A7E7", "markdownStrong": "#F5F3ED", "markdownHorizontalRule": "#6C7770",
    "markdownListItem": "#B7D6A3", "markdownListEnumeration": "#8BD5FF", "markdownImage": "#C4A7E7",
    "markdownImageText": "#B9BEB9", "markdownCodeBlock": "#F5F3ED", "syntaxComment": "#87918C",
    "syntaxKeyword": "#C4A7E7", "syntaxFunction": "#8BD5FF", "syntaxVariable": "#F5F3ED",
    "syntaxString": "#A6D189", "syntaxNumber": "#E5C890", "syntaxType": "#B7D6A3",
    "syntaxOperator": "#8BD5FF", "syntaxPunctuation": "#B9BEB9",
}
assert {key: resolved(theme[key]) for key in expected_theme} == expected_resolved_theme

print("dark glass generated and integration assets: ok")
