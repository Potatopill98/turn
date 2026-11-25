extends Node

# B2 走查截图：NPC 物证分支、日入夜出口、堂屋组合热点、夜场可达。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b02_fix_<标签>.png。

const OUT_DIR: String = "E:/gamejam/jam200/shots/"

var world = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	TurnState.reset()
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

	await _shot_npc_evidence()
	await _shot_day_night_exit()
	await _shot_hall_combo()
	await _shot_night_scene()
	print("SHOT_B2 DONE")
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b02_fix_%s.png" % tag
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err)

func _find_npc(person_id: String) -> Dictionary:
	for npc in world.current_scene_data().get("npcs", []) as Array:
		var n: Dictionary = npc as Dictionary
		if str(n.get("id", "")) == person_id:
			return n
	return {}

func _find_exit_to(target: String) -> Dictionary:
	for exit in world.current_scene_data().get("exits", []) as Array:
		var e: Dictionary = exit as Dictionary
		if str(e.get("to", "")) == target:
			return e
	return {}

func _shot_npc_evidence() -> void:
	world.force_scene("town_road")
	await get_tree().process_frame
	world.puzzle.add_evidence("ev_letter")
	var npc: Dictionary = _find_npc("p_zhang")
	if npc.is_empty():
		_fail_save("npc_evidence", "p_zhang 不存在")
		return
	world.player.pos = npc.get("pos", Vector2(480, 480)) as Vector2
	world._update_nearby()
	world._say_npc(npc)
	await _wait(0.45)
	await _save("npc_evidence")
	world._advance_dialog()
	world._advance_dialog()
	world._close_dialog_now()

func _shot_day_night_exit() -> void:
	world.force_scene("playground_day")
	await get_tree().process_frame
	var night_exit: Dictionary = _find_exit_to("playground_night")
	if not night_exit.is_empty():
		world.player.pos = night_exit.get("pos", Vector2(760, 560)) as Vector2
		world._update_nearby()
	await _wait(0.25)
	await _save("day_night_exit")

func _shot_hall_combo() -> void:
	world.force_scene("house_hall")
	await get_tree().process_frame
	await _wait(0.25)
	await _save("hall_combo")

func _shot_night_scene() -> void:
	world.force_scene("playground_night")
	await get_tree().process_frame
	world._close_dialog_now()
	await _wait(0.25)
	await _save("night_scene")

func _fail_save(tag: String, reason: String) -> void:
	print("  FAIL ", tag, " ", reason)
