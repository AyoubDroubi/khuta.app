"""Turns the PNG rendered by mobile/test/island_preview_generator_test.dart
(ISLAND_PREVIEW_OUT=<png> flutter test test/island_preview_generator_test.dart)
into mobile/assets/island/preview.webp: the sea backdrop (a known vertical
gradient) becomes transparent and the picture is cropped to the island."""
import sys

import numpy as np
from PIL import Image, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGBA')
a = np.array(im).astype(float)
H, W = a.shape[:2]
top = np.array([0x7A, 0xCC, 0xEA], float)
deep = np.array([0x2C, 0x86, 0xB4], float)
t = (np.arange(H) / (H - 1))[:, None, None]
bg = np.broadcast_to(top * (1 - t) + deep * t, (H, W, 3))
mask = np.abs(a[:, :, :3] - bg).max(axis=2) <= 3
alpha = Image.fromarray(np.where(mask, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
out = im.copy()
out.putalpha(alpha)
out = out.crop(out.getbbox())
out.save(dst, 'WEBP', quality=88, method=6)
