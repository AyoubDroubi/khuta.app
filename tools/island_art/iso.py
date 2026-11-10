"""Isometric box renderer for the Khuta island art.

Everything here is original project work (GPLv3). No third-party art or sample
is used. Images are drawn at 4x and reduced to the delivered size, so edges are
smooth. All randomness is seeded: the same script and Pillow version give the
same bytes.
"""
from __future__ import annotations

import colorsys
import math
import random
from dataclasses import dataclass

from PIL import Image, ImageDraw, ImageFilter

SS = 4                 # supersampling factor
CELL_W = 128           # pixels of one grid cell across, in the delivered 2x image
PZ = 9.0               # pixels of one voxel of height in the delivered image
VOX = 1 / 8            # one voxel = 1/8 of a grid cell


def hexc(h: str) -> tuple[int, int, int]:
    h = h.lstrip('#')
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def shade(c, f):
    """Multiply a colour by f (clamped)."""
    return tuple(max(0, min(255, int(round(v * f)))) for v in c[:3])


def mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


def tint(c, hue_shift=0.0, sat=1.0, val=1.0):
    r, g, b = [v / 255 for v in c[:3]]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    h = (h + hue_shift) % 1.0
    s = max(0, min(1, s * sat))
    v = max(0, min(1, v * val))
    return tuple(int(round(x * 255)) for x in colorsys.hsv_to_rgb(h, s, v))


