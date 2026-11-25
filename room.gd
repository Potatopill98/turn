extends Node2D

const Progress = preload("res://chapter_progress.gd")

const TravelerArt = preload("res://traveler_art.gd")
const ROOM_ART = preload("res://art/00_场景/05_旧宅原型底图_960x600.png")
const CASE_ART = preload("res://art/06_道具_第一幕/上锁的旧吉他箱.png")
const NPC_ART = [
	preload("res://art/03_角色_镇民/陈守业_父亲.png"),
	preload("res://art/03_角色_镇民/陈小满_女儿.png"),
]
const NPC_REGIONS = [Rect2(215, 68, 313, 906), Rect2(224, 45, 296, 928)]
const PORTRAITS = [
	preload("res://art/04_对话头像/陈守业_冲突或停顿.png"),
	preload("res://art/04_对话头像/陈小满_冲突或停顿.png"),
]
const ARGUMENT = preload("res://art/09_来信与插帧/女儿摔门后父亲捡谱.png")
const CHANGED = preload("res://art/04_对话头像/陈小满_转变之后.png")
const INK = Color("#202a30")
const PAPER = Color("#f2e9d8")
const GOLD = Color("#ebc389")
const SCORE_SPOTS = [Vector2(661, 406), Vector2(512, 447), Vector2(373, 392)]
const SPOTS = [Vector2(285,338), Vector2(705,360), Vector2(497,272), Vector2(175,422)]
const NAMES = ["父亲", "女儿", "旧琴箱", "碎纸"]
const FORM = preload("res://art/06_道具_第一幕/演艺参赛报名表.png")
const PHOTO = preload("res://art/06_道具_第一幕/拼合用的老照片.png")
const CALLBACK_NOTICE = preload("res://art/06_道具_第一幕/省歌舞团复试通知.png")
const SAVINGS = preload("res://art/06_道具_第一幕/双人户名的旧存折.png")
var collecting_score := false
var score_collected := [false, false, false]
var found_form := false
var fixed_form := false
var selected_piece := -1
var swapped_slots := Vector2i(-1, -1)
var fixing_photo := false
const WORLD_ZOOM := 1.48
const ROOM_BOUNDS := Rect2(68, 106, 824, 394)
var world := Node2D.new()
var camera_focus := Vector2.ZERO
var move_speed := Vector2.ZERO
var walk_phase := 0.0
var step_meter := 0.0
var footstep := AudioStreamPlayer.new()
var instrument := AudioStreamPlayer.new()
var step_strength := 0.0
var pickup_at := Vector2.ZERO
var pickup_timer := 0.0
var dialogue_body: Label
var deposit_marks: Array[int] = []
var reveal_time := 0.0
var player := Vector2(780,299)
var direction := 1
var heard := [false,false]
var repaired := false
var mode := "intro"
var pieces: Array[int] = []
var showing_insert := false
var panel := Control.new()
var font := SystemFont.new()

func _ready():
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	Progress.mark(get_tree(), "room")
	footstep.stream = preload("res://audio/prologue/wood.wav")
	footstep.volume_db = -18
	add_child(footstep)
	instrument.stream = preload("res://audio/trial_chord.wav")
	instrument.volume_db = -10
	add_child(instrument)
	world.z_index = -1
	world.scale = Vector2.ONE * WORLD_ZOOM
	world.draw.connect(draw_world)
	add_child(world)
	camera_focus = camera_target()
	update_camera()
	add_child(panel)
	show_card("未寄出的信笺","小满扶着琴箱：“今天是报名最后一天。”\n守业扣住箱盖：“报名表我收起来了。你上次也说只去一天。”",["继续"],[door_slams],null,PORTRAITS[1])

func door_slams():
	show_card("摔门","小满抽出压在箱底的琴谱，一下没拿住，三页散在地板上。她转身出了门。\n守业没追。他弯下腰，把散开的谱子往自己这边够。",["帮他捡琴谱"],[begin_collecting])

