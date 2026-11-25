extends Node

# 探索模式走查截图：每个地点一张，960×600。

const OUT: String = "C:/Users/45803/AppData/Local/Temp/"
const SHOTS: Array = [
	"langcheng_room",
	"langcheng_office",
	"langcheng_factory",
	"town_gate",
	"town_road",
	"old_house_yard",
	"house_hall",
	"basement",
	"playground_day",
	"playground_night",
	"street_cross",
	"town_final",
	"dream_classroom",
	"dream_alley",
	"dream_postbox",
	"dream_box",
	"dream_swing",
	"dream_dirt_road",
	"dream_station",
]

var world = null

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

	for id in SHOTS:
		world.force_scene(str(id))
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = OUT + "turn_world_" + str(id) + ".png"
		var err: int = image.save_png(path)
		print("SHOT %-22s err=%d" % [str(id), err])
	print("DONE")
	get_tree().quit()
