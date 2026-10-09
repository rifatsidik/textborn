extends Node2D

# WRECKLINE prototype: momentum platformer with a destructible bridge.
const SPEED := 300.0
const JUMP_VELOCITY := -460.0
const GRAVITY := 1100.0
var view := Vector2(1280, 720)
var player := Vector2(130, 480)
var velocity := Vector2.ZERO
var grounded := false
var dash_time := 0.0
var dash_cooldown := 0.0
var hp := 3
var score := 0
var game_over := false
var won := false
var banner := "RUN  •  JUMP  •  BREAK THE SUPPORT"
var banner_timer := 4.0
var platforms: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var touch_move := Vector2.ZERO
var touch_jump := false
var touch_dash := false
var jump_requested := false
var dash_requested := false
var jump_was_down := false
var dash_was_down := false
var camera_offset := 0.0
var world_width := 2400.0
var bridge_broken := false

func _ready() -> void:
    view = get_viewport_rect().size
    _build_level()
    queue_redraw()

func _build_level() -> void:
    platforms.clear()
    enemies.clear()
    # Static floor sections with one deliberately weak bridge.
    _add_platform(Rect2(0, 590, 400, 80), "solid")
    _add_platform(Rect2(400, 590, 300, 28), "bridge")
    _add_platform(Rect2(700, 590, 300, 80), "solid")
    _add_platform(Rect2(1000, 500, 180, 28), "solid")
    _add_platform(Rect2(1180, 590, 340, 80), "solid")
    _add_platform(Rect2(1520, 530, 190, 28), "solid")
    _add_platform(Rect2(1710, 590, 420, 80), "solid")
    _add_platform(Rect2(2130, 500, 180, 28), "solid")
    _add_platform(Rect2(2310, 590, 160, 80), "solid")
    # The bridge support is a destructible object below the bridge.
    _add_platform(Rect2(520, 545, 28, 45), "support")
    _add_platform(Rect2(625, 545, 28, 45), "support")
    enemies = [
        {"pos": Vector2(820, 545), "hp": 2, "dir": -1.0, "left": 740.0, "right": 950.0, "alive": true},
        {"pos": Vector2(1350, 545), "hp": 2, "dir": 1.0, "left": 1220.0, "right": 1470.0, "alive": true},
        {"pos": Vector2(1850, 545), "hp": 3, "dir": -1.0, "left": 1740.0, "right": 2070.0, "alive": true}
    ]

func _add_platform(rect: Rect2, kind: String) -> void:
    platforms.append({"rect": rect, "kind": kind, "alive": true})

