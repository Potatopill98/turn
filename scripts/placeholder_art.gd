extends RefCounted

# 全部占位美术都在这里用 _draw 画出来：不加载任何图片。
# 颜色只表达层次与可读性，不代表最终美术。

# Playtest presentation. Restore the illustration layers here when the art pass resumes.
const USE_SCENE_ILLUSTRATIONS := false

const INK: Color = Color(0.10, 0.10, 0.11, 1.0)
const PAPER: Color = Color(0.93, 0.89, 0.79, 1.0)
const PAPER_DARK: Color = Color(0.78, 0.72, 0.60, 1.0)
const RED: Color = Color(0.72, 0.27, 0.25, 1.0)
const GOLD: Color = Color(0.86, 0.68, 0.34, 1.0)

static var _font: Font = null


static func font() -> Font:
	if _font == null:
		_font = load("res://fonts/NotoSansSC-Regular.ttf") as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


static func text(canvas: CanvasItem, pos: Vector2, value: String, size: int = 13,
		color: Color = Color(0.10, 0.10, 0.11, 1.0), width: float = -1.0,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = font()
	if f == null:
		return
	canvas.draw_string(f, pos, value, align, width, size, color)


static func text_center(canvas: CanvasItem, center_x: float, y: float, value: String,
		size: int = 13, color: Color = Color(0.10, 0.10, 0.11, 1.0)) -> void:
	text(canvas, Vector2(center_x - 160.0, y), value, size, color, 320.0, HORIZONTAL_ALIGNMENT_CENTER)


static func text_width(value: String, size: int) -> float:
	var f: Font = font()
	if f == null:
		return 0.0
	return f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func wrap(value: String, max_width: float, size: int) -> PackedStringArray:
	var f: Font = font()
	var lines: PackedStringArray = PackedStringArray()
	if f == null:
		lines.append(value)
		return lines
	var current: String = ""
	for i in range(value.length()):
		var ch: String = value.substr(i, 1)
		if ch == "\n":
			lines.append(current)
			current = ""
			continue
		var trial: String = current + ch
		var w: float = f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if w > max_width and current.length() > 0:
			lines.append(current)
			current = ch
		else:
			current = trial
	if current.length() > 0:
		lines.append(current)
	return lines


static func rect(canvas: CanvasItem, x: float, y: float, w: float, h: float, fill: Color,
		outline: bool = true, width: float = 2.0) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), fill, true)
	if outline:
		canvas.draw_rect(Rect2(x, y, w, h), INK, false, width)


static func panel(canvas: CanvasItem, x: float, y: float, w: float, h: float,
		fill: Color = PAPER, border: Color = INK) -> void:
	canvas.draw_rect(Rect2(x + 5, y + 5, w, h), Color(0.0, 0.0, 0.0, 0.28), true)
	canvas.draw_rect(Rect2(x, y, w, h), fill, true)
	canvas.draw_rect(Rect2(x, y, w, h), border, false, 2.0)


static func ellipse(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	canvas.draw_colored_polygon(pts, color)


static func shadow(canvas: CanvasItem, x: float, y: float, w: float) -> void:
	ellipse(canvas, Vector2(x, y), w, 7.0, Color(0.0, 0.0, 0.0, 0.28))


static func sky(canvas: CanvasItem, phase: int, width: float, floor_y: float) -> void:
	var top: Color = Color("#8FA3A0")
	var bottom: Color = Color("#E6D3B4")
	if phase == 1:
		top = Color("#626078")
		bottom = Color("#D89563")
	elif phase == 2:
		top = Color("#0D1727")
		bottom = Color("#24394A")
	elif phase == 3:
		top = Color("#9FA9AA")
		bottom = Color("#D7D1C1")
	var steps: int = 36
	for i in range(steps):
		var t: float = float(i) / float(steps)
		var c: Color = top.lerp(bottom, t)
		canvas.draw_rect(Rect2(0.0, floor_y * t, width, floor_y / float(steps) + 2.0), c, true)
	if phase <= 1:
		var sun: Vector2 = Vector2(width * 0.72, floor_y * 0.33)
		if phase == 1:
			sun.y = floor_y * 0.48
		ellipse(canvas, sun, 72.0, 72.0, Color(1.0, 0.88, 0.62, 0.16))
		ellipse(canvas, sun, 34.0, 34.0, Color(1.0, 0.91, 0.69, 0.75))
	elif phase == 2:
		ellipse(canvas, Vector2(width * 0.24, floor_y * 0.26), 46.0, 46.0, Color(0.80, 0.86, 0.88, 0.12))
		ellipse(canvas, Vector2(width * 0.24, floor_y * 0.26), 24.0, 24.0, Color(0.86, 0.90, 0.90, 0.65))
		for i in range(90):
			var x: float = float((i * 137 + 41) % int(width))
			var y: float = float((i * 83 + 17) % int(floor_y * 0.55))
			canvas.draw_rect(Rect2(x, y, 2.0, 2.0), Color(0.9, 0.9, 0.85, 0.35), true)


static func far(canvas: CanvasItem, scene_id: String, phase: int, width: float, floor_y: float) -> void:
	if scene_id.begins_with("house_") or scene_id == "shop" or scene_id == "basement":
		_interior_far(canvas, scene_id, phase, width, floor_y)
		return
	if scene_id == "dream":
		_dream_far(canvas, width, floor_y)
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = abs(hash(scene_id))
	var hill_color: Color = Color("#7A8478")
	if phase == 1:
		hill_color = Color("#8B7767")
	elif phase == 2:
		hill_color = Color("#2A3B43")
	elif phase == 3:
		hill_color = Color("#8C9188")
	# 远山两层
	for band in range(2):
		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(Vector2(-200.0, floor_y - 24.0))
		var segs: int = 9
		for i in range(segs + 1):
			var x: float = -200.0 + (width + 400.0) * float(i) / float(segs)
			var h: float = 70.0 + float((i + band * 3) % 4) * 28.0 + rng.randf_range(-12.0, 12.0)
			pts.append(Vector2(x, floor_y - 38.0 - h))
		pts.append(Vector2(width + 200.0, floor_y - 24.0))
		var c: Color = hill_color
		c.a = 0.55 if band == 0 else 0.38
		canvas.draw_colored_polygon(pts, c)
	# 远处屋顶与窗
	var base_y: float = floor_y - 28.0
	for i in range(12):
		var x: float = rng.randf_range(-50.0, width + 50.0)
		var w: float = rng.randf_range(50.0, 120.0)
		var h: float = rng.randf_range(48.0, 110.0)
		var c: Color = Color("#5D6A66")
		if phase == 2:
			c = Color("#1D2B33")
		c.a = 0.5
		canvas.draw_rect(Rect2(x, base_y - h, w, h), c, true)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8.0, base_y - h),
			Vector2(x + w * 0.5, base_y - h - 24.0),
			Vector2(x + w + 8.0, base_y - h),
		]), c.darkened(0.12))
		if phase >= 2:
			for k in range(3):
				canvas.draw_rect(Rect2(x + 12.0 + k * 22.0, base_y - h + 20.0, 8.0, 6.0),
					Color(0.92, 0.72, 0.38, 0.55), true)
	# 水塔 / 烟囱
	var tower_x: float = width * 0.18
	canvas.draw_rect(Rect2(tower_x, floor_y - 250.0, 8.0, 230.0), hill_color.darkened(0.1), true)
	canvas.draw_rect(Rect2(tower_x + 100.0, floor_y - 210.0, 7.0, 190.0), hill_color.darkened(0.1), true)
	canvas.draw_rect(Rect2(tower_x - 30.0, floor_y - 280.0, 168.0, 44.0), hill_color.darkened(0.2), true)
	# 风车 / 树线
	for i in range(int(width / 420.0) + 2):
		var tx: float = 90.0 + float(i) * 420.0 + rng.randf_range(-30.0, 30.0)
		canvas.draw_rect(Rect2(tx, floor_y - 94.0, 7.0, 84.0), Color(0.22, 0.22, 0.20, 0.45), true)
		ellipse(canvas, Vector2(tx + 3.0, floor_y - 100.0), 34.0, 24.0,
			Color(0.26, 0.32, 0.28, 0.32))


