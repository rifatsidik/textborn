extends Node2D

# LIGHTNING SURVIVOR — Prototype 1
# Godot 4.x | Landscape | PC + touchscreen
const ARENA := Vector2(1280.0, 720.0)
var player := Vector2(640, 390)
var facing := Vector2.RIGHT
var enemies: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var hp := 5
var kills := 0
var wave := 1
var time_alive := 0.0
var attack_cd := 0.0
var skill_cd := 0.0
var invuln := 0.0
var game_over := false
var red_lightning := false
var skill_active := false
var skill_targets: Array[Vector2] = []
var skill_index := 0
var skill_timer := 0.0
var skill_origin := Vector2.ZERO
var move_touch := Vector2.ZERO
var touch_start := Vector2.ZERO
var touch_now := Vector2.ZERO
var moving_touch := false
var banner := "SURVIVE  //  TAP LIGHTNING EXECUTION"
var banner_time := 4.0
var shake := 0.0

func _ready() -> void:
    randomize()
    _spawn_wave()

func _spawn_wave() -> void:
    for i in range(8 + wave * 2):
        var side := randi() % 4
        var p := Vector2.ZERO
        if side == 0: p = Vector2(randf_range(40, 1240), 95)
        elif side == 1: p = Vector2(1240, randf_range(100, 680))
        elif side == 2: p = Vector2(randf_range(40, 1240), 680)
        else: p = Vector2(40, randf_range(100, 680))
        enemies.append({"pos":p, "vel":Vector2.ZERO, "hp":2 if randf() > 0.22 else 3, "alive":true, "flash":0.0, "kind":randi()%3, "radius":randf_range(12.0,18.0)})
    banner = "WAVE " + str(wave) + "  //  ENEMIES INBOUND"
    banner_time = 2.2

func _process(dt: float) -> void:
    if game_over:
        _tick_fx(dt)
        queue_redraw()
        return
    time_alive += dt
    attack_cd = maxf(0.0, attack_cd - dt)
    skill_cd = maxf(0.0, skill_cd - dt)
    invuln = maxf(0.0, invuln - dt)
    banner_time = maxf(0.0, banner_time - dt)
    shake = maxf(0.0, shake - dt * 18.0)

    var move := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1
    if moving_touch:
        move = (touch_now - touch_start).limit_length(80.0) / 80.0
    if move.length() > 1.0: move = move.normalized()
    if not skill_active:
        player += move * 245.0 * dt
    if move.length() > 0.1: facing = move.normalized()
    player.x = clampf(player.x, 30.0, 1250.0)
    player.y = clampf(player.y, 90.0, 690.0)

    if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
        if skill_cd <= 0 and not skill_active: _start_lightning()
    if attack_cd <= 0 and not skill_active:
        _auto_attack()

    if skill_active:
        skill_timer -= dt
        if skill_timer <= 0:
            _lightning_jump()

    for e in enemies:
        if not e.alive: continue
        e.flash = maxf(0.0, e.flash - dt)
        var delta_pos: Vector2 = player - e.pos
        var dist := delta_pos.length()
        if dist > 1.0 and not skill_active:
            var speed := 65.0 if e.kind == 0 else (92.0 if e.kind == 1 else 76.0)
            e.vel = e.vel.lerp(delta_pos.normalized() * speed, minf(1.0, dt * 2.0))
            e.pos += e.vel * dt
        if dist < 27 and invuln <= 0 and not skill_active:
            hp -= 1
            invuln = 0.9
            _burst(player, Color(1.0,0.18,0.25), 14, 150.0)
            shake = 4.0
            if hp <= 0:
                game_over = true
                banner = "RUN ENDED"
    _tick_fx(dt)
    if _alive_count() == 0:
        wave += 1
        if kills >= 25 and not red_lightning:
            red_lightning = true
            banner = "EVOLUTION UNLOCKED  //  CRIMSON LIGHTNING"
            banner_time = 3.0
        _spawn_wave()
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_R and game_over:
        get_tree().reload_current_scene()
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x > get_viewport_rect().size.x * 0.72 and event.position.y > get_viewport_rect().size.y * 0.55:
                if skill_cd <= 0 and not skill_active: _start_lightning()
            elif event.position.x < get_viewport_rect().size.x * 0.42:
                moving_touch = true
                touch_start = event.position
                touch_now = event.position
            else:
                # Tap the playfield to launch the signature skill too.
                if skill_cd <= 0 and not skill_active: _start_lightning()
        else:
            moving_touch = false
    elif event is InputEventScreenDrag and moving_touch:
        touch_now = event.position
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and event.position.x > get_viewport_rect().size.x * 0.70 and event.position.y > get_viewport_rect().size.y * 0.55:
            if skill_cd <= 0 and not skill_active: _start_lightning()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            if skill_cd <= 0 and not skill_active: _start_lightning()

