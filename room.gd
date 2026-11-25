extends Node2D

const Progress = preload("res://chapter_progress.gd")
const Data = preload("res://scripts/turn_data.gd")
const EvidencePanel = preload("res://ui/evidence_panel.gd")
const TitleCard = preload("res://ui/title_card.gd")
const ChapterPlayer = preload("res://ui/chapter_player.gd")

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
const SPOTS = [Vector2(285,338), Vector2(705,360), Vector2(497,272), Vector2(175,422), Vector2(590,420)]
const NAMES = ["父亲", "女儿", "旧琴箱", "碎纸", "便签"]
const NOTE_ART = preload("res://art/06_道具_第一幕/便签_完整母图_768x512.png")
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
var note_fixed: bool = false
var note_pieces: Array[int] = []
var note_selected: int = -1
var note_swapped: Vector2i = Vector2i(-1, -1)
var savings_left: int = -1
var savings_pairs: Array[Vector2i] = []
var savings_right_order: Array[int] = [2, 0, 1]
var savings_layer: Control
var evidence_layer: CanvasLayer
var title_card: CanvasLayer
var hint_timer: float = 0.0
var savings_message: String = ""
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
var chapter_player: CanvasLayer
var _dream_seen: bool = false

func _ready():
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	TurnState.start_act("A1")
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
	title_card = TitleCard.new()
	add_child(title_card)
	evidence_layer = EvidencePanel.new()
	add_child(evidence_layer)
	chapter_player = ChapterPlayer.new()
	add_child(chapter_player)
	chapter_player.play("first", _begin_act)

func _begin_act() -> void:
	title_card.show_act("A1", 1.5)
	await title_card.finished
	if not is_inside_tree():
		return
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
		TurnState.unlock_item("e_score")
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
		if collecting_score and i < score_collected.size() and score_collected[i]: continue
		if not collecting_score and i == 3 and fixed_form: continue
		if not collecting_score and i == 4 and note_fixed: continue
		var d := player.distance_to(spots[i])
		if d < dist:
			index = i
			dist = d
	return index