static func _interior_far(canvas: CanvasItem, scene_id: String, phase: int, width: float, floor_y: float) -> void:
	var wall: Color = Color("#8C7E69")
	var floor: Color = Color("#6A5B49")
	if scene_id == "basement":
		wall = Color("#5D554B")
		floor = Color("#4A4138")
	if phase == 2:
		wall = wall.darkened(0.35)
		floor = floor.darkened(0.30)
	if phase == 1:
		wall = wall.lerp(Color("#A8795D"), 0.18)
	canvas.draw_rect(Rect2(0.0, 0.0, width, floor_y + 20.0), wall, true)
	# 墙板
	for i in range(int(width / 96.0) + 1):
		var x: float = float(i) * 96.0
		canvas.draw_line(Vector2(x, 0.0), Vector2(x, floor_y), wall.darkened(0.12), 2.0)
	# 踢脚线
	canvas.draw_rect(Rect2(0.0, floor_y - 26.0, width, 22.0), wall.darkened(0.22), true)
	canvas.draw_rect(Rect2(0.0, floor_y - 4.0, width, 4.0), INK, true)
	# 窗
	var win_x: float = width * 0.62
	rect(canvas, win_x, 96.0, 220.0, 150.0, wall.darkened(0.25), true, 3.0)
	canvas.draw_rect(Rect2(win_x + 12.0, 108.0, 196.0, 126.0),
		Color(0.72, 0.78, 0.74, 0.55) if phase < 2 else Color(0.09, 0.14, 0.20, 1.0), true)
	canvas.draw_line(Vector2(win_x + 110.0, 108.0), Vector2(win_x + 110.0, 234.0), INK, 2.0)
	canvas.draw_line(Vector2(win_x + 12.0, 171.0), Vector2(win_x + 208.0, 171.0), INK, 2.0)
	if phase == 2:
		canvas.draw_rect(Rect2(win_x + 20.0, 116.0, 8.0, 8.0), Color(0.94, 0.77, 0.48, 0.6), true)
	if scene_id == "house_hall":
		# 老钟
		canvas.draw_rect(Rect2(330.0, 88.0, 54.0, 96.0), Color("#6B4A34"), true)
		canvas.draw_circle(Vector2(357.0, 136.0), 18.0, Color("#E8DDC4"), true)
		canvas.draw_circle(Vector2(357.0, 136.0), 18.0, INK, false, 2.0)
		canvas.draw_line(Vector2(357.0, 136.0), Vector2(357.0, 122.0), INK, 2.0)
		canvas.draw_line(Vector2(357.0, 136.0), Vector2(369.0, 142.0), INK, 2.0)
		# 墙上相框
		rect(canvas, 470.0, 86.0, 86.0, 108.0, Color("#D8C7A6"), true, 3.0)
		canvas.draw_rect(Rect2(480.0, 96.0, 66.0, 88.0), Color("#6C7D72"), true)
	# 地下室管道
	if scene_id == "basement":
		canvas.draw_line(Vector2(0.0, 54.0), Vector2(width, 54.0), Color("#3B342D"), 8.0)
		for i in range(int(width / 260.0) + 1):
			canvas.draw_line(Vector2(120.0 + i * 260.0, 54.0), Vector2(120.0 + i * 260.0, 110.0),
				Color("#3B342D"), 6.0)


static func _dream_far(canvas: CanvasItem, width: float, floor_y: float) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, width, floor_y + 30.0), Color("#101B2A"), true)
	for i in range(5):
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, floor_y - 10.0),
			Vector2(width * 0.2 + i * 120.0, floor_y - 250.0 - i * 18.0),
			Vector2(width * 0.45 + i * 80.0, floor_y - 10.0),
		]), Color(0.10, 0.18, 0.25, 0.55))
	# 漂浮的纸片
	for i in range(32):
		var x: float = float((i * 197) % int(width))
		var y: float = float((i * 73) % int(floor_y - 80.0))
		var r: float = 4.0 + float(i % 3) * 2.0
		canvas.draw_rect(Rect2(x, y, r * 2.0, r * 1.2), Color(0.86, 0.82, 0.70, 0.18), true)
	# 月亮
	ellipse(canvas, Vector2(width * 0.8, 96.0), 64.0, 64.0, Color(0.86, 0.88, 0.82, 0.10))
	ellipse(canvas, Vector2(width * 0.8, 96.0), 30.0, 30.0, Color(0.92, 0.90, 0.80, 0.52))


static func mid(canvas: CanvasItem, scene_id: String, phase: int, width: float, floor_y: float) -> void:
	if scene_id == "station":
		_station(canvas, phase, floor_y)
	elif scene_id == "town_gate":
		_town_gate(canvas, phase, floor_y)
	elif scene_id == "street_west":
		_street_west(canvas, phase, floor_y)
	elif scene_id == "street_east":
		_street_east(canvas, phase, floor_y)
	elif scene_id == "playground":
		_playground(canvas, phase, floor_y)
	elif scene_id == "crossing":
		_crossing(canvas, phase, floor_y)
	elif scene_id == "town_final":
		_town_final(canvas, phase, floor_y)
	elif scene_id == "house_yard":
		_house_yard(canvas, phase, floor_y)
	elif scene_id == "house_hall":
		_house_hall(canvas, phase, floor_y)
	elif scene_id == "shop":
		_shop_interior(canvas, phase, floor_y)
	elif scene_id == "basement":
		_basement(canvas, phase, floor_y)
	elif scene_id == "dream":
		_dream_mid(canvas, floor_y)
	else:
		_generic_street(canvas, phase, width, floor_y)


static func _facade(canvas: CanvasItem, x: float, y: float, w: float, h: float,
		wall: Color, roof: Color, phase: int, lit: bool = true) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), wall, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(x - 14.0, y),
		Vector2(x + w * 0.5, y - 42.0),
		Vector2(x + w + 14.0, y),
	]), roof)
	canvas.draw_line(Vector2(x - 14.0, y), Vector2(x + w + 14.0, y), INK, 2.0)
	var cols: int = max(2, int(w / 76.0))
	var rows: int = max(2, int(h / 82.0))
	for r in range(rows):
		for c in range(cols):
			var wx: float = x + 26.0 + c * (w - 52.0) / float(cols)
			var wy: float = y + 22.0 + r * (h - 44.0) / float(rows)
			var ww: float = max(24.0, (w - 52.0) / float(cols) - 20.0)
			var wh: float = 34.0
			var wc: Color = Color("#9AA59C")
			if phase == 2:
				wc = Color("#E0B268") if lit and (r + c) % 3 != 0 else Color("#24333B")
			canvas.draw_rect(Rect2(wx, wy, ww, wh), wc, true)
			canvas.draw_rect(Rect2(wx, wy, ww, wh), INK, false, 2.0)
			canvas.draw_line(Vector2(wx + ww * 0.5, wy), Vector2(wx + ww * 0.5, wy + wh), INK, 1.5)
	# 门
	canvas.draw_rect(Rect2(x + w * 0.46, y + h - 92.0, 46.0, 88.0), Color("#3D332B") if phase < 2 else Color("#24211D"), true)
	canvas.draw_rect(Rect2(x + w * 0.46, y + h - 92.0, 46.0, 88.0), INK, false, 2.0)
	canvas.draw_circle(Vector2(x + w * 0.46 + 38.0, y + h - 48.0), 3.0, GOLD, true)


