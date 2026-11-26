extends Node2D

signal rod_hit(base: Vector2, tip: Vector2, strike_id: int)
signal dashed

const WALK_SPEED = 245.0
const JUMP_SPEED = 590.0
const GRAVITY = 1550.0
const DASH_SPEED = 665.0
const DASH_DURATION = 0.17
const DASH_COOLDOWN = 0.55
const STRIKE_DURATION = 0.50
const STRIKE_HIT_TIME = 0.18
const ROD_REACH = 152.0
const ROD_DAMAGE = 1
const LINE_HEIGHT = 46.0
const ROD_TIP_DISTANCE = 64.0

var actor: Node2D
var art: AnimatedSprite2D
var feet_offset: float
var direction = 1.0
var movement = 0.0
var grounded = true
var jump_velocity = 0.0
var dash_remaining = 0.0
var dash_cooldown = 0.0
var dash_direction = 1.0
var strike_remaining = 0.0
var strike_direction = 1.0
var strike_id = 0

func setup(character: Node2D, character_art: AnimatedSprite2D, offset: float):
	actor = character
	art = character_art
	feet_offset = offset
	var atlas = preload("res://fisherman/action_frames.png")
	var frames: Array[AtlasTexture] = []
	var size = Vector2(128, 96)
	for index in range(6):
		var frame = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(Vector2(index % 3, floorf(index / 3.0)) * size, size)
		frame.filter_clip = true
		frames.append(frame)
	var animations = art.sprite_frames
	for side_name in ["right", "left"]:
		var rise = "motion_rise_" + side_name
		var fall = "motion_fall_" + side_name
		var dash_pose = "motion_dash_" + side_name
		var thrust = "rod_strike_" + side_name
		for name in [rise, fall, dash_pose, thrust]:
			animations.add_animation(name)
			animations.set_animation_loop(name, false)
		animations.add_frame(rise, frames[0])
		animations.add_frame(fall, frames[1])
		animations.set_animation_speed(dash_pose, 13.0)
		animations.add_frame(dash_pose, frames[2])
		animations.add_frame(dash_pose, frames[3])
		animations.set_animation_speed(thrust, 10.0)
		animations.add_frame(thrust, frames[4])
		animations.add_frame(thrust, frames[5], 3.0)
		animations.add_frame(thrust, frames[4])

func reset_motion(floor_y: float):
	actor.position.y = floor_y - feet_offset
	grounded = true
	jump_velocity = 0.0
	movement = 0.0
	dash_remaining = 0.0
	dash_cooldown = 0.0
	cancel_strike()

func cancel_strike():
	strike_remaining = 0.0
	queue_redraw()

func side() -> String:
	return "right" if direction > 0.0 else "left"

func jump():
	if not grounded: return
	grounded = false
	jump_velocity = -JUMP_SPEED

func dash():
	if dash_cooldown > 0.0: return
	var input_direction = read_direction()
	dash_direction = direction if input_direction == 0.0 else input_direction
	direction = dash_direction
	dash_remaining = DASH_DURATION
	dash_cooldown = DASH_COOLDOWN
	dashed.emit()
	queue_redraw()

func strike():
	if strike_remaining > 0.0: return
	strike_direction = direction
	strike_id += 1
	strike_remaining = STRIKE_DURATION
	art.play("rod_strike_" + side())
	art.set_frame_and_progress(0, 0.0)
	queue_redraw()

func read_direction() -> float:
	return float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))

func step(delta: float, bounds: Vector2, floor_at: Callable, controls_enabled: bool):
	movement = read_direction() if controls_enabled else 0.0
	var was_dashing = dash_remaining > 0.0
	var dash_step = minf(delta, dash_remaining) if controls_enabled else 0.0
	var horizontal = dash_direction * DASH_SPEED * dash_step + movement * WALK_SPEED * (delta - dash_step)
	if dash_step == 0.0 and movement != 0.0:
		direction = movement
	dash_remaining = maxf(0.0, dash_remaining - delta) if controls_enabled else 0.0
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	actor.position.x = clampf(actor.position.x + horizontal, bounds.x, bounds.y)
	var floor_y: float = floor_at.call(actor.position.x)
	var feet_y = actor.position.y + feet_offset
	if not grounded:
		jump_velocity += GRAVITY * delta
		feet_y += jump_velocity * delta
		grounded = feet_y >= floor_y
	if grounded:
		feet_y = floor_y
		jump_velocity = 0.0
	actor.position.y = feet_y - feet_offset
	if was_dashing:
		queue_redraw()

	if strike_remaining > 0.0:
		if not controls_enabled:
			cancel_strike()
			return
		strike_remaining = maxf(0.0, strike_remaining - delta)
		var elapsed = STRIKE_DURATION - strike_remaining
		if hook_is_out(elapsed):
			var origin = strike_origin()
			rod_hit.emit(origin + Vector2(strike_direction * 30.0, 0), hook_at(origin, elapsed), strike_id)
		queue_redraw()

func play_movement():
	if strike_remaining > 0.0: return
	if dash_remaining > 0.0:
		art.play("motion_dash_" + side())
	elif not grounded:
		art.play(("motion_rise_" if jump_velocity < 0.0 else "motion_fall_") + side())
	else:
		art.play(("walk_" if movement != 0.0 else "idle_") + side())

func strike_origin() -> Vector2:
	return actor.position + Vector2(0, feet_offset - LINE_HEIGHT)

func hook_is_out(elapsed: float) -> bool:
	return elapsed >= 0.10 and elapsed < 0.40

func hook_at(origin: Vector2, elapsed: float) -> Vector2:
	var extension = smoothstep(0.10, STRIKE_HIT_TIME, elapsed) * (1.0 - smoothstep(0.23, 0.40, elapsed))
	return origin + Vector2(strike_direction * lerpf(ROD_TIP_DISTANCE, ROD_REACH, extension), 0)

func _draw():
	if dash_remaining > 0.0:
		draw_dash_streaks()
	if strike_remaining <= 0.0: return
	var elapsed = STRIKE_DURATION - strike_remaining
	if not hook_is_out(elapsed): return
	var origin = strike_origin()
	var rod_tip = origin + Vector2(strike_direction * ROD_TIP_DISTANCE, 0)
	var hook = hook_at(origin, elapsed)
	draw_line(rod_tip, hook, Color(0.84, 0.91, 0.93, 0.92), 1.4, true)
	var shape = PackedVector2Array([hook - Vector2(6 * strike_direction, 0), hook, hook + Vector2(0, 5), hook + Vector2(-3 * strike_direction, 8), hook + Vector2(-7 * strike_direction, 7), hook + Vector2(-7 * strike_direction, 4)])
	draw_polyline(shape, Color("212636"), 3.5, true)
	draw_polyline(shape, Color("d5dee3"), 1.5, true)

func draw_dash_streaks():
	var retreat = Vector2(-dash_direction, 0)
	var elapsed = 1.0 - dash_remaining / DASH_DURATION
	var alpha = smoothstep(0.0, 0.15, elapsed) * (1.0 - smoothstep(0.66, 1.0, elapsed))
	for streak in range(3):
		var root = actor.position + Vector2(0, -30.0 + streak * 14.0) + retreat * (22.0 + streak * 4.0)
		var bend = root + retreat * (18.0 + elapsed * 11.0) + Vector2(0, -2.0)
		var tail = root + retreat * (40.0 + elapsed * 25.0 + 7.0 * (streak % 2))
		draw_polyline(PackedVector2Array([root, bend, tail]), Color(0.73, 0.92, 0.96, alpha * (0.64 - streak * 0.11)), 1.5, true)
