extends Node2D

# 探索模式主控：场景切换、自由移动、相机、热点交互、剧情播放、HUD。
# 目标：整条镇子 + 老宅室内 + 三个梦 + 狼城，全部可以走进去。

const WorldData = preload("res://world/world_data.gd")
const PlayerState = preload("res://world/player_state.gd")
const SceneView = preload("res://world/scene_view.gd")
const ChapterPlayer = preload("res://ui/chapter_player.gd")
const SKIN = preload("res://ui/theme.gd")
const Journal = preload("res://ui/journal_panel.gd")
const PuzzleState = preload("res://world/puzzle_state.gd")
const AnimFx = preload("res://world/anim_fx.gd")

const FONT_SIZE_HUD: int = 12
const SPOT_RADIUS: float = 76.0
const NPC_RADIUS: float = 84.0
const EXIT_RADIUS: float = 76.0
const SAVE_FILE: String = "user://turn_world.cfg"

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
var _dialog_panel: Panel = null
var _dialog_label: Label = null
var _dialog_speaker: Label = null
var _dialog_hint: Label = null
var _dialog_open: bool = false
var _type_full: String = ""
var _type_progress: float = 0.0
var _hint_band: ColorRect = null
var _hint_label: Label = null
var _toast: Label = null
var _toast_bg: ColorRect = null
var _toast_time: float = 0.0
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _title_card: CanvasLayer = null
var _title_card_bg: ColorRect = null
var _title_card_name: Label = null
var _title_card_sub: Label = null
var _zoom_scale: float = 1.0
var _return_scene: String = ""
var _return_spawn: String = ""
var _nearest_spot: Dictionary = {}
var _nearest_npc: Dictionary = {}
var _nearest_exit: Dictionary = {}
var _used: Dictionary = {}
var _talked: Dictionary = {}
var _talk_count: Dictionary = {}
var puzzle: RefCounted = null
var fx: CanvasLayer = null
var _journal_button: Button = null
var _pickup_busy: bool = false

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

	puzzle = PuzzleState.new()
	fx = AnimFx.new()
	add_child(fx)

	_load_progress()
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

	_dialog_panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.050, 0.060, 0.95)
	sb.border_color = Color(SKIN.GOLD, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	_dialog_panel.add_theme_stylebox_override("panel", sb)
	_dialog_panel.position = Vector2(96, 440)
	_dialog_panel.size = Vector2(768, 108)
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_panel.visible = false
	_hud_root.add_child(_dialog_panel)

	_dialog_speaker = SKIN.make_label("", 12, SKIN.GOLD)
	_dialog_speaker.position = Vector2(116, 452)
	_hud_root.add_child(_dialog_speaker)

	_dialog_label = SKIN.make_label("", 16, SKIN.PAPER, 728.0)
	_dialog_label.position = Vector2(116, 474)
	_dialog_label.size = Vector2(728, 62)
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_root.add_child(_dialog_label)

	_dialog_hint = SKIN.make_label("E  继续", 12, Color(SKIN.GOLD, 1.0))
	_dialog_hint.position = Vector2(786, 516)
	_dialog_hint.size = Vector2(76, 20)
	_dialog_hint.modulate.a = 0.0
	_hud_root.add_child(_dialog_hint)

	_hint_band = ColorRect.new()
	_hint_band.color = Color(0.06, 0.07, 0.08, 0.62)
	_hint_band.position = Vector2(0, 560)
	_hint_band.size = Vector2(960, 40)
	_hint_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_hint_band)
	_hint_label = SKIN.make_label("WASD / 方向键 走动　E 查看与交谈　I 手记　Esc 菜单", 12, Color(SKIN.PAPER, 0.82))
	_hint_label.position = Vector2(24, 572)
	_hud_root.add_child(_hint_label)

	var journal_button: Button = SKIN.make_button("手记  I", 12, 92.0, 28.0)
	journal_button.position = Vector2(760, 14)
	journal_button.pressed.connect(_toggle_journal)
	_hud_root.add_child(journal_button)
	_journal_button = journal_button

	_toast_bg = ColorRect.new()
	_toast_bg.color = Color(0.05, 0.06, 0.07, 0.0)
	_toast_bg.position = Vector2(660, 70)
	_toast_bg.size = Vector2(280, 28)
	_toast_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_toast_bg)

	_toast = SKIN.make_label("", 13, SKIN.GOLD)
	_toast.position = Vector2(674, 76)
	_toast.size = Vector2(260, 20)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_hud_root.add_child(_toast)



	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 320
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

	_build_title_card()


