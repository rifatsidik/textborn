extends Node2D

# CRUSH//CORE - small touch-first destruction prototype.
# Tap anywhere to launch an energy core at the tower.
const BLOCK_SIZE := Vector2(38.0, 30.0)
const SHOT_COOLDOWN := 0.42

var screen_size := Vector2(720.0, 1280.0)
var floor_y := 1020.0
var tower_center := Vector2.ZERO
var shots_left := 12
var score := 0
var combo := 0
var best_combo := 0
var cooldown := 0.0
var game_over := false
var blocks: Array[RigidBody2D] = []
var projectiles: Array[RigidBody2D] = []
var shockwaves: Array[Dictionary] = []
var message := "TAP TO SMASH"
var message_timer := 2.5
var floor_body: StaticBody2D

func _ready() -> void:
    screen_size = get_viewport_rect().size
    # Portrait-first layout, but keep working in desktop landscape.
    floor_y = screen_size.y * 0.82
    tower_center = Vector2(screen_size.x * 0.68, floor_y - 155.0)
    _build_arena()
    _spawn_tower()
    queue_redraw()

func _build_arena() -> void:
    floor_body = StaticBody2D.new()
    floor_body.name = "Floor"
    floor_body.position = Vector2(screen_size.x * 0.5, floor_y + 28.0)
    add_child(floor_body)
    var floor_shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(screen_size.x * 1.5, 56.0)
    floor_shape.shape = rect
    floor_body.add_child(floor_shape)

func _spawn_tower() -> void:
    for old_block in blocks:
        if is_instance_valid(old_block):
            old_block.queue_free()
    blocks.clear()
    var columns := 5
    var rows := 6
    var bw := minf(42.0, screen_size.x * 0.09)
    var bh := 30.0
    var gap := 2.0
    var start_x := tower_center.x - (columns * (bw + gap) - gap) * 0.5
    for row in range(rows):
        for col in range(columns):
            var block := RigidBody2D.new()
            block.name = "Block_%d_%d" % [row, col]
            block.position = Vector2(start_x + col * (bw + gap) + bw * 0.5, floor_y - 28.0 - row * (bh + gap) - bh * 0.5)
            block.mass = 0.8
            block.gravity_scale = 1.0
            block.linear_damp = 0.15
            block.angular_damp = 0.2
            block.set_meta("is_tower_block", true)
            add_child(block)
            var collision := CollisionShape2D.new()
            var shape := RectangleShape2D.new()
            shape.size = Vector2(bw, bh)
            collision.shape = shape
            block.add_child(collision)
            blocks.append(block)

