extends CanvasLayer

# 镇口章节选择：列出 v3 五个章节，点哪章从哪章进。
# 不破坏存档，只切换场景；当前进度由 TurnState 保留。

const SKIN = preload("res://ui/theme.gd")
const Data = preload("res://scripts/turn_data.gd")

var _root: Control
var _list_box: Control
var _on_pick: Callable = Callable()
var _was_paused: bool = false

func _ready() -> void:
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	_root = Control.new()
	_root.size = Vector2(960, 600)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.06, 0.82)
	dim.size = Vector2(960, 600)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var board := ColorRect.new()
	board.color = Color("#20272e")
	board.position = Vector2(220, 40)
	board.size = Vector2(520, 520)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(board)
	var edge := ColorRect.new()
	edge.color = SKIN.GOLD_DIM
	edge.position = Vector2(220, 40)
	edge.size = Vector2(520, 2)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(edge)

	var title := SKIN.make_label("从哪一章开始", 26, SKIN.PAPER)
	title.position = Vector2(252, 68)
	_root.add_child(title)
	var sub := SKIN.make_label("章节选择不覆盖已有手记与立场。", 12, SKIN.PAPER_DIM)
	sub.position = Vector2(252, 106)
	_root.add_child(sub)

	_list_box = Control.new()
	_list_box.size = Vector2(960, 600)
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_list_box)

	var close := SKIN.make_button("收起  Esc", 13, 140.0, 34.0)
	close.position = Vector2(568, 520)
	close.pressed.connect(close_panel)
	_root.add_child(close)

func open(on_pick: Callable) -> void:
	_on_pick = on_pick
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh()
	visible = true

func close_panel() -> void:
	visible = false
	get_tree().paused = _was_paused

func _refresh() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var chapters: Array = Data.dialogue().get("chapters", []) as Array
	for i in chapters.size():
		var chapter: Dictionary = chapters[i] as Dictionary
		var id: String = str(chapter.get("id", ""))
		var button := SKIN.make_button(str(chapter.get("no", "")) + "   " + str(chapter.get("name", "")), 18, 456.0, 56.0)
		button.position = Vector2(252, 140 + i * 68)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var hint := SKIN.make_label(str(chapter.get("hint", "")), 11, SKIN.GOLD_DIM)
		hint.position = Vector2(252 + 330, 140 + i * 68 + 22)
		hint.size.x = 120
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_list_box.add_child(button)
		_list_box.add_child(hint)
		button.pressed.connect(_pick.bind(id))

func _pick(id: String) -> void:
	visible = false
	get_tree().paused = _was_paused
	var callback: Callable = _on_pick
	if callback.is_valid():
		callback.call(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()
