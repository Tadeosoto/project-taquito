class_name EnjambreLombrices
extends Node3D
# Las crias de la Madre del Carcamo (MadreCarcamo.gd): `lombrices` x `puntos` puntos sueltos
# unidos por hilos, sin un solo collider (el truco de los cuerpos de Hitman). El estado vive en
# arreglos planos (pos, old_pos, links, vivos, modo, meta, uniones) y SolverLombrices los mueve en
# otro hilo; el nivel se hornea al empezar en un campo de distancia (CampoDistancia) dentro de una
# caja de `caja` m.
#
# Una "lombriz" es cualquier tramo de puntos vivos unidos: al cortarlas, cada mitad de 3 o mas
# puntos sigue sola (su primer punto es su cabeza) y vuelve a crecer tomando puntos muertos de su
# mismo bloque de `puntos` (nunca hay mas de lombrices x puntos). Cortar a lo loco las multiplica:
# lo que mata de veras es pegarle a la cabeza, la sal y el fuego.
#
# Rendimiento: el paso corre en otro hilo a `hz` pasos por segundo y el hilo principal NUNCA lo
# espera: si no ha terminado, se dibuja lo ultimo (interpolado entre las dos ultimas fotos) y se
# intenta en el siguiente cuadro de fisica. Los golpes que cambian los arreglos mientras el hilo
# corre se guardan como ordenes (`_ordenes`) y se aplican al recoger el paso. Las lombrices lejos
# del jugador se mueven un paso de cada tres (SolverLombrices.LEJOS/DORMIDA), y si aun asi el paso
# tarda mas de CALIDAD_ALTA ms, se quitan las mas lejanas hasta MINIMO lombrices.
#
# Lo que piensa cada lombriz (estado por cabeza, abajo) se decide aqui, en el hilo principal, y le
# llega al solver por punto como `modo` y `meta`:
#   RODEA: cada una va a su lugar en un anillo alrededor del jugador, que se cierra al acercarse.
#   ERGUIDA -> SALTA: se para (aviso, boca abierta) y se avienta; si te toca te muerde y se pega.
#   PEGADA: colgando de ti; te frena y te chupa vida. Rodar las avienta; curarte (Q) o la sal las
#           queman.
#   ENTERRADA -> (sale): se mete al piso, viaja por debajo y sale atras de ti (fase 2+).
#   LATIGO / COLA: 3-5 se funden en una sola que barre en circulo (fase 2+).
#   TORRE -> CAE: un monton sube en columna arriba de ti y se deja caer (fase 3).
#   INFECTA: montada en un zombi, que corre mas y te caza.
#   TREPA -> ACECHA (fase 2+): sube por una pared o pilar cercano, espera arriba y se te deja
#           caer encima cuando pasas abajo.
#   BOLA (fase 2+): 8-12 se anudan en una bola que se retuerce, rueda hacia ti y se te avienta;
#           pegarle (BOLA_VIDA) la deshace antes. Al romperse quedan ATONTADA un rato.
#   SUBE: si estas arriba (pasarela), suben por la rampa cuya punta queda mas cerca de ti
#           (`rampas`, las pone la escena); sin rampas, trepan un pilar o muro que llegue a tu
#           plataforma (CampoDistancia.trepaderos/plataforma). Ya en tu altura te siguen.
# Ademas: apuntan a donde vas a estar (te adelantan), arrancan a ratos a RAPIDO_X y, si hay
# muchas cerca, arrancan todas juntas (una oleada).

signal horneado
signal fase_cambio(fase: int)

const SOLVER := preload("res://scripts/lombrices/SolverLombrices.gd")
const ESTELA := preload("res://scripts/EstelaBarrido.gd")
const S := preload("res://scripts/lombrices/SolverLombrices.gd")

enum Estado { RODEA, ERGUIDA, SALTA, PEGADA, ENTERRADA, LATIGO, COLA, TORRE, CAE, INFECTA, TREPA, ACECHA,
	BOLA, ATONTADA, SUBE }

const ABAJO := 1.0              # m de la caja debajo del piso: el piso cae en un borde de celda
const PRESUPUESTO_HORNEO := 6000  # us por cuadro horneando
const GRUESO := 0.085           # m de radio de la carne (el punto mide S.RADIO)
const COLOR_CARNE := Color(0.5, 0.4, 0.37)
const COLOR_PIEL := Color(0.25, 0.27, 0.28)   # la piel de carbon de la Madre (shaders/madre.gdshader)
const COLOR_SANGRE := Color(0.38, 0.04, 0.05)
const COLOR_AGUA := Color(0.33, 0.36, 0.27)    # agua sucia, como la de los zombis
const COLOR_TIERRA := Color(0.3, 0.24, 0.18)
const ALTO_JUGADOR := 1.0       # del centro del jugador a sus pies
# Morder
const DANO := 3                 # tocarte con el cuerpo, cada CADA s
const CADA := 0.8
const TOCA := 0.2
const DANO_SALTO := 9
const SALTO_DESDE := 4.5        # m: de aqui se para para aventarse
const SALTO_ENFRIA := Vector2(1.8, 4.0)
const SALTO_MAX := 12           # paradas o volando a la vez
const ERGUIDA_DURA := 0.45      # el aviso
const SALTO_FUERZA := 9.0       # m/s
const SALTO_DURA := 0.7
const PEGADAS_MAX := 6
const PEGADA_FRENA := 0.08      # de tu velocidad, por cada una
const PEGADA_CHUPA := 4.0       # vida por segundo, cada una
# Rodear
const ANILLO_MAX := 3.5
# Enterrarse (fase 2+)
const ENTERRAR_PROB := 0.04     # por segundo, a las que estan lejos
const ENTERRADAS_MAX := 6
const HONDO := 0.55             # m bajo el piso
const SALE_ATRAS := 2.5         # m detras de ti
const TIERRA_CADA := 0.25
# Latigo (fase 2+)
const LATIGO_CADA := 9.0
const LATIGO_DURA := 5.0
const LATIGO_RADIO := 2.4
const LATIGO_GIRA := 1.6        # rad/s
const LATIGO_MAX := 2
# Torre (fase 3)
const TORRE_CADA := 16.0
const TORRE_PARTE := 0.4        # de las que estan cerca
const TORRE_SUBE := 2.6         # s subiendo
const TORRE_ALTO := 3.2
const TORRE_CAE := 0.7          # s hasta que pega
const TORRE_RADIO := 2.6        # m del golpe
const TORRE_DANO := 16
# Crecer
const CRECE_CADA := [1.6, 1.2, 0.8]   # s por fase
const CRECE_MAX := 24           # puntos por vez
# Armas
const EMPUJE_BALA := 7.0
const RADIO_BALA := 0.8
const EMPUJE_GOLPE := 6.0
const CORTES_POR_DANO := 0.34  # machete 12: 4 por machetazo
const CORTES_TAJO := 12         # el tajo cargado (todas): cuantas como mucho
const CORTES_MAX := 14
const ALTO_GOLPE := Vector2(-1.3, 1.0)
const PEDAZO_MINIMO := 3
# Zonas (ZonaLombrices.gd)
const SAL_CADA := 0.8           # s: la sal se come una cabeza por lombriz cada esto
const FUEGO_CADA := 0.25        # s: el fuego le quema la cola (un punto) a cada lombriz adentro
const EMPUJE_ZONA := 3.0
# Infectar zombis
const INFECTA_PROB := 0.3
const INFECTA_DESDE := 0.9
const CHORROS := 8
# Amenaza
const ADELANTA_MAX := 1.2       # s: apuntan a donde vas a estar en hasta esto
const ARRANQUE_DURA := 0.5      # s de arranque (RAPIDO) a ratos, rodeando
const ARRANQUE_PROB := 0.35     # por segundo
const OLA_CADA := Vector2(6.0, 10.0)
const OLA_JUNTAS := 15          # crias a menos de OLA_CERCA m para que arranquen todas
const OLA_CERCA := 8.0
const OLA_DURA := 2.0
const TREPA_CADA := 4.0         # s entre intentos de emboscada (fase 2+)
const TREPA_MAX := 3
const TREPA_ALTO := 2.2         # m arriba del piso donde se quedan acechando
const ACECHA_DESDE := 3.0       # m (en planta): se deja caer si pasas tan cerca
const ACECHA_DURA := 9.0
# Bola de lombrices (fase 2+)
const BOLA_CADA := Vector2(15.0, 25.0)
const BOLA_CUANTAS := Vector2i(8, 12)
const BOLA_JUNTAS := 8.0         # m entre las que se juntan
const BOLA_LEJOS := Vector2(4.0, 14.0)   # m del jugador para que se arme
const BOLA_RADIO := 0.6
const BOLA_JUNTA := 1.0          # s anudandose (el aviso)
const BOLA_VEL := 5.0            # m/s rodando
const BOLA_SALTA_DESDE := 3.0
const BOLA_SALTA := 0.45         # s del brinco
const BOLA_DANO := 18
const BOLA_VIDA := 40.0
const BOLA_RUEDA_MAX := 6.0
const BOLA_SAL := 8.0            # de vida por tick de sal
const BOLA_FUEGO := 6.0
const ATONTADA_DURA := 1.5
# Subir a la pasarela
const SUBE_DESDE := 1.2          # m que estas mas arriba que ella
const SUBE_MAX := 10.0
const CARGA_RAMPA := 1.5        # m de mas que cuesta una rampa por cada cria que ya va subiendo por ella
# Efectos: lo menos que pasa entre dos hojas iguales (un tajo corta 12 y no salen 12 hojas)
const FX_ESPERA := {"cria_corte": 80, "cria_cabeza": 100, "pegada_mordida": 200,
	"pegada_suelta": 300, "madre_tierra": 300, "torre_golpe": 500}
# Rendimiento
const PASO_MAX := 0.05          # s: si el hilo tardo, el siguiente paso no avanza mas que esto
const LEJOS_DESDE := 14.0       # m: mas lejos, una lombriz que solo rodea duerme 2 de cada 3 pasos
const CALIDAD_ALTA := 22.0      # ms del paso (de 33 a 30/s): arriba de esto por CALIDAD_ESPERA s quita lombrices
const CALIDAD_ESPERA := 2.0
const CALIDAD_QUITA := 6        # lombrices por vez, las mas lejanas
const MINIMO := 40              # nunca menos lombrices que esto por calidad
const GOTAS_CHORRO := 24

@export var lombrices := 80
@export var puntos := 12
@export var caja := Vector3(24.0, 5.0, 24.0)
@export var celda := 0.25
# Archivo donde guardar el campo horneado ("" = hornear siempre). Lleva la firma de la geometria
# (CampoDistancia.firma): si el lugar cambia, se hornea otra vez solo
@export var guardar_campo := ""
@export var hornear_al_entrar := true   # la escena de prueba; el safehouse hornea al soltarlas
# El paso corre en otro hilo (WorkerThreadPool) mientras el juego sigue; se recoge el cuadro
# siguiente. Lo que se ve y lo que preguntan las armas es `vista`, la foto del ultimo paso.
@export var en_hilo := true
@export var hz := 30.0          # pasos de fisica por segundo (se dibujan interpolados)
@export var lento_ms := 0       # para probar: el paso tarda al menos esto (simula una PC lenta)
# 1: rodean y saltan; 2: + se entierran y se funden en latigo; 3: + torre y crecen mas rapido.
# Sola (sin Madre) va en 3, para ver todo
@export var fase := 3:
	set(valor):
		if valor != fase:
			fase = valor
			fase_cambio.emit(fase)

