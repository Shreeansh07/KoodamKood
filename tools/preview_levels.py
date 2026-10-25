#!/usr/bin/env python3
"""Renders terrain + objects of each level to tools/preview_<theme>.png using the
SAME tile-selection rules as scripts/TerrainBuilder.gd (keep them in sync)."""
import json, os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, "..")
A = lambda p: Image.open(os.path.join(ROOT, "assets", p)).convert("RGBA")
PP, TD, CH = A("pixel_platformer/tiles.png"), A("tiny_dungeon/tiles.png"), A("pixel_platformer/characters.png")
BK, SL, CN = A("brackeys/world_tileset.png"), A("brackeys/slime_green.png"), A("brackeys/coin.png")
def bk(i): return BK.crop(((i % 16) * 16, (i // 16) * 16, (i % 16) * 16 + 16, (i // 16) * 16 + 16)).resize((18, 18), Image.NEAREST)
def pp(i): return PP.crop(((i % 20) * 18, (i // 20) * 18, (i % 20) * 18 + 18, (i // 20) * 18 + 18))
def td(i): return TD.crop(((i % 12) * 16, (i // 12) * 16, (i % 12) * 16 + 16, (i // 12) * 16 + 16)).resize((18, 18), Image.NEAREST)
def ch(i): return CH.crop(((i % 9) * 24, (i // 9) * 24, (i % 9) * 24 + 24, (i // 9) * 24 + 24))

# theme -> (atlas fn, top_with_bottom_outline[4], top_open_below[4], fill_open_below[4], fill_with_bottom[4])
# column order: [alone, left-cap, middle, right-cap]
THEMES = {
  "earth":  (pp, [0, 1, 2, 3], [20, 21, 22, 23], [120, 121, 122, 123], [140, 141, 142, 143]),
  "heaven": (pp, [80, 81, 82, 83], [100, 101, 102, 103], [120, 121, 122, 123], [140, 141, 142, 143]),
  "hell":   (td, [50, 51, 51, 50], [50, 51, 51, 50], [48, 49, 49, 48], [48, 49, 49, 48]),
}
def solid(rows, c, r):
    if c < 0 or c >= len(rows[0]): return True
    if r < 0: return False
    if r >= len(rows): return True
    return rows[r][c] == "#"
BRICKS = [14, 40, 57]
def depth(rows, c, r):
    d = 0
    while r - d - 1 >= 0 and rows[r - d - 1][c] == "#": d += 1
    return d
def pick(theme, rows, c, r):
    if theme == "earth":
        up = solid(rows, c, r - 1)
        return bk, (0 if not up else (17 if (c * 13 + r * 7) % 5 == 0 else 16))
    if theme == "hell":      # sand cap (2 rows) over a brick body; 1-thick platforms are pure brick
        d, dn = depth(rows, c, r), solid(rows, c, r + 1)
        if d == 0 and not dn: return td, BRICKS[(c * 7 + r) % 3]
        if d == 0: return td, (50 if (c % 2 == 0) else 51)
        if d == 1: return td, (48 if (c % 3) else 49)
        return td, BRICKS[(c * 7 + r) % 3]
    fn, top_b, top_o, fill_o, fill_b = THEMES[theme]
    l, rt, up, dn = solid(rows, c-1, r), solid(rows, c+1, r), solid(rows, c, r-1), solid(rows, c, r+1)
    k = 2 if (l and rt) else (1 if (not l and rt) else (3 if (l and not rt) else 0))
    if not up: return fn, (top_o if dn else top_b)[k]
    return fn, (fill_o if dn else fill_b)[k]

if __name__ == "__main__":
    for theme in ("earth", "heaven", "hell"):
        d = json.load(open(os.path.join(ROOT, "levels", theme + ".json")))
        W, H = d["width"], d["height"]; rows = d["rows"]
        bg = {"earth": (140, 205, 235), "heaven": (200, 235, 245), "hell": (40, 18, 22)}[theme]
        img = Image.new("RGBA", (W * 18, H * 18), bg + (255,))
        for r in range(H):
            for c in range(W):
                if rows[r][c] == "#":
                    fn, i = pick(theme, rows, c, r); img.alpha_composite(fn(i), (c * 18, r * 18))
        for o in d["objects"]:
            x, y, t = o["c"] * 18, o["r"] * 18, o["type"]
            if t == "coin":
                if theme == "hell": img.alpha_composite(pp(67), (x, y))
                else: img.alpha_composite(CN.crop((0, 0, 16, 16)), (x + 1, y + 1))
            elif t == "spikes": img.alpha_composite(pp(68), (x, y))
            elif t in ("walker", "hopper") and theme == "earth":
                img.alpha_composite(SL.crop((0, 0, 24, 24)), (x - 3, y - 5))
            elif t == "walker": img.alpha_composite(ch(18 if theme == "heaven" else 13).resize((18, 18)), (x, y))
            elif t == "flyer": img.alpha_composite(ch(24).resize((18, 18)), (x, y))
            elif t == "lift":
                for k in range(-1, 2): img.alpha_composite(pp(146), (x + k * 18, y))
                for rr in range(o["r"] - o["rise"], o["r"]): img.alpha_composite(pp(89), (x, rr * 18))
            elif t == "goal": img.alpha_composite(pp(111), (x, y))
            elif t == "deco":
                if "tiles" in o:
                    for k, ti in enumerate(o["tiles"]): img.alpha_composite(bk(ti), (x, y - k * 18))
                else: img.alpha_composite(pp(o["tile"]), (x, y))
            elif t in ("cloud", "cloud_move", "cloud_vmove"):
                for k in range(o["w"]): img.alpha_composite(pp(146), (x + k * 18, y))
        img.save(os.path.join(HERE, f"preview_{theme}.png"))
    print("previews written")
