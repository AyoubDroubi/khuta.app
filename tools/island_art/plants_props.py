"""Small pieces: plants, rocks and props."""
from __future__ import annotations

import math

import palette as P
from common import canvas_for, face_l, face_r, slab
from iso import shade, mix, tint


# ---- plants ----------------------------------------------------------------
def palm(key, variant):
    c = canvas_for(key)
    hue = {'': 0, 'autumn': -0.06, 'deep': 0.0, 'silver': 0.12}.get(variant, 0)
    sat = {'silver': 0.45}.get(variant, 1)
    val = {'deep': 0.7}.get(variant, 1)
    leaf = tint(P.PALM, hue, sat, val)
    leaf_l = tint(P.PALM_LIGHT, hue, sat, val)
    if variant == 'autumn':
        leaf, leaf_l = mix(leaf, P.GOLD, 0.35), mix(leaf_l, P.GOLD, 0.5)
    cu, cv = 0.5, 0.5
    for i in range(8):  # slightly leaning trunk
        o = i * 0.006
        c.box(cu - 0.075 + o, cv - 0.075, i * 1.6, 0.15 - i * 0.004, 0.15 - i * 0.004, 1.7, P.TRUNK if i % 2 else shade(P.TRUNK, 0.9), grain=0.1)
    top = 12.8
    tu, tv = cu + 0.05, cv
    c.box(tu - 0.1, tv - 0.1, top - 0.5, 0.2, 0.2, 3, shade(leaf, 0.75), grain=0.05)
    for du, dv in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for k in range(1, 5):  # long drooping fronds
            c.box(tu + du * 0.1 * k - 0.06, tv + dv * 0.1 * k - 0.06, top + 1.6 - k * 1.0, 0.12 if du else 0.14, 0.14 if du else 0.12, 1.1, leaf_l if k < 3 else leaf, grain=0.08)
    for du, dv in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
        for k in range(1, 4):
            c.box(tu + du * 0.09 * k - 0.05, tv + dv * 0.09 * k - 0.05, top + 2.2 - k * 1.2, 0.1, 0.1, 1.1, leaf, grain=0.08)
    c.box(tu - 0.06, tv - 0.06, top + 2.4, 0.12, 0.12, 1.8, leaf_l, grain=0.05)
    c.box(tu + 0.03, tv + 0.05, top - 1.6, 0.08, 0.08, 1.6, P.GOLD if variant != 'silver' else P.SAND, grain=0.05)  # dates
    c.box(tu - 0.1, tv + 0.03, top - 1.6, 0.08, 0.08, 1.6, P.AMBER if variant != 'silver' else P.SAND, grain=0.05)
    return c


def acacia(key, variant):
    c = canvas_for(key)
    hue = {'': 0, 'autumn': -0.07, 'deep': 0.0, 'silver': 0.1}.get(variant, 0)
    sat = {'silver': 0.4}.get(variant, 1)
    val = {'deep': 0.7}.get(variant, 1)
    leaf = tint(P.SAGE, hue, sat, val)
    if variant == 'autumn':
        leaf = mix(leaf, P.OCHRE, 0.4)
    cu, cv = 0.5, 0.5
    c.box(cu - 0.07, cv - 0.07, 0, 0.14, 0.14, 9, P.TRUNK, grain=0.1)
    c.box(cu - 0.17, cv - 0.04, 6, 0.14, 0.08, 4, P.TRUNK, grain=0.1)
    for i, (r, z) in enumerate(((0.36, 10), (0.30, 12.4), (0.2, 14.6))):
        c.box(cu - r, cv - r, z, 2 * r, 2 * r, 2.4, shade(leaf, 1.05 - i * 0.07), grain=0.1)
    return c


def agave(key, variant):  # desert aloe
    c = canvas_for(key)
    cu, cv = 0.5, 0.5
    for du, dv in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        for k in range(1, 4):
            c.box(cu + du * 0.07 * k - 0.025, cv + dv * 0.07 * k - 0.025, 1 + k * 1.6, 0.05, 0.05, 1.6, P.SAGE if k < 3 else P.PALM_LIGHT, grain=0.1)
    c.box(cu - 0.05, cv - 0.05, 0, 0.1, 0.1, 3, P.PALM, grain=0.05)
    return c


def bougainvillea(key, variant):
    c = canvas_for(key)
    col = P.ACCENTS[variant]
    cu, cv = 0.5, 0.5
    c.box(cu - 0.26, cv - 0.26, 0, 0.52, 0.52, 4, P.PALM_DARK, grain=0.12)
    c.box(cu - 0.2, cv - 0.2, 4, 0.4, 0.4, 3, P.PALM, grain=0.12)
    rng = c.rng
    for _ in range(34):
        u = cu - 0.26 + rng.random() * 0.46
        v = cv - 0.26 + rng.random() * 0.46
        c.box(u, v, 1 + rng.random() * 6, 0.1, 0.1, 1.6, col, grain=0.08, top=shade(col, 1.2), layer=1)
    return c