static func _generic_street(canvas: CanvasItem, phase: int, width: float, floor_y: float) -> void:
	for i in range(int(width / 420.0) + 1):
		var x: float = 40.0 + i * 420.0
		_facade(canvas, x, floor_y - 190.0, 360.0, 190.0, Color("#9C9482"), Color("#54453A"), phase)


static func _station(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 站牌与候车棚
	canvas.draw_line(Vector2(230.0, floor_y - 190.0), Vector2(230.0, floor_y - 10.0), INK, 8.0)
	canvas.draw_rect(Rect2(172.0, floor_y - 250.0, 116.0, 46.0), Color("#D8C8A6"), true)
	text_center(canvas, 230.0, floor_y - 222.0, "镇 口", 20, INK)
	canvas.draw_line(Vector2(172.0, floor_y - 250.0), Vector2(320.0, floor_y - 200.0), Color(0.8, 0.7, 0.5, 0.4), 2.0)
	# 候车棚
	canvas.draw_rect(Rect2(560.0, floor_y - 150.0, 310.0, 8.0), Color("#6C5D49"), true)
	canvas.draw_rect(Rect2(590.0, floor_y - 146.0, 8.0, 146.0), Color("#6C5D49"), true)
	canvas.draw_rect(Rect2(840.0, floor_y - 146.0, 8.0, 146.0), Color("#6C5D49"), true)
	# 远处中巴
	canvas.draw_rect(Rect2(980.0, floor_y - 86.0, 180.0, 64.0), Color("#7A8C85"), true)
	canvas.draw_rect(Rect2(1000.0, floor_y - 78.0, 50.0, 34.0), Color("#B8C4BC"), true)
	canvas.draw_rect(Rect2(1062.0, floor_y - 78.0, 50.0, 34.0), Color("#B8C4BC"), true)
	canvas.draw_circle(Vector2(1016.0, floor_y - 22.0), 13.0, INK, true)
	canvas.draw_circle(Vector2(1120.0, floor_y - 22.0), 13.0, INK, true)
	# 田埂
	for i in range(6):
		canvas.draw_line(Vector2(40.0 + i * 32.0, floor_y - 2.0), Vector2(10.0 + i * 42.0, floor_y + 42.0),
			Color(0.4, 0.42, 0.3, 0.4), 2.0)


static func _town_gate(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 牌坊
	canvas.draw_rect(Rect2(520.0, floor_y - 238.0, 18.0, 230.0), Color("#6B4A3A"), true)
	canvas.draw_rect(Rect2(900.0, floor_y - 238.0, 18.0, 230.0), Color("#6B4A3A"), true)
	canvas.draw_rect(Rect2(500.0, floor_y - 260.0, 438.0, 34.0), Color("#6B4A3A"), true)
	canvas.draw_rect(Rect2(500.0, floor_y - 260.0, 438.0, 34.0), INK, false, 2.0)
	text_center(canvas, 719.0, floor_y - 241.0, "老 街", 20, Color("#E8D6AF"))
	for i in range(3):
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(540.0 + i * 140.0, floor_y - 260.0),
			Vector2(600.0 + i * 140.0, floor_y - 292.0),
			Vector2(660.0 + i * 140.0, floor_y - 260.0),
		]), Color("#6B4A3A"))
	# 告示牌
	canvas.draw_rect(Rect2(1100.0, floor_y - 140.0, 92.0, 70.0), Color("#D8C7A6"), true)
	canvas.draw_line(Vector2(1146.0, floor_y - 70.0), Vector2(1146.0, floor_y), INK, 7.0)
	text_center(canvas, 1146.0, floor_y - 116.0, "告示", 13, INK)
	# 旧车
	canvas.draw_rect(Rect2(300.0, floor_y - 62.0, 150.0, 46.0), Color("#6E7770"), true)
	canvas.draw_rect(Rect2(330.0, floor_y - 84.0, 90.0, 26.0), Color("#6E7770"), true)
	canvas.draw_circle(Vector2(340.0, floor_y - 16.0), 15.0, INK, true)
	canvas.draw_circle(Vector2(420.0, floor_y - 16.0), 15.0, INK, true)


static func _street_west(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 老宅
	_facade(canvas, 560.0, floor_y - 280.0, 380.0, 280.0, Color("#B7A58A"), Color("#5A4438"), phase)
	text_center(canvas, 750.0, floor_y - 252.0, "老 宅", 16, Color("#E8D6AF"))
	# 副食店
	_facade(canvas, 1680.0, floor_y - 214.0, 330.0, 214.0, Color("#A8A18C"), Color("#4F463A"), phase)
	canvas.draw_rect(Rect2(1680.0, floor_y - 206.0, 330.0, 34.0), Color("#7E5B46"), true)
	text_center(canvas, 1845.0, floor_y - 192.0, "副 食 店", 16, Color("#E8D6AF"))
	# 矮墙与树
	canvas.draw_rect(Rect2(0.0, floor_y - 70.0, width_of(canvas), 16.0), Color("#7D7866"), true)
	for i in range(5):
		var tx: float = 120.0 + i * 150.0
		canvas.draw_rect(Rect2(tx, floor_y - 108.0, 8.0, 100.0), Color("#4B4135"), true)
		ellipse(canvas, Vector2(tx + 4.0, floor_y - 126.0), 42.0, 30.0, Color(0.27, 0.34, 0.28, 0.75))
	# 电线
	canvas.draw_line(Vector2(0.0, 60.0), Vector2(2880.0, 48.0), Color(0.15, 0.15, 0.14, 0.5), 2.0)
	canvas.draw_line(Vector2(0.0, 76.0), Vector2(2880.0, 64.0), Color(0.15, 0.15, 0.14, 0.35), 1.0)


static func _street_east(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 修车摊
	canvas.draw_rect(Rect2(760.0, floor_y - 170.0, 300.0, 170.0), Color("#8C8473"), true)
	canvas.draw_rect(Rect2(760.0, floor_y - 170.0, 300.0, 28.0), Color("#5D4A3A"), true)
	text_center(canvas, 910.0, floor_y - 150.0, "修 理", 14, Color("#E8D6AF"))
	canvas.draw_rect(Rect2(820.0, floor_y - 84.0, 180.0, 74.0), Color("#6C5A45"), true)
	# 自行车
	canvas.draw_circle(Vector2(1220.0, floor_y - 20.0), 24.0, Color("#2A2A28"), false, 4.0)
	canvas.draw_circle(Vector2(1300.0, floor_y - 20.0), 24.0, Color("#2A2A28"), false, 4.0)
	canvas.draw_line(Vector2(1220.0, floor_y - 20.0), Vector2(1260.0, floor_y - 70.0), INK, 3.0)
	canvas.draw_line(Vector2(1300.0, floor_y - 20.0), Vector2(1260.0, floor_y - 70.0), INK, 3.0)
	# 海报墙
	canvas.draw_rect(Rect2(1650.0, floor_y - 130.0, 260.0, 120.0), Color("#7C7B6C"), true)
	for i in range(4):
		canvas.draw_rect(Rect2(1672.0 + i * 58.0, floor_y - 112.0, 42.0, 56.0), Color("#D8C7A6"), true)
	# 去游乐场的箭头
	canvas.draw_line(Vector2(2200.0, floor_y - 140.0), Vector2(2300.0, floor_y - 140.0), Color("#E8D6AF"), 6.0)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(2300.0, floor_y - 140.0),
		Vector2(2282.0, floor_y - 152.0),
		Vector2(2282.0, floor_y - 128.0),
	]), Color("#E8D6AF"))
	text(canvas, Vector2(2130.0, floor_y - 162.0), "游乐场", 13, Color("#F0E6CF"))


