@tool
extends Node2D
## tiled_map_loader.gd —— 由 game-map-toolkit 生成（等距增强版，适配本张 turn-town）。
## 读取 Tiled JSON（turn-town.json），在 Godot 4 里构建 TileSet 与瓦片图层。
## 不依赖任何插件：图集切分、物理层、碰撞多边形全部在代码里完成。
##
## 相对工具箱默认模板，本版补了三件等距落地必需的事：
##   1) TileSet 设为 Isometric + Diamond Down，否则 64x32 菱形瓦片按方格铺开会错位；
##   2) 渲染 decor 对象组（props.png 的 112 个装饰物），底对齐、按 y 排序；
##   3) 把 objects 对象组的 15 个叙事 POI 建成 Marker2D，并暴露 get_poi() 查询接口。
##
## 用法：Node2D 场景挂本脚本 → 填 Map Json Path / Tileset Texture / Props Texture → 运行。
## 兼容性：Godot 4.3+ 用 TileMapLayer；4.0–4.2 自动回退到 TileMap。

@export_file("*.json") var map_json_path: String = ""
@export var tileset_texture: Texture2D
## 装饰物图集 props.png（可选）：填上才会渲染树/灌木/石头等装饰
@export var props_texture: Texture2D
## 自然地形背景 Texture（大地图才有；本张等距地牢地图没有，留空即可）
@export var background_texture: Texture2D
## 需要参与碰撞的图层名
@export var collision_layers: Array[String] = ["collision"]
## 是否生成物理层与瓦片碰撞体
@export var build_collision: bool = true
## 是否渲染 decor 对象组里的装饰物
@export var render_decor: bool = true
## 是否把叙事 POI 建成 Marker2D 节点
@export var build_poi_markers: bool = true
## 整张地图的缩放（像素级微调用，一般留 1.0）
@export var map_scale: float = 1.0

var _tile_size: Vector2i = Vector2i(64, 32)
var _columns: int = 1
var _firstgid: int = 1
var _source_id: int = -1
var _layers_built: int = 0
var _is_isometric: bool = false
# 不定类型：TileMapLayer / TileMap 都有 map_to_local，但 Node2D 没有，
# 声明成 Node2D 会被静态检查拦下，这里保持 Variant 动态调用。
var _ref_layer = null
var _poi: Dictionary = {}
var _prop_columns: int = 4
var _prop_tile: int = 128
## 只记录本脚本生成的节点；build() 重跑时不误删场景里手放的相机等节点
var _built_nodes: Array[Node] = []

## 按叙事地点类型取锚点，返回 [{name, tileX, tileY, world}, ...]
## 例：get_poi("old_house") 拿到老宅；get_poi("spawn") 拿到镇口起点。
func get_poi(poi_type: String) -> Array:
	var arr: Array = _poi.get(poi_type, [])
	return arr

## 取全部锚点：key = POI 类型，value = 该类型下的锚点数组
func get_all_poi() -> Dictionary:
	return _poi.duplicate(true)

## 格坐标 → 本图的局部像素坐标（跟随 TileSet 的等距换算，勿手写公式）
func tile_center(tile_x: int, tile_y: int) -> Vector2:
	if _ref_layer == null:
		return Vector2.ZERO
	return _ref_layer.map_to_local(Vector2i(tile_x, tile_y))

func _ready() -> void:
	scale = Vector2(map_scale, map_scale)
	# @tool：编辑器里打开场景也会构建，可以直接在视口看到地图（无需按 F6）
	build()

