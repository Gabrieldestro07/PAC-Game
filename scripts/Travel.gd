extends CanvasLayer
var unlocked = false
var region = 1
var show_diary_next = false
var busy = false
var overlay: ColorRect
var mat: ShaderMaterial
var data = {}
var dev_mode = false
var normal_data = {}
var normal_unlocked = false
func enable_dev():
 if dev_mode: return
 normal_data = data.duplicate(true)
 normal_unlocked = unlocked
 data = data.duplicate(true)
 dev_mode = true
 unlocked = true
 data["unlocked"] = true
func disable_dev():
 if not dev_mode: return
 data = normal_data.duplicate(true)
 unlocked = normal_unlocked
 dev_mode = false
 region = 1

func _ready():
 layer = 100
 var f = FileAccess.open("user://journey.save", FileAccess.READ)
 if not f:
  f = FileAccess.open("user://journey.backup", FileAccess.READ)
 if f:
  var saved = f.get_var()
  if saved is Dictionary:
   data = saved
 unlocked = data.get("unlocked", false)
 overlay = ColorRect.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter = Control.MOUSE_FILTER_STOP
 var shader = Shader.new()
 shader.code = "shader_type canvas_item; uniform float radius = 1.0; void fragment(){ float d=length((UV-vec2(0.5))*vec2(1.0,0.5625)); COLOR=vec4(0.0,0.0,0.0,smoothstep(radius-0.035,radius+0.035,d)); }"
 mat = ShaderMaterial.new()
 mat.shader = shader
 overlay.material = mat
 add_child(overlay)
 overlay.hide()
func save():
 data["unlocked"] = unlocked
 if dev_mode: return
 var f = FileAccess.open("user://journey.tmp", FileAccess.WRITE)
 if not f:
  push_warning("Não foi possível salvar o progresso.")
  return
 f.store_var(data)
 f.flush()
 var error = f.get_error()
 f.close()
 if error != OK:
  push_warning("Erro ao gravar o progresso.")
  return
 var dir = DirAccess.open("user://")
 if dir.file_exists("journey.save"):
  if dir.file_exists("journey.backup"):
   dir.remove("journey.backup")
  if dir.rename("journey.save", "journey.backup") != OK:
   return
 if dir.rename("journey.tmp", "journey.save") != OK:
  push_warning("Erro ao finalizar o salvamento.")
func close_iris():
 busy = true
 overlay.show()
 var t = create_tween()
 t.tween_method(func(v): mat.set_shader_parameter("radius",v), 1.0,-0.05,0.7)
 await t.finished
func open_iris():
 var t = create_tween()
 t.tween_method(func(v): mat.set_shader_parameter("radius",v), -0.05,1.0,0.7)
 await t.finished
 overlay.hide()
 busy = false
func go(path: String):
 if busy: return
 await close_iris()
 get_tree().change_scene_to_file(path)
 await get_tree().process_frame
 await open_iris()
