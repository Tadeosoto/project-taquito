class_name Arrojadizo
extends Node3D
# Lo que avienta el Lanzador (y lo que escupe la Madre): vuela a mano, sin cuerpo de fisica. La
# molotov va en parabola y revienta en fuego (ZonaLombrices). El escupitajo de la Madre (tipo 3) es
# como un balazo: derecho, sin gravedad, y si te da te baja `dano`; no deja charco (JJ).
# La palomita (tipo PALOMITA, JJ) va en parabola como la molotov; al caer truena como balazo,
# luego te zumban los oidos (zumbido_oidos) y mientras dura el zumbido los zombis a ATURDE_RADIO
# se quedan atontados (Zombie.aturdir). Una cebada (`cebada`, Lanzador.CEBADA_PROB) cae sin tronar
# y sale "¡Se cebó!"; la que truena en la mano la truena el Lanzador con tronar.
# La bocina (BOCINA, o BOCINA_AGUA encintada con la botella) vuela dando vueltas y al caer se queda
# sonando y jalando zombis (Senuelo).

const GRAVEDAD := 14.0
const VIDA := 4.0
const SAL_RADIO := 1.5
const SAL_DURA := 12.0
const FUEGO_RADIO := 2.0
const FUEGO_DURA := 5.0
const PALOMITA := 4
const BOCINA := 5
const BOCINA_AGUA := 6
const MOLOTOV_CEREZA := 7       # la de gasolina de cereza (JJ): el fuego llega 1.5 veces mas lejos
const CEREZA_ALCANCE := 1.5     # x FUEGO_RADIO (la de limon, 2, es la de siempre y la de la Madre)
const ATURDE_RADIO := 7.0       # m: los zombis que alcanza el trueno
const OYEN_TRUENO := 30.0       # m: los que no aturde pero voltean (Zombie.ruido)
const TRUENO_TONO := 0.8        # el balazo mas grave, de cohete
const ZUMBIDO_CERCA := -6.0     # dB del zumbido si truena junto a ti...
const ZUMBIDO_LEJOS := -16.0    # ...y a OYEN_TRUENO m
const DESTELLO_DURA := 0.15
# La molotov en el aire: el tamaño del fuego del trapo y la luz que echa
const TRAPO_FUEGO := 0.06
const MECHA_LUZ := 1.4
const CEBADA_QUEDA := 2.5       # s que se queda tirada la cebada
const TEXTO_SUBE := 0.8         # m que sube el letrero en TEXTO_DURA
const TEXTO_DURA := 2.5
# El escupitajo: una gota que se estira con la velocidad y tiembla, con una cola de gotitas, de
# Serenol como agua radioactiva del azul de las espinas (shaders/escupitajo.gdshader)
const ESCUPE_COLOR := Color(0.18, 0.77, 1.0)
# A escala de la Madre (MadreCarcamo.ESCALA): crece con ella
const ESCUPE_RADIO := 0.15 * MadreCarcamo.ESCALA
const ESCUPE_ESTIRA := 0.07      # x la rapidez: cuanto se alarga
const ESCUPE_COLA := [0.1 * MadreCarcamo.ESCALA, 0.075 * MadreCarcamo.ESCALA, 0.055 * MadreCarcamo.ESCALA, 0.04 * MadreCarcamo.ESCALA]   # radio de cada gotita de la cola
const ESCUPE_COLA_CADA := 1      # cuadros de atraso entre gotitas

static var _material_escupe: ShaderMaterial

var tipo := 1          # 1 sal, 2 molotov; 3 lodo (la Madre); PALOMITA, BOCINA, BOCINA_AGUA
var dano := 0           # el escupitajo: lo que te baja si te da
var cebada := false     # la palomita: cae y no truena
var velocidad := Vector3.ZERO
var _edad := 0.0
var _excluir: Array[RID] = []
var _gota: MeshInstance3D
var _cola: Array[MeshInstance3D] = []
var _rastro := PackedVector3Array()
var _mecha: OmniLight3D   # la luz del trapo prendido de la molotov, que titila


static func lanzar(padre: Node, desde: Vector3, vel: Vector3, tipo_: int, excluir: Array[RID]) -> Arrojadizo:
	var a := Arrojadizo.new()
	a.tipo = tipo_
	a.velocidad = vel
	a._excluir = excluir
	padre.add_child(a)
	a.global_position = desde
	return a


# Las dos molotovs: la de limon (2, como `InventoryItemData.arrojar`) y la de cereza
func es_molotov() -> bool:
	return tipo == 2 or tipo == MOLOTOV_CEREZA


# Lo que quema la molotov de ese `tipo` (m): la de cereza llega CEREZA_ALCANCE veces mas lejos
static func fuego_radio(tipo_: int) -> float:
	return FUEGO_RADIO * (CEREZA_ALCANCE if tipo_ == MOLOTOV_CEREZA else 1.0)


