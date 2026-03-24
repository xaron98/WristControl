#!/usr/bin/env python3
"""
Generate a 1024x1024 app icon for WristControl (Apple Watch Mac controller).
Design: dark blue/purple gradient background with a clean slider/dial icon.
"""

from PIL import Image, ImageDraw
import math

SIZE = 1024

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def draw_rounded_rect(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.ellipse([x0, y0, x0 + radius * 2, y0 + radius * 2], fill=fill)
    draw.ellipse([x1 - radius * 2, y0, x1, y0 + radius * 2], fill=fill)
    draw.ellipse([x0, y1 - radius * 2, x0 + radius * 2, y1], fill=fill)
    draw.ellipse([x1 - radius * 2, y1 - radius * 2, x1, y1], fill=fill)

def generate_icon(path, size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # --- Background: radial-ish gradient (dark navy -> deep purple) ---
    top_color    = (10,  14,  40)   # very dark navy
    mid_color    = (22,  26,  72)   # dark blue
    corner_color = (35,  18,  65)   # deep purple-navy

    # Paint background pixel-row by pixel-row for a smooth gradient
    bg = Image.new("RGB", (size, size))
    bg_draw = ImageDraw.Draw(bg)
    cx, cy = size / 2, size / 2
    max_dist = math.hypot(cx, cy)
    for y in range(size):
        for x in range(size):
            dist = math.hypot(x - cx, y - cy) / max_dist
            # blend: center -> mid_color, edges -> corner_color
            c = lerp_color(mid_color, corner_color, min(dist * 1.4, 1.0))
            bg_draw.point((x, y), fill=c)

    # Faster approach: draw horizontal bands approximating the gradient
    # (override with a proper per-pixel approach for quality)
    bg = Image.new("RGB", (size, size))
    pixels = bg.load()
    for y in range(size):
        for x in range(size):
            dx = (x - cx) / cx
            dy = (y - cy) / cy
            dist = min(math.hypot(dx, dy), 1.0)
            c = lerp_color(mid_color, corner_color, dist)
            pixels[x, y] = c

    img = bg.convert("RGBA")
    draw = ImageDraw.Draw(img)

    # --- Icon corner radius (app-icon style rounded rect clip) ---
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_r = int(size * 0.2232)   # standard Apple icon corner radius ratio
    draw_rounded_rect(mask_draw, [0, 0, size, size], corner_r, fill=255)
    img.putalpha(mask)

    draw = ImageDraw.Draw(img)

    # ---------------------------------------------------------------
    # Design: Three horizontal sliders representing volume/brightness
    # with a glowing "knob" on each — clean, modern, readable at 40px.
    # ---------------------------------------------------------------

    track_w  = int(size * 0.56)   # total track width
    track_h  = int(size * 0.065)  # track height
    track_x0 = (size - track_w) // 2
    track_r  = track_h // 2

    # Vertical positions for the three sliders
    slider_ys = [
        int(size * 0.335),
        int(size * 0.50),
        int(size * 0.665),
    ]

    # Knob fill positions (as fraction of track, left-to-right)
    knob_fracs = [0.72, 0.45, 0.82]

    # Accent colors for each slider (teal, violet, sky-blue)
    accent_colors = [
        (64,  220, 180),   # teal / mint
        (160, 110, 255),   # violet
        (80,  180, 255),   # sky blue
    ]

    # Icons above first slider: small sun symbol (brightness)
    # and speaker symbol — omit to keep it simple/iconic
    # Instead, draw small label dots to the left of each track.

    for i, (ty, frac, accent) in enumerate(zip(slider_ys, knob_fracs, accent_colors)):
        tx0 = track_x0
        tx1 = track_x0 + track_w
        ty0 = ty - track_r
        ty1 = ty + track_r

        # --- Track background ---
        track_bg = (255, 255, 255, 35)
        draw_rounded_rect(draw, [tx0, ty0, tx1, ty1], track_r, fill=(255, 255, 255, 30))

        # --- Filled portion (left side of knob) ---
        knob_cx = int(tx0 + frac * track_w)
        fill_x1 = min(knob_cx, tx1)
        if fill_x1 > tx0:
            # Glow: draw slightly wider semi-transparent stripe first
            glow_r = track_r + 2
            draw_rounded_rect(draw, [tx0 - 1, ty - glow_r, fill_x1 + 1, ty + glow_r],
                               glow_r, fill=(*accent, 60))
            draw_rounded_rect(draw, [tx0, ty0, fill_x1, ty1],
                               track_r, fill=(*accent, 230))

        # --- Knob (circle) ---
        knob_r = int(size * 0.052)
        knob_x0 = knob_cx - knob_r
        knob_y0 = ty - knob_r
        knob_x1 = knob_cx + knob_r
        knob_y1 = ty + knob_r

        # Shadow behind knob
        shadow_offset = int(size * 0.012)
        draw.ellipse(
            [knob_x0 + shadow_offset, knob_y0 + shadow_offset,
             knob_x1 + shadow_offset, knob_y1 + shadow_offset],
            fill=(0, 0, 0, 80)
        )
        # White knob with accent inner highlight
        draw.ellipse([knob_x0, knob_y0, knob_x1, knob_y1], fill=(245, 245, 255, 255))
        # Accent center dot
        dot_r = int(knob_r * 0.35)
        draw.ellipse(
            [knob_cx - dot_r, ty - dot_r, knob_cx + dot_r, ty + dot_r],
            fill=(*accent, 255)
        )

    # ---------------------------------------------------------------
    # Small icon glyphs to the LEFT of each slider:
    #   top    -> sun  (brightness)
    #   middle -> speaker (volume)
    #   bottom -> macOS logo hint (Apple-style rounded square)
    # Keep them tiny and simple so they read at small sizes.
    # ---------------------------------------------------------------
    icon_cx = track_x0 - int(size * 0.082)
    icon_r  = int(size * 0.034)

    def draw_sun(cx, cy, r, color):
        # Circle
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*color, 220))
        # Rays
        ray_len = int(r * 0.55)
        ray_w   = max(2, int(r * 0.15))
        for angle_deg in range(0, 360, 45):
            angle = math.radians(angle_deg)
            inner_x = cx + int((r + 2) * math.cos(angle))
            inner_y = cy + int((r + 2) * math.sin(angle))
            outer_x = cx + int((r + 2 + ray_len) * math.cos(angle))
            outer_y = cy + int((r + 2 + ray_len) * math.sin(angle))
            draw.line([inner_x, inner_y, outer_x, outer_y],
                      fill=(*color, 200), width=ray_w)

    def draw_speaker(cx, cy, r, color):
        # Simple speaker: rectangle body + triangle bell + arc waves
        bw = int(r * 0.6)
        bh = int(r * 0.8)
        # Body rectangle
        draw.rectangle(
            [cx - r, cy - bh // 2, cx - r + bw, cy + bh // 2],
            fill=(*color, 220)
        )
        # Triangle bell
        pts = [
            (cx - r + bw, cy - r),
            (cx + r,      cy),
            (cx - r + bw, cy + r),
        ]
        draw.polygon(pts, fill=(*color, 220))
        # Sound waves (arcs approximated with lines)
        for wave_r in [int(r * 1.1), int(r * 1.5)]:
            draw.arc(
                [cx + r - wave_r, cy - wave_r, cx + r + wave_r, cy + wave_r],
                start=-50, end=50,
                fill=(*color, 180), width=max(2, int(r * 0.13))
            )

    # Draw sun above first slider
    draw_sun(icon_cx, slider_ys[0], icon_r, accent_colors[0])
    # Draw speaker above second slider
    draw_speaker(icon_cx, slider_ys[1], icon_r, accent_colors[1])
    # Draw a small watch icon (rounded rect with crown) for third
    ww = int(icon_r * 1.2)
    wh = int(icon_r * 1.5)
    ac = accent_colors[2]
    draw_rounded_rect(draw,
        [icon_cx - ww, slider_ys[2] - wh,
         icon_cx + ww, slider_ys[2] + wh],
        int(ww * 0.4),
        fill=(*ac, 210)
    )
    # Crown nub
    crown_w = int(ww * 0.3)
    crown_h = int(wh * 0.35)
    draw.rectangle(
        [icon_cx + ww, slider_ys[2] - crown_h // 2,
         icon_cx + ww + crown_w, slider_ys[2] + crown_h // 2],
        fill=(*ac, 210)
    )
    # Small screen area inside watch
    sw = int(ww * 0.65)
    sh = int(wh * 0.55)
    draw.rectangle(
        [icon_cx - sw, slider_ys[2] - sh,
         icon_cx + sw, slider_ys[2] + sh],
        fill=(20, 24, 60, 230)
    )

    # ---------------------------------------------------------------
    # Subtle top highlight (gloss / lens flare)
    # ---------------------------------------------------------------
    gloss = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gloss_draw = ImageDraw.Draw(gloss)
    gloss_draw.ellipse(
        [int(size * 0.15), int(size * 0.04),
         int(size * 0.85), int(size * 0.45)],
        fill=(255, 255, 255, 18)
    )
    img = Image.alpha_composite(img, gloss)

    # Save as PNG with alpha
    img.save(path, "PNG")
    print(f"Saved icon: {path}  ({size}x{size})")

if __name__ == "__main__":
    generate_icon("/Users/xaron/Desktop/CMac/AppIcon.png", SIZE)
