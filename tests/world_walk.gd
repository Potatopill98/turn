extends Node

# 探索模式自动检查：
# 1) 静态：场景数量、出生点、出口连通、热点合法、图片存在
# 2) 可达性：网格 BFS，确认每个出口/热点/NPC 都能走到
# 3) 50 轮随机走位，验证玩家永远不出界、不进墙

const PlayerState = preload("res://world/player_state.gd")
const WorldData = preload("res://world/world_data.gd")
const PuzzleState = preload("res://world/puzzle_state.gd")
const Data = preload("res://scripts/turn_data.gd")
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
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
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
	_cross_scene_reachability()
	_lock_coverage_checks()
	_puzzle_checks()
	_wiring_checks()
	_puzzle_coverage_checks()
	_soft_lock_checks()
	_persistence_checks()
	await _lock_world_checks()
	await _cross_scene_chain()
	await _new_puzzle_chains()
	_combo_bench_checks()
	await _present_flow_checks()
	_ending_tier_checks()
	await _title_checks()
	_b6_delivery_checks()
	_b7_delivery_checks()
	await _b8_delivery_checks()
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
			if not (kind in ["talk", "item", "travel", "story", "dream", "wake", "combo", "examine", "ending_review"]):
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

func _cross_scene_reachability() -> void:
	print("== 跨场景连通 BFS（带锁分级）==")
	var scenes: Dictionary = WorldData.all()
	var adjacency: Dictionary = {}
	var open_adjacency: Dictionary = {}
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		var edges: Array[String] = []
		var open_edges: Array[String] = []
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			if bool(e.get("wake", false)):
				continue
			var to: String = str(e.get("to", ""))
			if not to.is_empty() and scenes.has(to):
				edges.append(to)
				var lock: Dictionary = e.get("lock", {}) as Dictionary
				if lock.is_empty() or bool(e.get("open_edge", false)):
					open_edges.append(to)
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			var kind: String = str(s.get("kind", ""))
			if kind == "travel" or kind == "dream":
				var target: String = str(s.get("arg", ""))
				if scenes.has(target):
					edges.append(target)
					var lock: Dictionary = s.get("lock", {}) as Dictionary
					if lock.is_empty() or bool(s.get("open_edge", false)):
						open_edges.append(target)
		adjacency[scene_id] = edges
		open_adjacency[scene_id] = open_edges
	var visited: Dictionary = {"langcheng_room": true}
	var queue: Array[String] = ["langcheng_room"]
	var head: int = 0
	while head < queue.size():
		var cur: String = queue[head]
		head += 1
		for nxt in adjacency.get(cur, []) as Array:
			var n: String = str(nxt)
			if not visited.has(n):
				visited[n] = true
				queue.append(n)
	var orphans: Array[String] = []
	for id in scenes.keys():
		if not visited.has(str(id)):
			orphans.append(str(id))
	if orphans.is_empty():
		_ok()
		print("  19 场景全部可达（跨场景 BFS）  OK")
	else:
		_fail("孤儿场景无入边：" + ", ".join(orphans))
	# 自由 BFS：锁边不算通走，只统计被条件门控的场景，不白嫖锁边。
	var open_visited: Dictionary = {"langcheng_room": true}
	var open_queue: Array[String] = ["langcheng_room"]
	var open_head: int = 0
	while open_head < open_queue.size():
		var cur_open: String = open_queue[open_head]
		open_head += 1
		for nxt in open_adjacency.get(cur_open, []) as Array:
			var n_open: String = str(nxt)
			if not open_visited.has(n_open):
				open_visited[n_open] = true
				open_queue.append(n_open)
	var gated: Array[String] = []
	for id in visited.keys():
		if not open_visited.has(str(id)):
			gated.append(str(id))
	print("  条件门控场景（仅锁边可达）：" + ", ".join(gated))

func _lock_coverage_checks() -> void:
	print("== 锁目标入边覆盖断言 ==")
	var scenes: Dictionary = WorldData.all()
	var inbound: Dictionary = {}
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			if bool(e.get("wake", false)):
				continue
			var to: String = str(e.get("to", ""))
			if not to.is_empty() and scenes.has(to):
				var entry: Dictionary = {
					"source": scene_id,
					"kind": "exit",
					"lock": e.get("lock", {}) as Dictionary,
					"open_edge": bool(e.get("open_edge", false)),
					"reason": str(e.get("open_reason", "")),
				}
				_inbound_add(inbound, to, entry)
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			var kind: String = str(s.get("kind", ""))
			if kind == "travel" or kind == "dream":
				var target: String = str(s.get("arg", ""))
				if scenes.has(target):
					var entry: Dictionary = {
						"source": scene_id,
						"kind": "spot:" + kind,
						"lock": s.get("lock", {}) as Dictionary,
						"open_edge": bool(s.get("open_edge", false)),
						"reason": str(s.get("open_reason", "")),
					}
					_inbound_add(inbound, target, entry)
	var locked_targets: Dictionary = {}
	for target in inbound.keys():
		for edge in inbound[target] as Array:
			var lock: Dictionary = edge.get("lock", {}) as Dictionary
			if not lock.is_empty():
				locked_targets[str(target)] = lock
	for target in locked_targets.keys():
		var canon: Dictionary = locked_targets[target] as Dictionary
		for edge in inbound[target] as Array:
			if bool(edge.get("open_edge", false)):
				if str(edge.get("reason", "")).is_empty():
					_fail("%s 的开放入边 %s(%s) 缺 open_reason 剧情理由" % [str(target), str(edge.get("source", "")), str(edge.get("kind", ""))])
				continue
			if not _lock_equivalent(edge.get("lock", {}) as Dictionary, canon):
				_fail("锁定目标 %s 的入边 %s(%s) 未挂同等条件锁" % [str(target), str(edge.get("source", "")), str(edge.get("kind", ""))])
	_ok()
	print("  每个锁定目标的全部入边均挂同等条件或显式开放  OK")

func _inbound_add(inbound: Dictionary, target: String, entry: Dictionary) -> void:
	if not inbound.has(target):
		inbound[target] = []
	(inbound[target] as Array).append(entry)

func _lock_equivalent(a: Dictionary, b: Dictionary) -> bool:
	var a_ev: Array[String] = _sorted_ids(a.get("evidence", []) as Array)
	var b_ev: Array[String] = _sorted_ids(b.get("evidence", []) as Array)
	var a_cl: Array[String] = _sorted_ids(a.get("clues", []) as Array)
	var b_cl: Array[String] = _sorted_ids(b.get("clues", []) as Array)
	return a_ev == b_ev and a_cl == b_cl

