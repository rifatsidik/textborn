extends Node2D

# ELEMENTAL OVERDRIVE — MVP prototype
# Real-time survivor combat + 2-4 skill combo queue.
# Desktop: WASD/arrows, click skill then slot, Enter executes, 1-3 reward choices.
# Touch: left side moves; tap skill buttons and combo slots on right.
const SKILL_NAMES := ["CHAIN", "EXECUTE", "NOVA", "STORM"]
const SKILL_COLORS := [Color("#ffd34d"), Color("#fff3a0"), Color("#ff9a35"), Color("#ff4c62")]
const SKILL_COOLDOWNS := [4.0, 7.0, 9.0, 12.0]
const SLOT_X := [720.0, 842.0, 964.0, 1086.0]
var view_size := Vector2(1280, 720)
var player := Vector2(640, 390)
var facing := Vector2.RIGHT
var hp := 100.0
var max_hp := 100.0
var kills := 0
var wave := 1
var xp := 0
var xp_needed := 8
var level := 1
var game_over := false
var reward_open := false
var red_evolved := false
var selected_skill := -1
var combo_queue: Array[int] = []
var cooldowns := [0.0, 0.0, 0.0, 0.0]
var enemies: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var attack_timer := 0.0
var combo_running := false
var combo_steps: Array[int] = []
var combo_step := 0
var combo_timer := 0.0
var move_touch := false
var touch_origin := Vector2.ZERO
var touch_pos := Vector2.ZERO
var banner := "ELEMENTAL OVERDRIVE  //  BUILD YOUR COMBO"
var banner_timer := 4.0
var reward_choices: Array[int] = []
var upgrades := {"damage": 0, "chain": 0, "targets": 0, "cooldown": 0}
var time_alive := 0.0
var shake := 0.0

func _ready() -> void:
    randomize()
    view_size = get_viewport_rect().size
    _spawn_wave()

func _spawn_wave() -> void:
    for i in range(7 + wave * 2):
        var side := randi() % 4
        var pos := Vector2.ZERO
        if side == 0: pos = Vector2(randf_range(30, view_size.x-30), 88)
        elif side == 1: pos = Vector2(view_size.x-28, randf_range(95, view_size.y-25))
        elif side == 2: pos = Vector2(randf_range(30, view_size.x-30), view_size.y-25)
        else: pos = Vector2(28, randf_range(95, view_size.y-25))
        enemies.append({"pos":pos,"vel":Vector2.ZERO,"hp":2 + int(wave > 3),"alive":true,"flash":0.0,"kind":randi()%3,"r":randf_range(12.0,17.0)})
    banner = "WAVE " + str(wave) + "  //  SURVIVE AND BUILD"
    banner_timer = 2.0

