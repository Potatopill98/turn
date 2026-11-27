extends RefCounted

# 小镇日常层（R203）：时段、可重复的“帮忙”、回访反应。
# 不改原场景字典的既有字段，只在 WorldData.all() 末尾补齐，
# 这样既不动已验收的 19 个场景数据，也能让主体玩法换成“过日子”的节奏。

static func apply(d: Dictionary) -> void:
	_playground_day(d)
	_playground_night(d)
	_town_road(d)
	_street_cross(d)

static func _scene(d: Dictionary, id: String) -> Dictionary:
	if not d.has(id):
		return {}
	return d[id] as Dictionary

# ---------------------------------------------------------------- 游乐场 · 白天
static func _playground_day(d: Dictionary) -> void:
	var scene: Dictionary = _scene(d, "playground_day")
	if scene.is_empty():
		return
	scene["title"] = "游乐场"
	scene["phase_title"] = true
	var spots: Array = scene.get("spots", []) as Array
	spots.append({
		"pos": Vector2(330, 485),
		"label": "搭把手 · 扶住秋千",
		"kind": "chore",
		"chore": "zhou_swing",
		"person": "p_zhou",
		"phase": ["afternoon", "dusk"],
		"labels": ["搭把手 · 扶住秋千", "扶稳 · 让他上油", "秋千 · 修好了"],
		"lines": [
			"你挪半步，双手扶住座板。链条停摆，老周拧开油壶，抬了抬下巴示意你再撑一会儿。",
			"你数到第三下，他把最后一滴油点上链轴。链条轻了，座板还在轻轻地晃。",
		],
		"done_line": "秋千不晃了。老周把工具箱挪到一边，腾出座板旁的位置。",
		"done_toast": "帮过忙 · 周德海",
		"done_phase": 1,
		"cancel_distance": 200.0,
		"cancel_line": "你松了手，秋千又晃起来。老周没说什么，把油壶放回工具箱。",
	})
	spots.append({
		"pos": Vector2(640, 525),
		"label": "长椅 · 在这里坐到天黑",
		"kind": "wait",
		"phase": ["afternoon", "dusk"],
		"phase_to": 2,
		"to": "playground_night",
		"spawn": "night",
		"line": "坐到天黑",
		"toast": "天一点点暗下去。灯先亮，随后才看得见灯下那双鞋。",
		"arrive_line": "天一点点暗下来。长椅凉了，游乐场的灯一盏盏亮。月亮被云遮了一半，我起身往秋千那边走——声音忽然没了。就在我转身要走的时候，我看见了那个黑影。",
	})
	scene["spots"] = spots
	scene["npcs"] = [{
		"name": "周德海",
		"art": "周德海",
		"id": "p_zhou",
		"pos": Vector2(250, 505),
		"pos_helped": Vector2(310, 500),
		"present_act": "A2",
		"present_phase": "night",
		"phase": ["afternoon", "dusk"],
		"line": "搭把手？别让它晃。",
		"line2": "这架秋千我修过三回。每回修完都想，下次总该有人来坐了。",
		"line3": "囡囡以前每晚都坐在这儿。她不说，我知道她在等谁。",
		"line_helped": "链条轻了。你要是有事，先去忙。",
		"line_recent": "你听，轻多了。",
		"lines_without": "搭把手？别让它晃。",
		"lines_with_evidence": "螺丝你都摸到了？这架子我修了三回。",
		"lines_by_phase": {
			"dusk": "天要黑了。我去把灯点上，你要是不急，坐长椅等一会儿。",
		},
		"choices": [
			{"id": "help", "label": "扶一下", "chore": "zhou_swing", "hide_if_flag": "helped_zhou"},
			{"id": "ask", "label": "问这架秋千", "line": "这架秋千我修过三回。每回修完都想，下次总该有人来坐了。"},
			{"id": "leave", "label": "我先走了"},
		],
	}]

# ---------------------------------------------------------------- 游乐场 · 夜里
static func _playground_night(d: Dictionary) -> void:
	var scene: Dictionary = _scene(d, "playground_night")
	if scene.is_empty():
		return
	var zhou: Dictionary = _npc(scene, "p_zhou")
	if zhou.is_empty():
		return
	zhou["pos_helped"] = Vector2(585, 542)
	zhou["present_phase"] = "night"
	zhou["line_helped"] = "链条轻了。你坐一会儿，等灯稳了再走。"
	zhou["line_recent"] = "你听，轻多了。"
	zhou["line_after"] = "灯我修好了。你坐一会儿吧，别误了车。"
	zhou["present_after"] = "「我知道是我。」\n他低下头，重新拧起那颗螺丝。两下，很轻。"
	zhou["choices"] = [
		{"id": "present", "label": "拿出「灯下的旧鞋」", "requires_evidence": "ev_shoes"},
		{"id": "ask", "label": "问那件事", "line": "这架秋千我修过三回。每回修完都想，下次总该有人来坐了。"},
		{"id": "ask2", "label": "问囡囡", "line": "囡囡以前每晚都坐在这儿。她不说，我知道她在等谁。"},
		{"id": "leave", "label": "我先走了"},
	]

