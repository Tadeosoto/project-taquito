class_name ArbolJardinera
extends RefCounted

# Un arbol de models/arboles (arce, realista o roble, los mismos del mapa en Blender: ArbolesModelo)
# como una sola malla, para ponerlo dentro de una jardinera de la plaza. Cuelga del nodo de la
# jardinera, asi se esconde junto con el cajon cuando la Catrina lo revienta (Rompible).

const ESTIRAR := {"roble": 1.4, "realista": 1.45}    # a lo alto, sin ensanchar la copa
static var _modelos: Dictionary = {}
static var _mallas: Dictionary = {}


static func crear(nombre: String, altura: float, ancho: float, semilla: float = 0.0) -> MeshInstance3D:
	if _modelos.is_empty():
		var datos = JSON.parse_string(FileAccess.get_file_as_string(ArbolesModelo.new().modelos_path))
		if datos is Dictionary:
			_modelos = datos
	if not _modelos.has(nombre):
		push_warning("ArbolJardinera: no hay modelo '%s'" % nombre)
		return null
	if not _mallas.has(nombre):
		var fabrica := ArbolesModelo.new()
		_mallas[nombre] = fabrica._malla(nombre, _modelos[nombre])
		fabrica.free()
	var modelo: Dictionary = _modelos[nombre]
	var escala := minf(altura, ancho / float(modelo["ancho"]))
	var instancia := MeshInstance3D.new()
	instancia.name = "Arbol_" + nombre
	instancia.mesh = _mallas[nombre]
	instancia.basis = Basis(Vector3.UP, semilla).scaled(Vector3(escala, escala * ESTIRAR.get(nombre, 1.0), escala))
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instancia
