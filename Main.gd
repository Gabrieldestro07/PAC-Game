extends Node2D

# ============================================================
# MAIN
# Liga as partes do jogo: movimento do jogador, cliques no cenário
# e a comunicação entre inventário, pesca e comerciante.
#
#   scripts/FishData.gd   -> espécies, valores e sorteio de raridade
#   scripts/Inventory.gd  -> grade, itens e arrastar
#   scripts/FishingBar.gd -> pesca em barra
#   scripts/TicTacToe.gd  -> jogo da velha do comerciante (vencer = vender)
# ============================================================

const FishData = preload("res://scripts/FishData.gd")
const InventoryScript = preload("res://scripts/Inventory.gd")
const FishingBarScript = preload("res://scripts/FishingBar.gd")
const FishingTensionScript = preload("res://scripts/FishingTension.gd")
const CaptureDiaryScript = preload("res://scripts/CaptureDiary.gd")
const CrowFightScript = preload("res://scripts/CrowFight.gd")
const PlayerActionsScript = preload("res://scripts/PlayerActions.gd")
const TicTacToeScript = preload("res://scripts/TicTacToe.gd")

const GRASS_FEET_Y = 430.0
const PIER_FEET_Y = 407.0
const PIER_START_X = 625.0
const PIER_END_X = 965.0
const STEP_SPACING = 82.0
const FIRST_STEP_DISTANCE = 36.0
const RARE_CATCHES = ["raro", "mistico", "fantasma"]
const CAVE_AMBIENCE_VOLUME = -17.0
const CAVE_AMBIENCE_FADED = -54.0
const FISHING_DISTANCE = 18.0
const CATCH_COOLDOWN = 3.0
const CAVE_CATCH_DURATION = 4.0
const FEET_OFFSET = 40.625
const PLAYER_ART_SCALE = 1.25
const PLAYER_ART_X = 26.5
const ARRIVAL_FEET = 520.0
const CAVE_FEET = 520.0
const CAVE_BRIDGE_START_X = 365.0
const CAVE_BRIDGE_END_X = 990.0
const CAVE_FISHING_WATER = Rect2(405, 300, 570, 190)
const GHOST_X = 1150.0
const GHOST_Y = 445.0
const GHOST_FLOAT_HEIGHT = 8.0
const GHOST_FLOAT_PERIOD = 3.4
const CAVE_ENTRY_X = 1080.0
const CAVE_CLICK = Rect2(960, 220, 240, 260)
const CROW_X = 930.0
const CROW_REACH = 100.0
const CROW_CLICK = Rect2(800, 95, 275, 240)
const OVERLOOK_EDGE_X = 1035.0
const TRAIN_FEET_Y = 552.0
const TRAIN_PLATFORM_END_X = 600.0
const TRAIN_DOOR_X = 445.0
const TRAIN_CLICK = Rect2(30, 310, 535, 225)

var money = 0
var train_area = false
var cave_area = false
enum Exterior { ARRIVAL, OVERLOOK }
var exterior = Exterior.ARRIVAL
var crow_offering = false
var crow_defeated = false
var crow_fight: CrowFightScript
var spectral: AnimatedSprite2D
var smoke: AnimatedSprite2D
var crow_art: AnimatedSprite2D
var swim_time = 0.0
var background: Sprite2D
var train_dialog: ConfirmationDialog
var crow_dialog: ConfirmationDialog
var menu_button: Button
var dev_label: Label
var dev_fish_menu: PopupMenu
var dev_fish_kinds: Array[String] = []
var capture_diary: CaptureDiaryScript
var caught_species: Array[String] = []
var gear
var attempt_worm = false

# PEIXES NO LAGO (só decoração por enquanto)
var lake_fishes = []

# Partes do jogo (criadas no _ready)
var inventory
var fishing
var tension_fishing: FishingTensionScript
var tictactoe

@onready var player = $Player
@onready var info = $Info
@onready var inv_button = $InventoryButton
@onready var merchant = $Merchant

var player_art: AnimatedSprite2D
var player_actions: PlayerActionsScript
var merchant_art: Sprite2D
var sale_timer = 0.0
var result_timer = 0.0
var result_duration = CATCH_COOLDOWN
var fishing_cooldown = 0.0
var result_icon: Sprite2D
var result_echo: Sprite2D
var rare_catch_audio: AudioStreamPlayer
var grass_step_audio: AudioStreamPlayer
var wood_step_audio: AudioStreamPlayer
var dash_audio: AudioStreamPlayer
var cave_ambience_audio: AudioStreamPlayer
var cave_ambience_fade: Tween
var rare_sound_pending = false
var step_audio: AudioStreamPlayer
var walk_distance = STEP_SPACING - FIRST_STEP_DISTANCE
var fish_art = [preload("res://itens_pesca/peixe_azul.png"), preload("res://itens_pesca/peixe_verde.png"), preload("res://itens_pesca/peixe_vermelho.png"), preload("res://itens_pesca/peixe_mistico.png"), preload("res://itens_pesca/peixe_dourado.png")]

