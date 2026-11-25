extends RefCounted

# v3 数据层：所有台词、手记条目、举证卡都从 res://data/*.json 读。
# 设计口径见《turn v3 策划优化稿.md》。改文案只改 JSON，不改脚本。

const DIALOGUE_PATH := "res://data/dialogue.json"
const JOURNAL_PATH := "res://data/journal.json"
const EVIDENCE_PATH := "res://data/evidence.json"

static var _dialogue_cache: Dictionary = {}
static var _journal_cache: Dictionary = {}
static var _evidence_cache: Dictionary = {}

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("缺少数据文件：" + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("打不开数据文件：" + path)
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("数据文件不是对象：" + path)
	return {}

static func dialogue() -> Dictionary:
	if _dialogue_cache.is_empty():
		_dialogue_cache = load_json(DIALOGUE_PATH)
	return _dialogue_cache

static func journal() -> Dictionary:
	if _journal_cache.is_empty():
		_journal_cache = load_json(JOURNAL_PATH)
	return _journal_cache

static func evidence() -> Dictionary:
	if _evidence_cache.is_empty():
		_evidence_cache = load_json(EVIDENCE_PATH)
	return _evidence_cache

static func act_evidence(act: String) -> Dictionary:
	var all_data: Dictionary = evidence()
	if all_data.has(act) and all_data[act] is Dictionary:
		return all_data[act] as Dictionary
	return {}

static func evidence_items(act: String) -> Array:
	var act_data: Dictionary = act_evidence(act)
	if act_data.has("items") and act_data["items"] is Array:
		return act_data["items"] as Array
	return []

static func act_title(act: String) -> Dictionary:
	var titles: Dictionary = dialogue().get("titles", {}) as Dictionary
	if titles.has(act) and titles[act] is Dictionary:
		return titles[act] as Dictionary
	return {"no": "", "name": act, "epigraph": ""}

static func hints_for(act: String) -> Array:
	var hints: Dictionary = dialogue().get("hints", {}) as Dictionary
	if hints.has(act) and hints[act] is Array:
		return hints[act] as Array
	return []

static func hint_text(act: String, level: int) -> String:
	var hints: Array = hints_for(act)
	if hints.is_empty():
		return ""
	var index: int = clampi(level - 1, 0, hints.size() - 1)
	return str(hints[index])

static func ending(tier: String) -> Dictionary:
	var endings: Dictionary = dialogue().get("endings", {}) as Dictionary
	if endings.has(tier) and endings[tier] is Dictionary:
		return endings[tier] as Dictionary
	return {}

static func letter_note(key: String) -> String:
	var letters: Dictionary = dialogue().get("letters", {}) as Dictionary
	return str(letters.get(key, ""))

static func person_entries() -> Array:
	var people: Variant = journal().get("people", [])
	if people is Array:
		return people as Array
	return []

static func person(id: String) -> Dictionary:
	for entry in person_entries():
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry as Dictionary
	return {}

static func item_entries() -> Array:
	var items: Variant = journal().get("items", [])
	if items is Array:
		return items as Array
	return []

static func item(id: String) -> Dictionary:
	for entry in item_entries():
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry as Dictionary
	return {}

static func item_exists(id: String) -> bool:
	return not item(id).is_empty()

static func person_exists(id: String) -> bool:
	return not person(id).is_empty()

static func exists(path: String) -> bool:
	return ResourceLoader.exists(path, "Texture2D")

static func texture(path: String) -> Texture2D:
	if path.is_empty() or not exists(path):
		return null
	return load(path) as Texture2D
