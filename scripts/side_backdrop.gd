extends Node2D

const PlaceholderArt = preload("res://scripts/placeholder_art.gd")

# 世界坐标里的背景层；position.x 由相机每帧重算，实现视差。

var scene_id: String = ""
var phase: int = 0
var scene_width: float = 2880.0
var floor_y: float = 456.0
var layer_name: String = "far"
var layer_z: int = -40
var parallax: float = 0.2
var art_texture: Texture2D = null


func setup(p_scene: String, p_phase: int, p_width: float, p_floor: float, p_layer: String) -> void:
	scene_id = p_scene
	phase = p_phase
	scene_width = p_width
	floor_y = p_floor
	layer_name = p_layer
	if layer_name == "far":
		layer_z = -40
		parallax = 0.20
	elif layer_name == "mid":
		layer_z = -30
		parallax = 0.58
	elif layer_name == "near":
		layer_z = 12
		parallax = 1.0
	if layer_name == "far":
		var path: String = "res://art/scenes/" + scene_id + "/" + scene_id + "_P0_far.png"
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is Texture2D:
				art_texture = res as Texture2D
	z_index = layer_z
	queue_redraw()


func refresh(p_phase: int) -> void:
	phase = p_phase
	queue_redraw()


func _draw() -> void:
	if layer_name == "far" and art_texture != null:
		draw_texture_rect(art_texture, Rect2(0.0, 0.0, scene_width, 540.0), false, _phase_tint())
		return
	if layer_name == "far":
		PlaceholderArt.far(self, scene_id, phase, scene_width, floor_y)
	elif layer_name == "mid":
		PlaceholderArt.mid(self, scene_id, phase, scene_width, floor_y)
	elif layer_name == "near":
		PlaceholderArt.near(self, scene_id, phase, scene_width, floor_y)


func _phase_tint() -> Color:
	if phase == 1:
		return Color(1.0, 0.84, 0.70, 1.0)
	if phase == 2:
		return Color(0.38, 0.44, 0.56, 1.0)
	if phase == 3:
		return Color(0.75, 0.78, 0.76, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)
