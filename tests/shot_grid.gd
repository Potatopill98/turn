extends Node

# 标定用截图：把小镇总图缩到一屏，叠加 100px 世界坐标网格，用于手标建筑碰撞框。

const OUT: String = "C:/Users/45803/AppData/Local/Temp/"
const SKIN = preload("res://ui/theme.gd")

var world = null
var overlay: Node2D = null

func _ready() -> void:
	TurnState.reset()
	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	world = packed.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	if world.chapter != null:
		world.chapter.skip()
	await get_tree().process_frame

	world.force_scene("town_road")
	world.set_process(false)
	world.camera.zoom = Vector2(0.6, 0.6)
	world.camera.position = Vector2(768, 512)

	overlay = GridOverlay.new()
	overlay.z_index = 100
	add_child(overlay)

	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: int = image.save_png(OUT + "turn_world_grid.png")
	print("GRID err=%d" % err)
	get_tree().quit()

class GridOverlay extends Node2D:
	var font: SystemFont

	func _ready() -> void:
		font = SKIN.font()
		z_index = 100

	func _draw() -> void:
		for x in range(0, 1537, 100):
			draw_line(Vector2(x, 0), Vector2(x, 1024), Color(1, 0.2, 0.2, 0.55), 1.0)
			for y in range(0, 1025, 100):
				draw_string(font, Vector2(x + 3, y + 14), "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.92))
		for y in range(0, 1025, 100):
			draw_line(Vector2(0, y), Vector2(1536, y), Color(0.2, 0.6, 1, 0.55), 1.0)
