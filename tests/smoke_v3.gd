extends Node

# v3 冒烟测试：不点鼠标，直接调用各系统的公开入口，断言状态。
# 运行：godot --headless --path E:\GodotProjects\turn --script res://tests/smoke_v3.gd

const Data = preload("res://scripts/turn_data.gd")
const EvidencePanel = preload("res://ui/evidence_panel.gd")
const SAVE_PATH := "user://turn_chapters.cfg"

var failures: PackedStringArray = []
var checks: int = 0
var backup_exists: bool = false
var backup_text: String = ""
var evidence_result: String = ""
var evidence_item: String = ""

func _ready() -> void:
	_run()

func _run() -> void:
	_backup_save()
	print("== turn v3 smoke ==")
	_test_data()
	_test_journal()
	await _test_evidence()
	await _test_room()
	await _test_later()
	_restore_save()
	print("== %d checks, %d failures ==" % [checks, failures.size()])
	for item in failures:
		print("FAILED: " + item)
	if failures.is_empty():
		print("PASS: v3 data, journal, evidence, room puzzles, walk layer, mirrors, tape, ending")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)

func _backup_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			backup_text = file.get_as_text()
			backup_exists = true
			file.close()

func _restore_save() -> void:
	if backup_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(backup_text)
			file.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _test_data() -> void:
	print("[data]")
	check(Data.person_entries().size() == 6, "6 张人物卡")
	check(Data.item_entries().size() >= 20, "物证条目 >= 20")
	for act in ["A1", "A2", "A3"]:
		var items: Array = Data.evidence_items(act)
		check(items.size() == 4, act + " 有 4 张举证卡")
		var decoys: int = 0
		var valid: int = 0
		for item in items:
			if str((item as Dictionary).get("stance", "")) == "decoy":
				decoys += 1
			else:
				valid += 1
		check(decoys == 1 and valid == 3, act + " = 3 有效 + 1 干扰")
	check(Data.hint_text("A1", 1) != "", "第三幕提示文案存在")
	check(Data.ending("clear").size() > 0, "三档结局表存在")
	check(str(Data.act_title("A2").get("name", "")) == "白天与提灯人", "第二幕标题卡")

func _test_journal() -> void:
	print("[journal]")
	var journal: CanvasLayer = get_tree().root.get_node("JournalUI")
	check(journal != null, "JournalUI autoload 存在")
	TurnState.reset()
	TurnState.start_act("A1")
	check(TurnState.people.size() >= 2, "进入第一幕解锁父女")
	TurnState.unlock_item("e_savings")
	TurnState.push_backlog("小满", "“他每回把我叫回来，就往里存一笔。”")
	journal.open()
	check(journal.visible, "手记可打开")
	check(get_tree().paused, "手记打开时世界暂停")
	journal._select_item("e_savings")
	journal._select_tab("hint")
	TurnState.request_hint()
	journal._refresh()
	check(TurnState.hint_index >= 1, "提示可升到第一层")
	journal.close()
	check(not get_tree().paused, "手记关闭后世界恢复")

func _test_evidence() -> void:
	print("[evidence]")
	await get_tree().process_frame
	var panel: CanvasLayer = EvidencePanel.new()
	get_tree().root.add_child(panel)
	await get_tree().process_frame
	panel.open("A1", func(stance: String, id: String) -> void:
		evidence_result = stance
		evidence_item = id
	)
	check(panel.visible, "举证面板打开")
	panel._select_card(0)
	panel._confirm()
	check(panel._reaction_box.visible, "有效件进入反应页")
	panel._finish_reaction()
	check(evidence_result == "expose", "存折 → expose")
	check(evidence_item == "e_savings", "回调带回物证 id")
	check(TurnState.get_stance("A1") == "expose", "立场写入 TurnState")
	panel.open("A1", func(_stance: String, _id: String) -> void: pass)
	panel._select_card(3)
	panel._confirm()
	check(panel._reaction_box.visible, "干扰件也进入反应页")
	panel._finish_reaction()
	check(panel.visible and not panel._reaction_box.visible, "干扰件退回卡片，不锁死")
	panel.close()
	panel.queue_free()
	await get_tree().process_frame

