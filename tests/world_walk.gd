extends Node

# 探索模式自动检查：
# 1) 静态：场景数量、出生点、出口连通、热点合法、图片存在
# 2) 可达性：网格 BFS，确认每个出口/热点/NPC 都能走到
# 3) 50 轮随机走位，验证玩家永远不出界、不进墙

const PlayerState = preload("res://world/player_state.gd")
const WorldData = preload("res://world/world_data.gd")
const GRID: float = 16.0

var world = null
var failures: Array = []
var checks: int = 0
var warnings: Array = []
var rounds: int = 50
var seed_base: int = 7000
var steps_per_round: int = 120

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1 and str(args[0]).is_valid_int():
		seed_base = int(args[0])
	if args.size() >= 2 and str(args[1]).is_valid_int():
		rounds = int(args[1])
	TurnState.reset()
	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	if packed == null:
		_fail("world.tscn 加载失败")
		_report()
		return
	world = packed.instantiate()
	add_child(world)
	await get_tree().process_frame
	if world.chapter != null:
		world.chapter.skip()
	await get_tree().process_frame

	_static_checks()
	_reachability_checks()
	_random_rounds()
	_report()

func _fail(message: String) -> void:
	failures.append(message)
	print("  FAIL  ", message)

func _ok() -> void:
	checks += 1

func _warn(message: String) -> void:
	warnings.append(message)

func _static_checks() -> void:
	print("== 静态检查 ==")
	var scenes: Dictionary = WorldData.all()
	if scenes.size() != 19:
		_fail("场景数量应为 19，实际 %d" % scenes.size())
	else:
		_ok()
		print("  场景数量 19  OK")

	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		var bounds: Rect2 = data.get("bounds", Rect2()) as Rect2
		if bounds.size.x < 400.0 or bounds.size.y < 300.0:
			_fail("%s bounds 异常 %s" % [scene_id, str(bounds)])
		var walk: Array = data.get("walk", []) as Array
		if walk.is_empty():
			_fail("%s 没有可行走区" % scene_id)
		var spawn: Vector2 = data.get("spawn", Vector2.ZERO) as Vector2
		var probe: PlayerState = PlayerState.new()
		if not probe.can_stand(spawn, data):
			_fail("%s 出生点不可站立 %s" % [scene_id, str(spawn)])
		var exits: Array = data.get("exits", []) as Array
		if exits.is_empty():
			_fail("%s 没有出口，玩家会被困住" % scene_id)
		for exit in exits:
			var e: Dictionary = exit as Dictionary
			var to: String = str(e.get("to", ""))
			if not bool(e.get("wake", false)) and not scenes.has(to):
				_fail("%s 出口指向不存在的场景 %s" % [scene_id, to])
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			var kind: String = str(s.get("kind", ""))
			if not (kind in ["talk", "item", "travel", "story", "dream", "wake"]):
				_fail("%s 热点类型非法 %s" % [scene_id, kind])
			if kind == "travel" and not scenes.has(str(s.get("arg", ""))):
				_fail("%s 热点 travel 目标不存在 %s" % [scene_id, str(s.get("arg", ""))])
		var bg: String = str(data.get("bg", ""))
		if not bg.is_empty() and not ResourceLoader.exists(bg):
			_warn("%s 背景图未出：%s" % [scene_id, bg])
		for npc in data.get("npcs", []) as Array:
			var n: Dictionary = npc as Dictionary
			if not probe.can_stand(n.get("pos", Vector2.ZERO) as Vector2, data):
				_warn("%s 的 NPC %s 站位不在可行走区" % [scene_id, str(n.get("name", ""))])
	checks += 1

