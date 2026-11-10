"""Buildings, towers and structures (Arab oasis)."""
from __future__ import annotations

import palette as P
from common import canvas_for, face_l, face_r, slab
from iso import shade, mix, tint

WALL = P.PLASTER


def _accent(variant, default=None):
    return P.ACCENTS.get(variant, default or P.TERRACOTTA)


def _door_l(c, u, v1, accent, h=6.5, w=0.2):
    face_l(c, u, v1, 0.4, w, h, shade(accent, 0.8))
    face_l(c, u + 0.02, v1, h + 0.4 - 1.2, w - 0.04, 1.2, shade(accent, 1.0))


def _win_r(c, u1, v, z, accent, w=0.14, h=3.2):
    face_r(c, u1, v, z, w, h, P.DARK)
    face_r(c, u1, v - 0.025, z - 0.4, w + 0.05, 0.6, accent)


def _crenel(c, u, v, du, dv, z, color, step=0.2):
    n = int(du / step) if du > dv else int(dv / step)
    for i in range(0, n, 2):
        if du > dv:
            c.box(u + i * step, v, z, step, dv, 1.2, color, grain=0.04)
        else:
            c.box(u, v + i * step, z, du, step, 1.2, color, grain=0.04)


def house(key, variant):
    c = canvas_for(key)
    a = _accent(variant)
    slab(c, P.STONE)
    c.box(0.22, 0.22, 1.2, 1.56, 1.56, 12, WALL, grain=0.04)
    c.box(0.18, 0.18, 13.2, 1.64, 1.64, 1.3, shade(WALL, 1.05), grain=0.03)  # parapet
    c.box(0.9, 0.9, 14.5, 0.6, 0.6, 5, WALL, grain=0.04)                      # roof room
    c.box(0.86, 0.86, 19.5, 0.68, 0.68, 1, shade(WALL, 1.05), grain=0.03)
    _door_l(c, 0.55, 1.78, a)
    _win_r(c, 1.78, 0.6, 6, a)
    _win_r(c, 1.78, 1.1, 6, a)
    face_l(c, 1.05, 1.78, 6, 0.16, 3, P.DARK)
    c.box(0.3, 1.78, 1.2, 0.16, 0.22, 1.6, P.CLAY, grain=0.04)  # step pot
    return c


def cube_house(key, variant):
    c = canvas_for(key)
    a = _accent(variant, P.TEAL)
    slab(c, P.STONE)
    c.box(0.3, 0.3, 1.2, 1.4, 1.4, 11, mix(WALL, P.SAND, 0.2), grain=0.05)
    c.box(0.26, 0.26, 12.2, 1.48, 1.48, 1, shade(WALL, 1.05))
    c.dome(1.0, 1.0, 13.2, 0.55, a, layers=5, grain=0.05)
    c.box(0.97, 0.97, 22.8, 0.06, 0.06, 2.4, P.GOLD, grain=0)
    _door_l(c, 0.6, 1.7, a)
    _win_r(c, 1.7, 0.7, 6, a)
    _win_r(c, 1.7, 1.15, 6, a)
    return c


def terrace_house(key, variant):
    c = canvas_for(key)
    a = _accent(variant, P.CLAY)
    slab(c, P.STONE)
    c.box(0.2, 0.2, 1.2, 2.6, 1.6, 9, WALL, grain=0.04)
    c.box(0.16, 0.16, 10.2, 2.68, 1.68, 1.2, shade(WALL, 1.05))
    c.box(0.3, 0.3, 11.4, 1.3, 1.1, 7, mix(WALL, P.SAND, 0.15), grain=0.04)
    c.box(0.26, 0.26, 18.4, 1.38, 1.18, 1, shade(WALL, 1.05))
    for i in range(5):  # stairs on the front
        c.box(1.7 + i * 0.1, 1.55, 1.2 + i * 1.8, 0.16, 0.3, 1.8, shade(P.STONE, 0.95 + i * 0.02), grain=0.04)
    _door_l(c, 0.5, 1.8, a)
    _door_l(c, 1.6, 1.8, a, h=5)
    _win_r(c, 2.8, 0.6, 5, a)
    _win_r(c, 2.8, 1.1, 5, a)
    c.box(0.3, 1.8, 7, 2.0, 0.1, 0.6, a, grain=0.03, layer=1)  # awning
    return c


