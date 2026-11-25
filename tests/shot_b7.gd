extends Node

# B7 走查截图：16:9 安全区、继续存档落点一致、出示层对/错两路。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b07_fix_<标签>.png。

const OUT_DIR: String = "E:/gamejam/jam200/shots/"
const EvidencePanel = preload("res://ui/evidence_panel.gd")

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

	# 1) 16:9 安全区：960×540 视口，底部提示条 / 对话框不被裁切。
	world.force_scene("town_road")
	await get_tree().process_frame
	await _wait(0.15)
	get_tree().root.size = Vector2(960, 540)
	await get_tree().process_frame
	await _wait(0.15)
	await _save("safe_169")

	# 2) 存档落点：中段走到指定坐标 → 写盘 → 销毁旧世界 → 新世界从存档读回。
	var target: Vector2 = Vector2(430.0, 560.0)
	world.force_scene("town_road")
	await get_tree().process_frame
	world.player.pos = target
	world.player.dir = 2
	world._save_position()
	await _save("save_before")

	remove_child(world)
	world.queue_free()
	world = null
	await get_tree().process_frame

	var reloaded: PackedScene = load("res://world/world.tscn") as PackedScene
	world = reloaded.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	if world.chapter != null:
		world.chapter.skip()
	await get_tree().process_frame
	await _wait(0.15)
	var after_pos: Vector2 = world.player.pos
	print("SAVE_ROUNDTRIP before=", str(target), " after=", str(after_pos), " dir=", world.player.dir)
	if after_pos.distance_to(target) > 1.0:
		print("FAIL 存档落点不一致：", str(after_pos))
	await _save("save_after")

	# 3) 出示层：A3 干扰件 → ✗ 反应；有效件 → ✓ 反应。
	var panel: CanvasLayer = EvidencePanel.new()
	add_child(panel)
	panel.open("A3", Callable())
	await get_tree().process_frame
	# e_radio 是 decoy（下标 3）。
	panel._select_card(3)
	await get_tree().process_frame
	panel._confirm()
	await get_tree().process_frame
	await _wait(0.1)
	await _save("present_wrong")
	panel._finish_reaction()
	await get_tree().process_frame
	# e_draft 是有效件（下标 2）。
	panel._select_card(2)
	await get_tree().process_frame
	panel._confirm()
	await get_tree().process_frame
	await _wait(0.1)
	await _save("present_right")

	print("SHOT_B7 DONE")
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b07_fix_%s.png" % tag
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err, " size=", image.get_width(), "x", image.get_height())
