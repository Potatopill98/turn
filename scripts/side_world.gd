extends Node2D

const SceneDefs = preload("res://data/scene_defs.gd")
const SidePlayer = preload("res://scripts/side_player.gd")
const SideBackdrop = preload("res://scripts/side_backdrop.gd")
const SideGround = preload("res://scripts/side_ground.gd")
const SideProp = preload("res://scripts/side_prop.gd")
const SideActor = preload("res://scripts/side_actor.gd")
const SideDoor = preload("res://scripts/side_door.gd")
const SideUI = preload("res://scripts/side_ui.gd")

const TurnObject = preload("res://scripts/turn_object.gd")

const DREAM_INTRO: Array = [
	"录音里的脚步还没停。你脚下已经变成了走廊。",
]
const DREAM_END: Array = [
	"你听见报时声，却不知道现在是几点。",
	"钟面没有指针。你醒过来时，老宅的天花板就在头顶，中间有一道很细的裂纹。",
]
const FINAL_LINES: Array = [
	"十一假期的最后一天，你把东西收拾好了。",
	"车还没来。小满夹住的那叠谱子里，少了第三页。",
	"临走那天晚上，你站在镇口。兜里那块旧手表，凉凉地硌着你。",
	"表针还在走。一下，一下，慢吞吞的。",
]
const CHORE_LABELS: Dictionary = {
	"xiaoman_score": "帮她夹好散谱",
	"zhou_swing": "扶住秋千",
	"tang_box": "帮她把最后一箱挪上车",
}

var scene_id: String = "station"
var scene_data: Dictionary = {}
var scene_width: float = 1600.0
var floor_y: float = 456.0
var stage: Node2D
var sky: Control
var sky_layer: CanvasLayer
var player: CharacterBody2D
var camera: Camera2D
var ui: Control
var ui_layer: CanvasLayer
var backdrops: Array[Node2D] = []
var ground_node: Node2D
var props: Array[Node2D] = []
var actors: Array[Node2D] = []
var doors: Array[Node2D] = []
var active_target: Node = null
var active_kind: String = ""
var active_npc: Dictionary = {}
var active_chore: Dictionary = {}
var chore_stage: int = 0
var creak_timer := 0.0
var present_npc: Dictionary = {}
var reopen_npc: Dictionary = {}
var pending_refresh: bool = false
var pending_dream_return: bool = false
var final_choice_mode: bool = false
var object_view := TurnObject.new()
var hint_time := 0.0
var asked_topics: Dictionary = {}
var started: bool = false
var fade_busy: bool = false
var dream_active: bool = false
var dream_wake: bool = false
var player_x: float = 0.0
var last_scene_id: String = ""
var chapter_pending: bool = false


func _ready() -> void:
	GameState.reset()
	sky_layer = CanvasLayer.new()
	sky_layer.layer = -5
	add_child(sky_layer)
	sky = Control.new()
	sky.set_script(preload("res://scripts/side_sky.gd"))
	sky.size = Vector2(960.0, 540.0)
	sky_layer.add_child(sky)

	stage = Node2D.new()
	stage.z_index = 0
	add_child(stage)

	player = SidePlayer.new()
	player.z_index = 5
	add_child(player)
	player.call("setup", 456.0, 28.0, 1572.0)

	camera = Camera2D.new()
	camera.position = Vector2(480.0, 270.0)
	camera.limit_left = 0
	camera.limit_right = 1600
	camera.limit_top = 0
	camera.limit_bottom = 540
	add_child(camera)
	camera.make_current()

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	ui = SideUI.new()
	ui.size = Vector2(960.0, 540.0)
	ui_layer.add_child(ui)
	object_view.size = Vector2(960, 540)
	ui_layer.add_child(object_view)
	object_view.finished.connect(_object_finished)
	ui.connect("choice_selected", _on_choice)
	ui.connect("evidence_selected", _on_evidence)
	ui.connect("dialog_finished", _on_dialog_finished)
	ui.connect("title_started", _begin_game)
	ui.connect("restart_requested", _restart)

	last_scene_id = ""
	load_scene("station", 160.0, false)
	ui.call("open_title")
	player.set("input_enabled", false)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	player_x = player.position.x
	if chore_stage == 1 and absf(player_x - float(active_chore.get("anchor_x", player_x))) > 100:
		chore_stage = 0
		ui.call("show_toast", "你松了手。秋千重新晃起来。", 2.6)
	var blocking: bool = bool(ui.call("is_blocking")) or object_view.visible
	hint_time = maxf(0.0, hint_time - delta)
	player.set("input_enabled", started and not blocking and not fade_busy)
	_update_camera(delta)
	_update_active()
	if scene_id == "playground" and not blocking and not fade_busy and absf(player_x - 640.0) < 270.0:
		creak_timer -= delta
		if creak_timer <= 0.0:
			creak_timer = 2.6
			if chore_stage == 0:
				var repaired := GameState.has_flag("helped_zhou")
				object_view.ring(object_view.note_audio, -32 if repaired else -23, 0.42 if repaired else 0.56)
	_update_quest_hint(blocking)
	if scene_id == "dream" and dream_active and not dream_wake:
		var exit_x: float = float(scene_data.get("exit_x", 3380.0))
		if player.position.x >= exit_x:
			_wake_from_dream()
	ui.call("set_prompt", _make_prompt(blocking))


