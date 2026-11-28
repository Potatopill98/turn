extends Control

const PlaceholderArt = preload("res://scripts/placeholder_art.gd")
const SceneDefs = preload("res://data/scene_defs.gd")

var tex_dialog_panel: Texture2D = null
var tex_name_plate: Texture2D = null
var tex_portrait_frame: Texture2D = null
var tex_choice_row: Texture2D = null
var tex_toast: Texture2D = null
var tex_prompt: Texture2D = null
var tex_title_bg: Texture2D = null
var tex_chapter_block: Texture2D = null
var tex_focus_frame: Texture2D = null
var tex_ending_stay: Texture2D = null
var tex_ending_leave: Texture2D = null
var tex_hud_top: Texture2D = null
var tex_hud_bottom: Texture2D = null
var portrait_cache: Dictionary = {}
var evidence_textures: Dictionary = {}

signal choice_selected(id: String)
signal evidence_selected(id: String)
signal dialog_finished
signal title_started
signal restart_requested

var title_open: bool = true
var game_open: bool = false
var dialog_open: bool = false
var dialog_speaker: String = ""
var dialog_style: String = ""
var dialog_lines: Array[String] = []
var dialog_index: int = 0
var dialog_chars: float = 0.0
var dialog_choices: Array = []
var choices_visible: bool = false
var choice_index: int = 0
var evidence_open: bool = false
var evidence_items: Array[String] = []
var evidence_index: int = 0
var journal_open: bool = false
var journal_tab: int = 0
var journal_selection: int = 0
var toast_text: String = ""
var toast_life: float = 0.0
var toast_total: float = 0.0
var toast_age: float = 0.0
var prompt_text: String = ""
var fade_alpha: float = 0.0
var ending_open: bool = false
var ending_kind: String = "keep"
var chapter_open: bool = false
var chapter_step: int = 0
var chapter_age: float = 0.0
var quest: Dictionary = {}
var _t: float = 0.0
var _title_pulse: float = 0.0
var mouse_pos: Vector2 = Vector2(-1.0, -1.0)
var hover_choice: int = -1
var hover_evidence: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_load_ui_art()
	set_process(true)
	set_process_input(true)
	queue_redraw()


func _load_ui_art() -> void:
	tex_dialog_panel = _safe_texture("res://art/ui/ui_07_dialog_panel.png")
	tex_name_plate = _safe_texture("res://art/ui/ui_09_name_plate.png")
	tex_portrait_frame = _safe_texture("res://art/ui/ui_08_portrait_frame.png")
	tex_choice_row = _safe_texture("res://art/ui/ui_10_choice_row.png")
	tex_toast = _safe_texture("res://art/ui/ui_21_toast.png")
	tex_prompt = _safe_texture("res://art/ui/ui_22_prompt.png")
	tex_title_bg = _safe_texture("res://art/ui/ui_01_title_bg.png")
	tex_chapter_block = _safe_texture("res://art/ui/ui_02_title_block.png")
	tex_focus_frame = _safe_texture("res://art/ui/ui_29_focus_frame.png")
	tex_ending_stay = _safe_texture("res://art/ui/ui_23_ending_stay.png")
	tex_ending_leave = _safe_texture("res://art/ui/ui_24_ending_leave.png")
	tex_hud_top = _safe_texture("res://art/ui/ui_04_hud_top.png")
	tex_hud_bottom = _safe_texture("res://art/ui/ui_05_hud_bottom.png")
	if not PlaceholderArt.USE_SCENE_ILLUSTRATIONS:
		return
	evidence_textures["ev_photo"] = _safe_texture("res://art/evidence/ev-01A.png")
	evidence_textures["ev_note"] = _safe_texture("res://art/evidence/ev-02.png")
	evidence_textures["ev_score"] = _safe_texture("res://art/evidence/ev-03.png")
	evidence_textures["ev_screw"] = _safe_texture("res://art/evidence/ev-04.png")
	evidence_textures["ev_shoes"] = _safe_texture("res://art/evidence/ev-05.png")
	evidence_textures["ev_mirror"] = _safe_texture("res://art/evidence/ev-06.png")
	evidence_textures["ev_list"] = _safe_texture("res://art/evidence/ev-07.png")
	evidence_textures["ev_tape"] = _safe_texture("res://art/evidence/ev-08.png")


func _safe_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	return null


func _draw_ui_panel(texture: Texture2D, rect: Rect2, margin: float, alpha: float) -> bool:
	if texture == null:
		return false
	_draw_nine_patch(texture, rect, margin, Color(1.0, 1.0, 1.0, alpha))
	return true


func _draw_nine_patch(texture: Texture2D, rect: Rect2, margin: float, tint: Color) -> void:
	if texture == null or rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var tex_size: Vector2 = texture.get_size()
	var m: float = min(margin, min(tex_size.x, tex_size.y) * 0.5)
	if m <= 0.0:
		draw_texture_rect(texture, rect, false, tint)
		return
	var dm: float = min(m, min(rect.size.x, rect.size.y) * 0.5)
	var sx: float = tex_size.x
	var sy: float = tex_size.y
	# 四角
	draw_texture_rect_region(texture, Rect2(rect.position, Vector2(dm, dm)), Rect2(0.0, 0.0, m, m), tint)
	draw_texture_rect_region(texture, Rect2(rect.position.x + rect.size.x - dm, rect.position.y, dm, dm), Rect2(sx - m, 0.0, m, m), tint)
	draw_texture_rect_region(texture, Rect2(rect.position.x, rect.position.y + rect.size.y - dm, dm, dm), Rect2(0.0, sy - m, m, m), tint)
	draw_texture_rect_region(texture, Rect2(rect.position.x + rect.size.x - dm, rect.position.y + rect.size.y - dm, dm, dm), Rect2(sx - m, sy - m, m, m), tint)
	# 四边
	draw_texture_rect_region(texture, Rect2(rect.position.x + dm, rect.position.y, rect.size.x - dm * 2.0, dm), Rect2(m, 0.0, sx - m * 2.0, m), tint)
	draw_texture_rect_region(texture, Rect2(rect.position.x + dm, rect.position.y + rect.size.y - dm, rect.size.x - dm * 2.0, dm), Rect2(m, sy - m, sx - m * 2.0, m), tint)
	draw_texture_rect_region(texture, Rect2(rect.position.x, rect.position.y + dm, dm, rect.size.y - dm * 2.0), Rect2(0.0, m, m, sy - m * 2.0), tint)
	draw_texture_rect_region(texture, Rect2(rect.position.x + rect.size.x - dm, rect.position.y + dm, dm, rect.size.y - dm * 2.0), Rect2(sx - m, m, m, sy - m * 2.0), tint)
	# 中心
	draw_texture_rect_region(texture, Rect2(rect.position.x + dm, rect.position.y + dm, rect.size.x - dm * 2.0, rect.size.y - dm * 2.0), Rect2(m, m, sx - m * 2.0, sy - m * 2.0), tint)


