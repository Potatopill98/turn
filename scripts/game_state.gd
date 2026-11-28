extends Node

# 全局状态：相位、旗标、物证、手记、线性主线进度。
# 主线只认 GameState.linear_step()：上一步没完成，下一步不会出现。

const EVIDENCE: Dictionary = {
	"ev_photo": {
		"name": "旧照片",
		"desc": "门槛缝里卡着的旧照片，背面粘着复试通知的残片。",
		"where": "老宅 · 客厅",
	},
	"ev_note": {
		"name": "琴弦字条",
		"desc": "「备用弦在夹层，到那边也能换。」字是父亲的。",
		"where": "老宅 · 客厅",
	},
	"ev_score": {
		"name": "夹好的谱子",
		"desc": "散开的谱页被按页码理齐，最上面一页空了一个方方正正的位置。",
		"where": "老街 · 西段",
	},
	"ev_screw": {
		"name": "拧平的螺丝",
		"desc": "被反复拧了三年，纹路已经磨平的一颗螺丝。",
		"where": "游乐场",
	},
	"ev_shoes": {
		"name": "灯下的旧鞋",
		"desc": "一双很小的红鞋，鞋底的纹路被刷得发白。",
		"where": "游乐场 · 入夜",
	},
	"ev_mirror": {
		"name": "裂镜",
		"desc": "周德海让你收着的裂镜。不用出示，只是留个念想。",
		"where": "周德海给的",
	},
	"ev_list": {
		"name": "搬家清单",
		"desc": "最后一行写着「磁带机——带走」，又被划掉，改成「留下」。",
		"where": "搬家路口",
	},
	"ev_tape": {
		"name": "给阿棠的旧磁带",
		"desc": "盒脊上贴着白胶布：给阿棠，明天九点，老地方。",
		"where": "唐棠给的",
	},
}

# 一条严格线性的主线。0–6 是七步，7 表示已经进入结局。
const STEPS: Dictionary = {
	0: {
		"title": "第一幕 · 归乡",
		"objective": "沿主路往右，回老宅客厅看看。",
		"detail": "车站 → 镇口 → 老街西段 → 老宅门前 → 客厅",
		"target_scene": "house_hall",
		"target_x": 200.0,
		"target_label": "老宅客厅",
	},
	1: {
		"title": "第一幕 · 两件旧物",
		"objective": "客厅里有两件旧东西：旧照片和琴弦字条。两件都要拿。",
		"detail": "先拿照片，再拿字条；少一件，主线不会往下走。",
		"target_scene": "house_hall",
		"target_x": 700.0,
		"target_label": "客厅旧物",
	},
	2: {
		"title": "第二幕 · 散开的谱子",
		"objective": "去老街西段找陈小满：先帮她夹好散谱，再把旧照片递给她。",
		"detail": "顺序不能反：先帮完忙，才能递照片。",
		"target_scene": "street_west",
		"target_x": 1560.0,
		"target_label": "陈小满",
	},
	3: {
		"title": "第三幕 · 秋千与旧鞋",
		"objective": "去游乐场找周德海：扶住秋千，坐到天黑，捡起灯下旧鞋，再把鞋递给他。",
		"detail": "① 扶秋千 → ② 长椅等到天黑 → ③ 捡鞋 → ④ 把鞋给周德海。",
		"target_scene": "playground",
		"target_x": 620.0,
		"target_label": "周德海",
	},
	4: {
		"title": "第四幕 · 最后一箱",
		"objective": "去搬家路口找唐棠：帮她搬最后一箱，拿起搬家清单，再把清单递给她。",
		"detail": "① 搬箱 → ② 拿清单 → ③ 把清单给唐棠。",
		"target_scene": "crossing",
		"target_x": 1660.0,
		"target_label": "唐棠",
	},
	5: {
		"title": "第五幕 · 磁带",
		"objective": "回老宅地下室，把磁带放进琴箱，走进梦里；一直往右，走到车站的钟下醒来。",
		"detail": "回客厅 → 下地下室 → 琴箱 → 梦境右端。",
		"target_scene": "basement",
		"target_x": 1100.0,
		"target_label": "地下室琴箱",
	},
	6: {
		"title": "终幕 · 镇口灯火",
		"objective": "去镇口灯火，走到灯下，决定要不要拨动表针。",
		"detail": "这是最后一步。灯下站定后，做出选择。",
		"target_scene": "town_final",
		"target_x": 1700.0,
		"target_label": "镇口灯火",
	},
}

