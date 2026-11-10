"""Terrain tiles: 7 kinds x 4 variants, 144x223 (water 144x111)."""
from __future__ import annotations

import random

from PIL import Image, ImageDraw

import palette as P
from iso import SS, shade, mix

W = 144
TOP_H = 72

KINDS = {
    # kind: (top base, top accent, wall top, wall bottom, height)
    'grass':   (P.PALM_LIGHT, P.PALM, P.MUD, shade(P.MUD, 0.62), 223),
    'thicket': (P.PALM, P.PALM_DARK, P.MUD, shade(P.MUD, 0.62), 223),
    'rock':    (P.STONE_DARK, P.STONE, P.STONE_DARK, shade(P.STONE_DARK, 0.62), 223),
    'path':    (P.SAND_LIGHT, P.SAND, P.MUD_LIGHT, shade(P.MUD_LIGHT, 0.62), 223),
    'stone':   (P.PLASTER, P.STONE, P.STONE, shade(P.STONE, 0.66), 223),
    'sand':    (P.SAND, P.SAND_LIGHT, P.SAND_DARK, shade(P.SAND_DARK, 0.6), 223),
    'water':   (P.WATER, P.TURQUOISE, P.WATER_DEEP, shade(P.WATER_DEEP, 0.7), 111),
}


def _top_texture(kind, base, accent, variant):
    rng = random.Random(f'{kind}-{variant}')
    S = SS
    tex = Image.new('RGB', (W * S, TOP_H * S), base)
    d = ImageDraw.Draw(tex)
    block = 6 * S
    # soft mottling in blocks
    for y in range(0, TOP_H * S, block):
        for x in range(0, W * S, block):
            f = 0.93 + rng.random() * 0.14
            d.rectangle([x, y, x + block, y + block], fill=shade(base, f))
    if kind in ('grass', 'thicket'):
        for _ in range(170):
            x, y = rng.randrange(W * S), rng.randrange(TOP_H * S)
            c = mix(base, accent, rng.random())
            d.rectangle([x, y, x + 2 * S, y + 3 * S], fill=c)
        if kind == 'thicket':
            for _ in range(10):  # small palm crowns seen from above
                x, y = rng.randrange(20 * S, 124 * S), rng.randrange(14 * S, 58 * S)
                d.ellipse([x - 5 * S, y - 3 * S, x + 5 * S, y + 3 * S], fill=P.PALM_LIGHT)
    elif kind == 'sand':
        for i in range(7):  # dune ripples
            y = (10 + i * 9 + rng.randrange(-2, 3)) * S
            d.line([(0, y), (W * S, y + rng.randrange(-3, 4) * S)], fill=shade(base, 0.9), width=S)
        for _ in range(60):
            x, y = rng.randrange(W * S), rng.randrange(TOP_H * S)
            d.rectangle([x, y, x + S, y + S], fill=accent)
    elif kind == 'path':
        for row in range(0, 7):
            for col in range(0, 12):
                x = (col * 14 + (row % 2) * 7 - 7) * S
                y = row * 11 * S
                c = shade(base, 0.9 + rng.random() * 0.16)
                d.rectangle([x + S, y + S, x + 13 * S, y + 10 * S], fill=c)
    elif kind == 'stone':
        for k in range(1, 4):
            d.line([(0, k * 18 * S), (W * S, k * 18 * S)], fill=shade(base, 0.82), width=S)
            d.line([(k * 36 * S, 0), (k * 36 * S, TOP_H * S)], fill=shade(base, 0.82), width=S)
    elif kind == 'rock':
        for _ in range(26):
            x, y = rng.randrange(W * S), rng.randrange(TOP_H * S)
            d.polygon([(x, y), (x + 9 * S, y + 2 * S), (x + 5 * S, y + 7 * S)], fill=shade(base, 0.8 + rng.random() * 0.4))
    elif kind == 'water':
        for _ in range(34):
            x, y = rng.randrange(W * S), rng.randrange(TOP_H * S)
            d.line([(x, y), (x + rng.randrange(6, 16) * S, y)], fill=mix(base, P.WHITE, 0.5), width=S)
    return tex


def make_tile(kind: str, variant: int) -> Image.Image:
    base, accent, wall_top, wall_bot, height = KINDS[kind]
    S = SS
    img = Image.new('RGBA', (W * S, height * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    mid = TOP_H // 2
    # side walls with a vertical gradient (drawn as thin strips)
    wall_h = height - mid
    for i in range(wall_h * S):
        t = i / (wall_h * S)
        c_left = mix(wall_top, wall_bot, min(1, t * 1.15))
        y = mid * S + i
        # left wall spans x in [0, 72] with a sloped top edge
        top_l = mid * S + int(i * 0)  # placeholder to keep structure simple
    left = [(0, mid * S), (W * S // 2, TOP_H * S), (W * S // 2, height * S), (0, (height - mid) * S)]
    right = [(W * S // 2, TOP_H * S), (W * S, mid * S), (W * S, (height - mid) * S), (W * S // 2, height * S)]
    wall = Image.new('RGB', (W * S, height * S), wall_top)
    wd = ImageDraw.Draw(wall)
    for y in range(height * S):
        t = max(0.0, (y / S - mid) / (height - mid))
        wd.line([(0, y), (W * S, y)], fill=mix(wall_top, wall_bot, min(1.0, t * 1.1)))
    rng = random.Random(f'{kind}-wall-{variant}')
    for _ in range(90):  # brick/earth speckle
        x, y = rng.randrange(W * S), rng.randrange(mid * S, height * S)
        wd.rectangle([x, y, x + 4 * S, y + 2 * S], fill=shade(mix(wall_top, wall_bot, y / (height * S)), 0.9 + rng.random() * 0.2))
    mask_l = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask_l).polygon(left, fill=255)
    mask_r = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask_r).polygon(right, fill=255)
    lw = Image.eval(wall.convert('RGB'), lambda v: int(v * 0.9))
    rw = Image.eval(wall.convert('RGB'), lambda v: int(v * 0.72))
    img.paste(lw, (0, 0), mask_l)
    img.paste(rw, (0, 0), mask_r)
    # top diamond
    tex = _top_texture(kind, base, accent, variant)
    top_mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(top_mask).polygon(
        [(W * S // 2, 0), (W * S, mid * S), (W * S // 2, TOP_H * S), (0, mid * S)], fill=255)
    canvas = Image.new('RGBA', img.size, (0, 0, 0, 0))
    canvas.paste(tex, (0, 0))
    img.paste(canvas, (0, 0), top_mask)
    # top rim highlight
    ImageDraw.Draw(img).line(
        [(0, mid * S), (W * S // 2, 0), (W * S, mid * S)], fill=shade(base, 1.18) + (255,), width=S)
    return img.resize((W, height), Image.LANCZOS)


def all_tiles():
    for kind in KINDS:
        for v in range(4):
            yield f't_{kind}_{v}', make_tile(kind, v)
