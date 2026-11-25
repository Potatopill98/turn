extends RefCounted

# 主线章节数据：读 res://data/story.json。
# 每幕一组 beat，beat 字段：
#   t     : n 旁白 / d 对白 / c 选择 / m 记忆
#   bg    : 背景图（可选，切换时生效）
#   who   : 说话人（可选）
#   text  : 正文
#   m     : true 进入记忆色调
#   if    : 条件 flag，支持 "flag" 与 "!flag"
#   options: 选择项，每项 {label, flag}

const PATH := "res://data/story.json"
static var _cache: Dictionary = {}

static func all() -> Dictionary:
	if _cache.is_empty():
		var text: String = FileAccess.get_file_as_string(PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_cache = (parsed as Dictionary).duplicate(true)
	return _cache

static func act(id: String) -> Dictionary:
	var acts: Dictionary = all().get("acts", {}) as Dictionary
	var entry: Variant = acts.get(id, {})
	if entry is Dictionary:
		return entry as Dictionary
	return {}

static func beats(id: String) -> Array:
	var entry: Dictionary = act(id)
	var list: Variant = entry.get("beats", [])
	if list is Array:
		return list as Array
	return []

static func title(id: String) -> String:
	return str(act(id).get("title", id))

static func has(id: String) -> bool:
	return not act(id).is_empty()

static func act_ids() -> Array[String]:
	var ids: Array[String] = []
	var acts: Dictionary = all().get("acts", {}) as Dictionary
	for key in acts.keys():
		ids.append(str(key))
	return ids