func setup_art():
	var bg = Sprite2D.new()
	bg.texture = preload("res://mapa/mapa_alinhado.png")
	bg.centered = false
	background = bg
	bg.z_index = -10
	add_child(bg)
	player.self_modulate.a = 0.0
	player_art = AnimatedSprite2D.new()
	player_art.sprite_frames = preload("res://fisherman/fisherman_frames.tres").duplicate()
	var reel_durations = [0.78, 0.93, 0.99, 0.46, 0.41, 0.30]
	for phase in ["prepare", "cast", "idle", "reel"]:
		var anim = "back_" + phase
		player_art.sprite_frames.add_animation(anim)
		player_art.sprite_frames.set_animation_speed(anim, 1.0 if phase == "reel" else 6.0)
		player_art.sprite_frames.set_animation_loop(anim, phase == "idle")
		for i in range(reel_durations.size() if phase == "reel" else 3):
			var duration: float = reel_durations[i] if phase == "reel" else 1.0
			player_art.sprite_frames.add_frame(anim, load("res://fisherman/back_fishing/back_%s_%d.png" % [phase, i]), duration)
	player_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_art.scale = Vector2.ONE * PLAYER_ART_SCALE
	player_art.position = Vector2(PLAYER_ART_X, -11.875)
	# Desenha o pescador acima da tendinha, sem alterar colisao ou movimento.
	player.z_index = 1
	player.add_child(player_art)
	player_art.play("idle_right")
	player_art.animation_changed.connect(align_player_art)
	player_art.animation_finished.connect(_art_animation_finished)
	merchant.self_modulate.a = 0.0
	merchant_art = Sprite2D.new()
	merchant_art.texture = preload("res://mercador/idle.png")
	merchant_art.scale = Vector2(0.18, 0.18)
	merchant_art.position = Vector2(0, -45)
	merchant.add_child(merchant_art)
	$MerchantText.position.y = 270
	$MerchantText.add_theme_constant_override("outline_size", 4)
	$Info.add_theme_constant_override("outline_size", 4)
	result_icon = Sprite2D.new()
	result_icon.visible = false
	result_echo = Sprite2D.new()
	result_echo.hide()
	player.add_child(result_echo)
	player.add_child(result_icon)

func align_player_art():
	var animation = str(player_art.animation)
	var side_action = animation.begins_with("motion_") or animation.begins_with("rod_strike_")
	player_art.position.x = 0.0 if side_action or animation.begins_with("back_") else PLAYER_ART_X
	player_art.flip_h = side_action and animation.ends_with("_left")

func _art_animation_finished():
	if result_timer > 0.0 and player_art.animation == &"fishing_bite":
		player_art.play("celebration", 0.51)
		return
	if not is_fishing():
		return
	if player_art.animation == &"back_prepare":
		player_art.play("back_cast")
	elif player_art.animation == &"back_cast":
		player_art.play("back_idle")
	elif player_art.animation == &"fishing_prepare":
		player_art.play("fishing_cast")
	elif player_art.animation == &"fishing_cast" or player_art.animation == &"fishing_bite":
		player_art.play("fishing_idle")

func update_art(delta):
	if sale_timer > 0:
		sale_timer -= delta
		if sale_timer <= 0 and Travel.region == 1:
			merchant_art.texture = preload("res://mercador/idle.png")
	if result_timer > 0:
		result_timer = maxf(0.0, result_timer - delta)
		update_catch_display()
	if is_fishing():
		return
	if result_timer > 0:
		return
	player_actions.play_movement()

func update_catch_display():
	var display_scale = CATCH_COOLDOWN / result_duration
	var elapsed = (result_duration - result_timer) * display_scale
	var rise_start = 0.72
	var rise_end = 2.04
	var rise = smoothstep(rise_start, rise_end, elapsed)
	result_icon.visible = elapsed >= rise_start and result_timer > 0.0
	if rare_sound_pending and result_icon.visible:
		rare_sound_pending = false
		rare_catch_audio.play()
	result_icon.position = Vector2(lerpf(54.0, 9.0, rise), lerpf(-34.0, -111.0, rise))
	result_icon.modulate.a = smoothstep(rise_start, 1.12, elapsed) * smoothstep(0.0, 0.46, result_timer * display_scale)
	result_echo.visible = result_icon.visible and result_icon.texture == inventory.ICONS["fantasma"] and elapsed < 2.22
	if result_echo.visible:
		var trail = smoothstep(rise_start, rise_end, elapsed - 0.18)
		result_echo.position = Vector2(lerpf(54.0, 9.0, trail), lerpf(-34.0, -111.0, trail))
		result_echo.modulate = Color(0.42, 1.0, 0.59, result_icon.modulate.a * 0.34 * (1.0 - smoothstep(1.83, 2.22, elapsed)))

