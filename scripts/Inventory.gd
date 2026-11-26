extends Node
signal changed

const FishData = preload("res://scripts/FishData.gd")
const SLOT_SIZE = 48
const GRID_SIZE = 6
const ORIGIN = Vector2(16, 76)
const ICONS = {
	"fantasma": preload("res://ui/ghostfish0.png"),
	"comum": preload("res://itens_pesca/peixe_azul.png"),
	"incomum": preload("res://itens_pesca/peixe_verde.png"),
	"raro": preload("res://itens_pesca/peixe_dourado.png"),
	"vermelho": preload("res://itens_pesca/peixe_vermelho.png"),
	"ambar": preload("res://itens_pesca/peixe_ambar.png"),
	"mistico": preload("res://itens_pesca/peixe_mistico.png"),
	"bota": preload("res://itens_pesca/bota_corinthians.png")
}
const COLORS = {"fantasma": Color.GREEN, "comum": Color("72bce9"), "incomum": Color("86c76a"), "raro": Color("e7bc4c"), "vermelho": Color("e66c59"), "ambar": Color("e6a34d"), "mistico": Color("aa83df"), "bota": Color("aaa9a4")}
var columns = 6
var slots: Array[Panel] = []
var track: ColorRect
var close_button: Button
var context: PopupMenu
var confirm: ConfirmationDialog
var selected: Panel
var panel: Panel
var items: Array[Panel] = []
var dragging_item: Panel = null
var original_pos: Vector2
var original_cells: Vector2i
var original_rotated: bool
var drag_offset: Vector2
var preview: Panel
var counter: Label
var tea_status: Label
var meter: ColorRect