func _sorted_ids(raw: Array) -> Array[String]:
	var out: Array[String] = []
	for value in raw:
		out.append(str(value))
	out.sort()
	return out

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

func _puzzle_checks() -> void:
	print("== 物证 / 推论 / 条件锁 ==")
	var puzzle: RefCounted = PuzzleState.new()

	# 拾取成功 / 重复拾取返回 false
	if puzzle.add_evidence("ev_note"):
		_ok()
		print("  物证拾取成功  OK")
	else:
		_fail("add_evidence 首次应返回 true")
	if not puzzle.add_evidence("ev_note") and puzzle.has_evidence("ev_note"):
		_ok()
		print("  重复拾取返回 false  OK")
	else:
		_fail("重复拾取应返回 false 且 has_evidence 为 true")

	# 缺一件时组合失败
	if puzzle.try_combine("ev_note", "ev_photo") == "":
		_ok()
		print("  缺物证组合失败  OK")
	else:
		_fail("缺物证时 try_combine 应返回空串")

	puzzle.add_evidence("ev_photo")
	var clue: String = puzzle.try_combine("ev_note", "ev_photo")
	if clue == "cl_score" and puzzle.has_clue("cl_score"):
		_ok()
		print("  组合成功得到推论 ", clue, "  OK")
	else:
		_fail("组合 ev_note+ev_photo 应得到 cl_score，实际：" + clue)
	if puzzle.try_combine("ev_note", "ev_photo") == "":
		_ok()
		print("  重复组合返回空串  OK")
	else:
		_fail("推论已合成后再次组合应返回空串")
	if puzzle.try_combine("ev_screw", "ev_tape") == "":
		_ok()
		print("  无关组合失败  OK")
	else:
		_fail("无关两件物证不应合成推论")

	# 锁：满足 / 不满足
	var open_lock: Dictionary = puzzle.lock_state({"evidence": ["ev_note"], "clues": [], "hint": "已满足"})
	if bool(open_lock.get("ok", false)):
		_ok()
		print("  锁条件满足放行  OK")
	else:
		_fail("条件满足时 lock_state 应 ok=true")
	var closed_lock: Dictionary = puzzle.lock_state({"evidence": ["ev_screw"], "clues": ["cl_lamp"], "hint": "先找螺丝"})
	var missing: Array = closed_lock.get("missing", []) as Array
	if not bool(closed_lock.get("ok", true)) and missing.has("ev_screw") and missing.has("cl_lamp") and not str(closed_lock.get("hint", "")).is_empty():
		_ok()
		print("  锁拒绝且给出缺口与提示  OK")
	else:
		_fail("锁拒绝时应列出缺失 id 且 hint 非空：" + str(closed_lock))

	# 数据完整性：≥5 个条件锁；锁字段合法；组合配方合法
	var scenes: Dictionary = WorldData.all()
	var locked_count: int = 0
	var evidence_reg: Dictionary = PuzzleState.EVIDENCE_NAMES
	var clue_reg: Dictionary = PuzzleState.CLUE_NAMES
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			var lock: Dictionary = e.get("lock", {}) as Dictionary
			if lock.is_empty():
				continue
			locked_count += 1
			if str(lock.get("hint", "")).is_empty():
				_fail("%s 锁出口缺 hint：%s" % [scene_id, str(e.get("label", ""))])
			for eid in lock.get("evidence", []) as Array:
				if not evidence_reg.has(str(eid)):
					_fail("%s 锁引用未知物证 %s" % [scene_id, str(eid)])
			for cid in lock.get("clues", []) as Array:
				if not clue_reg.has(str(cid)):
					_fail("%s 锁引用未知推论 %s" % [scene_id, str(cid)])
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			if str(s.get("kind", "")) == "combo":
				var combo: Dictionary = s.get("combo", {}) as Dictionary
				var a: String = str(combo.get("a", ""))
				var b: String = str(combo.get("b", ""))
				var c: String = str(combo.get("clue", ""))
				if not evidence_reg.has(a) or not evidence_reg.has(b):
					_fail("%s 组合热点引用未知物证 %s/%s" % [scene_id, a, b])
				if not clue_reg.has(c):
					_fail("%s 组合热点引用未知推论 %s" % [scene_id, c])
				var pair: String = a + "|" + b if a <= b else b + "|" + a
				if str(PuzzleState.COMBOS.get(pair, "")) != c:
					_fail("%s 组合配方不匹配 COMBOS：%s" % [scene_id, pair])
			var ev: String = str(s.get("gives_evidence", ""))
			if not ev.is_empty() and not evidence_reg.has(ev):
				_fail("%s 热点 gives_evidence 未知：%s" % [scene_id, ev])
	if locked_count >= 5:
		_ok()
		print("  条件锁出口 %d 个（≥5）  OK" % locked_count)
	else:
		_fail("条件锁出口应 ≥5，实际 %d" % locked_count)
	checks += 1

