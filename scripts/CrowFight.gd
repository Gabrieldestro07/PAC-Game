extends Node2D

signal finished(won: bool)

const PlayerActionsScript = preload("res://scripts/PlayerActions.gd")
enum Phase { DESCENT, WAITING, WINDUP, ATTACKING, RECOVERY, DEFEATED }
enum Attack { WIND, FEATHERS, BONES }
const PLAYER_MAX_HP = 10
const CROW_MAX_HP = 20
const CROW_NAME = "Corvo da Maldição"
const ARENA_LEFT = 96.0
const ARENA_RIGHT = 1015.0
const LANDING_X = 230.0
const CROW_SCALE = 0.66
const ATTACK_DAMAGE = {Attack.WIND: 1, Attack.FEATHERS: 2, Attack.BONES: 3}
const WINDUP_SECONDS = {Attack.WIND: 0.8, Attack.FEATHERS: 1.25, Attack.BONES: 1.15}
const FIRST_ATTACK_PAUSE = 1.15
const RECOVERY_SECONDS = 2.1
const GUST_SPEED = 470.0
const GUST_RADIUS = 31.0
const FEATHER_COUNT = 3
const FEATHER_WAVES = 3
const FEATHER_FALL_SECONDS = 0.58
const FEATHER_SKY_Y = 94.0
const FEATHER_RADIUS = 19.0
const BONE_RADIUS = 52.0
const CROW_BODY = Rect2(-31, -86, 85, 74)
const CROW_HEAD = Rect2(-57, -111, 61, 56)

var active = false
var phase: Phase
var actions: PlayerActionsScript
var crow: AnimatedSprite2D
var feet_y: float
var perch_start: Vector2
var crow_feet: Vector2
var player_hp: int
var crow_hp: int
var phase_time: float
var attack: Attack
var attack_index: int
var attack_target: float
var attack_hit: bool
var feather_wave: int
var feather_positions: Array[float] = []
var crow_direction = -1.0
var invulnerability: float
var registered_strike = -1
var health_frame: StyleBoxFlat
var boss_fill: StyleBoxFlat
var player_fill: StyleBoxFlat

func _ready():
	health_frame = health_style(Color("271d30"), 8)
	health_frame.border_color = Color("bda07d")
	health_frame.set_border_width_all(2)
	boss_fill = health_style(Color("c44e68"), 5)
	player_fill = health_style(Color("5fae9a"), 5)

func begin(player_actions: PlayerActionsScript, boss_art: AnimatedSprite2D, floor_y: float):
	actions = player_actions
	crow = boss_art
	feet_y = floor_y
	player_hp = PLAYER_MAX_HP
	crow_hp = CROW_MAX_HP
	invulnerability = 0.0
	registered_strike = -1
	attack_index = 0
	actions.reset_motion(feet_y)
	actions.direction = -1.0
	actions.play_movement()
	actions.art.modulate = Color.WHITE
	crow.stop()
	crow.frame = 0
	perch_start = crow.position
	crow_feet = Vector2(LANDING_X, feet_y)
	crow_direction = 1.0
	phase = Phase.DESCENT
	phase_time = 0.0
	active = true
	queue_redraw()

func accepts_controls() -> bool:
	return active and phase != Phase.DESCENT and phase != Phase.DEFEATED

func receive_rod_hit(base: Vector2, tip: Vector2, strike_id: int):
	if not accepts_controls() or registered_strike == strike_id: return
	if not touches_crow(base, tip): return
	registered_strike = strike_id
	crow_hp = maxi(0, crow_hp - PlayerActionsScript.ROD_DAMAGE)
	crow.modulate = Color("ffb39a")
	if crow_hp == 0:
		phase = Phase.DEFEATED
		phase_time = 0.0

func touches_crow(base: Vector2, tip: Vector2) -> bool:
	var visible_feet = Vector2(crow_feet.x, crow.position.y + 179.0 * CROW_SCALE)
	for part in [CROW_BODY, CROW_HEAD]:
		var bounds: Rect2 = part
		if crow.flip_h:
			bounds.position.x = -bounds.end.x
		bounds.position += visible_feet
		bounds = bounds.grow(3.0)
		if base.y >= bounds.position.y and base.y <= bounds.end.y and maxf(base.x, tip.x) >= bounds.position.x and minf(base.x, tip.x) <= bounds.end.x:
			return true
	return false