static func _playground(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 铁栏
	for i in range(28):
		var x: float = 80.0 + i * 96.0
		canvas.draw_line(Vector2(x, floor_y - 84.0), Vector2(x, floor_y - 10.0), Color(0.24, 0.27, 0.25, 0.7), 3.0)
	canvas.draw_line(Vector2(60.0, floor_y - 84.0), Vector2(2800.0, floor_y - 84.0), Color(0.24, 0.27, 0.25, 0.7), 4.0)
	# 大滑梯
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(1420.0, floor_y - 210.0),
		Vector2(1580.0, floor_y - 20.0),
		Vector2(1680.0, floor_y - 20.0),
		Vector2(1560.0, floor_y - 210.0),
	]), Color("#7A8E88"))
	canvas.draw_line(Vector2(1420.0, floor_y - 210.0), Vector2(1560.0, floor_y - 210.0), INK, 4.0)
	# 树
	for i in range(4):
		var tx: float = 180.0 + i * 640.0
		canvas.draw_rect(Rect2(tx, floor_y - 130.0, 10.0, 122.0), Color("#3B332A"), true)
		ellipse(canvas, Vector2(tx + 5.0, floor_y - 150.0), 58.0, 38.0, Color(0.24, 0.31, 0.25, 0.8))
	# 灯柱
	canvas.draw_line(Vector2(500.0, floor_y - 190.0), Vector2(500.0, floor_y - 8.0), Color("#3B3731"), 7.0)
	canvas.draw_line(Vector2(500.0, floor_y - 190.0), Vector2(540.0, floor_y - 190.0), Color("#3B3731"), 7.0)
	canvas.draw_circle(Vector2(548.0, floor_y - 190.0), 12.0, Color(0.92, 0.78, 0.45, 0.85), true)
	if phase == 2:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(540.0, floor_y - 188.0),
			Vector2(620.0, floor_y - 10.0),
			Vector2(490.0, floor_y - 10.0),
		]), Color(0.95, 0.78, 0.42, 0.10))


