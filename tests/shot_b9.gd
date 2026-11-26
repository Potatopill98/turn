extends Node

# 终验补齐截图：A2 出示面板接周德海 / 尾声两件并排组合 + 铁柜出口 / 11·6 全收集结算页。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b09_fix_<标签>.png。

const OUT_DIR: String = "E:/gamejam/jam200/shots/"
const PuzzleState = preload("res://world/puzzle_state.gd")

var world = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	TurnState.reset()
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	if packed == null:
		print("FAIL world.tscn 加载失败")
		get_tree().quit(1)
		return
	world = packed.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	if world.chapter != null:
		world.chapter.skip()
	await get_tree().process_frame

	# 1) A2 面板：夜场周德海交谈后打开四卡选择层（对 / 错两路）。
	world.force_scene("playground_night")
	await get_tree().process_frame
	var zhou: Dictionary = _npc_by_id("p_zhou")
	if not zhou.is_empty():
		world._say_npc(zhou)
	await get_tree().process_frame
	await _wait(0.25)
	await _save("a2_panel")
	if world._evidence_panel != null:
		world._evidence_panel.close()

	# 2) 尾声工厂：拾工装袖标，与草稿并排合成 cl_factory，铁柜对照出口打开。
	TurnState.reset()
	world.puzzle.reload()
	world.force_scene("langcheng_factory")
	await get_tree().process_frame
	world.puzzle.add_evidence("ev_draft")
	var tag: Dictionary = _spot_by_label("挂着的工装")
	if not tag.is_empty():
		world._use_spot(tag)
	await _wait(0.3)
	world.puzzle.combine_attempt("ev_draft", "ev_tag")
	await _wait(0.2)
	var locker: Dictionary = _spot_by_label("更衣室铁柜")
	if not locker.is_empty():
		world._use_spot(locker)
	await _wait(0.4)
	await _save("factory_combo")

	# 3) 全收集结算页：11 物证 / 6 推论，计数与缺失名齐备。
	TurnState.reset()
	world.puzzle.reload()
	for eid in PuzzleState.EVIDENCE_NAMES.keys():
		world.puzzle.add_evidence(str(eid))
	for cid in PuzzleState.CLUE_NAMES.keys():
		world.puzzle.add_clue(str(cid))
	world._open_ending_panel("clear")
	await _wait(0.3)
	await _save("ending_review_full")
	world._close_ending_panel()

	print("SHOT_B9 DONE")
	get_tree().quit(0)

func _spot_by_label(label: String) -> Dictionary:
	for spot in world.data.get("spots", []) as Array:
		var entry: Dictionary = spot as Dictionary
		if str(entry.get("label", "")) == label:
			return entry
	return {}

func _npc_by_id(person_id: String) -> Dictionary:
	for npc in world.current_scene_data().get("npcs", []) as Array:
		var entry: Dictionary = npc as Dictionary
		if str(entry.get("id", "")) == person_id:
			return entry
	return {}

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b09_fix_%s.png" % tag
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err, " size=", image.get_width(), "x", image.get_height())