def two_story(key, variant):
    c = canvas_for(key)
    a = _accent(variant, P.CLAY)
    slab(c, P.STONE, dz=1.4)
    c.box(0.3, 0.3, 1.4, 2.4, 2.4, 9, WALL, grain=0.04)
    c.box(0.26, 0.26, 10.4, 2.48, 2.48, 1.2, shade(WALL, 1.05))
    c.box(0.6, 0.6, 11.6, 1.8, 1.8, 8, mix(WALL, P.SAND, 0.12), grain=0.04)
    c.box(0.56, 0.56, 19.6, 1.88, 1.88, 1.2, shade(WALL, 1.05))
    _crenel(c, 0.56, 0.56, 1.88, 0.1, 20.8, shade(WALL, 1.05))
    c.box(2.62, 0.9, 7.6, 0.45, 1.2, 0.5, a, grain=0.03)                  # balcony floor
    c.box(3.0, 0.9, 8.1, 0.05, 1.2, 1.4, a, grain=0.03, layer=1)         # railing
    _door_l(c, 0.9, 2.78, a)
    _win_r(c, 2.7, 0.9, 4, a)
    _win_r(c, 2.7, 1.9, 4, a)
    _win_r(c, 2.42, 1.2, 14, a)
    face_l(c, 1.0, 2.38, 14, 0.2, 3.2, P.DARK)
    return c


def pergola_house(key, variant):
    c = canvas_for(key)
    a = _accent(variant, P.TEAL)
    slab(c, P.STONE, dz=1.4)
    c.box(0.3, 0.3, 1.4, 1.7, 1.9, 10, WALL, grain=0.04)
    c.box(0.26, 0.26, 11.4, 1.78, 1.98, 1.2, shade(WALL, 1.05))
    # pergola over the courtyard
    for u, v in ((2.1, 0.5), (2.1, 2.5), (2.8, 0.5), (2.8, 2.5)):
        c.box(u, v, 1.4, 0.1, 0.1, 9, P.WOOD, grain=0.06)
    for k in range(6):
        c.box(2.05, 0.45 + k * 0.42, 10.4, 0.8, 0.07, 0.7, P.WOOD, grain=0.05, layer=1)
    for k in range(4):
        c.box(2.05 + k * 0.25, 0.45, 11.1, 0.07, 2.2, 0.5, a, grain=0.04, layer=1)
    c.box(2.15, 0.6, 11.0, 0.3, 0.3, 1.2, P.PALM, grain=0.1, layer=1)
    c.box(2.5, 1.8, 11.0, 0.3, 0.3, 1.2, P.PALM_LIGHT, grain=0.1, layer=1)
    c.box(2.1, 1.0, 1.4, 0.7, 1.4, 0.3, mix(P.SAND, P.CLAY, 0.3), grain=0.05)  # rug
    _door_l(c, 0.7, 2.18, a)
    _win_r(c, 2.0, 0.8, 6, a)
    _win_r(c, 2.0, 1.5, 6, a)
    return c


