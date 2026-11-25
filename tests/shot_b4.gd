extends Node

# B4 走查截图：八向行走连续 6 帧、上手引导高亮、手记解谜 chips、长 toast。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b04_fix_<标签>.png。

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

	await _shot_walk()
	await _shot_guidance()
	await _shot_journal_chips()
	await _shot_toast()
	print("SHOT_B4 DONE")
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b04_fix_%s.png" % tag
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err)

func _shot_walk() -> void:
	world.force_scene("town_gate")
	await get_tree().process_frame
	await get_tree().process_frame
	var motion: Vector2 = Vector2(1.0, 0.0)
	var phases: Array[float] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
	var start: Vector2 = Vector2(400, 470)
	for frame_index in 6:
		var phase: float = phases[frame_index]
		world.player.reset(start + Vector2(frame_index * 10.0, 0.0), 2)
		world.player.walking = true
		world.player.walk_dir = motion
		world.player.step_phase = phase
		world.player.step_meter = 0.0
		world._update_nearby()
		await get_tree().process_frame
		await _save("walk_f%d" % (frame_index + 1))

func _shot_guidance() -> void:
	TurnState.reset()
	world.puzzle.reload()
	world.force_scene("langcheng_room")
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("guidance_target")

func _shot_journal_chips() -> void:
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
	await _save("journal_chips")
	JournalUI.close()

func _shot_toast() -> void:
	world.force_scene("town_gate")
	await get_tree().process_frame
	world.toast("组合失败 · 缺 茶几便签残片、门槛缝里的旧照片")
	await _wait(0.10)
	await _save("toast_long")
