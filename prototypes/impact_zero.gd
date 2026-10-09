extends Node2D

# IMPACT ZERO — Prototype 2
# Top-down physics arena: dash, pulse, slam, explosive chain reactions.
var screen := Vector2(1280, 720)
var player := Vector2(640, 370)
var velocity := Vector2.ZERO
var aim := Vector2.RIGHT
var hp := 3
var score := 0
var pulse_cd := 0.0
var dash_cd := 0.0
var slam_cd := 0.0
var dash_time := 0.0
var game_over := false
var won := false
var banner := "DASH THROUGH BARRELS. CHAIN THE BLASTS."
var banner_time := 4.0
var move_touch := Vector2.ZERO
var touch_dash := false
var touch_pulse := false
var touch_slam := false
var dash_pressed := false
var pulse_pressed := false
var slam_pressed := false
var prev_dash := false
var prev_pulse := false
var prev_slam := false
var enemies: Array[Dictionary] = []
var barrels: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var time_alive := 0.0
var combo := 0
var combo_time := 0.0

func _ready() -> void:
    screen = get_viewport_rect().size
    _reset_arena()

func _reset_arena() -> void:
    player = Vector2(screen.x * 0.5, screen.y * 0.58)
    velocity = Vector2.ZERO
    hp = 3
    score = 0
    pulse_cd = 0.0
    dash_cd = 0.0
    slam_cd = 0.0
    dash_time = 0.0
    game_over = false
    won = false
    time_alive = 0.0
    combo = 0
    combo_time = 0.0
    enemies.clear()
    barrels.clear()
    walls.clear()
    shots.clear()
    particles.clear()
    # Hand-built arena layout, designed for readable chain reactions.
    walls.append({"rect": Rect2(170, 155, 270, 22), "alive": true, "hp": 3})
    walls.append({"rect": Rect2(840, 150, 260, 22), "alive": true, "hp": 3})
    walls.append({"rect": Rect2(280, 485, 220, 22), "alive": true, "hp": 2})
    walls.append({"rect": Rect2(780, 480, 250, 22), "alive": true, "hp": 2})
    walls.append({"rect": Rect2(610, 230, 24, 110), "alive": true, "hp": 3})
    barrels.append({"pos": Vector2(360, 245), "r": 19.0, "alive": true, "fuse": -1.0})
    barrels.append({"pos": Vector2(420, 275), "r": 19.0, "alive": true, "fuse": -1.0})
    barrels.append({"pos": Vector2(900, 280), "r": 19.0, "alive": true, "fuse": -1.0})
    barrels.append({"pos": Vector2(955, 310), "r": 19.0, "alive": true, "fuse": -1.0})
    barrels.append({"pos": Vector2(635, 530), "r": 19.0, "alive": true, "fuse": -1.0})
    for i in range(7):
        var a := TAU * float(i) / 7.0
        var pos := Vector2(640, 350) + Vector2.RIGHT.rotated(a) * 240.0
        enemies.append({"pos": pos, "vel": Vector2.ZERO, "hp": 2 if i % 3 != 0 else 3, "alive": true, "flash": 0.0, "fire": randf_range(1.0, 3.0)})
    banner = "DASH THROUGH BARRELS. CHAIN THE BLASTS."
    banner_time = 4.0