var pos := PackedVector3Array()
var old_pos := PackedVector3Array()
var links := PackedByteArray()
var vivos := PackedByteArray()
var modo := PackedByteArray()
var meta := PackedVector3Array()
var uniones := PackedInt32Array()
var vista := PackedVector3Array()
var solver: SolverLombrices
var campo := CampoDistancia.new()
var horneando := false
var ms_solver := 0.0
var ms_pensar := 0.0
var ms_horneo := 0.0
var ms_pintar := 0.0
var quitadas := 0               # lombrices que quito la calidad automatica
var vivos_total := 0
var piso := 0.0                 # altura del piso donde se soltaron
var cuenta := {"saltos": 0, "pegadas": 0, "cortes": 0, "crecidas": 0, "enterradas": 0,
	"latigos": 0, "torres": 0, "cabezas": 0, "quemadas": 0, "saladas": 0, "infectados": 0, "paridas": 0,
	"arranques": 0, "olas": 0, "trepas": 0, "emboscadas": 0, "bolas": 0, "bolas_rotas": 0,
	"subidas": 0, "subieron": 0}

var _jugador: Node3D
var _salud: Node
var _malla_seg: MultiMesh
var _malla_cab: MultiMesh
var _malla_esp: MultiMesh
var _buf_esp := PackedFloat32Array()
var _buf_seg := PackedFloat32Array()
var _buf_cab := PackedFloat32Array()
var _soltar_en := Vector3.INF
var _toca_espera := 0.0
var _chorros: Array[GPUParticles3D] = []
var _siguiente_chorro := 0
var _horneo_desde := 0
var _espera := 0                # cuadros antes de hornear: lo recien puesto aun no esta en la fisica
var _tarea := -1
var _antes := PackedVector3Array()   # la foto anterior a `vista`, para interpolar
var _recogido := 0              # ms en que se recogio la ultima foto
var _intervalo := 1.0 / 30.0    # s entre las dos ultimas fotos
var _acumulado := 0.0
var _ordenes: Array[Callable] = []
var _paso_n := 0
var _ema := 0.0
var _calidad_t := 0.0
var _ciclo: Node
var _t := 0.0
# Por punto: la cabeza de su lombriz, y por cabeza: su cola y su estado
var _cabeza_de := PackedInt32Array()
var _cola := PackedInt32Array()
var _cabezas := PackedInt32Array()
var _era_cabeza := PackedByteArray()
var _estado := PackedByteArray()
var _reloj := PackedFloat32Array()
var _enfria := PackedFloat32Array()
var _angulo := PackedFloat32Array()
var _base := PackedVector3Array()        # donde se paro, a donde va enterrada, el ancla...
var _zombi := {}                         # cabeza -> el zombi que monta
var _latigos: Array[PackedInt32Array] = []   # cabezas de cada latigo, la primera manda
var _latigo_t := 0.0
var _torre_t := 0.0
var _torre_en := Vector3.INF
var _torre_reloj := -1.0
var _torre_pego := false
var _anillo_torre: MeshInstance3D
var _crece_t := 0.0
var _sal_t := 0.0
var _fuego_t := 0.0
var _chupa := 0.0
var _zombis_t := 0.0
var _tierra_t := 0.0
var _disolviendo := false
var _libreta_t := 0.0
var _remedio_muertes := 0
var _arranque := PackedFloat32Array()
var _ola_t := 8.0
var _trepa_t := 0.0
var _fx_ultimo := {}
var _sonido_t := 0
# La bola (una a la vez): sus cabezas, en que va, su centro y su vida
var _bola := PackedInt32Array()
var _bola_fase := 0              # 0 nada, 1 se junta, 2 rueda, 3 brinca
var _bola_t := 0.0
var _bola_sig := 18.0
var _bola_centro := Vector3.ZERO
var _bola_desde := Vector3.ZERO
var _bola_hasta := Vector3.ZERO
var _bola_giro := 0.0
var _bola_vida := 0.0
var _bola_pego := false
var _bola_aura: Node3D
# Pies de pilares y muros (CampoDistancia.trepaderos) y a donde va a subir cada lombriz
var _trepaderos := PackedVector3Array()
var _trepa_hacia := PackedVector3Array()
var _subir := PackedVector3Array()
# Rampas de la escena: [pie, punta] por rampa (PruebaLombrices las registra)
var rampas: Array = []
# Medio lado del eje de un mezzanine cuadrado alrededor del centro (la escena; 0 = no hay): arriba
# contigo te siguen por el anillo, de esquina en esquina, en vez de irse derecho por el hueco
var anillo := 0.0
var _por_rampa := PackedInt32Array()  # por cabeza: la rampa que va subiendo (-1 = pilar)
var _firma := 0
var _plataforma := {}            # CampoDistancia.plataforma de donde estas parado
var _plataforma_de := -1         # la celda de tus pies con la que se calculo
var _utiles := PackedInt32Array() # trepaderos cuyo pilar o muro llega a tu plataforma


func _ready() -> void:
	add_to_group("lombrices")
	solver = SOLVER.new()
	solver.puntos_por_lombriz = puntos
	_salud = get_node_or_null("/root/Salud")
	_armar_mallas()
	_armar_sangre()
	_armar_anillo()
	if hornear_al_entrar:
		soltar(global_position)


# Hornea el campo alrededor de `centro` (a la altura del piso) y suelta ahi el enjambre
func soltar(centro: Vector3) -> void:
	_esperar()
	_soltar_en = centro
	piso = centro.y
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	var excluir: Array[RID] = []
	if _jugador is CollisionObject3D:
		excluir.append((_jugador as CollisionObject3D).get_rid())
	campo.preparar(centro - Vector3(caja.x / 2.0, ABAJO, caja.z / 2.0), caja, celda, excluir)
	horneando = true
	_espera = 2
	_horneo_desde = Time.get_ticks_msec()
	_vaciar()


# Vuelve a armar el enjambre completo sin hornear de nuevo (la pelea se reinicia)
func rearmar() -> void:
	_esperar()
	if campo.listo:
		_armar(_soltar_en)


func _vaciar() -> void:
	pos.resize(0)
	old_pos.resize(0)
	links.resize(0)
	vivos.resize(0)
	modo.resize(0)
	meta.resize(0)
	vista.resize(0)
	uniones.resize(0)
	_latigos.clear()
	_soltar_pegadas()
	_malla_seg.visible_instance_count = 0
	_malla_esp.visible_instance_count = 0
	_malla_cab.visible_instance_count = 0


func _exit_tree() -> void:
	_esperar()
	_soltar_pegadas()


# Espera de veras al hilo: solo al soltar, rearmar o salir (cosas raras)
func _esperar() -> void:
	if _tarea != -1:
		_recoger()
	_aplicar_ordenes()


# Recoge un paso ya terminado: la foto vieja pasa a `_antes` para interpolar
func _recoger() -> void:
	if _tarea != -1:
		WorkerThreadPool.wait_for_task_completion(_tarea)
		_tarea = -1
	_antes = vista
	vista = pos.duplicate()
	var ahora := Time.get_ticks_msec()
	_intervalo = clampf((ahora - _recogido) / 1000.0, 0.01, 0.25)
	_recogido = ahora


func _ocupado() -> bool:
	return _tarea != -1


func _aplicar_ordenes() -> void:
	if _ordenes.is_empty():
		return
	var ordenes := _ordenes
	_ordenes = []
	for orden in ordenes:
		orden.call()


func _paso(delta: float) -> void:
	var t := Time.get_ticks_usec()
	solver.step(pos, old_pos, links, vivos, modo, meta, uniones, delta, campo)
	if lento_ms > 0:
		while Time.get_ticks_usec() - t < lento_ms * 1000:
			pass
	ms_solver = (Time.get_ticks_usec() - t) / 1000.0


func _armar(centro: Vector3) -> void:
	var total := lombrices * puntos
	pos.resize(total)
	old_pos.resize(total)
	meta.resize(total)
	links.resize(total)
	modo.resize(total)
	modo.fill(0)
	_era_cabeza.resize(total)
	_era_cabeza.fill(0)
	_estado.resize(total)
	_estado.fill(0)
	vivos.resize(total)
	_reloj.resize(total)
	_reloj.fill(0.0)
	_enfria.resize(total)
	_angulo.resize(total)
	_arranque.resize(total)
	_arranque.fill(0.0)
	_subir.resize(total)
	_por_rampa.resize(total)
	_romper_bola(false)
	_bola_sig = randf_range(BOLA_CADA.x, BOLA_CADA.y)
	_base.resize(total)
	_cabeza_de.resize(total)
	_cola.resize(total)
	vivos.fill(1)
	uniones.resize(0)
	_latigos.clear()
	_zombi.clear()
	var radio := minf(caja.x, caja.z) * 0.3
	for w in lombrices:
		var donde := centro + Vector3(randf_range(-radio, radio), 0.4 + randf() * 0.6, randf_range(-radio, radio))
		var rumbo := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		for k in puntos:
			var i := w * puntos + k
			pos[i] = donde - rumbo * k * S.LARGO
			old_pos[i] = pos[i]
			meta[i] = pos[i]
			links[i] = 1 if k < puntos - 1 else 0
		_angulo[w * puntos] = randf() * TAU
		_enfria[w * puntos] = randf_range(SALTO_ENFRIA.x, SALTO_ENFRIA.y)
	vivos_total = total
	_disolviendo = false
	quitadas = 0
	vista = pos.duplicate()
	_antes = vista
	solver.reiniciar()
	for clave in cuenta:
		cuenta[clave] = 0
	_buf_seg.resize(total * 20)
	_buf_cab.resize(total * 20)


# El campo ya esta (horneado o cargado del archivo): suelta el enjambre
func _listo_campo(como: String) -> void:
	horneando = false
	ms_horneo = Time.get_ticks_msec() - _horneo_desde
	print("Lombrices: campo %dx%dx%d %s en %d ms" % [campo.nx, campo.ny, campo.nz, como, ms_horneo])
	_armar(_soltar_en)
	var t := campo.trepaderos(piso)
	_trepaderos = t[0]
	_trepa_hacia = t[1]
	horneado.emit()


