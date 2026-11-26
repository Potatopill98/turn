extends Node2D

const Progress = preload("res://chapter_progress.gd")
const Data = preload("res://scripts/turn_data.gd")
const EvidencePanel = preload("res://ui/evidence_panel.gd")
const TitleCard = preload("res://ui/title_card.gd")
const ChapterPlayer = preload("res://ui/chapter_player.gd")
const ActWalk = preload("res://world/act_walk.gd")

const DAY = preload("res://art/00_场景/09_游乐场与老街路灯_白天.png")
const NIGHT = preload("res://art/00_场景/10_游乐场的蓝调夜色.png")
const STREET = preload("res://art/00_场景/11_搬家路口.png")
const TOWN = preload("res://art/00_场景/12_终章镇口灯火.png")
const NOTICE = preload("res://art/07_道具_第二幕/告示牌的调查特写.png")
const RECORD = preload("res://art/07_道具_第二幕/连续三年的维修记录本.png")
const MIRROR = preload("res://art/07_道具_第二幕/镜面谜题的旋转件.png")
const LAMP = preload("res://art/07_道具_第二幕/老街路灯_点亮.png")
const TAPE = preload("res://art/08_道具_第三幕/给阿棠的旧磁带.png")
const LIST = preload("res://art/08_道具_第三幕/搬家清单.png")
const DECK = preload("res://art/08_道具_第三幕/磁带机的倒带面板.png")
const FAREWELL = preload("res://art/09_来信与插帧/旧友在搬家路口道别.png")
const REPAIR = preload("res://art/09_来信与插帧/老周在亮灯后仍拧螺丝.png")
const GOLD = Color("#f0cc89")
const PAPER = Color("#f6ecd8")
const SOURCE = Vector2(195, 226)
const FIRST = Vector2(435, 226)
const SECOND = Vector2(435, 114)
const RECEIVER = Vector2(733, 114)

const PANEL := Color("#20272e")
const SHOES = preload("res://art/07_道具_第二幕/小女孩的一双旧鞋.png")
const SCREW = preload("res://art/07_道具_第二幕/反复拧平的螺丝.png")
const PARTS = preload("res://art/08_道具_第三幕/磁带机维修的小零件.png")
const PHONE = preload("res://art/08_道具_第三幕/唐棠展示照片的手机.png")
const GROUP = preload("res://art/09_来信与插帧/终章镇口群像.png")
const LETTER = preload("res://art/09_来信与插帧/分幕收到的信_空白母图.png")
const DIARY_ART = preload("res://art/05_道具_序章/旧日记本_空白页.png")
const PRINT_ART = preload("res://art/05_道具_序章/多出的三步脚印.png")
const CLOCK_ART = preload("res://art/05_道具_序章/老宅墙钟.png")
const LETTERS = [
	"小满今年三十岁，在镇上教钢琴，学生很多，都说她教得好。那把吉他锁在地下室，钥匙在她爸那儿。她再没写过自己的歌。存折她一直没动，现在夹在父亲床头那本歌选里。父亲说留着给她孩子上学。她说爸你真好。",
	"路灯修好了，孩子们还是不去那儿玩。老周每天晚上把灯开到天亮，说怕黑。游乐场围了围挡，牌子上写着「设施老化，请勿靠近」，那几颗螺丝是他亲手拧上去的。",
	"唐棠搬走了。两人再没联系。据说走的那天，谁也没回头。她孙子说，她最后那半年常提起一位老朋友，说那天下雨，也不是谁故意的。"
]
var page := "day"
var observed := [false, false]
var mirror_angles: Array[int] = [0, 0]
var lit := false
var deck_fixed := false
var walk_layer: Node2D
var title_card: CanvasLayer
var evidence_layer: CanvasLayer
var chapter_player: CanvasLayer
var _story_played: Dictionary = {}
var _a2_dream: bool = false
var _a3_dream: bool = false
var a2_stance: String = "none"
var a3_stance: String = "none"
var a2_done: bool = false
var a3_done: bool = false
var _act: String = ""
var letter_return := ""
var prose := Label.new()
var reveal := 0.0
var previous_body := ""
var tape_hiss := AudioStreamWAV.new()
var effects := AudioStreamPlayer.new()
const CLICK = preload("res://audio/prologue/latch.wav")
var tape_position := 54
var heard_tape := false
var note := ""
var font := SystemFont.new()
var buttons := HBoxContainer.new()