func _process(delta: float) -> void:
    if game_over or won:
        _tick_particles(delta)
        queue_redraw()
        return
    time_alive += delta
    banner_time = maxf(0.0, banner_time - delta)
    combo_time -= delta
    if combo_time <= 0.0: combo = 0
    pulse_cd = maxf(0.0, pulse_cd - delta)
    dash_cd = maxf(0.0, dash_cd - delta)
    slam_cd = maxf(0.0, slam_cd - delta)
    dash_time = maxf(0.0, dash_time - delta)

    var direction := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
    direction += move_touch
    if direction.length() > 1.0: direction = direction.normalized()
    if direction.length() > 0.1: aim = direction.normalized()
    var dash_now := Input.is_key_pressed(KEY_SHIFT) or touch_dash
    var pulse_now := Input.is_key_pressed(KEY_E) or touch_pulse
    var slam_now := Input.is_key_pressed(KEY_SPACE) or touch_slam
    if dash_now and not prev_dash: dash_pressed = true
    if pulse_now and not prev_pulse: pulse_pressed = true
    if slam_now and not prev_slam: slam_pressed = true
    prev_dash = dash_now
    prev_pulse = pulse_now
    prev_slam = slam_now

    if dash_pressed and dash_cd <= 0.0:
        dash_time = 0.22
        dash_cd = 1.0
        velocity = (direction.normalized() if direction.length() > 0.1 else aim) * 850.0
        _emit(player, Color("#5deaff"), 18, 230)
        banner = "KINETIC DASH"
        banner_time = 0.55
    dash_pressed = false
    if dash_time <= 0.0:
        velocity = velocity.lerp(direction * 300.0, minf(1.0, delta * 7.5))
    player += velocity * delta
    player.x = clampf(player.x, 34.0, screen.x - 34.0)
    player.y = clampf(player.y, 78.0, screen.y - 34.0)

    if pulse_pressed and pulse_cd <= 0.0:
        pulse_cd = 2.4
        _pulse()
    pulse_pressed = false
    if slam_pressed and slam_cd <= 0.0:
        slam_cd = 3.5
        _slam()
    slam_pressed = false

    # Dash collides with barrels, setting off explosive chain reactions.
    if dash_time > 0.0:
        for i in range(barrels.size()):
            var b: Dictionary = barrels[i]
            if bool(b["alive"]) and player.distance_to(b["pos"]) < 48.0:
                b["fuse"] = 0.01
                barrels[i] = b
        for i in range(enemies.size()):
            var e: Dictionary = enemies[i]
            if bool(e["alive"]) and player.distance_to(e["pos"]) < 48.0:
                _damage_enemy(i, 1, velocity.normalized() * 220.0)

    # Hostiles pursue and fire slow readable projectiles.
    for i in range(enemies.size()):
        var e: Dictionary = enemies[i]
        if not bool(e["alive"]): continue
        var ep: Vector2 = e["pos"]
        var ev: Vector2 = e["vel"]
        var to_player := player - ep
        if to_player.length() > 60.0:
            ev += to_player.normalized() * 100.0 * delta
        ev *= pow(0.08, delta)
        ep += ev * delta
        e["pos"] = ep
        e["vel"] = ev
        e["flash"] = maxf(0.0, float(e["flash"]) - delta)
        e["fire"] = float(e["fire"]) - delta
        if float(e["fire"]) <= 0.0 and ep.distance_to(player) < 460.0:
            e["fire"] = randf_range(1.6, 2.7)
            shots.append({"pos": ep, "vel": (player - ep).normalized() * 230.0, "life": 3.0})
        if ep.distance_to(player) < 28.0 and dash_time <= 0.0:
            _hurt_player()
            e["vel"] = (ep - player).normalized() * 280.0
            enemies[i] = e
        enemies[i] = e

    for i in range(shots.size() - 1, -1, -1):
        var shot: Dictionary = shots[i]
        shot["pos"] = (shot["pos"] as Vector2) + (shot["vel"] as Vector2) * delta
        shot["life"] = float(shot["life"]) - delta
        var sp: Vector2 = shot["pos"]
        if float(shot["life"]) <= 0.0 or not Rect2(0, 55, screen.x, screen.y - 55).has_point(sp):
            shots.remove_at(i)
        elif dash_time > 0.0 and sp.distance_to(player) < 65.0:
            _emit(sp, Color("#b8a1ff"), 7, 150)
            shots.remove_at(i)
            score += 10
        elif sp.distance_to(player) < 20.0:
            shots.remove_at(i)
            _hurt_player()
        else:
            shots[i] = shot

    # Barrel fuses tick, and blasts may trigger neighbouring barrels.
    for i in range(barrels.size()):
        var b: Dictionary = barrels[i]
        if not bool(b["alive"]): continue
        if float(b["fuse"]) >= 0.0:
            b["fuse"] = float(b["fuse"]) - delta
            barrels[i] = b
            if float(b["fuse"]) <= 0.0:
                _explode_barrel(i)
        else:
            barrels[i] = b
    _tick_particles(delta)
    if time_alive >= 85.0:
        won = true
        banner = "ARENA SURVIVED"
        banner_time = 999.0
    queue_redraw()