# ---------------------------------------------------------------- 老街
static func _town_road(d: Dictionary) -> void:
	var scene: Dictionary = _scene(d, "town_road")
	if scene.is_empty():
		return
	scene["title"] = "小镇"
	scene["phase_title"] = true
	var xiaoman: Dictionary = _npc(scene, "p_xiaoman")
	xiaoman["pos_helped"] = Vector2(600, 600)
	xiaoman["line_helped"] = "谱子我收好了。别的，没什么好说的。"
	xiaoman["line_recent"] = "谢谢。……我爸等会儿来拿。"
	xiaoman["line_after"] = "照片我收着。你要问的，去问我爸。"
	xiaoman["present_after"] = "她伸手接过照片，指尖在背面停了一下。「……谢谢你还留着。」"
	xiaoman["choices"] = [
		{"id": "help", "label": "帮她夹好散谱", "chore": "xiaoman_score", "hide_if_flag": "helped_xiaoman"},
		{"id": "present", "label": "拿出那张旧照片", "requires_evidence": "ev_photo"},
		{"id": "ask", "label": "问谱子的事", "line": "谱子是我爸收的。他一页一页捡回来，又一张张压平。"},
		{"id": "leave", "label": "我先走了"},
	]
	var zhou: Dictionary = _npc(scene, "p_zhou")
	if not zhou.is_empty():
		zhou["present_phase"] = "never"
		zhou["line_helped"] = "秋千那边你搭过手了。今天就这样吧。"
	var spots: Array = scene.get("spots", []) as Array
	spots.append({
		"pos": Vector2(505, 625),
		"label": "散开的谱子 · 帮她夹好",
		"kind": "chore",
		"chore": "xiaoman_score",
		"person": "p_xiaoman",
		"phase": ["afternoon", "dusk"],
		"labels": ["散开的谱子 · 帮她夹好", "夹好的谱子"],
		"lines": [
			"你蹲下去，把散开的谱页按页码顺序理齐。小满伸手压住最上面一张，怕风再吹开。",
		],
		"done_line": "谱子叠成了一摞。小满把它抱在怀里，往门边挪了半步。",
		"done_toast": "帮过忙 · 陈小满",
		"done_phase": 1,
		"hide_if_flag": "helped_xiaoman",
		"cancel_distance": 0.0,
	})
	spots.append({
		"pos": Vector2(505, 625),
		"label": "夹好的谱子 · 少了一页",
		"kind": "talk",
		"arg": "谱子叠得很齐。最上面那一页被抽走了，留下一个方方正正的空位。",
		"show_if_flag": "helped_xiaoman",
		"phase": ["dusk", "night", "leave"],
	})
	scene["spots"] = spots
	# 去游乐场按当前时段选白天/夜里，避免“白天扶完秋千，晚上还得再进白天场景”。
	for spot in scene.get("spots", []) as Array:
		var s: Dictionary = spot as Dictionary
		if str(s.get("kind", "")) == "travel" and str(s.get("arg", "")) == "playground_day":
			s["to_by_phase"] = {"afternoon": "playground_day", "dusk": "playground_day", "night": "playground_night", "leave": "playground_night", "default": "playground_day"}
	for exit in scene.get("exits", []) as Array:
		var e: Dictionary = exit as Dictionary
		if str(e.get("to", "")) == "playground_day":
			e["to_by_phase"] = {"afternoon": "playground_day", "dusk": "playground_day", "night": "playground_night", "leave": "playground_night", "default": "playground_day"}

# ---------------------------------------------------------------- 搬家路口
static func _street_cross(d: Dictionary) -> void:
	var scene: Dictionary = _scene(d, "street_cross")
	if scene.is_empty():
		return
	scene["phase_title"] = true
	var tang: Dictionary = _npc(scene, "p_tang")
	tang["line_helped"] = "箱子都上车了。……谢谢。"
	tang["line_recent"] = "最后一箱也上去了。"
	tang["line_after"] = "清单我收着。该留的，留下。"
	tang["present_after"] = "她翻了一下手机，没说话。老吴对着不认识的人点了点头。车门关上，街上的声音才回来。"
	tang["hide_if_flag"] = "presented_p_tang"
	tang["choices"] = [
		{"id": "help", "label": "帮她把最后一箱挪上车", "chore": "tang_box", "hide_if_flag": "helped_tang"},
		{"id": "present", "label": "拿出搬家清单", "requires_evidence": "ev_list"},
		{"id": "ask", "label": "问搬走以后", "line": "有些东西，带走也放不下。"},
		{"id": "leave", "label": "我先走了"},
	]
	var wu: Dictionary = _npc(scene, "p_wu")
	if not wu.is_empty():
		wu["pos_helped"] = Vector2(640, 430)
		wu["line_helped"] = "车靠边了。你们说话，我把机器看着。"
	var spots: Array = scene.get("spots", []) as Array
	spots.append({
		"pos": Vector2(820, 515),
		"label": "最后一箱 · 帮唐棠挪上车",
		"kind": "chore",
		"chore": "tang_box",
		"person": "p_tang",
		"labels": ["最后一箱 · 帮唐棠挪上车", "箱子都上车了"],
		"lines": [
			"你抬住箱底，唐棠扶住箱角，两个人一起把它送进后备厢。箱盖合上，车身往下沉了一点。",
		],
		"done_line": "老吴把电动车停在界线外。唐棠站在车门边，没急着上去。",
		"done_toast": "帮过忙 · 唐棠",
		"done_phase": 3,
		"cancel_distance": 0.0,
	})
	scene["spots"] = spots
	for item in spots:
		var box: Dictionary = item as Dictionary
		if str(box.get("chore", "")) == "tang_box":
			box["hide_if_flag"] = "presented_p_tang"

static func _npc(scene: Dictionary, id: String) -> Dictionary:
	for npc in scene.get("npcs", []) as Array:
		var n: Dictionary = npc as Dictionary
		if str(n.get("id", "")) == id:
			return n
	return {}
