extends RefCounted

const FILE := "user://turn_chapters.cfg"
const SCENES := {"room":"res://room.tscn", "letter1":"res://later_chapters.tscn", "day":"res://later_chapters.tscn", "letter2":"res://later_chapters.tscn", "street":"res://later_chapters.tscn", "letter3":"res://later_chapters.tscn", "ending":"res://later_chapters.tscn"}
const NAMES := {"room":"旧宅", "letter1":"第一封信", "day":"老街", "letter2":"第二封信", "street":"搬家路口", "letter3":"第三封信", "ending":"镇口灯火"}

static func read_save() -> ConfigFile:
	var data := ConfigFile.new()
	if data.load(FILE) != OK or not SCENES.has(data.get_value("turn", "chapter", "")):
		data.clear()
	return data

static func mark(tree: SceneTree, chapter: String):
	var data := ConfigFile.new()
	data.set_value("turn", "chapter", chapter)
	for key in ["prologue_diary", "shared_note", "spoke_to_zhou"]:
		if tree.has_meta(key):
			data.set_value("turn", key, tree.get_meta(key))
	var state := tree.root.get_node_or_null("TurnState")
	if state != null:
		data.set_value("turn", "v3_state", state.snapshot())
	var result := data.save(FILE)
	if result != OK:
		push_warning("章节进度保存失败：" + error_string(result))

static func restore(tree: SceneTree, data: ConfigFile) -> Error:
	var chapter: String = data.get_value("turn","chapter","")
	if not SCENES.has(chapter):
		return ERR_INVALID_DATA
	for key in ["prologue_diary", "shared_note", "spoke_to_zhou"]:
		if data.has_section_key("turn", key):
			tree.set_meta(key, data.get_value("turn",key))
		elif tree.has_meta(key):
			tree.remove_meta(key)
	var state := tree.root.get_node_or_null("TurnState")
	if state != null:
		var raw: String = str(data.get_value("turn", "v3_state", ""))
		state.restore_snapshot(raw)
	tree.set_meta("entry_chapter", chapter)
	return tree.change_scene_to_file(SCENES[chapter])

static func fresh(tree: SceneTree):
	for key in ["prologue_diary","shared_note","spoke_to_zhou","entry_chapter"]:
		if tree.has_meta(key):
			tree.remove_meta(key)
	var state := tree.root.get_node_or_null("TurnState")
	if state != null:
		state.reset()
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
