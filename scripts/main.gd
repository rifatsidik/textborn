extends Node2D

# GRAVITY SHIFT prototype: move, pull enemies/projectiles together, then burst.
const PLAYER_SPEED := 300.0
var view := Vector2(1280, 720)
var player := Vector2.ZERO
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var score := 0
var wave := 1
var hp := 3
var spawn_timer := 0.0
var auto_timer := 0.0
var pull_timer := 0.0
var pull_cooldown := 0.0
var burst_cooldown := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var hurt_timer := 0.0
var game_over := false
var banner := "PULL  •  BURST  •  SURVIVE"
var banner_timer := 3.0
var move_touch := Vector2.ZERO
var active_touches := {}
var keys_previous := {}

func _ready() -> void:
    view = get_viewport_rect().size
    player = view * Vector2(0.5, 0.55)
    for i in range(4):
        _spawn_enemy(i % 3)
    queue_redraw()

func _spawn_enemy(kind: int = -1) -> void:
    if kind < 0:
        kind = randi_range(0, 2)
    var edge := randi_range(0, 3)
    var pos := Vector2.ZERO
    if edge == 0: pos = Vector2(randf_range(90, view.x - 90), 92)
    elif edge == 1: pos = Vector2(view.x - 45, randf_range(110, view.y - 70))
    elif edge == 2: pos = Vector2(randf_range(90, view.x - 90), view.y - 50)
    else: pos = Vector2(45, randf_range(110, view.y - 70))
    enemies.append({"pos": pos, "hp": 1 if kind == 0 else (2 if kind == 1 else 3), "kind": kind, "speed": randf_range(45.0, 78.0) + wave * 2.0, "fire": randf_range(0.8, 2.0), "phase": randf_range(0.0, TAU)})

func _process(delta: float) -> void:
    if game_over:
        queue_redraw()
        return
    banner_timer = maxf(0.0, banner_timer - delta)
    pull_timer = maxf(0.0, pull_timer - delta)
    pull_cooldown = maxf(0.0, pull_cooldown - delta)
    burst_cooldown = maxf(0.0, burst_cooldown - delta)
    dash_timer = maxf(0.0, dash_timer - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    hurt_timer = maxf(0.0, hurt_timer - delta)
    spawn_timer += delta
    auto_timer += delta

    var move := Vector2.ZERO
    move.x = Input.get_axis("ui_left", "ui_right")
    move.y = Input.get_axis("ui_up", "ui_down")
    if Input.is_key_pressed(KEY_A): move.x -= 1.0
    if Input.is_key_pressed(KEY_D): move.x += 1.0
    if Input.is_key_pressed(KEY_W): move.y -= 1.0
    if Input.is_key_pressed(KEY_S): move.y += 1.0
    move += move_touch
    if move.length() > 1.0: move = move.normalized()
    player += move * PLAYER_SPEED * (2.5 if dash_timer > 0.0 else 1.0) * delta
    player.x = clampf(player.x, 28.0, view.x - 28.0)
    player.y = clampf(player.y, 86.0, view.y - 28.0)

    if Input.is_key_pressed(KEY_Q): _activate_pull()
    if Input.is_key_pressed(KEY_E): _activate_burst()
    if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT): _activate_dash()
    if auto_timer >= 0.72:
        auto_timer = 0.0
        _auto_fire()

    for i in range(enemies.size() - 1, -1, -1):
        var enemy: Dictionary = enemies[i]
        var pos: Vector2 = enemy["pos"]
        var toward := player - pos
        var dist := maxf(1.0, toward.length())
        var kind: int = enemy["kind"]
        var speed := float(enemy["speed"]) * (0.55 if kind == 1 else 1.0)
        if pull_timer > 0.0:
            pos += (player - pos).normalized() * 420.0 * delta
        else:
            pos += toward / dist * speed * delta
        enemy["phase"] = float(enemy["phase"]) + delta * 2.0
        enemy["fire"] = float(enemy["fire"]) - delta
        if int(enemy["hp"]) >= 2 and float(enemy["fire"]) <= 0.0:
            enemy["fire"] = maxf(0.7, 1.8 - wave * 0.04)
            shots.append({"pos": pos, "vel": (player - pos).normalized() * 190.0, "hostile": true, "life": 4.0})
        enemy["pos"] = pos
        enemies[i] = enemy
        if pos.distance_to(player) < (36.0 if kind == 2 else 27.0) and dash_timer <= 0.0:
            _hurt()
            enemy["pos"] = pos + (pos - player).normalized() * 45.0
            enemies[i] = enemy

    for i in range(shots.size() - 1, -1, -1):
        var shot: Dictionary = shots[i]
        var pos: Vector2 = shot["pos"]
        var vel: Vector2 = shot["vel"]
        if pull_timer > 0.0:
            var to_core := player - pos
            vel += to_core.normalized() * 550.0 * delta
        pos += vel * delta
        shot["pos"] = pos
        shot["vel"] = vel
        shot["life"] = float(shot["life"]) - delta
        if bool(shot["hostile"]) and pos.distance_to(player) < 23.0:
            shots.remove_at(i)
            if pull_timer > 0.0:
                score += 20
                _burst(pos, Color("#65f2ff"), 7)
            else:
                _hurt()
            continue
        if not bool(shot["hostile"]):
            var hit := false
            for j in range(enemies.size() - 1, -1, -1):
                var e: Dictionary = enemies[j]
                if (e["pos"] as Vector2).distance_to(pos) < 22.0:
                    e["hp"] = int(e["hp"]) - 1
                    score += 50
                    _burst(pos, Color("#ff6b82"), 9)
                    if int(e["hp"]) <= 0:
                        enemies.remove_at(j)
                        score += 100
                    else:
                        enemies[j] = e
                    hit = true
                    break
            if hit:
                shots.remove_at(i)
                continue
        if float(shot["life"]) <= 0.0 or pos.x < -30 or pos.x > view.x + 30 or pos.y < 65 or pos.y > view.y + 30:
            shots.remove_at(i)
        else:
            shots[i] = shot

    for i in range(particles.size() - 1, -1, -1):
        particles[i]["pos"] = (particles[i]["pos"] as Vector2) + (particles[i]["vel"] as Vector2) * delta
        particles[i]["life"] = float(particles[i]["life"]) - delta
        if float(particles[i]["life"]) <= 0.0:
            particles.remove_at(i)

    if spawn_timer >= maxf(0.65, 1.8 - wave * 0.06) and enemies.size() < 4 + wave:
        spawn_timer = 0.0
        _spawn_enemy()
    if score >= wave * 700:
        wave += 1
        banner = "GRAVITY INTENSIFIES  •  WAVE %02d" % wave
        banner_timer = 1.6
        for n in range(mini(2, wave)):
            _spawn_enemy()
    queue_redraw()

