#!/usr/bin/env python3
"""Búsqueda de canciones en Spotify (flujo client-credentials, sin iniciar sesión).
Uso: spotify-search.py "texto"
Salida: primera línea OK o "ERR <motivo>"; luego una pista por línea, separada por tabuladores:
        uri  título  artista  álbum  portada  duración_ms
Credenciales en ~/.config/hypr/spotify-api.json: {"client_id": "...", "client_secret": "..."}"""
import base64, json, os, sys, time, urllib.parse, urllib.request, urllib.error

HOME = os.path.expanduser("~")
CRED = os.path.join(HOME, ".config/hypr/spotify-api.json")
TOKEN = os.path.join(HOME, ".cache/cubi/spotify-token.json")
UA = {"User-Agent": "cubi-shell/1.0"}


def fail(why):
    print("ERR " + why)
    sys.exit(0)


def token():
    try:
        t = json.load(open(TOKEN))
        if t["exp"] > time.time() + 30:
            return t["token"]
    except Exception:
        pass
    try:
        c = json.load(open(CRED))
        cid, sec = c["client_id"].strip(), c["client_secret"].strip()
    except Exception:
        fail("nocreds")
    if not cid or not sec or cid.startswith("PEGA"):
        fail("nocreds")
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=b"grant_type=client_credentials",
        headers={**UA, "Authorization": "Basic " + base64.b64encode(f"{cid}:{sec}".encode()).decode()},
    )
    try:
        r = json.load(urllib.request.urlopen(req, timeout=10))
    except urllib.error.HTTPError:
        fail("auth")
    except Exception:
        fail("net")
    os.makedirs(os.path.dirname(TOKEN), exist_ok=True)
    json.dump({"token": r["access_token"], "exp": time.time() + r.get("expires_in", 3600)}, open(TOKEN, "w"))
    return r["access_token"]


def main():
    q = " ".join(sys.argv[1:]).strip()
    if not q:
        fail("empty")
    tk = token()
    url = "https://api.spotify.com/v1/search?" + urllib.parse.urlencode({"q": q, "type": "track", "limit": 8})
    try:
        d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={**UA, "Authorization": "Bearer " + tk}), timeout=10))
    except urllib.error.HTTPError as e:
        if e.code == 401:
            try:
                os.remove(TOKEN)
            except OSError:
                pass
            fail("auth")
        fail("http%d" % e.code)
    except Exception:
        fail("net")
    print("OK")
    for t in d.get("tracks", {}).get("items", []):
        imgs = t["album"].get("images", [])
        art = (imgs[-2] if len(imgs) > 1 else imgs[0])["url"] if imgs else ""
        clean = lambda s: str(s).replace("\t", " ").replace("\n", " ")
        print("\t".join([t["uri"], clean(t["name"]), clean(", ".join(a["name"] for a in t["artists"])),
                         clean(t["album"]["name"]), art, str(t.get("duration_ms", 0))]))


main()
