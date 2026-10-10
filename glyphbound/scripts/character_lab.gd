extends Node2D
## GLYPHBOUND Character Lab v0.1
## Procedural side-view human silhouette built from glyphs, not a sprite.

const GlyphHuman = preload("res://scripts/glyph_human.gd")

var player: Node2D
var mode_index: int = 0
var modes: Array[String] = ["IDLE", "WALK", "RUN", "JUMP", "ATTACK"]
var elapsed: float = 0.0

func _ready() -> void:
	player = GlyphHuman.new()
	player.position = Vector2(470.0, 390.0)
	add_child(player)
	player.set("animation_mode", "IDLE")
	player.set("glyph_density", 1.0)

func _process(delta: float) -> void:
	elapsed += delta
	if Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_accept"):
		mode_index = (mode_index + 1) % modes.size()
		player.set("animation_mode", modes[mode_index])
	if Input.is_action_just_pressed("ui_left"):
		mode_index = posmod(mode_index - 1, modes.size())
		player.set("animation_mode", modes[mode_index])
	if Input.is_action_pressed("ui_right") and modes[mode_index] == "IDLE":
		player.set("animation_mode", "WALK")
	elif Input.is_action_just_released("ui_right") and modes[mode_index] == "WALK":
		player.set("animation_mode", "IDLE")
	queue_redraw()

func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	# Subtle technical grid and baseline.
	for x in range(0, int(viewport_size.x), 40):
		draw_line(Vector2(x, 90), Vector2(x, viewport_size.y - 65), Color(0.22, 0.27, 0.32, 0.12), 1.0)
	for y in range(100, int(viewport_size.y), 40):
		draw_line(Vector2(40, y), Vector2(viewport_size.x - 40, y), Color(0.22, 0.27, 0.32, 0.10), 1.0)
	draw_line(Vector2(80, 570), Vector2(viewport_size.x - 80, 570), Color(0.72, 0.82, 0.90, 0.42), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(54, 48), "GLYPHBOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.91, 0.96, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(56, 73), "CHARACTER LAB  /  v0.1  /  PROCEDURAL GLYPH CONTOUR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.49, 0.62, 0.72))
	draw_string(ThemeDB.fallback_font, Vector2(56, 112), "01  HUMAN SILHOUETTE STUDY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.61, 0.76, 0.84))
	draw_string(ThemeDB.fallback_font, Vector2(820, 142), "DESIGN TARGETS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.83, 0.92))
	var notes: Array[String] = [
		"01 / Side-view anatomy",
		"02 / Glyph-built contour",
		"03 / Adaptive character density",
		"04 / Real-time pose animation",
		"05 / No character PNG sprites"
	]
	for i in range(notes.size()):
		draw_string(ThemeDB.fallback_font, Vector2(820, 178 + i * 28), notes[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.79, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(820, 370), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.83, 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(820, 398), "RIGHT / walk", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.79, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(820, 424), "LEFT / previous pose", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.79, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(820, 450), "ENTER / next pose", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.79, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(820, 520), "POSE: " + modes[mode_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.52, 0.88, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(54, 650), "WHITE GLYPHS  /  BLACK VOID  /  COLOR RESERVED FOR ENERGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.42, 0.53, 0.62))