func _process(dt: float) -> void:
    view_size = get_viewport_rect().size
    if game_over:
        _tick_fx(dt)
        queue_redraw()
        return
    time_alive += dt
    banner_timer = maxf(0.0, banner_timer-dt)
    shake = maxf(0.0, shake-dt*18.0)
    attack_timer = maxf(0.0, attack_timer-dt)
    for i in range(cooldowns.size()):
        cooldowns[i] = maxf(0.0, float(cooldowns[i])-dt)

    var move := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1
    if move_touch:
        move = (touch_pos-touch_origin).limit_length(75.0)/75.0
    if move.length() > 1.0: move = move.normalized()
    if not combo_running and not reward_open:
        player += move * 245.0 * dt
    if move.length() > 0.1: facing = move.normalized()
    player.x = clampf(player.x, 24.0, view_size.x-24.0)
    player.y = clampf(player.y, 82.0, view_size.y-22.0)

    # Basic auto-attack always runs.
    if attack_timer <= 0.0 and not reward_open:
        _basic_attack()

    if combo_running:
        combo_timer -= dt
        if combo_timer <= 0.0:
            _execute_next()

    for e in enemies:
        if not e.alive: continue
        e.flash = maxf(0.0, e.flash-dt)
        var delta: Vector2 = player-e.pos
        var distance := delta.length()
        if distance > 1.0 and not reward_open:
            var speed := 66.0 if e.kind == 0 else (88.0 if e.kind == 1 else 75.0)
            e.vel = e.vel.lerp(delta.normalized()*speed, minf(1.0,dt*2.4))
            e.pos += e.vel*dt
        if distance < 26.0 and not combo_running:
            hp -= 22.0*dt
            if hp <= 0:
                hp = 0
                game_over = true
                banner = "RUN ENDED"

    _tick_fx(dt)
    if not reward_open and _alive_count() == 0:
        wave += 1
        _spawn_wave()
        if kills >= 20 and not red_evolved:
            red_evolved = true
            banner = "EVOLUTION UNLOCKED  //  CRIMSON LIGHTNING"
            banner_timer = 3.0
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_R and game_over:
            get_tree().reload_current_scene()
        if game_over or reward_open: 
            if reward_open:
                if event.keycode == KEY_1: _choose_reward(0)
                elif event.keycode == KEY_2: _choose_reward(1)
                elif event.keycode == KEY_3: _choose_reward(2)
            return
        if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
            _execute_combo()
        elif event.keycode == KEY_BACKSPACE:
            if not combo_queue.is_empty(): combo_queue.pop_back()
        elif event.keycode == KEY_1: _select_skill(0)
        elif event.keycode == KEY_2: _select_skill(1)
        elif event.keycode == KEY_3: _select_skill(2)
        elif event.keycode == KEY_4: _select_skill(3)
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < view_size.x*0.43:
                move_touch = true
                touch_origin = event.position
                touch_pos = event.position
            else:
                _handle_tap(event.position)
        else:
            move_touch = false
    elif event is InputEventScreenDrag and move_touch:
        touch_pos = event.position
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_tap(event.position)

func _handle_tap(pos: Vector2) -> void:
    if game_over:
        if pos.y > view_size.y*0.5: get_tree().reload_current_scene()
        return
    if reward_open:
        for i in range(3):
            var rect := Rect2(view_size.x*0.5-300+i*205, view_size.y*0.5-70, 190, 150)
            if rect.has_point(pos): _choose_reward(i); return
        return
    # Skill buttons along bottom-right.
    for i in range(4):
        var r := Rect2(520+i*112, view_size.y-104, 104, 72)
        if r.has_point(pos):
            _select_skill(i)
            return
    # Four combo slots.
    for i in range(4):
        var r := Rect2(SLOT_X[i]-48, 92, 96, 72)
        if r.has_point(pos):
            if selected_skill >= 0:
                _put_skill_in_slot(selected_skill, i)
            elif i < combo_queue.size():
                combo_queue.remove_at(i)
            return
    if Rect2(view_size.x-220, view_size.y-190, 195, 65).has_point(pos):
        _execute_combo()
    elif Rect2(view_size.x-220, view_size.y-112, 195, 44).has_point(pos):
        combo_queue.clear()
        selected_skill = -1

func _select_skill(idx: int) -> void:
    if idx < 0 or idx >= 4 or combo_running: return
    if cooldowns[idx] > 0:
        banner = SKILL_NAMES[idx] + " ON COOLDOWN"
        banner_timer = 1.0
        return
    selected_skill = idx
    banner = "SELECTED " + SKILL_NAMES[idx] + "  //  TAP A SLOT"
    banner_timer = 1.0

func _put_skill_in_slot(skill: int, slot: int) -> void:
    if combo_running or cooldowns[skill] > 0: return
    var existing := combo_queue.find(skill)
    if existing >= 0: combo_queue.remove_at(existing)
    slot = mini(slot, combo_queue.size())
    if combo_queue.size() < 4:
        combo_queue.insert(slot, skill)
    selected_skill = -1
    if combo_queue.size() >= 2:
        banner = "COMBO READY  //  EXECUTE WHEN YOU CHOOSE"
    else:
        banner = "SKILL QUEUED"
    banner_timer = 1.1