func _ready():
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	buttons.position = Vector2(50, 544)
	buttons.add_theme_constant_override("separation", 10)
	add_child(buttons)
	add_child(effects)
	var samples := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	var level := 0.0
	for i in 11025:
		level = lerpf(level, rng.randf_range(-1, 1), 0.28)
		var envelope := minf(1, mini(i, 11024-i) / 160.0)
		samples.append(int(level * envelope * 96) & 255)
	tape_hiss.format = AudioStreamWAV.FORMAT_8_BITS
	tape_hiss.mix_rate = 11025
	tape_hiss.data = samples
	prose.position = Vector2(50, 472)
	prose.size = Vector2(862, 67)
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prose.add_theme_font_override("font", font)
	prose.add_theme_font_size_override("font_size", 19)
	prose.modulate = PAPER
	prose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prose)
	var entry: String = get_tree().get_meta("entry_chapter","day")
	if get_tree().has_meta("entry_chapter"): get_tree().remove_meta("entry_chapter")
	walk_layer = ActWalk.new()
	add_child(walk_layer)
	title_card = TitleCard.new()
	add_child(title_card)
	evidence_layer = EvidencePanel.new()
	add_child(evidence_layer)
	chapter_player = ChapterPlayer.new()
	add_child(chapter_player)
	show_page(entry if entry in ["day","street","letter1","letter2","letter3","ending"] else "day")
	if entry in ["day", "letter1", "letter2"]:
		title_card.show_act("A2", 1.4)
	elif entry in ["street", "letter3"]:
		title_card.show_act("A3", 1.4)
	elif entry == "ending":
		title_card.show_act("ending", 1.4)

func show_page(next: String, feedback := ""):
	var story_id: String = ""
	if next in ["letter1", "day"]:
		story_id = "second"
	elif next == "street":
		story_id = "third"
	elif next == "ending":
		story_id = "epilogue"
	if not story_id.is_empty() and not _story_played.has(story_id) and chapter_player != null:
		_story_played[story_id] = true
		chapter_player.play(story_id, _show_page_now.bind(next, feedback))
		return
	_show_page_now(next, feedback)

func _show_page_now(next: String, feedback: String = ""):
	var was := page
	var focus_slot := buttons.get_children().find(get_viewport().gui_get_focus_owner())
	page = next
	var act := act_for_page(page)
	if act != _act:
		_act = act
		TurnState.start_act(act)
	if Progress.SCENES.has(page) and letter_return.is_empty():
		Progress.mark(get_tree(), page)
	if page == "ending" and TurnState.ending_tier.is_empty():
		TurnState.settle_ending()
	note = feedback
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	match page:
		"day":
			add_button("等到天黑", show_page.bind("night"), observed.all(func(done): return done))
		"notice", "record", "shoes", "tape", "list":
			add_button("返回现场", show_page.bind("day" if page in ["notice","record","shoes"] else "street"))
		"night":
			add_button("转动镜面 1", turn_mirror.bind(0))
			add_button("转动镜面 2", turn_mirror.bind(1))
			add_button("走到路灯下", show_page.bind("repair"), lit)
		"repair":
			add_button("问起那颗螺丝", zhou.bind(true))
			add_button("替他扶住灯", zhou.bind(false))
		"zhou":
			add_button("把维修记录本递过去", open_evidence_a2, not a2_done)
			add_button("收下第二封信", show_page.bind("letter2"))
		"street":
			add_button("打开磁带机", show_page.bind("rewind" if deck_fixed else "fix"), observed.all(func(done): return done))
		"fix":
			add_button("换电池", fix_deck.bind(false))
			add_button("把皮带套回轮槽", fix_deck.bind(true))
			add_button("返回路口", show_page.bind("street"))
		"rewind":
			add_button("倒带 6 秒", wind.bind(-6), tape_position > 0)
			add_button("快进 6 秒", wind.bind(6), tape_position < 60)
			add_button("试播", listen)
			add_button("把留言带给唐棠", show_page.bind("phone"), heard_tape)
		"phone":
			add_button("把手机还给她", show_page.bind("farewell"))
		"farewell":
			add_button("把最后一件东西递过去", open_evidence_a3, heard_tape and not a3_done)
			add_button("收下第三封信", show_page.bind("letter3"))
		"letter1","letter2","letter3":
			if not letter_return.is_empty():
				add_button("收好信", close_letter)
			elif page == "letter2":
				add_button("去搬家路口", begin_street)
			else:
				add_button("去老街" if page == "letter1" else "回到镇口", show_page.bind("day" if page == "letter1" else "ending"))
		"ending":
			add_button("读完结尾", show_page.bind("credits"))
		"credits":
			for i in 3: add_button("回读第%d封信" % (i + 1), review_letter.bind(i + 1))
			add_button("从头重玩", show_page.bind("confirm_restart"))
		"confirm_restart":
			add_button("保留进度", show_page.bind("credits"))
			add_button("从镇口重新开始", restart)
	if page == "shoes":
		TurnState.unlock_item("e_shoes")
	elif page == "notice":
		TurnState.unlock_item("e_fence")
	elif page == "record":
		TurnState.unlock_item("e_record")
	elif page == "tape":
		TurnState.unlock_item("e_tape")
	elif page == "list":
		TurnState.unlock_item("e_list")
	elif page == "repair":
		TurnState.unlock_item("e_lamp")
	elif page == "phone":
		TurnState.unlock_item("e_phone")
	var walking: bool = page == "day" or page == "street"
	if walk_layer != null:
		if walking:
			_configure_walk()
			walk_layer.activate()
		else:
			walk_layer.deactivate()
	buttons.visible = not walking
	var letter_page := page.begins_with("letter")
	prose.position = Vector2(355, 82) if letter_page else Vector2(50, 472)
	prose.size = Vector2(224, 285) if letter_page else Vector2(862, 68)
	prose.modulate = Color("#483c32") if letter_page else PAPER
	prose.add_theme_font_size_override("font_size", 18 if letter_page else 19)
	if walking:
		queue_redraw()
		return
	var options := buttons.get_children()
	var index := clampi(focus_slot, 0, options.size()-1) if was == page else 0
	if not options[index].disabled: options[index].grab_focus()
	else:
		for option in options:
			if not option.disabled:
				option.grab_focus()
				break
	queue_redraw()