func _update_camera(delta: float) -> void:
	var half: float = 480.0
	var cam_limit_low: float = half
	var cam_limit_high: float = max(half, scene_width - half)
	if scene_width <= 960.0:
		cam_limit_low = scene_width * 0.5
		cam_limit_high = cam_limit_low
	var target_x: float = player.position.x + float(player.get("direction")) * 64.0
	var desired: float = camera.position.x
	if absf(target_x - camera.position.x) > 180.0:
		desired = lerp(camera.position.x, target_x, clampf(0.12 * delta * 60.0, 0.0, 1.0))
	camera.position.x = clampf(desired, cam_limit_low, cam_limit_high)
	camera.position.y = 270.0
	for bg in backdrops:
		var parallax: float = float(bg.get("parallax"))
		bg.position.x = (camera.position.x - 480.0) * (1.0 - parallax)


func _update_active() -> void:
	active_target = null
	active_kind = ""
	if not started or bool(ui.call("is_blocking")) or fade_busy or object_view.visible:
		for door in doors:
			door.call("set_active", false)
		return
	var best: Node = null
	var best_dist: float = 100000.0
	for candidate in doors + actors + props:
		var entry: Dictionary = candidate.get("data")
		if candidate.is_in_group("prop") and not bool(entry.get("interact", false)):
			continue
		if candidate.is_in_group("actor") and bool(entry.get("hide_actor", false)):
			continue
		var distance: float = absf(candidate.position.x - player.position.x)
		if distance < 82.0 and distance < best_dist:
			best = candidate
			best_dist = distance
	active_target = best
	if active_target != null:
		if active_target.is_in_group("door"):
			active_kind = "door"
		elif active_target.is_in_group("actor"):
			active_kind = "actor"
		else:
			active_kind = "prop"
	for door in doors:
		door.call("set_active", door == active_target)


func _make_prompt(blocking: bool) -> String:
	if blocking or active_target == null:
		return ""
	if active_kind == "door":
		var d: Dictionary = active_target.get("data") as Dictionary
		var reason: String = _door_locked_reason(d)
		if not reason.is_empty():
			return "E　查看门 · 还不能过去"
		return "E　" + str(d.get("label", "门"))
	if active_kind == "actor":
		var a: Dictionary = active_target.get("data") as Dictionary
		return "E　和「" + str(a.get("name", "")) + "」说话"
	if active_kind == "prop":
		var p: Dictionary = active_target.get("data") as Dictionary
		var label: String = str(p.get("label", "看看"))
		var action: String = str(p.get("action", "read"))
		if action == "chore":
			return "E　松开座板" if chore_stage == 1 and str(p.get("chore")) == "zhou_swing" else "E　" + label
		if action == "evidence":
			return "E　" + label + " · 收进手记"
		if action == "wait":
			return "E　" + label
		if action == "chest":
			return "E　把磁带放进琴箱"
		if action == "ending":
			return "E　走到灯下"
		return "E　" + label
	return ""


func is_prop_active(node: Node) -> bool:
	return active_target == node


func is_actor_active(node: Node) -> bool:
	return active_target == node