func begin_collecting():
	collecting_score = true
	resume()

func collect_score(index: int):
	score_collected[index] = true
	pickup_at = SCORE_SPOTS[index]
	pickup_timer = 0.55
	if not score_collected.has(false):
		collecting_score = false
		show_card("最后一页","守业蹲在地上，把折角慢慢抚平，按页码叠好。\n“她练这一段练了半年。纸皱成这样，上台怎么翻？”",["把琴谱递过去"],[after_score], ARGUMENT)
	queue_redraw()

func after_score():
	show_card("门口","门又开了。小满回屋来拿琴。守业把谱放到门边，低声说：“先试试弦。”",["听听他们怎么说"],[resume],null,CHANGED)

func current_spots() -> Array:
	return SCORE_SPOTS if collecting_score else SPOTS


func resume():
	mode = "walk"
	move_speed = Vector2.ZERO
	clear_card()

func clear_card():
	showing_insert = false
	dialogue_body = null
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	queue_redraw()

func show_card(title: String, body: String, choices: Array, actions: Array, illustration: Texture2D = null, portrait: Texture2D = null):
	clear_card()
	if illustration:
		showing_insert = true
		show_picture(illustration, Vector2(62, 72), Vector2(836, 280))
	if portrait:
		show_picture(portrait, Vector2(760, 380), Vector2(116, 173))
	var bg := ColorRect.new()
	bg.color = Color("#263238")
	bg.position = Vector2(62,362)
	bg.size = Vector2(836,204)
	panel.add_child(bg)
	panel.move_child(bg, 0)
	for item in [[title,23,GOLD,Vector2(85,376)],[body,18,PAPER,Vector2(85,414)]]:
		var label := Label.new()
		label.text = item[0]
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",item[1])
		label.modulate = item[2]
		label.position = item[3]
		if item[0] == body:
			label.size.x = 656 if portrait else 790
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(label)
		if item[0] == body:
			dialogue_body = label
			label.visible_characters = 0
			reveal_time = 0.0
	var x := 85.0
	for i in choices.size():
		var btn := Button.new()
		btn.text = choices[i]
		btn.add_theme_font_override("font",font)
		btn.add_theme_font_size_override("font_size",16)
		btn.position = Vector2(x,510)
		btn.custom_minimum_size = Vector2(90,38)
		panel.add_child(btn)
		btn.pressed.connect(advance_card.bind(actions[i]))
		x += btn.get_combined_minimum_size().x + 15
		if i == 0:
			btn.grab_focus()

	var entrance := create_tween()
	panel.modulate.a = 0.0
	entrance.tween_property(panel, "modulate:a", 1.0, 0.16).from(0.0)

func advance_card(action: Callable):
	if dialogue_body and dialogue_body.visible_ratio < 1.0:
		dialogue_body.visible_characters = -1
		return
	action.call()

func _process(delta: float):
	if dialogue_body and dialogue_body.visible_ratio < 1.0:
		reveal_time += delta
		dialogue_body.visible_characters = int(reveal_time * 48.0)
	pickup_timer = maxf(pickup_timer - delta, 0.0)
	camera_focus = camera_focus.lerp(camera_target(), 1.0 - exp(-9.0 * delta))
	update_camera()
	world.visible = not showing_insert
	world.queue_redraw()

func camera_target() -> Vector2:
	var half_view := Vector2(480.0, 255.0) / WORLD_ZOOM
	var focus := player - Vector2(0, 46)
	var aim := camera_focus.clamp(focus - Vector2(44, 22), focus + Vector2(44, 22))
	return aim.clamp(ROOM_BOUNDS.position + half_view, ROOM_BOUNDS.end - half_view)

func update_camera():
	world.position = Vector2(480.0, 255.0) - camera_focus * WORLD_ZOOM

func show_picture(texture: Texture2D, pos: Vector2, dimensions: Vector2):
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = texture
	picture.position = pos
	picture.size = dimensions
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(picture)

