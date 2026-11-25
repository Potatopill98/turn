extends CanvasLayer

# v3 幕标题卡：每幕进场 2 秒，可按键跳过。
# 不暂停世界，只盖一层黑场。

const SKIN = preload("res://ui/theme.gd")
const Data = preload("res://scripts/turn_data.gd")

signal finished

var _root: Control
var _no_label: Label
var _name_label: Label
var _epigraph_label: Label
var _hint_label: Label
var _anim: Tween
var _playing: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	_root = Control.new()
	_root.size = Vector2(960, 600)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)

	var black := ColorRect.new()
	black.color = Color(0.045, 0.055, 0.062, 1.0)
	black.size = Vector2(960, 600)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(black)

	var line_top := ColorRect.new()
	line_top.color = Color(0.73, 0.60, 0.42, 0.55)
	line_top.position = Vector2(300, 238)
	line_top.size = Vector2(360, 1)
	line_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(line_top)

	var line_bottom := ColorRect.new()
	line_bottom.color = Color(0.73, 0.60, 0.42, 0.55)
	line_bottom.position = Vector2(300, 372)
	line_bottom.size = Vector2(360, 1)
	line_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(line_bottom)

	_no_label = SKIN.make_label("", 16, SKIN.GOLD_DIM)
	_no_label.position = Vector2(300, 204)
	_no_label.size.x = 360
	_no_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_no_label)

	_name_label = SKIN.make_label("", 44, SKIN.PAPER)
	_name_label.position = Vector2(160, 254)
	_name_label.size.x = 640
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_name_label)

	_epigraph_label = SKIN.make_label("", 16, Color(0.80, 0.76, 0.68, 0.9), 640.0)
	_epigraph_label.position = Vector2(160, 326)
	_epigraph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_epigraph_label)

	_hint_label = SKIN.make_label("按任意键跳过", 12, Color(0.55, 0.52, 0.46, 0.75))
	_hint_label.position = Vector2(160, 520)
	_hint_label.size.x = 640
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint_label)

func show_act(act: String, hold: float = 1.6) -> void:
	var title: Dictionary = Data.act_title(act)
	show_custom(str(title.get("no", "")), str(title.get("name", act)), str(title.get("epigraph", "")), hold)

func show_custom(no: String, name: String, epigraph: String, hold: float = 1.6) -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_no_label.text = no
	_name_label.text = name
	_epigraph_label.text = epigraph
	_root.modulate.a = 0.0
	visible = true
	_playing = true
	_anim = create_tween()
	_anim.tween_property(_root, "modulate:a", 1.0, 0.34)
	_anim.tween_interval(hold)
	_anim.tween_property(_root, "modulate:a", 0.0, 0.42)
	_anim.tween_callback(_finish)

func _finish() -> void:
	if not _playing:
		return
	_playing = false
	visible = false
	finished.emit()

func skip() -> void:
	if not _playing:
		return
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_root.modulate.a = 0.0
	_finish()

func _unhandled_key_input(event: InputEvent) -> void:
	if not _playing or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		skip()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		skip()
		get_viewport().set_input_as_handled()
