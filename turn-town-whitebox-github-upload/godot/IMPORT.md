# GODOT 导入说明 —— turn-town-whitebox（45° 等距现代小镇白盒）

| 项目 | 值 |
|---|---|
| 地图名 | turn-town-whitebox（《Turn / 转变》小镇**白盒底图**，已按现代小镇示意图改造内容） |
| 地图数据 | `turn-town-whitebox.json`（另有 .tmx / 每层 .csv） |
| 瓦片图集 | `tileset.png`（272 张，16 列，64×32 菱形，**灰阶白盒**，RGBA 四角透明） |
| 装饰图集 | `props.png`（灰阶，备用；装饰已作为瓦片铺进 detail 图层，不依赖此图渲染） |
| 视角 | isometric，64×32（2:1 菱形，即「45° 俯视、高 32px」） |
| 尺寸 | **96 × 96 格**（较大的小镇） |
| 图层 | ground（地面/水域/绿地）、detail（现代装饰瓦片 289 个）、collision（建筑/墙，参与碰撞） |
| 对象组 | objects（15 个叙事 POI，分 14 类，已按剧情地标重新落位） |
| 脚本 | `godot/tiled_map_loader.gd`（等距增强版，带 `@tool` 编辑器预览） |
| 风格 | **白盒 / graybox**：纯灰阶体块占位，三档明暗分明（地中灰／墙白／空深） |

## 白盒是什么

白盒（graybox）= 用纯几何体块、灰阶配色占位的地图，**不含正式美术**。作用是：
在换美术前就能验证尺寸、动线、碰撞、叙事锚点是否合理。换正式美术只需替换同名 PNG，地图文件不用动。

本图内容已按《Turn》现代小镇**概念示意图**改造，灰阶配色约定：
- **地面 floor**：中浅灰（可走区域）
- **墙体 wall**：白色顶面 + 深灰侧边（现代建筑体块，读作「立体」）
- **空白 empty**：不铺瓦片，透出深色画布底（图外/建筑内部）
- **水面 water**：椭圆池塘（灰阶波纹）+ 一排石桥栏杆，位于地图右下（格 62–78, 58–72）
- **绿地 grass**：游乐场草坪（格 70–88, 18–34），内有秋千/滑梯/旋转木马/长椅
- **装饰 prop**：中深灰现代小镇物件（路灯/电线杆/行道树/小汽车/电动车/长椅/花坛/垃圾桶/秋千/滑梯/旋转木马/邮筒/空调外机/遮阳伞/石桥栏/消防栓）
- 路灯沿主干道成排布置（80 盏），呼应剧情「老街路灯」解谜

> 白盒是灰阶体块，不是美术成品。概念示意图 `turn-town-modern-concept.png` 只作风格与内容参照。

## 版本要求

Godot 4.x。4.3+ 用 `TileMapLayer`，4.0–4.2 自动回退 `TileMap`。脚本带 `@tool`，编辑器里打开场景即铺瓦片。

## 怎么看地图（不需要移动视角）

1. **只想看图**：双击 `turn-town-whitebox.overview.png`（2400×1200 灰阶全览图），一屏看全，不用进 Godot。
2. **Godot 里看图**：双击 `turn_town_whitebox_viewer.tscn` → F6，静态全图自动铺满窗口。
3. **看地图本体（瓦片+装饰+POI）**：双击 `turn_town_whitebox_demo.tscn` → F6，相机自动定位全图，**不用 WASD/拖视口**；编辑器打开时瓦片已铺好（`@tool`）。
4. 日志应打印：`完成：3 个图层，瓦片 64x32，等距=true，POI=15` 与 `[map_view_camera] 全览：...`。

> 打开**场景文件（.tscn）**，不要停在 `[空]` 场景对脚本按 F6。相机只在启动时自动适配一次，想放大细节用鼠标滚轮。

## 手动路径

1. 把 `turn-town-whitebox.json`、`tileset.png`、`props.png` 放进 `res://map/`。
2. 新建 `Node2D` 场景，挂 `godot/tiled_map_loader.gd`。
3. Inspector 设置：
   - `Map Json Path` = `res://map/turn-town-whitebox.json`
   - `Tileset Texture` = `res://map/tileset.png`
   - `Props Texture` = 留空或填 `props.png`（装饰已在 detail 瓦片层，此图非必需）
   - `Collision Layers` = `collision`（已预填）
4. 运行。脚本自动完成：等距 TileSet 切图 → 铺瓦片 → 菱形碰撞体 → y 排序 → POI 锚点。

## 关键：脚本相对默认模板补了什么

