extends Control

signal open_requested

const FishData = preload("res://scripts/FishData.gd")
const Inventory = preload("res://scripts/Inventory.gd")
const PAGE_INK = Color("62391f")

var book: Control
var entries: Control
var open_button: Button
var handwriting = SystemFont.new()
var illustration_ink = ShaderMaterial.new()

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	handwriting.font_names = PackedStringArray(["Segoe Print", "Bradley Hand ITC", "Georgia", "serif"])
	var ink_shader = Shader.new()
	ink_shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 pigment = texture(TEXTURE, UV);
	float lightness = dot(pigment.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sepia = mix(vec3(0.23, 0.12, 0.06), vec3(0.87, 0.64, 0.36), lightness);
	vec3 wash = mix(sepia, pigment.rgb, 0.30);
	float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	float opacity = mix(0.92, 0.54, lightness) * mix(0.84, 1.0, grain);
	COLOR = vec4(wash, pigment.a * opacity);
}
"""
	illustration_ink.shader = ink_shader
	open_button = wood_button(self, "Diário", Rect2(1114, 654, 142, 42))
	open_button.pressed.connect(func(): open_requested.emit())

	book = Control.new()
	book.size = Vector2(1280, 720)
	book.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(book)
	var paper = TextureRect.new()
	paper.texture = preload("res://ui/capture_diary.png")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.size = book.size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(paper)

	ink_label(book, "Diário de Capturas", Vector2(229, 103), 32)
	ink_stroke(book, Vector2(229, 153), 298.0, 0.43)
	var back = wood_button(book, "Voltar", Rect2(24, 654, 118, 42))
	back.pressed.connect(close_book)
	entries = Control.new()
	entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(entries)
	book.hide()

func wood_button(parent: Control, caption: String, bounds: Rect2) -> Button:
	var button = Button.new()
	button.text = caption
	button.position = bounds.position
	button.size = bounds.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", Color("fff0cf"))
	button.add_theme_color_override("font_hover_color", Color("fff0cf"))
	var wood = StyleBoxFlat.new()
	wood.bg_color = Color("704423")
	wood.border_color = Color("b5834c")
	wood.set_border_width_all(2)
	wood.set_corner_radius_all(5)
	var hover = wood.duplicate()
	hover.bg_color = Color("8b562d")
	button.add_theme_stylebox_override("normal", wood)
	button.add_theme_stylebox_override("pressed", wood)
	button.add_theme_stylebox_override("hover", hover)
	parent.add_child(button)
	return button

func ink_label(parent: Control, caption: String, at: Vector2, font_size: int) -> Label:
	var label = Label.new()
	label.position = at
	label.text = caption
	label.add_theme_font_override("font", handwriting)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PAGE_INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func ink_stroke(parent: Control, at: Vector2, length: float, opacity: float):
	var stroke = Line2D.new()
	stroke.position = at
	stroke.points = PackedVector2Array([Vector2.ZERO, Vector2(length * 0.42, 1), Vector2(length * 0.78, -0.5), Vector2(length, 0.5)])
	stroke.width = 1.5
	stroke.default_color = Color(PAGE_INK, opacity)
	stroke.antialiased = true
	parent.add_child(stroke)

func show_book(species: Array[String]):
	for entry in entries.get_children():
		entries.remove_child(entry)
		entry.queue_free()
	for index in species.size():
		var kind = species[index]
		var fish = FishData.types[kind]
		var slot = index % 4
		var page_x = 230.0 if index < 4 else 678.0
		var entry = VBoxContainer.new()
		entry.position = Vector2(page_x + (slot % 2) * 183.0, 181.0 + floorf(slot / 2.0) * 150.0)
		entry.size.x = 172.0
		entry.add_theme_constant_override("separation", 5)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entries.add_child(entry)
		var icon = TextureRect.new()
		icon.texture = Inventory.ICONS[kind]
		icon.custom_minimum_size = Vector2(54, 48)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.material = illustration_ink
		entry.add_child(icon)
		var name_label = ink_label(entry, fish["nome"].capitalize(), Vector2.ZERO, 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var price_label = ink_label(entry, "R$ %d" % fish["valor"], Vector2.ZERO, 15)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	open_button.hide()
	book.show()

func close_book():
	book.hide()
	open_button.show()

func is_open() -> bool:
	return book.visible

func is_over_button(point: Vector2) -> bool:
	return open_button.visible and open_button.get_global_rect().has_point(point)
