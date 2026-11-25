extends CanvasLayer

# 主线章节播放器：全屏视觉小说式推进。
# 支持旁白 / 对白 / 选择 / 记忆色调 / 背景切换 / 条件 beat。
# 数据来自 res://data/story.json。

const SKIN = preload("res://ui/theme.gd")
const Story = preload("res://scripts/story_data.gd")

signal finished

var _root: Control
var _bg_view: TextureRect
var _dim: ColorRect
var _panel: ColorRect
var _who_label: Label
var _text_label: Label
var _prompt_label: Label
var _next_button: Button
var _skip_button: Button
var _memory_label: Label
var _choice_box: Control
var _beats: Array = []
var _index: int = -1
var _revealed: float = 0.0
var _typing: bool = false
var _memory_mode: bool = false
var _on_done: Callable = Callable()
var _playing: bool = false

func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	_root = Control.new()
	_root.size = Vector2(960, 600)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_bg_view = TextureRect.new()
	_bg_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_view.position = Vector2.ZERO
	_bg_view.size = Vector2(960, 600)
	_bg_view.custom_minimum_size = Vector2.ZERO
	_bg_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg_view)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.04, 0.45)
	_dim.position = Vector2.ZERO
	_dim.size = Vector2(960, 600)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	var top_shade := _make_shade(0.0, 128.0, 0.82, false)
	_root.add_child(top_shade)
	var bottom_shade := _make_shade(472.0, 128.0, 0.92, true)
	_root.add_child(bottom_shade)

	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.06, 0.07, 0.94)
	_panel.position = Vector2(40, 388)
	_panel.size = Vector2(880, 184)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	var line := ColorRect.new()
	line.color = Color(0.88, 0.72, 0.49, 0.5)
	line.position = Vector2(40, 388)
	line.size = Vector2(880, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(line)

	_memory_label = SKIN.make_label("记  忆", 12, SKIN.GOLD_DIM)
	_memory_label.position = Vector2(64, 360)
	_memory_label.visible = false
	_root.add_child(_memory_label)

	_who_label = SKIN.make_label("", 15, SKIN.GOLD)
	_who_label.position = Vector2(64, 400)
	_root.add_child(_who_label)

	_text_label = SKIN.make_label("", 20, SKIN.PAPER, 832.0)
	_text_label.position = Vector2(64, 428)
	_text_label.size = Vector2(832, 96)
	_root.add_child(_text_label)

	_prompt_label = SKIN.make_label("", 15, SKIN.GOLD_DIM, 832.0)
	_prompt_label.position = Vector2(64, 440)
	_prompt_label.size = Vector2(832, 40)
	_prompt_label.visible = false
	_root.add_child(_prompt_label)

	_next_button = SKIN.make_button("继续  ▸", 14, 132.0, 32.0)
	_next_button.position = Vector2(764, 530)
	_next_button.visible = false
	_next_button.pressed.connect(_advance)
	_root.add_child(_next_button)

	_skip_button = SKIN.make_button("跳过", 12, 72.0, 28.0)
	_skip_button.position = Vector2(862, 18)
	_skip_button.pressed.connect(skip)
	_root.add_child(_skip_button)

	_choice_box = Control.new()
	_choice_box.position = Vector2(64, 470)
	_choice_box.size = Vector2(832, 100)
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_choice_box)

