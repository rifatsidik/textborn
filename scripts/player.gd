extends CharacterBody2D

# Textborn Character V1: restrained proportions and a quiet walk cycle.
const WALK_SPEED: float = 125.0
const GRAVITY: float = 1100.0
const GLYPH_SIZE: int = 10
const GLYPHS: Array[String] = ["0", "1", "I", "l", "|", ":", ".", "+", "-", "/", "\\", "x"]

var font: Font
var gait: float = 0.0
var facing: float = 1.0
var walk_blend: float = 0.0

func _ready() -> void:
    font = ThemeDB.fallback_font
    var collision := CollisionShape2D.new()
    collision.name = "BodyCollision"
    var capsule := CapsuleShape2D.new()
    capsule.radius = 10.0
    capsule.height = 100.0
    collision.shape = capsule
    collision.position = Vector2(0, -50)
    add_child(collision)
    queue_redraw()

func _physics_process(delta: float) -> void:
    var direction := Input.get_axis("ui_left", "ui_right")
    if direction != 0.0:
        facing = signf(direction)

    velocity.x = direction * WALK_SPEED
    if not is_on_floor():
        velocity.y += GRAVITY * delta
    elif velocity.y > 0.0:
        velocity.y = 0.0

    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = -380.0

    var moving := absf(direction) > 0.05
    walk_blend = move_toward(walk_blend, 1.0 if moving else 0.0, delta * 4.5)
    if moving:
        gait += delta * 7.0
    else:
        # Gait settles naturally instead of continuing to bounce while idle.
        gait = lerpf(gait, roundf(gait / TAU) * TAU, delta * 2.5)

    move_and_slide()
    queue_redraw()

func _draw() -> void:
    if font == null:
        return

    # World-space y is negative above the feet. Proportions are based on
    # a roughly 7.5-head-tall adult silhouette.
    var step := sin(gait) * 10.0 * walk_blend
    var counter_step := -step
    var hip_y := -43.0
    var shoulder_y := -75.0
    var bob := absf(sin(gait * 2.0)) * 1.0 * walk_blend

    var pelvis := Vector2(0, hip_y + bob)
    var sternum := Vector2(-step * 0.035, shoulder_y + bob)
    var neck := sternum + Vector2(0, -7)
    var head := neck + Vector2(0, -13)

    # Legs use two segments, with knees bending only slightly.
    var left_hip := pelvis + Vector2(-5, 0)
    var right_hip := pelvis + Vector2(5, 0)
    var left_knee := left_hip + Vector2(step * 0.48, 18)
    var right_knee := right_hip + Vector2(counter_step * 0.48, 18)
    var left_ankle := left_knee + Vector2(step * 0.52, 20)
    var right_ankle := right_knee + Vector2(counter_step * 0.52, 20)

    # Keep feet near the floor; only the swing foot lifts a little.
    left_ankle.y -= maxf(0.0, sin(gait)) * 2.0 * walk_blend
    right_ankle.y -= maxf(0.0, -sin(gait)) * 2.0 * walk_blend

    var left_shoulder := sternum + Vector2(-9, 1)
    var right_shoulder := sternum + Vector2(9, 1)
    var arm_swing := sin(gait) * 5.0 * walk_blend
    var left_elbow := left_shoulder + Vector2(-1 - arm_swing * 0.3, 14)
    var right_elbow := right_shoulder + Vector2(1 + arm_swing * 0.3, 14)
    var left_hand := left_elbow + Vector2(-arm_swing, 13)
    var right_hand := right_elbow + Vector2(arm_swing, 13)

    var ink := Color(0.91, 0.93, 0.96, 1.0)

    # Human contour first: head, neck, shoulder line, ribcage, waist and pelvis.
    _glyph_ellipse(head, Vector2(6.2, 8.2), 0.0, ink, 3)
    _glyph_path(PackedVector2Array([
        neck + Vector2(-2.5, -1), sternum + Vector2(-7.0, -1),
        sternum + Vector2(-11.0, 3), sternum + Vector2(-8.5, 14),
        pelvis + Vector2(-5.5, -1), pelvis + Vector2(5.5, -1),
        sternum + Vector2(8.5, 14), sternum + Vector2(11.0, 3),
        sternum + Vector2(7.0, -1), neck + Vector2(2.5, -1)
    ]), ink, 11, true)
    _glyph_path(PackedVector2Array([
        pelvis + Vector2(-5.5, -1), left_hip + Vector2(-4.0, 2),
        left_hip + Vector2(1.0, 8), right_hip + Vector2(-1.0, 8),
        right_hip + Vector2(4.0, 2), pelvis + Vector2(5.5, -1)
    ]), ink, 19, true)

    # Arms read as tapered limbs with joints, rather than thick glyph bundles.
    _glyph_limb(left_shoulder, left_elbow, 4.0, ink, 29)
    _glyph_limb(left_elbow, left_hand, 3.0, ink, 31)
    _glyph_limb(right_shoulder, right_elbow, 4.0, ink, 37)
    _glyph_limb(right_elbow, right_hand, 3.0, ink, 41)

    # Leg contour and a restrained centerline for knee articulation.
    _glyph_limb(left_hip, left_knee, 4.5, ink, 43)
    _glyph_limb(left_knee, left_ankle, 3.2, ink, 47)
    _glyph_limb(right_hip, right_knee, 4.5, ink, 53)
    _glyph_limb(right_knee, right_ankle, 3.2, ink, 59)

    # Feet remain small and nearly horizontal.
    _glyph_path(PackedVector2Array([
        left_ankle + Vector2(-2, 0), left_ankle + Vector2(6, 0),
        left_ankle + Vector2(8, 2)
    ]), ink, 61, false)
    _glyph_path(PackedVector2Array([
        right_ankle + Vector2(-2, 0), right_ankle + Vector2(6, 0),
        right_ankle + Vector2(8, 2)
    ]), ink, 67, false)

    # Face details are tiny so the head stays human-scaled.
    _glyph_text(head + Vector2(-2.5, 1), ".", ink, 71)
    _glyph_text(head + Vector2(2.0, 1), ".", ink, 73)

