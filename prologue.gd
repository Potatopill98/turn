extends Node2D

const Progress = preload("res://chapter_progress.gd")
const Data = preload("res://scripts/turn_data.gd")
const TravelerArt = preload("res://traveler_art.gd")
const TitleCard = preload("res://ui/title_card.gd")
const ChapterSelect = preload("res://ui/chapter_select.gd")
const ChapterPlayer = preload("res://ui/chapter_player.gd")
const ROOM = "res://room.tscn"
const BACKGROUNDS = [
	preload("res://art/00_场景/02_镇口可玩空景.png"),
	preload("res://art/00_场景/08_归乡老宅门前.png"),
	preload("res://art/00_场景/05_旧宅原型底图_960x600.png"),
]
const DOOR_SHOT = preload("res://art/00_场景/13_推开干净木门的手.png")
const DIARY = preload("res://art/05_道具_序章/旧日记本_空白页.png")
const PRINT_ART = preload("res://art/05_道具_序章/多出的三步脚印.png")
const CLOCK = preload("res://art/05_道具_序章/老宅墙钟.png")
const CLOCK_HAND = preload("res://art/05_道具_序章/墙钟秒针.png")
const VISIBLE := Vector2(960, 540)
const STARTS = [Vector2(540, 480), Vector2(515, 478), Vector2(248, 438)]
const EXITS = [Vector2(548, 141), Vector2(568, 246), Vector2(826, 253)]
const DESK := Vector2(371, 341)
const BOOK_SPOT := Vector2(368, 366)
const CLOCK_SPOT := Vector2(540, 126)
const CLOCK_TRIGGER := Vector2(540, 283)
const MUD := Rect2(635, 370, 255, 135)
const DIARY_FIRST := "我要离开这里"
const DIARY_SECOND := "，等把该做的事做完。"
const INK := Color("#20272b")
const PAPER := Color("#f5ead5")
const GOLD := Color("#ffdc9d")
const PRINT_REGIONS = [Rect2(348, 83, 185, 232), Rect2(491, 308, 201, 305), Rect2(345, 616, 209, 340)]

var walkable := [
	PackedVector2Array([Vector2(399, 535), Vector2(659, 535), Vector2(655, 440), Vector2(937, 466), Vector2(937, 353), Vector2(639, 321), Vector2(598, 105), Vector2(522, 105), Vector2(447, 316), Vector2(51, 282), Vector2(35, 377), Vector2(412, 427)]),
	PackedVector2Array([Vector2(416, 505), Vector2(887, 505), Vector2(887, 377), Vector2(730, 365), Vector2(740, 318), Vector2(732, 267), Vector2(651, 250), Vector2(644, 233), Vector2(491, 233), Vector2(467, 252), Vector2(347, 247), Vector2(347, 306), Vector2(451, 330)]),
	PackedVector2Array([Vector2(110, 482), Vector2(854, 482), Vector2(854, 255), Vector2(110, 255)]),
]
var area := 0
var player: Vector2 = STARTS[0]
var velocity := Vector2.ZERO
var direction := 0
var step_phase := 0.0
var moved := false
var walking := false
var shop_memory := 0.0
const SHOP := Vector2(185, 308)
const SHOT_ZOOM = [1.13, 1.12, 1.18]
var camera_position := VISIBLE / 2
var zoom := 1.0
var world := Node2D.new()
var font := SystemFont.new()
var handwriting := SystemFont.new()
var opening_door := false
var switching := false
var fade := 0.0
var diary_open := false
var diary_read := false
var footprints_started := false
var trail_points := PackedVector2Array()
var trail_angles := PackedFloat32Array()
var trail_times := PackedFloat32Array()
var trail_distance := 0.0
var footprint_time := 0.0
var clock_approached := false
var clock_reversed := false
var clock_hold := 0.0
var clock_accumulator := 0.0
var clock_tick := 11
var heard_room := false
var room_caption_time := 0.0
const ROOM_LINE := "「爸……先把手松开。」"
const STEP_SOUNDS = [preload("res://audio/prologue/stone.wav"), preload("res://audio/prologue/mud.wav"), preload("res://audio/prologue/wood.wav")]
const HINGE = preload("res://audio/prologue/hinge.wav")
const PAGE = preload("res://audio/prologue/page.wav")
const TICK = preload("res://audio/prologue/tick.wav")
const LATCH = preload("res://audio/prologue/latch.wav")
var steps := AudioStreamPlayer.new()
var props := AudioStreamPlayer.new()
var clock_sound := AudioStreamPlayer.new()
var step_distance := 0.0
var left_foot := false
var arrival_fade := 1.0
var town_title_time := 3.4
var hint_alpha := 1.0
var checkpoint: ConfigFile
var diary_hint := 0.0
var title_card: CanvasLayer
var chapter_select: CanvasLayer
var chapter_player: CanvasLayer
var story_done: bool = false

