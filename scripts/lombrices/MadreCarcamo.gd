class_name MadreCarcamo
extends Node3D
# La Madre del Carcamo: una lombriz enorme que vive en el charco de lodo de Serenol del carcamo
# (docs/lore.md) y cuyas crias son el EnjambreLombrices. Es la misma fisica (SolverLombrices) con
# PUNTOS puntos gordos, en el hilo principal (son pocos). Su vida son sus SACOS de Serenol, que
# brillan en el lomo; cada uno es dueno de su seccion del cuerpo (_seccion), y pegarle a cualquier
# parte de esa seccion lo hiere, solo cuando esta afuera. Cada 2 sacos reventados sube la
# fase del enjambre (EnjambreLombrices.fase): 2 = se entierran y hacen latigos, 3 = torres.
#
# Ataques, en ciclo, con aviso, y entre uno y otro se esconde en el charco:
#   MORDIDA: va por debajo hasta ti, un anillo rojo y tierra te avisan, y sale a morder para
#            arriba; luego cae y se queda tirada un rato (sacos al aire).
#            Con `alberca` (el carcamo) solo nada dentro de la alberca: si estas en el cemento va
#            por debajo hasta la orilla mas cercana a ti, avisa ahi y SALTA hacia ti; cae en el piso
#            y se queda tirada. Para volver se arrastra por el piso (REGRESA) hasta la alberca.
#   BARRIDO: sale entera y te embiste: apunta, se lanza derecho y se pasa de largo, varias
#            veces; rueda de lado. Afuera recibe dano.
#   VOMITO: asoma la cabeza y escupe crias (EnjambreLombrices.parir).
#   ESCUPE: asoma la cabeza y avienta bolas de lodo que dejan charcos que frenan y queman
#           (ZonaLombrices LODO).
# Esta en el grupo "lombrices": la pistola y el machete le preguntan igual que a las crias.

signal muerta
signal saco_reventado(quedan: int)

const SOLVER := preload("res://scripts/lombrices/SolverLombrices.gd")
const S := preload("res://scripts/lombrices/SolverLombrices.gd")

enum Estado { CHARCO, VA, AVISA, MUERDE, TIRADA, BARRE, VOMITA, ESCUPE, MUERE, ATURDIDA, SALTA, REGRESA }

const PUNTOS := 18
# Todo su tamano (JJ, 2026-11-09: el doble era mucho, 1.5): grueso, largo, sacos y alturas de sus ataques
const ESCALA := 1.5
const RADIO := 0.42 * ESCALA
const LARGO := 0.5 * ESCALA
const VELOCIDAD := 3.4
const GRUESO := 0.4 * ESCALA
const COLOR := Color(0.25, 0.27, 0.28)   # #3F4447: carbon con un toque verde del lodo
const SACOS := 6
const SACO_EN := [3, 5, 7, 9, 11, 13]
const SACO_VIDA := 70.0
const SACO_RADIO := 0.24 * ESCALA
const SACO_ALTO := 0.45 * ESCALA   # m arriba del centro del punto: salen del lomo
# El color de un saco segun su vida: magenta lleno, rosa a la mitad, naranja casi roto (se distinguen del azul del cuerpo)
const SACO_LLENO := Color(0.88, 0.25, 0.98)   # #E040FB: magenta, casi opuesto al azul del cuerpo
const SACO_MEDIO := Color(1.0, 0.31, 0.66)    # #FF4FA8
const SACO_ROTO := Color(1.0, 0.48, 0.27)     # #FF7A45: naranja, que no se confunda con la sangre
const LATE := Vector2(5.0, 12.0)       # rad/s del pulso, lleno -> casi roto
const GOTEO_CADA := Vector2(0.6, 0.15) # s entre gotas de un saco herido, poco -> muy herido
const RASTRO_CADA := 0.3        # s entre manchas en el piso mientras se arrastra herida
const ATURDIDA_DURA := 2.0      # s tirada al reventarle un saco: la ventana para el siguiente
const COLOR_SACO_SANGRE := Color(0.75, 0.2, 0.8)
const COLOR_SANGRE := Color(0.38, 0.04, 0.05)
const DANO_BALA := 5.0
# Que le hace dano (JJ, 2026-11-09): los balazos solo en las crestas (los sacos), no en el cuerpo;
# y de lo cuerpo a cuerpo solo el machetazo cargado (golpe_cuerpo con `todas`), que le pega a la
# seccion que alcance (al saco de esa seccion). Los machetazos normales, el giro aereo y la estocada
# le pegan (suena y la detiene) pero no le bajan nada. Fraccion del dano del tajo que llega por el cuerpo
const DANO_CUERPO := 1.0
const DANO_FUEGO := 2.0         # cada FUEGO_CADA dentro de una molotov
const FUEGO_CADA := 0.5
const DANO_CHOQUE := 16
const DANO_MORDIDA := 26
const DESCANSO := [2.2, 1.6, 1.0]   # s en el charco entre ataques, por fase
const ENCADENA := 0.4           # fase 3: probabilidad de pegar otro ataque sin descansar
const VA_DURA := 1.6
const AVISA_DURA := 0.6         # el aviso de la mordida: tierra y un gruñido bajo, nada mas
const MUERDE_DURA := 0.9
const MUERDE_ALTO := 3.6 * ESCALA
const TIRADA_DURA := 2.0
# El barrido ahora son embestidas (JJ, 2026-11-09: dando vueltas en el cuarto grande nunca habia
# que esquivarla, solo pegarle): se levanta apuntandote EMBISTE_APUNTA s (el aviso), se lanza
# derecho a donde estabas y se pasa EMBISTE_PASA m de largo; luego otra vez, EMBISTE_PASADAS por fase
const EMBISTE_PASADAS := [2, 3, 3]
const EMBISTE_APUNTA := 0.4
const EMBISTE_PASA := 3.0
const EMBISTE_MAX := 3.0        # s por pasada como mucho, por si se atora
const EMBISTE_VEL := 1.6        # x VELOCIDAD mientras se lanza (arrastrandose iba a ~4 m/s)
const EMBISTE_LLEGA := 1.2      # m de su meta: se acabo la pasada
const EMBISTE_HASTA := 11.0     # m del centro (en planta) que puede llegar: no se mete bajo el mezzanine
const VOMITA_DURA := 3.0
const VOMITA_CADA := 0.5
const VOMITA_CRIAS := 6         # por bocanada (+ fase); eran 3, JJ quiere que saque mas (2026-11-09)
const ESCUPE_BOLAS := [3, 4, 5]
const ESCUPE_CADA := 0.7
# El escupitajo es como un balazo (JJ, 2026-11-09: iba lento en parabola y dejaba un charco):
# derecho y rapido a tu pecho con un poco de adelanto y error; si te da, te baja vida y ya
const ESCUPE_VEL := 14.0        # m/s: a 10 m tarda ~0.7 s, da tiempo de rodar (a 30 no, JJ)
const ESCUPE_DANO := 10
const ESCUPE_ADELANTA := 0.5    # de tu velocidad por el tiempo que tarda en llegar
const ESCUPE_ERROR := 0.35      # m al azar en donde apunta
const MUERE_DURA := 2.5
# El salto desde la orilla (con `alberca`): la cabeza va en arco hasta donde estabas
const SALTA_DURA := 0.75
const SALTA_ALTO := 2.2 * ESCALA
const SALTA_PUNTOS := 8         # los primeros puntos van en el arco; lo demas se arrastra detras
const REGRESA_MAX := 7.0        # s arrastrandose de vuelta; si se atora, se zambulle donde este
const TREPA_ADENTRO := 1.0      # m antes de la orilla donde empieza a levantarse
const TREPA_AFUERA := 0.6       # m despues del barandal donde ya baja al piso
const ORILLA := 0.9             # m adentro de la orilla de la alberca donde asoma para saltar
const ARRIBA_DESDE := 1.2        # m sobre el charco de tus pies: estas en el mezzanine

