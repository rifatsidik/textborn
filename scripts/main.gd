extends Node2D

# REBOUND: landscape arena survival. Reflect hostile shots back at enemies.
const PLAYER_RADIUS := 15.0
const DEFLECT_RADIUS := 82.0
const DEFLECT_TIME := 0.22
const PLAYER_SPEED := 290.0

var view := Vector2(1280, 720)
var player := Vector2.ZERO
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var score := 0
var wave := 1
var hp := 3
var spawn_clock := 0.0
var fire_clock := 0.0
var deflect_clock := 0.0
var dash_clock := 0.0
var dash_cooldown := 0.0
var hurt_flash := 0.0
var game_over := false
var banner := "MOVE  •  DEFLECT  •  SURVIVE"
var banner_time := 3.0
var touch_move := Vector2.ZERO
var touch_ids := {}
var mouse_aim := Vector2.ZERO
var mouse_down := false

func _ready() -> void:
    view = get_viewport_rect().size
    player = Vector2(view.x * 0.5, view.y * 0.55)
    _reset_enemies()
    queue_redraw()

func _reset_enemies() -> void:
    enemies.clear()
    bullets.clear()
    for i in range(3):
        _spawn_enemy(i % 2)

func _spawn_enemy(kind: int = -1) -> void:
    if kind < 0:
        kind = randi_range(0, 2)
    var edge := randi_range(0, 3)
    var pos := Vector2.ZERO
    if edge == 0:
        pos = Vector2(randf_range(80, view.x - 80), 100)
    elif edge == 1:
        pos = Vector2(view.x - 45, randf_range(120, view.y - 90))
    elif edge == 2:
        pos = Vector2(randf_range(80, view.x - 80), view.y - 75)
    else:
        pos = Vector2(45, randf_range(120, view.y - 90))
    enemies.append({"pos": pos, "hp": 1 if kind == 0 else (2 if kind == 1 else 3), "kind": kind, "speed": randf_range(52.0, 88.0) + wave * 2.0, "fire": randf_range(0.7, 1.8), "phase": randf_range(0.0, TAU)})

