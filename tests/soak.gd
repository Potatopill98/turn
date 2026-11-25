extends Node

# 演出浸泡测试：50 轮随机「进场景 → 触发热点对话 → 走出口 → 转场」，
# 检查对话状态、转场、脉冲不把游戏卡住。

var world = null

func _ready() -> void:
	TurnState.reset()
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	world = packed.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	if world.chapter != null:
		world.chapter.skip()
	await get_tree().process_frame

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261126
	var fails: int = 0
	var talks: int = 0
	var travels: int = 0

	for round_index in 50:
		var ids: Array = world.scene_ids()
		var pick: String = str(ids[rng.randi_range(0, ids.size() - 1)])
		world.force_scene(pick)
		await get_tree().process_frame

		var spots: Array = world.current_scene_data().get("spots", []) as Array
		for k in 3:
			if spots.size() <= 0:
				continue
			var sp: Dictionary = spots[rng.randi_range(0, spots.size() - 1)] as Dictionary
			var kind: String = str(sp.get("kind", "talk"))
			if kind == "talk" or kind == "item":
				world.player.pos = sp.get("pos", Vector2(400, 400)) as Vector2
				world._process(0.016)
				world._use_spot(sp)
				talks += 1
				await get_tree().process_frame
				if not world._dialog_open:
					fails += 1
					print("  FAIL round=", round_index, " 对话没打开：", sp.get("label", ""))
				world._advance_dialog()
				world._advance_dialog()
				await get_tree().process_frame

		var exits: Array = world.current_scene_data().get("exits", []) as Array
		if exits.size() > 0:
			var ex: Dictionary = exits[rng.randi_range(0, exits.size() - 1)] as Dictionary
			if bool(ex.get("wake", false)):
				world._use_exit(ex)
			elif not str(ex.get("to", "")).is_empty():
				world.travel(str(ex.get("to", "")), str(ex.get("spawn", "")))
			travels += 1
			await get_tree().create_timer(1.15).timeout
		if world._dialog_open:
			fails += 1
			print("  FAIL round=", round_index, " 转场后对话没关")
		var fade: float = float(world._title_card_bg.color.a)
		if fade > 0.02:
			fails += 1
			print("  FAIL round=", round_index, " 转场黑场没退：", fade)

	print("SOAK DONE  round=50  talks=%d  travels=%d  fails=%d" % [talks, travels, fails])
	get_tree().quit()
