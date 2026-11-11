class_name CarrosColonia
extends Node3D

# Los carros estacionados, del taller y el quemado de la casa derrumbada del mapa en Blender: los cuatro
# modelos de Sketchfab (CarrosModelo: Grand Vitara, Tsuru, vocho y la van blanca). Cada carro es
# [x, z, giro, modelo, estado, y] en resources/mapa/<colonia>/carros_modelo.json (lo escribe exportar.py,
# con sus cajas de choque en el .glb): un MultiMesh por modelo, estado y celda.
# Estados: "normal"; "ladrillos" (sin llantas, sobre dos ladrillos de block por cada una, los
# ladrillos en otro MultiMesh); "quemado" (CarrosModelo.quemado: manchas negras de hollin y sin vidrios).

@export_file("*.json") var carros_path := "res://resources/mapa/santa_mugre/carros_modelo.json"
@export var visible_hasta := 160.0
# Un MultiMesh por celda de CELDA m, para que se recorten y no se dibujen los de lejos
@export var celda := 48.0

# Los ladrillos: block de 50 x 20 x 26 cm, apilados de dos en dos bajo cada llanta que falta
const BLOCK := Vector3(0.5, 0.2, 0.26)
const PILA := 2
const BLOCK_COLOR := Color(0.5, 0.48, 0.45)
# Cuanto se meten hacia el centro (m): la llanta iba afuera, el block queda bajo el faldon
const BLOCK_ADENTRO := 0.25


func _ready() -> void:
	var datos = JSON.parse_string(FileAccess.get_file_as_string(carros_path))
	if not datos is Dictionary:
		push_warning("CarrosColonia: no se pudo leer %s" % carros_path)
		return
	var grupos := {}
	var blocks := {}
	for c: Array in datos["carros"]:
		var modelo: String = c[3]
		var estado: String = c[4]
		var celda_x := floori(c[0] / celda)
		var celda_z := floori(c[1] / celda)
		var clave := "%s|%s|%d|%d" % [modelo, estado, celda_x, celda_z]
		var base := Basis(Vector3.UP, c[2])
		var sube := 0.0
		if estado == "ladrillos":
			var sin := CarrosModelo.sin_ruedas(modelo)
			var altura := BLOCK.y * PILA
			sube = maxf(altura - float(sin["suelo"]), 0.0)
			var llave := "%d|%d" % [celda_x, celda_z]
			if not blocks.has(llave):
				blocks[llave] = []
			for rueda: Vector3 in sin["ruedas"]:
				var dentro := Vector3(rueda.x - signf(rueda.x) * BLOCK_ADENTRO, 0.0, rueda.z)
				for k in PILA:
					# Cada block un poco chueco, como los dejaron
					var giro := Basis(Vector3.UP, c[2] + sin(rueda.x * 13.0 + rueda.z * 7.0 + k) * 0.12)
					blocks[llave].append(Transform3D(giro, Vector3(c[0], c[5], c[1]) + base * (dentro + Vector3(0.0, BLOCK.y * (k + 0.5), 0.0))))
		if not grupos.has(clave):
			grupos[clave] = []
		grupos[clave].append(Transform3D(base, Vector3(c[0], c[5] + sube, c[1])))
	for clave: String in grupos:
		var partes: PackedStringArray = clave.split("|")
		var malla: ArrayMesh
		match partes[1]:
			"ladrillos":
				malla = CarrosModelo.sin_ruedas(partes[0])["malla"]
			"quemado":
				malla = CarrosModelo.quemado(partes[0])
			_:
				malla = CarrosModelo.malla(partes[0])
		_multimesh("%s_%s_%s_%s" % [partes[0].capitalize(), partes[1], partes[2], partes[3]], malla, grupos[clave])
	if not blocks.is_empty():
		var caja := BoxMesh.new()
		caja.size = BLOCK
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/ps1_combined.gdshader")
		material.set_shader_parameter("tint", BLOCK_COLOR)
		material.set_shader_parameter("jitter_enabled", false)
		material.set_shader_parameter("wobble_enabled", false)
		material.set_shader_parameter("affine_enabled", false)
		caja.material = material
		for llave: String in blocks:
			_multimesh("Blocks_%s" % llave.replace("|", "_"), caja, blocks[llave])


func _multimesh(nombre: String, malla: Mesh, lista: Array) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = malla
	multi.instance_count = lista.size()
	for i in lista.size():
		multi.set_instance_transform(i, lista[i])
	var instancia := MultiMeshInstance3D.new()
	instancia.name = nombre
	instancia.multimesh = multi
	instancia.visibility_range_end = visible_hasta
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instancia)
