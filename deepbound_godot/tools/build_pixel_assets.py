#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SPRITE_DIR = ROOT / "assets" / "sprites"
TILE_DIR = ROOT / "assets" / "tiles"
UI_DIR = ROOT / "assets" / "ui"
ENEMY_DIR = ROOT / "assets" / "enemies"
ITEM_DIR = ROOT / "assets" / "items"
PROP_DIR = ROOT / "assets" / "props"
EFFECT_DIR = ROOT / "assets" / "effects"
PREVIEW_DIR = ROOT / "assets" / "previews"
AI_REFERENCE = ROOT / "assets" / "source_ai" / "villager_delver_ai_reference.png"
AI_ENEMY_REFERENCE = ROOT / "assets" / "source_ai" / "enemy_roster_ai_reference.png"
AI_WORLD_REFERENCE = ROOT / "assets" / "source_ai" / "world_asset_ai_reference.png"
AI_DROW_TILE_REFERENCE = ROOT / "assets" / "source_ai" / "drow_village_tiles_ai_reference.png"
AI_HEART_CHEST_REFERENCE = ROOT / "assets" / "source_ai" / "chest_heart_ai_reference.png"

FRAME_W = 32
FRAME_H = 32
COLS = 8
ROWS = 7
ENEMY_COLS = 8
ENEMY_ROWS = 4
BREAK_STAGE_COUNT = 5

BREAK_MATERIALS = {
    "loose_dirt": {"shadow": (64, 43, 36, 210), "mid": (168, 111, 60, 225), "hi": (230, 172, 104, 230), "chip": (255, 214, 132, 240)},
    "compacted_dirt": {"shadow": (45, 31, 28, 220), "mid": (141, 90, 54, 225), "hi": (208, 142, 82, 230), "chip": (245, 188, 113, 240)},
    "soft_stone": {"shadow": (38, 45, 52, 225), "mid": (122, 132, 140, 225), "hi": (190, 199, 203, 235), "chip": (224, 229, 226, 240)},
    "copper_ore": {"shadow": (69, 45, 35, 220), "mid": (194, 101, 51, 225), "hi": (255, 176, 79, 235), "chip": (255, 214, 107, 245)},
    "hardened_resin": {"shadow": (90, 53, 31, 215), "mid": (198, 134, 51, 225), "hi": (241, 184, 91, 235), "chip": (255, 225, 130, 245)},
    "royal_jelly": {"shadow": (154, 118, 49, 205), "mid": (240, 211, 94, 215), "hi": (255, 238, 154, 230), "chip": (255, 255, 214, 240)},
    "sandstone_block": {"shadow": (88, 66, 40, 220), "mid": (155, 129, 80, 225), "hi": (231, 196, 122, 235), "chip": (255, 230, 152, 240)},
    "pressure_plate": {"shadow": (36, 61, 57, 220), "mid": (62, 143, 116, 225), "hi": (112, 206, 177, 235), "chip": (168, 236, 205, 240)},
    "cursed_treasure": {"shadow": (55, 39, 28, 220), "mid": (170, 111, 45, 225), "hi": (255, 214, 107, 240), "chip": (112, 206, 177, 245)},
    "glow_mushroom_loam": {"shadow": (24, 30, 72, 220), "mid": (45, 63, 130, 225), "hi": (85, 214, 210, 235), "chip": (182, 255, 236, 245)},
    "drow_basalt_brick": {"shadow": (18, 20, 45, 225), "mid": (72, 65, 138, 225), "hi": (133, 112, 184, 235), "chip": (85, 214, 210, 240)},
    "drow_carved_floor": {"shadow": (23, 28, 61, 225), "mid": (66, 82, 138, 225), "hi": (112, 206, 177, 235), "chip": (182, 255, 236, 240)},
    "drow_mushroom_plank": {"shadow": (42, 31, 62, 220), "mid": (106, 67, 136, 225), "hi": (172, 111, 171, 235), "chip": (236, 180, 222, 240)},
    "drow_silk_canopy": {"shadow": (45, 36, 92, 190), "mid": (98, 71, 155, 205), "hi": (160, 112, 220, 220), "chip": (218, 188, 255, 230)},
    "drow_arch_inlay": {"shadow": (22, 24, 52, 225), "mid": (62, 55, 119, 225), "hi": (160, 112, 220, 235), "chip": (112, 206, 177, 240)},
    "drow_glowglass": {"shadow": (24, 40, 78, 205), "mid": (45, 63, 130, 215), "hi": (85, 214, 210, 235), "chip": (182, 255, 236, 245)},
    "obsidian_ash": {"shadow": (12, 10, 16, 230), "mid": (92, 22, 20, 225), "hi": (255, 93, 36, 240), "chip": (255, 166, 43, 245)},
}

DROW_VILLAGE_TILE_IDS = [
    "drow_basalt_brick",
    "drow_carved_floor",
    "drow_mushroom_plank",
    "drow_silk_canopy",
    "drow_arch_inlay",
    "drow_glowglass",
]

DROW_VILLAGE_PROP_IDS = [
    "drow_door",
    "drow_lantern",
    "drow_silk_banner",
    "drow_market_crate",
    "drow_moon_shrine",
    "drow_watch_crystal",
    "drow_bridge_post",
    "drow_mushroom_lamp",
    "drow_web_bridge",
]

PALETTE = {
    "transparent": (0, 0, 0, 0),
    "outline": (24, 23, 36, 255),
    "outline_warm": (32, 21, 29, 255),
    "skin": (224, 154, 116, 255),
    "skin_hi": (246, 190, 148, 255),
    "skin_shadow": (158, 91, 75, 255),
    "hair": (84, 53, 39, 255),
    "hair_hi": (144, 84, 48, 255),
    "hair_shadow": (48, 32, 30, 255),
    "tunic": (178, 138, 82, 255),
    "tunic_hi": (215, 172, 104, 255),
    "tunic_shadow": (93, 67, 48, 255),
    "belt": (74, 50, 36, 255),
    "pants": (49, 74, 104, 255),
    "pants_hi": (77, 104, 132, 255),
    "boot": (47, 35, 31, 255),
    "drill": (192, 139, 62, 255),
    "drill_hi": (255, 214, 107, 255),
    "steel": (188, 196, 196, 255),
    "steel_shadow": (91, 98, 105, 255),
    "spark": (255, 166, 43, 255),
}


def ensure_dirs() -> None:
    for path in (SPRITE_DIR, TILE_DIR, UI_DIR, ENEMY_DIR, ITEM_DIR, PROP_DIR, EFFECT_DIR, PREVIEW_DIR):
        path.mkdir(parents=True, exist_ok=True)


def rect(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, color: tuple[int, int, int, int]) -> None:
    draw.rectangle((x, y, x + w - 1, y + h - 1), fill=color)


