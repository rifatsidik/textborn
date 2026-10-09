extends Node2D

# ELEMENTAL OVERDRIVE — GESTURE EXECUTION PROTOTYPE
# Desktop: WASD move, SPACE activate Lightning Execution, arrows/ swipe to follow prompts.
# Touch: drag on left half to move; tap the EXECUTE button; swipe anywhere during execution.
const BG := Color("#080b18")
const GOLD := Color("#ffd34d")
const RED := Color("#ff405b")
const DIRECTIONS := ["LEFT", "RIGHT", "UP", "DOWN"]
const DIR_VECTORS := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
const DIR_ICONS := ["←", "→", "↑", "↓"]

var view_size := Vector2(1280, 720)
var player := Vector2(640, 390)
var facing := Vector2.RIGHT
var hp := 100.0
var kills := 0
var wave := 1
var enemies: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var banner := "MOVE • SURVIVE • BUILD YOUR CHAIN"
var banner_timer := 3.0
var move_touch := false
var touch_origin := Vector2.ZERO
var touch_pos := Vector2.ZERO
var attack_timer := 0.0
var execution := false
var sequence: Array[int] = []
var sequence_step := 0
var sequence_timer := 0.0
var sequence_window := 0.9
var chain_count := 0
var total_chain := 0
var last_tap_time := -10.0
var elapsed := 0.0
var game_over := false
var shake := 0.0

func _ready() -> void:
    randomize()
    view_size = get_viewport_rect().size
    _spawn_wave()

func _spawn_wave() -> void:
    var amount := 8 + wave * 2
    for i in range(amount):
        var side := randi() % 4
        var pos := Vector2.ZERO
        if side == 0:
            pos = Vector2(randf_range(35, view_size.x - 35), 92)
        elif side == 1:
            pos = Vector2(view_size.x - 30, randf_range(100, view_size.y - 30))
        elif side == 2:
            pos = Vector2(randf_range(35, view_size.x - 35), view_size.y - 30)
        else:
            pos = Vector2(30, randf_range(100, view_size.y - 30))
        enemies.append({"pos": pos, "hp": 2 + int(wave >= 4), "alive": true, "kind": randi() % 3, "r": randf_range(12.0, 17.0), "flash": 0.0})
    banner = "WAVE " + str(wave) + "  •  LIGHTNING EXECUTION READY"
    banner_timer = 2.2

func _process(dt: float) -> void:
    view_size = get_viewport_rect().size
    elapsed += dt
    banner_timer = maxf(0.0, banner_timer - dt)
    shake = maxf(0.0, shake - dt * 20.0)
    if game_over:
        _tick_fx(dt)
        queue_redraw()
        return

    var move := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        move.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        move.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        move.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        move.y += 1.0
    if move_touch:
        move = (touch_pos - touch_origin).limit_length(80.0) / 80.0
    if move.length() > 1.0:
        move = move.normalized()
    if not execution:
        player += move * 245.0 * dt
    if move.length() > 0.1:
        facing = move.normalized()
    player.x = clampf(player.x, 24.0, view_size.x - 24.0)
    player.y = clampf(player.y, 88.0, view_size.y - 25.0)

    attack_timer = maxf(0.0, attack_timer - dt)
    if not execution and attack_timer <= 0.0:
        _basic_attack()

    if execution:
        sequence_timer -= dt
        if sequence_timer <= 0.0:
            _break_chain("TOO SLOW — CHAIN LOST")

    for e in enemies:
        if not e.alive:
            continue
        e.flash = maxf(0.0, e.flash - dt)
        var delta: Vector2 = player - e.pos
        var distance := delta.length()
        if distance > 1.0 and not execution:
            var speed := 68.0 if e.kind == 0 else (86.0 if e.kind == 1 else 76.0)
            e.pos += delta.normalized() * speed * dt
        if distance < 25.0 and not execution:
            hp -= 20.0 * dt
            if hp <= 0.0:
                hp = 0.0
                game_over = true
                banner = "RUN ENDED"

    _tick_fx(dt)
    if _alive_count() == 0:
        wave += 1
        _spawn_wave()
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if game_over:
            if event.keycode == KEY_R:
                get_tree().reload_current_scene()
            return
        if execution:
            if event.keycode == KEY_LEFT or event.keycode == KEY_A:
                _gesture(0)
            elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
                _gesture(1)
            elif event.keycode == KEY_UP or event.keycode == KEY_W:
                _gesture(2)
            elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
                _gesture(3)
        elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            _start_execution()
    elif event is InputEventScreenTouch:
        if game_over:
            if event.pressed:
                get_tree().reload_current_scene()
            return
        if event.pressed:
            if execution:
                _register_tap(event.position)
            elif event.position.x < view_size.x * 0.43:
                move_touch = true
                touch_origin = event.position
                touch_pos = event.position
            elif Rect2(view_size.x - 255, view_size.y - 135, 225, 100).has_point(event.position):
                _start_execution()
            else:
                _register_tap(event.position)
        else:
            move_touch = false
    elif event is InputEventScreenDrag:
        if execution:
            var delta: Vector2 = event.position - event.relative
            _gesture_from_vector(event.relative)
        elif move_touch:
            touch_pos = event.position
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if game_over:
                get_tree().reload_current_scene()
            elif not execution and Rect2(view_size.x - 255, view_size.y - 135, 225, 100).has_point(event.position):
                _start_execution()
            elif execution:
                _register_tap(event.position)
    elif event is InputEventMouseMotion and execution and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _gesture_from_vector(event.relative)

