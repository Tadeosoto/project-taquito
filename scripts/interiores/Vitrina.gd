class_name Vitrina
extends Node3D

# Lo que vende un interior, flotando y dando vueltas sobre el mostrador: solo el
# producto elegido; al cambiar, se va hacia un lado y entra el otro. Interior.gd
# la pone en su nodo `Vitrina`. Cada modelo se escala a una caja de 1 m (los de
# Sketchfab vienen en cualquier unidad) y luego al tamano de su lugar.

const TAMANO_CENTRO := 0.32
const SEPARACION := 0.6
const GIRO_CENTRO := 70.0   # grados por segundo
const DESLIZAR := 0.25      # s

var _pivotes: Array[Node3D] = []
var _indice := 0
var _tiempo := 0.0


func mostrar(productos: Array[InventoryItemData]) -> void:
	for producto in productos:
		var pivote := Node3D.new()
		add_child(pivote)
		_pivotes.append(pivote)
		if producto == null or producto.inspection_model == null:
			continue
		var modelo := producto.inspection_model.instantiate() as Node3D
		var caja := Mueble.medir(modelo)
		var mayor := maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
		if mayor > 0.0:
			modelo.scale = Vector3.ONE / mayor
			modelo.position = -caja.get_center() / mayor
		pivote.add_child(modelo)
	# Una luz chiquita para que se vea aunque quede afuera de la reja o en lo oscuro
	var luz := OmniLight3D.new()
	luz.position = Vector3(0, 0.4, 0.6)
	luz.light_energy = 0.8
	luz.omni_range = 1.8
	add_child(luz)
	_acomodar()


func actual() -> int:
	return _indice


func mover(paso: int) -> void:
	if _pivotes.is_empty():
		return
	var antes := _pivotes[_indice]
	_indice = wrapi(_indice + paso, 0, _pivotes.size())
	if _pivotes[_indice] == antes:
		return
	# El que estaba sale hacia el lado contrario encogiendose; el nuevo entra del otro
	_deslizar(antes, Vector3(-paso * SEPARACION, 0, 0), Vector3.ZERO, true)
	var nuevo := _pivotes[_indice]
	nuevo.visible = true
	nuevo.position = Vector3(paso * SEPARACION, 0, 0)
	nuevo.scale = Vector3.ONE * 0.01
	_deslizar(nuevo, Vector3.ZERO, Vector3.ONE * TAMANO_CENTRO, false)


func _acomodar() -> void:
	for i in _pivotes.size():
		_pivotes[i].visible = i == _indice
		_pivotes[i].position = Vector3.ZERO
		_pivotes[i].scale = Vector3.ONE * TAMANO_CENTRO


func _deslizar(pivote: Node3D, destino: Vector3, escala: Vector3, esconder: bool) -> void:
	# Si cambias rapido, el tween anterior de ese producto se cancela
	if pivote.has_meta("tween"):
		(pivote.get_meta("tween") as Tween).kill()
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pivote.set_meta("tween", tween)
	tween.tween_property(pivote, "position:x", destino.x, DESLIZAR)
	tween.tween_property(pivote, "scale", escala.max(Vector3.ONE * 0.01), DESLIZAR)
	if esconder:
		tween.chain().tween_callback(func(): pivote.visible = pivote == _pivotes[_indice])


func _process(delta: float) -> void:
	_tiempo += delta
	for pivote in _pivotes:
		if pivote.visible:
			pivote.rotation_degrees.y += GIRO_CENTRO * delta
			pivote.position.y = sin(_tiempo * 2.0) * 0.02