func _physics_process(delta: float) -> void:
	if horneando:
		if _espera > 0:
			_espera -= 1
			# Ya con todo en la fisica: si ya se habia horneado este mismo lugar, se carga
			if _espera == 0 and not guardar_campo.is_empty():
				_firma = CampoDistancia.firma(get_tree(), campo.origen, campo.tamano())
				if campo.cargar(guardar_campo, _firma):
					_listo_campo("cargado")
			return
		if campo.hornear_paso(get_world_3d().direct_space_state, PRESUPUESTO_HORNEO):
			if not guardar_campo.is_empty():
				campo.guardar(guardar_campo, _firma)
			_listo_campo("horneado")
		return
	if vivos.is_empty():
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	# Con el jugador congelado (tienda, dron, inventario) no se mueven
	if _jugador and not _jugador.is_physics_processing():
		return
	_acumulado += delta
	# Nunca se espera al hilo: si no ha terminado, se dibuja lo que hay y se vuelve a ver luego
	if _tarea != -1:
		if not WorkerThreadPool.is_task_completed(_tarea):
			_pintar()
			return
		_recoger()
	if _acumulado < 1.0 / hz:
		_pintar()
		return
	delta = minf(_acumulado, PASO_MAX)
	_acumulado = 0.0
	_t += delta
	var t := Time.get_ticks_usec()
	_aplicar_ordenes()
	_tramos()
	if _disolviendo:
		# Murio la Madre: se deshacen unas cuantas por cuadro
		for h in _cabezas.slice(0, 6):
			_matar_tramo(h, "")
		_tramos()
	_pensar(delta)
	_zonas(delta)
	_crecer(delta)
	_morder(delta)
	_dormir_lejanas()
	_calidad(delta)
	ms_pensar = (Time.get_ticks_usec() - t) / 1000.0
	if _jugador:
		solver.obstaculo = _jugador.global_position
		solver.obstaculo_activo = true
	if en_hilo:
		_tarea = WorkerThreadPool.add_task(_paso.bind(delta), true, "Lombrices")
	else:
		_paso(delta)
		_recoger()
	_pintar()


# Las que solo rodean lejos del jugador se mueven un paso de cada LEJOS_CADA (con ese dt)
func _dormir_lejanas() -> void:
	if _jugador == null:
		return
	_paso_n += 1
	var yo := _jugador.global_position
	var lejos2 := LEJOS_DESDE * LEJOS_DESDE
	for h in _cabezas:
		if _estado[h] != Estado.RODEA or pos[h].distance_squared_to(yo) < lejos2:
			continue
		var bits := S.LEJOS
		if (h / puntos + _paso_n) % S.LEJOS_CADA != 0:
			bits |= S.DORMIDA
		for i in range(h, _cola[h] + 1):
			modo[i] |= bits


# Si el paso tarda mucho (PC lenta), quita sin ruido las lombrices mas lejanas
func _calidad(delta: float) -> void:
	_ema = lerpf(_ema, ms_solver, 0.1)
	if _ema < CALIDAD_ALTA or _jugador == null or _cabezas.size() <= MINIMO:
		_calidad_t = 0.0
		return
	_calidad_t += delta
	if _calidad_t < CALIDAD_ESPERA:
		return
	_calidad_t = 0.0
	var yo := _jugador.global_position
	var lejanas := Array(_cabezas)
	lejanas.sort_custom(func(a: int, b: int) -> bool:
		return pos[a].distance_squared_to(yo) > pos[b].distance_squared_to(yo))
	for h: int in lejanas.slice(0, mini(CALIDAD_QUITA, _cabezas.size() - MINIMO)):
		for i in range(h, _cola[h] + 1):
			_matar(i)
		quitadas += 1
	_tramos()


# --- Tramos: quien es cabeza de quien ---

func _tramos() -> void:
	_cabezas.clear()
	var n := vivos.size()
	var i := 0
	while i < n:
		if vivos[i] == 0:
			_cabeza_de[i] = -1
			_era_cabeza[i] = 0
			i += 1
			continue
		var h := i
		while i + 1 < n and links[i] == 1 and vivos[i + 1] == 1:
			_cabeza_de[i] = h
			if i != h:
				_era_cabeza[i] = 0
			i += 1
		_cabeza_de[i] = h
		if i != h:
			_era_cabeza[i] = 0
		_cola[h] = i
		if _era_cabeza[h] == 0:
			# Cabeza nueva (la mitad de atras de un corte): empieza rodeando
			_era_cabeza[h] = 1
			_estado[h] = Estado.RODEA
			_reloj[h] = 0.0
			_enfria[h] = randf_range(SALTO_ENFRIA.x, SALTO_ENFRIA.y)
			_angulo[h] = randf() * TAU
		_cabezas.append(h)
		i += 1


func _largo(h: int) -> int:
	return _cola[h] - h + 1


# Sin la Madre se mueren todas (MadreCarcamo.muerta)
func disolver() -> void:
	_disolviendo = true


func biomasa() -> float:
	return float(vivos_total) / maxf(vivos.size(), 1.0)


# --- Lo que piensa cada lombriz ---

func _pensar(delta: float) -> void:
	if _jugador == null:
		for h in _cabezas:
			_escribir(h, S.CABEZA, global_position)
		return
	var yo := _jugador.global_position
	var pies := yo - Vector3.UP * ALTO_JUGADOR
	var corriendo := 0
	var enterradas := 0
	var pegadas := 0
	for h in _cabezas:
		var e := _estado[h]
		if e == Estado.ERGUIDA or e == Estado.SALTA:
			corriendo += 1
		elif e == Estado.ENTERRADA:
			enterradas += 1
		elif e == Estado.PEGADA:
			pegadas += 1
	# A donde vas: tu velocidad por lo que tardarian en llegar (hasta ADELANTA_MAX s)
	var vel: Vector3 = _jugador.velocity if _jugador is CharacterBody3D else Vector3.ZERO
	vel.y = 0.0
	var adelante := pies
	_pensar_ola(delta, yo)
	_pensar_trepa(delta, yo)
	# La libreta: las viste si alguna anda a menos de 15 m
	_libreta_t -= delta
	if _libreta_t <= 0.0:
		_libreta_t = 1.0
		for h in _cabezas:
			if pos[h].distance_squared_to(yo) < 225.0:
				_nota("ver", "crias")
				break
	_pensar_bola(delta, yo, pies, vel)
	# Estas arriba (pasarela) y parado: las de abajo buscan por donde subir
	var estas_arriba: bool = _jugador.is_on_floor() if _jugador is CharacterBody3D else false
	var rueda: bool = _jugador.get("_rodada_t") != null and _jugador._rodada_t >= 0.0
	var curando: bool = _jugador.get("_curando") != null and _jugador._curando > 0.0
	_validar_latigos()
	_latigo_t += delta
	if fase >= 2 and _latigo_t >= LATIGO_CADA and _latigos.size() < LATIGO_MAX:
		_latigo_t = 0.0
		_armar_latigo(yo)
	_pensar_torre(delta, yo, pies)
	_zombis_t -= delta
	var buscar_zombis := _zombis_t <= 0.0
	if buscar_zombis:
		_zombis_t = 0.5
	for h in _cabezas:
		var e := _estado[h]
		_reloj[h] += delta
		_enfria[h] -= delta
		var p := pos[h]
		var hacia := yo - p
		var plano := Vector2(hacia.x, hacia.z).length()
		adelante = pies + vel * minf(plano / S.VELOCIDAD, ADELANTA_MAX)
		match e:
			Estado.RODEA:
				# Un lugar en el anillo, que se cierra conforme llega, alrededor de donde VAS a estar
				var r := minf(plano * 0.6, ANILLO_MAX)
				var lugar := adelante + Vector3(cos(_angulo[h]), 0.3, sin(_angulo[h])) * r
				# Arriba contigo (pasarela angosta): derecho a ti, sin anillo, o se caen por la orilla
				if pies.y - piso > SUBE_DESDE and absf(p.y - pies.y) < 0.8:
					lugar = _por_anillo(p, pies) + Vector3.UP * 0.3
				_arranque[h] -= delta
				if _arranque[h] <= 0.0 and randf() < ARRANQUE_PROB * delta:
					_arranque[h] = ARRANQUE_DURA
					cuenta.arranques += 1
				_escribir(h, S.CABEZA | (S.RAPIDO if _arranque[h] > 0.0 else 0), lugar)
				if estas_arriba and pies.y - p.y > SUBE_DESDE and _empezar_subida(h, pies):
					continue
				if _largo(h) >= 4 and plano < SALTO_DESDE and _enfria[h] <= 0.0 and corriendo < SALTO_MAX:
					_estado[h] = Estado.ERGUIDA
					_reloj[h] = 0.0
					_base[h] = p
					corriendo += 1
				elif fase >= 2 and plano > 5.0 and enterradas < ENTERRADAS_MAX and randf() < ENTERRAR_PROB * delta:
					_estado[h] = Estado.ENTERRADA
					_reloj[h] = 0.0
					_base[h] = Vector3(p.x, piso - HONDO, p.z)
					enterradas += 1
					cuenta.enterradas += 1
				elif buscar_zombis and randf() < INFECTA_PROB:
					_buscar_zombi(h)
			Estado.ERGUIDA:
				# El aviso: la cabeza arriba, la boca abierta
				var arriba := _base[h] + Vector3.UP * 0.55 + hacia.normalized() * 0.15
				_escribir(h, S.CABEZA, arriba)
				modo[h] = S.CABEZA | S.AIRE
				for k in range(1, mini(3, _largo(h))):
					modo[h + k] = S.AIRE
					meta[h + k] = _base[h] + Vector3.UP * (0.3 / k)
				if _reloj[h] >= ERGUIDA_DURA:
					_estado[h] = Estado.SALTA
					_reloj[h] = 0.0
					cuenta.saltos += 1
					var dt := 1.0 / hz
					var dir := (yo - p).normalized() + Vector3.UP * 0.35
					for k in mini(5, _largo(h)):
						old_pos[h + k] = pos[h + k] - dir.normalized() * SALTO_FUERZA * dt * (1.0 - k * 0.15)
			Estado.SALTA:
				_escribir(h, S.LIBRE, yo)
				if _toca_jugador(p, 0.15):
					if not _jugador.has_method("esquivando") or not _jugador.esquivando():
						_jugador.recibir_dano(DANO_SALTO, p)
						var bloquea: bool = _jugador.get("_bloqueando") == true
						if not bloquea and pegadas < PEGADAS_MAX:
							_pegar(h)
							pegadas += 1
							continue
					_rebotar(h, yo)
				elif _reloj[h] >= SALTO_DURA:
					_volver(h)
			Estado.PEGADA:
				if rueda:
					_rebotar(h, yo)
					pegadas -= 1
					continue
				if curando:
					_matar_tramo(h, "quemadas")
					continue
				var ancla := _ancla(h)
				_escribir(h, S.LIBRE, ancla)
				modo[h] = S.CABEZA | S.ANCLA
				meta[h] = ancla
			Estado.ENTERRADA:
				_pensar_enterrada(h, delta, yo)
			Estado.LATIGO, Estado.COLA:
				pass   # _pensar_latigos
			Estado.TORRE, Estado.CAE:
				pass   # _pensar_torre
			Estado.TREPA:
				# Sube por la pared que tiene junto
				_escribir(h, S.CABEZA, _base[h])
				if p.y > piso + TREPA_ALTO:
					_estado[h] = Estado.ACECHA
					_reloj[h] = 0.0
					_base[h] = p
				elif _reloj[h] > 5.0:
					_volver(h)
			Estado.ACECHA:
				# Quieta arriba hasta que pasas abajo; entonces se deja caer encima
				_escribir(h, S.CABEZA, _base[h])
				if plano < ACECHA_DESDE and p.y > yo.y - 0.5:
					var dt := 1.0 / hz
					var cae := (yo - p).normalized() * 6.0 + Vector3.DOWN * 2.0
					for i in range(h, _cola[h] + 1):
						old_pos[i] = pos[i] - cae * dt
					_escribir(h, S.LIBRE, yo)
					_estado[h] = Estado.SALTA
					_reloj[h] = 0.0
					cuenta.emboscadas += 1
				elif _reloj[h] > ACECHA_DURA:
					_volver(h)
			Estado.BOLA:
				pass   # _pensar_bola
			Estado.ATONTADA:
				_escribir(h, S.LIBRE, p)
				if _reloj[h] > ATONTADA_DURA:
					_volver(h)
			Estado.SUBE:
				var falta := pies.y - p.y
				# Por rampa solo se acaba en la punta (ver abajo); por pilar, al llegar a tu altura
				if falta < 0.3 and _por_rampa[h] < 0:
					cuenta.subieron += 1
					_volver(h)
				elif _reloj[h] > SUBE_MAX:
					_volver(h)
				elif _por_rampa[h] >= 0:
					# Al pie de la rampa y luego hasta su punta: se arrastran por la cuesta
					var pie_r: Vector3 = rampas[_por_rampa[h]][0]
					var punta: Vector3 = rampas[_por_rampa[h]][1]
					var al_pie_r := Vector2(p.x - pie_r.x, p.z - pie_r.z).length()
					var meta_r := pie_r if al_pie_r > 1.0 and p.y < piso + 0.3 else punta + (punta - pie_r).normalized() * 0.8
					_escribir(h, S.CABEZA | (S.RAPIDO if _arranque[h] > 0.0 else 0), meta_r + Vector3.UP * 0.2)
					# Ya en la pasarela: pasando la punta, no a media rampa (se iban por la orilla)
					var fin := punta + (punta - pie_r).normalized() * 0.6
					if p.y > punta.y - 0.3 and Vector2(p.x - fin.x, p.z - fin.z).length() < 0.7:
						cuenta.subieron += 1
						_volver(h)
				else:
					var pie := _subir[h]
					var al_pie := Vector2(p.x - pie.x, p.z - pie.z).length()
					# Primero al pie del pilar; ya ahi, contra el pilar y para arriba (el solver trepa)
					var meta_ := pie if al_pie > 0.7 and p.y < piso + 0.4 else \
						pie + _subir_hacia(h) * 1.0 + Vector3.UP * (falta + 1.0)
					_escribir(h, S.CABEZA, meta_)
			Estado.INFECTA:
				var z: Node3D = _zombi.get(h)
				if z == null or not is_instance_valid(z) or not z.is_inside_tree() \
						or (z is Zombie and (z as Zombie).estado == Zombie.Estado.MUERTO):
					_zombi.erase(h)
					_volver(h)
				else:
					var lomo := z.global_position + Vector3.UP * 1.35 - z.global_basis.z * 0.25
					_escribir(h, S.LIBRE, lomo)
					modo[h] = S.CABEZA | S.ANCLA
					meta[h] = lomo
	_pensar_latigos(delta, yo)
	# Las pegadas te frenan y te chupan
	var frenan := 0
	for h in _cabezas:
		if _estado[h] == Estado.PEGADA:
			frenan += 1
	if _jugador.get("lastres") != null:
		if frenan > 0:
			_jugador.lastres["lombrices"] = maxf(1.0 - PEGADA_FRENA * frenan, 0.4)
		else:
			_jugador.lastres.erase("lombrices")
	if frenan > 0 and _salud:
		_chupa += PEGADA_CHUPA * frenan * delta
		if _chupa >= 1.0:
			_salud.vida -= int(_chupa)
			_chupa -= int(_chupa)


