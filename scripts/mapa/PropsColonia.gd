class_name PropsColonia
extends Node3D

# Props de la libreria de modelos que el generador de una colonia pone a mano (la favela de La
# Gotera: dentro de las casas abandonadas y los callejones techados). Cada uno es
# [x, z, giro, pack, nodo, y, choca, medida] en resources/mapa/<colonia>/props_modelo.json (lo
# escribe exportar.py desde datos["props"]); `pack` y `nodo` son los de TianguisPiezas (o `pack` es
# la ruta de una escena), que da la pieza asentada en el piso. `medida` (opcional) [largo, alto]:
# se escala para caber en lo mas largo en planta y en el alto, en metros. `choca`: una caja de choque del tamano de la pieza; el
# generador la apaga donde estorbaria el paso (los callejones techados) y los pone lejos de las
# puertas de las casas.

const Piezas := preload("res://scripts/map/TianguisPiezas.gd")

@export_file("*.json") var props_path := ""
# Lo que queda mas lejos que esto del jugador no se dibuja
@export var visible_hasta := 60.0


func _ready() -> void:
	if props_path == "" or not FileAccess.file_exists(props_path):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(props_path))
	if not datos is Dictionary:
		push_warning("PropsColonia: no se pudo leer %s" % props_path)
		return
	for p: Array in datos.get("props", []):
		var pieza: Node3D = Piezas.pieza(String(p[3]), String(p[4]))
		if pieza == null:
			continue
		if p.size() > 7 and p[7] is Array and (p[7] as Array).size() == 2:
			# Que quepa en [largo en planta, alto] (los modelos sueltos vienen en otras escalas)
			var tam: Vector3 = Piezas.caja_de(pieza).size
			if tam.x > 0.0 and tam.y > 0.0 and tam.z > 0.0:
				var s := minf(float(p[7][0]) / maxf(tam.x, tam.z), float(p[7][1]) / tam.y)
				var escala := Transform3D().scaled(Vector3.ONE * s)
				for m: Node3D in pieza.get_children():
					m.transform = escala * m.transform
		pieza.position = Vector3(float(p[0]), float(p[5]), float(p[1]))
		pieza.rotation.y = float(p[2])
		add_child(pieza)
		for m: MeshInstance3D in pieza.find_children("*", "MeshInstance3D", true, false):
			m.visibility_range_end = visible_hasta
		if bool(p[6]):
			var caja: AABB = Piezas.caja_de(pieza)
			var cuerpo := StaticBody3D.new()
			var forma := CollisionShape3D.new()
			var cubo := BoxShape3D.new()
			cubo.size = caja.size
			forma.shape = cubo
			forma.position = caja.get_center()
			cuerpo.add_child(forma)
			pieza.add_child(cuerpo)
