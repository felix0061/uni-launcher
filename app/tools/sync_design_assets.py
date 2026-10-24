#!/usr/bin/env python3
"""Export this repository's original design symbols for the Flutter renderer."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[2]
out = root / 'app/assets/icons'
out.mkdir(parents=True, exist_ok=True)
source = (root / 'design/index.html').read_text()
for name, view, body in re.findall(r'<symbol id="([^"]+)" viewBox="([^"]+)">(.*?)</symbol>', source, re.S):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">{body.replace("currentColor", "#FFFFFF")}</svg>\n'
    (out / f'{name}.svg').write_text(svg)
art = re.search(r'const art = `(.*?)`;', (root / 'design/study.js').read_text(), re.S)[1]
(root / 'app/assets/art/cover.svg').write_text(art.replace('aria-hidden="true"', 'xmlns="http://www.w3.org/2000/svg"') + '\n')
print(f'Exported {len(list(out.glob("*.svg")))} original symbols and cover artwork')