func _unhandled_key_input(event):
	if mode == "puzzle" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6]:
		swap_piece(event.physical_keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		if dialogue_body and dialogue_body.visible_ratio < 1.0:
			dialogue_body.visible_characters = -1
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		JournalUI.toggle()
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
			TurnState.unlock_item("e_form")
			show_card("窗边","碎纸已经收进手记。",["返回"],[resume])
		else:
			start_puzzle(false)
	elif i == 4:
		if note_fixed:
			TurnState.unlock_item("e_note")
			show_card("琴箱旁","三片便签已经拼好。上面只有一行字：备用弦在夹层，到那边也能换。",["记入手记"],[resume], NOTE_ART)
		else:
			start_note_puzzle()
	elif i < 2:
		if repaired and i == 1:
			open_evidence()
		else:
			heard[i] = true
			TurnState.unlock_person("p_shouye" if i == 0 else "p_xiaoman")
			var line := "“弦是我昨晚换的。报名表也是我收的。她去了，受了气，谁替她收拾？”" if i == 0 else "“我走过三回。四月十二、七月三号、九月十七，他每回都到车站把我叫回来。\n这回我只想自己决定。”"
			TurnState.push_backlog(NAMES[i], line)
			show_card(NAMES[i],line,["继续调查"],[resume], null, PORTRAITS[i])
	elif repaired:
		TurnState.unlock_item("e_shell")
		show_card("旧琴箱","琴箱夹层里放着换下的旧弦。去找小满谈谈吧。",["合上箱盖"],[resume])
	elif heard.has(false) or not fixed_form:
		TurnState.unlock_item("e_shell")
		show_card("旧琴箱","夹层里露出一角相纸。先问问父女两人，再把窗边的碎纸拼起来。",["继续调查"],[resume])
	else:
		TurnState.unlock_item("e_shell")
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

func start_note_puzzle() -> void:
	if note_pieces.is_empty():
		note_pieces.assign([2, 0, 1])
	note_selected = -1
	note_puzzle()

func note_puzzle() -> void:
	mode = "note"
	showing_insert = true
	clear_card()
	var board := ColorRect.new()
	board.color = PAPER
	board.position = Vector2(50, 70)
	board.size = Vector2(860, 478)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(board)
	var title := Label.new()
	title.text = "琴箱旁的三片便签"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = INK
	title.position = Vector2(70, 84)
	panel.add_child(title)
	var note := Label.new()
	note.text = "点击两片交换。纸边对上了，字才连得起来。"
	note.add_theme_font_override("font", font)
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color(0.35, 0.30, 0.24, 0.9)
	note.position = Vector2(70, 116)
	panel.add_child(note)
	var image_size := NOTE_ART.get_size()
	var scale_factor := minf(560.0 / image_size.x, 340.0 / image_size.y)
	var piece_size := Vector2(image_size.x / 3.0, image_size.y) * scale_factor
	var start_x := (960.0 - piece_size.x * 3.0 - 20.0) / 2.0
	for slot in 3:
		var atlas := AtlasTexture.new()
		atlas.atlas = NOTE_ART
		atlas.region = Rect2(note_pieces[slot] * image_size.x / 3.0, 0, image_size.x / 3.0, image_size.y)
		var button := _piece_button(atlas, piece_size, Vector2(start_x + slot * (piece_size.x + 10.0), 140))
		button.modulate = GOLD if note_selected == slot else Color.WHITE
		button.tooltip_text = "便签 %d" % (slot + 1)
		panel.add_child(button)
		button.pressed.connect(_note_select.bind(slot))
	var hint := Label.new()
	hint.text = "拼好后，琴箱夹层里那句话就能读全。"
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.32, 0.27, 0.21, 0.9)
	hint.position = Vector2(70, 500)
	panel.add_child(hint)
	var back := Button.new()
	back.text = "先收起来"
	back.add_theme_font_override("font", font)
	back.add_theme_font_size_override("font_size", 14)
	back.position = Vector2(720, 496)
	back.custom_minimum_size = Vector2(160, 36)
	panel.add_child(back)
	back.pressed.connect(resume)
	queue_redraw()

func _note_select(slot: int) -> void:
	if mode != "note":
		return
	if note_selected < 0:
		note_selected = slot
		note_puzzle()
		return
	var previous: int = note_pieces[note_selected]
	note_pieces[note_selected] = note_pieces[slot]
	note_pieces[slot] = previous
	note_selected = -1
	if note_pieces == [0, 1, 2]:
		note_fixed = true
		TurnState.unlock_item("e_note")
		show_card("三片便签","纸边对上了。三片连起来只有一行字：\n“备用弦在夹层，到那边也能换。”\n落款处画了一个很小的调音记号。",["记入手记"],[resume],NOTE_ART)
	else:
		note_puzzle()


func start_savings_puzzle() -> void:
	savings_left = -1
	savings_pairs.clear()
	savings_message = ""
	build_savings()