def villa(key, variant):
    c = canvas_for(key)
    a = P.TURQUOISE
    slab(c, P.STONE, dz=1.4, inset=0.05)
    H = 9
    # U shaped courtyard house: back wing, left wing, right wing
    c.box(0.3, 0.3, 1.4, 3.4, 1.0, H, WALL, grain=0.04)
    c.box(0.3, 1.3, 1.4, 1.0, 2.4, H, WALL, grain=0.04)
    c.box(2.7, 1.3, 1.4, 1.0, 2.4, H, WALL, grain=0.04)
    for (u, v, du, dv) in ((0.26, 0.26, 3.48, 1.08), (0.26, 1.26, 1.08, 2.48), (2.66, 1.26, 1.08, 2.48)):
        c.box(u, v, 1.4 + H, du, dv, 1.2, shade(WALL, 1.05))
    # courtyard: tiles, fountain, palm
    c.box(1.3, 1.3, 1.4, 1.4, 2.4, 0.3, P.SAND_LIGHT, grain=0.05)
    c.box(1.8, 2.2, 1.7, 0.4, 0.4, 1.4, P.STONE, grain=0.05)
    c.box(1.88, 2.28, 3.1, 0.24, 0.24, 0.4, P.WATER, grain=0.02)
    c.box(1.9, 1.5, 1.7, 0.12, 0.12, 9, P.TRUNK, grain=0.1)
    for du, dv in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for k in range(1, 4):
            c.box(1.96 + du * 0.1 * k - 0.06, 1.56 + dv * 0.1 * k - 0.06, 11 - k * 0.9, 0.12, 0.12, 1, P.PALM_LIGHT if k < 3 else P.PALM, grain=0.08, layer=1)
    # entrance gate with a small dome
    c.box(1.6, 3.7, 1.4, 0.8, 0.3, 7, mix(WALL, P.SAND, 0.15), grain=0.04)
    c.dome(2.0, 3.85, 8.4, 0.3, a, layers=3, grain=0.05)
    face_l(c, 1.8, 4.02, 1.6, 0.4, 5, shade(P.WOOD, 0.9))
    # windows
    for v in (0.55, 1.05):
        _win_r(c, 3.7, v + 0.0, 5, a, w=0.16)
    for u in (0.7, 1.4, 2.4, 3.0):
        face_l(c, u, 1.32, 5, 0.16, 3.2, P.DARK)
    # roof corner towers
    c.box(0.2, 0.2, 10.6, 0.5, 0.5, 4, WALL, grain=0.04)
    c.dome(0.45, 0.45, 14.6, 0.28, a, layers=3, grain=0.05)
    return c


def main_chapel(key, variant):  # mosque
    c = canvas_for(key)
    dome = P.CLAY if variant == 'clay' else P.TEAL
    slab(c, P.STONE, dz=1.4)
    c.box(0.3, 0.3, 1.4, 2.0, 2.0, 8, WALL, grain=0.04)
    c.box(0.26, 0.26, 9.4, 2.08, 2.08, 1.2, shade(WALL, 1.05))
    c.box(0.55, 0.55, 10.6, 1.5, 1.5, 2.4, shade(WALL, 1.0), grain=0.04)
    c.dome(1.3, 1.3, 13, 0.8, dome, layers=6, grain=0.05)
    c.box(1.27, 1.27, 25.2, 0.06, 0.06, 3, P.GOLD, grain=0)
    # minaret
    c.box(2.35, 0.35, 1.4, 0.4, 0.4, 20, WALL, grain=0.04)
    c.box(2.3, 0.3, 21.4, 0.5, 0.5, 1.2, P.STONE, grain=0.04)
    c.box(2.37, 0.37, 22.6, 0.36, 0.36, 3, WALL, grain=0.04)
    c.dome(2.55, 0.55, 25.6, 0.22, dome, layers=3, grain=0.05)
    c.box(2.52, 0.52, 28.2, 0.05, 0.05, 2, P.GOLD, grain=0)
    # arched windows and door
    for v in (0.8, 1.45, 2.0):
        face_r(c, 2.3, v - 0.1, 3, 0.2, 4, P.DARK)
    face_l(c, 0.9, 2.3, 1.6, 0.5, 6, shade(P.WOOD, 0.9))
    face_l(c, 0.6, 2.3, 3, 0.18, 3.5, P.DARK)
    face_l(c, 1.6, 2.3, 3, 0.18, 3.5, P.DARK)
    return c