func act_for_page(p: String) -> String:
	if p in ["day","notice","record","shoes","night","repair","zhou","letter1","letter2"]:
		return "A2"
	if p in ["street","tape","list","fix","rewind","phone","farewell","letter3"]:
		return "A3"
	return "ending"

func _configure_walk() -> void:
	if page == "day":
		var day_spots: Array[Vector2] = [Vector2(220, 232), Vector2(500, 248), Vector2(700, 235)]
		var day_labels: Array[String] = ["围挡", "维修记录", "旧鞋"]
		walk_layer.configure(Rect2(140, 205, 700, 75), day_spots, day_labels, Vector2(846, 240), "走到路灯下", _walk_spot, _walk_exit)
	else:
		var street_spots: Array[Vector2] = [Vector2(250, 255), Vector2(420, 270), Vector2(560, 260)]
		var street_labels: Array[String] = ["搬家清单", "旧磁带", "磁带机"]
		walk_layer.configure(Rect2(150, 225, 500, 110), street_spots, street_labels, Vector2(700, 270), "走到唐棠身边", _walk_spot, _walk_exit)

func _walk_spot(index: int) -> void:
	if page == "day":
		match index:
			0: inspect(0, "notice")
			1: inspect(1, "record")
			2: show_page("shoes")
	elif page == "street":
		match index:
			0: inspect(1, "list")
			1: inspect(0, "tape")
			2: show_page("rewind" if deck_fixed else "fix")

func _walk_exit() -> void:
	if page == "day":
		if observed.all(func(done): return done):
			show_page("night")
		else:
			walk_layer.say("还有东西没看。围挡、记录、旧鞋都看一眼。")
	elif page == "street":
		if heard_tape:
			show_page("phone")
		else:
			walk_layer.say("磁带还没听到 00:18。先去打开磁带机。")

func review_letter(number: int):
	letter_return = "credits"
	show_page("letter%d" % number)

func close_letter():
	letter_return = ""
	show_page("credits")

func zhou(spoke: bool):
	get_tree().set_meta("spoke_to_zhou", spoke)
	show_page("zhou")

func fix_deck(correct: bool):
	if correct:
		deck_fixed = true
		click_sound(0.9)
		show_page("rewind", "皮带咬住轮槽。按倒带，去找标签上写的那一段。")
	else:
		show_page("fix","指示灯亮着，右侧轮轴空转。盒底那圈松下来的皮带还在。")