func _auto_fire() -> void:
    if enemies.is_empty(): return
    var target: Vector2 = enemies[0]["pos"]
    var best := player.distance_squared_to(target)
    for enemy in enemies:
        var d := player.distance_squared_to(enemy["pos"])
        if d < best:
            best = d
            target = enemy["pos"]
    shots.append({"pos": player + (target - player).normalized() * 20.0, "vel": (target - player).normalized() * 370.0, "hostile": false, "life": 1.5})

func _activate_pull() -> void:
    if pull_cooldown > 0.0 or game_over: return
    pull_timer = 1.15
    pull_cooldown = 4.2
    banner = "GRAVITY WELL!"
    banner_timer = 0.8
    _burst(player, Color("#8c72ff"), 20)

func _activate_burst() -> void:
    if burst_cooldown > 0.0 or game_over: return
    burst_cooldown = 3.0
    var hit_count := 0
    for i in range(enemies.size() - 1, -1, -1):
        var e: Dictionary = enemies[i]
        var pos: Vector2 = e["pos"]
        var offset := pos - player
        var dist := offset.length()
        if dist < 260.0:
            var falloff := 1.0 - dist / 260.0
            e["hp"] = int(e["hp"]) - (2 if pull_timer > 0.0 else 1)
            e["pos"] = pos + offset.normalized() * 240.0 * falloff
            _burst(pos, Color("#ffad65"), 13)
            score += 75
            hit_count += 1
            if int(e["hp"]) <= 0:
                enemies.remove_at(i)
                score += 150
            else:
                enemies[i] = e
    for i in range(shots.size() - 1, -1, -1):
        var s: Dictionary = shots[i]
        var offset: Vector2 = s["pos"] - player
        if offset.length() < 290.0:
            if pull_timer > 0.0:
                score += 15
                _burst(s["pos"], Color("#ffcf72"), 5)
                shots.remove_at(i)
            elif bool(s["hostile"]):
                s["vel"] = offset.normalized() * 460.0
                s["hostile"] = false
                shots[i] = s
    banner = "COSMIC BURST  x%d" % hit_count if hit_count > 0 else "BURST!"
    banner_timer = 1.0
    _burst(player, Color("#ffad65"), 36)
    queue_redraw()

