extends CanvasLayer

# v3 全局手记：I / Tab 随时打开，世界暂停并压暗。
# 左页人物 3×2，右页物证 4×3 分页，底栏 目标 / 提示 / 回看。

const SKIN = preload("res://ui/theme.gd")
const Data = preload("res://scripts/turn_data.gd")
const PuzzleState = preload("res://world/puzzle_state.gd")

const PANEL_LAYER := 120
const PEOPLE_PER_PAGE := 6
const ITEMS_PER_PAGE := 12

var _root: Control
var _board: ColorRect
var _people_box: Control
var _items_box: Control
var _detail_box: Control
var _tab_box: Control
var _title_left: Label
var _title_right: Label
var _act_label: Label
var _page_label: Label
var _selection: Dictionary = {"kind": "goal", "id": ""}
var _item_page: int = 0
var _tab: String = "goal"
var _was_paused: bool = false
var _sound: AudioStreamPlayer
var puzzle: RefCounted = null

func _ready() -> void:
	layer = PANEL_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	puzzle = PuzzleState.new()
	_sound = AudioStreamPlayer.new()
	_sound.stream = preload("res://audio/prologue/page.wav")
	_sound.volume_db = -16.0
	add_child(_sound)
	_build()
	visible = false
	if TurnState.journal_changed.is_connected(_refresh):
		TurnState.journal_changed.disconnect(_refresh)
	TurnState.journal_changed.connect(_refresh)
	TurnState.hint_changed.connect(_on_hint_changed)
	TurnState.stance_changed.connect(_on_stance_changed)

func _build() -> void:
	_root = Control.new()
	_root.size = Vector2(960, 600)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.06, 0.80)
	dim.size = Vector2(960, 600)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var shadow := ColorRect.new()
	shadow.color = Color(0.02, 0.02, 0.02, 0.42)
	shadow.position = Vector2(26, 18)
	shadow.size = Vector2(914, 570)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shadow)

	SKIN.paper_board(_root, Rect2(20, 12, 920, 576))

	var spine := ColorRect.new()
	spine.color = Color(0.30, 0.24, 0.17, 0.26)
	spine.position = Vector2(470, 56)
	spine.size = Vector2(2, 396)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(spine)

	_title_left = SKIN.make_label("人物", 20, SKIN.INK)
	_title_left.position = Vector2(44, 32)
	_root.add_child(_title_left)

	_title_right = SKIN.make_label("物证", 20, SKIN.INK)
	_title_right.position = Vector2(492, 32)
	_root.add_child(_title_right)

	_act_label = SKIN.make_label("", 14, Color(0.36, 0.30, 0.22, 0.9))
	_act_label.position = Vector2(760, 36)
	_act_label.size.x = 170
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_act_label)

	SKIN.divider(_root, Vector2(44, 58), 388, false)
	SKIN.divider(_root, Vector2(492, 58), 424, false)

	_people_box = Control.new()
	_people_box.position = Vector2.ZERO
	_people_box.size = Vector2(960, 600)
	_people_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_people_box)

	_items_box = Control.new()
	_items_box.position = Vector2.ZERO
	_items_box.size = Vector2(960, 600)
	_items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_items_box)

	_page_label = SKIN.make_label("1 / 2", 13, SKIN.INK_SOFT)
	_page_label.position = Vector2(820, 446)
	_page_label.size.x = 90
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_page_label)

	var prev_button := SKIN.make_button("上一页", 12, 70.0, 26.0)
	prev_button.position = Vector2(678, 442)
	prev_button.pressed.connect(_change_page.bind(-1))
	_root.add_child(prev_button)

	var next_button := SKIN.make_button("下一页", 12, 70.0, 26.0)
	next_button.position = Vector2(744, 442)
	next_button.pressed.connect(_change_page.bind(1))
	_root.add_child(next_button)

	var detail_bg := ColorRect.new()
	detail_bg.color = SKIN.INK
	detail_bg.position = Vector2(40, 468)
	detail_bg.size = Vector2(648, 104)
	detail_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(detail_bg)

	_detail_box = Control.new()
	_detail_box.size = Vector2(960, 600)
	_detail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_detail_box)

	_tab_box = Control.new()
	_tab_box.size = Vector2(960, 600)
	_tab_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tab_box)

	var hint := SKIN.make_label("I / Tab 收起    ·    点击卡片翻看    ·    底栏可切换 目标 / 提示 / 回看", 11, Color(0.33, 0.28, 0.21, 0.85))
	hint.position = Vector2(44, 574)
	_root.add_child(hint)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.physical_keycode in [KEY_I, KEY_TAB]:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if visible and key_event.physical_keycode in [KEY_ESCAPE, KEY_E]:
		close()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_selection = {"kind": "goal", "id": ""}
	_tab = "goal"
	if puzzle != null:
		puzzle.reload()
		puzzle.clear_fresh()
	_refresh()
	if _sound.stream != null:
		_sound.play()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	if _sound.stream != null:
		_sound.play()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _on_hint_changed(_level: int) -> void:
	if visible and _tab == "hint":
		_refresh()