var enjambre: EnjambreLombrices
var charco := Vector3.ZERO          # centro del charco, a la altura del piso
# Medio lado de la alberca (CarcamoNivel.ALBERCA). 0 = sin alberca (safehouse): nada por todo el piso
var alberca := 0.0
# El barandal de la alberca: alto y a cuantos m de la orilla (CarcamoNivel). Para salir o entrar
# trepa por encima (_trepar); la pared de 0.9 m de la fosa sola ya no la dejaba salir
var barandal := 0.0
var barandal_a := 0.0
var estado := Estado.CHARCO
var pos := PackedVector3Array()
var old_pos := PackedVector3Array()
var links := PackedByteArray()
var vivos := PackedByteArray()
var modo := PackedByteArray()
var meta := PackedVector3Array()
var sacos := PackedFloat32Array()
var cuenta := {"mordidas": 0, "barridos": 0, "vomitos": 0, "escupidas": 0, "aturdidas": 0, "zambullidas": 0, "saltos": 0}
# Estas parado arriba (mezzanine, rampa): no sale entera, se zambulle si estaba afuera y sus sacos
# no reciben dano. Asi no se le puede pegar sin riesgo desde arriba: hay que bajar
var arriba := false

var _uniones := PackedInt32Array()
var _solver: SolverLombrices
var _jugador: Node3D
var _reloj := 0.0
var _turno := 0
var _blanco := Vector3.ZERO
var _desde := Vector3.ZERO           # de donde salta (la orilla)
var _pasadas := 0
var _cada := 0.0
var _angulo := 0.0
var _choque := 0.0
var _fuego := 0.0
var _malla: MultiMesh
var _buf := PackedFloat32Array()
var _cabeza: MultiMesh
var _buf_cab := PackedFloat32Array()
var _espinas: MultiMesh
var _buf_esp := PackedFloat32Array()
var _bolsas: Array[MeshInstance3D] = []
var _materiales: Array[ShaderMaterial] = []
var _goteo := PackedFloat32Array()
var _rastro := 0.0
var _squelch := 0
var _chapoteo := 0.0
var _niebla: Node3D
var _anillo: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	add_to_group("lombrices")
	_solver = SOLVER.new()
	_solver.radio = RADIO
	_solver.largo = LARGO
	_solver.velocidad = VELOCIDAD
	_solver.separar = false
	_solver.puntos_por_lombriz = PUNTOS
	_malla = MallaLombriz.multimesh(MallaLombriz.segmento(), PUNTOS)
	_cabeza = MallaLombriz.multimesh(MallaLombriz.cabeza(), 1)
	_buf.resize(PUNTOS * 20)
	_buf_cab.resize(20)
	_espinas = MallaLombriz.multimesh(MallaLombriz.espina(), PUNTOS)
	_buf_esp.resize(PUNTOS * 20)
	# La piel de la Madre es suya (shaders/madre.gdshader); las crias siguen con la de lombriz
	for mm in [_malla, _cabeza, _espinas]:
		var nodo := MallaLombriz.nodo(mm)
		nodo.material_override = MallaLombriz.material_madre()
		add_child(nodo)
	# Los sacos son espinas grandes del lomo: gris de piel que se enciende hacia la punta en rosa-violeta,
	# como las azules (el golpe sigue siendo una esfera)
	var cristal := MallaLombriz.aleta()
	# Un material por saco: cada uno cambia de color con su vida
	for n in SACOS:
		var material := ShaderMaterial.new()
		material.shader = MallaLombriz.SHADER_MADRE
		material.set_shader_parameter("es_saco", 1.0)
		var bolsa := MeshInstance3D.new()
		bolsa.mesh = cristal
		bolsa.material_override = material
		bolsa.top_level = true
		add_child(bolsa)
		_bolsas.append(bolsa)
		_materiales.append(material)
	var anillo := TorusMesh.new()
	anillo.inner_radius = 0.9
	anillo.outer_radius = 1.0
	anillo.rings = 24
	anillo.ring_segments = 3
	var rojo := StandardMaterial3D.new()
	rojo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rojo.albedo_color = Color(1.0, 0.15, 0.1)
	anillo.material = rojo
	_anillo = MeshInstance3D.new()
	_anillo.mesh = anillo
	_anillo.top_level = true
	_anillo.visible = false
	add_child(_anillo)
	reiniciar()