func build_savings() -> void:
	mode = "dates"
	showing_insert = true
	clear_card()
	var board := ColorRect.new()
	board.color = PAPER
	board.position = Vector2(50, 70)
	board.size = Vector2(860, 478)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(board)
	var title := Label.new()
	title.text = "两个人的存折"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = INK
	title.position = Vector2(72, 84)
	panel.add_child(title)
	var note := Label.new()
	note.text = "左边三个日期，右边三件事。把同一天发生的连起来。"
	note.add_theme_font_override("font", font)
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color(0.35, 0.30, 0.24, 0.9)
	note.position = Vector2(72, 116)
	panel.add_child(note)
	panel.add_child(_picture_rect(SAVINGS, Rect2(520, 74, 330, 96)))
	var dates := ["4 月 12 日", "7 月 3 日", "9 月 17 日"]
	var events := ["第一次买票，被他从车站叫回", "第二次报名，表被他收进箱底", "第三次试音，她在站台等到末班车"]
	for index in 3:
		var date_button := Button.new()
		date_button.text = dates[index]
		date_button.add_theme_font_override("font", font)
		date_button.add_theme_font_size_override("font_size", 17)
		date_button.position = Vector2(88, 196 + index * 72)
		date_button.custom_minimum_size = Vector2(220, 52)
		date_button.modulate = GOLD if savings_left == index else Color.WHITE
		date_button.disabled = _savings_left_paired(index)
		panel.add_child(date_button)
		date_button.pressed.connect(_pick_savings_left.bind(index))
	for slot in 3:
		var event_id: int = savings_right_order[slot]
		var event_button := Button.new()
		event_button.text = events[event_id]
		event_button.add_theme_font_override("font", font)
		event_button.add_theme_font_size_override("font_size", 14)
		event_button.position = Vector2(560, 196 + slot * 72)
		event_button.custom_minimum_size = Vector2(310, 52)
		event_button.disabled = _savings_right_paired(slot)
		panel.add_child(event_button)
		event_button.pressed.connect(_pick_savings_right.bind(slot))
	for pair in savings_pairs:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = GOLD
		line.points = PackedVector2Array([
			Vector2(312, 222 + pair.x * 72),
			Vector2(556, 222 + pair.y * 72)
		])
		panel.add_child(line)
	var feedback := Label.new()
	feedback.text = savings_message if not savings_message.is_empty() else "已经连上 %d / 3 条。" % savings_pairs.size()
	feedback.add_theme_font_override("font", font)
	feedback.add_theme_font_size_override("font_size", 14)
	feedback.modulate = Color("#b8564a") if not savings_message.is_empty() else Color(0.30, 0.26, 0.20, 0.9)
	feedback.position = Vector2(88, 430)
	panel.add_child(feedback)
	var journal_button := Button.new()
	journal_button.text = "看手记"
	journal_button.add_theme_font_override("font", font)
	journal_button.add_theme_font_size_override("font_size", 13)
	journal_button.position = Vector2(88, 492)
	journal_button.custom_minimum_size = Vector2(150, 34)
	panel.add_child(journal_button)
	journal_button.pressed.connect(JournalUI.open)
	var back := Button.new()
	back.text = "先收起来"
	back.add_theme_font_override("font", font)
	back.add_theme_font_size_override("font_size", 14)
	back.position = Vector2(720, 492)
	back.custom_minimum_size = Vector2(160, 34)
	panel.add_child(back)
	back.pressed.connect(resume)
	queue_redraw()

func _savings_left_paired(index: int) -> bool:
	for pair in savings_pairs:
		if pair.x == index:
			return true
	return false

func _savings_right_paired(slot: int) -> bool:
	for pair in savings_pairs:
		if pair.y == slot:
			return true
	return false

func _pick_savings_left(index: int) -> void:
	if _savings_left_paired(index):
		return
	savings_left = index
	savings_message = ""
	build_savings()

func _pick_savings_right(slot: int) -> void:
	if _savings_right_paired(slot):
		return
	if savings_left < 0:
		savings_message = "先选左边的日期，再选右边发生的事。"
		build_savings()
		return
	var event_id: int = savings_right_order[slot]
	if event_id == savings_left:
		savings_pairs.append(Vector2i(savings_left, slot))
		savings_left = -1
		savings_message = ""
		if savings_pairs.size() >= 3:
			repaired = true
			TurnState.unlock_item("e_savings")
			TurnState.push_backlog("你", "存折上的三个日期，对上小满三次被叫回的那天。")
			show_card("日期一一对上了","每次小满被叫回，存折上就多一笔。存折夹在父亲换好的琴弦下面。\n带着它去找小满，决定要不要把日期给她看。",["收好存折"],[resume],SAVINGS)
		else:
			build_savings()
	else:
		savings_left = -1
		savings_message = "这两条对不上。再想想她哪一次是真的已经走了。"
		build_savings()