func _on_stance_changed(_act: String, _value: String) -> void:
	if visible:
		_refresh()

func _change_page(delta: int) -> void:
	var max_page: int = maxi(1, int(ceil(float(Data.item_entries().size()) / float(ITEMS_PER_PAGE))))
	_item_page = clampi(_item_page + delta, 0, max_page - 1)
	_refresh()

func _clear_box(box: Control) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	if _root == null:
		return
	_clear_box(_people_box)
	_clear_box(_items_box)
	_clear_box(_detail_box)
	_clear_box(_tab_box)
	_title_left.text = "人物  %d / %d" % [TurnState.people.size(), Data.person_entries().size()]
	_title_right.text = "物证  %d / %d" % [TurnState.items.size(), Data.item_entries().size()]
	_act_label.text = str(Data.act_title(TurnState.current_act).get("no", "")) + "  ·  " + str(Data.act_title(TurnState.current_act).get("name", ""))
	_build_people()
	_build_items()
	_build_tabs()
	_build_detail()
	var max_page: int = maxi(1, int(ceil(float(Data.item_entries().size()) / float(ITEMS_PER_PAGE))))
	_item_page = clampi(_item_page, 0, max_page - 1)
	_page_label.text = "%d / %d" % [_item_page + 1, max_page]

func _build_people() -> void:
	var index: int = 0
	for entry in Data.person_entries():
		if not (entry is Dictionary):
			continue
		var person: Dictionary = entry as Dictionary
		var id: String = str(person.get("id", ""))
		var known: bool = TurnState.people.has(id)
		var column: int = index % 2
		var row: int = index / 2
		var position := Vector2(44 + column * 206, 70 + row * 94)
		var card := Button.new()
		card.position = position
		card.size = Vector2(200, 88)
		card.custom_minimum_size = Vector2(200, 88)
		card.add_theme_stylebox_override("normal", SKIN.style(Color(0.92, 0.87, 0.77, 0.55), Color(0.55, 0.45, 0.30, 0.35), 1, 4))
		card.add_theme_stylebox_override("hover", SKIN.style(Color(0.96, 0.91, 0.81, 0.85), SKIN.GOLD_DIM, 1, 4))
		card.add_theme_stylebox_override("pressed", SKIN.style(SKIN.GOLD, SKIN.GOLD, 1, 4))
		card.add_theme_stylebox_override("focus", SKIN.style(Color(0.96, 0.91, 0.81, 0.85), SKIN.GOLD, 2, 4))
		card.focus_mode = Control.FOCUS_ALL
		if _selection.get("kind") == "person" and str(_selection.get("id")) == id:
			card.add_theme_stylebox_override("normal", SKIN.style(SKIN.GOLD, SKIN.INK, 2, 4))
		_people_box.add_child(card)

		var portrait_path: String = str(person.get("portrait", ""))
		var texture: Texture2D = Data.texture(portrait_path)
		if texture != null:
			var portrait := SKIN.make_texture(texture, Rect2(8, 8, 72, 72))
			card.add_child(portrait)
		else:
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.35, 0.32, 0.28, 0.5)
			placeholder.position = Vector2(8, 8)
			placeholder.size = Vector2(72, 72)
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(placeholder)

		var name_label := SKIN.make_label(str(person.get("name", "？")), 15, SKIN.INK)
		name_label.position = Vector2(88, 8)
		name_label.size.x = 104
		card.add_child(name_label)
		var tag_label := SKIN.make_label(str(person.get("tag", "")), 10, Color(0.35, 0.30, 0.24, 0.9), 104.0)
		tag_label.position = Vector2(88, 30)
		card.add_child(tag_label)
		if not known:
			var lock := SKIN.make_label("未结识", 11, Color(0.45, 0.40, 0.33, 0.85))
			lock.position = Vector2(88, 62)
			card.add_child(lock)
			card.modulate = Color(1, 1, 1, 0.55)
		card.pressed.connect(_select_person.bind(id))
		index += 1