# Pone a toda la lombriz `h` en `bits` rumbo a `objetivo` (la cabeza) y el cuerpo detras
func _escribir(h: int, bits: int, objetivo: Vector3) -> void:
	var cola := _cola[h]
	modo[h] = bits | S.CABEZA
	meta[h] = objetivo
	var cuerpo := bits & ~S.CABEZA
	for i in range(h + 1, cola + 1):
		modo[i] = cuerpo
		# El cuerpo sigue al de adelante cuando va por el aire o enterrado; por el piso, a la meta
		meta[i] = pos[i - 1] if cuerpo & (S.AIRE | S.BAJO_TIERRA) else objetivo


func _toca_jugador(p: Vector3, de_mas: float) -> bool:
	var yo := _jugador.global_position
	if absf(p.y - yo.y) > ALTO_JUGADOR + de_mas:
		return false
	var r := solver.obstaculo_radio + S.RADIO + de_mas
	return Vector2(p.x - yo.x, p.z - yo.z).length_squared() < r * r


func _volver(h: int) -> void:
	_estado[h] = Estado.RODEA
	_reloj[h] = 0.0
	_enfria[h] = randf_range(SALTO_ENFRIA.x, SALTO_ENFRIA.y)


func _rebotar(h: int, yo: Vector3) -> void:
	if _estado[h] == Estado.PEGADA:
		_fx("pegada_suelta", pos[h], pos[h] - yo, 0.6)
	var dt := 1.0 / hz
	var fuera := pos[h] - yo
	fuera.y = 0.0
	fuera = fuera.normalized() * 4.0 + Vector3.UP * 3.0
	for i in range(h, _cola[h] + 1):
		old_pos[i] = pos[i] - fuera * dt
	_escribir(h, S.LIBRE, pos[h])
	_volver(h)


func _pegar(h: int) -> void:
	_estado[h] = Estado.PEGADA
	_reloj[h] = 0.0
	cuenta.pegadas += 1
	_fx("pegada_mordida", pos[h], Vector3.ZERO, 0.6)
	_nota("pelear", "crias")
	# Un lugar en tu cuerpo, en tu espacio: se mueve contigo
	var a := randf() * TAU
	_base[h] = Vector3(cos(a) * 0.42, randf_range(-0.35, 0.55), sin(a) * 0.42)


func _ancla(h: int) -> Vector3:
	var cuerpo: Node3D = _jugador.get("frijol") if _jugador.get("frijol") else _jugador
	return _jugador.global_position + cuerpo.global_basis.orthonormalized() * _base[h]


func _soltar_pegadas() -> void:
	if _jugador and is_instance_valid(_jugador) and _jugador.get("lastres") != null:
		_jugador.lastres.erase("lombrices")


func pegadas() -> int:
	var n := 0
	for h in _cabezas:
		if _estado[h] == Estado.PEGADA:
			n += 1
	return n


# --- Enterradas: bajan, van por debajo hasta atras de ti y salen ---

func _pensar_enterrada(h: int, delta: float, yo: Vector3) -> void:
	var p := pos[h]
	var atras: Vector3 = -_jugador.frijol.global_basis.z if _jugador.get("frijol") else Vector3.BACK
	atras.y = 0.0
	var sale := yo - atras.normalized() * SALE_ATRAS
	if _reloj[h] < 0.6:
		# Primero para abajo, en su lugar
		_escribir(h, S.BAJO_TIERRA, _base[h])
	else:
		_escribir(h, S.BAJO_TIERRA, Vector3(sale.x, piso - HONDO, sale.z))
		if Vector2(p.x - sale.x, p.z - sale.z).length() < 0.6 or _reloj[h] > 8.0:
			# Revienta para arriba: el campo la empuja fuera del piso y la avienta hacia ti
			var dt := 1.0 / hz
			var dir := (yo - p).normalized() * 3.0 + Vector3.UP * 6.0
			for i in range(h, _cola[h] + 1):
				pos[i] = Vector3(pos[i].x, maxf(pos[i].y, piso - 0.2), pos[i].z)
				old_pos[i] = pos[i] - dir * dt
			_escribir(h, S.LIBRE, yo)
			_tierra(Vector3(p.x, piso, p.z), 1.0)
			_fx("madre_tierra", Vector3(p.x, piso, p.z), Vector3.ZERO, 0.45)
			_estado[h] = Estado.SALTA
			_reloj[h] = 0.0
			return
	_tierra_t -= delta
	if _tierra_t <= 0.0 and p.y < piso:
		_tierra_t = TIERRA_CADA
		_tierra(Vector3(p.x, piso, p.z), 0.3)


# --- Latigo: varias en fila que barren en circulo ---

func _armar_latigo(yo: Vector3) -> void:
	var libres: Array[int] = []
	for h in _cabezas:
		if _estado[h] == Estado.RODEA and _largo(h) >= 5 and pos[h].distance_to(yo) < 9.0:
			libres.append(h)
	if libres.size() < 3:
		return
	libres.shuffle()
	var lider := libres[0]
	libres.sort_custom(func(a: int, b: int) -> bool:
		return pos[a].distance_squared_to(pos[lider]) < pos[b].distance_squared_to(pos[lider]))
	var cadena := PackedInt32Array()
	for h in libres.slice(0, randi_range(3, 5)):
		cadena.append(h)
		_estado[h] = Estado.COLA
		_reloj[h] = 0.0
	_estado[cadena[0]] = Estado.LATIGO
	_angulo[cadena[0]] = atan2(pos[cadena[0]].z - yo.z, pos[cadena[0]].x - yo.x)
	_latigos.append(cadena)
	cuenta.latigos += 1


# Un latigo se deshace si se acaba el tiempo o le cortan una cabeza
func _validar_latigos() -> void:
	uniones.resize(0)
	for n in range(_latigos.size() - 1, -1, -1):
		var cadena := _latigos[n]
		var sano := _reloj[cadena[0]] < LATIGO_DURA
		for h in cadena:
			if vivos[h] == 0 or _cabeza_de[h] != h or not (_estado[h] == Estado.LATIGO or _estado[h] == Estado.COLA):
				sano = false
		if not sano:
			for h in cadena:
				if vivos[h] == 1 and _cabeza_de[h] == h:
					_volver(h)
			_latigos.remove_at(n)
			continue
		for k in cadena.size() - 1:
			uniones.append(_cola[cadena[k]])
			uniones.append(cadena[k + 1])


func _pensar_latigos(delta: float, yo: Vector3) -> void:
	for cadena in _latigos:
		var lider := cadena[0]
		_angulo[lider] += LATIGO_GIRA * delta
		var punto := yo - Vector3.UP * (ALTO_JUGADOR - 0.2) + Vector3(cos(_angulo[lider]), 0.0, sin(_angulo[lider])) * LATIGO_RADIO
		_escribir(lider, S.RAPIDO, punto)
		for k in range(1, cadena.size()):
			var h := cadena[k]
			_escribir(h, S.LIBRE, pos[_cola[cadena[k - 1]]])
			modo[h] = 0   # sin CABEZA: la arrastra el de adelante
		# El latigo pega con todo el cuerpo
		for h in cadena:
			for i in range(h, _cola[h] + 1, 3):
				if _toca_jugador(pos[i], 0.0):
					_jugador.recibir_dano(DANO_SALTO, pos[i], 1.5)
					break


# --- Torre: suben en columna arriba de ti y se dejan caer ---

