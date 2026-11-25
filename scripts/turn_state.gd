extends Node

# v3 全局状态：手记、举证立场、伏笔 flag、提示计时、结局分档。
# 存进 ConfigFile 时只存一段 JSON，字段扩展不需要改 chapter_progress 白名单。

signal journal_changed
signal stance_changed(act: String, value: String)
signal hint_changed(level: int)

const Data = preload("res://scripts/turn_data.gd")

const STANCES := ["none", "expose", "half", "soft", "decoy"]
const ACT_ORDER := ["prologue", "A1", "A2", "A3", "ending"]

var flags: Dictionary = {}
var people: Array[String] = []
var items: Array[String] = []
var backlog: Array[Dictionary] = []
var stance: Dictionary = {"A1": "none", "A2": "none", "A3": "none"}
var current_act: String = "prologue"
var letters_read: Array[int] = []
var cg_unlocked: Array[String] = []
var bgm_unlocked: Array[String] = []
var ending_tier: String = ""
var hint_index: int = 0
var idle_since: int = 0
var play_started: int = 0

func _ready() -> void:
	play_started = Time.get_ticks_msec()
	idle_since = play_started
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset() -> void:
	flags.clear()
	people.clear()
	items.clear()
	backlog.clear()
	stance = {"A1": "none", "A2": "none", "A3": "none"}
	current_act = "prologue"
	letters_read.clear()
	cg_unlocked.clear()
	bgm_unlocked.clear()
	ending_tier = ""
	hint_index = 0
	idle_since = Time.get_ticks_msec()
	journal_changed.emit()
	hint_changed.emit(hint_index)

func set_flag(key: String, value: Variant = true) -> void:
	if key.is_empty():
		return
	flags[key] = value
	idle_since = Time.get_ticks_msec()

func get_flag(key: String, fallback: Variant = false) -> Variant:
	if flags.has(key):
		return flags[key]
	return fallback

func has_flag(key: String) -> bool:
	return flags.has(key) and bool(flags[key])

func erase_flag(key: String) -> void:
	if flags.has(key):
		flags.erase(key)

func start_act(act: String) -> void:
	current_act = act
	hint_index = 0
	idle_since = Time.get_ticks_msec()
	unlock_act_people(act)
	hint_changed.emit(hint_index)
	journal_changed.emit()

func unlock_act_people(act: String) -> void:
	for entry in Data.person_entries():
		if not (entry is Dictionary):
			continue
		var entry_act: String = str(entry.get("act", ""))
		if entry_act == act:
			var person_id: String = str(entry.get("id", ""))
			if not person_id.is_empty():
				unlock_person(person_id, false)
	journal_changed.emit()

func unlock_person(id: String, announce: bool = true) -> void:
	if id.is_empty() or people.has(id) or not Data.person_exists(id):
		return
	people.append(id)
	if announce:
		journal_changed.emit()

func unlock_item(id: String) -> void:
	if id.is_empty() or items.has(id):
		return
	if not Data.item_exists(id):
		return
	items.append(id)
	journal_changed.emit()

func knows_item(id: String) -> bool:
	return items.has(id)

func push_backlog(speaker: String, line: String) -> void:
	if line.is_empty():
		return
	backlog.append({"speaker": speaker, "line": line})
	while backlog.size() > 120:
		backlog.remove_at(0)
	journal_changed.emit()

func set_stance(act: String, value: String) -> void:
	if not stance.has(act):
		return
	if not STANCES.has(value):
		return
	stance[act] = value
	stance_changed.emit(act, value)

func get_stance(act: String) -> String:
	return str(stance.get(act, "none"))

func resolve_tier() -> String:
	var first: String = get_stance("A1")
	var last: String = get_stance("A3")
	if first == "soft" and last == "soft":
		return "soft"
	if first == "expose" or last == "expose":
		return "clear"
	if first == "none" and last == "none":
		return "soft"
	return "half"

func settle_ending() -> String:
	ending_tier = resolve_tier()
	set_flag("ending_tier", ending_tier)
	if not cg_unlocked.has(ending_tier):
		cg_unlocked.append(ending_tier)
	return ending_tier