@dataclass
class Canvas:
    """A sprite canvas. (ax, ay) is where the footprint's top corner sits, in
    delivered pixels (the catalog's anchor x2). u runs along +gx, v along +gy,
    both in grid cells; z is height in voxels."""
    w: int
    h: int
    ax: float
    ay: float
    seed: int = 1
    margin: int = 0

    def __post_init__(self):
        self.out_w, self.out_h = self.w, self.h
        self.out_ax, self.out_ay = self.ax, self.ay
        if self.margin:
            self.w += 2 * self.margin
            self.h += 2 * self.margin
            self.ax += self.margin
            self.ay += self.margin
        self.img = Image.new('RGBA', (self.w * SS, self.h * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.rng = random.Random(self.seed)
        self.queue = []

    # ---- projection -------------------------------------------------
    def p(self, u, v, z=0.0):
        x = self.ax + (u - v) * CELL_W / 2
        y = self.ay + (u + v) * CELL_W / 4 - z * PZ
        return x * SS, y * SS

    # ---- primitives (deferred, depth sorted) --------------------------
    def box(self, u, v, z, du, dv, dz, color, grain=0.05, top=None, left=None, right=None, layer=0):
        """Axis aligned box. u,v in cells; du,dv in cells; z,dz in voxels."""
        self.queue.append(('box', (layer, u + v + (du + dv) / 2), z, (u, v, z, du, dv, dz, color, grain, top, left, right)))

    def flat(self, u, v, z, du, dv, color, grain=0.05):
        self.queue.append(('flat', (-1, u + v), z - 1, (u, v, z, du, dv, color, grain)))

    def poly(self, pts, color, depth=0.0, z=0.0):
        self.queue.append(('poly', (0, depth), z, (pts, color)))

    def render(self):
        self.queue.sort(key=lambda q: (q[1], q[2]))
        for kind, _, _, a in self.queue:
            if kind == 'box':
                self._box(*a)
            elif kind == 'flat':
                self._flat(*a)
            else:
                self.d.polygon([(x * SS, y * SS) for x, y in a[0]], fill=a[1] + (255,))
        self.queue = []
        return self.img.resize((self.w, self.h), Image.LANCZOS)

    # ---- drawing ------------------------------------------------------
    def _grain(self, c, g):
        if g <= 0:
            return c
        f = 1 + (self.rng.random() - 0.5) * 2 * g
        return shade(c, f)

    def _box(self, u, v, z, du, dv, dz, color, grain, top, left, right):
        c = color
        top_c = top or shade(c, 1.06)
        left_c = left or shade(c, 0.86)
        right_c = right or shade(c, 0.68)
        u1, v1, z1 = u + du, v + dv, z + dz
        P = self.p
        # visible faces from the camera at (+u,+v) looking down: top, the face
        # at v1 (left on screen) and the face at u1 (right on screen).
        top_poly = [P(u, v, z1), P(u1, v, z1), P(u1, v1, z1), P(u, v1, z1)]
        left_poly = [P(u, v1, z1), P(u1, v1, z1), P(u1, v1, z), P(u, v1, z)]
        right_poly = [P(u1, v, z1), P(u1, v1, z1), P(u1, v1, z), P(u1, v, z)]
        d = self.d
        d.polygon(left_poly, fill=self._grain(left_c, grain) + (255,))
        d.polygon(right_poly, fill=self._grain(right_c, grain) + (255,))
        d.polygon(top_poly, fill=self._grain(top_c, grain) + (255,))
        edge = shade(c, 0.55) + (70,)
        d.line(top_poly + [top_poly[0]], fill=edge, width=max(1, SS // 2))

    def _flat(self, u, v, z, du, dv, color, grain):
        P = self.p
        poly = [P(u, v, z), P(u + du, v, z), P(u + du, v + dv, z), P(u, v + dv, z)]
        self.d.polygon(poly, fill=self._grain(color, grain) + (255,))

    def finish(self, min_scale=0.6):
        """Render, then fit the drawing into the delivered canvas (the pixel
        size and anchor fixed by the app). If it sticks out, it is scaled down
        around the footprint's ground centre. Returns (image, scale)."""
        big = self.render()
        m = self.margin
        bbox = big.getbbox()
        if bbox is None:
            return Image.new('RGBA', (self.out_w, self.out_h), (0, 0, 0, 0)), 1.0
        # footprint ground centre, in big-canvas pixels
        cu, cv = getattr(self, 'cols', 1) / 2, getattr(self, 'rows', 1) / 2
        gx, gy = self.p(cu, cv, 0)
        gx, gy = gx / SS, gy / SS
        # allowed rectangle in big-canvas pixels
        L, T = self.ax - self.out_ax, self.ay - self.out_ay
        R, B = L + self.out_w, T + self.out_h
        s = 1.0
        x0, y0, x1, y1 = bbox
        for lim, cur, g, side in ((L, x0, gx, 'l'), (R, x1, gx, 'r'), (T, y0, gy, 't'), (B, y1, gy, 'b')):
            if side in 'lt' and cur < lim:
                s = min(s, (g - lim) / (g - cur))
            if side in 'rb' and cur > lim:
                s = min(s, (lim - g) / (cur - g))
        s = max(min_scale, s)
        if s < 1.0:
            big = big.resize((int(round(big.width * s)), int(round(big.height * s))), Image.LANCZOS)
        # the ground centre keeps its place relative to the delivered anchor
        left = gx * s - (self.out_ax + gx - self.ax)
        top = gy * s - (self.out_ay + gy - self.ay)
        out = Image.new('RGBA', (self.out_w, self.out_h), (0, 0, 0, 0))
        out.paste(big, (-int(round(left)), -int(round(top))))
        return out, s

    # ---- composite shapes ---------------------------------------------
    def cylinder(self, cu, cv, z, r, dz, color, steps=3, **kw):
        """Blocky round tower: stacked boxes of one footprint (radius r cells)."""
        self.box(cu - r, cv - r, z, 2 * r, 2 * r, dz, color, **kw)

    def dome(self, cu, cv, z, r, color, layers=5, **kw):
        """Stepped dome from stacked shrinking boxes."""
        for i in range(layers):
            t = 1 - (i / layers) ** 2
            rr = r * max(0.15, math.sqrt(max(0.0, 1 - (i / layers) ** 2)))
            self.box(cu - rr, cv - rr, z + i * 2.0, 2 * rr, 2 * rr, 2.0, color, **kw)

    def pyramid(self, u, v, z, du, dv, color, layers=4, step=2.0, **kw):
        for i in range(layers):
            k = i / layers
            self.box(u + du * k / 2, v + dv * k / 2, z + i * step, du * (1 - k), dv * (1 - k), step, color, **kw)

    def base_slab(self, cols, rows, color, dz=1.5, inset=0.0):
        self.box(inset, inset, 0, cols - 2 * inset, rows - 2 * inset, dz, color, grain=0.04)


def new_image(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def shadow_from(sprite: Image.Image, size, pad_logical=13.33):
    """Soft black silhouette used by the app as the drop shadow. Delivered size
    is `size` (about 0.9 of the padded sprite)."""
    w, h = sprite.size
    pad = int(round(pad_logical * 2))
    a = sprite.split()[3]
    canvas = Image.new('L', (w + 2 * pad, h + 2 * pad), 0)
    canvas.paste(a, (pad, pad))
    canvas = canvas.filter(ImageFilter.GaussianBlur(5))
    canvas = canvas.resize(size, Image.LANCZOS).point(lambda v: min(255, int(v * 0.9)))
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    out.putalpha(canvas)
    return out
