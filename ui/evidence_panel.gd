extends CanvasLayer

# v3 举证面板：每幕 3 件有效物证 + 1 件干扰件。
# 干扰件不锁死、可重试；有效件写立场 expose / half / soft。

const SKIN = preload("res://ui/theme.gd")
const Data = preload("res://scripts/turn_data.gd")

const CARD_ORDER := [0, 3, 1, 2]
const CARD_SIZE := Vector2(260, 200)

var _root: Control
var _cards_box: Control
var _side_box: Control
var _reaction_box: Control
var _act: String = ""
var _items: Array = []
var _cards: Array[Button] = []
var _selected: int = -1
var _on_result: Callable = Callable()
var _pending: Dictionary = {}
var _pending_is_decoy: bool = false
var _title_label: Label
var _prompt_label: Label
var _target_label: Label
var _caption_label: Label
var _sound: AudioStreamPlayer

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_sound = AudioStreamPlayer.new()
	_sound.stream = preload("res://audio/prologue/page.wav")
	_sound.volume_db = -16.0
	add_child(_sound)
	_build_shell()

func _build_shell() -> void:
	_root = Control.new()
	_root.size = Vector2(960, 600)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.06, 0.84)
	dim.size = Vector2(960, 600)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var board := ColorRect.new()
	board.color = Color("#243036")
	board.position = Vector2(18, 14)
	board.size = Vector2(924, 572)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(board)

	var hairline := ColorRect.new()
	hairline.color = SKIN.GOLD_DIM
	hairline.position = Vector2(18, 14)
	hairline.size = Vector2(924, 2)
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hairline)

	_title_label = SKIN.make_label("", 24, SKIN.GOLD)
	_title_label.position = Vector2(44, 30)
	_title_label.size.x = 580
	_root.add_child(_title_label)

	_prompt_label = SKIN.make_label("", 12, SKIN.PAPER_DIM, 560.0)
	_prompt_label.position = Vector2(44, 66)
	_root.add_child(_prompt_label)

	_cards_box = Control.new()
	_cards_box.size = Vector2(960, 600)
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cards_box)

	_side_box = Control.new()
	_side_box.size = Vector2(960, 600)
	_side_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_side_box)

	_reaction_box = Control.new()
	_reaction_box.size = Vector2(960, 600)
	_reaction_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reaction_box.visible = false
	_root.add_child(_reaction_box)

func is_open() -> bool:
	return visible

func open(act: String, on_result: Callable) -> void:
	_act = act
	_on_result = on_result
	_items = Data.evidence_items(act)
	_selected = -1
	_pending = {}
	_pending_is_decoy = false
	var act_data: Dictionary = Data.act_evidence(act)
	_title_label.text = str(act_data.get("title", "把哪一件递过去？"))
	_prompt_label.text = str(act_data.get("prompt", ""))
	_reaction_box.visible = false
	_cards_box.visible = true
	_side_box.visible = true
	_build_cards()
	_build_side()
	visible = true
	if _sound.stream != null:
		_sound.play()

func close() -> void:
	visible = false
	_pending = {}
	_cards.clear()

func _clear(box: Control) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _build_cards() -> void:
	_clear(_cards_box)
	_cards.clear()
	for slot in CARD_ORDER.size():
		var index: int = int(CARD_ORDER[slot])
		if index >= _items.size():
			continue
		var item: Dictionary = _items[index] as Dictionary
		var column: int = slot % 2
		var row: int = slot / 2
		var position := Vector2(44 + column * 280, 86 + row * 220)
		var card := Button.new()
		card.position = position
		card.size = CARD_SIZE
		card.custom_minimum_size = CARD_SIZE
		card.add_theme_stylebox_override("normal", SKIN.style(Color("#2b383e"), Color("#52605f"), 1, 5))
		card.add_theme_stylebox_override("hover", SKIN.style(Color("#34454b"), SKIN.GOLD_DIM, 1, 5))
		card.add_theme_stylebox_override("pressed", SKIN.style(Color("#3c4d52"), SKIN.GOLD, 2, 5))
		card.add_theme_stylebox_override("focus", SKIN.style(Color("#34454b"), SKIN.GOLD, 2, 5))
		if index == _selected:
			card.add_theme_stylebox_override("normal", SKIN.style(Color("#41565a"), SKIN.GOLD, 2, 5))
		_cards_box.add_child(card)
		_cards.append(card)

		var texture: Texture2D = Data.texture(str(item.get("thumb", "")))
		if texture != null:
			var icon := SKIN.make_texture(texture, Rect2(10, 10, 100, 100))
			card.add_child(icon)
		else:
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.30, 0.34, 0.34, 0.55)
			placeholder.position = Vector2(10, 10)
			placeholder.size = Vector2(100, 100)
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(placeholder)

		var name_label := SKIN.make_label(str(item.get("label", "")), 14, SKIN.PAPER, 130.0)
		name_label.position = Vector2(120, 12)
		card.add_child(name_label)
		var caption := SKIN.make_label(str(item.get("caption", "")), 10, SKIN.PAPER_DIM, 130.0)
		caption.position = Vector2(120, 42)
		card.add_child(caption)
		var tag := SKIN.make_label("物证 %d" % (index + 1), 10, SKIN.GOLD_DIM)
		tag.position = Vector2(120, 174)
		card.add_child(tag)
		card.pressed.connect(_select_card.bind(index))

