#!/usr/bin/env python3
"""Feature slides (4:5) for the README and social posts.

Raw screens come from `mobile/test/showcase_generator_test.dart`
(SHOWCASE_OUT=... SHOWCASE_STYLES=express). Usage:
    python3 tools/screenshots/feature_slides.py RAW_DIR OUT_DIR ArefRuqaa-Bold.ttf
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAW = sys.argv[1]; OUT = sys.argv[2]; RUQAA = sys.argv[3]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, 'mobile', 'fonts')
ICON = os.path.join(ROOT, 'mobile', 'assets', 'icon.png')
S = 1.5
W, H = int(1080 * S), int(1350 * S)
TERRA = (0x94, 0x49, 0x2F); SAND = (0xF4, 0xEC, 0xE2); INK = (0x2B, 0x26, 0x22)
MUTED = (0x6E, 0x63, 0x5B); NIGHT = (0x1B, 0x18, 0x16); CREAM = (0xF1, 0xE9, 0xDE)

def f(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), int(size * S), layout_engine=ImageFont.Layout.RAQM)

def phone(name, h, dark=False):
    scr = Image.open(os.path.join(RAW, name)).convert('RGB')
    h = int(h * S); w = int(h * scr.width / scr.height)
    scr = scr.resize((w, h), Image.LANCZOS)
    bz = max(8, h // 62); r = h // 15
    body = Image.new('RGBA', (w + 2 * bz, h + 2 * bz), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, body.width - 1, body.height - 1], radius=r + bz,
                                           fill=(74, 66, 60, 255) if dark else (24, 22, 20, 255))
    m = Image.new('L', scr.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    body.paste(scr, (bz, bz), m)
    pad = int(60 * S)
    out = Image.new('RGBA', (body.width + 2 * pad, body.height + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle([pad, pad + int(18 * S), pad + body.width, pad + body.height + int(18 * S)],
                                          radius=r + bz, fill=(0, 0, 0, 120 if dark else 60))
    out = out.filter(ImageFilter.GaussianBlur(int(26 * S)))
    out.alpha_composite(body, (pad, pad))
    return out

def wrap(d, text, fnt, width):
    words = text.split(' '); lines = []; cur = ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=fnt) <= width: cur = t
        else: lines.append(cur); cur = w
    lines.append(cur); return lines

def callout(name, box, width):
    c = Image.open(os.path.join(RAW, name)).convert('RGB').crop(box)
    w = int(width * S); h = int(w * c.height / c.width)
    c = c.resize((w, h), Image.LANCZOS)
    r = int(28 * S); b = int(5 * S); pad = int(50 * S)
    card = Image.new('RGBA', (w + 2 * b, h + 2 * b), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle([0, 0, card.width - 1, card.height - 1], radius=r + b, fill=TERRA + (255,))
    m = Image.new('L', c.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    card.paste(c, (b, b), m)
    out = Image.new('RGBA', (card.width + 2 * pad, card.height + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle([pad, pad + int(16 * S), pad + card.width, pad + card.height + int(16 * S)], radius=r, fill=(0, 0, 0, 90))
    out = out.filter(ImageFilter.GaussianBlur(int(22 * S)))
    out.alpha_composite(card, (pad, pad))
    return out

def slide(n, kicker, title, sub, phones, dark=False, rotate=None, zoom=None):
    bg = NIGHT if dark else SAND; ink = CREAM if dark else INK; mut = (0xB5, 0xA9, 0x9C) if dark else MUTED
    img = Image.new('RGBA', (W, H), bg + (255,)); d = ImageDraw.Draw(img)
    # soft terracotta glow behind phones
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W * 0.1, H * 0.45, W * 0.9, H * 1.15], fill=TERRA + (70 if dark else 45,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(int(120 * S))))
    d = ImageDraw.Draw(img)
    m = int(72 * S)
    logo = Image.open(ICON).convert('RGBA').resize((int(56 * S), int(56 * S)), Image.LANCZOS)
    img.alpha_composite(logo, (m, m))
    d.text((m + int(72 * S), m + int(12 * S)), 'Khuta', font=f('Figtree-Bold.ttf', 30), fill=ink)
    d.text((W - m, m + int(16 * S)), f'{n:02d}', font=f('Figtree-SemiBold.ttf', 26), fill=mut, anchor='ra')
    y = m + int(110 * S)
    d.text((m, y), kicker.upper(), font=f('Figtree-Bold.ttf', 24), fill=TERRA if not dark else (0xE0, 0x9A, 0x7E)); y += int(48 * S)
    tf = f('Figtree-Bold.ttf', 64)
    for line in wrap(d, title, tf, W - 2 * m):
        d.text((m, y), line, font=tf, fill=ink); y += int(74 * S)
    y += int(10 * S)
    sf = f('Figtree-Regular.ttf', 30)
    for line in wrap(d, sub, sf, W - 2 * m):
        d.text((m, y), line, font=sf, fill=mut); y += int(42 * S)
    top = y + int(20 * S)
    avail = H - top - int(20 * S)
    ph = [phone(p, min(900, avail / S - 150), dark) for p in phones]
    if len(ph) == 1 and zoom:
        p = ph[0]; px = int(W * 0.06); img.alpha_composite(p, (px, top))
        z = callout(*zoom); img.alpha_composite(z, (W - z.width + int(10 * S), top + int(p.height * 0.32)))
    elif len(ph) == 1:
        p = ph[0]; img.alpha_composite(p, ((W - p.width) // 2, top))
    else:
        gap = int(-40 * S)
        total = sum(p.width for p in ph) + gap * (len(ph) - 1)
        x = (W - total) // 2
        for i, p in enumerate(ph):
            off = int((40 if i % 2 else 0) * S)
            img.alpha_composite(p, (x, top + off)); x += p.width + gap
    img.convert('RGB').save(os.path.join(OUT, f'{n:02d}.png'), optimize=True)
    return os.path.join(OUT, f'{n:02d}.png')

def cover():
    img = Image.new('RGBA', (W, H), NIGHT + (255,))
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([-W * 0.2, H * 0.35, W * 1.2, H * 1.3], fill=TERRA + (110,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(int(160 * S))))
    d = ImageDraw.Draw(img)
    logo = Image.open(ICON).convert('RGBA').resize((int(150 * S), int(150 * S)), Image.LANCZOS)
    img.alpha_composite(logo, ((W - logo.width) // 2, int(90 * S)))
    def c(y, t, fnt, fill):
        d.text((W / 2, y), t, font=fnt, fill=fill, anchor='ma')
    lat = f('Figtree-Bold.ttf', 76); ar = ImageFont.truetype(RUQAA, int(84 * S), layout_engine=ImageFont.Layout.RAQM)
    a, sep = 'Khuta', '  ·  '
    wa = d.textlength(a, font=lat); ws = d.textlength(sep, font=lat)
    b = d.textbbox((0, 0), 'خُطى', font=ar, direction='rtl', language='ar'); wb = b[2] - b[0]
    x0 = (W - (wa + ws + wb)) / 2; y0 = int(270 * S)
    d.text((x0, y0), a + sep, font=lat, fill=CREAM)
    d.text((x0 + wa + ws - b[0], y0 - int(14 * S)), 'خُطى', font=ar, fill=CREAM, direction='rtl', language='ar')
    c(int(370 * S), 'Small steps, every day.', f('Figtree-SemiBold.ttf', 40), (0xE0, 0x9A, 0x7E))
    c(int(430 * S), 'A private, Arabic-first habit tracker. Open source.', f('Figtree-Regular.ttf', 30), (0xB5, 0xA9, 0x9C))
    ph = [phone('en_express_light_2_details.png', 620), phone('en_express_dark_1_today.png', 700, True),
          phone('en_express_dark_4_island.png', 620, True)]
    top = int(520 * S)
    widths = [p.width for p in ph]
    xc = W // 2
    img.alpha_composite(ph[0], (xc - widths[1] // 2 - ph[0].width + int(150 * S), top + int(60 * S)))
    img.alpha_composite(ph[2], (xc + widths[1] // 2 - int(150 * S), top + int(60 * S)))
    img.alpha_composite(ph[1], (xc - widths[1] // 2, top))
    img.convert('RGB').save(os.path.join(OUT, '01.png'), optimize=True)

def closing(n):
    img = Image.new('RGBA', (W, H), NIGHT + (255,))
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W * 0.05, H * 0.05, W * 0.95, H * 0.8], fill=TERRA + (80,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(int(160 * S))))
    d = ImageDraw.Draw(img)
    m = int(90 * S)
    d.text((W / 2, int(120 * S)), 'PRIVATE BY DESIGN', font=f('Figtree-Bold.ttf', 26), fill=(0xE0, 0x9A, 0x7E), anchor='ma')
    d.text((W / 2, int(175 * S)), 'Your habits stay yours.', font=f('Figtree-Bold.ttf', 64), fill=CREAM, anchor='ma')
    items = [('No account', 'Nothing to sign up for.'), ('No ads, no tracking', 'Zero analytics, zero trackers.'),
             ('No Internet permission', 'The app cannot send your data anywhere.'),
             ('Backups you own', 'One file with all your data and photos.'),
             ('Open source', 'GPL-3.0. Read every line on GitHub.')]
    y = int(320 * S)
    for t, s in items:
        d.rounded_rectangle([m, y, W - m, y + int(118 * S)], radius=int(26 * S), fill=(0x2B, 0x26, 0x22))
        d.ellipse([m + int(30 * S), y + int(38 * S), m + int(72 * S), y + int(80 * S)], fill=TERRA)
        cx, cy = m + int(51 * S), y + int(59 * S)
        d.line([(cx - int(9 * S), cy), (cx - int(2 * S), cy + int(8 * S)), (cx + int(11 * S), cy - int(8 * S))], fill=CREAM, width=int(5 * S), joint='curve')
        d.text((m + int(100 * S), y + int(24 * S)), t, font=f('Figtree-Bold.ttf', 34), fill=CREAM)
        d.text((m + int(100 * S), y + int(68 * S)), s, font=f('Figtree-Regular.ttf', 26), fill=(0xB5, 0xA9, 0x9C))
        y += int(138 * S)
    y += int(40 * S)
    logo = Image.open(ICON).convert('RGBA').resize((int(96 * S), int(96 * S)), Image.LANCZOS)
    img.alpha_composite(logo, ((W - logo.width) // 2, y)); y += int(120 * S)
    d.text((W / 2, y), 'Free on GitHub · Android 9+', font=f('Figtree-SemiBold.ttf', 32), fill=CREAM, anchor='ma'); y += int(52 * S)
    d.text((W / 2, y), 'github.com/AyoubDroubi/khuta.app', font=f('Figtree-Bold.ttf', 36), fill=(0xE0, 0x9A, 0x7E), anchor='ma')
    img.convert('RGB').save(os.path.join(OUT, f'{n:02d}.png'), optimize=True)

os.makedirs(OUT, exist_ok=True)
cover()
slide(2, 'Minimum habit', 'A minimum that still counts.',
      'Hard day? Do the minimum and the day is done, your streak lives. The full goal stays in sight.',
      ['en_express_light_2_details.png'], zoom=('en_express_light_2_details.png', (40, 520, 1040, 1175), 560))
slide(3, 'Recovery', 'Fell off? Restart, no guilt.',
      'After a break, Khuta shows the habits to restart and sends a few gentle reminders. Never a wall of red.',
      ['en_express_light_1_today.png'], zoom=('en_express_light_1_today.png', (40, 1380, 1040, 1870), 600))
slide(4, 'Hijri calendar', 'Built around the Hijri calendar.',
      'Schedule habits by Hijri months, like every day in Ramadan, with Umm al-Qura dates and adjustment.',
      ['en_express_light_7_hijri_form.png', 'ar_express_dark_7_hijri_form.png'], dark=False)
slide(5, 'Insights', 'See your progress at a glance.',
      'Streaks, consistency, an activity grid and daily amounts for every habit.',
      ['en_express_dark_3_stats.png', 'en_express_dark_5_habit.png'], dark=True)
slide(6, 'The oasis', 'An oasis that grows with you.',
      'Every check-in earns points to build your own island: palms, mud-brick houses, a mosque and windcatchers.',
      ['en_express_dark_4_island.png'], dark=True)
slide(7, 'Focus', 'Deep focus, tied to your habits.',
      'Pomodoro or one long session, with ambient sound, counted toward the habit you are working on.',
      ['en_express_dark_8_focus.png'], dark=True)
slide(8, 'Arabic-first', 'Truly Arabic-first. 16 languages.',
      'A complete right-to-left interface, three styles, light and dark themes.',
      ['ar_express_light_1_today.png', 'en_express_dark_1_today.png'])
closing(9)
print('ok')