func load_scene(id: String, spawn_x: float = -1.0, show_note: bool = false) -> void:
	var data: Dictionary = SceneDefs.get_scene(id)
	if data.is_empty():
		return
	scene_id = id
	scene_data = data
	scene_width = float(data.get("width", 2880.0))
	floor_y = float(data.get("floor_y", 456.0))
	GameState.current_scene = id
	GameState.mark_scene(id)
	if id == "house_hall":
		GameState.set_flag("visited_hall")
		GameState.refresh_objective()
	if active_chore.size() > 0 and str(active_chore.get("scene", "")) != id:
		active_chore.clear()
		chore_stage = 0
	active_target = null
	active_kind = ""
	active_npc.clear()
	present_npc.clear()
	reopen_npc.clear()
	dream_active = (id == "dream")
	dream_wake = false
	pending_dream_return = false

	for child in stage.get_children():
		child.queue_free()
	backdrops.clear()
	props.clear()
	actors.clear()
	doors.clear()

	var has_scene_art: bool = ResourceLoader.exists(
		"res://art/scenes/" + id + "/" + id + "_P0_far.png")
	for layer_name in ["far", "mid", "near"]:
		if has_scene_art and layer_name != "far":
			continue
		var bg: Node2D = SideBackdrop.new()
		stage.add_child(bg)
		bg.call("setup", id, GameState.phase, scene_width, floor_y, str(layer_name))
		backdrops.append(bg)

	ground_node = SideGround.new()
	stage.add_child(ground_node)
	ground_node.call("setup", id, GameState.phase, scene_width, floor_y)

	for item in data.get("doors", []) as Array:
		var dd: Dictionary = item as Dictionary
		if dd.has("show_if_flag") and not GameState.has_flag(str(dd["show_if_flag"])):
			continue
		var door: Node2D = SideDoor.new()
		door.add_to_group("door")
		stage.add_child(door)
		door.call("setup", dd, floor_y, bool(data.get("interior", false)))
		doors.append(door)

	for item in data.get("props", []) as Array:
		var pd: Dictionary = item as Dictionary
		if not _prop_visible(pd):
			continue
		var prop: Node2D = SideProp.new()
		stage.add_child(prop)
		prop.call("setup", pd, id, GameState.phase, floor_y, self)
		prop.add_to_group("prop")
		props.append(prop)

	for item in data.get("npcs", []) as Array:
		var nd: Dictionary = item as Dictionary
		if nd.has("hide_if_flag") and GameState.has_flag(str(nd.get("hide_if_flag", ""))):
			continue
		if bool(nd.get("hide_if_presented", false)) and GameState.has_flag(str(nd.get("present_flag", ""))):
			continue
		var positions: Dictionary = nd.get("positions", {}) as Dictionary
		var key: String = str(GameState.phase)
		var ax: float = float(positions.get(key, positions.get("0", 600.0)))
		var npc_data: Dictionary = nd.duplicate(true)
		npc_data["x"] = ax
		var actor: Node2D = SideActor.new()
		actor.add_to_group("actor")
		stage.add_child(actor)
		actor.call("setup", npc_data, id, GameState.phase, floor_y, self)
		actors.append(actor)

	var sx: float = spawn_x
	if sx < 0.0:
		sx = float(data.get("spawn", 160.0))
	sx = clampf(sx, 28.0, scene_width - 28.0)
	player.call("setup", floor_y, 28.0, scene_width - 28.0)
	player.position = Vector2(sx, floor_y)
	player.set("direction", 1)
	GameState.current_x = sx
	camera.position.x = clampf(sx, 480.0, max(480.0, scene_width - 480.0))
	camera.position.y = 270.0
	camera.limit_right = int(scene_width)
	sky.call("setup", GameState.phase)
	ui.call("set_prompt", "")
	GameState.refresh_objective()
	last_scene_id = id
	if show_note and started and not bool(ui.get("title_open")):
		var nid: String = "entry_" + id
		if not GameState.has_flag(nid):
			GameState.set_flag(nid)
			var note: String = str(data.get("note", ""))
			if not note.is_empty():
				ui.call("show_toast", note, 3.5)


func refresh_current() -> void:
	var keep_x: float = player.position.x
	load_scene(scene_id, keep_x, false)


func _prop_visible(p: Dictionary) -> bool:
	if p.has("show_if_flag") and not GameState.has_flag(str(p.get("show_if_flag", ""))):
		return false
	if p.has("show_if_flag_not") and GameState.has_flag(str(p.get("show_if_flag_not", ""))):
		return false
	if p.has("show_if_phase_min") and GameState.phase < int(p.get("show_if_phase_min", 0)):
		return false
	if p.has("show_if_phase_max") and GameState.phase > int(p.get("show_if_phase_max", 9)):
		return false
	if p.has("hide_if_evidence") and GameState.has_evidence(str(p.get("hide_if_evidence", ""))):
		return false
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code: int = key.keycode
	if object_view.visible:
		if object_view.handle_key(code):
			get_viewport().set_input_as_handled()
		return
	if bool(ui.get("title_open")):
		if code == KEY_E or code == KEY_ENTER or code == KEY_KP_ENTER:
			_begin_game()
		return
	if bool(ui.get("ending_open")):
		if code == KEY_R:
			_restart()
		elif code == KEY_ESCAPE:
			get_tree().quit()
		return
	if bool(ui.get("chapter_open")):
		if code == KEY_E or code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE or code == KEY_ESCAPE:
			ui.call("close_chapter")
		return
	if bool(ui.get("evidence_open")):
		if code == KEY_ESCAPE:
			ui.call("close_evidence")
			present_npc.clear()
		elif code == KEY_UP:
			ui.call("move_evidence", -1)
		elif code == KEY_DOWN:
			ui.call("move_evidence", 1)
		elif code in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			ui.call("choose_evidence")
		elif code >= KEY_1 and code <= KEY_9:
			ui.call("choose_evidence", code - KEY_1)
		return
	if bool(ui.get("journal_open")):
		if code == KEY_I or code == KEY_ESCAPE:
			ui.call("close_journal")
		elif code >= KEY_1 and code <= KEY_5:
			ui.call("switch_journal", code - KEY_1)
		elif code == KEY_UP:
			ui.call("select_journal", -1)
		elif code == KEY_DOWN:
			ui.call("select_journal", 1)
		return
	if bool(ui.get("dialog_open")):
		if code == KEY_ESCAPE:
			if pending_dream_return:
				ui.call("close_dialog", true)
				return
			if not reopen_npc.is_empty():
				reopen_npc.clear()
			if pending_refresh:
				ui.call("close_dialog", true)
				return
			final_choice_mode = false
			active_npc.clear()
			ui.call("close_dialog", false)
			return
		if bool(ui.get("choices_visible")):
			if code == KEY_UP:
				ui.call("move_choice", -1)
			elif code == KEY_DOWN:
				ui.call("move_choice", 1)
			elif code in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				ui.call("choose_index")
			elif code >= KEY_1 and code <= KEY_9:
				ui.call("choose_number", code - KEY_1)
		else:
			if code == KEY_E or code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
				ui.call("advance_dialog")
		return
	if code == KEY_H:
		hint_time = 7.0
		return
	if code == KEY_ESCAPE and not active_chore.is_empty():
		active_chore.clear()
		chore_stage = 0
		ui.call("show_toast", "先放下。想帮忙时可以回来。", 2.6)
		return
	if code == KEY_I:
		ui.call("open_journal")
		return
	if code == KEY_E:
		_interact()
		return


