extends Node2D

const PlaceholderArt = preload("res://scripts/placeholder_art.gd")

var scene_id: String = ""
var phase: int = 0
var scene_width: float = 2880.0
var floor_y: float = 456.0


func setup(p_scene: String, p_phase: int, p_width: float, p_floor: float) -> void:
	scene_id = p_scene
	phase = p_phase
	scene_width = p_width
	floor_y = p_floor
	z_index = 0
	queue_redraw()


func refresh(p_phase: int) -> void:
	phase = p_phase
	queue_redraw()


func _draw() -> void:
	PlaceholderArt.ground(self, scene_id, phase, scene_width, floor_y)
