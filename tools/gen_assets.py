#!/usr/bin/env python3
"""Generates every art and audio asset of the prototype (original, procedural).

Run from the project root:  python3 tools/gen_assets.py
Requires Pillow and numpy. Output: assets/textures, assets/sprites, assets/ui, assets/audio.
Art density: 64 px per game unit (drawn at scale 0.5 in the 32 px/gu world, i.e. 1:1 on
screen with the 2x camera). Fixed seeds: the output is reproducible.
"""
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PPU = 64  # pixels per game unit in the source art
SS = 4    # supersampling factor for shapes
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

# Palette: dark conifer greens, cold blue-grey shadows, faded wood, a little warm light.
PINE = [(22, 40, 30), (28, 52, 37), (35, 64, 44), (46, 80, 54), (62, 98, 66)]
GRASS = (31, 45, 33)
MOSS = (44, 58, 38)
DIRT = (64, 56, 44)
WOOD = (96, 76, 54)
WOOD_DARK = (58, 44, 32)
COLD = (36, 44, 58)


def out(*parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


# ---------------------------------------------------------------- noise helpers

def tile_noise(size, cells, rng):
    """Tileable value noise in [0, 1], shape (size, size)."""
    g = rng.random((cells, cells))
    x = np.arange(size) * cells / size
    xi = np.floor(x).astype(int)
    xf = x - xi
    xf = xf * xf * (3 - 2 * xf)
    x0, x1 = xi % cells, (xi + 1) % cells
    a = g[np.ix_(x0, x0)]
    b = g[np.ix_(x0, x1)]
    c = g[np.ix_(x1, x0)]
    d = g[np.ix_(x1, x1)]
    fy = xf[:, None]
    fx = xf[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, rng, base=4, octaves=5):
    n = np.zeros((size, size))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n += tile_noise(size, base * 2 ** o, rng) * amp
        tot += amp
        amp *= 0.5
    return n / tot


def to_img(arr_rgb, alpha=None):
    arr = np.clip(arr_rgb, 0, 255).astype(np.uint8)
    if alpha is not None:
        a = np.clip(alpha, 0, 255).astype(np.uint8)
        arr = np.dstack([arr, a])
        return Image.fromarray(arr, "RGBA")
    return Image.fromarray(arr, "RGB")


def mix(c1, c2, t):
    t = np.asarray(t)[..., None]
    return np.array(c1) * (1 - t) + np.array(c2) * t


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def finish(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def ell(d, cx, cy, rx, ry, fill, outline=None, width=0):
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=fill,
              outline=outline, width=width * SS)


def poly(d, pts, fill):
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)


def wrap_draw(d, size, fn):
    """Draw fn(ox, oy) for 9 offsets so strokes wrap around a tile."""
    for ox in (-size, 0, size):
        for oy in (-size, 0, size):
            fn(ox, oy)


# ---------------------------------------------------------------- ground textures

def grass_texture():
    rng = np.random.default_rng(1)
    S = 256
    n = fbm(S, rng, 3)
    m = fbm(S, rng, 8)
    base = mix(GRASS, MOSS, np.clip((n - 0.35) * 2.2, 0, 1))
    base = mix(base, (52, 50, 38), np.clip((m - 0.62) * 4, 0, 0.6))  # dry patches
    base *= (0.85 + 0.3 * fbm(S, rng, 32, 2))[..., None]
    img = to_img(base).convert("RGBA")
    big = img.resize((S * 2, S * 2), Image.BILINEAR)
    d = ImageDraw.Draw(big)
    r = np.random.default_rng(2)
    for _ in range(2600):
        x, y = r.random() * S * 2, r.random() * S * 2
        ang = -math.pi / 2 + r.normal(0, 0.5)
        ln = r.uniform(3, 9)
        shade = r.uniform(0.7, 1.35)
        col = tuple(int(min(255, c * shade)) for c in (48, 70, 46)) + (int(r.uniform(90, 200)),)

        def stroke(ox, oy, x=x, y=y, ang=ang, ln=ln, col=col):
            d.line([(x + ox, y + oy), (x + ox + math.cos(ang) * ln, y + oy + math.sin(ang) * ln)], fill=col, width=1)
        wrap_draw(d, S * 2, stroke)
    for _ in range(260):  # fallen needles
        x, y = r.random() * S * 2, r.random() * S * 2
        ang = r.random() * math.pi
        col = (92, 70, 44, 150)

        def needle(ox, oy, x=x, y=y, ang=ang, col=col):
            d.line([(x + ox, y + oy), (x + ox + math.cos(ang) * 5, y + oy + math.sin(ang) * 5)], fill=col, width=1)
        wrap_draw(d, S * 2, needle)
    big.resize((S, S), Image.LANCZOS).save(out("textures", "ground_grass.png"))