func _interact() -> void:
	if active_target == null or fade_busy:
		return
	if active_kind == "door":
		var d: Dictionary = active_target.get("data") as Dictionary
		_use_door(d)
	elif active_kind == "actor":
		var a: Dictionary = active_target.get("data") as Dictionary
		_talk_actor(a)
	elif active_kind == "prop":
		var p: Dictionary = active_target.get("data") as Dictionary
		_use_prop(p)


func _use_door(d: Dictionary) -> void:
	var reason: String = _door_locked_reason(d)
	if not reason.is_empty():
		ui.call("show_toast", reason, 4.0)
		return
	var to: String = str(d.get("to", "station"))
	var spawn: float = float(d.get("spawn", 160.0))
	await _travel(to, spawn, true)


func _door_locked_reason(d: Dictionary) -> String:
	var to: String = str(d.get("to", ""))
	if (to == "street_east" or to == "playground") and not GameState.has_flag("visited_hall"):
		return "先回老宅客厅看看。现在往东走，还太早。"
	if (to == "street_east" or to == "playground") and not (GameState.has_evidence("ev_photo") and GameState.has_evidence("ev_note")):
		return "先回客厅，把照片和琴弦字条都拿上。"
	if to == "street_east" and not GameState.has_flag("presented_xiaoman"):
		return "先回老街西段，把小满的事做完。照片还没递出去。"
	if to == "playground" and not GameState.has_flag("presented_xiaoman"):
		return "先回老街西段，把小满的事做完。"
	if to == "crossing" and not GameState.has_flag("presented_zhou"):
		return "先回游乐场，把旧鞋递给周德海。"
	if to == "basement" and not GameState.has_flag("presented_tang"):
		return "先把搬家清单递给唐棠。地下室的门现在打不开。"
	if to == "town_final":
		if not GameState.has_flag("presented_tang"):
			return "先把手里的东西交出去。"
		if not GameState.has_flag("dream_seen"):
			return "还不到走的时候。先回老宅地下室，听见那盘磁带。"
	return ""


func _travel(to: String, spawn: float, show_note: bool = true) -> void:
	if fade_busy:
		return
	fade_busy = true
	ui.call("close_dialog", false)
	ui.call("close_evidence")
	ui.call("close_journal")
	ui.call("close_chapter")
	ui.call("set_fade", 0.85)
	await get_tree().create_timer(0.18, true).timeout
	if to == "town_final":
		GameState.phase = 3
		GameState.refresh_objective()
	load_scene(to, spawn, show_note)
	await get_tree().create_timer(0.08, true).timeout
	ui.call("set_fade", 0.0)
	fade_busy = false