func _make_shade(y: float, height: float, alpha: float, flip: bool) -> TextureRect:
	var grad := Gradient.new()
	if flip:
		grad.set_color(0, Color(0.01, 0.015, 0.02, 0.0))
		grad.set_color(1, Color(0.01, 0.015, 0.02, alpha))
	else:
		grad.set_color(0, Color(0.01, 0.015, 0.02, alpha))
		grad.set_color(1, Color(0.01, 0.015, 0.02, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 128
	var shade := TextureRect.new()
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2(0, y)
	shade.size = Vector2(960, height)
	shade.custom_minimum_size = Vector2.ZERO
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade

func play(id: String, on_done: Callable = Callable()) -> void:
	var entry: Dictionary = Story.act(id)
	if entry.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_start(entry.get("beats", []) as Array, on_done)

# 探索模式用：只播某个 act 的一段 beat（首访某个地点时播 2~6 条）。
func play_range(id: String, from_beat: int, to_beat: int, on_done: Callable = Callable()) -> void:
	var entry: Dictionary = Story.act(id)
	if entry.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	var all_beats: Array = entry.get("beats", []) as Array
	var slice: Array = []
	var i: int = maxi(0, from_beat)
	var stop: int = mini(all_beats.size(), to_beat)
	while i < stop:
		slice.append(all_beats[i])
		i += 1
	if slice.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_start(slice, on_done)

func _start(beats: Array, on_done: Callable) -> void:
	_beats = beats
	_on_done = on_done
	_index = _next_index(0)
	_playing = true
	visible = true
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.24)
	_show_beat()

func skip() -> void:
	if not _playing:
		return
	_finish()

func _process(delta: float) -> void:
	if not _playing or not _typing:
		return
	_revealed += 32.0 * delta
	var total: int = _text_label.text.length()
	if int(_revealed) >= total:
		_text_label.visible_characters = -1
		_typing = false
		_show_next()
	else:
		_text_label.visible_characters = int(_revealed)

func _show_beat() -> void:
	_index = _next_index(_index)
	if _index >= _beats.size():
		_finish()
		return
	_next_button.visible = false
	_clear_choices()
	var beat: Dictionary = _beats[_index] as Dictionary
	var bg: String = str(beat.get("bg", ""))
	if not bg.is_empty():
		_set_bg(bg)
	var memory: bool = bool(beat.get("m", false)) or str(beat.get("t", "")) == "m"
	_set_memory(memory)
	var who: String = str(beat.get("who", ""))
	_who_label.text = who
	_who_label.visible = not who.is_empty()
	var text: String = str(beat.get("text", beat.get("prompt", "")))
	_text_label.text = text
	_text_label.visible = true
	_text_label.visible_characters = 0
	_revealed = 0.0
	_typing = true
	var item: String = str(beat.get("item", ""))
	if not item.is_empty():
		TurnState.unlock_item(item)
	var person: String = str(beat.get("person", ""))
	if not person.is_empty():
		TurnState.unlock_person(person, false)
	if beat.has("options"):
		_show_choices(beat["options"] as Array)

func _show_next() -> void:
	if _choice_box.get_child_count() > 0:
		return
	_next_button.visible = true

func _advance() -> void:
	if not _playing:
		return
	if _typing:
		_text_label.visible_characters = -1
		_typing = false
		_show_next()
		return
	if _choice_box.get_child_count() > 0:
		return
	_index = _next_index(_index + 1)
	_show_beat()

func _next_index(from: int) -> int:
	var i: int = from
	while i < _beats.size():
		if _match(_beats[i] as Dictionary):
			return i
		i += 1
	return i

func _match(beat: Dictionary) -> bool:
	var condition: String = str(beat.get("if", ""))
	if condition.is_empty():
		return true
	if condition.begins_with("!"):
		return not TurnState.has_flag(condition.substr(1))
	return TurnState.has_flag(condition)

func _set_bg(path: String) -> void:
	if not ResourceLoader.exists(path, "Texture2D"):
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture != null:
		_bg_view.texture = texture

func _set_memory(on: bool) -> void:
	_memory_mode = on
	_memory_label.visible = on
	if on:
		_dim.color = Color(0.11, 0.07, 0.04, 0.72)
		_text_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.74))
		_panel.color = Color(0.09, 0.06, 0.04, 0.94)
	else:
		_dim.color = Color(0.02, 0.03, 0.04, 0.45)
		_text_label.add_theme_color_override("font_color", SKIN.PAPER)
		_panel.color = Color(0.05, 0.06, 0.07, 0.94)

func _show_choices(options: Array) -> void:
	_text_label.visible = false
	_prompt_label.text = _text_label.text
	_prompt_label.visible = true
	_typing = false
	_choice_box.position = Vector2(64, 486)
	for i in options.size():
		var option: Dictionary = options[i] as Dictionary
		var button := SKIN.make_button(str(option.get("label", "……")), 16, 832.0, 38.0)
		button.position = Vector2(0, i * 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_choice_box.add_child(button)
		button.pressed.connect(_choose.bind(option))

func _choose(option: Dictionary) -> void:
	var flag: String = str(option.get("flag", ""))
	if not flag.is_empty():
		TurnState.set_flag(flag, true)
	_clear_choices()
	_index = _next_index(_index + 1)
	_show_beat()

func _clear_choices() -> void:
	_prompt_label.visible = false
	for child in _choice_box.get_children():
		_choice_box.remove_child(child)
		child.queue_free()

func _finish() -> void:
	if not _playing:
		return
	_playing = false
	visible = false
	var callback: Callable = _on_done
	_on_done = Callable()
	finished.emit()
	if callback.is_valid():
		callback.call()

func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not _playing:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_advance()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_ESCAPE:
		skip()
		get_viewport().set_input_as_handled()