func _build_title_card() -> void:
	_title_card = CanvasLayer.new()
	_title_card.layer = 310
	add_child(_title_card)
	_title_card_bg = ColorRect.new()
	_title_card_bg.color = Color(0.03, 0.035, 0.040, 0.0)
	_title_card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.add_child(_title_card_bg)
	_title_card_name = SKIN.make_label("", 26, SKIN.PAPER)
	_title_card_name.position = Vector2(0, 258)
	_title_card_name.size = Vector2(960, 40)
	_title_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_card_name.modulate.a = 0.0
	_title_card.add_child(_title_card_name)
	_title_card_sub = SKIN.make_label("", 12, SKIN.GOLD_DIM)
	_title_card_sub.position = Vector2(0, 302)
	_title_card_sub.size = Vector2(960, 24)
	_title_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_card_sub.modulate.a = 0.0
	_title_card.add_child(_title_card_sub)

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
	_zoom_scale = 0.94
	_update_camera(true)
	var zoom_tween: Tween = create_tween()
	zoom_tween.tween_method(_set_zoom_scale, 0.94, 1.0, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	TurnState.set_flag("explore_scene", id)
	if _scene_title != null:
		_scene_title.text = str(data.get("title", ""))
		_scene_sub.text = str(data.get("subtitle", ""))
		if bool(data.get("dream", false)):
			_scene_title.add_theme_color_override("font_color", Color("#f2cd93"))
		else:
			_scene_title.add_theme_color_override("font_color", Color(SKIN.PAPER))
		_scene_title.modulate.a = 0.0
		_scene_sub.modulate.a = 0.0
		var head_tween: Tween = create_tween()
		head_tween.set_parallel(true)
		head_tween.tween_property(_scene_title, "modulate:a", 1.0, 0.30)
		head_tween.tween_property(_scene_sub, "modulate:a", 1.0, 0.45)
	TurnState.set_flag("explore_x", at.x)
	TurnState.set_flag("explore_y", at.y)
	_save_progress()
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

func travel(to: String, spawn_name: String = "", anim: String = "wipe") -> void:
	if _locked or to.is_empty() or not scenes.has(to):
		return
	_lock()
	_close_dialog_now()
	if fx == null:
		_enter(to, spawn_name, true)
		if not chapter.visible:
			_unlock()
		return
	if anim == "door":
		var resume: Array = [false]
		fx.play_door_open(func() -> void: resume[0] = true)
		while not bool(resume[0]):
			await get_tree().process_frame
		if bool(data.get("dream", false)) and not bool((scenes[to] as Dictionary).get("dream", false)):
			_return_scene = ""
		_enter(to, spawn_name, true)
		fx.door_reveal(func() -> void: _unlock())
	else:
		var mid: Callable = func() -> void:
			if bool(data.get("dream", false)) and not bool((scenes[to] as Dictionary).get("dream", false)):
				_return_scene = ""
			_enter(to, spawn_name, true)
		var done: Callable = func() -> void: _unlock()
		fx.play_location_wipe(mid, done)

func _close_dialog_now() -> void:
	_dialog_open = false
	_dialog_panel.visible = false
	_dialog_panel.modulate.a = 0.0
	_dialog_hint.modulate.a = 0.0
	_dialog_label.text = ""
	_dialog_speaker.text = ""
	_set_hint_visible(true)

func _process(delta: float) -> void:
	if not _locked and not chapter.visible:
		var motion: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var key_x: float = float(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)))
		var key_y: float = float(int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
		motion += Vector2(key_x, key_y)
		var move_scale: float = 0.55 if _dialog_open else 1.0
		player.step(delta, motion.limit_length() * move_scale, data)
		_update_nearby()
	_update_camera(false)
	_update_camera_text()

	if _dialog_open:
		if _type_progress < float(_type_full.length()):
			_type_progress = minf(float(_type_full.length()), _type_progress + delta * 38.0)
			_dialog_label.visible_characters = int(_type_progress)
		else:
			_dialog_hint.modulate.a = 0.58 + 0.34 * sin(float(Time.get_ticks_msec()) * 0.006)

	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - delta)
		var alpha: float = clampf(_toast_time / 0.45, 0.0, 1.0)
		_toast.modulate.a = alpha
		_toast_bg.color.a = 0.72 * alpha

