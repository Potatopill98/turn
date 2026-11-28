extends CharacterBody2D

const PlaceholderArt = preload("res://scripts/placeholder_art.gd")

var speed_walk: float = 150.0
var speed_run: float = 260.0
var direction: int = 1
var moving: bool = false
var input_enabled: bool = true
var floor_y: float = 456.0
var min_x: float = 24.0
var max_x: float = 2856.0
var _t: float = 0.0
var _dust: Array[Dictionary] = []
var idle_frames: Array[Texture2D] = []
var art_loaded: bool = false
var walk_frames: Array[Texture2D] = []
var stride_distance := 0.0
var last_dust_step := -1


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if PlaceholderArt.USE_SCENE_ILLUSTRATIONS:
		_load_player_art()
	queue_redraw()


func _load_player_art() -> void:
	var first: Texture2D = _load_frame("res://art/chars/shenyan/shenyan_idle_L_01.png")
	if first != null:
		idle_frames.append(first)
	var second: Texture2D = _load_frame("res://art/chars/shenyan/shenyan_idle_L_02.png")
	if second != null:
		idle_frames.append(second)
	for i in range(1, 7):
		var frame := _load_frame("res://art/chars/shenyan/shenyan_walk_L_%02d.png" % i)
		if frame != null:
			walk_frames.append(frame)
	art_loaded = not idle_frames.is_empty()


func _load_frame(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	return null


func setup(p_floor: float, p_min: float, p_max: float) -> void:
	floor_y = p_floor
	min_x = p_min
	max_x = p_max
	position.y = floor_y
	velocity = Vector2.ZERO
	moving = false
	stride_distance = 0.0
	last_dust_step = -1
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	var axis: float = 0.0
	if input_enabled:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			axis -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			axis += 1.0
	var running: bool = Input.is_key_pressed(KEY_SHIFT)
	var target_speed: float = speed_run if running else speed_walk
	velocity.x = move_toward(velocity.x, axis * target_speed, delta * (1750.0 if axis == 0 else 1250.0)) if input_enabled else 0.0
	velocity.y = 0.0
	if absf(axis) > 0.01:
		direction = 1 if axis > 0.0 else -1
	var previous_x := position.x
	move_and_slide()
	position.y = floor_y
	position.x = clampf(position.x, min_x, max_x)
	GameState.current_x = position.x
	var traveled := absf(position.x - previous_x)
	moving = traveled > 0.08
	stride_distance += traveled
	var dust_step := int(stride_distance / 30.0)
	if moving and dust_step != last_dust_step:
		last_dust_step = dust_step
		_dust.append({"x": position.x - direction * 16.0, "y": floor_y - 2.0, "life": 0.45, "vx": -direction * 26.0})
	if _dust.size() > 16:
		_dust.pop_front()
	for i in range(_dust.size() - 1, -1, -1):
		var d: Dictionary = _dust[i]
		d["life"] = float(d.get("life", 0.0)) - delta
		d["x"] = float(d.get("x", 0.0)) + float(d.get("vx", 0.0)) * delta
		d["y"] = float(d.get("y", 0.0)) - 16.0 * delta
		if float(d.get("life", 0.0)) <= 0.0:
			_dust.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for d in _dust:
		var life: float = float(d.get("life", 0.0))
		var a: float = clampf(life / 0.45, 0.0, 1.0) * 0.28
		draw_circle(Vector2(float(d.get("x", 0.0)) - position.x, float(d.get("y", 0.0)) - position.y), 3.0,
			Color(0.75, 0.70, 0.58, a), true)
	if art_loaded:
		PlaceholderArt.shadow(self, 0.0, 2.0, 30.0)
		var texture: Texture2D = idle_frames[int(_t * 1.5) % idle_frames.size()]
		if moving and not walk_frames.is_empty():
			texture = walk_frames[int(stride_distance / 10.0) % walk_frames.size()]
		var flip: float = -1.0 if direction > 0 else 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
		draw_texture_rect(texture, Rect2(-88.0, -160.0, 176.0, 176.0), false, Color(1.0, 1.0, 1.0, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var data: Dictionary = {"style": "player", "name": ""}
		PlaceholderArt.actor(self, data, stride_distance * 0.10 / 9.0 if moving else _t, moving, direction, false)
