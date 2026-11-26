extends Node

# R151 原生通关演练：从新游戏到结局，不挂任何探针补偿（不手动 reload、不直改锁状态），
# 只走世界层真实交互 API：_use_spot / _use_exit / _say_npc / _present_pick / puzzle.combine_attempt。
# 逐步日志落盘 E:/gamejam/jam200/state/b8_native_playthrough.txt。

const LOG_PATH: String = "E:/gamejam/jam200/state/b8_native_playthrough.txt"

var world = null
var log_lines: Array[String] = []
var stuck_count: int = 0
var step_no: int = 0

# kind: spot / exit / combo / npc；expect 为到达场景（留空表示按出口 to 或梦醒来源）。
var plan: Array = [
	{"kind": "spot", "label": "床", "expect": "langcheng_room"},
	{"kind": "spot", "label": "窗外", "expect": "langcheng_room"},
	{"kind": "spot", "label": "桌上的合同", "expect": "langcheng_room"},
	{"kind": "exit", "label": "出门 · 去公司", "expect": "langcheng_office"},
	{"kind": "spot", "label": "屏幕", "expect": "langcheng_office"},
	{"kind": "spot", "label": "抽屉里的草稿", "expect": "langcheng_office"},
	{"kind": "combo", "pair": "ev_letter|ev_draft", "expect": "langcheng_office"},
	{"kind": "exit", "label": "下楼 · 去厂里", "expect": "langcheng_factory"},
	{"kind": "spot", "label": "工装名牌", "expect": "langcheng_factory"},
	{"kind": "exit", "label": "沿楼梯回工位", "expect": "langcheng_office"},
	{"kind": "exit", "label": "沿楼梯回出租屋", "expect": "langcheng_room"},
	{"kind": "exit", "label": "收行李 · 回镇上", "expect": "town_gate"},
	{"kind": "exit", "label": "往里走 · 老街", "expect": "town_road"},
	{"kind": "exit", "label": "进老宅院子", "expect": "old_house_yard"},
	{"kind": "spot", "label": "门槛缝", "expect": "old_house_yard"},
	{"kind": "exit", "label": "进门", "expect": "house_hall"},
	{"kind": "spot", "label": "茶几夹层的便签", "expect": "house_hall"},
	{"kind": "combo", "pair": "ev_note|ev_photo", "expect": "house_hall"},
	{"kind": "spot", "label": "上锁的琴箱 · 把手放上去", "expect": "dream_classroom"},
	{"kind": "exit", "label": "往前 · 巷子", "expect": "dream_alley"},
	{"kind": "exit", "label": "往前 · 邮筒", "expect": "dream_postbox"},
	{"kind": "spot", "label": "邮筒边的票根", "expect": "dream_postbox"},
	{"kind": "exit", "label": "往前 · 木箱", "expect": "dream_box"},
	{"kind": "exit", "label": "醒过来", "expect": "house_hall"},
	{"kind": "exit", "label": "下地下室", "expect": "basement"},
	{"kind": "exit", "label": "上楼", "expect": "house_hall"},
	{"kind": "exit", "label": "出门", "expect": "old_house_yard"},
	{"kind": "exit", "label": "回老街", "expect": "town_road"},
	{"kind": "exit", "label": "去游乐场", "expect": "playground_day"},
	{"kind": "spot", "label": "秋千", "expect": "playground_day"},
	{"kind": "exit", "label": "等到入夜 · 蓝调夜色", "expect": "playground_night"},
	{"kind": "spot", "label": "灯下的旧鞋", "expect": "playground_night"},
	{"kind": "npc", "label": "周德海", "ev": "ev_shoes", "expect": "playground_night"},
	{"kind": "combo", "pair": "ev_screw|ev_shoes", "expect": "playground_night"},
	{"kind": "exit", "label": "等到白天", "expect": "playground_day"},
	{"kind": "exit", "label": "回老街", "expect": "town_road"},
	{"kind": "exit", "label": "往路口", "expect": "street_cross"},
	{"kind": "spot", "label": "搬家清单", "expect": "street_cross"},
	{"kind": "spot", "label": "磁带机旁的旧磁带", "expect": "street_cross"},
	{"kind": "combo", "pair": "ev_list|ev_tape", "expect": "street_cross"},
	{"kind": "spot", "label": "旧磁带 · 听一段", "expect": "dream_dirt_road"},
	{"kind": "combo", "pair": "ev_ticket|ev_shoes", "expect": "dream_dirt_road"},
	{"kind": "exit", "label": "往前 · 车站", "expect": "dream_station"},
	{"kind": "exit", "label": "醒过来", "expect": "street_cross"},
	{"kind": "exit", "label": "回老街", "expect": "town_road"},
	{"kind": "exit", "label": "镇口灯火", "expect": "town_final"},
	{"kind": "spot", "label": "回到灯火下", "expect": "town_final"},
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("E:/gamejam/jam200/state/")
	var clear_file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if clear_file != null:
		clear_file.close()
	TurnState.reset()
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	if packed == null:
		_finish("world.tscn 加载失败", 1)
		return
	world = packed.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	if world.chapter != null:
		world.chapter.skip()
	await get_tree().process_frame
	world.force_scene("langcheng_room")
	await get_tree().process_frame

	_log("R151 原生通关演练（无探针补偿）")
	_log("起始场景：" + world.scene_id)

	for step in plan:
		step_no += 1
		var entry: Dictionary = step as Dictionary
		var kind: String = str(entry.get("kind", ""))
		var before: String = world.scene_id
		var expect: String = str(entry.get("expect", ""))
		var detail: String = ""
		var ok: bool = true

		match kind:
			"spot":
				detail = str(entry.get("label", ""))
				await _wait_free()
				ok = await _do_spot(str(entry.get("label", "")))
			"exit":
				detail = str(entry.get("label", ""))
				await _wait_free()
				ok = await _do_exit(str(entry.get("label", "")), expect)
			"combo":
				detail = str(entry.get("pair", ""))
				await _wait_free()
				ok = _do_combo(str(entry.get("pair", "")))
			"npc":
				detail = str(entry.get("label", "")) + " 出示 " + str(entry.get("ev", ""))
				await _wait_free()
				ok = await _do_npc(str(entry.get("label", "")), str(entry.get("ev", "")))

		await _frames(3)
		_dismiss_chapter()
		var after: String = world.scene_id
		var verdict: String = "OK"
		if not ok:
			verdict = "FAIL"
			stuck_count += 1
		elif not expect.is_empty() and after != expect:
			verdict = "STUCK(落点不符)"
			ok = false
			stuck_count += 1
		_log("#%02d [%s] %s -> %s | %s | %s" % [step_no, before, detail, after, verdict, _count_summary()])

	var ev_n: int = world.puzzle.all_evidence().size()
	var cl_n: int = world.puzzle.all_clues().size()
	var tier: String = TurnState.settle_collection_tier(ev_n, cl_n)
	_log("---- 演练结束 ----")
	_log("总步数：%d，卡住/失败：%d" % [plan.size(), stuck_count])
	_log("物证：%d/10，推论：%d/5，结局档位：%s" % [ev_n, cl_n, tier])

	var passed: bool = stuck_count == 0 and ev_n == 10 and cl_n == 5 and tier == "clear"
	_finish("原生通关 " + ("通过：0 卡点 / clear 档" if passed else "未通过：stuck=%d ev=%d cl=%d tier=%s" % [stuck_count, ev_n, cl_n, tier]), 0 if passed else 1)

func _wait_free() -> void:
	for i in range(60):
		await get_tree().create_timer(0.03).timeout
		_dismiss_chapter()
		if not world._locked and not world.chapter.visible and not world._present_layer_open():
			return

func _do_spot(label: String) -> bool:
	var spot: Dictionary = _find_spot(label)
	if spot.is_empty():
		return false
	var dream_target: String = ""
	if str(spot.get("kind", "")) == "dream":
		dream_target = str(spot.get("arg", ""))
	world._use_spot(spot)
	_settle_dialog()
	if not dream_target.is_empty():
		for i in range(60):
			await get_tree().create_timer(0.03).timeout
			_dismiss_chapter()
			if world.scene_id == dream_target:
				break
	_dismiss_chapter()
	return true

func _do_exit(label: String, expect: String) -> bool:
	var exit: Dictionary = _find_exit(label)
	if exit.is_empty():
		return false
	var before_return: String = world._return_scene
	world._use_exit(exit)
	await _frames(2)
	var arrived: bool = false
	for i in range(60):
		await get_tree().create_timer(0.03).timeout
		_dismiss_chapter()
		var target: String = expect
		if target.is_empty():
			target = before_return if not before_return.is_empty() else str(exit.get("to", ""))
		if world.scene_id == target:
			arrived = true
			break
	return arrived

func _do_combo(pair: String) -> bool:
	var parts: PackedStringArray = pair.split("|")
	if parts.size() != 2:
		return false
	var result: Dictionary = world.puzzle.combine_attempt(str(parts[0]), str(parts[1]))
	return bool(result.get("ok", false))

func _do_npc(name: String, ev: String) -> bool:
	var npc: Dictionary = _find_npc(name)
	if npc.is_empty():
		return false
	world._say_npc(npc)
	await get_tree().process_frame
	if world._present_layer_open():
		world._present_pick(ev)
		await get_tree().process_frame
	_settle_dialog()
	return world.puzzle.has_evidence(ev) or world._present_layer == null or not world._present_layer_open()

func _find_spot(label: String) -> Dictionary:
	for spot in world.data.get("spots", []) as Array:
		var entry: Dictionary = spot as Dictionary
		if str(entry.get("label", "")) == label:
			return entry
	return {}

func _find_exit(label: String) -> Dictionary:
	for exit in world.data.get("exits", []) as Array:
		var entry: Dictionary = exit as Dictionary
		if str(entry.get("label", "")) == label:
			return entry
	return {}

func _find_npc(name: String) -> Dictionary:
	for npc in world.data.get("npcs", []) as Array:
		var entry: Dictionary = npc as Dictionary
		if str(entry.get("name", "")) == name:
			return entry
	return {}

func _settle_dialog() -> void:
	for i in range(30):
		if not world._dialog_open:
			return
		world._advance_dialog()
		await get_tree().create_timer(0.03).timeout

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().create_timer(0.03).timeout

func _count_summary() -> String:
	return "ev=%d cl=%d" % [world.puzzle.all_evidence().size(), world.puzzle.all_clues().size()]

func _log(text: String) -> void:
	log_lines.append(text)
	print(text)
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file != null:
		file.seek_end()
		file.store_line(text)
		file.close()

func _dismiss_chapter() -> void:
	if world.chapter != null and world.chapter.visible:
		world.chapter.skip()

func _finish(message: String, code: int) -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		for line in log_lines:
			file.store_line(line)
		file.close()
	print("FINISH " + message)
	get_tree().quit(code)