func _build_side() -> void:
	_clear(_side_box)
	var act_data: Dictionary = Data.act_evidence(_act)
	var portrait: Texture2D = Data.texture(str(act_data.get("portrait", "")))
	if portrait != null:
		_side_box.add_child(SKIN.make_texture(portrait, Rect2(652, 84, 240, 240)))
	_target_label = SKIN.make_label("递给  " + str(act_data.get("target", "")), 17, SKIN.GOLD)
	_target_label.position = Vector2(652, 334)
	_target_label.size.x = 276
	_side_box.add_child(_target_label)

	_caption_label = SKIN.make_label("先选一件。四件里只有三件该递出去。", 12, SKIN.PAPER_DIM, 276.0)
	_caption_label.position = Vector2(652, 366)
	_side_box.add_child(_caption_label)

	var hand_button := SKIN.make_button("递过去", 16, 276.0, 42.0)
	hand_button.position = Vector2(652, 470)
	hand_button.pressed.connect(_confirm)
	_side_box.add_child(hand_button)

	var back_button := SKIN.make_button("先收起来", 13, 276.0, 32.0)
	back_button.position = Vector2(652, 520)
	back_button.pressed.connect(close)
	_side_box.add_child(back_button)

	var note := SKIN.make_label("数字 1–4 选卡   Enter 递出   Esc 收起", 11, Color(0.75, 0.72, 0.64, 0.8))
	note.position = Vector2(652, 560)
	_side_box.add_child(note)

func _select_card(index: int) -> void:
	_selected = index
	for i in _cards.size():
		var slot: int = int(CARD_ORDER[i])
		_cards[i].add_theme_stylebox_override("normal", SKIN.style(Color("#41565a") if slot == index else Color("#2b383e"), SKIN.GOLD if slot == index else Color("#52605f"), 2 if slot == index else 1, 5))
	if index >= 0 and index < _items.size():
		var item: Dictionary = _items[index] as Dictionary
		_caption_label.text = str(item.get("caption", ""))
		if _sound.stream != null:
			_sound.play()

func _confirm() -> void:
	if _selected < 0 or _selected >= _items.size():
		_caption_label.text = "先选一件，再递过去。"
		return
	_pending = (_items[_selected] as Dictionary).duplicate(true)
	_pending_is_decoy = str(_pending.get("stance", "")) == "decoy"
	_show_reaction()

func _show_reaction() -> void:
	_clear(_reaction_box)
	_cards_box.visible = false
	_side_box.visible = false
	_reaction_box.visible = true

	var panel := ColorRect.new()
	panel.color = Color("#1d262b")
	panel.position = Vector2(120, 120)
	panel.size = Vector2(720, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reaction_box.add_child(panel)

	var edge := ColorRect.new()
	edge.color = SKIN.GOLD_DIM
	edge.position = Vector2(120, 120)
	edge.size = Vector2(720, 2)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reaction_box.add_child(edge)

	var line_label := SKIN.make_label(str(_pending.get("line", "")), 15, SKIN.PAPER_DIM, 660.0)
	line_label.position = Vector2(152, 146)
	_reaction_box.add_child(line_label)

	var reply_label := SKIN.make_label(str(_pending.get("reply", "")), 22, SKIN.GOLD, 660.0)
	reply_label.position = Vector2(152, 190)
	_reaction_box.add_child(reply_label)

	var after_label := SKIN.make_label(str(_pending.get("after", "")), 15, SKIN.PAPER, 660.0)
	after_label.position = Vector2(152, 270)
	_reaction_box.add_child(after_label)

	var toast_text: String = ("✗ " if _pending_is_decoy else "✓ ") + str(_pending.get("toast", ""))
	var toast := SKIN.make_label(toast_text, 13, SKIN.RED if _pending_is_decoy else SKIN.GREEN)
	toast.position = Vector2(152, 352)
	_reaction_box.add_child(toast)

	var next_button := SKIN.make_button("换一件" if _pending_is_decoy else "就这样递过去", 16, 220.0, 42.0)
	next_button.position = Vector2(152, 400)
	next_button.pressed.connect(_finish_reaction)
	_reaction_box.add_child(next_button)

	var cancel_button := SKIN.make_button("先收起来", 13, 160.0, 34.0)
	cancel_button.position = Vector2(390, 404)
	cancel_button.pressed.connect(close)
	_reaction_box.add_child(cancel_button)

func _finish_reaction() -> void:
	if _pending_is_decoy:
		_reaction_box.visible = false
		_cards_box.visible = true
		_side_box.visible = true
		_selected = -1
		_build_cards()
		_build_side()
		_caption_label.text = "这件现在递不出去。换一件。"
		return
	var stance: String = str(_pending.get("stance", "soft"))
	var item_id: String = str(_pending.get("id", ""))
	TurnState.set_stance(_act, stance)
	TurnState.unlock_item(item_id)
	TurnState.push_backlog("你", str(_pending.get("caption", "")))
	TurnState.push_backlog(str(_pending.get("label", "")), str(_pending.get("reply", "")))
	var callback: Callable = _on_result
	close()
	if callback.is_valid():
		callback.call(stance, item_id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
		return
	if _reaction_box.visible:
		if key_event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_finish_reaction()
			get_viewport().set_input_as_handled()
		return
	if key_event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		var slot: int = key_event.physical_keycode - KEY_1
		if slot < CARD_ORDER.size():
			_select_card(int(CARD_ORDER[slot]))
			get_viewport().set_input_as_handled()
	elif key_event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_confirm()
		get_viewport().set_input_as_handled()
