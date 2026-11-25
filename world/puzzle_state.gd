extends RefCounted

# B1 物证 / 推论 / 条件锁状态层。
# 公开接口按审计命名：has_evidence / add_evidence / try_combine / has_clue / lock_state。
# 状态持久化到 TurnState 的 flag（JSON 数组），换场景回来不丢；重复拾取返回 false。

signal evidence_gained(id: String)

# 现场物证登记（id -> 名称）。文案只登记在这里，不改 data/*.json。
const EVIDENCE_NAMES: Dictionary = {
	"ev_letter": "合同残角",
	"ev_note": "茶几便签残片",
	"ev_photo": "门槛缝里的旧照片",
	"ev_screw": "拧平的螺丝",
	"ev_shoes": "灯下的旧鞋",
	"ev_list": "搬家清单",
	"ev_tape": "旧磁带",
	"ev_mirror": "裂了两道缝的破镜子",
	"ev_draft": "抽屉里的草稿",
	"ev_ticket": "没寄出去的站台票根",
}

# 每件物证的出口去向（锁 / 组合 / 出示），手记分区里标注用。
const EVIDENCE_USAGE: Dictionary = {
	"ev_letter": "开锁：凭它离开出租屋去公司；组合：和草稿并排对上",
	"ev_note": "组合：和旧照片并排对上",
	"ev_photo": "开锁：凭它进老宅堂屋；组合：和便签对上",
	"ev_screw": "组合：和旧鞋并排对上",
	"ev_shoes": "组合：和螺丝对上；可出示给周德海；组合：和票根对上",
	"ev_list": "组合：和旧磁带并排对上",
	"ev_tape": "组合：和搬家清单对上",
	"ev_mirror": "开锁：带着旧镜，才看得清入夜秋千的路",
	"ev_draft": "组合：和合同残角并排对上",
	"ev_ticket": "组合：和旧鞋并排对上",
}

# 组合推论登记（id -> 名称 / 文本）。
const CLUE_NAMES: Dictionary = {
	"cl_score": "他把谱子一张张收了回来",
	"cl_lamp": "这盏灯是等人回来的",
	"cl_tape": "那句道别一直没寄出去",
	"cl_leave": "纸上的地址还是回镇上",
	"cl_return": "她一直留在原地等我回来",
}

const CLUE_TEXTS: Dictionary = {
	"cl_score": "便签上的备用弦，和旧照片里同一把琴对上了——父亲收琴谱的时候，也把她走的路留着。",
	"cl_lamp": "拧了三年的螺丝，配着灯下那双鞋底还干净的旧鞋：灯不是修给街面的，是修给一个没回来的孩子的。",
	"cl_tape": "清单最后一改了三回，磁带里的人声却停在 00:18——有人把道别录好了，一直没寄出去。",
	"cl_leave": "合同残角上的地址，和草稿页边记的是同一个地方：绕了一整年，要去的还是回镇上那条路。",
	"cl_return": "站台票根挨着灯下那双没穿走的旧鞋：一个走得急，一个留下来等，两个人都没走出这条街。",
}

# 配方：无序两件物证 -> 推论。key 按字母序拼接 "a|b"。
const COMBOS: Dictionary = {
	"ev_note|ev_photo": "cl_score",
	"ev_screw|ev_shoes": "cl_lamp",
	"ev_list|ev_tape": "cl_tape",
	"ev_draft|ev_letter": "cl_leave",
	"ev_shoes|ev_ticket": "cl_return",
}

const FLAG_EVIDENCE: String = "pz_evidence"
const FLAG_CLUE: String = "pz_clues"
const FLAG_FRESH: String = "pz_fresh"

var _evidence: Array[String] = []
var _clues: Array[String] = []
var _fresh: Array[String] = []

func _init() -> void:
	_load()

# ------------------------------------------------------------ 读取

func has_evidence(id: String) -> bool:
	return _evidence.has(id)

func has_clue(id: String) -> bool:
	return _clues.has(id)