func _process(delta: float) -> void:
	_t += delta
	if dialog_open and not choices_visible:
		if dialog_index < dialog_lines.size():
			dialog_chars += delta * 38.0
			var line: String = dialog_lines[dialog_index]
			if dialog_chars > float(line.length()):
				dialog_chars = float(line.length())
			if dialog_chars >= float(line.length()) and dialog_index == dialog_lines.size() - 1 and dialog_choices.size() > 0:
				choices_visible = true
	if toast_life > 0.0:
		toast_life -= delta
		if toast_life < 0.0:
			toast_life = 0.0
	toast_age += delta
	if chapter_open:
		chapter_age += delta
	_title_pulse += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		mouse_pos = motion.position
		_update_hover()
		queue_redraw()
		return
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			mouse_pos = click.position
			_on_click(click.position)
			accept_event()


func _update_hover() -> void:
	hover_choice = -1
	hover_evidence = -1
	if dialog_open and choices_visible:
		var cr: Rect2 = _choice_panel_rect()
		if cr.has_point(mouse_pos):
			hover_choice = int(floor((mouse_pos.y - (cr.position.y + 9.0)) / 46.0))
			if hover_choice < 0 or hover_choice >= dialog_choices.size():
				hover_choice = -1
	elif evidence_open:
		if Rect2(168.0, 154.0, 620.0, float(evidence_items.size()) * 40.0).has_point(mouse_pos):
			hover_evidence = int(floor((mouse_pos.y - 154.0) / 40.0))
			if hover_evidence < 0 or hover_evidence >= evidence_items.size():
				hover_evidence = -1


func _on_click(pos: Vector2) -> void:
	if title_open:
		title_started.emit()
		return
	if chapter_open:
		close_chapter()
		return
	if ending_open:
		return
	if journal_open:
		if pos.x >= 56.0 and pos.x <= 188.0:
			var tab: int = int(floor((pos.y - 126.0) / 56.0))
			if tab >= 0 and tab < 5:
				switch_journal(tab)
		return
	if evidence_open:
		if Rect2(150.0, 78.0, 660.0, 374.0).has_point(pos) and not evidence_items.is_empty():
			var row: int = int(floor((pos.y - 154.0) / 40.0))
			if row >= 0 and row < evidence_items.size():
				evidence_index = row
				choose_evidence()
		return
	if dialog_open:
		if choices_visible:
			var cr: Rect2 = _choice_panel_rect()
			if cr.has_point(pos):
				var row: int = int(floor((pos.y - (cr.position.y + 9.0)) / 46.0))
				if row >= 0 and row < dialog_choices.size():
					choose_index(row)
			return
		advance_dialog()


func _choice_panel_rect() -> Rect2:
	var count: int = dialog_choices.size()
	var h: float = 18.0 + float(count) * 46.0
	var y: float = 346.0 - h - 10.0
	if y < 70.0:
		y = 70.0
	return Rect2(220.0, y, 520.0, h)


func open_title() -> void:
	title_open = true
	game_open = false
	dialog_open = false
	evidence_open = false
	journal_open = false
	ending_open = false
	chapter_open = false
	queue_redraw()


func start_game_ui() -> void:
	title_open = false
	game_open = true
	ending_open = false
	evidence_open = false
	journal_open = false
	chapter_open = false
	queue_redraw()


func show_dialog(speaker: String, style: String, lines: Array, choices: Array = []) -> void:
	dialog_open = true
	dialog_speaker = speaker
	dialog_style = style
	dialog_lines.clear()
	for item in lines:
		dialog_lines.append(str(item))
	dialog_index = 0
	dialog_chars = 0.0
	dialog_choices = choices
	choices_visible = false
	choice_index = 0
	evidence_open = false
	journal_open = false
	queue_redraw()


func current_line() -> String:
	if dialog_index < 0 or dialog_index >= dialog_lines.size():
		return ""
	return dialog_lines[dialog_index]


func is_typing() -> bool:
	if not dialog_open:
		return false
	return dialog_chars < float(current_line().length())


func advance_dialog() -> void:
	if not dialog_open:
		return
	if is_typing():
		dialog_chars = float(current_line().length())
		if dialog_index == dialog_lines.size() - 1 and dialog_choices.size() > 0:
			choices_visible = true
		return
	if dialog_index < dialog_lines.size() - 1:
		dialog_index += 1
		dialog_chars = 0.0
		return
	if dialog_choices.size() > 0:
		choices_visible = true
		choice_index = 0
		return
	dialog_open = false
	dialog_finished.emit()


func show_choices(choices: Array) -> void:
	dialog_choices = choices
	choices_visible = true
	choice_index = 0
	queue_redraw()


func move_choice(delta: int) -> void:
	if not choices_visible or dialog_choices.size() == 0:
		return
	choice_index = (choice_index + delta + dialog_choices.size()) % dialog_choices.size()
	queue_redraw()


func choose_index(index: int = -1) -> void:
	if not choices_visible or dialog_choices.size() == 0:
		return
	if index >= 0:
		choice_index = index
	if choice_index < 0 or choice_index >= dialog_choices.size():
		return
	var item: Dictionary = dialog_choices[choice_index] as Dictionary
	var id: String = str(item.get("id", ""))
	dialog_open = false
	choices_visible = false
	choice_selected.emit(id)


func choose_number(number: int) -> void:
	if number < 0 or number >= dialog_choices.size():
		return
	choose_index(number)


func choice_count() -> int:
	return dialog_choices.size()


func close_dialog(emit_finish: bool = false) -> void:
	dialog_open = false
	choices_visible = false
	if emit_finish:
		dialog_finished.emit()
	queue_redraw()


func open_evidence(items: Array) -> void:
	evidence_open = true
	evidence_items.clear()
	for item in items:
		evidence_items.append(str(item))
	evidence_index = 0
	queue_redraw()


func move_evidence(delta: int) -> void:
	if evidence_items.size() == 0:
		return
	evidence_index = (evidence_index + delta + evidence_items.size()) % evidence_items.size()
	queue_redraw()


func choose_evidence(index: int = -1) -> void:
	if index >= 0:
		evidence_index = index
	if evidence_index < 0 or evidence_index >= evidence_items.size():
		return
	var id: String = evidence_items[evidence_index]
	evidence_open = false
	evidence_selected.emit(id)


func close_evidence() -> void:
	evidence_open = false
	queue_redraw()


func open_journal() -> void:
	if ending_open or title_open:
		return
	journal_open = true
	journal_tab = 0
	journal_selection = 0
	queue_redraw()


func close_journal() -> void:
	journal_open = false
	queue_redraw()


func switch_journal(tab: int) -> void:
	journal_tab = clampi(tab, 0, 4)
	journal_selection = 0
	queue_redraw()


func select_journal(delta: int) -> void:
	if journal_tab == 2 and GameState.evidence.size() > 0:
		journal_selection = (journal_selection + delta + GameState.evidence.size()) % GameState.evidence.size()
		queue_redraw()


func show_toast(value: String, duration: float = 2.4) -> void:
	toast_text = value
	toast_life = duration
	toast_total = max(duration, 0.1)
	toast_age = 0.0
	queue_redraw()