func sound(channel: AudioStreamPlayer, clip: AudioStream, db: float, pitch := 1.0):
	channel.stream = clip
	channel.volume_db = db
	channel.pitch_scale = pitch
	channel.play()

func _ready():
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	handwriting.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei"])
	checkpoint = Progress.read_save()
	if checkpoint.has_section("turn"):
		var snapshot: String = str(checkpoint.get_value("turn", "v3_state", ""))
		if not snapshot.is_empty():
			TurnState.restore_snapshot(snapshot)
	for key in ["prologue_diary","shared_note","spoke_to_zhou","entry_chapter"]:
		if get_tree().has_meta(key): get_tree().remove_meta(key)
	for channel in [steps, props, clock_sound]:
		add_child(channel)
	world.z_index = -1
	world.draw.connect(draw_world)
	add_child(world)
	TurnState.start_act("prologue")
	diary_read = TurnState.has_flag("diary_read")
	clock_reversed = TurnState.has_flag("clock_reversed")
	if clock_reversed:
		clock_tick = 10
	title_card = TitleCard.new()
	add_child(title_card)
	chapter_player = ChapterPlayer.new()
	add_child(chapter_player)
	chapter_player.play("prologue", _on_story_done)
	chapter_select = ChapterSelect.new()
	add_child(chapter_select)
	reset_arrival_camera()

func _on_story_done() -> void:
	story_done = true
	title_card.show_act("prologue", 1.2)

func _physics_process(delta: float):
	if not story_done:
		return
	if switching or opening_door or diary_open:
		return
	var motion := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	motion += Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	)
	direction = TravelerArt.facing(motion, direction)
	var speed := 260.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 180.0
	var depth_scale: float = character_height() / [114.0, 166.0, 140.0][area]
	velocity = velocity.move_toward(motion.limit_length() * speed * depth_scale, delta * (1900.0 if motion.is_zero_approx() else 1450.0))
	move_on_ground(velocity * delta)

func move_on_ground(step: Vector2):
	var previous := player
	var next := player + Vector2(step.x, 0)
	if can_walk(next):
		player = next
	next = player + Vector2(0, step.y)
	if can_walk(next):
		player = next
	var traveled := player - previous
	walking = traveled.length_squared() > 0.0001
	if walking:
		moved = true
		var stride_length := character_height() * 0.49
		step_phase += traveled.length() / stride_length * 2.0
		step_distance += traveled.length()
		var in_mud := area == 1 and MUD.has_point(player)
		if step_distance >= stride_length:
			step_distance = fmod(step_distance, stride_length)
			left_foot = not left_foot
			var surface := 2 if area == 2 else (1 if in_mud else 0)
			sound(steps, STEP_SOUNDS[surface], -15.0, 0.93 if left_foot else 1.04)
		if area == 1 and not footprints_started:
			trail_distance += traveled.length()
			if trail_distance >= 16.0 or trail_points.is_empty() or in_mud:
				trail_distance = 0.0
				if trail_points.size() == 3:
					trail_points.remove_at(0)
					trail_angles.remove_at(0)
				trail_points.append(player)
				trail_angles.append(traveled.angle() + PI / 2)
			if in_mud and trail_points.size() == 3:
				footprints_started = true
				TurnState.set_flag("footprints_started", true)
				TurnState.unlock_item("e_footprints")
				for i in 3:
					var side := 3.0 if i % 2 == 0 else -3.0
					trail_points[i] += Vector2.from_angle(trail_angles[i]) * side
					trail_times.append(0.28 * i)

	if area == 2:
		check_hallway()