func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_bg.color.a = 0.72
	_toast_time = 1.7

func _set_zoom_scale(value: float) -> void:
	_zoom_scale = value

func _update_camera(force: bool) -> void:
	var bounds: Rect2 = data.get("bounds", Rect2(0, 0, 960, 600)) as Rect2
	var vp: Vector2 = Vector2(960, 600)
	var zoom: float = 1.0
	if bounds.size.y < vp.y:
		zoom = vp.y / bounds.size.y
	var base: float = zoom * _zoom_scale
	camera.zoom = Vector2(base, base)
	var half: Vector2 = vp * 0.5 / base
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
	_bubble.position = Vector2(screen.x - 130.0, screen.y - 136.0)
	_bubble.size = Vector2(260, 24)
	_bubble.visible = true
	_bubble_bg.size = Vector2(caption_width, 24)
	_bubble_bg.position = Vector2(screen.x - caption_width * 0.5, screen.y - 134.0)
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

func say(text: String, speaker: String = "旁白") -> void:
	_type_full = text
	_type_progress = 0.0
	_dialog_label.text = text
	_dialog_label.visible_characters = 0
	_dialog_speaker.text = speaker
	_dialog_open = true
	_dialog_hint.modulate.a = 0.0
	_dialog_panel.visible = true
	_dialog_panel.modulate.a = 0.0
	_set_hint_visible(false)
	var t: Tween = create_tween()
	t.tween_property(_dialog_panel, "modulate:a", 1.0, 0.14)

func _advance_dialog() -> void:
	if not _dialog_open:
		return
	if _type_progress < float(_type_full.length()):
		_type_progress = float(_type_full.length())
		_dialog_label.visible_characters = -1
		_dialog_hint.modulate.a = 0.0
		return
	_dialog_open = false
	_dialog_hint.modulate.a = 0.0
	_set_hint_visible(true)
	var t: Tween = create_tween()
	t.tween_property(_dialog_panel, "modulate:a", 0.0, 0.12)

func _interact() -> void:
	if _dialog_open:
		_advance_dialog()
		return
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

func _set_hint_visible(value: bool) -> void:
	if _hint_band != null:
		_hint_band.visible = value
	if _hint_label != null:
		_hint_label.visible = value

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _dialog_open:
			_advance_dialog()
			get_viewport().set_input_as_handled()

func _say_npc(npc: Dictionary) -> void:
	var person: String = str(npc.get("id", ""))
	var who: String = str(npc.get("name", "他"))
	var key: String = "npc_" + person
	var count: int = int(_talk_count.get(key, 0))
	_talk_count[key] = count + 1
	if not person.is_empty():
		TurnState.unlock_person(person, true)
		if count == 0:
			toast("认识了一个人 · " + who)

	# 出示物证分支：持有指定物证且尚未出示过，递出后给回复与新物证。
	var present: Dictionary = npc.get("present", {}) as Dictionary
	var present_ev: String = str(present.get("evidence", ""))
	var present_flag: String = "presented_" + person
	if puzzle != null and not present_ev.is_empty() and puzzle.has_evidence(present_ev) and not TurnState.has_flag(present_flag):
		TurnState.set_flag(present_flag, true)
		var grant: String = str(present.get("grants_evidence", ""))
		var granted_name: String = ""
		if not grant.is_empty() and puzzle.add_evidence(grant):
			granted_name = puzzle.evidence_name(grant)
			_play_pickup(npc.get("pos", Vector2.ZERO) as Vector2, granted_name)
			_save_progress()
		say(str(present.get("reply", "……")), who)
		if not granted_name.is_empty():
			toast("出示物证 · 得到 " + granted_name)
		else:
			toast("出示物证 · " + puzzle.evidence_name(present_ev))
		return

	# 物证感知分支：持有 / 未持有指定物证时说不同的话。
	var need: String = str(npc.get("needs_evidence", ""))
	var text: String = str(npc.get("line", "……"))
	if not need.is_empty() and puzzle != null:
		if puzzle.has_evidence(need):
			text = str(npc.get("lines_with_evidence", npc.get("line2", text)))
		else:
			text = str(npc.get("lines_without", text))
	else:
		if count == 1 and npc.has("line2"):
			text = str(npc.get("line2"))
		elif count >= 2 and npc.has("line3"):
			text = str(npc.get("line3"))
		elif count > 0 and npc.has("line2"):
			text = str(npc.get("line2"))
	say(text, who)