func advance(delta: float):
	phase_time += delta
	actions.step(delta, Vector2(ARENA_LEFT, ARENA_RIGHT), arena_floor_at, accepts_controls())
	if phase == Phase.DESCENT:
		var descent = smoothstep(0.0, 1.15, phase_time)
		crow.scale = Vector2.ONE * lerpf(1.0, CROW_SCALE, descent)
		crow.frame = 5 if phase_time < 1.0 else 0
		crow.position = perch_start.lerp(crow_feet - Vector2(104, 179) * CROW_SCALE, descent)
		crow.position.y -= sin(descent * PI) * 42.0
		if phase_time >= 1.15:
			phase = Phase.WAITING
			phase_time = 0.0
	elif phase == Phase.DEFEATED:
		crow.modulate.a = 1.0 - clampf(phase_time / 0.8, 0.0, 1.0)
		if phase_time >= 0.8:
			end_fight(true)
	else:
		invulnerability = maxf(0.0, invulnerability - delta)
		actions.art.modulate.a = 0.45 if invulnerability > 0.0 and int(invulnerability * 14) % 2 == 0 else 1.0
		actions.play_movement()
		update_crow(delta)
	queue_redraw()

func arena_floor_at(_x: float) -> float:
	return feet_y

func update_crow(delta: float):
	match phase:
		Phase.WAITING, Phase.RECOVERY:
			crow.frame = 0
			crow_direction = 1.0 if actions.actor.position.x >= crow_feet.x else -1.0
			if phase_time >= (FIRST_ATTACK_PAUSE if phase == Phase.WAITING else RECOVERY_SECONDS):
				begin_windup()
		Phase.WINDUP:
			crow.frame = 0
			if attack == Attack.BONES or attack == Attack.WIND:
				crow.frame = 3
			elif attack == Attack.FEATHERS and phase_time < 0.28:
				crow.frame = 5
			if phase_time >= WINDUP_SECONDS[attack]:
				phase = Phase.ATTACKING
				phase_time = 0.0
		Phase.ATTACKING:
			crow.frame = 5
			advance_attack(delta)
			if not active: return
	crow.flip_h = crow_direction > 0.0
	crow.position = crow_feet - Vector2(152.0 if crow.flip_h else 104.0, 179.0) * CROW_SCALE
	if phase == Phase.WINDUP and attack == Attack.BONES:
		crow.position.y -= 15.0 * smoothstep(0.58, 1.0, phase_time)
	crow.modulate = crow.modulate.lerp(Color.WHITE, minf(delta * 6.0, 1.0))

func begin_windup():
	attack = [Attack.WIND, Attack.FEATHERS, Attack.BONES][attack_index]
	attack_index = (attack_index + 1) % 3
	attack_hit = false
	match attack:
		Attack.FEATHERS:
			feather_wave = 1
			pick_feather_positions()
		Attack.BONES:
			attack_target = actions.actor.position.x
	phase = Phase.WINDUP
	phase_time = 0.0

func pick_feather_positions():
	feather_positions.clear()
	var candidates: Array[float] = []
	var gap = FEATHER_RADIUS * 2.0 + 22.0
	var offset = randf_range(0.0, gap)
	var point = ARENA_LEFT + FEATHER_RADIUS + offset
	while point <= ARENA_RIGHT - FEATHER_RADIUS:
		candidates.append(point)
		point += gap
	candidates.shuffle()
	for index in range(FEATHER_COUNT):
		feather_positions.append(candidates[index])

func advance_attack(delta: float):
	var player_x = actions.actor.position.x
	match attack:
		Attack.WIND:
			var now = gust_x(phase_time)
			var previous = gust_x(phase_time - delta)
			if player_x >= minf(previous, now) - GUST_RADIUS and player_x <= maxf(previous, now) + GUST_RADIUS:
				damage_player(67.0)
			if active and (now < ARENA_LEFT - 50.0 or now > ARENA_RIGHT + 50.0):
				recover()
		Attack.FEATHERS:
			var now = feather_tip_y(phase_time)
			var previous = feather_tip_y(phase_time - delta)
			var player_feet = actions.actor.position.y + actions.feet_offset
			if previous - 28.0 <= player_feet and now >= player_feet - 73.0:
				for point in feather_positions:
					if absf(player_x - point) <= FEATHER_RADIUS:
						damage_player(INF)
						break
			if not active or phase_time < FEATHER_FALL_SECONDS: return
			if feather_wave >= FEATHER_WAVES:
				recover()
			else:
				feather_wave += 1
				attack_hit = false
				pick_feather_positions()
				phase = Phase.WINDUP
				phase_time = 0.0
		Attack.BONES:
			if phase_time >= 0.10 and phase_time <= 0.36 and absf(player_x - attack_target) <= BONE_RADIUS:
				damage_player(63.0)
			if active and phase_time >= 0.57:
				recover()