func _wiring_checks() -> void:
	print("== NPC 分支与物证出口 ==")
	var scenes: Dictionary = WorldData.all()
	var evidence_reg: Dictionary = PuzzleState.EVIDENCE_NAMES
	var branch_npc: int = 0
	var present_npc: int = 0
	var outlet: Dictionary = {}
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		for npc in data.get("npcs", []) as Array:
			var n: Dictionary = npc as Dictionary
			var need: String = str(n.get("needs_evidence", ""))
			if not need.is_empty():
				branch_npc += 1
				if not evidence_reg.has(need):
					_fail("%s NPC %s 引用未知物证 %s" % [scene_id, str(n.get("name", "")), need])
				if str(n.get("lines_with_evidence", "")).is_empty() or str(n.get("lines_without", "")).is_empty():
					_fail("%s NPC %s 缺持有/未持有分支台词" % [scene_id, str(n.get("name", ""))])
			var present: Dictionary = n.get("present", {}) as Dictionary
			if not present.is_empty():
				present_npc += 1
				var pe: String = str(present.get("evidence", ""))
				if not evidence_reg.has(pe):
					_fail("%s NPC %s 出示未知物证 %s" % [scene_id, str(n.get("name", "")), pe])
				if str(present.get("reply", "")).is_empty():
					_fail("%s NPC %s 出示后缺回复台词" % [scene_id, str(n.get("name", ""))])
				var wrong_lines: Array = present.get("wrong_lines", []) as Array
				if wrong_lines.size() < 2:
					_fail("%s NPC %s 错配拒绝台词应 ≥2 条，实际 %d" % [scene_id, str(n.get("name", "")), wrong_lines.size()])
				var empty_line: String = str(n.get("lines_without", ""))
				for wl in wrong_lines:
					if str(wl) == empty_line:
						_fail("%s NPC %s 错配台词与空手台词逐字相同" % [scene_id, str(n.get("name", ""))])
				var grant: String = str(present.get("grants_evidence", ""))
				if not grant.is_empty() and not evidence_reg.has(grant):
					_fail("%s NPC %s 出示奖励未知物证 %s" % [scene_id, str(n.get("name", "")), grant])
				outlet[pe] = true
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			var lock: Dictionary = e.get("lock", {}) as Dictionary
			for eid in lock.get("evidence", []) as Array:
				outlet[str(eid)] = true
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			if str(s.get("kind", "")) == "combo":
				var combo: Dictionary = s.get("combo", {}) as Dictionary
				outlet[str(combo.get("a", ""))] = true
				outlet[str(combo.get("b", ""))] = true
	if branch_npc >= 3:
		_ok()
		print("  物证感知 NPC %d 个（≥3）  OK" % branch_npc)
	else:
		_fail("物证感知 NPC 应 ≥3，实际 %d" % branch_npc)
	if present_npc >= 1:
		_ok()
		print("  可出示物证的 NPC %d 个（≥1）  OK" % present_npc)
	else:
		_fail("至少 1 个 NPC 可出示物证推进谜题")
	if outlet.size() >= 5:
		_ok()
		print("  有出口的物证 %d 件（≥5）  OK" % outlet.size())
	else:
		_fail("有出口的物证应 ≥5，实际 %d" % outlet.size())
	var missing_outlet: Array[String] = []
	for eid in evidence_reg.keys():
		if not outlet.has(str(eid)):
			missing_outlet.append(str(eid))
	if missing_outlet.is_empty():
		_ok()
		print("  登记物证全部有下游出口（无死胡同）  OK")
	else:
		_fail("死胡同物证无出口：" + ", ".join(missing_outlet))

func _puzzle_coverage_checks() -> void:
	print("== 逐幕谜题覆盖（R051）==")
	var scenes: Dictionary = WorldData.all()
	var puzzle_scenes: Array[String] = []
	var reason_scenes: Array[String] = []
	var dream_puzzle: int = 0
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		var has_load: bool = false
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			if not str(s.get("gives_evidence", "")).is_empty():
				has_load = true
			if str(s.get("kind", "")) == "combo":
				has_load = true
			if str(s.get("kind", "")) == "examine" and not (s.get("lock", {}) as Dictionary).is_empty():
				has_load = true
		for npc in data.get("npcs", []) as Array:
			var npc_d: Dictionary = npc as Dictionary
			var present: Dictionary = npc_d.get("present", {}) as Dictionary
			if not present.is_empty():
				has_load = true
			if not str(npc_d.get("needs_evidence", "")).is_empty():
				has_load = true
		var reason: String = str(data.get("no_puzzle_reason", ""))
		if has_load:
			puzzle_scenes.append(scene_id)
			if bool(data.get("dream", false)):
				dream_puzzle += 1
		else:
			reason_scenes.append(scene_id)
			if reason.is_empty():
				_fail("%s 零谜题场景未标 no_puzzle_reason" % scene_id)
	if puzzle_scenes.size() >= 8:
		_ok()
		print("  有谜题负载场景 %d 个（≥8）  OK" % puzzle_scenes.size())
	else:
		_fail("有谜题负载场景应 ≥8，实际 %d" % puzzle_scenes.size())
	if reason_scenes.size() <= 4:
		_ok()
		print("  纯叙事转场场景 %d 个（≤4）：%s  OK" % [reason_scenes.size(), ", ".join(reason_scenes)])
	else:
		_fail("纯叙事场景应 ≤4，实际 %d：%s" % [reason_scenes.size(), ", ".join(reason_scenes)])
	if dream_puzzle >= 3:
		_ok()
		print("  有物证 / 组合的梦境 %d 个（≥3）  OK" % dream_puzzle)
	else:
		_fail("梦境有负载应 ≥3，实际 %d" % dream_puzzle)

func _soft_lock_checks() -> void:
	print("== 软锁断言：免条件出边可达性（R061）==")
	var scenes: Dictionary = WorldData.all()
	var free_adjacency: Dictionary = {}
	var has_wake: Dictionary = {}
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		var free_edges: Array[String] = []
		var wake: bool = false
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			if bool(e.get("wake", false)):
				wake = true
				continue
			var to: String = str(e.get("to", ""))
			if to.is_empty() or not scenes.has(to):
				continue
			var lock: Dictionary = e.get("lock", {}) as Dictionary
			if lock.is_empty() or bool(e.get("open_edge", false)):
				free_edges.append(to)
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			var kind: String = str(s.get("kind", ""))
			if kind == "travel" or kind == "dream":
				var target: String = str(s.get("arg", ""))
				if scenes.has(target):
					var lock: Dictionary = s.get("lock", {}) as Dictionary
					if lock.is_empty() or bool(s.get("open_edge", false)):
						free_edges.append(target)
		free_adjacency[scene_id] = free_edges
		has_wake[scene_id] = wake
	var stuck: Array[String] = []
	for id in scenes.keys():
		var start: String = str(id)
		var reached: Dictionary = {start: true}
		var queue: Array[String] = [start]
		var head: int = 0
		while head < queue.size():
			var cur: String = queue[head]
			head += 1
			for nxt in free_adjacency.get(cur, []) as Array:
				var n: String = str(nxt)
				if not reached.has(n):
					reached[n] = true
					queue.append(n)
		var escape: bool = bool(has_wake.get(start, false))
		for r in reached.keys():
			if (free_adjacency.get(str(r), []) as Array).size() > 0:
				escape = true
		if not escape:
			stuck.append(start)
	if stuck.is_empty():
		_ok()
		print("  全部场景存在免条件出边或可醒回现实，无软锁  OK")
	else:
		_fail("软锁场景：%s（无免条件出边且邻居也不通）" % ", ".join(stuck))

func _find_evidence_spot(ev: String) -> Dictionary:
	for spot in world.current_scene_data().get("spots", []) as Array:
		var s: Dictionary = spot as Dictionary
		if str(s.get("gives_evidence", "")) == ev:
			return s
	return {}