func _process(delta: float) -> void:
    if game_over:
        queue_redraw()
        return
    banner_time = maxf(0.0, banner_time - delta)
    deflect_clock = maxf(0.0, deflect_clock - delta)
    dash_clock = maxf(0.0, dash_clock - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    hurt_flash = maxf(0.0, hurt_flash - delta)
    spawn_clock += delta
    fire_clock += delta

    var move := Vector2.ZERO
    move.x = Input.get_axis("ui_left", "ui_right")
    move.y = Input.get_axis("ui_up", "ui_down")
    if Input.is_key_pressed(KEY_A): move.x -= 1.0
    if Input.is_key_pressed(KEY_D): move.x += 1.0
    if Input.is_key_pressed(KEY_W): move.y -= 1.0
    if Input.is_key_pressed(KEY_S): move.y += 1.0
    move += touch_move
    if move.length() > 1.0:
        move = move.normalized()
    var speed := PLAYER_SPEED * (2.7 if dash_clock > 0.0 else 1.0)
    player += move * speed * delta
    player.x = clampf(player.x, 28.0, view.x - 28.0)
    player.y = clampf(player.y, 90.0, view.y - 30.0)

    if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT):
        _start_dash()
    if Input.is_key_pressed(KEY_E):
        _start_deflect()
    if fire_clock > 0.8:
        fire_clock = 0.0
        _auto_fire()

    for i in range(enemies.size() - 1, -1, -1):
        var enemy: Dictionary = enemies[i]
        var epos: Vector2 = enemy["pos"]
        var to_player := player - epos
        var dist := maxf(1.0, to_player.length())
        var kind: int = enemy["kind"]
        var approach := 0.55 if kind == 1 else 1.0
        epos += to_player / dist * float(enemy["speed"]) * approach * delta
        enemy["phase"] = float(enemy["phase"]) + delta * 2.0
        enemy["fire"] = float(enemy["fire"]) - delta
        if int(enemy["hp"]) >= 2 and float(enemy["fire"]) <= 0.0:
            enemy["fire"] = maxf(0.55, 1.6 - wave * 0.04)
            _shoot(epos, (player - epos).normalized())
        enemy["pos"] = epos
        enemies[i] = enemy
        var collision_radius := 26.0 if kind == 2 else 20.0
        if epos.distance_to(player) < collision_radius + PLAYER_RADIUS and dash_clock <= 0.0:
            _hurt_player()
            var knock := (epos - player).normalized()
            enemy["pos"] = epos + knock * 42.0
            enemies[i] = enemy

    for i in range(bullets.size() - 1, -1, -1):
        var bullet: Dictionary = bullets[i]
        bullet["pos"] = (bullet["pos"] as Vector2) + (bullet["vel"] as Vector2) * delta
        bullet["life"] = float(bullet["life"]) - delta
        var bpos: Vector2 = bullet["pos"]
        if bool(bullet["friendly"]):
            var removed := false
            for j in range(enemies.size() - 1, -1, -1):
                var e: Dictionary = enemies[j]
                if (e["pos"] as Vector2).distance_to(bpos) < (25.0 if int(e["kind"]) == 2 else 19.0):
                    _burst(bpos, Color("#ff5e65"), 12)
                    score += 100
                    e["hp"] = int(e["hp"]) - 1
                    if int(e["hp"]) <= 0:
                        enemies.remove_at(j)
                        score += 150
                    else:
                        enemies[j] = e
                    removed = true
                    break
            if removed:
                bullets.remove_at(i)
                continue
        elif bpos.distance_to(player) < PLAYER_RADIUS + 6.0:
            if deflect_clock > 0.0:
                var reflected := (bpos - player).normalized()
                bullet["vel"] = reflected * 560.0
                bullet["friendly"] = true
                bullet["life"] = 2.0
                bullets[i] = bullet
                _burst(player, Color("#78f4ff"), 10)
                score += 25
                banner = "PERFECT REFLECT!"
                banner_time = 0.6
            else:
                bullets.remove_at(i)
                _hurt_player()
                continue
        if float(bullet["life"]) <= 0.0 or bpos.x < -40 or bpos.x > view.x + 40 or bpos.y < 70 or bpos.y > view.y + 40:
            bullets.remove_at(i)
        else:
            bullets[i] = bullet

    for i in range(particles.size() - 1, -1, -1):
        particles[i]["pos"] = (particles[i]["pos"] as Vector2) + (particles[i]["vel"] as Vector2) * delta
        particles[i]["life"] = float(particles[i]["life"]) - delta
        if float(particles[i]["life"]) <= 0.0:
            particles.remove_at(i)

    if spawn_clock >= maxf(0.65, 2.0 - wave * 0.08) and enemies.size() < 4 + wave:
        spawn_clock = 0.0
        _spawn_enemy()
    if score >= wave * 800:
        wave += 1
        banner = "WAVE %02d" % wave
        banner_time = 1.5
        for n in range(mini(2, wave)):
            _spawn_enemy()
    queue_redraw()

func _shoot(pos: Vector2, direction: Vector2) -> void:
    bullets.append({"pos": pos, "vel": direction * 190.0, "friendly": false, "life": 4.0})

func _auto_fire() -> void:
    if enemies.is_empty():
        return
    var target_pos: Vector2 = enemies[0]["pos"]
    var best := player.distance_squared_to(target_pos)
    for e in enemies:
        var d := player.distance_squared_to(e["pos"])
        if d < best:
            best = d
            target_pos = e["pos"]
    var direction := (target_pos - player).normalized()
    bullets.append({"pos": player + direction * 20.0, "vel": direction * 360.0, "friendly": true, "life": 1.5})

func _start_deflect() -> void:
    if deflect_clock <= 0.0:
        deflect_clock = DEFLECT_TIME
        banner = "DEFLECT!"
        banner_time = 0.3

func _start_dash() -> void:
    if dash_cooldown > 0.0:
        return
    dash_clock = 0.16
    dash_cooldown = 1.0
    _burst(player, Color("#8b9dff"), 8)

