@tool
extends Node3D

# Raiz de scenes/casa_personaje.tscn (la arma tools/construir_casa_personaje.gd). Godot no
# guarda cambios de material sobre las mallas de un .glb instanciado, asi que los dos colores
# que no vienen en los modelos se ponen aqui al cargar.


func _ready() -> void:
	_igualar_madera($Mesa/Modelo, $Silla1/Modelo)


func _mallas(nodo: Node) -> Array[MeshInstance3D]:
	var salida: Array[MeshInstance3D] = []
	for n in nodo.find_children("*", "MeshInstance3D", true, false):
		salida.append(n)
	return salida


# Promedio de color de la primera textura de albedo del modelo, sin contar los pixeles casi negros.
func _promedio(nodo: Node) -> Color:
	for mi in _mallas(nodo):
		for i in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(i)
			if m is BaseMaterial3D and m.albedo_texture:
				var img: Image = m.albedo_texture.get_image()
				if img.is_compressed():
					img.decompress()
				img.resize(16, 16)
				var suma := Vector3.ZERO
				var n := 0
				for y in 16:
					for x in 16:
						var c := img.get_pixel(x, y)
						if c.get_luminance() < 0.08:
							continue   # huecos negros del atlas: no son madera
						suma += Vector3(c.r, c.g, c.b)
						n += 1
				suma /= maxf(n, 1.0)
				return Color(suma.x, suma.y, suma.z)
	return Color.WHITE


# La mesa viene mas clara que la silla: se le multiplica el albedo por
# (promedio de la silla / promedio de la mesa) para que las dos sean de la misma madera.
func _igualar_madera(mesa: Node, silla: Node) -> void:
	var c_silla := _promedio(silla)
	var c_mesa := _promedio(mesa)
	var factor := Color(
		clampf(c_silla.r / maxf(c_mesa.r, 0.01), 0.0, 1.5),
		clampf(c_silla.g / maxf(c_mesa.g, 0.01), 0.0, 1.5),
		clampf(c_silla.b / maxf(c_mesa.b, 0.01), 0.0, 1.5))
	for mi in _mallas(mesa):
		for i in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(i)
			if m is BaseMaterial3D:
				var copia: BaseMaterial3D = m.duplicate()
				copia.albedo_color = factor
				mi.set_surface_override_material(i, copia)

