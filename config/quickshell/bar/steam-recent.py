#!/usr/bin/env python3
"""Imprime en JSON los juegos de Steam jugados recientemente (más reciente primero)."""
import glob, json, os, re, sys

root = os.path.expanduser("~/.local/share/Steam")
cache = os.path.join(root, "appcache/librarycache")
limit = int(sys.argv[1]) if len(sys.argv) > 1 else 6

def art(appid):
    # preferimos la portada vertical (600x900); si no, cualquier imagen decente
    for pat in ("library_600x900.jpg", "library_capsule.jpg", "library_header.jpg", "header.jpg", "library_hero.jpg"):
        hits = glob.glob(os.path.join(cache, appid, "**", pat), recursive=True)
        if hits:
            return hits[0]
    return ""

games = []
for f in glob.glob(os.path.join(root, "steamapps/appmanifest_*.acf")):
    try:
        t = open(f, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    def val(k):
        m = re.search(r'"%s"\s+"([^"]*)"' % k, t)
        return m.group(1) if m else ""
    last = int(val("LastPlayed") or 0)
    name = val("name")
    if last <= 0 or re.search(r"Proton|Steam Linux Runtime|Steamworks", name):
        continue
    appid = val("appid")
    games.append({"id": appid, "name": name, "last": last, "art": art(appid)})

games.sort(key=lambda g: g["last"], reverse=True)
print(json.dumps(games[:limit]))