def path_texture():
    rng = np.random.default_rng(3)
    W, H = 128, 96
    n = fbm(128, rng, 4)[:H, :W]
    base = mix(DIRT, (78, 68, 52), n)
    base *= (0.85 + 0.3 * fbm(128, rng, 24, 2)[:H, :W])[..., None]
    y = np.linspace(-1, 1, H)[:, None]
    edge = np.clip((1 - np.abs(y)) * 2.2 + (n - 0.5) * 0.9, 0, 1)
    alpha = edge * 235
    img = to_img(base, np.broadcast_to(alpha, (H, W)))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(4)
    for _ in range(70):
        x, yy = r.random() * W, H * 0.25 + r.random() * H * 0.5
        rr = r.uniform(0.8, 2.2)
        g = int(r.uniform(85, 120))
        d.ellipse([x - rr, yy - rr, x + rr, yy + rr], fill=(g, g - 4, g - 12, 220))
    img.save(out("textures", "ground_path.png"))


def clearing_texture():
    rng = np.random.default_rng(5)
    S = 256
    n = fbm(S, rng, 3)
    yy, xx = np.mgrid[0:S, 0:S]
    r = np.hypot(xx - S / 2, yy - S / 2) / (S / 2)
    a = np.clip((1 - r) * 1.6 + (n - 0.5) * 0.8, 0, 1) * 150
    base = mix((58, 66, 44), (70, 72, 50), n)
    to_img(base, a).save(out("textures", "clearing.png"))


