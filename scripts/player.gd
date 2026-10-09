extends CharacterBody2D

const SPEED := 250.0
const RUN_SPEED := 360.0
const JUMP_VELOCITY := -440.0
const GRAVITY := 1150.0

const FONT_SIZE := 12
const GLYPH_STEP := 5.5

const GLYPHS := ["0", "1", "#", "%", "@", "&", "X", "/", "\\", "+", "=", "*", ":", "."]

var facing := 1
var phase := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var visual_font: Font
var anim_state := "idle"
var hit_flash := 0.0

func _ready() -> void:
    visual_font = ThemeDB.fallback_font
    queue_redraw()

    var collision := CollisionShape2D.new()
    collision.name = "BodyCollision"
    var shape := CapsuleShape2D.new()
    shape.radius = 18.0
    shape.height = 110.0
    collision.shape = shape
    collision.position = Vector2(0, -55)
    add_child(collision)

func _physics_process(delta: float) -> void:
    phase += delta * (9.0 if abs(velocity.x) > 20.0 else 2.0)
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    attack_time = maxf(0.0, attack_time - delta)
    hit_flash = maxf(0.0, hit_flash - delta)

    if not is_on_floor():
        velocity.y += GRAVITY * delta

    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var direction := Input.get_axis("ui_left", "ui_right")
    var sprint := Input.is_key_pressed(KEY_SHIFT)
    var speed := RUN_SPEED if sprint else SPEED

    velocity.x = direction * speed

    if direction != 0:
        facing = int(sign(direction))

    if Input.is_key_pressed(KEY_X) and attack_cooldown <= 0.0:
        attack_time = 0.42
        attack_cooldown = 0.52

    if attack_time > 0.0:
        anim_state = "attack"
    elif not is_on_floor():
        anim_state = "jump"
    elif abs(velocity.x) > 20.0:
        anim_state = "run" if sprint else "walk"
    else:
        anim_state = "idle"

    move_and_slide()
    queue_redraw()

