extends Node2D

signal status(text)
signal caught(kind, time_taken)

const DIFFICULTY = {
	"bota": 0.0, "comum": 0.12, "incomum": 0.35, "raro": 0.75,
	"vermelho": 0.20, "ambar": 0.48, "mistico": 0.80, "fantasma": 1.0,
}
const METER_WIDTH = 15.0
const METER_HEIGHT = 108.0
const LIMIT_SECONDS = 55.0
const LOWEST_ZONE_CENTER = 0.33
const HIGHEST_ZONE_CENTER = 0.71

var active = false
var kind: String
var elapsed: float
var tension: float
var progress: float
var danger_time: float
var difficulty: float
var reel_speed: float
var pull_strength: float
var pull_phase: float
var safe_min: float
var safe_max: float
var safe_half_width: float
var safe_center: float
var safe_destination: float
var safe_pause: float
var safe_speed: float
var track_style = StyleBoxFlat.new()
var safe_style = StyleBoxFlat.new()

func _ready():
	track_style.bg_color = Color(0.13, 0.10, 0.24, 0.68)
	track_style.border_color = Color(0.76, 0.69, 0.96, 0.65)
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(8)
	track_style.anti_aliasing = true
	safe_style.bg_color = Color(0.30, 0.86, 0.73, 0.72)
	safe_style.set_corner_radius_all(6)
	safe_style.anti_aliasing = true
	hide()

func start(hooked_kind: String, gain_bonus: float, slow_bonus: float):
	kind = hooked_kind
	difficulty = DIFFICULTY[kind]
	reel_speed = lerpf(0.17, 0.086, difficulty) * (1.0 + gain_bonus)
	pull_strength = lerpf(0.05, 0.21, difficulty) * (1.0 - slow_bonus)
	safe_half_width = lerpf(0.22, 0.09, difficulty)
	safe_center = randf_range(LOWEST_ZONE_CENTER, HIGHEST_ZONE_CENTER)
	safe_destination = safe_center
	safe_pause = randf_range(0.65, 1.2)
	update_safe_zone(0.0)
	pull_phase = randf() * TAU
	elapsed = 0.0
	tension = 0.43
	progress = 0.0
	danger_time = 0.0
	active = true
	show()
	queue_redraw()
	status.emit("Acompanhe a faixa móvel. Segure o botão esquerdo para aumentar a tensão e solte para aliviar.")

func cancel():
	if not active: return
	end_attempt()
	status.emit("Você desistiu de pescar.")

func end_attempt():
	active = false
	hide()

func _process(delta):
	if not active: return
	advance_line(delta, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func advance_line(delta: float, reeling: bool):
	elapsed += delta
	update_safe_zone(delta)
	var pulse = pow(maxf(0.0, sin(elapsed * lerpf(1.8, 3.3, difficulty) + pull_phase)), 4.0)
	var tension_change = -0.30 + pulse * pull_strength
	if reeling:
		tension_change += 0.51
	tension = clampf(tension + tension_change * delta, 0.0, 1.0)

	if tension >= safe_min and tension <= safe_max:
		progress = minf(1.0, progress + reel_speed * delta)
	elif tension < 0.12:
		progress = maxf(0.0, progress - 0.10 * delta)

	if tension >= 0.97 or tension <= 0.03:
		danger_time += delta
	else:
		danger_time = 0.0

	if danger_time >= 0.75 or elapsed >= LIMIT_SECONDS:
		var reason = "A linha arrebentou." if tension >= 0.97 else "A linha ficou frouxa por tempo demais."
		if elapsed >= LIMIT_SECONDS: reason = "A captura demorou demais."
		end_attempt()
		status.emit("O peixe escapou! " + reason)
	elif progress >= 1.0:
		end_attempt()
		caught.emit(kind, elapsed)
	queue_redraw()

func update_safe_zone(delta: float):
	if safe_center == safe_destination:
		safe_pause -= delta
		if safe_pause <= 0.0:
			safe_destination = randf_range(LOWEST_ZONE_CENTER, HIGHEST_ZONE_CENTER)
			if absf(safe_destination - safe_center) < 0.10:
				safe_destination = HIGHEST_ZONE_CENTER if safe_center < 0.52 else LOWEST_ZONE_CENTER
			safe_speed = randf_range(0.045, 0.08) + 0.025 * difficulty
			safe_pause = randf_range(0.4, 1.25)
	else:
		safe_center = move_toward(safe_center, safe_destination, safe_speed * delta)
	safe_min = safe_center - safe_half_width
	safe_max = safe_center + safe_half_width

func _draw():
	if not active: return
	var meter = Vector2(-49.0 if position.x >= 68.0 else 42.0, -62.0)
	var font = ThemeDB.fallback_font
	var track = Rect2(meter, Vector2(METER_WIDTH, METER_HEIGHT))
	draw_style_box(track_style, track)
	var safe_zone = Rect2(meter + Vector2(1, (1.0 - safe_max) * METER_HEIGHT), Vector2(METER_WIDTH - 2, (safe_max - safe_min) * METER_HEIGHT))
	draw_style_box(safe_style, safe_zone)
	var marker = meter + Vector2(METER_WIDTH * 0.5, (1.0 - tension) * METER_HEIGHT)
	draw_line(marker - Vector2(9, 0), marker + Vector2(9, 0), Color("fff0cd"), 2.0, true)
	var percent = "%d%%" % floori(progress * 100)
	var percent_position = meter + Vector2((METER_WIDTH - 46) * 0.5, METER_HEIGHT + 17)
	draw_string_outline(font, percent_position, percent, HORIZONTAL_ALIGNMENT_CENTER, 46, 14, 3, Color(0, 0, 0, 0.7))
	draw_string(font, percent_position, percent, HORIZONTAL_ALIGNMENT_CENTER, 46, 14, Color("fff0cd"))