func _pulse() -> void:
    _emit(player, Color("#6defff"), 28, 320)
    banner = "PULSE — PUSH EVERYTHING OUT"
    banner_time = 0.8
    for i in range(enemies.size()):
        var e: Dictionary = enemies[i]
        if bool(e["alive"]) and (e["pos"] as Vector2).distance_to(player) < 230.0:
            var away: Vector2 = (e["pos"] as Vector2 - player).normalized()
            _damage_enemy(i, 1, away * 460.0)
    for i in range(barrels.size()):
        var b: Dictionary = barrels[i]
        if bool(b["alive"]) and (b["pos"] as Vector2).distance_to(player) < 220.0:
            b["fuse"] = 0.15
            barrels[i] = b
    for i in range(walls.size()):
        var w: Dictionary = walls[i]
        if bool(w["alive"]) and (w["rect"] as Rect2).get_center().distance_to(player) < 210.0:
            w["hp"] = int(w["hp"]) - 1
            if int(w["hp"]) <= 0:
                w["alive"] = false
                score += 50
                _emit((w["rect"] as Rect2).get_center(), Color("#7e9cb5"), 16, 200)
            walls[i] = w

func _slam() -> void:
    _emit(player, Color("#ff9c61"), 44, 400)
    banner = "ZERO-G SLAM!"
    banner_time = 0.8
    for i in range(enemies.size()):
        var e: Dictionary = enemies[i]
        if bool(e["alive"]) and (e["pos"] as Vector2).distance_to(player) < 170.0:
            _damage_enemy(i, 2, ((e["pos"] as Vector2) - player).normalized() * 520.0)
    for i in range(barrels.size()):
        var b: Dictionary = barrels[i]
        if bool(b["alive"]) and (b["pos"] as Vector2).distance_to(player) < 190.0:
            b["fuse"] = 0.05
            barrels[i] = b
    for i in range(walls.size()):
        var w: Dictionary = walls[i]
        if bool(w["alive"]) and (w["rect"] as Rect2).get_center().distance_to(player) < 180.0:
            w["hp"] = int(w["hp"]) - 2
            if int(w["hp"]) <= 0:
                w["alive"] = false
                score += 75
                _emit((w["rect"] as Rect2).get_center(), Color("#8faec7"), 22, 260)
            walls[i] = w

func _explode_barrel(index: int) -> void:
    if index < 0 or index >= barrels.size(): return
    var b: Dictionary = barrels[index]
    if not bool(b["alive"]): return
    b["alive"] = false
    barrels[index] = b
    var center: Vector2 = b["pos"]
    _emit(center, Color("#ff7a50"), 40, 360)
    _emit(center, Color("#ffd18b"), 20, 220)
    score += 100
    combo += 1
    combo_time = 2.2
    banner = "CHAIN x%d  +100" % combo
    banner_time = 1.1
    for i in range(barrels.size()):
        var other: Dictionary = barrels[i]
        if bool(other["alive"]) and (other["pos"] as Vector2).distance_to(center) < 145.0:
            other["fuse"] = 0.12
            barrels[i] = other
    for i in range(enemies.size()):
        var e: Dictionary = enemies[i]
        if bool(e["alive"]) and (e["pos"] as Vector2).distance_to(center) < 185.0:
            _damage_enemy(i, 2, ((e["pos"] as Vector2) - center).normalized() * 450.0)
    for i in range(walls.size()):
        var w: Dictionary = walls[i]
        if bool(w["alive"]) and (w["rect"] as Rect2).get_center().distance_to(center) < 150.0:
            w["hp"] = int(w["hp"]) - 2
            if int(w["hp"]) <= 0:
                w["alive"] = false
                score += 75
                _emit((w["rect"] as Rect2).get_center(), Color("#7b99b0"), 20, 230)
            walls[i] = w
    if center.distance_to(player) < 125.0:
        _hurt_player()

func _damage_enemy(index: int, damage: int, knockback: Vector2) -> void:
    if index < 0 or index >= enemies.size(): return
    var e: Dictionary = enemies[index]
    if not bool(e["alive"]): return
    e["hp"] = int(e["hp"]) - damage
    e["vel"] = knockback
    e["flash"] = 0.15
    enemies[index] = e
    _emit(e["pos"], Color("#ff6384"), 8, 180)
    if int(e["hp"]) <= 0:
        e["alive"] = false
        score += 200
        combo += 1
        combo_time = 2.2
        banner = "IMPACT CONFIRMED  +200"
        banner_time = 0.7