# Toda la vida, en el charco
func reiniciar() -> void:
	pos.resize(PUNTOS)
	old_pos.resize(PUNTOS)
	links.resize(PUNTOS)
	vivos.resize(PUNTOS)
	modo.resize(PUNTOS)
	meta.resize(PUNTOS)
	vivos.fill(1)
	for i in PUNTOS:
		var a := TAU * i / PUNTOS * 0.8
		pos[i] = _hondo(charco + Vector3(cos(a), 0.0, sin(a)) * 2.0)
		old_pos[i] = pos[i]
		meta[i] = pos[i]
		modo[i] = S.BAJO_TIERRA
		links[i] = 1 if i < PUNTOS - 1 else 0
	sacos.resize(SACOS)
	sacos.fill(SACO_VIDA)
	_goteo.resize(SACOS)
	_goteo.fill(0.0)
	if _niebla:
		_niebla.queue_free()
		_niebla = null
	_solver.reiniciar()
	_cambiar(Estado.CHARCO)
	_turno = 0
	visible = true
	if enjambre:
		enjambre.fase = 1


func quedan() -> int:
	var n := 0
	for v in sacos:
		if v > 0.0:
			n += 1
	return n


func vida() -> float:
	var total := 0.0
	for v in sacos:
		total += maxf(v, 0.0)
	return total / (SACO_VIDA * SACOS)


func _hondo(p: Vector3) -> Vector3:
	return Vector3(p.x, charco.y - 0.55 * ESCALA, p.z)


# Dentro de la alberca (en planta). Sin alberca, todo cuenta como adentro
func _en_alberca(p: Vector3, margen := 0.0) -> bool:
	if alberca <= 0.0:
		return true
	return absf(p.x - charco.x) < alberca - margen and absf(p.z - charco.z) < alberca - margen


# El punto de la alberca mas cercano a `p`, ORILLA adentro de la orilla
func _dentro(p: Vector3) -> Vector3:
	if alberca <= 0.0:
		return p
	var m := alberca - ORILLA
	return Vector3(clampf(p.x, charco.x - m, charco.x + m), p.y, clampf(p.z, charco.z - m, charco.z + m))


# Los puntos que van arrastrandose y estan en la franja de la orilla (de la pared de la fosa a
# pasando el barandal) se levantan y pasan por encima en arco: trepa para salir y para entrar.
# `desde` deja en paz los primeros (el salto los lleva en su arco)
func _trepar(desde := 0) -> void:
	if alberca <= 0.0:
		return
	var alto := charco.y + maxf(barandal, 0.2) + RADIO + 0.15
	var lejos := alberca + barandal_a + TREPA_AFUERA
	var cerca := alberca - TREPA_ADENTRO
	for i in range(desde, PUNTOS):
		if modo[i] & (S.BAJO_TIERRA | S.AIRE | S.LIBRE):
			continue
		var d := maxf(absf(pos[i].x - charco.x), absf(pos[i].z - charco.z))
		if d < cerca or d > lejos:
			continue
		# Mas alto en medio de la franja (sobre el barandal), parejo a los lados
		var t := clampf((d - cerca) / (lejos - cerca), 0.0, 1.0)
		var sigue := meta[i] if i == 0 else pos[i - 1]
		modo[i] = (modo[i] & (S.CABEZA | S.RAPIDO)) | S.AIRE
		meta[i] = Vector3(sigue.x, lerpf(charco.y + RADIO, alto, sin(t * PI) * 0.5 + 0.5), sigue.z)


func _cambiar(e: Estado) -> void:
	estado = e
	_reloj = 0.0
	_cada = 0.0


func _fase() -> int:
	return enjambre.fase if enjambre else 1


func _physics_process(delta: float) -> void:
	if enjambre == null or not enjambre.campo.listo:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		if _jugador == null:
			return
	if not _jugador.is_physics_processing():
		return
	_t += delta
	_reloj += delta
	_choque -= delta
	_ver_arriba()
	_solver.velocidad = VELOCIDAD
	_pensar(delta)
	_solver.obstaculo = _jugador.global_position
	_solver.obstaculo_activo = estado != Estado.MUERE
	_solver.step(pos, old_pos, links, vivos, modo, meta, _uniones, delta, enjambre.campo)
	_chocar()
	_quemar(delta)
	_sangrar_sacos(delta)
	_pintar()


# La libreta del Nocturno (autoload Libreta)
func _nota(cual: String) -> void:
	var libreta := get_node_or_null("/root/Libreta")
	if libreta:
		libreta.call(cual, "madre")


# --- Efectos (EfectosPixel, Liquido) ---

func _fx(lugar: String, donde: Vector3, hacia := Vector3.ZERO, escala := 1.0) -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		efectos.lanzar(lugar, donde, hacia, escala)


func _liquido() -> Node:
	return get_tree().get_first_node_in_group("liquido")


# Los sacos heridos gotean (mas entre mas heridos) y, si se arrastra, dejan rastro en el piso
func _sangrar_sacos(delta: float) -> void:
	var liquido := _liquido()
	if liquido == null or estado == Estado.CHARCO:
		return
	_rastro -= delta
	var arrastra := estado in [Estado.BARRE, Estado.TIRADA, Estado.ATURDIDA] and _rastro <= 0.0
	if arrastra:
		_rastro = RASTRO_CADA
	for n in SACOS:
		if sacos[n] <= 0.0 or sacos[n] >= SACO_VIDA:
			continue
		var vida_ := sacos[n] / SACO_VIDA
		var p := _saco(n)
		if p.y < charco.y:
			continue
		_goteo[n] -= delta
		if _goteo[n] <= 0.0:
			_goteo[n] = lerpf(GOTEO_CADA.y, GOTEO_CADA.x, vida_)
			liquido.salpicar(p, SACO_RADIO * 0.5, charco.y + 0.01, Vector3.DOWN, 2,
				COLOR_SACO_SANGRE if randf() < 0.6 else COLOR_SANGRE, Vector2(0.3, 1.2), 0.9)
		if arrastra and vida_ < 0.6:
			liquido.salpicar(p, 0.05, charco.y + 0.01, Vector3.DOWN, 3, COLOR_SACO_SANGRE, Vector2(1.0, 2.0), 0.3)