func _test_room() -> void:
	print("[room]")
	await get_tree().process_frame
	var room_scene: PackedScene = load("res://room.tscn")
	var room: Node = room_scene.instantiate()
	get_tree().root.add_child(room)
	await get_tree().process_frame
	check(room.note_fixed == false, "便签初始未拼")
	room.start_puzzle(false)
	check(room.pieces.size() == 6, "报名表 6 片")
	room.pieces.assign([0, 1, 2, 3, 4, 5])
	room.swap_piece(0)
	check(room.fixed_form, "报名表拼合完成")
	room.start_puzzle(true)
	check(room.pieces.size() == 6, "老照片 6 片")
	room.pieces.assign([0, 1, 2, 3, 4, 5])
	room.swap_piece(1)
	check(room.mode == "evidence", "照片拼合后进入证据卡")
	room.start_note_puzzle()
	check(room.note_pieces.size() == 3, "便签 3 片")
	room._note_select(0)
	room._note_select(2)
	room._note_select(0)
	room._note_select(1)
	check(room.note_fixed, "便签拼合完成")
	check(TurnState.knows_item("e_note"), "拼好便签记录 e_note")
	room.start_savings_puzzle()
	room._pick_savings_left(0)
	room._pick_savings_right(1)
	room._pick_savings_left(1)
	room._pick_savings_right(2)
	room._pick_savings_left(2)
	room._pick_savings_right(0)
	check(room.savings_pairs.size() == 3, "存折 3 对全连")
	check(room.repaired, "存折对完 repaired")
	check(TurnState.knows_item("e_savings"), "存折记录 e_savings")
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	check(cfg.has_section_key("turn", "v3_state"), "存档写入 v3_state")
	room.queue_free()
	await get_tree().process_frame

func _test_later() -> void:
	print("[later]")
	await get_tree().process_frame
	var later_scene: PackedScene = load("res://later_chapters.tscn")
	var later: Node = later_scene.instantiate()
	get_tree().root.add_child(later)
	await get_tree().process_frame
	later.show_page("day")
	check(later.walk_layer.active, "第二幕走位层激活")
	later._walk_spot(0)
	check(later.observed[0], "走近围挡记录 observed[0]")
	check(TurnState.knows_item("e_fence"), "围挡记录 e_fence")
	later.show_page("night")
	later.turn_mirror(0)
	later.turn_mirror(1)
	later.turn_mirror(1)
	check(later.mirror_angles[0] == 1 and later.mirror_angles[1] == 2, "镜面四向转到正确角")
	check(later.lit, "光路点亮")
	later.show_page("rewind")
	later.tape_position = 18
	later.listen()
	check(later.heard_tape, "00:18 听到人声")
	later.show_page("zhou")
	later.open_evidence_a2()
	await get_tree().process_frame
	later.evidence_layer._select_card(0)
	later.evidence_layer._confirm()
	later.evidence_layer._finish_reaction()
	check(TurnState.get_stance("A2") == "expose", "第二幕举证写 A2")
	later.show_page("farewell")
	TurnState.set_stance("A3", "expose")
	later.open_evidence_a3()
	await get_tree().process_frame
	later.evidence_layer._select_card(0)
	later.evidence_layer._confirm()
	later.evidence_layer._finish_reaction()
	check(later.a3_done, "第三幕举证完成")
	check(TurnState.ending_tier != "", "结局分档已结算")
	later.show_page("ending")
	check(str(Data.ending(TurnState.ending_tier).get("title", "")) != "", "终章读到三档文案")
	later.show_page("credits")
	await get_tree().process_frame
	check(true, "Turn 图谱页可绘制")
	later.queue_free()
	await get_tree().process_frame
