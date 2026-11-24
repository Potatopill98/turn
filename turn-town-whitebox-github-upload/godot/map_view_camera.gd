extends Camera2D
## 全览相机：运行后自动把整张地图装进视口，不需要移动/缩放就能看全图。
## 挂在场景的 Camera2D 节点上即可。优先按同级瓦片层的已用格子算包围盒；
## 没有瓦片层时按同级 Sprite2D 的贴图算（静态看图场景）。

@export_range(0.5, 1.0, 0.01) var fit_margin: float = 0.96
@export var auto_fit: bool = true
## 没有任何可测内容时使用的兜底尺寸（像素）
@export var fallback_size: Vector2 = Vector2(2400, 1200)

func _ready() -> void:
	if auto_fit:
		call_deferred("fit_to_content")

## 手动重算（改了地图尺寸/贴图后可调用）
func fit_to_content() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var bounds := _content_bounds(parent)
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return
	var vp := get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	var z: float = minf(vp.x / bounds.size.x, vp.y / bounds.size.y) * fit_margin
	zoom = Vector2.ONE * clampf(z, 0.001, 8.0)
	position = bounds.position + bounds.size * 0.5
	print("[map_view_camera] 全览：内容 %.0fx%.0f，视口 %.0fx%.0f，zoom=%.3f"
		% [bounds.size.x, bounds.size.y, vp.x, vp.y, zoom.x])

func _content_bounds(parent: Node) -> Rect2:
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	var found := false
	for child in parent.get_children():
		if child == self:
			continue
		if child is TileMapLayer:
			var tm := child as TileMapLayer
			for c in tm.get_used_cells():
				var p := tm.map_to_local(c)
				minp = minp.min(p)
				maxp = maxp.max(p)
				found = true
		elif child is TileMap:
			var tm := child as TileMap
			for c in tm.get_used_cells(0):
				var p := tm.map_to_local(c)
				minp = minp.min(p)
				maxp = maxp.max(p)
				found = true
		elif child is Sprite2D:
			var sp := child as Sprite2D
			if sp.texture == null:
				continue
			var s := sp.texture.get_size() * sp.scale
			minp = minp.min(sp.position - s * 0.5)
			maxp = maxp.max(sp.position + s * 0.5)
			found = true
	if not found:
		return Rect2(-fallback_size * 0.5, fallback_size)
	# 补一格瓦片，避免边缘被裁掉
	return Rect2(minp - Vector2(32, 16), maxp - minp + Vector2(64, 32))
