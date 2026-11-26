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
const Data = preload("res://scripts/turn_data.gd")
const EvidencePanel = preload("res://ui/evidence_panel.gd")

const FONT_SIZE_HUD: int = 12
const SPOT_RADIUS: float = 76.0
const NPC_RADIUS: float = 84.0
const EXIT_RADIUS: float = 76.0
const SAVE_FILE: String = "user://turn_world.cfg"
# 相机跟随：基础推近倍率（人物在屏幕上更大，且留出平移余量）、朝向预看偏移、对话时下沉让位。
const FOLLOW_ZOOM: float = 1.35
const CAM_LEAD: float = 20.0
const DIALOG_DOLLY: float = 24.0

# 出示面板卡 id -> 世界层物证 id：A2 正确卡走完后，走原 present 奖励链。
const PANEL_CARD_TO_EVIDENCE: Dictionary = {
	"e_shoes": "ev_shoes",
	"e_screw": "ev_screw",
}

# 场景所属幕：进场景时按幕切换提示层（R078）。
const ACT_BY_SCENE: Dictionary = {
	"langcheng_room": "prologue",
	"langcheng_office": "prologue",
	"langcheng_factory": "A3",
	"town_gate": "prologue",
	"town_road": "A1",
	"old_house_yard": "A1",
	"house_hall": "A1",
	"basement": "A1",
	"playground_day": "A2",
	"playground_night": "A2",
	"street_cross": "A3",
	"town_final": "ending",
	"dream_classroom": "A1",
	"dream_alley": "A1",
	"dream_postbox": "A1",
	"dream_box": "A1",
	"dream_swing": "A2",
	"dream_dirt_road": "A3",
	"dream_station": "A3",
}

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
var _last_load_ok: bool = false
var _save_existed: bool = false
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
var _primary: Dictionary = {}
var _primary_kind: String = ""
var _secondary_label: String = ""
var _used: Dictionary = {}
var _talked: Dictionary = {}
var _talk_count: Dictionary = {}
var puzzle: RefCounted = null
var fx: CanvasLayer = null
var _journal_button: Button = null
var _pickup_busy: bool = false
var _target_label: Label = null
var _bubble_w_cache: Dictionary = {}
var _footstep: AudioStreamPlayer = null
var _last_step_frame: int = -1
var _cam_pos: Vector2 = Vector2.ZERO
var _present_layer: CanvasLayer = null
var _present_panel: Panel = null
var _present_list: Control = null
var _present_npc: Dictionary = {}
var _present_wrong_count: Dictionary = {}
var _refusal_count: Dictionary = {}
var _evidence_panel: CanvasLayer = null
var _sfx: Dictionary = {}
var _ending_layer: CanvasLayer = null
var _ending_title: Label = null
var _ending_body: Label = null
var _ending_summary: Label = null
var _ending_missing: Label = null

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

	_footstep = AudioStreamPlayer.new()
	_footstep.stream = load("res://audio/prologue/mud.wav")
	_footstep.volume_db = -20.0
	add_child(_footstep)

	_load_progress()
	var start_id: String = str(TurnState.get_flag("explore_scene", "langcheng_room"))
	if not scenes.has(start_id):
		start_id = "langcheng_room"
	var start_spawn: String = str(TurnState.get_flag("explore_spawn", ""))
	_enter(start_id, start_spawn, false)
	# R128：继续上次回到退出时的实时坐标与朝向（可行走区内才恢复，否则落出生点）。
	_restore_position()
	# 坏档不静默：加载前已存在的存档读不回来时，开局给一次可见中文提示（R104）。
	if FileAccess.file_exists(SAVE_FILE) and not _last_load_ok and _save_existed:
		toast("存档读取出错，已从开头继续。")

