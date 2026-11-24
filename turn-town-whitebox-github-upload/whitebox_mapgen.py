# -*- coding: utf-8 -*-
"""whitebox_mapgen.py —— 白盒（graybox）配色驱动：覆盖占位图集调色板后跑 mapgen，
并把图集/预览统一去饱和成灰阶白盒。

用法：
    python whitebox_mapgen.py --spec <spec.json> --out <输出目录> [--scale N]

做法：gmlib.texture 的 PALETTE_HEX 是唯一配色源，整体替换为强对比灰阶白盒色；
装饰物（props）绘制颜色硬编码、不走调色板，故生成后再统一去饱和。
不修改工具箱源码，同 spec 逐字节可复现。
"""
from __future__ import annotations

import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_default_toolkit = os.path.join(
    os.environ.get("USERPROFILE", os.path.expanduser("~")),
    ".workbuddy", "plugins", "cache", "experts", "game-map-generator",
    "2.5.0", "skills", "game-map-toolkit", "scripts",
)
TOOLKIT_SCRIPTS = os.environ.get("GM_TOOLKIT_SCRIPTS", _default_toolkit)
sys.path.insert(0, TOOLKIT_SCRIPTS)

from gmlib import texture as tex  # noqa: E402

# 白盒灰阶调色板：低饱和 + 三档明度分明，让「地 / 墙 / 空」一眼可辨
#   empty 不画 → 深色画布底（最暗）
#   floor 可走地面 → 中浅灰（中亮）
#   wall  建筑体块 → 亮白顶面 + 深灰侧边（最亮 + 立体感，读作「体块」）
#   prop  装饰体块 → 中灰（生成后还会去饱和）
WHITEBOX_HEX = {
    "floor":  {"base": "#C2C2C2", "dark": "#A2A2A2", "light": "#DCDCDC", "line": "#8A8A8A"},
    "wall":   {"base": "#F2F2F2", "dark": "#5E5E5E", "light": "#FFFFFF", "line": "#424242"},
    "water":  {"base": "#B8C2CA", "dark": "#94A0AA", "light": "#D8E0E6", "line": "#7A8892"},
    "sand":   {"base": "#DCD8CC", "dark": "#BAB6AA", "light": "#F0EEE6", "line": "#A09C90"},
    "grass":  {"base": "#BEC6BA", "dark": "#9AA496", "light": "#D8DED2", "line": "#828C7E"},
    "forest": {"base": "#A0AA9C", "dark": "#7C8678", "light": "#BEC6B8", "line": "#666E60"},
    "rock":   {"base": "#ACACAC", "dark": "#888888", "light": "#C8C8C8", "line": "#707070"},
    "snow":   {"base": "#F0F0F0", "dark": "#CECECE", "light": "#FFFFFF", "line": "#B4B4B4"},
    "prop":   {"base": "#8A8A8A", "dark": "#666666", "light": "#ACACAC", "line": "#4E4E4E"},
}


def apply_whitebox() -> None:
    """把调色板整体替换为白盒灰阶。"""
    tex.PALETTE_HEX = dict(WHITEBOX_HEX)
    tex.PALETTE = {
        role: {k: tex.hex_to_rgb(v) for k, v in spec.items()}
        for role, spec in WHITEBOX_HEX.items()
    }
    from gmlib import tileset as ts_mod
    ts_mod._PLACEHOLDER_CACHE.clear()  # 缓存键不含调色板，清掉避免拿到旧色


def _desat(path: str) -> None:
    """去饱和为灰阶，保留 alpha（等距菱形四角必须透明）。"""
    from PIL import Image
    im = Image.open(path).convert("RGBA")
    r, g, b, a = im.split()
    gray = Image.merge("RGB", (r, g, b)).convert("L")
    Image.merge("RGBA", (gray, gray, gray, a)).save(path)


def _postprocess(out_dir: str, scale: int) -> None:
    """图集与预览统一去饱和；再从预览生成屏幕友好的全览图。"""
    from PIL import Image
    for name in ("tileset.png", "props.png"):
        p = os.path.join(out_dir, name)
        if os.path.isfile(p):
            _desat(p)
    previews = sorted(glob.glob(os.path.join(out_dir, "*.preview.png")))
    for p in previews:
        _desat(p)
    if previews:
        im = Image.open(previews[-1]).convert("RGBA")
        out = im.resize((2400, 1200), Image.LANCZOS)
        bg = Image.new("RGB", out.size, (32, 36, 44))
        bg.paste(out, mask=out.split()[3])
        ov = previews[-1].replace(".preview.png", ".overview.png")
        bg.save(ov, optimize=True)
        print("全览图: %s" % os.path.basename(ov))
    print("白盒后处理完成（图集/预览已灰阶化）")


def _parse_out(argv) -> str:
    for i, a in enumerate(argv):
        if a == "--out" and i + 1 < len(argv):
            return argv[i + 1]
        if a.startswith("--out="):
            return a.split("=", 1)[1]
    return "."


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    apply_whitebox()
    import mapgen
    code = mapgen.main(argv)
    if code == 0:
        _postprocess(_parse_out(argv), 2)
    return code


if __name__ == "__main__":
    if "--spec" not in sys.argv[1:]:
        print("用法: python whitebox_mapgen.py --spec spec.json --out 目录 [--scale N]",
              file=sys.stderr)
        sys.exit(2)
    sys.exit(main())
