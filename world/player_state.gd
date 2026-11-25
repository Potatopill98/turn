extends RefCounted

# 探索模式的玩家逻辑（纯数据，不依赖节点，headless 可直接跑测试）。
# 脚底锚点 = pos；碰撞用脚底小矩形，逐轴分离，避免贴墙抖动。
# B4：8 向朝向、步幅 bob、短惯性收尾，供画面层读取 lift / foot_shift / walk_dir。

const TravelerArt = preload("res://traveler_art.gd")

const SPEED: float = 152.0
const FOOT_HALF_W: float = 11.0
const FOOT_H: float = 9.0
const STEP_LENGTH: float = 58.0
const INERTIA_STOP: float = 8.0

var pos: Vector2 = Vector2.ZERO
var dir: int = 1
var walking: bool = false
var step_phase: float = 0.0
var step_meter: float = 0.0
var height: float = 84.0
var walk_dir: Vector2 = Vector2.ZERO
var _glide: Vector2 = Vector2.ZERO

func reset(at: Vector2, facing: int = 1) -> void:
	pos = at
	dir = facing
	walking = false
	step_phase = 0.0
	step_meter = 0.0
	walk_dir = Vector2.ZERO
	_glide = Vector2.ZERO

func foot_rect(at: Vector2) -> Rect2:
	return Rect2(at.x - FOOT_HALF_W, at.y - FOOT_H, FOOT_HALF_W * 2.0, FOOT_H)

static func inside_any(at: Vector2, rects: Array) -> bool:
	for item in rects:
		if item is Rect2 and (item as Rect2).has_point(at):
			return true
	return false

static func hits_block(at: Vector2, blocks: Array) -> bool:
	var foot: Rect2 = Rect2(at.x - FOOT_HALF_W, at.y - FOOT_H, FOOT_HALF_W * 2.0, FOOT_H)
	for item in blocks:
		if item is Rect2 and (item as Rect2).intersects(foot):
			return true
	return false

func can_stand(at: Vector2, data: Dictionary) -> bool:
	var bounds: Rect2 = data.get("bounds", Rect2(0, 0, 960, 600)) as Rect2
	if not bounds.has_point(at):
		return false
	var walk: Array = data.get("walk", []) as Array
	if not walk.is_empty() and not inside_any(at, walk):
		return false
	if hits_block(at, data.get("blocks", []) as Array):
		return false
	return true

func step(delta: float, motion: Vector2, data: Dictionary) -> void:
	var input: Vector2 = motion.limit_length()
	dir = TravelerArt.facing(input, dir)
	if input.length_squared() > 1.0:
		walk_dir = input
		_glide = input * SPEED
		walking = true
		var desired: Vector2 = _glide
		var move_x: float = desired.x * delta
		var move_y: float = desired.y * delta
		if absf(move_x) > 0.0001:
			var next_x: Vector2 = Vector2(pos.x + move_x, pos.y)
			if can_stand(next_x, data):
				pos = next_x
		if absf(move_y) > 0.0001:
			var next_y: Vector2 = Vector2(pos.x, pos.y + move_y)
			if can_stand(next_y, data):
				pos = next_y
		step_meter += desired.length() * delta
		step_phase += desired.length() * delta / STEP_LENGTH
		if step_meter >= STEP_LENGTH:
			step_meter = 0.0
	else:
		# 松手后的短滑步惯性：速度线性衰减到阈值内再切站立。
		_glide = _glide * maxf(0.0, 1.0 - delta * 6.0)
		if _glide.length() > INERTIA_STOP:
			walking = true
			var move_x: float = _glide.x * delta
			var move_y: float = _glide.y * delta
			if absf(move_x) > 0.0001:
				var next_x: Vector2 = Vector2(pos.x + move_x, pos.y)
				if can_stand(next_x, data):
					pos = next_x
			if absf(move_y) > 0.0001:
				var next_y: Vector2 = Vector2(pos.x, pos.y + move_y)
				if can_stand(next_y, data):
					pos = next_y
			step_phase += _glide.length() * delta / STEP_LENGTH
		else:
			walking = false
			step_phase = 0.0
			step_meter = 0.0

func frame() -> int:
	return int(floor(step_phase)) % 4

# 垂直 bob：相位正弦 ±1.5px。
func lift() -> float:
	return sin(step_phase * TAU) * 1.5

# 影子随左右脚相位小幅偏移。
func foot_shift() -> float:
	return sin(step_phase * TAU) * 4.0

# 上身前倾角（弧度）：朝下走略前倾，朝上略后仰。
func lean() -> float:
	if walk_dir.y > 0.35:
		return 0.06
	if walk_dir.y < -0.35:
		return -0.04
	return 0.0

# 走到某一点的直线自动寻路（测试与"自动走位检查"用）：
# 逐轴靠近，卡住就换另一轴，最多 400 步。
func walk_towards(target: Vector2, data: Dictionary, max_steps: int = 400) -> bool:
	var guard: int = 0
	while guard < max_steps:
		guard += 1
		if pos.distance_to(target) < 6.0:
			return true
		var delta: Vector2 = target - pos
		var motion: Vector2 = Vector2(signf(delta.x), signf(delta.y))
		step(1.0 / 60.0, motion, data)
	if pos.distance_to(target) < 8.0:
		return true
	return false
