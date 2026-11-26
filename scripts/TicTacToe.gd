extends Node2D

# ============================================================
# JOGO DA VELHA DO COMERCIANTE
# Abre em cima da cabeça do comerciante. Cada casa tem uma conta:
# o jogador digita o resultado de uma casa livre e marca com X (vermelho).
# A cada 10 segundos o comerciante marca uma casa livre aleatória com O (preto).
#
# Este script só cuida do jogo. Ele AVISA o resto do jogo por sinais:
#   status(texto)    -> mensagem para mostrar ao jogador
#   finished(result) -> "player", "merchant" ou "draw"
# ============================================================

signal status(text)
signal finished(result)

# ---- CONFIGURAÇÃO ----
const MERCHANT_INTERVAL = 10.0   # segundos entre as jogadas do comerciante
const END_DELAY = 1.5            # tempo mostrando o resultado antes de fechar

# ---- Tamanho e posição ----
const CELL = 76.0                # tamanho de cada casa (o tabuleiro tem 3 x CELL)
const BOARD_TOP = 80.0           # onde começa o topo do tabuleiro na tela
const LINE_THICKNESS = 1.0

# ---- Cores ----
const COLOR_LINES = Color(0.05, 0.05, 0.05, 0.95)
const COLOR_PROBLEM = Color(0.1, 0.1, 0.12)
const COLOR_PLAYER = Color(0.85, 0.12, 0.12)     # tom de vermelho
const COLOR_MERCHANT = Color(0.05, 0.05, 0.05)   # tom de preto

const WIN_LINES = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6]
]

# ---- Estado ----
var active = false
var locked = false              # true enquanto mostra o resultado final
var slow_bonus = 0.0
var merchant_timer = 0.0
var board_left = 0.0

# cada casa: {"answer": int, "owner": "" | "player" | "merchant", "label": Label}
var cells = []

var holder
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

	holder = Node2D.new()
	add_child(holder)

	# campo de resposta: sem caixa em volta, só o texto digitado
	input = LineEdit.new()
	input.size = Vector2(100, 28)
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.placeholder_text = "resultado"

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

	visible = false

# center_x = posição horizontal do comerciante (o tabuleiro fica centralizado nela)
func start(center_x):

	_clear_board()

	board_left = center_x - (CELL * 3.0) / 2.0

	_build_board()

	input.position = Vector2(center_x - 50, BOARD_TOP + (CELL * 3.0) + 6)
	input.text = ""
	input.editable = true

	active = true
	locked = false
	merchant_timer = 0.0

	visible = true

	# deferido: garante que o foco vem depois do clique que abriu o jogo
	call_deferred("_refocus")

	status.emit("Digite o resultado de uma casa para marcar! O comerciante joga a cada 10 segundos. (ESC para sair)")

func cancel():

	if not active or locked:
		return

	_close()

	status.emit("Voce saiu do jogo da velha.")

func _close():

	visible = false
	input.release_focus()
	active = false
	locked = false

# Deixa o campo de resposta selecionado para o jogador só digitar.
func _refocus():

	if not active or locked:
		return

	input.grab_focus()
	input.edit()

# ------------------------------------------------------------
# Tabuleiro
# ------------------------------------------------------------

func _clear_board():

	for child in holder.get_children():
		child.queue_free()

	cells.clear()

