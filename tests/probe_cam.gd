extends Node

# 相机构图探针：把玩家分别放在场景左/右，连续两帧截图对比，
# 验证"镜头真的跟着人平移、且不会把背景边界露出来"。

const OUT: String = "C:/Users/45803/AppData/Local/Temp/"

func _ready() -> void:
	TurnState.reset()
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var ps: PackedScene = load("res://world/world.tscn") as PackedScene
	var w: Node = ps.instantiate()
	add_child(w)
	await _frames(3)
	if w.chapter != null:
		w.chapter.skip()
	await _frames(3)

	w.force_scene("town_road")
	await _frames(6)
	await _place(w, Vector2(420, 700), "turn_cam_left.png", "left")
	await _place(w, Vector2(1120, 700), "turn_cam_right.png", "right")

	w.force_scene("house_hall")
	await _frames(6)
	await _place(w, Vector2(300, 470), "turn_cam_hall_left.png", "hall_left")
	await _place(w, Vector2(700, 470), "turn_cam_hall_right.png", "hall_right")

	get_tree().quit()

func _place(w: Node, at: Vector2, file_name: String, tag: String) -> void:
	w.player.pos = at
	w.call("_update_camera", true)
	await _frames(10)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(OUT + file_name)
	var cam_pos: Vector2 = w.get("_cam_pos") as Vector2
	var zoom: Vector2 = (w.camera as Camera2D).zoom
	print("[cam] ", tag, " player=", str(at), " cam=", str(cam_pos), " zoom=", str(zoom))

func _frames(n: int) -> void:
	var i: int = 0
	while i < n:
		await get_tree().process_frame
		i += 1