func all_evidence() -> Array[String]:
	return _evidence.duplicate()

func all_clues() -> Array[String]:
	return _clues.duplicate()

func fresh_ids() -> Array[String]:
	return _fresh.duplicate()

func evidence_name(id: String) -> String:
	return str(EVIDENCE_NAMES.get(id, id))

func usage_of(id: String) -> String:
	return str(EVIDENCE_USAGE.get(id, ""))

func clue_name(id: String) -> String:
	return str(CLUE_NAMES.get(id, id))

func clue_text(id: String) -> String:
	return str(CLUE_TEXTS.get(id, ""))

# 反查一条推论由哪两件物证合成（无序，返回两个物证 id）。
func clue_sources(id: String) -> Array[String]:
	var out: Array[String] = []
	for pair in COMBOS.keys():
		var key: String = str(pair)
		if str(COMBOS[key]) == id:
			var parts: PackedStringArray = key.split("|")
			if parts.size() == 2:
				out.append(str(parts[0]))
				out.append(str(parts[1]))
			break
	return out

# ------------------------------------------------------------ 写入

func add_evidence(id: String) -> bool:
	if id.is_empty():
		return false
	if _evidence.has(id):
		return false
	_evidence.append(id)
	if not _fresh.has(id):
		_fresh.append(id)
	_save()
	evidence_gained.emit(id)
	return true

func try_combine(a: String, b: String) -> String:
	if a.is_empty() or b.is_empty():
		return ""
	if not _evidence.has(a) or not _evidence.has(b):
		return ""
	var key: String = _pair_key(a, b)
	if not COMBOS.has(key):
		return ""
	var clue: String = str(COMBOS[key])
	if _clues.has(clue):
		return ""
	_clues.append(clue)
	if not _fresh.has(clue):
		_fresh.append(clue)
	_save()
	return clue

func add_clue(id: String) -> bool:
	if id.is_empty() or _clues.has(id):
		return false
	_clues.append(id)
	if not _fresh.has(id):
		_fresh.append(id)
	_save()
	return true

func clear_fresh() -> void:
	_fresh.clear()
	_save()

# 从 TurnState 重新载入（手记面板持有独立实例时，打开前调用以同步世界层拾取结果）。
func reload() -> void:
	_load()

# ------------------------------------------------------------ 条件锁

# lock 约定：{"evidence": Array[String], "clues": Array[String], "hint": String}
# 返回 {"ok": bool, "missing": Array[String], "hint": String}；missing 为缺的物证/推论 id。
func lock_state(lock: Dictionary) -> Dictionary:
	var missing: Array[String] = []
	for eid in lock.get("evidence", []) as Array:
		var e: String = str(eid)
		if not _evidence.has(e):
			missing.append(e)
	for cid in lock.get("clues", []) as Array:
		var c: String = str(cid)
		if not _clues.has(c):
			missing.append(c)
	var hint: String = str(lock.get("hint", ""))
	var result: Dictionary = {
		"ok": missing.is_empty(),
		"missing": missing,
		"hint": hint,
	}
	return result

# ------------------------------------------------------------ 持久化

static func _pair_key(a: String, b: String) -> String:
	if a <= b:
		return a + "|" + b
	return b + "|" + a

func _load() -> void:
	_evidence = _read_list(FLAG_EVIDENCE)
	_clues = _read_list(FLAG_CLUE)
	_fresh = _read_list(FLAG_FRESH)

func _save() -> void:
	_write_list(FLAG_EVIDENCE, _evidence)
	_write_list(FLAG_CLUE, _clues)
	_write_list(FLAG_FRESH, _fresh)

func _read_list(flag: String) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = TurnState.get_flag(flag, "")
	if raw is String and not (raw as String).is_empty():
		var parsed: Variant = JSON.parse_string(raw as String)
		if parsed is Array:
			for value in parsed as Array:
				out.append(str(value))
	return out

func _write_list(flag: String, values: Array[String]) -> void:
	TurnState.set_flag(flag, JSON.stringify(values))
