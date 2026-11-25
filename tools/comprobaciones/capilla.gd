extends Comprobacion

# La capilla del templo (F3, Templo.gd): el padre Chuy recibe tus envases hasta el cupo, al amanecer
# te los da como agua (Cartera.agua), el filtro robado sube el cupo y todo se guarda

const TEMPLO := "res://scenes/casas/templo.tscn"
const BOTELLA := "res://resources/productos/botella_vacia.tres"


func correr(r: Node) -> void:
	var mis = r.autoload("Misiones")
	var inv = r.autoload("Inventory")
	var cartera = r.autoload("Cartera")
	r.ok(await r.ir_a(SAFEHOUSE), "safehouse")
	var templo: Node3D = load(TEMPLO).instantiate()
	r.get_tree().current_scene.add_child(templo)
	templo.global_position = Vector3(0.0, 300.0, 0.0)
	await r.frames(5)
	var padre := templo.get_node_or_null("PadreChuy")
	r.ok(padre != null, "el padre Chuy esta en el templo")
	if padre == null:
		return
	var hablar: Callable = padre.get("al_hablar")
	inv.vaciar()
	var linea: String = hablar.call()
	r.ok(mis.capilla_dejadas == 0 and not linea.contains("Mañana temprano te"), "sin envases no recibe nada")
	for i in 3:
		inv.add_item(load(BOTELLA))
	var agua: int = cartera.agua
	hablar.call()
	r.ok(mis.capilla_dejadas == Misiones.CAPILLA_CUPO, "recibe hasta el cupo (%d)" % mis.capilla_dejadas)
	var quedan: int = inv.unidades().filter(func(i) -> bool: return i.resource_path == BOTELLA).size()
	r.ok(quedan == 3 - Misiones.CAPILLA_CUPO, "te deja lo que no cupo (%d)" % quedan)
	r.ok(hablar.call().contains("no alcanza"), "con el cupo lleno ya no recibe")
	r.ok(cartera.agua == agua, "el mismo dia no da agua")
	mis.amanecer()
	r.ok(mis.capilla_listas == Misiones.CAPILLA_CUPO and mis.capilla_dejadas == 0, "al amanecer ya estan limpias")
	r.ok(hablar.call().contains("+%d" % Misiones.CAPILLA_CUPO) and cartera.agua == agua + Misiones.CAPILLA_CUPO, "te da +%d de agua" % Misiones.CAPILLA_CUPO)
	# La mision del filtro: despues de la guardia de la reja, y sube el cupo
	var filtro: MisionData = null
	for m: MisionData in mis.todas:
		if m.id == "filtro_capilla":
			filtro = m
	r.ok(filtro != null, "la mision del filtro esta en Misiones.ARCHIVOS")
	if filtro:
		r.ok(not mis.requisito_cumplido(filtro), "antes de la guardia no se ofrece")
		mis.set("_hechas_siempre", {"guardia_reja": true})
		r.ok(mis.requisito_cumplido(filtro), "despues de la guardia si")
		mis.call("_cobrar", filtro)
		r.ok(mis.capilla_cupo == Misiones.CAPILLA_CUPO + Misiones.CAPILLA_FILTRO, "el filtro sube el cupo")
	var mundo := r.get_tree().current_scene.find_child("MisionesMundo", true, false)
	if mundo:
		var donde: Vector3 = mundo.call("_tienda", "giro:purificadora", true)
		r.ok(donde != Vector3.ZERO, "hay Puri-GelA de afuera para el filtro")
	# Se guarda
	mis.capilla_dejadas = 1
	var guardado = r.autoload("Guardado")
	guardado.guardar(true)
	mis.capilla_dejadas = 0
	mis.capilla_cupo = 0
	guardado.cargar()
	r.ok(mis.capilla_dejadas == 1 and mis.capilla_cupo == Misiones.CAPILLA_CUPO + Misiones.CAPILLA_FILTRO, "la capilla se guarda")
	guardado.nueva()
	templo.queue_free()