func gust_x(time: float) -> float:
	return crow_feet.x + crow_direction * (42.0 + GUST_SPEED * maxf(0.0, time))

func feather_tip_y(time: float) -> float:
	var fall = clampf(time / FEATHER_FALL_SECONDS, 0.0, 1.0)
	return lerpf(FEATHER_SKY_Y, feet_y + 3.0, fall * (0.65 + 0.35 * fall))

func damage_player(jump_clearance: float):
	var feet_above_floor = feet_y - (actions.actor.position.y + actions.feet_offset)
	if attack_hit or invulnerability > 0.0 or actions.dash_remaining > 0.0 or feet_above_floor >= jump_clearance: return
	attack_hit = true
	player_hp = maxi(0, player_hp - ATTACK_DAMAGE[attack])
	invulnerability = 0.8
	if player_hp == 0: end_fight(false)

func recover():
	phase = Phase.RECOVERY
	phase_time = 0.0

func end_fight(won: bool):
	active = false
	actions.cancel_strike()
	actions.art.modulate = Color.WHITE
	queue_redraw()
	finished.emit(won)

func _draw():
	if not active: return
	var viewport = get_viewport_rect().size
	var boss_bar = Rect2((viewport.x - 470.0) * 0.5, 57, 470, 24)
	var player_bar = Rect2(29, viewport.y - 46, 222, 22)
	draw_health(boss_bar, crow_hp, CROW_MAX_HP, boss_fill, CROW_NAME, 25)
	draw_health(player_bar, player_hp, PLAYER_MAX_HP, player_fill, "Vida do pescador", 16)
	if phase == Phase.WINDUP or phase == Phase.ATTACKING:
		draw_attack()

func draw_attack():
	match attack:
		Attack.WIND:
			if phase == Phase.WINDUP:
				draw_wind_warning()
				return
			var center = Vector2(gust_x(phase_time), feet_y - 38.0)
			for stream in range(3):
				var line_center = center + Vector2(-10.0 * stream * crow_direction, (stream - 1) * 12.0)
				var start = line_center - Vector2(32.0 * crow_direction, 0)
				var end = line_center + Vector2(27.0 * crow_direction, -5.0)
				draw_polyline(PackedVector2Array([start, line_center + Vector2(-15.0 * crow_direction, 3), end]), Color(0.74, 0.93, 0.95, 0.74 - 0.15 * stream), 2.5, true)
		Attack.FEATHERS:
			if phase == Phase.WINDUP and phase_time < 0.28:
				var rise = smoothstep(0.0, 0.28, phase_time)
				for index in range(FEATHER_COUNT):
					var lift = Vector2((index - 1) * 31.0, -125.0) * rise
					draw_feather(crow_feet + Vector2(0, -67.0) + lift, 1.0 - rise)
			for point in feather_positions:
				if phase == Phase.WINDUP:
					draw_feather_warning(point)
				else:
					draw_feather(Vector2(point, feather_tip_y(phase_time)))
		Attack.BONES:
			draw_crack()
			if phase == Phase.ATTACKING:
				draw_bones()

func draw_feather_warning(point: float):
	var pulse = phase_time / WINDUP_SECONDS[Attack.FEATHERS]
	var opacity = 0.42 + 0.22 * sin(pulse * PI)
	draw_rect(Rect2(point - FEATHER_RADIUS - 4, feet_y - 7.0, (FEATHER_RADIUS + 4) * 2.0, 13), Color(0.91, 0.11, 0.17, 0.24))
	for row in range(3):
		var width = (FEATHER_RADIUS - 4.0 * row) * 2.0
		draw_rect(Rect2(point - width * 0.5, feet_y + 4.0 - row * 3.0, width, 3.0), Color(1.0, 0.34, 0.37, opacity))