func _process(delta: float) -> void:
    if game_over or won:
        _update_particles(delta)
        queue_redraw()
        return
    banner_timer = maxf(0.0, banner_timer - delta)
    dash_time = maxf(0.0, dash_time - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    var move := Input.get_axis("ui_left", "ui_right")
    if Input.is_key_pressed(KEY_A): move -= 1.0
    if Input.is_key_pressed(KEY_D): move += 1.0
    move += touch_move.x
    move = clampf(move, -1.0, 1.0)

    var jump_down := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch_jump
    var dash_down := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_E) or touch_dash
    if jump_down and not jump_was_down:
        jump_requested = true
    if dash_down and not dash_was_down:
        dash_requested = true
    jump_was_down = jump_down
    dash_was_down = dash_down

    if dash_requested and dash_cooldown <= 0.0:
        dash_time = 0.20
        dash_cooldown = 0.9
        velocity.x = (1.0 if move >= 0.0 else -1.0) * 780.0
        velocity.y *= 0.3
        _burst(player + Vector2(0, 4), Color("#6ceeff"), 14)
        banner = "KINETIC DASH!"
        banner_timer = 0.65
    dash_requested = false

    velocity.x = move * SPEED if dash_time <= 0.0 else velocity.x
    if jump_requested and grounded:
        velocity.y = JUMP_VELOCITY
        grounded = false
        _burst(player + Vector2(0, 14), Color("#a78bfa"), 8)
    jump_requested = false
    if not grounded:
        velocity.y += GRAVITY * delta
    var old_player := player
    player.x += velocity.x * delta
    player.y += velocity.y * delta
    player.x = clampf(player.x, 18.0, world_width - 18.0)
    grounded = false
    for p in platforms:
        if not bool(p["alive"]):
            continue
        var rect: Rect2 = p["rect"]
        if player.x + 13.0 > rect.position.x and player.x - 13.0 < rect.end.x:
            if old_player.y + 14.0 <= rect.position.y and player.y + 14.0 >= rect.position.y and velocity.y >= 0.0:
                player.y = rect.position.y - 14.0
                velocity.y = 0.0
                grounded = true
            elif old_player.y - 14.0 >= rect.end.y and player.y - 14.0 <= rect.end.y and velocity.y < 0.0:
                player.y = rect.end.y + 14.0
                velocity.y = 0.0
    if player.y > view.y + 140.0:
        _damage_player()
        player = Vector2(maxf(30.0, player.x - 120.0), 420.0)
        velocity = Vector2.ZERO

    # Dash impact damages enemies and weak supports.
    if dash_time > 0.0:
        for i in range(enemies.size()):
            var e: Dictionary = enemies[i]
            if bool(e["alive"]) and player.distance_to(e["pos"]) < 52.0:
                e["hp"] = int(e["hp"]) - 1
                e["pos"] = e["pos"] + Vector2(signf(velocity.x) * 65.0, -20.0)
                _burst(e["pos"], Color("#ff865d"), 12)
                if int(e["hp"]) <= 0:
                    e["alive"] = false
                    score += 250
                    banner = "ENEMY SHATTERED  +250"
                    banner_timer = 1.0
                enemies[i] = e
        for i in range(platforms.size()):
            var p: Dictionary = platforms[i]
            if String(p["kind"]) == "support" and bool(p["alive"]) and player.distance_to((p["rect"] as Rect2).get_center()) < 75.0:
                p["alive"] = false
                platforms[i] = p
                _burst((p["rect"] as Rect2).get_center(), Color("#ff9d59"), 22)
                banner = "SUPPORT DESTROYED!"
                banner_timer = 1.2
                _collapse_bridge()
                break

    # Enemies patrol their ledges.
    for i in range(enemies.size()):
        var e: Dictionary = enemies[i]
        if not bool(e["alive"]): continue
        var pos: Vector2 = e["pos"]
        pos.x += float(e["dir"]) * 75.0 * delta
        if pos.x < float(e["left"]):
            pos.x = float(e["left"])
            e["dir"] = 1.0
        elif pos.x > float(e["right"]):
            pos.x = float(e["right"])
            e["dir"] = -1.0
        e["pos"] = pos
        if pos.distance_to(player) < 30.0 and dash_time <= 0.0:
            _damage_player()
            velocity.x = -signf(pos.x - player.x) * 260.0
            velocity.y = -220.0
        enemies[i] = e

    # Debris falls and can damage enemies, creating chain-reaction moments.
    for i in range(debris.size() - 1, -1, -1):
        var d: Dictionary = debris[i]
        var pos: Vector2 = d["pos"]
        var vel: Vector2 = d["vel"]
        vel.y += GRAVITY * delta
        pos += vel * delta
        d["pos"] = pos
        d["vel"] = vel
        d["life"] = float(d["life"]) - delta
        if pos.y > view.y + 120.0 or float(d["life"]) <= 0.0:
            debris.remove_at(i)
        else:
            for j in range(enemies.size()):
                var e: Dictionary = enemies[j]
                if bool(e["alive"]) and pos.distance_to(e["pos"]) < 24.0:
                    e["hp"] = int(e["hp"]) - 1
                    e["pos"] = e["pos"] + Vector2(35, -35)
                    _burst(pos, Color("#ffae63"), 8)
                    if int(e["hp"]) <= 0:
                        e["alive"] = false
                        score += 200
                        banner = "DEBRIS CHAIN  +200"
                        banner_timer = 1.0
                    enemies[j] = e
                    debris.remove_at(i)
                    break
            if i < debris.size():
                debris[i] = d

    _update_particles(delta)
    camera_offset = clampf(player.x - view.x * 0.35, 0.0, world_width - view.x)
    if player.x > world_width - 80.0:
        won = true
        banner = "SIGNAL REACHED  •  LEVEL CLEAR"
        banner_timer = 999.0
    queue_redraw()

