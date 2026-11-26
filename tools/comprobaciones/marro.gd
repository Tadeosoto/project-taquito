extends Comprobacion

# El combo pesado (Player.PESADO, JJ 2026-11-25): con el marro (InventoryItemData.pesada) los
# golpes son Sword_Heavy_A, B y C, mas lentos que el machete (a la velocidad del arma), le pegan a
# varios sin matar de un golpe, los dos primeros lo recorren poquito y el remate lo avienta; con el
# machete todo sigue como antes

const MARRO := "res://resources/taller/marro.tres"
const MACHETE := "res://resources/productos/machete.tres"


func correr(r: Node) -> void:
	await r.ir_a("res://scenes/safehouse.tscn")
	var jugador: Player = r.nodo("jugador")
	var inventario = r.autoload("Inventory")
	var zombis: Zombis = r.get_tree().current_scene.get_node("Zombis")
	inventario.vaciar()
	inventario.add_item(load(MARRO))
	jugador._invulnerable = 999.0
	var frente := -jugador.frijol.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var zombi := zombis.sacar(jugador.global_position + frente * 1.6, false)
	zombi._vida = 999
	await r.frames(10)
	var antes := (zombi.global_position - jugador.global_position).length()
	jugador._atacar()
	await r.frames(2)
	r.ok(jugador.figura.clip_golpe() == "Sword_Heavy_A", "el marro empieza con Sword_Heavy_A (%s)" % jugador.figura.clip_golpe())
	await r.segundos(0.3)
	r.ok(zombi._vida == 999, "a los 0.3 s el marro todavia no pega (el machete ya pego a los 0.24)")
	await r.segundos(0.5)
	r.ok(zombi._vida < 999, "el marro pega despues (vida %d)" % zombi._vida)
	r.ok(zombi.estado == Zombie.Estado.HERIDO, "el golpe pesado aturde al zombi")
	await r.segundos(0.4)
	var despues := (zombi.global_position - jugador.global_position).length()
	r.ok(despues > antes + 0.15 and despues < antes + 0.8,
		"el primer golpe lo recorre poquito y sigue en alcance (%.1f m -> %.1f m)" % [antes, despues])
	jugador._atacar()
	await r.frames(2)
	r.ok(jugador.figura.clip_golpe() == "Sword_Heavy_B", "el segundo golpe del combo es Sword_Heavy_B (%s)" % jugador.figura.clip_golpe())
	var vida_b := zombi._vida
	# Hasta que abre el siguiente (PESADO.desde a la velocidad del arma)
	await r.segundos(Player.PESADO[1]["desde"] / load(MARRO).velocidad + 0.05)
	r.ok(zombi._vida < vida_b, "el segundo golpe tambien le pega (vida %d)" % zombi._vida)
	var antes_c := (zombi.global_position - jugador.global_position).length()
	jugador._atacar()
	await r.frames(2)
	r.ok(jugador.figura.clip_golpe() == "Sword_Heavy_C", "el tercero es Sword_Heavy_C (%s)" % jugador.figura.clip_golpe())
	await r.segundos(1.4)
	var despues_c := (zombi.global_position - jugador.global_position).length()
	r.ok(despues_c > antes_c + 2.0, "el remate lo avienta (%.1f m -> %.1f m)" % [antes_c, despues_c])
	zombi.queue_free()
	await r.segundos(1.0)
	# En area y sin matar de un golpe (JJ): tres zombis normales enfrente y uno atras
	var bola: Array[Zombie] = []
	for grados: float in [-40.0, 0.0, 40.0]:
		bola.append(zombis.sacar(jugador.global_position + frente.rotated(Vector3.UP, deg_to_rad(grados)) * 1.5, true))
	var atras := zombis.sacar(jugador.global_position - frente * 1.5, true)
	await r.frames(10)
	jugador._atacar()
	await r.segundos(0.9)
	var vidas := bola.map(func(z: Zombie) -> int: return z._vida)
	r.ok(vidas.all(func(v: int) -> bool: return v > 0 and v < Zombie.VIDA),
		"un golpe le pega a los tres de enfrente y no mata a ninguno (vidas %s de %d)" % [vidas, Zombie.VIDA])
	r.ok(atras._vida == Zombie.VIDA, "al de atras no le pega (%d)" % atras._vida)
	for z: Zombie in bola + [atras]:
		z.queue_free()
	# A un jefe (el garrafonero es un Zombie con es_jefe) no lo avienta
	var jefe := zombis.aparecer_jefe(jugador.global_position + frente * 2.0)
	if jefe:
		# aparecer_jefe busca un lugar libre lejos: se pone enfrente
		jefe.global_position = jugador.global_position + frente * 2.2
		jefe._vida = 9999
		await r.frames(10)
		var al_jefe := (jefe.global_position - jugador.global_position).length()
		jugador._atacar()
		await r.segundos(1.0)
		var al_jefe_despues := (jefe.global_position - jugador.global_position).length()
		r.ok(jefe._vida < 9999 and al_jefe_despues < al_jefe + 0.4,
			"al jefe le pega pero no lo avienta (%.1f m -> %.1f m)" % [al_jefe, al_jefe_despues])
		jefe.queue_free()
	else:
		r.ok(false, "no se pudo sacar al garrafonero para probar el jefe")
	await r.segundos(1.0)
	inventario.vaciar()
	inventario.add_item(load(MACHETE))
	await r.segundos(1.0)
	jugador._atacar()
	await r.frames(2)
	r.ok(jugador.figura.clip_golpe() == "Sword_Regular_A" and jugador._golpe_dura == Player.ATAQUE_ENFRIAR,
		"con el machete el combo sigue igual (%s)" % jugador.figura.clip_golpe())