func _talk_actor(npc: Dictionary) -> void:
	if bool(ui.get("dialog_open")) or bool(ui.get("evidence_open")):
		return
	active_npc = npc.duplicate(true)
	var npc_id: String = str(npc.get("id", ""))
	var name: String = str(npc.get("name", ""))
	var style: String = str(npc.get("style", ""))
	var step: int = GameState.linear_step()
	var greet: String = str(npc.get("greet", "……"))
	var choices: Array = []

	if npc_id == "p_xiaoman":
		if step < 2:
			greet = "先去老宅客厅看看。你妈说你要回来，先别急着找我。"
		elif not GameState.has_flag("helped_xiaoman"):
			greet = "帮我压一下。别按折痕，第三页我还得改。"
			choices.append({"id": "help", "label": "帮她夹好散谱", "hint": "走到散谱边，按 E 把谱页理齐。", "recommended": true})
		elif not GameState.has_flag("presented_xiaoman"):
			greet = "第三页给我。等一下……你见过我爸抱那把琴吗？"
			if GameState.has_evidence("ev_photo"):
				choices.append({"id": "present", "label": "给她看一样旧东西", "hint": "她刚才问起父亲抱琴的样子。", "recommended": true})
		else:
			greet = "照片我收着。你要问的，去问我爸。"
	elif npc_id == "p_zhou":
		if step < 3:
			greet = "先去老街找小满。她那边还没完。"
		elif not GameState.has_flag("helped_zhou"):
			greet = "别推。扶住就好。听见右边那一声了吗？"
			choices.append({"id": "help", "label": "扶住秋千", "hint": "走到秋千边，按 E 扶住座板。", "recommended": true})
		elif GameState.phase < 2:
			greet = "听。刚才响的是右边。你坐会儿，我等灯亮。"
		elif not GameState.has_evidence("ev_shoes"):
			greet = "灯照到的地方，别踩。鞋尖我才摆好。"
		else:
			greet = "她老把右脚穿反。一跑起来，就听得出来。"
			choices.append({"id": "present", "label": "拿出灯下的东西", "hint": "老周盯着空座下方。", "recommended": true})
	elif npc_id == "p_tang":
		if step < 4:
			greet = "先去游乐场，老周那边还有事。"
		elif not GameState.has_flag("helped_tang"):
			greet = "抬那头，底下软了。别让它再沾水。"
			choices.append({"id": "help", "label": "帮她搬最后一箱", "hint": "走到纸箱边，按 E 抬住箱底。", "recommended": true})
		elif not GameState.has_evidence("ev_list"):
			greet = "箱子都上车了。清单在箱子边，帮我拿一下。"
		else:
			greet = "我写了三遍带走。你看看，最后到底划掉了什么。"
			choices.append({"id": "present", "label": "给她看自己找到的东西", "hint": "她在等你认出被划掉的一行。", "recommended": true})
	else:
		var done_flag: String = str(npc.get("done_flag", ""))
		var present_flag: String = str(npc.get("present_flag", ""))
		if not present_flag.is_empty() and GameState.has_flag(present_flag) and not str(npc.get("line_after", "")).is_empty():
			greet = str(npc.get("line_after", greet))
		elif not done_flag.is_empty() and GameState.has_flag(done_flag) and not str(npc.get("line_helped", "")).is_empty():
			greet = str(npc.get("line_helped", greet))
		var accept: String = str(npc.get("accept_evidence", ""))
		if not accept.is_empty() and GameState.has_evidence(accept):
			var pflag: String = str(npc.get("present_flag", ""))
			if pflag.is_empty() or not GameState.has_flag(pflag):
				choices.append({"id": "present", "label": "拿出「" + GameState.evidence_name(accept) + "」", "hint": "递给他看看。", "recommended": false})

	var topics := {"p_xiaoman":"问她在改哪一段", "p_zhou":"问他每天修什么", "p_tang":"问她想留下什么"}
	if not (npc.get("lines", []) as Array).is_empty():
		choices.append({"id": "ask", "label": topics.get(npc_id, "再聊两句"), "hint": "", "recommended": false})
	choices.append({"id": "leave", "label": "我先走了", "hint": "离开对话。", "recommended": false})
	ui.call("show_dialog", name, style, [greet], choices)


func _on_choice(id: String) -> void:
	if final_choice_mode:
		final_choice_mode = false
		if id == "end_turn":
			object_view.open("ending_watch")
			return
		GameState.ending_seen = true
		ui.call("show_ending", id)
		return
	if active_npc.is_empty():
		return
	if id == "help":
		_start_chore(active_npc)
	elif id == "ask":
		_ask_npc(active_npc)
	elif id == "present":
		_open_present(active_npc)
	elif id == "leave":
		active_npc.clear()
		ui.call("close_dialog", false)


func _ask_npc(npc: Dictionary) -> void:
	var lines: Array = npc.get("lines", []) as Array
	if lines.is_empty():
		lines = ["……"]
	var person := str(npc.get("id", ""))
	var idx: int = int(asked_topics.get(person, 0))
	asked_topics[person] = idx + 1
	var line: String = str(lines[idx % lines.size()])
	var updated: Dictionary = npc.duplicate(true)
	updated["_ask_index"] = (idx + 1) % lines.size()
	active_npc = updated
	ui.call("show_dialog", str(npc.get("name", "")), str(npc.get("style", "")), [line], [])


func _open_present(npc: Dictionary) -> void:
	if GameState.evidence.size() == 0:
		ui.call("show_dialog", "旁白", "", ["你手里没有可以递出去的东西。"], [])
		return
	present_npc = npc.duplicate(true)
	ui.call("open_evidence", GameState.evidence)


func _on_evidence(id: String) -> void:
	if present_npc.is_empty():
		return
	var npc: Dictionary = present_npc
	var accept: String = str(npc.get("accept_evidence", ""))
	var name: String = str(npc.get("name", ""))
	var style: String = str(npc.get("style", ""))
	if id != accept:
		ui.call("show_dialog", name, style, [str(npc.get("line_present_bad", "这个，现在不该给我。"))], [])
		reopen_npc = npc
		present_npc.clear()
		return
	var pflag: String = str(npc.get("present_flag", ""))
	if not pflag.is_empty():
		GameState.set_flag(pflag)
	var reward: String = str(npc.get("reward", ""))
	if not reward.is_empty() and GameState.add_evidence(reward):
		ui.call("show_toast", "物证 · " + GameState.evidence_name(reward), 2.8)
	GameState.refresh_objective()
	ui.call("show_dialog", name, style, [str(npc.get("line_present_ok", "……"))], [])
	pending_refresh = true
	present_npc.clear()