func _build_board():

	var problems = _generate_problems()

	_panel(holder, Vector2(board_left - 12, BOARD_TOP - 35), Vector2(CELL * 3 + 24, CELL * 3 + 82), Color(0.88, 0.92, 0.89, 0.48), Color(0.96, 0.98, 0.96, 0.75))
	var heading = Label.new()
	heading.position = Vector2(board_left, BOARD_TOP - 30)
	heading.size = Vector2(CELL * 3, 24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", COLOR_PROBLEM)
	heading.text = "NEGOCIACAO"
	holder.add_child(heading)
	# as 9 casas, com a conta de cada uma
	for i in range(9):

		var col = i % 3
		var row = floori(i / 3.0)

		_panel(holder, Vector2(board_left + col * CELL + 2, BOARD_TOP + row * CELL + 2), Vector2(CELL - 4, CELL - 4), Color(0.93, 0.95, 0.92, 0.43), Color(0.10, 0.14, 0.12, 0.7), 2)
		var label = Label.new()
		label.position = Vector2(board_left + (col * CELL), BOARD_TOP + (row * CELL))
		label.size = Vector2(CELL, CELL)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", COLOR_PROBLEM)
		label.text = problems[i]["text"]
		holder.add_child(label)

		cells.append({
			"answer": problems[i]["answer"],
			"owner": "",
			"label": label
		})

# 9 contas com resultados todos diferentes (assim cada resultado aponta para uma casa só)
func _generate_problems():

	var used = []
	var result = []

	while result.size() < 9:

		var problem = _random_problem()

		if problem["answer"] in used:
			continue

		used.append(problem["answer"])
		result.append(problem)

	return result

func _random_problem():

	var kind = randi_range(0, 2)
	var a = 0
	var b = 0

	if kind == 0:

		a = randi_range(3, 19)
		b = randi_range(3, 19)
		return {"text": "%d + %d" % [a, b], "answer": a + b}

	elif kind == 1:

		a = randi_range(10, 30)
		b = randi_range(2, a - 1)
		return {"text": "%d - %d" % [a, b], "answer": a - b}

	a = randi_range(2, 6)
	b = randi_range(2, 6)
	return {"text": "%d x %d" % [a, b], "answer": a * b}

# ------------------------------------------------------------
# Jogadas
# ------------------------------------------------------------

func _process(delta):

	if not active or locked:
		return

	merchant_timer += delta * (1.0 - slow_bonus)

	if merchant_timer >= MERCHANT_INTERVAL:

		merchant_timer = 0.0

		_merchant_move()

func _merchant_move():

	var free_cells = []

	for i in range(cells.size()):

		if cells[i]["owner"] == "":
			free_cells.append(i)

	if free_cells.is_empty():
		return

	_place(free_cells[randi() % free_cells.size()], "merchant")

func _on_answer_submitted(text):

	if not active or locked:
		return

	if not text.strip_edges().is_valid_int():
		input.text = ""
		return

	var value = int(text)

	for i in range(cells.size()):

		if cells[i]["owner"] == "" and cells[i]["answer"] == value:

			input.text = ""

			_place(i, "player")

			call_deferred("_refocus")

			return

	# nenhuma casa livre com esse resultado
	input.text = ""

	status.emit("Nenhuma casa livre tem esse resultado.")

	call_deferred("_refocus")

func _place(index, who):

	var cell = cells[index]
	var label = cell["label"]

	cell["owner"] = who

	label.add_theme_font_size_override("font_size", 56)

	if who == "player":
		label.text = "X"
		label.add_theme_color_override("font_color", COLOR_PLAYER)
	else:
		label.text = "O"
		label.add_theme_color_override("font_color", COLOR_MERCHANT)

	_check_end()

func _check_end():

	for line in WIN_LINES:

		var first = cells[line[0]]["owner"]

		if first != "" and first == cells[line[1]]["owner"] and first == cells[line[2]]["owner"]:
			_end(first)
			return

	for cell in cells:

		if cell["owner"] == "":
			return

	_end("draw")

func _end(result):

	locked = true

	input.editable = false

	if result == "player":
		status.emit("Voce venceu o jogo da velha!")
	elif result == "merchant":
		status.emit("O comerciante venceu o jogo da velha!")
	else:
		status.emit("Deu empate no jogo da velha!")

	var tween = create_tween()

	tween.tween_interval(END_DELAY)

	tween.tween_callback(func():
		_close()
		finished.emit(result)
	)