func style(bg: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s

func label_at(txt: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)
	return l

func setup(inv_panel):
	panel = inv_panel
	for child in panel.get_children():
		child.hide()
	panel.position = Vector2(930, 104)
	panel.size = Vector2(320, 428)
	panel.add_theme_stylebox_override("panel", style(Color(0.06,0.10,0.13,0.79), Color(0.76,0.82,0.81,0.65), 5))
	label_at("INVENTÁRIO", Vector2(16,10), 19, Color.WHITE)
	counter = label_at("", Vector2(16,36), 13, Color("bacbc7"))
	tea_status = label_at("Chá de camomila · ativo", Vector2(151,36), 13, Color("a8d9ae"))
	tea_status.hide()
	track = ColorRect.new()
	track.position = Vector2(16,64)
	track.size = Vector2(288,3)
	track.color = Color(1,1,1,0.15)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(track)
	meter = ColorRect.new()
	meter.position = track.position
	meter.color = Color("8cc5a4")
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(meter)
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var slot = Panel.new()
			slot.position = ORIGIN + Vector2(x,y)*SLOT_SIZE
			slot.size = Vector2(46,46)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_theme_stylebox_override("panel", style(Color(0.75,0.84,0.82,0.07), Color(0.76,0.82,0.81,0.28),2))
			panel.add_child(slot)
			slots.append(slot)
	label_at("Arrastar para mover", Vector2(16,374), 14, Color("e2e9e6"))
	label_at("[R] Girar item", Vector2(16,396), 13, Color("bacbc7"))
	var close = Button.new()
	close.text = "×"
	close.position = Vector2(278,8)
	close.size = Vector2(28,28)
	close.flat = true
	close.pressed.connect(toggle)
	panel.add_child(close)
	close_button = close
	context = PopupMenu.new()
	context.add_item("Informações", 0)
	context.add_item("Girar item", 1)
	context.add_item("Descartar item", 2)
	context.id_pressed.connect(context_action)
	panel.add_child(context)
	confirm = ConfirmationDialog.new()
	confirm.title = "Descartar item?"
	confirm.confirmed.connect(discard_selected)
	panel.add_child(confirm)
	preview = Panel.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 1
	preview.hide()
	panel.add_child(preview)
	refresh_counter()

func refresh_counter():
	var used = 0
	for item in items:
		var c: Vector2i = item.get_meta("cells")
		used += c.x*c.y
	counter.text = "%d / %d slots ocupados" % [used, columns*6]
	meter.size = Vector2(48.0*columns*used/(columns*6.0),3)

func set_tea_active(active: bool):
	tea_status.visible = active

func toggle():
	if dragging_item != null:
		cancel_drag()
	panel.visible = not panel.visible

func count():
	return items.size()

func counts_by_kind():
	var counts = {}
	for item in items:
		var kind = item.get_meta("fish_kind")
		counts[kind] = counts.get(kind,0)+1
	return counts

func clear():
	cancel_drag()
	for item in items:
		item.queue_free()
	items.clear()
	refresh_counter()

func fits(pos: Vector2, cells: Vector2i, ignore: Panel = null) -> bool:
	var grid = (pos-ORIGIN)/SLOT_SIZE
	if grid.x < 0 or grid.y < 0 or grid.x+cells.x > columns or grid.y+cells.y > GRID_SIZE:
		return false
	var candidate = Rect2(pos,Vector2(cells)*SLOT_SIZE)
	for item in items:
		if item == ignore:
			continue
		var other_pos = original_pos if item == dragging_item else item.position
		var other_cells: Vector2i = original_cells if item == dragging_item else item.get_meta("cells")
		if candidate.intersects(Rect2(other_pos,Vector2(other_cells)*SLOT_SIZE)):
			return false
	return true

func find_free_position(cells: Vector2i) -> Vector2:
	for y in range(GRID_SIZE-cells.y+1):
		for x in range(columns-cells.x+1):
			var pos = ORIGIN+Vector2(x,y)*SLOT_SIZE
			if fits(pos,cells):
				return pos
	return Vector2(-1,-1)

func has_room_for(cells: Vector2i):
	return find_free_position(cells).x >= 0 or find_free_position(Vector2i(cells.y,cells.x)).x >= 0

func add_fish(kind):
	var cells: Vector2i = FishData.types[kind]["tamanho"]
	var pos = find_free_position(cells)
	var rotated = false
	if pos.x < 0:
		cells = Vector2i(cells.y,cells.x)
		pos = find_free_position(cells)
		rotated = true
	if pos.x < 0:
		return false
	return create_fish(kind, pos, cells, rotated)

func restore_fish(record: Dictionary) -> bool:
	var kind = record.get("kind", "")
	if not FishData.types.has(kind):
		return false
	var rotated: bool = record.get("rotated", false)
	var cells: Vector2i = FishData.types[kind]["tamanho"]
	if rotated:
		cells = Vector2i(cells.y, cells.x)
	var pos: Vector2 = record.get("pos", Vector2(-1,-1))
	if not fits(pos, cells):
		return false
	return create_fish(kind, pos, cells, rotated)

func create_fish(kind, pos: Vector2, cells: Vector2i, rotated: bool) -> bool:
	var item = Panel.new()
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.set_meta("fish_kind",kind)
	item.set_meta("cells",cells)
	item.set_meta("rotated",rotated)
	var tint: Color = COLORS[kind]
	item.add_theme_stylebox_override("panel",style(Color(tint,0.16),Color(tint,0.85)))
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = ICONS[kind]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(icon)
	var dim = Label.new()
	dim.name = "Dimensions"
	dim.add_theme_font_size_override("font_size",11)
	dim.add_theme_color_override("font_color",tint)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(dim)
	panel.add_child(item)
	item.position = pos
	items.append(item)
	layout_item(item)
	refresh_counter()
	return true

func layout_item(item: Panel):
	var cells: Vector2i = item.get_meta("cells")
	var rotated: bool = item.get_meta("rotated")
	item.size = Vector2(cells)*SLOT_SIZE-Vector2(2,2)
	var icon: TextureRect = item.get_node("Icon")
	var area = item.size-Vector2(8,16)
	icon.size = Vector2(area.y,area.x) if rotated else area
	icon.pivot_offset = icon.size/2
	icon.rotation = PI/2 if rotated else 0.0
	icon.position = Vector2(item.size.x/2,(item.size.y-10)/2)-icon.size/2
	var dim: Label = item.get_node("Dimensions")
	dim.text = "%d×%d" % [cells.x,cells.y]
	dim.position = Vector2(4,item.size.y-17)

func is_over(pos):
	return panel.visible and panel.get_global_rect().has_point(pos)

func is_dragging():
	return dragging_item != null

func try_start_drag(pos):
	if not panel.visible or dragging_item != null:
		return false
	for item in items:
		if item.get_global_rect().has_point(pos):
			dragging_item = item
			original_pos = item.position
			original_cells = item.get_meta("cells")
			original_rotated = item.get_meta("rotated")
			drag_offset = pos-item.global_position
			item.z_index = 2
			drag_to(pos)
			return true
	return false

func snap_to_grid() -> Vector2:
	return ORIGIN+((dragging_item.position-ORIGIN)/SLOT_SIZE).round()*SLOT_SIZE

func drag_to(pos):
	if dragging_item == null:
		return
	dragging_item.position = pos-panel.global_position-drag_offset
	var cells: Vector2i = dragging_item.get_meta("cells")
	var candidate = snap_to_grid()
	var tint = Color("8cc5a4") if fits(candidate,cells,dragging_item) else Color("ef6868")
	preview.position = candidate
	preview.size = Vector2(cells)*SLOT_SIZE-Vector2(2,2)
	preview.add_theme_stylebox_override("panel",style(Color(tint,0.3),tint))
	preview.show()
	dragging_item.modulate.a = 0.72

func rotate_drag(pos: Vector2):
	if dragging_item == null:
		return
	var cells: Vector2i = dragging_item.get_meta("cells")
	dragging_item.set_meta("cells",Vector2i(cells.y,cells.x))
	dragging_item.set_meta("rotated",not dragging_item.get_meta("rotated"))
	layout_item(dragging_item)
	drag_offset = dragging_item.size/2
	drag_to(pos)

func cancel_drag():
	if dragging_item == null:
		return
	dragging_item.position = original_pos
	dragging_item.set_meta("cells",original_cells)
	dragging_item.set_meta("rotated",original_rotated)
	layout_item(dragging_item)
	finish_drag()

func finish_drag():
	dragging_item.z_index = 0
	dragging_item.modulate.a = 1.0
	dragging_item = null
	preview.hide()
	refresh_counter()

func end_drag():
	if dragging_item == null:
		return
	var candidate = snap_to_grid()
	if not fits(candidate,dragging_item.get_meta("cells"),dragging_item):
		cancel_drag()
		return
	dragging_item.position = candidate
	finish_drag()
	changed.emit()

func set_columns(n: int) -> bool:
	if n == columns:
		return true
	cancel_drag()
	for item in items:
		var c: Vector2i = item.get_meta("cells")
		if (item.position.x-ORIGIN.x)/SLOT_SIZE+c.x > n:
			return false
	for slot in slots:
		slot.queue_free()
	slots.clear()
	columns = n
	panel.position.x = 930 - (n-6)*48
	panel.size.x = 320 + (n-6)*48
	track.size.x = n*48
	close_button.position.x = panel.size.x-42
	for y in range(6):
		for x in range(n):
			var slot = Panel.new()
			slot.position = ORIGIN + Vector2(x,y)*SLOT_SIZE
			slot.size = Vector2(46,46)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_theme_stylebox_override("panel", style(Color(0.75,0.84,0.82,0.07), Color(0.76,0.82,0.81,0.28),2))
			panel.add_child(slot)
			panel.move_child(slot,0)
			slots.append(slot)
	refresh_counter()
	return true

func open_context(pos: Vector2) -> bool:
	if not panel.visible or is_dragging():
		return false
	for item in items:
		if item.get_global_rect().has_point(pos):
			selected = item
			context.position = Vector2i(pos)
			context.popup()
			return true
	return false

func context_action(id: int):
	if not is_instance_valid(selected) or not items.has(selected):
		return
	var data = FishData.types[selected.get_meta("fish_kind")]
	if id == 2:
		confirm.dialog_text = "Descartar %s definitivamente?" % data["nome"]
		confirm.popup_centered()
	elif id == 0:
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "%s | R$%d" % [data["nome"],data["valor"]]
		panel.add_child(dialog)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
	elif id == 1:
		var c: Vector2i = selected.get_meta("cells")
		var rotated = Vector2i(c.y,c.x)
		if fits(selected.position,rotated,selected):
			selected.set_meta("cells",rotated)
			selected.set_meta("rotated",not selected.get_meta("rotated"))
			layout_item(selected)
			changed.emit()

func take_one(kind: String) -> bool:
	for item in items:
		if item.get_meta("fish_kind") == kind:
			selected = item
			discard_selected()
			return true
	return false

func discard_selected():
	if is_instance_valid(selected) and items.has(selected):
		items.erase(selected)
		selected.queue_free()
		selected = null
		refresh_counter()
		changed.emit()