func _pensar_torre(delta: float, yo: Vector3, pies: Vector3) -> void:
	_torre_t += delta
	if _torre_reloj < 0.0:
		if fase >= 3 and _torre_t >= TORRE_CADA:
			_torre_t = 0.0
			var cerca: Array[int] = []
			for h in _cabezas:
				if _estado[h] == Estado.RODEA and pos[h].distance_to(yo) < 10.0:
					cerca.append(h)
			if cerca.size() >= 6:
				cerca.shuffle()
				for h in cerca.slice(0, maxi(6, int(cerca.size() * TORRE_PARTE))):
					_estado[h] = Estado.TORRE
					_reloj[h] = 0.0
				_torre_en = pies
				_torre_reloj = 0.0
				_torre_pego = false
				cuenta.torres += 1
		_anillo_torre.visible = false
		return
	_torre_reloj += delta
	_anillo_torre.visible = true
	_anillo_torre.global_position = _torre_en + Vector3.UP * 0.02
	var crece := clampf(_torre_reloj / (TORRE_SUBE + TORRE_CAE), 0.15, 1.0)
	_anillo_torre.scale = Vector3(TORRE_RADIO, 1.0, TORRE_RADIO) * crece
	var sube := _torre_reloj < TORRE_SUBE
	var dt := 1.0 / hz
	for h in _cabezas:
		var e := _estado[h]
		if e == Estado.TORRE:
			if sube:
				var alto := TORRE_ALTO * clampf(_torre_reloj / TORRE_SUBE, 0.2, 1.0)
				var giro := _angulo[h] + _torre_reloj * 2.0
				var punto := _torre_en + Vector3(cos(giro) * 0.45, alto, sin(giro) * 0.45)
				_escribir(h, S.AIRE, punto)
			else:
				# Se dejan caer sobre donde estabas (ya no te siguen: hay que moverse)
				_estado[h] = Estado.CAE
				var cae := (_torre_en - pos[h]) * Vector3(1.5, 0.0, 1.5) + Vector3.DOWN * 7.0
				for i in range(h, _cola[h] + 1):
					old_pos[i] = pos[i] - cae * dt
				_escribir(h, S.LIBRE, _torre_en)
		elif e == Estado.CAE:
			_escribir(h, S.LIBRE, _torre_en)
	if not sube and not _torre_pego and _torre_reloj >= TORRE_SUBE + TORRE_CAE:
		_torre_pego = true
		var d := Vector2(yo.x - _torre_en.x, yo.z - _torre_en.z).length()
		if d < TORRE_RADIO:
			_jugador.recibir_dano(int(TORRE_DANO * (1.0 - d / TORRE_RADIO * 0.5)), _torre_en, 2.0)
		_tierra(_torre_en, 1.5)
		sangrar(_torre_en + Vector3.UP * 0.3, Vector3.UP, 1.0)
		_fx("torre_golpe", _torre_en, Vector3.ZERO, 1.4)
		Sonidos.tocar(self, "retumbo", -4.0, 1.2)
	if _torre_reloj >= TORRE_SUBE + TORRE_CAE + 0.6:
		_torre_reloj = -1.0
		for h in _cabezas:
			if _estado[h] == Estado.TORRE or _estado[h] == Estado.CAE:
				_volver(h)


# --- Subir hasta ti ---

# Arriba en el mezzanine: si estas en otro lado del anillo, primero a la esquina de su lado que
# deja el camino mas corto (derecho se iban por el hueco del centro)
func _por_anillo(p: Vector3, pies: Vector3) -> Vector3:
	if anillo <= 0.0:
		return pies
	var c := _soltar_en if _soltar_en != Vector3.INF else global_position
	var yo := _lado_anillo(p - c)
	if yo == _lado_anillo(pies - c):
		return pies
	var esquinas: Array[Vector3] = []
	for s in [-1.0, 1.0]:
		match yo:
			0, 1: esquinas.append(Vector3(anillo if yo == 0 else -anillo, 0.0, s * anillo))
			_: esquinas.append(Vector3(s * anillo, 0.0, anillo if yo == 2 else -anillo))
	var mejor := pies
	var menos := INF
	for e in esquinas:
		var punto := Vector3(c.x + e.x, p.y, c.z + e.z)
		var d := p.distance_to(punto) + punto.distance_to(pies)
		if d < menos:
			menos = d
			mejor = punto
	return mejor


# 0 = +x, 1 = -x, 2 = +z, 3 = -z
func _lado_anillo(d: Vector3) -> int:
	if absf(d.x) > absf(d.z):
		return 0 if d.x > 0.0 else 1
	return 2 if d.z > 0.0 else 3


# Escoge un pie de pilar o muro que de veras llegue a donde estas parado (su columna toca tu
# plataforma: la pasarela con sus pilares, no el muro de enfrente), cerca de ti y repartidos
func _empezar_subida(h: int, pies: Vector3) -> bool:
	if not rampas.is_empty():
		# La que deja el camino mas corto (hasta el pie, y arriba de la punta a ti; con anillo,
		# por las orillas del cuadro) contando las que ya van subiendo por cada una: asi no se
		# amontonan todas en la mas cercana
		var subiendo := PackedInt32Array()
		subiendo.resize(rampas.size())
		for otra in _cabezas:
			if _estado[otra] == Estado.SUBE and _por_rampa[otra] >= 0:
				subiendo[_por_rampa[otra]] += 1
		var mejor := 0
		var menos := INF
		for k in rampas.size():
			var pie: Vector3 = rampas[k][0]
			var punta: Vector3 = rampas[k][1]
			var arriba := absf(punta.x - pies.x) + absf(punta.z - pies.z) if anillo > 0.0 else punta.distance_to(pies)
			var costo := pos[h].distance_to(pie) + arriba + subiendo[k] * CARGA_RAMPA
			if costo < menos:
				menos = costo
				mejor = k
		_por_rampa[h] = mejor
		_estado[h] = Estado.SUBE
		_reloj[h] = 0.0
		cuenta.subidas += 1
		return true
	_por_rampa[h] = -1
	if _trepaderos.is_empty():
		return false
	var mia := campo.celda_xz(pies)
	if mia != _plataforma_de:
		_plataforma_de = mia
		_plataforma = campo.plataforma(pies)
		_utiles.clear()
		for k in _trepaderos.size():
			if _plataforma.has(campo.celda_xz(_trepaderos[k] + _trepa_hacia[k] * campo.celda)):
				_utiles.append(k)
	if _utiles.is_empty():
		return false
	var mejores: Array[int] = []
	var distancias: Array[float] = []
	for k in _utiles:
		var t := _trepaderos[k]
		var d := Vector2(t.x - pies.x, t.z - pies.z).length_squared()
		if mejores.size() < 6:
			mejores.append(k)
			distancias.append(d)
		else:
			var peor := distancias.find(distancias.max())
			if d < distancias[peor]:
				mejores[peor] = k
				distancias[peor] = d
	var k := mejores[(h / puntos) % mejores.size()]
	_subir[h] = _trepaderos[k]
	_estado[h] = Estado.SUBE
	_reloj[h] = 0.0
	cuenta.subidas += 1
	return true


func _subir_hacia(h: int) -> Vector3:
	var k := _trepaderos.find(_subir[h])
	return _trepa_hacia[k] if k >= 0 else Vector3.ZERO


# --- La bola ---

func _pensar_bola(delta: float, yo: Vector3, pies: Vector3, vel: Vector3) -> void:
	if _bola_fase == 0:
		_bola_sig -= delta
		if fase >= 2 and _bola_sig <= 0.0:
			_bola_sig = randf_range(BOLA_CADA.x, BOLA_CADA.y)
			_armar_bola(yo)
		return
	# Las que se le cortaron o mataron ya no cuentan
	var siguen := PackedInt32Array()
	for h in _bola:
		if vivos[h] == 1 and _cabeza_de[h] == h and _estado[h] == Estado.BOLA:
			siguen.append(h)
	_bola = siguen
	if _bola.size() < 3 or _bola_vida <= 0.0:
		_romper_bola(true)
		return
	_bola_t += delta
	var piso_bola := piso + BOLA_RADIO
	match _bola_fase:
		1:
			if _bola_t >= BOLA_JUNTA:
				_bola_fase = 2
				_bola_t = 0.0
		2:
			var hacia := Vector3(pies.x - _bola_centro.x, 0.0, pies.z - _bola_centro.z)
			var paso := minf(BOLA_VEL * delta, hacia.length())
			if hacia.length() > 0.01:
				_bola_centro += hacia.normalized() * paso
			_bola_centro.y = move_toward(_bola_centro.y, piso_bola, delta * 3.0)
			_bola_giro += paso / BOLA_RADIO
			if hacia.length() < BOLA_SALTA_DESDE:
				_bola_fase = 3
				_bola_t = 0.0
				_bola_desde = _bola_centro
				_bola_hasta = pies + vel * 0.3 + Vector3.UP * BOLA_RADIO
				_bola_pego = false
			elif _bola_t > BOLA_RUEDA_MAX:
				_romper_bola(true)
				return
		3:
			var u := clampf(_bola_t / BOLA_SALTA, 0.0, 1.0)
			_bola_centro = _bola_desde.lerp(_bola_hasta, u) + Vector3.UP * sin(PI * u) * 1.4
			_bola_giro += delta * 12.0
			if not _bola_pego and _bola_centro.distance_to(yo) < BOLA_RADIO + 0.7:
				_bola_pego = true
				_jugador.recibir_dano(BOLA_DANO, _bola_centro, 2.5)
			if u >= 1.0:
				_fx("torre_golpe", Vector3(_bola_centro.x, _bola_hasta.y - BOLA_RADIO, _bola_centro.z), Vector3.ZERO, 0.7)
				_tierra(_bola_centro, 0.8)
				_romper_bola(true)
				return
	_colocar_bola()
	if _bola_aura:
		_bola_aura.global_position = Vector3(_bola_centro.x, _bola_centro.y - BOLA_RADIO, _bola_centro.z)


func _armar_bola(yo: Vector3) -> void:
	var libres: Array[int] = []
	for h in _cabezas:
		var d := pos[h].distance_to(yo)
		if _estado[h] == Estado.RODEA and _largo(h) >= 4 and d > BOLA_LEJOS.x and d < BOLA_LEJOS.y:
			libres.append(h)
	if libres.size() < BOLA_CUANTAS.x:
		return
	var semilla: int = libres.pick_random()
	libres.sort_custom(func(a: int, b: int) -> bool:
		return pos[a].distance_squared_to(pos[semilla]) < pos[b].distance_squared_to(pos[semilla]))
	var juntas := libres.filter(func(h: int) -> bool: return pos[h].distance_to(pos[semilla]) < BOLA_JUNTAS)
	if juntas.size() < BOLA_CUANTAS.x:
		return
	_bola = PackedInt32Array(juntas.slice(0, randi_range(BOLA_CUANTAS.x, BOLA_CUANTAS.y)))
	var centro := Vector3.ZERO
	for h in _bola:
		_estado[h] = Estado.BOLA
		_reloj[h] = 0.0
		centro += pos[h]
	centro /= _bola.size()
	_bola_centro = Vector3(centro.x, piso + BOLA_RADIO, centro.z)
	_bola_fase = 1
	_bola_t = 0.0
	_bola_vida = BOLA_VIDA
	_bola_giro = 0.0
	cuenta.bolas += 1
	if Sonidos.turno("rugido_corto"):
		Sonidos.tocar(self, "rugido_corto", -4.0, 0.6)
	_bola_aura = EfectosPixel.cuadro_bucle("madre_niebla", 0.6, 0.8, 0.0, false, true)
	if _bola_aura:
		get_parent().add_child(_bola_aura)