func _register_tap(pos: Vector2) -> void:
    if not execution:
        return
    var now := elapsed
    if now - last_tap_time <= 0.32:
        _gesture(4)
        last_tap_time = -10.0
    else:
        last_tap_time = now

func _gesture_from_vector(delta: Vector2) -> void:
    if delta.length() < 18.0:
        return
    if absf(delta.x) > absf(delta.y):
        _gesture(1 if delta.x > 0.0 else 0)
    else:
        _gesture(3 if delta.y > 0.0 else 2)

func _start_execution() -> void:
    if game_over or execution:
        return
    var target := _nearest_enemy(player, 520.0)
    if target == -1:
        banner = "NO TARGET IN RANGE"
        banner_timer = 1.0
        return
    execution = true
    chain_count = 0
    sequence_step = 0
    sequence.clear()
    var length := mini(3 + int(total_chain / 5), 7)
    for i in range(length):
        sequence.append(randi() % 5)
    sequence_window = maxf(0.36, 0.86 - float(total_chain) * 0.012)
    sequence_timer = sequence_window
    banner = "LIGHTNING EXECUTION  •  FOLLOW THE GESTURE"
    banner_timer = 1.5
    _strike_target(target)
    _next_prompt()

func _next_prompt() -> void:
    if sequence_step >= sequence.size():
        _complete_chain()
        return
    sequence_timer = sequence_window
    banner = "FOLLOW THE GESTURE"
    banner_timer = 0.35

func _gesture(input_id: int) -> void:
    if not execution or game_over:
        return
    if sequence_step >= sequence.size():
        return
    if input_id != sequence[sequence_step]:
        _break_chain("WRONG GESTURE — CHAIN LOST")
        return
    chain_count += 1
    total_chain += 1
    var next := _nearest_enemy(player, 650.0)
    if next != -1:
        _strike_target(next)
    else:
        _burst(player, GOLD, 18, 210.0)
    sequence_step += 1
    sequence_window = maxf(0.34, 0.86 - float(total_chain) * 0.012)
    if sequence_step >= sequence.size():
        _complete_chain()
    else:
        _next_prompt()

func _strike_target(idx: int) -> void:
    if idx < 0 or idx >= enemies.size() or not enemies[idx].alive:
        return
    var target: Vector2 = enemies[idx].pos
    var col := RED if total_chain >= 10 else GOLD
    bolts.append({"a": player, "b": target, "life": 0.19, "max": 0.19, "col": col})
    _burst(player, col, 8, 170.0)
    _burst(target, col, 18, 240.0)
    player = target + (player - target).normalized() * 18.0
    enemies[idx].hp -= 99
    enemies[idx].alive = false
    kills += 1
    shake = 4.0 + minf(float(chain_count), 8.0) * 0.4
    attack_timer = 0.18