def floor_texture():
    rng = np.random.default_rng(6)
    S = 128
    plank = 32
    img = np.zeros((S, S, 3))
    grain = fbm(S, rng, 4)
    streak = np.repeat(fbm(S, rng, 16, 3)[:1, :], S, 0)
    for i in range(S // plank):
        tone = rng.uniform(0.82, 1.1)
        y0, y1 = i * plank, (i + 1) * plank
        g = np.roll(grain, rng.integers(0, S), axis=1)[y0:y1]
        s = np.roll(fbm(S, rng, 8, 3), rng.integers(0, S), 0)[y0:y1]
        lines = (np.sin((np.arange(plank)[:, None] + s * 18) * 0.9) * 0.5 + 0.5) * 0.12
        img[y0:y1] = mix(WOOD, (120, 98, 72), g * 0.6) * (tone - lines)[..., None]
        img[y0, :] = np.array(WOOD_DARK) * 0.6
        img[y1 - 1, :] = np.array(WOOD_DARK) * 0.8
        cut = rng.integers(10, S - 10)
        img[y0:y1, cut:cut + 1] = np.array(WOOD_DARK) * 0.6
    img *= 0.92 + 0.12 * streak[..., None]
    to_img(img).save(out("textures", "floor_wood.png"))


def wall_texture():
    rng = np.random.default_rng(7)
    S = 64
    n = fbm(S, rng, 4)
    base = mix((70, 58, 44), (98, 82, 62), n)
    rows = (np.sin(np.arange(S)[:, None] * math.pi / 8) * 0.5 + 0.5)
    base *= (0.82 + 0.25 * rows)[..., None]
    to_img(base).save(out("textures", "wall_logs.png"))


def roof_texture():
    rng = np.random.default_rng(8)
    W, H = 256, 192
    n = fbm(256, rng, 4)[:H, :W]
    x = np.arange(W)[None, :]
    corr = np.sin(x * 2 * math.pi / 12) * 0.5 + 0.5
    base = mix((74, 78, 82), (96, 70, 50), np.clip((n - 0.45) * 2.5, 0, 1))  # rust
    base *= (0.7 + 0.35 * corr)[..., None]
    base[H // 2 - 2:H // 2 + 2, :] *= 0.6
    to_img(base, np.full((H, W), 255)).save(out("sprites", "shed_roof.png"))


# ---------------------------------------------------------------- vegetation

def canopy(name, seed, radius_gu, palette, kind):
    rng = np.random.default_rng(seed)
    R = int(radius_gu * PPU)
    size = R * 2 + 8
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size / 2
    if kind == "pine":
        for layer, (rf, col) in enumerate(zip([1.0, 0.84, 0.66, 0.46, 0.26], palette)):
            n = 11 + layer * 2
            for k in range(n):
                a = 2 * math.pi * k / n + rng.uniform(-0.15, 0.15) + layer * 0.3
                rr = R * rf * rng.uniform(0.85, 1.0)
                w = rr * 0.42
                pts = [(c + math.cos(a - 0.5) * w * 0.4, c + math.sin(a - 0.5) * w * 0.4),
                       (c + math.cos(a) * rr, c + math.sin(a) * rr),
                       (c + math.cos(a + 0.5) * w * 0.4, c + math.sin(a + 0.5) * w * 0.4)]
                shade = 1.0 + 0.18 * math.cos(a + 2.3)  # moonlight from the north-west
                fill = tuple(int(min(255, ch * shade)) for ch in col) + (255,)
                poly(d, pts, fill)
            ell(d, c, c, R * rf * 0.45, R * rf * 0.45, palette[min(layer + 1, 4)] + (255,))
    else:  # birch-like broadleaf: clustered blobs
        for k in range(60):
            a = rng.random() * 2 * math.pi
            rr = R * math.sqrt(rng.random()) * 0.78
            br = R * rng.uniform(0.18, 0.3)
            x, y = c + math.cos(a) * rr, c + math.sin(a) * rr
            shade = 0.85 + 0.3 * (1 - (x - c + y - c) / (2 * R) * 0.5)
            col = palette[int(rng.integers(1, 5))]
            ell(d, x, y, br, br, tuple(int(min(255, ch * shade)) for ch in col) + (255,))
    img = finish(img, size, size)
    # needle texture noise + soft edge darkening
    arr = np.array(img).astype(float)
    nz = np.random.default_rng(seed + 100).random(arr.shape[:2])
    arr[..., :3] *= (0.85 + 0.25 * nz)[..., None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    img.save(out("sprites", name))


def trunk(name, seed):
    rng = np.random.default_rng(seed)
    size = 72
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size / 2
    for k in range(5):  # roots
        a = rng.random() * 2 * math.pi
        poly(d, [(c + math.cos(a - 0.35) * 14, c + math.sin(a - 0.35) * 14), (c + math.cos(a) * 33, c + math.sin(a) * 33),
                 (c + math.cos(a + 0.35) * 14, c + math.sin(a + 0.35) * 14)], (60, 44, 30, 255))
    ell(d, c, c, 26, 26, (64, 46, 32, 255))
    for k in range(18):
        a = rng.random() * 2 * math.pi
        rr = rng.uniform(8, 24)
        ell(d, c + math.cos(a) * rr, c + math.sin(a) * rr, 3, 3, (80, 60, 42, 255))
    ell(d, c - 5, c - 5, 15, 15, (92, 70, 50, 255))
    ell(d, c - 5, c - 5, 9, 9, (110, 86, 60, 255))
    finish(img, size, size).save(out("sprites", name))


def bush(name, seed):
    rng = np.random.default_rng(seed)
    R = 76
    size = R * 2 + 8
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size / 2
    for k in range(90):
        a = rng.random() * 2 * math.pi
        rr = R * math.sqrt(rng.random()) * 0.78
        br = rng.uniform(10, 22)
        x, y = c + math.cos(a) * rr, c + math.sin(a) * rr
        col = [(30, 58, 34), (38, 70, 40), (46, 84, 46), (26, 48, 30)][int(rng.integers(0, 4))]
        shade = 0.9 + 0.25 * (1 - (x - c + y - c) / (2 * R))
        ell(d, x, y, br, br, tuple(int(min(255, ch * shade)) for ch in col) + (255,))
    for k in range(25):  # leaf highlights
        x, y = c + rng.normal(0, R * 0.4), c + rng.normal(0, R * 0.4)
        ell(d, x, y, 3, 5, (78, 110, 66, 200))
    finish(img, size, size).save(out("sprites", name))


def details():
    rng = np.random.default_rng(11)
    # fern
    img = canvas(64, 64)
    d = ImageDraw.Draw(img)
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        for j in range(1, 9):
            px, py = 32 + math.cos(a) * j * 3.3, 32 + math.sin(a) * j * 3.3
            ell(d, px + math.cos(a + 1.5) * 3, py + math.sin(a + 1.5) * 3, 2.2, 1.2, (52, 86, 50, 255))
            ell(d, px - math.cos(a + 1.5) * 3, py - math.sin(a + 1.5) * 3, 2.2, 1.2, (46, 78, 46, 255))
    finish(img, 64, 64).save(out("sprites", "detail_fern.png"))
    # rocks
    img = canvas(48, 48)
    d = ImageDraw.Draw(img)
    ell(d, 22, 26, 13, 10, (70, 74, 78, 255))
    ell(d, 19, 23, 9, 6, (96, 100, 104, 255))
    ell(d, 33, 33, 6, 5, (80, 84, 88, 255))
    finish(img, 48, 48).save(out("sprites", "detail_rocks.png"))
    # stump
    img = canvas(56, 56)
    d = ImageDraw.Draw(img)
    ell(d, 28, 28, 18, 18, (70, 52, 36, 255))
    ell(d, 28, 28, 14, 14, (140, 112, 78, 255))
    for rr in (11, 8, 5, 2):
        ell(d, 28, 28, rr, rr, None, (110, 86, 58, 255), 1)
    finish(img, 56, 56).save(out("sprites", "detail_stump.png"))
    # branch
    img = canvas(96, 32)
    d = ImageDraw.Draw(img)
    d.line([(8 * SS, 18 * SS), (88 * SS, 12 * SS)], fill=(82, 62, 42, 255), width=4 * SS)
    d.line([(46 * SS, 16 * SS), (62 * SS, 4 * SS)], fill=(82, 62, 42, 255), width=2 * SS)
    d.line([(30 * SS, 17 * SS), (40 * SS, 28 * SS)], fill=(82, 62, 42, 255), width=2 * SS)
    finish(img, 96, 32).save(out("sprites", "detail_branch.png"))
    # grass tuft
    img = canvas(40, 40)
    d = ImageDraw.Draw(img)
    for k in range(14):
        a = -math.pi / 2 + rng.normal(0, 0.7)
        d.line([(20 * SS, 26 * SS), ((20 + math.cos(a) * 14) * SS, (26 + math.sin(a) * 14) * SS)], fill=(60, 92, 54, 255), width=SS)
    finish(img, 40, 40).save(out("sprites", "detail_tuft.png"))


# ---------------------------------------------------------------- characters

def person(d, cx, cy, kind, swing=0.0, pose="walk"):
    """Top-down character facing +x, in source pixels (64/gu)."""
    if kind == "survivor":
        jacket, jacket_hi, hair, skin, pack = (58, 88, 108), (82, 116, 136), (60, 42, 30), (196, 160, 130), (78, 82, 52)
        sw, sh, head = 10, 20, 9.5
    else:
        jacket, jacket_hi, hair, skin, pack = (40, 34, 32), (62, 52, 48), (28, 24, 22), (214, 206, 188), None
        sw, sh, head = 13, 25, 11
    ell(d, cx + 2, cy + 3, sw + 8, sh + 4, (0, 0, 0, 90))  # soft shadow
    if pack:
        d.rounded_rectangle([(cx - sw - 7) * SS, (cy - 9) * SS, (cx - sw + 3) * SS, (cy + 9) * SS], 3 * SS, fill=pack + (255,))
    # arms (swing along facing)
    for side in (-1, 1):
        ax = cx + swing * side * 6
        if kind == "killer" and side == 1:
            if pose == "windup":
                ax = cx - 12
            else:
                ax = cx + 6 + swing * 3
        ell(d, ax, cy + side * (sh - 2), 6, 5, jacket + (255,))
        ell(d, ax + 4, cy + side * (sh - 2), 3.5, 3.5, skin + (255,) if kind == "survivor" else (60, 52, 48, 255))
    if kind == "killer":  # hatchet in the right hand (+y side)
        hx = cx - 14 if pose == "windup" else cx + 12 + swing * 3
        hy = cy + sh - 2
        d.line([(hx * SS, hy * SS), ((hx + 14) * SS, (hy + 1) * SS)], fill=(70, 50, 34, 255), width=3 * SS)
        poly(d, [(hx + 12, hy - 6), (hx + 18, hy - 5), (hx + 18, hy + 5), (hx + 12, hy + 3)], (150, 150, 156, 255))
        poly(d, [(hx + 17, hy - 5), (hx + 19, hy - 5), (hx + 19, hy + 5), (hx + 17, hy + 5)], (120, 24, 20, 255))
    ell(d, cx, cy, sw, sh, jacket + (255,))
    ell(d, cx - 2, cy - 4, sw * 0.6, sh * 0.6, jacket_hi + (255,))
    if kind == "killer":
        d.line([(cx - 2) * SS, (cy - sh + 4) * SS, (cx - 2) * SS, (cy + sh - 4) * SS], fill=(90, 22, 20, 255), width=2 * SS)
    # head
    ell(d, cx + 2, cy, head, head, hair + (255,))
    if kind == "survivor":
        ell(d, cx + 6, cy, head * 0.55, head * 0.75, skin + (255,))
    else:  # pale mask with eye holes under a hood
        ell(d, cx + 6, cy, head * 0.62, head * 0.8, skin + (255,))
        ell(d, cx + 9, cy - 3, 1.6, 1.4, (20, 10, 10, 255))
        ell(d, cx + 9, cy + 3, 1.6, 1.4, (20, 10, 10, 255))


def character_sheet(kind):
    F = 96
    frames = []
    for swing in (0.0, 1.0, 0.0, -1.0):
        frames.append(("walk", swing))
    frames.insert(0, ("idle", 0.0))
    frames.append(("windup" if kind == "killer" else "hurt", 0.0))
    frames.append(("downed", 0.0))
    sheet = Image.new("RGBA", (F * len(frames), F), (0, 0, 0, 0))
    for i, (pose, swing) in enumerate(frames):
        img = canvas(F, F)
        d = ImageDraw.Draw(img)
        if pose == "downed":
            ell(d, 48, 52, 34, 22, (90, 8, 10, 170))  # blood pool
            ell(d, 50, 50, 26, 11, (58, 88, 108, 255) if kind == "survivor" else (40, 34, 32, 255))
            ell(d, 76, 50, 9, 9, (60, 42, 30, 255))
            ell(d, 34, 42, 9, 4, (58, 88, 108, 255))
            ell(d, 30, 58, 9, 4, (58, 88, 108, 255))
        else:
            person(d, 46, 48, kind, swing, pose)
            if pose == "hurt":
                ell(d, 44, 44, 6, 4, (150, 10, 12, 220))
        sheet.paste(finish(img, F, F), (i * F, 0))
    sheet.save(out("sprites", f"{kind}_sheet.png"))


# ---------------------------------------------------------------- items & furniture

def items():
    # stone
    img = canvas(28, 28)
    d = ImageDraw.Draw(img)
    ell(d, 15, 16, 10, 8, (0, 0, 0, 80))
    ell(d, 14, 14, 9, 8, (112, 114, 110, 255))
    ell(d, 12, 11, 5, 4, (150, 152, 146, 255))
    finish(img, 28, 28).save(out("sprites", "stone.png"))
    # bottle (top-down: round body, neck forward)
    img = canvas(40, 24)
    d = ImageDraw.Draw(img)
    ell(d, 15, 13, 10, 8, (0, 0, 0, 70))
    ell(d, 14, 12, 9, 8, (46, 98, 64, 235))
    d.rectangle([20 * SS, 9 * SS, 33 * SS, 15 * SS], fill=(52, 110, 72, 235))
    ell(d, 11, 9, 3.5, 2.5, (170, 220, 180, 200))
    d.rectangle([32 * SS, 9 * SS, 35 * SS, 15 * SS], fill=(110, 80, 50, 255))
    finish(img, 40, 24).save(out("sprites", "bottle.png"))
    # locker 1.0 x 0.6 gu, door slit on the +y (front) side
    W, H = 64, 40
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W * SS, H * SS], fill=(66, 70, 74, 255))
    d.rectangle([2 * SS, 2 * SS, (W - 2) * SS, (H - 2) * SS], fill=(86, 92, 96, 255))
    d.line([(W / 2) * SS, 2 * SS, (W / 2) * SS, (H - 2) * SS], fill=(46, 48, 52, 255), width=2 * SS)
    for x in (10, 42):
        for y in (8, 13, 18):
            d.line([x * SS, y * SS, (x + 12) * SS, y * SS], fill=(52, 56, 60, 255), width=SS)
    d.rectangle([4 * SS, (H - 6) * SS, (W - 4) * SS, (H - 3) * SS], fill=(24, 24, 26, 255))
    finish(img, W, H).save(out("sprites", "locker.png"))
    # bed 1.2 x 2.0 gu
    W, H = 77, 128
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W * SS, H * SS], 4 * SS, fill=(74, 56, 40, 255))
    d.rounded_rectangle([4 * SS, 4 * SS, (W - 4) * SS, (H - 4) * SS], 6 * SS, fill=(104, 108, 124, 255))
    d.rounded_rectangle([10 * SS, 8 * SS, (W - 10) * SS, 30 * SS], 6 * SS, fill=(170, 168, 160, 255))
    d.rounded_rectangle([4 * SS, 40 * SS, (W - 4) * SS, (H - 4) * SS], 6 * SS, fill=(82, 70, 98, 255))
    for y in range(48, H - 8, 12):
        d.line([8 * SS, y * SS, (W - 8) * SS, (y + 3) * SS], fill=(70, 60, 86, 255), width=SS)
    finish(img, W, H).save(out("sprites", "bed.png"))
    # table 1.6 x 1.0 gu
    W, H = 102, 64
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W * SS, H * SS], 3 * SS, fill=(88, 64, 42, 255))
    d.rounded_rectangle([3 * SS, 3 * SS, (W - 3) * SS, (H - 3) * SS], 3 * SS, fill=(112, 84, 56, 255))
    for x in range(16, W - 4, 18):
        d.line([x * SS, 4 * SS, x * SS, (H - 4) * SS], fill=(92, 68, 44, 255), width=SS)
    ell(d, 24, 22, 9, 7, (200, 196, 180, 230))  # plate
    finish(img, W, H).save(out("sprites", "table.png"))
    # chair 0.5 gu
    W = 32
    img = canvas(W, W)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2 * SS, 2 * SS, (W - 2) * SS, (W - 2) * SS], 3 * SS, fill=(96, 70, 46, 255))
    d.rectangle([2 * SS, 2 * SS, 7 * SS, (W - 2) * SS], fill=(70, 50, 32, 255))
    finish(img, W, W).save(out("sprites", "chair.png"))
    # crate 0.8 gu
    W = 51
    img = canvas(W, W)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W * SS, W * SS], fill=(108, 82, 48, 255))
    d.rectangle([3 * SS, 3 * SS, (W - 3) * SS, (W - 3) * SS], fill=(132, 102, 62, 255))
    for y in (13, 25, 37):
        d.line([3 * SS, y * SS, (W - 3) * SS, y * SS], fill=(98, 74, 44, 255), width=SS)
    d.line([3 * SS, 3 * SS, (W - 3) * SS, (W - 3) * SS], fill=(90, 66, 38, 255), width=3 * SS)
    finish(img, W, W).save(out("sprites", "crate.png"))
    # radio
    W, H = 30, 20
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W * SS, H * SS], 3 * SS, fill=(62, 52, 44, 255))
    ell(d, 9, 10, 6, 6, (40, 36, 32, 255))
    for k in range(4):
        d.line([4 * SS, (6 + k * 3) * SS, 14 * SS, (6 + k * 3) * SS], fill=(90, 84, 74, 255), width=SS)
    d.rectangle([17 * SS, 5 * SS, 27 * SS, 11 * SS], fill=(150, 130, 80, 255))
    ell(d, 22, 15, 2.5, 2.5, (160, 150, 130, 255))
    finish(img, W, H).save(out("sprites", "radio.png"))
    # door leaf 1.2 x 0.3 gu
    W, H = 77, 19
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W * SS, H * SS], fill=(80, 56, 34, 255))
    d.rectangle([2 * SS, 3 * SS, (W - 2) * SS, (H - 3) * SS], fill=(112, 80, 50, 255))
    for x in (24, 50):
        d.line([x * SS, 3 * SS, x * SS, (H - 3) * SS], fill=(84, 60, 38, 255), width=SS)
    ell(d, W - 10, H / 2, 2.2, 2.2, (190, 170, 110, 255))
    finish(img, W, H).save(out("sprites", "door.png"))
    # window frame 1.2 x 0.3 gu
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W * SS, H * SS], fill=(70, 52, 36, 255))
    d.rectangle([4 * SS, 5 * SS, (W - 4) * SS, (H - 5) * SS], fill=(120, 150, 170, 140))
    d.line([(W / 2) * SS, 2 * SS, (W / 2) * SS, (H - 2) * SS], fill=(70, 52, 36, 255), width=2 * SS)
    d.line([10 * SS, 7 * SS, 22 * SS, 7 * SS], fill=(200, 220, 230, 170), width=SS)
    finish(img, W, H).save(out("sprites", "window.png"))
    # gate leaf 0.3 x 2.2 gu
    W, H = 19, 141
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    for y in range(0, H, 14):
        d.rectangle([1 * SS, (y + 1) * SS, (W - 1) * SS, (y + 12) * SS], fill=(96, 72, 46, 255))
    d.rectangle([7 * SS, 0, 12 * SS, H * SS], fill=(70, 52, 34, 255))
    d.line([0, 0, W * SS, H * SS], fill=(70, 52, 34, 255), width=3 * SS)
    finish(img, W, H).save(out("sprites", "gate.png"))
    # rug for the bedroom
    W, H = 128, 90
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W * SS, H * SS], 8 * SS, fill=(86, 40, 36, 235))
    d.rounded_rectangle([8 * SS, 8 * SS, (W - 8) * SS, (H - 8) * SS], 6 * SS, outline=(150, 110, 70, 235), width=2 * SS)
    d.rounded_rectangle([20 * SS, 20 * SS, (W - 20) * SS, (H - 20) * SS], 6 * SS, outline=(120, 70, 50, 235), width=2 * SS)
    finish(img, W, H).save(out("sprites", "rug.png"))
    # oil lamp and lantern
    img = canvas(24, 24)
    d = ImageDraw.Draw(img)
    ell(d, 12, 12, 8, 8, (70, 60, 40, 255))
    ell(d, 12, 12, 5, 5, (255, 200, 110, 255))
    ell(d, 12, 12, 2.5, 2.5, (255, 245, 210, 255))
    finish(img, 24, 24).save(out("sprites", "lamp.png"))
    # blood decals
    for i in range(3):
        r = np.random.default_rng(30 + i)
        img = canvas(32, 32)
        d = ImageDraw.Draw(img)
        for k in range(6):
            x, y = 16 + r.normal(0, 4), 16 + r.normal(0, 4)
            rr = r.uniform(1.5, 4.5)
            ell(d, x, y, rr, rr * r.uniform(0.6, 1), (110, 8, 12, 230))
        finish(img, 32, 32).save(out("sprites", f"blood_{i}.png"))
    # glass shards
    r = np.random.default_rng(40)
    img = canvas(40, 40)
    d = ImageDraw.Draw(img)
    for k in range(10):
        x, y = 20 + r.normal(0, 7), 20 + r.normal(0, 7)
        a = r.random() * math.pi * 2
        poly(d, [(x, y), (x + math.cos(a) * 5, y + math.sin(a) * 5), (x + math.cos(a + 1.1) * 3, y + math.sin(a + 1.1) * 3)], (120, 190, 140, 220))
    finish(img, 40, 40).save(out("sprites", "glass_shards.png"))