func _activate_dash() -> void:
    if dash_cooldown > 0.0 or game_over: return
    dash_timer = 0.18
    dash_cooldown = 1.0
    _burst(player, Color("#62e9ff"), 9)

func _hurt() -> void:
    if hurt_timer > 0.0 or dash_timer > 0.0: return
    hp -= 1
    hurt_timer = 0.8
    _burst(player, Color("#ff526e"), 20)
    if hp <= 0:
        game_over = true
        banner = "SINGULARITY LOST"
        banner_timer = 999.0
    else:
        banner = "CORE DAMAGED  •  %d LEFT" % hp
        banner_timer = 0.8

func _burst(pos: Vector2, color: Color, count: int) -> void:
    for i in range(count):
        var angle := randf_range(0.0, TAU)
        var speed := randf_range(35.0, 250.0)
        particles.append({"pos": pos, "vel": Vector2.RIGHT.rotated(angle) * speed, "life": randf_range(0.2, 0.7), "color": color})

func _input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        if active_touches.has(event.index):
            active_touches[event.index] = event.position
            _update_move()
    elif event is InputEventScreenTouch:
        if event.pressed:
            if game_over:
                _restart()
            elif event.position.x > view.x * 0.78 and event.position.y > view.y * 0.59:
                _activate_pull()
            elif event.position.x > view.x * 0.78 and event.position.y > view.y * 0.32:
                _activate_burst()
            elif event.position.x > view.x * 0.64:
                _activate_dash()
            else:
                active_touches[event.index] = event.position
                _update_move()
        else:
            active_touches.erase(event.index)
            _update_move()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if game_over:
            _restart()
        elif event.position.x > view.x * 0.78 and event.position.y > view.y * 0.59:
            _activate_pull()
        elif event.position.x > view.x * 0.78 and event.position.y > view.y * 0.32:
            _activate_burst()
        elif event.position.x > view.x * 0.64:
            _activate_dash()
        else:
            # Click left side to move toward that point.
            move_touch = (event.position - player).normalized()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        move_touch = Vector2.ZERO
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R: _restart()
        elif event.keycode == KEY_Q: _activate_pull()
        elif event.keycode == KEY_E: _activate_burst()
        elif event.keycode == KEY_SPACE or event.keycode == KEY_SHIFT: _activate_dash()

func _update_move() -> void:
    move_touch = Vector2.ZERO
    for key in active_touches.keys():
        var pos: Vector2 = active_touches[key]
        var center := Vector2(view.x * 0.14, view.y * 0.77)
        if pos.x < view.x * 0.4:
            move_touch = ((pos - center) / 70.0).limit_length(1.0)

