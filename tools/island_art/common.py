"""Helpers shared by the sprite builders."""
from __future__ import annotations

import json
import os

from iso import Canvas, shade, mix, tint
import palette as P

HERE = os.path.dirname(os.path.abspath(__file__))
PINS = json.load(open(os.path.join(HERE, '..', '..', 'mobile', 'test', 'fixtures', 'island_pins.json')))
SPRITES = PINS['sprites']
MARGIN = 260


def canvas_for(key: str) -> Canvas:
    s = SPRITES[key]
    c = Canvas(int(round(s['w'] * 2)), int(round(s['h'] * 2)), s['ax'] * 2, s['ay'] * 2,
               seed=sum(ord(ch) for ch in key), margin=MARGIN)
    c.cols, c.rows = s['cols'], s['rows']
    c.key = key
    return c


def face_r(c, u1, v, z, w, h, color):
    """Thin decal on the right-hand face (the face at u = u1)."""
    c.box(u1, v, z, 0.012, w, h, color, grain=0, top=color, left=color, right=color)


def face_l(c, u, v1, z, w, h, color):
    """Thin decal on the left-hand face (the face at v = v1)."""
    c.box(u, v1, z, w, 0.012, h, color, grain=0, top=color, left=color, right=color)


def slab(c, color=None, inset=0.04, dz=1.2):
    c.box(inset, inset, 0, c.cols - 2 * inset, c.rows - 2 * inset, dz, color or P.STONE, grain=0.05)