# Cada punto de la bola en su lugar de una esfera (Fibonacci) que gira; las cabezas salen
func _colocar_bola() -> void:
	var total := 0
	for h in _bola:
		total += _cola[h] - h + 1
	var j := 0
	var junta := clampf(_bola_t / BOLA_JUNTA, 0.0, 1.0) if _bola_fase == 1 else 1.0
	for h in _bola:
		for i in range(h, _cola[h] + 1):
			var y := 1.0 - 2.0 * (j + 0.5) / total
			var r := sqrt(maxf(1.0 - y * y, 0.0))
			var fi := j * 2.39996 + _bola_giro + sin(_t * 6.0 + j) * 0.15
			var lugar := Vector3(cos(fi) * r, y, sin(fi) * r) * BOLA_RADIO * (1.3 if i == h else 1.0)
			var donde := _bola_centro + lugar
			modo[i] = S.ANCLA | (S.CABEZA if i == h else 0)
			meta[i] = pos[i].lerp(donde, 0.15 + junta * 0.6)
			j += 1


# Se deshace: salen volando y quedan atontadas (`atontar` false: solo se olvida, al rearmar)
func _romper_bola(atontar: bool) -> void:
	if _bola_aura:
		_bola_aura.queue_free()
		_bola_aura = null
	if _bola_fase != 0 and atontar:
		var dt := 1.0 / hz
		for h in _bola:
			if vivos[h] == 0 or _cabeza_de[h] != h:
				continue
			_estado[h] = Estado.ATONTADA
			_reloj[h] = 0.0
			for i in range(h, _cola[h] + 1):
				var fuera := (pos[i] - _bola_centro).normalized() * 4.0 + Vector3.UP * 2.0
				old_pos[i] = pos[i] - fuera * dt
				modo[i] = S.LIBRE
		if _bola_vida <= 0.0:
			cuenta.bolas_rotas += 1
			_fx("saco_revienta", Vector3(_bola_centro.x, piso, _bola_centro.z), Vector3.ZERO, 0.6)
			Sonidos.tocar(self, "squelch", -4.0, 0.8)
	_bola = PackedInt32Array()
	_bola_fase = 0


func _es_bola(i: int) -> bool:
	return _bola_fase != 0 and i < _cabeza_de.size() and _cabeza_de[i] >= 0 and _estado[_cabeza_de[i]] == Estado.BOLA


# Pegarle a la bola le baja vida en vez de cortar (el tajo cargado la rompe de una)
func _herir_bola(dano: float, donde: Vector3) -> void:
	_bola_vida -= dano
	_fx("saco_golpe", donde, Vector3.ZERO, 0.6)
	if Time.get_ticks_msec() - _sonido_t > 70:
		_sonido_t = Time.get_ticks_msec()
		Sonidos.tocar(self, "squelch", -8.0, randf_range(0.8, 1.0))


# --- Oleadas y emboscadas ---

# Si hay muchas cerca, arrancan todas juntas un rato: no basta con caminar en circulos
func _pensar_ola(delta: float, yo: Vector3) -> void:
	_ola_t -= delta
	if _ola_t > 0.0:
		return
	_ola_t = randf_range(OLA_CADA.x, OLA_CADA.y)
	var cerca := 0
	for h in _cabezas:
		if pos[h].distance_squared_to(yo) < OLA_CERCA * OLA_CERCA:
			cerca += 1
	if cerca < OLA_JUNTAS:
		return
	for h in _cabezas:
		if _estado[h] == Estado.RODEA and pos[h].distance_squared_to(yo) < 100.0:
			_arranque[h] = OLA_DURA
	cuenta.olas += 1
	if Sonidos.turno("rugido_corto"):
		Sonidos.tocar(self, "rugido_corto", -6.0, 1.4)


# Fase 2+: unas cuantas que estan junto a una pared o pilar se suben a acechar
func _pensar_trepa(delta: float, yo: Vector3) -> void:
	_trepa_t -= delta
	if fase < 2 or _trepa_t > 0.0:
		return
	_trepa_t = TREPA_CADA
	var arriba := 0
	for h in _cabezas:
		if _estado[h] == Estado.TREPA or _estado[h] == Estado.ACECHA:
			arriba += 1
	for h in _cabezas:
		if arriba >= TREPA_MAX:
			return
		if _estado[h] != Estado.RODEA or _largo(h) < 5:
			continue
		var d := Vector2(pos[h].x - yo.x, pos[h].z - yo.z).length()
		if d < 3.0 or d > 8.0:
			continue
		# Junto a una pared: se mira el campo a los lados, a media altura, buscando algo cerca
		var mejor := 10.0
		var hacia_pared := Vector3.ZERO
		for k in 8:
			var lado := Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0))
			var dp := campo.muestra(pos[h] + lado * 0.7 + Vector3.UP * 0.5)
			if dp < mejor:
				mejor = dp
				hacia_pared = lado
		if mejor > 0.2:
			continue
		_estado[h] = Estado.TREPA
		_reloj[h] = 0.0
		# Va hacia la pared y para arriba: al tocarla, el solver la hace trepar
		_base[h] = pos[h] + hacia_pared * 1.0 + Vector3.UP * (TREPA_ALTO + 1.0)
		arriba += 1
		cuenta.trepas += 1


# --- Infectar zombis ---

func _buscar_zombi(h: int) -> void:
	var p := pos[h]
	for z in get_tree().get_nodes_in_group("zombis"):
		if not z is Zombie:
			continue
		var zombi := z as Zombie
		if zombi.es_jefe or zombi.estado == Zombie.Estado.MUERTO or zombi.get("infectado"):
			continue
		if zombi.global_position.distance_to(p) < INFECTA_DESDE + 1.0:
			zombi.infectar()
			_zombi[h] = zombi
			_estado[h] = Estado.INFECTA
			cuenta.infectados += 1
			return


# --- Crecer: las mitades vuelven a su largo con puntos muertos de su bloque ---

func _crecer(delta: float) -> void:
	_crece_t += delta
	if _crece_t < CRECE_CADA[clampi(fase - 1, 0, 2)]:
		return
	_crece_t = 0.0
	var crecieron := 0
	for h in _cabezas:
		if crecieron >= CRECE_MAX:
			break
		var t := _cola[h]
		if t % puntos == puntos - 1 or vivos[t + 1] == 1:
			continue
		# El siguiente tambien debe estar libre (o ser fin de bloque): si no, se pegaria a otra
		if (t + 1) % puntos != puntos - 1 and vivos[t + 2] == 1:
			continue
		var atras := (pos[t] - pos[t - 1]).normalized() if t > h else Vector3.BACK
		var n := t + 1
		pos[n] = pos[t] + atras * S.LARGO * 0.5
		old_pos[n] = pos[n]
		meta[n] = pos[n]
		modo[n] = modo[t] & ~S.CABEZA
		vivos[n] = 1
		links[t] = 1
		links[n] = 0
		_cabeza_de[n] = h
		_fotografiar(n)
		vivos_total += 1
		crecieron += 1
	cuenta.crecidas += crecieron


# Un punto que nacio o crecio entre fotos: que se dibuje donde esta, no donde murio
func _fotografiar(i: int) -> void:
	if i < vista.size():
		vista[i] = pos[i]
	if i < _antes.size():
		_antes[i] = pos[i]


# La Madre las escupe: revive tramos muertos como lombrices nuevas que salen volando.
# Con el hilo corriendo se aplica al recoger el paso (y regresa 0)
func parir(donde: Vector3, hacia: Vector3, cuantas: int) -> int:
	if _ocupado():
		_ordenes.append(_parir.bind(donde, hacia, cuantas))
		return 0
	return _parir(donde, hacia, cuantas)


func _parir(donde: Vector3, hacia: Vector3, cuantas: int) -> int:
	var dt := 1.0 / hz
	var salieron := 0
	var w := 0
	while w < lombrices and salieron < cuantas:
		# El primer hueco de 5+ puntos muertos seguidos en este bloque
		var desde := w * puntos
		var k := 0
		while k < puntos and salieron < cuantas:
			var largo := 0
			while k + largo < puntos and vivos[desde + k + largo] == 0:
				largo += 1
			if largo >= 5:
				var usa := mini(largo, 7)
				var vuelo := (hacia.normalized() + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.6), randf_range(-0.4, 0.4))).normalized() * randf_range(5.0, 9.0)
				for j in usa:
					var i := desde + k + j
					pos[i] = donde - hacia.normalized() * j * S.LARGO
					old_pos[i] = pos[i] - vuelo * dt
					meta[i] = pos[i]
					modo[i] = S.LIBRE
					vivos[i] = 1
					links[i] = 1 if j < usa - 1 else 0
					_fotografiar(i)
				if k > 0:
					links[desde + k - 1] = 0
				vivos_total += usa
				salieron += 1
				k += usa + 1
			else:
				k += maxi(largo, 1)
		w += 1
	cuenta.paridas += salieron
	if salieron > 0:
		_tramos()
	return salieron


# --- Zonas: sal, fuego, tambos (ZonaLombrices.gd) ---

func _zonas(delta: float) -> void:
	var zonas := get_tree().get_nodes_in_group("zonas_lombriz")
	if zonas.is_empty():
		return
	_sal_t -= delta
	_fuego_t -= delta
	var sala := _sal_t <= 0.0
	var quema := _fuego_t <= 0.0
	if sala:
		_sal_t = SAL_CADA
	if quema:
		_fuego_t = FUEGO_CADA
	var dt := 1.0 / hz
	for zona: Node3D in zonas:
		var tipo: int = zona.tipo
		if tipo == ZonaLombrices.Tipo.LODO:
			continue
		var centro := zona.global_position
		var r: float = zona.radio
		var r2 := r * r
		for h in _cabezas.duplicate():
			if vivos[h] == 0:
				continue
			for i in range(h, _cola[h] + 1):
				var p := pos[i]
				var dx := p.x - centro.x
				var dz := p.z - centro.z
				if dx * dx + dz * dz > r2 or absf(p.y - centro.y) > 2.0:
					continue
				if _estado[h] == Estado.BOLA:
					# La bola se derrite en la sal y el fuego
					if tipo == ZonaLombrices.Tipo.SAL and sala:
						_herir_bola(BOLA_SAL, p)
					elif tipo == ZonaLombrices.Tipo.FUEGO and quema:
						_herir_bola(BOLA_FUEGO, p)
					break
				# Las empuja para afuera
				var fuera := Vector3(dx, 0.0, dz).normalized()
				old_pos[i] -= fuera * EMPUJE_ZONA * dt
				if tipo == ZonaLombrices.Tipo.SAL and sala and _estado[h] != Estado.PEGADA:
					# La sal se come la cabeza, y luego la que sigue
					_matar(h)
					cuenta.saladas += 1
					_remedio_muerte()
					sangrar(pos[h], Vector3.UP, 0.4)
					_limpiar_tramo(h + 1)
					break
				if tipo == ZonaLombrices.Tipo.FUEGO and quema:
					# Se le quema la cola, un punto a la vez: se encoge sin partirse
					var cola := _cola[h]
					_matar(cola)
					sangrar(pos[cola], Vector3.UP, 0.2)
					if cola == h:
						cuenta.quemadas += 1
						_remedio_muerte()
					_limpiar_bloque(h / puntos)
					break
	# Sal sobre ti: quema a las que traes pegadas
	for zona: Node3D in zonas:
		if zona.tipo == ZonaLombrices.Tipo.SAL and _jugador and zona.global_position.distance_to(_jugador.global_position) < zona.radio + 0.5:
			for h in _cabezas.duplicate():
				if vivos[h] == 1 and _estado[h] == Estado.PEGADA:
					_matar_tramo(h, "saladas")