## 构建（可重复调用；重复调用会先清掉上一次生成的子节点）
func build() -> void:
	# 只清掉上一次自己生成的节点，保留场景里手放的 Camera2D 等节点
	for node in _built_nodes:
		if is_instance_valid(node) and node.get_parent() == self:
			remove_child(node)
			node.queue_free()
	_built_nodes.clear()
	_layers_built = 0
	_poi.clear()
	_ref_layer = null

	if map_json_path.is_empty():
		push_warning("[tiled_map_loader] 还没设置 Map Json Path")
		return
	var map := _read_json(map_json_path)
	if map.is_empty():
		return
	if tileset_texture == null:
		push_error("[tiled_map_loader] 还没设置 Tileset Texture，无法切图")
		return

	_tile_size = Vector2i(int(map.get("tilewidth", 64)), int(map.get("tileheight", 32)))
	var tilesets: Array = map.get("tilesets", [])
	if tilesets.is_empty():
		push_error("[tiled_map_loader] JSON 里没有 tileset 信息")
		return
	var ts_info: Dictionary = tilesets[0]
	_columns = max(1, int(ts_info.get("columns", 1)))
	_firstgid = int(ts_info.get("firstgid", 1))
	var tilecount: int = max(1, int(ts_info.get("tilecount", 1)))

	var map_width: int = int(map.get("width", 0))
	var map_height: int = int(map.get("height", 0))
	_is_isometric = String(map.get("orientation", "")) == "isometric"
	_build_background(map_width, map_height)
	var tile_set_plain := _make_tileset(tilecount, false)
	var tile_set_solid := _make_tileset(tilecount, true) if build_collision else tile_set_plain

	for layer in map.get("layers", []):
		if typeof(layer) != TYPE_DICTIONARY:
			continue
		var layer_dict: Dictionary = layer
		if String(layer_dict.get("type", "")) != "tilelayer":
			continue
		var layer_name: String = String(layer_dict.get("name", "layer"))
		var solid := build_collision and collision_layers.has(layer_name)
		var node = _make_layer_node(layer_name, tile_set_solid if solid else tile_set_plain, _layers_built)
		if _ref_layer == null:
			_ref_layer = node
		# 瓦片层透明度（自然地形背景存在时 JSON 里为 0.5）：让下方连续渐变透出。
		node.modulate.a = clampf(float(layer_dict.get("opacity", 1.0)), 0.0, 1.0)
		# visible=false 的图层（有背景时的 collision 层）只作碰撞数据，不重复渲染。
		node.visible = bool(layer_dict.get("visible", true))
		add_child(node)
		_built_nodes.append(node)
		_layers_built += 1

		var data: Array = layer_dict.get("data", [])
		var width: int = int(layer_dict.get("width", map_width))
		var height: int = int(layer_dict.get("height", 0))
		for y in range(height):
			for x in range(width):
				var index := y * width + x
				if index >= data.size():
					continue
				var gid := int(data[index])
				if gid == 0:
					continue
				var local := gid - _firstgid
				var atlas := Vector2i(local % _columns, int(local / _columns))
				_set_cell(node, Vector2i(x, y), _source_id, atlas)

	_build_decor(map)
	_build_poi(map)
	var poi_count: int = 0
	for key in _poi.keys():
		poi_count += (_poi[key] as Array).size()
	print("[tiled_map_loader] 完成：%d 个图层，瓦片 %dx%d，等距=%s，POI=%d"
		% [_layers_built, _tile_size.x, _tile_size.y, str(_is_isometric), poi_count])

## 自然地形背景：等距地图的菱形瓦片与矩形背景对不齐，跳过。
func _build_background(map_width: int, map_height: int) -> void:
	if background_texture == null:
		return
	if _is_isometric:
		push_warning("[tiled_map_loader] 等距地图不使用矩形背景，已跳过自然地形背景")
		return
	var bg := Sprite2D.new()
	bg.name = "NaturalBackground"
	bg.texture = background_texture
	bg.centered = true
	bg.position = Vector2(map_width * _tile_size.x * 0.5, map_height * _tile_size.y * 0.5)
	bg.z_index = -1
	add_child(bg)
	_built_nodes.append(bg)

## 渲染 decor 对象组：props.png 的装饰物按 tileX/tileY 底对齐落在格子上。
## 装饰物是纯视觉叠加，不写进碰撞、不改变可行走性。
func _build_decor(map: Dictionary) -> void:
	if not render_decor or props_texture == null or _ref_layer == null:
		return
	var props_firstgid: int = -1
	for ts in map.get("tilesets", []):
		if String(ts.get("image", "")) == "props.png":
			props_firstgid = int(ts.get("firstgid", 1))
			_prop_columns = max(1, int(ts.get("columns", 4)))
			_prop_tile = max(1, int(ts.get("tilewidth", 128)))
			break
	if props_firstgid < 0:
		return
	var group := Node2D.new()
	group.name = "Decor"
	if group.has_method("set_y_sort_enabled"):
		group.set_y_sort_enabled(true)
	group.z_index = 1
	add_child(group)
	_built_nodes.append(group)
	for layer in map.get("layers", []):
		if String(layer.get("name", "")) != "decor":
			continue
		for obj in layer.get("objects", []):
			var gid := int(obj.get("gid", 0))
			if gid < props_firstgid:
				continue
			var local := gid - props_firstgid
			var tx: int = -1
			var ty: int = -1
			for pr in obj.get("properties", []):
				var pname := String(pr.get("name", ""))
				if pname == "tileX":
					tx = int(pr.get("value", -1))
				elif pname == "tileY":
					ty = int(pr.get("value", -1))
			if tx < 0 or ty < 0:
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = props_texture
			var col := local % _prop_columns
			var row := int(local / _prop_columns)
			atlas.region = Rect2(col * _prop_tile, row * _prop_tile, _prop_tile, _prop_tile)
			var sprite := Sprite2D.new()
			sprite.texture = atlas
			sprite.centered = true
			# 纹理底部中心落在节点原点 = 视觉脚底贴住瓦片中心
			sprite.offset = Vector2(0, -float(_prop_tile) * 0.5)
			sprite.position = _ref_layer.map_to_local(Vector2i(tx, ty))
			group.add_child(sprite)