func _hurt_player() -> void:
    if hurt_flash > 0.0 or dash_clock > 0.0:
        return
    hp -= 1
    hurt_flash = 0.8
    _burst(player, Color("#ff5e65"), 18)
    if hp <= 0:
        game_over = true
        banner = "SIGNAL LOST  •  TAP TO RETRY"
        banner_time = 999.0
    else:
        banner = "HULL HIT  •  %d LEFT" % hp
        banner_time = 0.8

func _burst(pos: Vector2, color: Color, count: int) -> void:
    for i in range(count):
        var angle := randf_range(0.0, TAU)
        var speed := randf_range(45.0, 220.0)
        particles.append({"pos": pos, "vel": Vector2.RIGHT.rotated(angle) * speed, "life": randf_range(0.18, 0.55), "color": color})

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if game_over:
                _restart()
                return
            if event.position.x > view.x * 0.72 and event.position.y > view.y * 0.58:
                _start_deflect()
            elif event.position.x > view.x * 0.72 and event.position.y > view.y * 0.32:
                _start_dash()
            else:
                touch_ids[event.index] = event.position
                _update_touch_move()
        else:
            touch_ids.erase(event.index)
            _update_touch_move()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if game_over:
                _restart()
            elif event.position.x > view.x * 0.78 and event.position.y > view.y * 0.6:
                _start_deflect()
            elif event.position.x > view.x * 0.78 and event.position.y > view.y * 0.35:
                _start_dash()
            else:
                mouse_down = true
                mouse_aim = event.position
        else:
            mouse_down = false
    elif event is InputEventMouseMotion and mouse_down:
        mouse_aim = event.position
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            _restart()
        elif event.keycode == KEY_E:
            _start_deflect()
        elif event.keycode == KEY_SPACE or event.keycode == KEY_SHIFT:
            _start_dash()

func _update_touch_move() -> void:
    touch_move = Vector2.ZERO
    for key in touch_ids.keys():
        var pos: Vector2 = touch_ids[key]
        var center := Vector2(view.x * 0.16, view.y * 0.72)
        var delta := pos - center
        if delta.length() > 10.0 and pos.x < view.x * 0.42:
            touch_move = (delta / 72.0).limit_length(1.0)