func _build_items() -> void:
	var all_items: Array = Data.item_entries()
	var start: int = _item_page * ITEMS_PER_PAGE
	var end: int = mini(start + ITEMS_PER_PAGE, all_items.size())
	for slot in range(start, end):
		var entry: Dictionary = all_items[slot] as Dictionary
		var id: String = str(entry.get("id", ""))
		var known: bool = TurnState.items.has(id)
		var local: int = slot - start
		var column: int = local % 4
		var row: int = local / 4
		var position := Vector2(492 + column * 104, 70 + row * 120)
		var card := Button.new()
		card.position = position
		card.size = Vector2(96, 110)
		card.custom_minimum_size = Vector2(96, 110)
		card.add_theme_stylebox_override("normal", SKIN.style(Color(0.92, 0.87, 0.77, 0.5), Color(0.55, 0.45, 0.30, 0.32), 1, 3))
		card.add_theme_stylebox_override("hover", SKIN.style(Color(0.96, 0.91, 0.81, 0.85), SKIN.GOLD_DIM, 1, 3))
		card.add_theme_stylebox_override("pressed", SKIN.style(SKIN.GOLD, SKIN.GOLD, 1, 3))
		card.add_theme_stylebox_override("focus", SKIN.style(Color(0.96, 0.91, 0.81, 0.85), SKIN.GOLD, 2, 3))
		if _selection.get("kind") == "item" and str(_selection.get("id")) == id:
			card.add_theme_stylebox_override("normal", SKIN.style(SKIN.GOLD, SKIN.INK, 2, 3))
		_items_box.add_child(card)

		var texture: Texture2D = Data.texture(str(entry.get("thumb", "")))
		if texture != null and known:
			var icon := SKIN.make_texture(texture, Rect2(10, 6, 76, 74))
			card.add_child(icon)
		else:
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.40, 0.36, 0.30, 0.35)
			placeholder.position = Vector2(10, 6)
			placeholder.size = Vector2(76, 74)
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(placeholder)
			var question := SKIN.make_label("？", 26, Color(0.30, 0.26, 0.22, 0.55))
			question.position = Vector2(10, 24)
			question.size.x = 76
			question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(question)
		var name_label := SKIN.make_label(str(entry.get("name", "")) if known else "未记录", 9, SKIN.INK, 86.0)
		name_label.position = Vector2(5, 84)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_label)
		if known:
			card.pressed.connect(_select_item.bind(id))
		else:
			card.disabled = false
			card.modulate = Color(1, 1, 1, 0.55)
	_build_puzzle_sections()

func _build_puzzle_sections() -> void:
	if puzzle == null:
		return
	var fresh: Array[String] = puzzle.fresh_ids()
	var ev_ids: Array[String] = puzzle.all_evidence()
	var clue_ids: Array[String] = puzzle.all_clues()

	var ev_title: Label = SKIN.make_label("现场物证（解谜）  %d" % ev_ids.size(), 13, SKIN.INK)
	ev_title.position = Vector2(492, 318)
	_items_box.add_child(ev_title)
	var ev_index: int = 0
	for eid in ev_ids:
		var chip: Panel = _puzzle_chip(Vector2(492 + (ev_index % 3) * 142, 340 + (ev_index / 3) * 30), puzzle.evidence_name(eid), fresh.has(eid))
		_items_box.add_child(chip)
		ev_index += 1
	if ev_ids.is_empty():
		var empty_ev: Label = SKIN.make_label("还没有捡到现场物证。", 11, SKIN.INK_SOFT)
		empty_ev.position = Vector2(492, 340)
		_items_box.add_child(empty_ev)

	var clue_title: Label = SKIN.make_label("组合推论  %d" % clue_ids.size(), 13, SKIN.INK)
	clue_title.position = Vector2(492, 402)
	_items_box.add_child(clue_title)
	var clue_index: int = 0
	for cid in clue_ids:
		var chip2: Panel = _puzzle_chip(Vector2(492 + (clue_index % 3) * 142, 424), puzzle.clue_name(cid), fresh.has(cid))
		_items_box.add_child(chip2)
		clue_index += 1
	if clue_ids.is_empty():
		var empty_clue: Label = SKIN.make_label("把两件物证并排对上，才能推出一条推论。", 11, SKIN.INK_SOFT)
		empty_clue.position = Vector2(492, 424)
		_items_box.add_child(empty_clue)

func _puzzle_chip(at: Vector2, text: String, is_fresh: bool) -> Panel:
	var chip: Panel = Panel.new()
	chip.position = at
	chip.size = Vector2(136, 26)
	var border: Color = SKIN.GOLD if is_fresh else Color(0.55, 0.45, 0.30, 0.35)
	chip.add_theme_stylebox_override("panel", SKIN.style(Color(0.94, 0.89, 0.79, 0.92), border, 2 if is_fresh else 1, 4))
	var label: Label = SKIN.make_label(text, 10, SKIN.INK, 120.0)
	label.position = Vector2(8, 6)
	chip.add_child(label)
	if is_fresh:
		var badge: Label = SKIN.make_label("新", 10, SKIN.GOLD, 16.0, HORIZONTAL_ALIGNMENT_CENTER)
		badge.position = Vector2(116, 4)
		chip.add_child(badge)
	return chip