func _physics_process(delta):
	if mode != "walk":
		return
	var motion := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	motion += Vector2(int(Input.is_physical_key_pressed(KEY_D))-int(Input.is_physical_key_pressed(KEY_A)),int(Input.is_physical_key_pressed(KEY_S))-int(Input.is_physical_key_pressed(KEY_W)))
	direction = TravelerArt.facing(motion, direction)
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
	var desired_speed := motion.limit_length() * (286.0 if sprint else 195.0)
	var acceleration := 2200.0 if motion.is_zero_approx() else 1500.0
	move_speed = move_speed.move_toward(desired_speed, acceleration * delta)
	var previous := player
	player = (player + move_speed * delta).clamp(Vector2(104,282),Vector2(856,477))
	var distance := player.distance_to(previous)
	step_meter += distance
	if step_meter >= person_height(player.y) * 0.49:
		step_meter = 0.0
		footstep.pitch_scale = 0.96 if int(walk_phase) % 4 < 2 else 1.04
		footstep.play()
	walk_phase += distance / (person_height(player.y) * 0.49) * 2.0
	step_strength = 1.0 if distance > 0.02 else 0.0
	queue_redraw()

func nearest() -> int:
	var index := -1
	var dist := 83.0
	var spots := current_spots()
	for i in spots.size():
		if collecting_score and score_collected[i]: continue
		if not collecting_score and i == 3 and fixed_form: continue
		var d := player.distance_to(spots[i])
		if d < dist:
			index = i
			dist = d
	return index

