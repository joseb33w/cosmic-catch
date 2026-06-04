class_name Catcher
extends Node2D

var half_width := 84.0
var height := 30.0
var color := Color(0.25, 0.95, 0.95)
var _flash := 0.0
var _bob := 0.0


func _process(delta: float) -> void:
	_bob += delta
	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 2.5)
	queue_redraw()


func hit_flash() -> void:
	_flash = 1.0
	queue_redraw()


func _draw() -> void:
	var c := color.lerp(Color(1.0, 0.35, 0.4), _flash)
	var pulse: float = 1.0 + 0.04 * sin(_bob * 4.0)
	# Outer glow.
	var glow := c
	glow.a = 0.16
	_capsule(half_width + 16.0, height + 12.0, glow)
	glow.a = 0.28
	_capsule(half_width + 6.0, height + 4.0, glow)
	# Body.
	_capsule(half_width, height, c)
	# Inner lighter core for depth.
	var core := c.lerp(Color.WHITE, 0.45)
	core.a = 0.9
	_capsule((half_width - 10.0) * pulse, height * 0.5, core)
	# Top rim highlight line (the "catch" lip).
	var rim := Color.WHITE
	rim.a = 0.85
	draw_line(Vector2(-half_width + 8.0, -height * 0.5),
		Vector2(half_width - 8.0, -height * 0.5), rim, 3.0)


func _capsule(hw: float, h: float, col: Color) -> void:
	var r := h * 0.5
	draw_rect(Rect2(-hw, -r, hw * 2.0, h), col)
	draw_circle(Vector2(-hw, 0.0), r, col)
	draw_circle(Vector2(hw, 0.0), r, col)
