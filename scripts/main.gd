extends Node2D

# THREADBOUND prototype: traverse the void by attaching to luminous anchors.
const WORLD_WIDTH := 2600.0
const FLOOR_Y := 650.0
const PLAYER_SCRIPT := preload("res://systems/threadbound_player.gd")

var player: CharacterBody2D
var anchors: Array[Vector2] = []
var hud: Label
var hint: Label

func _ready() -> void:
    _build_level()
    player = CharacterBody2D.new()
    player.set_script(PLAYER_SCRIPT)
    player.name = "Threadbound"
    player.position = Vector2(120.0, 560.0)
    add_child(player)
    player.set("grapple_anchors", anchors)

    var camera := Camera2D.new()
    camera.position = Vector2(0, -70)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 4.5
    camera.limit_left = 0
    camera.limit_right = int(WORLD_WIDTH)
    camera.limit_top = 0
    camera.limit_bottom = 720
    player.add_child(camera)
    camera.enabled = true

    _make_hud()
    queue_redraw()

func _build_level() -> void:
    _platform(Vector2(320, 650), Vector2(640, 70))
    _platform(Vector2(930, 575), Vector2(170, 28))
    _platform(Vector2(1390, 520), Vector2(180, 28))
    _platform(Vector2(1810, 455), Vector2(180, 28))
    _platform(Vector2(2300, 390), Vector2(260, 28))
    anchors = [
        Vector2(420, 405), Vector2(680, 330), Vector2(900, 390),
        Vector2(1110, 285), Vector2(1320, 350), Vector2(1550, 250),
        Vector2(1760, 300), Vector2(1990, 210), Vector2(2220, 245),
        Vector2(2450, 175)
    ]

func _platform(pos: Vector2, size: Vector2) -> void:
    var body := StaticBody2D.new()
    body.position = pos
    body.collision_layer = 1
    body.collision_mask = 1
    add_child(body)
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    var visual := Node2D.new()
    visual.set_script(load("res://systems/platform_visual.gd"))
    visual.set("platform_size", size)
    body.add_child(visual)

func _make_hud() -> void:
    hud = Label.new()
    hud.text = "THREADBOUND  //  CONSTELLATION TRAVERSAL"
    hud.position = Vector2(24, 18)
    hud.add_theme_color_override("font_color", Color(0.58, 0.88, 1.0))
    hud.add_theme_font_size_override("font_size", 17)
    hud.z_index = 20
    add_child(hud)

    hint = Label.new()
    hint.text = "A / D  MOVE     SPACE  JUMP     E  GRAPPLE / RELEASE     R  RESET"
    hint.position = Vector2(24, 43)
    hint.add_theme_color_override("font_color", Color(0.72, 0.79, 0.88))
    hint.add_theme_font_size_override("font_size", 13)
    hint.z_index = 20
    add_child(hint)

func _process(_delta: float) -> void:
    if is_instance_valid(player):
        var progress := clampf(player.global_position.x / WORLD_WIDTH, 0.0, 1.0) * 100.0
        hud.text = "THREADBOUND  //  DISTANCE %03d%%" % int(progress)
        if player.global_position.x > 2380.0:
            hint.text = "SIGNAL REACHED  //  PRESS R TO RUN AGAIN"
        else:
            hint.text = "A / D  MOVE     SPACE  JUMP     E  GRAPPLE / RELEASE     R  RESET"

func _draw() -> void:
    # Faint cosmic grid and anchor halos.
    for x in range(0, int(WORLD_WIDTH), 80):
        draw_line(Vector2(x, 80), Vector2(x, 720), Color(0.12, 0.24, 0.32, 0.18), 1.0)
    for y in range(120, 720, 80):
        draw_line(Vector2(0, y), Vector2(WORLD_WIDTH, y), Color(0.12, 0.24, 0.32, 0.14), 1.0)
    for i in range(anchors.size()):
        var a := anchors[i]
        draw_circle(a, 16.0, Color(0.08, 0.45, 0.75, 0.10))
        draw_arc(a, 9.0, 0.0, TAU, 24, Color(0.22, 0.72, 1.0, 0.72), 1.2, true)
        draw_circle(a, 2.7, Color(0.75, 0.96, 1.0, 1.0))
        draw_circle(a, 1.0, Color.WHITE)