func _find_combo_spot(clue: String) -> Dictionary:
	for spot in world.current_scene_data().get("spots", []) as Array:
		var s: Dictionary = spot as Dictionary
		var combo: Dictionary = s.get("combo", {}) as Dictionary
		if str(combo.get("clue", "")) == clue:
			return s
	return {}

func _find_exit_to(target: String) -> Dictionary:
	for exit in world.current_scene_data().get("exits", []) as Array:
		var e: Dictionary = exit as Dictionary
		if str(e.get("to", "")) == target:
			return e
	return {}

func _cross_scene_chain() -> void:
	print("== 跨场景推进链 ==")
	# A=old_house_yard 取 ev_photo → B=house_hall 取 ev_note → 合成 cl_score → 回 C=house_hall 开锁 → D=basement
	TurnState.reset()
	world.puzzle.reload()
	world.force_scene("old_house_yard")
	await get_tree().process_frame
	var photo_spot: Dictionary = _find_evidence_spot("ev_photo")
	if photo_spot.is_empty():
		_fail("链上找不到 ev_photo 热点")
		return
	world._use_spot(photo_spot)
	await get_tree().process_frame
	if world.puzzle.has_evidence("ev_photo"):
		_ok()
		print("  A 场景 old_house_yard 取得 ev_photo  OK")
	else:
		_fail("第一步：old_house_yard 应取得 ev_photo")

	world.force_scene("house_hall")
	await get_tree().process_frame
	var note_spot: Dictionary = _find_evidence_spot("ev_note")
	if note_spot.is_empty():
		_fail("链上找不到 ev_note 热点")
		return
	world._use_spot(note_spot)
	await get_tree().process_frame
	if world.puzzle.has_evidence("ev_note"):
		_ok()
		print("  B 场景 house_hall 取得 ev_note  OK")
	else:
		_fail("第二步：house_hall 应取得 ev_note")

	var combo_spot: Dictionary = _find_combo_spot("cl_score")
	if combo_spot.is_empty():
		_fail("链上找不到 cl_score 组合热点")
		return
	world.puzzle.try_combine("ev_note", "ev_photo")
	await get_tree().process_frame
	if world.puzzle.has_clue("cl_score"):
		_ok()
		print("  两件物证合成推论 cl_score  OK")
	else:
		_fail("第三步：ev_note+ev_photo 应合成 cl_score")

	var basement_exit: Dictionary = _find_exit_to("basement")
	if basement_exit.is_empty():
		_fail("链上找不到去 basement 的出口")
		return
	world._use_exit(basement_exit)
	await get_tree().create_timer(0.90).timeout
	if world.scene_id == "basement":
		_ok()
		print("  回 C 场景开锁进入 D=basement  OK")
	else:
		_fail("合成 cl_score 后应能进入 basement，实际：" + world.scene_id)

func _new_puzzle_chains() -> void:
	print("== B4 新谜题链路（各 3 步断言）==")
	# 链 A：room 取 ev_letter → office 取 ev_draft → 并排合成 cl_leave。
	TurnState.reset()
	world.puzzle.reload()
	world.force_scene("langcheng_room")
	await get_tree().process_frame
	var letter_spot: Dictionary = _find_evidence_spot("ev_letter")
	if letter_spot.is_empty():
		_fail("链 A 找不到 ev_letter 热点")
	else:
		world._use_spot(letter_spot)
		await get_tree().process_frame
		if world.puzzle.has_evidence("ev_letter"):
			_ok()
			print("  A1 room 取得 ev_letter  OK")
		else:
			_fail("链 A 第一步：应取得 ev_letter")
	world.force_scene("langcheng_office")
	await get_tree().process_frame
	var draft_spot: Dictionary = _find_evidence_spot("ev_draft")
	if draft_spot.is_empty():
		_fail("链 A 找不到 ev_draft 热点")
	else:
		world._use_spot(draft_spot)
		await get_tree().process_frame
		if world.puzzle.has_evidence("ev_draft"):
			_ok()
			print("  A2 office 取得 ev_draft  OK")
		else:
			_fail("链 A 第二步：应取得 ev_draft")
	var leave_spot: Dictionary = _find_combo_spot("cl_leave")
	if leave_spot.is_empty():
		_fail("链 A 找不到 cl_leave 组合热点")
	else:
		world.puzzle.try_combine("ev_letter", "ev_draft")
		await get_tree().process_frame
		if world.puzzle.has_clue("cl_leave"):
			_ok()
			print("  A3 ev_letter+ev_draft 合成 cl_leave  OK")
		else:
			_fail("链 A 第三步：应合成 cl_leave")

	# 链 B：postbox 取 ev_ticket → 携 ev_shoes → 土路并排合成 cl_return。
	TurnState.reset()
	world.puzzle.reload()
	world.puzzle.add_evidence("ev_shoes")
	world.force_scene("dream_postbox")
	await get_tree().process_frame
	var ticket_spot: Dictionary = _find_evidence_spot("ev_ticket")
	if ticket_spot.is_empty():
		_fail("链 B 找不到 ev_ticket 热点")
	else:
		world._use_spot(ticket_spot)
		await get_tree().process_frame
		if world.puzzle.has_evidence("ev_ticket"):
			_ok()
			print("  B1 postbox 取得 ev_ticket  OK")
		else:
			_fail("链 B 第一步：应取得 ev_ticket")
	world.force_scene("dream_dirt_road")
	await get_tree().process_frame
	var return_spot: Dictionary = _find_combo_spot("cl_return")
	if return_spot.is_empty():
		_fail("链 B 找不到 cl_return 组合热点")
	else:
		world.puzzle.try_combine("ev_ticket", "ev_shoes")
		await get_tree().process_frame
		if world.puzzle.has_clue("cl_return"):
			_ok()
			print("  B2 ev_ticket+ev_shoes 合成 cl_return  OK")
		else:
			_fail("链 B 第二步：应合成 cl_return")
		if world.puzzle.has_evidence("ev_shoes"):
			_ok()
			print("  B3 携 ev_shoes 完成土路对照  OK")
		else:
			_fail("链 B 第三步：ev_shoes 应仍在手中")