func _restart() -> void:
    score = 0
    wave = 1
    hp = 3
    spawn_timer = 0.0
    auto_timer = 0.0
    pull_timer = 0.0
    pull_cooldown = 0.0
    burst_cooldown = 0.0
    dash_timer = 0.0
    dash_cooldown = 0.0
    hurt_timer = 0.0
    game_over = false
    banner = "PULL  •  BURST  •  SURVIVE"
    banner_timer = 2.0
    player = view * Vector2(0.5, 0.55)
    particles.clear()
    shots.clear()
    enemies.clear()
    for i in range(4): _spawn_enemy(i % 3)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, view), Color("#080a14"))
    for x in range(0, int(view.x), 48):
        draw_line(Vector2(x, 64), Vector2(x, view.y), Color(0.20, 0.24, 0.43, 0.18), 1.0)
    for y in range(80, int(view.y), 48):
        draw_line(Vector2(0, y), Vector2(view.x, y), Color(0.20, 0.24, 0.43, 0.16), 1.0)
    draw_rect(Rect2(0, 0, view.x, 62), Color("#101426"))
    draw_line(Vector2(0, 62), Vector2(view.x, 62), Color("#34345b"), 1.0)

    # Active singularity field.
    if pull_timer > 0.0:
        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
        draw_circle(player, 145.0, Color(0.35, 0.20, 1.0, 0.07 + pulse * 0.04))
        draw_arc(player, 75.0 + pulse * 16.0, 0.0, TAU, 72, Color(0.58, 0.43, 1.0, 0.95), 3.0, true)
        draw_arc(player, 112.0 - pulse * 12.0, 0.0, TAU, 72, Color(0.22, 0.78, 1.0, 0.65), 2.0, true)
    for s in shots:
        var pos: Vector2 = s["pos"]
        var hostile := bool(s["hostile"])
        var c := Color("#ff5c78") if hostile else Color("#73f6ff")
        draw_circle(pos, 10.0, Color(c.r, c.g, c.b, 0.15))
        draw_circle(pos, 4.5, c)
        draw_circle(pos, 1.8, Color.WHITE)
    for e in enemies:
        var pos: Vector2 = e["pos"]
        var kind: int = e["kind"]
        var radius := 24.0 if kind == 2 else 17.0
        var c := Color("#ff4e83") if kind == 0 else (Color("#ff9d56") if kind == 1 else Color("#b778ff"))
        draw_circle(pos, radius + 10.0, Color(c.r, c.g, c.b, 0.09))
        if kind == 2:
            draw_rect(Rect2(pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), c, false, 3.0)
            draw_line(pos - Vector2(radius, 0), pos + Vector2(radius, 0), c, 2.0)
        else:
            var points := PackedVector2Array()
            for k in range(3):
                points.append(pos + Vector2.UP.rotated(float(k) * TAU / 3.0) * radius)
            draw_colored_polygon(points, c)
        draw_circle(pos, 4.0, Color.WHITE)
        for pip in range(int(e["hp"])):
            draw_circle(pos + Vector2(-7.0 + pip * 7.0, radius + 8.0), 2.0, c)
    for p in particles:
        var col: Color = p["color"]
        col.a = clampf(float(p["life"]) * 1.7, 0.0, 1.0)
        draw_circle(p["pos"], 2.5, col)

    draw_circle(player, 42.0, Color(0.25, 0.65, 1.0, 0.06))
    draw_circle(player, 25.0, Color("#5042c8"))
    draw_circle(player, 17.0, Color("#64eaff"))
    draw_circle(player, 8.0, Color("#f4ffff"))
    if dash_timer > 0.0:
        draw_arc(player, 36.0, 0.0, TAU, 48, Color("#b5a0ff"), 4.0, true)
    var font := ThemeDB.fallback_font
    if font == null: return
    draw_string(font, Vector2(22, 27), "GRAVITY SHIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#f2f3ff"))
    draw_string(font, Vector2(22, 48), "WAVE %02d   SCORE %06d" % [wave, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a9b6dc"))
    draw_string(font, Vector2(view.x - 132, 30), "CORE  " + "◆".repeat(hp) + "◇".repeat(3 - hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ff829b"))
    if banner_timer > 0.0:
        draw_string(font, Vector2(0, view.y * 0.18), banner, HORIZONTAL_ALIGNMENT_CENTER, view.x, 19, Color("#c2b4ff"))
    # Mobile controls.
    draw_circle(Vector2(view.x * 0.14, view.y * 0.77), 52.0, Color(0.30, 0.35, 0.62, 0.14))
    draw_arc(Vector2(view.x * 0.14, view.y * 0.77), 52.0, 0.0, TAU, 48, Color("#7885cf"), 2.0, true)
    draw_circle(Vector2(view.x * 0.14, view.y * 0.77) + move_touch * 25.0, 18.0, Color(0.65, 0.78, 1.0, 0.52))
    _draw_button(Vector2(view.x * 0.78, view.y * 0.72), 39.0, Color("#65eaff"), "PULL")
    _draw_button(Vector2(view.x * 0.90, view.y * 0.49), 32.0, Color("#ffad65"), "BURST")
    _draw_button(Vector2(view.x * 0.68, view.y * 0.77), 28.0, Color("#b8a4ff"), "DASH")
    if game_over:
        draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.01, 0.05, 0.76))
        draw_string(font, Vector2(0, view.y * 0.44), "SINGULARITY LOST", HORIZONTAL_ALIGNMENT_CENTER, view.x, 31, Color("#ff7293"))
        draw_string(font, Vector2(0, view.y * 0.51), "SCORE %06d  •  WAVE %02d" % [score, wave], HORIZONTAL_ALIGNMENT_CENTER, view.x, 18, Color("#f4f4ff"))
        draw_string(font, Vector2(0, view.y * 0.59), "TAP OR PRESS R TO RETRY", HORIZONTAL_ALIGNMENT_CENTER, view.x, 15, Color("#a9efff"))

func _draw_button(pos: Vector2, radius: float, color: Color, label: String) -> void:
    draw_circle(pos, radius + 8.0, Color(color.r, color.g, color.b, 0.08))
    draw_arc(pos, radius, 0.0, TAU, 40, color, 2.0, true)
    draw_string(ThemeDB.fallback_font, pos + Vector2(-radius * 0.65, 5), label, HORIZONTAL_ALIGNMENT_LEFT, radius * 1.6, 10, Color("#f1f3ff"))