func _restore_position() -> void:
	var saved_x: float = float(TurnState.get_flag("explore_x", -1.0))
	var saved_y: float = float(TurnState.get_flag("explore_y", -1.0))
	if saved_x < 0.0 or saved_y < 0.0:
		return
	var probe: PlayerState = PlayerState.new()
	probe.height = player.height
	if probe.can_stand(Vector2(saved_x, saved_y), data):
		player.pos = Vector2(saved_x, saved_y)
		player.dir = clampi(int(TurnState.get_flag("explore_dir", 1)), 0, 3)

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
	_dialog_panel.position = Vector2(96, 392)
	_dialog_panel.size = Vector2(768, 96)
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_panel.visible = false
	_hud_root.add_child(_dialog_panel)

	_dialog_speaker = SKIN.make_label("", 12, SKIN.GOLD)
	_dialog_speaker.position = Vector2(116, 402)
	_hud_root.add_child(_dialog_speaker)

	_dialog_label = SKIN.make_label("", 16, SKIN.PAPER, 728.0)
	_dialog_label.position = Vector2(116, 420)
	_dialog_label.size = Vector2(728, 52)
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_root.add_child(_dialog_label)

	_dialog_hint = SKIN.make_label("E  继续", 12, Color(SKIN.GOLD, 1.0))
	_dialog_hint.position = Vector2(786, 452)
	_dialog_hint.size = Vector2(76, 20)
	_dialog_hint.modulate.a = 0.0
	_hud_root.add_child(_dialog_hint)

	_hint_band = ColorRect.new()
	_hint_band.color = Color(0.06, 0.07, 0.08, 0.62)
	_hint_band.position = Vector2(0, 514)
	_hint_band.size = Vector2(960, 26)
	_hint_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_hint_band)
	_hint_label = SKIN.make_label("WASD / 方向键 走动　E 查看与交谈　I 手记　Esc 关闭", 12, Color(SKIN.PAPER, 0.82))
	_hint_label.position = Vector2(24, 517)
	_hud_root.add_child(_hint_label)

	_target_label = SKIN.make_label("", 12, SKIN.GOLD, 320.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_target_label.position = Vector2(616, 517)
	_hud_root.add_child(_target_label)

	# 气泡改作底栏交互提示，必须压在提示带之上（否则被半透明底色蒙暗）。
	_hud_root.move_child(_bubble, _target_label.get_index() + 1)

	var journal_button: Button = SKIN.make_button("手记  I", 12, 92.0, 28.0)
	journal_button.position = Vector2(760, 14)
	journal_button.pressed.connect(_toggle_journal)
	_hud_root.add_child(journal_button)
	_journal_button = journal_button

	_toast_bg = ColorRect.new()
	_toast_bg.color = Color(0.05, 0.06, 0.07, 0.0)
	_toast_bg.position = Vector2(620, 66)
	_toast_bg.size = Vector2(320, 38)
	_toast_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_toast_bg)

	_toast = SKIN.make_label("", 13, SKIN.GOLD, 296.0, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.position = Vector2(632, 72)
	_toast.size = Vector2(296, 28)
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
	var char_scale: float = float(data.get("char_scale", WorldData.CHAR_SCALE))
	player.height = float(data.get("player_height", 84.0)) * char_scale
	view.setup(data, player, self)
	_zoom_scale = 0.94
	_update_camera(true)
	var zoom_tween: Tween = create_tween()
	zoom_tween.tween_method(_set_zoom_scale, 0.94, 1.0, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	TurnState.set_flag("explore_scene", id)
	var act: String = str(ACT_BY_SCENE.get(id, ""))
	if not act.is_empty() and TurnState.current_act != act:
		TurnState.start_act(act)
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
	TurnState.set_flag("explore_spawn", spawn_name)
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
	# R162：由出口进入梦境（不走 _enter_dream）时也记下来源，醒转回到来源而非兜底堂屋。
	var entering_dream: bool = bool((scenes[to] as Dictionary).get("dream", false))
	if entering_dream and not bool(data.get("dream", false)):
		_return_scene = scene_id
		_return_spawn = ""
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
	if not _locked and not chapter.visible and not _present_layer_open():
		var motion: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var key_x: float = float(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)))
		var key_y: float = float(int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
		motion += Vector2(key_x, key_y)
		var move_scale: float = 0.75 if _dialog_open else 1.0
		player.step(delta, motion.limit_length() * move_scale, data)
		_update_nearby()
		_update_footstep()
	_update_camera(false)
	_update_camera_text()
	_update_target_label()

	if _dialog_open:
		if _type_progress < float(_type_full.length()):
			var speed: float = 38.0 * (1.2 if _type_fast_held() else 1.0)
			_type_progress = minf(float(_type_full.length()), _type_progress + delta * speed)
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
	_toast_time = 2.2

func _set_zoom_scale(value: float) -> void:
	_zoom_scale = value

func _update_camera(force: bool) -> void:
	var bounds: Rect2 = data.get("bounds", Rect2(0, 0, 960, 600)) as Rect2
	var vp: Vector2 = Vector2(960, 600)
	var fit: float = 1.0
	if bounds.size.y < vp.y:
		fit = vp.y / bounds.size.y
	# R202：固定 1.0 倍率时，960×600 场景铺满屏，相机无处可移，看起来"画面是固定的"。
	# 现在至少推近 FOLLOW_ZOOM，画面随人平移，人物在屏幕上也更大。
	var base: float = maxf(fit, FOLLOW_ZOOM) * _zoom_scale
	camera.zoom = Vector2(base, base)
	var half: Vector2 = vp * 0.5 / base
	var target: Vector2 = player.pos
	# 朝向预看：镜头往人物面向的方向多留一点，走动时视野先到。
	var lead: Vector2 = Vector2.ZERO
	match int(player.dir):
		0:
			lead = Vector2(0, -CAM_LEAD)
		1:
			lead = Vector2(0, CAM_LEAD)
		2:
			lead = Vector2(CAM_LEAD, 0)
		3:
			lead = Vector2(-CAM_LEAD, 0)
		4:
			lead = Vector2(CAM_LEAD, -CAM_LEAD) * 0.7
		5:
			lead = Vector2(-CAM_LEAD, -CAM_LEAD) * 0.7
		6:
			lead = Vector2(CAM_LEAD, CAM_LEAD) * 0.7
		7:
			lead = Vector2(-CAM_LEAD, CAM_LEAD) * 0.7
	target += lead
	# 对话时镜头稍微下沉，人物从对话框上沿露出来，而不是被压在字下面。
	if _dialog_open:
		target.y += DIALOG_DOLLY
	if bounds.size.x <= half.x * 2.0:
		target.x = bounds.get_center().x
	else:
		target.x = clampf(target.x, bounds.position.x + half.x, bounds.end.x - half.x)
	if bounds.size.y <= half.y * 2.0:
		target.y = bounds.get_center().y
	else:
		target.y = clampf(target.y, bounds.position.y + half.y, bounds.end.y - half.y)
	if force:
		_cam_pos = target
	else:
		var damp: float = clampf(8.0 * get_process_delta_time(), 0.0, 1.0)
		_cam_pos = _cam_pos.lerp(target, damp)
	camera.position = _cam_pos

func _update_nearby() -> void:
	_nearest_spot = {}
	_nearest_npc = {}
	_nearest_exit = {}
	_primary = {}
	_primary_kind = ""
	_secondary_label = ""
	var candidates: Array = []
	for spot in data.get("spots", []) as Array:
		var s: Dictionary = spot as Dictionary
		var distance: float = player.pos.distance_to(s.get("pos", Vector2.ZERO) as Vector2)
		if distance <= SPOT_RADIUS:
			candidates.append({"kind": "spot", "data": s, "dist": distance})
	for npc in data.get("npcs", []) as Array:
		var n: Dictionary = npc as Dictionary
		var distance: float = player.pos.distance_to(n.get("pos", Vector2.ZERO) as Vector2)
		if distance <= NPC_RADIUS:
			candidates.append({"kind": "npc", "data": n, "dist": distance})
	for exit in data.get("exits", []) as Array:
		var e: Dictionary = exit as Dictionary
		var distance: float = player.pos.distance_to(e.get("pos", Vector2.ZERO) as Vector2)
		if distance <= EXIT_RADIUS:
			candidates.append({"kind": "exit", "data": e, "dist": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("dist", 9999.0)) < float(b.get("dist", 9999.0)))
	if candidates.is_empty():
		return
	var first: Dictionary = candidates[0]
	_primary = first.get("data", {}) as Dictionary
	_primary_kind = str(first.get("kind", ""))
	match _primary_kind:
		"spot":
			_nearest_spot = _primary
		"npc":
			_nearest_npc = _primary
		"exit":
			_nearest_exit = _primary
	for i in range(1, candidates.size()):
		var other: Dictionary = candidates[i] as Dictionary
		if str(other.get("kind", "")) != _primary_kind:
			_secondary_label = _candidate_label(other)
			break

func _candidate_label(candidate: Dictionary) -> String:
	var kind: String = str(candidate.get("kind", ""))
	var entry: Dictionary = candidate.get("data", {}) as Dictionary
	match kind:
		"npc":
			return str(entry.get("name", ""))
		"spot":
			return str(entry.get("label", ""))
		"exit":
			return str(entry.get("label", ""))
	return ""

func _update_camera_text() -> void:
	if _dialog_open or _present_layer_open() or chapter.visible:
		_bubble.visible = false
		if _bubble_bg != null:
			_bubble_bg.visible = false
		return
	if _nearest_npc.is_empty() and _nearest_spot.is_empty() and _nearest_exit.is_empty():
		_bubble.visible = false
		if _bubble_bg != null:
			_bubble_bg.visible = false
		if _hint_label != null and _hint_band != null and _hint_band.visible:
			_hint_label.visible = true
		return
	var caption: String = ""
	match _primary_kind:
		"npc":
			caption = "E  和「" + str(_primary.get("name", "")) + "」说话"
		"spot":
			caption = "E  " + str(_primary.get("label", ""))
		"exit":
			caption = "E  " + str(_primary.get("label", ""))
	if not _secondary_label.is_empty():
		caption += "　·　旁边还有「" + _secondary_label + "」"
	# R202：交互提示不再飘在人物头顶，而是接管底部提示带。
	# 推近镜头后，世界气泡会压住角色与热点标签；固定提示带永远不吃画面。
	_bubble.text = caption
	_bubble.position = Vector2(24.0, 517.0)
	_bubble.size = Vector2(580.0, 22.0)
	_bubble.add_theme_color_override("font_color", SKIN.GOLD.lightened(0.22))
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bubble.visible = true
	if _bubble_bg != null:
		_bubble_bg.visible = false
	if _hint_label != null:
		_hint_label.visible = false

# 按住 Shift / 空格：打字机 1.2 倍快进（R053）。
func _type_fast_held() -> bool:
	return Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SPACE)

