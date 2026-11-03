extends SceneTree

# Texturas de los otros pastos del mapa (ps1_suelo, Deterioro.tipo_pasto), repetibles y del
# mismo tamano que pasto.png. En GDScript para no depender de Python:
#
#   godot --path . --headless -s tools/map_import/make_pastos.gd
#
# Las nuevas necesitan mipmaps/generate=true en su .import (ver docs/mapa/tecnico.md).

const LADO := 128
const CARPETA := "res://textures/map/"

var _semilla := 0


func _init() -> void:
	# Cuidado: parejo, claro y corto, con franjas apenas visibles de podadora
	_guardar("pasto_cuidado.png", func(x: int, y: int) -> Color:
		var grano := _ruido(x, y, 64) * 0.5 + randf() * 0.5
		var franja := 0.04 if (y / 16) % 2 == 0 else -0.02
		return Color(0.27, 0.56, 0.2).lerp(Color(0.42, 0.72, 0.28), grano) * (1.0 + franja))
	# Crecido: oscuro y disparejo, en matones, con espigas amarillas sueltas
	_guardar("pasto_crecido.png", func(x: int, y: int) -> Color:
		var maton := _ruido(x, y, 8) * 0.6 + _ruido(x, y, 16) * 0.4
		var color := Color(0.05, 0.17, 0.05).lerp(Color(0.2, 0.42, 0.13), clampf(maton * 1.6 - 0.3 + randf() * 0.3, 0.0, 1.0))
		if randf() < 0.03:
			color = Color(0.62, 0.58, 0.25)
		return color)
	# Podrido: cafe y negruzco, con manchas de moho gris y hebras secas
	_guardar("pasto_podrido.png", func(x: int, y: int) -> Color:
		var mancha := _ruido(x, y, 8) * 0.55 + _ruido(x, y, 32) * 0.45
		var color := Color(0.1, 0.08, 0.04).lerp(Color(0.34, 0.27, 0.13), clampf(mancha * 1.5 - 0.2 + randf() * 0.25, 0.0, 1.0))
		if _ruido(x + 40, y + 40, 8) > 0.72:
			color = color.lerp(Color(0.38, 0.4, 0.34), 0.55)
		if randf() < 0.04:
			color = Color(0.48, 0.4, 0.2)
		return color)
	quit()


func _guardar(nombre: String, pixel: Callable) -> void:
	seed(nombre.hash())
	_semilla = absi(nombre.hash()) % 1000
	var imagen := Image.create(LADO, LADO, false, Image.FORMAT_RGB8)
	for y in LADO:
		for x in LADO:
			imagen.set_pixel(x, y, pixel.call(x, y))
	imagen.save_png(CARPETA + nombre)
	print("PASTO ", nombre)


# Ruido que se repite: `celdas` cuadros en cada lado de la textura
func _ruido(x: int, y: int, celdas: int) -> float:
	var u := float(x) / LADO * celdas
	var v := float(y) / LADO * celdas
	var ix := floori(u)
	var iy := floori(v)
	var fx := u - ix
	var fy := v - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_valor(ix, iy, celdas), _valor(ix + 1, iy, celdas), fx),
		lerpf(_valor(ix, iy + 1, celdas), _valor(ix + 1, iy + 1, celdas), fx), fy)


func _valor(ix: int, iy: int, celdas: int) -> float:
	return float(hash(Vector3i(posmod(ix, celdas), posmod(iy, celdas), celdas + _semilla)) & 65535) / 65535.0
