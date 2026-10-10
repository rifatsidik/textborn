extends Node2D
## A side-view human silhouette rendered from sampled body contours and glyph characters.
## This is a procedural prototype; all visible character marks are drawn at runtime.

var animation_mode: String = "IDLE"
var glyph_density: float = 1.0
var clock: float = 0.0
const GLYPHS: String = "01{}[]<>/\\|+=-*.:;#"
const WHITE := Color(0.86, 0.94, 1.0, 0.96)
const DIM := Color(0.40, 0.62, 0.75, 0.68)
const CYAN := Color(0.22, 0.83, 1.0, 0.95)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var bob: float = 0.0
	var stride: float = 0.0
	var lean: float = 0.0
	var arm_swing: float = 0.0
	var jump_lift: float = 0.0
	match animation_mode:
		"WALK":
			stride = sin(clock * 7.0) * 13.0
			bob = abs(sin(clock * 7.0)) * 3.0
			arm_swing = sin(clock * 7.0 + PI) * 10.0
			lean = 2.0
		"RUN":
			stride = sin(clock * 11.0) * 21.0
			bob = abs(sin(clock * 11.0)) * 5.0
			arm_swing = sin(clock * 11.0 + PI) * 17.0
			lean = 7.0
		"JUMP":
			jump_lift = -36.0 + sin(clock * 3.0) * 3.0
			stride = 8.0
		"ATTACK":
			lean = 8.0 + sin(clock * 15.0) * 3.0
			arm_swing = -25.0
	var origin := Vector2(0, bob + jump_lift)
	# Human proportions: head ~34 px, torso ~78 px, legs ~91 px at this scale.
	var head_center := origin + Vector2(0, -157)
	var neck := origin + Vector2(-1, -132)
	var shoulder := origin + Vector2(-2 - lean * 0.25, -119)
	var chest := origin + Vector2(-5 - lean * 0.35, -91)
	var waist := origin + Vector2(-3 - lean * 0.25, -62)
	var hip := origin + Vector2(0, -52)
	var near_knee := origin + Vector2(-8 + stride, -29)
	var near_ankle := origin + Vector2(-12 + stride * 1.45, -4)
	var far_knee := origin + Vector2(7 - stride, -30)
	var far_ankle := origin + Vector2(10 - stride * 1.45, -4)
	var near_elbow := origin + Vector2(-19 + arm_swing * 0.35, -88)
	var near_hand := origin + Vector2(-25 + arm_swing, -64)
	var far_elbow := origin + Vector2(15 - arm_swing * 0.25, -88)
	var far_hand := origin + Vector2(20 - arm_swing * 0.65, -67)
	if animation_mode == "JUMP":
		near_knee.y += 12
		far_knee.y += 4
		near_ankle.y -= 6
		far_ankle.y -= 13
	# Rear limbs are slightly dimmer, giving a readable side-on pose.
	_draw_glyph_limb(hip, far_knee, far_ankle, DIM, 1.0)
	_draw_glyph_limb(shoulder + Vector2(0, 5), far_elbow, far_hand, DIM, 0.9)
	# Core torso contour and a restrained inner structure.
	_draw_glyph_path(PackedVector2Array([
		shoulder + Vector2(-7, -2), shoulder + Vector2(5, -1),
		chest + Vector2(11, 7), waist + Vector2(8, 3),
		hip + Vector2(8, 1), hip + Vector2(-8, 1),
		waist + Vector2(-9, 2), chest + Vector2(-12, 8),
		shoulder + Vector2(-7, -2)
	]), WHITE, 1.0)
	_draw_glyph_path(PackedVector2Array([shoulder, chest, waist, hip]), DIM, 0.72)
	_draw_glyph_path(PackedVector2Array([shoulder + Vector2(-5, 5), chest + Vector2(-7, 5), waist + Vector2(-5, 0)]), WHITE, 0.7)
	# Neck and human head profile, facing right.
	_draw_glyph_path(PackedVector2Array([neck + Vector2(-4, 4), neck + Vector2(4, 4), head_center + Vector2(3, 14)]), WHITE, 0.9)
	var head_outline := PackedVector2Array([
		head_center + Vector2(-11, 7), head_center + Vector2(-12, -5),
		head_center + Vector2(-8, -15), head_center + Vector2(1, -19),
		head_center + Vector2(10, -14), head_center + Vector2(13, -7),
		head_center + Vector2(18, -2), head_center + Vector2(12, 2),
		head_center + Vector2(11, 9), head_center + Vector2(5, 13),
		head_center + Vector2(-4, 12), head_center + Vector2(-11, 7)
	])
	_draw_glyph_path(head_outline, WHITE, 1.0)
	_draw_glyph_path(PackedVector2Array([head_center + Vector2(8, -2), head_center + Vector2(13, -1)]), CYAN, 0.65)
	# Arms and hands.
	_draw_glyph_limb(shoulder + Vector2(-7, 0), near_elbow, near_hand, WHITE, 1.0)
	_draw_glyph_path(PackedVector2Array([near_hand, near_hand + Vector2(-3, 5), near_hand + Vector2(0, 8), near_hand + Vector2(3, 3)]), WHITE, 0.85)
	# Legs and feet: explicit hip-knee-ankle articulation.
	_draw_glyph_limb(hip + Vector2(-4, 0), near_knee, near_ankle, WHITE, 1.0)
	_draw_glyph_path(PackedVector2Array([near_ankle, near_ankle + Vector2(10, 1), near_ankle + Vector2(15, 4), near_ankle + Vector2(1, 5), near_ankle + Vector2(-2, 2)]), WHITE, 0.9)
	_draw_glyph_path(PackedVector2Array([far_ankle, far_ankle + Vector2(8, 1), far_ankle + Vector2(12, 4), far_ankle + Vector2(0, 5)]), DIM, 0.8)
	# Sparse internal glyphs suggest anatomy without filling the silhouette.
	for i in range(8):
		var t: float = float(i) / 7.0
		var p: Vector2 = shoulder.lerp(waist, t) + Vector2(2.0 * sin(t * PI), 0)
		_draw_glyph(p, i + 4, DIM, 0.72)
	for i in range(4):
		_draw_glyph(chest + Vector2(-2 + i * 3, 11 + sin(float(i)) * 2), i + 11, DIM, 0.7)
	if animation_mode == "ATTACK":
		_draw_glyph_path(PackedVector2Array([near_hand, near_hand + Vector2(20, -14), near_hand + Vector2(42, -21)]), CYAN, 1.1)

