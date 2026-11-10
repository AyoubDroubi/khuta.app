#!/usr/bin/env python3
"""Compose showcase images (README, portfolio) from raw app screenshots.

Raw screenshots come from `mobile/test/showcase_generator_test.dart`
(SHOWCASE_OUT=...). Usage:
    python3 tools/screenshots/compose.py RAW_DIR OUT_DIR --ruqaa ArefRuqaa-Bold.ttf
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, "mobile", "fonts")
TERRACOTTA = (0x94, 0x49, 0x2F)
SAND = (0xF1, 0xE9, 0xDE)
CHARCOAL = (0x2B, 0x26, 0x22)
MUTED = (0x6E, 0x63, 0x5B)
NIGHT = (0x1B, 0x18, 0x16)
# Page colours per theme: background, text, secondary text.
PAGE = {"light": (SAND, CHARCOAL, MUTED), "dark": (NIGHT, SAND, (0xB5, 0xA9, 0x9C))}

CAPTIONS = {
    "ar": {
        "1_today": "يومك في نظرة",
        "2_details": "حدّ أدنى يكمل يومك",
        "3_stats": "تقدّمك بالأرقام",
        "4_island": "واحة تكبر مع كل خطوة",
        "5_habit": "سلاسل وتاريخ كامل",
        "6_about": "خاص، بلا حسابات ولا إعلانات",
        "tagline": "خطوات صغيرة، كل يوم.",
        "sub": "متتبّع عادات خاص، عربي أولاً، يعمل بلا إنترنت.",
    },
    "en": {
        "1_today": "Your day at a glance",
        "2_details": "A minimum that counts",
        "3_stats": "Progress in numbers",
        "4_island": "An oasis that grows",
        "5_habit": "Streaks and full history",
        "6_about": "Private: no accounts, no ads",
        "tagline": "Small steps, every day.",
        "sub": "A private, Arabic-first habit tracker that works offline.",
    },
}


def font(name, size):
    return ImageFont.truetype(name if os.path.isabs(name) else os.path.join(FONTS, name), size,
                              layout_engine=ImageFont.Layout.RAQM)


def phone(shot, height, theme="light"):
    """The screenshot inside a simple rounded phone body with a soft shadow."""
    scr = Image.open(shot).convert("RGB")
    w = int(height * scr.width / scr.height)
    scr = scr.resize((w, height), Image.LANCZOS)
    bezel = max(10, height // 60)
    radius = height // 16
    body = Image.new("RGBA", (w + 2 * bezel, height + 2 * bezel), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, body.width - 1, body.height - 1], radius=radius + bezel, fill=(24, 22, 20, 255) if theme == "light" else (74, 66, 60, 255))
    mask = Image.new("L", scr.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, height - 1], radius=radius, fill=255)
    body.paste(scr, (bezel, bezel), mask)
    shadow = Image.new("RGBA", (body.width + 80, body.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 52, 40 + body.width, 52 + body.height],
                                             radius=radius + bezel, fill=(60, 30, 20, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    shadow.alpha_composite(body, (40, 40))
    return shadow


def text_center(draw, cx, y, text, fnt, fill, rtl):
    kw = {"direction": "rtl", "language": "ar"} if rtl else {}
    b = draw.textbbox((0, 0), text, font=fnt, **kw)
    draw.text((cx - (b[2] - b[0]) / 2 - b[0], y - b[1]), text, font=fnt, fill=fill, **kw)
    return b[3] - b[1]


def hero(raw, out, lang, ruqaa, icon, style="express", theme="light"):
    rtl = lang == "ar"
    cap = CAPTIONS[lang]
    bg, ink, muted = PAGE[theme]
    W, H = 2800, 1660
    img = Image.new("RGBA", (W, H), bg + (255,))
    d = ImageDraw.Draw(img)
    # Brand block: the logo is the word خُطى, so no separate title.
    logo = Image.open(icon).convert("RGBA").resize((210, 210), Image.LANCZOS)
    img.alpha_composite(logo, (W // 2 - 105, 50))
    body = font("IBMPlexSansArabic-SemiBold.ttf" if rtl else "Figtree-SemiBold.ttf", 54)
    text_center(d, W // 2, 300, cap["tagline"], body, ink, rtl)
    small = font("IBMPlexSansArabic-Regular.ttf" if rtl else "Figtree-Regular.ttf", 36)
    text_center(d, W // 2, 380, cap["sub"], small, muted, rtl)
    # Four phones, read in the language direction.
    keys = ["1_today", "2_details", "3_stats", "4_island"]
    if rtl:
        keys = keys[::-1]
    ph = 1000
    phones = [phone(os.path.join(raw, f"{lang}_{style}_{theme}_{k}.png"), ph, theme) for k in keys]
    gap = 10
    total = sum(p.width for p in phones) + gap * (len(phones) - 1)
    x = (W - total) // 2
    top = 430
    capf = font("IBMPlexSansArabic-Medium.ttf" if rtl else "Figtree-Medium.ttf", 38)
    for k, p in zip(keys, phones):
        img.alpha_composite(p, (x, top))
        text_center(d, x + p.width // 2, top + p.height - 10, cap[k], capf, ink, rtl)
        x += p.width + gap
    suffix = "" if theme == "light" else "_dark"
    img.convert("RGB").save(os.path.join(out, f"showcase_{lang}{suffix}.png"), optimize=True)


def single(raw, out, lang, key, style="express", theme="light"):
    rtl = lang == "ar"
    bg, ink, _ = PAGE[theme]
    W, H = 1200, 1700
    img = Image.new("RGBA", (W, H), bg + (255,))
    d = ImageDraw.Draw(img)
    capf = font("IBMPlexSansArabic-SemiBold.ttf" if rtl else "Figtree-SemiBold.ttf", 56)
    text_center(d, W // 2, 90, CAPTIONS[lang][key], capf, ink, rtl)
    p = phone(os.path.join(raw, f"{lang}_{style}_{theme}_{key}.png"), 1380, theme)
    img.alpha_composite(p, ((W - p.width) // 2, 200))
    img.convert("RGB").save(os.path.join(out, f"{lang}_{theme}_{key}.png"), optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("out")
    ap.add_argument("--ruqaa", required=True)
    ap.add_argument("--style", default="express")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    icon = os.path.join(ROOT, "mobile", "assets", "icon.png")
    for lang in ("ar", "en"):
        for theme in ("light", "dark"):
            hero(args.raw, args.out, lang, args.ruqaa, icon, args.style, theme)
        for key in CAPTIONS[lang]:
            if key[0].isdigit():
                for theme in ("light", "dark"):
                    single(args.raw, args.out, lang, key, args.style, theme)
    print("showcase written to", args.out)


if __name__ == "__main__":
    main()
