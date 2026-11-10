#!/usr/bin/env python3
"""Generate the Khuta (خُطى) brand assets.

The mark is the word خُطى written in Aref Ruqaa (SIL OFL 1.1), white on the
terracotta of the palette chosen in D-014-11 ("فخّار هادئ"). Raster images are
drawn with Pillow (raqm shaping); the vector files (assets/icon.svg and the
Android notification icon) use the same shaped glyph outlines (HarfBuzz +
fontTools), so every size shows the same letters.

Usage (from the `mobile/` folder):
    python3 tool/generate_brand_assets.py --ruqaa /path/to/ArefRuqaa-Bold.ttf

The font itself is not bundled in the app. Requires Pillow with raqm,
uharfbuzz and fontTools.
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFont

TERRACOTTA = (0x94, 0x49, 0x2F)
SAND = (0xF1, 0xE9, 0xDE)
SAND_DEEP = (0xE6, 0xD8, 0xC6)
CHARCOAL = (0x2B, 0x26, 0x22)
WHITE = (0xFF, 0xFF, 0xFF)

WORD = "خُطى"
SS = 4  # supersampling factor
# Share of the image the word may fill (width, height).
ICON_BOX = (0.64, 0.56)
ADAPTIVE_BOX = (0.50, 0.44)  # adaptive icons are masked to the inner ~66%


def _fit_font(ruqaa, draw, box_w, box_h):
    lo, hi = 8, int(max(box_w, box_h) * 2)
    while hi - lo > 1:
        mid = (lo + hi) // 2
        font = ImageFont.truetype(ruqaa, mid, layout_engine=ImageFont.Layout.RAQM)
        x0, y0, x1, y1 = draw.textbbox((0, 0), WORD, font=font, direction="rtl", language="ar")
        if x1 - x0 <= box_w and y1 - y0 <= box_h:
            lo = mid
        else:
            hi = mid
    return ImageFont.truetype(ruqaa, lo, layout_engine=ImageFont.Layout.RAQM)


def word_layer(size, ruqaa, colour, box=ICON_BOX):
    """Transparent RGBA image with خُطى centred, drawn supersampled."""
    big = size * SS
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    font = _fit_font(ruqaa, draw, big * box[0], big * box[1])
    x0, y0, x1, y1 = draw.textbbox((0, 0), WORD, font=font, direction="rtl", language="ar")
    pos = ((big - (x1 - x0)) / 2 - x0, (big - (y1 - y0)) / 2 - y0)
    draw.text(pos, WORD, font=font, fill=colour + (255,), direction="rtl", language="ar")
    return layer.resize((size, size), Image.LANCZOS)


def full_icon(size, ruqaa, bg=TERRACOTTA, fg=WHITE, radius=230):
    big = size * SS
    base = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(base).rounded_rectangle(
        [0, 0, big - 1, big - 1], radius=radius * big / 1024, fill=bg + (255,)
    )
    base = base.resize((size, size), Image.LANCZOS)
    base.alpha_composite(word_layer(size, ruqaa, fg))
    return base


def word_path(ruqaa, box_size, box=ICON_BOX):
    """SVG path data of خُطى, centred in a box_size square (y down)."""
    import uharfbuzz as hb
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont

    data = open(ruqaa, "rb").read()
    face = hb.Face(data)
    font = hb.Font(face)
    buf = hb.Buffer()
    buf.add_str(WORD)
    buf.guess_segment_properties()
    hb.shape(font, buf, {})
    tt = TTFont(ruqaa)
    glyphs = tt.getGlyphSet()
    order = tt.getGlyphOrder()

    placed = []
    x = 0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        placed.append((order[info.codepoint], x + pos.x_offset, pos.y_offset))
        x += pos.x_advance

    bounds = BoundsPen(glyphs)
    for name, gx, gy in placed:
        glyphs[name].draw(TransformPen(bounds, (1, 0, 0, 1, gx, gy)))
    xmin, ymin, xmax, ymax = bounds.bounds
    w, h = xmax - xmin, ymax - ymin
    scale = min(box_size * box[0] / w, box_size * box[1] / h)
    ox = (box_size - w * scale) / 2 - xmin * scale
    oy = (box_size + h * scale) / 2 + ymin * scale  # font y up -> svg y down

    pen = SVGPathPen(glyphs, ntos=lambda v: f"{v:.2f}".rstrip("0").rstrip("."))
    for name, gx, gy in placed:
        t = (scale, 0, 0, -scale, ox + gx * scale, oy - gy * scale)
        glyphs[name].draw(TransformPen(pen, t))
    return pen.getCommands()


def svg_icon(ruqaa):
    return (
        '<svg width="1024" height="1024" viewBox="0 0 1024 1024" fill="none" '
        'xmlns="http://www.w3.org/2000/svg">\n'
        "  <!-- Khuta: the word خُطى in Aref Ruqaa (SIL OFL 1.1). -->\n"
        '  <rect width="1024" height="1024" rx="230" fill="#94492F"/>\n'
        f'  <path fill="#FFFFFF" d="{word_path(ruqaa, 1024)}"/>\n'
        "</svg>\n"
    )


def notify_vector(ruqaa):
    path = word_path(ruqaa, 24, box=(0.86, 0.80))
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Khuta notification icon: the word خُطى (Aref Ruqaa, SIL OFL 1.1). -->\n"
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="24dp"\n'
        '    android:height="24dp"\n'
        '    android:viewportWidth="24"\n'
        '    android:viewportHeight="24">\n'
        f'    <path android:fillColor="#FFFFFFFF" android:pathData="{path}" />\n'
        "</vector>\n"
    )


def wordmark_card(width, height, ruqaa, latin_font, bg=SAND, fg=TERRACOTTA):
    """Icon tile on the right (Arabic reading order), “Khuta” and tagline left."""
    card = Image.new("RGB", (width, height), bg)
    draw = ImageDraw.Draw(card)
    tile = int(height * 0.52)
    mark = full_icon(tile, ruqaa)
    latin = ImageFont.truetype(latin_font, int(height * 0.17))
    tag = ImageFont.truetype(latin_font, int(height * 0.055))
    tagline = "Small steps, every day."
    lb = draw.textbbox((0, 0), "Khuta", font=latin)
    tb = draw.textbbox((0, 0), tagline, font=tag)
    text_w = max(lb[2] - lb[0], tb[2] - tb[0])
    gap = int(height * 0.09)
    x0 = (width - (text_w + gap + tile)) // 2
    cy = height // 2
    card.paste(mark, (x0 + text_w + gap, cy - tile // 2), mark)
    lh = lb[3] - lb[1]
    draw.text((x0 - lb[0], cy - lh + int(height * 0.01) - lb[1]), "Khuta", font=latin, fill=fg)
    draw.text((x0 - tb[0], cy + int(height * 0.07) - tb[1]), tagline, font=tag, fill=CHARCOAL)
    return card


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ruqaa", required=True, help="ArefRuqaa-Bold.ttf")
    parser.add_argument("--latin", default="fonts/Figtree-SemiBold.ttf")
    args = parser.parse_args()
    ruqaa = args.ruqaa

    res = "android/app/src/main/res"
    os.makedirs("assets", exist_ok=True)

    full_icon(1024, ruqaa).save("assets/icon.png")
    word_layer(1024, ruqaa, WHITE, ADAPTIVE_BOX).save("assets/icon_foreground.png")
    with open("assets/icon.svg", "w", encoding="utf-8") as f:
        f.write(svg_icon(ruqaa))
    with open(f"{res}/drawable/ic_stat_notify.xml", "w", encoding="utf-8") as f:
        f.write(notify_vector(ruqaa))

    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for density, size in legacy.items():
        full_icon(size, ruqaa).save(f"{res}/mipmap-{density}/ic_launcher.png")
    for density, size in adaptive.items():
        for folder in (f"{res}/mipmap-{density}", f"{res}/drawable-{density}"):
            if not os.path.isdir(folder):
                continue
            word_layer(size, ruqaa, WHITE, ADAPTIVE_BOX).save(f"{folder}/ic_launcher_foreground.png")
            word_layer(size, ruqaa, WHITE, ADAPTIVE_BOX).save(f"{folder}/ic_launcher_monochrome.png")
            if folder.startswith(f"{res}/mipmap-"):
                # Alternate icons: neutral (sand on charcoal) and accent
                # (terracotta on sand); file names are kept for the XML.
                word_layer(size, ruqaa, SAND_DEEP, ADAPTIVE_BOX).save(f"{folder}/ic_launcher_fg_green.png")
                word_layer(size, ruqaa, TERRACOTTA, ADAPTIVE_BOX).save(f"{folder}/ic_launcher_fg_tri.png")
                Image.new("RGB", (size, size), TERRACOTTA).save(f"{folder}/ic_launcher_background.png")

    wordmark_card(2400, 800, ruqaa, args.latin).save("assets/banner.png")
    wordmark_card(1280, 640, ruqaa, args.latin).save("assets/social-preview.png")
    print("brand assets written")


if __name__ == "__main__":
    main()