func _lock_world_checks() -> void:
	print("== 锁出口世界级检查（拒绝 / 放行 / 状态与 fx 校验）==")
	var scenes: Dictionary = WorldData.all()
	var locked_exits: Array = []
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			var lock: Dictionary = e.get("lock", {}) as Dictionary
			if not lock.is_empty():
				locked_exits.append({"source": scene_id, "exit": e})
	if locked_exits.is_empty():
		_fail("没有可测的条件锁出口")
		return
	var refusal_ok: int = 0
	var pass_ok: int = 0
	for entry in locked_exits:
		var source: String = str(entry.get("source", ""))
		var exit: Dictionary = entry.get("exit", {}) as Dictionary
		var target: String = str(exit.get("to", ""))
		var lock: Dictionary = exit.get("lock", {}) as Dictionary
		# 拒绝：清空状态后触发，应留在原场景并弹出缺口提示。
		TurnState.reset()
		world.puzzle.reload()
		world.force_scene(source)
		await get_tree().process_frame
		world._use_exit(exit)
		await get_tree().process_frame
		if world.scene_id == source and world._dialog_open:
			refusal_ok += 1
			print("  锁拒绝 %s→%s：未进入且弹出缺口提示  OK" % [source, target])
		else:
			_fail("锁 %s→%s 应拒绝进入并弹出缺口提示" % [source, target])
		# 放行：补齐物证 / 推论，按真实动画时长 + 余量等待。
		world._dialog_open = false
		for eid in lock.get("evidence", []) as Array:
			world.puzzle.add_evidence(str(eid))
		for cid in lock.get("clues", []) as Array:
			world.puzzle.add_clue(str(cid))
		var anim: String = "door" if str(exit.get("spawn", "")) == "door" else "wipe"
		var wait_sec: float = 1.05 if anim == "door" else 0.85
		world._use_exit(exit)
		await get_tree().create_timer(wait_sec).timeout
		if world.scene_id != target:
			_fail("满足条件后应进入 %s，实际 %s" % [target, world.scene_id])
			continue
		if world._locked:
			_fail("进入 %s 后锁状态 _locked 未释放" % target)
		if world.fx != null and world.fx.get_child_count() != 0:
			_fail("进入 %s 后 fx 层未拆除，残留 %d 个子节点" % [target, world.fx.get_child_count()])
		pass_ok += 1
		print("  锁通过 %s→%s：进入目标、锁释放、fx 已拆除  OK" % [source, target])
	if refusal_ok == locked_exits.size():
		_ok()
	else:
		_fail("锁拒绝断言通过 %d / %d" % [refusal_ok, locked_exits.size()])
	if pass_ok == locked_exits.size():
		_ok()
	else:
		_fail("锁放行断言通过 %d / %d" % [pass_ok, locked_exits.size()])
	checks += 1

func _persistence_checks() -> void:
	print("== 解谜状态持久化 ==")
	TurnState.reset()
	var probe: RefCounted = PuzzleState.new()
	probe.add_evidence("ev_photo")
	probe.add_evidence("ev_note")
	probe.try_combine("ev_note", "ev_photo")
	var raw: String = TurnState.snapshot()
	# 模拟重启：清空单例状态后按快照读回。
	TurnState.reset()
	var after_reset: RefCounted = PuzzleState.new()
	if after_reset.has_evidence("ev_photo"):
		_fail("重置后不应残留物证")
	TurnState.restore_snapshot(raw)
	var restored: RefCounted = PuzzleState.new()
	if restored.has_evidence("ev_photo") and restored.has_evidence("ev_note") and restored.has_clue("cl_score"):
		_ok()
		print("  写入 → 模拟重启 → 读回，物证与推论仍在  OK")
	else:
		_fail("重启读回后物证 / 推论丢失")
	# 旧档兼容：空串与缺 flags 键的字典不应报错。
	TurnState.reset()
	TurnState.restore_snapshot("")
	var legacy: RefCounted = PuzzleState.new()
	if legacy.all_evidence().is_empty() and legacy.all_clues().is_empty():
		_ok()
		print("  旧档（无 pz_* 键）兼容读回，物证为空数组  OK")
	else:
		_fail("旧档缺键时应读为空状态，不报错")

func _combo_bench_checks() -> void:
	print("== 推理台正解 / 错解断言（R076/R077）==")
	TurnState.reset()
	world.puzzle.reload()
	var p: RefCounted = world.puzzle
	var recipes: Array = [
		["ev_note", "ev_photo", "cl_score"],
		["ev_screw", "ev_shoes", "cl_lamp"],
		["ev_list", "ev_tape", "cl_tape"],
		["ev_draft", "ev_letter", "cl_leave"],
		["ev_shoes", "ev_ticket", "cl_return"],
	]
	var recipe_ok: int = 0
	for r in recipes:
		p.add_evidence(str(r[0]))
		p.add_evidence(str(r[1]))
		var result: Dictionary = p.combine_attempt(str(r[0]), str(r[1]))
		if bool(result.get("ok", false)) and p.has_clue(str(r[2])):
			recipe_ok += 1
		else:
			_fail("正解 %s+%s 应推出 %s，实际：%s" % [str(r[0]), str(r[1]), str(r[2]), str(result)])
	if recipe_ok == recipes.size():
		_ok()
		print("  5 条配方全部正解出推论  OK")
	else:
		_fail("正解断言通过 %d / %d" % [recipe_ok, recipes.size()])

	TurnState.reset()
	p.reload()
	for eid in PuzzleState.EVIDENCE_NAMES.keys():
		p.add_evidence(str(eid))
	var ids: Array[String] = p.all_evidence()
	var wrong: Array = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var pair: String = ids[i] + "|" + ids[j] if ids[i] <= ids[j] else ids[j] + "|" + ids[i]
			if not PuzzleState.COMBOS.has(pair):
				wrong.append([ids[i], ids[j]])
	var sample: Array = wrong.slice(0, maxi(10, wrong.size()))
	var wrong_ok: int = 0
	for pair in sample:
		var a: String = str(pair[0])
		var b: String = str(pair[1])
		var result: Dictionary = p.combine_attempt(a, b)
		if not bool(result.get("ok", false)) and not str(result.get("reason", "")).is_empty() and p.has_evidence(a) and p.has_evidence(b):
			wrong_ok += 1
		else:
			_fail("错解 %s+%s 应失败、给理由且保留物证：%s" % [a, b, str(result)])
	var same: Dictionary = p.combine_attempt("ev_note", "ev_note")
	if not bool(same.get("ok", false)) and not str(same.get("reason", "")).is_empty():
		wrong_ok += 1
	else:
		_fail("同一件选两次应失败并给理由")
	if wrong_ok == sample.size() + 1:
		_ok()
		print("  错解抽样 %d 对 + 同件自比 1 对：全部失败、有反馈、物证仍在  OK" % sample.size())
	else:
		_fail("错解断言通过 %d / %d" % [wrong_ok, sample.size() + 1])

