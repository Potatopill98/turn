extends Node

# 标定用：把 walk / blocks / exits / spots / npcs 叠到小镇图上，一张图看清对齐情况。

func _ready() -> void:
	TurnState.reset()
	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	var w = packed.instantiate()
	add_child(w)
	await get_tree().process_frame
	if w.chapter != null:
		w.chapter.skip()
	await get_tree().process_frame
	w.force_scene("town_road")
	await get_tree().process_frame
	var d: Dictionary = w.current_scene_data()

	var layer: Node2D = Node2D.new()
	layer.draw.connect(func() -> void:
		for r in d.get("walk", []) as Array:
			layer.draw_rect(r as Rect2, Color(0.25, 1.0, 0.4, 0.22))
		for b in d.get("blocks", []) as Array:
			layer.draw_rect(b as Rect2, Color(1.0, 0.25, 0.2, 0.38))
			layer.draw_rect(b as Rect2, Color(1.0, 0.25, 0.2, 0.9), false, 2.0)
		for s in d.get("spots", []) as Array:
			layer.draw_circle((s as Dictionary)["pos"] as Vector2, 7.0, Color(0.2, 0.9, 1.0, 1.0))
		for e in d.get("exits", []) as Array:
			layer.draw_circle((e as Dictionary)["pos"] as Vector2, 11.0, Color(1.0, 1.0, 0.2, 1.0))
		for n in d.get("npcs", []) as Array:
			layer.draw_circle((n as Dictionary)["pos"] as Vector2, 9.0, Color(1.0, 0.2, 0.9, 1.0))
		layer.draw_circle(w.player.pos as Vector2, 6.0, Color(1, 1, 1, 1))
	)
	layer.z_index = 50
	w.add_child(layer)

	await get_tree().process_frame
	w.camera.zoom = Vector2(0.62, 0.62)
	w.camera.position = Vector2(768, 512)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("C:/Users/45803/AppData/Local/Temp/turn_blocks.png")
	print("BLOCKS OK  player=", w.player.pos)
	get_tree().quit()