func clear_toast() -> void:
	toast_life = 0.0
	toast_total = 0.0
	queue_redraw()


func set_fade(value: float) -> void:
	fade_alpha = clampf(value, 0.0, 1.0)
	queue_redraw()


func set_prompt(value: String) -> void:
	prompt_text = value
	queue_redraw()


func set_quest_hint(info: Dictionary) -> void:
	quest = info
	queue_redraw()


func show_chapter(step: int) -> void:
	chapter_open = true
	chapter_step = step
	chapter_age = 0.0
	dialog_open = false
	choices_visible = false
	evidence_open = false
	journal_open = false
	queue_redraw()


func close_chapter() -> void:
	chapter_open = false
	queue_redraw()


func show_ending(kind: String = "keep") -> void:
	ending_kind = kind
	ending_open = true
	journal_open = false
	dialog_open = false
	evidence_open = false
	chapter_open = false
	title_open = false
	game_open = false
	queue_redraw()


func is_blocking() -> bool:
	return title_open or dialog_open or evidence_open or journal_open or ending_open or chapter_open


func _draw() -> void:
	# 背景底
	if title_open:
		_draw_title()
		return
	if ending_open:
		_draw_ending()
		return
	_draw_hud()
	if chapter_open:
		_draw_chapter()
		return
	if dialog_open or evidence_open or journal_open:
		draw_rect(Rect2(0.0, 54.0, 960.0, 442.0), Color(0.02, 0.02, 0.02, 0.18), true)
	if journal_open:
		_draw_journal()
	elif evidence_open:
		_draw_evidence()
	elif dialog_open:
		_draw_dialog()
	else:
		_draw_quest_marker()
		_draw_prompt()
	if toast_life > 0.0:
		_draw_toast()
	if fade_alpha > 0.001:
		draw_rect(Rect2(0.0, 0.0, 960.0, 540.0), Color(0.0, 0.0, 0.0, fade_alpha), true)


func _draw_hud() -> void:
	# 上条
	var title_color: Color = Color("#211A13") if tex_hud_top != null else Color("#E9DEC6")
	if tex_hud_top != null:
		_draw_nine_patch(tex_hud_top, Rect2(0.0, 0.0, 960.0, 54.0), 28.0, Color(1.0, 1.0, 1.0, 1.0))
	else:
		draw_rect(Rect2(0.0, 0.0, 960.0, 54.0), Color(0.055, 0.075, 0.082, 0.92), true)
		draw_line(Vector2(0.0, 53.0), Vector2(960.0, 53.0), Color(0.75, 0.64, 0.40, 0.65), 2.0)
	PlaceholderArt.text(self, Vector2(24.0, 33.0), "TURN", 22, title_color)
	PlaceholderArt.text(self, Vector2(97.0, 33.0), "归乡", 11, title_color if tex_hud_top == null else Color(0.34, 0.28, 0.20, 0.9))
	var scene_title: String = str(_scene_title())
	PlaceholderArt.text(self, Vector2(390.0, 33.0), scene_title, 17, title_color)
	var phase_text: String = GameState.phase_name() + "  " + GameState.phase_time()
	var pw: float = PlaceholderArt.text_width(phase_text, 13) + 26.0
	draw_rect(Rect2(936.0 - pw, 13.0, pw, 28.0), Color(0.12, 0.12, 0.10, 0.88), true)
	draw_rect(Rect2(936.0 - pw, 13.0, pw, 28.0), Color(0.86, 0.70, 0.38, 0.75), false, 1.0)
	PlaceholderArt.text(self, Vector2(936.0 - pw + 13.0, 32.0), phase_text, 13, Color("#F1E6CC"))

	if not quest.is_empty() and not dialog_open and not evidence_open and not journal_open:
		var what: String = str(quest.get("objective", ""))
		PlaceholderArt.panel(self, 18, 65, 590, 34, Color("#e6dcc3"), Color("#54483b"))
		PlaceholderArt.text(self, Vector2(30, 87), what, 13, Color("#332919"))

	# 下条：对白/物证/手记打开时收起，避免和面板叠在一起
	if not dialog_open and not evidence_open and not journal_open:
		if tex_hud_bottom != null:
			_draw_nine_patch(tex_hud_bottom, Rect2(0.0, 496.0, 960.0, 44.0), 30.0, Color(1.0, 1.0, 1.0, 1.0))
		else:
			draw_rect(Rect2(0.0, 496.0, 960.0, 44.0), Color(0.055, 0.075, 0.082, 0.90), true)
			draw_line(Vector2(0.0, 496.0), Vector2(960.0, 496.0), Color(0.75, 0.64, 0.40, 0.45), 1.0)
		var hint_color: Color = Color(0.20, 0.17, 0.13, 0.95) if tex_hud_bottom != null else Color(0.82, 0.78, 0.67, 0.92)
		var hint2_color: Color = Color(0.34, 0.29, 0.22, 0.85) if tex_hud_bottom != null else Color(0.62, 0.58, 0.48, 0.82)
		var hint: String = "A / D 走　Shift 跑　E 互动　I 手记"
		PlaceholderArt.text(self, Vector2(22.0, 519.0), hint, 12, hint_color)
		PlaceholderArt.text(self, Vector2(22.0, 534.0), "H 查看线索方向", 10, hint2_color)
		var ev: String = "手记 " + str(GameState.evidence.size())
		PlaceholderArt.text(self, Vector2(960.0 - PlaceholderArt.text_width(ev, 12) - 22.0, 519.0), ev, 12,
			Color(0.50, 0.32, 0.12, 0.95))


func _draw_quest_marker() -> void:
	var marker_visible: bool = bool(quest.get("marker_visible", false))
	var arrow_dir: int = int(quest.get("arrow_dir", 0))
	if not marker_visible and arrow_dir == 0:
		return
	if marker_visible:
		var mx: float = float(quest.get("marker_x", -100.0))
		var my: float = float(quest.get("marker_y", 300.0))
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.4)
		var label: String = str(quest.get("label", "目标"))
		draw_circle(Vector2(mx, my), 18.0 + pulse * 4.0, Color(0.95, 0.74, 0.30, 0.10), true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(mx, my - 14.0),
			Vector2(mx + 11.0, my),
			Vector2(mx, my + 14.0),
			Vector2(mx - 11.0, my),
		]), Color(0.95, 0.76, 0.33, 0.96))
		draw_polyline(PackedVector2Array([
			Vector2(mx, my - 14.0),
			Vector2(mx + 11.0, my),
			Vector2(mx, my + 14.0),
			Vector2(mx - 11.0, my),
			Vector2(mx, my - 14.0),
		]), Color(0.30, 0.22, 0.12, 0.9), 1.5, true)
		var tw: float = PlaceholderArt.text_width(label, 10) + 16.0
		draw_rect(Rect2(mx - tw * 0.5, my + 18.0, tw, 18.0), Color(0.07, 0.08, 0.08, 0.88), true)
		PlaceholderArt.text(self, Vector2(mx - tw * 0.5 + 8.0, my + 31.0), label, 10, Color("#F1E6CC"))
	if arrow_dir != 0:
		_draw_edge_arrow(arrow_dir, str(quest.get("arrow_text", "目标")))