# --- Que hace ---

# Solo cuenta parado: brincar desde el piso (hasta ~2 m) no te sube
func _ver_arriba() -> void:
	if _jugador is CharacterBody3D and not (_jugador as CharacterBody3D).is_on_floor():
		return
	var antes := arriba
	arriba = _jugador.global_position.y - 1.0 - charco.y > ARRIBA_DESDE
	# Te subiste con ella afuera: se mete de un jalon a la alberca
	if arriba and not antes and estado in [Estado.VA, Estado.AVISA, Estado.TIRADA, Estado.BARRE, Estado.ATURDIDA, Estado.SALTA]:
		cuenta.zambullidas += 1
		_volver()
		if estado == Estado.CHARCO:
			_fx("madre_surge", charco, Vector3.ZERO, 1.0)
		Sonidos.tocar(self, "chapoteo", -6.0)


func _pensar(delta: float) -> void:
	var yo := _jugador.global_position
	var pies := Vector3(yo.x, charco.y, yo.z)
	var f := clampi(_fase() - 1, 0, 2)
	_anillo.visible = false
	match estado:
		Estado.CHARCO:
			# Da vueltas bajo el lodo
			_angulo += delta * 0.8
			_cabeza_a(S.BAJO_TIERRA, _hondo(charco + Vector3(cos(_angulo), 0.0, sin(_angulo)) * 2.0))
			if _reloj >= DESCANSO[f]:
				_siguiente()
		Estado.VA:
			# Solo nada en la alberca: si estas afuera va a la orilla mas cercana a ti
			_cabeza_a(S.BAJO_TIERRA | S.RAPIDO, _hondo(_dentro(pies)))
			if _reloj >= VA_DURA:
				_blanco = pies
				_desde = _dentro(pies)
				if not _en_alberca(pies):
					_blanco = _desde
				_cambiar(Estado.AVISA)
				# El unico aviso: un retumbo grave y quedito
				Sonidos.tocar(self, "retumbo", -12.0, 0.8)
		Estado.AVISA:
			_cabeza_a(S.BAJO_TIERRA, _hondo(_blanco))
			_cada -= delta
			if _cada <= 0.0:
				_cada = 0.3
				enjambre._tierra(_blanco + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)), 0.25)
			if _reloj >= AVISA_DURA and not _en_alberca(pies):
				# Estas en el cemento: salta de la orilla hacia donde estas ahorita
				_saltar(pies)
			elif _reloj >= AVISA_DURA:
				_cambiar(Estado.MUERDE)
				cuenta.mordidas += 1
				_fx("madre_tierra", _blanco, Vector3.ZERO, 1.2)
				Sonidos.tocar(self, "chapoteo", -4.0, 0.7)
				var dt := 1.0 / Engine.physics_ticks_per_second
				for i in 6:
					pos[i] = Vector3(_blanco.x, charco.y - 0.3 - i * 0.3, _blanco.z)
					old_pos[i] = pos[i] - Vector3.UP * 14.0 * dt
		Estado.MUERDE:
			# La cabeza y el cuello salen derecho para arriba; lo demas sigue enterrado
			for i in PUNTOS:
				if i < 7:
					modo[i] = S.AIRE | S.RAPIDO | (S.CABEZA if i == 0 else 0)
					meta[i] = _blanco + Vector3.UP * (MUERDE_ALTO - i * LARGO)
				else:
					modo[i] = S.BAJO_TIERRA
					meta[i] = pos[i - 1] if i > 0 else pos[i]
			if _reloj >= MUERDE_DURA:
				_cambiar(Estado.TIRADA)
				for i in PUNTOS:
					modo[i] = S.LIBRE
		Estado.TIRADA:
			# Cae y se queda tirada: los sacos al aire
			for i in PUNTOS:
				modo[i] = S.LIBRE
				meta[i] = pos[i]
			if _reloj >= TIRADA_DURA * (1.0 - f * 0.15):
				_descansar()
		Estado.BARRE:
			_cada += delta
			if _cada < EMBISTE_APUNTA:
				# El aviso: alza la cabeza hacia donde va a embestir; lo demas se queda
				var hacia := _blanco - pos[0]
				hacia.y = 0.0
				for i in PUNTOS:
					modo[i] = S.AIRE | S.CABEZA if i == 0 else 0
					meta[i] = pos[0] + hacia.normalized() * 0.3 + Vector3.UP * 0.9 if i == 0 else pos[i]
			else:
				_solver.velocidad = VELOCIDAD * EMBISTE_VEL
				_cabeza_a(S.RAPIDO, _blanco)
				_trepar()
			var falta := Vector2(_blanco.x - pos[0].x, _blanco.z - pos[0].z).length()
			if (_cada >= EMBISTE_APUNTA and falta < EMBISTE_LLEGA) or _cada >= EMBISTE_APUNTA + EMBISTE_MAX:
				_pasadas += 1
				if _pasadas >= EMBISTE_PASADAS[f]:
					_descansar()
				else:
					_apuntar_embestida(pies)
		Estado.VOMITA, Estado.ESCUPE:
			# Asoma la cabeza del charco, viendo hacia ti
			var hacia := pies - charco
			hacia.y = 0.0
			hacia = hacia.normalized()
			for i in PUNTOS:
				if i < 6:
					modo[i] = S.AIRE | (S.CABEZA if i == 0 else 0)
					meta[i] = charco + hacia * (1.5 - i * 0.25) * ESCALA + Vector3.UP * (2.8 - i * 0.45) * ESCALA
				else:
					modo[i] = S.BAJO_TIERRA
					meta[i] = _hondo(charco + Vector3(cos(i * 0.7), 0.0, sin(i * 0.7)) * 1.5)
			_cada -= delta
			if _cada <= 0.0 and _reloj > 0.6:
				var boca := pos[0] + (pos[0] - pos[1]).normalized() * 0.4 * ESCALA
				if estado == Estado.VOMITA:
					_cada = VOMITA_CADA
					enjambre.parir(boca, (yo - boca).normalized() + Vector3.UP * 0.4, VOMITA_CRIAS + f)
				else:
					_cada = ESCUPE_CADA
					_escupir(boca, yo)
			var dura: float = VOMITA_DURA if estado == Estado.VOMITA else ESCUPE_CADA * ESCUPE_BOLAS[f] + 0.8
			if _reloj >= dura:
				_descansar()
		Estado.SALTA:
			# La cabeza en arco de la orilla a donde estabas; el cuello la sigue en el arco y lo
			# demas se arrastra detras
			for i in PUNTOS:
				if i < SALTA_PUNTOS:
					var t := clampf(_reloj / SALTA_DURA - i * 0.07, 0.0, 1.0)
					modo[i] = S.AIRE | S.RAPIDO | (S.CABEZA if i == 0 else 0)
					meta[i] = _desde.lerp(_blanco, t) + Vector3.UP * (RADIO + sin(t * PI) * SALTA_ALTO)
				else:
					modo[i] = 0
					meta[i] = pos[i - 1]
			_trepar(SALTA_PUNTOS)
			if _reloj >= SALTA_DURA + 0.15:
				_fx("madre_tierra", _blanco, Vector3.ZERO, 1.0)
				Sonidos.tocar(self, "chapoteo", -4.0, 0.6)
				_cambiar(Estado.TIRADA)
				for i in PUNTOS:
					modo[i] = S.LIBRE
		Estado.REGRESA:
			# Se arrastra por el piso hasta la alberca y ahi se zambulle
			_cabeza_a(0, _dentro(pos[0]) if not _en_alberca(pos[0]) else charco)
			_trepar()
			# Se zambulle con medio cuerpo adentro, si no la cola cruzaria el cemento por debajo
			if (_en_alberca(pos[0], ORILLA * 0.5) and _en_alberca(pos[PUNTOS / 2])) or _reloj >= REGRESA_MAX:
				_cambiar(Estado.CHARCO)
				_meterse()
				_fx("madre_surge", Vector3(pos[0].x, charco.y, pos[0].z), Vector3.ZERO, 0.8)
				Sonidos.tocar(self, "chapoteo", -6.0)
		Estado.ATURDIDA:
			# Le reventaste un saco: se desploma donde esta y se retuerce. Los sacos quedan al aire
			for i in PUNTOS:
				modo[i] = S.LIBRE
				meta[i] = pos[i]
			if randf() < 0.25:
				var i := randi() % PUNTOS
				old_pos[i] = pos[i] - Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1)) * 0.05
			if _reloj >= ATURDIDA_DURA:
				_descansar()
		Estado.MUERE:
			# Se retuerce y se deshace
			if _reloj < 0.05 and _niebla == null:
				_niebla = EfectosPixel.cuadro_bucle("madre_niebla", 3.0, 1.0, 0.0, false, true)
				if _niebla:
					get_parent().add_child(_niebla)
					_niebla.global_position = charco
			if fmod(_reloj, 0.7) < 1.0 / 60.0:
				var donde := pos[randi() % PUNTOS]
				_fx("madre_muere", Vector3(donde.x, charco.y, donde.z), Vector3.ZERO, 0.8)
			for i in PUNTOS:
				modo[i] = S.LIBRE
				meta[i] = pos[i]
			if randf() < 0.3:
				var i := randi() % PUNTOS
				enjambre.sangrar(pos[i], Vector3.UP, 1.0)
				old_pos[i] = pos[i] - Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)) * 0.1
			if _reloj >= MUERE_DURA:
				visible = false
				set_physics_process(false)
				if _niebla:
					var niebla := _niebla
					_niebla = null
					get_tree().create_timer(4.0).timeout.connect(niebla.queue_free)
				_nota("matar")
				muerta.emit()


