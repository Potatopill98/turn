extends CanvasLayer

# B1 演出层：四类动画各自独立实现，不共用同一个 _fade()。
# 1) 拾取物证：图标从热点世界坐标飞向右上手记按钮，加速曲线 + 缩放 + 拖尾，落点按钮脉冲。
# 2) 开门：门扇绕枢轴旋转 + 门缝光溢出 + 后接黑场。
# 3) 入梦：灰度 + 径向缩放 + 白噪闪一下。
# 4) 换地点：横向擦除，地图从一侧滑入。

const SKIN = preload("res://ui/theme.gd")

const PICKUP_DURATION: float = 0.55
const DOOR_DURATION: float = 0.62
const DREAM_DURATION: float = 0.90
const WIPE_DURATION: float = 0.50

const JOURNAL_TARGET: Vector2 = Vector2(806, 28)

# ---- 拾取飞行 ----
var _pickup_icon: Panel = null
var _pickup_label: Label = null
var _pickup_from: Vector2 = Vector2.ZERO
var _pickup_to: Vector2 = JOURNAL_TARGET
var _pickup_t: float = 0.0
var _pickup_target: Control = null
var _pickup_done: Callable = Callable()
var _ghosts: Array[ColorRect] = []

# ---- 开门 ----
var _door_root: Control = null
var _door_black: ColorRect = null

# ---- 入梦 ----
var _dream_root: Control = null

# ---- 擦除 ----
var _wipe_root: Control = null

func _process(delta: float) -> void:
	if _pickup_icon != null:
		_pickup_t += delta
		var k: float = clampf(_pickup_t / PICKUP_DURATION, 0.0, 1.0)
		_update_pickup(k)

# ============================================================ 1. 拾取飞行

func play_pickup(from_screen: Vector2, text: String, target: Control, on_done: Callable) -> void:
	_clear_pickup()
	_pickup_from = from_screen
	_pickup_to = JOURNAL_TARGET
	_pickup_target = target
	_pickup_done = on_done
	_pickup_t = 0.0

	_pickup_icon = Panel.new()
	_pickup_icon.position = from_screen - Vector2(13, 13)
	_pickup_icon.size = Vector2(26, 26)
	_pickup_icon.add_theme_stylebox_override("panel", SKIN.style(SKIN.GOLD, SKIN.INK, 1, 6))
	add_child(_pickup_icon)

	_pickup_label = SKIN.make_label("证", 13, SKIN.INK, 26.0, HORIZONTAL_ALIGNMENT_CENTER)
	_pickup_label.position = Vector2(0, 4)
	_pickup_icon.add_child(_pickup_label)

	var tw: Tween = create_tween()
	tw.tween_method(_set_pickup_progress, 0.0, 1.0, PICKUP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_pickup_land)

func _set_pickup_progress(value: float) -> void:
	_pickup_t = value * PICKUP_DURATION

func _update_pickup(k: float) -> void:
	if _pickup_icon == null:
		return
	# 加速曲线：二次缓入；途中抬一道弧线，避免直线平飞。
	var ease_k: float = k * k
	var arc: float = sin(k * PI) * -46.0
	var pos: Vector2 = _pickup_from.lerp(_pickup_to, ease_k) + Vector2(0, arc)
	_pickup_icon.position = pos - Vector2(13, 13)
	var scale: float = 1.0 + 0.35 * sin(k * PI) - 0.20 * k
	_pickup_icon.scale = Vector2(scale, scale)
	# 拖尾：沿途留半透明残影。
	if k > 0.08 and k < 0.92 and int(_pickup_t * 30.0) % 3 == 0:
		_spawn_ghost(pos)

func _spawn_ghost(pos: Vector2) -> void:
	var ghost: ColorRect = ColorRect.new()
	ghost.color = Color(SKIN.GOLD, 0.35)
	ghost.position = pos - Vector2(7, 7)
	ghost.size = Vector2(14, 14)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	_ghosts.append(ghost)
	var tw: Tween = create_tween()
	tw.tween_property(ghost, "color:a", 0.0, 0.28)
	tw.tween_callback(ghost.queue_free)