# ---------------------------------------------------------------- UI icons

def ui_icons():
    S = 48
    # footsteps: two neutral prints
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    for (x, y) in ((17, 30), (30, 17)):
        ell(d, x, y, 5, 7, (230, 226, 214, 255))
        for k in range(4):
            ell(d, x - 4 + k * 2.6, y - 9, 1.4, 1.4, (230, 226, 214, 255))
    finish(img, S, S).save(out("ui", "icon_steps.png"))
    # heart
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    ell(d, 17, 19, 9, 9, (255, 255, 255, 255))
    ell(d, 31, 19, 9, 9, (255, 255, 255, 255))
    poly(d, [(8.5, 22), (39.5, 22), (24, 40)], (255, 255, 255, 255))
    finish(img, S, S).save(out("ui", "icon_heart.png"))
    # stamina (running lung / lightning)
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    poly(d, [(27, 4), (12, 27), (23, 27), (19, 44), (36, 19), (25, 19)], (255, 255, 255, 255))
    finish(img, S, S).save(out("ui", "icon_stamina.png"))
    # gate
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    for x in (10, 18, 26, 34):
        d.rectangle([x * SS, 10 * SS, (x + 5) * SS, 40 * SS], fill=(255, 255, 255, 255))
    d.rectangle([8 * SS, 16 * SS, 41 * SS, 20 * SS], fill=(255, 255, 255, 255))
    d.rectangle([8 * SS, 30 * SS, 41 * SS, 34 * SS], fill=(255, 255, 255, 255))
    finish(img, S, S).save(out("ui", "icon_gate.png"))


