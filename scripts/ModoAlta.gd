extends Node

# Prueba de 1080p sin perder la imagen PS1 (AG, 2026-11-19). Autoload "ModoAlta"; solo se prende
# con el argumento --alta (el juego normal sigue a 640 x 480 con stretch "viewport"):
#   godot --path . -- --alta                      (o cualquier escena: ... scenes/x.tscn -- --alta)
#   godot --path . -- --alta --completa           (pantalla completa)
# Lo que hace:
#   - la ventana a 1920 x 1080 y el stretch a "canvas_items": la UI y los textos se dibujan a la
#     resolucion de la pantalla, nitidos (con la misma distribucion, base 640 x 480, aspecto expand);
#   - el 3D se renderiza a ALTO_3D px de alto (Viewport.scaling_3d_scale), como hoy, y una capa
#     (shaders/pixeles_alta.gdshader) lo vuelve a juntar en cuadros duros, sin suavizado;
#   - el patron del dither (dittershader) se agranda igual (global pixel_bloque), para que sus
#     cuadritos midan lo de antes y no un pixel de 1080p.
# Lo que va en SubViewports (la pantalla de EL GORDO, las burbujas de los NPC) queda igual.

const TAMANO := Vector2i(1920, 1080)
const ALTO_3D := 480.0
const CAPA := -50                    # arriba del 3D, abajo de toda la UI (y del dither)

var activo := false
var _material: ShaderMaterial


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--alta"):
		activar(args.has("--completa"))


func activar(completa := false) -> void:
	activo = true
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if completa:
		w.mode = Window.MODE_FULLSCREEN
	else:
		w.size = TAMANO
		w.move_to_center()
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var capa := CanvasLayer.new()
	capa.layer = CAPA
	add_child(capa)
	var cuadro := ColorRect.new()
	cuadro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cuadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/pixeles_alta.gdshader")
	cuadro.material = _material
	capa.add_child(cuadro)
	w.size_changed.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	var tam := get_window().size
	if tam.y <= 0:
		return
	var escala := clampf(ALTO_3D / float(tam.y), 0.25, 1.0)
	get_viewport().scaling_3d_scale = escala
	var rejilla := (Vector2(tam) * escala).round()
	_material.set_shader_parameter("rejilla", rejilla)
	RenderingServer.global_shader_parameter_set("pixel_bloque", float(tam.y) / ALTO_3D)