# 上手引导：还没拿到第一件物证时，常显当前目标热点与 HUD 提示（R054）。
func guidance_active() -> bool:
	return puzzle != null and puzzle.all_evidence().is_empty()

func current_target_spot() -> Dictionary:
	if not guidance_active():
		return {}
	for spot in data.get("spots", []) as Array:
		var s: Dictionary = spot as Dictionary
		if str(s.get("kind", "")) == "item" and not str(s.get("gives_evidence", "")).is_empty():
			return s
	return {}

func _update_target_label() -> void:
	if _target_label == null:
		return
	var target: Dictionary = current_target_spot()
	if target.is_empty():
		_target_label.text = ""
		return
	_target_label.text = "目标：" + str(target.get("label", ""))

func _update_footstep() -> void:
	if _footstep == null or player == null:
		return
	if not player.walking:
		_last_step_frame = -1
		return
	var frame: int = player.frame()
	if frame == _last_step_frame:
		return
	_last_step_frame = frame
	if _footstep.stream != null:
		_footstep.play()

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
	_dialog_hint.text = "E / 空格 继续"
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
		_dialog_hint.text = "E / 空格 继续"
		_dialog_hint.modulate.a = 0.58
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
	if _locked or chapter.visible or _present_layer_open():
		return
	match _primary_kind:
		"npc":
			_say_npc(_primary)
		"spot":
			_use_spot(_primary)
		"exit":
			_use_exit(_primary)

