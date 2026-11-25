extends Node2D

const Progress = preload("res://chapter_progress.gd")

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
const LETTERS = [
	"小满今年三十岁，在镇上教钢琴，学生很多，都说她教得好。那把吉他锁在地下室，钥匙在她爸那儿。她再没写过自己的歌。存折她一直没动，现在夹在父亲床头那本歌选里。父亲说留着给她孩子上学。她说爸你真好。",
	"路灯修好了，孩子们还是不去那儿玩。老周每天晚上把灯开到天亮，说怕黑。游乐场围了围挡，牌子上写着「设施老化，请勿靠近」，那几颗螺丝是他亲手拧上去的。",
	"唐棠搬走了。两人再没联系。据说走的那天，谁也没回头。她儿子说，她最后那半年常提起一位老朋友，说那天下雨，也不是谁故意的。"
]
var page := "day"
var observed := [false, false]
var mirrors := [false, false]
var lit := false
var deck_fixed := false
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
	show_page(entry if entry in ["day","street","letter1","letter2","letter3","ending"] else "day")

func show_page(next: String, feedback := ""):
	var was := page
	var focus_slot := buttons.get_children().find(get_viewport().gui_get_focus_owner())
	page = next
	if Progress.SCENES.has(page) and letter_return.is_empty():
		Progress.mark(get_tree(), page)
	note = feedback
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	match page:
		"day":
			add_button("看围挡告示" + (" ✓" if observed[0] else ""), inspect.bind(0, "notice"))
			add_button("翻维修记录" + (" ✓" if observed[1] else ""), inspect.bind(1, "record"))
			add_button("看看旧鞋", show_page.bind("shoes"))
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
			add_button("收下第二封信", show_page.bind("letter2"))
		"street":
			add_button("看看旧磁带" + (" ✓" if observed[0] else ""), inspect.bind(0, "tape"))
			add_button("看看搬家清单" + (" ✓" if observed[1] else ""), inspect.bind(1, "list"))
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
	var letter_page := page.begins_with("letter")
	prose.position = Vector2(355, 82) if letter_page else Vector2(50, 472)
	prose.size = Vector2(224, 285) if letter_page else Vector2(862, 68)
	prose.modulate = Color("#483c32") if letter_page else PAPER
	prose.add_theme_font_size_override("font_size", 18 if letter_page else 19)
	var options := buttons.get_children()
	var index := clampi(focus_slot, 0, options.size()-1) if was == page else 0
	if not options[index].disabled: options[index].grab_focus()
	else:
		for option in options:
			if not option.disabled:
				option.grab_focus()
				break
	queue_redraw()

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
	click_sound(1.4)
	mirrors[index] = not mirrors[index]
	lit = mirrors[0] and mirrors[1]
	show_page("night")

func begin_street():
	observed = [false, false]
	show_page("street")

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
		show_page("rewind", "留言：“阿棠，明天下午两点，桥下等。”")
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
	if mirrors[0]:
		draw_line(FIRST, SECOND, GOLD, 5, true)
		draw_line(SECOND, RECEIVER if mirrors[1] else Vector2(338, 114), GOLD, 5, true)
	else:
		draw_line(FIRST, Vector2(435, 315), GOLD, 5, true)
	for i in 2:
		var pos := FIRST if i == 0 else SECOND
		art(MIRROR, Rect2(pos - Vector2(25, 25), Vector2(50, 50)))
		var diagonal := Vector2(11, -11) if mirrors[i] else Vector2(11, 11)
		draw_line(pos - diagonal, pos + diagonal, PAPER, 4, true)
		label(pos + Vector2(25, 12), str(i + 1), 18)
	draw_circle(SOURCE, 8, GOLD)
	draw_circle(RECEIVER, 11, GOLD if lit else Color("#627589"))
	label(SOURCE + Vector2(-32, 43), "起点", 17)
	label(RECEIVER + Vector2(-22, 42), "路灯", 17)

func _draw():
	var background: Texture2D = DAY
	var feature: Texture2D
	var title := ""
	var body := ""
	match page:
		"day":
			title = "第二幕 · 白昼与提灯人"
			body = "围挡上的通知说，秋千要拆了。傍晚前，先查清是谁在修它。"
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
			body = "灯亮了。照见了秋千旁那个人。" if lit else "让光依次经过两面镜子，照到右边的旧路灯。"
		"repair":
			background = REPAIR
			title = "老周 · 灯亮之后"
			body = "孩子们隔着围挡看了一眼就走了。灯照着秋千，老周手里的螺丝刀转了一圈，又一圈。"
		"zhou":
			background = REPAIR
			feature = SCREW
			title = "拧平的螺丝"
			body = "「我知道是我。」老周低下头，继续拧那颗已经拧平的螺丝。" if get_tree().get_meta("spoke_to_zhou",false) else "你把灯扶稳。老周说了声谢谢，又把螺丝刀抵进磨平的凹槽。"
		"street":
			background = STREET
			title = "第三幕 · 旧录音带里的夏日"
			body = "车快到了。老吴把电动车停在路口。唐棠儿子的新车已经到了。搬家箱底压着一盘没听完的磁带。"
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
			body = "「哦，原来约的两点。那天雨真大。」唐棠翻出这几年的照片。老吴一张也没认出来，只在她停下时点点头。"
		"farewell":
			background = FAREWELL
			title = "唐棠 · 搬家路口"
			body = "车门开着。唐棠说：「以后常联系。」老吴握住车把：「一定。」"
		"letter1","letter2","letter3":
			var number := int(page.right(1))
			background = [TOWN, REPAIR, FAREWELL][number-1]
			feature = LETTER
			title = "镇上来信 · 第%d封" % number
			body = LETTERS[number-1]
		"ending":
			background = GROUP
			title = "终章 · 小镇的灯火"
			body = "镇子现在很整齐。灯是亮的，路是平的，秋千没人玩了，所以也不会坏。我们从这里开始，都过得还不错"
		"credits","confirm_restart":
			background = TOWN
			title = "turn · 全剧终"
			body = "三封来信已经收好。" if page == "credits" else "从镇口重新开始会清除这次的章节进度。"

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
	draw_rect(Rect2(0, 425, 960, 175), Color("#20272e"))
	label(Vector2(50, 465), title, 24, GOLD)
	if page.begins_with("letter"):
		label(Vector2(50,510), "空格显示全文", 16, PAPER)
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
