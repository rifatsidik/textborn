extends Node2D
class_name TextbornGlyphRenderer

# Glyph-only renderer with a controlled sampling interval. Glyphs are spaced
# farther apart than their font advance to prevent the noisy white clumps.
const FONT_SIZE := 10
const GLYPHS: Array[String] = ["|", "/", "\\", "(", ")", ".", ":", "_"]

var font: Font
var pose: Dictionary = {}

func _ready() -> void:
    font = ThemeDB.fallback_font

func set_pose(next_pose: Dictionary) -> void:
    pose = next_pose
    queue_redraw()

func _draw() -> void:
    if font == null or pose.is_empty():
        return
    var bright := Color(0.92, 0.95, 1.0, 1.0)
    var soft := Color(0.68, 0.76, 0.86, 1.0)
    var far := Color(0.34, 0.43, 0.54, 0.9)

    var head: Vector2 = pose["head"]
    var neck: Vector2 = pose["neck"]
    var chest: Vector2 = pose["chest"]
    var pelvis: Vector2 = pose["pelvis"]
    var ls: Vector2 = pose["left_shoulder"]
    var rs: Vector2 = pose["right_shoulder"]
    var le: Vector2 = pose["left_elbow"]
    var re: Vector2 = pose["right_elbow"]
    var lh: Vector2 = pose["left_hand"]
    var rh: Vector2 = pose["right_hand"]
    var lhip: Vector2 = pose["left_hip"]
    var rhip: Vector2 = pose["right_hip"]
    var lk: Vector2 = pose["left_knee"]
    var rk: Vector2 = pose["right_knee"]
    var la: Vector2 = pose["left_ankle"]
    var ra: Vector2 = pose["right_ankle"]

    # Skull and jaw, sampled sparsely for a cleaner silhouette.
    _ellipse(head, Vector2(6.0, 8.0), bright, 1)
    _line(head + Vector2(-4.5, 2.0), head + Vector2(-2.5, 6.0), soft, 3)
    _line(head + Vector2(-2.5, 6.0), head + Vector2(0.0, 7.0), soft, 5)
    _line(head + Vector2(0.0, 7.0), head + Vector2(3.5, 4.0), soft, 7)
    _line(head + Vector2(-4.5, -3.0), head + Vector2(-1.5, -7.0), soft, 9)
    _line(head + Vector2(-1.5, -7.0), head + Vector2(2.5, -6.5), soft, 11)
    _glyph(head + Vector2(-2.0, 0.0), ".", soft, 13)
    _glyph(head + Vector2(2.0, 0.0), ".", soft, 14)

    # Narrow shoulder line and tapered torso. Avoid drawing a second inner body.
    _line(neck + Vector2(-2.0, -1.0), chest + Vector2(-5.5, -1.0), bright, 17)
    _line(chest + Vector2(-5.5, -1.0), chest + Vector2(-7.0, 3.0), bright, 19)
    _line(chest + Vector2(-7.0, 3.0), chest + Vector2(-5.0, 13.0), bright, 21)
    _line(chest + Vector2(-5.0, 13.0), pelvis + Vector2(-3.5, -1.0), bright, 23)
    _line(neck + Vector2(2.0, -1.0), chest + Vector2(5.5, -1.0), bright, 25)
    _line(chest + Vector2(5.5, -1.0), chest + Vector2(7.0, 3.0), bright, 27)
    _line(chest + Vector2(7.0, 3.0), chest + Vector2(5.0, 13.0), bright, 29)
    _line(chest + Vector2(5.0, 13.0), pelvis + Vector2(3.5, -1.0), bright, 31)
    _line(pelvis + Vector2(-3.5, -1.0), pelvis + Vector2(0.0, 4.0), soft, 33)
    _line(pelvis + Vector2(0.0, 4.0), pelvis + Vector2(3.5, -1.0), soft, 35)

    # Draw the far limbs first; near limbs are brighter but share anatomy.
    _limb(ls, le, 1.8, far, 37)
    _limb(le, lh, 1.5, far, 41)
    _limb(rs, re, 1.8, soft, 43)
    _limb(re, rh, 1.5, bright, 47)
    _limb(lhip, lk, 2.0, far, 53)
    _limb(lk, la, 1.7, far, 59)
    _limb(rhip, rk, 2.0, soft, 61)
    _limb(rk, ra, 1.7, bright, 67)
    _foot(la, far, 71)
    _foot(ra, bright, 73)

func _ellipse(center: Vector2, radius: Vector2, color: Color, seed: int) -> void:
    const COUNT := 24
    for i in range(COUNT):
        if i % 2 == 0:
            var a := TAU * float(i) / float(COUNT)
            _glyph(center + Vector2(cos(a) * radius.x, sin(a) * radius.y), GLYPHS[posmod(seed + i, GLYPHS.size())], color, seed + i)

func _limb(a: Vector2, b: Vector2, width: float, color: Color, seed: int) -> void:
    var delta := b - a
    if delta.length() < 1.0:
        return
    var normal := delta.normalized().orthogonal() * width
    var count := maxi(2, int(delta.length() / 7.0))
    for i in range(count + 1):
        var t := float(i) / float(count)
        var p := a.lerp(b, t)
        _glyph(p + normal, GLYPHS[posmod(seed + i, GLYPHS.size())], color, seed + i)
        if i % 2 == 0:
            _glyph(p - normal, GLYPHS[posmod(seed + i + 3, GLYPHS.size())], color, seed + i + 3)

func _foot(ankle: Vector2, color: Color, seed: int) -> void:
    _line(ankle + Vector2(-1.0, 0.0), ankle + Vector2(4.0, 0.0), color, seed)
    _line(ankle + Vector2(4.0, 0.0), ankle + Vector2(7.0, 1.0), color, seed + 2)

func _line(a: Vector2, b: Vector2, color: Color, seed: int) -> void:
    var distance := a.distance_to(b)
    var count := maxi(1, int(distance / 6.5))
    for i in range(count + 1):
        _glyph(a.lerp(b, float(i) / float(count)), GLYPHS[posmod(seed + i, GLYPHS.size())], color, seed + i)

func _glyph(pos: Vector2, value: String, color: Color, seed: int) -> void:
    var shade := 0.96 + float(posmod(seed * 3, 5)) / 100.0
    draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(color.r * shade, color.g * shade, color.b * shade, color.a))
