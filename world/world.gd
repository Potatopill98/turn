extends Node2D

# 探索模式主控：场景切换、自由移动、相机、热点交互、剧情播放、HUD。
# 目标：整条镇子 + 老宅室内 + 三个梦 + 狼城，全部可以走进去。

const WorldData = preload("res://world/world_data.gd")
const PlayerState = preload("res://world/player_state.gd")
const SceneView = preload("res://world/scene_view.gd")
const ChapterPlayer = preload("res://ui/chapter_player.gd")
const SKIN = preload("res://ui/theme.gd")
const Journal = preload("res://ui/journal_panel.gd")

const FONT_SIZE_HUD: int = 12
const SPOT_RADIUS: float = 76.0
const NPC_RADIUS: float = 84.0
const EXIT_RADIUS: float = 76.0

# 每个地点首访播放的剧情段（act, 起始 beat, 结束 beat 不含）
const INTROS: Dictionary = {
	"langcheng_room": ["prologue", 0, 2],
	"langcheng_office": ["prologue", 2, 3],
	"langcheng_factory": ["epilogue", 19, 21],
	"town_gate": ["prologue", 8, 12],
	"town_road": ["first", 6, 9],
	"old_house_yard": ["first", 0, 1],
	"house_hall": ["first", 1, 6],
	"playground_day": ["second", 3, 6],
	"playground_night": ["second", 4, 9],
	"street_cross": ["third", 10, 14],
	"town_final": ["epilogue", 0, 4],
	"dream_classroom": ["first_dream", 0, 6],
	"dream_alley": ["first_dream", 6, 10],
	"dream_postbox": ["first_dream", 10, 15],
	"dream_box": ["first_dream", 15, 20],
	"dream_swing": ["second_dream", 10, 14],
	"dream_dirt_road": ["third_dream", 12, 18],
	"dream_station": ["third_dream", 24, 30],
}

var scenes: Dictionary = {}
var data: Dictionary = {}
var scene_id: String = "langcheng_room"
var player = null
var view = null
var camera: Camera2D = null
var chapter = null

var _locked: bool = false
var _hud: CanvasLayer = null
var _hud_root: Control = null
var _bubble: Label = null
var _bubble_bg: ColorRect = null
var _scene_title: Label = null
var _scene_sub: Label = null
var _dialog_panel: ColorRect = null
var _dialog_label: Label = null
var _dialog_time: float = 0.0
var _hint_band: ColorRect = null
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _return_scene: String = ""
var _return_spawn: String = ""
var _nearest_spot: Dictionary = {}
var _nearest_npc: Dictionary = {}
var _nearest_exit: Dictionary = {}
var _used: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	scenes = WorldData.all()
	player = PlayerState.new()

	view = SceneView.new()
	view.name = "SceneView"
	add_child(view)

	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()

	_build_hud()

	chapter = ChapterPlayer.new()
	add_child(chapter)

	var start_id: String = str(TurnState.get_flag("explore_scene", "langcheng_room"))
	if not scenes.has(start_id):
		start_id = "langcheng_room"
	var start_spawn: String = str(TurnState.get_flag("explore_spawn", ""))
	_enter(start_id, start_spawn, false)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 110
	add_child(_hud)

	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hud_root)

	_bubble = SKIN.make_label("", FONT_SIZE_HUD, SKIN.GOLD)
	_bubble.position = Vector2(400, 300)
	_bubble.size = Vector2(260, 24)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.visible = false
	_hud_root.add_child(_bubble)
	_bubble_bg = ColorRect.new()
	_bubble_bg.color = Color(0.05, 0.06, 0.07, 0.82)
	_bubble_bg.position = Vector2(400, 298)
	_bubble_bg.size = Vector2(260, 24)
	_bubble_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_bg.visible = false
	_hud_root.add_child(_bubble_bg)
	_hud_root.move_child(_bubble_bg, _bubble.get_index())

	var title_bg: ColorRect = ColorRect.new()
	title_bg.color = Color(0.05, 0.06, 0.07, 0.58)
	title_bg.position = Vector2(0, 0)
	title_bg.size = Vector2(960, 62)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(title_bg)

	_scene_title = SKIN.make_label("", 18, SKIN.PAPER)
	_scene_title.position = Vector2(26, 9)
	_hud_root.add_child(_scene_title)

	_scene_sub = SKIN.make_label("", 12, SKIN.GOLD_DIM)
	_scene_sub.position = Vector2(26, 34)
	_hud_root.add_child(_scene_sub)

	_dialog_panel = ColorRect.new()
	_dialog_panel.color = Color(SKIN.INK, 0.93)
	_dialog_panel.position = Vector2(120, 452)
	_dialog_panel.size = Vector2(720, 92)
	_dialog_panel.visible = false
	_hud_root.add_child(_dialog_panel)

	_dialog_label = SKIN.make_label("", 16, SKIN.PAPER, 696.0)
	_dialog_label.position = Vector2(136, 466)
	_dialog_label.size = Vector2(696, 68)
	_hud_root.add_child(_dialog_label)

	_hint_band = ColorRect.new()
	_hint_band.color = Color(0.06, 0.07, 0.08, 0.62)
	_hint_band.position = Vector2(0, 560)
	_hint_band.size = Vector2(960, 40)
	_hint_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_hint_band)
	var hint: Label = SKIN.make_label("WASD / 方向键 走动　E 查看与交谈　I 手记　Esc 菜单", 12, Color(SKIN.PAPER, 0.82))
	hint.position = Vector2(24, 572)
	_hud_root.add_child(hint)

	var journal_button: Button = SKIN.make_button("手记  I", 12, 92.0, 28.0)
	journal_button.position = Vector2(760, 14)
	journal_button.pressed.connect(_toggle_journal)
	_hud_root.add_child(journal_button)



	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 300
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