func _auto_attack() -> void:
    attack_cd = 0.48
    var target_index := _nearest_enemy(player, 260.0, [])
    if target_index == -1: return
    var target: Vector2 = enemies[target_index].pos
    facing = (target - player).normalized()
    bolts.append({"a":player, "b":target, "life":0.12, "max":0.12, "col":Color(0.5,0.9,1.0)})
    enemies[target_index].hp -= 1
    enemies[target_index].flash = 0.10
    if enemies[target_index].hp <= 0: _kill_enemy(target_index, false)

func _start_lightning() -> void:
    if skill_cd > 0 or skill_active: return
    skill_cd = 5.5
    skill_active = true
    skill_targets.clear()
    skill_index = 0
    skill_origin = player
    var max_targets := 10 if not red_lightning else 18
    var used: Array[int] = []
    var cursor := player
    for i in range(max_targets):
        var idx := _nearest_enemy(cursor, 520.0, used)
        if idx == -1: break
        used.append(idx)
        skill_targets.append(Vector2(idx, 0))
        cursor = enemies[idx].pos
    if skill_targets.is_empty():
        skill_active = false
        banner = "NO TARGETS IN RANGE"
        banner_time = 1.0
        return
    skill_timer = 0.025
    banner = "LIGHTNING EXECUTION!"
    banner_time = 1.0
    _lightning_jump()

func _lightning_jump() -> void:
    if skill_index >= skill_targets.size():
        skill_active = false
        skill_timer = 0.0
        rings.append({"pos":player, "r":10.0, "life":0.35, "max":0.35, "col":Color(1.0,0.16,0.22) if red_lightning else Color(1.0,0.82,0.18)})
        _burst(player, Color(1.0,0.15,0.24) if red_lightning else Color(1.0,0.82,0.18), 35, 270.0)
        shake = 9.0
        banner = "CRIMSON FINISHER!" if red_lightning else "GOLDEN FINISHER!"
        banner_time = 1.1
        return
    var idx := int(skill_targets[skill_index].x)
    if idx < 0 or idx >= enemies.size() or not enemies[idx].alive:
        skill_index += 1
        skill_timer = 0.018
        return
    var old_pos := player
    var target_pos: Vector2 = enemies[idx].pos
    var col := Color(1.0,0.12,0.20) if red_lightning else Color(1.0,0.84,0.18)
    bolts.append({"a":old_pos, "b":target_pos, "life":0.20, "max":0.20, "col":col})
    _burst(old_pos, col, 7, 160.0)
    _burst(target_pos, col, 14, 230.0)
    player = target_pos + (old_pos - target_pos).normalized() * 23.0
    facing = (target_pos - old_pos).normalized()
    enemies[idx].hp -= 99
    enemies[idx].flash = 0.16
    _kill_enemy(idx, true)
    kills += 0 # counted in _kill_enemy
    skill_index += 1
    skill_timer = 0.025 if not red_lightning else 0.018
    shake = 1.7

func _nearest_enemy(from: Vector2, radius: float, excluded: Array) -> int:
    var best := -1
    var best_dist := radius
    for i in range(enemies.size()):
        if not enemies[i].alive or excluded.has(i): continue
        var d: float = from.distance_to(enemies[i].pos)
        if d < best_dist:
            best_dist = d
            best = i
    return best

func _kill_enemy(idx: int, by_skill: bool) -> void:
    if not enemies[idx].alive: return
    enemies[idx].alive = false
    kills += 1
    var col := Color(1.0,0.12,0.20) if red_lightning else Color(1.0,0.84,0.18)
    _burst(enemies[idx].pos, col if by_skill else Color(0.25,0.85,1.0), 16 if by_skill else 7, 190.0)
    if by_skill and red_lightning:
        # Red chain sparks jump to a nearby surviving enemy.
        var next := _nearest_enemy(enemies[idx].pos, 100.0, [idx])
        if next != -1:
            bolts.append({"a":enemies[idx].pos, "b":enemies[next].pos, "life":0.12, "max":0.12, "col":Color(1.0,0.12,0.20)})
            enemies[next].hp -= 1
            if enemies[next].hp <= 0: _kill_enemy(next, true)

func _burst(pos: Vector2, col: Color, count: int, force: float) -> void:
    for i in range(count):
        var angle := randf() * TAU
        particles.append({"pos":pos, "vel":Vector2.RIGHT.rotated(angle)*randf_range(force*0.25,force), "life":randf_range(0.12,0.45), "max":0.45, "col":col, "size":randf_range(1.5,4.5)})

func _tick_fx(dt: float) -> void:
    for p in particles:
        p.life -= dt
        p.pos += p.vel * dt
        p.vel *= pow(0.08, dt)
    particles = particles.filter(func(p): return p.life > 0)
    for b in bolts: b.life -= dt
    bolts = bolts.filter(func(b): return b.life > 0)
    for r in rings:
        r.life -= dt
        r.r += 600.0 * dt
    rings = rings.filter(func(r): return r.life > 0)