func draw_wind_warning():
	var start = Vector2(gust_x(0.0), feet_y - 38.0)
	var end_x = ARENA_RIGHT if crow_direction > 0.0 else ARENA_LEFT
	var arrow_color = Color(0.65, 0.92, 1.0, 0.55 + 0.3 * smoothstep(0.0, WINDUP_SECONDS[Attack.WIND], phase_time))
	for index in range(1, 5):
		var x = lerpf(start.x, end_x, index * 0.17)
		if x < ARENA_LEFT or x > ARENA_RIGHT: continue
		var tip = Vector2(x, start.y)
		var tail = tip - Vector2(crow_direction * 13.0, 0.0)
		draw_polyline(PackedVector2Array([tail - Vector2(0, 7), tip, tail + Vector2(0, 7)]), arrow_color, 3.0, true)

func draw_feather(tip: Vector2, opacity := 1.0):
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-8, -12), tip + Vector2(3, -31), tip + Vector2(9, -24), tip + Vector2(7, -10)]), Color(Color("4e3765"), opacity))
	draw_line(tip, tip + Vector2(4, -26), Color(Color("c7afd9"), opacity), 1.5, true)

func draw_crack():
	var center = Vector2(attack_target, feet_y + 2.0)
	var ink = Color(0.18, 0.10, 0.15, 0.84)
	var crack = PackedVector2Array([center + Vector2(-47, -2), center + Vector2(-22, -7), center + Vector2(-11, 2), center + Vector2(7, -4), center + Vector2(16, 3), center + Vector2(46, -5)])
	if phase == Phase.WINDUP:
		var opacity = 0.35 + 0.40 * smoothstep(0.0, WINDUP_SECONDS[Attack.BONES], phase_time)
		draw_rect(Rect2(attack_target - BONE_RADIUS, feet_y - 8.0, BONE_RADIUS * 2.0, 18.0), Color(0.96, 0.58, 0.27, 0.22))
		draw_polyline(crack, Color(1.0, 0.69, 0.40, opacity), 8.0, true)
	draw_polyline(crack, ink, 3.0, true)
	draw_polyline(PackedVector2Array([center + Vector2(-11, 2), center + Vector2(-21, 7), center + Vector2(-17, 10)]), ink, 2.0, true)
	draw_polyline(PackedVector2Array([center + Vector2(16, 3), center + Vector2(24, 8), center + Vector2(33, 7)]), ink, 2.0, true)

func draw_bones():
	var raised = smoothstep(0.0, 0.17, phase_time) * (1.0 - smoothstep(0.34, 0.57, phase_time))
	if raised <= 0.0: return
	for bone in range(3):
		var offset = (bone - 1) * 25.0
		var base = Vector2(attack_target + offset, feet_y)
		var tip = base + Vector2(offset * 0.28, -(62.0 - absf(offset) * 0.82) * raised)
		draw_line(base, tip, Color("75607c"), 12.0, true)
		draw_line(base, tip, Color("e7d8b3"), 8.0, true)
		draw_circle(tip + Vector2(-3, 0), 5.0, Color("eee4c9"), true)
		draw_circle(tip + Vector2(3, -1), 5.0, Color("eee4c9"), true)

func health_style(tint: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(radius)
	return style

func draw_health(bounds: Rect2, hp: int, max_hp: int, fill_style: StyleBoxFlat, title: String, font_size: int):
	draw_style_box(health_frame, bounds)
	var fill = bounds.grow(-4.0)
	fill.size.x *= float(hp) / max_hp
	if hp > 0:
		draw_style_box(fill_style, fill)
	var font = ThemeDB.fallback_font
	var text_position = bounds.position - Vector2(0, 12)
	draw_string_outline(font, text_position, title, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, font_size, 5, Color("201628"))
	draw_string(font, text_position, title, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, font_size, Color("ffead0"))
	var value = "%d / %d" % [hp, max_hp]
	var value_position = bounds.position + Vector2(0, bounds.size.y * 0.5 + 5.0)
	draw_string_outline(font, value_position, value, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 14, 3, Color("271d30"))
	draw_string(font, value_position, value, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, 14, Color("fff3db"))