def tower_chapel(key, variant):  # minaret
    c = canvas_for(key)
    cap = {'ochre': P.OCHRE, 'teal': P.TEAL}.get(variant, P.TEAL)
    slab(c, P.STONE, dz=1.4)
    c.box(0.5, 0.5, 1.4, 1.0, 1.0, 4, mix(WALL, P.SAND, 0.15), grain=0.04)
    c.box(0.62, 0.62, 5.4, 0.76, 0.76, 15, WALL, grain=0.04)
    c.box(0.5, 0.5, 20.4, 1.0, 1.0, 1.2, P.STONE, grain=0.04)
    c.box(0.58, 0.58, 21.6, 0.84, 0.84, 1, shade(WALL, 1.0))
    c.box(0.7, 0.7, 22.6, 0.6, 0.6, 7, WALL, grain=0.04)
    c.box(0.62, 0.62, 29.6, 0.76, 0.76, 1.2, P.STONE, grain=0.04)
    c.dome(1.0, 1.0, 30.8, 0.4, cap, layers=4, grain=0.05)
    c.box(0.97, 0.97, 38.8, 0.05, 0.05, 2.2, P.GOLD, grain=0)
    for z in (9, 14):
        face_r(c, 1.38, 0.88, z, 0.24, 3, P.DARK)
        face_l(c, 0.88, 1.38, z, 0.24, 3, P.DARK)
    face_l(c, 0.85, 1.5, 1.6, 0.3, 3.4, shade(P.WOOD, 0.9))
    return c


def windmill(key, variant):  # windcatcher (badgir)
    c = canvas_for(key)
    a = P.CLAY if variant == 'clay' else P.TERRACOTTA
    slab(c, P.STONE, dz=1.4)
    c.box(0.35, 0.35, 1.4, 1.3, 1.3, 7, mix(WALL, P.SAND, 0.2), grain=0.05)
    c.box(0.55, 0.55, 8.4, 0.9, 0.9, 12, mix(WALL, P.SAND, 0.25), grain=0.05)
    c.box(0.5, 0.5, 20.4, 1.0, 1.0, 1.4, shade(WALL, 1.05))
    for i in range(4):  # louvred vents
        c.box(0.52 + i * 0.22, 0.52, 21.8, 0.1, 0.96, 4.5, shade(WALL, 0.85), grain=0.04, layer=1)
    c.box(0.46, 0.46, 26.4, 1.08, 1.08, 1.2, a, grain=0.04)
    face_r(c, 1.45, 0.75, 10, 0.2, 4, P.DARK)
    face_l(c, 0.9, 1.65, 1.6, 0.3, 4.6, shade(P.WOOD, 0.9))
    return c


def altar(key, variant):  # bedouin tent
    c = canvas_for(key)
    cloth = P.PLUM if variant == 'plum' else P.CLAY
    slab(c, mix(P.SAND, P.CLAY, 0.2), dz=0.8, inset=0.1)
    for u, v in ((0.35, 0.35), (1.55, 0.35), (0.35, 1.55), (1.55, 1.55)):
        c.box(u, v, 0.8, 0.08, 0.08, 7, P.WOOD, grain=0.05)
    c.pyramid(0.3, 0.3, 7.8, 1.4, 1.4, cloth, layers=5, step=1.6, grain=0.06)
    c.box(0.9, 0.9, 15.8, 0.2, 0.2, 2.6, P.WOOD, grain=0.04)
    c.box(0.45, 0.45, 0.8, 1.1, 1.1, 0.4, mix(cloth, P.WHITE, 0.3), grain=0.05, layer=1)  # rug
    c.box(0.55, 0.55, 1.2, 0.3, 0.3, 1.3, P.GOLD, grain=0.05, layer=1)
    return c


def archway(key, variant):
    c = canvas_for(key)
    c.box(0.15, 0.3, 0, 0.22, 0.4, 14, P.STONE, grain=0.06)
    c.box(0.63, 0.3, 0, 0.22, 0.4, 14, P.STONE, grain=0.06)
    for i, z in enumerate((14, 15.4)):
        w = 0.7 - i * 0.14
        c.box(0.15 + i * 0.07, 0.3, z, w + 0.08, 0.4, 1.4, shade(P.STONE, 1.05), grain=0.05)
    c.box(0.44, 0.3, 16.8, 0.12, 0.4, 1, P.GOLD, grain=0.03)
    return c


