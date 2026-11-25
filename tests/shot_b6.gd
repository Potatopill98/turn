extends Node

# B6 走查截图：补内容后的两个梦境、960 基准 HUD、1920×1200 放大不模糊不出界。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b06_fix_<标签>.png。

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

	await _scene_shot("dream_alley", "dream_alley")
	await _scene_shot("dream_box", "dream_box")
	await _scene_shot("town_road", "hud_960")

	# 放大到 1920×1200：stretch=canvas_items + aspect=keep，HUD 固定坐标不出界。
	get_tree().root.size = Vector2(1920, 1200)
	await get_tree().process_frame
	await _wait(0.2)
	await _save("hud_1920")

	print("SHOT_B6 DONE")
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _scene_shot(scene_id: String, tag: String) -> void:
	world.force_scene(scene_id)
	await get_tree().process_frame
	await _wait(0.15)
	await _save(tag)

func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b06_fix_%s.png" % tag
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err, " size=", image.get_width(), "x", image.get_height())
