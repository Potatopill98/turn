extends RefCounted

# 横版场景表：宽度、地面线、门、可交互物、NPC。
# 坐标全部是横向 x；y 由 floor_y 锁定，不做纵向关卡。

static func all() -> Dictionary:
	var d: Dictionary = {}
	d["station"] = {
		"title": "车站",
		"subtitle": "归乡 · 午后",
		"width": 1600.0,
		"floor_y": 456.0,
		"spawn": 160.0,
		"kind": "exterior",
		"interior": false,
		"note": "中巴车刚走。背包比走的时候轻，心却比走的时候重。",
		"doors": [
			{"x": 1000.0, "to": "town_gate", "spawn": 1670.0, "label": "往镇口"},
		],
		"props": [
			{"id": "station_watch", "x": 211.0, "kind": "watch", "label": "拨动停表", "interact": true, "action": "turn_watch"},
			{"id": "station_ticket", "x": 680.0, "kind": "note", "label": "多出来的车票", "interact": true, "action": "read", "show_if_flag": "station_turned", "text": "去程盖的是今天。回程盖的是昨天。"},
			{"id": "station_sign", "x": 300.0, "kind": "sign", "label": "镇口站牌", "interact": true, "action": "read", "text": "站牌背面有一行旧地名。和合同残角上记的是同一个地方。"},
			{"id": "station_bus", "x": 1080.0, "kind": "bus", "label": "旧中巴", "interact": true, "action": "read", "text": "收音机还开着。车里没人。"},
			{"id": "station_bench", "x": 720.0, "kind": "bench", "label": "候车长椅", "interact": true, "action": "read", "text": "长椅还是当年的长椅。坐下去，木头会响一声。"},
		],
		"npcs": [],
	}

	d["town_gate"] = {
		"title": "镇口",
		"subtitle": "归乡 · 午后",
		"width": 2400.0,
		"floor_y": 456.0,
		"spawn": 120.0,
		"kind": "exterior",
		"interior": false,
		"note": "牌子上的红漆是新描的。往右，老街。",
		"doors": [
			{"x": 80.0, "to": "station", "spawn": 920.0, "label": "回车站"},
			{"x": 2320.0, "to": "street_west", "spawn": 120.0, "label": "进老街"},
		],
		"props": [
			{"id": "gate_notice", "x": 1140.0, "kind": "sign", "label": "镇口告示", "interact": true, "action": "read", "text": "告示上写着老街路灯改造，落款是三年前。纸边被雨水泡过，字还认得。"},
			{"id": "gate_car", "x": 350.0, "kind": "car", "label": "旧车", "interact": true, "action": "read", "text": "车停得很靠边，像随时会开走，又像很久没动过。"},
			{"id": "gate_bench", "x": 1700.0, "kind": "bench", "label": "路边长椅", "interact": true, "action": "read", "text": "坐在这能看见整条街。小时候放学，我总在这儿等我妈。"},
		],
		"npcs": [],
	}

	d["street_west"] = {
		"title": "老街 · 西段",
		"subtitle": "老街",
		"width": 2880.0,
		"floor_y": 456.0,
		"spawn": 120.0,
		"kind": "exterior",
		"interior": false,
		"note": "老宅、副食店、散开的谱子。往右还有一段。",
		"doors": [
			{"x": 80.0, "to": "town_gate", "spawn": 2280.0, "label": "回镇口"},
			{"x": 2800.0, "to": "street_east", "spawn": 120.0, "label": "往东段"},
			{"x": 750.0, "to": "house_yard", "spawn": 160.0, "label": "进老宅"},
			{"x": 1840.0, "to": "shop", "spawn": 160.0, "label": "进副食店"},
		],
		"props": [
			{"id": "west_mailbox", "x": 820.0, "kind": "mailbox", "label": "老宅信箱", "interact": true, "action": "read", "text": "信箱里塞着几张广告纸。最底下压着一封没有寄出的信，收信人写的是我。"},
			{"id": "west_score", "x": 1460.0, "kind": "score", "label": "散开的谱子", "interact": true, "action": "chore", "chore": "xiaoman_score", "show_if_flag_not": "helped_xiaoman"},
			{"id": "west_score_done", "x": 1460.0, "kind": "score", "label": "夹好的谱子", "interact": false, "show_if_flag": "helped_xiaoman"},
			{"id": "west_lamp", "x": 2260.0, "kind": "lamp", "label": "老街路灯", "interact": true, "action": "read", "text": "灯罩上积着灰。灯还亮，光有点发黄。"},
			{"id": "west_puddle", "x": 2360.0, "kind": "puddle", "label": "水洼", "interact": true, "action": "read", "text": "水洼里有半片天。人走过去，影子就散了。"},
		],
		"npcs": [
			{
				"id": "p_xiaoman",
				"name": "陈小满",
				"style": "xiaoman",
				"role": "旧识",
				"positions": {"0": 1560.0, "1": 1820.0, "2": 2140.0, "3": 520.0},
				"greet": "你怎么回来了？",
				"lines": [
					"谱子是我爸收的。他一页一页捡回来，又一张张压平。",
					"我不是非要走。我只是不想一辈子站在这条街上。",
					"他撕了我的报名表。撕得很整齐，像早就想好了。",
				],
				"line_helped": "谱子我收好了。别的，没什么好说的。",
				"line_after": "照片我收着。你要问的，去问我爸。",
				"line_present_ok": "她伸手接过照片，指尖在背面停了一下。「原来他那时候，也把琴背在身上。」",
				"line_present_bad": "她看了一眼，没有接。「这个，现在不该给我。」",
				"chore": "xiaoman_score",
				"chore_label": "帮她夹好散谱",
				"chore_done": "谱子叠成了一摞。小满把它抱在怀里，往门边挪了半步。",
				"accept_evidence": "ev_photo",
				"reward": "",
				"done_flag": "helped_xiaoman",
				"present_flag": "presented_xiaoman",
				"hide_if_presented": false,
			},
		],
	}

	d["street_east"] = {
		"title": "老街 · 东段",
		"subtitle": "老街",
		"width": 2880.0,
		"floor_y": 456.0,
		"spawn": 120.0,
		"kind": "exterior",
		"interior": false,
		"note": "修车摊、自行车、去游乐场的路口。",
		"doors": [
			{"x": 80.0, "to": "street_west", "spawn": 2700.0, "label": "回西段"},
			{"x": 2800.0, "to": "playground", "spawn": 120.0, "label": "去游乐场"},
		],
		"props": [
			{"id": "east_bike", "x": 1200.0, "kind": "bicycle", "label": "旧自行车", "interact": true, "action": "read", "text": "车链子掉了。靠墙停着，像在等一个会修的人。"},
			{"id": "east_poster", "x": 1900.0, "kind": "poster", "label": "海报墙", "interact": true, "action": "read", "text": "几张旧演出海报，边角卷了。最上面一张写着《出城记》。"},
			{"id": "east_arrow", "x": 2320.0, "kind": "sign", "label": "去游乐场", "interact": true, "action": "read", "text": "箭头指向东边。铁皮被雨淋得发黑，字还看得清。"},
		],
		"npcs": [],
	}

	d["playground"] = {
		"title": "游乐场",
		"subtitle": "游乐场",
		"width": 2880.0,
		"floor_y": 456.0,
		"spawn": 120.0,
		"kind": "exterior",
		"interior": false,
		"note": "秋千还在晃。长椅正对着灯。往右是搬家路口。",
		"doors": [
			{"x": 80.0, "to": "street_east", "spawn": 2700.0, "label": "回东段"},
			{"x": 2800.0, "to": "crossing", "spawn": 120.0, "label": "去搬家路口"},
		],
		"props": [
			{"id": "play_swing", "x": 640.0, "kind": "swing", "label": "旧秋千", "label_dy": -30.0, "interact": true, "action": "chore", "chore": "zhou_swing", "cancel_distance": 200.0, "show_if_flag_not": "helped_zhou"},
			{"id": "play_swing_done", "x": 640.0, "kind": "swing", "label": "秋千 · 修好了", "label_dy": -30.0, "interact": false, "show_if_flag": "helped_zhou"},
			{"id": "play_bench", "x": 900.0, "kind": "bench", "label": "长椅 · 坐到天黑", "interact": true, "action": "wait", "target_phase": 2, "show_if_phase_max": 1},
			{"id": "play_shoes", "x": 560.0, "kind": "shoes", "label": "灯下的旧鞋", "label_dy": 26.0, "interact": true, "action": "evidence", "evidence": "ev_shoes", "show_if_phase_min": 2, "hide_if_evidence": "ev_shoes"},
			{"id": "play_slide", "x": 1450.0, "kind": "slide", "label": "滑梯", "interact": true, "action": "read", "text": "滑梯的漆掉了大半。小时候我总从上面冲下来，裤子上全是灰。"},
			{"id": "play_fence", "x": 2050.0, "kind": "marker", "label": "围挡", "interact": true, "action": "read", "text": "围挡上写着「设施老化，请勿靠近」。落款日期是三年前。"},
			{"id": "play_lamp", "x": 500.0, "kind": "lamp", "label": "路灯", "label_dy": -30.0, "interact": true, "action": "read", "text": "灯柱上有一颗被拧平的螺丝。纹路已经磨没了。"},
		],
		"npcs": [
			{
				"id": "p_zhou",
				"name": "周德海",
				"style": "zhou",
				"role": "修灯的人",
				"positions": {"0": 620.0, "1": 760.0, "2": 640.0, "3": 620.0},
				"greet": "搭把手？别让它晃。",
				"lines": [
					"这架秋千我修过三回。每回修完都想，下次总该有人来坐了。",
					"囡囡以前每晚都坐在这儿。她不说，我知道她在等谁。",
					"灯不亮，人就走得不安心。我知道这理由站不住。",
				],
				"line_helped": "链条轻了。你要是有事，先去忙。",
				"line_after": "灯我修好了。你坐一会儿吧，别误了车。",
				"line_present_ok": "「我知道是我。」\n他低下头，重新拧起那颗螺丝。两下，很轻。",
				"line_present_bad": "他看了一眼，把东西推回来。「这个，不是给我的。」",
				"chore": "zhou_swing",
				"chore_label": "扶住秋千",
				"chore_done": "秋千不晃了。老周把工具箱挪到一边，腾出座板旁的位置。",
				"accept_evidence": "ev_shoes",
				"reward": "ev_mirror",
				"done_flag": "helped_zhou",
				"present_flag": "presented_zhou",
				"hide_if_presented": false,
			},
		],
	}

	d["crossing"] = {
		"title": "搬家路口",
		"subtitle": "搬家路口",
		"width": 2400.0,
		"floor_y": 456.0,
		"spawn": 120.0,
		"kind": "exterior",
		"interior": false,
		"note": "车已经掉好头。最后一箱还在路边。",
		"doors": [
			{"x": 80.0, "to": "playground", "spawn": 2700.0, "label": "回游乐场"},
			{"x": 1450.0, "to": "house_hall", "spawn": 1510.0, "label": "穿过侧巷回老宅", "show_if_flag": "presented_tang"},
			{"x": 2300.0, "to": "town_final", "spawn": 120.0, "label": "去镇口灯火", "requires_flag": "dream_seen", "requires_flag2": "presented_tang", "reason": "还不到走的时候。先把手里的东西交出去。"},
		],
		"props": [
			{"id": "cross_box", "x": 1600.0, "kind": "box", "label": "最后一箱", "interact": true, "action": "chore", "chore": "tang_box", "show_if_flag_not": "helped_tang"},
			{"id": "cross_box_done", "x": 1600.0, "kind": "box", "label": "箱子都上车了", "interact": false, "show_if_flag": "helped_tang"},
			{"id": "cross_list", "x": 1510.0, "kind": "note", "label": "搬家清单", "interact": true, "action": "evidence", "evidence": "ev_list", "show_if_flag": "helped_tang", "hide_if_evidence": "ev_list"},
			{"id": "cross_car", "x": 1900.0, "kind": "car", "label": "搬家车", "interact": true, "action": "read", "text": "车已经掉好头。车门开着，像在等人把最后一件东西放上去。"},
			{"id": "cross_puddle", "x": 1180.0, "kind": "puddle", "label": "水洼", "interact": true, "action": "read", "text": "水洼里有半片天。远处有人把纸箱摞得很高。"},
		],
		"npcs": [
			{
				"id": "p_tang",
				"name": "唐棠",
				"style": "tang",
				"role": "要搬走的人",
				"positions": {"0": 1660.0, "1": 1660.0, "2": 1660.0, "3": 1660.0},
				"greet": "最后一箱。帮我挪上车。",
				"lines": [
					"有些东西，带走也放不下。",
					"我不是回来拿东西的。我就是想让他们看看，我过得还行。",
					"清单上写着带走，又划掉。改了三回。",
				],
				"line_helped": "箱子都上车了。……谢谢。",
				"line_after": "清单我收着。该留的，留下。",
				"line_present_ok": "唐棠顺着折痕把清单对起来。「机器留下。磁带……你替我听一下。」",
				"line_present_bad": "她看了一眼，把东西推回来。「这件，不是给你的。」",
				"chore": "tang_box",
				"chore_label": "帮她把最后一箱挪上车",
				"chore_done": "老吴把电动车停在界线外。唐棠站在车门边，没急着上去。",
				"accept_evidence": "ev_list",
				"reward": "ev_tape",
				"done_flag": "helped_tang",
				"present_flag": "presented_tang",
				"hide_if_presented": true,
			},
			{
				"id": "p_wu",
				"name": "吴长庚",
				"style": "wu",
				"role": "修东西的人",
				"positions": {"0": 1280.0, "1": 1280.0, "2": 1280.0, "3": 1280.0},
				"greet": "车靠边了。你们说话，我把机器看着。",
				"lines": [
					"修东西的人，最怕别人说谢谢。",
					"她考上省城那年，我送了一台修好的收音机。后来就没后来了。",
					"有些话，当时不说，后来就说不出口了。",
				],
				"line_helped": "车靠边了。你们说话，我把机器看着。",
				"line_after": "她走了。车拐过街角，看不见了。",
				"line_present_ok": "",
				"line_present_bad": "",
				"chore": "",
				"accept_evidence": "",
				"reward": "",
				"done_flag": "",
				"present_flag": "",
				"hide_if_presented": false,
			},
		],
	}

	d["town_final"] = {
		"title": "镇口灯火",
		"subtitle": "临走 · 06:00",
		"width": 2400.0,
		"floor_y": 456.0,
		"spawn": 120.0,
		"kind": "final",
		"interior": false,
		"note": "十一假期的最后一天。灯还亮着。",
		"doors": [
			{"x": 80.0, "to": "crossing", "spawn": 2250.0, "label": "回路口"},
		],
		"props": [
			{"id": "final_ending", "x": 1700.0, "kind": "marker", "label": "走到灯下", "interact": true, "action": "ending"},
			{"id": "final_bus", "x": 2000.0, "kind": "bus", "label": "早班车", "interact": true, "action": "read", "text": "早班车还没来。站牌下站着一个拎着煮鸡蛋的人。"},
			{"id": "final_sign", "x": 900.0, "kind": "sign", "label": "镇口灯火", "interact": true, "action": "read", "text": "牌坊上的字被灯照亮。风吹过来，还是饭菜香和旧砖味。"},
		],
		"npcs": [],
	}

	d["house_yard"] = {
		"title": "老宅 · 门前",
		"subtitle": "老宅",
		"width": 1600.0,
		"floor_y": 456.0,
		"spawn": 160.0,
		"kind": "exterior",
		"interior": false,
		"note": "门没锁。门口摆着两双鞋，都摆得很正。",
		"doors": [
			{"x": 80.0, "to": "street_west", "spawn": 820.0, "label": "回老街"},
			{"x": 900.0, "to": "house_hall", "spawn": 200.0, "label": "进门"},
		],
		"props": [
			{"id": "yard_mailbox", "x": 840.0, "kind": "mailbox", "label": "信箱", "interact": true, "action": "read", "text": "信箱里塞着几张广告纸。最底下压着一封没有寄出的信，收信人写的是我。"},
			{"id": "yard_step", "x": 1180.0, "kind": "marker", "label": "门槛缝", "interact": true, "action": "read", "text": "门槛留着一条晒白的印子。两双鞋都朝里。"},
		],
		"npcs": [],
	}

	d["house_hall"] = {
		"title": "老宅 · 客厅",
		"subtitle": "老宅",
		"width": 1920.0,
		"floor_y": 470.0,
		"spawn": 200.0,
		"kind": "interior",
		"interior": true,
		"note": "钟还在走。沙发塌下去一块。茶几上压着两件旧东西。",
		"doors": [
			{"x": 80.0, "to": "house_yard", "spawn": 900.0, "label": "出门"},
			{"x": 1360.0, "to": "town_final", "spawn": 1050.0, "label": "抄近路去镇口", "show_if_flag": "dream_seen"},
			{"x": 1600.0, "to": "basement", "spawn": 160.0, "label": "下地下室"},
		],
		"props": [
			{"id": "hall_photo", "x": 700.0, "kind": "photo", "label": "旧照片", "interact": true, "action": "turn_photo", "evidence": "ev_photo", "hide_if_evidence": "ev_photo"},
			{"id": "hall_note", "x": 1180.0, "kind": "note", "label": "琴弦字条", "interact": true, "action": "evidence", "evidence": "ev_note", "hide_if_evidence": "ev_note"},
			{"id": "hall_clock", "x": 380.0, "kind": "clock", "label": "老钟", "interact": true, "action": "read", "text": "四点十分。秒针还在走，红色针尖一下一下地跳。"},
			{"id": "hall_sofa", "x": 540.0, "kind": "bench", "label": "布沙发", "interact": true, "action": "read", "text": "坐垫塌下去一块，是固定坐着的那个人留下的形状。"},
			{"id": "hall_table", "x": 900.0, "kind": "marker", "label": "茶几", "interact": true, "action": "read", "text": "半杯凉水，杯壁上没有水汽。妈妈大概出门有一会儿了。"},
		],
		"npcs": [
			{
				"id": "p_chen",
				"name": "陈守业",
				"style": "chen",
				"role": "父亲",
				"positions": {"0": 820.0, "1": 820.0, "2": 1180.0, "3": 820.0},
				"greet": "回来啦。",
				"lines": [
					"你妈去镇口了。她说你要是回来，先去老宅看看，别急着找她。",
					"琴箱在夹层。备用弦也在。到那边也能换。",
					"有些东西，锁起来不是因为不想给。是怕给了，就真的走了。",
				],
				"line_helped": "回来啦。",
				"line_after": "回来啦。",
				"line_present_ok": "",
				"line_present_bad": "",
				"chore": "",
				"accept_evidence": "",
				"reward": "",
				"done_flag": "",
				"present_flag": "",
				"hide_if_presented": false,
			},
			{
				"id": "p_mom",
				"name": "妈妈",
				"style": "mom",
				"role": "家人",
				"positions": {"0": 1280.0, "1": 1280.0, "2": 1280.0, "3": 1280.0},
				"greet": "盐呢？",
				"lines": [
					"家里没盐了，下楼买包盐去。",
					"你在外头，也不容易。",
					"回来就好。回来就好。",
				],
				"line_helped": "盐呢？",
				"line_after": "盐呢？",
				"line_present_ok": "",
				"line_present_bad": "",
				"chore": "",
				"accept_evidence": "",
				"reward": "",
				"done_flag": "",
				"present_flag": "",
				"hide_if_presented": false,
			},
		],
	}

	d["basement"] = {
		"title": "老宅 · 地下室",
		"subtitle": "老宅",
		"width": 1440.0,
		"floor_y": 470.0,
		"spawn": 160.0,
		"kind": "interior",
		"interior": true,
		"note": "灯泡晃了一下。琴箱在最里面。",
		"doors": [
			{"x": 80.0, "to": "house_hall", "spawn": 1550.0, "label": "回客厅"},
		],
		"props": [
			{"id": "base_chest", "x": 1100.0, "kind": "chest", "label": "琴箱", "interact": true, "action": "chest"},
			{"id": "base_shelf", "x": 350.0, "kind": "marker", "label": "旧木架", "interact": true, "action": "read", "text": "木架上堆着旧报纸。最上面一张的日期，是十年前。"},
		],
		"npcs": [],
	}

	d["shop"] = {
		"title": "副食店",
		"subtitle": "小卖部",
		"width": 1200.0,
		"floor_y": 470.0,
		"spawn": 160.0,
		"kind": "interior",
		"interior": true,
		"note": "货架上的橘子汽水摆得很整齐。价签是手写的。",
		"doors": [
			{"x": 80.0, "to": "street_west", "spawn": 1840.0, "label": "出门"},
		],
		"props": [
			{"id": "shop_counter", "x": 760.0, "kind": "counter", "label": "柜台", "interact": true, "action": "read", "text": "柜台后面空着。收音机还在响，播的是本地戏。"},
			{"id": "shop_shelf", "x": 300.0, "kind": "marker", "label": "货架", "interact": true, "action": "read", "text": "橘子汽水，价签手写：一块五。旁边摆着一排落灰的磁带。"},
		],
		"npcs": [
			{
				"id": "p_shop",
				"name": "店主",
				"style": "shop",
				"role": "看店的人",
				"positions": {"0": 760.0, "1": 760.0, "2": 760.0, "3": 760.0},
				"greet": "回来啦？",
				"lines": [
					"你妈今早去镇口了。她说你要是回来，先去老宅看看。",
					"老街这几个月热闹，路灯修了一半。",
					"橘子汽水还是那个价。给你留了一瓶。",
				],
				"line_helped": "回来啦？",
				"line_after": "回来啦？",
				"line_present_ok": "",
				"line_present_bad": "",
				"chore": "",
				"accept_evidence": "",
				"reward": "",
				"done_flag": "",
				"present_flag": "",
				"hide_if_presented": false,
			},
		],
	}

	d["dream"] = {
		"title": "梦 · 教室与车站",
		"subtitle": "梦",
		"width": 3600.0,
		"floor_y": 456.0,
		"spawn": 160.0,
		"kind": "dream",
		"interior": false,
		"note": "教室、巷子、秋千、车站。你只能往前走。",
		"doors": [],
		"props": [
			{"id": "dream_desk1", "x": 700.0, "kind": "dream_desk", "label": "课桌", "interact": true, "action": "read", "text": "课桌上刻着一行小字：我要离开这里。下面还有半句，笔迹更深：也走不远。"},
			{"id": "dream_desk2", "x": 1080.0, "kind": "dream_desk", "label": "空座位", "interact": true, "action": "read", "text": "座位空着。窗外有人在笑，声音很远。"},
			{"id": "dream_clock", "x": 3200.0, "kind": "dream_clock", "label": "车站的钟", "interact": true, "action": "read", "text": "钟面没有指针。你听见报时声，却不知道现在是几点。"},
		],
		"npcs": [],
		"exit_x": 3380.0,
	}

	return d


static func get_scene(id: String) -> Dictionary:
	var data: Dictionary = all()
	return data.get(id, {}) as Dictionary


