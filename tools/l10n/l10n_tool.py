#!/usr/bin/env python3
"""Helpers for the app translations (mobile/lib/l10n/app_<lang>.arb).

  missing <lang> [out.json]   keys the language lacks, with the English text
  merge <lang> <in.json>      add translations for missing keys (validated)
  check                       every language has every key and the same placeholders
"""
import json
import re
import sys
from pathlib import Path

L10N = Path(__file__).resolve().parents[2] / "mobile" / "lib" / "l10n"
NAME = re.compile(r"\{([A-Za-z_]\w*)\s*[,}]")


def load(lang):
    return json.loads((L10N / f"app_{lang}.arb").read_text(encoding="utf-8"))


def keys(data):
    return [k for k in data if not k.startswith("@")]


def blank(data, key):
    value = data.get(key)
    return value is None or (isinstance(value, str) and not value.strip())


def names(text):
    return set(NAME.findall(text))


def problems(lang, en, data):
    out = []
    for key in keys(en):
        if blank(data, key) and (not isinstance(en[key], str) or en[key].strip()):
            out.append(f"{lang}: missing {key}")
        elif isinstance(en[key], str):
            if not isinstance(data[key], str):
                out.append(f"{lang}: {key} is not a string")
            elif names(data[key]) != names(en[key]):
                out.append(f"{lang}: {key} placeholders {sorted(names(data[key]))} != {sorted(names(en[key]))}")
    return out


def cmd_missing(lang, out=None):
    en, data = load("en"), load(lang)
    todo = {k: en[k] for k in keys(en) if blank(data, k) and str(en[k]).strip()}
    text = json.dumps(todo, ensure_ascii=False, indent=1)
    if out:
        Path(out).write_text(text, encoding="utf-8")
    else:
        print(text)
    print(f"{lang}: {len(todo)} missing", file=sys.stderr)


def cmd_merge(lang, src):
    en, data = load("en"), load(lang)
    new = json.loads(Path(src).read_text(encoding="utf-8"))
    bad = []
    for key, value in new.items():
        if key not in en or key.startswith("@"):
            bad.append(f"unknown key {key}")
        elif not isinstance(value, str) or not value.strip():
            bad.append(f"{key}: empty")
        elif names(value) != names(en[key]):
            bad.append(f"{key}: placeholders {sorted(names(value))} != {sorted(names(en[key]))}")
    if bad:
        print("\n".join(bad[:50]))
        sys.exit(f"{len(bad)} problems; nothing written")
    merged = {}
    for key, value in en.items():
        if key == "@@locale":
            merged[key] = data.get(key, lang)
        elif key.startswith("@"):
            base = key[1:]
            if base in data or base in new:
                merged[key] = data.get(key, en[key])
        elif key in data and not (key in new and blank(data, key)):
            merged[key] = data[key]
            if f"@{key}" in data:
                merged[f"@{key}"] = data[f"@{key}"]
        elif key in new:
            merged[key] = new[key]
            if f"@{key}" in data:
                merged[f"@{key}"] = data[f"@{key}"]
    for key, value in data.items():  # keep anything not in English untouched
        merged.setdefault(key, value)
    (L10N / f"app_{lang}.arb").write_text(
        json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{lang}: merged {len(new)} strings")


def cmd_check():
    en = load("en")
    found = []
    for f in sorted(L10N.glob("app_*.arb")):
        lang = f.stem[4:]
        if lang != "en":
            found += problems(lang, en, load(lang))
    print("\n".join(found[:100]) or "ok")
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["missing"]:
        cmd_missing(*args[1:])
    elif args[:1] == ["merge"]:
        cmd_merge(*args[1:])
    elif args[:1] == ["check"]:
        cmd_check()
    else:
        sys.exit(__doc__)