func _execute_combo() -> void:
    if combo_running or combo_queue.size() < 2: 
        banner = "QUEUE AT LEAST 2 READY SKILLS"
        banner_timer = 1.2
        return
    for skill in combo_queue:
        if cooldowns[skill] > 0:
            banner = "ONE OR MORE SKILLS ON COOLDOWN"
            banner_timer = 1.2
            return
    combo_steps = combo_queue.duplicate()
    combo_step = 0
    combo_running = true
    banner = "COMBO EXECUTION!"
    banner_timer = 1.0
    _execute_next()

func _execute_next() -> void:
    if combo_step >= combo_steps.size():
        combo_running = false
        combo_queue.clear()
        combo_steps.clear()
        banner = "COMBO COMPLETE"
        banner_timer = 1.0
        return
    var skill: int = combo_steps[combo_step]
    cooldowns[skill] = maxf(1.0, SKILL_COOLDOWNS[skill] - float(upgrades["cooldown"])*0.7)
    if skill == 0: _cast_chain()
    elif skill == 1: _cast_execution()
    elif skill == 2: _cast_nova()
    elif skill == 3: _cast_storm()
    combo_step += 1
    combo_timer = 0.55 if skill == 1 else 0.36

func _basic_attack() -> void:
    attack_timer = maxf(0.22, 0.65 - float(upgrades["damage"])*0.025)
    var idx := _nearest_enemy(player, 320.0)
    if idx == -1: return
    var target: Vector2 = enemies[idx].pos
    var col := Color("#ff4b60") if red_evolved else Color("#ffd34d")
    bolts.append({"a":player,"b":target,"life":0.13,"max":0.13,"col":col})
    enemies[idx].hp -= 1 + int(upgrades["damage"] > 0)
    if enemies[idx].hp <= 0: _kill_enemy(idx)

func _cast_chain() -> void:
    var current := player
    var hit: Array[int] = []
    var count := 3 + int(upgrades["targets"])
    for n in range(count):
        var idx := _nearest_enemy(current, 420.0, hit)
        if idx == -1: break
        hit.append(idx)
        var target: Vector2 = enemies[idx].pos
        var col := Color("#ff354c") if red_evolved else Color("#ffd34d")
        bolts.append({"a":current,"b":target,"life":0.22,"max":0.22,"col":col})
        _burst(target,col,12,190.0)
        enemies[idx].hp -= 2 + int(upgrades["damage"])
        if enemies[idx].hp <= 0: _kill_enemy(idx)
        current = target
    shake = 3.0

func _cast_execution() -> void:
    var count := 5 + int(upgrades["targets"])*2
    var current := player
    var used: Array[int] = []
    for n in range(count):
        var idx := _nearest_enemy(current, 520.0, used)
        if idx == -1: break
        used.append(idx)
        var target: Vector2 = enemies[idx].pos
        var col := Color("#ff334d") if red_evolved else Color("#ffdf55")
        bolts.append({"a":current,"b":target,"life":0.19,"max":0.19,"col":col})
        _burst(current,col,7,140.0)
        _burst(target,col,15,230.0)
        player = target + (current-target).normalized()*18.0
        enemies[idx].hp -= 99
        _kill_enemy(idx)
        current = target
    shake = 6.0

func _cast_nova() -> void:
    var col := Color("#ff334d") if red_evolved else Color("#ff9d35")
    effects.append({"pos":player,"r":15.0,"life":0.42,"max":0.42,"col":col})
    for i in range(enemies.size()):
        if enemies[i].alive and enemies[i].pos.distance_to(player) < 190.0:
            enemies[i].hp -= 3 + int(upgrades["damage"])
            enemies[i].vel += (enemies[i].pos-player).normalized()*250.0
            if enemies[i].hp <= 0: _kill_enemy(i)
    _burst(player,col,38,260.0)
    shake = 5.0