def small_bridge(key, variant):
    c = canvas_for(key)
    c.box(0.0, 0.0, 0, 2.0, 1.0, 1.0, P.STONE, grain=0.05)
    c.box(0.25, 0.15, 0.8, 1.5, 0.7, 0.9, P.WATER, grain=0.02, top=P.WATER, left=P.WATER_DEEP, right=P.WATER_DEEP, layer=0)
    for k in range(7):
        c.box(0.1 + k * 0.26, 0.2, 1.0, 0.24, 0.6, 1.0 + (k in (2, 3, 4)) * 0.8, P.WOOD if k % 2 else shade(P.WOOD, 1.1), grain=0.06, layer=1)
    for v in (0.12, 0.74):
        c.box(0.1, v, 1.8, 1.8, 0.07, 1.4, P.TEAL, grain=0.04, layer=1)
    return c


def stone_basin(key, variant):  # fountain
    c = canvas_for(key)
    a = P.TEAL if variant == 'teal' else P.SAGE
    c.box(0.2, 0.2, 0, 0.6, 0.6, 3, P.STONE, grain=0.05)
    c.box(0.16, 0.16, 3, 0.68, 0.68, 0.7, a, grain=0.04)
    c.box(0.28, 0.28, 3, 0.44, 0.44, 0.6, P.WATER, grain=0.02, top=mix(P.WATER, P.WHITE, 0.2))
    c.box(0.46, 0.46, 3.4, 0.08, 0.08, 3, P.WATER_DEEP, grain=0, layer=1)
    return c


def well(key, variant):
    c = canvas_for(key)
    a = P.TEAL if variant == 'teal' else P.CLAY
    c.box(0.22, 0.22, 0, 0.56, 0.56, 5, P.STONE, grain=0.06)
    c.box(0.18, 0.18, 5, 0.64, 0.64, 1, shade(P.STONE, 1.08), grain=0.05)
    c.box(0.3, 0.3, 5.9, 0.4, 0.4, 0.3, P.WATER_DEEP, grain=0.02, layer=1)
    for u, v in ((0.2, 0.2), (0.74, 0.74)):
        c.box(u, v, 6, 0.06, 0.06, 7, P.WOOD, grain=0.05, layer=1)
    c.box(0.18, 0.18, 13, 0.66, 0.66, 0.7, a, grain=0.04, layer=1)
    c.box(0.4, 0.4, 9, 0.12, 0.12, 2, P.WOOD_DARK, grain=0.04, layer=1)
    return c


def lantern_post(key, variant):
    c = canvas_for(key)
    a = P.CLAY if variant == 'clay' else P.TEAL
    c.box(0.42, 0.42, 0, 0.16, 0.16, 1.2, P.STONE, grain=0.05)
    c.box(0.46, 0.46, 1.2, 0.08, 0.08, 15, P.DARK, grain=0.04)
    c.box(0.4, 0.4, 16.2, 0.2, 0.2, 0.8, a, grain=0.04)
    c.box(0.41, 0.41, 17, 0.18, 0.18, 3, P.GOLD, grain=0.02, top=mix(P.GOLD, P.WHITE, 0.4), layer=1)
    c.box(0.38, 0.38, 20, 0.24, 0.24, 0.8, a, grain=0.04, layer=1)
    return c


def stone_lantern(key, variant):
    c = canvas_for(key)
    a = P.OCHRE if variant == 'ochre' else P.SAGE
    c.box(0.34, 0.34, 0, 0.32, 0.32, 1.2, P.STONE, grain=0.05)
    c.box(0.42, 0.42, 1.2, 0.16, 0.16, 6, P.STONE, grain=0.05)
    c.box(0.34, 0.34, 7.2, 0.32, 0.32, 3.2, P.GOLD, grain=0.02, top=mix(P.GOLD, P.WHITE, 0.4))
    c.box(0.3, 0.3, 10.4, 0.4, 0.4, 1.2, a, grain=0.04)
    c.box(0.4, 0.4, 11.6, 0.2, 0.2, 1, shade(a, 1.1))
    return c