func _glyph_ellipse(center: Vector2, radius: Vector2, _unused: float, ink: Color, seed: int) -> void:
    # Contour-only glyph ring leaves negative space inside the head and neck.
    var count := 28
    for i in range(count):
        if i % 7 == 0:
            continue
        var angle := TAU * float(i) / float(count)
        var p := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
        _glyph_text(p, GLYPHS[posmod(seed + i, GLYPHS.size())], ink, seed + i)

func _glyph_polygon(points: PackedVector2Array, ink: Color, seed: int, spacing: float) -> void:
    if points.size() < 3:
        return
    var min_x := points[0].x
    var max_x := points[0].x
    var min_y := points[0].y
    var max_y := points[0].y
    for p in points:
        min_x = minf(min_x, p.x)
        max_x = maxf(max_x, p.x)
        min_y = minf(min_y, p.y)
        max_y = maxf(max_y, p.y)
    var y := min_y
    var row := 0
    while y <= max_y:
        var x := min_x
        while x <= max_x:
            if Geometry2D.is_point_in_polygon(Vector2(x, y), points):
                _glyph_text(Vector2(x, y), GLYPHS[posmod(seed + row * 5 + int(x * 2.0), GLYPHS.size())], ink, seed + row)
            x += spacing
        y += spacing
        row += 1

func _glyph_limb(a: Vector2, b: Vector2, width: float, ink: Color, seed: int) -> void:
    # Two narrow contour rails, tapered at joints, with sparse interior hatching.
    var direction := b - a
    var length := direction.length()
    if length < 0.1:
        return
    var normal := direction.normalized().orthogonal()
    var steps := maxi(3, int(length / 3.5))
    var half_width := width * 0.5
    for i in range(steps + 1):
        var t := float(i) / float(steps)
        var center := a.lerp(b, t)
        var taper := 0.72 + 0.28 * sin(t * PI)
        var edge := normal * half_width * taper
        if i % 5 != 0:
            _glyph_text(center + edge, GLYPHS[posmod(seed + i, GLYPHS.size())], ink, seed + i)
            _glyph_text(center - edge, GLYPHS[posmod(seed + i + 3, GLYPHS.size())], ink, seed + i + 3)
        if i % 4 == 0:
            var shade := Color(ink.r * 0.72, ink.g * 0.72, ink.b * 0.72, ink.a)
            _glyph_text(center, GLYPHS[posmod(seed + i + 6, GLYPHS.size())], shade, seed + i + 6)

func _glyph_path(points: PackedVector2Array, ink: Color, seed: int, closed: bool) -> void:
    if points.size() < 2:
        return
    for i in range(points.size() - 1):
        var length := points[i].distance_to(points[i + 1])
        var count := maxi(2, int(length / 4.0))
        _glyph_segment(points[i], points[i + 1], count, ink, seed + i * 7)
    if closed:
        var length := points[points.size() - 1].distance_to(points[0])
        _glyph_segment(points[points.size() - 1], points[0], maxi(2, int(length / 4.0)), ink, seed + points.size() * 7)

func _glyph_segment(a: Vector2, b: Vector2, count: int, ink: Color, seed: int) -> void:
    for i in range(count):
        var t := float(i) / float(maxi(1, count - 1))
        _glyph_text(a.lerp(b, t), GLYPHS[posmod(seed + i * 3, GLYPHS.size())], ink, seed + i)

func _glyph_text(pos: Vector2, glyph: String, ink: Color, seed: int) -> void:
    var variation := 0.78 + float(posmod(seed * 7, 17)) / 100.0
    var color := Color(ink.r * variation, ink.g * variation, ink.b * variation, ink.a)
    draw_string(font, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, GLYPH_SIZE, color)
