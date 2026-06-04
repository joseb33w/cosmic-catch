extends Node2D
## Cosmic Catch — a mobile-web arcade catcher.
## Move the catcher (drag anywhere, or arrow / A,D keys) to grab falling stars
## and gems for points; dodge the spiky bombs. Three lives, combo multiplier,
## ramping difficulty, local best-score persistence (user:// -> IndexedDB on web).

const CATCHER_BOTTOM_GAP := 200.0
const CATCHER_SPEED := 760.0
const BASE_SPAWN := 0.95
const MIN_SPAWN := 0.40
const BASE_FALL := 250.0
const MAX_LIVES := 3
const SAVE_PATH := "user://cosmic_catch.save"

const STAR_COLOR := Color(1.0, 0.84, 0.25)
const GEM_COLORS := [
	Color(0.35, 0.85, 1.0), Color(0.85, 0.45, 1.0),
	Color(0.4, 1.0, 0.65), Color(1.0, 0.5, 0.7),
]

var world: Node2D
var catcher: Catcher
var starfield: Starfield

var hud: CanvasLayer
var score_label: Label
var best_label: Label
var combo_label: Label
var lives_node: Node2D
var overlay_layer: CanvasLayer
var overlay: Control

var items: Array[FallingItem] = []
var score := 0
var best := 0
var lives := MAX_LIVES
var combo := 0
var difficulty := 0.0
var started := false
var game_over := false
var spcwn_timer := 0.0
var shake := 0.0
var _new_best := false
var _touch_target_x := -1.0

var sfx_catch: AudioStreamPlayer
var sfx_gem: AudioStreamPlayer
var sfx_bomb: AudioStreamPlayer
var sfx_over: AudioStreamPlayer


func _ready() -> void:
	randomize()
	best = _load_best()
	_build_background()
	_build_world()
	_build_hud()
	_build_audio()
	_show_title()


func _process(delta: float) -> void:
	_apply_shake(delta)
	if not started or game_over:
		return

	difficulty = clampf(float(score) / 600.0, 0.0, 1.0)
	_move_catcher(delta)
	_spawn_tick(delta)
	_update_items()
	_update_hud()


func _input(event: InputEvent) -> void:
	if game_over or not started:
		return
	var vp := get_viewport_rect().size
	var set_target := false
	if event is InputEventScreenTouch and event.pressed:
		_touch_target_x = event.position.x - world.position.x
		set_target = true
	elif event is InputEventScreenDrag:
		_touch_target_x = event.position.x - world.position.x
		set_target = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_touch_target_x = event.position.x - world.position.x
		set_target = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_touch_target_x = event.position.x - world.position.x
		set_target = true
	if set_target:
		_touch_target_x = clampf(_touch_target_x, 0.0, vp.x)


# --- Movement -------------------------------------------------------------

func _move_catcher(delta: float) -> void:
	var vp := get_viewport_rect().size
	var kb := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		kb -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		kb += 1.0
	var x := catcher.position.x
	if kb != 0.0:
		_touch_target_x = -1.0
		x += kb * CATCHER_SPEED * delta
	elif _touch_target_x >= 0.0:
		x = lerpf(x, _touch_target_x, clampf(delta * 16.0, 0.0, 1.0))
	catcher.position.x = clampf(x, catcher.half_width, vp.x - catcher.half_width)


# --- Spawning -------------------------------------------------------------

func _spawn_tick(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var interval := lerpf(BASE_SPAWN, MIN_SPAWN, difficulty)
	spawn_timer = interval * randf_range(0.78, 1.2)
	_spawn_item()


func _spawn_item() -> void:
	var vp := get_viewport_rect().size
	var fall := lerpf(BASE_FALL, BASE_FALL * 2.5, difficulty) * randf_range(0.9, 1.12)
	var item := FallingItem.new()
	var roll := randf()
	var bomb_p := lerpf(0.16, 0.32, difficulty)
	if roll < bomb_p:
		item.setup(FallingItem.Kind.BOMB, 30.0, fall, Color(0.85, 0.25, 0.3), 0)
	elif roll < bomb_p + 0.18:
		item.setup(FallingItem.Kind.GEM, 26.0, fall, GEM_COLORS[randi() % GEM_COLORS.size()], 30)
	else:
		item.setup(FallingItem.Kind.STAR, 30.0, fall, STAR_COLOR, 10)
	item.position = Vector2(randf_range(60.0, vp.x - 60.0), -40.0)
	world.add_child(item)
	items.append(item)


# --- Item update / collisions --------------------------------------------

func _update_items() -> void:
	var vp := get_viewport_rect().size
	var catch_line := catcher.position.y
	for item: FallingItem in items.duplicate():
		if not is_instance_valid(item):
			items.erase(item)
			continue
		if item.position.y > vp.y + 60.0:
			items.erase(item)
			item.queue_free()
			continue
		var dx: float = absf(item.position.x - catcher.position.x)
		var in_band := item.position.y >= catch_line - 18.0 and item.position.y <= catch_line + 38.0
		if not item.caught and in_band and dx <= catcher.half_width + item.radius * 0.55:
			item.caught = true
			_resolve_catch(item)
			items.erase(item)
			item.queue_free()


func _resolve_catch(item: FallingItem) -> void:
	if item.kind == FallingItem.Kind.BOMB:
		combo = 0
		lives -= 1
		shake = 16.0
		catcher.hit_flash()
		_burst(item.position, Color(1.0, 0.35, 0.35), 22, 280.0)
		_play(sfx_bomb)
		_update_hud()
		if lives <= 0:
			_end_game()
		return
	combo += 1
	var mult := 1 + int((combo - 1) / 5)
	score += item.points * mult
	_burst(item.position, item.base_color, 14, 200.0)
	_play(sfx_gem if item.kind == FallingItem.Kind.GEM else sfx_catch)
	_update_hud()


func _burst(pos: Vector2, color: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, 520.0)
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = color
	world.add_child(p)
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)