func _draw_edge_arrow(direction: int, label: String) -> void:
	var x: float = 900.0 if direction > 0 else 60.0
	var y: float = 300.0
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var c: Color = Color(0.95, 0.76, 0.33, 0.85 + pulse * 0.12)
	if direction > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 16.0, y - 18.0), Vector2(x + 8.0, y), Vector2(x - 16.0, y + 18.0)]), c)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(x + 16.0, y - 18.0), Vector2(x - 8.0, y), Vector2(x + 16.0, y + 18.0)]), c)
	var tw: float = PlaceholderArt.text_width(label, 10) + 14.0
	var tx: float = x - tw * 0.5
	draw_rect(Rect2(tx, y + 24.0, tw, 18.0), Color(0.07, 0.08, 0.08, 0.86), true)
	PlaceholderArt.text(self, Vector2(tx + 7.0, y + 37.0), label, 10, Color("#F1E6CC"))


func _draw_chapter() -> void:
	var fade: float = clampf(chapter_age / 0.18, 0.0, 1.0)
	var rise: float = (1.0 - fade) * 16.0
	draw_rect(Rect2(0.0, 0.0, 960.0, 540.0), Color(0.02, 0.03, 0.035, 0.55), true)
	if not _draw_ui_panel(tex_chapter_block, Rect2(112.0, 132.0 + rise, 736.0, 276.0), 64.0, 0.99):
		PlaceholderArt.panel(self, 112.0, 132.0 + rise, 736.0, 276.0, Color(0.94, 0.90, 0.80, 0.99), Color(0.24, 0.20, 0.15, 0.95))
	PlaceholderArt.text(self, Vector2(146.0, 174.0 + rise), "TURN / 主线", 11, Color(0.48, 0.36, 0.19, 0.9))
	var data: Dictionary = GameState.step_data(chapter_step)
	var title: String = str(data.get("title", "主线"))
	var objective: String = str(data.get("objective", ""))
	var detail: String = str(data.get("detail", ""))
	PlaceholderArt.text(self, Vector2(146.0, 222.0 + rise), title, 30, Color("#211A13"))
	draw_line(Vector2(146.0, 246.0 + rise), Vector2(824.0, 246.0 + rise), Color(0.66, 0.52, 0.30, 0.6), 2.0)
	var lines: PackedStringArray = PlaceholderArt.wrap(objective, 660.0, 15)
	for i in range(min(3, lines.size())):
		PlaceholderArt.text(self, Vector2(146.0, 286.0 + rise + i * 24.0), lines[i], 15, Color("#211A13"))
	PlaceholderArt.text(self, Vector2(146.0, 356.0 + rise), detail, 10, Color(0.40, 0.34, 0.25, 0.9))
	var pulse: float = 0.55 + 0.25 * sin(_t * 2.6)
	PlaceholderArt.text(self, Vector2(620.0, 382.0 + rise), "按 E / Enter 或点击继续", 13, Color(0.55, 0.38, 0.18, pulse))
	PlaceholderArt.text(self, Vector2(146.0, 382.0 + rise), "这一步只做一件事。做完才会出现下一条。", 10, Color(0.42, 0.35, 0.26, 0.85))


func _scene_title() -> String:
	var id: String = GameState.current_scene
	var data: Dictionary = SceneDefs.get_scene(id)
	return str(data.get("title", id))


func _draw_dialog() -> void:
	var narration: bool = dialog_speaker == "旁白"
	var px: float = 28.0
	var py: float = 346.0
	var pw: float = 904.0
	var ph: float = 176.0
	if not _draw_ui_panel(tex_dialog_panel, Rect2(px, py, pw, ph), 64.0, 0.97):
		PlaceholderArt.panel(self, px, py, pw, ph, Color(0.93, 0.89, 0.79, 0.97))
	# 左侧头像 / 名字
	if not narration:
		draw_rect(Rect2(px + 18.0, py + 18.0, 118.0, 118.0), Color(0.16, 0.17, 0.16, 0.92), true)
		draw_rect(Rect2(px + 18.0, py + 18.0, 118.0, 118.0), Color(0.75, 0.64, 0.40, 0.6), false, 2.0)
		if tex_portrait_frame != null:
			draw_texture_rect(tex_portrait_frame, Rect2(px + 14.0, py + 14.0, 126.0, 126.0), false, Color(1.0, 1.0, 1.0, 0.98))
		_draw_portrait(px + 77.0, py + 78.0, dialog_style)
		if tex_portrait_frame == null:
			PlaceholderArt.text(self, Vector2(px + 22.0, py + 158.0), "占位头像", 9, Color(0.62, 0.58, 0.48, 0.8))
		var name_rect: Rect2 = Rect2(px + 154.0, py + 20.0, 232.0, 34.0)
		if not _draw_ui_panel(tex_name_plate, name_rect, 16.0, 0.98):
			draw_rect(name_rect, Color(0.78, 0.65, 0.37, 0.23), true)
		PlaceholderArt.text(self, Vector2(px + 166.0, py + 42.0), dialog_speaker, 16, Color("#2A2118"))
		PlaceholderArt.text(self, Vector2(px + 154.0, py + 72.0), _style_role(dialog_style), 11, Color(0.35, 0.30, 0.24, 0.85))
	else:
		PlaceholderArt.text(self, Vector2(px + 22.0, py + 36.0), "旁白", 14, Color(0.35, 0.29, 0.22, 0.9))
	# 正文
	var text_x: float = px + 154.0 if not narration else px + 24.0
	var text_y: float = py + 104.0
	var max_w: float = pw - (text_x - px) - 26.0
	var line: String = current_line()
	if is_typing():
		line = line.substr(0, int(dialog_chars))
	var wrapped: PackedStringArray = PlaceholderArt.wrap(line, max_w, 15)
	for i in range(min(4, wrapped.size())):
		PlaceholderArt.text(self, Vector2(text_x, text_y + i * 24.0), wrapped[i], 15, Color("#211A13"))
	# 页码 / 继续
	var page: String = str(dialog_index + 1) + " / " + str(dialog_lines.size())
	PlaceholderArt.text(self, Vector2(px + pw - 74.0, py + ph - 15.0), page, 10, Color(0.42, 0.35, 0.26, 0.75))
	if not is_typing() and dialog_choices.size() == 0:
		var hint: String = "空格 / E 继续"
		var hw: float = PlaceholderArt.text_width(hint, 12)
		PlaceholderArt.text(self, Vector2(px + pw - hw - 22.0, py + ph - 15.0), hint, 12, Color(0.55, 0.38, 0.20, 0.9))
	elif is_typing():
		PlaceholderArt.text(self, Vector2(px + pw - 112.0, py + ph - 15.0), "E 跳过打字", 10, Color(0.55, 0.38, 0.20, 0.65))
	if choices_visible:
		_draw_choices(px, py)


