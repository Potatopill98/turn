# -*- coding: utf-8 -*-
"""modernize_whitebox.py —— 把等距白盒地图的内容从「地牢」改成「现代中国小镇」。

在 whitebox_mapgen.py 生成的 96x96 灰阶白盒基础上做三件事：
1) 重绘 tileset.png 的 prop 槽位（第 17 行 16 格，gid 257-272）：
   地牢物件 -> 现代小镇物件（路灯/电线杆/树/长椅/汽车/电动车/秋千/滑梯/旋转木马/垃圾桶/花坛…）。
2) 在 ground 层挖出池塘（water 角色 gid 65-96）、绿地（grass gid 129-160）、
   在 detail 层沿街布路灯、在游乐场区布秋千/滑梯/旋转木马。
3) 把 objects 层 15 个叙事 POI 重新落到与示意图/剧情对应的地标位置。

输出覆盖同名文件（json/tmx/csv/tileset.png），并重建 preview/overview。
灰阶保持：所有新绘制物件仍是低饱和灰阶体块，符合白盒定义。
"""
from __future__ import annotations

import csv
import json
import os
import re
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))

# ---- 角色 GID 基址（见 spec.default_roles：每角色 2 变体 x16 = 32 张，firstgid=1）----
ROLE_BASE = {
    "floor": 1, "wall": 33, "water": 65, "sand": 97,
    "grass": 129, "forest": 161, "rock": 193, "snow": 225, "prop": 257,
}
TW, TH = 64, 32           # 瓦片尺寸
COLS, ROWS = 16, 17       # 图集 16 列 x 17 行（272 张）
PROP_ROW = 16             # prop 在第 17 行

# 现代装饰槽位 -> 与 PROP_NAMES 一一对应的 16 类
# 槽位 0..15 依次：路灯/电线杆/行道树/长椅/小汽车/电动车/秋千/滑梯/旋转木马/垃圾桶/花坛/邮筒/空调外机/遮阳伞/石桥栏/消防栓
MODERN_PROPS = [
    "street_lamp", "power_pole", "tree", "bench", "car", "scooter",
    "swing", "slide", "carousel", "trash_bin", "flower_bed", "mailbox",
    "ac_unit", "parasol", "bridge_rail", "hydrant",
]
# 关键槽位索引（对应上面的序号）
SL = {name: i for i, name in enumerate(MODERN_PROPS)}

# 灰阶调色（与白盒一致：明度分档）
G_DARK = (70, 70, 70)
G_MID = (120, 120, 120)
G_LIGHT = (180, 180, 180)
G_WHITE = (225, 225, 225)
G_SHADOW = (52, 52, 52)


# --------------------------------------------------------------------------
# 1) 重绘 prop 槽位（每个 64x32 菱形格，四角透明）
# --------------------------------------------------------------------------
def _diamond_mask(cx, cy, hw=32, hh=16):
    """菱形瓦片多边形顶点（中心 cx,cy，半宽 32 半高 16）。"""
    return [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]