var phase: int = 0
var current_scene: String = "station"
var current_x: float = 160.0
var flags: Dictionary = {}
var evidence: Array[String] = []
var evidence_scene: Dictionary = {}
var seen_scene: Dictionary = {}
var current_objective: String = ""
var ending_seen: bool = false


func reset() -> void:
	phase = 0
	current_scene = "station"
	current_x = 160.0
	flags.clear()
	evidence.clear()
	evidence_scene.clear()
	seen_scene.clear()
	ending_seen = false
	current_objective = ""
	refresh_objective()


func phase_name() -> String:
	if phase == 0:
		return "午后"
	if phase == 1:
		return "傍晚"
	if phase == 2:
		return "入夜"
	return "临走"


func phase_time() -> String:
	if phase == 0:
		return "15:00"
	if phase == 1:
		return "18:00"
	if phase == 2:
		return "21:00"
	return "06:00"


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func set_flag(flag: String) -> void:
	flags[flag] = true


func has_evidence(id: String) -> bool:
	return evidence.has(id)


func add_evidence(id: String) -> bool:
	if evidence.has(id):
		return false
	if not EVIDENCE.has(id):
		return false
	evidence.append(id)
	evidence_scene[id] = current_scene
	refresh_objective()
	return true


func evidence_name(id: String) -> String:
	var data: Dictionary = EVIDENCE.get(id, {}) as Dictionary
	return str(data.get("name", id))


func evidence_desc(id: String) -> String:
	var data: Dictionary = EVIDENCE.get(id, {}) as Dictionary
	return str(data.get("desc", ""))


func evidence_where(id: String) -> String:
	var data: Dictionary = EVIDENCE.get(id, {}) as Dictionary
	return str(data.get("where", ""))


func scene_visited(id: String) -> bool:
	return bool(seen_scene.get(id, false))


func mark_scene(id: String) -> void:
	seen_scene[id] = true


# ---------- 线性主线 ----------

func linear_step() -> int:
	if ending_seen:
		return 7
	if not has_flag("visited_hall"):
		return 0
	if not (has_evidence("ev_photo") and has_evidence("ev_note")):
		return 1
	if not has_flag("presented_xiaoman"):
		return 2
	if not has_flag("presented_zhou"):
		return 3
	if not has_flag("presented_tang"):
		return 4
	if not has_flag("dream_seen"):
		return 5
	return 6


func step_data(index: int = -1) -> Dictionary:
	var target: int = linear_step() if index < 0 else index
	return STEPS.get(target, {}) as Dictionary


func step_title(index: int = -1) -> String:
	return str(step_data(index).get("title", "终幕"))


func step_objective(index: int = -1) -> String:
	var step: int = linear_step() if index < 0 else index
	if step == 5 and current_scene == "dream":
		return "沿着走廊一直往右。走到车站的钟下，梦就会醒。"
	if step == 2 and has_flag("helped_xiaoman"):
		return "散谱已经夹好。现在把旧照片拿给陈小满。"
	if step == 3:
		if not has_flag("helped_zhou"):
			return "去游乐场找周德海，先和他说一句。"
		if phase < 2:
			return "秋千修好了。去长椅坐一会儿，等到天黑。"
		if not has_evidence("ev_shoes"):
			return "灯下有一双旧鞋，走过去按 E 捡起来。"
		return "把旧鞋拿给周德海。"
	if step == 4:
		if not has_flag("helped_tang"):
			return "去搬家路口找唐棠，先和她说话。"
		if not has_evidence("ev_list"):
			return "箱子搬完了。拿起箱子边的搬家清单。"
		return "把搬家清单拿给唐棠。"
	return str(step_data(step).get("objective", ""))


