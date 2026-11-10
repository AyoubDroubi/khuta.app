"""Generate every island image into <out_dir>. Usage:
    python3 generate.py <out_dir> [--sheets <sheet_dir>]
"""
from __future__ import annotations

import hashlib
import os
import sys

from PIL import Image

import buildings
import plants_props
import terrain
from common import PINS, SPRITES
from iso import shadow_from
from sheet import contact_sheet

BUILDERS = {**plants_props.BUILDERS, **buildings.BUILDERS}


def generate(out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    sizes = PINS['imageSizes']
    images: dict[str, Image.Image] = {}
    for name, im in terrain.all_tiles():
        images[name] = im
    sprites = {}
    shadows_done = set()
    for key, spec in SPRITES.items():
        base, _, variant = key.partition('__')
        canvas = BUILDERS[base](key, variant)
        im, scale = canvas.finish()
        images[key] = im
        sprites[key] = im
        sb = spec['base']
        if sb and sb not in shadows_done:
            shadows_done.add(sb)
            images['s_' + sb] = shadow_from(im, tuple(sizes['s_' + sb]))
    for name, im in images.items():
        want = tuple(sizes[name])
        assert im.size == want, (name, im.size, want)
        im.save(os.path.join(out_dir, name + '.webp'), 'WEBP', quality=90, method=6)
    assert set(images) == set(sizes), set(sizes) ^ set(images)
    return images, sprites


GROUPS = {
    '02-plants-rocks-props': ['cypress', 'olive', 'agave', 'bougainvillea', 'flower_pot', 'terracotta_pot', 'boulder', 'large_rock', 'rocks',
                              'pebbles', 'flat_stone', 'mossy_stone', 'stone_pile', 'crate', 'storage_box', 'hay_bale', 'wood_pile',
                              'water_bucket', 'pottery_jar', 'crop_patch', 'garden_bed', 'veg_garden'],
    '03-buildings': ['house', 'cube_house', 'terrace_house', 'two_story', 'pergola_house', 'villa', 'main_chapel', 'tower_chapel', 'windmill', 'altar'],
    '04-structures-lights': ['archway', 'small_bridge', 'stone_basin', 'well', 'lantern_post', 'stone_lantern', 'hanging_lantern', 'signpost',
                             'banner', 'bench', 'blue_railing'],
}


def sheets(sprites, out):
    os.makedirs(out, exist_ok=True)
    for name, bases in GROUPS.items():
        pick = {k: v for k, v in sprites.items() if k.split('__')[0] in bases}
        contact_sheet(pick, os.path.join(out, name + '.png'), cols=8 if '03' not in name else 5)


if __name__ == '__main__':
    out = sys.argv[1]
    images, sprites = generate(out)
    if '--sheets' in sys.argv:
        sheets(sprites, sys.argv[sys.argv.index('--sheets') + 1])
    lines = []
    for name in sorted(images):
        data = open(os.path.join(out, name + '.webp'), 'rb').read()
        lines.append(f'{hashlib.sha256(data).hexdigest()}  {name}.webp  {images[name].width}x{images[name].height}')
    open(os.path.join(out, 'SHA256.txt'), 'w').write('\n'.join(lines) + '\n')
    print(len(images), 'files')
