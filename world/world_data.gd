extends RefCounted

# 探索模式的世界数据：19 个场景、可行走区、碰撞、热点、出口、NPC。
# 全部用字符串路径 + 运行时 load，避免"图还没出"时 preload 直接编译失败。

const ART: String = "res://art/"

static func all() -> Dictionary:
	var d: Dictionary = {}

	# ---------------------------------------------------------------- 狼城
	d["langcheng_room"] = {
		"title": "狼城 · 七平米的出租屋",
		"subtitle": "序章",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/狼城_七平米出租屋_夜.png",
		"sky": Color("#141a22"),
		"ground": Color("#2a2e35"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(150, 400, 700, 160)],
		"blocks": [],
		"spawn": Vector2(420, 520),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(360, 470), "label": "床", "kind": "talk", "arg": "床板硬得像桌面。我把外套垫在下面，躺下去，天花板就在眼前——七平米，连翻身都得先想好方向。"},
			{"pos": Vector2(700, 430), "label": "窗外", "kind": "talk", "arg": "窗外是另一栋楼的墙。对面那扇窗也亮着，有人在里面走来走去，看不见脸。"},
			{"pos": Vector2(620, 480), "label": "桌上的合同", "kind": "item", "arg": "e_letter", "gives_evidence": "ev_letter", "arg2": "合同压在一只凉掉的饭盒底下。转正两个字，是这一整年最像样的东西。残角上还记着一个地址。"},
		],
		"exits": [
			{"pos": Vector2(560, 440), "to": "langcheng_office", "label": "出门 · 去公司", "spawn": "door", "lock": {"evidence": ["ev_letter"], "hint": "先在桌上把那份合同残角收进手记，再出门。"}},
			{"pos": Vector2(545, 545), "to": "town_gate", "label": "收行李 · 回镇上", "spawn": "bus"},
		],
	}

	d["langcheng_office"] = {
		"title": "狼城 · 凌晨两点的工位",
		"subtitle": "序章",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/狼城_凌晨两点的工位.png",
		"sky": Color("#10151c"),
		"ground": Color("#272b31"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(150, 360, 660, 170)],
		"blocks": [],
		"spawn": Vector2(480, 500),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(420, 400), "label": "屏幕", "kind": "talk", "arg": "屏幕上是我改了十一版的方案。保存，关掉，再打开——其实一个字也没动。"},
			{"pos": Vector2(660, 420), "label": "同事的椅子", "kind": "talk", "arg": "外套还搭在椅背上。人走了，杯子里的水还剩一半，杯壁已经不冒热气了。"},
			{"pos": Vector2(560, 450), "label": "抽屉里的草稿", "kind": "item", "arg": "e_draft", "gives_evidence": "ev_draft", "arg2": "抽屉夹层压着一版草稿，页边记着镇上的老地址，和合同残角上的是同一个。"},
			{"pos": Vector2(610, 380), "label": "把合同和草稿并排看", "kind": "combo", "combo": {"a": "ev_letter", "b": "ev_draft", "clue": "cl_leave"}, "arg": "合同残角上的地址，和草稿页边记的是同一个地方？"},
		],
		"exits": [
			{"pos": Vector2(480, 520), "to": "langcheng_factory", "label": "下楼 · 去厂里", "spawn": "door"},
			{"pos": Vector2(300, 500), "to": "langcheng_room", "label": "沿楼梯回出租屋", "spawn": "door", "open_edge": true, "open_reason": "从工位返回已进过的出租屋，属于返程边，不受新条件门控"},
		],
	}

	d["langcheng_factory"] = {
		"title": "狼城 · 罐头厂（尾声）",
		"subtitle": "尾声",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/狼城_罐头厂_流水线.png",
		"sky": Color("#181c1e"),
		"ground": Color("#2c3033"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(620, 380, 290, 180)],
		"blocks": [],
		"spawn": Vector2(760, 530),
		"spawns": {"door": Vector2(760, 530)},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(620, 480), "label": "流水线", "kind": "talk", "arg": "一罐接一罐，从眼前过去，望不到头。每一罐都一模一样，连标签贴歪的角度都一样。"},
			{"pos": Vector2(700, 380), "label": "挂着的工装", "kind": "talk", "arg": "蓝工装挂在钩上，袖口磨白了。名字牌是我自己贴的，写歪了，一直没换。"},
			{"pos": Vector2(880, 520), "label": "水洼里的倒影", "kind": "talk", "arg": "灯在水里晃。人走过去，影子就散了。"},
			{"pos": Vector2(700, 460), "label": "工装名牌", "kind": "examine", "lock": {"clues": ["cl_leave"], "hint": "先在出租屋桌上取合同残角、工位抽屉取草稿，到手记里对照出回镇的那条路。"}, "arg": "名牌背面用铅笔补过一行：回镇上老宅看看。", "arg2": "和草稿上的地址对上了——从一开始这条路就指着家。"},
		],
		"exits": [
			{"pos": Vector2(860, 545), "to": "town_final", "label": "请假 · 回镇上", "spawn": "bus", "lock": {"clues": ["cl_lamp"], "hint": "想通路灯那件事之前，先别急着去终章灯火。"}},
			{"pos": Vector2(640, 545), "to": "langcheng_office", "label": "沿楼梯回工位", "spawn": "door", "open_edge": true, "open_reason": "从厂房返回已进过的工位，属于返程边，不受新条件门控"},
		],
	}

	# ---------------------------------------------------------------- 镇子
	d["town_gate"] = {
		"title": "镇口",
		"subtitle": "归乡",
		"bg": ART + "00_场景/02_镇口可玩空景.png",
		"sky": Color("#b7c9cf"),
		"ground": Color("#8f8a7c"),
		"player_height": 76.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(70, 300, 820, 240)],
		"blocks": [],
		"spawn": Vector2(480, 470),
		"spawns": {"bus": Vector2(480, 470), "gate": Vector2(480, 470)},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(255, 325), "label": "副食店的招牌", "kind": "item", "arg": "e_sign"},
			{"pos": Vector2(600, 356), "label": "脚下的路", "kind": "talk", "arg": "柏油在太阳底下发软。走了两步，鞋底粘起一点黑。跟十年前一模一样。"},
			{"pos": Vector2(360, 330), "label": "站牌上的旧地址", "kind": "examine", "lock": {"evidence": ["ev_letter"], "hint": "回出租屋桌上，先把那份合同残角收进手记。"}, "arg": "站牌背面的旧地名，和合同残角上记的对得上。", "arg2": "地址没错。这条街，就是回家的那条街。"},
		],
		"exits": [
			{"pos": Vector2(480, 300), "to": "town_road", "label": "往里走 · 老街", "spawn": "gate"},
		],
	}

	d["town_road"] = {
		"title": "小镇",
		"subtitle": "整条镇子 · 可自由走",
		"player_height": 76.0,
		"bg": ART + "00_场景/14_小镇总图_等距.png",
		"sky": Color("#d9d2bd"),
		"ground": Color("#9a9482"),
		"bounds": Rect2(0, 0, 1536, 1024),
		"walk": [Rect2(80, 130, 1360, 630)],
		"blocks": [
			Rect2(395, 190, 210, 165),
			Rect2(630, 100, 230, 205),
			Rect2(1085, 295, 170, 130),
			Rect2(895, 295, 160, 160),
			Rect2(765, 445, 140, 130),
			Rect2(370, 640, 150, 120),
			Rect2(875, 555, 210, 130),
			Rect2(815, 780, 150, 120),
		],
		"spawn": Vector2(700, 700),
		"spawns": {
			"gate": Vector2(700, 730),
			"house": Vector2(360, 470),
			"play": Vector2(880, 470),
			"cross": Vector2(760, 690),
		},
		"props": [],
		"npcs": [
			{"name": "街坊", "pos": Vector2(700, 630), "id": "", "needs_evidence": "ev_letter", "line": "回来啦？你妈天天念叨。老街这几个月热闹，路灯修了一半。", "line2": "你妈今早去镇口了。她说你要是回来，先去老宅看看，别急着找她。", "lines_without": "回来啦？你妈天天念叨。老街这几个月热闹，路灯修了一半。", "lines_with_evidence": "合同上那个地址我认得。你妈走之前也提过一回——先去老宅看看，别急着找她。"},
			{"name": "陈小满", "pos": Vector2(560, 600), "id": "p_xiaoman", "present_act": "A1", "line": "你怎么还没走？", "line2": "谱子我收好了。别的，没什么好说的。"},
			{"name": "周德海", "pos": Vector2(340, 690), "id": "p_zhou", "needs_evidence": "ev_screw", "line": "灯又灭了两盏。我这把老骨头，爬不动梯子喽。", "line2": "你小时候天天在这条街上跑。那时候路灯坏一盏，整条街都黑，没人修。", "lines_without": "灯又灭了两盏。我这把老骨头，爬不动梯子喽。", "lines_with_evidence": "螺丝你都摸到了？这架子我修了三回。真正没人带走的，是灯下那双鞋。"},
		],
		"spots": [
			{"pos": Vector2(360, 440), "label": "老宅的门", "kind": "travel", "arg": "old_house_yard"},
			{"pos": Vector2(258, 628), "label": "副食店", "kind": "talk", "arg": "柜台后面空着。货架上的橘子汽水摆得很整齐，价签是手写的。", "arg2": "柜台后面的人抬头看了我一眼，又低下去。像在等我自己先开口。"},
			{"pos": Vector2(880, 470), "label": "游乐场", "kind": "travel", "arg": "playground_day"},
			{"pos": Vector2(660, 560), "label": "老街路灯", "kind": "item", "arg": "e_lamp"},
			{"pos": Vector2(920, 690), "label": "池塘", "kind": "talk", "arg": "池塘边有一排石桥栏杆。水面很静，映着半边天。"},
		],
		"exits": [
			{"pos": Vector2(660, 745), "to": "town_gate", "label": "回镇口", "spawn": "gate"},
			{"pos": Vector2(360, 470), "to": "old_house_yard", "label": "进老宅院子", "spawn": "door"},
			{"pos": Vector2(800, 655), "to": "street_cross", "label": "往路口", "spawn": "road"},
			{"pos": Vector2(860, 455), "to": "playground_day", "label": "去游乐场", "spawn": "road"},
			{"pos": Vector2(560, 725), "to": "town_final", "label": "镇口灯火", "spawn": "road", "lock": {"clues": ["cl_lamp"], "hint": "想通路灯那件事之前，先别急着去终章灯火。"}},
		],
	}
	d["old_house_yard"] = {
		"title": "老宅 · 门前",
		"subtitle": "第一幕",
		"bg": ART + "00_场景/08_归乡老宅门前.png",
		"sky": Color("#c9cfc6"),
		"ground": Color("#8a8272"),
		"player_height": 90.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(90, 330, 780, 210)],
		"blocks": [],
		"spawn": Vector2(480, 470),
		"spawns": {"door": Vector2(480, 470)},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(760, 400), "label": "门边的鞋", "kind": "talk", "arg": "门口摆着两双鞋。一双大的，一双小的，都摆得很正——像随时有人会回来穿。"},
			{"pos": Vector2(420, 430), "label": "门槛缝", "kind": "item", "arg": "e_photo", "gives_evidence": "ev_photo", "arg2": "门槛缝里卡着一张旧照片，边角磨毛了。背面粘着一张复试通知的残片。"},
		],
		"exits": [
			{"pos": Vector2(480, 340), "to": "house_hall", "label": "进门", "spawn": "door", "lock": {"evidence": ["ev_photo"], "hint": "门虚掩着，先弯腰看看门槛缝里卡着什么。"}},
			{"pos": Vector2(120, 500), "to": "town_road", "label": "回老街", "spawn": "house"},
		],
	}

	d["house_hall"] = {
		"title": "老宅 · 客厅与走廊",
		"subtitle": "第一幕",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/老宅_客厅_可走.png",
		"sky": Color("#b8b09c"),
		"ground": Color("#8e8574"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(140, 300, 720, 230)],
		"blocks": [],
		"spawn": Vector2(480, 470),
		"spawns": {"door": Vector2(480, 470)},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(350, 300), "label": "墙上的老钟", "kind": "item", "arg": "e_clock"},
			{"pos": Vector2(340, 340), "label": "布沙发", "kind": "talk", "arg": "坐垫塌下去一块，是固定坐着的那个人留下的形状。", "arg2": "坐下去，塌的那块正好托住腰。这个家还记得我的形状。"},
			{"pos": Vector2(440, 350), "label": "茶几上的半杯水", "kind": "talk", "arg": "水是凉的，杯壁上没有水汽。妈妈大概出门有一会儿了。", "arg2": "杯子底下压着一张超市小票。日期是今天，买了两样东西：盐，和一束花。"},
			{"pos": Vector2(510, 380), "label": "茶几夹层的便签", "kind": "item", "arg": "e_note", "gives_evidence": "ev_note", "arg2": "便签从茶几夹层露出来：「备用弦在夹层，到那边也能换。」字是父亲的。"},
			{"pos": Vector2(300, 390), "label": "把两样东西并排看", "kind": "combo", "combo": {"a": "ev_note", "b": "ev_photo", "clue": "cl_score"}, "arg": "便签上的备用弦，和旧照片里那把琴是不是同一把？"},
			{"pos": Vector2(750, 330), "label": "上锁的琴箱 · 把手放上去", "kind": "dream", "arg": "dream_classroom"},
		],
		"exits": [
			{"pos": Vector2(860, 480), "to": "old_house_yard", "label": "出门", "spawn": "door"},
			{"pos": Vector2(120, 320), "to": "basement", "label": "下地下室", "spawn": "stairs", "lock": {"clues": ["cl_score"], "hint": "下楼前，先把厅里找到的便签和旧照片并排对上一一对。"}},
		],
	}
	d["basement"] = {
		"title": "老宅 · 地下室",
		"subtitle": "记忆里，你已经站在琴箱旁边",
		"bg": ART + "00_场景/07_地下室琴箱角落.png",
		"sky": Color("#2a2b28"),
		"ground": Color("#4b4a44"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 1023, 691),
		"walk": [Rect2(390, 320, 610, 340)],
		"blocks": [],
		"spawn": Vector2(760, 600),
		"spawns": {"stairs": Vector2(760, 600)},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(780, 470), "label": "落了灰的琴箱", "kind": "item", "arg": "e_shell"},
			{"pos": Vector2(920, 520), "label": "堆着的旧报纸", "kind": "talk", "arg": "报纸的日期停在很多年前。最上面一张，头版是省歌舞团的招生启事。"},
			{"pos": Vector2(860, 460), "label": "琴箱背面的刻字", "kind": "examine", "lock": {"clues": ["cl_score"], "hint": "先在堂屋把茶几便签和门槛旧照片到手记里对照出同一把琴。"}, "arg": "琴箱背面刻着两道弦距，和便签上记的备用弦对得上。", "arg2": "父亲收琴谱那天，也把她要走的路留着了。"},
		],
		"exits": [
			{"pos": Vector2(440, 360), "to": "house_hall", "label": "上楼", "spawn": "door", "open_edge": true, "open_reason": "从地下室返回堂屋，此前已凭旧照片进入过"},
		],
	}

	d["playground_day"] = {
		"title": "游乐场 · 白天",
		"subtitle": "第二幕",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/游乐场_白天_地面.png",
		"sky": Color("#cfd8d4"),
		"ground": Color("#8e9378"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(120, 420, 720, 160)],
		"blocks": [],
		"spawn": Vector2(200, 545),
		"spawns": {"road": Vector2(200, 545)},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(310, 460), "label": "秋千", "kind": "item", "arg": "e_screw", "gives_evidence": "ev_screw"},
			{"pos": Vector2(700, 470), "label": "告示牌", "kind": "talk", "arg": "告示牌上写着：游乐场设施维修中，请勿靠近。落款是三年前。", "arg2": "告示牌背面有人用铅笔写了两个字。被雨泡糊了，只认得出一个「等」。"},
			{"pos": Vector2(820, 500), "label": "纸壳堆", "kind": "talk", "arg": "纸壳被雨泡过又晒干，一层一层压在一起。最上面那只印着凤梨罐头的牌子。"},
		],
		"exits": [
			{"pos": Vector2(120, 560), "to": "town_road", "label": "回老街", "spawn": "play"},
			{"pos": Vector2(760, 560), "to": "playground_night", "label": "等到入夜 · 蓝调夜色", "spawn": "night"},
		],
	}

	d["playground_night"] = {
		"title": "游乐场 · 蓝调夜色",
		"subtitle": "第二幕",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/游乐场_夜_地面.png",
		"sky": Color("#1e2a38"),
		"ground": Color("#2c3542"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(120, 420, 720, 160)],
		"blocks": [],
		"spawn": Vector2(300, 545),
		"spawns": {"day": Vector2(300, 545), "night": Vector2(300, 545)},
		"props": [],
		"npcs": [
			{"name": "周德海", "pos": Vector2(520, 540), "id": "p_zhou", "needs_evidence": "ev_shoes", "line": "这么晚还出来走？灯我修了一半，剩下那半，得有人接着修。", "line2": "这架秋千我修过三回。每回修完都想，下次总该有人来坐了。", "line3": "囡囡以前每晚都在这秋千上坐着。她不说，我知道她在等谁。", "lines_without": "这么晚还出来走？灯我修了一半，剩下那半，得有人接着修。", "lines_with_evidence": "这架秋千我修过三回。每回修完都想，下次总该有人来坐了。", "present": {"evidence": "ev_shoes", "reply": "你把那双旧鞋提过来。他低头擦了擦鞋面的灰，把墙角那面裂了两道缝的破镜子塞给我：「夜里路灯底下，照得见回去的路。」", "grants_evidence": "ev_mirror", "wrong_lines": ["他接过东西翻来覆去看了两眼，又递回给我——像压根没听过这名字。", "他摇了摇头：这玩意儿跟秋千对不上号，你再想想。"]}},
		],
		"spots": [
			{"pos": Vector2(700, 470), "label": "路灯", "kind": "item", "arg": "e_lamp"},
			{"pos": Vector2(340, 505), "label": "秋千的链子", "kind": "talk", "arg": "链子上的锈一层一层。摸上去，指腹会留下橙红的粉。"},
			{"pos": Vector2(350, 520), "label": "松掉的螺丝", "kind": "talk", "arg": "夜里这颗螺丝还在原处，锈痕和白天秋千上那颗一模一样——天黑了，它也没自己走开。"},
			{"pos": Vector2(560, 500), "label": "灯下的旧鞋", "kind": "item", "arg": "e_shoes", "gives_evidence": "ev_shoes", "arg2": "灯最亮的地方摆着一双小女孩的旧鞋，鞋底还是干净的。"},
			{"pos": Vector2(620, 530), "label": "把螺丝和旧鞋并排看", "kind": "combo", "combo": {"a": "ev_screw", "b": "ev_shoes", "clue": "cl_lamp"}, "arg": "拧了三年的螺丝，和这双没穿走的鞋，能对上什么？"},
		],
		"exits": [
			{"pos": Vector2(120, 560), "to": "playground_day", "label": "等到白天", "spawn": "day"},
			{"pos": Vector2(300, 480), "to": "dream_swing", "label": "坐上秋千 · 入梦", "spawn": "", "lock": {"evidence": ["ev_mirror"], "clues": ["cl_lamp"], "hint": "带着夜里那面旧镜，再想明白这架秋千和灯下那双鞋的关系，才坐得上去。"}},
		],
	}

	d["street_cross"] = {
		"title": "搬家路口",
		"subtitle": "第三幕",
		"bg": ART + "00_场景/11_搬家路口.png",
		"sky": Color("#c8c8bc"),
		"ground": Color("#8b8778"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(70, 330, 820, 210)],
		"blocks": [],
		"spawn": Vector2(160, 480),
		"spawns": {"road": Vector2(160, 480)},
		"props": [],
		"npcs": [
			{"name": "张成", "pos": Vector2(150, 490), "id": "p_zhang", "line": "装车我熟，劝人我不劝。", "line2": "见过太多搬一半又搬回去的家。"},
			{"name": "吴长庚", "pos": Vector2(500, 360), "id": "p_wu", "line": "店里就剩这台机器，还没修好。", "line2": "磁带先放那儿吧，别急着寄。"},
			{"name": "唐棠", "pos": Vector2(760, 480), "id": "p_tang", "present_act": "A3", "line": "车已经掉好头，东西都收拾得差不多了。", "line2": "有些东西，带走也放不下。"},
		],
		"spots": [
			{"pos": Vector2(430, 400), "label": "搬家清单", "kind": "item", "arg": "e_list", "gives_evidence": "ev_list", "arg2": "清单最后一项原本写着：把该带走的都带走。后来划掉了，改成：把该留的留下。"},
			{"pos": Vector2(330, 430), "label": "旧磁带 · 听一段", "kind": "dream", "arg": "dream_dirt_road"},
			{"pos": Vector2(250, 470), "label": "磁带机旁的旧磁带", "kind": "item", "arg": "e_tape", "gives_evidence": "ev_tape", "arg2": "标签上写着阿棠。00:18 有一块人声，一直没寄出去。"},
			{"pos": Vector2(620, 430), "label": "手机里的照片", "kind": "item", "arg": "e_phone"},
			{"pos": Vector2(520, 480), "label": "把清单和磁带并排看", "kind": "combo", "combo": {"a": "ev_list", "b": "ev_tape", "clue": "cl_tape"}, "arg": "清单改了三回，磁带上的人话说到一半——这两件能对上什么？打开手记，把两件物证放进槽里对照。"},
			{"pos": Vector2(180, 430), "label": "旧磁带机", "kind": "examine", "lock": {"clues": ["cl_tape"], "hint": "先把搬家清单和旧磁带到手记里对照出那段没寄出去的道别。"}, "arg": "磁带机皮带松了，按下播放键只会沙沙响，人声卡在 00:18 进不来。", "arg2": "清单最后一改了三回，道别却录好了一直没寄——人和东西都停在这句话上。"},
		],
		"exits": [
			{"pos": Vector2(120, 500), "to": "town_road", "label": "回老街", "spawn": "cross"},
			{"pos": Vector2(820, 470), "to": "town_final", "label": "去镇口", "spawn": "road", "lock": {"clues": ["cl_lamp"], "hint": "想通路灯那件事之前，先别急着去终章灯火。"}},
		],
	}

	d["town_final"] = {
		"title": "镇口 · 灯火",
		"subtitle": "终章",
		"bg": ART + "00_场景/12_终章镇口灯火.png",
		"sky": Color("#20242c"),
		"ground": Color("#474a46"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(80, 330, 800, 200)],
		"blocks": [],
		"spawn": Vector2(480, 480),
		"spawns": {"road": Vector2(480, 480), "bus": Vector2(480, 480)},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(300, 430), "label": "三口箱子", "kind": "talk", "arg": "三口箱子摆在地上：一口装衣服，一口装书，一口空着。空的那口，是留给还没决定的东西。", "arg2": "空箱子里积了一层灰。用手指划过去，能划出一条干净的线。"},
			{"pos": Vector2(660, 430), "label": "停在四点十分的钟", "kind": "item", "arg": "e_watch"},
			{"pos": Vector2(480, 430), "label": "空箱子里的灰", "kind": "examine", "lock": {"clues": ["cl_lamp"], "hint": "先想明白路灯拧了三年的螺丝，和灯下那双没穿走的鞋是什么关系。"}, "arg": "空箱子积了一层灰，留出来的位置正好搁一盏灯。", "arg2": "灯是等人回来的。空箱子也是——东西留下来，人就该回来了。"},
			{"pos": Vector2(620, 500), "label": "回到灯火下", "kind": "ending_review", "arg": "按手记里记下的物证与推论，回看这一趟。"},
		],
		"exits": [
			{"pos": Vector2(480, 520), "to": "house_hall", "label": "回家", "spawn": "door", "open_edge": true, "open_reason": "从终章返回堂屋，此前已凭旧照片进入过"},
			{"pos": Vector2(100, 500), "to": "town_road", "label": "再走一遍老街", "spawn": "gate"},
		],
	}

	# ---------------------------------------------------------------- 梦境
	d["dream_classroom"] = {
		"title": "梦 · 教室",
		"subtitle": "第一幕 · 老陈的记忆",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/梦_教室_过道.png",
		"sky": Color("#6b5640"),
		"ground": Color("#8a7154"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(370, 340, 220, 190)],
		"blocks": [],
		"spawn": Vector2(480, 510),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(420, 380), "label": "讲台", "kind": "talk", "arg": "讲台上摊着一本卷了边的课本。粉笔灰落在上面，像一层薄雪。"},
			{"pos": Vector2(560, 430), "label": "起哄的同学", "kind": "talk", "arg": "几个人围着最后一排笑。被围着的那个人低着头，肩膀在抖。"},
			{"pos": Vector2(390, 470), "label": "歪掉的椅子", "kind": "talk", "arg": "椅子被撞得歪过去，桌上是几张揉皱的纸。"},
			{"pos": Vector2(500, 440), "label": "课桌上的旧照片", "kind": "examine", "lock": {"evidence": ["ev_photo"], "hint": "回老宅门前，先弯腰看看门槛缝里卡着什么。"}, "arg": "课桌缝里夹着半张旧照片，和门槛缝里捡到的是同一张。", "arg2": "照片背面的通知残片，是她留下来的那一半。"},
		],
		"exits": [
			{"pos": Vector2(560, 545), "to": "dream_alley", "label": "往前 · 巷子", "spawn": ""},
		],
		"dream": true,
	}
	d["dream_alley"] = {
		"title": "梦 · 巷子",
		"subtitle": "第一幕 · 老陈的记忆",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/梦_巷子_烂菜叶与裂口的手.png",
		"sky": Color("#5f5140"),
		"ground": Color("#7d6a50"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(120, 420, 720, 160)],
		"blocks": [],
		"spawn": Vector2(480, 540),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(760, 470), "label": "墙角", "kind": "talk", "arg": "墙根堆着几片烂菜叶。有人蹲在那里，手撑着墙，指节上有一道口子。", "arg2": "再看一眼：那道口子不深，血已经干了，可他还攥着拳头，像疼的不是手。"},
			{"pos": Vector2(300, 500), "label": "墙上的粉笔线", "kind": "talk", "arg": "墙根划着一排粉笔线，从低到高，最上面一道已经超过了门框。", "arg2": "粉笔头只剩半截，最上面那道线旁边，还画了个歪歪扭扭的小箭头。"},
			{"pos": Vector2(500, 505), "label": "墙边的人影", "kind": "examine", "arg": "那人背对着巷子蹲着，肩膀一下一下地抖，像在压着哭声，又像只是冷风灌进领口。", "arg2": "他脚边落着一张折过的纸，风没吹动它，像被什么按住了。"},
		],
		"exits": [
			{"pos": Vector2(150, 550), "to": "dream_postbox", "label": "往前 · 邮筒", "spawn": ""},
		],
		"dream": true,
		"no_puzzle_reason": "梦境链过渡节点：承担第一幕记忆转场，线索对照集中在相邻的教室与邮筒节点。",
	}

	d["dream_postbox"] = {
		"title": "梦 · 邮筒前",
		"subtitle": "第一幕 · 老陈的记忆",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/梦_邮筒前_折了又展开的通知.png",
		"sky": Color("#6a5a44"),
		"ground": Color("#867357"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(120, 430, 700, 150)],
		"blocks": [],
		"spawn": Vector2(480, 540),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(520, 490), "label": "邮筒", "kind": "talk", "arg": "绿色的邮筒，漆掉了一块。手里的纸被折出十字痕，又展开，又折上。"},
			{"pos": Vector2(760, 520), "label": "地上的纸", "kind": "talk", "arg": "纸角被风掀起一点，又落回去。上面那行字，看了很多遍，还是不敢确认。"},
			{"pos": Vector2(620, 500), "label": "邮筒边的票根", "kind": "item", "arg": "e_ticket", "gives_evidence": "ev_ticket", "arg2": "票根被折过两回，站台名磨花了，日期是她走的那天。"},
		],
		"exits": [
			{"pos": Vector2(150, 555), "to": "dream_box", "label": "往前 · 木箱", "spawn": ""},
		],
		"dream": true,
	}

	d["dream_box"] = {
		"title": "梦 · 木箱",
		"subtitle": "第一幕 · 老陈的记忆",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/梦_木箱_锁上的那一下.png",
		"sky": Color("#6d5840"),
		"ground": Color("#8b6f4f"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(120, 430, 700, 150)],
		"blocks": [],
		"spawn": Vector2(480, 540),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(560, 470), "label": "柜台下的木箱", "kind": "talk", "arg": "箱盖半开，里面是一摞旧报纸。一只手把信封放进去，然后，咔哒一声，锁上了。", "arg2": "再凑近：信封边角露在报纸外面，没被压住，像故意留了个记号。"},
			{"pos": Vector2(300, 500), "label": "木箱锁扣", "kind": "talk", "arg": "铜锁扣磨出了一道亮痕。锁上之后，钥匙被留在了柜台的另一边。", "arg2": "亮痕很深，说明这把锁开开关关过很多回，最后一次才是真的锁死。"},
			{"pos": Vector2(460, 500), "label": "旧报纸", "kind": "examine", "arg": "报纸叠得四四方方，头版的日期被墨迹盖住，只露出一个年份。", "arg2": "那个年份，和邮筒里攥了一路的票根是同一年。"},
		],
		"exits": [
			{"pos": Vector2(150, 555), "to": "", "label": "醒过来", "spawn": "", "wake": true},
		],
		"dream": true,
		"no_puzzle_reason": "梦境链收尾节点：第一幕记忆在此醒回现实，线索对照已在教室 / 邮筒节点完成，此处只承担情绪落点。",
	}

	d["dream_swing"] = {
		"title": "梦 · 秋千",
		"subtitle": "第二幕 · 老周的记忆",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/梦_秋千_囡囡荡得很高.png",
		"sky": Color("#6d5038"),
		"ground": Color("#8f6845"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(120, 430, 720, 150)],
		"blocks": [],
		"spawn": Vector2(480, 540),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(480, 470), "label": "荡到最高点", "kind": "talk", "arg": "小红鞋在黄昏里划出一道弧。两个小辫飞起来，笑声比人还高。"},
			{"pos": Vector2(760, 500), "label": "秋千的链子", "kind": "item", "arg": "e_screw"},
			{"pos": Vector2(620, 480), "label": "秋千绳结", "kind": "examine", "lock": {"evidence": ["ev_shoes"], "hint": "夜里路灯底下，先找到那双鞋底还干净的旧鞋。"}, "arg": "绳结上还系着一截鞋带，和旧鞋上的是同一根。", "arg2": "鞋留在灯下，秋千还在等她荡回来。"},
		],
		"exits": [
			{"pos": Vector2(150, 555), "to": "", "label": "醒过来", "spawn": "", "wake": true},
		],
		"dream": true,
	}

	d["dream_dirt_road"] = {
		"title": "梦 · 土路",
		"subtitle": "第三幕 · 吴叔的记忆",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/梦_土路_蛙声与两个人的影子.png",
		"sky": Color("#7a6440"),
		"ground": Color("#9a7c4c"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(120, 430, 720, 150)],
		"blocks": [],
		"spawn": Vector2(480, 540),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(480, 490), "label": "两个人的影子", "kind": "talk", "arg": "夕阳把两个背书包的影子拉得很长。一个快，一个慢，走着走着就并到一起了。"},
			{"pos": Vector2(760, 500), "label": "水渠", "kind": "talk", "arg": "水渠里有蛙声，一阵一阵。稻田的味道是热的。"},
			{"pos": Vector2(260, 500), "label": "田埂上的鞋印", "kind": "talk", "arg": "一行小鞋印顺着田埂走到站台方向，走到一半就断了。票根上记的，也是这一天。"},
			{"pos": Vector2(620, 490), "label": "把票根和旧鞋并排看", "kind": "combo", "combo": {"a": "ev_ticket", "b": "ev_shoes", "clue": "cl_return"}, "arg": "站台票根，和灯下那双没穿走的旧鞋，能对上什么？"},
		],
		"exits": [
			{"pos": Vector2(150, 555), "to": "dream_station", "label": "往前 · 车站", "spawn": ""},
		],
		"dream": true,
	}

	d["dream_station"] = {
		"title": "梦 · 车站",
		"subtitle": "第三幕 · 吴叔的记忆",
		"bg": ART + "10_v3_待出图/06_全文叙事/02_章节背景/梦_车站_她没有回头.png",
		"sky": Color("#5c5a4e"),
		"ground": Color("#7b7866"),
		"player_height": 84.0,
		"bounds": Rect2(0, 0, 960, 600),
		"walk": [Rect2(120, 430, 720, 150)],
		"blocks": [],
		"spawn": Vector2(480, 540),
		"spawns": {},
		"props": [],
		"npcs": [],
		"spots": [
			{"pos": Vector2(700, 470), "label": "车门", "kind": "talk", "arg": "绿皮车的门开着。提行李的人上了车，一直没有回头。"},
			{"pos": Vector2(320, 500), "label": "站台的裂缝", "kind": "examine", "lock": {"clues": ["cl_return"], "hint": "先把手记里的票根和灯下旧鞋对照出：一个走得急，一个留下来等。"}, "arg": "地上有一道很深的裂缝，被水冲得发亮。广播响了两遍，谁的名字都没念清。", "arg2": "票根上的日期，和站台上没带走的那双鞋是同一年——两个人都没走出这条街。"},
		],
		"exits": [
			{"pos": Vector2(150, 555), "to": "", "label": "醒过来", "spawn": "", "wake": true},
		],
		"dream": true,
		"no_puzzle_reason": "梦境链收尾节点：第三幕记忆在此醒回现实，票根与旧鞋的对照已在土路节点完成，此处只承担道别画面。",
	}

	return d
