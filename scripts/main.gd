extends Node2D

const WORLD_WIDTH := 2400.0

func _ready() -> void:
    _create_platform(Vector2(600, 650), Vector2(1200, 60))
    _create_platform(Vector2(1400, 540), Vector2(250, 35))
    _create_platform(Vector2(1750, 430), Vector2(250, 35))
    _create_platform(Vector2(2050, 330), Vector2(250, 35))

    var player_script := load("res://scripts/player.gd")
    var player := CharacterBody2D.new()
    player.set_script(player_script)
    player.name = "Player"
    player.position = Vector2(150, 590)
    add_child(player)

    var camera := Camera2D.new()
    camera.position = Vector2(0, -100)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 5.0
    camera.limit_left = 0
    camera.limit_right = int(WORLD_WIDTH)
    camera.limit_top = 0
    camera.limit_bottom = 720
    player.add_child(camera)
    camera.enabled = true

    _create_label()

func _create_platform(pos: Vector2, dimensions: Vector2) -> void:
    var body := StaticBody2D.new()
    body.position = pos
    add_child(body)

    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = dimensions
    collision.shape = shape
    body.add_child(collision)

    var visual := Node2D.new()
    visual.set_script(load("res://systems/platform_visual.gd"))
    visual.set("platform_size", dimensions)
    body.add_child(visual)

func _create_label() -> void:
    var label := Label.new()
    label.text = "TEXTBORN  //  A WORLD MADE OF GLYPHS\nARROW KEYS: MOVE     SPACE: JUMP"
    label.position = Vector2(24, 20)
    label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
    label.add_theme_font_size_override("font_size", 15)
    label.z_index = 10
    add_child(label)
