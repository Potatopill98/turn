extends Node2D

# v3 第二三幕走位层：只画人物 / 热点 / 出口，背景仍由 later_chapters 画。
# 走近热点按 E 触发，走近出口按 E 推进。

const TravelerArt = preload("res://traveler_art.gd")
const SKIN = preload("res://ui/theme.gd")

var walk_rect: Rect2 = Rect2(120, 300, 740, 105)
var spots: Array[Vector2] = []
var labels: Array[String] = []
var exit_spot: Vector2 = Vector2(860, 360)
var exit_label: String = ""
var player: Vector2 = Vector2(200, 370)
var direction: int = 1
var speed: float = 150.0
var step_phase: float = 0.0
var step_meter: float = 0.0
var active: bool = false
var walking: bool = false
var on_spot: Callable = Callable()
var on_exit: Callable = Callable()
var nearest_index: int = -1
var toast: String = ""
var toast_time: float = 0.0
var font: SystemFont
var sound: AudioStreamPlayer

func _ready() -> void:
	font = SKIN.font()
	sound = AudioStreamPlayer.new()
	sound.stream = preload("res://audio/prologue/wood.wav")
	sound.volume_db = -18.0
	add_child(sound)
	visible = false
	set_process(false)

func configure(rect: Rect2, spot_list: Array[Vector2], label_list: Array[String], exit_position: Vector2, exit_caption: String, spot_callback: Callable, exit_callback: Callable) -> void:
	walk_rect = rect
	spots = spot_list
	labels = label_list
	exit_spot = exit_position
	exit_label = exit_caption
	on_spot = spot_callback
	on_exit = exit_callback

func activate() -> void:
	active = true
	visible = true
	set_process(true)
	player = Vector2(walk_rect.position.x + 50.0, walk_rect.end.y - 26.0)
	direction = 1
	nearest_index = -1
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false
	set_process(false)

func say(text: String) -> void:
	toast = text
	toast_time = 2.2
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
	var motion := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	motion += Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	)
	direction = TravelerArt.facing(motion, direction)
	var desired := motion.limit_length() * speed
	walking = desired.length_squared() > 0.01
	player += desired * delta
	player.x = clampf(player.x, walk_rect.position.x, walk_rect.end.x)
	player.y = clampf(player.y, walk_rect.position.y, walk_rect.end.y)
	if walking:
		step_meter += desired.length() * delta
		step_phase += desired.length() * delta / 56.0 * 2.0
		if step_meter >= 56.0:
			step_meter = 0.0
			if sound.stream != null:
				sound.play()
	nearest_index = -1
	var best := 52.0
	for i in spots.size():
		var distance := player.distance_to(spots[i])
		if distance < best:
			best = distance
			nearest_index = i
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not active:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.physical_keycode != KEY_E:
		return
	if nearest_index >= 0 and on_spot.is_valid():
		on_spot.call(nearest_index)
		get_viewport().set_input_as_handled()
	elif player.distance_to(exit_spot) < 58.0 and on_exit.is_valid():
		on_exit.call()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not active:
		return
	if walking:
		TravelerArt.draw_walk(self, player, direction, 118.0, int(step_phase) % 4)
	else:
		TravelerArt.draw(self, player, direction, 118.0)
	for i in spots.size():
		var here: bool = i == nearest_index
		draw_circle(spots[i] + Vector2(0, -8), 5.0 if here else 3.5, SKIN.GOLD if here else Color(SKIN.GOLD, 0.42))
		draw_string(font, spots[i] + Vector2(-26, -20), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(SKIN.PAPER, 0.95 if here else 0.62))
	draw_circle(exit_spot + Vector2(0, -8), 6.0, Color(SKIN.GOLD, 0.55))
	draw_string(font, exit_spot + Vector2(-34, -22), exit_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(SKIN.PAPER, 0.72))
	if nearest_index >= 0:
		var caption: String = "E  " + labels[nearest_index]
		var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18.0
		draw_rect(Rect2(player + Vector2(-width / 2.0, -152), Vector2(width, 24)), SKIN.INK)
		draw_string(font, player + Vector2(-width / 2.0 + 9.0, -135), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SKIN.GOLD)
	elif player.distance_to(exit_spot) < 58.0:
		var caption: String = "E  " + exit_label
		var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18.0
		draw_rect(Rect2(player + Vector2(-width / 2.0, -152), Vector2(width, 24)), SKIN.INK)
		draw_string(font, player + Vector2(-width / 2.0 + 9.0, -135), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SKIN.GOLD)
	if toast_time > 0.0:
		var alpha: float = clampf(toast_time / 0.5, 0.0, 1.0)
		draw_rect(Rect2(220, 278, 520, 30), Color(SKIN.INK, 0.82 * alpha))
		draw_string(font, Vector2(240, 299), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(SKIN.GOLD, alpha))
	draw_string(font, Vector2(60, 420), "WASD / 方向键走动   E 查看   I 手记", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(SKIN.PAPER, 0.55))
