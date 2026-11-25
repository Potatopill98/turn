extends Node

# R112 转场节点泄漏回归：连续 N 次重入四类转场（不等上一轮播完即切下一场景），
# 结束后让所有 tween 自然走完，统计 fx 层 Control 数回到基线 ±5 以内。
# 旧实现：全局单槽位 + 旧回调按槽位释放 → 误删新层、旧层连同子节点泄漏。

const AnimFx = preload("res://world/anim_fx.gd")

var fx: CanvasLayer = null
var failures: Array = []
var checks: int = 0

const ROUNDS: int = 200

func _ready() -> void:
	TurnState.reset()
	var save_path: String = "user://turn_world.cfg"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	fx = AnimFx.new()
	add_child(fx)
	await get_tree().process_frame

	var before: int = fx.fx_control_count()

	# 加压重入：每轮四类转场连开，不等 tween 完成，模拟转场 0.5–0.9s 内被打断。
	for i in ROUNDS:
		fx.play_door_open(Callable())
		fx.play_dream_in(Callable(), Callable())
		fx.play_location_wipe(Callable(), Callable())
		fx.play_wake_out(Callable(), Callable())

	# 开门层按既有流程走 reveal 拆层；其余三类等 tween 自然完成。
	# dream 并行段 0.90s + 顺序尾段约 0.85s，等待取足 2.5s 余量。
	fx.door_reveal(Callable())
	await get_tree().create_timer(2.5).timeout
	await get_tree().process_frame

	var after: int = fx.fx_control_count()
	var delta: int = after - before

	if absi(delta) <= 5:
		checks += 1
		print("  FXLEAK 节点数回到基线：before=%d after=%d delta=%d OK" % [before, after, delta])
	else:
		failures.append("fx 层节点泄漏：before=%d after=%d delta=%d（阈值 ±5）" % [before, after, delta])
		print("  FAIL  fx 层节点泄漏：before=%d after=%d delta=%d" % [before, after, delta])

	# 直接清点 fx 直接子节点：完成后不应残留任何转场根。
	var leftover: int = fx.get_child_count()
	for c in fx.get_children():
		print("  LEFTOVER child=", c.name, " type=", c.get_class(), " children=", c.get_child_count())
	if leftover == 0:
		checks += 1
		print("  FXLEAK 残留转场根节点=0 OK")
	else:
		failures.append("fx 层残留 %d 个未释放转场根节点" % leftover)
		print("  FAIL  fx 层残留 %d 个转场根节点" % leftover)

	print("FXLEAK DONE  N=%d  before=%d  after=%d  delta=%d  leftover=%d  fails=%d" % [
		ROUNDS, before, after, delta, leftover, failures.size()])
	get_tree().quit(1 if failures.size() > 0 else 0)
