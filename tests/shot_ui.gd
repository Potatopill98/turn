extends Node

# 临时 UI 截图：跑一次，导出三张 PNG，用来检查 v3 面板排版。
# 不参与正式流程，交付前可删。

const EvidencePanel = preload("res://ui/evidence_panel.gd")
const OUT_DIR := "C:/Users/45803/AppData/Local/Temp/"

func _ready() -> void:
	await get_tree().process_frame
	TurnState.reset()
	TurnState.start_act("A1")
	TurnState.unlock_item("e_savings")
	TurnState.unlock_item("e_form")
	TurnState.unlock_item("e_note")
	TurnState.unlock_item("e_score")
	TurnState.push_backlog("小满", "“他每回把我叫回来，就往里存一笔。”")
	TurnState.push_backlog("父亲", "“弦是我昨晚换的。报名表也是我收的。”")
	TurnState.request_hint()
	var journal: CanvasLayer = get_tree().root.get_node("JournalUI")
	journal.open()
	await _wait(0.8)
	await _shot("turn_journal.png")
	var puzzle: RefCounted = journal.puzzle as RefCounted
	puzzle.add_evidence("ev_screw")
	puzzle.add_evidence("ev_shoes")
	puzzle.add_evidence("ev_note")
	puzzle.add_evidence("ev_photo")
	puzzle.add_evidence("ev_tape")
	puzzle.try_combine("ev_note", "ev_photo")
	journal._select_right_mode("puzzle")
	journal._toggle_slot("ev_screw")
	journal._toggle_slot("ev_shoes")
	await _wait(0.3)
	journal._submit_combo()
	await _wait(0.4)
	await _shot("turn_journal_puzzle.png")
	journal._select_right_mode("legacy")
	journal.close()
	await _wait(0.3)
	var panel: CanvasLayer = EvidencePanel.new()
	add_child(panel)
	panel.open("A1", func(_stance: String, _id: String) -> void: pass)
	await _wait(0.5)
	panel._select_card(0)
	await _wait(0.3)
	await _shot("turn_evidence.png")
	panel.close()
	panel.queue_free()
	await _wait(0.2)
	get_tree().quit()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUT_DIR + name
	var result: Error = image.save_png(path)
	print("SHOT " + path + " " + error_string(result))
