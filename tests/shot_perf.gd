extends Node

# 演出走查：对话打字机、标题卡转场、toast、呼吸圈。

const OUT: String = "C:/Users/45803/AppData/Local/Temp/"

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

	world.force_scene("town_road")
	for i in 4:
		await get_tree().process_frame
	await _shot("perf_1_town")

	world.say("门口摆着两双鞋。一双大的，一双小的，都摆得很正——像随时有人会回来穿。", "旁白")
	await get_tree().create_timer(0.18).timeout
	await _shot("perf_2_dialog_typing")
	await get_tree().create_timer(1.10).timeout
	await _shot("perf_3_dialog_full")

	world.toast("手记 +1 · 秋千")
	await get_tree().create_timer(0.12).timeout
	await _shot("perf_4_toast")

	world.travel("house_hall", "door")
	await get_tree().create_timer(0.42).timeout
	await _shot("perf_5_title")
	await get_tree().create_timer(1.30).timeout
	await _shot("perf_6_hall")
	print("PERF DONE")
	get_tree().quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: int = image.save_png(OUT + "turn_" + name + ".png")
	print("SHOT %-22s err=%d" % [name, err])
