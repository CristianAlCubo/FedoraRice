#!/usr/bin/env python3
"""Genera los presets de ~/.config/rice/themes/*.json y el índice index.json.
Edita aquí una paleta y vuelve a ejecutar, o edita directamente el JSON del preset."""
import json, os
D = os.path.expanduser("~/.config/rice/themes"); os.makedirs(D, exist_ok=True)

def mix(a, b, t):
    A = [int(a[i:i+2], 16) for i in (1, 3, 5)]; B = [int(b[i:i+2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(A, B))

# id: (nombre, descripción, base, bgDark, surface, text, dim, accent, accent2, cyan, green, yellow, orange, red, [line, selection] opcional)
T = {
 "catppuccin": ("Catppuccin", "Soothing pastel theme for the high-spirited.", "#1e1e2e","#181825","#313244","#cdd6f4","#7f849c","#89b4fa","#cba6f7","#89dceb","#a6e3a1","#f9e2af","#fab387","#f38ba8","#313244","#45475a"),
 "gruvbox": ("Gruvbox", "Retro groove color scheme.", "#282828","#1d2021","#3c3836","#ebdbb2","#928374","#83a598","#d3869b","#8ec07c","#b8bb26","#fabd2f","#fe8019","#fb4934","#3c3836","#504945"),
 "nord": ("Nord", "Arctic, north-bluish color palette.", "#2e3440","#242933","#3b4252","#d8dee9","#7b88a1","#88c0d0","#b48ead","#8fbcbb","#a3be8c","#ebcb8b","#d08770","#bf616a","#3b4252","#434c5e"),
 "everforest": ("Everforest", "Comfortable and pleasant green forest color scheme.", "#2d353b","#232a2e","#343f44","#d3c6aa","#859289","#a7c080","#d699b6","#83c092","#a7c080","#dbbc7f","#e69875","#e67e80","#3d484d","#475258"),
 "dracula": ("Dracula", "Dark spooky theme.", "#282a36","#21222c","#343746","#f8f8f2","#6272a4","#bd93f9","#ff79c6","#8be9fd","#50fa7b","#f1fa8c","#ffb86c","#ff5555","#44475a","#44475a"),
 "rose-pine": ("Rosé Pine", "All natural pine, faux fur and a bit of soho vibes for the classy minimalist.", "#191724","#13111e","#1f1d2e","#e0def4","#6e6a86","#c4a7e7","#ebbcba","#9ccfd8","#3e8fb0","#f6c177","#ebbcba","#eb6f92","#26233a","#403d52"),
 "tokyo-night": ("Tokyo Night", "Clean, dark theme that celebrates the lights of Tokyo at night.", "#1a1b26","#16161e","#24283b","#c0caf5","#737aa2","#7aa2f7","#bb9af7","#7dcfff","#9ece6a","#e0af68","#ff9e64","#f7768e","#292e42","#33467c"),
 "sweet": ("Sweet", "Colorful candy theme.", "#161925","#10121b","#1f2335","#c3c7d1","#6b7089","#c74ded","#ff6bcb","#00c1e4","#5ee3a1","#f2e968","#f69c5e","#f20055"),
 "kanagawa": ("Kanagawa", "Dark color scheme inspired by the famous painting.", "#1f1f28","#16161d","#2a2a37","#dcd7ba","#727169","#7e9cd8","#957fb8","#7fb4ca","#98bb6c","#e6c384","#ffa066","#e46876","#363646","#2d4f67"),
 "blacklotus": ("BlackLotus", "Dark, dim, blue, purple... beautiful.", "#0f0f1a","#0a0a12","#1a1a2e","#c8c8e8","#6a6a8e","#7b8cff","#b48bff","#6cd0ff","#7ee0a8","#e6c27a","#f0a070","#ff6b8a"),
 "whale": ("Whale", "Dark theme inspired by Ark and Nord.", "#232b36","#1a2029","#2d3745","#d8dee9","#6f7f96","#62b6e3","#a98fd6","#7fd1d1","#8fcf9a","#e3c77c","#e09a6c","#e0707e"),
 "everblush": ("Everblush", "Dark, vibrant and beautiful Colorscheme.", "#141b1e","#0f1518","#232a2d","#dadada","#5c6a70","#67b0e8","#c47fd5","#6cbfbf","#8ccf7e","#e5c76b","#e59a6b","#e57474","#2d3437","#2d3437"),
 "shades-of-purple": ("Shades of Purple", "Sweet purple theme.", "#2d2b55","#1e1e3f","#3a3868","#f4f0ff","#a599e9","#b362ff","#ff628c","#9effff","#3ad900","#fad000","#ff9d00","#ec3a37","#4d4a8f","#5a4fa0"),
 "opulo": ("opulo", "Colorscheme for absolute nerds.", "#0b0e14","#070a0f","#151a23","#c5cdd9","#5c6773","#73d0ff","#d4bfff","#95e6cb","#aad94c","#ffb454","#ff8f40","#f07178"),
 "camellia": ("Camellia", "Dark yet vibrant color scheme.", "#1c1b22","#151419","#26242d","#e6dfe8","#8a8194","#ff6b9d","#c792ea","#7fdbca","#a9dc76","#ffd866","#fc9867","#ff6188"),
}
idx = []
for k, v in T.items():
    n, d, base, dark, surf, text, dim, acc, acc2, cy, gr, ye, orr, red = v[:14]
    line = v[14] if len(v) > 14 else mix(base, text, 0.12)
    sel  = v[15] if len(v) > 15 else mix(base, acc, 0.30)
    colors = dict(base=base, bgDark=dark, surface=surf, text=text, dim=dim, accent=acc, accent2=acc2,
                  cyan=cy, green=gr, yellow=ye, orange=orr, red=red, ink=dark, line=line, selection=sel, url=cy)
    ansi = [surf, red, gr, ye, acc, acc2, cy, text, dim, red, gr, ye, acc, acc2, cy, text]
    json.dump(dict(id=k, name=n, description=d, colors=colors, ansi=ansi), open(f"{D}/{k}.json", "w"), indent=2, ensure_ascii=False)
    idx.append(dict(id=k, name=n, description=d, base=base, text=text, accent=acc, accent2=acc2, green=gr, yellow=ye, red=red))
wp = f"{D}/wallpaper.json"
if os.path.exists(wp):                      # el tema generado desde el fondo se conserva
    w = json.load(open(wp)); c = w["colors"]
    idx.append(dict(id="wallpaper", name=w["name"], description=w["description"], base=c["base"], text=c["text"],
                    accent=c["accent"], accent2=c["accent2"], green=c["green"], yellow=c["yellow"], red=c["red"]))
json.dump(idx, open(f"{D}/index.json", "w"), indent=1, ensure_ascii=False)
print(len(idx), "temas")
