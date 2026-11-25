extends RefCounted

# 角色切片绘制：4 方向站立 / 走路，8 向朝向归类到最近的水平切片；
# bob 抬升与上身倾角由场景层（player_state）计算后传入。

const TEXTURES = [
	preload("res://art/02_角色_归乡旅人/站立_朝上.png"),
	preload("res://art/02_角色_归乡旅人/站立_朝下.png"),
	preload("res://art/02_角色_归乡旅人/站立_朝右.png"),
	preload("res://art/02_角色_归乡旅人/站立_朝左.png"),
]
const REGIONS = [
	Rect2(247, 135, 274, 776), Rect2(242, 137, 277, 812),
	Rect2(250, 131, 252, 818), Rect2(277, 172, 213, 710),
]

# 0 上 / 1 下 / 2 右 / 3 左 / 4 右上 / 5 左上 / 6 右下 / 7 左下
static func facing(motion: Vector2, previous: int) -> int:
	if motion.is_zero_approx():
		return previous
	var ax: float = absf(motion.x)
	var ay: float = absf(motion.y)
	if ax < 0.3 and ay < 0.3:
		return previous
	var h: int = -1
	if motion.x > 0.3:
		h = 2
	elif motion.x < -0.3:
		h = 3
	var v: int = -1
	if motion.y < -0.3:
		v = 0
	elif motion.y > 0.3:
		v = 1
	if h == -1:
		return v
	if v == -1:
		return h
	if v == 0:
		return 4 if h == 2 else 5
	if v == 1:
		return 6 if h == 2 else 7
	return previous

static func _cardinal(dir: int) -> int:
	if dir == 4 or dir == 6:
		return 2
	if dir == 5 or dir == 7:
		return 3
	return dir

static func draw(canvas: CanvasItem, foot: Vector2, direction: int, height: float, lift: float = 0.0, lean: float = 0.0) -> void:
	var card: int = _cardinal(direction)
	var region: Rect2 = REGIONS[card]
	var width: float = height * region.size.x / region.size.y
	canvas.draw_set_transform(foot, 0.0, Vector2(1.0, 0.32))
	canvas.draw_circle(Vector2.ZERO, width * 0.65, Color(0.13, 0.13, 0.16, 0.38))
	canvas.draw_set_transform(foot - Vector2(0, lift), lean)
	canvas.draw_texture_rect_region(TEXTURES[card], Rect2(-Vector2(width / 2, height), Vector2(width, height)), region)
	canvas.draw_set_transform(Vector2.ZERO)

const WALK = [
	preload("res://art/02_角色_归乡旅人/步行循环_朝上_游戏切片.png"),
	preload("res://art/02_角色_归乡旅人/步行循环_朝下_四帧.png"),
	preload("res://art/02_角色_归乡旅人/步行循环_朝右_四帧.png"),
	preload("res://art/02_角色_归乡旅人/步行循环_朝左_四帧.png"),
]
const WALK_REGIONS = [
	[Rect2(82,4,99,244),Rect2(332,4,102,249),Rect2(591,4,100,249),Rect2(850,4,96,246)],
	[Rect2(69,2,109,251),Rect2(332,5,98,249),Rect2(591,5,95,249),Rect2(843,5,99,248)],
	[Rect2(5,4,126,247),Rect2(318,4,110,247),Rect2(602,4,126,247),Rect2(896,4,123,248)],
	[Rect2(4,3,159,246),Rect2(302,3,137,250),Rect2(588,3,152,250),Rect2(882,3,138,249)],
]

static func draw_walk(canvas: CanvasItem, foot: Vector2, direction: int, height: float, frame: int, lift: float = 0.0, lean: float = 0.0) -> void:
	var card: int = _cardinal(direction)
	canvas.draw_set_transform(foot, 0.0, Vector2(1, 0.32))
	canvas.draw_circle(Vector2.ZERO, height * 0.21, Color(0.13, 0.13, 0.16, 0.32))
	var region: Rect2 = WALK_REGIONS[card][frame]
	var width: float = height * region.size.x / region.size.y
	canvas.draw_set_transform(foot - Vector2(0, lift), lean)
	canvas.draw_texture_rect_region(WALK[card], Rect2(-width / 2, -height, width, height), region)
	canvas.draw_set_transform(Vector2.ZERO)
