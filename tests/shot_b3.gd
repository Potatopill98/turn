extends Node

# B3 走查截图：拾取短名、开门 reveal 门扇退净、梦醒 veil、手记解谜分区与推论回看、锁拒绝提示。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b03_fix_<标签>.png。

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

	await _shot_pickup_label()
	await _shot_door_reveal()
	await _shot_wake_veil()
	await _shot_journal_puzzle()
	await _shot_clue_detail()
	await _shot_lock_refusal()
	print("SHOT_B3 DONE")
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b03_fix_%s.png" % tag
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err)

func _find_exit_to(target: String) -> Dictionary:
	for exit in world.current_scene_data().get("exits", []) as Array:
		var e: Dictionary = exit as Dictionary
		if str(e.get("to", "")) == target:
			return e
	return {}

func _shot_pickup_label() -> void:
	world.force_scene("town_gate")
	await get_tree().process_frame
	world.fx.play_pickup(Vector2(300, 300), "茶几便签残片", world._journal_button, Callable())
	await _wait(0.22)
	await _save("pickup_label")
	await _wait(0.40)

func _shot_door_reveal() -> void:
	world.force_scene("town_gate")
	await get_tree().process_frame
	world.fx.play_door_open(Callable())
	await _wait(0.70)
	var done: Array = [false]
	world.fx.door_reveal(func() -> void: done[0] = true)
	await _wait(0.05)
	await _save("door_reveal")
	while not bool(done[0]):
		await get_tree().process_frame

func _shot_wake_veil() -> void:
	world.force_scene("town_gate")
	await get_tree().process_frame
	world.fx.play_wake_out(Callable(), Callable())
	await _wait(0.28)
	await _save("wake_veil")
	await _wait(0.50)

func _shot_journal_puzzle() -> void:
	world.force_scene("house_hall")
	await get_tree().process_frame
	world.puzzle.add_evidence("ev_photo")
	world.puzzle.add_evidence("ev_note")
	world.puzzle.add_evidence("ev_screw")
	world.puzzle.add_evidence("ev_shoes")
	world.puzzle.try_combine("ev_note", "ev_photo")
	world.puzzle.try_combine("ev_screw", "ev_shoes")
	JournalUI.open()
	await _wait(0.15)
	JournalUI._select_right_mode("puzzle")
	await _wait(0.15)
	await _save("journal_puzzle")

func _shot_clue_detail() -> void:
	JournalUI._select_puzzle("clue", "cl_score")
	await _wait(0.15)
	await _save("clue_detail")
	JournalUI.close()

func _shot_lock_refusal() -> void:
	TurnState.reset()
	world.puzzle.reload()
	world.force_scene("town_road")
	await get_tree().process_frame
	var exit: Dictionary = _find_exit_to("town_final")
	if exit.is_empty():
		print("  FAIL lock_refusal 找不到去 town_final 的出口")
		return
	world.player.pos = exit.get("pos", Vector2(560, 725)) as Vector2
	world._update_nearby()
	world._use_exit(exit)
	await _wait(0.30)
	await _save("lock_refusal")