# La cabeza va a `objetivo` con `bits`; el cuerpo la sigue (en tierra o arrastrandose)
func _cabeza_a(bits: int, objetivo: Vector3) -> void:
	modo[0] = bits | S.CABEZA
	meta[0] = objetivo
	for i in range(1, PUNTOS):
		modo[i] = bits & ~(S.CABEZA | S.RAPIDO)
		meta[i] = pos[i - 1] if bits & S.BAJO_TIERRA else objetivo


# Acabo un ataque: al charco, o en fase 3 a veces otro de una vez
func _descansar() -> void:
	if not _en_alberca(pos[0]):
		_volver()
		return
	if _fase() >= 3 and randf() < ENCADENA:
		_siguiente()
		return
	_cambiar(Estado.CHARCO)
	_meterse()


# A la alberca: arrastrandose si quedo en el cemento (no nada por el piso), o de una si ya esta adentro
func _volver() -> void:
	if not _en_alberca(pos[0]):
		_cambiar(Estado.REGRESA)
	else:
		_cambiar(Estado.CHARCO)
		_meterse()


# La siguiente embestida: derecho a donde estas y EMBISTE_PASA m mas alla, sin pasar de EMBISTE_HASTA
func _apuntar_embestida(pies: Vector3) -> void:
	var hacia := pies - pos[0]
	hacia.y = 0.0
	if hacia.length_squared() < 0.01:
		hacia = Vector3.FORWARD
	var meta_ := pies + hacia.normalized() * EMBISTE_PASA
	if alberca > 0.0:
		meta_.x = clampf(meta_.x, charco.x - EMBISTE_HASTA, charco.x + EMBISTE_HASTA)
		meta_.z = clampf(meta_.z, charco.z - EMBISTE_HASTA, charco.z + EMBISTE_HASTA)
	_blanco = Vector3(meta_.x, charco.y + RADIO, meta_.z)
	_cada = 0.0
	Sonidos.tocar(self, "retumbo", -10.0, 1.1)


# Sale de la orilla en arco hacia `pies`: lo de la alberca sube al piso de un jalon, como al barrer
func _saltar(pies: Vector3) -> void:
	_blanco = pies
	_cambiar(Estado.SALTA)
	cuenta.saltos += 1
	_fx("madre_surge", _desde, Vector3.ZERO, 1.1)
	# Chapoteo, no chillido: el chillido es el de herida (saco reventado, cambio de fase)
	Sonidos.tocar(self, "chapoteo", -4.0, 0.8)
	var dt := 1.0 / Engine.physics_ticks_per_second
	for i in PUNTOS:
		pos[i].y = maxf(pos[i].y, charco.y + RADIO)
		old_pos[i] = pos[i] - Vector3.UP * 3.0 * dt