func _complete_chain() -> void:
    execution = false
    banner = "CHAIN COMPLETE  ×" + str(chain_count) + "  •  " + ("CRIMSON OVERDRIVE!" if total_chain >= 10 else "KEEP THE MOMENTUM")
    banner_timer = 2.0
    _burst(player, RED if total_chain >= 10 else GOLD, 34, 290.0)
    shake = 8.0
    if chain_count >= 4:
        hp = minf(100.0, hp + 5.0)
    sequence.clear()
    sequence_step = 0

func _break_chain(reason: String) -> void:
    execution = false
    chain_count = 0
    total_chain = 0
    sequence.clear()
    sequence_step = 0
    banner = reason
    banner_timer = 1.6
    _burst(player, Color("#ff536e"), 20, 170.0)

func _basic_attack() -> void:
    attack_timer = 0.72
    var idx := _nearest_enemy(player, 300.0)
    if idx == -1:
        return
    var target: Vector2 = enemies[idx].pos
    bolts.append({"a": player, "b": target, "life": 0.12, "max": 0.12, "col": GOLD})
    enemies[idx].hp -= 1
    if enemies[idx].hp <= 0:
        enemies[idx].alive = false
        kills += 1
        _burst(target, GOLD, 8, 130.0)

func _nearest_enemy(from: Vector2, radius: float) -> int:
    var best := -1
    var best_distance := radius
    for i in range(enemies.size()):
        if not enemies[i].alive:
            continue
        var d: float = from.distance_to(enemies[i].pos)
        if d < best_distance:
            best_distance = d
            best = i
    return best

func _alive_count() -> int:
    var count := 0
    for e in enemies:
        if e.alive:
            count += 1
    return count

func _burst(pos: Vector2, col: Color, count: int, force: float) -> void:
    for i in range(count):
        var a := randf() * TAU
        particles.append({"pos": pos, "vel": Vector2.RIGHT.rotated(a) * randf_range(force * 0.2, force), "life": randf_range(0.15, 0.5), "max": 0.5, "col": col, "size": randf_range(1.5, 4.5)})