func can_walk(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, walkable[area]) and (
		area != 2 or not Rect2(DESK - Vector2(34, 18), Vector2(68, 20)).has_point(point)
	)

func check_hallway():
	var distance_to_clock := player.distance_to(CLOCK_TRIGGER)
	if distance_to_clock <= 66.0:
		clock_approached = true
	elif distance_to_clock > 100.0 and clock_approached and not clock_reversed:
		clock_reversed = true
		clock_tick -= 1
		TurnState.set_flag("clock_reversed", true)
		TurnState.unlock_item("e_clock")
		TurnState.push_backlog("墙钟", "你退开时，秒针往回跳了一格。")
		sound(clock_sound, TICK, -25.0, 0.75)
		clock_hold = 1.15
		clock_accumulator = 0.0
	if player.distance_to(EXITS[2]) < 108.0 and not heard_room:
		heard_room = true
		room_caption_time = 3.2

func _process(delta: float):
	arrival_fade = move_toward(arrival_fade, 0.0, delta * 2.8)
	town_title_time = maxf(0.0, town_title_time - delta)
	if footprints_started:
		footprint_time += delta
	shop_memory = maxf(0, shop_memory - delta)
	if area == 2 and not diary_open:
		if clock_hold > 0:
			clock_hold = maxf(0, clock_hold - delta)
		else:
			clock_accumulator += delta
			if clock_accumulator >= 1.0:
				clock_accumulator -= 1.0
				clock_tick += 1
				sound(clock_sound, TICK, -22.0 - minf(player.distance_to(CLOCK_TRIGGER) / 18.0, 18.0))
		room_caption_time = maxf(0, room_caption_time - delta)
	if moved:
		hint_alpha = move_toward(hint_alpha, 0.0, delta * 0.48)
	diary_hint = maxf(0.0, diary_hint - delta)
	update_camera(delta)
	world.visible = not opening_door
	world.queue_redraw()
	queue_redraw()

func update_camera(delta: float):
	var blend := 1.0 - exp(-8.0 * delta)
	var half_view := VISIBLE / (2.0 * zoom)
	var focus := player - Vector2(0, character_height() * 0.45)
	var dead_zone := Vector2(72, 42)
	var target := camera_position.clamp(focus - dead_zone, focus + dead_zone).clamp(half_view, VISIBLE - half_view)
	camera_position = camera_position.lerp(target, blend).clamp(half_view, VISIBLE - half_view)
	world.scale = Vector2.ONE * zoom
	world.position = VISIBLE / 2.0 - camera_position * zoom

func near_exit() -> bool:
	var offset: Vector2 = (player - EXITS[area]).abs()
	return offset.x <= [48, 82, 58][area] and offset.y <= 54

func _unhandled_key_input(event: InputEvent):
	if not story_done:
		return
	if not (event is InputEventKey and event.pressed and not event.echo) or switching:
		return
	if event.physical_keycode == KEY_R and area == 0:
		get_viewport().set_input_as_handled()
		chapter_select.open(_on_chapter_picked)
		return
	if event.physical_keycode == KEY_SPACE and room_caption_time > 0.0 and not diary_open:
		room_caption_time = minf(room_caption_time, 2.4)
	elif event.physical_keycode == KEY_I:
		get_viewport().set_input_as_handled()
		JournalUI.toggle()
	elif event.physical_keycode in [KEY_E, KEY_ESCAPE] and diary_open:
		toggle_diary()
	elif event.physical_keycode == KEY_E and not opening_door:
		if area == 0 and player.distance_to(SHOP) <= 58.0:
			shop_memory = 4.5
		elif area == 2 and player.distance_to(BOOK_SPOT) <= 59.0:
			diary_read = true
			TurnState.set_flag("diary_read", true)
			TurnState.unlock_item("e_diary")
			TurnState.push_backlog("旧日记", DIARY_FIRST + DIARY_SECOND)
			get_tree().set_meta("prologue_diary", DIARY_FIRST + DIARY_SECOND)
			toggle_diary()
		elif near_exit():
			activate_exit()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()

