extends Node2D

# BLADE SYMPHONY — playable combat prototype
# Abstract constellation warrior, fast slashes, dash-cancel, and chain finishers.
const W := 1280.0
const H := 720.0
var player := Vector2(640, 360)
var facing := Vector2.RIGHT
var move_vec := Vector2.ZERO
var enemies: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var slashes: Array[Dictionary] = []
var hp := 5
var score := 0
var combo := 0
var combo_timer := 0.0
var attack_cd := 0.0
var dash_cd := 0.0
var dash_timer := 0.0
var nova_cd := 0.0
var invuln := 0.0
var game_over := false
var time_alive := 0.0
var touch_origin := Vector2.ZERO
var touch_current := Vector2.ZERO
var touch_active := false
var touch_dash := false
var touch_nova := false
var touch_attack := false
var screen_size := Vector2(W, H)
var banner := "BLADE SYMPHONY  //  FLOW INTO A FINISHER"
var banner_timer := 5.0

func _ready() -> void:
    screen_size = get_viewport_rect().size
    _spawn_wave()

func _spawn_wave() -> void:
    for i in range(7):
        var a := TAU * float(i) / 7.0 + randf_range(-0.2, 0.2)
        var p := player + Vector2.RIGHT.rotated(a) * randf_range(220.0, 310.0)
        p.x = clampf(p.x, 80, screen_size.x - 80)
        p.y = clampf(p.y, 100, screen_size.y - 80)
        enemies.append({"p":p, "v":Vector2.ZERO, "hp":2 if i % 3 != 0 else 3, "flash":0.0, "alive":true, "kind":i % 3})

func _process(dt: float) -> void:
    screen_size = get_viewport_rect().size
    if game_over:
        queue_redraw()
        return
    time_alive += dt
    attack_cd = maxf(0.0, attack_cd - dt)
    dash_cd = maxf(0.0, dash_cd - dt)
    dash_timer = maxf(0.0, dash_timer - dt)
    nova_cd = maxf(0.0, nova_cd - dt)
    invuln = maxf(0.0, invuln - dt)
    banner_timer = maxf(0.0, banner_timer - dt)
    combo_timer -= dt
    if combo_timer <= 0: combo = 0

    var d := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.y += 1
    if touch_active and touch_origin.x < screen_size.x * 0.48:
        d = (touch_current - touch_origin).limit_length(85.0) / 85.0
    if d.length() > 1: d = d.normalized()
    move_vec = d

    var mouse := get_global_mouse_position()
    if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or mouse.distance_to(player) > 10:
        if not touch_active: facing = (mouse - player).normalized()
    if facing.length() < 0.1: facing = Vector2.RIGHT
    var speed := 360.0 if dash_timer > 0 else 235.0
    player += d * speed * dt
    player.x = clampf(player.x, 35, screen_size.x - 35)
    player.y = clampf(player.y, 90, screen_size.y - 35)

    if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SHIFT) and dash_cd <= 0:
        _dash()
    if Input.is_key_pressed(KEY_Q) and nova_cd <= 0: _nova()
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and attack_cd <= 0:
        _attack()
    if touch_attack: _attack()
    if touch_dash: _dash()
    if touch_nova: _nova()
    touch_attack = false
    touch_dash = false
    touch_nova = false

    for e in enemies:
        if not e.alive: continue
        e.flash = maxf(0.0, e.flash - dt)
        var to_p: Vector2 = player - e.p
        var dist := to_p.length()
        if dist > 1:
            var target_speed := 85.0 if e.kind != 1 else 125.0
            e.v = e.v.lerp(to_p.normalized() * target_speed, minf(1.0, dt * 2.8))
            e.p += e.v * dt
        if dist < 35 and invuln <= 0:
            hp -= 1
            invuln = 0.8
            _burst(player, Color(1.0, 0.22, 0.45), 16, 210)
            if hp <= 0: game_over = true
    for p in particles:
        p.life -= dt
        p.pos += p.vel * dt
        p.vel *= pow(0.04, dt)
    particles = particles.filter(func(p): return p.life > 0)
    for s in slashes: s.life -= dt
    slashes = slashes.filter(func(s): return s.life > 0)

    if _alive_count() == 0:
        score += 100
        _spawn_wave()
        banner = "WAVE CLEARED  //  +100  //  KEEP THE FLOW"
        banner_timer = 2.6
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x > screen_size.x - 170 and event.position.y > screen_size.y - 180:
                if event.position.y > screen_size.y - 95: touch_nova = true
                else: touch_dash = true
            elif event.position.x > screen_size.x * 0.52:
                touch_attack = true
                facing = (event.position - player).normalized()
            else:
                touch_active = true
                touch_origin = event.position
                touch_current = event.position
        else:
            touch_active = false
    elif event is InputEventScreenDrag and touch_active:
        touch_current = event.position
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        _nova()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_R and game_over:
        get_tree().reload_current_scene()

