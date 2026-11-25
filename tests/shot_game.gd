extends Node

# 临时截图：便签、存折、报名表拼图、镜面夜、磁带波形、终章、图谱。
# 不参与正式流程，交付前可删。

const OUT_DIR := "C:/Users/45803/AppData/Local/Temp/"
const Progress = preload("res://chapter_progress.gd")
const SAVE_PATH := "user://turn_chapters.cfg"

var _save_backup: String = ""

func _ready() -> void:
	await get_tree().process_frame
	if FileAccess.file_exists(SAVE_PATH):
		_save_backup = FileAccess.get_file_as_string(SAVE_PATH)
	Progress.fresh(get_tree())
	TurnState.reset()
	await _shot_prologue()
	await _shot_room()
	await _shot_later()
	_restore_save()
	get_tree().quit()

func _restore_save() -> void:
	if _save_backup.is_empty():
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_save_backup)

func _shot_prologue() -> void:
	var scene: PackedScene = load("res://prologue.tscn")
	var prologue: Node = scene.instantiate()
	get_tree().root.add_child(prologue)
	await _wait(0.4)
	prologue.chapter_player.skip()
	await _wait(0.2)
	prologue.title_card.skip()
	await _wait(0.6)
	await _shot("turn_prologue.png")
	prologue.chapter_select.open(Callable())
	await _wait(0.4)
	await _shot("turn_chapters.png")
	prologue.chapter_select.close_panel()
	await _wait(0.2)
	prologue.queue_free()
	await _wait(0.3)

func _shot_room() -> void:
	var room_scene: PackedScene = load("res://room.tscn")
	var room: Node = room_scene.instantiate()
	get_tree().root.add_child(room)
	await _wait(0.4)
	room.chapter_player.skip()
	await _wait(0.2)
	room.title_card.skip()
	await _wait(0.5)
	room.start_note_puzzle()
	await _wait(0.4)
	await _shot("turn_note.png")
	room.start_savings_puzzle()
	await _wait(0.4)
	await _shot("turn_savings.png")
	room.start_puzzle(false)
	await _wait(0.4)
	await _shot("turn_form.png")
	room.queue_free()
	await _wait(0.3)

func _shot_later() -> void:
	var later_scene: PackedScene = load("res://later_chapters.tscn")
	var later: Node = later_scene.instantiate()
	get_tree().root.add_child(later)
	await _wait(0.4)
	later.chapter_player.skip()
	await _wait(0.2)
	later.title_card.skip()
	await _wait(0.5)
	await _shot("turn_day.png")
	later.show_page("street")
	await _wait(0.4)
	await _shot("turn_street.png")
	later.show_page("night")
	later.turn_mirror(0)
	later.turn_mirror(1)
	later.turn_mirror(1)
	await _wait(0.4)
	await _shot("turn_night.png")
	later.show_page("rewind")
	later.tape_position = 18
	later.note = "留言：“阿棠，明天下午两点，桥下等。”"
	await _wait(0.4)
	await _shot("turn_tape.png")
	TurnState.start_act("A1")
	TurnState.unlock_item("e_savings")
	TurnState.unlock_item("e_form")
	TurnState.set_stance("A1", "expose")
	TurnState.set_stance("A2", "half")
	TurnState.set_stance("A3", "soft")
	TurnState.settle_ending()
	TurnState.mark_letter(1)
	later.show_page("ending")
	await _wait(0.4)
	await _shot("turn_ending.png")
	later.show_page("credits")
	await _wait(0.4)
	await _shot("turn_graph.png")
	later.queue_free()
	await _wait(0.3)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUT_DIR + name
	var result: Error = image.save_png(path)
	print("SHOT " + path + " " + error_string(result))
