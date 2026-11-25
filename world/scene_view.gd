extends Node2D

# 单个场景的绘制层：背景 / 地面 / 排序道具 / NPC / 玩家 / 热点。
# 全部自绘，避免每个地点建一棵节点树；场景数据来自 world_data.gd。

const SKIN = preload("res://ui/theme.gd")
const TravelerArt = preload("res://traveler_art.gd")
const PlayerState = preload("res://world/player_state.gd")

var data: Dictionary = {}
var player = null
var world = null
var font: SystemFont
var _tex: Dictionary = {}
var _npc_rects: Dictionary = {
	"陈守业": Rect2(215, 68, 313, 906),
	"陈小满": Rect2(224, 45, 296, 928),
	"周德海": Rect2(210, 70, 320, 900),
	"吴长庚": Rect2(210, 70, 320, 900),
	"唐棠": Rect2(210, 70, 320, 900),
	"张成": Rect2(210, 70, 320, 900),
}

func _ready() -> void:
	font = SKIN.font()
	z_as_relative = false

func setup(scene_data: Dictionary, player_state: RefCounted, owner_world: Node) -> void:
	data = scene_data
	player = player_state
	world = owner_world
	_tex.clear()
	queue_redraw()

func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex.has(path):
		return _tex[path] as Texture2D
	var got: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		got = load(path) as Texture2D
	_tex[path] = got
	return got

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if data.is_empty() or player == null:
		return
	var bounds: Rect2 = data.get("bounds", Rect2(0, 0, 960, 600)) as Rect2
	_draw_background(bounds)

	var drawables: Array = []
	for prop in data.get("props", []) as Array:
		drawables.append({"kind": "prop", "sort": float((prop as Dictionary).get("sort", 0.0)), "data": prop})
	for npc in data.get("npcs", []) as Array:
		var npc_d: Dictionary = npc as Dictionary
		drawables.append({"kind": "npc", "sort": float((npc_d.get("pos", Vector2.ZERO) as Vector2).y), "data": npc_d})
	drawables.append({"kind": "player", "sort": (player.pos as Vector2).y, "data": player})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["sort"]) < float(b["sort"]))
	for item in drawables:
		var kind: String = str(item["kind"])
		if kind == "prop":
			_draw_prop(item["data"] as Dictionary)
		elif kind == "npc":
			_draw_npc(item["data"] as Dictionary)
		else:
			_draw_player()

	_draw_spots()
	_draw_exits()
	if bool(data.get("dream", false)):
		_draw_dream_veil(bounds)

func _draw_background(bounds: Rect2) -> void:
	var bg_path: String = str(data.get("bg", ""))
	var tex: Texture2D = texture(bg_path)
	if tex != null:
		draw_texture_rect(tex, bounds, false)
	else:
		var sky: Color = data.get("sky", Color("#b7c9cf")) as Color
		var ground: Color = data.get("ground", Color("#8f8a7c")) as Color
		var horizon: float = bounds.position.y + bounds.size.y * 0.52
		draw_rect(Rect2(bounds.position, Vector2(bounds.size.x, horizon - bounds.position.y)), sky)
		draw_rect(Rect2(bounds.position.x, horizon, bounds.size.x, bounds.end.y - horizon), ground)
		draw_rect(Rect2(bounds.position.x, horizon - 4.0, bounds.size.x, 8.0), ground.darkened(0.12))
		draw_rect(Rect2(bounds.position.x, horizon + 40.0, bounds.size.x, 3.0), ground.lightened(0.08))

	var tile_path: String = str(data.get("tile", ""))
	var tile_tex: Texture2D = texture(tile_path)
	if tile_tex != null:
		var tile_rect: Rect2 = data.get("tile_rect", Rect2(60, 500, 2280, 320)) as Rect2
		draw_texture_rect(tile_tex, tile_rect, true, Color(1, 1, 1, 0.86))

func _draw_prop(prop: Dictionary) -> void:
	var rect: Rect2 = prop.get("rect", Rect2()) as Rect2
	var tex_path: String = str(prop.get("tex", ""))
	var tex: Texture2D = texture(tex_path)
	if tex != null:
		var alpha: float = float(prop.get("alpha", 1.0))
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))
		return
	var shape: String = str(prop.get("shape", "rect"))
	var color: Color = prop.get("color", Color(0.5, 0.5, 0.5)) as Color
	if shape == "glow":
		_draw_soft_rect(rect, color)
	elif shape == "grass":
		draw_rect(rect, color)
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 6.0), color.lightened(0.12))
	elif shape == "band":
		draw_rect(rect, color)
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 4.0), color.lightened(0.18))
		draw_rect(Rect2(rect.position.x, rect.end.y - 5.0, rect.size.x, 5.0), color.darkened(0.22))
	else:
		draw_rect(rect, color)
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 5.0), color.lightened(0.16))
		draw_rect(Rect2(rect.position.x, rect.end.y - 6.0, rect.size.x, 6.0), color.darkened(0.24))

func _draw_soft_rect(rect: Rect2, color: Color) -> void:
	var steps: int = 6
	for i in steps:
		var t: float = float(i) / float(steps)
		var shrink: Vector2 = Vector2(rect.size.x * t * 0.5, rect.size.y * t * 0.5)
		var r: Rect2 = Rect2(rect.position + shrink, rect.size - shrink * 2.0)
		draw_rect(r, Color(color.r, color.g, color.b, color.a * (1.0 - t) * 0.5))