func _draw_portrait(cx: float, cy: float, style: String) -> void:
	var portrait: Texture2D = _portrait_texture(style)
	if portrait != null:
		draw_texture_rect(portrait, Rect2(cx - 59.0, cy - 59.0, 118.0, 118.0), false, Color(1.0, 1.0, 1.0, 1.0))
		return
	var skin: Color = Color("#D8B796")
	var hair: Color = Color("#2B2622")
	var cloth: Color = Color("#5E7169")
	if style == "zhou":
		skin = Color("#C9A47E")
		hair = Color("#7B7B70")
		cloth = Color("#3F4E49")
	elif style == "xiaoman":
		skin = Color("#D8B796")
		hair = Color("#241F1E")
		cloth = Color("#7C5A62")
	elif style == "tang":
		skin = Color("#D8B796")
		hair = Color("#31251F")
		cloth = Color("#A48C78")
	elif style == "wu":
		skin = Color("#C6A37E")
		hair = Color("#6A6258")
		cloth = Color("#3A3E3A")
	elif style == "chen":
		skin = Color("#C9A47E")
		hair = Color("#4A4238")
		cloth = Color("#6C5848")
	elif style == "mom":
		skin = Color("#D8B796")
		hair = Color("#3A2E28")
		cloth = Color("#8C6B62")
	elif style == "shop":
		skin = Color("#C9A47E")
		hair = Color("#4A4238")
		cloth = Color("#7C7464")
	# 肩
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 42.0, cy + 40.0),
		Vector2(cx - 30.0, cy + 8.0),
		Vector2(cx + 30.0, cy + 8.0),
		Vector2(cx + 42.0, cy + 40.0),
	]), cloth)
	# 脸
	draw_circle(Vector2(cx, cy - 14.0), 27.0, skin, true)
	draw_circle(Vector2(cx, cy - 14.0), 27.0, Color(0.12, 0.11, 0.10, 0.8), false, 2.0)
	# 头发
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 28.0, cy - 18.0),
		Vector2(cx - 24.0, cy - 38.0),
		Vector2(cx + 24.0, cy - 38.0),
		Vector2(cx + 28.0, cy - 18.0),
	]), hair)
	draw_rect(Rect2(cx - 4.0, cy - 12.0, 4.0, 4.0), Color(0.12, 0.10, 0.09, 1.0), true)
	draw_rect(Rect2(cx + 14.0, cy - 12.0, 4.0, 4.0), Color(0.12, 0.10, 0.09, 1.0), true)
	draw_line(Vector2(cx + 2.0, cy + 7.0), Vector2(cx + 15.0, cy + 7.0), Color(0.45, 0.22, 0.18, 0.75), 2.0)
	if style == "wu":
		draw_circle(Vector2(cx - 4.0, cy - 12.0), 8.0, Color(0.1, 0.1, 0.1, 0.12), true)
		draw_circle(Vector2(cx - 4.0, cy - 12.0), 8.0, Color(0.1, 0.1, 0.1, 0.7), false, 1.0)
		draw_circle(Vector2(cx + 14.0, cy - 12.0), 8.0, Color(0.1, 0.1, 0.1, 0.12), true)
		draw_circle(Vector2(cx + 14.0, cy - 12.0), 8.0, Color(0.1, 0.1, 0.1, 0.7), false, 1.0)
	if style == "zhou":
		draw_rect(Rect2(cx - 26.0, cy - 46.0, 52.0, 9.0), Color(0.24, 0.28, 0.25, 0.95), true)


func _style_role(style: String) -> String:
	if style == "zhou":
		return "修灯的人"
	if style == "xiaoman":
		return "旧识"
	if style == "tang":
		return "要搬走的人"
	if style == "wu":
		return "修东西的人"
	if style == "chen":
		return "父亲"
	if style == "mom":
		return "家人"
	if style == "shop":
		return "看店的人"
	return ""


func _portrait_texture(style: String) -> Texture2D:
	if not PlaceholderArt.USE_SCENE_ILLUSTRATIONS:
		return null
	if portrait_cache.has(style):
		return portrait_cache[style] as Texture2D
	if style == "shop":
		portrait_cache[style] = null
		return null
	var folder: String = "shenyan" if style == "player" else style
	var path: String = "res://art/chars/" + folder + "/" + folder + "_portrait.png"
	if not ResourceLoader.exists(path):
		portrait_cache[style] = null
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		var tex: Texture2D = res as Texture2D
		portrait_cache[style] = tex
		return tex
	portrait_cache[style] = null
	return null


func _draw_choices(_px: float, _py: float) -> void:
	var count: int = dialog_choices.size()
	var row_h: float = 46.0
	var rect: Rect2 = _choice_panel_rect()
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	if not _draw_ui_panel(tex_dialog_panel, rect, 64.0, 0.99):
		PlaceholderArt.panel(self, x, y, w, h, Color(0.94, 0.90, 0.80, 0.99), Color(0.22, 0.19, 0.15, 0.95))
	for i in range(count):
		var item: Dictionary = dialog_choices[i] as Dictionary
		var row_y: float = y + 9.0 + float(i) * row_h
		var row_rect: Rect2 = Rect2(x + 8.0, row_y, w - 16.0, row_h - 4.0)
		var selected: bool = i == choice_index
		var hovered: bool = i == hover_choice
		if not _draw_ui_panel(tex_choice_row, row_rect, 24.0, 0.96 if not selected else 1.0):
			draw_rect(row_rect, Color(0.86, 0.80, 0.68, 0.55), true)
		if selected or hovered:
			var fill_alpha: float = 0.22 if selected else 0.12
			draw_rect(row_rect, Color(0.78, 0.64, 0.35, fill_alpha), true)
			if selected and tex_focus_frame != null:
				_draw_ui_panel(tex_focus_frame, row_rect.grow(4.0), 20.0, 1.0)
			else:
				draw_rect(row_rect, Color(0.78, 0.64, 0.35, 0.92 if selected else 0.55), false, 2.0)
		draw_circle(Vector2(x + 24.0, row_y + 16.0), 9.0, Color(0.78, 0.64, 0.35, 0.95) if selected else Color(0.48, 0.42, 0.32, 0.55), true)
		PlaceholderArt.text(self, Vector2(x + 20.0, row_y + 21.0), str(i + 1), 12, Color("#211A13"))
		PlaceholderArt.text(self, Vector2(x + 44.0, row_y + 19.0), str(item.get("label", "")), 14, Color("#211A13"))
		var hint: String = str(item.get("hint", ""))
		if not hint.is_empty():
			PlaceholderArt.text(self, Vector2(x + 44.0, row_y + 34.0), hint, 9, Color(0.42, 0.35, 0.26, 0.88))
		if bool(item.get("recommended", false)):
			var bw: float = 42.0
			draw_rect(Rect2(x + w - bw - 16.0, row_y + 10.0, bw, 18.0), Color(0.66, 0.43, 0.22, 0.18), true)
			draw_rect(Rect2(x + w - bw - 16.0, row_y + 10.0, bw, 18.0), Color(0.66, 0.43, 0.22, 0.65), false, 1.0)
			PlaceholderArt.text(self, Vector2(x + w - bw - 10.0, row_y + 23.0), "推荐", 9, Color(0.48, 0.32, 0.16, 0.95))
	PlaceholderArt.text(self, Vector2(x + 12.0, y + h - 7.0), "点击 / ↑↓ 选择　E 确认　Esc 返回", 9, Color(0.42, 0.35, 0.26, 0.72))