func _enter(id: String, spawn_name: String = "", play_intro: bool = true) -> void:
	if not scenes.has(id):
		return
	scene_id = id
	data = scenes[id] as Dictionary
	var spawns: Dictionary = data.get("spawns", {}) as Dictionary
	var at: Vector2 = data.get("spawn", Vector2(480, 480)) as Vector2
	if not spawn_name.is_empty() and spawns.has(spawn_name):
		at = spawns[spawn_name] as Vector2
	player.reset(at, 1)
	player.height = float(data.get("player_height", 92.0))
	view.setup(data, player, self)
	_update_camera(true)
	TurnState.set_flag("explore_scene", id)
	if _scene_title != null:
		_scene_title.text = str(data.get("title", ""))
		_scene_sub.text = str(data.get("subtitle", ""))
	TurnState.set_flag("explore_x", at.x)
	TurnState.set_flag("explore_y", at.y)
	if play_intro:
		_play_intro()

func _play_intro() -> void:
	if not INTROS.has(scene_id):
		return
	var key: String = "intro_" + scene_id
	if TurnState.has_flag(key):
		return
	TurnState.set_flag(key, true)
	var spec: Array = INTROS[scene_id] as Array
	_lock()
	chapter.play_range(str(spec[0]), int(spec[1]), int(spec[2]), func() -> void:
		_unlock()
	)

func _lock() -> void:
	_locked = true

func _unlock() -> void:
	_locked = false

func travel(to: String, spawn_name: String = "") -> void:
	if _locked or to.is_empty() or not scenes.has(to):
		return
	_lock()
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.18)
	await tween.finished
	if bool(data.get("dream", false)) and not bool((scenes[to] as Dictionary).get("dream", false)):
		_return_scene = ""
	_enter(to, spawn_name, true)
	var out: Tween = create_tween()
	out.tween_property(_fade_rect, "color:a", 0.0, 0.24)
	await out.finished
	if not chapter.visible:
		_unlock()

func _process(delta: float) -> void:
	if not _locked and not chapter.visible:
		var motion: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var key_x: float = float(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)))
		var key_y: float = float(int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
		motion += Vector2(key_x, key_y)
		player.step(delta, motion.limit_length(), data)
		_update_camera(false)
		_update_nearby()
	_update_camera_text()

	if _dialog_time > 0.0:
		_dialog_time = maxf(0.0, _dialog_time - delta)
		if _dialog_time <= 0.0:
			_dialog_panel.visible = false

func _update_camera(force: bool) -> void:
	var bounds: Rect2 = data.get("bounds", Rect2(0, 0, 960, 600)) as Rect2
	var vp: Vector2 = Vector2(960, 600)
	var zoom: float = 1.0
	if bounds.size.y < vp.y:
		zoom = vp.y / bounds.size.y
	camera.zoom = Vector2(zoom, zoom)
	var half: Vector2 = vp * 0.5 / zoom
	var target: Vector2 = player.pos
	if bounds.size.x <= half.x * 2.0:
		target.x = bounds.get_center().x
	else:
		target.x = clampf(target.x, bounds.position.x + half.x, bounds.end.x - half.x)
	if bounds.size.y <= half.y * 2.0:
		target.y = bounds.get_center().y
	else:
		target.y = clampf(target.y, bounds.position.y + half.y, bounds.end.y - half.y)
	camera.position = target

func _update_nearby() -> void:
	_nearest_spot = {}
	_nearest_npc = {}
	_nearest_exit = {}
	var best: float = SPOT_RADIUS
	for spot in data.get("spots", []) as Array:
		var s: Dictionary = spot as Dictionary
		var at: Vector2 = s.get("pos", Vector2.ZERO) as Vector2
		var distance: float = player.pos.distance_to(at)
		if distance < best:
			best = distance
			_nearest_spot = s
	var npc_best: float = NPC_RADIUS
	for npc in data.get("npcs", []) as Array:
		var n: Dictionary = npc as Dictionary
		var distance: float = player.pos.distance_to(n.get("pos", Vector2.ZERO) as Vector2)
		if distance < npc_best:
			npc_best = distance
			_nearest_npc = n
	var exit_best: float = EXIT_RADIUS
	for exit in data.get("exits", []) as Array:
		var e: Dictionary = exit as Dictionary
		var distance: float = player.pos.distance_to(e.get("pos", Vector2.ZERO) as Vector2)
		if distance < exit_best:
			exit_best = distance
			_nearest_exit = e

func _update_camera_text() -> void:
	if _nearest_npc.is_empty() and _nearest_spot.is_empty() and _nearest_exit.is_empty():
		_bubble.visible = false
		if _bubble_bg != null:
			_bubble_bg.visible = false
		return
	var caption: String = ""
	if not _nearest_npc.is_empty():
		caption = "E  和「" + str(_nearest_npc.get("name", "")) + "」说话"
	elif not _nearest_spot.is_empty():
		caption = "E  " + str(_nearest_spot.get("label", ""))
	elif not _nearest_exit.is_empty():
		caption = "E  " + str(_nearest_exit.get("label", ""))
	var screen: Vector2 = get_viewport().get_canvas_transform() * player.pos
	_bubble.text = caption
	var caption_width: float = SKIN.font().get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_HUD).x + 26.0
	_bubble.position = Vector2(screen.x - 130.0, screen.y - 172.0)
	_bubble.size = Vector2(260, 24)
	_bubble.visible = true
	_bubble_bg.size = Vector2(caption_width, 24)
	_bubble_bg.position = Vector2(screen.x - caption_width * 0.5, screen.y - 170.0)
	_bubble_bg.visible = true