func _alive_count() -> int:
    var n := 0
    for e in enemies:
        if e.alive: n += 1
    return n

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO,size), Color("#080a16"))
    for x in range(0, int(size.x), 48):
        draw_line(Vector2(x,70),Vector2(x,size.y),Color(0.12,0.20,0.34,0.28),1)
    for y in range(70, int(size.y), 48):
        draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.12,0.20,0.34,0.28),1)
    var col := Color(1.0,0.13,0.20) if red_lightning else Color(1.0,0.84,0.18)
    for b in bolts:
        var alpha: float = clampf(b.life / b.max,0.0,1.0)
        var a: Vector2 = b.a
        var z: Vector2 = b.b
        var c: Color = b.col
        var mid := (a+z)*0.5 + Vector2(randf_range(-18,18),randf_range(-18,18))
        draw_line(a,mid,Color(c.r,c.g,c.b,alpha),5.0)
        draw_line(mid,z,Color(1,1,1,alpha),3.0)
        draw_line(a,z,Color(c.r,c.g,c.b,alpha*0.35),10.0)
    for r in rings:
        draw_arc(r.pos,r.r,0,TAU,64,Color(r.col.r,r.col.g,r.col.b,clampf(r.life/r.max,0,1)),4.0,true)
    for e in enemies:
        if not e.alive: continue
        var ec := Color("#ff4f6e") if e.kind == 0 else (Color("#ff934f") if e.kind == 1 else Color("#bd72ff"))
        if e.flash > 0: ec = Color.WHITE
        draw_circle(e.pos,e.radius+6,Color(ec.r,ec.g,ec.b,0.10))
        draw_colored_polygon(PackedVector2Array([e.pos+Vector2(0,-e.radius),e.pos+Vector2(e.radius,0),e.pos+Vector2(0,e.radius),e.pos+Vector2(-e.radius,0)]),ec)
        draw_circle(e.pos,3.0,Color("#1a1025"))
    for p in particles:
        draw_circle(p.pos,p.size*clampf(p.life/p.max,0,1),Color(p.col.r,p.col.g,p.col.b,clampf(p.life/p.max,0,1)))
    if invuln <= 0 or int(time_alive*18)%2 == 0:
        draw_circle(player,29,Color(col.r,col.g,col.b,0.12))
        draw_circle(player,18,Color("#b9fbff"))
        draw_colored_polygon(PackedVector2Array([player+facing*30,player+facing.rotated(2.5)*13,player+facing.rotated(-2.5)*13]),Color.WHITE)
    draw_rect(Rect2(0,0,size.x,70),Color(0.025,0.035,0.09,0.95))
    draw_string(ThemeDB.fallback_font,Vector2(22,28),"LIGHTNING SURVIVOR",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#bafaff"))
    draw_string(ThemeDB.fallback_font,Vector2(22,52),"HP "+str(hp)+"   KILLS "+str(kills)+"   WAVE "+str(wave),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(size.x*0.56,34),"CRIMSON" if red_lightning else "GOLDEN LIGHTNING",HORIZONTAL_ALIGNMENT_CENTER,-1,18,col)
    var cd_text := "READY" if skill_cd <= 0 else str(snappedf(skill_cd,0.1))+"s"
    draw_string(ThemeDB.fallback_font,Vector2(size.x-24,28),"E / SPACE: EXECUTION",HORIZONTAL_ALIGNMENT_RIGHT,-1,14,Color("#f3f5ff"))
    draw_string(ThemeDB.fallback_font,Vector2(size.x-24,51),"SKILL "+cd_text,HORIZONTAL_ALIGNMENT_RIGHT,-1,14,col)
    if banner_time > 0:
        draw_string(ThemeDB.fallback_font,Vector2(size.x*0.5,102),banner,HORIZONTAL_ALIGNMENT_CENTER,-1,18,Color.WHITE)
    # Touch-friendly controls
    draw_circle(Vector2(100,size.y-105),52,Color(0.18,0.7,1,0.10))
    draw_arc(Vector2(100,size.y-105),52,0,TAU,48,Color(0.35,0.85,1,0.65),2.0,true)
    draw_string(ThemeDB.fallback_font,Vector2(63,size.y-100),"MOVE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#bafaff"))
    draw_circle(Vector2(size.x-112,size.y-116),67,Color(col.r,col.g,col.b,0.13))
    draw_arc(Vector2(size.x-112,size.y-116),67,0,TAU,48,col,3.0,true)
    draw_string(ThemeDB.fallback_font,Vector2(size.x-160,size.y-110),"LIGHTNING",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(size.x-155,size.y-88),"EXECUTE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,col)
    if game_over:
        draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,0.78))
        draw_string(ThemeDB.fallback_font,size*0.5+Vector2(0,-12),"RUN ENDED",HORIZONTAL_ALIGNMENT_CENTER,-1,40,Color("#ff536e"))
        draw_string(ThemeDB.fallback_font,size*0.5+Vector2(0,34),"KILLS "+str(kills)+"  //  PRESS R TO RESTART",HORIZONTAL_ALIGNMENT_CENTER,-1,18,Color.WHITE)