# --- Dano por contacto (lo de siempre, fuera de saltos y pegadas) ---

func _morder(delta: float) -> void:
	_toca_espera -= delta
	if _toca_espera > 0.0 or _jugador == null or not _jugador.has_method("recibir_dano"):
		return
	for h in _cabezas:
		if _estado[h] != Estado.RODEA:
			continue
		if _toca_jugador(pos[h], TOCA):
			_jugador.recibir_dano(DANO, pos[h], 0.3)
			_toca_espera = CADA
			return


# --- Dibujo: tubos entre puntos y una boca por cabeza ---

# Una vez por cuadro de fisica, entre las dos ultimas fotos (`_antes` -> `vista`): el paso va a
# `hz`, el dibujo a 60
func _pintar() -> void:
	var t0 := Time.get_ticks_usec()
	var a := clampf((Time.get_ticks_msec() - _recogido) / 1000.0 / maxf(_intervalo, 0.001), 0.0, 1.0)
	var q := vista
	if _antes.size() == vista.size() and a < 1.0:
		q = _antes.duplicate()
		for i in q.size():
			if vivos[i] == 1:
				q[i] = q[i].lerp(vista[i], a)
	if q.size() != vivos.size():
		return
	var ns := 0
	var nc := 0
	var ne := 0
	var noche := 1.0
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _ciclo and _ciclo.has_method("es_noche") and _ciclo.es_noche():
		noche = 2.5
	MallaLombriz.material_crias().set_shader_parameter("brillo", 0.6 * noche)
	for h in _cabezas:
		if h >= vivos.size() or vivos[h] == 0:
			continue
		var cola := _cola[h]
		var largo := float(cola - h + 1)
		var e := _estado[h]
		var tinte := COLOR_PIEL.darkened(float((h / puntos) % 5) * 0.05)
		var prisa := 2.0 if e == Estado.SALTA or e == Estado.LATIGO or e == Estado.ERGUIDA else 1.0
		var semilla := float((h * 37) % 100) / 100.0
		for i in range(h, cola):
			var k := float(i - h)
			var afina := lerpf(1.1, 0.55, k / largo)
			var late := 1.0 + 0.18 * sin(_t * 7.0 * prisa - k * 0.9 + semilla * 6.0)
			var t := MallaLombriz.tramo(q[i + 1], q[i], GRUESO * afina * late)
			# Como la Madre: .g las grietas, que brillan mas hacia la cola; .a la semilla de la piel
			var grietas := lerpf(0.3, 1.0, k / largo)
			MallaLombriz.escribir(_buf_seg, ns, t, tinte, Color(0.0, grietas, 0.0, fmod(semilla + k * 0.37, 1.0)))
			ns += 1
			# Una espina cada dos tramos, hacia arriba del tubo e inclinada hacia la cola
			if (i - h) % 2 == 1:
				var atras := (q[i + 1] - q[i]).normalized()
				var arriba := Vector3.UP - atras * atras.dot(Vector3.UP)
				if arriba.length_squared() < 0.01:
					arriba = Vector3.RIGHT - atras * atras.dot(Vector3.RIGHT)
				arriba = arriba.normalized()
				var dir := (arriba + atras * 0.45).normalized()
				var ex := dir.cross(atras).normalized()
				var ez := ex.cross(dir)
				var ancho := GRUESO * afina * 0.55
				var base := q[i] + arriba * GRUESO * afina * 0.75
				MallaLombriz.escribir(_buf_esp, ne, Transform3D(Basis(ex * ancho, dir * GRUESO * afina * 1.6, ez * ancho), base), tinte, Color(0.0, grietas, 0.0, 0.0))
				ne += 1
		# La boca: hacia adelante, del segundo punto a la cabeza
		if cola > h:
			var adelante := (q[h] - q[h + 1]).normalized()
			var abre := 0.0
			if e == Estado.ERGUIDA or e == Estado.SALTA or e == Estado.PEGADA or e == Estado.INFECTA:
				abre = 1.0
			elif e == Estado.LATIGO:
				abre = 0.6
			else:
				abre = maxf(sin(_t * 3.0 + semilla * 9.0), 0.0) * 0.25
			var t := MallaLombriz.tramo(q[h] - adelante * 0.06, q[h] + adelante * 0.14, GRUESO * 1.25, 1.0)
			MallaLombriz.escribir(_buf_cab, nc, t, tinte.darkened(0.15), Color(abre, 0.1, 0.0, semilla))
			nc += 1
	_malla_seg.buffer = _buf_seg
	_malla_seg.visible_instance_count = ns
	_malla_cab.buffer = _buf_cab
	_malla_cab.visible_instance_count = nc
	_malla_esp.buffer = _buf_esp
	_malla_esp.visible_instance_count = ne
	ms_pintar = (Time.get_ticks_usec() - t0) / 1000.0


func _armar_mallas() -> void:
	var total := maxi(lombrices * puntos, 1)
	_malla_seg = MallaLombriz.multimesh(MallaLombriz.segmento(), total)
	_malla_cab = MallaLombriz.multimesh(MallaLombriz.cabeza(), total)
	_malla_esp = MallaLombriz.multimesh(MallaLombriz.espina(), total)
	_buf_seg.resize(total * 20)
	_buf_cab.resize(total * 20)
	_buf_esp.resize(total * 20)
	# Sin sombras: mil tubos en el mapa de sombras costaban mas que dibujarlos. La piel es la de
	# la Madre (MallaLombriz.material_crias)
	for mm in [_malla_seg, _malla_cab, _malla_esp]:
		var nodo := MallaLombriz.nodo(mm, false)
		nodo.material_override = MallaLombriz.material_crias()
		add_child(nodo)


# La sombra de la torre: un disco oscuro y tenue que crece mientras suben (sin anillo rojo)
func _armar_anillo() -> void:
	var anillo := CylinderMesh.new()
	anillo.top_radius = 1.0
	anillo.bottom_radius = 1.0
	anillo.height = 0.01
	anillo.radial_segments = 16
	anillo.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	anillo.material = material
	_anillo_torre = MeshInstance3D.new()
	_anillo_torre.mesh = anillo
	_anillo_torre.top_level = true
	_anillo_torre.visible = false
	_anillo_torre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_anillo_torre)


# --- Armas ---

# El punto vivo que el rayo toca primero (esfera de `hit_radius`, mas grande en las cabezas), o {}:
# {dot_index, position, distance}
func query_ray_hit(ray_origin: Vector3, ray_dir: Vector3, max_dist: float, hit_radius: float) -> Dictionary:
	var dir := ray_dir.normalized()
	var mejor := -1
	var mejor_t := max_dist
	for i in mini(vivos.size(), vista.size()):
		if vivos[i] == 0:
			continue
		var r := hit_radius
		var oc := vista[i] - ray_origin
		var t := oc.dot(dir)
		if t < 0.0 or t > mejor_t + r:
			continue
		var d2 := oc.length_squared() - t * t
		if d2 > r * r:
			continue
		var entra := t - sqrt(r * r - d2)
		if entra < mejor_t:
			mejor_t = maxf(entra, 0.0)
			mejor = i
	if mejor == -1:
		return {}
	return {"dot_index": mejor, "position": ray_origin + dir * mejor_t, "distance": mejor_t}


# Lo mismo en todo lo del grupo "lombrices" (crias y Madre); agrega "enjambre"
static func rayo(arbol: SceneTree, origen: Vector3, dir: Vector3, max_dist: float, radio: float) -> Dictionary:
	var mejor := {}
	for enjambre in arbol.get_nodes_in_group("lombrices"):
		var pego: Dictionary = enjambre.query_ray_hit(origen, dir, mejor.get("distance", max_dist), radio)
		if not pego.is_empty():
			pego["enjambre"] = enjambre
			mejor = pego
	return mejor


# Explosion de prueba (no hay balas explosivas aun) donde apunta el centro de la pantalla
static func explotar_en_mira(arbol: SceneTree, vista_: Viewport, radio := 3.0, fuerza := 12.0) -> void:
	var camara := vista_.get_camera_3d()
	if camara == null:
		return
	var centro := vista_.get_visible_rect().size / 2.0
	var origen := camara.project_ray_origin(centro)
	var dir := camara.project_ray_normal(centro)
	var jugador := arbol.get_first_node_in_group("jugador") as CollisionObject3D
	var excluir: Array[RID] = [jugador.get_rid()] if jugador else []
	var pego := camara.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(origen, origen + dir * 60.0, 1, excluir))
	var punto: Vector3 = pego.position if pego else origen + dir * 60.0
	var lombriz := rayo(arbol, origen, dir, origen.distance_to(punto), 0.15)
	if not lombriz.is_empty():
		punto = lombriz.position
	for enjambre in arbol.get_nodes_in_group("lombrices"):
		enjambre.apply_explosion_impulse(punto, radio, fuerza)


# Un balazo: a la cabeza mata a la lombriz entera; al cuerpo la corta ahi y avienta las de junto
func bullet_hit(dot_index: int, hit_point: Vector3, dir: Vector3) -> void:
	if _ocupado():
		_ordenes.append(bullet_hit.bind(dot_index, hit_point, dir))
		return
	if dot_index < 0 or dot_index >= vivos.size() or vivos[dot_index] == 0:
		return
	var hacia := dir.normalized()
	var dt := 1.0 / hz
	for i in vivos.size():
		if vivos[i] == 0:
			continue
		var d := pos[i].distance_to(hit_point)
		if d < RADIO_BALA:
			var lejos := (pos[i] - hit_point).normalized() if d > 0.01 else hacia
			var empuje := (hacia + lejos + Vector3.UP * 0.6).normalized() * EMPUJE_BALA * (1.0 - d / RADIO_BALA)
			old_pos[i] -= empuje * dt
	if _es_bola(dot_index):
		_herir_bola(5.0, hit_point)
		return
	sangrar(hit_point, -hacia + Vector3.UP * 0.5)
	_fx("cria_corte", hit_point, -hacia, 0.5)
	if _cabeza_de[dot_index] == dot_index:
		_matar_tramo(dot_index, "cabezas")
		return
	_matar(dot_index)
	cuenta.cortes += 1
	_limpiar_bloque(dot_index / puntos)