## 把 objects 对象组里的叙事 POI 建成 Marker2D，并登记到 _poi 供剧情系统查询。
func _build_poi(map: Dictionary) -> void:
	if _ref_layer == null:
		return
	for layer in map.get("layers", []):
		if String(layer.get("name", "")) != "objects":
			continue
		for obj in layer.get("objects", []):
			var typ := String(obj.get("type", ""))
			var nm := String(obj.get("name", ""))
			var tx: int = -1
			var ty: int = -1
			for pr in obj.get("properties", []):
				var pname := String(pr.get("name", ""))
				if pname == "tileX":
					tx = int(pr.get("value", -1))
				elif pname == "tileY":
					ty = int(pr.get("value", -1))
			if tx < 0 or ty < 0:
				continue
			var world: Vector2 = _ref_layer.map_to_local(Vector2i(tx, ty))
			var entry := {"name": nm, "tileX": tx, "tileY": ty, "world": world}
			if not _poi.has(typ):
				_poi[typ] = []
			(_poi[typ] as Array).append(entry)
			if build_poi_markers:
				var marker := Marker2D.new()
				marker.name = nm
				marker.position = world
				marker.set_meta("poi_type", typ)
				marker.set_meta("tileX", tx)
				marker.set_meta("tileY", ty)
				add_child(marker)
				_built_nodes.append(marker)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[tiled_map_loader] 找不到文件: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[tiled_map_loader] 打不开文件: %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[tiled_map_loader] JSON 解析失败: %s" % path)
		return {}
	return parsed

func _make_tileset(tilecount: int, with_collision: bool) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = _tile_size
	# 等距关键设置：菱形瓦片必须配 Isometric 形状 + Diamond Down 布局，
	# 否则 Godot 会按方格铺 64x32 矩形，瓦片互相错位/遮挡。
	if _is_isometric:
		tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
		tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
		tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	if with_collision:
		tile_set.add_physics_layer(0)
		tile_set.set_physics_layer_collision_layer(0, 1)
		tile_set.set_physics_layer_collision_mask(0, 1)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = tileset_texture
	atlas_source.texture_region_size = _tile_size
	_source_id = tile_set.add_source(atlas_source, _firstgid)

	var half_w := float(_tile_size.x) * 0.5
	var half_h := float(_tile_size.y) * 0.5
	# 等距用菱形碰撞多边形（贴合菱形瓦片），正交用矩形
	var box := PackedVector2Array([
		Vector2(-half_w, -half_h),
		Vector2(half_w, -half_h),
		Vector2(half_w, half_h),
		Vector2(-half_w, half_h),
	])
	var diamond := PackedVector2Array([
		Vector2(0, -half_h),
		Vector2(half_w, 0),
		Vector2(0, half_h),
		Vector2(-half_w, 0),
	])
	for i in range(tilecount):
		var coords := Vector2i(i % _columns, int(i / _columns))
		atlas_source.create_tile(coords)
		if with_collision:
			var tile_data := atlas_source.get_tile_data(coords, 0)
			if tile_data != null:
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, diamond if _is_isometric else box)

	return tile_set

func _make_layer_node(layer_name: String, tile_set: TileSet, order: int):
	var node = null
	if ClassDB.class_exists("TileMapLayer"):
		node = ClassDB.instantiate("TileMapLayer")
	else:
		node = ClassDB.instantiate("TileMap")
	node.name = layer_name
	node.tile_set = tile_set
	if node.has_method("set_y_sort_enabled"):
		# 等距必须开 y 排序：靠下的瓦片/角色画在上层，才不会前后穿帮
		node.set_y_sort_enabled(_is_isometric)
	if "z_index" in node:
		node.z_index = order
	return node

func _set_cell(node, pos: Vector2i, source: int, atlas: Vector2i) -> void:
	if ClassDB.class_exists("TileMapLayer"):
		# TileMapLayer: set_cell(coords, source_id, atlas_coords, alternative)
		node.set_cell(pos, source, atlas, 0)
	else:
		# TileMap (4.0–4.2): set_cell(layer, coords, source_id, atlas_coords, alternative)
		node.set_cell(0, pos, source, atlas, 0)
