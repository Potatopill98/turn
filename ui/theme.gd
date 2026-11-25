extends RefCounted

# v3 UI 统一视觉：暖纸、墨色、金色描边。
# 没有 v3 新图时，全部 UI 用色块 + 现有字体搭出来，保证可玩。

const INK := Color("#202a30")
const INK_SOFT := Color("#2b3438")
const PAPER := Color("#f2e9d8")
const PAPER_DIM := Color("#d9cdb8")
const GOLD := Color("#ebc389")
const GOLD_DIM := Color("#a98d63")
const RED := Color("#b8564a")
const GREEN := Color("#7f9c74")
const SHADOW := Color(0.05, 0.06, 0.07, 0.72)

const EMBEDDED_FONT: String = "res://fonts/NotoSansSC-Regular.ttf"

static var _font: Font = null
static var _hand: Font = null

static func font() -> Font:
	if _font == null:
		var embedded: FontFile = FontFile.new()
		if ResourceLoader.exists(EMBEDDED_FONT) and embedded.load_dynamic_font(EMBEDDED_FONT) == OK:
			_font = embedded
		else:
			# 干净机器上内嵌字体缺失时的降级回退链。
			var sys: SystemFont = SystemFont.new()
			sys.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "SimHei"])
			_font = sys
	return _font

static func hand() -> Font:
	if _hand == null:
		# 手写体暂未内嵌可商用字体：回退系统楷体链，缺失时再落黑体。
		var sys: SystemFont = SystemFont.new()
		sys.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
		_hand = sys
	return _hand

static func style(bg: Color, border: Color, border_width: int = 1, radius: int = 4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box

static func make_label(text: String, size: int, color: Color, width: float = 0.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		label.size.x = width
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = align
	return label

static func make_button(text: String, size: int = 16, width: float = 0.0, height: float = 38.0) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", style(INK_SOFT, GOLD_DIM, 1, 4))
	button.add_theme_stylebox_override("hover", style(Color("#33403f"), GOLD, 1, 4))
	button.add_theme_stylebox_override("pressed", style(GOLD, GOLD, 1, 4))
	button.add_theme_stylebox_override("focus", style(Color("#33403f"), GOLD, 2, 4))
	if width > 0.0:
		button.custom_minimum_size = Vector2(width, height)
		button.size = Vector2(width, height)
	return button

static func make_texture(texture: Texture2D, rect: Rect2) -> TextureRect:
	var view := TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture = texture
	view.position = rect.position
	view.size = rect.size
	view.custom_minimum_size = Vector2.ZERO
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

static func paper_board(parent: Node, rect: Rect2) -> ColorRect:
	var board := ColorRect.new()
	board.color = PAPER
	board.position = rect.position
	board.size = rect.size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(board)
	var edge := ColorRect.new()
	edge.color = Color(0.32, 0.24, 0.16, 0.24)
	edge.position = rect.position + Vector2(6, 6)
	edge.size = rect.size + Vector2(10, 10)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(edge)
	parent.move_child(edge, board.get_index())
	return board

static func divider(parent: Node, at: Vector2, length: float, vertical: bool = true) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.30, 0.24, 0.17, 0.28)
	line.position = at
	line.size = Vector2(1, length) if vertical else Vector2(length, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line
