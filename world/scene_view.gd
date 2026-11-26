extends Node2D

# 单个场景的绘制层：背景 / 地面 / 排序道具 / NPC / 玩家 / 热点。
# 全部自绘，避免每个地点建一棵节点树；场景数据来自 world_data.gd。

const SKIN = preload("res://ui/theme.gd")
const TravelerArt = preload("res://traveler_art.gd")
const PlayerState = preload("res://world/player_state.gd")
const WorldData = preload("res://world/world_data.gd")

var data: Dictionary = {}
var player = null
var world = null
var font: Font
var _pulses: Array = []
var _tex: Dictionary = {}
var _w_cache: Dictionary = {}

func _text_w(text: String, size: int) -> float:
	var cache_key: String = text + "|" + str(size)
	if _w_cache.has(cache_key):
		return float(_w_cache[cache_key])
	var measured: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_w_cache[cache_key] = measured
	return measured
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
	_w_cache.clear()
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

func _process(delta: float) -> void:
	var keep: Array = []
	for p in _pulses:
		var item: Dictionary = p as Dictionary
		item["t"] = float(item["t"]) + delta
		if float(item["t"]) < 0.62:
			keep.append(item)
	_pulses = keep
	queue_redraw()

func pulse(at: Vector2, color: Color = Color(0.98, 0.84, 0.48, 1.0)) -> void:
	_pulses.append({"pos": at, "t": 0.0, "color": color})

func _draw_pulses() -> void:
	var t: float = 0.0
	for p in _pulses:
		var item: Dictionary = p as Dictionary
		var age: float = float(item["t"])
		var k: float = clampf(age / 0.58, 0.0, 1.0)
		var radius: float = 8.0 + 44.0 * k
		var col: Color = item["color"] as Color
		draw_arc((item["pos"] as Vector2) + Vector2(0, -10), radius, 0.0, TAU, 16, Color(col.r, col.g, col.b, (1.0 - k) * 0.5), 2.0)

func _draw() -> void:
	if data.is_empty() or player == null:
		return
	var bounds: Rect2 = data.get("bounds", Rect2(0, 0, 960, 600)) as Rect2
	_draw_background(bounds)
	# 地面标记先画：热点圈与出口圈属于地面，应压在角色脚下而不是盖在身上。
	_draw_spots()
	_draw_exits()

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

	_draw_pulses()
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
	var height: float = float(data.get("npc_height", 0.0))
	var char_scale: float = float(data.get("char_scale", WorldData.CHAR_SCALE))
	if height <= 0.0:
		height = float(player.height)
	else:
		height = height * char_scale
	if tex != null:
		var region: Rect2 = _npc_rects.get(art_key, Rect2(210, 70, 320, 900)) as Rect2
		var width: float = height * region.size.x / region.size.y
		draw_set_transform(at)
		draw_texture_rect_region(tex, Rect2(-Vector2(width / 2.0, height), Vector2(width, height)), region)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(at.x - 22, at.y - 96, 44, 96), Color("#8b7a63"))
		draw_circle(Vector2(at.x, at.y - 112), 20.0, Color("#d8c3a4"))
	var near: bool = world != null and world.has_method("is_near_npc") and bool(world.is_near_npc(npc))
	if not near:
		var width2: float = _text_w(name, 12)
		var top: float = at.y - height - 16.0
		draw_rect(Rect2(at.x - width2 / 2.0 - 6.0, top, width2 + 12.0, 18.0), Color(SKIN.INK, 0.74))
		draw_string(font, Vector2(at.x - width2 / 2.0, top + 14.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(SKIN.PAPER, 0.78))

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
	var shift: float = p.foot_shift()
	draw_set_transform(p.pos, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2(shift, 2), 11.0, Color(0.05, 0.05, 0.04, 0.34))
	draw_set_transform(Vector2.ZERO)
	if p.walking:
		var f: int = p.frame()
		draw_circle(p.pos + Vector2(-7.0 if f % 2 == 0 else 7.0, -2), 3.0, Color(0.76, 0.71, 0.62, 0.10))
		draw_circle(p.pos + Vector2(3.0 if f % 2 == 0 else -3.0, 0), 2.2, Color(0.76, 0.71, 0.62, 0.06))
		TravelerArt.draw_walk(self, p.pos, p.dir, p.height, f, p.lift(), p.lean())
	else:
		TravelerArt.draw(self, p.pos, p.dir, p.height, 0.0, 0.0)

func _draw_spots() -> void:
	var nearest: Dictionary = {}
	if world != null:
		nearest = world.nearest_spot() as Dictionary
	var target: Dictionary = {}
	if world != null and world.has_method("current_target_spot"):
		target = world.current_target_spot() as Dictionary
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
		var is_target: bool = not target.is_empty() and target.get("pos", Vector2.ZERO) == at
		if is_target:
			# 引导软光斑：未拿到首物证前，在目标热点脚下留一团暖色光晕。
			draw_circle(at + Vector2(0, -6), 22.0, Color(SKIN.GOLD, 0.16))
			draw_circle(at + Vector2(0, -6), 14.0, Color(SKIN.GOLD, 0.12))
		var pulse_t: float = float(Time.get_ticks_msec()) * 0.0015
		var near_unused: bool = is_near or (not used and player.pos.distance_to(at) < 140.0)
		var breathe: float = 1.0 if near_unused else 0.0
		var base_r: float = 6.0 if is_near else 4.0
		var ring_r: float = base_r + (1.8 if is_near else 0.9) * breathe * sin(pulse_t * 1.6 + at.x * 0.05 + at.y * 0.03)
		if is_near:
			draw_arc(at + Vector2(0, -10), 11.0 + 2.2 * breathe * sin(pulse_t * 2.0), 0.0, TAU, 16, Color(SKIN.GOLD, 0.32), 1.4)
		draw_circle(at + Vector2(0, -10), ring_r, color)
		draw_circle(at + Vector2(0, -10), 2.0, Color(SKIN.PAPER, 0.9))
func _draw_exits() -> void:
	for exit in data.get("exits", []) as Array:
		var e: Dictionary = exit as Dictionary
		var at: Vector2 = e.get("pos", Vector2.ZERO) as Vector2
		var near: bool = player.pos.distance_to(at) < 72.0
		var color: Color = SKIN.GOLD if near else Color(SKIN.GOLD, 0.3)
		var pulse_t: float = float(Time.get_ticks_msec()) * 0.0015
		var ring: float = 14.0 + (2.0 * float(near) * sin(pulse_t * 1.7))
		draw_arc(at + Vector2(0, -8), ring, 0.0, TAU, 16, color, 2.0)
		draw_line(at + Vector2(-5, -8), at + Vector2(5, -8), color, 2.0)

func _draw_dream_veil(bounds: Rect2) -> void:
	var breath: float = 0.022 * sin(float(Time.get_ticks_msec()) * 0.0012)
	draw_rect(bounds, Color(0.72, 0.55, 0.34, 0.16 + breath))
	draw_rect(bounds, Color(0.86, 0.66, 0.38, 0.02 + breath * 0.4))
	var steps: int = 8
	for i in steps:
		var alpha: float = 0.05 * float(i)
		draw_rect(Rect2(bounds.position, Vector2(bounds.size.x, 10.0)), Color(0.86, 0.74, 0.55, alpha))
		draw_rect(Rect2(bounds.position.x, bounds.end.y - 10.0, bounds.size.x, 10.0), Color(0.86, 0.74, 0.55, alpha))