func click_sound(pitch: float):
	effects.stream = CLICK
	effects.pitch_scale = pitch
	effects.volume_db = -16
	effects.play()

func _process(delta: float):
	if prose.visible_ratio < 1.0:
		reveal += delta * 44
		prose.visible_characters = int(reveal)

func _input(event: InputEvent):
	if chapter_player != null and chapter_player.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE and prose.visible_ratio < 1:
		prose.visible_characters = -1
		get_viewport().set_input_as_handled()
	elif page == "rewind" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Rect2(140,373,680,41).has_point(get_local_mouse_position()):
		var seconds := clampf((get_local_mouse_position().x - 155.0) / 650.0, 0.0, 1.0) * 60
		wind(roundi(seconds / 6.0) * 6 - tape_position)
		get_viewport().set_input_as_handled()
	elif page == "night" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in 2:
			if get_local_mouse_position().distance_to([FIRST, SECOND][i]) < 30:
				turn_mirror(i)
				get_viewport().set_input_as_handled()
				return

func add_button(caption: String, action: Callable, enabled := true):
	var button := Button.new()
	button.text = caption
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(125, 38)
	button.disabled = not enabled
	button.pressed.connect(advance.bind(action))
	buttons.add_child(button)

func advance(action: Callable):
	if (page.begins_with("letter") or page in ["ending","zhou","farewell","phone"]) and prose.visible_ratio < 1.0:
		prose.visible_characters = -1
		return
	action.call()

func inspect(index: int, detail: String):
	observed[index] = true
	show_page(detail)

func turn_mirror(index: int):
	click_sound(1.0 + float(mirror_angles[index]) * 0.12)
	mirror_angles[index] = (mirror_angles[index] + 1) % 4
	lit = mirror_angles[0] == 1 and mirror_angles[1] == 2
	show_page("night")

func begin_street():
	observed = [false, false]
	a3_done = false
	if title_card != null:
		title_card.show_act("A3", 1.4)
	show_page("street")

func open_evidence_a2() -> void:
	if evidence_layer == null:
		return
	if not _a2_dream:
		_a2_dream = true
		chapter_player.play("second_dream", _open_evidence_a2_now)
		return
	_open_evidence_a2_now()

func _open_evidence_a2_now() -> void:
	if evidence_layer == null:
		return
	evidence_layer.open("A2", _on_a2_result)

func _on_a2_result(stance: String, _item_id: String) -> void:
	a2_done = true
	a2_stance = stance
	TurnState.set_flag("a2_stance", stance)
	show_page("zhou", "老周把记录本接过去，翻到三年前那一页，没合上。")

func open_evidence_a3() -> void:
	if evidence_layer == null:
		return
	if not _a3_dream:
		_a3_dream = true
		chapter_player.play("third_dream", _open_evidence_a3_now)
		return
	_open_evidence_a3_now()

func _open_evidence_a3_now() -> void:
	if evidence_layer == null:
		return
	evidence_layer.open("A3", _on_a3_result)

func _on_a3_result(stance: String, _item_id: String) -> void:
	a3_done = true
	a3_stance = stance
	TurnState.set_flag("a3_stance", stance)
	TurnState.settle_ending()
	show_page("farewell", "唐棠把最后一件东西收进包里。车没有立刻开走。")

func wind(step: int):
	click_sound(1.2 if step > 0 else 0.8)
	tape_position = clampi(tape_position + step, 0, 60)
	show_page("rewind")

func listen():
	effects.stream = tape_hiss
	effects.pitch_scale = 1.0
	effects.volume_db = -11
	effects.play()
	if tape_position == 18:
		heard_tape = true
		show_page("rewind", "留言：“阿棠，明天九点，老地方见。”")
	else:
		show_page("rewind", "只有沙沙声。" if tape_position > 18 else "只听见一声关门。可以往后找。")

func restart():
	Progress.fresh(get_tree())
	get_tree().change_scene_to_file("res://prologue.tscn")

func cover(texture: Texture2D, rect: Rect2):
	var source := texture.get_size()
	var scale := maxf(rect.size.x / source.x, rect.size.y / source.y)
	var visible := rect.size / scale
	draw_texture_rect_region(texture, rect, Rect2((source - visible) / 2, visible))

func art(texture: Texture2D, rect: Rect2):
	var source := texture.get_size()
	var scale := minf(rect.size.x / source.x, rect.size.y / source.y)
	var size := source * scale
	draw_texture_rect(texture, Rect2(rect.position + (rect.size - size) / 2, size), false)