func _ready():

	randomize()

	player.position.y = ground_feet_at(player.position.x) - FEET_OFFSET

	# INVENTÁRIO (usa o painel que já existe na cena)
	inventory = InventoryScript.new()
	add_child(inventory)
	inventory.setup($InventoryPanel)
	inventory.changed.connect(save_progress)
	$InventoryPanel.z_index = 3
	inv_button.z_index = 3
	info.z_index = 3

	inv_button.pressed.connect(toggle_inventory)
	gear = preload("res://scripts/Equipment.gd").new()
	add_child(gear)
	gear.setup(self)

	# PESCA
	fishing = FishingBarScript.new()
	fishing.z_index = 4
	add_child(fishing)
	fishing.status.connect(_on_status)
	fishing.caught.connect(_on_fish_caught)
	tension_fishing = FishingTensionScript.new()
	tension_fishing.z_index = 4
	add_child(tension_fishing)
	tension_fishing.status.connect(_on_status)
	tension_fishing.caught.connect(award_fish)

	# JOGO DA VELHA DO COMERCIANTE
	tictactoe = TicTacToeScript.new()
	tictactoe.z_index = 4
	add_child(tictactoe)
	tictactoe.status.connect(_on_status)
	tictactoe.finished.connect(_on_tictactoe_finished)

	setup_art()
	setup_audio()
	player_actions = PlayerActionsScript.new()
	player_actions.z_index = 2
	player_actions.setup(player, player_art, FEET_OFFSET)
	player_actions.dashed.connect(func(): dash_audio.play())
	add_child(player_actions)
	create_lake_fishes()
	load_progress()
	menu_button = gear.btn(self,"Menu",Vector2(20,55),Vector2(100,38),return_menu)
	menu_button.z_index = 9
	capture_diary = CaptureDiaryScript.new()
	capture_diary.z_index = 30
	add_child(capture_diary)
	capture_diary.open_requested.connect(open_capture_diary)
	train_dialog = ConfirmationDialog.new()
	train_dialog.title = "Viagem"
	train_dialog.confirmed.connect(buy_ticket)
	add_child(train_dialog)
	crow_dialog = ConfirmationDialog.new()
	crow_dialog.title = CrowFightScript.CROW_NAME
	crow_dialog.confirmed.connect(confirm_crow_dialog)
	add_child(crow_dialog)
	style_crow_dialog()
	crow_fight = CrowFightScript.new()
	crow_fight.z_index = 25
	crow_fight.finished.connect(finish_crow_fight)
	player_actions.rod_hit.connect(crow_fight.receive_rod_hit)
	add_child(crow_fight)
	if Travel.region == 2:
		setup_second()
	else:
		info.text = "A/D para andar · Espaço para pular · Shift para dash"
	if Travel.dev_mode:
		dev_label = Label.new()
		dev_label.text = "MODO DEV · F2 dinheiro | F3 fases | F4 equipamentos | F5 iscas | F6 peixes | F7 limpar"
		dev_label.position = Vector2(18,685)
		dev_label.add_theme_font_size_override("font_size",14)
		dev_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dev_label.z_index = 20
		add_child(dev_label)
		setup_dev_fish_menu()

func _physics_process(delta):

	fishing_cooldown = maxf(0.0, fishing_cooldown - delta)
	if Travel.busy: return
	if crow_fight.active:
		crow_fight.advance(delta)
		return
	var previous_x = player.position.x
	var was_walking = player_actions.grounded and player_actions.dash_remaining <= 0.0
	player_actions.step(delta, movement_bounds(), ground_feet_at, world_controls_enabled())
	update_footsteps(previous_x, was_walking)
	if Travel.region == 2:
		update_second(delta)
	elif not train_area and is_exiting(-1, 51.0):
		change_area(true)
	elif train_area and is_exiting(1, 1240.0):
		change_area(false)
	update_art(delta)

func setup_audio():
	rare_catch_audio = AudioStreamPlayer.new()
	rare_catch_audio.stream = preload("res://assets/audio/captura_rara.wav")
	rare_catch_audio.volume_db = -9.0
	add_child(rare_catch_audio)
	grass_step_audio = create_step_audio([
		preload("res://assets/audio/passo_grama_1.wav"),
		preload("res://assets/audio/passo_grama_2.wav"),
		preload("res://assets/audio/passo_grama_3.wav"),
	], -22.0)
	wood_step_audio = create_step_audio([
		preload("res://assets/audio/passo_madeira_1.wav"),
		preload("res://assets/audio/passo_madeira_2.wav"),
		preload("res://assets/audio/passo_madeira_3.wav"),
	], -17.0)
	dash_audio = AudioStreamPlayer.new()
	dash_audio.stream = preload("res://assets/audio/dash.wav")
	dash_audio.volume_db = -12.0
	add_child(dash_audio)
	var cave_loop: AudioStreamWAV = preload("res://assets/audio/ambiente_caverna.wav").duplicate()
	cave_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	cave_loop.loop_end = roundi(cave_loop.get_length() * cave_loop.mix_rate)
	cave_ambience_audio = AudioStreamPlayer.new()
	cave_ambience_audio.stream = cave_loop
	cave_ambience_audio.volume_db = CAVE_AMBIENCE_FADED
	add_child(cave_ambience_audio)

func create_step_audio(variants: Array[AudioStream], volume: float) -> AudioStreamPlayer:
	var randomizer = AudioStreamRandomizer.new()
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	randomizer.random_pitch = 1.08
	for index in variants.size():
		randomizer.add_stream(index, variants[index])
	var audio = AudioStreamPlayer.new()
	audio.stream = randomizer
	audio.volume_db = volume
	add_child(audio)
	return audio

