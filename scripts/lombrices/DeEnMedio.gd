class_name DeEnMedio
extends Node3D

# Los de en medio en las cañerías (JJ, 2026-11-21; lore §8 "Los de en medio"): ni persona ni zombi,
# no atacan, solo estan. Cada visita salen CUANTOS al azar: modelo de Transicion.MODELOS, un pasillo,
# un lugar a lo largo del tunel y una de sus tres cosas:
#   PARADO: en pose de zombi (Zombie_Idle), viendo a un lado; de vez en cuando se voltea.
#   CAMINA: despacio en pose de zombi (Zombie_Walk_Fwd) por su pasillo, y se regresa en las puntas
#           o cuando se le ocurre.
#   FETAL:  sentado contra el muro en posicion fetal, viendo al canal.
# Sin colision: no estorban el campo de las crias (se hornea con la capa 1) y las atraviesas.
# Lo crea Tuneles.gd despues del nivel.

enum Hace { PARADO, CAMINA, FETAL }

const CUANTOS := 6
const DESDE := 5.0              # m de la reja: no te reciben en la entrada
const HASTA := 3.0              # m antes del fondo
const SEPARA := 4.0             # m minimos entre uno y otro en el mismo pasillo
const VELOCIDAD := 0.35         # m/s, arrastrando los pies
const PASO := 0.75              # velocidad del clip de caminar a VELOCIDAD (se ve sin patinar)
const VOLTEA := Vector2(6.0, 14.0)      # s entre volteadas del que esta parado
const REGRESA := Vector2(10.0, 25.0)    # s entre regresos del que camina (si no llega antes a la punta)
const LUZ := 0.8                # la luz calida que trae cada uno enfrente (los focos los dejaban en silueta)

var largo := TunelesNivel.LARGO
# Cada uno: {nodo, hace, lado, dir, espera}
var _ellos: Array[Dictionary] = []


func _ready() -> void:
	var usados := {-1: [], 1: []}
	for i in CUANTOS:
		var lado: int = [-1, 1].pick_random()
		var z := _lugar(usados[lado])
		if is_nan(z):
			lado = -lado
			z = _lugar(usados[lado])
			if is_nan(z):
				continue
		usados[lado].append(z)
		var hace: Hace = [Hace.PARADO, Hace.CAMINA, Hace.FETAL].pick_random()
		var clip: String = ["Zombie_Idle", "Zombie_Walk_Fwd", "Fetal"][hace]
		var datos: Array = Transicion.MODELOS.pick_random()
		var nodo := Transicion.humano(datos[0], randf() * 100.0, datos[1], datos[2], clip)
		add_child(nodo)
		var x: float = lado * TunelesNivel.LADO_PASILLO
		var dir := 1.0 if randf() < 0.5 else -1.0
		match hace:
			Hace.FETAL:
				# Contra el muro, viendo al canal (el civil ve a su -Z)
				x = lado * (TunelesNivel.ANCHO / 2.0 - 0.45)
				nodo.rotation.y = PI / 2.0 * lado
			Hace.PARADO:
				nodo.rotation.y = randf() * TAU
			Hace.CAMINA:
				nodo.rotation.y = 0.0 if dir > 0.0 else PI   # adentro es -Z, a donde ve el civil
				var ap := nodo.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if ap:
					ap.speed_scale = PASO
		nodo.position = Vector3(x + randf_range(-0.15, 0.15), 0.0, -z)
		# Una luz calida tenue enfrente de la cara (JJ: que se les vea lo humano); sin sombra
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.85, 0.7)
		luz.light_energy = LUZ
		luz.omni_range = 2.2
		luz.position = Vector3(0.0, 0.9 if hace == Hace.FETAL else 1.9, -0.7)
		nodo.add_child(luz)
		_ellos.append({"nodo": nodo, "hace": hace, "lado": lado, "dir": dir,
			"espera": randf_range(VOLTEA.x, VOLTEA.y) if hace == Hace.PARADO else randf_range(REGRESA.x, REGRESA.y)})


# Una z al azar (m desde la reja, hacia adentro) lejos de las ya usadas en ese pasillo; NAN si no cabe
func _lugar(usadas: Array) -> float:
	for intento in 20:
		var z := randf_range(DESDE, largo - HASTA)
		var libre := true
		for otra: float in usadas:
			if absf(otra - z) < SEPARA:
				libre = false
				break
		if libre:
			return z
	return NAN


func _process(delta: float) -> void:
	for e: Dictionary in _ellos:
		var nodo := e["nodo"] as Node3D
		match e["hace"]:
			Hace.PARADO:
				e["espera"] -= delta
				if e["espera"] <= 0.0:
					e["espera"] = randf_range(VOLTEA.x, VOLTEA.y)
					var t := nodo.create_tween()
					t.tween_property(nodo, "rotation:y", nodo.rotation.y + randf_range(-2.0, 2.0), 1.6)
			Hace.CAMINA:
				var z := -nodo.position.z
				e["espera"] -= delta
				var punta: bool = (e["dir"] > 0.0 and z > largo - HASTA) or (e["dir"] < 0.0 and z < DESDE)
				if punta or e["espera"] <= 0.0:
					e["dir"] = -e["dir"]
					e["espera"] = randf_range(REGRESA.x, REGRESA.y)
					var t := nodo.create_tween()
					t.tween_property(nodo, "rotation:y", 0.0 if e["dir"] > 0.0 else PI, 1.2)
				# dir > 0: hacia adentro (-Z del tunel)
				nodo.position.z -= e["dir"] * VELOCIDAD * delta