func label(at: Vector2, value: String, size: int, color := PAPER):
	draw_multiline_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, -1, color)

func draw_mirrors():
	draw_rect(Rect2(120, 61, 720, 295), Color(0.07, 0.10, 0.15, 0.94))
	draw_line(SOURCE, FIRST, GOLD, 5, true)
	if mirror_angles[0] == 1:
		draw_line(FIRST, SECOND, GOLD, 5, true)
		if mirror_angles[1] == 2:
			draw_line(SECOND, RECEIVER, GOLD, 5, true)
		else:
			draw_line(SECOND, SECOND + Vector2(-94, 0), Color(GOLD, 0.45), 3, true)
			label(SECOND + Vector2(-96, -8), "偏光", 14, Color(GOLD, 0.55))
	else:
		var miss: Vector2 = Vector2(435, 315) if mirror_angles[0] == 3 else Vector2(338, 226)
		draw_line(FIRST, miss, Color(GOLD, 0.45), 3, true)
		label(miss + Vector2(-22, 18), "偏光", 14, Color(GOLD, 0.55))
	for i in 2:
		var pos := FIRST if i == 0 else SECOND
		art(MIRROR, Rect2(pos - Vector2(25, 25), Vector2(50, 50)))
		var angle: int = mirror_angles[i]
		var up_down: float = 1.0 if angle in [0, 2] else -1.0
		var diagonal := Vector2(11, -11 * up_down)
		draw_line(pos - diagonal, pos + diagonal, PAPER, 4, true)
		if (i == 0 and angle == 1) or (i == 1 and angle == 2):
			draw_arc(pos, 22, 0, TAU, 24, Color(GOLD, 0.75), 2, true)
		label(pos + Vector2(25, 12), str(i + 1), 18)
	draw_circle(SOURCE, 8, GOLD)
	draw_circle(RECEIVER, 11, GOLD if lit else Color("#627589"))
	label(SOURCE + Vector2(-32, 43), "起点", 17)
	label(RECEIVER + Vector2(-22, 42), "路灯", 17)
	if lit:
		label(Vector2(300, 330), "光到了路灯。可以往下走了。", 15, GOLD)

func draw_waveform() -> void:
	var base_y := 376.0
	for i in 130:
		var x := 155.0 + 650.0 * float(i) / 130.0
		var seconds := 60.0 * float(i) / 130.0
		var amp := 3.0 + 7.0 * absf(sin(float(i) * 0.9)) * (0.4 + 0.6 * absf(sin(float(i) * 0.17)))
		if absf(seconds - 18.0) < 3.0:
			draw_line(Vector2(x, base_y - 14.0), Vector2(x, base_y + 14.0), GOLD, 2.0)
		else:
			draw_line(Vector2(x, base_y - amp), Vector2(x, base_y + amp), Color(PAPER, 0.42), 1.0)
	label(Vector2(155, 352), "00:18 人声块", 12, GOLD)
	label(Vector2(690, 352), "点击刻度可直接定位", 12, Color(PAPER, 0.55))

func draw_memories() -> void:
	var captions: Array[String] = ["旧日记", "多出的三步", "往回走的钟"]
	var textures: Array[Texture2D] = [DIARY_ART, PRINT_ART, CLOCK_ART]
	var flags: Array[String] = ["diary_read", "footprints_started", "clock_reversed"]
	label(Vector2(566, 6), "你在序章记下的三件事", 13, Color(PAPER, 0.7))
	for i in 3:
		var x: float = 566.0 + float(i) * 104.0
		var rect := Rect2(x, 26, 92, 92)
		draw_rect(rect, Color(0.08, 0.10, 0.12, 0.6))
		var on: bool = TurnState.has_flag(flags[i])
		if on:
			art(textures[i], rect)
		else:
			draw_rect(rect, Color(0.18, 0.20, 0.22, 0.35))
			label(Vector2(x + 18, 76), "没记起", 13, Color(PAPER, 0.35))
		label(Vector2(x, 134), captions[i], 12, GOLD if on else Color(PAPER, 0.4))

func stance_name(stance: String) -> String:
	match stance:
		"expose":
			return "全说开"
		"half":
			return "各留一半"
		"soft":
			return "留白"
		_:
			return "还没定"