func _meterse() -> void:
	for i in PUNTOS:
		modo[i] = S.BAJO_TIERRA
		meta[i] = _hondo(charco)


# El siguiente ataque: mas variado y mas seguido conforme sube la fase
func _siguiente() -> void:
	var opciones := [Estado.VA, Estado.BARRE, Estado.VOMITA, Estado.ESCUPE]
	var e: Estado = opciones[_turno % opciones.size()] if _turno < 4 else opciones.pick_random()
	# Si estas arriba solo se asoma: escupe (su lodo si te alcanza) o vomita crias que suben por ti
	if arriba:
		e = Estado.ESCUPE if randf() < 0.65 else Estado.VOMITA
	_turno += 1
	_cambiar(e)
	_nota("ver")
	if e != Estado.VA:
		# Sale del charco: un geiser de lodo
		_fx("madre_surge", charco, Vector3.ZERO, 1.3)
		Sonidos.tocar(self, "chapoteo", -6.0)
	if e == Estado.BARRE:
		cuenta.barridos += 1
		_pasadas = 0
		var yo := _jugador.global_position
		_apuntar_embestida(Vector3(yo.x, charco.y, yo.z))
		# Sale del charco de un jalon
		var dt := 1.0 / Engine.physics_ticks_per_second
		for i in PUNTOS:
			pos[i].y = charco.y + RADIO
			old_pos[i] = pos[i] - Vector3.UP * 4.0 * dt
	elif e == Estado.VOMITA:
		cuenta.vomitos += 1
	elif e == Estado.ESCUPE:
		cuenta.escupidas += 1


func _escupir(boca: Vector3, yo: Vector3) -> void:
	var vel_jugador: Vector3 = _jugador.velocity if _jugador is CharacterBody3D else Vector3.ZERO
	var pecho := yo + Vector3.UP * 0.2
	var tarda := boca.distance_to(pecho) / ESCUPE_VEL
	var blanco := pecho + vel_jugador * tarda * ESCUPE_ADELANTA \
		+ Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * ESCUPE_ERROR
	var bala := Arrojadizo.lanzar(get_parent(), boca, (blanco - boca).normalized() * ESCUPE_VEL, 3, [])
	bala.dano = ESCUPE_DANO


# --- Dano al jugador por chocar con ella ---

func _chocar() -> void:
	if _choque > 0.0 or estado == Estado.CHARCO or estado == Estado.MUERE:
		return
	var yo := _jugador.global_position
	for i in PUNTOS:
		var p := pos[i]
		if absf(p.y - yo.y) > 1.0 + RADIO:
			continue
		var r := 0.45 + RADIO + 0.1
		if Vector2(p.x - yo.x, p.z - yo.z).length_squared() < r * r:
			var dano := DANO_MORDIDA if estado in [Estado.MUERDE, Estado.SALTA] and i < 3 else DANO_CHOQUE
			_jugador.recibir_dano(dano, p, 2.0)
			_choque = 0.8
			return


# Molotovs: le queman los sacos que esten en el fuego
func _quemar(delta: float) -> void:
	_fuego -= delta
	if _fuego > 0.0:
		return
	_fuego = FUEGO_CADA
	for zona in get_tree().get_nodes_in_group("zonas_lombriz"):
		if zona.tipo != ZonaLombrices.Tipo.FUEGO:
			continue
		for n in SACOS:
			if sacos[n] > 0.0 and ((_expuesto(n) and _saco(n).distance_to(zona.global_position) < zona.radio + SACO_RADIO) \
					or _seccion_alcanzada(n, zona.global_position, zona.radio + RADIO)):
				_herir(n, DANO_FUEGO, Vector3.UP, false)


# --- Sacos ---

func _saco(n: int) -> Vector3:
	var i: int = SACO_EN[n]
	var lado := (pos[i + 1] - pos[i - 1]).cross(Vector3.UP)
	return pos[i] + Vector3.UP * SACO_ALTO + (lado.normalized() * 0.1 * ESCALA * (1.0 if n % 2 == 0 else -1.0) if lado.length_squared() > 0.0001 else Vector3.ZERO)


# Solo cuando esta de veras afuera: tirada, barriendo o asomada vomitando o escupiendo
func _expuesto(n: int) -> bool:
	return not arriba and estado in [Estado.TIRADA, Estado.BARRE, Estado.VOMITA, Estado.ESCUPE, Estado.ATURDIDA, Estado.SALTA, Estado.REGRESA] \
		and _saco(n).y > charco.y + 0.1


# Algun punto expuesto de la seccion del saco `n` esta a menos de `radio` de `donde`
func _seccion_alcanzada(n: int, donde: Vector3, radio: float) -> bool:
	for i in PUNTOS:
		if _seccion(i) == n and _punto_expuesto(i) and pos[i].distance_to(donde) < radio:
			return true
	return false


# El saco vivo dueno del punto `i` del cuerpo: el de SACO_EN mas cercano (la cabeza va al primero y
# la cola al ultimo que quede). -1 si ya no quedan
func _seccion(i: int) -> int:
	var mejor := -1
	var mejor_d := 1000
	for n in SACOS:
		if sacos[n] > 0.0 and absi(SACO_EN[n] - i) < mejor_d:
			mejor_d = absi(SACO_EN[n] - i)
			mejor = n
	return mejor


# El punto `i` del cuerpo se puede herir: esta afuera (los mismos estados que los sacos) y sobre el charco
func _punto_expuesto(i: int) -> bool:
	return not arriba and estado in [Estado.TIRADA, Estado.BARRE, Estado.VOMITA, Estado.ESCUPE, Estado.ATURDIDA, Estado.SALTA, Estado.REGRESA] \
		and pos[i].y > charco.y - RADIO * 0.5


# El siguiente saco que conviene: el primero que siga vivo (brilla mas mientras esta aturdida)
func _siguiente_saco() -> int:
	for n in SACOS:
		if sacos[n] > 0.0:
			return n
	return -1


