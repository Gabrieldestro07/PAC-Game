extends Control
var page: Control
var mode = "menu"
func _ready():
 if Travel.show_diary_next:
  Travel.show_diary_next = false
  show_diary()
 else:
  show_menu()
func picture(parent: Control, path: String):
 var r = TextureRect.new()
 r.texture = load(path)
 r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 r.size = Vector2(1280,720)
 r.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(r)
func hit(parent: Control, rect: Rect2, action: Callable, hint: String):
 var b = Button.new()
 b.position = rect.position
 b.size = rect.size
 b.tooltip_text = hint
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 for state in ["normal","pressed","focus"]:
  b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 var hover = StyleBoxFlat.new()
 hover.bg_color = Color(1,0.9,0.5,0.15)
 hover.set_corner_radius_all(8)
 b.add_theme_stylebox_override("hover",hover)
 b.pressed.connect(action)
 parent.add_child(b)
func reset():
 if is_instance_valid(page):
  remove_child(page)
  page.queue_free()
 page = Control.new()
 add_child(page)
func show_menu():
 mode = "menu"
 reset()
 picture(page,"res://ui/menu.png")
 hit(page,Rect2(180,335,390,90),show_diary,"Jogar")
 hit(page,Rect2(185,438,385,88),show_tutorial,"Tutorial")
 hit(page,Rect2(190,538,380,90),func(): get_tree().quit(),"Sair")
 var dev = Button.new()
 dev.text = "Modo DEV ativo · sair" if Travel.dev_mode else "Modo desenvolvedor"
 dev.position = Vector2(16,668)
 dev.size = Vector2(210,38)
 dev.pressed.connect(dev_access)
 page.add_child(dev)
func dev_access():
 if Travel.dev_mode:
  Travel.disable_dev()
  show_menu()
  return
 var dialog = ConfirmationDialog.new()
 dialog.title = "Modo desenvolvedor"
 dialog.ok_button_text = "Desbloquear"
 var field = LineEdit.new()
 field.secret = true
 field.placeholder_text = "Código de acesso"
 field.custom_minimum_size = Vector2(260,38)
 var message = Label.new()
 var content = VBoxContainer.new()
 content.add_child(field)
 content.add_child(message)
 dialog.add_child(content)
 dialog.dialog_hide_on_ok = false
 page.add_child(dialog)
 dialog.confirmed.connect(func():
  if field.text == "1234":
   Travel.enable_dev()
   dialog.hide()
   show_menu()
  else:
   message.text = "Código incorreto."
   field.clear()
   field.grab_focus()
 )
 field.text_submitted.connect(func(_value): dialog.confirmed.emit())
 dialog.canceled.connect(dialog.queue_free)
 dialog.popup_centered(Vector2i(320,150))
 field.grab_focus()
func show_diary():
 mode = "diary"
 reset()
 picture(page,"res://ui/diary_unlocked.png" if Travel.unlocked else "res://ui/diary.png")
 hit(page,Rect2(150,115,110,80),show_menu,"Voltar")
 hit(page,Rect2(235,205,385,115),func(): enter_first(),"Lugar Tranquilo")
 hit(page,Rect2(235,330,385,115),second,"Caverna Sombria")
 if Travel.data.get("crow_defeated", false):
  var l = Label.new()
  l.text = "Em desenvolvimento"
  l.position = Vector2(394,545)
  l.add_theme_color_override("font_color",Color("59351d"))
  l.add_theme_font_size_override("font_size",16)
  page.add_child(l)
 page.position.y = 720
 create_tween().tween_property(page,"position:y",0.0,0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func second():
 if not Travel.unlocked: return
 Travel.region = 2
 Travel.go("res://Main.tscn")
func enter_first():
 Travel.region = 1
 Travel.go("res://Main.tscn")
func tutorial_text(pos: Vector2, heading: String, body: String):
 var title = Label.new()
 title.position = pos
 title.size = Vector2(365,25)
 title.text = heading
 title.add_theme_color_override("font_color",Color("492a16"))
 title.add_theme_font_size_override("font_size",17)
 page.add_child(title)
 var l = Label.new()
 l.position = pos + Vector2(0,30)
 l.size = Vector2(365,310)
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_color_override("font_color",Color("492a16"))
 l.add_theme_font_size_override("font_size",12)
 l.text = body
 page.add_child(l)
func show_tutorial():
 mode = "tutorial"
 reset()
 picture(page,"res://ui/tutorial.png")
 tutorial_text(Vector2(235,205),"Controles","A e D movem o pescador. Espaço pula e Shift dá um dash na direção do movimento ou para onde você está olhando.\n\nClique com o botão esquerdo para interagir ou pescar. Em um ponto sem interação, o clique dá um golpe com a vara.\n\nPesque na ponta do píer ou na ponte da caverna. Aproxime-se do trem e dos personagens antes de clicar neles.\n\nNo inventário, arraste os itens, use R para girar e clique com o botão direito para descartar.")
 tutorial_text(Vector2(670,205),"Mecânicas","A pesca alterna entre contas e tensão. Na tensão, segure o botão esquerdo para aumentar a tensão e solte para aliviar. A captura avança na faixa verde móvel. Nas contas, demorar reduz as chances a partir de 15 segundos.\n\nUse os Óculos Espectrais para encontrar o Peixe Fantasma e ofereça um ao Corvo da Maldição para desafiá-lo.\n\nNa luta, observe os avisos e pule ou use o dash para esquivar. Todas as varas causam 1 de dano. O progresso é salvo automaticamente.")
 hit(page,Rect2(156,116,98,74),show_menu,"Voltar")