func _present_flow_checks() -> void:
	print("== 出示选择层路径（R077/R088）==")
	TurnState.reset()
	world.puzzle.reload()
	world.force_scene("playground_night")
	await get_tree().process_frame
	var npc: Dictionary = {}
	for candidate in world.current_scene_data().get("npcs", []) as Array:
		var c: Dictionary = candidate as Dictionary
		if str(c.get("id", "")) == "p_zhou":
			npc = c
	if npc.is_empty():
		_fail("夜场找不到 p_zhou")
		return
	world._say_npc(npc)
	if world._present_layer_open():
		_fail("空手时不应打开出示选择层")
	else:
		_ok()
		print("  空手走交谈台词，不开选择层  OK")
	world._advance_dialog()

	world.puzzle.add_evidence("ev_letter")
	world._say_npc(npc)
	if not world._present_layer_open():
		_fail("持有物证时应打开出示选择层")
	else:
		_ok()
		print("  持有物证打开选择层  OK")
	world._present_pick("ev_letter")
	if world.puzzle.has_evidence("ev_letter") and not world.puzzle.has_evidence("ev_mirror") and world._dialog_open:
		_ok()
		print("  错配拒绝：物证仍在、不出镜子、给台词  OK")
	else:
		_fail("错配后物证被消耗或误发奖励")
	world._advance_dialog()

	world.puzzle.add_evidence("ev_shoes")
	world._say_npc(npc)
	world._present_pick("ev_shoes")
	if world.puzzle.has_evidence("ev_mirror") and TurnState.has_flag("presented_p_zhou"):
		_ok()
		print("  正解出示：得到 ev_mirror 并登记已出示  OK")
	else:
		_fail("正解出示应得到 ev_mirror")

func _ending_tier_checks() -> void:
	print("== 终章收集度三档（R081）==")
	TurnState.reset()
	world.puzzle.reload()
	var soft: String = TurnState.settle_collection_tier(0, 0)
	if soft == "soft":
		_ok()
		print("  0 物证 0 推论 → soft 档  OK")
	else:
		_fail("低收集度应判 soft，实际 " + soft)
	TurnState.reset()
	var half: String = TurnState.settle_collection_tier(5, 1)
	if half == "half":
		_ok()
		print("  中收集度 → half 档  OK")
	else:
		_fail("中收集度应判 half，实际 " + half)
	TurnState.reset()
	var clear: String = TurnState.settle_collection_tier(10, 5)
	if clear == "clear":
		_ok()
		print("  全收集 → clear 档  OK")
	else:
		_fail("全收集应判 clear，实际 " + clear)
	var titles: Dictionary = {}
	for t in ["clear", "half", "soft"]:
		var ending: Dictionary = Data.ending(t)
		if str(ending.get("body", "")).is_empty():
			_fail("终章档位 " + t + " 缺 body 文案")
		titles[t] = str(ending.get("title", ""))
	if titles["clear"] != titles["half"] and titles["half"] != titles["soft"]:
		_ok()
		print("  三档标题与正文互不相同  OK")
	else:
		_fail("三档收束文本没有区分度")

func _title_checks() -> void:
	print("== 标题界面（R082）==")
	var packed: PackedScene = load("res://title/title.tscn") as PackedScene
	if packed == null:
		_fail("标题场景加载失败")
		return
	var title: Node = packed.instantiate()
	add_child(title)
	await get_tree().process_frame
	var button_count: int = 0
	for child in title.get_children():
		if child is Button:
			button_count += 1
	if button_count == 3:
		_ok()
		print("  标题界面 3 个入口（继续 / 新游戏 / 退出）  OK")
	else:
		_fail("标题按钮数量应为 3，实际 %d" % button_count)
	title.queue_free()

func _b6_delivery_checks() -> void:
	print("== B6 交付项断言（R101/R103/R104/R109/R110）==")
	# 内嵌 OFL 字体：文件存在且可被 FontFile 加载。
	var font_path: String = "res://fonts/NotoSansSC-Regular.ttf"
	if FileAccess.file_exists(font_path):
		var ff: FontFile = FontFile.new()
		if ff.load_dynamic_font(font_path) == OK:
			_ok()
			print("  内嵌中文字体加载成功  OK")
		else:
			_fail("内嵌字体存在但 FontFile 加载失败")
	else:
		_fail("缺少内嵌中文字体 " + font_path)

	# 坏档：乱码快照必须判失败，不抛空引用。
	TurnState.reset()
	if not TurnState.restore_snapshot("{{{坏档"):
		_ok()
		print("  损坏快照 restore 返回 false，不静默吞错  OK")
	else:
		_fail("损坏快照应判恢复失败")

	# 两个纯叙事梦境：可回看台词总量达到 3s 量级（38 字/s ≈ 114 字，取 110 阈值）。
	for dream_id in ["dream_alley", "dream_box"]:
		var scene: Dictionary = WorldData.all().get(dream_id, {}) as Dictionary
		var chars: int = 0
		for spot in scene.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			chars += str(s.get("arg", "")).length()
			chars += str(s.get("arg2", "")).length()
		if chars >= 110:
			_ok()
			print("  %s 可回看台词 %d 字（≥110）  OK" % [dream_id, chars])
		else:
			_fail("%s 台词仅 %d 字，不足 3s 有效内容" % [dream_id, chars])

	# 缩放 / 最小窗口策略已写入工程设置。
	var aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	var min_w: int = int(ProjectSettings.get_setting("display/window/size/min_width", 0))
	var min_h: int = int(ProjectSettings.get_setting("display/window/size/min_height", 0))
	if aspect == "keep" and min_w >= 960 and min_h >= 600:
		_ok()
		print("  stretch aspect=keep，最小窗口 %dx%d  OK" % [min_w, min_h])
	else:
		_fail("缩放策略缺失：aspect=%s min=%dx%d" % [aspect, min_w, min_h])

	# 导出预设：非游戏目录进入排除清单。
	var preset_path: String = "res://export_presets.cfg"
	if FileAccess.file_exists(preset_path):
		var cfg: ConfigFile = ConfigFile.new()
		if cfg.load(preset_path) == OK:
			var exclude: String = str(cfg.get_value("preset.0", "exclude_filter", ""))
			var product: String = str(cfg.get_value("preset.0.options", "application/product_name", ""))
			if exclude.contains("tests/") and exclude.contains("docs/") and exclude.contains("turn-town-whitebox-github-upload/") and not product.is_empty():
				_ok()
				print("  导出预设排除 tests/docs/whitebox，产品名=%s  OK" % product)
			else:
				_fail("导出预设排除清单或产品名缺失：exclude=%s product=%s" % [exclude, product])
		else:
			_fail("export_presets.cfg 解析失败")
	else:
		_fail("缺少 export_presets.cfg")