func _cast_storm() -> void:
    var col := Color("#ff334d") if red_evolved else Color("#fff3a0")
    for i in range(enemies.size()):
        if enemies[i].alive and enemies[i].pos.distance_to(player) < 280.0:
            bolts.append({"a":player,"b":enemies[i].pos,"life":0.16,"max":0.16,"col":col})
            enemies[i].hp -= 2 + int(upgrades["damage"])
            if enemies[i].hp <= 0: _kill_enemy(i)
    _burst(player,col,30,230.0)
    shake = 4.0

func _nearest_enemy(from: Vector2, radius: float, excluded: Array = []) -> int:
    var best := -1
    var best_distance := radius
    for i in range(enemies.size()):
        if not enemies[i].alive or excluded.has(i): continue
        var d: float = from.distance_to(enemies[i].pos)
        if d < best_distance:
            best_distance = d
            best = i
    return best

func _kill_enemy(idx: int) -> void:
    if not enemies[idx].alive: return
    enemies[idx].alive = false
    kills += 1
    xp += 1
    _burst(enemies[idx].pos, Color("#ffd34d") if not red_evolved else Color("#ff354c"), 10, 140.0)
    if xp >= xp_needed:
        xp -= xp_needed
        level += 1
        xp_needed = int(8 + level*2)
        _open_reward()

func _open_reward() -> void:
    reward_open = true
    reward_choices = [randi()%4, randi()%4, randi()%4]
    banner = "LEVEL UP  //  CHOOSE ONE UPGRADE"
    banner_timer = 2.0

func _choose_reward(index: int) -> void:
    if not reward_open or index < 0 or index >= 3: return
    var reward: int = reward_choices[index]
    if reward == 0: upgrades["damage"] += 1
    elif reward == 1: upgrades["chain"] += 1
    elif reward == 2: upgrades["targets"] += 1
    else: upgrades["cooldown"] += 1
    reward_open = false
    banner = ["SPARK POWER UP","CHAIN VOLTAGE UP","MORE EXECUTION TARGETS","COOLDOWN REDUCED"][reward]
    banner_timer = 1.8
    if kills >= 20 and not red_evolved:
        red_evolved = true
        banner = "CRIMSON LIGHTNING EVOLVED!"
        banner_timer = 2.8

func _burst(pos: Vector2, col: Color, count: int, force: float) -> void:
    for i in range(count):
        var a := randf()*TAU
        particles.append({"pos":pos,"vel":Vector2.RIGHT.rotated(a)*randf_range(force*0.2,force),"life":randf_range(0.15,0.48),"max":0.48,"col":col,"size":randf_range(1.5,4.5)})

func _tick_fx(dt: float) -> void:
    for p in particles:
        p.life -= dt
        p.pos += p.vel*dt
        p.vel *= pow(0.08,dt)
    particles = particles.filter(func(p): return p.life > 0)
    for b in bolts: b.life -= dt
    bolts = bolts.filter(func(b): return b.life > 0)
    for e in effects:
        e.life -= dt
        e.r += 520.0*dt
    effects = effects.filter(func(e): return e.life > 0)