# `hacia`: de donde vino el golpe (el chorro sale para alla). `chorro` false: el fuego, que no salpica
func _herir(n: int, dano: float, hacia := Vector3.UP, chorro := true) -> void:
	if sacos[n] <= 0.0:
		return
	sacos[n] -= dano
	_nota("pelear")
	var donde := _saco(n)
	if chorro:
		var liquido := _liquido()
		if liquido:
			var sale := (hacia.normalized() + Vector3.UP * 0.6).normalized()
			liquido.salpicar(donde, SACO_RADIO * 0.5, charco.y + 0.01, sale, 8, COLOR_SACO_SANGRE, Vector2(2.0, 4.5), 0.4)
			liquido.salpicar(donde, SACO_RADIO * 0.5, charco.y + 0.01, sale, 4, COLOR_SANGRE, Vector2(2.0, 4.0), 0.5)
		_fx("saco_golpe", donde, hacia, 0.8)
		if Time.get_ticks_msec() - _squelch > 90:
			_squelch = Time.get_ticks_msec()
			Sonidos.tocar(self, "squelch", -6.0, randf_range(0.9, 1.15))
	if sacos[n] > 0.0:
		return
	# Revienta: un chorro grande, mancha en el piso, se desploma y la fase sube cada dos
	_fx("saco_revienta", Vector3(donde.x, charco.y, donde.z), Vector3.ZERO, 1.2)
	Sonidos.tocar(self, "reventar", -2.0, 0.8)
	var liquido := _liquido()
	if liquido:
		liquido.reventar(donde, SACO_RADIO, charco.y + 0.01, 24, COLOR_SACO_SANGRE, Vector2(2.5, 6.0))
		liquido.reventar(donde, SACO_RADIO, charco.y + 0.01, 10, COLOR_SANGRE, Vector2(2.0, 5.0))
		liquido.salpicar(Vector3(donde.x, charco.y + 0.3, donde.z), 0.6, charco.y + 0.01, Vector3.DOWN, 16, COLOR_SACO_SANGRE, Vector2(0.5, 1.5), 1.0)
	for i in PUNTOS:
		old_pos[i] = pos[i] - Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1)) * 0.06
	var q := quedan()
	saco_reventado.emit(q)
	var antes := enjambre.fase
	enjambre.fase = 1 + (SACOS - q) / 2
	if q == 0:
		_cambiar(Estado.MUERE)
		_anillo.visible = false
		Sonidos.tocar(self, "chillido", 0.0, 0.7)
		return
	if enjambre.fase != antes:
		_fx("fase_onda", Vector3(pos[0].x, charco.y, pos[0].z), Vector3.ZERO, 1.4)
		Sonidos.tocar(self, "chillido", -2.0)
	# Se desploma: la ventana para ir por el siguiente
	_cambiar(Estado.ATURDIDA)
	cuenta.aturdidas += 1


# --- Armas (mismo trato que las crias: EnjambreLombrices.rayo, Player._golpear) ---

# Le pega a un saco expuesto (dot_index 0..5) o a su cuerpo, que tapa (dot_index 100 + punto)
func query_ray_hit(ray_origin: Vector3, ray_dir: Vector3, max_dist: float, hit_radius: float) -> Dictionary:
	if estado == Estado.MUERE or not visible:
		return {}
	var dir := ray_dir.normalized()
	var mejor := -1
	var mejor_t := max_dist
	for n in SACOS:
		if sacos[n] > 0.0 and _expuesto(n):
			var t := _esfera(ray_origin, dir, _saco(n), SACO_RADIO + hit_radius)
			if t >= 0.0 and t < mejor_t:
				mejor_t = t
				mejor = n
	for i in PUNTOS:
		if pos[i].y < charco.y - RADIO:
			continue
		var t := _esfera(ray_origin, dir, pos[i], RADIO)
		if t >= 0.0 and t < mejor_t:
			mejor_t = t
			mejor = 100 + i
	if mejor == -1:
		return {}
	return {"dot_index": mejor, "position": ray_origin + dir * mejor_t, "distance": mejor_t}


static func _esfera(origen: Vector3, dir: Vector3, centro: Vector3, r: float) -> float:
	var oc := centro - origen
	var t := oc.dot(dir)
	var d2 := oc.length_squared() - t * t
	if t < 0.0 or d2 > r * r:
		return -1.0
	return maxf(t - sqrt(r * r - d2), 0.0)


func bullet_hit(dot_index: int, hit_point: Vector3, dir: Vector3) -> void:
	if dot_index < SACOS:
		_herir(dot_index, DANO_BALA, -dir)
	else:
		# Al cuerpo: rebota, no le hace nada (solo a las crestas)
		enjambre.sangrar(hit_point, -dir + Vector3.UP * 0.3, 0.15)


func golpe_cuerpo(origen: Vector3, frente: Vector3, alcance: float, cono: float, dano: int, giro := false, todas := false) -> bool:
	if estado == Estado.MUERE or not visible:
		return false
	var pego := false
	var mejor := -1
	var mejor_d := INF
	for n in SACOS:
		if sacos[n] <= 0.0 or not _expuesto(n):
			continue
		var p := _saco(n)
		if p.y - origen.y > 1.6 or p.y - origen.y < -1.4:
			continue
		var hacia := Vector3(p.x - origen.x, 0.0, p.z - origen.z)
		var d := hacia.length()
		if d > alcance + SACO_RADIO + 0.3:
			continue
		if not giro and d > 0.01 and hacia.normalized().dot(frente) < cono:
			continue
		if todas:
			_herir(n, dano, frente)
			pego = true
		elif d < mejor_d:
			mejor_d = d
			mejor = n
	if mejor >= 0:
		# Un machetazo normal (o giro, o estocada) a la cresta: le pega pero no le baja
		pego = true
	if not pego:
		# Contra el cuerpo: hiere al saco de esa seccion (al del punto mas cercano; con `todas`, a cada
		# seccion que alcance una vez). Escondida, se siente el golpe pero no le hace nada
		var heridos := {}
		var cerca := -1
		var cerca_d := INF
		for i in PUNTOS:
			var hacia := Vector3(pos[i].x - origen.x, 0.0, pos[i].z - origen.z)
			if hacia.length() < alcance + RADIO and absf(pos[i].y - origen.y) < 1.0 + RADIO \
					and (giro or hacia.length() < 0.01 or hacia.normalized().dot(frente) >= cono):
				pego = true
				if not todas or not _punto_expuesto(i):
					continue
				var n := _seccion(i)
				if n < 0:
					continue
				if todas:
					heridos[n] = true
				elif hacia.length() < cerca_d:
					cerca_d = hacia.length()
					cerca = n
		if cerca >= 0:
			heridos[cerca] = true
		for n: int in heridos:
			_herir(n, dano * DANO_CUERPO, frente)
	return pego


