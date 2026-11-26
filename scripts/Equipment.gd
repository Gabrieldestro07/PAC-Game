extends Node

const PRODUCTS = {
	"clock": ["Relógio amaldiçoado",250,"Barra decai 15% mais devagar; menos botas; bônus de raridade até 20s"],
	"glasses": ["Óculos espectrais",500,"Revela o Peixe Fantasma"],
	"bamboo": ["Vara de bambu",100,"+10% de progresso por acerto"],
	"worm": ["Minhoca",3,"Melhora a chance de peixes melhores"],
	"bread": ["Massa de pão",15,"+5% de progresso por acerto"],
	"bag": ["Mochila reforçada",300,"Inventário 7 × 6"],
	"tea": ["Chá de camomila",500,"Bônus passivo · comerciante 8% mais lento"]
}
var game
var menu: Panel
var shop: Panel
var equipment: Panel
var button: Button
var balance: Label
var owned = {"bamboo":false,"bag":false,"tea":false,"worm":0,"bread":0}
var glasses_on = false
var rod = "wood"
var bag = "basic"
var bait = "none"
var accessory_slots = [false,false,false,false]
var accessories = ["","","",""]
var attempt_bonus = 0.0

func style(bg: Color, edge: Color) -> StyleBoxFlat:
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.10,0.055,0.15,bg.a) if Travel.region == 2 else bg
	st.border_color = Color(0.42,0.25,0.55,edge.a) if Travel.region == 2 else edge
	st.set_border_width_all(1)
	st.set_corner_radius_all(5)
	return st

func panel_at(pos: Vector2, dimensions: Vector2) -> Panel:
	var panel = Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.z_index = 8
	panel.add_theme_stylebox_override("panel",style(Color(0.06,0.10,0.13,0.83),Color(0.76,0.82,0.81,0.65)))
	game.add_child(panel)
	panel.hide()
	return panel

func label_at(parent: Node, txt: String, pos: Vector2, font_size: int = 15) -> Label:
	var l = Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size",font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func btn(parent: Node, txt: String, pos: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var b = Button.new()
	b.text = txt
	b.position = pos
	b.size = dimensions
	b.add_theme_stylebox_override("normal",style(Color(0.13,0.23,0.21,0.75),Color(0.48,0.65,0.58,0.8)))
	b.add_theme_stylebox_override("hover",style(Color(0.24,0.39,0.32,0.85),Color(0.65,0.85,0.72)))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func setup(main):
	game = main
	button = btn(game,"Equipamentos",Vector2(775,46),Vector2(180,50),toggle_equipment)
	button.z_index = 3
	balance = label_at(game,"",Vector2(965,12),16)
	balance.z_index = 3
	refresh_money()
	menu = panel_at(Vector2(380,210),Vector2(520,220))
	shop = panel_at(Vector2(340,100),Vector2(600,500))
	equipment = panel_at(Vector2(900,104),Vector2(350,520))
	label_at(menu,"COMERCIANTE",Vector2(20,14),22)
	label_at(menu,"O que vamos negociar hoje, pescador?",Vector2(20,54))
	btn(menu,"Vender peixes",Vector2(20,95),Vector2(230,62),sell)
	btn(menu,"Comprar itens",Vector2(270,95),Vector2(230,62),open_shop)
	btn(menu,"Voltar ao jogo",Vector2(150,174),Vector2(220,32),close_all)

func refresh_money():
	balance.text = "Dinheiro: R$%d" % game.money

func modal_open() -> bool:
	return menu.visible or shop.visible

func is_over(pos: Vector2) -> bool:
	return button.get_global_rect().has_point(pos) or (equipment.visible and equipment.get_global_rect().has_point(pos))

func close_all():
	menu.hide()
	shop.hide()
	equipment.hide()

func open_menu():
	game.inventory.cancel_drag()
	game.inventory.panel.hide()
	close_all()
	menu.show()

func sell():
	close_all()
	game.start_sale()

func clear_children(parent: Node):
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func open_shop():
	menu.hide()
	clear_children(shop)
	label_at(shop,"LOJA · CAVERNA" if Travel.region == 2 else "LOJA · FASE 1",Vector2(20,14),22)
	label_at(shop,"Saldo: R$%d" % game.money,Vector2(20,45))
	var y = 82
	for key in (["clock","glasses","worm","bread","bag"] if Travel.region == 2 else ["bamboo","worm","bread","bag","tea"]):
		var data = PRODUCTS[key]
		label_at(shop,data[0],Vector2(20,y),17)
		label_at(shop,data[2],Vector2(20,y+25),13)
		var consumable = key == "worm" or key == "bread"
		var purchased = not consumable and owned.get(key,false)
		var b = btn(shop,"Adquirido" if purchased else "R$%d · Comprar" % data[1],Vector2(415,y),Vector2(165,43),buy.bind(key))
		b.disabled = purchased or game.money < data[1]
		y += 72
	btn(shop,"Voltar",Vector2(20,450),Vector2(150,32),open_menu)
	shop.show()