def px(img: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def draw_hair(img: Image.Image, ox: int, oy: int, bob: int, head_x: int) -> None:
    d = ImageDraw.Draw(img)
    o = PALETTE["outline"]
    h = PALETTE["hair"]
    hh = PALETTE["hair_hi"]
    hs = PALETTE["hair_shadow"]
    x = ox + head_x
    y = oy + bob
    for r in [
        (11, 3, 10, 4),
        (10, 5, 3, 4),
        (19, 5, 3, 4),
        (12, 2, 7, 2),
        (15, 1, 3, 2),
    ]:
        rect(d, x + r[0], y + r[1], r[2], r[3], o)
    for r in [
        (12, 3, 8, 4),
        (11, 6, 3, 3),
        (18, 6, 2, 2),
        (14, 2, 5, 2),
    ]:
        rect(d, x + r[0], y + r[1], r[2], r[3], h)
    px(img, x + 13, y + 3, hh)
    px(img, x + 16, y + 2, hh)
    px(img, x + 19, y + 5, hs)
    px(img, x + 11, y + 8, hs)


def draw_head(img: Image.Image, ox: int, oy: int, bob: int, head_x: int) -> None:
    d = ImageDraw.Draw(img)
    o = PALETTE["outline"]
    skin = PALETTE["skin"]
    hi = PALETTE["skin_hi"]
    shadow = PALETTE["skin_shadow"]
    x = ox + head_x
    y = oy + bob
    rect(d, x + 12, y + 5, 9, 8, o)
    rect(d, x + 12, y + 6, 8, 6, skin)
    rect(d, x + 17, y + 7, 3, 4, hi)
    px(img, x + 18, y + 9, o)
    px(img, x + 20, y + 10, shadow)
    px(img, x + 14, y + 11, hi)
    draw_hair(img, ox, oy, bob, head_x)


def draw_legs(img: Image.Image, ox: int, oy: int, bob: int, left: int, right: int) -> None:
    d = ImageDraw.Draw(img)
    o = PALETTE["outline"]
    pants = PALETTE["pants"]
    pants_hi = PALETTE["pants_hi"]
    boot = PALETTE["boot"]
    rect(d, ox + 11 + left, oy + 21 + bob, 5, 8, o)
    rect(d, ox + 17 + right, oy + 21 + bob, 5, 8, o)
    rect(d, ox + 12 + left, oy + 22 + bob, 3, 6, pants)
    rect(d, ox + 18 + right, oy + 22 + bob, 3, 6, pants_hi)
    rect(d, ox + 10 + left, oy + 28 + bob, 6, 2, boot)
    rect(d, ox + 17 + right, oy + 28 + bob, 6, 2, boot)
    px(img, ox + 14 + left, oy + 23 + bob, PALETTE["pants_hi"])


def draw_torso(img: Image.Image, ox: int, oy: int, bob: int) -> None:
    d = ImageDraw.Draw(img)
    o = PALETTE["outline"]
    tunic = PALETTE["tunic"]
    hi = PALETTE["tunic_hi"]
    shadow = PALETTE["tunic_shadow"]
    belt = PALETTE["belt"]
    rect(d, ox + 11, oy + 12 + bob, 11, 11, o)
    rect(d, ox + 12, oy + 13 + bob, 9, 8, tunic)
    rect(d, ox + 13, oy + 14 + bob, 6, 2, hi)
    rect(d, ox + 12, oy + 20 + bob, 9, 2, shadow)
    rect(d, ox + 14, oy + 17 + bob, 6, 2, belt)
    px(img, ox + 20, oy + 14 + bob, shadow)
    px(img, ox + 12, oy + 18 + bob, hi)


def draw_idle_arms(img: Image.Image, ox: int, oy: int, bob: int, left_y: int, right_y: int) -> None:
    d = ImageDraw.Draw(img)
    o = PALETTE["outline"]
    tunic = PALETTE["tunic"]
    hi = PALETTE["tunic_hi"]
    skin = PALETTE["skin"]
    rect(d, ox + 8, oy + 14 + bob + left_y, 5, 10, o)
    rect(d, ox + 20, oy + 14 + bob + right_y, 5, 10, o)
    rect(d, ox + 9, oy + 15 + bob + left_y, 3, 5, tunic)
    rect(d, ox + 21, oy + 15 + bob + right_y, 3, 5, hi)
    rect(d, ox + 9, oy + 20 + bob + left_y, 3, 3, skin)
    rect(d, ox + 21, oy + 20 + bob + right_y, 3, 3, skin)


def draw_drill_side(img: Image.Image, ox: int, oy: int, bob: int, frame: int) -> None:
    d = ImageDraw.Draw(img)
    rect(d, ox + 17, oy + 14 + bob, 8, 5, PALETTE["outline"])
    rect(d, ox + 18, oy + 15 + bob, 5, 3, PALETTE["tunic_hi"])
    rect(d, ox + 22, oy + 14 + bob, 4, 5, PALETTE["drill"])
    rect(d, ox + 25, oy + 15 + bob, 5, 3, PALETTE["steel_shadow"])
    px(img, ox + 30, oy + 16 + bob, PALETTE["steel"])
    if frame % 2 == 1:
        px(img, ox + 26, oy + 14 + bob, PALETTE["drill_hi"])
        px(img, ox + 31, oy + 18 + bob, PALETTE["spark"])


def draw_drill_up(img: Image.Image, ox: int, oy: int, bob: int, frame: int) -> None:
    d = ImageDraw.Draw(img)
    rect(d, ox + 11, oy + 11 + bob, 10, 4, PALETTE["outline"])
    rect(d, ox + 12, oy + 11 + bob, 8, 2, PALETTE["tunic_hi"])
    rect(d, ox + 15, oy + 4 + bob, 5, 8, PALETTE["outline"])
    rect(d, ox + 16, oy + 4 + bob, 3, 6, PALETTE["drill"])
    rect(d, ox + 16, oy + 2 + bob, 3, 3, PALETTE["steel_shadow"])
    px(img, ox + 17 + (frame % 2), oy + 2 + bob, PALETTE["steel"])
    if frame % 2 == 1:
        px(img, ox + 19, oy + 3 + bob, PALETTE["spark"])


def draw_drill_down(img: Image.Image, ox: int, oy: int, bob: int, frame: int) -> None:
    d = ImageDraw.Draw(img)
    rect(d, ox + 18, oy + 17 + bob, 6, 5, PALETTE["outline"])
    rect(d, ox + 19, oy + 18 + bob, 4, 3, PALETTE["tunic_hi"])
    rect(d, ox + 21, oy + 22 + bob, 5, 8, PALETTE["outline"])
    rect(d, ox + 22, oy + 22 + bob, 3, 6, PALETTE["drill"])
    rect(d, ox + 22, oy + 28 + bob, 3, 3, PALETTE["steel_shadow"])
    px(img, ox + 23 + (frame % 2), oy + 30 + bob, PALETTE["steel"])
    if frame % 2 == 1:
        px(img, ox + 25, oy + 29 + bob, PALETTE["spark"])


def draw_weapon_swing(img: Image.Image, ox: int, oy: int, bob: int, frame: int) -> None:
    d = ImageDraw.Draw(img)
    outline = PALETTE["outline"]
    steel = PALETTE["steel"]
    steel_shadow = PALETTE["steel_shadow"]
    spark = PALETTE["spark"]
    hilt = PALETTE["drill"]
    cycle = frame % 8
    arm_points = [
        ((19, 13), (23, 9), (25, 7)),
        ((20, 13), (25, 9), (27, 8)),
        ((20, 14), (27, 11), (30, 10)),
        ((20, 15), (29, 15), (31, 15)),
        ((19, 17), (26, 21), (29, 23)),
        ((18, 18), (23, 24), (25, 27)),
        ((18, 17), (22, 20), (24, 22)),
        ((18, 15), (22, 16), (24, 17)),
    ][cycle]
    shoulder, blade_mid, blade_tip = arm_points
    rect(d, ox + 17, oy + 14 + bob, 5, 5, outline)
    rect(d, ox + 18, oy + 15 + bob, 3, 3, PALETTE["tunic_hi"])
    d.line((ox + shoulder[0], oy + shoulder[1] + bob, ox + blade_mid[0], oy + blade_mid[1] + bob), fill=outline, width=2)
    d.line((ox + shoulder[0], oy + shoulder[1] + bob, ox + blade_mid[0], oy + blade_mid[1] + bob), fill=hilt, width=1)
    d.line((ox + blade_mid[0], oy + blade_mid[1] + bob, ox + blade_tip[0], oy + blade_tip[1] + bob), fill=outline, width=2)
    d.line((ox + blade_mid[0], oy + blade_mid[1] + bob, ox + blade_tip[0], oy + blade_tip[1] + bob), fill=steel, width=1)
    px(img, ox + blade_tip[0], oy + blade_tip[1] + bob, steel_shadow)
    if cycle in (2, 3, 4):
        trail = [(23, 8), (27, 10), (30, 14), (27, 20), (23, 24)]
        for index, point in enumerate(trail[max(0, cycle - 2):cycle + 1]):
            px(img, ox + point[0], oy + point[1] + bob, spark if index == 0 else (255, 214, 107, 180))


def draw_delver_frame(img: Image.Image, col: int, row: int, pose: str, frame: int) -> None:
    ox = col * FRAME_W
    oy = row * FRAME_H
    bob = 0
    head_x = 0
    left_leg = 0
    right_leg = 0
    left_arm_y = 0
    right_arm_y = 0

    if pose == "idle":
        bob = 1 if frame in (2, 3, 4) else 0
        right_arm_y = 1 if frame in (2, 3, 4) else 0
    elif pose == "walk":
        cycle = frame % 8
        bob = 1 if cycle in (1, 2, 5, 6) else 0
        left_leg = [-2, -1, 0, 1, 2, 1, 0, -1][cycle]
        right_leg = [2, 1, 0, -1, -2, -1, 0, 1][cycle]
        left_arm_y = [1, 0, -1, -2, -1, 0, 1, 2][cycle]
        right_arm_y = [-1, 0, 1, 2, 1, 0, -1, -2][cycle]
    elif pose == "jump":
        jf = min(frame, 7)
        bob = [-1, -2, -2, -1, 0, 1, 1, 0][jf]
        left_leg = [-1, -1, 0, 1, 1, 0, -1, 0][jf]
        right_leg = [1, 1, 0, -1, -1, 0, 1, 0][jf]
        left_arm_y = [-2, -2, -1, 0, 1, 1, 0, -1][jf]
        right_arm_y = [-2, -2, -1, 0, 1, 1, 0, -1][jf]
    elif pose == "drill_side":
        bob = 1 if frame % 2 else 0
        head_x = 1
    elif pose == "drill_up":
        bob = -1 if frame % 2 else 0
    elif pose == "drill_down":
        bob = 1
        left_leg = -1
        right_leg = 1
    elif pose == "weapon_swing":
        cycle = frame % 8
        bob = 1 if cycle in (2, 3, 4) else 0
        head_x = 1 if cycle in (2, 3) else 0
        left_leg = [-1, -1, 0, 1, 1, 0, -1, -1][cycle]
        right_leg = [1, 1, 0, -1, -1, 0, 1, 1][cycle]

    draw_legs(img, ox, oy, bob, left_leg, right_leg)
    if pose == "drill_side":
        draw_drill_side(img, ox, oy, bob, frame)
    elif pose == "drill_up":
        draw_drill_up(img, ox, oy, bob, frame)
    elif pose == "drill_down":
        draw_drill_down(img, ox, oy, bob, frame)
    elif pose == "weapon_swing":
        draw_weapon_swing(img, ox, oy, bob, frame)
    else:
        draw_idle_arms(img, ox, oy, bob, left_arm_y, right_arm_y)
    draw_torso(img, ox, oy, bob)
    draw_head(img, ox, oy, bob, head_x)


def make_delver_sheet_from_ai(reference: Path) -> Image.Image:
    src = Image.open(reference).convert("RGBA")
    centers_x = [110, 260, 410, 560, 710, 860]
    centers_y = [100, 255, 420, 585, 745, 905]
    crop_w = 120
    crop_h = 145
    frames: list[Image.Image] = []
    for cy in centers_y:
        source_frames: list[Image.Image] = []
        for cx in centers_x:
            crop = src.crop((cx - crop_w // 2, cy - crop_h // 2, cx + crop_w // 2, cy + crop_h // 2))
            small = crop.resize((FRAME_W, FRAME_H), Image.Resampling.BOX).convert("RGBA")
            _remove_border_black(small)
            source_frames.append(_quantize_rgba(small, 24))
        for frame in range(COLS):
            source_position = frame * (len(source_frames) - 1) / float(COLS - 1)
            lo = int(source_position)
            hi = min(len(source_frames) - 1, lo + 1)
            t = source_position - lo
            if t <= 0.001:
                cell = source_frames[lo].copy()
            else:
                cell = Image.blend(source_frames[lo], source_frames[hi], t).convert("RGBA")
                _remove_border_black(cell)
                cell = _quantize_rgba(cell, 24)
            frames.append(cell)

    sheet = Image.new("RGBA", (FRAME_W * COLS, FRAME_H * ROWS), PALETTE["transparent"])
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, ((index % COLS) * FRAME_W, (index // COLS) * FRAME_H))
    for frame in range(COLS):
        weapon_frame = frames[frame % COLS].copy()
        draw_weapon_swing(weapon_frame, 0, 0, 0, frame)
        sheet.alpha_composite(weapon_frame, (frame * FRAME_W, 6 * FRAME_H))
    return sheet


def _remove_border_black(image: Image.Image) -> None:
    pixels = image.load()
    seen: set[tuple[int, int]] = set()
    queue: list[tuple[int, int]] = []
    for x in range(image.width):
        queue.append((x, 0))
        queue.append((x, image.height - 1))
    for y in range(image.height):
        queue.append((0, y))
        queue.append((image.width - 1, y))
    while queue:
        x, y = queue.pop()
        if (x, y) in seen or x < 0 or y < 0 or x >= image.width or y >= image.height:
            continue
        r, g, b, _a = pixels[x, y]
        if max(r, g, b) > 24:
            continue
        seen.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])


def _quantize_rgba(image: Image.Image, colors: int) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    quantized.putalpha(alpha.point(lambda a: 255 if a > 24 else 0))
    return quantized


def _crop_pixelized(src: Image.Image, center: tuple[int, int], crop_size: tuple[int, int], out_size: tuple[int, int], colors: int) -> Image.Image:
    cx, cy = center
    cw, ch = crop_size
    crop = src.crop((cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2)).convert("RGBA")
    resized = crop.resize(out_size, Image.Resampling.BOX).convert("RGBA")
    _remove_border_black(resized)
    return _quantize_rgba(resized, colors)


def _crop_pixelized_opaque(src: Image.Image, center: tuple[int, int], crop_size: tuple[int, int], out_size: tuple[int, int], colors: int) -> Image.Image:
    cx, cy = center
    cw, ch = crop_size
    crop = src.crop((cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2)).convert("RGBA")
    resized = crop.resize(out_size, Image.Resampling.BOX).convert("RGBA")
    alpha = Image.new("L", resized.size, 255)
    resized.putalpha(alpha)
    return _quantize_rgba(resized, colors)


def _save_ai_cells(
    src: Image.Image,
    specs: list[tuple[str, tuple[int, int]]],
    directory: Path,
    crop_size: tuple[int, int],
    out_size: tuple[int, int],
    colors: int,
) -> list[Image.Image]:
    cells: list[Image.Image] = []
    for name, center in specs:
        cell = _crop_pixelized(src, center, crop_size, out_size, colors)
        cell.save(directory / f"{name}.png")
        cells.append(cell)
    return cells


def _heart_mask() -> set[tuple[int, int]]:
    rows = {
        2: [(4, 6), (9, 11)],
        3: [(3, 7), (8, 12)],
        4: [(2, 13)],
        5: [(1, 14)],
        6: [(1, 14)],
        7: [(1, 14)],
        8: [(2, 13)],
        9: [(3, 12)],
        10: [(4, 11)],
        11: [(5, 10)],
        12: [(6, 9)],
        13: [(7, 8)],
    }
    mask: set[tuple[int, int]] = set()
    for y, ranges in rows.items():
        for left, right in ranges:
            for x in range(left, right + 1):
                mask.add((x, y))
    return mask


def _is_mask_edge(mask: set[tuple[int, int]], x: int, y: int) -> bool:
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if (nx, ny) not in mask:
            return True
    return False


def _make_heart_frame(state: str) -> Image.Image:
    mask = _heart_mask()
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    outline = (92, 32, 36, 255)
    outline_dark = (47, 19, 27, 255)
    red = (213, 45, 31, 255)
    red_mid = (245, 77, 40, 255)
    red_shadow = (129, 26, 31, 255)
    red_deep = (84, 20, 30, 255)
    hi = (255, 183, 106, 255)
    empty_fill = (40, 28, 38, 255)
    empty_hi = (86, 42, 56, 255)

    for y in range(16):
        for x in range(16):
            if (x, y) not in mask:
                continue
            edge = _is_mask_edge(mask, x, y)
            active = state == "full" or (state == "half" and x <= 7)
            if edge:
                color = outline_dark if y >= 10 else outline
            elif active:
                if y <= 5:
                    color = red_mid
                elif y >= 10:
                    color = red_deep if x in (6, 9) else red_shadow
                else:
                    color = red
            else:
                color = empty_hi if edge and y <= 5 else empty_fill
            px(img, x, y, color)

    for point in [(4, 4), (5, 4), (4, 5), (10, 4), (11, 5)]:
        if state in ("full", "half") and point[0] <= (15 if state == "full" else 7):
            px(img, point[0], point[1], hi)
    return img


def make_heart_assets_from_ai() -> None:
    full = _make_heart_frame("full")
    half = _make_heart_frame("half")
    empty = _make_heart_frame("empty")

    full.save(UI_DIR / "health.png")
    full.save(UI_DIR / "heart_full.png")
    half.save(UI_DIR / "heart_half.png")
    empty.save(UI_DIR / "heart_empty.png")

    sheet = Image.new("RGBA", (48, 16), (0, 0, 0, 0))
    for index, frame in enumerate([full, half, empty]):
        sheet.alpha_composite(frame, (index * 16, 0))
    sheet.save(UI_DIR / "heart_sheet.png")
    make_preview(sheet, PREVIEW_DIR / "heart_sheet_preview.png", scale=8, grid=(16, 16))


def _make_chest_open_frame(closed: Image.Image, frame: int) -> Image.Image:
    progress = frame / 7.0
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    base = closed.crop((0, 12, 32, 32))
    lid = closed.crop((0, 0, 32, 16))
    if frame == 0:
        canvas.alpha_composite(closed)
        return canvas

    canvas.alpha_composite(base, (0, 12))
    d = ImageDraw.Draw(canvas)
    interior_y = 13 + int(progress * 2)
    d.rectangle((5, interior_y, 26, interior_y + 6), fill=(33, 22, 26, 255))
    d.rectangle((7, interior_y + 1, 24, interior_y + 3), fill=(88, 55, 34, 255))
    lid_y = int(round(3 - progress * 3))
    lid = lid.resize((32, max(8, int(16 - progress * 4))), Image.Resampling.BOX)
    canvas.alpha_composite(lid, (0, lid_y))
    if frame >= 3:
        for spark in range(frame - 2):
            px(canvas, 11 + spark * 3, interior_y - 1 - (spark % 2), (255, 214, 107, 230))
    return _quantize_rgba(canvas, 28)


def make_chest_assets_from_ai() -> None:
    if AI_HEART_CHEST_REFERENCE.exists():
        src = Image.open(AI_HEART_CHEST_REFERENCE).convert("RGBA")
        closed = _crop_pixelized(src, (1072, 185), (112, 112), (32, 32), 28)
    else:
        closed = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(closed)
        rect(d, 3, 12, 26, 15, (66, 39, 25, 255))
        rect(d, 5, 9, 22, 8, (146, 89, 42, 255))
        rect(d, 2, 11, 28, 3, (255, 214, 107, 255))
        rect(d, 14, 15, 4, 5, (85, 214, 210, 255))
    frames = [_make_chest_open_frame(closed, frame) for frame in range(8)]
    frames[0].save(PROP_DIR / "chest_closed.png")
    frames[-1].save(PROP_DIR / "chest_open.png")
    sheet = Image.new("RGBA", (32 * 8, 32), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * 32, 0))
    sheet.save(PROP_DIR / "chest_open_sheet.png")
    make_preview(sheet, PREVIEW_DIR / "chest_open_sheet_preview.png", scale=5, grid=(32, 32))


def make_delver_sheet() -> None:
    if AI_REFERENCE.exists():
        sheet = make_delver_sheet_from_ai(AI_REFERENCE)
    else:
        sheet = Image.new("RGBA", (FRAME_W * COLS, FRAME_H * ROWS), PALETTE["transparent"])
        poses = ["idle", "walk", "jump", "drill_side", "drill_up", "drill_down", "weapon_swing"]
        for row, pose in enumerate(poses):
            for col in range(COLS):
                draw_delver_frame(sheet, col, row, pose, col)
    sheet.save(SPRITE_DIR / "delver_villager_sheet.png")
    make_preview(sheet, PREVIEW_DIR / "delver_villager_sheet_preview.png", scale=6, grid=(FRAME_W, FRAME_H))


def make_tile(name: str, base: tuple[int, int, int], hi: tuple[int, int, int], shadow: tuple[int, int, int], ore: tuple[int, int, int] | None = None) -> None:
    img = Image.new("RGBA", (16, 16), (*base, 255))
    d = ImageDraw.Draw(img)
    rect(d, 0, 12, 16, 4, (*shadow, 255))
    rect(d, 2, 2, 4, 2, (*hi, 255))
    rect(d, 10, 5, 3, 2, (*hi, 255))
    rect(d, 3, 9, 5, 1, (*hi, 150))
    for p in [(5, 5), (12, 12), (8, 3), (1, 10)]:
        px(img, p[0], p[1], (*hi, 180))
    if ore:
        rect(d, 6, 4, 2, 2, (*ore, 255))
        rect(d, 10, 8, 3, 2, (255, 214, 107, 255))
        px(img, 7, 5, (255, 228, 141, 255))
    img.save(TILE_DIR / f"{name}.png")


def make_resin_tiles() -> None:
    img = Image.new("RGBA", (16, 16), (143, 95, 34, 255))
    d = ImageDraw.Draw(img)
    rect(d, 0, 11, 16, 5, (90, 53, 31, 255))
    rect(d, 3, 2, 8, 5, (198, 134, 51, 255))
    rect(d, 5, 4, 6, 2, (241, 184, 91, 255))
    rect(d, 11, 8, 3, 4, (104, 62, 28, 255))
    px(img, 4, 3, (255, 225, 130, 255))
    px(img, 9, 5, (255, 225, 130, 255))
    img.save(TILE_DIR / "hardened_resin.png")

    jelly = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(jelly)
    rect(d, 2, 3, 12, 10, (240, 211, 94, 255))
    rect(d, 4, 5, 8, 4, (255, 238, 154, 255))
    rect(d, 3, 11, 10, 2, (154, 118, 49, 255))
    px(jelly, 6, 6, (255, 255, 255, 255))
    jelly.save(TILE_DIR / "royal_jelly.png")


def make_pressure_plate() -> None:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rect(d, 1, 11, 14, 3, (36, 61, 57, 255))
    rect(d, 2, 9, 12, 3, (62, 143, 116, 255))
    rect(d, 4, 8, 8, 1, (112, 206, 177, 255))
    px(img, 11, 9, (168, 236, 205, 255))
    img.save(TILE_DIR / "pressure_plate.png")


def make_cursed_treasure() -> None:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rect(d, 1, 10, 14, 5, (55, 39, 28, 255))
    rect(d, 3, 4, 10, 8, (88, 66, 40, 255))
    rect(d, 4, 5, 8, 2, (255, 214, 107, 255))
    rect(d, 6, 8, 4, 2, (170, 111, 45, 255))
    rect(d, 7, 9, 2, 2, (112, 206, 177, 255))
    px(img, 5, 5, (255, 238, 154, 255))
    img.save(TILE_DIR / "cursed_treasure.png")


def make_dark_tile() -> None:
    img = Image.new("RGBA", (16, 16), (5, 6, 17, 255))
    d = ImageDraw.Draw(img)
    rect(d, 3, 4, 10, 8, (8, 9, 20, 255))
    rect(d, 2, 2, 2, 2, (34, 39, 70, 255))
    rect(d, 11, 12, 2, 1, (18, 22, 45, 255))
    img.save(TILE_DIR / "solid_dark_block.png")


def make_drow_tile(tile_id: str) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if tile_id == "drow_basalt_brick":
        img.paste((22, 24, 52, 255), (0, 0, 16, 16))
        rect(d, 0, 11, 16, 5, (13, 16, 35, 255))
        for y in (4, 9, 14):
            d.line((0, y, 16, y), fill=(48, 45, 95, 255))
        for x, y0, y1 in [(5, 0, 4), (11, 4, 9), (3, 9, 14), (9, 14, 16)]:
            d.line((x, y0, x, y1), fill=(48, 45, 95, 255))
        px(img, 2, 2, (112, 206, 177, 255))
        px(img, 12, 7, (72, 65, 138, 255))
    elif tile_id == "drow_carved_floor":
        img.paste((36, 44, 86, 255), (0, 0, 16, 16))
        rect(d, 0, 13, 16, 3, (20, 25, 54, 255))
        d.line((2, 8, 7, 3, 13, 8), fill=(72, 65, 138, 255))
        d.line((2, 9, 7, 14, 13, 9), fill=(72, 65, 138, 255))
        px(img, 7, 8, (112, 206, 177, 255))
        px(img, 8, 8, (85, 214, 210, 255))
    elif tile_id == "drow_mushroom_plank":
        img.paste((70, 45, 91, 255), (0, 0, 16, 16))
        rect(d, 0, 12, 16, 4, (42, 31, 62, 255))
        for y in (4, 8, 12):
            d.line((1, y, 15, y + (1 if y == 8 else 0)), fill=(137, 78, 142, 255))
        rect(d, 3, 2, 5, 1, (172, 111, 171, 255))
        px(img, 10, 6, (236, 180, 222, 255))
    elif tile_id == "drow_silk_canopy":
        img.paste((0, 0, 0, 0), (0, 0, 16, 16))
        rect(d, 0, 3, 16, 10, (98, 71, 155, 210))
        d.line((0, 4, 4, 10, 8, 4, 12, 10, 15, 5), fill=(160, 112, 220, 230))
        rect(d, 0, 12, 16, 2, (45, 36, 92, 185))
        px(img, 6, 5, (218, 188, 255, 235))
        px(img, 12, 6, (218, 188, 255, 220))
    elif tile_id == "drow_arch_inlay":
        img.paste((25, 27, 62, 255), (0, 0, 16, 16))
        rect(d, 0, 12, 16, 4, (14, 17, 40, 255))
        d.arc((2, 1, 13, 16), 180, 360, fill=(72, 65, 138, 255), width=2)
        d.arc((4, 4, 11, 15), 180, 360, fill=(160, 112, 220, 255), width=1)
        px(img, 7, 6, (112, 206, 177, 255))
    elif tile_id == "drow_glowglass":
        img.paste((24, 40, 78, 220), (0, 0, 16, 16))
        rect(d, 2, 2, 12, 12, (45, 63, 130, 230))
        rect(d, 4, 4, 8, 8, (85, 214, 210, 210))
        d.line((2, 8, 13, 8), fill=(18, 22, 45, 255))
        d.line((8, 2, 8, 13), fill=(18, 22, 45, 255))
        px(img, 5, 5, (182, 255, 236, 255))
    img.save(TILE_DIR / f"{tile_id}.png")
    return img


def make_drow_prop(prop_id: str) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline = (18, 16, 35, 255)
    if prop_id == "drow_door":
        rect(d, 4, 3, 8, 12, outline)
        rect(d, 5, 4, 6, 10, (48, 36, 70, 255))
        d.arc((4, 2, 12, 10), 180, 360, fill=(112, 206, 177, 255), width=1)
        px(img, 10, 9, (218, 188, 255, 255))
    elif prop_id == "drow_lantern":
        rect(d, 7, 1, 2, 4, outline)
        rect(d, 4, 5, 8, 8, outline)
        rect(d, 5, 6, 6, 6, (45, 63, 130, 255))
        rect(d, 6, 7, 4, 4, (85, 214, 210, 255))
        px(img, 7, 8, (182, 255, 236, 255))
    elif prop_id == "drow_silk_banner":
        rect(d, 3, 1, 2, 14, outline)
        rect(d, 5, 2, 8, 10, (98, 71, 155, 235))
        d.polygon([(5, 12), (9, 15), (13, 12)], fill=(45, 36, 92, 235))
        px(img, 8, 5, (218, 188, 255, 255))
    elif prop_id == "drow_market_crate":
        rect(d, 2, 8, 12, 6, outline)
        rect(d, 3, 9, 10, 4, (70, 45, 91, 255))
        d.line((3, 9, 13, 13), fill=(160, 112, 220, 255))
        d.line((13, 9, 3, 13), fill=(48, 36, 70, 255))
    elif prop_id == "drow_moon_shrine":
        rect(d, 3, 12, 10, 3, outline)
        rect(d, 5, 8, 6, 5, (62, 55, 119, 255))
        d.arc((4, 1, 12, 10), 90, 270, fill=(182, 255, 236, 255), width=2)
        px(img, 8, 10, (160, 112, 220, 255))
    elif prop_id == "drow_watch_crystal":
        d.polygon([(8, 1), (13, 6), (10, 14), (6, 14), (3, 6)], fill=outline)
        d.polygon([(8, 2), (12, 6), (9, 13), (7, 13), (4, 6)], fill=(45, 63, 130, 255))
        d.line((8, 2, 8, 13), fill=(85, 214, 210, 255))
        px(img, 10, 5, (182, 255, 236, 255))
    elif prop_id == "drow_bridge_post":
        rect(d, 6, 3, 4, 12, outline)
        rect(d, 7, 4, 2, 10, (72, 65, 138, 255))
        rect(d, 4, 2, 8, 3, (112, 206, 177, 255))
    elif prop_id == "drow_mushroom_lamp":
        rect(d, 7, 7, 2, 8, outline)
        d.ellipse((3, 2, 13, 9), fill=(160, 112, 220, 255))
        rect(d, 5, 6, 6, 2, (85, 214, 210, 255))
        px(img, 8, 5, (218, 188, 255, 255))
    elif prop_id == "drow_web_bridge":
        d.line((0, 8, 15, 8), fill=(218, 188, 255, 220), width=1)
        d.line((0, 11, 15, 11), fill=(98, 71, 155, 220), width=1)
        for x in (2, 6, 10, 14):
            d.line((x, 6, x - 2, 13), fill=(160, 112, 220, 190), width=1)
    img.save(PROP_DIR / f"{prop_id}.png")
    return img


def make_drow_village_assets() -> None:
    tiles: list[Image.Image] = []
    if AI_DROW_TILE_REFERENCE.exists():
        src = Image.open(AI_DROW_TILE_REFERENCE).convert("RGBA")
        centers = {
            "drow_basalt_brick": (216, 348),
            "drow_carved_floor": (568, 348),
            "drow_mushroom_plank": (916, 348),
            "drow_silk_canopy": (1264, 348),
            "drow_arch_inlay": (1616, 348),
            "drow_glowglass": (1964, 348),
        }
        for tile_id in DROW_VILLAGE_TILE_IDS:
            tile = _crop_pixelized_opaque(src, centers[tile_id], (286, 286), (16, 16), 28)
            tile.save(TILE_DIR / f"{tile_id}.png")
            tiles.append(tile)
    else:
        tiles = [make_drow_tile(tile_id) for tile_id in DROW_VILLAGE_TILE_IDS]
    props = [make_drow_prop(prop_id) for prop_id in DROW_VILLAGE_PROP_IDS]
    atlas = Image.new("RGBA", (16 * 8, 16 * 2), (0, 0, 0, 0))
    for index, tile in enumerate(tiles):
        atlas.alpha_composite(tile, ((index % 8) * 16, (index // 8) * 16))
    for index, prop in enumerate(props):
        atlas.alpha_composite(prop, (((index + len(tiles)) % 8) * 16, ((index + len(tiles)) // 8) * 16))
    atlas.save(PREVIEW_DIR / "drow_village_kit.png")
    make_preview(atlas, PREVIEW_DIR / "drow_village_kit_preview.png", scale=8, grid=(16, 16))


def make_item_icon(name: str, color: tuple[int, int, int], highlight: tuple[int, int, int], shape: str = "chunk") -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline = (28, 24, 30, 255)
    base = (*color, 255)
    hi = (*highlight, 255)
    if shape == "nugget":
        rect(d, 4, 5, 8, 6, outline)
        rect(d, 5, 5, 6, 5, base)
        px(img, 7, 6, hi)
        px(img, 10, 8, hi)
    elif shape == "shard":
        d.polygon([(8, 2), (13, 9), (8, 14), (3, 9)], fill=outline)
        d.polygon([(8, 3), (12, 9), (8, 13), (4, 9)], fill=base)
        px(img, 9, 5, hi)
        px(img, 7, 11, hi)
    elif shape == "spore":
        rect(d, 5, 4, 7, 8, outline)
        rect(d, 6, 5, 5, 6, base)
        px(img, 7, 6, hi)
        px(img, 10, 9, hi)
    elif shape == "relic":
        rect(d, 4, 3, 8, 10, outline)
        rect(d, 5, 4, 6, 8, base)
        rect(d, 6, 6, 4, 2, hi)
        px(img, 8, 10, (112, 206, 177, 255))
    elif shape == "core":
        rect(d, 4, 4, 8, 8, outline)
        rect(d, 5, 5, 6, 6, base)
        rect(d, 7, 3, 2, 10, hi)
    else:
        rect(d, 3, 6, 9, 6, outline)
        rect(d, 4, 6, 7, 5, base)
        px(img, 6, 7, hi)
        px(img, 10, 9, hi)
    img.save(ITEM_DIR / f"{name}.png")
    return img


def make_items() -> None:
    specs = [
        ("dirt_clod", (122, 75, 46), (168, 111, 60), "chunk"),
        ("stone_chunk", (89, 97, 106), (168, 180, 188), "chunk"),
        ("copper_nugget", (194, 101, 51), (255, 214, 107), "nugget"),
        ("resin_shard", (198, 134, 51), (255, 225, 130), "shard"),
        ("royal_jelly", (240, 211, 94), (255, 255, 214), "spore"),
        ("sandstone_shard", (155, 129, 80), (231, 196, 122), "shard"),
        ("cursed_relic", (88, 66, 40), (255, 214, 107), "relic"),
        ("glow_spore", (45, 63, 130), (85, 214, 210), "spore"),
        ("obsidian_chip", (23, 20, 26), (255, 93, 36), "shard"),
        ("dark_block_sliver", (5, 6, 17), (34, 39, 70), "shard"),
        ("copper_brace", (194, 101, 51), (255, 214, 107), "core"),
        ("resin_seal", (143, 95, 34), (255, 225, 130), "core"),
        ("tomb_key", (155, 129, 80), (112, 206, 177), "relic"),
        ("drow_silk", (72, 65, 138), (160, 112, 220), "shard"),
        ("heat_core", (92, 22, 20), (255, 93, 36), "core"),
    ]
    if AI_WORLD_REFERENCE.exists():
        src = Image.open(AI_WORLD_REFERENCE).convert("RGBA")
        centers = [
            ("dirt_clod", (72, 403)),
            ("stone_chunk", (178, 403)),
            ("copper_nugget", (283, 403)),
            ("resin_shard", (387, 401)),
            ("royal_jelly", (500, 405)),
            ("sandstone_shard", (603, 402)),
            ("cursed_relic", (708, 404)),
            ("glow_spore", (816, 402)),
            ("obsidian_chip", (924, 401)),
            ("dark_block_sliver", (1019, 398)),
            ("copper_brace", (1125, 406)),
            ("resin_seal", (1222, 401)),
            ("tomb_key", (1300, 395)),
            ("drow_silk", (1380, 405)),
            ("heat_core", (1474, 405)),
        ]
        icons = _save_ai_cells(src, centers, ITEM_DIR, (112, 112), (16, 16), 20)
        atlas = Image.new("RGBA", (16 * 6, 16 * 3), (0, 0, 0, 0))
        for index, icon in enumerate(icons):
            atlas.alpha_composite(icon, ((index % 6) * 16, (index // 6) * 16))
        atlas.save(ITEM_DIR / "item_icon_atlas.png")
        make_preview(atlas, PREVIEW_DIR / "item_icon_atlas_preview.png", scale=8, grid=(16, 16))
        return

    icons = []
    for spec in specs:
        icons.append(make_item_icon(*spec))
    atlas = Image.new("RGBA", (16 * 6, 16 * 3), (0, 0, 0, 0))
    for index, icon in enumerate(icons):
        atlas.alpha_composite(icon, ((index % 6) * 16, (index // 6) * 16))
    atlas.save(ITEM_DIR / "item_icon_atlas.png")
    make_preview(atlas, PREVIEW_DIR / "item_icon_atlas_preview.png", scale=8, grid=(16, 16))


def _shift_cell(cell: Image.Image, dx: int, dy: int) -> Image.Image:
    shifted = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    shifted.alpha_composite(cell, (dx, dy))
    return shifted


def _animated_enemy_cell(cell: Image.Image, move_row: int, frame: int) -> Image.Image:
    offsets = {
        0: [(0, 0), (0, 0), (0, -1), (0, -1), (0, 0), (0, 0), (0, 1), (0, 0)],
        1: [(-1, 0), (0, 0), (1, 1), (1, 0), (0, 0), (-1, 1), (-1, 0), (0, -1)],
        2: [(0, 0), (1, 0), (2, -1), (1, 0), (0, 0), (-1, 1), (0, 0), (0, 0)],
        3: [(1, 0), (0, -1), (-1, 0), (0, 1), (1, 0), (0, -1), (-1, 0), (0, 0)],
    }
    dx, dy = offsets[move_row][frame % ENEMY_COLS]
    return _shift_cell(cell, dx, dy)


def _draw_enemy_cell(
    sheet: Image.Image,
    origin: tuple[int, int],
    base: tuple[int, int, int],
    highlight: tuple[int, int, int],
    kind: str,
    frame: int,
    move_row: int,
) -> None:
    ox, oy = origin
    d = ImageDraw.Draw(sheet)
    outline = (32, 21, 29, 255)
    attack = move_row == 2
    hurt = move_row == 3
    bob = [0, 0, 1, 0, 0, 1, 0, -1][frame % ENEMY_COLS]
    recoil = 1 if hurt and frame % 2 == 0 else 0
    lunge = 2 if attack and frame in (2, 3) else 0
    if kind == "skitter":
        y = oy + 22 + bob
        rect(d, ox + 8 + lunge - recoil, y - 8, 17, 8, outline)
        rect(d, ox + 10 + lunge - recoil, y - 7, 13, 6, (*base, 255))
        px(sheet, ox + 22 + lunge - recoil, y - 6, (*highlight, 255))
        for leg in [7, 12, 19, 24]:
            leg_swing = -2 if frame % 2 == 0 else 2
            d.line((ox + leg, y - 1, ox + leg + leg_swing, y + 3), fill=outline, width=1)
    elif kind == "ant_worker":
        y = oy + 22 + bob
        rect(d, ox + 5 + lunge - recoil, y - 9, 22, 9, outline)
        rect(d, ox + 7 + lunge - recoil, y - 8, 8, 7, (*base, 255))
        rect(d, ox + 15 + lunge - recoil, y - 7, 9, 6, (143, 95, 34, 255))
        px(sheet, ox + 24 + lunge - recoil, y - 6, (*highlight, 255))
        d.line((ox + 24 + lunge, y - 8, ox + 28 + lunge, y - 12), fill=outline)
        d.line((ox + 24 + lunge, y - 7, ox + 29 + lunge, y - 6), fill=outline)
    elif kind == "ant_soldier":
        y = oy + 22 + bob
        rect(d, ox + 3 + lunge - recoil, y - 12, 26, 12, outline)
        rect(d, ox + 5 + lunge - recoil, y - 10, 10, 8, (*base, 255))
        rect(d, ox + 15 + lunge - recoil, y - 9, 10, 7, (90, 53, 31, 255))
        rect(d, ox + 24 + lunge - recoil, y - 7, 6, 2 + frame % 2, (*highlight, 255))
        px(sheet, ox + 25 + lunge - recoil, y - 8, (255, 225, 130, 255))
    elif kind == "worm_head":
        y = oy + 23 + bob
        rect(d, ox + 3 + lunge - recoil, y - 13, 24, 13, outline)
        rect(d, ox + 5 + lunge - recoil, y - 11, 19, 10, (*base, 255))
        rect(d, ox + 22 + lunge - recoil, y - 9, 7, 7, (52, 38, 36, 255))
        rect(d, ox + 24 + lunge - recoil, y - 7, 3 + frame % 2, 2, (234, 215, 176, 255))
        px(sheet, ox + 18 + lunge - recoil, y - 9, (*highlight, 255))
    elif kind == "worm_segment":
        y = oy + 22 + bob
        rect(d, ox + 8 - recoil, y - 10, 16, 10, outline)
        rect(d, ox + 9 - recoil, y - 9, 14, 8, (*base, 255))
        rect(d, ox + 11 + frame % 2 - recoil, y - 7, 9, 2, (*highlight, 255))
    elif kind == "boss":
        rect(d, ox + 4 + lunge - recoil, oy + 4 + bob, 24, 25, outline)
        rect(d, ox + 6 + lunge - recoil, oy + 6 + bob, 20, 21, (*base, 255))
        rect(d, ox + 8 + lunge - recoil, oy + 8 + bob + frame % 2, 16, 3, (*highlight, 255))
        rect(d, ox + 11 + lunge - recoil, oy + 14 + bob, 10, 8, (30, 25, 31, 255))
        px(sheet, ox + 16 + lunge - recoil, oy + 12 + bob, (255, 238, 154, 255))
    else:
        rect(d, ox + 9 + lunge - recoil, oy + 5 + bob, 12, 24, outline)
        rect(d, ox + 10 + lunge - recoil, oy + 7 + bob, 10, 20, (*base, 255))
        rect(d, ox + 11 + lunge - recoil, oy + 9 + bob + frame % 2, 8, 2, (*highlight, 255))
        rect(d, ox + 8 + lunge - recoil, oy + 14 + bob, 4, 9, outline)
        rect(d, ox + 20 + lunge - recoil, oy + 14 + bob + frame % 2, 4, 9, outline)
        px(sheet, ox + 17 + lunge - recoil, oy + 12 + bob, (112, 206, 177, 255))


def make_enemy_sheet(enemy_id: str, base: tuple[int, int, int], highlight: tuple[int, int, int], kind: str) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_W * ENEMY_COLS, FRAME_H * ENEMY_ROWS), (0, 0, 0, 0))
    for move_row in range(ENEMY_ROWS):
        for frame in range(ENEMY_COLS):
            _draw_enemy_cell(
                sheet,
                (frame * FRAME_W, move_row * FRAME_H),
                base,
                highlight,
                kind,
                frame,
                move_row,
            )
    sheet.save(ENEMY_DIR / f"{enemy_id}.png")
    return sheet


def make_enemies() -> None:
    specs = [
        ("cave_skitter", (139, 70, 80), (232, 213, 161), "skitter"),
        ("worker_ant", (198, 134, 51), (255, 225, 130), "ant_worker"),
        ("soldier_ant", (143, 95, 34), (255, 138, 31), "ant_soldier"),
        ("mummy_sentry", (210, 179, 106), (112, 206, 177), "mummy"),
        ("tunneling_worm_head", (122, 49, 66), (255, 138, 31), "worm_head"),
        ("tunneling_worm_segment", (122, 49, 66), (192, 106, 83), "worm_segment"),
        ("rootbound_foreman", (110, 74, 48), (255, 214, 107), "boss"),
        ("amber_queen", (143, 95, 34), (255, 225, 130), "boss"),
        ("pharaoh_of_buried_sun", (155, 129, 80), (112, 206, 177), "boss"),
        ("drow_matriarch", (45, 63, 130), (85, 214, 210), "boss"),
        ("obsidian_baron", (23, 20, 26), (255, 93, 36), "boss"),
    ]
    if AI_ENEMY_REFERENCE.exists():
        src = Image.open(AI_ENEMY_REFERENCE).convert("RGBA")
        enemy_rows = [
            ("cave_skitter", 72, (170, 120)),
            ("worker_ant", 190, (170, 135)),
            ("soldier_ant", 316, (180, 140)),
            ("mummy_sentry", 464, (180, 160)),
            ("tunneling_worm_head", 610, (190, 140)),
            ("tunneling_worm_segment", 746, (170, 120)),
            ("rootbound_foreman", 880, (210, 170)),
            ("amber_queen", 1048, (220, 170)),
            ("pharaoh_of_buried_sun", 1230, (220, 180)),
            ("drow_matriarch", 1403, (210, 180)),
            ("obsidian_baron", 1560, (220, 180)),
        ]
        centers_x = [140, 338, 537, 732]
        sheets = []
        for enemy_id, center_y, crop_size in enemy_rows:
            pose_cells: list[Image.Image] = []
            for center_x in centers_x:
                pose_cells.append(_crop_pixelized(src, (center_x, center_y), crop_size, (FRAME_W, FRAME_H), 28))
            sheet = Image.new("RGBA", (FRAME_W * ENEMY_COLS, FRAME_H * ENEMY_ROWS), (0, 0, 0, 0))
            for move_row, pose_cell in enumerate(pose_cells):
                for frame in range(ENEMY_COLS):
                    cell = _animated_enemy_cell(pose_cell, move_row, frame)
                    sheet.alpha_composite(cell, (frame * FRAME_W, move_row * FRAME_H))
            sheet.save(ENEMY_DIR / f"{enemy_id}.png")
            sheets.append(sheet)
        atlas = Image.new("RGBA", (FRAME_W * ENEMY_COLS, FRAME_H * ENEMY_ROWS * len(sheets)), (0, 0, 0, 0))
        for index, sheet in enumerate(sheets):
            atlas.alpha_composite(sheet, (0, index * FRAME_H * ENEMY_ROWS))
        atlas.save(ENEMY_DIR / "enemy_sheet_atlas.png")
        make_preview(atlas, PREVIEW_DIR / "enemy_sheet_atlas_preview.png", scale=6, grid=(FRAME_W, FRAME_H))
        return

    sheets = []
    for spec in specs:
        sheets.append(make_enemy_sheet(*spec))
    atlas = Image.new("RGBA", (FRAME_W * ENEMY_COLS, FRAME_H * ENEMY_ROWS * len(sheets)), (0, 0, 0, 0))
    for index, sheet in enumerate(sheets):
        atlas.alpha_composite(sheet, (0, index * FRAME_H * ENEMY_ROWS))
    atlas.save(ENEMY_DIR / "enemy_sheet_atlas.png")
    make_preview(atlas, PREVIEW_DIR / "enemy_sheet_atlas_preview.png", scale=6, grid=(FRAME_W, FRAME_H))


def make_ui_icons() -> None:
    if AI_WORLD_REFERENCE.exists():
        src = Image.open(AI_WORLD_REFERENCE).convert("RGBA")
        ui_specs = [
            ("health", (78, 608)),
            ("drill_heat", (205, 615)),
            ("quickbar_slot", (334, 611)),
            ("quickbar_selected", (473, 619)),
            ("inventory_slot", (596, 628)),
            ("flare_bundle", (728, 620)),
            ("outpost_beacon", (849, 613)),
            ("copper_brace", (974, 615)),
            ("resin_seal", (1096, 616)),
            ("tomb_key", (1197, 611)),
            ("light", (1294, 618)),
            ("danger_pulse", (1440, 609)),
        ]
        icons = _save_ai_cells(src, ui_specs, UI_DIR, (112, 112), (16, 16), 22)
        atlas = Image.new("RGBA", (16 * 6, 16 * 2), (0, 0, 0, 0))
        for index, icon in enumerate(icons):
            atlas.alpha_composite(icon, ((index % 6) * 16, (index // 6) * 16))
        atlas.save(UI_DIR / "ui_icon_atlas.png")
        make_preview(atlas, PREVIEW_DIR / "ui_icon_atlas_preview.png", scale=8, grid=(16, 16))
        make_heart_assets_from_ai()

        hud_order = ["health", "drill_heat", "copper_brace", "flare_bundle", "outpost_beacon", "copper_brace"]
        hud = Image.new("RGBA", (96, 16), (0, 0, 0, 0))
        for index, name in enumerate(hud_order):
            hud.alpha_composite(Image.open(UI_DIR / f"{name}.png").convert("RGBA"), (index * 16, 0))
        hud.save(UI_DIR / "hud_icons.png")
        make_preview(hud, PREVIEW_DIR / "hud_icons_preview.png", scale=8, grid=None)
        return

    img = Image.new("RGBA", (96, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Health
    rect(d, 3, 4, 4, 4, (201, 78, 78, 255))
    rect(d, 8, 4, 4, 4, (201, 78, 78, 255))
    rect(d, 4, 8, 7, 4, (201, 78, 78, 255))
    px(img, 6, 5, (255, 160, 142, 255))
    # Heat
    rect(d, 20, 3, 10, 10, (197, 138, 50, 255))
    rect(d, 22, 5, 6, 6, (255, 138, 31, 255))
    # Drill
    rect(d, 36, 6, 6, 4, PALETTE["drill"])
    rect(d, 42, 5, 5, 6, PALETTE["steel_shadow"])
    px(img, 47, 8, PALETTE["steel"])
    # Flare
    rect(d, 53, 5, 4, 8, (99, 56, 28, 255))
    rect(d, 54, 2, 5, 5, (255, 138, 31, 255))
    px(img, 56, 1, (255, 214, 107, 255))
    # Beacon
    rect(d, 68, 4, 8, 9, (63, 58, 57, 255))
    rect(d, 70, 6, 4, 5, (255, 214, 107, 255))
    # Copper
    rect(d, 83, 5, 8, 7, (169, 94, 48, 255))
    px(img, 87, 6, (255, 214, 107, 255))
    img.save(UI_DIR / "hud_icons.png")
    make_preview(img, PREVIEW_DIR / "hud_icons_preview.png", scale=8, grid=None)

    ui_specs = [
        ("health", (201, 78, 78), (255, 160, 142), "heart"),
        ("drill_heat", (197, 138, 50), (255, 138, 31), "bar"),
        ("quickbar_slot", (39, 34, 31), (108, 89, 61), "slot"),
        ("quickbar_selected", (39, 34, 31), (255, 214, 107), "slot_selected"),
        ("inventory_slot", (24, 23, 36), (92, 102, 112), "slot"),
        ("flare_bundle", (255, 138, 31), (255, 214, 107), "torch"),
        ("outpost_beacon", (192, 139, 62), (255, 214, 107), "beacon"),
        ("copper_brace", (194, 101, 51), (255, 214, 107), "brace"),
        ("resin_seal", (143, 95, 34), (255, 225, 130), "seal"),
        ("tomb_key", (155, 129, 80), (112, 206, 177), "key"),
        ("light", (255, 214, 107), (255, 238, 154), "spark"),
        ("danger_pulse", (201, 78, 78), (255, 138, 31), "warning"),
    ]
    icons = []
    for name, color, highlight, kind in ui_specs:
        icon = _make_ui_icon(color, highlight, kind)
        icon.save(UI_DIR / f"{name}.png")
        icons.append(icon)
    make_heart_assets_from_ai()
    atlas = Image.new("RGBA", (16 * 6, 16 * 2), (0, 0, 0, 0))
    for index, icon in enumerate(icons):
        atlas.alpha_composite(icon, ((index % 6) * 16, (index // 6) * 16))
    atlas.save(UI_DIR / "ui_icon_atlas.png")
    make_preview(atlas, PREVIEW_DIR / "ui_icon_atlas_preview.png", scale=8, grid=(16, 16))


def _make_ui_icon(color: tuple[int, int, int], highlight: tuple[int, int, int], kind: str) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = (*color, 255)
    hi = (*highlight, 255)
    border = (24, 23, 36, 255)
    if kind == "heart":
        rect(d, 3, 4, 4, 4, base)
        rect(d, 8, 4, 4, 4, base)
        rect(d, 4, 8, 7, 4, base)
        px(img, 6, 5, hi)
    elif kind == "bar":
        rect(d, 3, 4, 10, 8, border)
        rect(d, 5, 6, 6, 4, base)
        px(img, 10, 7, hi)
    elif kind == "slot_selected":
        rect(d, 1, 1, 14, 14, border)
        rect(d, 2, 2, 12, 12, (39, 34, 31, 255))
        rect(d, 1, 1, 4, 2, hi)
        rect(d, 11, 13, 4, 2, hi)
    elif kind == "slot":
        rect(d, 1, 1, 14, 14, border)
        rect(d, 3, 3, 10, 10, base)
        px(img, 4, 4, hi)
    elif kind == "torch":
        rect(d, 7, 7, 3, 7, (99, 56, 28, 255))
        rect(d, 6, 3, 5, 5, base)
        px(img, 8, 2, hi)
    elif kind == "beacon":
        rect(d, 5, 5, 6, 8, border)
        rect(d, 6, 6, 4, 5, base)
        px(img, 8, 7, hi)
    elif kind == "brace":
        rect(d, 4, 4, 8, 8, border)
        rect(d, 5, 5, 6, 6, base)
        rect(d, 7, 5, 2, 6, hi)
    elif kind == "seal":
        rect(d, 4, 4, 8, 8, border)
        rect(d, 5, 5, 6, 6, base)
        px(img, 8, 8, hi)
    elif kind == "key":
        rect(d, 4, 4, 5, 5, border)
        rect(d, 5, 5, 3, 3, base)
        rect(d, 8, 7, 5, 2, hi)
        px(img, 12, 9, hi)
    elif kind == "warning":
        d.polygon([(8, 2), (14, 13), (2, 13)], fill=border)
        d.polygon([(8, 4), (12, 12), (4, 12)], fill=base)
        px(img, 8, 10, hi)
    else:
        rect(d, 7, 2, 2, 12, hi)
        rect(d, 2, 7, 12, 2, hi)
        px(img, 8, 8, base)
    return img


def make_props_and_effects() -> None:
    if AI_WORLD_REFERENCE.exists():
        src = Image.open(AI_WORLD_REFERENCE).convert("RGBA")
        prop_specs = [
            ("flare", (66, 845)),
            ("outpost_beacon", (183, 859)),
            ("dart_trap", (1263, 863)),
            ("dart_projectile", (1353, 866)),
            ("pressure_plate_depressed", (1456, 900)),
        ]
        _save_ai_cells(src, prop_specs, PROP_DIR, (112, 112), (16, 16), 22)
        make_chest_assets_from_ai()
        effect_specs = [
            ("tile_crack_1", (305, 855)),
            ("tile_crack_2", (397, 857)),
            ("tile_crack_3", (543, 853)),
            ("drill_impact_spark", (652, 882)),
            ("pickup_magnet", (776, 859)),
            ("worm_telegraph_crescent", (891, 867)),
            ("worm_dust_crack", (1023, 890)),
            ("enemy_hit_flash", (1149, 857)),
        ]
        _save_ai_cells(src, effect_specs, EFFECT_DIR, (112, 112), (16, 16), 22)
        crack_frames = make_tile_breaking_frames("tile_break", save_compat=True)
        make_material_breaking_sheets()
        sparks = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
        sparks.alpha_composite(Image.open(EFFECT_DIR / "drill_impact_spark.png").convert("RGBA"), (0, 0))
        sparks.alpha_composite(Image.open(EFFECT_DIR / "enemy_hit_flash.png").convert("RGBA"), (16, 0))
        sparks.save(EFFECT_DIR / "drill_sparks.png")

        preview = Image.new("RGBA", (128, 16), (0, 0, 0, 0))
        preview_cells = [
            Image.open(PROP_DIR / "outpost_beacon.png").convert("RGBA"),
            Image.open(PROP_DIR / "flare.png").convert("RGBA"),
            crack_frames[-1],
            Image.open(EFFECT_DIR / "drill_impact_spark.png").convert("RGBA"),
            Image.open(EFFECT_DIR / "worm_telegraph_crescent.png").convert("RGBA"),
            Image.open(EFFECT_DIR / "worm_dust_crack.png").convert("RGBA"),
            Image.open(EFFECT_DIR / "enemy_hit_flash.png").convert("RGBA"),
            Image.open(PROP_DIR / "dart_projectile.png").convert("RGBA"),
        ]
        for index, cell in enumerate(preview_cells):
            preview.alpha_composite(cell, (index * 16, 0))
        make_preview(preview, PREVIEW_DIR / "props_effects_preview.png", scale=8, grid=(16, 16))
        return

    beacon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(beacon)
    rect(d, 6, 4, 4, 10, (63, 58, 57, 255))
    rect(d, 5, 6, 6, 5, (192, 139, 62, 255))
    rect(d, 6, 7, 4, 3, (255, 214, 107, 255))
    px(beacon, 8, 5, (255, 238, 154, 255))
    beacon.save(PROP_DIR / "outpost_beacon.png")

    flare = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(flare)
    rect(d, 7, 7, 3, 7, (99, 56, 28, 255))
    rect(d, 6, 3, 5, 5, (255, 138, 31, 255))
    px(flare, 8, 2, (255, 214, 107, 255))
    flare.save(PROP_DIR / "flare.png")

    crack_frames = make_tile_breaking_frames("tile_break", save_compat=True)
    make_material_breaking_sheets()

    sparks = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    for i, (x, y) in enumerate([(4, 9), (10, 5), (15, 11), (22, 6), (28, 10)]):
        px(sparks, x, y, (255, 214, 107, 255))
        px(sparks, x + 1, y, (255, 138, 31, 255))
    sparks.save(EFFECT_DIR / "drill_sparks.png")
    sparks.crop((0, 0, 16, 16)).save(EFFECT_DIR / "drill_impact_spark.png")

    magnet = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(magnet)
    d.arc((3, 3, 13, 13), 30, 330, fill=(85, 214, 210, 255), width=1)
    px(magnet, 8, 8, (255, 255, 214, 255))
    magnet.save(EFFECT_DIR / "pickup_magnet.png")

    crescent = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(crescent)
    d.arc((2, 6, 14, 18), 200, 340, fill=(255, 138, 31, 255), width=2)
    px(crescent, 8, 12, (255, 214, 107, 255))
    crescent.save(EFFECT_DIR / "worm_telegraph_crescent.png")

    dust = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(dust)
    d.line((3, 9, 7, 12, 12, 10), fill=(168, 111, 60, 255), width=1)
    px(dust, 5, 8, (255, 214, 107, 255))
    dust.save(EFFECT_DIR / "worm_dust_crack.png")

    hit = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(hit)
    d.line((2, 8, 14, 8), fill=(255, 255, 255, 255), width=1)
    d.line((8, 2, 8, 14), fill=(255, 214, 107, 255), width=1)
    hit.save(EFFECT_DIR / "enemy_hit_flash.png")

    dart_trap = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(dart_trap)
    rect(d, 1, 4, 14, 8, (88, 66, 40, 255))
    rect(d, 10, 7, 3, 2, (112, 206, 177, 255))
    dart_trap.save(PROP_DIR / "dart_trap.png")

    dart = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(dart)
    rect(d, 3, 7, 8, 2, (188, 196, 196, 255))
    px(dart, 12, 8, (255, 214, 107, 255))
    dart.save(PROP_DIR / "dart_projectile.png")

    depressed = Image.open(TILE_DIR / "pressure_plate.png").convert("RGBA")
    d = ImageDraw.Draw(depressed)
    rect(d, 2, 10, 12, 3, (36, 61, 57, 255))
    depressed.save(PROP_DIR / "pressure_plate_depressed.png")
    make_chest_assets_from_ai()

    preview = Image.new("RGBA", (128, 16), (0, 0, 0, 0))
    preview.alpha_composite(beacon, (0, 0))
    preview.alpha_composite(flare, (16, 0))
    preview.alpha_composite(crack_frames[-1], (32, 0))
    preview.alpha_composite(sparks.crop((0, 0, 16, 16)), (48, 0))
    preview.alpha_composite(crescent, (64, 0))
    preview.alpha_composite(dust, (80, 0))
    preview.alpha_composite(hit, (96, 0))
    preview.alpha_composite(dart, (112, 0))
    make_preview(preview, PREVIEW_DIR / "props_effects_preview.png", scale=8, grid=(16, 16))


def make_tile_breaking_frames(prefix: str, colors: dict[str, tuple[int, int, int, int]] | None = None, save_compat: bool = False) -> list[Image.Image]:
    """Generate transparent tile damage overlays that ramp from hairline cracks to collapse."""
    colors = colors or {"shadow": (64, 43, 36, 210), "mid": (214, 176, 113, 225), "hi": (255, 224, 161, 225), "chip": (255, 238, 154, 240)}
    crack_hi = colors["hi"]
    crack_mid = colors["mid"]
    crack_shadow = colors["shadow"]
    chip = colors["chip"]
    frames: list[Image.Image] = []
    crack_lines = [
        [((5, 2), (7, 5), (6, 8))],
        [((5, 2), (8, 6), (6, 10), (7, 13)), ((10, 5), (8, 8), (11, 10))],
        [((4, 2), (8, 6), (6, 11), (8, 14)), ((11, 4), (8, 8), (12, 13)), ((3, 11), (6, 9), (2, 7))],
        [((4, 2), (8, 6), (6, 11), (8, 14)), ((12, 3), (8, 8), (12, 13)), ((3, 12), (7, 8), (2, 5)), ((13, 10), (10, 9), (9, 13))],
        [((3, 1), (8, 6), (6, 11), (8, 15)), ((13, 2), (8, 8), (13, 14)), ((2, 13), (7, 8), (1, 5)), ((14, 10), (10, 8), (8, 13)), ((5, 4), (11, 5), (14, 7))],
    ]
    chip_pixels = [
        [(6, 5)],
        [(6, 5), (10, 9)],
        [(6, 5), (10, 9), (4, 12), (12, 5)],
        [(6, 5), (10, 9), (4, 12), (12, 5), (8, 13), (3, 6)],
        [(6, 5), (10, 9), (4, 12), (12, 5), (8, 13), (3, 6), (13, 12), (7, 2)],
    ]
    for index in range(BREAK_STAGE_COUNT):
        cracks = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(cracks)
        for points in crack_lines[index]:
            flattened: list[int] = []
            for point in points:
                flattened.extend([point[0], point[1]])
            shadow = tuple(value + offset for point in points for value, offset in zip(point, (1, 1)))
            d.line(shadow, fill=crack_shadow, width=1)
            d.line(tuple(flattened), fill=crack_hi if index >= 3 else crack_mid, width=1)
        if index >= 2:
            d.line((2, 14, 13, 3), fill=crack_shadow, width=1)
            d.line((2, 13, 12, 3), fill=(255, 214, 107, 180), width=1)
        for px_x, px_y in chip_pixels[index]:
            px(cracks, px_x, px_y, chip)
        if index >= 3:
            rect(d, 1, 14, 3, 1, crack_shadow)
            rect(d, 12, 1, 2, 1, chip)
        cracks.save(EFFECT_DIR / f"{prefix}_stage_{index + 1}.png")
        frames.append(cracks)

    if save_compat:
        frames[0].save(EFFECT_DIR / "tile_crack_1.png")
        frames[2].save(EFFECT_DIR / "tile_crack_2.png")
        frames[4].save(EFFECT_DIR / "tile_crack_3.png")
        frames[4].save(EFFECT_DIR / "tile_crack_overlay.png")

    sheet = Image.new("RGBA", (16 * BREAK_STAGE_COUNT, 16), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * 16, 0))
    sheet_name = "tile_breaking_sheet.png" if prefix == "tile_break" else f"{prefix}_sheet.png"
    sheet.save(EFFECT_DIR / sheet_name)
    make_preview(sheet, PREVIEW_DIR / sheet_name.replace(".png", "_preview.png"), scale=8, grid=(16, 16))
    return frames


def make_material_breaking_sheets() -> None:
    combined = Image.new("RGBA", (16 * BREAK_STAGE_COUNT, 16 * len(BREAK_MATERIALS)), (0, 0, 0, 0))
    for row, (tile_id, colors) in enumerate(BREAK_MATERIALS.items()):
        frames = make_tile_breaking_frames(f"tile_breaking_{tile_id}", colors, save_compat=False)
        for frame_index, frame in enumerate(frames):
            combined.alpha_composite(frame, (frame_index * 16, row * 16))
    make_preview(combined, PREVIEW_DIR / "tile_breaking_materials_preview.png", scale=8, grid=(16, 16))


def make_preview(img: Image.Image, output: Path, scale: int, grid: tuple[int, int] | None) -> None:
    preview = img.resize((img.width * scale, img.height * scale), Image.Resampling.NEAREST)
    if grid:
        d = ImageDraw.Draw(preview)
        gw, gh = grid
        for x in range(0, img.width + 1, gw):
            d.line((x * scale, 0, x * scale, preview.height), fill=(40, 44, 56, 255), width=1)
        for y in range(0, img.height + 1, gh):
            d.line((0, y * scale, preview.width, y * scale), fill=(40, 44, 56, 255), width=1)
    output.parent.mkdir(parents=True, exist_ok=True)
    preview.save(output)


def make_tiles() -> None:
    if AI_WORLD_REFERENCE.exists():
        src = Image.open(AI_WORLD_REFERENCE).convert("RGBA")
        tile_specs = [
            ("loose_dirt", (79, 177)),
            ("compacted_dirt", (208, 176)),
            ("soft_stone", (339, 176)),
            ("copper_ore", (467, 176)),
            ("hardened_resin", (595, 176)),
            ("royal_jelly", (714, 184)),
            ("sandstone_block", (837, 177)),
            ("pressure_plate", (959, 178)),
            ("cursed_treasure", (1084, 179)),
            ("glow_mushroom_loam", (1308, 177)),
            ("obsidian_ash", (1365, 178)),
            ("solid_dark_block", (1450, 177)),
        ]
        tiles = _save_ai_cells(src, tile_specs, TILE_DIR, (112, 112), (16, 16), 24)
        atlas = Image.new("RGBA", (16 * 6, 16 * 2), (0, 0, 0, 0))
        for index, tile in enumerate(tiles):
            atlas.alpha_composite(tile, ((index % 6) * 16, (index // 6) * 16))
        atlas.save(TILE_DIR / "deepbound_tile_samples.png")
        make_preview(atlas, PREVIEW_DIR / "deepbound_tile_samples_preview.png", scale=8, grid=(16, 16))
        make_drow_village_assets()
        return

    make_tile("loose_dirt", (122, 75, 46), (168, 111, 60), (95, 61, 43))
    make_tile("compacted_dirt", (95, 61, 43), (141, 90, 54), (59, 42, 36))
    make_tile("soft_stone", (89, 97, 106), (136, 147, 154), (52, 60, 69))
    make_tile("copper_ore", (89, 97, 106), (136, 147, 154), (52, 60, 69), (240, 168, 79))
    make_tile("sandstone_block", (155, 129, 80), (210, 179, 106), (102, 78, 47))
    make_tile("obsidian_ash", (23, 20, 26), (255, 93, 36), (9, 9, 15))
    make_tile("glow_mushroom_loam", (45, 63, 130), (85, 214, 210), (22, 28, 69))
    make_resin_tiles()
    make_pressure_plate()
    make_cursed_treasure()
    make_dark_tile()

    atlas = Image.new("RGBA", (16 * 5, 16 * 2), (0, 0, 0, 0))
    names = [
        "loose_dirt",
        "soft_stone",
        "copper_ore",
        "hardened_resin",
        "royal_jelly",
        "pressure_plate",
        "cursed_treasure",
        "sandstone_block",
        "glow_mushroom_loam",
        "obsidian_ash",
        "solid_dark_block",
    ]
    for i, name in enumerate(names):
        tile = Image.open(TILE_DIR / f"{name}.png").convert("RGBA")
        atlas.alpha_composite(tile, ((i % 5) * 16, (i // 5) * 16))
    atlas.save(TILE_DIR / "deepbound_tile_samples.png")
    make_preview(atlas, PREVIEW_DIR / "deepbound_tile_samples_preview.png", scale=8, grid=(16, 16))
    make_drow_village_assets()


def main() -> None:
    ensure_dirs()
    make_delver_sheet()
    make_tiles()
    make_items()
    make_enemies()
    make_ui_icons()
    make_props_and_effects()


if __name__ == "__main__":
    main()