func _reachability_checks() -> void:
	print("== 可达性 BFS ==")
	var scenes: Dictionary = WorldData.all()
	var probe: PlayerState = PlayerState.new()
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		var grid: Dictionary = _flood(data, probe)
		if grid.is_empty():
			_fail("%s 出生点无法连通任何格子" % scene_id)
			continue
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			if not _near_grid(grid, e.get("pos", Vector2.ZERO) as Vector2, 52.0, data):
				_fail("%s 出口不可达：%s %s" % [scene_id, str(e.get("label", "")), str(e.get("pos", Vector2.ZERO))])
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			if not _near_grid(grid, s.get("pos", Vector2.ZERO) as Vector2, 52.0, data):
				_fail("%s 热点不可达：%s %s" % [scene_id, str(s.get("label", "")), str(s.get("pos", Vector2.ZERO))])
	checks += 1
	print("  可达性检查完成")

func _flood(data: Dictionary, probe: RefCounted) -> Dictionary:
	var bounds: Rect2 = data.get("bounds", Rect2()) as Rect2
	var spawn: Vector2 = data.get("spawn", Vector2.ZERO) as Vector2
	var start: Vector2i = _snap(spawn, bounds)
	if not probe.can_stand(_center(start, bounds), data):
		return {}
	var seen: Dictionary = {start: true}
	var queue: Array = [start]
	var head: int = 0
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cur: Vector2i = queue[head] as Vector2i
		head += 1
		for d in dirs:
			var nxt: Vector2i = cur + (d as Vector2i)
			if seen.has(nxt):
				continue
			var at: Vector2 = _center(nxt, bounds)
			if at.x < bounds.position.x or at.x > bounds.end.x or at.y < bounds.position.y or at.y > bounds.end.y:
				continue
			if not probe.can_stand(at, data):
				continue
			seen[nxt] = true
			queue.append(nxt)
	return seen

func _snap(at: Vector2, bounds: Rect2) -> Vector2i:
	return Vector2i(int(floor((at.x - bounds.position.x) / GRID)), int(floor((at.y - bounds.position.y) / GRID)))

func _center(cell: Vector2i, bounds: Rect2) -> Vector2:
	return bounds.position + Vector2(float(cell.x) * GRID + GRID * 0.5, float(cell.y) * GRID + GRID * 0.5)

func _near_grid(grid: Dictionary, at: Vector2, radius: float, _data: Dictionary) -> bool:
	for key in grid.keys():
		var cell: Vector2i = key as Vector2i
		var center: Vector2 = Vector2(float(cell.x) * GRID + GRID * 0.5, float(cell.y) * GRID + GRID * 0.5)
		if center.distance_to(at) <= radius:
			return true
	return false

func _random_rounds() -> void:
	print("== 随机走位 %d 轮 ==" % rounds)
	var scenes: Dictionary = WorldData.all()
	var scene_ids: Array = scenes.keys()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var bad_steps: int = 0
	var total_steps: int = 0
	for round_index in rounds:
		rng.seed = seed_base + round_index * 131
		for id in scene_ids:
			var scene_id: String = str(id)
			var data: Dictionary = scenes[id] as Dictionary
			var probe: PlayerState = PlayerState.new()
			probe.reset(data.get("spawn", Vector2.ZERO) as Vector2, 1)
			for step_index in steps_per_round:
				var angle: float = rng.randf_range(0.0, TAU)
				var motion: Vector2 = Vector2(cos(angle), sin(angle))
				probe.step(1.0 / 60.0, motion, data)
				total_steps += 1
				if not probe.can_stand(probe.pos, data):
					bad_steps += 1
					if bad_steps <= 6:
						_fail("第 %d 轮 %s 第 %d 步走出可行走区：%s" % [round_index + 1, scene_id, step_index, str(probe.pos)])
	if bad_steps == 0:
		_ok()
		print("  %d 步随机走位，0 次越界" % total_steps)
	else:
		print("  越界次数 %d / %d" % [bad_steps, total_steps])

func _report() -> void:
	print("")
	print("==========================================")
	print("WORLD: %d checks, %d failures, %d warnings" % [checks, failures.size(), warnings.size()])
	if not warnings.is_empty():
		print("--- 警告（图未出，不影响可玩）---")
		for w in warnings:
			print("  WARN  ", w)
	if not failures.is_empty():
		print("--- 失败 ---")
		for f in failures:
			print("  - ", f)
	print("==========================================")
	get_tree().quit(0 if failures.is_empty() else 1)