func nearest_spot() -> Dictionary:
	return _nearest_spot

func nearest_npc() -> Dictionary:
	return _nearest_npc

func is_near_npc(npc: Dictionary) -> bool:
	return not _nearest_npc.is_empty() and _nearest_npc.get("pos", Vector2.ZERO) == npc.get("pos", Vector2.ZERO)

func spot_used(spot: Dictionary) -> bool:
	var key: String = _spot_key(spot)
	return bool(_used.get(key, false)) or TurnState.has_flag("spot_" + key)

func _spot_key(spot: Dictionary) -> String:
	return scene_id + "_" + str(spot.get("label", "")) + "_" + str((spot.get("pos", Vector2.ZERO) as Vector2).x)

func say(text: String) -> void:
	_dialog_label.text = text
	_dialog_panel.visible = true
	_dialog_time = clampf(2.4 + float(text.length()) * 0.09, 3.0, 9.0)

func _interact() -> void:
	if _locked or chapter.visible:
		return
	if not _nearest_npc.is_empty():
		_say_npc(_nearest_npc)
		return
	if not _nearest_spot.is_empty():
		_use_spot(_nearest_spot)
		return
	if not _nearest_exit.is_empty():
		_use_exit(_nearest_exit)

func _say_npc(npc: Dictionary) -> void:
	var person: String = str(npc.get("id", ""))
	if not person.is_empty():
		TurnState.unlock_person(person, true)
	say(str(npc.get("line", "……")))

func _use_spot(spot: Dictionary) -> void:
	var kind: String = str(spot.get("kind", "talk"))
	var arg: String = str(spot.get("arg", ""))
	var key: String = _spot_key(spot)
	_used[key] = true
	match kind:
		"item":
			TurnState.unlock_item(arg)
			var label: String = str(spot.get("label", "记下了"))
			say("记下手记： " + label)
		"talk":
			say(arg)
		"travel":
			travel(arg, "")
		"wake":
			_wake()
		"dream":
			_enter_dream(arg)
		_:
			say(arg)

func _use_exit(exit: Dictionary) -> void:
	if bool(exit.get("wake", false)):
		_wake()
		return
	travel(str(exit.get("to", "")), str(exit.get("spawn", "")))

func _enter_dream(target: String) -> void:
	_return_scene = scene_id
	_return_spawn = ""
	travel(target, "")

func _wake() -> void:
	var back: String = _return_scene if not _return_scene.is_empty() else "house_hall"
	_return_scene = ""
	travel(back, "")

func _turn_dream_off() -> void:
	pass

func _toggle_journal() -> void:
	if Journal == null:
		return
	if JournalUI.is_open():
		JournalUI.close()
	else:
		JournalUI.open()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.physical_keycode == KEY_E:
		_interact()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_I:
		_toggle_journal()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_ESCAPE:
		if JournalUI.is_open():
			JournalUI.close()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_SPACE:
		if _dialog_time > 0.0:
			_dialog_time = 0.0
			_dialog_panel.visible = false
			get_viewport().set_input_as_handled()

# 供测试使用：直接跳场景、直接拿当前场景数据
func force_scene(id: String, spawn_name: String = "") -> void:
	_enter(id, spawn_name, false)
	_unlock()

func current_scene_data() -> Dictionary:
	return data

func scene_ids() -> Array:
	return scenes.keys()