def _draw_prop(draw, ox, oy, idx):
    """在 (ox,oy) 为左上角的 64x32 格里画第 idx 个现代物件（灰阶体块）。"""
    cx = ox + 32
    ground = oy + 26          # 贴地线
    name = MODERN_PROPS[idx]

    def pole(x, top, bottom, w=2, color=G_MID):
        draw.rectangle([x - w // 2, top, x + w // 2, bottom], fill=color)

    if name == "street_lamp":
        pole(cx, oy + 6, ground, 2, G_DARK)
        draw.line([(cx, oy + 7), (cx + 12, oy + 7)], fill=G_DARK, width=2)
        draw.ellipse([cx + 8, oy + 5, cx + 16, oy + 11], fill=G_WHITE)
    elif name == "power_pole":
        pole(cx, oy + 4, ground, 3, G_DARK)
        draw.line([(cx - 14, oy + 8), (cx + 14, oy + 8)], fill=G_DARK, width=2)
        draw.line([(cx - 10, oy + 12), (cx + 10, oy + 12)], fill=G_DARK, width=2)
        for dx in (-14, 14):
            draw.ellipse([cx + dx - 2, oy + 6, cx + dx + 2, oy + 10], fill=G_LIGHT)
    elif name == "tree":
        pole(cx, ground - 10, ground, 3, G_DARK)
        draw.ellipse([cx - 12, oy + 4, cx + 12, oy + 20], fill=G_MID)
        draw.ellipse([cx - 7, oy + 2, cx + 8, oy + 15], fill=G_LIGHT)
    elif name == "bench":
        draw.rectangle([cx - 12, ground - 5, cx + 12, ground - 2], fill=G_MID)
        draw.rectangle([cx - 12, ground - 10, cx + 12, ground - 7], fill=G_LIGHT)
        pole(cx - 9, ground - 5, ground, 2, G_DARK)
        pole(cx + 9, ground - 5, ground, 2, G_DARK)
    elif name == "car":
        draw.rectangle([cx - 18, ground - 8, cx + 18, ground - 2], fill=G_MID)
        draw.rectangle([cx - 9, ground - 13, cx + 8, ground - 8], fill=G_DARK)
        draw.ellipse([cx - 14, ground - 3, cx - 8, ground + 1], fill=G_SHADOW)
        draw.ellipse([cx + 8, ground - 3, cx + 14, ground + 1], fill=G_SHADOW)
    elif name == "scooter":
        draw.ellipse([cx - 8, ground - 4, cx - 2, ground + 1], fill=G_SHADOW)
        draw.ellipse([cx + 3, ground - 4, cx + 9, ground + 1], fill=G_SHADOW)
        draw.line([(cx - 5, ground - 4), (cx + 3, ground - 12)], fill=G_DARK, width=2)
        draw.line([(cx + 6, ground - 4), (cx + 3, ground - 12)], fill=G_DARK, width=2)
        pole(cx + 3, ground - 14, ground - 11, 2, G_MID)
    elif name == "swing":
        draw.line([(cx - 10, ground - 16), (cx - 5, ground)], fill=G_DARK, width=2)
        draw.line([(cx + 10, ground - 16), (cx + 5, ground)], fill=G_DARK, width=2)
        draw.line([(cx - 12, ground - 16), (cx + 12, ground - 16)], fill=G_DARK, width=2)
        draw.line([(cx - 4, ground - 16), (cx - 4, ground - 5)], fill=G_MID, width=1)
        draw.line([(cx + 4, ground - 16), (cx + 4, ground - 5)], fill=G_MID, width=1)
        draw.rectangle([cx - 7, ground - 6, cx + 7, ground - 4], fill=G_LIGHT)
    elif name == "slide":
        draw.polygon([(cx - 12, ground - 16), (cx + 12, ground - 4),
                      (cx + 8, ground - 4), (cx - 12, ground - 13)], fill=G_LIGHT)
        pole(cx - 9, ground - 16, ground, 2, G_DARK)
        pole(cx + 9, ground - 16, ground, 2, G_DARK)
    elif name == "carousel":
        draw.polygon([(cx, ground - 18), (cx + 16, ground - 8),
                      (cx - 16, ground - 8)], fill=G_MID)
        draw.rectangle([cx - 15, ground - 8, cx + 15, ground - 3], fill=G_LIGHT)
        pole(cx, ground - 18, ground - 8, 2, G_DARK)
        for dx in (-10, 0, 10):
            draw.line([(cx + dx, ground - 8), (cx + dx, ground - 3)], fill=G_DARK, width=1)
    elif name == "trash_bin":
        draw.rectangle([cx - 5, ground - 11, cx + 5, ground], fill=G_MID)
        draw.rectangle([cx - 6, ground - 12, cx + 6, ground - 10], fill=G_DARK)
    elif name == "flower_bed":
        draw.ellipse([cx - 14, ground - 6, cx + 14, ground + 1], fill=G_LIGHT)
        for dx in (-9, -3, 3, 9):
            draw.ellipse([cx + dx - 2, ground - 10, cx + dx + 2, ground - 6], fill=G_MID)
    elif name == "mailbox":
        pole(cx - 6, ground - 14, ground, 2, G_DARK)
        draw.rectangle([cx - 10, ground - 18, cx + 2, ground - 10], fill=G_MID)
    elif name == "ac_unit":
        draw.rectangle([cx - 10, ground - 12, cx + 10, ground - 4], fill=G_LIGHT)
        for dx in (-6, 0, 6):
            draw.line([(cx + dx, ground - 11), (cx + dx, ground - 5)], fill=G_MID, width=1)
    elif name == "parasol":
        pole(cx, ground - 12, ground, 2, G_DARK)
        draw.polygon([(cx - 13, ground - 12), (cx, ground - 20),
                      (cx + 13, ground - 12)], fill=G_MID)
    elif name == "bridge_rail":
        draw.line([(cx - 16, ground - 6), (cx + 16, ground - 6)], fill=G_LIGHT, width=2)
        for dx in (-12, -4, 4, 12):
            pole(cx + dx, ground - 12, ground - 4, 2, G_LIGHT)
    elif name == "hydrant":
        draw.rectangle([cx - 4, ground - 9, cx + 4, ground], fill=G_MID)
        draw.line([(cx - 6, ground - 7), (cx + 6, ground - 7)], fill=G_DARK, width=2)


def redraw_props(tileset_path: str) -> None:
    im = Image.open(tileset_path).convert("RGBA")
    assert im.size == (COLS * TW, ROWS * TH), im.size
    px = im.load()
    # 先清空第 17 行（透明）
    for y in range(PROP_ROW * TH, (PROP_ROW + 1) * TH):
        for x in range(im.width):
            px[x, y] = (0, 0, 0, 0)
    # 用 RGBA 图层绘制，保持菱形外透明
    layer = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    for idx in range(16):
        tile = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
        d = ImageDraw.Draw(tile)
        d.polygon(_diamond_mask(32, 16), fill=(200, 200, 200, 255))
        _draw_prop(d, 0, 0, idx)
        # 把菱形外的像素裁掉（保留透明四角）
        mask = Image.new("L", (TW, TH), 0)
        ImageDraw.Draw(mask).polygon(_diamond_mask(32, 16), fill=255)
        tile.putalpha(Image.composite(tile.getchannel("A"), Image.new("L", (TW, TH), 0), mask))
        im.paste(tile, (idx * TW, PROP_ROW * TH))
    im.save(tileset_path)


# --------------------------------------------------------------------------
# 2) 改造地图数据：池塘 / 绿地 / 路灯 / 游乐场 / POI
# --------------------------------------------------------------------------
def _role_gid(role, variant=0, mask=0):
    return ROLE_BASE[role] + variant * 16 + mask


def modernize_map(json_path: str, out_path: str = None) -> dict:
    with open(json_path, encoding="utf-8") as fh:
        data = json.load(fh)
    W, H = data["width"], data["height"]

    def layer(name):
        for l in data["layers"]:
            if l["name"] == name:
                return l
        raise KeyError(name)

    ground = layer("ground")["data"]
    detail = layer("detail")["data"]
    collision = layer("collision")["data"]

    # 选一块空旷区域做池塘：找 ground 上 floor 最密集的矩形
    def floor_density(x0, y0, x1, y1):
        n = tot = 0
        for y in range(y0, y1):
            for x in range(x0, x1):
                g = ground[y * W + x]
                if g != 0:
                    tot += 1
                    if 1 <= g <= 32:
                        n += 1
        return n / max(1, tot)

    # 固定选址：示意图右下区域（等距菱形右下=大 x 中 y）；96x96 取 x 62-78, y 58-72
    pond = (62, 58, 78, 72)
    # 若该区地面不足则退到中部
    if floor_density(*pond) < 0.7:
        pond = (40, 44, 56, 58)
    cx, cy = (pond[0] + pond[2]) / 2, (pond[1] + pond[3]) / 2
    rx, ry = (pond[2] - pond[0]) / 2, (pond[3] - pond[1]) / 2
    for y in range(pond[1], pond[3]):
        for x in range(pond[0], pond[2]):
            # 椭圆轮廓：水域整片覆盖（含原墙），清掉碰撞，保证是完整可辨的池塘
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                ground[y * W + x] = _role_gid("water", (x + y) % 2, (x * 3 + y) % 16)
                collision[y * W + x] = 0
    # 石桥：横穿池塘中腰的一排石桥栏杆（示意水库上有桥）
    bridge_y = int(cy)
    for x in range(int(cx - rx * 0.8), int(cx + rx * 0.8)):
        if 0 <= x < W and 0 <= bridge_y < H:
            detail[bridge_y * W + x] = ROLE_BASE["prop"] + SL["bridge_rail"]

    # 游乐场绿地：右上角区域 x 70-88, y 18-34（整片覆盖）
    park = (70, 18, 88, 34)
    for y in range(park[1], park[3]):
        for x in range(park[0], park[2]):
            ground[y * W + x] = _role_gid("grass", (x + y) % 2, (x + y * 2) % 16)
            collision[y * W + x] = 0
    # 在游乐场放秋千/滑梯/旋转木马（detail 层）
    for (px, py, slot) in [
        (74, 22, SL["swing"]), (78, 22, SL["swing"]),
        (82, 22, SL["slide"]), (85, 26, SL["carousel"]),
        (76, 28, SL["bench"]), (80, 30, SL["bench"]),
    ]:
        if 0 <= px < W and 0 <= py < H:
            detail[py * W + px] = ROLE_BASE["prop"] + slot

    # 沿主干道布路灯：找 floor 格，间隔放置
    lamp_count = 0
    for y in range(2, H - 2, 6):
        for x in range(2, W - 2, 8):
            if 1 <= ground[y * W + x] <= 32 and detail[y * W + x] == 0:
                detail[y * W + x] = ROLE_BASE["prop"] + SL["street_lamp"]
                lamp_count += 1
    # 电线杆：少量
    for (px, py) in [(20, 30), (44, 12), (60, 40), (30, 66)]:
        if detail[py * W + px] == 0:
            detail[py * W + px] = ROLE_BASE["prop"] + SL["power_pole"]

    # 装饰替换：地牢槽位 -> 现代槽位（按原 gid 的低 4 位轮转）
    modern_slots = [SL["tree"], SL["bench"], SL["car"], SL["scooter"],
                    SL["flower_bed"], SL["trash_bin"], SL["hydrant"], SL["mailbox"]]
    for i, g in enumerate(detail):
        if 257 <= g <= 272:
            old = (g - 257) % 8
            detail[i] = ROLE_BASE["prop"] + modern_slots[old]

    # POI 重新落位：对应示意图与剧情地标
    poi_new = {
        "spawn": (48, 3),            # 镇口（上边缘主路）
        "old_house": (24, 26),       # 老宅（左上居住区）
        "old_diary": (20, 30),
        "old_clock": (34, 20),
        "guitar_case": (26, 22),
        "registration_form": (40, 28),
        "street_lamp": [(46, 30), (52, 34)],  # 老街路灯
        "playground_swing": (76, 22),         # 游乐场秋千
        "repair_log": (78, 28),
        "cassette_label": (68, 50),
        "tape_deck": (60, 52),
        "crossroads": (48, 40),              # 镇中心路口
        "moving_list": (58, 44),
        "exit": (48, 5),                     # 终章镇口灯火（与 spawn 相邻）
    }
    objs = []
    for l in data["layers"]:
        if l["name"] == "objects":
            objs = l["objects"]
            break
    # 按类型计数分配
    seen = {}
    for o in objs:
        typ = o.get("type", "")
        loc = poi_new.get(typ)
        if isinstance(loc, list):
            idx = seen.get(typ, 0)
            if idx >= len(loc):
                idx = 0
            tx, ty = loc[idx]
            seen[typ] = idx + 1
        elif loc:
            tx, ty = loc
        else:
            tx = ty = 0
        for p in o.get("properties", []):
            if p["name"] == "tileX":
                p["value"] = tx
            elif p["name"] == "tileY":
                p["value"] = ty
        o["name"] = "%s" % typ if typ in ("spawn", "exit") else "%s-%d" % (typ, seen.get(typ, 1))
        o["x"] = int(tx * TW + TW / 2)
        o["y"] = int(ty * TH + TH / 2)

    out = out_path or json_path
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print("已更新地图数据：池塘=%s 游乐场=%s 路灯=%d" % (pond, park, lamp_count))
    return data


def sync_csv_tmx(data: dict, directory: str) -> None:
    W, H = data["width"], data["height"]
    for l in data["layers"]:
        if l["type"] != "tilelayer":
            continue
        name = l["name"]
        csv_path = os.path.join(directory, "turn-town-whitebox.%s.csv" % name)
        with open(csv_path, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            for y in range(H):
                w.writerow(l["data"][y * W:(y + 1) * W])

    tmx_path = os.path.join(directory, "turn-town-whitebox.tmx")
    with open(tmx_path, encoding="utf-8") as fh:
        tmx = fh.read()
    # 替换每层 <data> 内容：三个捕获组 = layer 开标签 / 层名 / data 开标签，
    # 只换中间内容，保留完整标签结构。
    def repl(m):
        open_layer, lname, open_data = m.group(1), m.group(2), m.group(3)
        for l in data["layers"]:
            if l["name"] == lname and l["type"] == "tilelayer":
                # 每行末尾补逗号：校验器去掉换行后靠逗号分隔，行间必须有逗号
                csv_text = "\n".join(",".join(str(g) for g in l["data"][y * W:(y + 1) * W]) + ","
                                     for y in range(H))
                return "%s%s\n%s\n</data>" % (open_layer, open_data, csv_text)
        return m.group(0)
    tmx = re.sub(
        r'(<layer[^>]*name="([^"]+)"[^>]*>\s*)(<data[^>]*>).*?</data>',
        repl, tmx, flags=re.S)
    # 同步 POI 的 x/y
    for l in data["layers"]:
        if l["name"] == "objects":
            for o in l["objects"]:
                pat = re.compile(r'(<object[^>]*?id="%s"[^>]*?)x="[^"]*"\s+y="[^"]*"' % re.escape(str(o["id"])))
                tmx = pat.sub(lambda mm: '%s x="%s" y="%s"' % (mm.group(1), o["x"], o["y"]), tmx)
    with open(tmx_path, "w", encoding="utf-8") as fh:
        fh.write(tmx)
    print("已同步 CSV 与 TMX")


def rebuild_preview(directory: str) -> None:
    """调用工具箱 preview 模块按改后的数据重建预览，再做灰阶全览。"""
    sys.path.insert(0, os.environ.get(
        "GM_TOOLKIT_SCRIPTS",
        os.path.join(os.environ.get("USERPROFILE", os.path.expanduser("~")),
                     ".workbuddy", "plugins", "cache", "experts", "game-map-generator",
                     "2.5.0", "skills", "game-map-toolkit", "scripts")))
    from gmlib import preview as pv
    from gmlib import spec as sp

    spec_path = os.path.join(directory, "turn-town-whitebox.spec.json")
    with open(spec_path, encoding="utf-8") as fh:
        spec = json.load(fh)
    spec = sp.normalize(spec)
    with open(os.path.join(directory, "turn-town-whitebox.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    layers = [l for l in data["layers"] if l["type"] == "tilelayer"]
    objs = []
    for l in data["layers"]:
        if l["type"] == "objectgroup":
            objs.extend(l.get("objects", []))
    tileset_path = os.path.join(directory, "tileset.png")
    preview_path = os.path.join(directory, "turn-town-whitebox.preview.png")
    pv.write_preview(spec, layers, objs, tileset_path, preview_path, 2, None)
    print("已重建预览")

    im = Image.open(preview_path).convert("RGBA")
    out = im.resize((2400, 1200), Image.LANCZOS)
    bg = Image.new("RGB", out.size, (32, 36, 44))
    bg.paste(out, mask=out.split()[3])
    bg.save(os.path.join(directory, "turn-town-whitebox.overview.png"), optimize=True)
    print("已重建全览图")


def main() -> int:
    d = HERE
    redraw_props(os.path.join(d, "tileset.png"))
    print("已重绘 16 个现代装饰槽位")
    data = modernize_map(os.path.join(d, "turn-town-whitebox.json"))
    sync_csv_tmx(data, d)
    rebuild_preview(d)
    return 0


if __name__ == "__main__":
    sys.exit(main())
