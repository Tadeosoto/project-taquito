class_name EstaminaEspecial
extends Node
# El aguante de los ataques especiales de la espada (JJ, 2026-11-16): machacar el golpe con
# brinco era la mejor estrategia y le quitaba variedad a la pelea. El tajo cargado, el giro
# aereo y la estocada aerea gastan un tercio cada uno; sin aguante no salen.
# Modelo hibrido: se llena solo y constante (LLENA_EN s de vacio a lleno) despues de ESPERA s
# sin gastar (como la stamina de Souls o Zelda), y cada espadazo o punetazo normal que pega
# suma POR_ACIERTO (como el medidor de Devil May Cry): mezclar el combo te los devuelve antes.
# Hijo del Player (Player._ready): existe en toda escena donde haya jugador, con su barra
# bajo la de vida. Empieza lleno en cada escena.

const SEGMENTOS := 3
const GASTO := 1.0 / SEGMENTOS
const LLENA_EN := 10.0          # s de vacio a lleno
const ESPERA := 1.0             # s despues de gastar antes de empezar a llenarse
const POR_ACIERTO := 0.04       # lo que suma un golpe normal que pega (~8 por segmento)
const PARPADEO := 0.4           # s que parpadea en rojo cuando no alcanza
const ANCHO := 110.0            # como la barra de vida (Supervivencia.BARRA_TAMANO)
const ALTO := 4.0
const COLOR := Color(1.0, 0.55, 0.12)       # naranja monarca (Player.CARGA_COLOR)
const COLOR_LLENO := Color(1.0, 0.78, 0.3)  # el segmento ya completo, un poco mas claro
const COLOR_NO := Color(0.9, 0.12, 0.08)

var jugador: Player
var valor := 1.0                # 0 a 1
# Para pruebas (tecla del safehouse) y, despues, las tachas de M7c: nunca se gasta
var infinita := false
# Arriba a la izquierda, bajo la barra de vida de Supervivencia (10, 10). La arena de la Madre
# tiene su propia caja de vida y la baja (PruebaLombrices)
var lugar := Vector2(10.0, 20.0):
	set(v):
		lugar = v
		if _caja:
			_caja.position = v

var _espera := 0.0
var _parpadeo := 0.0
var _capa: CanvasLayer
var _caja: Control
var _fondo: ColorRect
var _relleno: ColorRect
var _rayas: Array[ColorRect] = []


func _ready() -> void:
	_armar_barra()


# Hay para un especial
func alcanza() -> bool:
	return infinita or valor >= GASTO - 0.001


# Cobra un especial. Sin aguante regresa false, parpadea y suena el error: el especial no sale
func gastar() -> bool:
	if not alcanza():
		negar()
		return false
	if not infinita:
		valor = maxf(valor - GASTO, 0.0)
		_espera = ESPERA
	return true


# Un golpe normal que pego (Player._golpear sin giro)
func acierto() -> void:
	valor = minf(valor + POR_ACIERTO, 1.0)


# Lo pediste sin aguante: la barra parpadea en rojo y suena el error
func negar() -> void:
	_parpadeo = PARPADEO
	Sonidos.tocar(self, "ui_error", -8.0)


func _physics_process(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
	elif valor < 1.0:
		valor = minf(valor + delta / LLENA_EN, 1.0)
	_parpadeo = maxf(_parpadeo - delta, 0.0)
	_pintar()


func _armar_barra() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 8   # la de Supervivencia
	add_child(_capa)
	_caja = Control.new()
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja.position = lugar
	_capa.add_child(_caja)
	_fondo = ColorRect.new()
	_fondo.color = Color(0.0, 0.0, 0.0, 0.6)
	_fondo.position = -Vector2.ONE
	_fondo.size = Vector2(ANCHO, ALTO) + Vector2.ONE * 2.0
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja.add_child(_fondo)
	_relleno = ColorRect.new()
	_relleno.size = Vector2(ANCHO, ALTO)
	_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja.add_child(_relleno)
	# Las rayitas negras que parten la barra en tercios: cuantos especiales traes
	for i in range(1, SEGMENTOS):
		var raya := ColorRect.new()
		raya.color = Color.BLACK
		raya.position = Vector2(roundf(ANCHO * i / SEGMENTOS), 0.0)
		raya.size = Vector2(1.0, ALTO)
		raya.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caja.add_child(raya)
		_rayas.append(raya)
	var nombre := Label.new()
	nombre.text = "aguante"
	nombre.add_theme_font_size_override("font_size", 10)
	nombre.add_theme_color_override("font_color", COLOR)
	nombre.add_theme_color_override("font_outline_color", Color.BLACK)
	nombre.add_theme_constant_override("outline_size", 5)
	nombre.position = Vector2(ANCHO + 8.0, -7.0)
	_caja.add_child(nombre)
	_pintar()


func _pintar() -> void:
	if _caja == null:
		return
	# Sin especiales desbloqueados, o en la casa propia (sin pelea), no hay barra
	var hay := (Player.golpe_cargado or Player.giro_aereo) and (jugador == null or not jugador.sin_combate)
	_caja.visible = hay
	if not hay:
		return
	var v := 1.0 if infinita else valor
	_relleno.size.x = roundf(ANCHO * v)
	var lleno := v >= 1.0 - 0.001
	_relleno.color = COLOR_LLENO if lleno else COLOR
	# El parpadeo: rojo y negro alternados, el fondo tambien, para que se vea aunque este vacia
	var rojo := _parpadeo > 0.0 and int(_parpadeo * 12.0) % 2 == 0
	_fondo.color = Color(COLOR_NO, 0.8) if rojo else Color(0.0, 0.0, 0.0, 0.6)
	if rojo:
		_relleno.color = COLOR_NO
