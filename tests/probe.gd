extends Node

func _ready() -> void:
	TurnState.reset()
	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	var world = packed.instantiate()
	add_child(world)
	await get_tree().process_frame
	if world.chapter != null:
		world.chapter.skip()
	await get_tree().process_frame
	world.force_scene("town_road")
	await get_tree().process_frame
	print("PLAYER ", world.player.pos, "  CAMERA ", world.camera.position, "  ZOOM ", world.camera.zoom)
	var d: Dictionary = world.current_scene_data()
	print("BOUNDS ", d.get("bounds"), " WALK ", d.get("walk"))
	print("VIEW ", world.view.position, " SIZE ", world.view.size if "size" in world.view else "n/a")
	get_tree().quit()
