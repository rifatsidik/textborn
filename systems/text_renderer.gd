class_name TextRenderer
extends Node2D

const FONT_SIZE := 12
const CELL_WIDTH := 8.0
const CELL_HEIGHT := 13.0

var glyph_rows: Array[String] = []
var glyph_color := Color(0.94, 0.96, 1.0)
var glyph_font: Font
var cell_size := Vector2(CELL_WIDTH, CELL_HEIGHT)

func _ready() -> void:
    glyph_font = ThemeDB.fallback_font

func set_rows(rows: Array[String]) -> void:
    glyph_rows = rows
    queue_redraw()

func _draw() -> void:
    if glyph_font == null:
        return

    for y in range(glyph_rows.size()):
        var line: String = glyph_rows[y]
        for x in range(line.length()):
            var glyph := line.substr(x, 1)
            if glyph == " ":
                continue

            var brightness := 0.72
            if glyph in ["@", "#", "%", "&", "8"]:
                brightness = 1.0
            elif glyph in [".", ",", "'", ":"]:
                brightness = 0.55

            draw_string(
                glyph_font,
                Vector2(x * cell_size.x, (y + 1) * cell_size.y),
                glyph,
                HORIZONTAL_ALIGNMENT_LEFT,
                -1,
                FONT_SIZE,
                Color(glyph_color, brightness)
            )
