extends Control

const PlaceholderArt = preload("res://scripts/placeholder_art.gd")

# 固定在屏幕上的天空；不随相机横向移动。

var phase: int = 0


func setup(value: int) -> void:
	phase = value
	queue_redraw()


func _draw() -> void:
	PlaceholderArt.sky(self, phase, 960.0, 456.0)