func _draw_npc(npc: Dictionary) -> void:
	var at: Vector2 = npc.get("pos", Vector2.ZERO) as Vector2
	draw_set_transform(at, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2(0, 1), 13.0, Color(0.05, 0.05, 0.04, 0.30))
	draw_set_transform(Vector2.ZERO)
	var name: String = str(npc.get("name", ""))
	var art_key: String = str(npc.get("art", ""))
	if art_key.is_empty():
		art_key = name
	var path: String = _npc_texture_path(art_key)
	var tex: Texture2D = texture(path)
	var height: float = float(data.get("npc_height", 128.0))
	if tex != null:
		var region: Rect2 = _npc_rects.get(art_key, Rect2(210, 70, 320, 900)) as Rect2
		var width: float = height * region.size.x / region.size.y
		draw_set_transform(at)
		draw_texture_rect_region(tex, Rect2(-Vector2(width / 2.0, height), Vector2(width, height)), region)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(at.x - 22, at.y - 96, 44, 96), Color("#8b7a63"))
		draw_circle(Vector2(at.x, at.y - 112), 20.0, Color("#d8c3a4"))
	var width2: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var top: float = at.y - height - 16.0
	draw_rect(Rect2(at.x - width2 / 2.0 - 6.0, top, width2 + 12.0, 18.0), Color(SKIN.INK, 0.82))
	draw_string(font, Vector2(at.x - width2 / 2.0, top + 14.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SKIN.PAPER)
	if world != null and world.has_method("is_near_npc") and bool(world.is_near_npc(npc)):
		draw_string(font, Vector2(at.x - 42, top - 8.0), "E 交谈", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SKIN.GOLD)

func _npc_texture_path(key: String) -> String:
	var folder: String = "res://art/03_角色_镇民/"
	var map: Dictionary = {
		"陈守业": folder + "陈守业_父亲.png",
		"陈小满": folder + "陈小满_女儿.png",
		"周德海": folder + "周德海_老周.png",
		"吴长庚": folder + "吴长庚_老吴.png",
		"唐棠": folder + "唐棠_即将搬走的老友.png",
		"张成": folder + "张成_镇民.png",
		"妈妈": folder + "陈守业_父亲.png",
		"囡囡": "res://art/10_v3_待出图/06_全文叙事/00_头像/囡囡_平常.png",
	}
	return str(map.get(key, folder + "张成_镇民.png"))

func _draw_player() -> void:
	var p = player
	draw_set_transform(p.pos, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2(0, 2), 11.0, Color(0.05, 0.05, 0.04, 0.34))
	draw_set_transform(Vector2.ZERO)
	if p.walking:
		TravelerArt.draw_walk(self, p.pos, p.dir, p.height, p.frame())
	else:
		TravelerArt.draw(self, p.pos, p.dir, p.height)

func _draw_spots() -> void:
	var nearest: Dictionary = {}
	if world != null:
		nearest = world.nearest_spot() as Dictionary
	for spot in data.get("spots", []) as Array:
		var s: Dictionary = spot as Dictionary
		var at: Vector2 = s.get("pos", Vector2.ZERO) as Vector2
		var is_near: bool = not nearest.is_empty() and nearest.get("pos", Vector2.ZERO) == at
		var used: bool = false
		if world != null and world.has_method("spot_used"):
			used = bool(world.spot_used(s))
		var color: Color = SKIN.GOLD if is_near else Color(SKIN.GOLD, 0.38)
		if used:
			color = Color(0.62, 0.62, 0.58, 0.42)
		draw_circle(at + Vector2(0, -10), 6.0 if is_near else 4.0, color)
		draw_circle(at + Vector2(0, -10), 2.0, Color(SKIN.PAPER, 0.9))
		if is_near or (player.pos.distance_to(at) < 140.0 and not used):
			var label: String = str(s.get("label", ""))
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_rect(Rect2(at.x - w / 2.0 - 6.0, at.y - 46.0, w + 12.0, 20.0), Color(SKIN.INK, 0.78))
			draw_string(font, Vector2(at.x - w / 2.0, at.y - 31.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(SKIN.PAPER, 0.92))

func _draw_exits() -> void:
	for exit in data.get("exits", []) as Array:
		var e: Dictionary = exit as Dictionary
		var at: Vector2 = e.get("pos", Vector2.ZERO) as Vector2
		var near: bool = player.pos.distance_to(at) < 72.0
		var color: Color = SKIN.GOLD if near else Color(SKIN.GOLD, 0.3)
		draw_arc(at + Vector2(0, -8), 14.0, 0.0, TAU, 20, color, 2.0)
		draw_line(at + Vector2(-5, -8), at + Vector2(5, -8), color, 2.0)
		if near:
			var label: String = str(e.get("label", ""))
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_rect(Rect2(at.x - w / 2.0 - 7.0, at.y - 56.0, w + 14.0, 20.0), Color(SKIN.INK, 0.86))
			draw_string(font, Vector2(at.x - w / 2.0, at.y - 41.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SKIN.GOLD)

func _draw_dream_veil(bounds: Rect2) -> void:
	draw_rect(bounds, Color(0.72, 0.55, 0.34, 0.16))
	var steps: int = 8
	for i in steps:
		var alpha: float = 0.05 * float(i)
		draw_rect(Rect2(bounds.position, Vector2(bounds.size.x, 10.0)), Color(0.86, 0.74, 0.55, alpha))
		draw_rect(Rect2(bounds.position.x, bounds.end.y - 10.0, bounds.size.x, 10.0), Color(0.86, 0.74, 0.55, alpha))