func _unhandled_key_input(event):
	if mode == "puzzle" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
		swap_piece(event.physical_keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		if dialogue_body and dialogue_body.visible_ratio < 1.0:
			dialogue_body.visible_characters = -1
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I and mode in ["walk", "journal"]:
		if mode == "journal":
			resume()
		else:
			journal()
		get_viewport().set_input_as_handled()
		return
	if mode == "walk" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and nearest() >= 0:
		if collecting_score:
			collect_score(nearest())
		else:
			interact(nearest())
		get_viewport().set_input_as_handled()

func interact(i: int):
	mode = "dialogue"
	if i == 3:
		found_form = true
		if fixed_form:
			show_card("窗边","碎纸已经收进手记。",["返回"],[resume])
		else:
			start_puzzle(false)
	elif i < 2:
		if repaired and i == 1:
			show_card("女儿 · 等在门边","她认出了存折封皮：“他也给你看了？”",["翻开存折，让她看日期","合上存折，只说琴修好了"],[finish.bind(true),finish.bind(false)], null, CHANGED)
		else:
			heard[i] = true
			var line := "“弦是我昨晚换的。报名表也是我收的。她去了，受了气，谁替她收拾？”" if i == 0 else "“我走过三回。四月十二、七月三号、九月十七，他每回都到车站把我叫回来。\n这回我只想自己决定。”"
			show_card(NAMES[i],line,["继续调查"],[resume], null, PORTRAITS[i])
	elif repaired:
		show_card("旧琴箱","琴箱夹层里放着换下的旧弦。去找小满谈谈吧。",["合上箱盖"],[resume])
	elif heard.has(false) or not fixed_form:
		show_card("旧琴箱","夹层里露出一角相纸。先问问父女两人，再把窗边的碎纸拼起来。",["继续调查"],[resume])
	else:
		start_puzzle(true)

func journal():
	mode = "journal"
	var lines := PackedStringArray()
	if get_tree().has_meta("prologue_diary"):
		lines.append("旧日记 · " + str(get_tree().get_meta("prologue_diary")))
	if heard[0]: lines.append("陈守业说，他昨晚开过琴箱。")
	if heard[1]: lines.append("小满三次被叫回的日子 · 4/12、7/3、9/17。")
	if found_form: lines.append("报名表 · 已拼好" if fixed_form else "报名表 · 还需要拼合")
	if repaired: lines.append("老照片、备用琴弦和写着两个人名字的存折都在夹层里。")
	show_card("归乡手记", "　".join(lines) if not lines.is_empty() else "还没有记下线索。", ["收起手记"], [resume])

func start_puzzle(photo: bool):
	if pieces.is_empty() or fixing_photo != photo:
		pieces.assign([2, 0, 1] if photo else [1, 2, 0])
	fixing_photo = photo
	selected_piece = -1
	puzzle()

func puzzle():
	mode = "puzzle"
	var texture: Texture2D = PHOTO if fixing_photo else FORM
	show_card("琴箱里的老照片" if fixing_photo else "窗边的报名表",
		"点击两块碎片，或按 1–3 交换。沿着吉他和照片边缘拼回原图。" if fixing_photo else "点击两块碎片，或按 1–3 交换。对齐表格横线和纸边，修好报名表。",
		["先收起来"], [resume])
	showing_insert = true
	var image_size := texture.get_size()
	var scale_factor := minf(620.0 / image_size.x, 274.0 / image_size.y)
	var piece_size := Vector2(image_size.x / 3.0, image_size.y) * scale_factor
	var start_x := (960.0 - piece_size.x * 3 - 12.0) / 2
	for slot in 3:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(pieces[slot] * image_size.x / 3, 0, image_size.x / 3, image_size.y)
		var button := TextureButton.new()
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.texture_normal = atlas
		button.size = piece_size
		var target_pos := Vector2(start_x + slot * (piece_size.x + 6), 78)
		button.position = target_pos
		if slot in [swapped_slots.x, swapped_slots.y]:
			var old_slot := swapped_slots.y if slot == swapped_slots.x else swapped_slots.x
			button.position.x = start_x + old_slot * (piece_size.x + 6)
			var slide := button.create_tween()
			slide.tween_property(button, "position", target_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		button.modulate = GOLD if selected_piece == slot else Color.WHITE
		button.tooltip_text = "碎片 %d" % (slot + 1)
		panel.add_child(button)
		button.pressed.connect(swap_piece.bind(slot))
	swapped_slots = Vector2i(-1, -1)
	queue_redraw()

func swap_piece(slot: int):
	if selected_piece < 0:
		selected_piece = slot
	else:
		swapped_slots = Vector2i(selected_piece, slot)
		var previous := pieces[selected_piece]
		pieces[selected_piece] = pieces[slot]
		pieces[slot] = previous
		selected_piece = -1
	if pieces != [0,1,2]:
		puzzle()
		return
	pieces.clear()
	swapped_slots = Vector2i(-1, -1)
	mode = "evidence"
	if fixing_photo:
		show_card("照片背后","照片上的少年抱着同一把琴。照片背后，还粘着一张折旧的通知。",["展开复试通知"],[read_notice],PHOTO)
	else:
		fixed_form = true
		show_card("修好的报名表","参赛人是小满。背面用铅笔抄着末班车时间，还有一句：“备用弦在夹层，到那边也能换。”",["记入手记"],[resume],FORM)
		var signature := Label.new()
		var pen := SystemFont.new()
		pen.font_names = PackedStringArray(["KaiTi","STKaiti","Microsoft YaHei"])
		signature.text = "家长签名　陈守业"
		signature.add_theme_font_override("font",pen)
		signature.add_theme_font_size_override("font_size",21)
		signature.modulate = GOLD
		signature.position = Vector2(618, 317)
		panel.add_child(signature)

func read_notice():
	show_card("省歌舞团复试通知","三十年前，陈守业，二十岁。父亲盯着报到日期：“我没敢去。后来总跟她说，是为了这个家。”",["查看夹层里的存折"],[discover_savings],CALLBACK_NOTICE)

func discover_savings():
	mode = "dates"
	var captions := PackedStringArray(["3 月 8 日", "4 月 12 日", "7 月 3 日", "8 月 29 日", "9 月 17 日"])
	var choices: Array = []
	var actions: Array = []
	for index in captions.size():
		choices.append(("• " if index in deposit_marks else "") + captions[index])
		actions.append(mark_deposit.bind(index))
	var guidance := "户名是陈守业和陈小满。标出她三次被叫回当天的存款。"
	if deposit_marks.size() == 3:
		choices.append("核对")
		actions.append(compare_dates.bind(deposit_marks.has(1) and deposit_marks.has(2) and deposit_marks.has(4)))
	else:
		choices.append("看手记")
		actions.append(date_hint)
	show_card("两个人的存折", guidance, choices, actions, SAVINGS)
	dialogue_body.visible_characters = -1

func mark_deposit(index: int):
	if deposit_marks.has(index):
		deposit_marks.erase(index)
	elif deposit_marks.size() < 3:
		deposit_marks.append(index)
	discover_savings()

func date_hint():
	show_card("小满的话", "“四月十二、七月三号、九月十七，他每回都到车站把我叫回来。”", ["返回存折"], [discover_savings])

func compare_dates(matches: bool):
	if not matches:
		deposit_marks.clear()
		show_card("再看一眼日期","小满提到的是三次离开小镇。父亲每一次去车站找过她。",["重新比对"],[discover_savings],SAVINGS)
		return
	repaired = true
	show_card("日期一一对上了","每次小满被叫回，存折上就多一笔。存折夹在父亲换好的琴弦下面。\n带着它去找小满，决定要不要把日期给她看。",["收好存折"],[resume],SAVINGS)

func finish(hand_over: bool):
	mode = "end"
	if hand_over:
		show_card("给小满看日期","你把存折摊开，手指停在三笔记录上。小满一笔笔看过去，父亲把手搭在封皮上。",["听小满怎么说"],[show_ending.bind(true)],SAVINGS)
	else:
		show_card("把存折合上","你把存折合上，留在琴箱旁，只告诉她琴已经修好了。小满把琴抱到自己腿上。",["听她试弦"],[show_ending.bind(false)],null,CHANGED)

func show_ending(hand_over: bool):
	if not hand_over: instrument.play()
	mode = "end"
	var title := "回响之一 · 存款日期" if hand_over else "回响之二 · 留给明天"
	var body := "小满指着日期：“你每带我回来一次，就往里存一笔。爸，这钱到底是给谁的？”\n父亲伸手想合上存折。小满先松了手。" if hand_over else "你合上存折。小满拨了下新弦：“这回准了。”父亲把最后一页琴谱递给她。\n她接过来，两人低头对了一遍页码。"
	get_tree().set_meta("shared_note", hand_over)
	show_card(title,body,["继续 · 白昼与提灯人","从镇口重玩"],[next_chapter,confirm_restart.bind(hand_over)], ending_illustration(hand_over), CHANGED if not hand_over else PORTRAITS[1])

func ending_illustration(hand_over: bool) -> Texture2D:
	var name := "chapter1_dates" if hand_over else "chapter1_tuning"
	var path := "res://art/09_来信与插帧/%s.png" % name
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	return SAVINGS if hand_over else null

func next_chapter():
	get_tree().set_meta("entry_chapter","letter1")
	Progress.mark(get_tree(), "letter1")
	get_tree().change_scene_to_file("res://later_chapters.tscn")

func confirm_restart(hand_over: bool):
	show_card("回到镇口", "从头重玩会清除章节进度。", ["继续当前故事","从头重玩"], [show_ending.bind(hand_over),restart])

func restart():
	Progress.fresh(get_tree())
	get_tree().change_scene_to_file("res://prologue.tscn")

func txt(p: Vector2,s: String,sz: int,c: Color):
	draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,c)

func person_height(feet_y: float) -> float:
	return lerpf(96.0, 136.0, clampf((feet_y - 235.0) / 242.0, 0.0, 1.0))

func draw_npc(index: int):
	var foot: Vector2 = SPOTS[index]
	var region: Rect2 = NPC_REGIONS[index]
	var height := person_height(foot.y) * (1.02 if index == 0 else 0.97)
	var size := Vector2(height * region.size.x / region.size.y, height)
	world.draw_texture_rect_region(NPC_ART[index], Rect2(foot - Vector2(size.x / 2, size.y), size), region)

func _draw():
	if showing_insert:
		txt(Vector2(66, 50), "turn   /   未寄出的信笺", 28, PAPER)
		return
	draw_rect(Rect2(0, 0, 960, 54), Color(0.10, 0.13, 0.15, 0.94))
	txt(Vector2(25, 35), "旧宅  /  未寄出的信笺", 22, PAPER)
	if mode != "walk":
		return
	var goal := "分别听父女讲述  %d / 2" % heard.count(true)
	if collecting_score:
		goal = "帮父亲找齐琴谱  %d / 3" % score_collected.count(true)
	elif repaired:
		goal = "带着存折回到小满身边"
	elif not heard.has(false):
		goal = "调查墙边的旧琴箱" if fixed_form else "调查窗边的碎纸"
	draw_rect(Rect2(0, 510, 960, 90), INK)
	txt(Vector2(25, 548), goal, 22, GOLD)
	txt(Vector2(25, 577), "WASD / 方向键移动   Shift 快走   E 互动   I 手记", 16, PAPER)

func world_text(at: Vector2, caption: String, size: int, color: Color):
	world.draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func draw_world():
	world.draw_texture_rect_region(ROOM_ART, ROOM_BOUNDS, ROOM_BOUNDS)
	world.draw_texture_rect_region(CASE_ART, Rect2(464, 248, 66, 27), Rect2(56, 246, 914, 373))
	for index in 2:
		if (index == 0 or not collecting_score) and player.y >= SPOTS[index].y:
			draw_npc(index)
	var moving := step_strength if mode == "walk" else 0.0
	if moving > 0:
		TravelerArt.draw_walk(world, player, direction, person_height(player.y), int(walk_phase) % 4)
	else:
		TravelerArt.draw(world, player, direction, person_height(player.y))
	for index in 2:
		if (index == 0 or not collecting_score) and player.y < SPOTS[index].y:
			draw_npc(index)
	if collecting_score:
		draw_score_pickups()
		return
	if not fixed_form:
		world.draw_texture_rect(FORM, Rect2(162, 395, 26, 32), false)
	if mode != "walk":
		return
	var target := nearest()
	if target >= 0:
		var spot: Vector2 = SPOTS[target]
		var caption: String = "E  " + NAMES[target]
		var offset := 49.0 if target >= 2 else person_height(spot.y) + 10.0
		draw_prompt(spot - Vector2(0, offset), caption)

func draw_prompt(center: Vector2, caption: String):
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	world.draw_rect(Rect2(center - Vector2(width / 2.0 + 7, 15), Vector2(width + 14, 22)), INK)
	world_text(center - Vector2(width / 2.0, 0), caption, 13, PAPER)

func draw_score_pickups():
	var nearest_page := nearest()
	for index in SCORE_SPOTS.size():
		if score_collected[index]:
			continue
		var spot: Vector2 = SCORE_SPOTS[index]
		var sheet := Rect2(spot - Vector2(11, 16), Vector2(22, 16))
		world.draw_rect(sheet, GOLD if index == nearest_page else PAPER)
		world.draw_rect(sheet, INK, false, 1)
		for line in range(3):
			var start := sheet.position + Vector2(3, 4 + line * 4)
			world.draw_line(start, start + Vector2(15, 0), INK)
		if index == nearest_page:
			draw_prompt(spot - Vector2(0, 36), "E  捡琴谱")
	if pickup_timer > 0.0:
		var rise := (0.55 - pickup_timer) * 46.0
		world_text(pickup_at - Vector2(25, 23 + rise), "琴谱 +1", 13, Color(GOLD, pickup_timer / 0.55))