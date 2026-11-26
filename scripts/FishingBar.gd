extends Node2D

# ============================================================
# PESCA EM BARRA
# O jogador resolve contas simples para encher uma barra vertical.
# A barra desce com o tempo. Quanto mais rápido enche, maior a
# chance de peixe raro (o sorteio fica em FishData.gd).
#
# Este script só cuida da pesca. Ele AVISA o resto do jogo por sinais:
#   status(texto)  -> mensagem para mostrar ao jogador
#   caught(tempo)  -> a barra encheu (tempo = segundos que levou)
# ============================================================

signal status(text)
signal caught(time_taken)

# ---- CONFIGURAÇÃO (mexa nestes números para ajustar o equilíbrio) ----
const BAR_GAIN = 0.30        # quanto a barra sobe a cada acerto (0.30 = 30%)
const BAR_PENALTY = 0.10     # quanto a barra cai a cada erro
const BAR_DECAY = 0.025      # quanto a barra cai por segundo (só depois do 1º acerto)

# ---- Visual e posição da barra (canto direito da tela) ----
const BAR_MARGIN_RIGHT = 78.0 # distância da borda direita da janela
const BAR_TOP = 150.0        # onde começa o topo da barra
const BAR_HEIGHT = 160.0
const BAR_THICKNESS = 26.0
const BAR_COLOR = Color(0.55, 0.85, 0.6, 0.7)      # verde claro e tranquilo
const BAR_COLOR_GOLD = Color(1.0, 0.82, 0.25, 0.9) # dourado ao completar

# ---- Estado ----
var slow_bonus = 0.0
var gain_bonus = 0.0
var bar_x = 0.0                 # calculado a partir do tamanho real da janela
var active = false              # true enquanto a pesca está acontecendo
var finishing = false           # true durante o brilho dourado final
var started = false             # vira true depois do primeiro acerto
var bar = 0.0
var elapsed = 0.0
var answer = 0

var question_label
var fill
var input

func _style(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _panel(parent: Node, pos: Vector2, dimensions: Vector2, bg: Color, border: Color, radius: int = 4) -> void:
	var panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = pos
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _style(bg, border, radius))
	parent.add_child(panel)

func _ready():

	_create_ui()

	visible = false

func _create_ui():

	# a posição horizontal acompanha o tamanho real da janela do jogo
	bar_x = get_viewport_rect().size.x - BAR_MARGIN_RIGHT - BAR_THICKNESS

	var center_x = bar_x + (BAR_THICKNESS / 2.0)

	_panel(self, Vector2(center_x - 64, BAR_TOP - 65), Vector2(128, BAR_HEIGHT + 109), Color(0.06, 0.10, 0.14, 0.34), Color(0.8, 0.87, 0.89, 0.6))
	var heading = Label.new()
	heading.position = Vector2(center_x - 60, BAR_TOP - 60)
	heading.size = Vector2(120, 22)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.text = "PESCA"
	add_child(heading)
	# a conta, em cima da barra
	question_label = Label.new()
	question_label.position = Vector2(center_x - 60, BAR_TOP - 36)
	question_label.size = Vector2(120, 30)
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.add_theme_font_size_override("font_size", 20)
	question_label.add_theme_color_override("font_color", Color.WHITE)
	question_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	question_label.add_theme_constant_override("outline_size", 4)
	add_child(question_label)

	# fundo da barra (translúcido)
	_panel(self, Vector2(bar_x - 2, BAR_TOP - 2), Vector2(BAR_THICKNESS + 4, BAR_HEIGHT + 4), Color(0.02, 0.05, 0.08, 0.55), Color(0.75, 0.86, 0.80, 0.8), 2)

	# preenchimento da barra (verde claro, sobe de baixo para cima)
	fill = ColorRect.new()
	fill.color = BAR_COLOR
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)

	# campo de resposta: sem caixa em volta, só o texto digitado
	input = LineEdit.new()
	input.position = Vector2(center_x - 50, BAR_TOP + BAR_HEIGHT + 6)
	input.size = Vector2(100, 28)
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.placeholder_text = "resposta"

	var empty_style = _style(Color(0.04, 0.08, 0.11, 0.55), Color(0.85, 0.91, 0.92, 0.5))
	input.add_theme_stylebox_override("normal", empty_style)
	input.add_theme_stylebox_override("focus", _style(Color(0.04, 0.08, 0.11, 0.65), Color(0.85, 0.91, 0.92, 0.85)))
	input.add_theme_stylebox_override("read_only", empty_style)
	input.add_theme_font_size_override("font_size", 18)
	input.add_theme_color_override("font_color", Color.WHITE)
	input.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	input.add_theme_constant_override("outline_size", 4)
	input.add_theme_color_override("caret_color", Color.WHITE)

	# sem isso o campo sai do modo de digitação ao apertar Enter
	input.keep_editing_on_text_submit = true

	input.text_submitted.connect(_on_answer_submitted)
	add_child(input)

	_update_bar()

