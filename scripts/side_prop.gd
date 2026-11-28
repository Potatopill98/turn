extends Node2D

const PlaceholderArt = preload("res://scripts/placeholder_art.gd")

var data: Dictionary = {}
var phase: int = 0
var scene_id: String = ""
var floor_y: float = 456.0
var world_ref: Node = null
var _t: float = 0.0
var art_texture: Texture2D = null
var art_size: Vector2 = Vector2.ZERO
var art_y_offset: float = 0.0
var art_loaded: bool = false


func setup(p_data: Dictionary, p_scene: String, p_phase: int, p_floor: float, p_world: Node) -> void:
	data = p_data.duplicate(true)
	scene_id = p_scene
	phase = p_phase
	floor_y = p_floor
	world_ref = p_world
	position = Vector2(float(data.get("x", 0.0)), floor_y)
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if PlaceholderArt.USE_SCENE_ILLUSTRATIONS:
		_load_prop_art()
	queue_redraw()


func set_phase(p_phase: int) -> void:
	phase = p_phase
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _state() -> String:
	var kind: String = str(data.get("kind", ""))
	if kind == "swing":
		if GameState.has_flag("helped_zhou"):
			return "done"
		if world_ref != null and int(world_ref.get("chore_stage")) == 1:
			return "held"
	if kind == "score" and GameState.has_flag("helped_xiaoman"):
		return "done"
	if kind == "box" and GameState.has_flag("helped_tang"):
		return "done"
	if kind == "chest" and GameState.has_flag("dream_seen"):
		return "open"
	return "idle"


func _load_prop_art() -> void:
	var art_map: Dictionary = {
		"station/station_sign": {"path": "station/PR-01.png", "h": 220.0},
		"station/station_bus": {"path": "station/PR-02.png", "h": 300.0},
		"station/station_bench": {"path": "station/PR-03.png", "h": 92.0},
		"town_gate/gate_notice": {"path": "town_gate/PR-04.png", "h": 150.0},
		"town_gate/gate_car": {"path": "town_gate/PR-05.png", "h": 200.0},
		"town_gate/gate_bench": {"path": "town_gate/PR-06.png", "h": 92.0},
		"street_west/west_mailbox": {"path": "street_west/PR-07.png", "h": 220.0},
		"street_west/west_score": {"path": "street_west/PR-08.png", "h": 54.0},
		"street_west/west_score_done": {"path": "street_west/PR-09.png", "h": 70.0},
		"street_west/west_lamp": {"path": "street_west/PR-10.png", "h": 320.0},
		"street_west/west_puddle": {"path": "street_west/PR-11.png", "h": 22.0},
		"street_east/east_bike": {"path": "street_east/PR-12.png", "h": 150.0},
		"street_east/east_poster": {"path": "street_east/PR-13.png", "h": 190.0},
		"street_east/east_arrow": {"path": "street_east/PR-14.png", "h": 130.0},
		"playground/play_swing": {"path": "playground/PR-15.png", "h": 260.0},
		"playground/play_swing_done": {"path": "playground/PR-16.png", "h": 260.0},
		"playground/play_bench": {"path": "playground/PR-17.png", "h": 100.0},
		"playground/play_shoes": {"path": "playground/PR-18.png", "h": 56.0},
		"playground/play_slide": {"path": "playground/PR-19.png", "h": 280.0},
		"playground/play_fence": {"path": "playground/PR-20.png", "h": 160.0},
		"playground/play_lamp": {"path": "playground/PR-21.png", "h": 320.0},
		"crossing/cross_box": {"path": "crossing/PR-22.png", "h": 160.0},
		"crossing/cross_box_done": {"path": "crossing/PR-23.png", "h": 170.0},
		"crossing/cross_list": {"path": "crossing/PR-24.png", "h": 100.0, "y": -8.0},
		"crossing/cross_car": {"path": "crossing/PR-25.png", "h": 280.0},
		"crossing/cross_puddle": {"path": "crossing/PR-26.png", "h": 38.0},
		"town_final/final_bus": {"path": "town_final/PR-28.png", "h": 270.0},
		"town_final/final_sign": {"path": "town_final/PR-29.png", "h": 300.0},
		"house_yard/yard_mailbox": {"path": "house_yard/PR-30.png", "h": 220.0},
		"house_yard/yard_step": {"path": "house_yard/PR-31.png", "h": 66.0},
		"house_hall/hall_photo": {"path": "house_hall/PR-32.png", "h": 150.0, "y": -28.0},
		"house_hall/hall_note": {"path": "house_hall/PR-33.png", "h": 110.0, "y": -18.0},
		"house_hall/hall_clock": {"path": "house_hall/PR-34.png", "h": 270.0},
		"house_hall/hall_sofa": {"path": "house_hall/PR-35.png", "h": 160.0},
		"house_hall/hall_table": {"path": "house_hall/PR-36.png", "h": 100.0},
		"basement/base_chest": {"path": "basement/PR-37_closed.png", "h": 230.0, "open_path": "basement/PR-38_open.png"},
		"basement/base_shelf": {"path": "basement/PR-39.png", "h": 280.0},
		"shop/shop_counter": {"path": "shop/PR-40.png", "h": 210.0},
		"shop/shop_shelf": {"path": "shop/PR-41.png", "h": 250.0},
		"dream/dream_desk1": {"path": "dream/PR-42.png", "h": 150.0},
		"dream/dream_desk2": {"path": "dream/PR-42.png", "h": 150.0},
		"dream/dream_clock": {"path": "dream/PR-43.png", "h": 300.0},
	}
	var key: String = scene_id + "/" + str(data.get("id", ""))
	if not art_map.has(key):
		return
	var entry: Dictionary = art_map[key] as Dictionary
	var path: String = str(entry.get("path", ""))
	if _state() == "open" and entry.has("open_path"):
		path = str(entry.get("open_path", path))
	art_texture = _safe_texture("res://art/props/" + path)
	if art_texture == null:
		return
	var target_h: float = float(entry.get("h", 160.0))
	var tex_size: Vector2 = art_texture.get_size()
	var target_w: float = target_h * tex_size.x / max(1.0, tex_size.y)
	art_size = Vector2(target_w, target_h)
	art_y_offset = float(entry.get("y", 0.0))
	art_loaded = true


func _safe_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	return null


func _highlight() -> bool:
	return world_ref != null and bool(world_ref.call("is_prop_active", self))


func _draw() -> void:
	if str(data.get("kind", "")) != "swing" and art_loaded and art_texture != null:
		PlaceholderArt.shadow(self, 0.0, 2.0, art_size.x * 0.30)
		var rect: Rect2 = Rect2(-art_size.x * 0.5, -art_size.y + art_y_offset, art_size.x, art_size.y)
		draw_texture_rect(art_texture, rect, false, Color(1.0, 1.0, 1.0, 1.0))
		if _highlight():
			draw_rect(Rect2(rect.position - Vector2(4.0, 4.0), rect.size + Vector2(8.0, 8.0)), Color(0.95, 0.74, 0.30, 0.45), false, 2.0)
		return
	var local_data: Dictionary = data.duplicate(true)
	local_data["x"] = 0.0
	local_data["floor_y"] = 0.0
	PlaceholderArt.prop(self, local_data, phase, _t, _highlight(), _state())