func _start_chore(npc: Dictionary) -> void:
	var chore: String = str(npc.get("chore", ""))
	if chore.is_empty():
		return
	var anchor_x: float = 0.0
	var cancel_distance: float = 200.0
	for item in scene_data.get("props", []) as Array:
		var pd: Dictionary = item as Dictionary
		if str(pd.get("chore", "")) == chore:
			anchor_x = float(pd.get("x", 0.0))
			cancel_distance = float(pd.get("cancel_distance", 200.0))
			break
	active_chore = {
		"id": chore,
		"npc": npc.duplicate(true),
		"npc_name": str(npc.get("name", "")),
		"scene": scene_id,
		"anchor_x": anchor_x,
		"cancel_distance": cancel_distance,
	}
	chore_stage = 0
	active_npc.clear()
	ui.call("close_dialog", false)
	var chore_label: String = CHORE_LABELS.get(chore, str(npc.get("chore_label", "那件事")))
	ui.call("show_toast", "目标更新 · 去「" + chore_label + "」的位置，按 E。", 3.2)


func _advance_chore(p: Dictionary) -> void:
	var chore: String = str(active_chore.get("id", ""))
	if chore.is_empty() or str(p.get("chore", "")) != chore:
		ui.call("show_toast", "先听听旁边的人怎么说。", 3.0)
		return
	if chore == "zhou_swing" and chore_stage == 0:
		chore_stage = 1
		object_view.ring(object_view.note_audio, -22, 0.43)
		ui.call("show_toast", "链条停了。老周抬手示意你松开。", 3.4)
		return
	_complete_chore()


func _complete_chore() -> void:
	if active_chore.is_empty():
		return
	var npc: Dictionary = active_chore.get("npc", {}) as Dictionary
	var chore: String = str(active_chore.get("id", ""))
	var done_flag: String = str(npc.get("done_flag", ""))
	if not done_flag.is_empty():
		GameState.set_flag(done_flag)
	var extra: String = ""
	if chore == "zhou_swing":
		extra = "ev_screw"
	elif chore == "xiaoman_score":
		extra = "ev_score"
	var found_extra := not extra.is_empty() and GameState.add_evidence(extra)
	active_chore.clear()
	chore_stage = 0
	if chore == "zhou_swing" and GameState.phase == 0:
		advance_phase(1)
	else:
		refresh_current()
	GameState.refresh_objective()
	var replies := {
		"zhou_swing":"老周：你再听。右边轻了。",
		"xiaoman_score":"小满：第三页给我。那段我改了。",
		"tang_box":"唐棠：先别关车门。还有一张清单。"
	}
	ui.call("show_toast", str(replies[chore]), 3.8)
	if found_extra:
		object_view.ring(object_view.note_audio, -22, 0.91)


func advance_phase(target: int) -> void:
	if target <= GameState.phase:
		return
	GameState.phase = target
	GameState.refresh_objective()
	sky.call("setup", target)
	refresh_current()
	ui.call("show_toast", "时段 · " + GameState.phase_name(), 2.2)


func _use_prop(p: Dictionary) -> void:
	var action: String = str(p.get("action", "read"))
	if action == "turn_watch" or action == "turn_photo":
		object_view.open("watch" if action == "turn_watch" else "photo")
		return
	if action == "chore":
		_advance_chore(p)
	elif action == "evidence":
		_collect_object(str(p.get("evidence", "")))
	elif action == "wait":
		var target_phase: int = int(p.get("target_phase", 2))
		if GameState.phase < target_phase and GameState.has_flag("helped_zhou"):
			advance_phase(target_phase)
			GameState.refresh_objective()
			ui.call("set_fade", 0.65)
			create_tween().tween_method(func(value: float): ui.call("set_fade", value), 0.65, 0.0, 0.55)
			object_view.ring(object_view.note_audio, -24, 0.53)
			ui.call("show_toast", "灯亮了。", 2.6)
		elif GameState.phase < 2:
			ui.call("show_dialog", "旁白", "", ["先帮周德海把秋千扶好。现在坐下，只会耽误事。"], [])
		else:
			ui.call("show_dialog", "旁白", "", ["天已经黑了。灯下那双鞋还在。"], [])
	elif action == "chest":
		if GameState.has_flag("dream_seen"):
			ui.call("show_dialog", "旁白", "", ["琴箱开着。里面空了，只剩一圈灰。"], [])
		elif GameState.has_evidence("ev_tape") or GameState.has_flag("presented_tang"):
			object_view.open("tape")
		else:
			ui.call("show_dialog", "旁白", "", ["琴箱锁着。锁扣上有一层薄灰。先把唐棠的清单递出去，再回来。"], [])
	elif action == "ending":
		if GameState.linear_step() < 6:
			ui.call("show_dialog", "旁白", "", ["还不到走的时候。先把手里的东西交出去。"], [])
			return
		final_choice_mode = true
		ui.call("show_dialog", "旁白", "", FINAL_LINES, [
			{"id": "end_keep", "label": "把表放回兜里，不再动它", "hint": "让车开走，让镇子留在身后。", "recommended": false},
			{"id": "end_turn", "label": "拨动表针，回到某一天", "hint": "把时间拨回去，再看一眼。", "recommended": false},
		])
	else:
		var text: String = str(p.get("text", "……"))
		ui.call("show_toast", text, 5.0)


