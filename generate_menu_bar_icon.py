#!/usr/bin/env python3
"""
Generate a macOS menu bar template icon for WristControl.
The icon depicts three horizontal sliders — matching "slider.horizontal.3" —
as a pure white-on-transparent template image so macOS can tint it for
light/dark mode automatically.
"""

from PIL import Image, ImageDraw
import os

def draw_sliders(size):
    """
    Draw three horizontal slider lines with a small circular thumb on each.
    Returns an RGBA Image with white shapes on a transparent background.
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    color = (255, 255, 255, 255)

    # Layout: divide height into 3 equal bands
    padding = size * 0.12          # outer top/bottom padding
    band = (size - 2 * padding) / 3

    line_h = max(1, round(size * 0.07))   # line stroke thickness
    thumb_r = size * 0.12                 # thumb circle radius

    # Thumb positions (x-centre as fraction of width) for each row
    thumb_positions = [0.65, 0.35, 0.55]

    for i, thumb_x_frac in enumerate(thumb_positions):
        cy = padding + band * i + band / 2  # vertical centre of this row

        # Full-width track line
        y0 = cy - line_h / 2
        y1 = cy + line_h / 2
        draw.rectangle(
            [round(size * 0.05), round(y0), round(size * 0.95), round(y1)],
            fill=color,
        )

        # Thumb circle — draw a filled circle with a "hole" to make it look
        # like a ring/knob so the track is visible through it.
        tx = round(size * thumb_x_frac)
        ty = round(cy)
        r_outer = round(thumb_r)
        r_inner = max(1, round(thumb_r * 0.45))

        # Outer filled circle (white)
        draw.ellipse(
            [tx - r_outer, ty - r_outer, tx + r_outer, ty + r_outer],
            fill=color,
        )
        # Inner cut-out (transparent) to create ring effect
        draw.ellipse(
            [tx - r_inner, ty - r_inner, tx + r_inner, ty + r_inner],
            fill=(0, 0, 0, 0),
        )

    return img


def main():
    out_dir = "/Users/xaron/Desktop/CMac/WristControlMac/Assets.xcassets/MenuBarIcon.imageset"
    os.makedirs(out_dir, exist_ok=True)

    # 1x  — 22 px
    img_1x = draw_sliders(22)
    img_1x.save(os.path.join(out_dir, "MenuBarIcon.png"))
    print("Saved MenuBarIcon.png (22x22)")

    # 2x  — 44 px
    img_2x = draw_sliders(44)
    img_2x.save(os.path.join(out_dir, "MenuBarIcon@2x.png"))
    print("Saved MenuBarIcon@2x.png (44x44)")


if __name__ == "__main__":
    main()