func set_cave_ambience(inside: bool):
	if cave_ambience_fade and cave_ambience_fade.is_valid():
		cave_ambience_fade.kill()
	if inside and not cave_ambience_audio.playing:
		cave_ambience_audio.volume_db = CAVE_AMBIENCE_FADED
		cave_ambience_audio.play()
	elif not inside and not cave_ambience_audio.playing:
		return
	cave_ambience_fade = create_tween()
	var volume = CAVE_AMBIENCE_VOLUME if inside else CAVE_AMBIENCE_FADED
	cave_ambience_fade.tween_property(cave_ambience_audio, "volume_db", volume, 0.55)
	if not inside:
		cave_ambience_fade.tween_callback(cave_ambience_audio.stop)

func update_footsteps(previous_x: float, was_walking: bool):
	var next_step_audio = step_audio_at(player.position.x)
	if step_audio != next_step_audio:
		walk_distance = STEP_SPACING - FIRST_STEP_DISTANCE
		step_audio = next_step_audio
	var walking = was_walking and player_actions.grounded and player_actions.movement != 0.0
	var distance = absf(player.position.x - previous_x)
	if step_audio == null or not walking or distance <= 0.0:
		walk_distance = STEP_SPACING - FIRST_STEP_DISTANCE
		return
	walk_distance += distance
	if walk_distance >= STEP_SPACING:
		walk_distance -= STEP_SPACING
		step_audio.play()

func step_audio_at(x: float) -> AudioStreamPlayer:
	if Travel.region == 1:
		if train_area:
			return wood_step_audio if x <= TRAIN_PLATFORM_END_X else null
		return grass_step_audio if x < PIER_START_X - 28.0 else wood_step_audio
	if cave_area and x >= CAVE_BRIDGE_START_X and x <= CAVE_BRIDGE_END_X:
		return wood_step_audio
	return null

func ground_feet_at(x: float) -> float:
	if Travel.region == 2: return CAVE_FEET if cave_area else ARRIVAL_FEET
	if train_area: return TRAIN_FEET_Y
	var ascent = smoothstep(PIER_START_X - 28.0, PIER_START_X + 8.0, x)
	return lerpf(GRASS_FEET_Y, PIER_FEET_Y, ascent)

func movement_bounds() -> Vector2:
	if Travel.region == 1:
		return Vector2(80, 1250) if train_area else Vector2(50, PIER_END_X)
	if cave_area: return Vector2(50, 1210)
	return Vector2(50, OVERLOOK_EDGE_X if exterior == Exterior.OVERLOOK else 1245.0)

func place_player(x: float, direction: float):
	player.position.x = x
	player_actions.direction = direction
	player_actions.reset_motion(ground_feet_at(x))

func world_controls_enabled() -> bool:
	return not (is_fishing() or result_timer > 0.0 or tictactoe.active or capture_diary.is_open() or
		gear.modal_open() or gear.equipment.visible or $InventoryPanel.visible or train_dialog.visible or crow_dialog.visible or
		(is_instance_valid(dev_fish_menu) and dev_fish_menu.visible))

func is_exiting(direction: int, edge: float) -> bool:
	return player_actions.grounded and player_actions.movement * direction > 0.0 and (player.position.x - edge) * direction >= 0.0