# --- Shake ----------------------------------------------------------------

func _apply_shake(delta: float) -> void:
	if shake > 0.05:
		shake = maxf(0.0, shake - delta * 60.0)
		world.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	elif world.position != Vector2.ZERO:
		world.position = Vector2.ZERO


# --- Game flow ------------------------------------------------------------

func start_game() -> void:
	for item in items:
		if is_instance_valid(item):
			item.queue_free()
	items.clear()
	score = 0
	lives = MAX_LIVES
	combo = 0
	difficulty = 0.0
	spawn_timer = 0.6
	shake = 0.0
	_new_best = false
	game_over = false
	started = true
	world.position = Vector2.ZERO
	catcher.position.x = get_viewport_rect().size.x * 0.5
	_touch_target_x = -1.0
	_dismiss_overlay()
	get_tree().paused = false
	_update_hud()
	combo_label.visible = false


func _end_game() -> void:
	game_over = true
	started = false
	if score > best:
		best = score
		_new_best = true
		_save_best(best)
	_play(sfx_over)
	get_tree().paused = true
	_show_game_over()
	_update_hud()


# --- HUD ------------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	score_label = _make_label("0", 46, Color(1, 1, 1), Vector2(30, 26))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hud.add_child(score_label)

	var vp := get_viewport_rect().size
	best_label = _make_label("BEST 0", 26, Color(0.8, 0.85, 1.0), Vector2(vp.x - 250, 36))
	best_label.size = Vector2(220, 40)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_label.add_theme_constant_override("outline_size", 6)
	best_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hud.add_child(best_label)

	combo_label = _make_label("", 30, Color(1.0, 0.85, 0.3), Vector2(0, 92))
	combo_label.size = Vector2(vp.x, 40)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_constant_override("outline_size", 6)
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	combo_label.visible = false
	hud.add_child(combo_label)

	lives_node = Node2D.new()
	lives_node.position = Vector2(34, 104)
	lives_node.draw.connect(_draw_lives)
	hud.add_child(lives_node)


func _update_hud() -> void:
	score_label.text = str(score)
	best_label.text = "BEST %d" % maxi(best, score)
	lives_node.queue_redraw()
	if combo >= 2:
		var mult := 1 + int((combo - 1) / 5)
		combo_label.text = "COMBO x%d" % combo if mult == 1 else "COMBO x%d  (%dx pts)" % [combo, mult]
		combo_label.visible = true
	else:
		combo_label.visible = false


func _draw_lives() -> void:
	for i in MAX_LIVES:
		var on := i < lives
		var col := Color(1.0, 0.32, 0.42) if on else Color(1, 1, 1, 0.14)
		_draw_heart(Vector2(i * 42.0, 0.0), 13.0, col)


func _draw_heart(c: Vector2, s: float, col: Color) -> void:
	lives_node.draw_circle(c + Vector2(-s * 0.5, -s * 0.18), s * 0.55, col)
	lives_node.draw_circle(c + Vector2(s * 0.5, -s * 0.18), s * 0.55, col)
	lives_node.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s, -s * 0.02), c + Vector2(s, -s * 0.02), c + Vector2(0, s),
	]), col)


# --- Overlays -------------------------------------------------------------