func step_detail(index: int = -1) -> String:
	var step: int = linear_step() if index < 0 else index
	if step == 1:
		var count: int = 0
		if has_evidence("ev_photo"):
			count += 1
		if has_evidence("ev_note"):
			count += 1
		if count < 2:
			return "旧物 " + str(count) + " / 2 · 还差 " + ("旧照片" if not has_evidence("ev_photo") else "琴弦字条")
	if step == 2:
		if not has_flag("helped_xiaoman"):
			return "先找陈小满说一句；她同意后，再去散谱边按 E；最后回来递旧照片。"
		return "散谱已经夹好。现在把旧照片拿给陈小满。"
	if step == 3:
		if not has_flag("helped_zhou"):
			return "先和周德海说话；再去秋千边按 E 扶住座板；然后去长椅。"
		if phase < 2:
			return "秋千修好了。去长椅按 E 坐到天黑，灯下才会出现旧鞋。"
		if not has_evidence("ev_shoes"):
			return "灯下有一双旧鞋。走过去按 E 捡起来。"
		return "把旧鞋拿给周德海。"
	if step == 4:
		if not has_flag("helped_tang"):
			return "先和唐棠说话；再走到最后一箱边按 E 帮她搬上车。"
		if not has_evidence("ev_list"):
			return "箱子搬完了。箱子边多了一张搬家清单，按 E 拿起来。"
		return "把搬家清单拿给唐棠。"
	if step == 5:
		if current_scene == "dream":
			return "梦里的路只有一条：一直往右，走到车站的钟下。"
		return "回老宅地下室，走到琴箱前按 E。"
	return str(step_data(index).get("detail", ""))


func step_index_text() -> String:
	var step: int = linear_step()
	if step >= 7:
		return "主线完成"
	return "主线 " + str(step + 1) + " / 7"


func quest_target() -> Dictionary:
	var step: int = linear_step()
	if step == 0:
		return _target("house_hall", 200.0, "scene", "", "老宅客厅")
	if step == 1:
		if not has_evidence("ev_photo"):
			return _target("house_hall", 700.0, "prop", "hall_photo", "旧照片")
		if not has_evidence("ev_note"):
			return _target("house_hall", 1180.0, "prop", "hall_note", "琴弦字条")
	if step == 2:
		return _target("street_west", 1560.0, "actor", "p_xiaoman", "陈小满")
	if step == 3:
		if not has_flag("helped_zhou"):
			return _target("playground", 620.0, "actor", "p_zhou", "周德海")
		if phase < 2:
			return _target("playground", 900.0, "prop", "play_bench", "长椅")
		if not has_evidence("ev_shoes"):
			return _target("playground", 560.0, "prop", "play_shoes", "灯下旧鞋")
		return _target("playground", 640.0, "actor", "p_zhou", "周德海")
	if step == 4:
		if not has_flag("helped_tang"):
			return _target("crossing", 1660.0, "actor", "p_tang", "唐棠")
		if not has_evidence("ev_list"):
			return _target("crossing", 1510.0, "prop", "cross_list", "搬家清单")
		return _target("crossing", 1660.0, "actor", "p_tang", "唐棠")
	if step == 5:
		if current_scene == "dream":
			return _target("dream", 3380.0, "exit", "", "车站的钟")
		return _target("basement", 1100.0, "prop", "base_chest", "地下室琴箱")
	return _target("town_final", 1700.0, "prop", "final_ending", "镇口灯火")


func _target(scene: String, x: float, kind: String, id: String, label: String) -> Dictionary:
	return {
		"scene": scene,
		"x": x,
		"kind": kind,
		"id": id,
		"label": label,
	}


func refresh_objective() -> void:
	current_objective = step_objective()


func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"scene": current_scene,
		"x": current_x,
		"step": linear_step(),
		"flags": flags.duplicate(true),
		"evidence": evidence.duplicate(),
		"evidence_scene": evidence_scene.duplicate(true),
		"seen": seen_scene.duplicate(true),
		"ending": ending_seen,
	}
