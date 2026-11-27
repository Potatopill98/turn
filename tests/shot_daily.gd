extends Node

# R203 日常流程截图：白天招呼 → 扶秋千 → 傍晚 → 夜里选项 → 出示 → 小满 / 唐棠。

const OUT_DIR: String = "C:/Users/45803/AppData/Local/Temp/"

func _ready() -> void:
	TurnState.reset()
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	var world: Node = packed.instantiate()
	add_child(world)
	await _wait(0.6)
	if world.chapter != null:
		world.chapter.skip()
	await _wait(0.4)

	world.force_scene("playground_day")
	await _wait(0.8)
	var zhou: Dictionary = _npc(world, "p_zhou")
	world.player.pos = Vector2(292, 548)
	await _wait(0.2)
	world._say_npc(zhou)
	await _wait(0.25)
	await _finish_dialog(world)
	await _wait(0.3)
	await _shot("turn_daily_1_choice_day.png")
	world._choice_pick("help")
	await _wait(0.3)
	await _shot("turn_daily_2_help_line.png")
	world._close_dialog_now()
	var chore: Dictionary = _spot(world, "chore", "zhou_swing")
	world.player.pos = chore.get("pos", Vector2.ZERO) as Vector2
	world._use_chore(chore)
	await _wait(0.18)
	world._close_dialog_now()
	await _wait(0.15)
	await _shot("turn_daily_3_dusk.png")
	var bench: Dictionary = _spot(world, "wait", "")
	world.player.pos = bench.get("pos", Vector2.ZERO) as Vector2
	world._use_wait(bench)
	await _wait(2.2)
	await _shot("turn_daily_4_night.png")
	await _finish_dialog(world)
	await _wait(0.2)

	world.puzzle.add_evidence("ev_shoes")
	world._note_evidence_scene("ev_shoes")
	TurnState.unlock_item("ev_shoes")
	var zhou_night: Dictionary = _npc(world, "p_zhou")
	world.player.pos = world.npc_pos(zhou_night) + Vector2(0, 20)
	await _wait(0.2)
	world._say_npc(zhou_night)
	await _wait(0.2)
	await _finish_dialog(world)
	await _wait(0.3)
	await _shot("turn_daily_5_night_choices.png")
	world._choice_pick("present")
	await _wait(0.45)
	await _shot("turn_daily_6_evidence.png")
	if world._evidence_panel != null:
		world._evidence_panel.close()
	world._close_choice_layer()
	world._close_dialog_now()
	var journal: CanvasLayer = get_tree().root.get_node("JournalUI") as CanvasLayer
	journal.open()
	await _wait(0.5)
	journal._selection = {"kind": "evidence", "id": "ev_shoes"}
	journal._tab = "puzzle"
	journal._refresh()
	await _wait(0.4)
	await _shot("turn_daily_9_journal.png")
	journal.close()
	await _wait(0.3)

	world.set_phase(0, false)
	world.force_scene("town_road")
	await _wait(0.8)
	world.puzzle.add_evidence("ev_photo")
	var xiaoman: Dictionary = _npc(world, "p_xiaoman")
	world.player.pos = world.npc_pos(xiaoman) + Vector2(0, 26)
	await _wait(0.2)
	world._say_npc(xiaoman)
	await _wait(0.2)
	await _finish_dialog(world)
	await _wait(0.3)
	await _shot("turn_daily_7_xiaoman.png")
	world._close_choice_layer()
	world._close_dialog_now()

	world.set_phase(2, false)
	world.force_scene("street_cross")
	await _wait(0.8)
	world.puzzle.add_evidence("ev_list")
	var tang: Dictionary = _npc(world, "p_tang")
	world.player.pos = world.npc_pos(tang) + Vector2(-30, 26)
	await _wait(0.2)
	world._say_npc(tang)
	await _wait(0.2)
	await _finish_dialog(world)
	await _wait(0.3)
	await _shot("turn_daily_8_tang.png")

	get_tree().quit()

func _finish_dialog(world: Node) -> void:
	world._advance_dialog()
	await _wait(0.06)
	if bool(world._dialog_open):
		world._advance_dialog()
	await _wait(0.12)

func _npc(world: Node, id: String) -> Dictionary:
	for item in world.current_scene_data().get("npcs", []) as Array:
		var n: Dictionary = item as Dictionary
		if str(n.get("id", "")) == id:
			return n
	return {}

func _spot(world: Node, kind: String, chore_id: String) -> Dictionary:
	for item in world.current_scene_data().get("spots", []) as Array:
		var s: Dictionary = item as Dictionary
		if str(s.get("kind", "")) != kind:
			continue
		if not chore_id.is_empty() and str(s.get("chore", "")) != chore_id:
			continue
		return s
	return {}

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(OUT_DIR + name)
	print("SHOT " + name)