func _b7_delivery_checks() -> void:
	print("== B7 交付项断言（R126/R128/R130/R131/R134/R135/R136/R137/R138）==")
	# R130 景别三级：街道 76 / 室内中景 84 / 院子近景 90，NPC 默认继承玩家身高。
	var allowed: Array = [76.0, 84.0, 90.0]
	var height_table: Array[String] = []
	var height_ok: bool = true
	for id in WorldData.all():
		var scene: Dictionary = WorldData.all()[id] as Dictionary
		var h: float = float(scene.get("player_height", 0.0))
		height_table.append("%s=%.0f" % [str(id), h])
		if not allowed.has(h):
			height_ok = false
			_fail("场景 %s 玩家身高 %.1f 不在景别表 76/84/90" % [str(id), h])
	if height_ok:
		_ok()
		print("  景别身高全部落在 76/84/90：", " ".join(height_table), "  OK")

	# R134 16:9 安全区：对话框 / 提示条 / 标签底部 y ≤ 540（设计视口 960×600，16:9 裁到 540）。
	var panel_bottom: float = world._dialog_panel.position.y + world._dialog_panel.size.y
	var band_bottom: float = world._hint_band.position.y + world._hint_band.size.y
	if panel_bottom <= 540.0 and band_bottom <= 540.0 and world._dialog_label.position.y + world._dialog_label.size.y <= 540.0:
		_ok()
		print("  HUD 全部在 y≤540 安全区内（对话框底 %.0f，提示条底 %.0f）  OK" % [panel_bottom, band_bottom])
	else:
		_fail("HUD 越出 16:9 安全区：对话框底 %.0f，提示条底 %.0f" % [panel_bottom, band_bottom])

	# R128 存档落点：中段坐标 + 朝向写盘，模拟读回后原地恢复。
	world.force_scene("house_hall")
	var probe: PlayerState = PlayerState.new()
	probe.height = world.player.height
	var target: Vector2 = Vector2(300.0, 470.0)
	if probe.can_stand(target, world.current_scene_data()):
		world.player.pos = target
		world.player.dir = 3
		world._save_position()
		world.player.pos = Vector2(480.0, 480.0)
		world.player.dir = 1
		world._restore_position()
		if world.player.pos.distance_to(target) < 1.0 and world.player.dir == 3:
			_ok()
			print("  存档落点恢复一致：%s dir=%d  OK" % [str(world.player.pos), world.player.dir])
		else:
			_fail("存档落点未恢复：pos=%s dir=%d（目标 %s dir=3）" % [str(world.player.pos), world.player.dir, str(target)])
	else:
		_fail("测试落点 %s 在 house_hall 不可站立" % str(target))

	# R131 出示层接通：A1 / A3 各 4 张卡；对应 NPC 带 present_act；立场写入快照并可读回。
	var a1: Array = Data.evidence_items("A1")
	var a3: Array = Data.evidence_items("A3")
	if a1.size() == 4 and a3.size() == 4:
		_ok()
		print("  A1 出示卡 %d 张、A3 出示卡 %d 张  OK" % [a1.size(), a3.size()])
	else:
		_fail("出示卡数量异常：A1=%d A3=%d" % [a1.size(), a3.size()])

	var town_road: Dictionary = WorldData.all()["town_road"] as Dictionary
	var street_cross: Dictionary = WorldData.all()["street_cross"] as Dictionary
	var xiaoman: Dictionary = _npc_by_id(town_road.get("npcs", []) as Array, "p_xiaoman")
	var tang: Dictionary = _npc_by_id(street_cross.get("npcs", []) as Array, "p_tang")
	if str(xiaoman.get("present_act", "")) == "A1" and str(tang.get("present_act", "")) == "A3":
		_ok()
		print("  小满(A1) / 唐棠(A3) 出示接线到位  OK")
	else:
		_fail("NPC 出示接线缺失：小满 act=%s，唐棠 act=%s" % [str(xiaoman.get("present_act", "")), str(tang.get("present_act", ""))])

	TurnState.set_stance("A1", "half")
	var stance_snap: String = TurnState.snapshot()
	TurnState.reset()
	TurnState.restore_snapshot(stance_snap)
	if TurnState.get_stance("A1") == "half":
		_ok()
		print("  出示立场写入快照并读回  OK")
	else:
		_fail("stance 未持久化：A1=%s" % TurnState.get_stance("A1"))

	# R126 吴长庚档案：act=A3，修理店口径，世界层归位 street_cross。
	var wu: Dictionary = Data.person("p_wu")
	if str(wu.get("act", "")) == "A3" and str(wu.get("tag", "")).contains("修理店"):
		_ok()
		print("  吴长庚档案 A3 / 修理店口径  OK")
	else:
		_fail("吴长庚档案未对齐：act=%s tag=%s" % [str(wu.get("act", "")), str(wu.get("tag", ""))])
	var wu_npc: Dictionary = _npc_by_id(street_cross.get("npcs", []) as Array, "p_wu")
	if not wu_npc.is_empty():
		_ok()
		print("  吴长庚归位 street_cross  OK")
	else:
		_fail("street_cross 缺少吴长庚 NPC")

	# R135/R136/R137/R138 文案一致性：只读原文比对，不改既有剧情文本。
	var evidence_raw: String = FileAccess.get_file_as_string("res://data/evidence.json")
	var story_raw: String = FileAccess.get_file_as_string("res://data/story.json")
	var journal_raw: String = FileAccess.get_file_as_string("res://data/journal.json")
	var text_checks: Array = [
		[evidence_raw, "九点", "磁带时间已统一为九点"],
		[evidence_raw, "老地方", "磁带地点已统一为老地方"],
		[evidence_raw, "磁带机", "收音机已改磁带机"],
		[evidence_raw, "一天一行", "记录本数字口径对齐"],
		[story_raw, "你孩子吧", "辈分疑问已改对"],
		[journal_raw, "修理店", "档案标签修理店口径"],
	]
	for check in text_checks:
		if str(check[0]).contains(str(check[1])):
			_ok()
			print("  ", str(check[2]), "  OK")
		else:
			_fail("文案未命中：" + str(check[2]))
	for bad in ["两点，桥下", "你儿子吧", "七个日期"]:
		if evidence_raw.contains(bad) or story_raw.contains(bad) or journal_raw.contains(bad):
			_fail("残留矛盾文案：" + bad)
		else:
			_ok()
			print("  无残留「", bad, "」  OK")
	if evidence_raw.contains("修到一半的收音机"):
		_fail("物证标签仍是收音机")
	else:
		_ok()
		print("  物证标签为磁带机，无收音机素材错位  OK")