def flower_pot(key, variant):
    c = canvas_for(key)
    col = P.ACCENTS[variant]
    cu, cv = 0.5, 0.5
    c.box(cu - 0.14, cv - 0.14, 0, 0.28, 0.28, 3, P.CLAY, grain=0.06)
    c.box(cu - 0.17, cv - 0.17, 3, 0.34, 0.34, 1, shade(P.CLAY, 1.1), grain=0.04)
    c.box(cu - 0.15, cv - 0.15, 4, 0.3, 0.3, 2, P.PALM, grain=0.1)
    for du, dv in ((-1, -1), (1, -1), (-1, 1), (1, 1), (0, 0)):
        c.box(cu + du * 0.08 - 0.035, cv + dv * 0.08 - 0.035, 5.2 + (du == 0) * 1, 0.07, 0.07, 1.4, col, grain=0.05, top=shade(col, 1.2), layer=1)
    return c


def terracotta_pot(key, variant):
    c = canvas_for(key)
    col = P.ACCENTS[variant]
    cu, cv = 0.5, 0.45
    c.box(cu - 0.17, cv - 0.17, 0, 0.34, 0.34, 2.4, P.CLAY, grain=0.06)
    c.box(cu - 0.2, cv - 0.2, 2.4, 0.4, 0.4, 1, shade(P.CLAY, 1.1), grain=0.04)
    c.box(cu - 0.06, cv - 0.06, 3.4, 0.12, 0.12, 2.5, col, grain=0.05, top=shade(col, 1.2))
    return c


# ---- rocks -----------------------------------------------------------------
def _rock(c, cu, cv, r, h, color):
    c.box(cu - r, cv - r * 0.9, 0, 2 * r, 1.8 * r, h * 0.6, color, grain=0.1)
    c.box(cu - r * 0.7, cv - r * 0.6, h * 0.6, 1.4 * r, 1.2 * r, h * 0.4, shade(color, 1.06), grain=0.1)


def boulder(key, variant):
    c = canvas_for(key)
    _rock(c, 0.5, 0.5, 0.33, 8, P.STONE_DARK)
    return c


def large_rock(key, variant):
    c = canvas_for(key)
    _rock(c, 0.5, 0.5, 0.3, 9, shade(P.SAND_DARK, 1.05))
    c.box(0.62, 0.3, 0, 0.18, 0.16, 3, P.STONE_DARK, grain=0.1)
    return c


def rocks(key, variant):
    c = canvas_for(key)
    _rock(c, 0.38, 0.4, 0.2, 5, P.STONE_DARK)
    _rock(c, 0.64, 0.58, 0.17, 4, P.STONE)
    _rock(c, 0.55, 0.3, 0.1, 3, shade(P.SAND_DARK, 1.0))
    return c


def pebbles(key, variant):
    c = canvas_for(key)
    for u, v, r in ((0.3, 0.5, 0.07), (0.5, 0.4, 0.09), (0.62, 0.6, 0.06), (0.45, 0.62, 0.05)):
        c.box(u - r, v - r, 0, 2 * r, 2 * r, 1.6, P.STONE if r > 0.06 else P.SAND_DARK, grain=0.1)
    return c


def flat_stone(key, variant):
    c = canvas_for(key)
    c.box(0.15, 0.15, 0, 0.7, 0.7, 2, P.STONE, grain=0.08)
    c.box(0.25, 0.25, 2, 0.4, 0.4, 1, shade(P.STONE, 1.08), grain=0.08)
    return c


def mossy_stone(key, variant):
    c = canvas_for(key)
    _rock(c, 0.5, 0.5, 0.22, 7, P.STONE_DARK)
    c.box(0.38, 0.38, 6.6, 0.24, 0.24, 1, P.PALM_LIGHT, grain=0.1)
    return c


def stone_pile(key, variant):
    c = canvas_for(key)
    for i, (r, h) in enumerate(((0.3, 3), (0.24, 3), (0.17, 3), (0.1, 3))):
        c.box(0.5 - r, 0.5 - r, i * 3, 2 * r, 2 * r, 3, [P.STONE, P.SAND_DARK, P.STONE_DARK, P.STONE][i], grain=0.1)
    c.box(0.46, 0.46, 12, 0.08, 0.08, 1.4, P.GOLD)
    return c


# ---- props -----------------------------------------------------------------
def crate(key, variant):
    c = canvas_for(key)
    c.box(0.22, 0.22, 0, 0.56, 0.56, 6, P.WOOD, grain=0.08)
    for z in (0.5, 5):
        c.box(0.21, 0.21, z, 0.58, 0.58, 0.8, P.WOOD_DARK, grain=0.04)
    return c