func _input(event):
	if Travel.busy or train_dialog.visible or crow_dialog.visible: return
	if inventory == null:
		return
	if crow_fight.active:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if crow_fight.accepts_controls(): player_actions.strike()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE and crow_fight.phase != CrowFightScript.Phase.DEFEATED:
				crow_fight.end_fight(false)
			elif crow_fight.accepts_controls():
				handle_action_key(event)
		get_viewport().set_input_as_handled()
		return
	if capture_diary.is_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			capture_diary.close_book()
			get_viewport().set_input_as_handled()
		return
	if tension_fishing.active and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		return
	if Travel.dev_mode and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6 and not is_fishing() and not tictactoe.active:
			dev_fish_menu.popup_centered(Vector2i(230, 0))
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F7]:
			if is_fishing() or tictactoe.active: return
			match event.keycode:
				KEY_F2: money += 1000
				KEY_F3: Travel.unlocked = true
				KEY_F4:
					for key in gear.PRODUCTS:
						if key not in ["worm","bread"]: gear.owned[key] = true
					gear.accessory_slots = [true,true,true,true]
					inventory.set_tea_active(true)
				KEY_F5:
					gear.owned["worm"] += 100
					gear.owned["bread"] += 100
				KEY_F7: inventory.clear()
			gear.refresh_money()
			if gear.shop.visible: gear.open_shop()
			if gear.equipment.visible: gear.show_equipment()
			save_progress()
			info.text = "Modo DEV: ação executada."
			get_viewport().set_input_as_handled()
			return
	if inventory.is_dragging() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			inventory.rotate_drag(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			inventory.cancel_drag()
			return
	if gear != null and gear.modal_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			gear.close_all()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_fishing() and not tictactoe.active:
		if inventory.open_context(event.position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return

	if is_fishing() or tictactoe.active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			fishing.cancel()
			tension_fishing.cancel()
			tictactoe.cancel()
		return
	if event is InputEventKey and event.pressed and not event.echo and world_controls_enabled():
		handle_action_key(event)
	if inventory.is_dragging() and event is InputEventMouseMotion:
		inventory.drag_to(event.position)
	if event is InputEventMouseButton:
		if not event.pressed:
			inventory.end_drag()
			return
		var pos = event.position
		if inventory.try_start_drag(pos) or is_over_ui(pos) or not world_controls_enabled():
			return
		if not interact_at(pos):
			player_actions.strike()

func handle_action_key(event: InputEventKey):
	var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_SPACE:
			player_actions.jump()
		KEY_SHIFT:
			player_actions.dash()
		_:
			return
	get_viewport().set_input_as_handled()

func can_interact(x: float, reach: float) -> bool:
	return player_actions.grounded and absf(player.position.x - x) <= reach

func interact_at(pos: Vector2) -> bool:
	if merchant.visible and merchant_art.get_rect().has_point(merchant_art.to_local(pos)):
		if can_interact(merchant.position.x, 85.0): start_merchant()
		else: info.text = "Aproxime-se do comerciante para negociar."
		return true
	if Travel.region == 2:
		if cave_area and CAVE_FISHING_WATER.has_point(pos):
			if player_actions.grounded and player.position.x >= CAVE_BRIDGE_START_X and player.position.x <= CAVE_BRIDGE_END_X:
				start_fishing()
			else:
				info.text = "Fique sobre a ponte para pescar."
			return true
		if not cave_area and exterior == Exterior.OVERLOOK and CROW_CLICK.has_point(pos):
			if can_interact(CROW_X, CROW_REACH): show_crow_dialog()
			else: info.text = "Aproxime-se do corvo para falar com ele."
			return true
		if not cave_area and exterior == Exterior.ARRIVAL and CAVE_CLICK.has_point(pos):
			if can_interact(CAVE_ENTRY_X, 100.0): change_cave(true)
			else: info.text = "Aproxime-se da entrada da caverna."
			return true
		return false
	if train_area and TRAIN_CLICK.has_point(pos):
		if can_interact(TRAIN_DOOR_X, 95.0):
			train_dialog.dialog_text = "Passagem já adquirida. Voltar ao diário?" if Travel.unlocked else "Pretende ir para a próxima área?\nPassagem: R$ 1.000"
			train_dialog.popup_centered(Vector2i(420,160))
		else:
			info.text = "Aproxime-se do trem para viajar."
		return true
	if not train_area and pos.x > PIER_END_X + 25.0 and pos.y >= 365.0:
		if player_actions.grounded and player.position.x >= PIER_END_X - FISHING_DISTANCE:
			start_fishing()
		else:
			info.text = "Vá até a ponta do píer para pescar."
		return true
	return false

func create_lake_fishes():

	# cria peixes espalhados no lago
	for i in [0,1,4]:

		var fish_sprite = Sprite2D.new()

		fish_sprite.texture = fish_art[i]

		fish_sprite.position = Vector2(
			randf_range(760, 1150),
			randf_range(500, 660)
		)

		fish_sprite.scale = Vector2(0.12,0.12)
		fish_sprite.modulate.a = 0.65
		fish_sprite.z_index = -1

		add_child(fish_sprite)

		lake_fishes.append(fish_sprite)

# ============================================================
# PESCA
# ============================================================

func is_fishing() -> bool:
	return fishing.active or tension_fishing.active

func start_fishing():

	if fishing_cooldown > 0.0:
		info.text = "Espere mais %d s para pescar de novo." % ceili(fishing_cooldown)
		return

	if Travel.region == 1 and player.position.x < PIER_END_X - FISHING_DISTANCE:
		info.text = "Va ate a ponta do pier para pescar."
		return

	if not inventory.has_room_for(Vector2i(2, 1)):
		info.text = "Inventario cheio! Venda seus peixes antes de pescar."
		return

	var hooked_kind = ""
	if randi_range(0, 1) == 1:
		hooked_kind = roll_fish(0.0, gear.available_bait() == "worm")
		var hooked_fish = FishData.types[hooked_kind]
		if not inventory.has_room_for(hooked_fish["tamanho"]):
			info.text = "Libere espaço de %d × %d na mochila para recolher a captura." % [hooked_fish["tamanho"].x, hooked_fish["tamanho"].y]
			return

	player_actions.cancel_strike()
	result_icon.hide()
	result_timer = 0.0
	player_actions.direction = 1.0
	player_art.play("back_prepare" if cave_area else "fishing_prepare")
	attempt_worm = gear.consume_bait() == "worm"
	fishing.gain_bonus = gear.attempt_bonus
	fishing.slow_bonus = 0.15 if gear.accessories.has("clock") else 0.0
	if hooked_kind.is_empty():
		fishing.start()
	else:
		tension_fishing.position = player.position
		tension_fishing.start(hooked_kind, gear.attempt_bonus, fishing.slow_bonus)
	save_progress()

func _on_status(text):

	info.text = text
	if text.begins_with("O peixe escapou!"):
		rare_sound_pending = false
		result_icon.hide()
		result_timer = 0.0

func _on_fish_caught(time_taken):
	var kind = roll_fish(time_taken, attempt_worm)
	var escape_chance = FishData.catch_slowness(time_taken, gear.accessories.has("clock")) * 0.45
	if kind != "bota" and randf() < escape_chance:
		_on_status("O peixe escapou! A captura demorou demais.")
		return
	award_fish(kind, time_taken)

func roll_fish(time_taken: float, use_worm: bool) -> String:
	var clock: bool = gear.accessories.has("clock")
	if cave_area:
		return FishData.pick_cave(time_taken, use_worm, clock, gear.glasses_on)
	return FishData.pick_type(time_taken, use_worm, clock)

func setup_dev_fish_menu():
	dev_fish_menu = PopupMenu.new()
	add_child(dev_fish_menu)
	for kind in FishData.types:
		if kind == "bota": continue
		dev_fish_menu.add_item(FishData.types[kind]["nome"], dev_fish_kinds.size())
		dev_fish_kinds.append(kind)
	dev_fish_menu.id_pressed.connect(grant_dev_fish)

func grant_dev_fish(index: int):
	if not Travel.dev_mode or index < 0 or index >= dev_fish_kinds.size(): return
	var kind = dev_fish_kinds[index]
	if not add_caught_fish(kind):
		info.text = "Modo DEV · Sem espaço para %s." % FishData.types[kind]["nome"]
		return
	save_progress()
	info.text = "Modo DEV · %s adicionado ao inventário." % FishData.types[kind]["nome"]

func add_caught_fish(kind: String) -> bool:
	if not inventory.add_fish(kind): return false
	if kind != "bota" and not caught_species.has(kind):
		caught_species.append(kind)
	return true

func award_fish(kind: String, time_taken: float):
	var data = FishData.types[kind]

	# peixe grande demais para o espaço que sobrou
	if not add_caught_fish(kind):
		info.text = "Sem espaco no inventario para o %s. Ele escapou!" % data["nome"]
		return

	result_duration = CAVE_CATCH_DURATION if cave_area else CATCH_COOLDOWN
	fishing_cooldown = result_duration
	save_progress()
	player_art.play("back_reel" if cave_area else "fishing_bite", 1.0 if cave_area else 0.48)
	result_icon.texture = inventory.ICONS[kind]
	var texture_size = result_icon.texture.get_size()
	result_icon.scale = Vector2.ONE * (67.0 / maxf(texture_size.x, texture_size.y))
	result_echo.texture = result_icon.texture
	result_echo.scale = result_icon.scale
	rare_sound_pending = kind in RARE_CATCHES
	result_timer = result_duration
	update_catch_display()
	info.text = "Peixe capturado: %s (%s) em %.1f segundos! Foi para o inventario." % [data["nome"], kind, time_taken]

# ============================================================
# COMERCIANTE
# ============================================================

func start_merchant():
	player_actions.cancel_strike()
	gear.open_menu()

func start_sale():

	if inventory.counts_by_kind().is_empty():
		info.text = "Voce nao possui peixes para vender."
		return

	# primeiro o jogo da velha, em cima da cabeça do comerciante
	tictactoe.slow_bonus = gear.tea_bonus()
	tictactoe.start(merchant.position.x)

# Vencer o jogo da velha = vender todos os peixes pelo valor normal.
# Se perder ou empatar, nada é vendido e dá para tentar de novo.
func _on_tictactoe_finished(result):

	if result != "player":
		info.text = "Voce nao venceu. Fale com o comerciante para tentar de novo."
		return

	var earned = FishData.total_value(inventory.counts_by_kind())

	money += earned
	gear.refresh_money()
	if Travel.region == 1: merchant_art.texture = preload("res://mercador/sell.png")
	sale_timer = 2.0

	inventory.clear()
	save_progress()

	info.text = "Venda realizada! Voce recebeu R$%d. Dinheiro: R$%d" % [earned, money]

# true se o clique foi no botão do inventário ou no painel dele
func is_over_ui(pos):

	if inv_button.get_global_rect().has_point(pos):
		return true

	return inventory.is_over(pos) or gear.is_over(pos) or capture_diary.is_over_button(pos) or (is_instance_valid(menu_button) and menu_button.get_global_rect().has_point(pos))

func open_capture_diary():
	if Travel.busy or is_fishing() or tictactoe.active or gear.modal_open(): return
	inventory.cancel_drag()
	capture_diary.show_book(caught_species)

func toggle_inventory():
	if is_fishing() or tictactoe.active or gear.modal_open():
		return
	gear.close_all()
	inventory.toggle()


func change_area(to_train: bool):
	if Travel.busy: return
	await Travel.close_iris()
	train_area = to_train
	background.texture = preload("res://ui/train_tree_fixed.png") if to_train else preload("res://mapa/mapa_alinhado.png")
	merchant.visible = not to_train
	$MerchantText.visible = not to_train
	for fish in lake_fishes: fish.visible = not to_train
	place_player(1180.0 if to_train else 85.0, -1.0 if to_train else 1.0)
	info.text = "Clique no trem para viajar. Saída à direita." if to_train else "Vá até a ponta do píer para pescar."
	save_progress()
	await Travel.open_iris()

func buy_ticket():
	if not Travel.unlocked:
		if money < 1000:
			info.text = "Você precisa de R$ 1.000 para viajar."
			return
		money -= 1000
		Travel.unlocked = true
		gear.refresh_money()
	save_progress()
	Travel.show_diary_next = true
	return_menu()

func return_menu():
	if Travel.busy or is_fishing() or tictactoe.active: return
	save_progress()
	Travel.go("res://Menu.tscn")

func save_progress():
	inventory.cancel_drag()
	var records = []
	for item in inventory.items:
		records.append({"kind":item.get_meta("fish_kind"),"pos":item.position,"cells":item.get_meta("cells"),"rotated":item.get_meta("rotated")})
	Travel.data = {"money":money,"glasses_on":gear.glasses_on,"owned":gear.owned,"rod":gear.rod,"bag":gear.bag,"bait":gear.bait,"slots":gear.accessory_slots,"accessories":gear.accessories,"items":records}
	Travel.data["crow_offering"] = crow_offering
	Travel.data["crow_defeated"] = crow_defeated
	Travel.data["caught_species"] = caught_species.duplicate()
	Travel.save()

func load_progress():
	var d = Travel.data
	for kind in d.get("caught_species", []):
		if kind != "bota" and FishData.types.has(kind) and not caught_species.has(kind):
			caught_species.append(kind)
	crow_offering = d.get("crow_offering", d.get("crow_paid", false))
	crow_defeated = d.get("crow_defeated", false)
	money = d.get("money",0)
	gear.owned = d.get("owned",gear.owned)
	inventory.set_tea_active(gear.owned.get("tea", false))
	gear.glasses_on = d.get("glasses_on",false)
	gear.rod = d.get("rod","wood")
	gear.bag = d.get("bag","basic")
	gear.bait = d.get("bait","none")
	gear.accessory_slots = d.get("slots",gear.accessory_slots)
	gear.accessories = d.get("accessories",gear.accessories)
	for index in gear.accessories.size():
		if gear.accessories[index] == "tea":
			gear.accessories[index] = ""
	if gear.bag == "bag": inventory.set_columns(7)
	var pending = []
	for record in d.get("items",[]):
		if not inventory.restore_fish(record):
			pending.append(record)
	for record in pending:
		if FishData.types.has(record.get("kind", "")) and not inventory.add_fish(record["kind"]):
			push_warning("Item salvo sem espaço: %s" % record["kind"])
	inventory.refresh_counter()
	gear.refresh_money()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST and inventory != null and gear != null:
		save_progress()

func animated_asset(prefix: String, count: int, rate: float) -> AnimatedSprite2D:
	var a = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.set_animation_speed("default",rate)
	for i in range(count): frames.add_frame("default",load("res://ui/"+prefix+str(i)+".png"))
	a.sprite_frames = frames
	add_child(a)
	a.play("default")
	return a

func setup_crow_art():
	var atlas = preload("res://ui/crow_perched.png")
	var frames: Array[AtlasTexture] = []
	var frame_size = Vector2(256, 244)
	for cell in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var frame = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(cell * frame_size, frame_size)
		frame.filter_clip = true
		frames.append(frame)
	var perched = SpriteFrames.new()
	perched.set_animation_speed(&"default", 1.0)
	perched.add_frame(&"default", frames[0], 2.4)
	perched.add_frame(&"default", frames[2], 0.12)
	perched.add_frame(&"default", frames[0], 1.2)
	perched.add_frame(&"default", frames[1], 0.55)
	perched.add_frame(&"default", frames[0], 1.7)
	perched.add_frame(&"default", frames[3], 0.32)
	crow_art = AnimatedSprite2D.new()
	crow_art.sprite_frames = perched
	crow_art.centered = false
	crow_art.position = Vector2(796, 90)
	crow_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crow_art.hide()
	add_child(crow_art)

func setup_second():
	for f in lake_fishes: f.hide()
	background.texture = preload("res://ui/arrival.png")
	merchant.hide()
	$MerchantText.hide()
	place_player(530.0, 1.0)
	smoke = animated_asset("smoke",3,4.0)
	smoke.position = Vector2(340,200)
	smoke.z_index = -2
	spectral = animated_asset("ghostfish",6,6.0)
	spectral.scale = Vector2(0.19,0.19)
	spectral.modulate.a = 0.65
	spectral.z_index = -2
	spectral.hide()
	setup_crow_art()
	info.text = "O trem quebrou! Procure abrigo na caverna à direita."

func update_second(delta):
	swim_time += delta
	if cave_area:
		spectral.visible = gear.glasses_on
		spectral.position = Vector2(680+250*sin(swim_time*0.45),345+15*sin(swim_time))
		spectral.flip_h = cos(swim_time*0.45)>0
		merchant_art.position.y = ghost_float_offset()
		if is_exiting(-1, 51.0): change_cave(false)

	elif exterior == Exterior.ARRIVAL:
		smoke.position.y = 200-fmod(swim_time*18,45)
		if is_exiting(1, 1240.0):
			change_exterior(Exterior.OVERLOOK)
	elif exterior == Exterior.OVERLOOK:
		if is_exiting(-1, 51.0):
			change_exterior(Exterior.ARRIVAL)

func style_crow_dialog():
	var dialog_theme = Theme.new()
	var parchment = crow_dialog_style(Color("31243d"), Color("ad8969"))
	parchment.content_margin_left = 25.0
	parchment.content_margin_right = 25.0
	parchment.content_margin_top = 16.0
	parchment.content_margin_bottom = 15.0
	dialog_theme.set_stylebox("panel", "AcceptDialog", parchment)
	dialog_theme.set_color("title_color", "Window", Color("ffebc8"))
	dialog_theme.set_font_size("title_font_size", "Window", 18)
	crow_dialog.theme = dialog_theme
	var dialogue = crow_dialog.get_label()
	dialogue.add_theme_font_size_override("font_size", 18)
	dialogue.add_theme_color_override("font_color", Color("f2dfc4"))
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var accept = crow_dialog.get_ok_button()
	var decline = crow_dialog.get_cancel_button()
	accept.add_theme_stylebox_override("normal", crow_dialog_style(Color("69453b"), Color("d3a26e")))
	accept.add_theme_stylebox_override("hover", crow_dialog_style(Color("845647"), Color("ffcf93")))
	decline.add_theme_stylebox_override("normal", crow_dialog_style(Color("3b2c47"), Color("967f9e")))
	decline.add_theme_stylebox_override("hover", crow_dialog_style(Color("503957"), Color("c2a7cc")))
	for button in [accept, decline]:
		button.custom_minimum_size = Vector2(164, 38)
		button.add_theme_color_override("font_color", Color("fff0d6"))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func crow_dialog_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style

func show_crow_dialog():
	player_actions.cancel_strike()
	crow_dialog.get_cancel_button().text = "Talvez outra hora"
	if crow_defeated:
		crow_dialog.dialog_text = "Quer voltar ao Diário de Viagem?"
		crow_dialog.get_ok_button().text = "Abrir diário"
	elif not crow_offering:
		crow_dialog.dialog_text = "O corvo pede 1 Peixe Fantasma para ouvir você."
		crow_dialog.get_ok_button().text = "Entregar peixe"
	else:
		crow_dialog.dialog_text = "Preciso saber se você aguenta ir para a próxima área."
		crow_dialog.get_ok_button().text = "Mostrar que é capaz"
	crow_dialog.popup_centered(Vector2i(530, 170))

func confirm_crow_dialog():
	if Travel.busy or exterior != Exterior.OVERLOOK: return
	if crow_defeated:
		Travel.show_diary_next = true
		return_menu()
	elif not crow_offering:
		crow_offering = true
		if not inventory.take_one("fantasma"):
			crow_offering = false
			info.text = "Você precisa de 1 Peixe Fantasma para fazer a oferenda."
			return
		show_crow_dialog.call_deferred()
	else:
		begin_crow_fight()

func begin_crow_fight():
	if crow_fight.active: return
	inventory.cancel_drag()
	$InventoryPanel.hide()
	gear.close_all()
	result_timer = 0.0
	result_icon.hide()
	result_echo.hide()
	set_exploration_hud(false)
	crow_fight.begin(player_actions, crow_art, ARRIVAL_FEET)

func set_exploration_hud(visible_now: bool):
	for widget in [info, inv_button, menu_button, gear.button, gear.balance, capture_diary, dev_label]:
		if is_instance_valid(widget):
			widget.visible = visible_now

func finish_crow_fight(won: bool):
	if won:
		crow_defeated = true
		crow_art.hide()
		Travel.show_diary_next = true
		return_menu()
		return
	player_actions.reset_motion(ARRIVAL_FEET)
	crow_art.position = Vector2(796, 90)
	crow_art.scale = Vector2.ONE
	crow_art.modulate = Color.WHITE
	crow_art.flip_h = false
	crow_art.play()
	set_exploration_hud(true)
	info.text = "Aproxime-se do corvo para tentar o desafio de novo."

func change_exterior(next: Exterior):
	if Travel.busy: return
	await Travel.close_iris()
	exterior = next
	smoke.visible = next == Exterior.ARRIVAL
	crow_art.visible = next == Exterior.OVERLOOK
	match next:
		Exterior.ARRIVAL:
			crow_art.stop()
			background.texture = preload("res://ui/arrival.png")
			place_player(1210.0, -1.0)
			info.text = "Entre na caverna ou siga à direita para o mirante."
		Exterior.OVERLOOK:
			background.texture = preload("res://ui/crow_overlook_empty.png")
			crow_art.play()
			place_player(90.0, 1.0)
			info.text = "Chegue perto do corvo e clique nele para falar."
	update_art(0.0)
	await Travel.open_iris()

func ghost_float_offset() -> float:
	return GHOST_FLOAT_HEIGHT * sin(TAU * swim_time / GHOST_FLOAT_PERIOD)

func change_cave(inside: bool):
	if Travel.busy: return
	if not inside: set_cave_ambience(false)
	await Travel.close_iris()
	cave_area = inside
	if inside: set_cave_ambience(true)
	background.texture = preload("res://ui/cave_level_bridge.png") if inside else preload("res://ui/arrival.png")
	merchant.visible = inside
	merchant.position = Vector2(GHOST_X, GHOST_Y)
	merchant_art.texture = preload("res://ui/ghost_full.png")
	merchant_art.scale = Vector2.ONE
	merchant_art.position = Vector2(0, ghost_float_offset())
	smoke.visible = not inside
	spectral.visible = inside and gear.glasses_on
	place_player(90.0 if inside else CAVE_ENTRY_X, 1.0)
	info.text = "Clique na água atrás da ponte para pescar." if inside else "Entrada da caverna à direita."
	save_progress()
	await Travel.open_iris()