func _tick_fx(dt: float) -> void:
    for p in particles:
        p.life -= dt
        p.pos += p.vel * dt
        p.vel *= pow(0.08, dt)
    particles = particles.filter(func(p): return p.life > 0.0)
    for b in bolts:
        b.life -= dt
    bolts = bolts.filter(func(b): return b.life > 0.0)

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), BG)
    for x in range(0, int(size.x), 48):
        draw_line(Vector2(x, 72), Vector2(x, size.y), Color(0.12, 0.19, 0.32, 0.25), 1.0)
    for y in range(72, int(size.y), 48):
        draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.19, 0.32, 0.25), 1.0)

    for b in bolts:
        var alpha: float = clampf(b.life / b.max, 0.0, 1.0)
        var a: Vector2 = b.a
        var z: Vector2 = b.b
        var c: Color = b.col
        var mid := (a + z) * 0.5 + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
        draw_line(a, z, Color(c.r, c.g, c.b, alpha * 0.28), 10.0)
        draw_line(a, mid, Color(c.r, c.g, c.b, alpha), 4.0)
        draw_line(mid, z, Color.WHITE, 2.0)

    for e in enemies:
        if not e.alive:
            continue
        var col := Color("#ff4e6d") if e.kind == 0 else (Color("#ff994b") if e.kind == 1 else Color("#b977ff"))
        if e.flash > 0.0:
            col = Color.WHITE
        draw_circle(e.pos, e.r + 5.0, Color(col.r, col.g, col.b, 0.12))
        draw_colored_polygon(PackedVector2Array([e.pos + Vector2(0, -e.r), e.pos + Vector2(e.r, 0), e.pos + Vector2(0, e.r), e.pos + Vector2(-e.r, 0)]), col)
        draw_circle(e.pos, 3.0, Color("#191323"))

    for p in particles:
        draw_circle(p.pos, p.size * clampf(p.life / p.max, 0.0, 1.0), Color(p.col.r, p.col.g, p.col.b, clampf(p.life / p.max, 0.0, 1.0)))

    var player_col := RED if total_chain >= 10 else Color("#ffe98a")
    draw_circle(player, 33.0, Color(player_col.r, player_col.g, player_col.b, 0.13))
    draw_circle(player, 18.0, Color("#bafaff"))
    draw_colored_polygon(PackedVector2Array([player + facing * 30.0, player + facing.rotated(2.5) * 13.0, player + facing.rotated(-2.5) * 13.0]), Color.WHITE)

    draw_rect(Rect2(0, 0, size.x, 72), Color(0.02, 0.03, 0.08, 0.96))
    draw_string(ThemeDB.fallback_font, Vector2(20, 28), "ELEMENTAL OVERDRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#bafaff"))
    draw_string(ThemeDB.fallback_font, Vector2(20, 53), "HP " + str(int(hp)) + "   KILLS " + str(kills) + "   WAVE " + str(wave), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(size.x - 20, 28), "CHAIN ×" + str(total_chain), HORIZONTAL_ALIGNMENT_RIGHT, -1, 21, GOLD if total_chain < 10 else RED)
    draw_string(ThemeDB.fallback_font, Vector2(size.x - 20, 53), "GOLDEN LIGHTNING" if total_chain < 10 else "CRIMSON OVERDRIVE", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, player_col)

    if execution:
        draw_rect(Rect2(0, 72, size.x, size.y - 72), Color(0.02, 0.02, 0.06, 0.38))
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, 125), "LIGHTNING EXECUTION", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, GOLD)
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, 157), "INPUT " + str(sequence_step + 1) + " / " + str(sequence.size()) + "     CHAIN ×" + str(chain_count), HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color.WHITE)
        var prompt_count := mini(4, sequence.size())
        var prompt_width := 86.0
        var start_x := size.x * 0.5 - (prompt_count * prompt_width) * 0.5
        for i in range(prompt_count):
            var rect := Rect2(start_x + i * prompt_width, 190, 72, 72)
            var is_current := i == sequence_step
            draw_rect(rect, Color("#4a3d17") if is_current else Color("#17243a"), true)
            draw_rect(rect, GOLD if is_current else Color("#52617b"), false, 2.0)
            var token := "×2" if sequence[i] == 4 else DIR_ICONS[sequence[i]]
            draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 36, rect.position.y + 49), token, HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color.WHITE if is_current else Color("#91a0bd"))
        var timer_w := 320.0 * clampf(sequence_timer / maxf(sequence_window, 0.01), 0.0, 1.0)
        draw_rect(Rect2(size.x * 0.5 - 160, 278, 320, 8), Color("#202b40"), true)
        draw_rect(Rect2(size.x * 0.5 - 160, 278, timer_w, 8), RED if sequence_timer < 0.28 else GOLD, true)
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, 322), "SWIPE THE DIRECTION  •  DOUBLE TAP = ×2", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color("#d5def0"))

    if banner_timer > 0.0:
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, size.y - 160), banner, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)

    if not execution and not game_over:
        draw_circle(Vector2(92, size.y - 108), 47.0, Color(0.12, 0.7, 1, 0.07))
        draw_arc(Vector2(92, size.y - 108), 47.0, 0.0, TAU, 40, Color(0.35, 0.85, 1, 0.5), 2.0, true)
        draw_string(ThemeDB.fallback_font, Vector2(59, size.y - 103), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#bafaff"))
        var btn := Rect2(size.x - 255, size.y - 135, 225, 100)
        draw_rect(btn, Color("#3b3012"), true)
        draw_rect(btn, GOLD, false, 3.0)
        draw_string(ThemeDB.fallback_font, Vector2(btn.position.x + btn.size.x * 0.5, btn.position.y + 42), "LIGHTNING", HORIZONTAL_ALIGNMENT_CENTER, -1, 19, GOLD)
        draw_string(ThemeDB.fallback_font, Vector2(btn.position.x + btn.size.x * 0.5, btn.position.y + 70), "EXECUTION", HORIZONTAL_ALIGNMENT_CENTER, -1, 19, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, size.y - 34), "SPACE / ENTER OR TAP EXECUTION", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color("#9caaca"))

    if game_over:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.78))
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, size.y * 0.5 - 15), "RUN ENDED", HORIZONTAL_ALIGNMENT_CENTER, -1, 40, RED)
        draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, size.y * 0.5 + 32), "KILLS " + str(kills) + "  •  PRESS R / TAP TO RESTART", HORIZONTAL_ALIGNMENT_CENTER, -1, 17, Color.WHITE)