# ------------------------------------------------------------
# Controle da pesca
# ------------------------------------------------------------

func start():

	active = true
	finishing = false
	started = false
	bar = 0.0
	elapsed = 0.0

	fill.color = BAR_COLOR
	modulate.a = 1.0
	input.editable = true
	_update_bar()

	visible = true

	_new_question()

	# deferido: garante que o foco vem depois do clique que abriu a pesca
	call_deferred("_refocus")

	status.emit("Responda rapido para encher a barra! (ESC para desistir)")

# Deixa o campo de resposta selecionado para o jogador só digitar.
func _refocus():

	if not active or finishing:
		return

	input.grab_focus()
	input.edit()

func cancel():

	if not active or finishing:
		return

	_close()

	status.emit("Voce desistiu de pescar.")

func _close():

	visible = false
	input.release_focus()
	active = false
	finishing = false

func _process(delta):

	if not active or finishing:
		return

	elapsed += delta

	# a barra só começa a cair depois do primeiro acerto
	if started:

		bar = max(bar - BAR_DECAY * delta * (1.0 - slow_bonus), 0.0)

		_update_bar()

		if bar <= 0.0:
			_escaped()

func _update_bar():

	# a barra cresce de baixo para cima
	var h = BAR_HEIGHT * bar

	fill.position = Vector2(bar_x, BAR_TOP + BAR_HEIGHT - h)
	fill.size = Vector2(BAR_THICKNESS, h)

func _escaped():

	_close()

	status.emit("O peixe escapou! Tente responder mais rapido.")

# ------------------------------------------------------------
# Contas e respostas
# ------------------------------------------------------------

func _new_question():

	var kind = randi_range(0, 2)
	var a = 0
	var b = 0

	if kind == 0:

		a = randi_range(3, 19)
		b = randi_range(3, 19)
		answer = a + b
		question_label.text = "%d + %d" % [a, b]

	elif kind == 1:

		a = randi_range(10, 30)
		b = randi_range(2, a - 1)
		answer = a - b
		question_label.text = "%d - %d" % [a, b]

	else:

		a = randi_range(2, 6)
		b = randi_range(2, 6)
		answer = a * b
		question_label.text = "%d x %d" % [a, b]

	input.text = ""

func _on_answer_submitted(text):

	if not active or finishing:
		return

	if not text.strip_edges().is_valid_int():
		input.text = ""
		return

	if int(text) == answer:

		# ACERTOU: barra sobe e vem uma conta nova
		started = true

		bar = min(bar + BAR_GAIN * (1.0 + gain_bonus), 1.0)

		_update_bar()

		if bar >= 0.999:
			_finish()
		else:
			_new_question()
			call_deferred("_refocus")

	else:

		# ERROU: barra cai um pouco e a mesma conta continua
		bar = max(bar - BAR_PENALTY, 0.0)

		_update_bar()

		input.text = ""

		if started and bar <= 0.0:
			_escaped()
		else:
			call_deferred("_refocus")

func _finish():

	# barra cheia: fica dourada rapidinho e some
	finishing = true

	input.editable = false

	fill.color = BAR_COLOR_GOLD

	var tween = create_tween()

	tween.tween_interval(0.35)

	tween.tween_property(self, "modulate:a", 0.0, 0.25)

	tween.tween_callback(func():
		_close()
		caught.emit(elapsed)
	)