# ---------------------------------------------------------------- audio

RATE = 22050


def write_wav(name, samples, gain=0.8):
    s = np.asarray(samples, dtype=float)
    peak = np.max(np.abs(s)) or 1.0
    s = np.clip(s / peak * gain, -1, 1)
    p = out("audio", name)
    with wave.open(p, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((s * 32767).astype("<i2").tobytes())


def env(n, a, d):
    t = np.arange(n) / RATE
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)


def lowpass(x, k):
    kern = np.ones(k) / k
    return np.convolve(x, kern, mode="same")


def audio():
    rng = np.random.default_rng(50)
    t = lambda dur: np.arange(int(dur * RATE)) / RATE
    for i in range(3):  # footsteps on grass/needles
        n = int(0.16 * RATE)
        noise = lowpass(rng.normal(0, 1, n), 6 + i * 2)
        thump = np.sin(2 * np.pi * (70 + i * 8) * t(0.16)) * env(n, 0.003, 0.03)
        write_wav(f"step_grass_{i}.wav", noise * env(n, 0.005, 0.04) + thump * 0.6, 0.55)
    n = int(0.18 * RATE)
    write_wav("step_wood.wav", np.sin(2 * np.pi * 110 * t(0.18)) * env(n, 0.002, 0.05) + lowpass(rng.normal(0, 0.4, n), 3) * env(n, 0.002, 0.02), 0.5)
    # door creak: FM tone sweep + grit
    tt = t(0.7)
    f = 320 + 140 * np.sin(2 * np.pi * 1.6 * tt) + 60 * tt
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.5 + rng.normal(0, 0.3, len(tt))
    write_wav("door_creak.wav", lowpass(creak, 4) * np.sin(np.pi * tt / 0.7) ** 0.6, 0.45)
    # stone impact
    n = int(0.25 * RATE)
    write_wav("stone_impact.wav", rng.normal(0, 1, n) * env(n, 0.0005, 0.012) + np.sin(2 * np.pi * 180 * t(0.25)) * env(n, 0.001, 0.05), 0.8)
    # glass break: many short bright pings + noise
    n = int(0.8 * RATE)
    g = rng.normal(0, 1, n) * env(n, 0.001, 0.06)
    for k in range(14):
        st = int(rng.uniform(0, 0.4) * RATE)
        fr = rng.uniform(2500, 6000)
        m = n - st
        g[st:] += np.sin(2 * np.pi * fr * np.arange(m) / RATE) * env(m, 0.0005, rng.uniform(0.02, 0.08)) * 0.6
    write_wav("glass_break.wav", g, 0.75)
    # window vault: rustle + knock
    n = int(0.6 * RATE)
    r = lowpass(rng.normal(0, 1, n), 5) * np.sin(np.pi * t(0.6) / 0.6)
    k0 = int(0.42 * RATE)
    r[k0:] += np.sin(2 * np.pi * 140 * np.arange(n - k0) / RATE) * env(n - k0, 0.001, 0.04) * 2
    write_wav("window_vault.wav", r, 0.6)
    # attack swing (whoosh) and hit
    tt = t(0.35)
    wh = lowpass(rng.normal(0, 1, len(tt)), 3) * np.sin(np.pi * tt / 0.35) ** 2
    write_wav("attack_swing.wav", wh, 0.7)
    n = int(0.35 * RATE)
    hit = np.sin(2 * np.pi * 90 * t(0.35)) * env(n, 0.001, 0.07) + lowpass(rng.normal(0, 1, n), 8) * env(n, 0.001, 0.05)
    write_wav("attack_hit.wav", hit, 0.9)
    # locker (metal)
    tt = t(0.5)
    metal = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * d) for f, d in ((410, 7), (733, 9), (1210, 12)))
    write_wav("locker.wav", metal + rng.normal(0, 0.2, len(tt)) * np.exp(-tt * 20), 0.5)
    # gate open: long creak + latch
    tt = t(1.2)
    f = 180 + 90 * np.sin(2 * np.pi * 0.8 * tt)
    gc = np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.4 + rng.normal(0, 0.25, len(tt))
    gc = lowpass(gc, 5) * np.sin(np.pi * tt / 1.2) ** 0.5
    gc[:int(0.05 * RATE)] += np.sin(2 * np.pi * 900 * t(0.05)) * 1.5
    write_wav("gate_open.wav", gc, 0.6)
    # furniture scrape
    n = int(0.6 * RATE)
    write_wav("furniture.wav", lowpass(rng.normal(0, 1, n), 10) * np.sin(np.pi * t(0.6) / 0.6), 0.55)
    # radio loop (2 s): muffled melody + hiss
    tt = t(2.0)
    notes = [392, 440, 494, 440, 392, 330, 349, 392]
    mel = np.zeros_like(tt)
    for k, fr in enumerate(notes):
        seg = (tt >= k * 0.25) & (tt < (k + 1) * 0.25)
        mel[seg] = np.sign(np.sin(2 * np.pi * fr * tt[seg])) * 0.3 + np.sin(2 * np.pi * fr * 2 * tt[seg]) * 0.2
    write_wav("radio_loop.wav", lowpass(mel, 6) + rng.normal(0, 0.12, len(tt)), 0.35)
    # night ambience (8 s loop): wind + crickets
    tt = t(8.0)
    wind = lowpass(rng.normal(0, 1, len(tt)), 60) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / 8.0))
    crick = np.zeros_like(tt)
    for k in range(40):
        st = rng.uniform(0, 7.8)
        seg = (tt >= st) & (tt < st + 0.06)
        crick[seg] += np.sin(2 * np.pi * 4200 * tt[seg]) * np.sin(2 * np.pi * 30 * tt[seg]) * 0.25
    write_wav("night_ambience.wav", wind + crick, 0.3)


def main():
    grass_texture()
    path_texture()
    clearing_texture()
    floor_texture()
    wall_texture()
    roof_texture()
    canopy("canopy_pine_a.png", 101, 1.5, PINE, "pine")
    canopy("canopy_pine_b.png", 102, 1.6, [(20, 36, 32), (26, 48, 40), (32, 58, 46), (42, 72, 54), (56, 90, 64)], "pine")
    canopy("canopy_birch.png", 103, 1.4, [(40, 56, 34), (52, 72, 40), (64, 86, 46), (78, 100, 54), (92, 114, 62)], "broad")
    for i in range(3):
        trunk(f"trunk_{i}.png", 200 + i)
    bush("bush_a.png", 301)
    bush("bush_b.png", 302)
    details()
    character_sheet("survivor")
    character_sheet("killer")
    items()
    ui_icons()
    audio()
    print("assets written to", os.path.normpath(ROOT))


if __name__ == "__main__":
    main()
