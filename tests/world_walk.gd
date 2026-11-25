extends Node

# 探索模式自动检查：
# 1) 静态：场景数量、出生点、出口连通、热点合法、图片存在
# 2) 可达性：网格 BFS，确认每个出口/热点/NPC 都能走到
# 3) 50 轮随机走位，验证玩家永远不出界、不进墙

const PlayerState = preload("res://world/player_state.gd")
const WorldData = preload("res://world/world_data.gd")
const PuzzleState = preload("res://world/puzzle_state.gd")
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
	_cross_scene_reachability()
	_puzzle_checks()
	_wiring_checks()
	await _lock_world_checks()
	await _cross_scene_chain()
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
			if not (kind in ["talk", "item", "travel", "story", "dream", "wake", "combo"]):
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
	print("== 跨场景连通 BFS ==")
	var scenes: Dictionary = WorldData.all()
	var adjacency: Dictionary = {}
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		var edges: Array[String] = []
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			if bool(e.get("wake", false)):
				continue
			var to: String = str(e.get("to", ""))
			if not to.is_empty() and scenes.has(to):
				edges.append(to)
		for spot in data.get("spots", []) as Array:
			var s: Dictionary = spot as Dictionary
			var kind: String = str(s.get("kind", ""))
			if kind == "travel" or kind == "dream":
				var target: String = str(s.get("arg", ""))
				if scenes.has(target):
					edges.append(target)
		adjacency[scene_id] = edges
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
	world._use_combo(combo_spot)
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

func _lock_world_checks() -> void:
	print("== 锁出口世界级检查 ==")
	var scenes: Dictionary = WorldData.all()
	var target_scene: String = ""
	var target_exit: Dictionary = {}
	for id in scenes.keys():
		var scene_id: String = str(id)
		var data: Dictionary = scenes[id] as Dictionary
		for exit in data.get("exits", []) as Array:
			var e: Dictionary = exit as Dictionary
			var lock: Dictionary = e.get("lock", {}) as Dictionary
			if not lock.is_empty() and lock.has("evidence"):
				target_scene = scene_id
				target_exit = e
				break
		if not target_scene.is_empty():
			break
	if target_scene.is_empty():
		_fail("没有可测的物证锁出口")
		return

	world.force_scene(target_scene)
	await get_tree().process_frame
	world._use_exit(target_exit)
	await get_tree().process_frame
	if world.scene_id == target_scene and world._dialog_open:
		_ok()
		print("  锁拒绝：未进入且弹出缺口提示  OK")
	else:
		_fail("锁出口应拒绝进入并给出可读提示")

	var lock: Dictionary = target_exit.get("lock", {}) as Dictionary
	for eid in lock.get("evidence", []) as Array:
		world.puzzle.add_evidence(str(eid))
	world._dialog_open = false
	world._use_exit(target_exit)
	await get_tree().create_timer(0.90).timeout
	if world.scene_id == str(target_exit.get("to", "")):
		_ok()
		print("  锁通过：条件满足后进入目标场景  OK")
	else:
		_fail("满足条件后应进入 " + str(target_exit.get("to", "")))
	checks += 1

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