func _set_hint_visible(value: bool) -> void:
	if _hint_band != null:
		_hint_band.visible = value
	if _hint_label != null:
		_hint_label.visible = value

func _present_layer_open() -> bool:
	if _present_layer != null and _present_layer.visible:
		return true
	return _evidence_panel != null and _evidence_panel.visible

func _open_evidence_panel(npc: Dictionary, act: String) -> void:
	if _evidence_panel == null:
		_evidence_panel = EvidencePanel.new()
		add_child(_evidence_panel)
	_evidence_panel.open(act, _on_evidence_result.bind(npc))

func _on_evidence_result(stance: String, item_id: String, npc: Dictionary) -> void:
	var person: String = str(npc.get("id", ""))
	var present: Dictionary = npc.get("present", {}) as Dictionary
	var grant: String = str(present.get("grants_evidence", ""))
	if not grant.is_empty():
		var card_ev: String = str(PANEL_CARD_TO_EVIDENCE.get(item_id, ""))
		if card_ev == str(present.get("evidence", "")) and puzzle.add_evidence(grant):
			_play_pickup(npc.get("pos", Vector2.ZERO) as Vector2, puzzle.evidence_name(grant))
			toast("出示物证 · 得到 " + puzzle.evidence_name(grant))
	_save_position()
	if not person.is_empty():
		TurnState.set_flag("presented_" + person, true)
		TurnState.unlock_person(person, true)
	_save_position()