func apply_explosion_impulse(origin: Vector3, radius: float, force: float, mata := true) -> void:
	if estado == Estado.MUERE:
		return
	if mata:
		for n in SACOS:
			if sacos[n] > 0.0 and _expuesto(n) and _saco(n).distance_to(origin) < radius:
				_herir(n, force * 2.0, _saco(n) - origin)
			elif sacos[n] > 0.0 and _seccion_alcanzada(n, origin, radius):
				_herir(n, force * 2.0 * DANO_CUERPO, pos[SACO_EN[n]] - origin)


# --- Dibujo ---

func _pintar() -> void:
	var dato_extra := 0.6
	var n := 0
	var ne := 0
	# Donde hay una aleta (punto debil) no va la espina chica: se encimarian
	var con_aleta := PackedByteArray()
	con_aleta.resize(PUNTOS)
	for c in SACOS:
		if sacos[c] > 0.0:
			con_aleta[SACO_EN[c]] = 1
	for i in PUNTOS - 1:
		var k := float(i)
		var afina := lerpf(1.15, 0.45, k / PUNTOS)
		var late := 1.0 + 0.12 * sin(_t * 4.0 - k * 0.7)
		var t := MallaLombriz.tramo(pos[i + 1], pos[i], GRUESO * afina * late, 1.15)
		# .g: las grietas brillan mas hacia la cola; .a: la semilla de la piel de este tramo
		var grietas := lerpf(0.25, 1.0, k / (PUNTOS - 1))
		MallaLombriz.escribir(_buf, n, t, COLOR, Color(0.0, grietas, dato_extra, fmod(k * 0.37, 1.0)))
		n += 1
		if con_aleta[i] == 1:
			continue
		# La espina del lomo: de la nuca a la cola, grandes al medio, inclinadas hacia atras
		var arriba := Vector3.UP
		var atras := (pos[i + 1] - pos[i]).normalized()
		var alto := GRUESO * afina * 1.5 * (1.0 if i % 2 == 0 else 0.65) * sin(PI * (k + 1.0) / PUNTOS + 0.15)
		var dir := (arriba + atras * 0.45).normalized()
		var ancho := GRUESO * afina * 0.55
		var ex := dir.cross(Vector3.RIGHT).normalized() if absf(dir.dot(Vector3.RIGHT)) < 0.95 else dir.cross(Vector3.FORWARD).normalized()
		var ez := ex.cross(dir)
		var base := pos[i] + arriba * GRUESO * afina * 0.75
		MallaLombriz.escribir(_buf_esp, ne, Transform3D(Basis(ex * ancho, dir * maxf(alto, 0.05), ez * ancho), base), COLOR, Color(0.0, grietas, dato_extra + late * 0.4, 0.0))
		ne += 1
	_malla.buffer = _buf
	_malla.visible_instance_count = n
	_espinas.buffer = _buf_esp
	_espinas.visible_instance_count = ne
	var adelante := (pos[0] - pos[1]).normalized()
	var abre := 1.0 if estado in [Estado.MUERDE, Estado.VOMITA, Estado.ESCUPE, Estado.AVISA, Estado.ATURDIDA] else 0.2
	var t := MallaLombriz.tramo(pos[0] - adelante * 0.3 * ESCALA, pos[0] + adelante * 0.5 * ESCALA, GRUESO * 1.4, 1.0)
	MallaLombriz.escribir(_buf_cab, 0, t, COLOR.darkened(0.2), Color(abre, 0.1, dato_extra, 0.5))
	_cabeza.buffer = _buf_cab
	_cabeza.visible_instance_count = 1
	var siguiente := _siguiente_saco() if estado == Estado.ATURDIDA else -1
	for k in SACOS:
		var bolsa := _bolsas[k]
		bolsa.visible = sacos[k] > 0.0
		if not bolsa.visible:
			continue
		# Turquesa -> amarillo -> rojo, y late mas rapido entre mas roto
		var vida_ := clampf(sacos[k] / SACO_VIDA, 0.0, 1.0)
		var color := SACO_MEDIO.lerp(SACO_LLENO, (vida_ - 0.5) * 2.0) if vida_ > 0.5 else SACO_ROTO.lerp(SACO_MEDIO, vida_ * 2.0)
		var late := sin(_t * lerpf(LATE.y, LATE.x, vida_) + k)
		var material := _materiales[k]
		material.set_shader_parameter("color_grieta", color)
		material.set_shader_parameter("color_nucleo", color.lerp(Color.WHITE, 0.12))
		material.set_shader_parameter("brillo", (2.2 + late * 0.8) * (1.8 if k == siguiente else 1.0))
		var pulso := 1.0 + late * (0.12 + (1.0 - vida_) * 0.1) + (0.25 if k == siguiente else 0.0)
		# La aleta mira a lo largo del cuerpo (la punta echada hacia la cola), es delgada de lado, va
		# centrada en el lomo y crece con el grueso del cuerpo, como las espinas: las de la cola son
		# mas chicas. El golpe sigue en _saco(k).
		var i: int = SACO_EN[k]
		var cola := pos[i + 1] - pos[i - 1]
		cola.y = 0.0
		var ex := cola.normalized() if cola.length_squared() > 0.0001 else Vector3.RIGHT
		var ez := ex.cross(Vector3.UP)
		var afina := lerpf(1.15, 0.45, float(i) / PUNTOS)
		var tam := GRUESO * afina
		bolsa.global_transform = Transform3D(Basis(ex * tam * 1.2 * pulso, Vector3.UP * tam * 2.1 * pulso, ez * tam * 1.2), pos[i] + Vector3.UP * tam * 0.55)