func _build_tabs() -> void:
	var tabs := [
		{"id": "goal", "text": "目标"},
		{"id": "hint", "text": "提示"},
		{"id": "backlog", "text": "回看"}
	]
	for i in tabs.size():
		var tab: Dictionary = tabs[i] as Dictionary
		var id: String = str(tab.get("id", ""))
		var button := SKIN.make_button(str(tab.get("text", "")), 14, 88.0, 28.0)
		button.position = Vector2(700, 468 + i * 30)
		if _tab == id:
			button.add_theme_stylebox_override("normal", SKIN.style(SKIN.GOLD, SKIN.INK, 2, 4))
			button.add_theme_color_override("font_color", SKIN.INK)
		button.pressed.connect(_select_tab.bind(id))
		_tab_box.add_child(button)

func _select_tab(id: String) -> void:
	_tab = id
	_selection = {"kind": id, "id": ""}
	_refresh()

func _select_person(id: String) -> void:
	_selection = {"kind": "person", "id": id}
	_tab = "goal"
	_refresh()

func _select_item(id: String) -> void:
	if not TurnState.items.has(id):
		return
	_selection = {"kind": "item", "id": id}
	_tab = "goal"
	_refresh()

func _build_detail() -> void:
	var title_text: String = ""
	var body_text: String = ""
	var foot_text: String = ""
	var kind: String = str(_selection.get("kind", "goal"))
	var id: String = str(_selection.get("id", ""))
	if kind == "person" and Data.person_exists(id):
		var person: Dictionary = Data.person(id)
		title_text = str(person.get("name", "")) + "  ·  " + str(person.get("tag", ""))
		var lines: Array = person.get("lines", [])
		var joined: PackedStringArray = PackedStringArray()
		for line in lines:
			joined.append("· " + str(line))
		body_text = "\n".join(joined)
		foot_text = "已结识" if TurnState.people.has(id) else "还没见过这个人"
	elif kind == "item" and Data.item_exists(id):
		var item: Dictionary = Data.item(id)
		title_text = str(item.get("name", "")) + "  ·  " + str(Data.act_title(str(item.get("act", ""))).get("name", ""))
		body_text = str(item.get("text", ""))
		foot_text = "记于手记" if TurnState.items.has(id) else "尚未记录"
	elif kind == "hint":
		title_text = "提示  " + str(TurnState.hint_index) + " / 3"
		body_text = TurnState.current_hint() if TurnState.hint_index > 0 else "先自己找。卡住了，再按下面的按钮。"
		foot_text = "提示只换说法，不改判定，也不锁死任何结局。" if TurnState.hint_index < 3 else "三层提示已经全部给完。"
		var more := SKIN.make_button("再看一层提示", 11, 150.0, 24.0)
		more.position = Vector2(700, 560)
		if TurnState.hint_index >= 3:
			more.disabled = true
		more.pressed.connect(_request_more_hint)
		_tab_box.add_child(more)
	elif kind == "backlog":
		title_text = "回看  ·  " + str(TurnState.backlog.size()) + " 条"
		var lines: PackedStringArray = PackedStringArray()
		var start: int = maxi(0, TurnState.backlog.size() - 4)
		for i in range(start, TurnState.backlog.size()):
			var line: Dictionary = TurnState.backlog[i] as Dictionary
			lines.append(str(line.get("speaker", "")) + "：" + str(line.get("line", "")))
		body_text = "\n".join(lines) if not lines.is_empty() else "还没有可以回看的对话。"
		foot_text = "回到这里，可以确认自己听过什么、漏了什么。"
	else:
		var act_name: String = str(Data.act_title(TurnState.current_act).get("name", ""))
		title_text = "当前目标  ·  " + act_name
		var hints: Array = Data.hints_for(TurnState.current_act)
		body_text = str(hints[0]) if not hints.is_empty() else "继续往前走。"
		var counts: Dictionary = TurnState.journal_counts()
		foot_text = "人物 %d   物证 %d   回看 %d   ·   已递出的立场：第一幕 %s / 第二幕 %s / 第三幕 %s" % [
			counts.get("people", 0), counts.get("items", 0), counts.get("backlog", 0),
			TurnState.get_stance("A1"), TurnState.get_stance("A2"), TurnState.get_stance("A3")
		]

	var title_label := SKIN.make_label(title_text, 17, SKIN.GOLD)
	title_label.position = Vector2(54, 476)
	title_label.size.x = 620
	_detail_box.add_child(title_label)
	var body_label := SKIN.make_label(body_text, 13, SKIN.PAPER, 620.0)
	body_label.position = Vector2(54, 502)
	_detail_box.add_child(body_label)
	var foot_label := SKIN.make_label(foot_text, 11, SKIN.PAPER_DIM, 620.0)
	foot_label.position = Vector2(54, 550)
	_detail_box.add_child(foot_label)

func _request_more_hint() -> void:
	TurnState.request_hint()
	_refresh()
