extends Node2D

const INK = Color("#202a30")
const PAPER = Color("#f2e9d8")
const GOLD = Color("#ebc389")
const SPOTS = [Vector2(285,338), Vector2(705,360), Vector2(497,272)]
const NAMES = ["父亲", "女儿", "旧琴箱"]
const FRAGMENTS = ["我把琴弦换好了。", "要是上台前又断了，", "备用的在琴箱夹层。"]
var player := Vector2(482,436)
var heard := [false,false]
var repaired := false
var mode := "intro"
var pieces: Array[int] = []
var panel := Control.new()
var font := SystemFont.new()

func _ready():
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	add_child(panel)
	show_card("未寄出的信笺","女儿把琴箱推到门口。父亲按住箱盖：“今天先别走。”\n她松了手。屋里只剩墙上那只钟在响。",["走进房间"],[resume])

func resume():
	mode = "walk"
	clear_card()

func clear_card():
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	queue_redraw()

func show_card(title: String, body: String, choices: Array, actions: Array):
	clear_card()
	var bg := ColorRect.new()
	bg.color = Color("#263238")
	bg.position = Vector2(62,362)
	bg.size = Vector2(836,204)
	panel.add_child(bg)
	for item in [[title,23,GOLD,Vector2(85,376)],[body,18,PAPER,Vector2(85,414)]]:
		var label := Label.new()
		label.text = item[0]
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",item[1])
		label.modulate = item[2]
		label.position = item[3]
		panel.add_child(label)
	var x := 85.0
	for i in choices.size():
		var btn := Button.new()
		btn.text = choices[i]
		btn.add_theme_font_override("font",font)
		btn.add_theme_font_size_override("font_size",16)
		btn.position = Vector2(x,510)
		btn.custom_minimum_size = Vector2(90,38)
		panel.add_child(btn)
		btn.pressed.connect(actions[i])
		x += btn.get_combined_minimum_size().x + 15
		if i == 0:
			btn.grab_focus()

func _physics_process(delta):
	if mode != "walk":
		return
	var motion := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	motion += Vector2(int(Input.is_physical_key_pressed(KEY_D))-int(Input.is_physical_key_pressed(KEY_A)),int(Input.is_physical_key_pressed(KEY_S))-int(Input.is_physical_key_pressed(KEY_W)))
	player = (player + motion.limit_length() * 205 * delta).clamp(Vector2(104,282),Vector2(856,477))
	queue_redraw()

func nearest() -> int:
	var index := -1
	var dist := 83.0
	for i in SPOTS.size():
		var d := player.distance_to(SPOTS[i])
		if d < dist:
			index = i
			dist = d
	return index

func _unhandled_key_input(event):
	if mode == "walk" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and nearest() >= 0:
		interact(nearest())
		get_viewport().set_input_as_handled()

func interact(i: int):
	mode = "dialogue"
	if i < 2:
		if repaired and i == 1:
			show_card("女儿 · 等在门边","她的目光落在你手里的纸上。",["把纸条递给她","把纸条放回琴箱"],[finish.bind(true),finish.bind(false)])
		else:
			heard[i] = true
			var line := "“她说我藏了报名表。可我昨晚开琴箱的时候，连一根好弦都没剩。”" if i == 0 else "“他年轻时也弹琴。他知道报名只到今天。\n可我每次问他，他都只说，再等等。”"
			show_card(NAMES[i],line,["继续调查"],[resume])
	elif repaired:
		show_card("旧琴箱","夹层里有一包新琴弦。把拼好的纸条带给女儿吧。",["合上箱盖"],[resume])
	elif heard.has(false):
		show_card("旧琴箱","箱扣刚上过油，旁边散着几片纸。先听听父女各自怎么说。",["放下箱盖"],[resume])
	else:
		pieces.clear()
		puzzle()

func puzzle(note := ""):
	mode = "puzzle"
	var words := PackedStringArray()
	var buttons: Array = []
	var actions: Array = []
	for id in pieces:
		words.append(FRAGMENTS[id])
	for id in [2,0,1]:
		if not pieces.has(id):
			buttons.append(FRAGMENTS[id])
			actions.append(pick.bind(id))
	if not pieces.is_empty():
		buttons.append("重新排列")
		actions.append(reset_puzzle)
	show_card("琴箱夹层 · 拼回父亲的便签","按语意依次选取纸片。"+note+"\n"+"".join(words),buttons,actions)