func _collapse_bridge() -> void:
    bridge_broken = true
    for i in range(platforms.size()):
        var p: Dictionary = platforms[i]
        if String(p["kind"]) == "bridge" and bool(p["alive"]):
            p["alive"] = false
            platforms[i] = p
            var rect: Rect2 = p["rect"]
            for n in range(12):
                var piece := Vector2(rect.position.x + randf_range(0.0, rect.size.x), rect.position.y + randf_range(0.0, rect.size.y))
                debris.append({"pos": piece, "vel": Vector2(randf_range(-220, 220), randf_range(-320, -40)), "life": 3.0, "size": randf_range(8, 20)})
            _burst(rect.get_center(), Color("#ff8b56"), 30)
            # Nearby enemies are knocked away by the collapsing structure.
            for j in range(enemies.size()):
                var e: Dictionary = enemies[j]
                if bool(e["alive"]) and (e["pos"] as Vector2).x > rect.position.x and (e["pos"] as Vector2).x < rect.end.x:
                    e["pos"] = e["pos"] + Vector2(0, 60)
                    e["hp"] = int(e["hp"]) - 1
                    if int(e["hp"]) <= 0:
                        e["alive"] = false
                        score += 250
                    enemies[j] = e
            score += 100
            banner = "BRIDGE COLLAPSE!  +100"
            banner_timer = 1.8

func _damage_player() -> void:
    hp -= 1
    if hp <= 0:
        game_over = true
        banner = "WRECKED  •  TAP TO RETRY"
        banner_timer = 999.0
    else:
        banner = "HIT!  %d CORE LEFT" % hp
        banner_timer = 0.8

func _burst(pos: Vector2, color: Color, count: int) -> void:
    for i in range(count):
        var a := randf_range(0.0, TAU)
        particles.append({"pos": pos, "vel": Vector2.RIGHT.rotated(a) * randf_range(45, 240), "life": randf_range(0.2, 0.7), "color": color})

