extends Node2D

const PlaceholderArt = preload("res://scripts/placeholder_art.gd")

var data: Dictionary = {}
var phase: int = 0
var scene_id: String = ""
var floor_y: float = 456.0
var world_ref: Node = null
var direction: int = -1
var _t: float = 0.0
var idle_frames: Array[Texture2D] = []
var talk_frames: Array[Texture2D] = []
var art_loaded: bool = false


func setup(p_data: Dictionary, p_scene: String, p_phase: int, p_floor: float, p_world: Node) -> void:
	data = p_data.duplicate(true)
	scene_id = p_scene
	phase = p_phase
	floor_y = p_floor
	world_ref = p_world
	position = Vector2(float(data.get("x", 0.0)), floor_y)
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if PlaceholderArt.USE_SCENE_ILLUSTRATIONS:
		_load_character_art(str(data.get("style", "")))
	queue_redraw()


func set_phase(p_phase: int) -> void:
	phase = p_phase
	queue_redraw()


func _load_character_art(style: String) -> void:
	var folder: String = _art_folder(style)
	if folder.is_empty():
		return
	idle_frames = _load_pair(folder + "/" + folder + "_idle_L_01.png", folder + "/" + folder + "_idle_L_02.png")
	talk_frames = _load_pair(folder + "/" + folder + "_talk_L_01.png", folder + "/" + folder + "_talk_L_02.png")
	art_loaded = not idle_frames.is_empty()


func _art_folder(style: String) -> String:
	if style == "xiaoman":
		return "xiaoman"
	if style == "zhou":
		return "zhou"
	if style == "tang":
		return "tang"
	if style == "wu":
		return "wu"
	if style == "chen":
		return "chen"
	if style == "mom":
		return "mom"
	if style == "shop":
		return "shop"
	if style == "player":
		return "shenyan"
	return ""


func _load_pair(first: String, second: String) -> Array[Texture2D]:
	var list: Array[Texture2D] = []
	var a: Texture2D = _safe_texture("res://art/chars/" + first)
	var b: Texture2D = _safe_texture("res://art/chars/" + second)
	if a != null:
		list.append(a)
	if b != null:
		list.append(b)
	return list


func _safe_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	return null


func _process(delta: float) -> void:
	_t += delta
	if world_ref != null:
		var px: float = float(world_ref.get("player_x"))
		direction = -1 if px < position.x else 1
	queue_redraw()


func _draw() -> void:
	if not art_loaded:
		var local_data: Dictionary = data.duplicate(true)
		local_data["x"] = 0.0
		PlaceholderArt.actor(self, local_data, _t, false, direction, _highlight())
		return
	var active: bool = _highlight()
	var pool: Array[Texture2D] = talk_frames if active and not talk_frames.is_empty() else idle_frames
	var index: int = int(_t * (3.2 if active else 1.6)) % max(1, pool.size())
	var texture: Texture2D = pool[index]
	PlaceholderArt.shadow(self, 0.0, 2.0, 34.0)
	if active:
		draw_circle(Vector2(0.0, -4.0), 36.0, Color(0.95, 0.74, 0.30, 0.12), true)
		draw_arc(Vector2(0.0, -4.0), 36.0, 0.0, TAU, 32, Color(0.95, 0.74, 0.30, 0.45), 1.0)
	var draw_size: float = 176.0
	var flip: float = -1.0 if direction > 0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, -160.0, draw_size, draw_size), false, Color(1.0, 1.0, 1.0, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _highlight() -> bool:
	return world_ref != null and bool(world_ref.call("is_actor_active", self))