func _hurt_player() -> void:
    hp -= 1
    _emit(player, Color("#ff466d"), 14, 190)
    if hp <= 0:
        game_over = true
        banner = "SYSTEM FAILURE"
        banner_time = 999.0
    else:
        banner = "HULL HIT  •  %d LEFT" % hp
        banner_time = 0.7

func _emit(pos: Vector2, color: Color, count: int, speed: float) -> void:
    for i in range(count):
        var a := randf_range(0.0, TAU)
        particles.append({"pos": pos, "vel": Vector2.RIGHT.rotated(a) * randf_range(speed * 0.25, speed), "life": randf_range(0.22, 0.75), "color": color, "size": randf_range(2.0, 5.0)})

func _tick_particles(delta: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        var p: Dictionary = particles[i]
        p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
        p["vel"] = (p["vel"] as Vector2) * 0.96
        p["life"] = float(p["life"]) - delta
        if float(p["life"]) <= 0.0:
            particles.remove_at(i)
        else:
            particles[i] = p

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R: _reset_arena()
        if event.keycode == KEY_SHIFT: dash_pressed = true
        if event.keycode == KEY_E: pulse_pressed = true
        if event.keycode == KEY_SPACE: slam_pressed = true
    elif event is InputEventScreenTouch:
        if event.pressed:
            if game_over or won:
                _reset_arena()
            elif event.position.x < screen.x * 0.28:
                move_touch = (event.position - Vector2(screen.x * 0.15, screen.y * 0.78)).normalized()
            elif event.position.y > screen.y * 0.72 and event.position.x > screen.x * 0.76:
                slam_pressed = true
            elif event.position.x > screen.x * 0.82 and event.position.y < screen.y * 0.62:
                dash_pressed = true
            elif event.position.x > screen.x * 0.68:
                pulse_pressed = true
        else:
            move_touch = Vector2.ZERO
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if game_over or won:
            _reset_arena()
        elif event.position.x > screen.x * 0.82 and event.position.y < screen.y * 0.62:
            dash_pressed = true
        elif event.position.x > screen.x * 0.76 and event.position.y > screen.y * 0.72:
            slam_pressed = true
        elif event.position.x > screen.x * 0.68:
            pulse_pressed = true
        else:
            move_touch = (event.position - player).normalized()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        move_touch = Vector2.ZERO

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, screen), Color("#070a12"))
    # Fine arena grid and perimeter.
    for x in range(20, int(screen.x), 40):
        draw_line(Vector2(x, 58), Vector2(x, screen.y), Color(0.18, 0.31, 0.43, 0.12), 1.0)
    for y in range(80, int(screen.y), 40):
        draw_line(Vector2(0, y), Vector2(screen.x, y), Color(0.18, 0.31, 0.43, 0.12), 1.0)
    draw_rect(Rect2(12, 64, screen.x - 24, screen.y - 78), Color("#243447"), false, 2.0)
    for w in walls:
        if not bool(w["alive"]): continue
        var rect: Rect2 = w["rect"]
        draw_rect(rect, Color("#263b51"))
        draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("#6b92ad"))
        for i in range(int(w["hp"])):
            draw_rect(Rect2(rect.position + Vector2(8 + i * 12, 8), Vector2(7, 3)), Color("#9db6c7"))
    for b in barrels:
        if not bool(b["alive"]): continue
        var pos: Vector2 = b["pos"]
        draw_circle(pos, 31, Color(1.0, 0.28, 0.12, 0.07))
        draw_circle(pos, 19, Color("#e85d45"))
        draw_circle(pos, 11, Color("#ffad65"))
        draw_line(pos + Vector2(-11, -8), pos + Vector2(11, 8), Color("#713d3e"), 3)
        if float(b["fuse"]) >= 0.0:
            draw_arc(pos, 27, 0, TAU, 36, Color("#fff2a6"), 3)
    for e in enemies:
        if not bool(e["alive"]): continue
        var pos: Vector2 = e["pos"]
        draw_circle(pos, 29, Color(1.0, 0.2, 0.38, 0.08))
        draw_circle(pos, 17, Color("#ff4f73") if float(e["flash"]) <= 0.0 else Color("#ffffff"))
        draw_circle(pos, 6, Color("#fff2f4"))
        for i in range(int(e["hp"])):
            draw_rect(Rect2(pos + Vector2(-10 + i * 8, 22), Vector2(5, 3)), Color("#ffa8b9"))
    for s in shots:
        draw_circle(s["pos"], 5, Color("#ffcc79"))
        draw_circle(s["pos"], 10, Color(1.0, 0.55, 0.2, 0.15))
    for p in particles:
        var c: Color = p["color"]
        c.a = clampf(float(p["life"]) * 1.8, 0, 1)
        draw_circle(p["pos"], float(p["size"]) * clampf(float(p["life"]) * 2.0, 0.3, 1.0), c)
    draw_circle(player, 35, Color(0.2, 0.85, 1.0, 0.08))
    draw_circle(player, 20, Color("#4ce6ff"))
    draw_circle(player, 10, Color("#f4ffff"))
    draw_line(player, player + aim * 35, Color("#ffffff"), 3)
    if dash_time > 0.0:
        draw_arc(player, 43, 0, TAU, 48, Color("#b4a0ff"), 4)
    var font := ThemeDB.fallback_font
    if font == null: return
    draw_rect(Rect2(0, 0, screen.x, 58), Color(0.035, 0.05, 0.085, 0.96))
    draw_string(font, Vector2(20, 25), "IMPACT ZERO", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#f0f7ff"))
    draw_string(font, Vector2(20, 46), "SCORE %04d   HULL %d" % [score, hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a6bfd5"))
    draw_string(font, Vector2(screen.x - 420, 25), "DASH: SHIFT   PULSE: E   SLAM: SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b8cce0"))
    if combo > 1 and combo_time > 0:
        draw_string(font, Vector2(0, 92), "CHAIN x%d" % combo, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 23, Color("#ffb77e"))
    elif banner_time > 0:
        draw_string(font, Vector2(0, 92), banner, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color("#ffbd93"))
    draw_string(font, Vector2(20, screen.y - 20), "WASD / ARROWS MOVE     SURVIVE 85 SECONDS     R RESET", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#93abc0"))
    draw_circle(Vector2(80, screen.y - 92), 43, Color(0.3, 0.7, 0.9, 0.12))
    draw_arc(Vector2(80, screen.y - 92), 43, 0, TAU, 36, Color("#6aaac8"), 2)
    draw_string(font, Vector2(51, screen.y - 88), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d6f4ff"))
    draw_circle(Vector2(screen.x - 170, screen.y - 95), 34, Color(0.25, 0.85, 1, 0.12))
    draw_arc(Vector2(screen.x - 170, screen.y - 95), 34, 0, TAU, 36, Color("#70eeff"), 2)
    draw_string(font, Vector2(screen.x - 195, screen.y - 91), "PULSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#d6faff"))
    draw_circle(Vector2(screen.x - 75, screen.y - 155), 28, Color(0.65, 0.42, 1, 0.12))
    draw_arc(Vector2(screen.x - 75, screen.y - 155), 28, 0, TAU, 36, Color("#b6a0ff"), 2)
    draw_string(font, Vector2(screen.x - 95, screen.y - 151), "DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#eee5ff"))
    draw_circle(Vector2(screen.x - 75, screen.y - 70), 28, Color(1, 0.48, 0.25, 0.12))
    draw_arc(Vector2(screen.x - 75, screen.y - 70), 28, 0, TAU, 36, Color("#ffb27a"), 2)
    draw_string(font, Vector2(screen.x - 95, screen.y - 66), "SLAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffe5d0"))
    if game_over or won:
        draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.03, 0.06, 0.8))
        draw_string(font, Vector2(0, screen.y * 0.44), "SYSTEM FAILURE" if game_over else "ARENA SURVIVED", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 31, Color("#ff7c8e") if game_over else Color("#83f1ff"))
        draw_string(font, Vector2(0, screen.y * 0.53), "SCORE %04d  •  TAP OR PRESS R TO RETRY" % score, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color("#eef7ff"))
