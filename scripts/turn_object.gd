extends Control

signal finished(success: bool)

const Art = preload("res://scripts/placeholder_art.gd")
const PAPER := Color("#f1e5c8")
const DIM := Color("#b7c3b7")
const GOLD := Color("#f0c277")
var mode := ""
var position_index := 0
var played := false
var feedback := ""
var audio := AudioStreamPlayer.new()
var note_audio := AudioStreamWAV.new()
var noise_audio := AudioStreamWAV.new()
var pulse := 0.0
var stem := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(audio)
	note_audio = make_sound(false)
	noise_audio = make_sound(true)
	hide()

func make_sound(noise: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	var samples := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 36
	for i in 6200:
		var t := float(i) / 12000.0
		var level := rng.randf_range(-1, 1) if noise else sin(TAU * 440.0 * t) + 0.36 * sin(TAU * 660.0 * t)
		samples.append(int(level * 48.0 * minf(t * 120, 1) * exp(-7.5 * t)) & 255)
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 12000
	stream.data = samples
	return stream

func open(kind: String) -> void:
	mode = kind
	position_index = 9 if mode == "tape" else 0
	played = false
	feedback = ""
	pulse = 0.0
	stem = float(position_index)
	show()
	queue_redraw()

func ring(stream: AudioStreamWAV, volume: float, pitch: float) -> void:
	audio.stream = stream
	audio.volume_db = volume
	audio.pitch_scale = pitch
	audio.play()

func _process(delta: float) -> void:
	if not visible:
		return
	pulse = move_toward(pulse, 0.0, delta * 3.2)
	stem = lerpf(stem, float(position_index), 1.0 - exp(-14.0 * delta))
	queue_redraw()

func handle_key(code: int) -> bool:
	match code:
		KEY_A, KEY_LEFT: turn(-1)
		KEY_D, KEY_RIGHT: turn(1)
		KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: confirm()
		KEY_ESCAPE: close(false)
		_: return false
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in 3:
			if Rect2(213 + i * 182, 428, 170, 46).has_point(event.position):
				if i == 1:
					confirm()
				else:
					turn(i - 1)
				accept_event()
				return

func turn(amount: int) -> void:
	if played:
		return
	var next := clampi(position_index + amount, 0, 10) if mode == "tape" else 1 - position_index
	if next == position_index:
		return
	position_index = next
	feedback = ""
	pulse = 1.0
	ring(note_audio, -22, 0.72 if amount < 0 else 1.08)

func confirm() -> void:
	if mode != "tape":
		if position_index == 1:
			close(true)
		else:
			feedback = "沿边缘拨一下，看看另一面。"
		return
	if played:
		close(true)
		return
	pulse = 1.0
	if position_index == 3:
		played = true
		ring(note_audio, -19, 0.86)
		feedback = "「阿棠，明早九点，站牌背面等。别绕到前门。」"
	elif position_index > 3:
		ring(noise_audio, -14, 1.0)
		feedback = "磁带里只剩雨声。留言在这之前。"
	else:
		ring(noise_audio, -19, 1.0)
		feedback = "脚步挨近了录音机。说话的人还没开口。"

func close(success: bool) -> void:
	hide()
	audio.stop()
	finished.emit(success)

func line(at: Vector2, value: String, size: int, ink := PAPER) -> void:
	Art.text(self, at, value, size, ink)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.044, 0.064, 0.069, 0.92))
	var titles := {"watch":"停表", "ending_watch":"同一块表", "photo":"夹在相框里的照片", "tape":"地下室的录音机"}
	line(Vector2(90, 73), str(titles[mode]), 26)
	line(Vector2(785, 71), "Esc 放回", 15, DIM)
	draw_line(Vector2(90, 94), Vector2(870, 94), Color("#526760"))
	match mode:
		"watch", "ending_watch": draw_watch()
		"photo": draw_photo()
		"tape": draw_tape()
	if not feedback.is_empty():
		line(Vector2(125, 389), feedback, 20, GOLD)
	var buttons := ["←　往回拨", "E　放回", "往前拨　→"]
	if mode == "photo":
		buttons = ["←　翻一面", "E　收进手记", "翻一面　→"]
	elif mode == "tape":
		buttons = ["←　倒带 6 秒", "E　收好磁带" if played else "E　试播", "快进 6 秒　→"]
	elif position_index == 1:
		buttons[1] = "E　收起表" if mode == "ending_watch" else "E　抬头看看"
	for i in 3:
		var rect := Rect2(213 + i * 182, 428, 170, 46)
		draw_rect(rect, Color("#43564f") if i == 1 else Color("#243833"))
		draw_rect(rect, Color("#87a192"), false, 1)
		line(rect.position + Vector2(18, 29), buttons[i], 17)