func _ready() -> void:
	var malla := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if es_molotov():
		malla.free()
		var botella := BotellaMolotov.new()
		botella.etapa = BotellaMolotov.MOLOTOV
		botella.sabor = BotellaMolotov.CEREZA if tipo == MOLOTOV_CEREZA else BotellaMolotov.LIMON
		botella.position.y = -0.15
		add_child(botella)
		# El trapo prendido (JJ): el fuego de pixel de los tambos, en chiquito, en la punta del trapo
		var fuego := EfectosPixel.cuadro_bucle("fuego_tambo", TRAPO_FUEGO)
		if fuego:
			fuego.position = BotellaMolotov.MECHA
			botella.add_child(fuego)
		_mecha = OmniLight3D.new()
		_mecha.light_color = Color(1.0, 0.6, 0.2)
		_mecha.light_energy = MECHA_LUZ
		_mecha.omni_range = 2.5
		_mecha.position = botella.position + BotellaMolotov.MECHA
		add_child(_mecha)
		return
	elif tipo == 3:
		malla.free()
		_armar_escupitajo()
		return
	elif tipo == BOCINA or tipo == BOCINA_AGUA:
		malla.free()
		add_child(BocinaEncintada.new() if tipo == BOCINA_AGUA else Bocina.new())
		return
	elif tipo == PALOMITA:
		malla.free()
		add_child(Palomita.new())
		# La mecha prendida
		var chispa := OmniLight3D.new()
		chispa.light_color = Color(1.0, 0.75, 0.3)
		chispa.light_energy = 0.8
		chispa.omni_range = 1.5
		chispa.position.y = -Palomita.ALTO / 3.0 - Palomita.MECHA_LARGO
		add_child(chispa)
		return
	else:
		var bolsa := BoxMesh.new()
		bolsa.size = Vector3(0.14, 0.2, 0.08)
		malla.mesh = bolsa
		material.albedo_color = Color(0.9, 0.9, 0.95)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	malla.material_override = material
	add_child(malla)


func _physics_process(delta: float) -> void:
	_edad += delta
	if tipo != 3:
		velocidad.y -= GRAVEDAD * delta
	var desde := global_position
	var hasta := desde + velocidad * delta
	var rayo := PhysicsRayQueryParameters3D.create(desde, hasta, 1, _excluir)
	var pego := get_world_3d().direct_space_state.intersect_ray(rayo)
	if tipo == 3:
		_mover_escupitajo(desde)
	else:
		rotation += Vector3(7.0, 3.0, 0.0) * delta
	if _mecha:
		_mecha.light_energy = MECHA_LUZ * randf_range(0.7, 1.15)
	if pego:
		if tipo == 3 and pego.collider and pego.collider.is_in_group("jugador") and pego.collider.has_method("recibir_dano"):
			pego.collider.recibir_dano(dano, desde, 0.6)
		_reventar(pego.position)
		return
	global_position = hasta
	if _edad > VIDA:
		_reventar(global_position)


func _armar_escupitajo() -> void:
	if _material_escupe == null:
		_material_escupe = ShaderMaterial.new()
		_material_escupe.shader = load("res://shaders/escupitajo.gdshader")
	_gota = _esfera(ESCUPE_RADIO)
	add_child(_gota)
	# La cola va suelta en el mundo: cada gotita en donde estuvo la gota unos cuadros antes
	for radio: float in ESCUPE_COLA:
		var gotita := _esfera(radio)
		gotita.top_level = true
		gotita.visible = false
		add_child(gotita)
		_cola.append(gotita)
	var luz := OmniLight3D.new()
	luz.light_color = ESCUPE_COLOR
	luz.light_energy = 0.8
	luz.omni_range = 2.5
	add_child(luz)


func _esfera(radio: float) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = radio
	esfera.height = radio * 2.0
	esfera.radial_segments = 8
	esfera.rings = 4
	esfera.material = _material_escupe
	malla.mesh = esfera
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return malla


# Estirada hacia donde va y temblando como algo espeso; la cola la sigue
func _mover_escupitajo(desde: Vector3) -> void:
	var rapidez := velocidad.length()
	if rapidez > 0.1:
		var adelante := velocidad / rapidez
		var arriba := Vector3.UP if absf(adelante.y) < 0.95 else Vector3.RIGHT
		var largo := clampf(1.0 + rapidez * ESCUPE_ESTIRA, 1.0, 1.9)
		var tiembla := sin(_edad * 26.0) * 0.1
		var ancho := (1.0 + tiembla) / sqrt(largo)
		_gota.basis = Basis.looking_at(adelante, arriba).scaled_local(Vector3(ancho, ancho * (1.0 - tiembla * 0.5), largo * (1.0 - tiembla)))
	_rastro.insert(0, desde)
	var cabe := (_cola.size() + 1) * ESCUPE_COLA_CADA
	if _rastro.size() > cabe:
		_rastro.resize(cabe)
	for n in _cola.size():
		var atras := (n + 1) * ESCUPE_COLA_CADA
		_cola[n].visible = _rastro.size() > atras
		if _cola[n].visible:
			_cola[n].global_position = _rastro[atras]