func draw_graph() -> void:
	draw_rect(Rect2(0, 0, 960, 425), Color(0.06, 0.08, 0.10, 0.84))
	var acts: Array[String] = ["A1", "A2", "A3"]
	var names: Array[String] = ["第一幕 · 未寄出的信笺", "第二幕 · 白天与提灯人", "第三幕 · 最亮的那盏"]
	var columns: Array[float] = [70.0, 350.0, 630.0]
	for c in 3:
		var x: float = columns[c]
		var act: String = acts[c]
		label(Vector2(x, 52), names[c], 14, GOLD)
		draw_line(Vector2(x, 60), Vector2(x + 220, 60), Color(GOLD, 0.4), 1)
		var items: Array = Data.evidence_items(act)
		for i in 3:
			if i >= items.size():
				continue
			var item: Dictionary = items[i] as Dictionary
			var item_id: String = str(item.get("id", ""))
			var rect := Rect2(x, 72 + float(i) * 62.0, 48, 48)
			draw_rect(rect, Color(0.12, 0.15, 0.17, 0.85))
			var texture: Texture2D = Data.texture(str(item.get("thumb", "")))
			if texture != null and TurnState.knows_item(item_id):
				art(texture, rect)
			else:
				label(Vector2(x + 14, 102 + float(i) * 62.0), "？", 20, Color(PAPER, 0.3))
			label(Vector2(x + 56, 92 + float(i) * 62.0), str(item.get("label", "")), 11, PAPER if TurnState.knows_item(item_id) else Color(PAPER, 0.35))
			label(Vector2(x + 56, 108 + float(i) * 62.0), "已记录" if TurnState.knows_item(item_id) else "未记录", 10, Color(GOLD, 0.7))
		label(Vector2(x, 270), "本幕立场：" + stance_name(TurnState.get_stance(act)), 12, GOLD)
	for i in 3:
		var x: float = 70.0 + float(i) * 300.0
		draw_rect(Rect2(x, 300, 56, 40), Color(0.12, 0.15, 0.17, 0.85))
		label(Vector2(x + 66, 316), "第 %d 封信" % (i + 1), 12, PAPER)
		label(Vector2(x + 66, 332), "已读" if TurnState.letters_read.has(i + 1) else "未读", 10, Color(GOLD, 0.7))
	var tiers: Array[String] = ["clear", "half", "soft"]
	var tier_names: Array[String] = ["全说开", "各留一半", "留白"]
	for i in 3:
		var x: float = 70.0 + float(i) * 220.0
		var unlocked: bool = TurnState.cg_unlocked.has(tiers[i])
		draw_rect(Rect2(x, 362, 150, 34), Color(0.12, 0.15, 0.17, 0.85) if unlocked else Color(0.10, 0.11, 0.12, 0.55))
		label(Vector2(x + 10, 384), "CG · " + tier_names[i], 11, GOLD if unlocked else Color(PAPER, 0.35))
	label(Vector2(740, 384), "BGM  %d / 3" % TurnState.bgm_unlocked.size(), 11, Color(PAPER, 0.55))