func _process(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    message_timer = maxf(0.0, message_timer - delta)
    for i in range(shockwaves.size() - 1, -1, -1):
        shockwaves[i]["radius"] = float(shockwaves[i]["radius"]) + delta * 420.0
        shockwaves[i]["alpha"] = float(shockwaves[i]["alpha"]) - delta * 1.4
        if float(shockwaves[i]["alpha"]) <= 0.0:
            shockwaves.remove_at(i)
    _check_blocks()
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _handle_tap(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_tap(event.position)
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            _restart()
        elif event.keycode == KEY_SPACE:
            _fire_core()

func _handle_tap(pos: Vector2) -> void:
    if pos.y < 95.0 and pos.x > screen_size.x * 0.68:
        _restart()
        return
    if game_over:
        _restart()
        return
    _fire_core()

func _fire_core() -> void:
    if cooldown > 0.0 or game_over:
        return
    if shots_left <= 0:
        game_over = true
        message = "OUT OF CORES  •  TAP TO RETRY"
        message_timer = 99.0
        return
    shots_left -= 1
    cooldown = SHOT_COOLDOWN
    var orb := RigidBody2D.new()
    orb.name = "EnergyCore"
    orb.position = Vector2(screen_size.x * 0.13, floor_y - 110.0)
    orb.mass = 2.8
    orb.gravity_scale = 0.12
    orb.linear_damp = 0.05
    orb.collision_layer = 2
    orb.collision_mask = 1
    add_child(orb)
    var collision := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 15.0
    collision.shape = circle
    orb.add_child(collision)
    var visual := CoreVisual.new()
    orb.add_child(visual)
    orb.body_entered.connect(_on_projectile_body_entered.bind(orb))
    projectiles.append(orb)
    var direction := (Vector2(tower_center.x, floor_y - 100.0) - orb.position).normalized()
    orb.apply_central_impulse(direction * screen_size.x * 2.1)
    message = "SMASH!"
    message_timer = 0.7
    _make_shockwave(orb.position, 22.0, 0.5)
    queue_redraw()

func _on_projectile_body_entered(body: Node, orb: RigidBody2D) -> void:
    if not is_instance_valid(orb):
        return
    if body == floor_body:
        return
    _explode(orb.global_position, orb)
    if is_instance_valid(orb):
        orb.queue_free()
    projectiles.erase(orb)

func _explode(center: Vector2, source: RigidBody2D = null) -> void:
    _make_shockwave(center, 24.0, 1.0)
    var hit_count := 0
    for block in blocks:
        if not is_instance_valid(block) or block == source:
            continue
        var offset := block.global_position - center
        var distance := offset.length()
        var radius := screen_size.x * 0.28
        if distance < radius:
            var falloff := 1.0 - distance / radius
            var push := offset.normalized()
            if push == Vector2.ZERO:
                push = Vector2.UP
            block.apply_central_impulse((push * 500.0 + Vector2.UP * 230.0) * falloff)
            block.apply_torque_impulse(randf_range(-90.0, 90.0) * falloff)
            hit_count += 1
    score += hit_count * 10
    if hit_count >= 8:
        combo += 1
        best_combo = maxi(best_combo, combo)
        message = "CHAIN SMASH  x%d" % combo
    else:
        combo = 0
        message = "BOOM!"
    message_timer = 1.1
    _make_shockwave(center, screen_size.x * 0.24, 0.75)
    queue_redraw()

func _make_shockwave(pos: Vector2, radius: float, alpha: float) -> void:
    shockwaves.append({"pos": pos, "radius": radius, "alpha": alpha})

func _check_blocks() -> void:
    var alive := 0
    for block in blocks:
        if is_instance_valid(block):
            alive += 1
    if alive == 0 and not game_over:
        game_over = true
        message = "TOWER DESTROYED!  TAP TO PLAY AGAIN"
        message_timer = 99.0
    elif shots_left <= 0 and projectiles.is_empty() and not game_over:
        game_over = true
        message = "ROUND OVER  •  TAP TO RETRY"
        message_timer = 99.0

func _restart() -> void:
    for orb in projectiles:
        if is_instance_valid(orb):
            orb.queue_free()
    projectiles.clear()
    for block in blocks:
        if is_instance_valid(block):
            block.queue_free()
    blocks.clear()
    shots_left = 12
    score = 0
    combo = 0
    best_combo = 0
    game_over = false
    cooldown = 0.0
    message = "TAP TO SMASH"
    message_timer = 2.0
    _spawn_tower()
    queue_redraw()

func _draw() -> void:
    # Minimal dark arena with a quiet grid and a glowing target.
    draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#0b0d12"))
    for x in range(0, int(screen_size.x), 48):
        draw_line(Vector2(x, 100), Vector2(x, floor_y), Color(0.18, 0.23, 0.30, 0.22), 1.0)
    for y in range(120, int(floor_y), 48):
        draw_line(Vector2(0, y), Vector2(screen_size.x, y), Color(0.18, 0.23, 0.30, 0.18), 1.0)
    draw_rect(Rect2(0, floor_y, screen_size.x, screen_size.y - floor_y), Color("#171b24"))
    draw_line(Vector2(0, floor_y), Vector2(screen_size.x, floor_y), Color("#7d8799"), 2.0)
    # Launcher pad
    var launch_pos := Vector2(screen_size.x * 0.13, floor_y - 110.0)
    draw_circle(launch_pos, 35.0, Color(0.15, 0.75, 1.0, 0.08))
    draw_arc(launch_pos, 28.0, 0.0, TAU, 40, Color(0.25, 0.8, 1.0, 0.65), 2.0, true)
    draw_circle(launch_pos, 5.0, Color("#d7f7ff"))
    # Target marker
    draw_arc(Vector2(tower_center.x, floor_y - 118.0), 75.0, 0.0, TAU, 48, Color(1.0, 0.43, 0.24, 0.35), 1.5, true)
    for wave in shockwaves:
        var c := Color(1.0, 0.52, 0.26, clampf(float(wave["alpha"]), 0.0, 1.0))
        draw_arc(wave["pos"], float(wave["radius"]), 0.0, TAU, 48, c, 3.0, true)
    var font := ThemeDB.fallback_font
    if font == null:
        return
    draw_string(font, Vector2(24, 42), "CRUSH//CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#eef3ff"))
    draw_string(font, Vector2(24, 70), "ONE TAP. BIG IMPACT.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8d9aaf"))
    draw_string(font, Vector2(24, 112), "SCORE  %05d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f2f5fb"))
    draw_string(font, Vector2(24, 139), "CORES  %02d" % shots_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#6fe5ff"))
    draw_string(font, Vector2(screen_size.x - 98, 42), "RETRY  R", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#aab4c5"))
    if message_timer > 0.0:
        var width := screen_size.x
        draw_string(font, Vector2(0, screen_size.y * 0.22), message, HORIZONTAL_ALIGNMENT_CENTER, width, 19, Color("#ffb58b"))
    draw_string(font, Vector2(0, screen_size.y - 28), "TAP ANYWHERE TO LAUNCH", HORIZONTAL_ALIGNMENT_CENTER, screen_size.x, 13, Color("#9aa7bc"))

class CoreVisual extends Node2D:
    func _draw() -> void:
        draw_circle(Vector2.ZERO, 18.0, Color(0.1, 0.7, 1.0, 0.12))
        draw_circle(Vector2.ZERO, 12.0, Color(0.15, 0.76, 1.0, 0.3))
        draw_circle(Vector2.ZERO, 7.0, Color("#8deaff"))
        draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
