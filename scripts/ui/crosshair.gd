class_name Crosshair
extends Control

## 조준선. 구동 상태에 따라 벌어지고 색이 바뀐다.
## 사격이 불가능한 상태(직접 굴리는 중 / 들려 있는 중)는 X 표시로 명확히 알린다.

var spread_px: float = 10.0
var can_fire: bool = true
var blocked: bool = false


static func create() -> Crosshair:
	var c := Crosshair.new()
	c.set_script(load("res://scripts/ui/crosshair.gd"))
	c.name = "Crosshair"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(120.0, 120.0)
	return c


func _process(_delta: float) -> void:
	var vp := get_viewport_rect().size
	position = vp * 0.5 - size * 0.5
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var color := Color(0.35, 1.0, 0.55, 0.95)
	if blocked:
		color = Color(1.0, 0.35, 0.28, 0.95)
	elif not can_fire:
		color = Color(1.0, 0.82, 0.35, 0.95)

	if blocked:
		var d := 9.0
		draw_line(center + Vector2(-d, -d), center + Vector2(d, d), color, 2.5)
		draw_line(center + Vector2(-d, d), center + Vector2(d, -d), color, 2.5)
		return

	var gap := clampf(spread_px, 4.0, 46.0)
	var arm := 8.0
	draw_line(center + Vector2(-gap - arm, 0.0), center + Vector2(-gap, 0.0), color, 2.0)
	draw_line(center + Vector2(gap, 0.0), center + Vector2(gap + arm, 0.0), color, 2.0)
	draw_line(center + Vector2(0.0, -gap - arm), center + Vector2(0.0, -gap), color, 2.0)
	draw_line(center + Vector2(0.0, gap), center + Vector2(0.0, gap + arm), color, 2.0)
	draw_circle(center, 1.6, color)