func _draw() -> void:
    if visual_font == null:
        return

    var bob := 0.0
    if anim_state == "idle":
        bob = sin(phase) * 1.5
    elif anim_state == "walk" or anim_state == "run":
        bob = abs(sin(phase)) * 3.0

    var lean := 0.0
    if anim_state == "run":
        lean = -5.0
    elif anim_state == "attack":
        lean = -3.0

    var hip := Vector2(0, -65 + bob)
    var chest := Vector2(lean, -105 + bob)
    var neck := chest + Vector2(0, -9)
    var head := neck + Vector2(0, -17)

    var left_shoulder := chest + Vector2(-11, 2)
    var right_shoulder := chest + Vector2(11, 2)
    var left_elbow: Vector2
    var right_elbow: Vector2
    var left_hand: Vector2
    var right_hand: Vector2

    var left_hip := hip + Vector2(-7, 0)
    var right_hip := hip + Vector2(7, 0)
    var left_knee: Vector2
    var right_knee: Vector2
    var left_foot: Vector2
    var right_foot: Vector2

    if anim_state == "walk" or anim_state == "run":
        var stride := sin(phase) * (15.0 if anim_state == "walk" else 23.0)
        left_knee = left_hip + Vector2(stride, 17)
        right_knee = right_hip + Vector2(-stride, 17)
        left_foot = left_knee + Vector2(stride * 0.65, 24)
        right_foot = right_knee + Vector2(-stride * 0.65, 24)

        left_elbow = left_shoulder + Vector2(-stride * 0.65, 14)
        right_elbow = right_shoulder + Vector2(stride * 0.65, 14)
        left_hand = left_elbow + Vector2(-stride * 0.5, 15)
        right_hand = right_elbow + Vector2(stride * 0.5, 15)
    elif anim_state == "jump":
        left_knee = left_hip + Vector2(-10, 14)
        right_knee = right_hip + Vector2(12, 10)
        left_foot = left_knee + Vector2(-8, 15)
        right_foot = right_knee + Vector2(9, 18)

        left_elbow = left_shoulder + Vector2(-16, -10)
        right_elbow = right_shoulder + Vector2(15, -12)
        left_hand = left_elbow + Vector2(-3, -12)
        right_hand = right_elbow + Vector2(4, -12)
    elif anim_state == "attack":
        var progress := 1.0 - attack_time / 0.42
        left_knee = left_hip + Vector2(-7, 19)
        right_knee = right_hip + Vector2(10, 18)
        left_foot = left_knee + Vector2(-5, 23)
        right_foot = right_knee + Vector2(8, 23)

        left_elbow = left_shoulder + Vector2(-12, 12)
        left_hand = left_elbow + Vector2(-5, 15)

        var windup := progress < 0.3
        right_elbow = right_shoulder + Vector2(
            -facing * 15 if windup else facing * 17, -18 if windup else 3
        )
        right_hand = right_elbow + Vector2(
            -facing * 12 if windup else facing * 20, -10 if windup else -8
        )
    else:
        left_knee = left_hip + Vector2(-5, 20)
        right_knee = right_hip + Vector2(5, 20)
        left_foot = left_knee + Vector2(-4, 24)
        right_foot = right_knee + Vector2(4, 24)

        left_elbow = left_shoulder + Vector2(-8, 15)
        right_elbow = right_shoulder + Vector2(8, 15)
        left_hand = left_elbow + Vector2(-2, 15)
        right_hand = right_elbow + Vector2(2, 15)

    var ink := Color(0.94, 0.96, 1.0)
    if hit_flash > 0.0:
        ink = Color.WHITE

    # Legs: glyphs follow animated joints.
    _glyph_segment(left_hip, left_knee, 15, ink, 2)
    _glyph_segment(left_knee, left_foot, 17, ink, 3)
    _glyph_segment(right_hip, right_knee, 15, ink, 5)
    _glyph_segment(right_knee, right_foot, 17, ink, 7)

    # Torso and clothing details.
    _glyph_segment(left_shoulder, right_shoulder, 8, ink, 11)
    _glyph_segment(left_shoulder, hip + Vector2(-4, 0), 19, ink, 13)
    _glyph_segment(right_shoulder, hip + Vector2(4, 0), 19, ink, 17)
    _glyph_segment(chest, hip, 15, ink, 19)
    _glyph_segment(left_shoulder, right_hip, 14, ink, 23)
    _glyph_segment(right_shoulder, left_hip, 14, ink, 29)

    # Arms.
    _glyph_segment(left_shoulder, left_elbow, 13, ink, 31)
    _glyph_segment(left_elbow, left_hand, 12, ink, 37)
    _glyph_segment(right_shoulder, right_elbow, 13, ink, 41)
    _glyph_segment(right_elbow, right_hand, 12, ink, 43)

    # Head: dense glyph ring, face, hair and eyes.
    _glyph_ellipse(head, Vector2(10, 13), 44, ink, 47)
    _glyph_segment(head + Vector2(-8, -6), head + Vector2(8, -6), 5, ink, 53)
    _glyph_text(head + Vector2(-6, 1), "0 0", ink, 12)
    _glyph_text(head + Vector2(-3, 7), "###", ink, 19)

    # Boots and hands.
    _glyph_segment(left_foot, left_foot + Vector2(9, 0), 5, ink, 59)
    _glyph_segment(right_foot, right_foot + Vector2(9, 0), 5, ink, 61)
    _glyph_text(left_hand, "@", ink, 67)
    _glyph_text(right_hand, "@", ink, 71)

    # Sword is also text geometry, not an image.
    if anim_state == "attack":
        var progress := 1.0 - attack_time / 0.42
        var start := right_hand
        var tip := start + Vector2(facing * 72, -12 if progress < 0.3 else 8)
        _glyph_segment(start, tip, 28, Color(1, 1, 1), 73)
        _glyph_text(tip, ">", Color.WHITE, 79)

        if progress > 0.25 and progress < 0.8:
            for i in range(16):
                var t := float(i) / 15.0
                var angle := lerpf(-1.1, 1.1, t)
                var radius := 48.0 + sin(t * PI) * 15.0
                var point := chest + Vector2(
                    cos(angle) * radius * facing,
                    sin(angle) * radius - 5
                )
                _glyph_text(point, ["-", "/", "*", "\\", "+"][i % 5], ink, i + 83)

func _glyph_segment(a: Vector2, b: Vector2, count: int, ink: Color, seed: int) -> void:
    for i in range(count):
        var t := float(i) / float(maxi(1, count - 1))
        var p := a.lerp(b, t)
        var offset := Vector2(
            sin(float(i * 7 + seed)) * 2.0,
            cos(float(i * 11 + seed)) * 2.0
        )
        var glyph: String = str(GLYPHS[posmod(i * 7 + seed, GLYPHS.size())])
        _glyph_text(p + offset, glyph, ink, seed + i)

func _glyph_ellipse(center: Vector2, radius: Vector2, count: int, ink: Color, seed: int) -> void:
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        var p := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
        _glyph_text(p, GLYPHS[posmod(i + seed, GLYPHS.size())], ink, seed + i)

func _glyph_text(pos: Vector2, glyph: String, ink: Color, seed: int) -> void:
    var variation := 0.72 + float(posmod(seed * 13, 29)) / 100.0
    var color := Color(ink.r * variation, ink.g * variation, ink.b * variation, 1.0)
    draw_string(visual_font, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
