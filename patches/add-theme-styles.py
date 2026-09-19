#!/usr/bin/env python3
"""Give the STANDARD 'simple' theme the same extra color styles that the
'privau' theme already carries.

How it works: in SearXNG's compiled theme CSS each style is a block of CSS
custom properties under ``:root.theme-<style>``.  The standard upstream
'simple' build only bundles ``auto``/``dark``/``black``; the privau fork's
build bundles all 20.  Since the fork shares the same markup and the same
``--color-*`` variable names, we can re-use the already-compiled blocks:
this script extracts every ``:root.theme-<style>`` block (plus the matching
``<select>`` arrow rules) from the privau CSS and appends it to the simple CSS.

Usage:
    python3 patches/add-theme-styles.py [SEARXNG_SRC]
    (default SEARXNG_SRC=$HOME/searxng-src)

The script requires the 'privau' theme static to be present (see
apply-patches.sh).  idempotent: safe to run repeatedly.
"""
import re
import sys

WANT = {"auto", "light", "dark", "black", "paulgo", "latte", "frappe", "macchiato",
        "mocha", "kagi", "brave", "moa", "night", "dracula", "gruvbox", "gruvboxmat",
        "everforest", "evergarden", "nord", "matcha"}
SKIP = {"auto", "dark"}
MARKER = "/* extra theme styles added by Trusted Search Termux */"


def _themes_dir(src):
    return f"{src}/searx/static/themes"


def extract_blocks(css, styles):
    """Yield (rule_text) for the wanted styles: the :root.theme-* blocks and the
    grouped ``html.theme-* select`` arrow rules."""
    out = []
    for m in re.finditer(r':root\.theme-([a-zA-Z0-9_-]+)\s*\{', css):
        name = m.group(1)
        if name not in styles:
            continue
        depth = 0
        for j in range(m.end() - 1, len(css)):
            if css[j] == '{':
                depth += 1
            elif css[j] == '}':
                depth -= 1
                if depth == 0:
                    break
        out.append(css[m.start():j + 1])

    for m in re.finditer(r'html\.theme-([a-zA-Z0-9_-]+)', css):
        name = m.group(1)
        if name not in styles or name in SKIP:
            continue
        start = m.start()
        mm = re.search(r'@media[^{]*\{', css[:start])
        if mm is not None and css.rfind('}', mm.start(), start) < mm.start():
            rule_start = mm.start()  # inside an open @media wrapper
        else:
            rule_start = start
        i = css.find('{', start)
        depth = 0
        for j in range(i, len(css)):
            if css[j] == '{':
                depth += 1
            elif css[j] == '}':
                depth -= 1
                if depth == 0:
                    break
        text = css[rule_start:j + 1]
        head = text.split('{', 1)[0]
        if ' select' not in head:
            continue
        if re.search(r'theme-(?:auto|dark)\b', head):
            continue
        if not any((n + ' select') in head for n in styles):
            continue
        if all(existing != text for existing in out):
            out.append(text)
    return out


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/data/data/com.termux/files/home/searxng-src"
    td = _themes_dir(src)
    ok = True
    for variant in ("sxng-ltr", "sxng-rtl"):
        with open(f"{td}/privau/{variant}.min.css") as f:
            privau = f.read()
        path = f"{td}/simple/{variant}.min.css"
        with open(path) as f:
            simple = f.read()

        have = set(re.findall(r':root\.theme-([a-zA-Z0-9_-]+)\b', simple))
        styles = WANT - have
        if not styles:
            print(f"[{variant}] already complete ({len(have)} styles), nothing to do")
            continue
        if MARKER in simple:
            print(f"[{variant}] already patched but missing {sorted(styles)}; re-extracting clean")
            simple = simple.split(MARKER, 1)[0].rstrip(" \n")
        blocks = extract_blocks(privau, styles)
        names = sorted({b[:25] for b in blocks if b.startswith(':root')})
        print(f"[{variant}] appending blocks for: {sorted({n.split('.')[1].split('{')[0] for n in names})}")
        with open(path, "w") as f:
            f.write(simple.rstrip(" \n") + "\n" + MARKER + "\n" + "\n".join(blocks) + "\n")
        with open(path) as f:
            final = f.read()
        have = sorted(set(re.findall(r':root\.theme-([a-zA-Z0-9_-]+)\b', final)))
        assert final.count('{') == final.count('}'), "unbalanced braces"
        print(f"[{variant}] after: {len(have)} styles")
        if set(WANT) - set(have):
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())