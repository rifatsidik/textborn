extends Node2D
class_name TextbornGlyphRenderer

const FONT_SIZE := 10
const GLYPHS: Array[String] = ["I", "|", "/", "\\", ":", ".", "-", "x", "+"]

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
    var ink := Color(0.91, 0.94, 0.98, 1.0)
    var dim := Color(0.46, 0.52, 0.60, 1.0)

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

    # Head contour with restrained hairline and facial guide marks.
    _ellipse_outline(head, Vector2(6.5, 8.5), ink, 1)
    _path(PackedVector2Array([head + Vector2(-5.2, -4.5), head + Vector2(-2.5, -7.5), head + Vector2(2.5, -7.5), head + Vector2(5.0, -4.5)]), dim, 3, false)
    _glyph(head + Vector2(-2.0, 1.0), ".", ink, 5)
    _glyph(head + Vector2(2.0, 1.0), ".", ink, 7)

    # Neck, shoulder slope, rib cage and waist: only perimeter glyphs.
    _path(PackedVector2Array([
        neck + Vector2(-2.2, -1.0), chest + Vector2(-5.8, -1.0),
        chest + Vector2(-8.0, 2.0), chest + Vector2(-7.0, 12.0),
        pelvis + Vector2(-4.2, -1.0), pelvis + Vector2(4.2, -1.0),
        chest + Vector2(7.0, 12.0), chest + Vector2(8.0, 2.0),
        chest + Vector2(5.8, -1.0), neck + Vector2(2.2, -1.0)
    ]), ink, 11, true)
    _path(PackedVector2Array([pelvis + Vector2(-4.2, -1), pelvis + Vector2(-2.8, 4), pelvis + Vector2(0, 6), pelvis + Vector2(2.8, 4), pelvis + Vector2(4.2, -1)]), ink, 19, false)
    _path(PackedVector2Array([chest + Vector2(-3.2, 8), chest + Vector2(3.2, 8)]), dim, 23, false)
    _path(PackedVector2Array([chest + Vector2(-2.8, 16), chest + Vector2(2.8, 16)]), dim, 29, false)

    # Limbs are drawn as paired contour rails, not filled glyph tubes.
    _limb(ls, le, 3.0, ink, 31)
    _limb(le, lh, 2.0, ink, 37)
    _limb(rs, re, 3.0, ink, 41)
    _limb(re, rh, 2.0, ink, 43)
    # Far leg is quieter and drawn first; the near leg carries the clear contour.
    _limb(lhip, lk, 2.5, dim, 47)
    _limb(lk, la, 2.1, dim, 53)
    _limb(rhip, rk, 2.5, ink, 59)
    _limb(rk, ra, 2.1, ink, 61)

    # Hands and feet: short contour strokes only.
    _path(PackedVector2Array([lh + Vector2(-1, -1), lh + Vector2(1, 2), lh + Vector2(2, 4)]), ink, 67, false)
    _path(PackedVector2Array([rh + Vector2(-1, -1), rh + Vector2(1, 2), rh + Vector2(2, 4)]), ink, 71, false)
    _path(PackedVector2Array([la + Vector2(-1.5, 0), la + Vector2(3.5, 0.4), la + Vector2(5.5, 1.2)]), dim, 73, false)
    _path(PackedVector2Array([ra + Vector2(-1.5, 0), ra + Vector2(3.5, 0.4), ra + Vector2(5.5, 1.2)]), ink, 79, false)

func _ellipse_outline(center: Vector2, radius: Vector2, color: Color, seed: int) -> void:
    const COUNT := 32
    for i in range(COUNT):
        if i % 8 == 0:
            continue
        var angle := TAU * float(i) / float(COUNT)
        _glyph(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y), GLYPHS[posmod(seed + i, GLYPHS.size())], color, seed + i)

func _limb(a: Vector2, b: Vector2, width: float, color: Color, seed: int) -> void:
    var delta := b - a
    if delta.length() < 0.1:
        return
    var normal := delta.normalized().orthogonal()
    var count := maxi(3, int(delta.length() / 3.8))
    for i in range(count + 1):
        var t := float(i) / float(count)
        var center := a.lerp(b, t)
        var taper := 0.65 + 0.35 * sin(t * PI)
        var offset := normal * width * 0.5 * taper
        # Sparse paired rails retain negative space; rare center marks imply form.
        if i % 3 != 0:
            _glyph(center + offset, GLYPHS[posmod(seed + i, GLYPHS.size())], color, seed + i)
            _glyph(center - offset, GLYPHS[posmod(seed + i + 2, GLYPHS.size())], color, seed + i + 2)
        if i % 8 == 0:
            _glyph(center, ".", Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, color.a), seed + i + 5)

func _path(points: PackedVector2Array, color: Color, seed: int, closed: bool) -> void:
    if points.size() < 2:
        return
    for i in range(points.size() - 1):
        var count := maxi(2, int(points[i].distance_to(points[i + 1]) / 3.5))
        _segment(points[i], points[i + 1], count, color, seed + i * 7)
    if closed:
        var count := maxi(2, int(points[points.size() - 1].distance_to(points[0]) / 3.5))
        _segment(points[points.size() - 1], points[0], count, color, seed + points.size() * 7)

func _segment(a: Vector2, b: Vector2, count: int, color: Color, seed: int) -> void:
    for i in range(count + 1):
        var p := a.lerp(b, float(i) / float(count))
        _glyph(p, GLYPHS[posmod(seed + i * 3, GLYPHS.size())], color, seed + i)

func _glyph(pos: Vector2, value: String, color: Color, seed: int) -> void:
    var shade := 0.88 + float(posmod(seed * 7, 13)) / 100.0
    var tint := Color(color.r * shade, color.g * shade, color.b * shade, color.a)
    draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint)