func _update_particles(delta: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        var p: Dictionary = particles[i]
        p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
        p["vel"] = (p["vel"] as Vector2) * 0.97 + Vector2(0, 90) * delta
        p["life"] = float(p["life"]) - delta
        if float(p["life"]) <= 0.0:
            particles.remove_at(i)
        else:
            particles[i] = p

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            _restart()
        elif event.keycode == KEY_SPACE or event.keycode == KEY_W or event.keycode == KEY_UP:
            jump_requested = true
        elif event.keycode == KEY_SHIFT or event.keycode == KEY_E:
            dash_requested = true
    elif event is InputEventScreenTouch:
        if event.pressed:
            if game_over or won:
                _restart()
            elif event.position.x > view.x * 0.72 and event.position.y < view.y * 0.60:
                dash_requested = true
            elif event.position.x > view.x * 0.72:
                jump_requested = true
            else:
                touch_move = Vector2(signf(event.position.x - view.x * 0.18), 0)
                if event.position.y < view.y * 0.48:
                    jump_requested = true
        else:
            touch_move = Vector2.ZERO
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if game_over or won:
            _restart()
        elif event.position.x > view.x * 0.72 and event.position.y < view.y * 0.60:
            dash_requested = true
        elif event.position.x > view.x * 0.72:
            jump_requested = true
        else:
            touch_move = Vector2(signf(event.position.x - player.x), 0)
            if event.position.y < view.y * 0.48:
                jump_requested = true
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        touch_move = Vector2.ZERO

func _restart() -> void:
    player = Vector2(130, 480)
    velocity = Vector2.ZERO
    hp = 3
    score = 0
    game_over = false
    won = false
    bridge_broken = false
    dash_time = 0.0
    dash_cooldown = 0.0
    particles.clear()
    debris.clear()
    banner = "RUN  •  JUMP  •  BREAK THE SUPPORT"
    banner_timer = 3.0
    _build_level()
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, view), Color("#080b13"))
    # Parallax stars.
    for i in range(70):
        var sx := fposmod(float(i * 173) - camera_offset * 0.18, view.x)
        var sy := float((i * 97) % 520) + 70.0
        draw_circle(Vector2(sx, sy), 1.2, Color(0.45, 0.65, 0.88, 0.35))
    # World platforms and supports.
    for p in platforms:
        if not bool(p["alive"]): continue
        var rect: Rect2 = p["rect"]
        var screen_rect := Rect2(rect.position - Vector2(camera_offset, 0), rect.size)
        var kind := String(p["kind"])
        var col := Color("#283747")
        if kind == "bridge": col = Color("#594039") if bridge_broken else Color("#b66b43")
        if kind == "support": col = Color("#ff8959")
        draw_rect(screen_rect, col)
        draw_rect(Rect2(screen_rect.position, Vector2(screen_rect.size.x, 4)), Color("#bdefff") if kind == "solid" else Color("#ffd0a4"))
        if kind == "support":
            draw_line(screen_rect.position, screen_rect.end, Color("#ffe3a9"), 2.0)
            draw_line(Vector2(screen_rect.end.x, screen_rect.position.y), Vector2(screen_rect.position.x, screen_rect.end.y), Color("#ffe3a9"), 2.0)
    # Debris.
    for d in debris:
        var pos: Vector2 = d["pos"] - Vector2(camera_offset, 0)
        draw_rect(Rect2(pos, Vector2(float(d["size"]), float(d["size"]) * 0.7)), Color("#ff9b61"))
    # Enemies.
    for e in enemies:
        if not bool(e["alive"]): continue
        var pos: Vector2 = e["pos"] - Vector2(camera_offset, 0)
        draw_circle(pos, 22.0, Color(1.0, 0.25, 0.36, 0.10))
        draw_rect(Rect2(pos - Vector2(14, 14), Vector2(28, 28)), Color("#ff5e70"), false, 3.0)
        draw_circle(pos, 4.0, Color("#fff1f2"))
        for i in range(int(e["hp"])):
            draw_rect(Rect2(pos + Vector2(-10 + i * 9, 21), Vector2(5, 3)), Color("#ffb1ba"))
    # Player and trail.
    var ppos := player - Vector2(camera_offset, 0)
    draw_circle(ppos, 29.0, Color(0.18, 0.82, 1.0, 0.08))
    draw_circle(ppos, 17.0, Color("#4edff6"))
    draw_circle(ppos, 9.0, Color("#f4ffff"))
    if dash_time > 0.0:
        draw_arc(ppos, 30.0, 0, TAU, 48, Color("#a58cff"), 4.0, true)
    for p in particles:
        var pos: Vector2 = p["pos"] - Vector2(camera_offset, 0)
        var c: Color = p["color"]
        c.a = clampf(float(p["life"]) * 1.7, 0, 1)
        draw_circle(pos, 2.5, c)
    var font := ThemeDB.fallback_font
    if font == null: return
    draw_rect(Rect2(0, 0, view.x, 58), Color(0.04, 0.06, 0.10, 0.94))
    draw_string(font, Vector2(20, 24), "WRECKLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#eff7ff"))
    draw_string(font, Vector2(20, 45), "SCORE %04d   CORE %d" % [score, hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a6bed4"))
    if banner_timer > 0:
        draw_string(font, Vector2(0, 96), banner, HORIZONTAL_ALIGNMENT_CENTER, view.x, 17, Color("#ffbd93"))
    draw_string(font, Vector2(view.x - 360, view.y - 24), "A/D MOVE   SPACE JUMP   SHIFT DASH   R RESET", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9bb2c7"))
    # Touch-friendly controls.
    draw_circle(Vector2(80, view.y - 82), 44, Color(0.32, 0.54, 0.70, 0.15))
    draw_arc(Vector2(80, view.y - 82), 44, 0, TAU, 40, Color("#6cacc9"), 2, true)
    draw_string(font, Vector2(53, view.y - 77), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d8f4ff"))
    draw_circle(Vector2(view.x - 140, view.y - 82), 37, Color(0.25, 0.82, 1.0, 0.12))
    draw_arc(Vector2(view.x - 140, view.y - 82), 37, 0, TAU, 40, Color("#6ceeff"), 2, true)
    draw_string(font, Vector2(view.x - 162, view.y - 78), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d8faff"))
    draw_circle(Vector2(view.x - 55, view.y - 142), 30, Color(0.65, 0.42, 1.0, 0.12))
    draw_arc(Vector2(view.x - 55, view.y - 142), 30, 0, TAU, 40, Color("#b5a0ff"), 2, true)
    draw_string(font, Vector2(view.x - 75, view.y - 138), "DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#eee6ff"))
    if game_over or won:
        draw_rect(Rect2(Vector2.ZERO, view), Color(0.02, 0.03, 0.06, 0.78))
        draw_string(font, Vector2(0, view.y * 0.44), "LEVEL CLEAR" if won else "WRECKED", HORIZONTAL_ALIGNMENT_CENTER, view.x, 31, Color("#83f1ff") if won else Color("#ff7c8e"))
        draw_string(font, Vector2(0, view.y * 0.53), "SCORE %04d  •  TAP OR PRESS R TO RETRY" % score, HORIZONTAL_ALIGNMENT_CENTER, view.x, 16, Color("#eef7ff"))