func _restart() -> void:
    score = 0
    wave = 1
    hp = 3
    spawn_clock = 0.0
    fire_clock = 0.0
    deflect_clock = 0.0
    dash_clock = 0.0
    dash_cooldown = 0.0
    hurt_flash = 0.0
    game_over = false
    banner = "MOVE  •  DEFLECT  •  SURVIVE"
    banner_time = 2.0
    player = Vector2(view.x * 0.5, view.y * 0.55)
    particles.clear()
    _reset_enemies()
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, view), Color("#090c12"))
    for x in range(0, int(view.x), 48):
        draw_line(Vector2(x, 70), Vector2(x, view.y), Color(0.20, 0.28, 0.37, 0.18), 1.0)
    for y in range(80, int(view.y), 48):
        draw_line(Vector2(0, y), Vector2(view.x, y), Color(0.20, 0.28, 0.37, 0.18), 1.0)
    draw_rect(Rect2(0, 0, view.x, 64), Color("#101722"))
    draw_line(Vector2(0, 64), Vector2(view.x, 64), Color("#253344"), 1.0)
    for bullet in bullets:
        var pos: Vector2 = bullet["pos"]
        if bool(bullet["friendly"]):
            draw_circle(pos, 8.0, Color(0.20, 0.92, 1.0, 0.16))
            draw_circle(pos, 4.5, Color("#8af6ff"))
        else:
            draw_circle(pos, 8.0, Color(1.0, 0.22, 0.32, 0.16))
            draw_circle(pos, 4.0, Color("#ff6570"))
    for e in enemies:
        var pos: Vector2 = e["pos"]
        var kind: int = e["kind"]
        var radius := 25.0 if kind == 2 else 18.0
        var color := Color("#ff5c68") if kind == 0 else (Color("#ff9b50") if kind == 1 else Color("#b46cff"))
        draw_circle(pos, radius + 8.0, Color(color.r, color.g, color.b, 0.10))
        if kind == 2:
            draw_rect(Rect2(pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), color, false, 3.0)
        else:
            var points := PackedVector2Array()
            for k in range(3):
                points.append(pos + Vector2.UP.rotated(float(k) * TAU / 3.0) * radius)
            draw_colored_polygon(points, color)
        draw_circle(pos, 4.0, Color("#fff1f1"))
        for pip in range(int(e["hp"])):
            draw_circle(pos + Vector2(-8.0 + pip * 8.0, radius + 9.0), 2.0, color)
    for p in particles:
        var alpha := clampf(float(p["life"]) * 2.0, 0.0, 1.0)
        var col: Color = p["color"]
        col.a = alpha
        draw_circle(p["pos"], 2.2, col)
    # Player glow and directional core.
    var player_color := Color("#ff6a78") if hurt_flash > 0.0 else Color("#eafaff")
    draw_circle(player, 27.0, Color(0.20, 0.88, 1.0, 0.10))
    draw_circle(player, 18.0, Color("#47dff5"))
    draw_circle(player, 10.0, player_color)
    draw_circle(player, 3.0, Color.WHITE)
    if deflect_clock > 0.0:
        draw_arc(player, DEFLECT_RADIUS, 0.0, TAU, 64, Color(0.28, 0.95, 1.0, 0.95), 4.0, true)
    var font := ThemeDB.fallback_font
    if font == null:
        return
    draw_string(font, Vector2(22, 27), "REBOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#eef5ff"))
    draw_string(font, Vector2(22, 49), "WAVE %02d   SCORE %05d" % [wave, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#94a6bd"))
    draw_string(font, Vector2(view.x - 130, 29), "HP  " + "◆".repeat(hp) + "◇".repeat(3 - hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ff7c86"))
    if banner_time > 0.0:
        draw_string(font, Vector2(0, view.y * 0.19), banner, HORIZONTAL_ALIGNMENT_CENTER, view.x, 19, Color("#a9f5ff"))
    # Mobile touch controls, deliberately large and simple.
    draw_circle(Vector2(view.x * 0.16, view.y * 0.72), 54.0, Color(0.25, 0.38, 0.52, 0.16))
    draw_arc(Vector2(view.x * 0.16, view.y * 0.72), 54.0, 0.0, TAU, 48, Color(0.48, 0.65, 0.82, 0.42), 2.0, true)
    draw_circle(Vector2(view.x * 0.16, view.y * 0.72) + touch_move * 26.0, 20.0, Color(0.66, 0.85, 1.0, 0.55))
    draw_circle(Vector2(view.x * 0.84, view.y * 0.72), 43.0, Color(0.20, 0.90, 1.0, 0.10))
    draw_arc(Vector2(view.x * 0.84, view.y * 0.72), 43.0, 0.0, TAU, 48, Color("#67efff"), 2.0, true)
    draw_string(font, Vector2(view.x * 0.84 - 28, view.y * 0.72 + 5), "PARRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d9fbff"))
    draw_circle(Vector2(view.x * 0.91, view.y * 0.48), 31.0, Color(0.63, 0.49, 1.0, 0.12))
    draw_arc(Vector2(view.x * 0.91, view.y * 0.48), 31.0, 0.0, TAU, 40, Color("#bca4ff"), 2.0, true)
    draw_string(font, Vector2(view.x * 0.91 - 19, view.y * 0.48 + 5), "DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#eee5ff"))
    if game_over:
        draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.02, 0.04, 0.72))
        draw_string(font, Vector2(0, view.y * 0.44), "SIGNAL LOST", HORIZONTAL_ALIGNMENT_CENTER, view.x, 32, Color("#ff7581"))
        draw_string(font, Vector2(0, view.y * 0.51), "SCORE %05d  •  WAVE %02d" % [score, wave], HORIZONTAL_ALIGNMENT_CENTER, view.x, 18, Color("#eef5ff"))
        draw_string(font, Vector2(0, view.y * 0.59), "TAP OR PRESS R TO RETRY", HORIZONTAL_ALIGNMENT_CENTER, view.x, 16, Color("#9defff"))