func _collect_object(id: String) -> void:
	if GameState.add_evidence(id):
		refresh_current()
		GameState.refresh_objective()
		object_view.ring(object_view.note_audio, -24, 1.08)
		ui.call("show_toast", "已收好 · " + GameState.evidence_name(id), 2.7)

func _object_finished(success: bool) -> void:
	if not success:
		return
	match object_view.mode:
		"watch":
			if not GameState.has_flag("station_turned"):
				GameState.set_flag("station_turned")
				refresh_current()
			object_view.ring(object_view.note_audio, -14, 0.6)
			ui.call("set_fade", 0.38)
			create_tween().tween_method(func(value: float): ui.call("set_fade", value), 0.38, 0.0, 0.4)
			ui.call("show_toast", "刚才空着的长椅上，多了一张票。", 4.8)
		"ending_watch":
			GameState.ending_seen = true
			ui.call("show_ending", "turn")
		"photo":
			_collect_object("ev_photo")
		"tape":
			_start_dream()


func _start_dream() -> void:
	dream_active = true
	dream_wake = false
	await _travel("dream", 160.0, false)
	ui.call("show_dialog", "旁白", "", DREAM_INTRO, [])


func _wake_from_dream() -> void:
	dream_wake = true
	pending_dream_return = true
	ui.call("show_dialog", "旁白", "", DREAM_END, [])


func _on_dialog_finished() -> void:
	if pending_dream_return:
		pending_dream_return = false
		GameState.set_flag("dream_seen")
		GameState.refresh_objective()
		ui.call("show_toast", "梦醒了 · 手记更新", 2.4)
		await _travel("house_hall", 1500.0, false)
		return
	if pending_refresh:
		pending_refresh = false
		refresh_current()
	if not reopen_npc.is_empty():
		var npc: Dictionary = reopen_npc
		reopen_npc.clear()
		_talk_actor(npc)


func _begin_game() -> void:
	if not bool(ui.get("title_open")):
		return
	GameState.reset()
	asked_topics.clear()
	hint_time = 0.0
	started = true
	ui.call("start_game_ui")
	load_scene("station", 160.0, false)
	ui.call("show_toast", "站台的表停了。试着拨一下。", 4.3)


func _restart() -> void:
	GameState.reset()
	asked_topics.clear()
	hint_time = 0.0
	started = true
	ui.call("start_game_ui")
	load_scene("station", 160.0, false)
	ui.call("show_toast", "站台的表停了。试着拨一下。", 4.3)


# ---------- 主线提示与章节卡 ----------

func _update_quest_hint(blocking: bool) -> void:
	if not started or bool(ui.get("title_open")):
		return
	if hint_time <= 0.0:
		ui.call("set_quest_hint", {})
		return
	var quest: Dictionary = GameState.quest_target()
	if active_chore.size() > 0:
		var chore_id: String = str(active_chore.get("id", ""))
		for prop in props:
			var pdata: Dictionary = prop.get("data") as Dictionary
			if str(pdata.get("chore", "")) != chore_id:
				continue
			quest = {
				"scene": scene_id,
				"x": prop.position.x,
				"kind": "prop",
				"id": str(pdata.get("id", "")),
				"label": str(pdata.get("label", "那件事")),
			}
			break
	var step: int = GameState.linear_step()
	var info: Dictionary = {
		"step": step,
		"step_text": GameState.step_index_text(),
		"title": GameState.step_title(),
		"objective": GameState.step_objective(),
		"detail": GameState.step_detail(),
		"label": str(quest.get("label", "")),
		"target_scene": str(quest.get("scene", "")),
		"target_kind": str(quest.get("kind", "")),
		"blocking": blocking,
		"marker_visible": false,
		"arrow_dir": 0,
		"arrow_text": "",
	}
	if active_chore.size() > 0:
		var chore_id: String = str(active_chore.get("id", ""))
		var chore_text: String = str(CHORE_LABELS.get(chore_id, "那件事"))
		info["detail"] = "走到「" + chore_text + "」的位置，按 E 完成这一步。"
	var target_scene: String = str(quest.get("scene", ""))
	if target_scene == scene_id:
		var node: Node = _find_quest_node(quest)
		var wx: float = float(quest.get("x", 0.0))
		var node2d: Node2D = node as Node2D
		if node2d != null:
			wx = node2d.position.x
		var screen_x: float = wx - camera.position.x + 480.0
		if screen_x >= 52.0 and screen_x <= 908.0:
			info["marker_visible"] = true
			info["marker_x"] = screen_x
			info["marker_y"] = floor_y - 150.0
			info["label"] = str(quest.get("label", ""))
		else:
			info["arrow_dir"] = 1 if screen_x > 480.0 else -1
			info["arrow_text"] = "目标 · " + str(quest.get("label", ""))
	else:
		var next_door: Node = _next_door_towards(target_scene)
		var next_door2d: Node2D = next_door as Node2D
		if next_door2d != null:
			info["arrow_dir"] = 1 if next_door2d.position.x >= player.position.x else -1
			var to: String = str((next_door2d.get("data") as Dictionary).get("to", ""))
			info["arrow_text"] = "往「" + _scene_title(to) + "」方向"
		else:
			info["arrow_dir"] = 1
			info["arrow_text"] = "目标 · " + str(quest.get("label", ""))
	ui.call("set_quest_hint", info)


