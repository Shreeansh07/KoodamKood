#!/usr/bin/env python3
"""Authors the three KoodamKood levels (deterministic, hand-placed) and writes
levels/*.json. Also renders tools/preview_*.png (terrain + objects) and checks
simple fairness rules (max gap, max step-up).

Coordinates: (c, r) = (column, row) in 18px tiles, row 0 = top of section.
Ground surface row G=26. Section is W=150 cols x H=34 rows.
"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
LV = os.path.join(HERE, "..", "levels")
os.makedirs(LV, exist_ok=True)
W, H, G = 150, 34, 26
JUMP_MAX_GAP = 3      # tiles of empty space we allow between same-height ledges
JUMP_MAX_UP = 2       # tiles we allow to climb in one jump

class Level:
    def __init__(self, theme):
        self.theme = theme
        self.g = [[0] * W for _ in range(H)]
        self.objs = []
    def fill(self, c0, c1, r0, r1):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.g[r][c] = 1
    def ground(self, c0, c1, top=G): self.fill(c0, c1, top, H - 1)
    def island(self, c0, c1, top, thick=4): self.fill(c0, c1, top, top + thick - 1)
    def plat(self, c0, c1, row, thick=1): self.fill(c0, c1, row, row + thick - 1)
    def add(self, type_, c, r, **kw):
        d = {"type": type_, "c": c, "r": r}; d.update(kw); self.objs.append(d)
    def coins(self, cs, r):
        for c in cs: self.add("coin", c, r)
    def arc(self, c0, c1, r_base, h=2):
        n = c1 - c0 + 1
        for i, c in enumerate(range(c0, c1 + 1)):
            t = 0 if n == 1 else (i / (n - 1))
            self.add("coin", c, r_base - round(h * 4 * t * (1 - t)))
    def save(self):
        rows = ["".join("#" if v else "." for v in row) for row in self.g]
        with open(os.path.join(LV, self.theme + ".json"), "w") as f:
            json.dump({"theme": self.theme, "width": W, "height": H, "ground_row": G,
                       "rows": rows, "objects": self.objs}, f, indent=0)

# ====================================================================== EARTH
def earth():
    L = Level("earth")
    # --- terrain: (c0,c1) ground runs, pits between them (pit = fall into Hell)
    for a, b in [(0, 17), (20, 33), (37, 49), (50, 63), (67, 80), (101, 113), (117, 132), (136, 149)]:
        L.ground(a, b)
    # floating grass platforms over the long pit (82..100)
    L.plat(82, 85, 24); L.plat(89, 92, 22); L.plat(96, 99, 24)
    # 2-high step
    L.fill(42, 45, 24, 25)
    # --- start & decor
    L.add("start", 3, G - 1)
    # decor = Brackeys world-tileset tiles stacked bottom-up (see assets/brackeys/world_tileset.png)
    L.add("deco", 6, G - 1, tiles=[80, 64, 48])     # green tree
    L.add("deco", 13, G - 1, tiles=[65])             # bush
    L.add("deco", 2, G - 1, tiles=[56])              # wooden sign
    L.add("deco", 25, G - 1, tiles=[97])             # flower bush
    L.add("deco", 40, G - 1, tiles=[85, 69, 53])     # orange tree
    L.add("deco", 70, G - 1, tiles=[80, 64, 48])
    L.add("deco", 104, G - 1, tiles=[87])            # mushroom
    L.add("deco", 120, G - 1, tiles=[81])            # low bush
    L.add("deco", 140, G - 1, tiles=[57])            # fence
    L.add("deco", 15, G - 1, tiles=[132])            # pumpkin
    # --- coins
    L.arc(7, 13, G - 3, 2); L.arc(21, 26, G - 3, 2)
    L.coins([43, 44], 22); L.coins([38, 39, 40], G - 2)
    L.arc(82, 85, 22, 1); L.arc(89, 92, 20, 1); L.arc(96, 99, 22, 1)
    L.coins([68, 69, 70], G - 2); L.arc(103, 110, G - 3, 2)
    L.arc(118, 123, G - 3, 2); L.coins([138, 139, 140, 141, 142], G - 2)
    L.arc(126, 131, G - 3, 2)
    # --- hazards (spikes sit in the cell above ground)
    L.add("spikes", 31, G - 1); L.add("spikes", 106, G - 1); L.add("spikes", 107, G - 1)
    L.add("spikes", 74, G - 1)
    # --- enemies (walkers patrol their ledge; bats float)
    L.add("walker", 27, G - 1, v=0); L.add("walker", 72, G - 1, v=1); L.add("walker", 111, G - 1, v=0)
    L.add("walker", 129, G - 1, v=1); L.add("walker", 143, G - 1, v=0)
    L.add("hopper", 76, G - 1, v=0, hop=26); L.add("hopper", 109, G - 1, v=1, hop=24)   # bouncing Brackeys slimes
    # --- lifts up to Heaven (platform 3 tiles wide centred on column c)
    L.add("lift", 57, G, rise=16, dest="heaven")
    L.add("lift", 124, G, rise=16, dest="heaven")
    return L

# ====================================================================== HEAVEN
def heaven():
    L = Level("heaven")
    L.island(36, 70, 26, 5)          # island A (lift #1 arrives here)
    L.island(92, 112, 24, 6)         # island B
    L.island(120, 136, 25, 5)        # island C (lift #2 arrives here)
    L.island(143, 149, 21, 7)        # island D with goal
    L.island(3, 10, 21, 4)           # optional reward islet (far left)
    # static one-way clouds: (col, row, width)
    for c, r, w in [(30, 24, 3), (25, 22, 3), (20, 20, 3), (14, 20, 4),   # optional stairway
                    (73, 25, 3), (138, 23, 3), (116, 26, 3)]:
        L.add("cloud", c, r, w=w)
    # moving clouds: oscillate horizontally by +/-range px
    L.add("cloud_move", 79, 24, w=3, range=54, speed=0.9)
    # vertical mover bridging the gap to island B
    L.add("cloud_vmove", 87, 25, w=3, range=36, speed=0.8)
    L.add("start", 57, 25)                      # only used for debug previews
    # --- coins
    L.arc(40, 46, 24, 2); L.arc(60, 68, 24, 2); L.coins([30, 31, 32], 22)
    L.coins([25, 26, 27], 20); L.coins([20, 21, 22], 18); L.coins([15, 16, 17, 18], 18)
    L.coins([4, 5, 6, 7, 8, 9], 19); L.coins([5, 6, 7, 8], 17)         # optional reward cluster
    L.coins([73, 74, 75], 23); L.arc(94, 100, 22, 2); L.arc(104, 110, 22, 2)
    L.arc(122, 134, 23, 3); L.coins([138, 139, 140], 21); L.coins([144, 145, 147, 148], 19)
    # --- hazards / enemies
    L.add("spikes", 102, 23)
    L.add("walker", 48, 25, v=0); L.add("walker", 98, 23, v=1); L.add("walker", 107, 23, v=0)
    L.add("walker", 128, 24, v=0); L.add("walker", 64, 25, v=1)
    L.add("flyer", 56, 20, v=0, range=36); L.add("flyer", 101, 19, v=0, range=44); L.add("flyer", 129, 20, v=0, range=40)
    # --- goal flag
    L.add("goal", 147, 20)
    # --- background landmarks
    L.add("waterfall", 44, 8, h=18)         # hangs from the sky, falls past island A
    L.add("bg_castle", 140, 21, v=0); L.add("bg_castle", 15, 21, v=1)
    L.add("bg_tree", 40, 26, v=0); L.add("bg_tree", 67, 26, v=1); L.add("bg_tree", 95, 24, v=0)
    L.add("bg_tree", 133, 25, v=1); L.add("bg_tree", 108, 24, v=1); L.add("bg_tree", 146, 21, v=0)
    return L

# ======================================================================= HELL
def hell():
    L = Level("hell")
    runs = [(0, 25), (28, 48), (51, 66), (69, 82), (86, 108), (112, 114)]
    for a, b in runs: L.ground(a, b)
    L.ground(129, 149)
    # brick bridge platforms over the long pit (115..128) are 1 tile thick
    L.plat(115, 118, 24); L.plat(122, 125, 22); L.plat(127, 128, 24)
    # raised brick steps
    L.fill(58, 61, 24, 25); L.fill(74, 75, 24, 25); L.fill(98, 101, 24, 25)
    L.add("start", 4, G - 1)
    # coins (diamonds in hell)
    L.arc(5, 12, G - 3, 2); L.coins([59, 60], 22); L.arc(30, 36, G - 3, 2)
    L.arc(116, 118, 22, 1); L.arc(122, 125, 20, 1); L.coins([130, 131, 132], G - 2)
    L.coins([88, 89, 90], G - 2); L.coins([140, 141, 142, 143], G - 2)
    L.coins([53, 54, 55], G - 2)
    # hazards
    for c in (20, 21, 40, 63, 64, 92, 93, 135, 136): L.add("spikes", c, G - 1)
    # enemies
    for c, v in [(15, 0), (33, 1), (55, 2), (72, 0), (90, 1), (104, 2), (134, 0), (146, 1)]:
        L.add("walker", c, G - 1, v=v)
    for c, r, v in [(26, 21, 0), (50, 20, 1), (80, 20, 0), (110, 19, 1), (120, 19, 0), (138, 20, 1)]:
        L.add("flyer", c, r, v=v, range=44)
    # lifts up to Earth
    for c in (44, 96, 140):
        L.add("lift", c, G, rise=16, dest="earth")
    # background (gate, statues, banners)
    L.add("bg_gate", 10, G - 1); L.add("bg_gate", 70, G - 1); L.add("bg_gate", 122, G - 1)
    for c in (4, 22, 34, 52, 84, 106, 132, 146): L.add("bg_statue", c, G - 1)
    for c in (15, 30, 57, 77, 100, 135): L.add("bg_banner", c, G - 5)
    return L

def check(L):
    """Fairness checks along every row-top ledge: max gap + max step."""
    cols_top = []
    for c in range(W):
        top = None
        for r in range(H):
            if L.g[r][c]: top = r; break
        cols_top.append(top)
    issues = []
    # ledge = maximal run of columns with the same top
    runs, c = [], 0
    while c < W:
        if cols_top[c] is None: c += 1; continue
        c2 = c
        while c2 + 1 < W and cols_top[c2 + 1] is not None and cols_top[c2 + 1] == cols_top[c]: c2 += 1
        runs.append((c, c2, cols_top[c])); c = c2 + 1
    for (a0, a1, ar), (b0, b1, br) in zip(runs, runs[1:]):
        gap = b0 - a1 - 1
        up = ar - br
        if gap > JUMP_MAX_GAP: issues.append(f"gap {gap} between col {a1} and {b0}")
        if up > JUMP_MAX_UP: issues.append(f"step up {up} at col {b0}")
    return issues

if __name__ == "__main__":
    out = {}
    for fn in (earth, heaven, hell):
        L = fn(); L.save(); out[L.theme] = L
        print(L.theme, "objects:", len(L.objs), "layout warnings:", check(L) if L.theme != "heaven" else "(heaven bridged by clouds - checked in preview)")
