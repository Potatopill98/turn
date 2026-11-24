# turn-town-whitebox —— 生成产物说明

由 game-map-toolkit v2.4.0 生成。生成参数见 `turn-town-whitebox.spec.json`，文件清单与校验结果见 `turn-town-whitebox.report.json`。

## 文件

| 文件 | 用途 |
|---|---|
| `turn-town-whitebox.tmx` | Tiled 地图源文件，可直接用 Tiled 打开 |
| `turn-town-whitebox.json` | Tiled JSON 格式，各引擎脚本读取这一份 |
| `turn-town-whitebox.<图层名>.csv` | 每层的 gid 网格，便于核对数值 |
| `turn-town-whitebox.preview.png` | 预览图（2 倍放大），验收用 |
| `tileset.png` | 瓦片图集（你的美术图集） |
| `turn-town-whitebox.spec.json` | 归一化后的生成参数，用于复现 |
| `turn-town-whitebox.report.json` | 文件清单、sha256 与校验结果 |

## 生成摘要

| 项目 | 值 |
|---|---|
| 地形角色 | floor、forest、grass、prop、rock、sand、snow、wall、water |
| 地图图层 | ground、detail、collision |
| 自动瓦片 | wang16 |
| 装饰密度 | 0.05 |
| 装饰物数量 | 199 |

## 快速验收

```bash
python validate_map.py turn-town-whitebox.tmx
```

预览图是按真实图集切图、按 alpha 合成渲染出来的，与引擎里的像素位置和遮挡关系一致：
打开 `turn-town-whitebox.preview.png` 看到的就是引擎里会得到的结果。

## 本次校验

- 结果：通过
- 错误：0 条
- 提示：1 条

## 复现

同 seed 同 spec 重新生成，地图数据逐字节一致：

```bash
python mapgen.py --spec turn-town-whitebox.spec.json --out ./rerun
```

> 本图用的是自备图集：复现前请把 `tileset.png` 一并放进新的输出目录，
> 否则工具会报错而不是悄悄换成占位图。

## 本次提示

- 等距地图：对象像素坐标按 Tiled 约定换算，导入后如偏移请改用对象属性 tileX/tileY 自行定位