func _draw_glyph_limb(a: Vector2, b: Vector2, c: Vector2, tint: Color, scale: float) -> void:
	_draw_glyph_path(PackedVector2Array([a, b, c]), tint, scale)
	# A second, offset path gives the limb a narrow readable contour.
	var offset := Vector2(3.0, 0.0)
	_draw_glyph_path(PackedVector2Array([a + offset, b + offset, c + offset]), tint.darkened(0.16), scale * 0.82)
	_draw_glyph_path(PackedVector2Array([a.lerp(b, 0.48), b, b.lerp(c, 0.38)]), tint, scale * 0.55)

func _draw_glyph_path(points: PackedVector2Array, tint: Color, scale: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		draw_line(a, b, Color(tint.r, tint.g, tint.b, tint.a * 0.30), 1.0, true)
		var distance: float = a.distance_to(b)
		var count: int = maxi(2, int(distance / maxf(5.0, 7.0 / glyph_density)))
		for j in range(count + 1):
			var t: float = float(j) / float(count)
			var p: Vector2 = a.lerp(b, t)
			var idx: int = int(absf(p.x * 3.0 + p.y * 7.0)) % GLYPHS.length()
			_draw_glyph(p, idx, tint, scale)

func _draw_glyph(pos: Vector2, index: int, tint: Color, scale: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var glyph: String = GLYPHS.substr(index % GLYPHS.length(), 1)
	var size: int = maxi(8, int(12.0 * scale * glyph_density))
	draw_string(font, pos, glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, size, tint)