func draw_watch() -> void:
	var center := Vector2(480, 231)
	draw_circle(center, 100, Color("#8f7455"))
	draw_circle(center, 91, Color("#ded3af"))
	for i in 12:
		var ray := Vector2.from_angle(i * TAU / 12)
		draw_line(center + ray * 72, center + ray * 82, Color("#655746"), 2, true)
	draw_line(center, center + Vector2(-23, 32), Color("#3b4039"), 5, true)
	var hand := Vector2.from_angle(-PI / 2 - stem * TAU / 12)
	draw_line(center, center + hand * 74, Color("#9e4c36"), 3, true)
	draw_circle(center, 5, Color("#3b4039"))
	if position_index == 1:
		line(Vector2(612, 228), "刚过去的一格", 19, GOLD)
		var reaction := "站台响起同一声发车铃。"
		if mode == "ending_watch":
			reaction = "表针退了一格。车还在往前走。"
		line(Vector2(612, 258), reaction, 16, DIM)

func draw_photo() -> void:
	var width := maxf(18, 270 * absf(stem * 2 - 1))
	var rect := Rect2(480 - width / 2, 121, width, 224)
	draw_rect(rect, Color("#d6c39e"))
	if width < 235:
		return
	if stem < 0.5:
		draw_rect(rect.grow(-13), Color("#5d7366"))
		draw_line(Vector2(390, 292), Vector2(571, 292), Color("#acac7d"), 3)
		draw_circle(Vector2(463, 209), 18, Color("#d3af80"))
		draw_line(Vector2(461, 230), Vector2(450, 286), Color("#293e39"), 28, true)
		draw_line(Vector2(422, 264), Vector2(526, 236), Color("#c6975e"), 10, true)
		line(Vector2(637, 209), "父亲怀里的琴", 18)
		line(Vector2(637, 239), "是小满现在用的那把。", 16, DIM)
	else:
		line(Vector2(372, 172), "省歌舞团复试", 22, Color("#493e31"))
		line(Vector2(372, 218), "陈守业　请于周五报到", 16, Color("#493e31"))
		draw_line(Vector2(369, 261), Vector2(570, 251), Color("#9e754d"), 2)
		line(Vector2(372, 299), "背面没有车票。", 15, Color("#76583d"))

func draw_tape() -> void:
	draw_rect(Rect2(238, 118, 484, 186), Color("#344944"))
	draw_rect(Rect2(257, 135, 446, 151), Color("#253736"))
	for x in [379, 581]:
		var center := Vector2(x, 197)
		draw_circle(center, 44, Color("#ad936d"))
		draw_circle(center, 35, Color("#253736"))
		for i in 5:
			var point := Vector2.from_angle(i * TAU / 5 + stem * 2.3)
			draw_line(center + point * 9, center + point * 34, Color("#c1a980"), 5, true)
		draw_circle(center, 7, GOLD)
	draw_line(Vector2(317, 264), Vector2(643, 264), Color("#697c69"), 2)
	for i in 11:
		var x := 317 + i * 32.6
		draw_line(Vector2(x, 258), Vector2(x, 271), DIM, 1)
	draw_circle(Vector2(317 + stem * 32.6, 264), 5 + pulse * 3, GOLD)
	var seconds := position_index * 6
	line(Vector2(446, 337), "01:00" if seconds == 60 else "00:%02d" % seconds, 24)
	if feedback.is_empty():
		line(Vector2(213, 387), "纸标签写着「先听见脚步，人声过后开始下雨」。", 18, DIM)
