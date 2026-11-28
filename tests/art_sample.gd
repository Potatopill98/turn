extends Node

const OUT_DIR: String = "E:/gamejam/Turn_美术接入预览/"
var world: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	world = packed.instantiate()
	add_child(world)
	await get_tree().create_timer(0.8).timeout
	await _shot("00_标题")
	GameState.set_flag("visited_hall")
	GameState.add_evidence("ev_photo")
	GameState.add_evidence("ev_note")
	world.call("debug_load", "street_west", 1380.0)
	await get_tree().create_timer(0.6).timeout
	world.call("debug_talk", "p_xiaoman")
	await get_tree().create_timer(0.5).timeout
	await _shot("01_对话与立绘")
	world.call("debug_advance", 1)
	await get_tree().create_timer(0.4).timeout
	await _shot("02_选项与纸面UI")
	world.call("debug_load", "playground", 560.0)
	await get_tree().create_timer(0.6).timeout
	await _shot("03_游乐场角色")
	GameState.phase = 2
	world.call("debug_load", "playground", 1500.0)
	await get_tree().create_timer(0.6).timeout
	await _shot("03b_游乐场_入夜")
	GameState.phase = 0
	world.call("debug_load", "house_hall", 900.0)
	await get_tree().create_timer(0.6).timeout
	await _shot("04_客厅道具")
	world.call("debug_load", "street_west", 300.0)
	await get_tree().create_timer(0.5).timeout
	var ui_node: Control = world.get("ui") as Control
	if ui_node != null:
		ui_node.call("open_evidence", ["ev_photo", "ev_note", "ev_score"])
	await get_tree().create_timer(0.3).timeout
	await _shot("05_物证面板")
	if ui_node != null:
		ui_node.call("close_evidence")
	world.call("debug_load", "station", 300.0)
	await get_tree().create_timer(0.5).timeout
	await _shot("06_车站")
	world.call("debug_load", "town_final", 1000.0)
	await get_tree().create_timer(0.5).timeout
	await _shot("07_镇口")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _shot(name: String) -> void:
	await get_tree().create_timer(0.25).timeout
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(OUT_DIR + name + ".png")
		print("ART SHOT " + name + " " + str(image.get_width()) + "x" + str(image.get_height()))
	else:
		print("ART SHOT FAILED " + name)