func buy(key: String):
	var price: int = PRODUCTS[key][1]
	var consumable = key == "worm" or key == "bread"
	if game.money < price or (not consumable and owned.get(key,false)):
		return
	game.money -= price
	if consumable:
		owned[key] += 1
	else:
		owned[key] = true
		if key == "clock": accessory_slots[0] = true
		if key == "tea": game.inventory.set_tea_active(true)
	refresh_money()
	game.save_progress()
	open_shop()

func toggle_equipment():
	if game.is_fishing() or game.tictactoe.active or modal_open():
		return
	if equipment.visible:
		equipment.hide()
		return
	game.inventory.cancel_drag()
	game.inventory.panel.hide()
	show_equipment()

func show_equipment():
	clear_children(equipment)
	label_at(equipment,"EQUIPAMENTOS",Vector2(16,12),20)
	btn(equipment,"×",Vector2(305,8),Vector2(30,30),equipment.hide)
	label_at(equipment,"Óculos",Vector2(16,60))
	label_at(equipment,"Mochila",Vector2(180,60))
	var glasses = btn(equipment,"Espectrais" if glasses_on else "Vazio",Vector2(16,84),Vector2(150,68),toggle_glasses)
	glasses.disabled = not owned.get("glasses",false)
	btn(equipment,"Reforçada" if bag == "bag" else "Inicial",Vector2(180,84),Vector2(150,68),change_bag)
	label_at(equipment,"Vara de pesca",Vector2(16,168))
	label_at(equipment,"Isca",Vector2(180,168))
	btn(equipment,"Bambu" if rod == "bamboo" else "Madeira",Vector2(16,192),Vector2(150,68),change_rod)
	var bait_name = "Sem isca"
	if bait != "none":
		bait_name = PRODUCTS[bait][0] + " (%d)" % owned[bait]
	btn(equipment,bait_name,Vector2(180,192),Vector2(150,68),change_bait)
	label_at(equipment,"Acessórios adicionais",Vector2(16,280),17)
	for i in range(4):
		var b = btn(equipment,"Bloq." if not accessory_slots[i] else ("Relógio" if accessories[i] == "clock" else "Livre"),Vector2(16+i*81,310),Vector2(74,58),change_accessory.bind(i))
		b.disabled = not accessory_slots[i]
	label_at(equipment,"Bônus ativos",Vector2(16,390),17)
	label_at(equipment,"Capacidade: %d slots" % (game.inventory.columns*6),Vector2(16,420))
	label_at(equipment,"Progresso: +%d%%" % ((10 if rod == "bamboo" else 0)+(5 if bait == "bread" else 0)),Vector2(16,445))
	label_at(equipment,"Iscas: %d minhoca · %d pão" % [owned["worm"],owned["bread"]],Vector2(16,470))
	equipment.show()

func change_bag():
	if not owned["bag"]:
		return
	var next = "basic" if bag == "bag" else "bag"
	if game.inventory.set_columns(7 if next == "bag" else 6):
		bag = next
	else:
		game.info.text = "Libere a coluna extra antes de trocar a mochila."
	game.save_progress()
	show_equipment()

func change_rod():
	if owned["bamboo"]:
		rod = "wood" if rod == "bamboo" else "bamboo"
	game.save_progress()
	show_equipment()

func change_bait():
	var choices = ["none"]
	for key in ["worm","bread"]:
		if owned[key] > 0:
			choices.append(key)
	bait = choices[(choices.find(bait)+1)%choices.size()]
	game.save_progress()
	show_equipment()

func change_accessory(i: int):
	if accessory_slots[i] and owned.get("clock",false) and i == 0:
		accessories[i] = "" if accessories[i] == "clock" else "clock"
	game.save_progress()
	show_equipment()

func tea_bonus() -> float:
	return 0.08 if owned.get("tea", false) else 0.0

func available_bait() -> String:
	return bait if owned.get(bait, 0) > 0 else "none"

func consume_bait() -> String:
	var used = available_bait()
	attempt_bonus = 0.10 if rod == "bamboo" else 0.0
	if used != "none":
		owned[used] -= 1
		if used == "bread":
			attempt_bonus += 0.05
		if owned[used] == 0:
			bait = "none"
	return used

func toggle_glasses():
	glasses_on = not glasses_on
	game.save_progress()
	show_equipment()