func _find_quest_node(quest: Dictionary) -> Node:
	var kind: String = str(quest.get("kind", ""))
	var target_id: String = str(quest.get("id", ""))
	if kind == "actor":
		for actor in actors:
			var data: Dictionary = actor.get("data") as Dictionary
			if str(data.get("id", "")) == target_id:
				return actor
	elif kind == "prop":
		for prop in props:
			var pdata: Dictionary = prop.get("data") as Dictionary
			if str(pdata.get("id", "")) == target_id:
				return prop
	return null


func _scene_title(id: String) -> String:
	var data: Dictionary = SceneDefs.get_scene(id)
	return str(data.get("title", id))


func _next_door_towards(target_scene: String) -> Node:
	if target_scene.is_empty() or target_scene == scene_id:
		return null
	var all: Dictionary = SceneDefs.all()
	var queue: Array[String] = [scene_id]
	var prev: Dictionary = {scene_id: ""}
	var found: bool = false
	while queue.size() > 0:
		var cur: String = queue.pop_front()
		if cur == target_scene:
			found = true
			break
		var data: Dictionary = all.get(cur, {}) as Dictionary
		for item in data.get("doors", []) as Array:
			var dd: Dictionary = item as Dictionary
			var to: String = str(dd.get("to", ""))
			if to.is_empty() or prev.has(to) or not _door_locked_reason(dd).is_empty() or (dd.has("show_if_flag") and not GameState.has_flag(str(dd["show_if_flag"]))):
				continue
			prev[to] = cur
			queue.append(to)
	if not found:
		return null
	var node_id: String = target_scene
	while prev.has(node_id) and str(prev.get(node_id, "")) != scene_id:
		node_id = str(prev.get(node_id, ""))
		if node_id.is_empty():
			return null
	for door in doors:
		var dd: Dictionary = door.get("data") as Dictionary
		if str(dd.get("to", "")) == node_id:
			return door
	return null


# ---------- 调试 / 截图接口 ----------

func debug_begin() -> void:
	_begin_game()


func debug_load(id: String, x: float) -> void:
	ui.call("close_dialog", false)
	ui.call("close_evidence")
	ui.call("close_journal")
	ui.call("close_chapter")
	started = true
	ui.call("start_game_ui")
	load_scene(id, x, false)


func debug_talk(npc_id: String) -> bool:
	for actor in actors:
		var data: Dictionary = actor.get("data") as Dictionary
		if str(data.get("id", "")) == npc_id:
			_talk_actor(data)
			return true
	return false


func debug_choose(index: int) -> void:
	ui.call("choose_number", index)


func debug_advance(times: int = 1) -> void:
	for i in range(times):
		ui.call("advance_dialog")


func debug_open_journal() -> void:
	ui.call("open_journal")


func debug_journal_tab(tab: int) -> void:
	ui.call("switch_journal", tab)


func debug_show_ending(kind: String = "keep") -> void:
	GameState.ending_seen = true
	ui.call("show_ending", kind)


func debug_set_phase(value: int) -> void:
	GameState.phase = value
	GameState.refresh_objective()
	refresh_current()


func debug_goto(x: float) -> void:
	player.position.x = clampf(x, 28.0, scene_width - 28.0)
	GameState.current_x = player.position.x
	camera.position.x = clampf(player.position.x, 480.0, max(480.0, scene_width - 480.0))


func debug_interact() -> void:
	_interact()


func debug_door(to_scene: String) -> bool:
	for door in doors:
		var data: Dictionary = door.get("data") as Dictionary
		if str(data.get("to", "")) == to_scene:
			_use_door(data)
			return true
	return false


func debug_close_chapter() -> void:
	ui.call("close_chapter")


func debug_choice_count() -> int:
	return int(ui.call("choice_count"))


func debug_choose_evidence(index: int) -> void:
	ui.call("choose_evidence", index)


func debug_choose_evidence_id(id: String) -> bool:
	var index: int = GameState.evidence.find(id)
	if index < 0:
		return false
	ui.call("choose_evidence", index)
	return true


func debug_evidence_count() -> int:
	return GameState.evidence.size()


func debug_step() -> int:
	return GameState.linear_step()


func debug_quest() -> Dictionary:
	return GameState.quest_target()