| 问题 | 不修的后果 | 本脚本处理 |
|---|---|---|
| TileSet 没设等距形状 | 64×32 菱形按方格铺开，瓦片错位/遮挡 | `TILE_SHAPE_ISOMETRIC` + `TILE_LAYOUT_DIAMOND_DOWN` + y 排序 |
| POI 在 `objects` 对象组 | 15 个叙事锚点全丢 | 建成 Marker2D，并提供 `get_poi()` 查询 |
| 没有相机 | 只能看到地图左上角一小块 | 附 `map_view_camera.gd` 自动缩放铺满全图 |
| 编辑器看不到图 | 要按 F6 才见 | `@tool` 让打开场景即铺瓦片 |

> 装饰物是 **detail 瓦片图层**（gid 257–272 为现代物件），不是 decor 对象组，因此无需单独 props 渲染逻辑；`props.png` 仅作换美术备用。

## 叙事 POI 接口（给剧情/任务系统用）

```gdscript
for p in $TurnTown.get_poi("old_house"):
    print(p["name"], p["tileX"], p["tileY"], p["world"])  # world 是局部像素坐标

var all := $TurnTown.get_all_poi()  # key = 类型，value = 数组
```

坐标是 Tiled 格坐标（原点左上、y 向下），96×96 本图的落位（已按剧情地标重排）：

| 类型 | 故事位置 | 数量 | 格坐标 (tileX, tileY) |
|---|---|---|---|
| `spawn` | 序章·镇口（玩家起点，地图上方主路） | 1 | (48, 3) |
| `old_house` | 序章/第一幕·老宅（左上居住区） | 1 | (24, 26) |
| `old_diary` | 序章伏笔·旧日记 | 1 | (20, 30) |
| `old_clock` | 序章伏笔·老钟 | 1 | (34, 20) |
| `guitar_case` | 第一幕·琴箱 | 1 | (26, 22) |
| `registration_form` | 第一幕·报名表 | 1 | (40, 28) |
| `street_lamp` | 第二幕·老街路灯（灯带旁） | 2 | (46, 30)、(52, 34) |
| `playground_swing` | 第二幕·游乐场秋千（右上绿地） | 1 | (76, 22) |
| `repair_log` | 第二幕·维修记录本 | 1 | (78, 28) |
| `cassette_label` | 第三幕·磁带标签 | 1 | (68, 50) |
| `tape_deck` | 第三幕·磁带机 | 1 | (60, 52) |
| `crossroads` | 第三幕·路口（镇中心） | 1 | (48, 40) |
| `moving_list` | 第三幕·搬家清单 | 1 | (58, 44) |
| `exit` | 终章·镇口灯火汇聚点（与 spawn 相邻） | 1 | (48, 5) |

这些 POI 已按剧情地标重新落位（镇口/老宅/路灯/游乐场/路口），是对概念示意图的**白盒化还原**。需要精确对位可在 Tiled 打开 `turn-town-whitebox.tmx` 拖动锚点，改完重导 JSON（`tileX/tileY` 属性同步，脚本读的就是这两个属性，不用改代码）。

## 换正式美术（去白盒化）

保持「64×32 尺寸 / 16 列 / 序号顺序 / 16 掩码布局」不变，直接替换同名 `tileset.png` 即可脱离白盒。地图文件（json/tmx/csv）不用动。

- 图集导入设置：Filter = Point、mipmap 关、不预乘 Alpha、不做 sRGB 转换。
- 概念图 `turn-town-modern-concept.png` 只是氛围参照，不是切图源；正式美术需按上面的图集规格重绘。

## 复现与再改造

```bash
python whitebox_mapgen.py --spec turn-town-whitebox.source.json --out . --engines tiled,godot --scale 2
python modernize_whitebox.py    # 在图集与地图上叠加现代小镇内容（幂等，可重复运行）
```

`modernize_whitebox.py`：重绘 16 个装饰槽位为现代物件、挖池塘/绿地、布路灯与游乐设施、重排 POI，并重建 CSV/TMX/预览/全览图。原始生成物备份在 `_backup_original/`，需要回退时从那里还原。

## 排错

| 现象 | 原因 | 处理 |
|---|---|---|
| 什么都没显示 | 路径写成相对路径 | 用 `res://` 开头 |
| 打开场景看不到图 | 停在 `[空]` 场景按 F6 | 双击 .tscn 打开场景再 F6 |
| 地图是歪的/瓦片互相压 | TileSet 没走等距设置 | 确认用的是本目录这份增强版 `tiled_map_loader.gd` |
| 只看到地图一角 | 没有全览相机 | 确认场景里挂了 `map_view_camera.gd` 的 Camera2D |
| POI 取不到 | 场景没挂脚本或 `build()` 没跑 | `_ready()` 自动 build；也可手动调 `build()` |
| 报 set_cell 参数不匹配 | Godot 4.0–4.2 的 TileMap 是 5 参签名 | 脚本已做版本分支，勿手工删 |
| 碰撞不生效 | 图层名与 Collision Layers 不符 | 两处保持一致（默认 `collision`） |