func _attack() -> void:
    if attack_cd > 0: return
    attack_cd = 0.24
    var dir := facing.normalized()
    if dir.length() < 0.1: dir = Vector2.RIGHT
    var finisher := combo >= 4
    var reach := 155.0 if finisher else 112.0
    var arc := 1.15 if finisher else 0.92
    var col := Color(1.0, 0.28, 0.72) if finisher else Color(0.15, 0.92, 1.0)
    slashes.append({"p":player, "dir":dir, "life":0.24, "max":0.24, "col":col, "reach":reach, "arc":arc})
    var hits := 0
    for e in enemies:
        if not e.alive: continue
        var off: Vector2 = e.p - player
        if off.length() < reach and dir.angle_to(off.normalized()) < arc and dir.angle_to(off.normalized()) > -arc:
            e.hp -= 2 if finisher else 1
            e.flash = 0.18
            e.v += dir * (520 if finisher else 260)
            _burst(e.p, col, 11 if finisher else 6, 190 if finisher else 115)
            hits += 1
            if e.hp <= 0:
                e.alive = false
                score += 10
                combo += 1
                combo_timer = 2.4
    if hits > 0:
        combo += 1
        combo_timer = 2.4
        if combo >= 5:
            banner = "SYMPHONY FINISHER!"
            banner_timer = 1.0
            _burst(player + dir * 65, Color(1.0, 0.22, 0.62), 28, 270)
            combo = 0
    else:
        combo = maxi(0, combo - 1)

func _dash() -> void:
    if dash_cd > 0: return
    dash_cd = 0.85
    dash_timer = 0.22
    invuln = 0.28
    var dir := move_vec.normalized() if move_vec.length() > 0.1 else facing.normalized()
    player += dir * 65
    _burst(player, Color(0.12, 0.85, 1.0), 14, 160)
    slashes.append({"p":player, "dir":dir, "life":0.18, "max":0.18, "col":Color(0.1,0.85,1), "reach":100.0, "arc":1.5})
    for e in enemies:
        if e.alive and e.p.distance_to(player) < 85:
            e.hp -= 1
            e.v += dir * 360
            e.flash = 0.15
            if e.hp <= 0:
                e.alive = false
                score += 10
                combo += 1
                combo_timer = 2.4

func _nova() -> void:
    if nova_cd > 0: return
    nova_cd = 3.2
    var col := Color(0.7, 0.35, 1.0)
    _burst(player, col, 46, 300)
    slashes.append({"p":player, "dir":Vector2.RIGHT, "life":0.38, "max":0.38, "col":col, "reach":230.0, "arc":PI})
    for e in enemies:
        if e.alive and e.p.distance_to(player) < 220:
            e.hp -= 2
            e.v += (e.p - player).normalized() * 420
            e.flash = 0.2
            if e.hp <= 0:
                e.alive = false
                score += 10
                combo += 1
                combo_timer = 2.4
    banner = "NOVA BREAK!"
    banner_timer = 0.8

func _burst(pos: Vector2, col: Color, amount: int, force: float) -> void:
    for i in range(amount):
        var a := randf() * TAU
        var v := Vector2.RIGHT.rotated(a) * randf_range(force * 0.25, force)
        particles.append({"pos":pos, "vel":v, "life":randf_range(0.18,0.55), "max":0.55, "col":col, "r":randf_range(2.0,5.5)})

