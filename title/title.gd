extends Control

# 标题界面：继续上次 / 新游戏 / 退出。存档损坏时给中文提示，不静默（R082）。

const WorldPath: String = "res://world/world.tscn"
const SAVE_FILE: String = "user://turn_world.cfg"
const SKIN = preload("res://ui/theme.gd")

var _continue_btn: Button = null
var _corrupt_label: Label = null
var _title_label: Label = null
var _sub_label: Label = null

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_title_label = SKIN.make_label("归乡", 42, SKIN.PAPER, 400.0, HORIZONTAL_ALIGNMENT_CENTER)
	_title_label.position = Vector2(280, 150)
	add_child(_title_label)

	_sub_label = SKIN.make_label("有些路，走回来才算走完。", 14, SKIN.GOLD_DIM, 400.0, HORIZONTAL_ALIGNMENT_CENTER)
	_sub_label.position = Vector2(280, 214)
	add_child(_sub_label)

	_continue_btn = SKIN.make_button("继续上次", 15, 220.0, 40.0)
	_continue_btn.position = Vector2(370, 300)
	_continue_btn.pressed.connect(_on_continue)
	add_child(_continue_btn)

	var new_btn: Button = SKIN.make_button("新游戏", 15, 220.0, 40.0)
	new_btn.position = Vector2(370, 352)
	new_btn.pressed.connect(_on_new_game)
	add_child(new_btn)

	var quit_btn: Button = SKIN.make_button("退出", 15, 220.0, 40.0)
	quit_btn.position = Vector2(370, 404)
	quit_btn.pressed.connect(_on_quit)
	add_child(quit_btn)

	_corrupt_label = SKIN.make_label("存档损坏：可以重新开始。", 12, SKIN.RED, 400.0, HORIZONTAL_ALIGNMENT_CENTER)
	_corrupt_label.position = Vector2(280, 456)
	_corrupt_label.visible = false
	add_child(_corrupt_label)

func _save_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE):
		return {"exists": false, "valid": false}
	var file: ConfigFile = ConfigFile.new()
	if file.load(SAVE_FILE) != OK:
		return {"exists": true, "valid": false}
	var raw: String = str(file.get_value("world", "v3_state", ""))
	var parsed: Variant = JSON.parse_string(raw)
	return {"exists": true, "valid": parsed is Dictionary and not raw.is_empty()}

func _refresh() -> void:
	var state: Dictionary = _save_state()
	_continue_btn.disabled = not bool(state.get("valid", false))
	_corrupt_label.visible = bool(state.get("exists", false)) and not bool(state.get("valid", false))

func _on_continue() -> void:
	var state: Dictionary = _save_state()
	if not bool(state.get("valid", false)):
		return
	var file: ConfigFile = ConfigFile.new()
	file.load(SAVE_FILE)
	var raw: String = str(file.get_value("world", "v3_state", ""))
	TurnState.restore_snapshot(raw)
	get_tree().change_scene_to_file(WorldPath)

func _on_new_game() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))
	TurnState.reset()
	get_tree().change_scene_to_file(WorldPath)

func _on_quit() -> void:
	get_tree().quit()
