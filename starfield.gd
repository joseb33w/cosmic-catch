class_name Starfield
extends Node2D

var _stars: Array = []
var _field := Vector2(720, 1280)
var _t := 0.0


func init_field(vp: Vector2, count := 80) -> void:
	_field = vp
	_stars.clear()
	for i in count:
		_stars.append({
			"pos": Vector2(randf() * vp.x, randf() * vp.y),
			"size": randf_range(0.8, 3.0),
			"phase": randf() * TAU,
			"speed": randf_range(8.0, 30.0),
			"hue": randf(),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for s in _stars:
		s.pos.y += s.speed * delta
		if s.pos.y > _field.y + 4.0:
			s.pos.y = -4.0
			s.pos.x = randf() * _field.x
	queue_redraw()


func _draw() -> void:
	for s in _stars:
		var tw: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 2.2 + s.phase))
		var tint := Color(0.85, 0.9, 1.0).lerp(Color(1.0, 0.92, 0.8), s.hue)
		tint.a = tw
		draw_circle(s.pos, s.size, tint)
		if s.size > 2.2:
			tint.a = tw * 0.25
			draw_circle(s.pos, s.size * 2.4, tint)