func _npc_by_id(npcs: Array, person_id: String) -> Dictionary:
	for npc in npcs:
		var entry: Dictionary = npc as Dictionary
		if str(entry.get("id", "")) == person_id:
			return entry
	return {}

func _b8_delivery_checks() -> void:
	print("== B8 交付项断言（R152/R153/R154/R156/R159/R162）==")
	# R152 单一数据源：手记侧实例合成推论后，世界侧实例不 reload 直读 flags 必须为 true。
	TurnState.reset()
	world.puzzle.reload()
	var world_p: PuzzleState = world.puzzle
	var journal_p: PuzzleState = PuzzleState.new()
	world_p.add_evidence("ev_note")
	world_p.add_evidence("ev_photo")
	var attempt: Dictionary = journal_p.combine_attempt("ev_note", "ev_photo")
	if bool(attempt.get("ok", false)) and world_p.has_clue("cl_score"):
		_ok()
		print("  双实例同读 flags：手记侧合成后世界侧直读 cl_score=true，未 reload  OK")
	else:
		_fail("R152 双实例分叉：attempt=%s world_p.has_clue(cl_score)=%s" % [str(attempt), str(world_p.has_clue("cl_score"))])

	# R154 就近优先：夜场站在旧鞋热点上，主目标是鞋（物证），不是周德海对话。
	world.force_scene("playground_night")
	await get_tree().process_frame
	world.player.pos = Vector2(560.0, 500.0)
	world._update_nearby()
	if world._primary_kind == "spot" and str(world._primary.get("gives_evidence", "")) == "ev_shoes":
		_ok()
		print("  夜场鞋点按 E 主目标=ev_shoes（NPC 周德海未截胡）  OK")
	else:
		_fail("R154 夜场鞋点被截胡：kind=%s evidence=%s" % [world._primary_kind, str(world._primary.get("gives_evidence", ""))])
	# 路口清单点同样优先于吴长庚。
	world.force_scene("street_cross")
	await get_tree().process_frame
	world.player.pos = Vector2(430.0, 400.0)
	world._update_nearby()
	if world._primary_kind == "spot" and str(world._primary.get("gives_evidence", "")) == "ev_list":
		_ok()
		print("  路口清单点按 E 主目标=ev_list（NPC 吴长庚未截胡）  OK")
	else:
		_fail("R154 路口清单被截胡：kind=%s evidence=%s" % [world._primary_kind, str(world._primary.get("gives_evidence", ""))])

	# R153 序章返程边：office → room 为 open_edge 返程，不再单向关死。
	var office: Dictionary = WorldData.all()["langcheng_office"]
	var back_edge: Dictionary = {}
	for edge in office.get("exits", []) as Array:
		if str(edge.get("to", "")) == "langcheng_room":
			back_edge = edge
	if not back_edge.is_empty() and bool(back_edge.get("open_edge", false)):
		_ok()
		print("  工位→出租屋返程边在位（open_edge）  OK")
	else:
		_fail("R153 缺少 office→room 返程边：" + str(back_edge))

	# R162 由出口进入梦境时记录来源场景，醒转回到来源而非兜底堂屋。
	world.force_scene("playground_night")
	await get_tree().process_frame
	world._return_scene = ""
	world.travel("dream_swing")
	await get_tree().process_frame
	await get_tree().process_frame
	if world._return_scene == "playground_night":
		_ok()
		print("  出口入梦醒转来源已记录：_return_scene=playground_night  OK")
	else:
		_fail("R162 梦醒回落来源丢失：_return_scene=%s" % world._return_scene)
	# 醒转兜底：回到来源夜场，而不是 house_hall。
	world._wake()
	for i in range(60):
		await get_tree().create_timer(0.03).timeout
		if world.scene_id == "playground_night":
			break
	if world.scene_id == "playground_night":
		_ok()
		print("  秋千梦醒落回 playground_night（未兜底 house_hall）  OK")
	else:
		_fail("R162 梦醒落点错误：" + world.scene_id)

	# R156 正常玩法路径分档：只经 add_evidence 喂物证，再算档（不直接调 settle 传数字）。
	TurnState.reset()
	world.puzzle.reload()
	for soft_id in ["ev_letter", "ev_note"]:
		world.puzzle.add_evidence(str(soft_id))
	var soft_tier: String = TurnState.settle_collection_tier(world.puzzle.all_evidence().size(), world.puzzle.all_clues().size())
	if soft_tier == "soft":
		_ok()
		print("  玩法路径 2 物证 → soft 档（%d/10 物证）  OK" % world.puzzle.all_evidence().size())
	else:
		_fail("R156 2 物证应判 soft，实际 " + soft_tier)
	TurnState.reset()
	world.puzzle.reload()
	for half_id in ["ev_letter", "ev_note", "ev_photo", "ev_screw", "ev_shoes"]:
		world.puzzle.add_evidence(str(half_id))
	var half_tier: String = TurnState.settle_collection_tier(world.puzzle.all_evidence().size(), world.puzzle.all_clues().size())
	if half_tier == "half":
		_ok()
		print("  玩法路径 5 物证 → half 档（%d/10 物证）  OK" % world.puzzle.all_evidence().size())
	else:
		_fail("R156 5 物证应判 half，实际 " + half_tier)

	# R159 结算面板：clear 档标题/计数/缺失名齐备，带回标题入口。
	TurnState.reset()
	world.puzzle.reload()
	world.puzzle.add_evidence("ev_letter")
	world._open_ending_panel("clear")
	if str(world._ending_title.text).contains("全说开") and str(world._ending_summary.text).contains("/5") and not str(world._ending_missing.text).is_empty():
		_ok()
		print("  结局结算页：标题/计数/缺失名齐备  OK")
	else:
		_fail("R159 结算面板要素缺失：title=%s summary=%s missing=%s" % [str(world._ending_title.text), str(world._ending_summary.text), str(world._ending_missing.text)])
	world._close_ending_panel()

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