func _use_spot(spot: Dictionary) -> void:
	var kind: String = str(spot.get("kind", "talk"))
	var arg: String = str(spot.get("arg", ""))
	var key: String = _spot_key(spot)
	var at: Vector2 = spot.get("pos", Vector2.ZERO) as Vector2
	var label: String = str(spot.get("label", "记下了"))
	var first_time: bool = not bool(_used.get(key, false)) and not TurnState.has_flag("spot_" + key)
	_used[key] = true
	TurnState.set_flag("spot_" + key, true)
	if view != null:
		view.pulse(at, Color(0.98, 0.84, 0.48, 1.0))
	match kind:
		"item":
			var ev: String = str(spot.get("gives_evidence", ""))
			if not ev.is_empty() and puzzle != null:
				if puzzle.has_evidence(ev):
					say("这处已经记过了，换个地方再找找。", "手记")
				elif puzzle.add_evidence(ev):
					TurnState.unlock_item(arg)
					_play_pickup(at, puzzle.evidence_name(ev))
					say(label + "。我把它记进了手记。", "手记")
					toast("手记 +1 · " + puzzle.evidence_name(ev))
				else:
					say("这件东西刚才已经收进手记了。", "手记")
			else:
				if not arg.is_empty() and TurnState.knows_item(arg):
					say("这件已经记在手记里了，这处不再重复记。", "手记")
				else:
					TurnState.unlock_item(arg)
					say(label + "。我把它记在手记里了。", "手记")
					toast("手记 +1 · " + label)
		"combo":
			_use_combo(spot)
		"talk":
			var text: String = arg
			if not first_time and spot.has("arg2"):
				text = str(spot.get("arg2"))
			say(text, "旁白")
		"travel":
			var travel_lock: Dictionary = spot.get("lock", {}) as Dictionary
			_gate_navigate(arg, "", "wipe", travel_lock)
		"wake":
			_wake()
		"dream":
			var dream_lock: Dictionary = spot.get("lock", {}) as Dictionary
			if puzzle != null and not dream_lock.is_empty():
				var dream_state: Dictionary = puzzle.lock_state(dream_lock)
				if not bool(dream_state.get("ok", true)):
					_report_locked(dream_state)
					return
			toast("好像睡着了……")
			_enter_dream(arg)
		_:
			say(arg, "旁白")

func _use_exit(exit: Dictionary) -> void:
	if bool(exit.get("wake", false)):
		_wake()
		return
	var lock: Dictionary = exit.get("lock", {}) as Dictionary
	var anim: String = "door" if str(exit.get("spawn", "")) == "door" else "wipe"
	_gate_navigate(str(exit.get("to", "")), str(exit.get("spawn", "")), anim, lock)

# 统一跳转 gate：出口 / travel 热点 / 梦链全部从这里过锁判定，禁止分支直调 travel。
func _gate_navigate(to: String, spawn_name: String, anim: String, lock: Dictionary) -> void:
	if puzzle != null and not lock.is_empty():
		var state: Dictionary = puzzle.lock_state(lock)
		if not bool(state.get("ok", true)):
			_report_locked(state)
			return
	travel(to, spawn_name, anim)

func _report_locked(state: Dictionary) -> void:
	var missing: Array = state.get("missing", []) as Array
	var names: PackedStringArray = PackedStringArray()
	for mid in missing:
		var m: String = str(mid)
		if PuzzleState.CLUE_NAMES.has(m):
			names.append(puzzle.clue_name(m))
		else:
			names.append(puzzle.evidence_name(m))
	var hint: String = str(state.get("hint", ""))
	var text: String = "门锁着，进不去。还差：" + "、".join(names) + "。"
	if not hint.is_empty():
		text += " " + hint
	say(text, "旁白")
	toast("锁住了 · 缺 " + "、".join(names))