func _pickup_land() -> void:
	if _pickup_icon != null:
		_pickup_icon.queue_free()
		_pickup_icon = null
	# 落点：手记按钮脉冲一次（约 0.28s，含在 0.55s 总时长内）。
	if _pickup_target != null:
		var pulse: Tween = create_tween()
		pulse.tween_property(_pickup_target, "scale", Vector2(1.26, 1.26), 0.12)
		pulse.tween_property(_pickup_target, "scale", Vector2(1.0, 1.0), 0.16)
	for ghost in _ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	_ghosts.clear()
	var done: Callable = _pickup_done
	_pickup_done = Callable()
	if done.is_valid():
		done.call()

func _clear_pickup() -> void:
	if _pickup_icon != null and is_instance_valid(_pickup_icon):
		_pickup_icon.queue_free()
	_pickup_icon = null
	for ghost in _ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	_ghosts.clear()

# ============================================================ 2. 开门

func play_door_open(on_done: Callable) -> void:
	_door_root = Control.new()
	_door_root.size = Vector2(960, 600)
	_door_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_door_root)

	# 门缝光：门后暖光，随门扇打开溢出。
	var light: ColorRect = ColorRect.new()
	light.name = "DoorLight"
	light.color = Color(1.0, 0.84, 0.50, 0.0)
	light.position = Vector2(300, 0)
	light.size = Vector2(660, 600)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_root.add_child(light)

	# 门扇：左铰链枢轴，向内旋转。
	var leaf: Panel = Panel.new()
	leaf.name = "DoorLeaf"
	leaf.position = Vector2(0, 0)
	leaf.size = Vector2(380, 600)
	leaf.pivot_offset = Vector2(0, 300)
	leaf.add_theme_stylebox_override("panel", SKIN.style(Color("#4a3826"), Color("#2a1f14"), 2, 2))
	_door_root.add_child(leaf)
	for i in 4:
		var plank: ColorRect = ColorRect.new()
		plank.color = Color(1.0, 1.0, 1.0, 0.08)
		plank.position = Vector2(70.0 * float(i), 0)
		plank.size = Vector2(4, 600)
		leaf.add_child(plank)

	# 黑场：开门末尾压黑，后接新场景。
	var black: ColorRect = ColorRect.new()
	black.name = "DoorBlack"
	black.color = Color(0.0, 0.0, 0.0, 0.0)
	black.position = Vector2(0, 0)
	black.size = Vector2(960, 600)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_root.add_child(black)
	_door_black = black

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(leaf, "rotation", -1.55, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "color:a", 0.55, 0.18).set_delay(0.10)
	tw.tween_property(black, "color:a", 1.0, 0.22).set_delay(0.40)
	tw.set_parallel(false)
	tw.tween_callback(_door_finished.bind(on_done))

func _door_finished(on_done: Callable) -> void:
	if on_done.is_valid():
		on_done.call()

# 新场景已经在黑场背后就位：黑场淡出后再拆掉门扇层。
func door_reveal(on_done: Callable) -> void:
	if _door_black == null or not is_instance_valid(_door_black):
		if on_done.is_valid():
			on_done.call()
		return
	var tw: Tween = create_tween()
	tw.tween_property(_door_black, "color:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if _door_root != null and is_instance_valid(_door_root):
			_door_root.queue_free()
		_door_root = null
		_door_black = null
		if on_done.is_valid():
			on_done.call()
	)

# ============================================================ 3. 入梦