func _draw_evidence() -> void:
	PlaceholderArt.panel(self, 150.0, 78.0, 660.0, 374.0, Color(0.93, 0.89, 0.79, 0.98))
	PlaceholderArt.text(self, Vector2(178.0, 112.0), "拿出哪一件？", 20, Color("#211A13"))
	PlaceholderArt.text(self, Vector2(178.0, 134.0), "错牌不消耗；Esc 收起", 11, Color(0.40, 0.34, 0.26, 0.8))
	if evidence_items.size() == 0:
		PlaceholderArt.text(self, Vector2(178.0, 176.0), "手里还没有可拿出的东西。", 14, Color("#211A13"))
		return
	for i in range(evidence_items.size()):
		var id: String = evidence_items[i]
		var row_y: float = 154.0 + i * 40.0
		var selected: bool = i == evidence_index
		var hovered: bool = i == hover_evidence
		if selected or hovered:
			draw_rect(Rect2(168.0, row_y, 620.0, 34.0), Color(0.78, 0.64, 0.35, 0.22 if selected else 0.12), true)
			draw_rect(Rect2(168.0, row_y, 620.0, 34.0), Color(0.78, 0.64, 0.35, 0.9 if selected else 0.55), false, 2.0)
		PlaceholderArt.text(self, Vector2(182.0, row_y + 23.0), str(i + 1), 13, Color(0.52, 0.38, 0.20, 1.0))
		var icon: Texture2D = evidence_textures.get(id) as Texture2D
		if icon != null:
			draw_texture_rect(icon, Rect2(202.0, row_y + 2.0, 30.0, 30.0), false)
		PlaceholderArt.text(self, Vector2(240.0, row_y + 23.0), GameState.evidence_name(id), 14, Color("#211A13"))
		var desc: String = GameState.evidence_desc(id)
		PlaceholderArt.text(self, Vector2(424.0, row_y + 22.0), desc, 10, Color(0.36, 0.31, 0.24, 0.9))
	PlaceholderArt.text(self, Vector2(178.0, 430.0), "点击 / Enter / E 递出　↑↓ 选择　Esc 收起", 10, Color(0.42, 0.35, 0.26, 0.65))


func _draw_journal() -> void:
	draw_rect(Rect2(0.0, 0.0, 960.0, 540.0), Color(0.03, 0.04, 0.05, 0.55), true)
	PlaceholderArt.panel(self, 34.0, 26.0, 892.0, 488.0, Color(0.92, 0.87, 0.76, 0.99))
	PlaceholderArt.text(self, Vector2(56.0, 66.0), "手记", 24, Color("#211A13"))
	PlaceholderArt.text(self, Vector2(56.0, 86.0), "TURN / FIELD NOTES", 9, Color(0.42, 0.36, 0.27, 0.8))
	PlaceholderArt.text(self, Vector2(218.0, 86.0), GameState.step_index_text() + " · " + GameState.step_title(), 10, Color(0.42, 0.36, 0.27, 0.8))
	# 左侧标签
	var tabs: Array[String] = ["目标", "人物", "物证", "推论", "地图"]
	for i in range(tabs.size()):
		var ty: float = 126.0 + i * 56.0
		var selected: bool = journal_tab == i
		if selected:
			draw_rect(Rect2(56.0, ty - 20.0, 132.0, 38.0), Color(0.76, 0.62, 0.33, 0.24), true)
			draw_rect(Rect2(56.0, ty - 20.0, 132.0, 38.0), Color(0.76, 0.62, 0.33, 0.9), false, 2.0)
		PlaceholderArt.text(self, Vector2(68.0, ty + 6.0), str(i + 1) + "　" + tabs[i], 14, Color("#211A13"))
	draw_line(Vector2(196.0, 110.0), Vector2(196.0, 486.0), Color(0.42, 0.35, 0.25, 0.35), 2.0)
	# 右页
	var x: float = 218.0
	var y: float = 118.0
	if journal_tab == 0:
		PlaceholderArt.text(self, Vector2(x, y), GameState.step_index_text(), 12, Color(0.42, 0.32, 0.20, 0.9))
		PlaceholderArt.text(self, Vector2(x, y + 26.0), GameState.step_title(), 17, Color("#211A13"))
		var lines: PackedStringArray = PlaceholderArt.wrap(GameState.step_objective(), 640.0, 16)
		for i in range(lines.size()):
			PlaceholderArt.text(self, Vector2(x, y + 56.0 + i * 25.0), lines[i], 16, Color("#211A13"))
		PlaceholderArt.text(self, Vector2(x, y + 116.0), "这一步怎么做", 12, Color(0.42, 0.32, 0.20, 0.9))
		var details: PackedStringArray = PlaceholderArt.wrap(GameState.step_detail(), 630.0, 11)
		for i in range(min(4, details.size())):
			PlaceholderArt.text(self, Vector2(x, y + 142.0 + i * 19.0), details[i], 11, Color(0.38, 0.33, 0.26, 0.9))
		PlaceholderArt.text(self, Vector2(x, y + 226.0), "完成上一件，才会出现下一件。", 10, Color(0.42, 0.36, 0.27, 0.75))
		PlaceholderArt.text(self, Vector2(x, y + 250.0), "按 I / Esc 关闭手记", 10, Color(0.42, 0.36, 0.27, 0.65))
	elif journal_tab == 1:
		var people: Array[Array] = [
			["周德海", "修灯的人。秋千、路灯、囡囡的旧鞋。"],
			["陈小满", "旧识。散谱、报名表、没走成的那条路。"],
			["唐棠", "要搬走的人。最后一箱、清单、磁带。"],
			["吴长庚", "修东西的人。没说出口的那句话。"],
			["陈守业", "父亲。琴箱、备用弦、二十岁没寄出的信。"],
			["妈妈", "家人。盐、煮鸡蛋、电话里的难处。"],
		]
		for i in range(people.size()):
			var py: float = y + 8.0 + i * 54.0
			PlaceholderArt.text(self, Vector2(x, py), str(people[i][0]), 16, Color("#211A13"))
			PlaceholderArt.text(self, Vector2(x + 100.0, py), str(people[i][1]), 11, Color(0.38, 0.33, 0.26, 0.9))
		PlaceholderArt.text(self, Vector2(x, y + 348.0), "已见人物随场景变化；手记只记你确实见过的人。", 10, Color(0.42, 0.36, 0.27, 0.7))
	elif journal_tab == 2:
		if GameState.evidence.size() == 0:
			PlaceholderArt.text(self, Vector2(x, y + 10.0), "还没有物证。去客厅、老街、游乐场看看。", 14, Color("#211A13"))
		else:
			for i in range(GameState.evidence.size()):
				var id: String = GameState.evidence[i]
				var row_y: float = y + 4.0 + i * 42.0
				var selected: bool = i == journal_selection
				if selected:
					draw_rect(Rect2(x - 8.0, row_y - 18.0, 640.0, 36.0), Color(0.76, 0.62, 0.33, 0.20), true)
				PlaceholderArt.text(self, Vector2(x, row_y), GameState.evidence_name(id), 14, Color("#211A13"))
				PlaceholderArt.text(self, Vector2(x + 180.0, row_y), "上次出现：" + GameState.evidence_where(id), 10, Color(0.42, 0.36, 0.27, 0.8))
			if journal_selection < GameState.evidence.size():
				var sid: String = GameState.evidence[journal_selection]
				var desc_y: float = y + 4.0 + GameState.evidence.size() * 42.0 + 20.0
				PlaceholderArt.text(self, Vector2(x, desc_y), "描述", 12, Color(0.42, 0.32, 0.20, 0.9))
				var dlines: PackedStringArray = PlaceholderArt.wrap(GameState.evidence_desc(sid), 620.0, 12)
				for i in range(min(3, dlines.size())):
					PlaceholderArt.text(self, Vector2(x, desc_y + 24.0 + i * 18.0), dlines[i], 12, Color("#211A13"))
	elif journal_tab == 3:
		PlaceholderArt.text(self, Vector2(x, y), "把两件东西并排看，才会出现新的路。", 13, Color("#211A13"))
		var nodes: Array[String] = ["旧照片", "陈小满", "周德海", "灯下旧鞋", "唐棠", "旧磁带", "琴箱"]
		for i in range(nodes.size()):
			var nx: float = x + 12.0 + (i % 4) * 150.0
			var ny: float = y + 52.0 + (i / 4) * 96.0
			draw_rect(Rect2(nx, ny, 124.0, 42.0), Color(0.86, 0.79, 0.65, 0.9), true)
			PlaceholderArt.text(self, Vector2(nx + 10.0, ny + 27.0), nodes[i], 12, Color("#211A13"))
			if i < nodes.size() - 1 and i % 4 != 3:
				draw_line(Vector2(nx + 124.0, ny + 21.0), Vector2(nx + 150.0, ny + 21.0), Color(0.42, 0.35, 0.25, 0.6), 2.0)
		PlaceholderArt.text(self, Vector2(x, y + 248.0), "当前推论", 12, Color(0.42, 0.32, 0.20, 0.9))
		var clue: String = "把旧鞋递给周德海 → 裂镜；把清单递给唐棠 → 磁带。"
		PlaceholderArt.text(self, Vector2(x, y + 274.0), clue, 12, Color("#211A13"))
	elif journal_tab == 4:
		_draw_map(x, y)