func _alive_count() -> int:
    var n := 0
    for e in enemies:
        if e.alive: n += 1
    return n

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), Color("#080b18"))
    for x in range(0, int(size.x), 48):
        draw_line(Vector2(x, 72), Vector2(x, size.y), Color(0.12,0.18,0.31,0.35), 1)
    for y in range(72, int(size.y), 48):
        draw_line(Vector2(0,y), Vector2(size.x,y), Color(0.12,0.18,0.31,0.35), 1)
    for i in range(16):
        var a := TAU * i / 16.0 + time_alive * 0.08
        var p := player + Vector2.RIGHT.rotated(a) * (48 + sin(time_alive * 2 + i) * 5)
        draw_circle(p, 2.0, Color(0.2,0.85,1,0.5))
        draw_line(player, p, Color(0.1,0.65,1,0.13), 1)
    for s in slashes:
        var alpha: float = clampf(s.life / s.max, 0, 1)
        var p: Vector2 = s.p
        var dir: Vector2 = s.dir
        var reach: float = s.reach
        var arc: float = s.arc
        var col: Color = s.col
        for j in range(3):
            var rr := reach * (0.45 + j * 0.22)
            var start := dir.angle() - arc
            var end := dir.angle() + arc
            var pts := PackedVector2Array()
            for k in range(25):
                pts.append(p + Vector2.RIGHT.rotated(lerpf(start,end,float(k)/24.0)) * rr)
            draw_polyline(pts, Color(col.r,col.g,col.b,alpha * (0.9-j*0.22)), 4.0-j, true)
    for e in enemies:
        if not e.alive: continue
        var col := Color("#ff426d") if e.kind == 0 else (Color("#ff9a3c") if e.kind == 1 else Color("#bf72ff"))
        if e.flash > 0: col = Color.WHITE
        draw_circle(e.p, 21 if e.kind == 1 else 17, Color(col.r,col.g,col.b,0.12))
        draw_colored_polygon(PackedVector2Array([e.p+Vector2(0,-19),e.p+Vector2(15,0),e.p+Vector2(0,19),e.p+Vector2(-15,0)]), col)
        draw_circle(e.p, 4, Color("#101326"))
        draw_line(e.p+Vector2(-13,-27),e.p+Vector2(13,-27),Color(0.25,0.28,0.4),3)
        draw_line(e.p+Vector2(-13,-27),e.p+Vector2(-13+26.0*float(e.hp)/3.0,-27),Color("#ff587b"),3)
    for p in particles:
        draw_circle(p.pos, p.r * p.life / p.max, Color(p.col.r,p.col.g,p.col.b,clampf(p.life/p.max,0,1)))
    if invuln <= 0 or int(time_alive * 18) % 2 == 0:
        draw_circle(player, 24, Color(0.1,0.8,1,0.12))
        draw_circle(player, 15, Color("#8ffaff"))
        draw_colored_polygon(PackedVector2Array([player+facing*31,player+facing.rotated(2.5)*13,player+facing.rotated(-2.5)*13]), Color("#ffffff"))
        draw_line(player, player+facing*42, Color("#ff66cc"), 5)
    draw_rect(Rect2(0,0,size.x,72), Color(0.025,0.035,0.09,0.94))
    draw_string(ThemeDB.fallback_font, Vector2(28,30), "BLADE SYMPHONY", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#a4f7ff"))
    draw_string(ThemeDB.fallback_font, Vector2(28,54), "HP " + str(hp) + "   SCORE " + str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e3eaff"))
    draw_string(ThemeDB.fallback_font, Vector2(size.x*0.43,40), "FLOW  x" + str(combo), HORIZONTAL_ALIGNMENT_CENTER, -1, 25, Color("#ff72d2") if combo > 0 else Color("#66708d"))
    draw_string(ThemeDB.fallback_font, Vector2(size.x-25,28), "SLASH: CLICK / TAP", HORIZONTAL_ALIGNMENT_RIGHT, -1, 13, Color("#94a5c8"))
    draw_string(ThemeDB.fallback_font, Vector2(size.x-25,51), "DASH: SHIFT   NOVA: Q / RIGHT CLICK", HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color("#94a5c8"))
    if banner_timer > 0:
        draw_string(ThemeDB.fallback_font, Vector2(size.x*0.5, 100), banner, HORIZONTAL_ALIGNMENT_CENTER, -1, 17, Color("#ffffff"))
    # Touch controls
    draw_circle(Vector2(105,size.y-105), 54, Color(0.1,0.65,0.95,0.12))
    draw_circle(Vector2(105,size.y-105), 54, Color(0.35,0.85,1,0.55), false, 2)
    draw_string(ThemeDB.fallback_font, Vector2(65,size.y-100), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b9f8ff"))
    draw_circle(Vector2(size.x-100,size.y-110), 48, Color(0.15,0.8,1,0.12), true)
    draw_string(ThemeDB.fallback_font, Vector2(size.x-125,size.y-105), "DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b9f8ff"))
    draw_circle(Vector2(size.x-100,size.y-220), 48, Color(0.8,0.25,0.8,0.14), true)
    draw_string(ThemeDB.fallback_font, Vector2(size.x-126,size.y-215), "NOVA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffd4fa"))
    if game_over:
        draw_rect(Rect2(Vector2.ZERO,size), Color(0.01,0.01,0.04,0.78))
        draw_string(ThemeDB.fallback_font, size*0.5+Vector2(0,-10), "SYMPHONY ENDED", HORIZONTAL_ALIGNMENT_CENTER, -1, 38, Color("#ff72d2"))
        draw_string(ThemeDB.fallback_font, size*0.5+Vector2(0,35), "SCORE " + str(score) + "   //   PRESS R TO RESTART", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)