func apply_explosion_impulse(origin: Vector3, radius: float, force: float, mata := true) -> void:
	if _ocupado():
		_ordenes.append(apply_explosion_impulse.bind(origin, radius, force, mata))
		return
	var dt := 1.0 / hz
	var tocadas := {}
	for i in vivos.size():
		if vivos[i] == 0:
			continue
		var delta := pos[i] - origin
		var d := delta.length()
		if d > radius:
			continue
		var cae := 1.0 - d / radius
		var hacia := (delta.normalized() if d > 0.01 else Vector3.UP) + Vector3.UP * 0.8
		old_pos[i] -= hacia.normalized() * force * cae * dt
		# Las pegadas salen volando
		var h := _cabeza_de[i] if i < _cabeza_de.size() else -1
		if h >= 0 and _estado[h] == Estado.PEGADA:
			_volver(h)
		if not mata:
			continue
		if d < radius * 0.25:
			_matar(i)
		elif d < radius * 0.5 and randf() < 0.5:
			links[i] = 0
		tocadas[i / puntos] = true
	for w: int in tocadas:
		_limpiar_bloque(w)
	if mata:
		for n in 3:
			sangrar(origin + Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1)) * radius * 0.3, Vector3.UP)


# Un machetazo (Player._golpear / _pegar_estocada): avienta a todas las del cono y corta las
# mas cercanas, segun el dano. `cono`: coseno minimo con `frente`; `giro`: en redondo; `todas`:
# el tajo cargado corta todo lo que alcanza. Con la estela de fuego, quema en vez de cortar
func golpe_cuerpo(origen: Vector3, frente: Vector3, alcance: float, cono: float, dano: int, giro := false, todas := false) -> bool:
	if vivos_total == 0 or vista.size() != vivos.size():
		return false
	# A quien le pega se ve ya, en la ultima foto; cortarlas se aplica cuando el hilo suelta
	var alcanzados: Array[Vector2] = []   # (distancia, indice)
	var salidas := {}
	var en_bola := Vector3.INF
	for i in vivos.size():
		if vivos[i] == 0:
			continue
		var p := vista[i]
		var dy := p.y - origen.y
		if dy < ALTO_GOLPE.x or dy > ALTO_GOLPE.y:
			continue
		var hacia := Vector3(p.x - origen.x, 0.0, p.z - origen.z)
		var d := hacia.length()
		# Las que traes pegadas siempre te quedan a la mano
		var pegada := _cabeza_de[i] >= 0 and _estado[_cabeza_de[i]] == Estado.PEGADA
		if d > alcance + S.RADIO and not pegada:
			continue
		if not giro and not pegada and d > 0.01 and hacia.normalized().dot(frente) < cono:
			continue
		if _es_bola(i):
			en_bola = p
			continue
		alcanzados.append(Vector2(d, i))
		salidas[i] = ((hacia.normalized() if d > 0.01 else frente) + frente * 0.5 + Vector3.UP * 0.7).normalized()
	if en_bola != Vector3.INF:
		_herir_bola(BOLA_VIDA * 2.0 if todas else float(dano), en_bola)
	if not alcanzados.is_empty() or en_bola != Vector3.INF:
		_nota("pelear", "crias")
	if alcanzados.is_empty():
		return en_bola != Vector3.INF
	alcanzados.sort()
	var quema := ESTELA.estilo == ESTELA.Estilo.FUEGO or ESTELA.estilo == ESTELA.Estilo.FLAMAS_FELIPE
	var cortes := CORTES_TAJO if todas else clampi(roundi(dano * CORTES_POR_DANO), 2, CORTES_MAX)
	if _ocupado():
		_ordenes.append(_cortar.bind(alcanzados, salidas, frente, cortes, quema))
	else:
		_cortar(alcanzados, salidas, frente, cortes, quema)
	return true


func _cortar(alcanzados: Array[Vector2], salidas: Dictionary, frente: Vector3, cortes: int, quema: bool) -> void:
	var dt := 1.0 / hz
	for i: int in salidas:
		if vivos[i] == 1:
			old_pos[i] -= salidas[i] * EMPUJE_GOLPE * dt
	var tocadas := {}
	for n in mini(cortes, alcanzados.size()):
		var i := int(alcanzados[n].y)
		if vivos[i] == 0:
			continue
		var h := _cabeza_de[i]
		if h == i:
			_matar_tramo(h, "cabezas")
			continue
		if quema and h >= 0:
			# La estela de fuego quema la cabeza en vez de partirla
			_matar(h)
			cuenta.quemadas += 1
			tocadas[h / puntos] = true
			continue
		_matar(i)
		cuenta.cortes += 1
		tocadas[i / puntos] = true
		_fx("cria_corte", pos[i], frente, 0.5)
		if n % 2 == 0:
			sangrar(pos[i], frente + Vector3.UP * 0.6)
	for w: int in tocadas:
		_limpiar_bloque(w)


func _matar(i: int) -> void:
	if vivos[i] == 0:
		return
	vivos[i] = 0
	vivos_total -= 1
	links[i] = 0
	if i > 0:
		links[i - 1] = 0


# Toda la lombriz de la cabeza `h`, de una (cabeza, fuego, sal sobre ti)
func _matar_tramo(h: int, por: String) -> void:
	if h < 0 or vivos[h] == 0:
		return
	var cola := _cola[h] if _cabeza_de[h] == h else h
	var medio := pos[(h + cola) / 2]
	for i in range(h, cola + 1):
		if vivos[i] == 1:
			_matar(i)
	_zombi.erase(h)
	if cuenta.has(por):
		cuenta[por] += 1
	if por in ["cabezas", "quemadas", "saladas"]:
		_nota("matar", "crias")
	if por in ["quemadas", "saladas"]:
		_remedio_muerte()
	sangrar(medio, Vector3.UP, 0.8)
	if por != "":
		_fx("cria_cabeza", medio, Vector3.ZERO, 0.5)
	if por == "quemadas":
		_tierra(medio, 0.5)


# Lo que queda de menos de PEDAZO_MINIMO puntos en el bloque `w` se muere
func _limpiar_bloque(w: int) -> void:
	var desde := w * puntos
	var k := 0
	while k < puntos:
		var i := desde + k
		if vivos[i] == 0:
			k += 1
			continue
		var largo := 1
		while k + largo < puntos and links[i + largo - 1] == 1 and vivos[i + largo] == 1:
			largo += 1
		if largo < PEDAZO_MINIMO:
			for j in largo:
				_matar(i + j)
			sangrar(pos[i], Vector3.UP, 0.4)
		k += largo


func _limpiar_tramo(i: int) -> void:
	if i < vivos.size():
		_limpiar_bloque(i / puntos)


# --- Sangre (agua sucia y rojo oscuro) y tierra ---

func _armar_sangre() -> void:
	var rojo := _rampa(COLOR_SANGRE.lightened(0.1), COLOR_AGUA.darkened(0.3))
	var cafe := _rampa(COLOR_TIERRA.lightened(0.2), COLOR_TIERRA.darkened(0.4))
	for n in CHORROS:
		_chorros.append(_chorro(rojo if n < CHORROS - 2 else cafe))


func _rampa(a: Color, b: Color) -> GradientTexture1D:
	var rampa := Gradient.new()
	rampa.set_color(0, a)
	rampa.set_color(1, b)
	var textura := GradientTexture1D.new()
	textura.gradient = rampa
	return textura


func _chorro(rampa: GradientTexture1D) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.07   # los billboard ignoran la escala de la particula si no
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	quad.material = material
	var chorro := GPUParticles3D.new()
	chorro.amount = GOTAS_CHORRO
	chorro.lifetime = 0.7
	chorro.one_shot = true
	chorro.explosiveness = 1.0
	chorro.emitting = false
	chorro.draw_pass_1 = quad
	chorro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chorro.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var proceso := ParticleProcessMaterial.new()
	proceso.direction = Vector3.UP
	proceso.spread = 50.0
	proceso.initial_velocity_min = 2.0
	proceso.initial_velocity_max = 5.0
	proceso.gravity = Vector3(0, -14.0, 0)
	proceso.scale_min = 0.6
	proceso.scale_max = 1.4
	proceso.color_initial_ramp = rampa
	chorro.process_material = proceso
	chorro.top_level = true
	add_child(chorro)
	return chorro


# La libreta del Nocturno (autoload Libreta)
func _nota(cual: String, id: String) -> void:
	var libreta := get_node_or_null("/root/Libreta")
	if libreta:
		libreta.call(cual, id)


# Sal o fuego mataron algo: la pagina de remedios se llena a las 10
func _remedio_muerte() -> void:
	_remedio_muertes += 1
	_nota("pelear", "remedios")
	if _remedio_muertes == 10:
		_nota("matar", "remedios")


# Una hoja de pixel (EfectosPixel), sin repetir la misma mas seguido que FX_ESPERA
func _fx(lugar: String, donde: Vector3, hacia := Vector3.ZERO, escala := 1.0) -> void:
	var ahora := Time.get_ticks_msec()
	if ahora - int(_fx_ultimo.get(lugar, -100000)) < int(FX_ESPERA.get(lugar, 0)):
		return
	_fx_ultimo[lugar] = ahora
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		efectos.lanzar(lugar, donde, hacia, escala)
	if lugar == "cria_corte" or lugar == "cria_cabeza":
		if ahora - _sonido_t > 70:
			_sonido_t = ahora
			Sonidos.tocar(self, "squelch", -14.0, randf_range(1.2, 1.6))


func sangrar(donde: Vector3, hacia: Vector3, cuanto := 1.0) -> void:
	_lanzar_chorro(_siguiente_chorro, donde, hacia, cuanto)
	_siguiente_chorro = (_siguiente_chorro + 1) % (CHORROS - 2)
	# Manchas en el piso si hay Liquido (Zombis lo crea): agua sucia con rojo oscuro
	var liquido := get_tree().get_first_node_in_group("liquido")
	if liquido and liquido.has_method("salpicar"):
		liquido.salpicar(donde, 0.05, piso + 0.01, hacia, int(4 * cuanto), COLOR_AGUA, Vector2(1.5, 3.5), 0.6)
		liquido.salpicar(donde, 0.05, piso + 0.01, hacia, int(3 * cuanto), COLOR_SANGRE, Vector2(1.5, 3.5), 0.6)


func _tierra(donde: Vector3, cuanto: float) -> void:
	_lanzar_chorro(CHORROS - 2 + randi() % 2, donde, Vector3.UP, cuanto)


func _lanzar_chorro(n: int, donde: Vector3, hacia: Vector3, cuanto: float) -> void:
	if n >= _chorros.size():
		return
	var chorro := _chorros[n]
	chorro.global_position = donde
	(chorro.process_material as ParticleProcessMaterial).direction = hacia.normalized() if hacia.length_squared() > 0.0001 else Vector3.UP
	chorro.amount_ratio = clampf(cuanto, 0.1, 1.0)
	chorro.restart()
