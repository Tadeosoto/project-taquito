class_name Deterioro
extends RefCounted

# Cuanto deterioro hay en un punto del mapa (0..1), igual que zona_deterioro() de
# shaders/ps1_deterioro.gdshaderinc: lo que se ve destruido en las casas y calles.
# Lo usan las bodegas (portones abiertos, hoyos) y lo usara el spawn de zombies
# (mas zombies donde esta mas destruido). Si cambia la formula del shader, cambiar esta.


static var _maximo := -1.0
static var _escala := 150.0


static func zona(x: float, z: float) -> float:
	if _maximo < 0.0:
		_maximo = _setting("deterioro", 0.8)
		_escala = _setting("deterioro_escala", 150.0)
	var p := Vector2(x, z) / maxf(_escala, 1.0)
	var n := _ruido(p) * 0.65 + _ruido(p * 2.03 + Vector2(17.0, 17.0)) * 0.35
	return _maximo * lerpf(0.25, 1.0, smoothstep(0.3, 0.7, n))


# Que pasto hay en un punto, igual que pasto() de shaders/ps1_suelo.gdshader: lo usan las
# matas (MapPasto.gd) para que salgan como el piso. Si cambia el shader, cambiar esta.
enum Pasto { NORMAL, CRECIDO, CUIDADO, PODRIDO }


static func tipo_pasto(x: float, z: float) -> Pasto:
	var pura := zona(x, z) / maxf(_maximo, 0.01)
	var p := Vector2(x, z)
	if pura > 0.7 and _ruido(p / 17.0 + Vector2(31.0, 31.0)) > 0.45:
		return Pasto.PODRIDO
	if pura < 0.55 and _ruido(p / 41.0 + Vector2(9.0, 9.0)) > 0.6:
		return Pasto.CUIDADO
	if _ruido(p / 23.0 + Vector2(5.0, 5.0)) > 0.52:
		return Pasto.CRECIDO
	return Pasto.NORMAL


# Cambia el deterioro en el juego: los shaders y esta funcion a la vez
static func configurar(maximo: float, escala: float) -> void:
	_maximo = maximo
	_escala = escala
	RenderingServer.global_shader_parameter_set("deterioro", maximo)
	RenderingServer.global_shader_parameter_set("deterioro_escala", escala)


static func _setting(nombre: String, default: float) -> float:
	var setting = ProjectSettings.get_setting("shader_globals/" + nombre)
	return float(setting["value"]) if setting is Dictionary else default


static func _hash(ix: int, iz: int) -> float:
	var h := ((ix & 0xFFFFFFFF) * 374761393 + (iz & 0xFFFFFFFF) * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 16777215) / 16777215.0


static func _ruido(p: Vector2) -> float:
	var ix := floori(p.x)
	var iz := floori(p.y)
	var f := p - Vector2(ix, iz)
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(lerpf(_hash(ix, iz), _hash(ix + 1, iz), f.x),
		lerpf(_hash(ix, iz + 1), _hash(ix + 1, iz + 1), f.x), f.y)