# 终章按收集度分档：clear 物证≥8 且推论≥4；half 物证≥5 或推论≥3；其余 soft。
func settle_collection_tier(evidence_n: int, clue_n: int) -> String:
	if evidence_n >= 8 and clue_n >= 4:
		ending_tier = "clear"
	elif evidence_n >= 5 or clue_n >= 3:
		ending_tier = "half"
	else:
		ending_tier = "soft"
	set_flag("ending_tier", ending_tier)
	if not cg_unlocked.has(ending_tier):
		cg_unlocked.append(ending_tier)
	hint_changed.emit(hint_index)
	journal_changed.emit()
	return ending_tier

func mark_letter(index: int) -> void:
	if not letters_read.has(index):
		letters_read.append(index)
		journal_changed.emit()

func unlock_cg(name: String) -> void:
	if name.is_empty() or cg_unlocked.has(name):
		return
	cg_unlocked.append(name)
	journal_changed.emit()

func unlock_bgm(name: String) -> void:
	if name.is_empty() or bgm_unlocked.has(name):
		return
	bgm_unlocked.append(name)
	journal_changed.emit()

func idle_seconds() -> float:
	return float(Time.get_ticks_msec() - idle_since) / 1000.0

func request_hint() -> int:
	if hint_index < 3:
		hint_index += 1
	idle_since = Time.get_ticks_msec()
	hint_changed.emit(hint_index)
	return hint_index

func current_hint() -> String:
	if hint_index <= 0:
		return ""
	return Data.hint_text(current_act, hint_index)

func note_progress() -> void:
	idle_since = Time.get_ticks_msec()
	if hint_index > 0:
		hint_index = 0
		hint_changed.emit(hint_index)

func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"people": people.duplicate(),
		"items": items.duplicate(),
		"backlog": backlog.duplicate(true),
		"stance": stance.duplicate(),
		"current_act": current_act,
		"letters_read": letters_read.duplicate(),
		"cg_unlocked": cg_unlocked.duplicate(),
		"bgm_unlocked": bgm_unlocked.duplicate(),
		"ending_tier": ending_tier,
	}

func snapshot() -> String:
	return JSON.stringify(to_dict())

func from_dict(data: Dictionary) -> void:
	flags = {}
	if data.has("flags") and data["flags"] is Dictionary:
		flags = (data["flags"] as Dictionary).duplicate(true)
	people = []
	if data.has("people") and data["people"] is Array:
		for value in data["people"]:
			people.append(str(value))
	items = []
	if data.has("items") and data["items"] is Array:
		for value in data["items"]:
			items.append(str(value))
	backlog = []
	if data.has("backlog") and data["backlog"] is Array:
		for value in data["backlog"]:
			if value is Dictionary:
				backlog.append((value as Dictionary).duplicate())
	stance = {"A1": "none", "A2": "none", "A3": "none"}
	if data.has("stance") and data["stance"] is Dictionary:
		for key in stance.keys():
			var value: String = str((data["stance"] as Dictionary).get(key, "none"))
			if STANCES.has(value):
				stance[key] = value
	current_act = str(data.get("current_act", "prologue"))
	letters_read = []
	if data.has("letters_read") and data["letters_read"] is Array:
		for value in data["letters_read"]:
			letters_read.append(int(value))
	cg_unlocked = []
	if data.has("cg_unlocked") and data["cg_unlocked"] is Array:
		for value in data["cg_unlocked"]:
			cg_unlocked.append(str(value))
	bgm_unlocked = []
	if data.has("bgm_unlocked") and data["bgm_unlocked"] is Array:
		for value in data["bgm_unlocked"]:
			bgm_unlocked.append(str(value))
	ending_tier = str(data.get("ending_tier", ""))
	hint_index = 0
	idle_since = Time.get_ticks_msec()
	journal_changed.emit()

func restore_snapshot(raw: String) -> bool:
	if raw.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return false
	from_dict(parsed as Dictionary)
	return true

func journal_counts() -> Dictionary:
	return {
		"people": people.size(),
		"items": items.size(),
		"backlog": backlog.size(),
	}