func play_dream_in(on_mid: Callable, on_done: Callable) -> void:
	_dream_root = Control.new()
	_dream_root.size = Vector2(960, 600)
	_dream_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dream_root)

	# 灰度层。
	var gray: ColorRect = ColorRect.new()
	gray.name = "DreamGray"
	gray.color = Color(0.18, 0.18, 0.20, 0.0)
	gray.position = Vector2(0, 0)
	gray.size = Vector2(960, 600)
	gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dream_root.add_child(gray)

	# 径向缩放环：从中心向外胀开。
	var ring: Panel = Panel.new()
	ring.name = "DreamRing"
	ring.position = Vector2(480, 300)
	ring.size = Vector2(240, 240)
	ring.pivot_offset = Vector2(120, 120)
	ring.add_theme_stylebox_override("panel", SKIN.style(Color(1, 1, 1, 0.0), Color(SKIN.GOLD, 0.6), 3, 120))
	ring.modulate = Color(1, 1, 1, 0.5)
	_dream_root.add_child(ring)

	# 白噪闪：一批随机小方块 + 一次全白闪光。
	var noise: Control = Control.new()
	noise.name = "DreamNoise"
	_dream_root.add_child(noise)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261126
	for i in 36:
		var chip: ColorRect = ColorRect.new()
		chip.color = Color(1.0, 0.95, 0.82, 0.0)
		chip.position = Vector2(rng.randf_range(0, 920), rng.randf_range(0, 560))
		chip.size = Vector2(rng.randf_range(4, 18), rng.randf_range(4, 18))
		noise.add_child(chip)

	var flash: ColorRect = ColorRect.new()
	flash.name = "DreamFlash"
	flash.color = Color(0.96, 0.90, 0.78, 0.0)
	flash.position = Vector2(0, 0)
	flash.size = Vector2(960, 600)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dream_root.add_child(flash)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(gray, "color:a", 0.55, 0.35)
	tw.tween_property(ring, "scale", Vector2(1.6, 1.6), DREAM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, DREAM_DURATION)
	tw.tween_property(flash, "color:a", 0.72, 0.10).set_delay(0.22)
	tw.tween_property(flash, "color:a", 0.0, 0.20).set_delay(0.34)
	for chip in noise.get_children():
		var chip_rect: ColorRect = chip as ColorRect
		tw.tween_property(chip_rect, "color:a", 0.5, 0.06).set_delay(rng.randf_range(0.18, 0.30))
		tw.tween_property(chip_rect, "color:a", 0.0, 0.16).set_delay(0.34)
	tw.set_parallel(false)
	tw.tween_callback(_dream_mid.bind(on_mid)).set_delay(0.45)
	tw.tween_property(gray, "color:a", 0.12, 0.40)
	tw.tween_callback(_dream_finished.bind(on_done))

func _dream_mid(on_mid: Callable) -> void:
	if on_mid.is_valid():
		on_mid.call()

func _dream_finished(on_done: Callable) -> void:
	if _dream_root != null and is_instance_valid(_dream_root):
		_dream_root.queue_free()
	_dream_root = null
	if on_done.is_valid():
		on_done.call()

# ============================================================ 4. 换地点擦除

func play_location_wipe(on_mid: Callable, on_done: Callable) -> void:
	_wipe_root = Control.new()
	_wipe_root.size = Vector2(960, 600)
	_wipe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wipe_root)

	var cover: ColorRect = ColorRect.new()
	cover.name = "WipeCover"
	cover.color = Color(0.06, 0.07, 0.08, 1.0)
	cover.position = Vector2(0, 0)
	cover.size = Vector2(960, 600)
	cover.modulate = Color(1, 1, 1, 0.0)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe_root.add_child(cover)

	var band: ColorRect = ColorRect.new()
	band.name = "WipeBand"
	band.color = Color(SKIN.GOLD, 0.85)
	band.position = Vector2(-20, 0)
	band.size = Vector2(20, 600)
	band.modulate = Color(1, 1, 1, 0.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe_root.add_child(band)

	var half: float = WIPE_DURATION * 0.5
	var tw: Tween = create_tween()
	# 前半：擦除盖入 + 金边横扫；中段切入新场景；后半：擦除淡出露出新场景。
	tw.set_parallel(true)
	tw.tween_property(cover, "modulate:a", 1.0, half)
	tw.tween_property(band, "modulate:a", 0.9, 0.05)
	tw.tween_property(band, "position:x", 960.0, half).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel(false)
	tw.tween_callback(_wipe_mid.bind(on_mid))
	tw.set_parallel(true)
	tw.tween_property(cover, "modulate:a", 0.0, half)
	tw.tween_property(band, "modulate:a", 0.0, 0.10)
	tw.set_parallel(false)
	tw.tween_callback(_wipe_finished.bind(on_done))

func _wipe_mid(on_mid: Callable) -> void:
	if on_mid.is_valid():
		on_mid.call()

func _wipe_finished(on_done: Callable) -> void:
	if _wipe_root != null and is_instance_valid(_wipe_root):
		_wipe_root.queue_free()
	_wipe_root = null
	if on_done.is_valid():
		on_done.call()