func _draw_map(x: float, y: float) -> void:
	var nodes: Array[Dictionary] = [
		{"id": "station", "name": "车站", "x": 20.0},
		{"id": "town_gate", "name": "镇口", "x": 150.0},
		{"id": "street_west", "name": "老街西", "x": 280.0},
		{"id": "house_yard", "name": "老宅", "x": 410.0},
		{"id": "street_east", "name": "老街东", "x": 540.0},
		{"id": "playground", "name": "游乐场", "x": 670.0},
		{"id": "crossing", "name": "搬家路口", "x": 800.0},
		{"id": "town_final", "name": "镇口灯火", "x": 930.0},
	]
	PlaceholderArt.text(self, Vector2(x, y), "只记录走过的地方；不负责传送。", 11, Color(0.42, 0.36, 0.27, 0.8))
	draw_line(Vector2(x + 20.0, y + 86.0), Vector2(x + 650.0, y + 86.0), Color(0.42, 0.35, 0.25, 0.4), 3.0)
	for i in range(nodes.size()):
		var nx: float = x + float(nodes[i].get("x", 0.0)) * 0.62
		var visited: bool = GameState.scene_visited(str(nodes[i].get("id", ""))) or i == 0
		draw_circle(Vector2(nx, y + 86.0), 9.0, Color(0.76, 0.62, 0.33, 0.9) if visited else Color(0.50, 0.45, 0.36, 0.5), true)
		PlaceholderArt.text(self, Vector2(nx - 30.0, y + 116.0), str(nodes[i].get("name", "")), 10, Color(0.30, 0.25, 0.19, 0.9))
	PlaceholderArt.text(self, Vector2(x + 20.0, y + 190.0), "当前：" + _scene_title(), 13, Color("#211A13"))
	PlaceholderArt.text(self, Vector2(x + 20.0, y + 218.0), "往左是家，往右是游乐场。门内是短条，不是迷宫。", 11, Color(0.38, 0.33, 0.26, 0.9))


func _draw_toast() -> void:
	if journal_open or evidence_open:
		return
	var t: float = clampf(toast_age / 0.18, 0.0, 1.0)
	var out: float = clampf(toast_life / 0.35, 0.0, 1.0)
	var alpha: float = min(t, out)
	var slide: float = (1.0 - t) * -14.0
	var w: float = min(910.0, PlaceholderArt.text_width(toast_text, 13) + 56.0)
	var x: float = 480.0 - w * 0.5
	var y: float = 392.0 + slide
	if dialog_open or evidence_open or journal_open:
		y = 176.0 + slide
	if not _draw_ui_panel(tex_toast, Rect2(x, y, w, 40.0), 28.0, alpha):
		PlaceholderArt.panel(self, x, y+2.0, w, 36.0, Color(0.94, 0.90, 0.80, 0.98 * alpha), Color(0.30, 0.24, 0.16, 0.85 * alpha))
		draw_rect(Rect2(x, y+2.0, 5.0, 36.0), Color(0.78, 0.62, 0.30, 0.95 * alpha), true)
	PlaceholderArt.text(self, Vector2(x + 18.0, y + 25.0), toast_text, 13, Color(0.16, 0.13, 0.10, alpha))
	var progress: float = clampf(toast_life / toast_total, 0.0, 1.0) if toast_total > 0.0 else 0.0
	draw_rect(Rect2(x + 10.0, y + 36.0, (w - 20.0) * progress, 2.0), Color(0.48, 0.35, 0.18, 0.72 * alpha), true)


func _draw_prompt() -> void:
	if prompt_text.is_empty():
		return
	var label: String = prompt_text
	if label.begins_with("E　"):
		label = label.substr(2)
	var w: float = min(640.0, PlaceholderArt.text_width(label, 14) + 86.0)
	var x: float = 480.0 - w * 0.5
	var y: float = 424.0
	if not _draw_ui_panel(tex_prompt, Rect2(x, y, w, 42.0), 24.0, 0.98):
		PlaceholderArt.panel(self, x, y, w, 42.0, Color(0.94, 0.90, 0.80, 0.97), Color(0.22, 0.19, 0.15, 0.9))
	draw_circle(Vector2(x + 23.0, y + 21.0), 13.0, Color(0.30, 0.22, 0.12, 0.95), true)
	PlaceholderArt.text(self, Vector2(x + 18.0, y + 26.0), "E", 13, Color("#F1E6CC"))
	PlaceholderArt.text(self, Vector2(x + 46.0, y + 26.0), label, 14, Color("#211A13"))


