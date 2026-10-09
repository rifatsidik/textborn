extends Node2D
class_name TextbornGlyphRenderer

# Character is drawn only with font glyphs. Contours are deliberately clean and
# anatomical; random-looking glyph noise is kept out of joints and face.
const FONT_SIZE := 9
const CONTOUR_GLYPHS: Array[String] = ["|", "/", "\\", "(", ")", "—", ".", ":"]
const DETAIL_GLYPHS: Array[String] = [".", ":", "·", "|"]

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
    var ink := Color(0.92, 0.95, 1.0, 1.0)
    var mid := Color(0.70, 0.77, 0.86, 1.0)
    var far := Color(0.38, 0.45, 0.54, 0.9)

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

    # Head: slightly oval skull, readable jaw, short hairline and restrained face.
    _ellipse(head, Vector2(6.0, 8.0), ink, 1)
    _path(PackedVector2Array([
        head + Vector2(-4.5, 2.0), head + Vector2(-3.2, 5.0),
        head + Vector2(0.0, 7.0), head + Vector2(3.2, 5.0),
        head + Vector2(4.5, 2.0)
    ]), mid, 5, false, 4.0)
    _path(PackedVector2Array([
        head + Vector2(-4.5, -3.5), head + Vector2(-2.0, -7.0),
        head + Vector2(1.5, -7.3), head + Vector2(4.6, -4.0)
    ]), mid, 9, false, 4.0)
    _glyph(head + Vector2(-2.4, 0.5), ".", mid, 11)
    _glyph(head + Vector2(1.5, 0.5), ".", mid, 12)

    # Neck and lean torso: sloped shoulders, tapered ribcage, visible waist.
    _path(PackedVector2Array([
        neck + Vector2(-2.0, -1.0), chest + Vector2(-4.8, -1.0),
        chest + Vector2(-7.0, 1.5), chest + Vector2(-6.0, 9.0),
        chest + Vector2(-4.2, 15.0), pelvis + Vector2(-3.8, -1.0),
        pelvis + Vector2(3.8, -1.0), chest + Vector2(4.2, 15.0),
        chest + Vector2(6.0, 9.0), chest + Vector2(7.0, 1.5),
        chest + Vector2(4.8, -1.0), neck + Vector2(2.0, -1.0)
    ]), ink, 17, true, 3.0)
    _path(PackedVector2Array([
        pelvis + Vector2(-3.8, -1.0), pelvis + Vector2(-3.1, 2.0),
        pelvis + Vector2(0.0, 5.0), pelvis + Vector2(3.1, 2.0),
        pelvis + Vector2(3.8, -1.0)
    ]), mid, 21, false, 3.0)
    _path(PackedVector2Array([chest + Vector2(-2.8, 7.0), chest + Vector2(2.8, 7.0)]), far, 23, false, 3.0)

    # Arms are kept separate from the torso with narrower upper/lower segments.
    _limb(ls, le, 3.5, mid, 31)
    _limb(le, lh, 2.7, ink, 37)
    _limb(rs, re, 3.5, ink, 41)
    _limb(re, rh, 2.7, ink, 43)
    _path(PackedVector2Array([lh + Vector2(-1.0, -1.0), lh + Vector2(0.5, 2.0), lh + Vector2(1.5, 3.5)]), mid, 47, false, 3.8)
    _path(PackedVector2Array([rh + Vector2(-1.0, -1.0), rh + Vector2(0.5, 2.0), rh + Vector2(1.5, 3.5)]), ink, 49, false, 2.8)

    # Far leg first, then near leg. Matched widths and lengths avoid the
    # previous visual impression that one leg was a different character.
    _limb(lhip, lk, 3.0, far, 53)
    _limb(lk, la, 2.5, far, 59)
    _limb(rhip, rk, 3.0, mid, 61)
    _limb(rk, ra, 2.5, ink, 67)
    _foot(la, far, 71)
    _foot(ra, ink, 73)

func _ellipse(center: Vector2, radius: Vector2, color: Color, seed: int) -> void:
    const COUNT := 36
    for i in range(COUNT):
        var angle := TAU * float(i) / float(COUNT)
        var p := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
        if i % 3 != 0:
            _glyph(p, CONTOUR_GLYPHS[posmod(seed + i, CONTOUR_GLYPHS.size())], color, seed + i)

func _limb(a: Vector2, b: Vector2, width: float, color: Color, seed: int) -> void:
    var delta := b - a
    if delta.length() < 0.1:
        return
    var normal := delta.normalized().orthogonal()
    var count := maxi(4, int(delta.length() / 4.0))
    for i in range(count + 1):
        var t := float(i) / float(count)
        var center := a.lerp(b, t)
        var taper := 0.72 + 0.28 * sin(t * PI)
        var offset := normal * width * 0.5 * taper
        var glyph_a := CONTOUR_GLYPHS[posmod(seed + i, CONTOUR_GLYPHS.size())]
        var glyph_b := CONTOUR_GLYPHS[posmod(seed + i + 3, CONTOUR_GLYPHS.size())]
        _glyph(center + offset, glyph_a, color, seed + i)
        _glyph(center - offset, glyph_b, color, seed + i + 3)
        if i % 7 == 0 and t > 0.18 and t < 0.82:
            _glyph(center, DETAIL_GLYPHS[posmod(seed + i, DETAIL_GLYPHS.size())], color.darkened(0.12), seed + i + 5)

func _foot(ankle: Vector2, color: Color, seed: int) -> void:
    _path(PackedVector2Array([
        ankle + Vector2(-2.0, -0.4), ankle + Vector2(1.5, 0.0),
        ankle + Vector2(5.0, 1.0), ankle + Vector2(7.0, 1.2)
    ]), color, seed, false, 2.8)

func _path(points: PackedVector2Array, color: Color, seed: int, closed: bool, spacing: float = 3.5) -> void:
    if points.size() < 2:
        return
    for i in range(points.size() - 1):
        var count := maxi(2, int(points[i].distance_to(points[i + 1]) / spacing))
        _segment(points[i], points[i + 1], count, color, seed + i * 7)
    if closed:
        var count := maxi(2, int(points[points.size() - 1].distance_to(points[0]) / spacing))
        _segment(points[points.size() - 1], points[0], count, color, seed + points.size() * 7)

func _segment(a: Vector2, b: Vector2, count: int, color: Color, seed: int) -> void:
    for i in range(count + 1):
        var p := a.lerp(b, float(i) / float(count))
        _glyph(p, CONTOUR_GLYPHS[posmod(seed + i * 3, CONTOUR_GLYPHS.size())], color, seed + i)

func _glyph(pos: Vector2, value: String, color: Color, seed: int) -> void:
    var shade := 0.94 + float(posmod(seed * 7, 7)) / 100.0
    draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(color.r * shade, color.g * shade, color.b * shade, color.a))
