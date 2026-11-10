# Island art generator

Original project work (GPLv3): the Arab-oasis island art is drawn by this script.
No third-party art, font or sample is used.

- Needs Python 3 and Pillow (developed with Pillow 12.3.0 and libwebp 1.6.0). Bytes are reproducible only with the same Pillow and libwebp builds.
- Sizes, anchors and the list of files come from `mobile/test/fixtures/island_pins.json`
  (made from the previous version, so the app layout stays valid).
- `python3 generate.py <out_dir>` writes all 160 webp files into `<out_dir>`.
- `preview.webp` is the finished island rendered by the app itself: `ISLAND_PREVIEW_OUT=x.png flutter test test/island_preview_generator_test.dart`, then `python3 preview_from_png.py x.png mobile/assets/island/preview.webp`.
- Output is deterministic for the same script and Pillow version; the SHA-256 list of the
  delivered files is `mobile/test/fixtures/island_new_art_sha256.txt`.