func _use_combo(spot: Dictionary) -> void:
	var combo: Dictionary = spot.get("combo", {}) as Dictionary
	var a: String = str(combo.get("a", ""))
	var b: String = str(combo.get("b", ""))
	var clue: String = str(combo.get("clue", ""))
	if puzzle == null:
		return
	if puzzle.has_clue(clue):
		say("这条推论已经记在手记里了。", "推论")
		return
	var missing: PackedStringArray = PackedStringArray()
	if not puzzle.has_evidence(a):
		missing.append(puzzle.evidence_name(a))
	if not puzzle.has_evidence(b):
		missing.append(puzzle.evidence_name(b))
	if not missing.is_empty():
		say("还差两件物证才能对上：" + "、".join(missing) + "。先在这附近找找。", "旁白")
		toast("组合失败 · 缺 " + "、".join(missing))
		return
	var got: String = puzzle.try_combine(a, b)
	if got.is_empty():
		say("这两件东西对在一起，暂时还看不出名堂。", "旁白")
		return
	_play_pickup(spot.get("pos", Vector2.ZERO) as Vector2, puzzle.clue_name(got))
	say("推论出来了：" + puzzle.clue_name(got) + "。" + puzzle.clue_text(got), "推论")
	toast("新推论 · " + puzzle.clue_name(got))
	_save_progress()

func _play_pickup(at_world: Vector2, text: String) -> void:
	if fx == null or _pickup_busy:
		return
	_pickup_busy = true
	_lock()
	var screen: Vector2 = get_viewport().get_canvas_transform() * at_world
	var done: Callable = func() -> void:
		_pickup_busy = false
		_unlock()
	fx.play_pickup(screen, text, _journal_button, done)

func _enter_dream(target: String) -> void:
	_return_scene = scene_id
	_return_spawn = ""
	if fx == null:
		travel(target, "", "wipe")
		return
	var dream_mid: Callable = func() -> void: _enter(target, "", true)
	var dream_done: Callable = func() -> void:
		if not chapter.visible:
			_unlock()
	fx.play_dream_in(dream_mid, dream_done)
	_lock()

func _flash(color: Color) -> void:
	if _fade_rect == null:
		return
	_fade_rect.color = Color(color.r, color.g, color.b, 0.0)
	var t: Tween = create_tween()
	t.tween_property(_fade_rect, "color:a", 0.55, 0.12)
	t.tween_property(_fade_rect, "color:a", 0.0, 0.32)

func _wake() -> void:
	var back: String = _return_scene if not _return_scene.is_empty() else "house_hall"
	_return_scene = ""
	toast("醒了 · 回到刚才的地方")
	if fx == null:
		travel(back, "", "wipe")
		return
	_lock()
	_close_dialog_now()
	var mid: Callable = func() -> void: _enter(back, "", true)
	var done: Callable = func() -> void:
		if not chapter.visible:
			_unlock()
	fx.play_wake_out(mid, done)

func _turn_dream_off() -> void:
	pass

func _toggle_journal() -> void:
	if Journal == null:
		return
	if _locked or _dialog_open:
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
		if _dialog_open:
			_advance_dialog()
			get_viewport().set_input_as_handled()

# 供测试使用：直接跳场景、直接拿当前场景数据
func force_scene(id: String, spawn_name: String = "") -> void:
	_enter(id, spawn_name, false)
	_unlock()

func current_scene_data() -> Dictionary:
	return data

func scene_ids() -> Array:
	return scenes.keys()

# ---- 进度落盘（R031）：TurnState 快照写入 user://，启动时读回；旧档缺键不报错。
func _save_progress() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("world", "v3_state", TurnState.snapshot())
	var result: int = file.save(SAVE_FILE)
	if result != OK:
		push_warning("世界进度保存失败：" + error_string(result))

func _load_progress() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(SAVE_FILE) != OK:
		return
	var raw: String = str(file.get_value("world", "v3_state", ""))
	TurnState.restore_snapshot(raw)