func _draw():
	var background: Texture2D = DAY
	var feature: Texture2D
	var title := ""
	var body := ""
	match page:
		"day":
			title = "第二幕 · 白昼与提灯人"
			body = "围挡、维修记录、旧鞋。走近任一热点按 E 看，看完再走到路灯下。"
		"notice":
			feature = NOTICE
			title = "围挡告示"
			body = "有人在拆除日期下面写了四个小字：还能修好。"
		"record":
			feature = RECORD
			title = "维修记录"
			body = "三本册子，每天一行「紧秋千螺丝」。头一年的字沿着格子写，末页的横画抖到了下一行。"
		"shoes":
			feature = SHOES
			title = "秋千底下的小鞋"
			body = "你刚伸手，老周就把鞋挪到了膝上。他拧干布，先擦左脚，再擦右脚。"
		"night":
			background = NIGHT
			title = "转动两面镜子"
			body = "灯亮了。照见了秋千旁那个人。" if lit else "两面镜子各能转四个朝向。让光依次经过两面镜子，照到右边的旧路灯。"
		"repair":
			background = REPAIR
			title = "老周 · 灯亮之后"
			body = "孩子们隔着围挡看了一眼就走了。灯照着秋千，老周手里的螺丝刀转了一圈，又一圈。"
		"zhou":
			background = REPAIR
			feature = SCREW
			title = "拧平的螺丝"
			body = note if not note.is_empty() else ("「我知道是我。」老周低下头，继续拧那颗已经拧平的螺丝。" if get_tree().get_meta("spoke_to_zhou",false) else "你把灯扶稳。老周说了声谢谢，又把螺丝刀抵进磨平的凹槽。")
		"street":
			background = STREET
			title = "第三幕 · 旧录音带里的夏日"
			body = "搬家清单、旧磁带、磁带机。走近任一热点按 E，走到唐棠身边再递最后一件东西。"
		"tape":
			background = STREET
			feature = TAPE
			title = "给阿棠的旧磁带"
			body = "标签背面写着：“雨声大了才开始说话，大约在 00:18。”"
		"list":
			background = STREET
			feature = LIST
			title = "搬家清单"
			body = "纸上每一行都划掉了，只有「把磁带听完」还留着。"
		"fix":
			background = STREET
			feature = PARTS
			title = "修磁带机"
			body = "电源灯亮着，马达嗡嗡响，带轮却没跟着转。盒底躺着一圈松脱的橡胶。" if note.is_empty() else note
		"rewind":
			background = STREET
			feature = DECK
			title = "磁带机 · 00:%02d" % tape_position if tape_position < 60 else "磁带机 · 01:00"
			body = "用倒带、快进或点击刻度定位，再按试播。" if note.is_empty() else note
		"phone":
			background = STREET
			feature = PHONE
			title = "唐棠的相册"
			body = "「哦，原来约的九点。那天雨真大。」唐棠翻出这几年的照片。老吴一张也没认出来，只在她停下时点点头。"
		"farewell":
			background = FAREWELL
			title = "唐棠 · 搬家路口"
			body = note if not note.is_empty() else "车门开着。唐棠说：「以后常联系。」老吴握住车把：「一定。」"
		"letter1","letter2","letter3":
			var number := int(page.right(1))
			background = [TOWN, REPAIR, FAREWELL][number-1]
			feature = LETTER
			title = "镇上来信 · 第%d封" % number
			body = LETTERS[number-1]
		"ending":
			background = GROUP
			title = "终章 · 小镇的灯火"
			var tier: String = TurnState.ending_tier if not TurnState.ending_tier.is_empty() else TurnState.resolve_tier()
			var echo: Dictionary = Data.ending(tier)
			body = str(echo.get("body", ""))
		"credits","confirm_restart":
			background = TOWN
			title = "turn · 全剧终"
			body = "镇子现在很整齐。灯是亮的，路是平的，秋千没人玩了，所以也不会坏。我们从这里开始，都过得还不错。" if page == "credits" else "从镇口重新开始会清除这次的章节进度。"

	art(background, Rect2(0, 0, 960, 425))
	if page.begins_with("letter"):
		draw_rect(Rect2(0, 0, 960, 425), Color(0.07, 0.09, 0.11, 0.72))
		# Use the blank sheet itself as the reading surface; keep the envelope at its edge.
		draw_texture_rect_region(LETTER, Rect2(324, 15, 315, 395), Rect2(Vector2(0.09,0.09)*LETTER.get_size(),Vector2(0.69,0.82)*LETTER.get_size()))
	elif feature:
		draw_rect(Rect2(310, 34, 340, 346), Color(0.09, 0.12, 0.16, 0.89))
		art(feature, Rect2(327, 48, 306, 315))
	if page == "night":
		draw_mirrors()
		if lit:
			art(LAMP, Rect2(754, 155, 72, 156))
	if page == "rewind":
		draw_waveform()
	if page == "ending":
		draw_memories()
	if page == "credits":
		draw_graph()
	draw_rect(Rect2(0, 425, 960, 175), Color("#20272e"))
	label(Vector2(50, 465), title, 24, GOLD)
	if page.begins_with("letter"):
		label(Vector2(50, 500), "附言：" + Data.letter_note("letter%d" % int(page.right(1))), 13, Color(PAPER, 0.66))
	if previous_body != body:
		previous_body = body
		prose.text = body
		prose.visible_characters = 0
		reveal = 0
	if page == "rewind":
		draw_rect(Rect2(155, 392, 650, 5), Color("#5c6468"))
		draw_rect(Rect2(155, 392, 650 * tape_position / 60.0, 5), GOLD)
		for i in 11:
			var tick_x := 155 + i * 65
			draw_line(Vector2(tick_x,387), Vector2(tick_x,400), PAPER, 1)
		draw_circle(Vector2(155 + 650 * tape_position / 60.0, 394), 6, PAPER)
