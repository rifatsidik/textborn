extends Node2D

@export var platform_size := Vector2(400, 40)

func _draw() -> void:
    var columns := int(platform_size.x / 8.0)
    var rows := int(platform_size.y / 13.0)

    for y in range(rows):
        var line := ""
        for x in range(columns):
            if y == 0:
                line += "="
            elif y == rows - 1:
                line += "#"
            elif x == 0 or x == columns - 1:
                line += "|"
            elif (x + y) % 7 == 0:
                line += "+"
            elif (x * 3 + y) % 11 == 0:
                line += "."
            else:
                line += " "
        draw_string(
            ThemeDB.fallback_font,
            Vector2(0, (y + 1) * 13.0),
            line,
            HORIZONTAL_ALIGNMENT_LEFT,
            -1,
            12,
            Color(0.85, 0.88, 0.92)
        )