func _picture_rect(texture: Texture2D, rect: Rect2) -> TextureRect:
	var view := TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture = texture
	view.position = rect.position
	view.size = rect.size
	view.custom_minimum_size = Vector2.ZERO
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

func _piece_button(atlas: AtlasTexture, piece_size: Vector2, at: Vector2) -> Button:
	var holder := Button.new()
	holder.flat = true
	holder.position = at
	holder.size = piece_size
	holder.custom_minimum_size = piece_size
	holder.focus_mode = Control.FOCUS_NONE
	var plate := ColorRect.new()
	plate.color = Color(0.875, 0.825, 0.735, 0.92)
	plate.position = Vector2.ZERO
	plate.size = piece_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(plate)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.custom_minimum_size = Vector2.ZERO
	icon.size = piece_size
	icon.position = Vector2.ZERO
	icon.texture = atlas
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	return holder

func start_puzzle(photo: bool):
	if pieces.is_empty() or fixing_photo != photo:
		if photo:
			pieces.assign([2, 5, 0, 4, 1, 3])
		else:
			pieces.assign([3, 0, 4, 1, 5, 2])
	fixing_photo = photo
	selected_piece = -1
	puzzle()

func puzzle():
	mode = "puzzle"
	var texture: Texture2D = PHOTO if fixing_photo else FORM
	show_card("琴箱里的老照片" if fixing_photo else "窗边的报名表",
		"点击两块碎片，或按 1–6 交换。沿着照片边缘和表格横线拼回原图。" if fixing_photo else "点击两块碎片，或按 1–6 交换。对齐表格横线和纸边，修好报名表。",
		["先收起来"], [resume])
	showing_insert = true
	var image_size := texture.get_size()
	var scale_factor := minf(620.0 / image_size.x, 268.0 / image_size.y)
	var piece_size := Vector2(image_size.x / 3.0, image_size.y / 2.0) * scale_factor
	var start_x := (960.0 - piece_size.x * 3.0 - 12.0) / 2
	for slot in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		var source_column: int = pieces[slot] % 3
		var source_row: int = pieces[slot] / 3
		atlas.region = Rect2(source_column * image_size.x / 3.0, source_row * image_size.y / 2.0, image_size.x / 3.0, image_size.y / 2.0)
		var column: int = slot % 3
		var row: int = slot / 3
		var button := _piece_button(atlas, piece_size, Vector2(start_x + column * (piece_size.x + 6.0), 66.0 + row * (piece_size.y + 6.0)))
		button.modulate = GOLD if selected_piece == slot else Color.WHITE
		button.tooltip_text = "碎片 %d" % (slot + 1)
		panel.add_child(button)
		button.pressed.connect(swap_piece.bind(slot))
	swapped_slots = Vector2i(-1, -1)
	queue_redraw()

func swap_piece(slot: int):
	if pieces.size() != 6:
		return
	if selected_piece < 0:
		selected_piece = slot
	else:
		swapped_slots = Vector2i(selected_piece, slot)
		var previous := pieces[selected_piece]
		pieces[selected_piece] = pieces[slot]
		pieces[slot] = previous
		selected_piece = -1
	if pieces != [0,1,2,3,4,5]:
		puzzle()
		return
	pieces.clear()
	swapped_slots = Vector2i(-1, -1)
	mode = "evidence"
	if fixing_photo:
		show_card("照片背后","照片上的少年抱着同一把琴。照片背后，还粘着一张折旧的通知。",["展开复试通知"],[read_notice],PHOTO)
	else:
		fixed_form = true
		TurnState.unlock_item("e_form")
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
	show_card("省歌舞团复试通知","三十年前，陈守业，二十岁。父亲盯着报到日期：“我没敢去。后来总跟她说，是为了这个家。”",["查看夹层里的存折"],[start_savings_puzzle],CALLBACK_NOTICE)
	TurnState.unlock_item("e_photo")
	TurnState.unlock_item("e_notice")