# ---- R159 结局结算页：列出收集度与缺失项，给回标题 / 继续逛逛入口。
func _build_ending_panel() -> void:
	_ending_layer = CanvasLayer.new()
	_ending_layer.layer = 130
	add_child(_ending_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.06, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ending_layer.add_child(dim)
	var board: ColorRect = ColorRect.new()
	board.color = Color("#243036")
	board.position = Vector2(120, 70)
	board.size = Vector2(720, 460)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_layer.add_child(board)

	_ending_title = SKIN.make_label("", 24, SKIN.GOLD, 660.0, HORIZONTAL_ALIGNMENT_CENTER)
	_ending_title.position = Vector2(150, 96)
	_ending_layer.add_child(_ending_title)

	_ending_body = SKIN.make_label("", 15, SKIN.PAPER, 660.0)
	_ending_body.position = Vector2(150, 150)
	_ending_body.size = Vector2(660, 120)
	_ending_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_layer.add_child(_ending_body)

	_ending_summary = SKIN.make_label("", 13, SKIN.PAPER_DIM, 660.0)
	_ending_summary.position = Vector2(150, 290)
	_ending_layer.add_child(_ending_summary)

	_ending_missing = SKIN.make_label("", 12, Color(SKIN.GOLD, 0.9), 660.0)
	_ending_missing.position = Vector2(150, 330)
	_ending_missing.size = Vector2(660, 90)
	_ending_missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_layer.add_child(_ending_missing)

	var title_btn: Button = SKIN.make_button("回标题", 15, 220.0, 40.0)
	title_btn.position = Vector2(250, 456)
	title_btn.pressed.connect(_ending_to_title)
	_ending_layer.add_child(title_btn)
	var roam_btn: Button = SKIN.make_button("继续逛逛", 15, 220.0, 40.0)
	roam_btn.position = Vector2(490, 456)
	roam_btn.pressed.connect(_close_ending_panel)
	_ending_layer.add_child(roam_btn)

func _open_ending_panel(tier: String) -> void:
	if _ending_layer == null:
		_build_ending_panel()
	var ending: Dictionary = Data.ending(tier)
	_ending_title.text = str(ending.get("title", ""))
	_ending_body.text = str(ending.get("body", ""))
	var held_ev: Array[String] = puzzle.all_evidence()
	var held_cl: Array[String] = puzzle.all_clues()
	_ending_summary.text = "已解开 推论 %d/%d · 物证 %d/%d" % [held_cl.size(), PuzzleState.CLUE_NAMES.size(), held_ev.size(), PuzzleState.EVIDENCE_NAMES.size()]
	var missing_ev: Array[String] = []
	for eid in PuzzleState.EVIDENCE_NAMES.keys():
		if not held_ev.has(str(eid)):
			missing_ev.append(puzzle.evidence_name(str(eid)))
	var missing_cl: Array[String] = []
	for cid in PuzzleState.CLUE_NAMES.keys():
		if not held_cl.has(str(cid)):
			missing_cl.append(puzzle.clue_name(str(cid)))
	var missing_text: String = ""
	if missing_ev.is_empty() and missing_cl.is_empty():
		missing_text = "这一趟能带上的，都带上了。"
	else:
		missing_text = "还没记下："
		if not missing_cl.is_empty():
			missing_text += "推论「" + "、".join(missing_cl) + "」"
		if not missing_ev.is_empty():
			if not missing_cl.is_empty():
				missing_text += "；"
			missing_text += "物证「" + "、".join(missing_ev) + "」"
		missing_text += "（回镇上还能再找）"
	_ending_missing.text = missing_text
	_locked = true
	_ending_layer.visible = true

func _close_ending_panel() -> void:
	if _ending_layer != null:
		_ending_layer.visible = false
	_unlock()

func _ending_to_title() -> void:
	_save_position()
	get_tree().change_scene_to_file("res://title/title.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _dialog_open:
			_advance_dialog()
			get_viewport().set_input_as_handled()
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _present_layer_open():
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

	# 出示物证分支：尚未出示过，且手里有物证 → 进入选择层让玩家挑；空手走交谈台词。
	var present_act: String = str(npc.get("present_act", ""))
	if not present_act.is_empty() and not TurnState.has_flag("presented_" + person):
		_open_evidence_panel(npc, present_act)
		return
	var present: Dictionary = npc.get("present", {}) as Dictionary
	var present_ev: String = str(present.get("evidence", ""))
	var present_flag: String = "presented_" + person
	if not present_ev.is_empty() and not TurnState.has_flag(present_flag):
		if puzzle != null and not puzzle.all_evidence().is_empty():
			_open_present_layer(npc)
			return
	_say_npc_plain(npc)

func _say_npc_plain(npc: Dictionary) -> void:
	var person: String = str(npc.get("id", ""))
	var who: String = str(npc.get("name", "他"))
	var count: int = int(_talk_count.get("npc_" + person, 0))
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

# 出示选择层：列出当前持有物证，挑错给拒绝台词，物证不消耗（R077/R088）。
func _build_present_layer() -> void:
	_present_layer = CanvasLayer.new()
	_present_layer.layer = 120
	add_child(_present_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.06, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_present_layer.add_child(dim)
	_present_panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.97)
	sb.border_color = Color(SKIN.GOLD, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	_present_panel.add_theme_stylebox_override("panel", sb)
	_present_panel.position = Vector2(270, 150)
	_present_panel.size = Vector2(420, 300)
	_present_layer.add_child(_present_panel)
	var title: Label = SKIN.make_label("", 15, SKIN.GOLD)
	title.position = Vector2(24, 18)
	_present_panel.add_child(title)
	title.name = "PresentTitle"
	_present_list = Control.new()
	_present_list.position = Vector2(24, 56)
	_present_list.size = Vector2(372, 180)
	_present_panel.add_child(_present_list)
	var chat_btn: Button = SKIN.make_button("先聊两句", 12, 160.0, 28.0)
	chat_btn.position = Vector2(24, 252)
	chat_btn.pressed.connect(_present_pick.bind(""))
	_present_panel.add_child(chat_btn)
	_present_layer.visible = false

func _open_present_layer(npc: Dictionary) -> void:
	if _present_layer == null:
		_build_present_layer()
	_present_npc = npc
	var who: String = str(npc.get("name", "他"))
	var title: Label = _present_panel.get_node("PresentTitle") as Label
	title.text = "出示物证给「" + who + "」"
	for child in _present_list.get_children():
		_present_list.remove_child(child)
		child.queue_free()
	var held: Array[String] = puzzle.all_evidence()
	var row: int = 0
	for ev in held:
		var btn: Button = SKIN.make_button(puzzle.evidence_name(ev), 12, 180.0, 30.0)
		btn.position = Vector2((row % 2) * 188, (row / 2) * 36)
		btn.pressed.connect(_present_pick.bind(ev))
		_present_list.add_child(btn)
		row += 1
	_present_layer.visible = true

func _close_present_layer() -> void:
	if _present_layer != null:
		_present_layer.visible = false

func _present_pick(ev: String) -> void:
	if _present_npc.is_empty():
		return
	var present: Dictionary = _present_npc.get("present", {}) as Dictionary
	var person: String = str(_present_npc.get("id", ""))
	var who: String = str(_present_npc.get("name", "他"))
	var target: String = str(present.get("evidence", ""))
	if ev.is_empty():
		_close_present_layer()
		_say_npc_plain(_present_npc)
		return
	if ev == target:
		TurnState.set_flag("presented_" + person, true)
		var grant: String = str(present.get("grants_evidence", ""))
		var granted_name: String = ""
		if not grant.is_empty() and puzzle.add_evidence(grant):
			granted_name = puzzle.evidence_name(grant)
			_play_pickup(_present_npc.get("pos", Vector2.ZERO) as Vector2, granted_name)
			_save_position()
		_play_sfx("present_ok", "res://audio/prologue/page.wav")
		_close_present_layer()
		say(str(present.get("reply", "……")), who)
		if not granted_name.is_empty():
			toast("出示物证 · 得到 " + granted_name)
		else:
			toast("出示物证 · " + puzzle.evidence_name(target))
		return
	# 错配：两件物证仍在手里，只给拒绝台词；错配台词按次数轮换。
	var lines: Array = present.get("wrong_lines", [])
	var used: int = int(_present_wrong_count.get(person, 0))
	_present_wrong_count[person] = used + 1
	var line: String = str(lines[used % lines.size()]) if not lines.is_empty() else "他看看这件东西，摇了摇头，像是不认识。"
	_close_present_layer()
	_play_sfx("present_wrong", "res://audio/prologue/tick.wav")
	say(line, who)

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
					TurnState.note_progress()
					_play_pickup(at, puzzle.evidence_name(ev))
					_save_position()
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
		"ending_review":
			var tier: String = TurnState.ending_tier
			if tier.is_empty():
				tier = TurnState.settle_collection_tier(puzzle.all_evidence().size(), puzzle.all_clues().size())
			_open_ending_panel(tier)
		"examine":
			var ex_lock: Dictionary = spot.get("lock", {}) as Dictionary
			if puzzle != null and not ex_lock.is_empty():
				var ex_state: Dictionary = puzzle.lock_state(ex_lock)
				if not bool(ex_state.get("ok", true)):
					_report_locked(ex_state, "examine")
					return
			var ex_text: String = arg
			if not first_time and spot.has("arg2"):
				ex_text = str(spot.get("arg2"))
			say(ex_text, "旁白")
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
					_report_locked(dream_state, "dream")
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
			_report_locked(state, "exit")
			return
	travel(to, spawn_name, anim)

func _report_locked(state: Dictionary, context: String = "exit") -> void:
	var missing: Array = state.get("missing", []) as Array
	var names: PackedStringArray = PackedStringArray()
	for mid in missing:
		var m: String = str(mid)
		if PuzzleState.CLUE_NAMES.has(m):
			names.append(puzzle.clue_name(m))
		else:
			names.append(puzzle.evidence_name(m))
	var hint: String = str(state.get("hint", ""))
	var prefix: String = "这件东西现在看不出名堂，还差：" if context == "examine" else "门锁着，进不去。还差："
	var sig: String = context + ":" + ",".join(names)
	var count: int = int(_refusal_count.get(sig, 0))
	_refusal_count[sig] = count + 1
	var text: String = prefix + "、".join(names) + "。"
	if not hint.is_empty():
		text += " " + hint
	if count == 1:
		text += " 先去别处找找。"
	elif count >= 2:
		text += " 再想想还差什么，别硬闯。"
	say(text, "旁白")
	toast("锁住了 · 缺 " + "、".join(names))
	_play_sfx("locked", "res://audio/prologue/tick.wav")

# 组合一律走手记推理台：热点只给指向，不再自动判定（R076）。
func _use_combo(spot: Dictionary) -> void:
	var combo: Dictionary = spot.get("combo", {}) as Dictionary
	var clue: String = str(combo.get("clue", ""))
	if puzzle == null:
		say("这里两样东西或许能对上，但现在手记还打不开。", "旁白")
		return
	if puzzle.has_clue(clue):
		say("这条推论已经记在手记里了。", "推论")
		return
	say(str(spot.get("arg", "")) + "（按 I 打开手记推理台，把这两件物证放进槽里对上。）", "旁白")

func _play_pickup(at_world: Vector2, text: String) -> void:
	if fx == null or _pickup_busy:
		return
	_pickup_busy = true
	_lock()
	_play_sfx("pickup", "res://audio/prologue/latch.wav")
	var screen: Vector2 = get_viewport().get_canvas_transform() * at_world
	var done: Callable = func() -> void:
		_pickup_busy = false
		_unlock()
	fx.play_pickup(screen, text, _journal_button, done)

func _enter_dream(target: String) -> void:
	_return_scene = scene_id
	_return_spawn = ""
	_play_sfx("dream", "res://audio/prologue/hinge.wav")
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
	_play_sfx("wake", "res://audio/prologue/hinge.wav")
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
	if _locked or _dialog_open or _present_layer_open():
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
		if _dialog_open:
			_advance_dialog()
		elif _present_layer_open():
			_close_present_layer()
		elif JournalUI.is_open():
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

func _play_sfx(key: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var player: AudioStreamPlayer
	if _sfx.has(key):
		player = _sfx[key] as AudioStreamPlayer
	else:
		player = AudioStreamPlayer.new()
		player.volume_db = -16.0
		add_child(player)
		_sfx[key] = player
	player.stream = load(path)
	player.play()

# ---- 进度落盘（R031）：TurnState 快照写入 user://，启动时读回；旧档缺键不报错。
func _save_progress() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("world", "v3_state", TurnState.snapshot())
	var result: int = file.save(SAVE_FILE)
	if result != OK:
		push_warning("世界进度保存失败：" + error_string(result))

# R128：把玩家实时坐标与朝向一并写入快照，继续上次时原地恢复。
func _save_position() -> void:
	TurnState.set_flag("explore_x", player.pos.x)
	TurnState.set_flag("explore_y", player.pos.y)
	TurnState.set_flag("explore_dir", player.dir)
	_save_progress()

func _load_progress() -> bool:
	var file: ConfigFile = ConfigFile.new()
	_save_existed = FileAccess.file_exists(SAVE_FILE)
	if file.load(SAVE_FILE) != OK:
		_last_load_ok = false
		return false
	var raw: String = str(file.get_value("world", "v3_state", ""))
	if raw.is_empty():
		_last_load_ok = false
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		_last_load_ok = false
		return false
	_last_load_ok = TurnState.restore_snapshot(raw)
	return _last_load_ok

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)