func _draw_title() -> void:
	if tex_title_bg != null:
		draw_texture_rect(tex_title_bg, Rect2(0.0, 0.0, 960.0, 540.0), false, Color(1.0, 1.0, 1.0, 0.96))
	else:
		draw_rect(Rect2(0.0, 0.0, 960.0, 540.0), Color(0.035, 0.045, 0.050, 0.72), true)
		# 背景剪影
		draw_rect(Rect2(0.0, 396.0, 960.0, 144.0), Color(0.06, 0.07, 0.07, 0.72), true)
		for i in range(5):
			var x: float = 60.0 + i * 210.0
			draw_rect(Rect2(x, 330.0 - i * 10.0, 36.0, 120.0), Color(0.10, 0.12, 0.12, 0.8), true)
			draw_circle(Vector2(x + 18.0, 318.0 - i * 10.0), 7.0, Color(0.80, 0.64, 0.34, 0.6), true)
	PlaceholderArt.panel(self, 92.0, 76.0, 776.0, 330.0, Color(0.93, 0.89, 0.79, 0.98))
	PlaceholderArt.text(self, Vector2(126.0, 144.0), "T U R N", 16, Color(0.42, 0.32, 0.20, 0.9))
	PlaceholderArt.text(self, Vector2(126.0, 208.0), "转　向", 46, Color("#211A13"))
	PlaceholderArt.text(self, Vector2(130.0, 240.0), "横版探索", 16, Color(0.38, 0.31, 0.23, 0.95))
	draw_line(Vector2(126.0, 264.0), Vector2(820.0, 264.0), Color(0.66, 0.52, 0.30, 0.6), 2.0)
	PlaceholderArt.text(self, Vector2(130.0, 300.0), "末班车开走了。站台的表还停在这里。", 13, Color("#211A13"))
	var pulse: float = 0.62 + 0.28 * sin(_title_pulse * 2.6)
	PlaceholderArt.text(self, Vector2(430.0, 364.0), "按 E / Enter 或点击开始", 18, Color(0.55, 0.38, 0.18, pulse))
	PlaceholderArt.text(self, Vector2(132.0, 386.0), "A / D 走　Shift 跑　E 互动　I 手记　Esc 关闭", 11, Color(0.42, 0.35, 0.26, 0.8))


func _draw_ending() -> void:
	var bg: Texture2D = tex_ending_leave if ending_kind == "turn" else tex_ending_stay
	if bg != null:
		draw_texture_rect(bg, Rect2(0.0, 0.0, 960.0, 540.0), false, Color(1.0, 1.0, 1.0, 0.96))
	else:
		draw_rect(Rect2(0.0, 0.0, 960.0, 540.0), Color(0.025, 0.030, 0.035, 0.92), true)
	PlaceholderArt.panel(self, 110.0, 62.0, 740.0, 400.0, Color(0.93, 0.89, 0.79, 0.98))
	PlaceholderArt.text(self, Vector2(146.0, 126.0), "E N D", 16, Color(0.42, 0.32, 0.20, 0.9))
	if ending_kind == "turn":
		PlaceholderArt.text(self, Vector2(146.0, 188.0), "表针停在四点十分", 36, Color("#211A13"))
		PlaceholderArt.text(self, Vector2(150.0, 224.0), "你拨动表针。远处响起了第二声铃。", 14, Color("#211A13"))
		PlaceholderArt.text(self, Vector2(150.0, 250.0), "车窗掠过秋千。座板在风里轻轻晃了一下。", 14, Color("#211A13"))
		draw_line(Vector2(146.0, 276.0), Vector2(814.0, 276.0), Color(0.66, 0.52, 0.30, 0.6), 2.0)
		PlaceholderArt.text(self, Vector2(150.0, 306.0), "这一趟：", 12, Color(0.42, 0.32, 0.20, 0.9))
		PlaceholderArt.text(self, Vector2(150.0, 332.0), "走过 " + str(GameState.seen_scene.size()) + " 处地点　物证 " + str(GameState.evidence.size()) + " 件", 13, Color("#211A13"))
		PlaceholderArt.text(self, Vector2(150.0, 358.0), _ending_help_text(), 11, Color(0.38, 0.33, 0.26, 0.9))
		PlaceholderArt.text(self, Vector2(150.0, 384.0), _ending_detail_text(), 11, Color(0.38, 0.33, 0.26, 0.9))
	else:
		PlaceholderArt.text(self, Vector2(146.0, 188.0), "灯还亮着", 36, Color("#211A13"))
		PlaceholderArt.text(self, Vector2(150.0, 224.0), "十一假期的最后一天。你把表放回兜里，没再动它。", 14, Color("#211A13"))
		PlaceholderArt.text(self, Vector2(150.0, 250.0), "车开动，小镇在窗外一点一点变小。", 14, Color("#211A13"))
		draw_line(Vector2(146.0, 276.0), Vector2(814.0, 276.0), Color(0.66, 0.52, 0.30, 0.6), 2.0)
		PlaceholderArt.text(self, Vector2(150.0, 306.0), "这一趟：", 12, Color(0.42, 0.32, 0.20, 0.9))
		PlaceholderArt.text(self, Vector2(150.0, 332.0), "走过 " + str(GameState.seen_scene.size()) + " 处地点　物证 " + str(GameState.evidence.size()) + " 件", 13, Color("#211A13"))
		PlaceholderArt.text(self, Vector2(150.0, 358.0), _ending_help_text(), 11, Color(0.38, 0.33, 0.26, 0.9))
		PlaceholderArt.text(self, Vector2(150.0, 384.0), _ending_detail_text(), 11, Color(0.38, 0.33, 0.26, 0.9))
	PlaceholderArt.text(self, Vector2(150.0, 426.0), "R 重新开始　Esc 退出", 12, Color(0.42, 0.32, 0.20, 0.9))


func _ending_help_text() -> String:
	var names: Array[String] = []
	if GameState.has_flag("helped_zhou"):
		names.append("周德海")
	if GameState.has_flag("helped_xiaoman"):
		names.append("陈小满")
	if GameState.has_flag("helped_tang"):
		names.append("唐棠")
	if names.is_empty():
		return "这回没来得及帮上谁。"
	return "帮过" + "、".join(names) + "。"


func _ending_detail_text() -> String:
	var bits: Array[String] = []
	if GameState.has_flag("presented_xiaoman"):
		bits.append("把旧照片递给了陈小满")
	if GameState.has_flag("presented_zhou"):
		bits.append("把旧鞋递给了周德海")
	if GameState.has_flag("presented_tang"):
		bits.append("把清单递给了唐棠")
	if GameState.has_flag("dream_seen"):
		bits.append("在地下室听见了那盘磁带")
	if bits.is_empty():
		return "旧东西还在原处。"
	return "；".join(bits) + "。"
