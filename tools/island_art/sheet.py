import sys
from PIL import Image
from common import SPRITES


def contact_sheet(images: dict, path, cols=8, bg=(38, 42, 50, 255), label=False):
    names = list(images)
    cw = max(i.width for i in images.values()) + 12
    ch = max(i.height for i in images.values()) + 12
    rows = (len(names) + cols - 1) // cols
    S = Image.new('RGBA', (cw * cols, ch * rows), bg)
    for k, n in enumerate(names):
        im = images[n]
        S.alpha_composite(im, ((k % cols) * cw + 6 + (cw - 12 - im.width) // 2, (k // cols) * ch + 6 + (ch - 12 - im.height)))
    S.save(path)
