#!/usr/bin/env python3
"""
Distribute the 1024x1024 AppIcon.png to all three asset catalogs
and write the correct Contents.json for each platform.
"""

import json
import shutil
from pathlib import Path

BASE = Path("/Users/xaron/Desktop/CMac")
SOURCE = BASE / "AppIcon.png"

TARGETS = [
    {
        "dir": BASE / "WristControlWatch" / "Assets.xcassets" / "AppIcon.appiconset",
        "platform": "watchos",
    },
    {
        "dir": BASE / "WristControlPhone" / "Assets.xcassets" / "AppIcon.appiconset",
        "platform": "ios",
    },
    {
        "dir": BASE / "WristControlMac" / "Assets.xcassets" / "AppIcon.appiconset",
        "platform": "macos",
    },
]

def contents_json(platform: str) -> dict:
    return {
        "images": [
            {
                "filename": "AppIcon.png",
                "idiom": "universal",
                "platform": platform,
                "size": "1024x1024",
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }

def main():
    assert SOURCE.exists(), f"Source icon not found: {SOURCE}"

    for target in TARGETS:
        dest_dir = target["dir"]
        platform = target["platform"]

        dest_dir.mkdir(parents=True, exist_ok=True)

        # Copy icon
        dest_icon = dest_dir / "AppIcon.png"
        shutil.copy2(SOURCE, dest_icon)
        print(f"Copied -> {dest_icon}")

        # Write Contents.json
        dest_json = dest_dir / "Contents.json"
        dest_json.write_text(
            json.dumps(contents_json(platform), indent=2) + "\n"
        )
        print(f"Wrote  -> {dest_json}")

    print("\nDone. All three asset catalogs updated.")

if __name__ == "__main__":
    main()
