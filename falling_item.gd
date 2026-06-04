class_name FallingItem
extends Node2D

enum Kind { STAR, GEM, BOMB }

var kind: int = Kind.STAR
var radius := 30.0
var fall_speed := 260.0
var points := 10
var base_color := Color.WHITE
var caught := false

var _spin := 0.0


func setup(k: int, r: float, speed: float, col: Color, pts: int) -> void:
	kind = k
	radius = r
	fall_speed = speed
	base_color = col
	points = pts
	_spin = randf_range(-2.2, 2.2)
	if kind == Kind.GEM:
		_spin *= 0.6
	queue_redraw()


func _process(delta: float) -> void:
	position.y += fall_speed * delta
	rotation += _spin * delta


func _draw() -> void:
	match kind:
		Kind.STAR:
			_draw_star()
		Kind.GEM:
			_draw_gem()
		Kind.BOMB:
			_draw_bomb()


func _draw_star() -> void:
	var glow := base_color
	glow.a = 0.22
	draw_circle(Vector2.ZERO, radius * 1.5, glow)
	var outer := _star_points(radius, radius * 0.46)
	draw_colored_polygon(outer, base_color)
	var loop := outer
	loop.append(outer[0])
	draw_polyline(loop, Color(1, 1, 1, 0.9), 2.0)
	draw_circle(Vector2.ZERO, radius * 0.28, Color(1, 1, 1, 0.85))


func _draw_gem() -> void:
	var glow := base_color
	glow.a = 0.22
	draw_circle(Vector2.ZERO, radius * 1.4, glow)
	var r := radius
	var body := PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.78, -r * 0.2),
		Vector2(r * 0.5, r), Vector2(-r * 0.5, r),
		Vector2(-r * 0.78, -r * 0.2),
	])
	draw_colored_polygon(body, base_color)
	# Facet highlights.
	var hi := Color(1, 1, 1, 0.55)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.78, -r * 0.2), Vector2(0, -r * 0.05),
	]), hi)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -r), Vector2(-r * 0.78, -r * 0.2), Vector2(0, -r * 0.05),
	]), Color(1, 1, 1, 0.25))
	var loop := body
	loop.append(body[0])
	draw_polyline(loop, Color(1, 1, 1, 0.8), 2.0)


func _draw_bomb() -> void:
	var danger := Color(1.0, 0.25, 0.3, 0.22)
	draw_circle(Vector2.ZERO, radius * 1.7, danger)
	# Spiky asteroid body.
	var spikes := PackedVector2Array()
	var n := 12
	for i in n:
		var ang := TAU * float(i) / float(n)
		var rad := radius if i % 2 == 0 else radius * 0.74
		spikes.append(Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(spikes, Color(0.16, 0.16, 0.22))
	draw_circle(Vector2.ZERO, radius * 0.62, Color(0.3, 0.32, 0.4))
	# Warning core + glints.
	draw_circle(Vector2(-radius * 0.18, -radius * 0.18), radius * 0.16, Color(1, 0.45, 0.45, 0.9))
	var loop := spikes
	loop.append(spikes[0])
	draw_polyline(loop, Color(1.0, 0.3, 0.35, 0.85), 2.0)


func _star_points(outer_r: float, inner_r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rr := outer_r if i % 2 == 0 else inner_r
		pts.append(Vector2(cos(ang), sin(ang)) * rr)
	return pts