func open_evidence() -> void:
	mode = "evidence"
	if not _dream_seen:
		_dream_seen = true
		chapter_player.play("first_dream", _open_evidence_now)
		return
	_open_evidence_now()

func _open_evidence_now() -> void:
	mode = "evidence"
	evidence_layer.open("A1", _on_evidence_result)

func _on_evidence_result(stance: String, _item_id: String) -> void:
	mode = "end"
	finish(stance)

func finish(stance: String):
	mode = "end"
	if stance == "expose":
		show_card("给小满看日期","你把存折摊开，手指停在三笔记录上。小满一笔笔看过去，父亲把手搭在封皮上。",["听小满怎么说"],[show_ending.bind(stance)],SAVINGS)
	elif stance == "half":
		show_card("只说到签名","你把报名表翻到家长签名那一栏，没有翻存折。\n小满盯着那三个字看了很久：“他签得比我还工整。”",["听她怎么说"],[show_ending.bind(stance)],FORM)
	else:
		show_card("把存折合上","你把存折合上，留在琴箱旁，只告诉她琴已经修好了。小满把琴抱到自己腿上。",["听她试弦"],[show_ending.bind(stance)],null,CHANGED)

func show_ending(stance: String):
	var hand_over: bool = stance != "soft"
	if not hand_over: instrument.play()
	mode = "end"
	var title := "回响之一 · 存款日期"
	var body := ""
	if stance == "expose":
		title = "回响之一 · 存款日期"
		body = "小满指着日期：“你每带我回来一次，就往里存一笔。爸，这钱到底是给谁的？”\n父亲伸手想合上存折。小满先松了手。"
	elif stance == "half":
		title = "回响之二 · 签名那一栏"
		body = "小满把报名表放回琴箱：“你签了名，又把它收起来。你到底想让我去，还是不想？”\n父亲没答。他把琴弦又紧了一遍。"
	else:
		title = "回响之三 · 留给明天"
		body = "你合上存折。小满拨了下新弦：“这回准了。”父亲把最后一页琴谱递给她。\n她接过来，两人低头对了一遍页码。"
	get_tree().set_meta("shared_note", hand_over)
	TurnState.set_flag("a1_shared", hand_over)
	show_card(title,body,["继续 · 白昼与提灯人","从镇口重玩"],[next_chapter,confirm_restart.bind(hand_over)], ending_illustration(stance), CHANGED if not hand_over else PORTRAITS[1])

func ending_illustration(stance: String) -> Texture2D:
	var v3_name := "chapter1_quiet.png" if stance != "soft" else "chapter1_shared.png"
	var v3_path := "res://art/10_v3_待出图/04_剧情插帧/%s" % v3_name
	if ResourceLoader.exists(v3_path, "Texture2D"):
		return load(v3_path) as Texture2D
	if stance == "soft":
		return preload("res://art/06_道具_第一幕/打开的琴箱与换好的弦.png")
	return preload("res://art/09_来信与插帧/女儿摔门后父亲捡谱.png")

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
	txt(Vector2(25, 574), "WASD / 方向键移动   Shift 快走   E 互动   I 手记", 15, PAPER)
	if not note_fixed and not repaired:
		txt(Vector2(25, 594), "支线：琴箱旁的便签还能拼。", 12, Color(0.78, 0.67, 0.48, 0.9))

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
	if not note_fixed:
		world.draw_rect(Rect2(576, 398, 34, 26), PAPER)
		world.draw_rect(Rect2(576, 398, 34, 26), INK, false, 1)
		for line in 3:
			world.draw_line(Vector2(580, 405 + line * 6), Vector2(606, 405 + line * 6), INK)
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