func _show_title() -> void:
	get_tree().paused = true
	overlay_layer = CanvasLayer.new()
	overlay_layer.name = "Overlay"
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)

	overlay = _dim_panel()
	overlay_layer.add_child(overlay)

	var vp := get_viewport_rect().size
	var title := _centered_label("COSMIC\nCATCH", 88, Color(1.0, 0.88, 0.35), vp.y * 0.26)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.15, 0.5, 0.9))
	overlay.add_child(title)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
	title.pivot_offset = Vector2(vp.x * 0.5, 60)

	overlay.add_child(_centered_label(
		"Catch stars and gems\nDodge the bombs", 34, Color(0.9, 0.93, 1.0), vp.y * 0.52))
	overlay.add_child(_centered_label(
		"Drag to move  ·  or Arrow / A D keys", 26, Color(0.7, 0.78, 0.95), vp.y * 0.64))

	var play := _centered_label("TAP TO PLAY", 44, Color(0.3, 1.0, 0.85), vp.y * 0.78)
	overlay.add_child(play)
	var pt := play.create_tween().set_loops()
	pt.tween_property(play, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	pt.tween_property(play, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	overlay.gui_input.connect(_on_overlay_tap)


func _show_game_over() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.name = "Overlay"
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)

	overlay = _dim_panel()
	overlay_layer.add_child(overlay)

	var vp := get_viewport_rect().size
	var go := _centered_label("GAME OVER", 76, Color(1.0, 0.4, 0.45), vp.y * 0.26)
	go.add_theme_constant_override("outline_size", 10)
	go.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.1, 0.9))
	overlay.add_child(go)

	overlay.add_child(_centered_label("SCORE\n%d" % score, 52, Color(1, 1, 1), vp.y * 0.42))
	if _new_best:
		var nb := _centered_label("NEW BEST!", 40, Color(1.0, 0.88, 0.3), vp.y * 0.58)
		overlay.add_child(nb)
		var nt := nb.create_tween().set_loops()
		nt.tween_property(nb, "scale", Vector2(1.08, 1.08), 0.5)
		nt.tween_property(nb, "scale", Vector2(1.0, 1.0), 0.5)
		nb.pivot_offset = Vector2(vp.x * 0.5, 20)
	else:
		overlay.add_child(_centered_label("BEST  %d" % best, 36, Color(0.85, 0.9, 1.0), vp.y * 0.58))

	var again := _centered_label("TAP TO PLAY AGAIN", 38, Color(0.3, 1.0, 0.85), vp.y * 0.76)
	overlay.add_child(again)
	var pt := again.create_tween().set_loops()
	pt.tween_property(again, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	pt.tween_property(again, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	overlay.gui_input.connect(_on_overlay_tap)


func _on_overlay_tap(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		start_game()


func _dim_panel() -> Control:
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.03, 0.12, 0.82)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _dismiss_overlay() -> void:
	if overlay_layer != null and is_instance_valid(overlay_layer):
		overlay_layer.queue_free()
	overlay_layer = null
	overlay = null


# --- World / background ---------------------------------------------------

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)

	var vp := get_viewport_rect().size
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.04, 0.16))
	grad.set_color(1, Color(0.12, 0.06, 0.24))
	grad.add_point(0.55, Color(0.07, 0.05, 0.2))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var bg := TextureRect.new()
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(bg)

	starfield = Starfield.new()
	starfield.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(starfield)
	starfield.init_field(vp, 90)


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	var vp := get_viewport_rect().size
	catcher = Catcher.new()
	catcher.position = Vector2(vp.x * 0.5, vp.y - CATCHER_BOTTOM_GAP)
	world.add_child(catcher)


# --- Audio ----------------------------------------------------------------

func _build_audio() -> void:
	sfx_catch = _player(_tone(660.0, 0.10, 0.5, true, 880.0))
	sfx_gem = _player(_tone(880.0, 0.16, 0.5, true, 1320.0))
	sfx_bomb = _player(_tone(120.0, 0.28, 0.6, true, 60.0, true))
	sfx_over = _player(_tone(440.0, 0.45, 0.55, true, 160.0))


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _play(p: AudioStreamPlayer) -> void:
	if p != null:
		p.play()


func _tone(freq: float, dur: float, vol: float, decay: bool, end_freq: float, square := false) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var prog := t / dur
		var f := lerpf(freq, end_freq, prog)
		var env := 1.0
		if decay:
			env = clampf(1.0 - prog, 0.0, 1.0)
		env *= clampf(t / 0.01, 0.0, 1.0)
		var s := sin(TAU * f * t)
		if square:
			s = 1.0 if s >= 0.0 else -1.0
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav


# --- Persistence ----------------------------------------------------------

func _load_best() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var v := f.get_32()
	f.close()
	return int(v)


func _save_best(value: int) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_32(value)
	f.close()


# --- Label helpers --------------------------------------------------------

func _make_label(text: String, fsize: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	return l


func _centered_label(text: String, fsize: int, col: Color, y: float) -> Label:
	var vp := get_viewport_rect().size
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(vp.x, 160)
	l.position = Vector2(0, y - 80)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
