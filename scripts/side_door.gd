extends Node2D

const PlaceholderArt = preload("res://scripts/placeholder_art.gd")

var data: Dictionary = {}
var label: String = ""
var active: bool = false
var interior: bool = false
var _t: float = 0.0


func setup(p_data: Dictionary, p_floor: float, p_interior: bool) -> void:
	data = p_data.duplicate(true)
	label = str(data.get("label", "门"))
	interior = p_interior
	position = Vector2(float(data.get("x", 0.0)), p_floor)
	z_index = 2
	queue_redraw()


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	PlaceholderArt.door(self, label, active, interior)