func _reventar(donde: Vector3) -> void:
	var padre := get_parent()
	if es_molotov():
		ZonaLombrices.crear(padre, donde, ZonaLombrices.Tipo.FUEGO, fuego_radio(tipo), FUEGO_DURA)
		Sonidos.tocar(self, "whack", -6.0, 0.6)
	elif tipo == 3:
		pass
	elif tipo == BOCINA or tipo == BOCINA_AGUA:
		Senuelo.crear(padre, donde, tipo == BOCINA_AGUA)
		Sonidos.tocar(padre, "golpe", -10.0, 1.3)
		queue_free()
		return
	elif tipo == PALOMITA:
		if cebada:
			_cebarse(padre, donde)
			return
		tronar(padre, donde)
		queue_free()
		return
	else:
		ZonaLombrices.crear(padre, donde, ZonaLombrices.Tipo.SAL, SAL_RADIO, SAL_DURA)
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		match tipo:
			2, MOLOTOV_CEREZA:
				efectos.lanzar("molotov_revienta", donde, Vector3.ZERO, fuego_radio(tipo) / FUEGO_RADIO)
			3:
				efectos.lanzar("lodo_choque", donde)
				Sonidos.tocar(self, "squelch", -8.0, 0.7)
			_:
				efectos.lanzar("cria_cabeza", donde + Vector3.UP * 0.2, Vector3.ZERO, 0.8)
	queue_free()


# La palomita: el balazo, el destello y el zumbido, que dura lo que quedan atontados los
# zombis de alrededor (lo regresa: el Lanzador aturde con eso al jugador si le trono en la mano).
# Los sonidos van en `padre`: la palomita se borra ya
static func tronar(padre: Node, donde: Vector3) -> float:
	Sonidos.tocar(padre, "disparo_pistola", 2.0, TRUENO_TONO)
	var zumbido := Sonidos.sonido("zumbido_oidos")
	var jugador := padre.get_tree().get_first_node_in_group("jugador") as Node3D
	var lejos := donde.distance_to(jugador.global_position) if jugador else OYEN_TRUENO
	Sonidos.tocar(padre, "zumbido_oidos", lerpf(ZUMBIDO_CERCA, ZUMBIDO_LEJOS, clampf(lejos / OYEN_TRUENO, 0.0, 1.0)))
	var dura := zumbido.get_length() if zumbido else 4.0
	for zombi in Zombie.activos:
		if is_instance_valid(zombi) and zombi.global_position.distance_to(donde) <= ATURDE_RADIO:
			zombi.aturdir(dura)
	Zombie.ruido(donde, OYEN_TRUENO)
	var destello := OmniLight3D.new()
	destello.light_color = Color(1.0, 0.95, 0.85)
	destello.light_energy = 8.0
	destello.omni_range = ATURDE_RADIO
	padre.add_child(destello)
	destello.global_position = donde + Vector3.UP * 0.5
	var apaga := destello.create_tween()
	apaga.tween_property(destello, "light_energy", 0.0, DESTELLO_DURA)
	apaga.tween_callback(destello.queue_free)
	return dura


# La cebada: se queda tirada sin tronar, con la mecha apagada, y sale el letrero
func _cebarse(padre: Node, donde: Vector3) -> void:
	set_physics_process(false)
	global_position = donde + Vector3.UP * Palomita.GRUESO * 0.5
	rotation = Vector3(-PI / 2.0, randf() * TAU, 0.0)
	for hijo in get_children():
		if hijo is OmniLight3D:
			hijo.queue_free()
	Sonidos.tocar(padre, "fizz", -14.0, 0.7)
	letrero(padre, donde, "¡Se cebó!")
	var quita := create_tween()
	quita.tween_interval(CEBADA_QUEDA)
	quita.tween_callback(queue_free)


# Un letrero que sube y se desvanece sobre `donde` (la cebada, la que te truena en la mano).
# Tamaño fijo en pantalla, para que se lea aunque caiga lejos
static func letrero(padre: Node, donde: Vector3, texto: String) -> void:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.fixed_size = true
	etiqueta.no_depth_test = true
	etiqueta.pixel_size = 0.0012
	etiqueta.font_size = 56
	etiqueta.outline_size = 16
	etiqueta.modulate = Color(1.0, 0.95, 0.4)
	etiqueta.outline_modulate = Color.BLACK
	padre.add_child(etiqueta)
	etiqueta.global_position = donde + Vector3.UP * 0.6
	var sube := etiqueta.create_tween().set_parallel()
	sube.tween_property(etiqueta, "global_position", etiqueta.global_position + Vector3.UP * TEXTO_SUBE, TEXTO_DURA)
	sube.tween_property(etiqueta, "modulate:a", 0.0, TEXTO_DURA * 0.4).set_delay(TEXTO_DURA * 0.6)
	sube.tween_property(etiqueta, "outline_modulate:a", 0.0, TEXTO_DURA * 0.4).set_delay(TEXTO_DURA * 0.6)
	sube.chain().tween_callback(etiqueta.queue_free)