def hanging_lantern(key, variant):
    c = canvas_for(key)
    a = P.PLUM if variant == 'plum' else P.TEAL
    c.box(0.2, 0.46, 0, 0.1, 0.1, 15, P.WOOD_DARK, grain=0.04)
    c.box(0.2, 0.46, 15, 0.45, 0.1, 0.8, P.WOOD_DARK, grain=0.04)
    c.box(0.6, 0.48, 11, 0.03, 0.03, 4, P.DARK, grain=0)
    c.box(0.55, 0.43, 7.4, 0.14, 0.14, 3.6, P.GOLD, grain=0.02, top=mix(P.GOLD, P.WHITE, 0.4))
    c.box(0.52, 0.4, 11, 0.2, 0.2, 0.8, a, grain=0.04)
    return c


def signpost(key, variant):
    c = canvas_for(key)
    a = P.CLAY if variant == 'clay' else P.TEAL
    c.box(0.45, 0.45, 0, 0.1, 0.1, 12, P.WOOD, grain=0.06)
    c.box(0.2, 0.4, 8.5, 0.6, 0.18, 3, a, grain=0.05)
    c.box(0.42, 0.42, 12, 0.16, 0.16, 0.8, P.GOLD, grain=0.03)
    return c


def banner(key, variant):
    c = canvas_for(key)
    a = P.ACCENTS[variant]
    c.box(0.15, 0.45, 0, 0.1, 0.1, 18, P.WOOD, grain=0.05)
    c.box(0.13, 0.43, 18, 0.14, 0.14, 0.8, P.GOLD, grain=0.03)
    c.box(0.25, 0.47, 8, 0.05, 0.5, 9, a, grain=0.05, layer=1)
    c.box(0.25, 0.47, 8, 0.05, 0.5, 1.2, shade(a, 0.75), grain=0.03, layer=1)
    return c


def bench(key, variant):
    c = canvas_for(key)
    a = P.ACCENTS[variant]
    c.box(0.15, 0.3, 0, 0.12, 0.4, 3, P.MUD, grain=0.06)
    c.box(0.65, 0.3, 0, 0.12, 0.4, 3, P.MUD, grain=0.06)
    c.box(0.12, 0.28, 3, 0.7, 0.44, 1.2, P.WOOD, grain=0.06)
    c.box(0.2, 0.32, 4.2, 0.5, 0.36, 0.8, a, grain=0.05, layer=1)
    return c


def blue_railing(key, variant):  # mashrabiya lattice fence
    c = canvas_for(key)
    a = P.ACCENTS[variant]
    c.box(0.05, 0.46, 0, 0.9, 0.08, 1.2, P.STONE, grain=0.05)
    for k in range(5):
        c.box(0.08 + k * 0.2, 0.46, 1.2, 0.07, 0.08, 6, a, grain=0.05)
    c.box(0.05, 0.46, 7.2, 0.9, 0.08, 0.9, shade(a, 0.8), grain=0.04)
    c.box(0.05, 0.46, 3.4, 0.9, 0.08, 0.5, shade(a, 0.9), grain=0.04, layer=1)
    return c


BUILDERS = {
    'house': house, 'cube_house': cube_house, 'terrace_house': terrace_house, 'two_story': two_story,
    'pergola_house': pergola_house, 'villa': villa, 'main_chapel': main_chapel, 'tower_chapel': tower_chapel,
    'windmill': windmill, 'altar': altar, 'archway': archway, 'small_bridge': small_bridge,
    'stone_basin': stone_basin, 'well': well, 'lantern_post': lantern_post, 'stone_lantern': stone_lantern,
    'hanging_lantern': hanging_lantern, 'signpost': signpost, 'banner': banner, 'bench': bench,
    'blue_railing': blue_railing,
}
