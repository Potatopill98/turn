extends Node

# B8 交付截图：夜场拿到鞋 / 结局结算页 / 序章返程边 / soft / half。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b08_fix_<标签>.png。

const OUT_DIR: String = "E:/gamejam/jam200/shots/"

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

	# 1) 夜场拿到鞋：站到旧鞋热点，就近优先于周德海，触发拾取。
	world.force_scene("playground_night")
	await get_tree().process_frame
	world.player.pos = Vector2(560.0, 500.0)
	world._update_nearby()
	await _wait(0.2)
	var shoe: Dictionary = _spot_by_label("灯下的旧鞋")
	if not shoe.is_empty():
		world._use_spot(shoe)
	await _wait(0.8)
	await _save("night_shoes")

	# 2) 结局结算页：全收集 clear 档，列计数与缺失名。
	TurnState.reset()
	world.puzzle.reload()
	for eid in ["ev_letter", "ev_note", "ev_photo", "ev_screw", "ev_shoes", "ev_list", "ev_tape", "ev_mirror", "ev_draft", "ev_ticket"]:
		world.puzzle.add_evidence(str(eid))
	for cid in ["cl_score", "cl_lamp", "cl_tape", "cl_leave", "cl_return"]:
		world.puzzle.add_clue(str(cid))
	world._open_ending_panel("clear")
	await _wait(0.3)
	await _save("ending_review")
	world._close_ending_panel()

	# 3) 序章返程边：工位 → 出租屋 open_edge 出口在就近提示里可见。
	world.force_scene("langcheng_office")
	await get_tree().process_frame
	world.player.pos = Vector2(300.0, 500.0)
	world._update_nearby()
	await _wait(0.2)
	await _save("prologue_return")

	# 4) soft 档：只拿 2 件物证。
	TurnState.reset()
	world.puzzle.reload()
	world.puzzle.add_evidence("ev_letter")
	world.puzzle.add_evidence("ev_note")
	world._open_ending_panel("soft")
	await _wait(0.3)
	await _save("ending_soft")
	world._close_ending_panel()

	# 5) half 档：5 件物证。
	TurnState.reset()
	world.puzzle.reload()
	for eid in ["ev_letter", "ev_note", "ev_photo", "ev_screw", "ev_shoes"]:
		world.puzzle.add_evidence(str(eid))
	world._open_ending_panel("half")
	await _wait(0.3)
	await _save("ending_half")
	world._close_ending_panel()

	print("SHOT_B8 DONE")
	get_tree().quit(0)

func _spot_by_label(label: String) -> Dictionary:
	for spot in world.data.get("spots", []) as Array:
		var entry: Dictionary = spot as Dictionary
		if str(entry.get("label", "")) == label:
			return entry
	return {}

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b08_fix_%s.png" % tag
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err, " size=", image.get_width(), "x", image.get_height())