static func _crossing(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 巷口与远处屋顶
	canvas.draw_rect(Rect2(0.0, floor_y - 190.0, 420.0, 190.0), Color("#8E8574"), true)
	canvas.draw_rect(Rect2(0.0, floor_y - 190.0, 420.0, 24.0), Color("#5D4A3A"), true)
	# 搬家货车
	canvas.draw_rect(Rect2(1720.0, floor_y - 150.0, 300.0, 110.0), Color("#87918C"), true)
	canvas.draw_rect(Rect2(2000.0, floor_y - 190.0, 110.0, 150.0), Color("#87918C"), true)
	canvas.draw_rect(Rect2(2014.0, floor_y - 176.0, 80.0, 50.0), Color("#C2CCC4"), true)
	canvas.draw_circle(Vector2(1790.0, floor_y - 34.0), 22.0, INK, true)
	canvas.draw_circle(Vector2(2020.0, floor_y - 34.0), 22.0, INK, true)
	text(canvas, Vector2(1750.0, floor_y - 132.0), "搬 家", 14, Color("#E8D6AF"))
	# 电线杆
	for i in range(3):
		var x: float = 520.0 + i * 600.0
		canvas.draw_line(Vector2(x, floor_y - 250.0), Vector2(x, floor_y - 8.0), Color("#3B3731"), 6.0)
		canvas.draw_line(Vector2(x - 34.0, floor_y - 236.0), Vector2(x + 34.0, floor_y - 236.0), Color("#3B3731"), 5.0)


static func _town_final(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 镇口灯火：密集的灯与人群剪影
	for i in range(9):
		var x: float = 80.0 + i * 300.0
		canvas.draw_line(Vector2(x, floor_y - 190.0), Vector2(x, floor_y - 8.0), Color("#2C2A27"), 6.0)
		canvas.draw_circle(Vector2(x, floor_y - 196.0), 14.0, Color(0.95, 0.78, 0.44, 0.92), true)
		canvas.draw_circle(Vector2(x, floor_y - 196.0), 48.0, Color(0.95, 0.78, 0.44, 0.10), true)
	# 牌坊
	canvas.draw_rect(Rect2(700.0, floor_y - 250.0, 16.0, 240.0), Color("#4A3A30"), true)
	canvas.draw_rect(Rect2(1080.0, floor_y - 250.0, 16.0, 240.0), Color("#4A3A30"), true)
	canvas.draw_rect(Rect2(680.0, floor_y - 272.0, 436.0, 32.0), Color("#4A3A30"), true)
	text_center(canvas, 898.0, floor_y - 253.0, "镇 口 灯 火", 20, Color("#E8D6AF"))
	# 等车的人影
	for i in range(7):
		var x: float = 180.0 + i * 290.0
		var h: float = 92.0 + float(i % 3) * 12.0
		canvas.draw_rect(Rect2(x, floor_y - h, 22.0, h), Color(0.08, 0.09, 0.10, 0.70), true)
		canvas.draw_circle(Vector2(x + 11.0, floor_y - h - 10.0), 12.0, Color(0.08, 0.09, 0.10, 0.70), true)


static func _house_yard(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	_facade(canvas, 520.0, floor_y - 330.0, 760.0, 330.0, Color("#B4A287"), Color("#584336"), phase)
	text_center(canvas, 900.0, floor_y - 302.0, "老 宅", 20, Color("#E8D6AF"))
	# 院墙
	canvas.draw_rect(Rect2(0.0, floor_y - 95.0, 520.0, 30.0), Color("#8A8372"), true)
	canvas.draw_rect(Rect2(1280.0, floor_y - 95.0, 320.0, 30.0), Color("#8A8372"), true)
	# 树
	canvas.draw_rect(Rect2(1430.0, floor_y - 160.0, 12.0, 150.0), Color("#3B332A"), true)
	ellipse(canvas, Vector2(1436.0, floor_y - 184.0), 64.0, 42.0, Color(0.24, 0.31, 0.25, 0.75))


static func _house_hall(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 沙发、茶几、门口
	canvas.draw_rect(Rect2(420.0, floor_y - 104.0, 190.0, 74.0), Color("#6A5947"), true)
	canvas.draw_rect(Rect2(420.0, floor_y - 134.0, 190.0, 34.0), Color("#7C6A54"), true)
	canvas.draw_rect(Rect2(430.0, floor_y - 140.0, 170.0, 18.0), Color("#8C7961"), true)
	canvas.draw_rect(Rect2(780.0, floor_y - 92.0, 160.0, 12.0), Color("#5A4534"), true)
	canvas.draw_rect(Rect2(800.0, floor_y - 80.0, 10.0, 70.0), Color("#4A392B"), true)
	canvas.draw_rect(Rect2(910.0, floor_y - 80.0, 10.0, 70.0), Color("#4A392B"), true)
	# 门
	canvas.draw_rect(Rect2(1540.0, floor_y - 210.0, 120.0, 210.0), Color("#5A4334"), true)
	canvas.draw_rect(Rect2(1552.0, floor_y - 198.0, 96.0, 198.0), Color("#3D2E25"), true)
	canvas.draw_circle(Vector2(1634.0, floor_y - 108.0), 4.0, GOLD, true)
	# 走廊阴影
	canvas.draw_rect(Rect2(1440.0, floor_y - 240.0, 480.0, 240.0), Color(0.0, 0.0, 0.0, 0.12), true)


static func _shop_interior(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 货架
	canvas.draw_rect(Rect2(120.0, floor_y - 260.0, 420.0, 250.0), Color("#75634E"), true)
	for r in range(3):
		canvas.draw_line(Vector2(120.0, floor_y - 190.0 + r * 62.0), Vector2(540.0, floor_y - 190.0 + r * 62.0),
			Color("#4B3D31"), 5.0)
	for i in range(12):
		var x: float = 146.0 + (i % 4) * 96.0
		var y: float = floor_y - 230.0 + (i / 4) * 62.0
		canvas.draw_rect(Rect2(x, y, 44.0, 32.0), Color("#C9B58D"), true)
	# 柜台
	canvas.draw_rect(Rect2(720.0, floor_y - 118.0, 260.0, 110.0), Color("#6B513D"), true)
	canvas.draw_rect(Rect2(720.0, floor_y - 118.0, 260.0, 14.0), Color("#8C6B4A"), true)


static func _basement(canvas: CanvasItem, phase: int, floor_y: float) -> void:
	# 架子与旧箱
	canvas.draw_rect(Rect2(120.0, floor_y - 230.0, 300.0, 220.0), Color("#4A4038"), true)
	for r in range(3):
		canvas.draw_line(Vector2(120.0, floor_y - 168.0 + r * 60.0), Vector2(420.0, floor_y - 168.0 + r * 60.0),
			Color("#2B2521"), 5.0)
	# 吊灯
	canvas.draw_line(Vector2(980.0, 0.0), Vector2(980.0, 116.0), Color("#2A2521"), 3.0)
	canvas.draw_circle(Vector2(980.0, 124.0), 12.0, Color(0.92, 0.78, 0.45, 0.9), true)
	canvas.draw_circle(Vector2(980.0, 124.0), 90.0, Color(0.92, 0.78, 0.45, 0.08), true)


static func _dream_mid(canvas: CanvasItem, floor_y: float) -> void:
	# 教室
	canvas.draw_rect(Rect2(420.0, floor_y - 230.0, 760.0, 230.0), Color(0.15, 0.22, 0.28, 0.7), true)
	for i in range(6):
		canvas.draw_rect(Rect2(500.0 + i * 110.0, floor_y - 78.0, 74.0, 12.0), Color("#5E5B4E"), true)
		canvas.draw_rect(Rect2(510.0 + i * 110.0, floor_y - 66.0, 8.0, 58.0), Color("#3B3830"), true)
		canvas.draw_rect(Rect2(556.0 + i * 110.0, floor_y - 66.0, 8.0, 58.0), Color("#3B3830"), true)
	# 巷子
	canvas.draw_rect(Rect2(1400.0, floor_y - 280.0, 360.0, 280.0), Color(0.10, 0.14, 0.17, 0.7), true)
	canvas.draw_rect(Rect2(1760.0, floor_y - 240.0, 300.0, 240.0), Color(0.08, 0.11, 0.14, 0.7), true)
	# 秋千影子
	canvas.draw_line(Vector2(2380.0, floor_y - 210.0), Vector2(2520.0, floor_y - 210.0), Color(0.8, 0.8, 0.7, 0.4), 4.0)
	canvas.draw_line(Vector2(2440.0, floor_y - 210.0), Vector2(2440.0, floor_y - 40.0), Color(0.8, 0.8, 0.7, 0.4), 2.0)
	canvas.draw_line(Vector2(2480.0, floor_y - 210.0), Vector2(2480.0, floor_y - 40.0), Color(0.8, 0.8, 0.7, 0.4), 2.0)
	canvas.draw_rect(Rect2(2434.0, floor_y - 46.0, 54.0, 8.0), Color(0.8, 0.8, 0.7, 0.45), true)
	# 车站钟
	canvas.draw_circle(Vector2(3220.0, floor_y - 160.0), 54.0, Color(0.75, 0.76, 0.70, 0.30), true)
	canvas.draw_circle(Vector2(3220.0, floor_y - 160.0), 54.0, Color(0.85, 0.86, 0.80, 0.45), false, 3.0)
	canvas.draw_line(Vector2(3220.0, floor_y - 160.0), Vector2(3220.0, floor_y - 196.0), Color(0.9, 0.9, 0.8, 0.7), 3.0)
	canvas.draw_line(Vector2(3220.0, floor_y - 160.0), Vector2(3248.0, floor_y - 142.0), Color(0.9, 0.9, 0.8, 0.7), 3.0)


static func ground(canvas: CanvasItem, scene_id: String, phase: int, width: float, floor_y: float) -> void:
	if scene_id.begins_with("house_") or scene_id == "shop" or scene_id == "basement":
		canvas.draw_rect(Rect2(0.0, floor_y, width, 540.0 - floor_y), Color("#4A3C30"), true)
		for i in range(int(width / 64.0) + 1):
			canvas.draw_line(Vector2(i * 64.0, floor_y), Vector2(i * 64.0 - 20.0, 540.0),
				Color(0.22, 0.17, 0.13, 0.5), 2.0)
		canvas.draw_line(Vector2(0.0, floor_y + 6.0), Vector2(width, floor_y + 6.0), Color(0.16, 0.12, 0.09, 0.6), 3.0)
		if scene_id == "house_hall":
			canvas.draw_rect(Rect2(250.0, floor_y + 34.0, 570.0, 80.0), Color(0.45, 0.28, 0.24, 0.45), true)
		return
	if scene_id == "dream":
		for i in range(int(width / 48.0) + 1):
			canvas.draw_rect(Rect2(i * 48.0, floor_y, 48.0, 540.0 - floor_y),
				Color(0.12, 0.16, 0.18, 0.8) if i % 2 == 0 else Color(0.09, 0.12, 0.15, 0.8), true)
		canvas.draw_line(Vector2(0.0, floor_y), Vector2(width, floor_y), Color(0.5, 0.5, 0.4, 0.4), 2.0)
		return
	var road: Color = Color("#4D4A42")
	if phase == 1:
		road = Color("#51463E")
	elif phase == 2:
		road = Color("#242B2D")
	canvas.draw_rect(Rect2(0.0, floor_y, width, 540.0 - floor_y), road, true)
	canvas.draw_rect(Rect2(0.0, floor_y, width, 12.0), Color("#8E8776"), true)
	canvas.draw_line(Vector2(0.0, floor_y + 12.0), Vector2(width, floor_y + 12.0), Color(0.18, 0.16, 0.13, 0.7), 3.0)
	# 路面裂缝 / 石块
	for i in range(int(width / 180.0) + 1):
		var x: float = 60.0 + i * 180.0
		canvas.draw_line(Vector2(x, floor_y + 28.0), Vector2(x + 34.0, floor_y + 42.0), Color(0.12, 0.12, 0.11, 0.3), 2.0)
	# 水洼
	ellipse(canvas, Vector2(width * 0.35, floor_y + 64.0), 44.0, 8.0, Color(0.30, 0.38, 0.41, 0.35))
	ellipse(canvas, Vector2(width * 0.72, floor_y + 72.0), 28.0, 5.0, Color(0.30, 0.38, 0.41, 0.28))


static func near(canvas: CanvasItem, scene_id: String, phase: int, width: float, floor_y: float) -> void:
	# 前景草、栏杆、线缆；z 在玩家前面，制造纵深
	if scene_id.begins_with("house_") or scene_id == "shop" or scene_id == "basement":
		canvas.draw_rect(Rect2(0.0, 0.0, 18.0, 540.0), Color(0.0, 0.0, 0.0, 0.18), true)
		canvas.draw_rect(Rect2(width - 18.0, 0.0, 18.0, 540.0), Color(0.0, 0.0, 0.0, 0.18), true)
		return
	if scene_id == "dream":
		for i in range(9):
			var x: float = float((i * 317) % int(width))
			canvas.draw_rect(Rect2(x, floor_y - 36.0, 3.0, 44.0), Color(0.75, 0.76, 0.68, 0.18), true)
		return
	for i in range(int(width / 240.0) + 2):
		var x: float = 40.0 + i * 240.0
		canvas.draw_line(Vector2(x, floor_y + 18.0), Vector2(x - 8.0, floor_y - 26.0), Color(0.18, 0.24, 0.18, 0.55), 2.0)
		canvas.draw_line(Vector2(x + 6.0, floor_y + 18.0), Vector2(x + 22.0, floor_y - 18.0), Color(0.18, 0.24, 0.18, 0.42), 2.0)
	# 顶部电线
	canvas.draw_line(Vector2(0.0, 26.0), Vector2(width, 18.0), Color(0.08, 0.08, 0.07, 0.55), 2.0)
	if phase == 2:
		canvas.draw_rect(Rect2(0.0, 0.0, width, 540.0), Color(0.03, 0.07, 0.12, 0.12), true)


static func prop(canvas: CanvasItem, data: Dictionary, phase: int, t: float,
		highlight: bool, state: String) -> void:
	var kind: String = str(data.get("kind", "marker"))
	var x: float = float(data.get("x", 0.0))
	var floor_y: float = 456.0
	if data.has("floor_y"):
		floor_y = float(data.get("floor_y", 456.0))
	var label: String = str(data.get("label", ""))
	var bob: float = sin(t * 2.2 + x) * 2.0
	if kind == "swing":
		var base_y: float = floor_y
		canvas.draw_line(Vector2(x - 54.0, base_y - 190.0), Vector2(x - 54.0, base_y), Color("#3C3731"), 6.0)
		canvas.draw_line(Vector2(x + 54.0, base_y - 190.0), Vector2(x + 54.0, base_y), Color("#3C3731"), 6.0)
		canvas.draw_line(Vector2(x - 70.0, base_y - 190.0), Vector2(x + 70.0, base_y - 190.0), Color("#3C3731"), 7.0)
		var swing_angle: float = sin(t * 1.1) * 0.18
		if state == "held":
			swing_angle = 0.0
		elif state == "done":
			swing_angle *= 0.23
		var pivot: Vector2 = Vector2(x, base_y - 186.0)
		var end: Vector2 = pivot + Vector2(sin(swing_angle) * 150.0, cos(swing_angle) * 150.0)
		canvas.draw_line(pivot + Vector2(-16.0, 0.0), end + Vector2(-16.0, 0.0), Color("#2B2925"), 3.0)
		canvas.draw_line(pivot + Vector2(16.0, 0.0), end + Vector2(16.0, 0.0), Color("#2B2925"), 3.0)
		canvas.draw_rect(Rect2(end.x - 32.0, end.y, 64.0, 10.0), Color("#8C5D42"), true)
		shadow(canvas, x, floor_y + 4.0, 46.0)
	elif kind == "bench":
		canvas.draw_rect(Rect2(x - 54.0, floor_y - 42.0, 108.0, 10.0), Color("#8A6747"), true)
		canvas.draw_rect(Rect2(x - 54.0, floor_y - 56.0, 108.0, 10.0), Color("#8A6747"), true)
		canvas.draw_rect(Rect2(x - 42.0, floor_y - 32.0, 8.0, 32.0), Color("#3C332B"), true)
		canvas.draw_rect(Rect2(x + 34.0, floor_y - 32.0, 8.0, 32.0), Color("#3C332B"), true)
	elif kind == "score":
		if state == "done":
			canvas.draw_rect(Rect2(x - 20.0, floor_y - 34.0, 40.0, 30.0), PAPER, true)
			for i in range(3):
				canvas.draw_line(Vector2(x - 14.0, floor_y - 28.0 + i * 7.0), Vector2(x + 14.0, floor_y - 28.0 + i * 7.0),
					Color(0.25, 0.24, 0.2, 0.6), 1.0)
		else:
			for i in range(5):
				var px: float = x - 40.0 + i * 18.0
				var py: float = floor_y - 8.0 - float(i % 3) * 6.0
				canvas.draw_rect(Rect2(px, py, 26.0, 32.0), PAPER, true)
				canvas.draw_line(Vector2(px + 4.0, py + 8.0), Vector2(px + 22.0, py + 8.0), Color(0.25, 0.24, 0.2, 0.45), 1.0)
	elif kind == "shoes":
		var glow: float = 0.45 + 0.25 * sin(t * 3.0)
		canvas.draw_circle(Vector2(x, floor_y - 10.0), 42.0, Color(0.95, 0.66, 0.45, 0.10 + glow * 0.08), true)
		canvas.draw_rect(Rect2(x - 28.0, floor_y - 18.0, 24.0, 10.0), Color("#B84E42"), true)
		canvas.draw_rect(Rect2(x - 8.0, floor_y - 14.0, 24.0, 10.0), Color("#B84E42"), true)
		canvas.draw_circle(Vector2(x - 22.0, floor_y - 8.0), 4.0, Color("#B84E42"), true)
		canvas.draw_circle(Vector2(x + 12.0, floor_y - 4.0), 4.0, Color("#B84E42"), true)
	elif kind == "box":
		var offset: float = 0.0
		if state == "done":
			offset = -22.0
		canvas.draw_rect(Rect2(x - 34.0, floor_y - 54.0 + offset, 68.0, 52.0), Color("#A77C4E"), true)
		canvas.draw_line(Vector2(x, floor_y - 54.0 + offset), Vector2(x, floor_y - 2.0 + offset), Color(0.4, 0.28, 0.17, 0.7), 2.0)
		canvas.draw_line(Vector2(x - 34.0, floor_y - 32.0 + offset), Vector2(x + 34.0, floor_y - 32.0 + offset),
			Color(0.4, 0.28, 0.17, 0.7), 2.0)
	elif kind == "car":
		canvas.draw_rect(Rect2(x - 110.0, floor_y - 62.0, 220.0, 50.0), Color("#6D7B77"), true)
		canvas.draw_rect(Rect2(x - 76.0, floor_y - 92.0, 110.0, 34.0), Color("#6D7B77"), true)
		canvas.draw_rect(Rect2(x - 64.0, floor_y - 85.0, 84.0, 24.0), Color("#B6C2BB"), true)
		canvas.draw_circle(Vector2(x - 70.0, floor_y - 12.0), 17.0, INK, true)
		canvas.draw_circle(Vector2(x + 70.0, floor_y - 12.0), 17.0, INK, true)
	elif kind == "bus":
		canvas.draw_rect(Rect2(x - 90.0, floor_y - 74.0, 180.0, 62.0), Color("#7C8A83"), true)
		canvas.draw_rect(Rect2(x - 74.0, floor_y - 66.0, 62.0, 32.0), Color("#B8C4BC"), true)
		canvas.draw_rect(Rect2(x + 2.0, floor_y - 66.0, 62.0, 32.0), Color("#B8C4BC"), true)
		canvas.draw_circle(Vector2(x - 54.0, floor_y - 12.0), 12.0, INK, true)
		canvas.draw_circle(Vector2(x + 54.0, floor_y - 12.0), 12.0, INK, true)
	elif kind == "photo":
		canvas.draw_rect(Rect2(x - 26.0, floor_y - 42.0, 52.0, 38.0), Color("#D8C7A6"), true)
		canvas.draw_rect(Rect2(x - 20.0, floor_y - 36.0, 40.0, 26.0), Color("#71847A"), true)
		canvas.draw_circle(Vector2(x - 4.0, floor_y - 22.0), 5.0, Color("#C7B18A"), true)
	elif kind == "note":
		canvas.draw_rect(Rect2(x - 20.0, floor_y - 34.0, 40.0, 28.0), Color("#E7D7B8"), true)
		for i in range(3):
			canvas.draw_line(Vector2(x - 14.0, floor_y - 28.0 + i * 6.0), Vector2(x + 14.0, floor_y - 28.0 + i * 6.0),
				Color(0.25, 0.24, 0.20, 0.5), 1.0)
	elif kind == "chest":
		canvas.draw_rect(Rect2(x - 54.0, floor_y - 66.0, 108.0, 62.0), Color("#6A4A34"), true)
		canvas.draw_rect(Rect2(x - 54.0, floor_y - 74.0, 108.0, 14.0), Color("#7C5940"), true)
		canvas.draw_rect(Rect2(x - 6.0, floor_y - 48.0, 12.0, 18.0), GOLD, true)
		if state == "open":
			canvas.draw_rect(Rect2(x - 54.0, floor_y - 112.0, 108.0, 38.0), Color("#5D4030"), true)
	elif kind == "lamp":
		canvas.draw_line(Vector2(x, floor_y - 210.0), Vector2(x, floor_y), Color("#3B3731"), 7.0)
		canvas.draw_line(Vector2(x, floor_y - 210.0), Vector2(x + 44.0, floor_y - 210.0), Color("#3B3731"), 7.0)
		var lamp_center := Vector2(x + 48.0, floor_y - 205.0)
		canvas.draw_rect(Rect2(lamp_center - Vector2(10, 10), Vector2(20, 16)), Color("#F4D589") if phase >= 2 else Color("#868A80"))
		if phase >= 2:
			canvas.draw_circle(lamp_center, 39.0, Color(0.94, 0.79, 0.46, 0.17), true)
			ellipse(canvas, Vector2(x + 48.0, floor_y), 96.0, 11.0, Color(0.94, 0.79, 0.46, 0.27))
	elif kind == "sign":
		canvas.draw_line(Vector2(x, floor_y - 80.0), Vector2(x, floor_y), Color("#4A3D31"), 6.0)
		canvas.draw_rect(Rect2(x - 56.0, floor_y - 132.0, 112.0, 58.0), Color("#D8C7A6"), true)
		text_center(canvas, x, floor_y - 108.0, label, 13, INK)
	elif kind == "mailbox":
		canvas.draw_rect(Rect2(x - 24.0, floor_y - 76.0, 48.0, 58.0), Color("#6A7A72"), true)
		canvas.draw_rect(Rect2(x - 28.0, floor_y - 82.0, 56.0, 10.0), Color("#54645D"), true)
	elif kind == "counter":
		canvas.draw_rect(Rect2(x - 80.0, floor_y - 70.0, 160.0, 62.0), Color("#6B513D"), true)
		canvas.draw_rect(Rect2(x - 80.0, floor_y - 70.0, 160.0, 12.0), Color("#8C6B4A"), true)
	elif kind == "watch":
		var center := Vector2(x, floor_y - 15)
		canvas.draw_rect(Rect2(x - 15, floor_y - 30, 30, 28), Color("#9C7852"))
		canvas.draw_circle(center, 11, PAPER)
		var angle := -PI / 2 - (TAU / 12 if GameState.has_flag("station_turned") else 0.0)
		canvas.draw_line(center, center + Vector2.from_angle(angle) * 8, Color("#A64D34"), 2, true)
	elif kind == "clock":
		canvas.draw_circle(Vector2(x, floor_y - 150.0), 26.0, Color("#E8DDC4"), true)
		canvas.draw_circle(Vector2(x, floor_y - 150.0), 26.0, INK, false, 2.0)
		canvas.draw_line(Vector2(x, floor_y - 150.0), Vector2(x, floor_y - 166.0), INK, 2.0)
	elif kind == "bicycle":
		canvas.draw_circle(Vector2(x - 30.0, floor_y - 20.0), 20.0, Color("#2A2A28"), false, 3.0)
		canvas.draw_circle(Vector2(x + 30.0, floor_y - 20.0), 20.0, Color("#2A2A28"), false, 3.0)
		canvas.draw_line(Vector2(x - 30.0, floor_y - 20.0), Vector2(x, floor_y - 58.0), INK, 2.0)
		canvas.draw_line(Vector2(x + 30.0, floor_y - 20.0), Vector2(x, floor_y - 58.0), INK, 2.0)
	elif kind == "poster":
		canvas.draw_rect(Rect2(x - 40.0, floor_y - 130.0, 80.0, 100.0), Color("#D8C7A6"), true)
		for i in range(5):
			canvas.draw_line(Vector2(x - 30.0, floor_y - 116.0 + i * 12.0), Vector2(x + 30.0, floor_y - 116.0 + i * 12.0),
				Color(0.2, 0.2, 0.18, 0.5), 1.0)
	elif kind == "puddle":
		ellipse(canvas, Vector2(x, floor_y + 12.0), 44.0, 7.0, Color(0.35, 0.42, 0.45, 0.4))
	elif kind == "dream_desk":
		canvas.draw_rect(Rect2(x - 44.0, floor_y - 64.0, 88.0, 10.0), Color(0.34, 0.34, 0.28, 0.6), true)
		canvas.draw_rect(Rect2(x - 34.0, floor_y - 54.0, 8.0, 54.0), Color(0.24, 0.24, 0.20, 0.6), true)
		canvas.draw_rect(Rect2(x + 26.0, floor_y - 54.0, 8.0, 54.0), Color(0.24, 0.24, 0.20, 0.6), true)
	elif kind == "dream_clock":
		canvas.draw_circle(Vector2(x, floor_y - 150.0), 48.0, Color(0.85, 0.84, 0.74, 0.30), true)
		canvas.draw_circle(Vector2(x, floor_y - 150.0), 48.0, Color(0.85, 0.84, 0.74, 0.45), false, 3.0)
	else:
		canvas.draw_rect(Rect2(x - 10.0, floor_y - 10.0, 20.0, 10.0), Color("#E8C56A"), true)
	if bool(data.get("interact", false)) and highlight:
		var ring_y: float = floor_y - 14.0 + bob
		canvas.draw_circle(Vector2(x, ring_y), 16.0, Color(0.94, 0.82, 0.45, 0.80), false, 2.0)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(x, ring_y - 26.0),
			Vector2(x + 7.0, ring_y - 34.0),
			Vector2(x - 7.0, ring_y - 34.0),
		]), Color(0.94, 0.82, 0.45, 0.9))
	if not label.is_empty() and (USE_SCENE_ILLUSTRATIONS or highlight):
		var label_dy: float = float(data.get("label_dy", 0.0))
		var tag_y: float = floor_y - 156.0 + label_dy
		var tag_w: float = max(54.0, text_width(label, 11) + 16.0)
		canvas.draw_rect(Rect2(x - tag_w * 0.5, tag_y, tag_w, 20.0), Color(0.08, 0.09, 0.09, 0.78), true)
		canvas.draw_rect(Rect2(x - tag_w * 0.5, tag_y, tag_w, 20.0), Color(0.7, 0.65, 0.5, 0.5), false, 1.0)
		text(canvas, Vector2(x - tag_w * 0.5 + 8.0, tag_y + 15.0), label, 11, Color("#EFE4CE"))


static func actor(canvas: CanvasItem, data: Dictionary, t: float, moving: bool,
		direction: int, highlight: bool) -> void:
	var style: String = str(data.get("style", "player"))
	var name: String = str(data.get("name", ""))
	var bob: float = sin(t * 2.4) * 1.2
	var step: float = sin(t * 9.0) * 5.0 if moving else 0.0
	var leg_l: float = step
	var leg_r: float = -step
	var body_color: Color = Color("#D9B36A")
	var head_color: Color = Color("#D7B58E")
	var hair: Color = Color("#2B2622")
	var accent: Color = Color("#6A7F73")
	if style == "zhou":
		body_color = Color("#5E7169")
		head_color = Color("#C9A47E")
		hair = Color("#7B7B70")
		accent = Color("#3F4E49")
	elif style == "xiaoman":
		body_color = Color("#7C5A62")
		head_color = Color("#D8B796")
		hair = Color("#241F1E")
		accent = Color("#B08A5A")
	elif style == "tang":
		body_color = Color("#A48C78")
		head_color = Color("#D8B796")
		hair = Color("#31251F")
		accent = Color("#C9B18B")
	elif style == "wu":
		body_color = Color("#6F756C")
		head_color = Color("#C6A37E")
		hair = Color("#6A6258")
		accent = Color("#3A3E3A")
	elif style == "chen":
		body_color = Color("#6C5848")
		head_color = Color("#C9A47E")
		hair = Color("#4A4238")
		accent = Color("#8A7158")
	elif style == "mom":
		body_color = Color("#8C6B62")
		head_color = Color("#D8B796")
		hair = Color("#3A2E28")
		accent = Color("#D8C7A6")
	elif style == "shop":
		body_color = Color("#7C7464")
		head_color = Color("#C9A47E")
		hair = Color("#4A4238")
		accent = Color("#A58B5E")
	# 影子
	shadow(canvas, 0.0, 2.0, 30.0)
	# 腿
	rect(canvas, -22.0 + leg_l, -38.0, 15.0, 38.0, body_color.darkened(0.15), true, 2.0)
	rect(canvas, 7.0 + leg_r, -38.0, 15.0, 38.0, body_color.darkened(0.15), true, 2.0)
	canvas.draw_rect(Rect2(-26.0 + leg_l, -6.0, 22.0, 6.0), INK, true)
	canvas.draw_rect(Rect2(6.0 + leg_r, -6.0, 22.0, 6.0), INK, true)
	# 身体
	var body_y: float = -86.0 + bob
	rect(canvas, -25.0, body_y, 50.0, 48.0, body_color, true, 2.0)
	# 围裙 / 背带 / 衣领
	if style == "mom":
		canvas.draw_rect(Rect2(-10.0, body_y + 8.0, 20.0, 38.0), Color("#D8C7A6"), true)
	if style == "zhou":
		canvas.draw_rect(Rect2(-16.0, body_y + 4.0, 6.0, 42.0), accent, true)
		canvas.draw_rect(Rect2(10.0, body_y + 4.0, 6.0, 42.0), accent, true)
	if style == "player":
		canvas.draw_rect(Rect2(-31.0, body_y + 6.0, 12.0, 34.0), Color("#4C5D55"), true)
	# 手臂
	var arm_y: float = body_y + 10.0
	canvas.draw_rect(Rect2(-31.0 if direction > 0 else 23.0, arm_y, 9.0, 30.0), body_color.darkened(0.08), true)
	canvas.draw_rect(Rect2(-31.0 if direction > 0 else 23.0, arm_y, 9.0, 30.0), INK, false, 2.0)
	# 头
	canvas.draw_circle(Vector2(0.0, body_y - 18.0), 19.0, INK, true)
	canvas.draw_circle(Vector2(0.0, body_y - 18.0), 17.0, head_color, true)
	# 头发 / 帽子
	if style == "player":
		canvas.draw_rect(Rect2(-18.0, body_y - 42.0, 36.0, 12.0), Color("#3C4A43"), true)
		canvas.draw_rect(Rect2(-24.0, body_y - 34.0, 48.0, 5.0), Color("#3C4A43"), true)
	elif style == "zhou":
		canvas.draw_rect(Rect2(-18.0, body_y - 38.0, 36.0, 9.0), Color("#3F4E49"), true)
	elif style == "tang":
		canvas.draw_rect(Rect2(-20.0, body_y - 36.0, 12.0, 30.0), hair, true)
		canvas.draw_rect(Rect2(8.0, body_y - 36.0, 12.0, 30.0), hair, true)
	elif style == "xiaoman":
		canvas.draw_rect(Rect2(-21.0, body_y - 34.0, 9.0, 50.0), hair, true)
		canvas.draw_rect(Rect2(12.0, body_y - 34.0, 9.0, 50.0), hair, true)
	else:
		canvas.draw_rect(Rect2(-18.0, body_y - 36.0, 36.0, 8.0), hair, true)
	# 眼睛 / 方向
	var eye_x: float = 6.0 if direction > 0 else -6.0
	canvas.draw_rect(Rect2(eye_x - 2.0, body_y - 22.0, 4.0, 4.0), INK, true)
	# 道具
	if style == "xiaoman":
		canvas.draw_rect(Rect2(-36.0, body_y + 6.0, 12.0, 64.0), Color("#5B4436"), true)
		canvas.draw_rect(Rect2(-40.0, body_y + 2.0, 20.0, 10.0), Color("#7C5A46"), true)
	elif style == "tang":
		canvas.draw_rect(Rect2(-34.0, body_y + 28.0, 18.0, 22.0), Color("#C9B18B"), true)
	elif style == "wu":
		canvas.draw_circle(Vector2(eye_x, body_y - 20.0), 7.0, Color(0.1, 0.1, 0.1, 0.15), true)
		canvas.draw_circle(Vector2(eye_x, body_y - 20.0), 7.0, INK, false, 1.0)
	# 名字牌
	if not name.is_empty():
		var tag_w: float = max(54.0, text_width(name, 11) + 14.0)
		canvas.draw_rect(Rect2(-tag_w * 0.5, body_y - 64.0, tag_w, 18.0), Color(0.08, 0.09, 0.09, 0.82), true)
		text(canvas, Vector2(-tag_w * 0.5 + 7.0, body_y - 50.0), name, 11, Color("#EFE4CE"))
	if highlight:
		canvas.draw_circle(Vector2(0.0, body_y - 78.0), 5.0, Color(0.96, 0.82, 0.38, 0.9), true)
		canvas.draw_circle(Vector2(0.0, body_y - 78.0), 10.0, Color(0.96, 0.82, 0.38, 0.22), true)


static func door(canvas: CanvasItem, label: String, active: bool, interior: bool) -> void:
	var wall: Color = Color("#3D2E25") if not interior else Color("#2B211B")
	canvas.draw_rect(Rect2(-38.0, -180.0, 76.0, 180.0), Color(0.0, 0.0, 0.0, 0.25), true)
	canvas.draw_rect(Rect2(-34.0, -176.0, 68.0, 176.0), Color("#4A392B"), true)
	canvas.draw_rect(Rect2(-28.0, -168.0, 56.0, 168.0), wall, true)
	canvas.draw_rect(Rect2(-28.0, -168.0, 56.0, 168.0), INK, false, 2.0)
	canvas.draw_circle(Vector2(18.0, -82.0), 4.0, GOLD, true)
	canvas.draw_line(Vector2(-34.0, -176.0), Vector2(34.0, -176.0), INK, 3.0)
	if active:
		canvas.draw_rect(Rect2(-34.0, -176.0, 68.0, 176.0), Color(0.95, 0.78, 0.38, 0.55), false, 3.0)
		canvas.draw_circle(Vector2(0.0, -190.0), 6.0, Color(0.96, 0.82, 0.38, 0.9), true)
	var tag_w: float = max(60.0, text_width(label, 11) + 14.0)
	canvas.draw_rect(Rect2(-tag_w * 0.5, -222.0, tag_w, 20.0), Color(0.08, 0.09, 0.09, 0.8), true)
	text(canvas, Vector2(-tag_w * 0.5 + 7.0, -207.0), label, 11, Color("#EFE4CE"))


static func width_of(canvas: CanvasItem) -> float:
	# 仅用于旧签名里的默认宽度，不从 canvas 取真实尺寸。
	return 2880.0
