extends Node

# 回归：真实输入路径能否让玩家移动。
# 之前的 86 项断言只检查"没走出可行走区"，玩家原地不动也能全绿，
# 于是 8 向改写里 `input.length_squared() > 1.0` 这个阈值把单键行走判死也没人发现。
# 本测试按物理键事件喂给 Input 单例，走 world.gd 的 _process，四个方向各按 60 帧，位移必须 > 20px。

var _fail_count: int = 0

func _ready() -> void:
	TurnState.reset()
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	TurnState.set_flag("intro_langcheng_room", true)
	TurnState.set_flag("intro_town_gate", true)
	TurnState.set_flag("intro_house_hall", true)
	var ps: PackedScene = load("res://world/world.tscn") as PackedScene
	var w: Node = ps.instantiate()
	add_child(w)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var p: Variant = w.get("player")
	var chapter_layer: CanvasLayer = w.get("chapter") as CanvasLayer
	print("[probe] scene=", str(w.get("scene_id")))
	print("[probe] locked=", str(w.get("_locked")))
	print("[probe] chapter_visible=", str(chapter_layer.visible))
	print("[probe] present_open=", str(w.call("_present_layer_open")))
	print("[probe] spawn=", str(p.pos))
	var d: Dictionary = w.get("data") as Dictionary
	print("[probe] can_stand_here=", str(p.can_stand(p.pos, d)))

	await _check(p, KEY_D, "右", 60)
	await _check(p, KEY_S, "下", 60)
	await _check(p, KEY_A, "左", 60)
	await _check(p, KEY_W, "上", 60)

	# 斜向也要能动，且不能比单轴慢太多（防止 limit_length 被写坏）
	await _check_diag(p)

	print("[probe] RESULT ", "PASS" if _fail_count == 0 else "FAIL", " fail=", str(_fail_count))
	get_tree().quit(0 if _fail_count == 0 else 1)

func _check(p: Variant, key: int, label: String, frames: int) -> void:
	var from: Vector2 = p.pos as Vector2
	await _hold(key, frames)
	var moved: float = (p.pos as Vector2).distance_to(from)
	if moved < 20.0:
		_fail_count += 1
		print("[probe] FAIL ", label, " 只走了 ", str(moved), "px（按键被吞或阈值写死）")
	else:
		print("[probe] OK ", label, " 走了 ", str(moved), "px dir=", str(p.dir), " frame=", str(p.frame()))

func _check_diag(p: Variant) -> void:
	var from: Vector2 = p.pos as Vector2
	var ev_d: InputEventKey = InputEventKey.new()
	ev_d.physical_keycode = KEY_D
	ev_d.keycode = KEY_D
	ev_d.pressed = true
	Input.parse_input_event(ev_d)
	var ev_w: InputEventKey = InputEventKey.new()
	ev_w.physical_keycode = KEY_W
	ev_w.keycode = KEY_W
	ev_w.pressed = true
	Input.parse_input_event(ev_w)
	var i: int = 0
	while i < 60:
		await get_tree().process_frame
		i += 1
	ev_d.pressed = false
	Input.parse_input_event(ev_d)
	ev_w.pressed = false
	Input.parse_input_event(ev_w)
	await get_tree().process_frame
	var moved: float = (p.pos as Vector2).distance_to(from)
	if moved < 30.0:
		_fail_count += 1
		print("[probe] FAIL 斜向 只走了 ", str(moved), "px")
	else:
		print("[probe] OK 斜向 走了 ", str(moved), "px")

func _hold(key: int, frames: int) -> void:
	var ev_down: InputEventKey = InputEventKey.new()
	ev_down.physical_keycode = key
	ev_down.keycode = key
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	var i: int = 0
	while i < frames:
		await get_tree().process_frame
		i += 1
	var ev_up: InputEventKey = InputEventKey.new()
	ev_up.physical_keycode = key
	ev_up.keycode = key
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	await get_tree().process_frame
