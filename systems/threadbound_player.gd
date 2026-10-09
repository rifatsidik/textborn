extends CharacterBody2D

const MOVE_SPEED := 235.0
const GROUND_ACCEL := 1050.0
const AIR_ACCEL := 500.0
const GRAVITY := 900.0
const JUMP_SPEED := -360.0
const ROPE_LENGTH := 250.0
const MAX_GRAPPLE_DISTANCE := 330.0

var grapple_anchors: Array[Vector2] = []
var grapple_point := Vector2.ZERO
var is_grappling := false
var elapsed := 0.0
var tether_length := ROPE_LENGTH
var font: Font

func _ready() -> void:
    font = ThemeDB.fallback_font
    var collision := CollisionShape2D.new()
    var capsule := CapsuleShape2D.new()
    capsule.radius = 7.0
    capsule.height = 34.0
    collision.shape = capsule
    collision.position = Vector2(0, -17)
    add_child(collision)
    floor_snap_length = 6.0

func _physics_process(delta: float) -> void:
    elapsed += delta
    if Input.is_key_pressed(KEY_R):
        global_position = Vector2(120, 560)
        velocity = Vector2.ZERO
        is_grappling = false

    var direction := Input.get_axis("ui_left", "ui_right")
    var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
    velocity.x = move_toward(velocity.x, direction * MOVE_SPEED, accel * delta)
    velocity.y += GRAVITY * delta

    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_SPEED
    if Input.is_key_pressed(KEY_E) and not is_grappling:
        _try_grapple()
    if Input.is_action_just_pressed("ui_focus_next"):
        is_grappling = false
    if Input.is_key_pressed(KEY_Q) and is_grappling:
        is_grappling = false

    if is_grappling:
        _apply_tether(delta)
    move_and_slide()
    if is_grappling and global_position.distance_to(grapple_point) > MAX_GRAPPLE_DISTANCE * 1.35:
        is_grappling = false
    queue_redraw()

func _try_grapple() -> void:
    var best := MAX_GRAPPLE_DISTANCE
    var chosen := Vector2.ZERO
    for anchor in grapple_anchors:
        var d := global_position.distance_to(anchor)
        if d < best:
            best = d
            chosen = anchor
    if chosen != Vector2.ZERO:
        grapple_point = chosen
        tether_length = minf(ROPE_LENGTH, global_position.distance_to(chosen))
        is_grappling = true

func _apply_tether(delta: float) -> void:
    var offset := grapple_point - global_position
    var distance := offset.length()
    if distance < 0.001:
        return
    var direction := offset / distance
    var stretch := maxf(0.0, distance - tether_length)
    var outward_speed := velocity.dot(-direction)
    velocity += direction * (stretch * 7.0 + maxf(0.0, outward_speed) * 1.7) * delta
    if distance > tether_length + 8.0 and velocity.dot(direction) > 0.0:
        velocity -= direction * velocity.dot(direction) * 0.22

func _draw() -> void:
    var bright := Color(0.88, 0.98, 1.0, 1.0)
    var cyan := Color(0.25, 0.78, 1.0, 0.92)
    var dim := Color(0.16, 0.48, 0.72, 0.85)
    if is_grappling:
        var target := to_local(grapple_point)
        draw_line(Vector2(0, -17), target, Color(0.18, 0.65, 1.0, 0.18), 5.0, true)
        draw_line(Vector2(0, -17), target, cyan, 1.5, true)
        draw_circle(target, 5.0 + (0.5 + 0.5 * sin(elapsed * 9.0)) * 2.0, Color(0.25, 0.8, 1.0, 0.22))
        draw_circle(target, 2.0, bright)

    var bob := sin(elapsed * 8.0) * 1.2 if is_on_floor() and absf(velocity.x) > 20.0 else 0.0
    var head := Vector2(0, -34 + bob)
    var neck := Vector2(0, -25 + bob)
    var chest := Vector2(0, -21 + bob)
    var pelvis := Vector2(0, -12 + bob)
    var ls := chest + Vector2(-5, 1)
    var rs := chest + Vector2(5, 1)
    var moving := is_on_floor() and absf(velocity.x) > 20.0
    var arm_swing := sin(elapsed * 8.0) * 3.0 if moving else 0.0
    var le := ls + Vector2(-2 - arm_swing, 7)
    var re := rs + Vector2(2 + arm_swing, 7)
    var lh := le + Vector2(-1, 6)
    var rh := re + Vector2(1, 6)
    var lhip := pelvis + Vector2(-2, 0)
    var rhip := pelvis + Vector2(2, 0)
    var leg_swing := sin(elapsed * 8.0) * 4.0 if moving else 0.0
    var lk := lhip + Vector2(-2 + leg_swing, 7)
    var rk := rhip + Vector2(2 - leg_swing, 7)
    var la := lk + Vector2(-1 + leg_swing * 0.6, 7)
    var ra := rk + Vector2(1 - leg_swing * 0.6, 7)

    _link(head, neck, dim)
    _link(neck, chest, cyan)
    _link(chest, pelvis, cyan)
    _link(ls, rs, dim)
    _link(ls, le, dim)
    _link(le, lh, cyan)
    _link(rs, re, cyan)
    _link(re, rh, cyan)
    _link(pelvis, lhip, dim)
    _link(pelvis, rhip, cyan)
    _link(lhip, lk, dim)
    _link(lk, la, dim)
    _link(rhip, rk, cyan)
    _link(rk, ra, cyan)
    draw_arc(head, 5.8, 0, TAU, 20, bright, 1.3, true)
    draw_arc(head, 3.5, elapsed * 1.8, elapsed * 1.8 + PI * 1.4, 16, cyan, 1.1, true)
    for joint in [neck, chest, pelvis, ls, rs, le, re, lh, rh, lhip, rhip, lk, rk, la, ra]:
        draw_circle(joint, 2.3, Color(0.18, 0.62, 1.0, 0.24))
        draw_circle(joint, 1.2, bright)
    draw_circle(head, 1.8, bright)
    draw_arc(Vector2(0, 1), 9.0, 0.0, TAU, 18, Color(0.25, 0.75, 1.0, 0.35), 1.0, true)

func _link(a: Vector2, b: Vector2, color: Color) -> void:
    draw_line(a, b, Color(color.r, color.g, color.b, 0.18), 4.0, true)
    draw_line(a, b, color, 1.2, true)
