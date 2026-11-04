#!/usr/bin/env python3
"""Genera themes/wallpaper.json (tema oscuro) con colores extraídos del fondo de escritorio actual,
y actualiza themes/index.json. Uso: wallpaper_theme.py [imagen]   (sin argumento usa el fondo activo)."""
import colorsys, json, math, os, subprocess, sys
from PIL import Image
H = os.path.expanduser("~")
R = f"{H}/.config/rice"

def current_wallpaper():
    st = dict(l.strip().split("=", 1) for l in open(f"{H}/.config/hypr/wallpaper.state") if "=" in l)
    kind, name = st.get("DESKTOP_KIND", "image"), st.get("DESKTOP", "")
    if kind == "image":
        p = f"{H}/Imágenes/Wallpapers/{name}-1440p.png"
        if os.path.exists(p): return p
    thumb = f"{H}/.cache/cubi/thumbs/v-{name}.jpg"
    if os.path.exists(thumb): return thumb
    vid = f"{H}/Videos/Wallpapers/{name}-1080p.mp4"
    out = "/tmp/rice-wall-frame.jpg"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", "3", "-i", vid, "-frames:v", "1", out])
    return out

src = sys.argv[1] if len(sys.argv) > 1 else current_wallpaper()
im = Image.open(src).convert("RGB"); im.thumbnail((128, 128))

# Histograma de tonos ponderado por saturación y luminosidad (ignora grises, negros y blancos)
bins = [0.0] * 36
for r, g, b in im.getdata():
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if s < 0.18 or v < 0.18 or v > 0.97: continue
    bins[int(h * 36) % 36] += s * v
sm = [sum(bins[(i + d) % 36] * (1.0 if d == 0 else 0.5) for d in (-1, 0, 1)) for i in range(36)]
tot = sum(sm)
if tot < 1e-6:                      # imagen casi gris: usa el tono medio general
    avg = im.resize((1, 1)).getpixel((0, 0)); H1 = colorsys.rgb_to_hsv(*[c / 255 for c in avg])[0] * 360; H2 = (H1 + 150) % 360
else:
    i1 = max(range(36), key=lambda i: sm[i]); H1 = i1 * 10 + 5
    far = [i for i in range(36) if min(abs(i - i1), 36 - abs(i - i1)) >= 4]
    i2 = max(far, key=lambda i: sm[i])
    H2 = i2 * 10 + 5 if sm[i2] > 0.18 * sm[i1] else (H1 + 150) % 360

def hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360, l, s)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))
def mix(a, b, t):
    A = [int(a[i:i+2], 16) for i in (1, 3, 5)]; B = [int(b[i:i+2], 16) for i in (1, 3, 5)]
    return "#" + "".join("%02x" % round(x + (y - x) * t) for x, y in zip(A, B))

base, dark, surf = hsl(H1, 0.26, 0.10), hsl(H1, 0.30, 0.065), hsl(H1, 0.24, 0.15)
text, dim = hsl(H1, 0.35, 0.89), hsl(H1, 0.16, 0.62)
acc, acc2 = hsl(H1, 0.80, 0.72), hsl(H2, 0.70, 0.74)
cy, gr, ye, orr, red = hsl(190, 0.70, 0.72), hsl(100, 0.55, 0.68), hsl(42, 0.78, 0.72), hsl(24, 0.85, 0.70), hsl(350, 0.80, 0.72)
colors = dict(base=base, bgDark=dark, surface=surf, text=text, dim=dim, accent=acc, accent2=acc2, cyan=cy, green=gr,
              yellow=ye, orange=orr, red=red, ink=dark, line=mix(base, text, 0.12), selection=mix(base, acc, 0.30), url=cy)
ansi = [surf, red, gr, ye, acc, acc2, cy, text, dim, red, gr, ye, acc, acc2, cy, text]
th = dict(id="wallpaper", name="Fondo (auto)", description="Paleta generada desde el fondo de escritorio actual.", colors=colors, ansi=ansi)
os.makedirs(f"{R}/themes", exist_ok=True)
json.dump(th, open(f"{R}/themes/wallpaper.json", "w"), indent=2, ensure_ascii=False)

# índice del selector
ip = f"{R}/themes/index.json"
idx = [e for e in json.load(open(ip)) if e["id"] != "wallpaper"] if os.path.exists(ip) else []
idx.append(dict(id="wallpaper", name=th["name"], description=th["description"], base=base, text=text, accent=acc,
                accent2=acc2, green=gr, yellow=ye, red=red))
json.dump(idx, open(ip, "w"), indent=1, ensure_ascii=False)
print(f"Tema desde fondo: {os.path.basename(src)} → tonos {H1:.0f}° y {H2:.0f}°, acento {acc}")
