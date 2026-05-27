"""
pack.py — Inline all PNG assets into a single self-contained HTML file.
Handles PNGs referenced in both HTML src attributes AND JavaScript strings.
Run from the same directory as the HTML and PNG files:
    python pack.py
"""

import base64, re, os

INPUT_HTML  = "the-hunger-games_final.html"
OUTPUT_HTML = "the-hunger-games_final_PACKED.html"

with open(INPUT_HTML, "r", encoding="utf-8") as f:
    html = f.read()

# Build a map of every unique .png filename found anywhere in the file
found = set(re.findall(r'["\']([^"\']+\.png)["\']', html))
print(f"PNG references found in file: {sorted(found)}\n")

cache = {}  # filename -> data URI (so we encode each file only once)

for src in found:
    if src.startswith("data:") or src.startswith("http"):
        continue
    if not os.path.isfile(src):
        print(f"  ⚠️  Not found on disk, skipping: {src}")
        continue
    with open(src, "rb") as img:
        b64 = base64.b64encode(img.read()).decode("utf-8")
    cache[src] = f"data:image/png;base64,{b64}"
    print(f"  ✅  Packed: {src} ({os.path.getsize(src)//1024} KB raw → {len(b64)//1024} KB base64)")

# Replace every quoted occurrence of each filename with the data URI
for src, data_uri in cache.items():
    # Handles both "file.png" and 'file.png'
    html = html.replace(f'"{src}"', f'"{data_uri}"')
    html = html.replace(f"'{src}'", f"'{data_uri}'")

with open(OUTPUT_HTML, "w", encoding="utf-8") as f:
    f.write(html)

total_kb = os.path.getsize(OUTPUT_HTML) // 1024
print(f"\nDone! Saved as: {OUTPUT_HTML}  ({total_kb} KB total)")