func _on_chapter_picked(id: String) -> void:
	if id == "prologue":
		get_tree().change_scene_to_file("res://prologue.tscn")
	elif id == "room":
		Progress.mark(get_tree(), "room")
		get_tree().change_scene_to_file("res://room.tscn")
	else:
		get_tree().set_meta("entry_chapter", id)
		get_tree().change_scene_to_file("res://later_chapters.tscn")

func toggle_diary():
	diary_open = not diary_open
	sound(props, PAGE, -12.0)
	if not diary_open:
		diary_hint = 4.0
	velocity = Vector2.ZERO

func activate_exit():
	velocity = Vector2.ZERO
	match area:
		0:
			area = 1
			player = STARTS[1]
			reset_arrival_camera()
		1:
			opening_door = true
			sound(props, HINGE, -12.0)
			# The insert closes on a timer so holding E cannot dismiss it twice.
			await get_tree().create_timer(0.95).timeout
			area = 2
			player = STARTS[2]
			reset_arrival_camera()
			opening_door = false
		2:
			switching = true
			sound(props, LATCH, -12.0)
			var transition := create_tween()
			transition.tween_property(self, "fade", 1.0, 0.28)
			await transition.finished
			var result := get_tree().change_scene_to_file(ROOM)
			if result != OK:
				fade = 0.0
				switching = false
				push_error(error_string(result))
	direction = 0

func reset_arrival_camera():
	arrival_fade = 1.0
	step_distance = 0.0
	zoom = SHOT_ZOOM[area]
	walking = false
	shop_memory = 0.0
	var half_view := VISIBLE / (2.0 * zoom)
	camera_position = (player - Vector2(0, 42)).clamp(half_view, VISIBLE - half_view)
	update_camera(0.0)

func draw_world():
	if area == 2:
		var source := Rect2(68, 107, 824, 393)
		world.draw_texture_rect_region(BACKGROUNDS[area], Rect2(0, 0, 960, 540), source)
		draw_indoor_props()
	elif area < 2:
		world.draw_texture_rect(BACKGROUNDS[area], Rect2(Vector2.ZERO, VISIBLE), false)
	if area == 1 and footprints_started:
		draw_footprints()
	var height := character_height()
	if walking and not diary_open:
		TravelerArt.draw_walk(world, player, direction, height, int(step_phase) % 4)
	else:
		TravelerArt.draw(world, player, direction, height)

func character_height() -> float:
	match area:
		0: return lerpf(58, 114, clampf((player.y - 120) / 365, 0, 1))
		1: return lerpf(134, 166, clampf((player.y - 235) / 270, 0, 1))
		_: return lerpf(109, 140, clampf((player.y - 255) / 227, 0, 1))

func draw_indoor_props():
	world.draw_set_transform(DESK + Vector2(4, 5), 0, Vector2(1, 0.23))
	world.draw_circle(Vector2.ZERO, 40, Color(0.15, 0.12, 0.1, 0.20))
	world.draw_set_transform(Vector2.ZERO)
	for x in [-30, 24]:
		world.draw_rect(Rect2(DESK + Vector2(x, -6), Vector2(5, 22)), Color("#5f4737"))
	world.draw_rect(Rect2(DESK - Vector2(35, 18), Vector2(70, 15)), Color("#6c4f3e"))
	world.draw_rect(Rect2(DESK - Vector2(35, 21), Vector2(70, 21)), Color("#a58361"))
	world.draw_texture_rect(DIARY, Rect2(DESK - Vector2(12, 23), Vector2(23, 23)), false)
	world.draw_texture_rect_region(CLOCK, Rect2(CLOCK_SPOT - Vector2(26, 23), Vector2(52, 48)), Rect2(79, 105, 865, 805))
	world.draw_set_transform(CLOCK_SPOT, deg_to_rad(float(clock_tick) * 6))
	world.draw_texture_rect_region(CLOCK_HAND, Rect2(-1.7, -18, 3.4, 22), Rect2(404, 101, 68, 490))
	world.draw_set_transform(Vector2.ZERO)