func _alive_count() -> int:
    var count := 0
    for e in enemies:
        if e.alive: count += 1
    return count

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO,size),Color("#080b18"))
    for x in range(0,int(size.x),48):
        draw_line(Vector2(x,70),Vector2(x,size.y),Color(0.12,0.19,0.32,0.28),1.0)
    for y in range(70,int(size.y),48):
        draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.12,0.19,0.32,0.28),1.0)
    for b in bolts:
        var alpha: float = clampf(b.life/b.max,0.0,1.0)
        var a: Vector2 = b.a
        var z: Vector2 = b.b
        var c: Color = b.col
        var mid := (a+z)*0.5+Vector2(randf_range(-12,12),randf_range(-12,12))
        draw_line(a,z,Color(c.r,c.g,c.b,alpha*0.32),9.0)
        draw_line(a,mid,Color(c.r,c.g,c.b,alpha),4.0)
        draw_line(mid,z,Color(1,1,1,alpha),2.0)
    for e in effects:
        draw_arc(e.pos,e.r,0,TAU,56,Color(e.col.r,e.col.g,e.col.b,clampf(e.life/e.max,0,1)),4.0,true)
    for e in enemies:
        if not e.alive: continue
        var col := Color("#ff4e6d") if e.kind == 0 else (Color("#ff994b") if e.kind == 1 else Color("#b977ff"))
        if e.flash > 0: col = Color.WHITE
        draw_circle(e.pos,e.r+5,Color(col.r,col.g,col.b,0.12))
        draw_colored_polygon(PackedVector2Array([e.pos+Vector2(0,-e.r),e.pos+Vector2(e.r,0),e.pos+Vector2(0,e.r),e.pos+Vector2(-e.r,0)]),col)
        draw_circle(e.pos,3.0,Color("#191323"))
    for p in particles:
        draw_circle(p.pos,p.size*clampf(p.life/p.max,0,1),Color(p.col.r,p.col.g,p.col.b,clampf(p.life/p.max,0,1)))
    var player_col := Color("#ff3c52") if red_evolved else Color("#ffe98a")
    draw_circle(player,31,Color(player_col.r,player_col.g,player_col.b,0.12))
    draw_circle(player,18,Color("#bafaff"))
    draw_colored_polygon(PackedVector2Array([player+facing*30,player+facing.rotated(2.5)*13,player+facing.rotated(-2.5)*13]),Color.WHITE)

    # Top HUD
    draw_rect(Rect2(0,0,size.x,70),Color(0.02,0.03,0.08,0.96))
    draw_string(ThemeDB.fallback_font,Vector2(20,27),"ELEMENTAL OVERDRIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#bafaff"))
    draw_string(ThemeDB.fallback_font,Vector2(20,51),"HP "+str(int(hp))+"   KILLS "+str(kills)+"   WAVE "+str(wave)+"   LV "+str(level),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(size.x-20,27),"CRIMSON LIGHTNING" if red_evolved else "GOLDEN LIGHTNING",HORIZONTAL_ALIGNMENT_RIGHT,-1,17,player_col)
    draw_string(ThemeDB.fallback_font,Vector2(size.x-20,51),"XP "+str(xp)+"/"+str(xp_needed),HORIZONTAL_ALIGNMENT_RIGHT,-1,14,Color("#a8bad9"))

    # Combo slots
    draw_string(ThemeDB.fallback_font,Vector2(720,84),"COMBO QUEUE  (1-4 TO SELECT SKILL, ENTER TO EXECUTE)",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#b9c9e8"))
    for i in range(4):
        var rect := Rect2(SLOT_X[i]-48,92,96,72)
        draw_rect(rect,Color("#273149") if i < combo_queue.size() else Color("#111a2c"),true)
        draw_rect(rect,Color("#ffd34d") if i < combo_queue.size() else Color("#3b4964"),false,2.0)
        if i < combo_queue.size():
            var skill: int = combo_queue[i]
            draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+48,121),SKILL_NAMES[skill],HORIZONTAL_ALIGNMENT_CENTER,-1,12,SKILL_COLORS[skill])
            draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+48,145),str(i+1),HORIZONTAL_ALIGNMENT_CENTER,-1,15,Color.WHITE)
        else:
            draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+48,134),"+",HORIZONTAL_ALIGNMENT_CENTER,-1,24,Color("#8796b7"))

    # Skill buttons
    draw_string(ThemeDB.fallback_font,Vector2(520,size.y-119),"TAP SKILL, THEN TAP SLOT",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#b9c9e8"))
    for i in range(4):
        var rect := Rect2(520+i*112,size.y-104,104,72)
        var ready: bool = cooldowns[i] <= 0.0
        draw_rect(rect,Color("#303044") if selected_skill == i else Color("#18253b"),true)
        draw_rect(rect,SKILL_COLORS[i] if ready else Color("#4a5367"),false,2.0)
        draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+52,rect.position.y+27),SKILL_NAMES[i],HORIZONTAL_ALIGNMENT_CENTER,-1,12,SKILL_COLORS[i] if ready else Color("#8790a5"))
        var cd_text := "READY" if ready else str(snappedf(cooldowns[i],0.1))+"s"
        draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+52,rect.position.y+51),cd_text,HORIZONTAL_ALIGNMENT_CENTER,-1,13,Color.WHITE)
    draw_rect(Rect2(size.x-220,size.y-190,195,65),Color("#8d6719") if combo_queue.size() >= 2 else Color("#34384a"),true)
    draw_string(ThemeDB.fallback_font,Vector2(size.x-122,size.y-151),"EXECUTE",HORIZONTAL_ALIGNMENT_CENTER,-1,20,Color.WHITE)
    draw_rect(Rect2(size.x-220,size.y-112,195,44),Color("#202b42"),true)
    draw_string(ThemeDB.fallback_font,Vector2(size.x-122,size.y-84),"CLEAR QUEUE",HORIZONTAL_ALIGNMENT_CENTER,-1,14,Color("#b9c9e8"))

    if banner_timer > 0:
        draw_string(ThemeDB.fallback_font,Vector2(size.x*0.5,190),banner,HORIZONTAL_ALIGNMENT_CENTER,-1,18,Color.WHITE)
    # Touch movement guide
    draw_circle(Vector2(95,size.y-110),49,Color(0.12,0.7,1,0.08))
    draw_arc(Vector2(95,size.y-110),49,0,TAU,40,Color(0.35,0.85,1,0.55),2.0,true)
    draw_string(ThemeDB.fallback_font,Vector2(62,size.y-105),"MOVE",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#bafaff"))

    if reward_open:
        draw_rect(Rect2(Vector2.ZERO,size),Color(0.01,0.02,0.06,0.68))
        draw_string(ThemeDB.fallback_font,Vector2(size.x*0.5,size.y*0.5-110),"LEVEL UP  //  CHOOSE ONE",HORIZONTAL_ALIGNMENT_CENTER,-1,27,Color("#ffe27a"))
        var labels := ["SPARK POWER","CHAIN VOLTAGE","EXECUTION TARGETS","COOLDOWN REDUCTION"]
        for i in range(3):
            var rect := Rect2(size.x*0.5-300+i*205,size.y*0.5-70,190,150)
            draw_rect(rect,Color("#1d2940"),true)
            draw_rect(rect,Color("#ffd34d"),false,2.0)
            draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+95,rect.position.y+55),labels[reward_choices[i]],HORIZONTAL_ALIGNMENT_CENTER,-1,14,Color.WHITE)
            draw_string(ThemeDB.fallback_font,Vector2(rect.position.x+95,rect.position.y+112),"TAP / "+str(i+1),HORIZONTAL_ALIGNMENT_CENTER,-1,14,Color("#ffe27a"))
    if game_over:
        draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,0.78))
        draw_string(ThemeDB.fallback_font,Vector2(size.x*0.5,size.y*0.5-15),"RUN ENDED",HORIZONTAL_ALIGNMENT_CENTER,-1,40,Color("#ff536e"))
        draw_string(ThemeDB.fallback_font,Vector2(size.x*0.5,size.y*0.5+32),"KILLS "+str(kills)+"  //  PRESS R OR TAP TO RESTART",HORIZONTAL_ALIGNMENT_CENTER,-1,18,Color.WHITE)