def storage_box(key, variant):
    c = canvas_for(key)
    c.box(0.12, 0.2, 0, 0.7, 0.55, 5, P.WOOD, grain=0.08)
    c.box(0.1, 0.18, 5, 0.74, 0.6, 1.6, P.WOOD_DARK, grain=0.05)
    face_l(c, 0.4, 0.75, 3, 0.12, 1.4, P.GOLD)
    return c


def hay_bale(key, variant):
    c = canvas_for(key)
    hay = mix(P.GOLD, P.SAND, 0.45)
    c.box(0.15, 0.2, 0, 0.7, 0.55, 5, hay, grain=0.14, top=shade(hay, 1.1), left=shade(hay, 0.82), right=shade(hay, 0.66))
    for u in (0.32, 0.58):
        c.box(u, 0.2, 0, 0.04, 0.56, 5.05, P.WOOD, grain=0.03, layer=1)
    return c


def wood_pile(key, variant):
    c = canvas_for(key)
    for k, z in enumerate((0, 2, 4)):
        for j in range(3 - k):
            c.box(0.2 + j * 0.2 + k * 0.1, 0.25, z, 0.17, 0.5, 2, P.WOOD if (j + k) % 2 else P.WOOD_DARK, grain=0.1, top=shade(P.WOOD, 1.2))
    return c


def water_bucket(key, variant):  # water skin pot
    c = canvas_for(key)
    c.box(0.3, 0.3, 0, 0.4, 0.4, 4, P.WOOD, grain=0.06)
    c.box(0.33, 0.33, 4, 0.34, 0.34, 0.6, P.WATER, grain=0.02)
    c.box(0.28, 0.28, 3, 0.44, 0.44, 0.7, P.WOOD_DARK, grain=0.03)
    return c


def pottery_jar(key, variant):  # amphora
    c = canvas_for(key)
    cu, cv = 0.5, 0.5
    for z, r in ((0, 0.1), (2, 0.16), (5, 0.2), (8, 0.17), (11, 0.11), (13, 0.07), (15, 0.09)):
        c.box(cu - r, cv - r, z, 2 * r, 2 * r, 2.2 if z < 15 else 1, P.CLAY if z < 13 else shade(P.CLAY, 1.1), grain=0.06)
    c.box(cu - 0.2, cv - 0.2, 7, 0.4, 0.4, 0.7, P.OCHRE, grain=0.03)
    return c


def crop_patch(key, variant):  # irrigated plot
    c = canvas_for(key)
    c.flat(0.05, 0.05, 0, 0.9, 0.9, P.MUD, grain=0.08)
    for k in range(5):
        c.box(0.12, 0.12 + k * 0.17, 0, 0.76, 0.08, 1.6, P.PALM_LIGHT if k % 2 else P.PALM, grain=0.1)
    return c


def garden_bed(key, variant):
    c = canvas_for(key)
    c.box(0.04, 0.04, 0, 0.92, 0.92, 1.2, P.STONE, grain=0.05)
    c.flat(0.1, 0.1, 1.2, 0.8, 0.8, P.MUD, grain=0.08)
    cols = [P.CORAL, P.AMBER, P.LILAC, P.WHITE]
    for i in range(4):
        for j in range(3):
            c.box(0.16 + i * 0.18, 0.2 + j * 0.26, 1.2, 0.09, 0.09, 0.9 + (i + j) % 2 * 0.5, cols[(i + j) % 4], grain=0.05, top=shade(cols[(i + j) % 4], 1.2), layer=1)
    return c


def veg_garden(key, variant):
    c = canvas_for(key)
    c.flat(0.05, 0.05, 0, 0.9, 0.9, P.MUD, grain=0.08)
    for k in range(4):
        c.box(0.14, 0.14 + k * 0.2, 0, 0.72, 0.1, 1.4, P.MUD_LIGHT, grain=0.06)
        for j in range(5):
            c.box(0.18 + j * 0.14, 0.16 + k * 0.2, 1.4, 0.08, 0.06, 1.3, P.PALM if (j + k) % 2 else P.SAGE, grain=0.1)
    return c


BUILDERS = {
    'cypress': palm, 'olive': acacia, 'agave': agave, 'bougainvillea': bougainvillea,
    'flower_pot': flower_pot, 'terracotta_pot': terracotta_pot,
    'boulder': boulder, 'large_rock': large_rock, 'rocks': rocks, 'pebbles': pebbles,
    'flat_stone': flat_stone, 'mossy_stone': mossy_stone, 'stone_pile': stone_pile,
    'crate': crate, 'storage_box': storage_box, 'hay_bale': hay_bale, 'wood_pile': wood_pile,
    'water_bucket': water_bucket, 'pottery_jar': pottery_jar,
    'crop_patch': crop_patch, 'garden_bed': garden_bed, 'veg_garden': veg_garden,
}
