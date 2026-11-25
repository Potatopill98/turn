extends Node

# B5 走查截图：标题界面、推理台三态（选中两件 / 正解 / 错解）、出示选择层、终章三档。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b05_fix_<标签>.png。

const OUT_DIR: String = "E:/gamejam/jam200/shots/"
const PuzzleState = preload("res://world/puzzle_state.gd")

var world = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	TurnState.reset()
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	await _shot_title()

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

	await _shot_combo_slots()
	await _shot_combo_success()
	await _shot_combo_fail()
	await _shot_present_layer()
	await _shot_endings()
	print("SHOT_B5 DONE")
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b05_fix_%s.png" % tag
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err)

func _shot_title() -> void:
	var packed: PackedScene = load("res://title/title.tscn") as PackedScene
	if packed == null:
		print("FAIL title.tscn 加载失败")
		return
	var title: Node = packed.instantiate()
	add_child(title)
	await get_tree().process_frame
	await _wait(0.15)
	await _save("title")
	title.queue_free()
	await get_tree().process_frame

func _seed_evidence(amount: int) -> void:
	var ids: Array = PuzzleState.EVIDENCE_NAMES.keys()
	for i in mini(amount, ids.size()):
		world.puzzle.add_evidence(str(ids[i]))

func _shot_combo_slots() -> void:
	TurnState.reset()
	world.puzzle.reload()
	world.puzzle.add_evidence("ev_note")
	world.puzzle.add_evidence("ev_photo")
	world.puzzle.add_evidence("ev_screw")
	world.puzzle.add_evidence("ev_shoes")
	JournalUI.open()
	await _wait(0.12)
	JournalUI._select_right_mode("puzzle")
	JournalUI._toggle_slot("ev_note")
	JournalUI._toggle_slot("ev_photo")
	await _wait(0.12)
	await _save("combo_slots")
	JournalUI.close()

func _shot_combo_success() -> void:
	JournalUI.open()
	await _wait(0.12)
	JournalUI._select_right_mode("puzzle")
	JournalUI._toggle_slot("ev_note")
	JournalUI._toggle_slot("ev_photo")
	JournalUI._submit_combo()
	await _wait(0.12)
	await _save("combo_success")
	JournalUI.close()

func _shot_combo_fail() -> void:
	TurnState.reset()
	world.puzzle.reload()
	world.puzzle.add_evidence("ev_screw")
	world.puzzle.add_evidence("ev_tape")
	JournalUI.open()
	await _wait(0.12)
	JournalUI._select_right_mode("puzzle")
	JournalUI._toggle_slot("ev_screw")
	JournalUI._toggle_slot("ev_tape")
	JournalUI._submit_combo()
	await _wait(0.12)
	await _save("combo_fail")
	JournalUI.close()

func _shot_present_layer() -> void:
	TurnState.reset()
	world.puzzle.reload()
	world.force_scene("playground_night")
	await get_tree().process_frame
	world.puzzle.add_evidence("ev_letter")
	var npc: Dictionary = {}
	for candidate in world.current_scene_data().get("npcs", []) as Array:
		var c: Dictionary = candidate as Dictionary
		if str(c.get("id", "")) == "p_zhou":
			npc = c
	if not npc.is_empty():
		world._say_npc(npc)
		await _wait(0.12)
		await _save("present_layer")
		if world._present_layer_open():
			world._close_present_layer()

func _shot_endings() -> void:
	await _ending_tier("soft", 0, 0)
	await _ending_tier("half", 5, 1)
	await _ending_tier("clear", 10, 5)

func _ending_tier(tag: String, ev_n: int, clue_n: int) -> void:
	TurnState.reset()
	world.puzzle.reload()
	_seed_evidence(ev_n)
	for i in range(clue_n):
		world.puzzle.add_clue(str(PuzzleState.CLUE_NAMES.keys()[i]))
	TurnState.settle_collection_tier(ev_n, clue_n)
	world.force_scene("town_final")
	await get_tree().process_frame
	var review: Dictionary = {}
	for spot in world.current_scene_data().get("spots", []) as Array:
		var s: Dictionary = spot as Dictionary
		if str(s.get("kind", "")) == "ending_review":
			review = s
	if not review.is_empty():
		world._use_spot(review)
		await _wait(0.15)
		world._advance_dialog()
		await _wait(0.10)
		await _save("ending_" + tag)
		world._advance_dialog()
