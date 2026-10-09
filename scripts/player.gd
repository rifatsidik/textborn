extends CharacterBody2D

const WALK_SPEED: float = 125.0
const GROUND_ACCELERATION: float = 720.0
const GROUND_DECELERATION: float = 900.0
const GRAVITY: float = 1100.0
const JUMP_SPEED: float = -380.0

const CharacterRig = preload("res://systems/character_rig.gd")
const GlyphRenderer = preload("res://systems/glyph_renderer.gd")

var rig: RefCounted
var glyph_renderer: Node2D
var gait_phase: float = 0.0
var walk_blend: float = 0.0

func _ready() -> void:
    rig = CharacterRig.new()
    glyph_renderer = GlyphRenderer.new()
    glyph_renderer.name = "GlyphRenderer"
    add_child(glyph_renderer)

    var collision := CollisionShape2D.new()
    collision.name = "BodyCollision"
    var capsule := CapsuleShape2D.new()
    capsule.radius = 9.0
    capsule.height = 118.0
    collision.shape = capsule
    collision.position = Vector2(0.0, -59.0)
    add_child(collision)

    _update_visual()

func _physics_process(delta: float) -> void:
    var direction := Input.get_axis("ui_left", "ui_right")
    var target_speed := direction * WALK_SPEED

    if absf(direction) > 0.01:
        velocity.x = move_toward(velocity.x, target_speed, GROUND_ACCELERATION * delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)

    if not is_on_floor():
        velocity.y += GRAVITY * delta
    elif velocity.y > 0.0:
        velocity.y = 0.0

    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_SPEED

    var moving := absf(velocity.x) > 8.0 and is_on_floor()
    walk_blend = move_toward(walk_blend, 1.0 if moving else 0.0, delta * 3.8)
    if moving:
        # One full gait cycle per stride rhythm; restrained cadence.
        gait_phase = fposmod(gait_phase + delta * 7.0 * clampf(absf(velocity.x) / WALK_SPEED, 0.0, 1.0), TAU)

    move_and_slide()
    _update_visual()

func _update_visual() -> void:
    if rig != null and glyph_renderer != null:
        glyph_renderer.set_pose(rig.build_pose(gait_phase, walk_blend))
