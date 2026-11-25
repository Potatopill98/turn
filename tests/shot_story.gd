extends Node

# 章节播放器走查截图：序章 / 第一幕 / 选择点 / 第二幕 / 尾声。
# 不参与正式流程。

const OUT_DIR := "C:/Users/45803/AppData/Local/Temp/"
const ChapterPlayer = preload("res://ui/chapter_player.gd")

var player: CanvasLayer

func _ready() -> void:
	await get_tree().process_frame
	player = ChapterPlayer.new()
	add_child(player)
	await _play_and_shot("prologue", "turn_story_prologue.png")
	await _play_and_shot("first", "turn_story_first.png")
	await _choice_shot("first_dream", "turn_story_choice.png")
	await _play_and_shot("second", "turn_story_second.png")
	await _play_and_shot("epilogue", "turn_story_epilogue.png")
	get_tree().quit()

func _play_and_shot(id: String, filename: String) -> void:
	print("shot: ", id)
	player._finish()
	player.play(id, Callable())
	await _wait(0.5)
	await _shot(filename)

func _choice_shot(id: String, filename: String) -> void:
	print("shot: ", id)
	player._finish()
	player.play(id, Callable())
	await _wait(0.3)
	var found: int = -1
	for i in player._beats.size():
		var beat: Dictionary = player._beats[i] as Dictionary
		if beat.has("options"):
			found = i
			break
	if found >= 0:
		player._index = found
		player._show_beat()
	await _wait(0.4)
	await _shot(filename)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err: int = image.save_png(OUT_DIR + filename)
	print("shot result: ", filename, " err=", err, " beats=", player._beats.size(), " idx=", player._index)