func draw_footprints():
	for i in trail_points.size():
		var visibility := clampf((footprint_time - trail_times[i] - 0.22) / 0.22, 0.0, 1.0)
		if visibility == 0.0:
			continue
		world.draw_set_transform(trail_points[i], trail_angles[i])
		world.draw_texture_rect_region(PRINT_ART, Rect2(-6, -10, 12, 20), PRINT_REGIONS[i], Color(1, 1, 1, visibility * 0.88))
	world.draw_set_transform(Vector2.ZERO)

func label(at: Vector2, caption: String, size: int, color: Color):
	draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func prompt(spot: Vector2, caption: String):
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 26
	var center := world.position + spot * zoom
	center.x = clampf(center.x, width / 2 + 8, 952 - width / 2)
	center.y = clampf(center.y - 24, 38, 516)
	draw_rect(Rect2(center - Vector2(width / 2, 23), Vector2(width, 29)), INK)
	label(center - Vector2(width / 2 - 13, 2), caption, 17, GOLD)

func _draw():
	draw_rect(Rect2(0, 540, 960, 60), INK)
	if opening_door:
		var size := DOOR_SHOT.get_size()
		size *= minf(VISIBLE.x / size.x, VISIBLE.y / size.y)
		draw_texture_rect(DOOR_SHOT, Rect2((VISIBLE - size) / 2, size), false)
		label(Vector2(23, 578), "门轴轻轻响了一声。", 19, PAPER)
	elif diary_open:
		draw_rect(Rect2(Vector2.ZERO, VISIBLE), Color(0.08, 0.09, 0.10, 0.75))
		draw_texture_rect(DIARY, Rect2(296, 28, 368, 482), false)
		label(Vector2(339, 153), DIARY_FIRST, 24, INK)
		draw_set_transform(Vector2(339, 196), -0.045)
		draw_string(handwriting, Vector2.ZERO, DIARY_SECOND.trim_prefix("，"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#534137"))
		draw_set_transform(Vector2.ZERO)
		label(Vector2(22, 577), "旧日记 · 第一页", 20, PAPER)
		label(Vector2(707, 577), "E / Esc 收起", 17, GOLD)
	else:
		var task: String = ["沿石板巷往里走。", "沿石路走到绿木门前。", "屋里有人。去右侧房门看看。"][area]
		if area == 0 and shop_memory > 0.0 and player.distance_to(SHOP) < 126.0:
			task = "小时候踮着脚，才够得着这个窗口。"
		if room_caption_time > 0.0:
			task = ROOM_LINE.left(int((3.2 - room_caption_time) * 19.0))
		label(Vector2(22, 576), task, 20, PAPER)
		if area == 0 and player.distance_to(SHOP) <= 58.0 and shop_memory <= 0.0:
			prompt(SHOP - Vector2(0, 55), "E  看看旧铺子")
		if near_exit():
			prompt(EXITS[area] + Vector2(64, -45), ["E  往老宅", "E  推门", "E  进去看看"][area])
		if area == 2 and player.distance_to(BOOK_SPOT) <= 59:
			prompt(DESK + Vector2(64, 0), "E  看日记")

		var controls := "WASD / 方向键   E 互动   Shift 快走"
		if diary_hint > 0.0:
			controls = "I 手记   E 互动"
		var color := Color(GOLD, 1.0 if diary_hint > 0.0 else hint_alpha)
		label(Vector2(647, 576), controls, 15, color)
	if area == 0:
		var resume_text: String = "R  章节列表"
		if checkpoint.has_section("turn"):
			resume_text = "R  章节 · " + str(Progress.NAMES[checkpoint.get_value("turn","chapter")])
		label(Vector2(622, 594), resume_text, 15, GOLD)
	if area == 0 and town_title_time > 0.0:
		var opacity := minf(town_title_time, 1.0)
		draw_rect(Rect2(26, 30, 158, 66), Color(INK, 0.82 * opacity))
		label(Vector2(39, 55), "序章", 16, Color(GOLD, opacity))
		label(Vector2(39, 83), "归乡旅人", 23, Color(PAPER, opacity))
	if arrival_fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VISIBLE), Color(INK, arrival_fade))
	if fade > 0.0:
		draw_rect(Rect2(0, 0, 960, 600), Color(INK, fade))
