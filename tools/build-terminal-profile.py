#!/usr/bin/env python3
from __future__ import annotations

import argparse
import plistlib
from pathlib import Path

LEGACY_PROFILE_NAME = "Herdr Dark Glass"
DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "profiles/Herdr Dark Glass.terminal"
PROFILE_OPACITIES = {
    LEGACY_PROFILE_NAME: 0.46,
    "Herdr Dark Glass Glass": 0.46,
    "Herdr Dark Glass Clear": 0.60,
    "Herdr Dark Glass Read": 0.74,
    "Herdr Dark Glass Focus": 0.88,
}


def hex_components(value: str) -> tuple[float, float, float]:
    value = value.removeprefix("#")
    if len(value) != 6:
        raise ValueError(f"expected six-digit RGB color, got {value!r}")
    return tuple(int(value[index : index + 2], 16) / 255 for index in (0, 2, 4))


def archived_color(value: str, alpha: float = 1.0) -> bytes:
    components = (*hex_components(value), alpha)
    component_count = 4 if alpha != 1.0 else 3
    payload = " ".join(format(component, ".17g") for component in components[:component_count])
    archive = {
        "$version": 100000,
        "$archiver": "NSKeyedArchiver",
        "$top": {"root": plistlib.UID(1)},
        "$objects": [
            "$null",
            {
                "NSRGB": (payload + "\0").encode("ascii"),
                "NSColorSpace": 1,
                "$class": plistlib.UID(2),
            },
            {
                "$classname": "NSColor",
                "$classes": ["NSColor", "NSObject"],
            },
        ],
    }
    return plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=True)


def archived_font(name: str = "SFMonoTerminal-Regular", size: float = 12.0) -> bytes:
    archive = {
        "$version": 100000,
        "$archiver": "NSKeyedArchiver",
        "$top": {"root": plistlib.UID(1)},
        "$objects": [
            "$null",
            {
                "NSSize": size,
                "NSfFlags": 16,
                "NSName": plistlib.UID(2),
                "$class": plistlib.UID(3),
            },
            name,
            {
                "$classname": "NSFont",
                "$classes": ["NSFont", "NSObject"],
            },
        ],
    }
    return plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=True)


def build_profile(name: str = LEGACY_PROFILE_NAME, opacity: float = 0.46) -> dict[str, object]:
    colors = {
        "ANSIBlackColor": "#080E14",
        "ANSIRedColor": "#E78284",
        "ANSIGreenColor": "#A6D189",
        "ANSIYellowColor": "#E5C890",
        "ANSIBlueColor": "#8BD5FF",
        "ANSIMagentaColor": "#C4A7E7",
        "ANSICyanColor": "#83C5BE",
        "ANSIWhiteColor": "#D5D8D4",
        "ANSIBrightBlackColor": "#B9BEB9",
        "ANSIBrightRedColor": "#E78284",
        "ANSIBrightGreenColor": "#B7D6A3",
        "ANSIBrightYellowColor": "#E5C890",
        "ANSIBrightBlueColor": "#8BD5FF",
        "ANSIBrightMagentaColor": "#C4A7E7",
        "ANSIBrightCyanColor": "#8BD5FF",
        "ANSIBrightWhiteColor": "#FFFFFF",
    }
    profile: dict[str, object] = {
        "name": name,
        "type": "Window Settings",
        "ProfileCurrentVersion": 2.09,
        "BackgroundColor": archived_color("#080E14", opacity),
        "BackgroundBlur": 0.24,
        "BackgroundBlurInactive": 0.24,
        "BackgroundSettingsForInactiveWindows": False,
        "TextColor": archived_color("#F5F3ED"),
        "TextBoldColor": archived_color("#FFFFFF"),
        "CursorColor": archived_color("#B7D6A3"),
        "SelectionColor": archived_color("#29332D"),
        "Font": archived_font(),
        "FontAntialias": True,
        "FontHeightSpacing": 1.0,
        "FontWidthSpacing": 1,
        "columnCount": 120,
        "rowCount": 30,
        "useOptionAsMetaKey": True,
    }
    profile.update({key: archived_color(value) for key, value in colors.items()})
    return profile


def write_profile(output: Path, name: str, opacity: float) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as handle:
        plistlib.dump(build_profile(name, opacity), handle, fmt=plistlib.FMT_XML, sort_keys=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Herdr Dark Glass Terminal profiles")
    parser.add_argument("output", nargs="?", type=Path, help="legacy profile output path")
    parser.add_argument("--all", dest="output_dir", type=Path, metavar="OUTPUT_DIR", help="write every profile to OUTPUT_DIR")
    args = parser.parse_args()

    if args.output is not None and args.output_dir is not None:
        parser.error("OUTPUT and --all cannot be used together")
    if args.output_dir is not None:
        for name, opacity in PROFILE_OPACITIES.items():
            write_profile(args.output_dir / f"{name}.terminal", name, opacity)
        return

    write_profile(args.output or DEFAULT_OUTPUT, LEGACY_PROFILE_NAME, PROFILE_OPACITIES[LEGACY_PROFILE_NAME])


if __name__ == "__main__":
    main()
