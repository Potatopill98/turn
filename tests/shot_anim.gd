extends Node

# B1 演出层走查：四类动画各拍 5 帧（t≈0.00 / 0.15 / 0.40 / 0.75 / 1.00）。
# PNG 落到 E:/gamejam/jam200/shots/，命名 b01_anim_<类别>_t<时间>.png。

const OUT_DIR: String = "E:/gamejam/jam200/shots/"
const FRACTIONS: Array[float] = [0.0, 0.15, 0.40, 0.75, 1.0]

const PICKUP_DURATION: float = 0.55
const DOOR_DURATION: float = 0.62
const DREAM_DURATION: float = 0.90
const WIPE_DURATION: float = 0.50

var world = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	TurnState.reset()
	var packed: PackedScene = load("res://world/world.tscn") as PackedScene
	if packed == null:
		print("FAIL world.tscn 加载失败")
		get_tree().quit(1)
		return
	world = packed.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	if world.chapter != null:
		world.chapter.skip()
	await get_tree().process_frame

	await _shot_pickup()
	await _shot_door()
	await _shot_dream()
	await _shot_wipe()
	print("SHOT_ANIM DONE")
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout

func _save(tag: String, fraction: float) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var name: String = "b01_anim_%s_t%.2f.png" % [tag, fraction]
	var err: int = image.save_png(OUT_DIR + name)
	print("SHOT ", name, " err=", err)

func _run_anim(tag: String, duration: float, start: Callable) -> void:
	world.force_scene("town_gate")
	await get_tree().process_frame
	await get_tree().process_frame
	start.call()
	var prev: float = 0.0
	for f in FRACTIONS:
		var gap: float = f * duration - prev * duration
		await _wait(gap)
		prev = f
		await _save(tag, f)

func _shot_pickup() -> void:
	var start: Callable = func() -> void:
		world.fx.play_pickup(Vector2(300, 300), "合同残角", world._journal_button, Callable())
	await _run_anim("pickup", PICKUP_DURATION, start)

func _shot_door() -> void:
	var start: Callable = func() -> void:
		world.fx.play_door_open(Callable())
	await _run_anim("door", DOOR_DURATION, start)
	# 测试里没有接新场景，主动收掉门扇层，避免黑场/门扇串到下一类动画。
	var reveal_done: Array = [false]
	world.fx.door_reveal(func() -> void: reveal_done[0] = true)
	while not bool(reveal_done[0]):
		await get_tree().process_frame

func _shot_dream() -> void:
	var start: Callable = func() -> void:
		world.fx.play_dream_in(Callable(), Callable())
	await _run_anim("dream", DREAM_DURATION, start)

func _shot_wipe() -> void:
	var start: Callable = func() -> void:
		world.fx.play_location_wipe(Callable(), Callable())
	await _run_anim("wipe", WIPE_DURATION, start)