func reset_puzzle():
	pieces.clear()
	puzzle()

func pick(id: int):
	pieces.append(id)
	if pieces.size() < 3:
		puzzle()
	elif pieces == [0,1,2]:
		repaired = true
		show_card("获得 · 拼好的便签","“我把琴弦换好了。要是上台前又断了，备用的在琴箱夹层。”\n落款被划掉了。那个歪歪扭扭的‘琴’字，你刚在父亲的工具盒上见过。",["收好便签"],[resume])
	else:
		pieces.clear()
		puzzle("  读起来有些断续，换个顺序试试。")

func finish(hand_over: bool):
	mode = "end"
	var title := "回响之一 · 门口的二重奏" if hand_over else "回响之二 · 留给明天"
	var body := "女儿读完纸条，把琴递过去：“爸，你听听准不准？”\n他拨了一个和弦，把门打开：“路上慢点。”" if hand_over else "她拿起琴箱时，纸角从夹层露了出来。\n父亲在门口站了一会儿。楼梯间传来她试弦的声音。"
	show_card(title,body,["重新开始"],[restart])

func restart():
	get_tree().reload_current_scene()

func txt(p: Vector2,s: String,sz: int,c: Color):
	draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,c)

func rect(x,y,w,h,c):
	draw_rect(Rect2(x,y,w,h),Color(c))

func person(p: Vector2,coat: Color):
	draw_set_transform(p,0,Vector2.ONE)
	draw_set_transform(p,0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,22,Color("#806e61"))
	draw_set_transform(p,0,Vector2.ONE)
	rect(-11,-14,8,15,"#343a3c")
	rect(3,-14,8,15,"#343a3c")
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-43),Vector2(10,-43),Vector2(16,-13),Vector2(-15,-13)]),coat)
	draw_circle(Vector2(0,-49),12,Color("#e1b699"))
	draw_arc(Vector2(0,-49),10,PI,TAU,18,Color("#494040"),7,true)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _draw():
	txt(Vector2(66,50),"turn   /   未寄出的信笺",28,PAPER)
	txt(Vector2(69,82),"旧宅   ·   午后",16,GOLD)
	rect(68,107,824,128,"#a59d8b")
	rect(68,232,824,266,"#c4ac91")
	for y in range(239,498,33):
		draw_line(Vector2(68,y),Vector2(892,y),Color("#af9882"),1)
		for x in range(76 + ((y-239)/33 as int)%2*69,890,140):
			draw_line(Vector2(x,y),Vector2(x,min(y+32,498)),Color("#b59c85"))
	rect(68,224,824,11,"#71675e")
	rect(135,121,141,87,"#655e53")
	rect(140,126,131,77,"#c5d8d3")
	rect(203,126,5,77,"#736c60")
	rect(140,161,131,4,"#736c60")
	draw_colored_polygon(PackedVector2Array([Vector2(141,235),Vector2(270,235),Vector2(405,325),Vector2(240,325)]),Color("#d7c2a0"))
	rect(740,123,80,103,"#776e62")
	rect(746,129,68,96,"#958471")
	draw_circle(Vector2(804,179),3,GOLD)
	rect(446,241,102,34,"#765947")
	rect(449,236,96,29,"#514c46")
	rect(466,250,7,7,"#d4b782")
	rect(522,250,7,7,"#d4b782")
	person(SPOTS[0],Color("#56697b"))
	person(SPOTS[1],Color("#ab6351"))
	person(player,Color("#668574"))
	for i in 3:
		txt(SPOTS[i]+Vector2(-22,23),NAMES[i],15,INK)
	if mode == "walk":
		var n := nearest()
		if n >= 0:
			txt(SPOTS[n]+Vector2(-34,-70),"[E] 调查" if n==2 else "[E] 交谈",18,INK)
		var goal := "分别听父女讲述  %d / 2" % (int(heard[0])+int(heard[1]))
		if repaired:
			goal = "带着便签回到女儿身边"
		elif not heard.has(false):
			goal = "调查墙边的旧琴箱"
		txt(Vector2(70,546),goal,22,GOLD)
		txt(Vector2(70,578),"WASD / 方向键移动     E 互动     鼠标选择",16,PAPER)
