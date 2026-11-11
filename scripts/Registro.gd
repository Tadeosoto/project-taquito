extends Node

# Autoload `Registro`: la medicion de los tests. Una sola fuente para el godmode y la
# carrera. Guarda por oleada:
#   - ataques del jugador: usos, golpes, dano, muertes
#   - mecanicas: rodar, bloquear, esquiva, carga
#   - items: usos, vida curada, usos de supervivencia (vida <= 25 %)
#   - enemigos: tipo/rol, vida, dano, velocidad, ataque, cadencia, TTK, dano al jugador/tinaco
# y clasifica la oleada en calma/medio/estres con vivos e intensidad del Director.
# Escribe CSV y resumenes en la carpeta de la noche; las compras van a la carpeta de la sesion.

const VIDA_APURO := 0.25
const CALMA_VIVOS := 3
const CALMA_INT := 0.4
const ESTRES_VIVOS := 6
const ESTRES_INT := 0.7
const CADA_CONTEXTO := 0.5

var activo := false
var carpeta := ""          # sesion: compras/mejoras
var carpeta_noche := ""    # noche_N/
var modo := ""
var noche := 1
var dificultad := ""
var duracion := 0.0
var pesos_inicio := 0
var pesos_final := 0

var _ola_activa := false
var _ola_num := 0
var _ola := {}
var _olas: Array = []
var _ataques := {}
var _mecanicas := {}
var _items := {}
var _enemigos := {}
var _zombis := {}
var _compras: Array = []
var _mejoras: Array = []
var _contexto_t := 0.0
var _config := {}
var _guardado := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not activo or not _ola_activa:
		return
	_contexto_t -= delta
	if _contexto_t > 0.0:
		return
	_contexto_t = CADA_CONTEXTO
	_actualizar_contexto()


# --- Sesion y noche ---

func sesion(nueva_carpeta: String, nuevo_modo: String) -> void:
	carpeta = nueva_carpeta
	modo = nuevo_modo
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	_compras.clear()
	_mejoras.clear()
	activo = true


func noche_inicio(nueva_noche: int, nuevo_modo: String, nueva_dificultad: String, nueva_duracion: float, dinero := 0) -> void:
	noche = nueva_noche
	modo = nuevo_modo
	dificultad = nueva_dificultad
	duracion = nueva_duracion
	pesos_inicio = dinero
	pesos_final = dinero
	carpeta_noche = carpeta + ("noche_%d/" % noche)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta_noche))
	_ataques.clear()
	_mecanicas.clear()
	_items.clear()
	_enemigos.clear()
	_zombis.clear()
	_olas.clear()
	_ola_activa = false
	_ola_num = 0
	_ola = {}
	_config.clear()
	_guardado = false
	activo = true


func config_enemigos(config) -> void:
	if config == null:
		return
	_config["enemigos"] = {
		"vida": config.vida, "dano": config.dano, "velocidad": [config.velocidad.x, config.velocidad.y],
		"ataque_dura": config.ataque_dura, "ataque_alcance": config.ataque_alcance,
		"cazador_velocidad": config.cazador_velocidad, "corre_desde": config.corre_desde,
		"gordo_vida": config.gordo_vida, "gordo_dano": config.gordo_dano, "gordo_velocidad": [config.gordo_velocidad.x, config.gordo_velocidad.y],
		"jefe_vida": config.jefe_vida, "jefe_dano": config.jefe_dano, "jefe_velocidad": config.jefe_velocidad,
	}
	_config["enemigos_texto"] = config.texto()


func config_extra(clave: String, valor: Variant) -> void:
	_config[clave] = valor


# --- Oleadas ---

func ola_empezada(n: int, cuantos: int, corredores: float, hora: float, tipo := "oleada", extra := {}) -> void:
	if not activo:
		return
	_cerrar_ola()
	_ola_num = n
	_ola = {
		"noche": noche, "modo": modo, "dificultad": dificultad, "ola": n, "tipo": tipo,
		"hora": hora, "cuantos": cuantos, "corredores": corredores,
		"inicio": _ahora(), "vivos_max": 0, "intensidad_max": 0.0, "intensidad_suma": 0.0,
		"contexto_n": 0, "vida_min": _vida(), "tinaco_inicio": _tinaco(),
		"dano_recibido_inicio": _vida(), "ataques": {}, "mecanicas": {}, "items": {},
		"enemigos": {}, "extra": extra,
	}
	_ola_activa = true
	_actualizar_contexto()


func emboscada(n: int, cuantos: int, hora: float) -> void:
	ola_empezada(n, cuantos, 1.0, hora, "emboscada")


func _cerrar_ola() -> void:
	if not _ola_activa:
		return
	_ola["fin"] = _ahora()
	_ola["duracion"] = _ola["fin"] - _ola["inicio"]
	_ola["tinaco_perdido"] = maxi(_ola["tinaco_inicio"] - _tinaco(), 0)
	_ola["vida_min"] = mini(_ola["vida_min"], _vida())
	_ola["presion"] = (float(_ola["intensidad_suma"]) / maxi(_ola["contexto_n"], 1))
	_ola["bucket"] = _clase(_ola["vivos_max"], _ola["intensidad_max"])
	_olas.append(_ola)
	_ola_activa = false


func _clase(vivos: int, intensidad: float) -> String:
	if vivos <= CALMA_VIVOS and intensidad < CALMA_INT:
		return "calma"
	if vivos >= ESTRES_VIVOS or intensidad >= ESTRES_INT:
		return "estres"
	return "medio"


func _actualizar_contexto() -> void:
	if not _ola_activa:
		return
	var vivos := _vivos()
	var intensidad := _intensidad()
	_ola["vivos_max"] = maxi(_ola["vivos_max"], vivos)
	_ola["intensidad_max"] = maxf(_ola["intensidad_max"], intensidad)
	_ola["intensidad_suma"] = float(_ola["intensidad_suma"]) + intensidad
	_ola["contexto_n"] = int(_ola["contexto_n"]) + 1
	_ola["vida_min"] = mini(_ola["vida_min"], _vida())


# --- Ataques y mecanicas ---

func uso_ataque(fuente: String) -> void:
	if not activo or fuente == "":
		return
	_sumar(_ataques, fuente, "usos", 1)
	if _ola_activa:
		_sumar(_ola["ataques"], fuente, "usos", 1)


func mecanica(nombre: String, valor := 0) -> void:
	if not activo:
		return
	_sumar(_mecanicas, nombre, "usos", 1)
	if valor > 0:
		_sumar(_mecanicas, nombre, "valor", valor)
	if _ola_activa:
		_sumar(_ola["mecanicas"], nombre, "usos", 1)
		if valor > 0:
			_sumar(_ola["mecanicas"], nombre, "valor", valor)


func item(nombre: String, curado: int, vida_antes: int, vida_max: int) -> void:
	if not activo:
		return
	var apuro := vida_antes <= roundi(vida_max * VIDA_APURO)
	_sumar(_items, nombre, "usos", 1)
	_sumar(_items, nombre, "curado", curado)
	if apuro:
		_sumar(_items, nombre, "apuro", 1)
	if _ola_activa:
		_sumar(_ola["items"], nombre, "usos", 1)
		_sumar(_ola["items"], nombre, "curado", curado)
		if apuro:
			_sumar(_ola["items"], nombre, "apuro", 1)


# --- Enemigos ---

func zombi_nace(z: Zombie) -> void:
	if not activo or z == null:
		return
	var tipo := _tipo(z)
	var info := _enemigo(tipo)
	if _zombis.has(z.get_instance_id()):
		return
	info["spawns"] = int(info.get("spawns", 0)) + 1
	info["vida_max"] = z._vida_max()
	info["dano"] = z._dano
	info["velocidad"] = z._velocidad
	info["ataque_dura"] = z._ataque_dura()
	info["alcance"] = z._alcance
	info["rol"] = _rol(z)
	if _ola_activa:
		var e := _enemigo_ola(tipo)
		e["spawns"] = int(e.get("spawns", 0)) + 1
	_zombis[z.get_instance_id()] = {
		"tipo": tipo, "rol": _rol(z), "nacimiento": _ahora(),
		"golpes": 0, "dano": 0, "ultimo_ataque": 0, "dano_por": {}, "vivo": true,
	}


func zombi_golpe(z: Zombie, fuente: String, dano: int, mato: bool) -> void:
	if not activo or z == null:
		return
	var id := z.get_instance_id()
	var info: Dictionary = _zombis.get(id, {})
	var tipo: String = info.get("tipo", _tipo(z))
	if not info.is_empty():
		info["golpes"] = int(info["golpes"]) + 1
		info["dano"] = int(info["dano"]) + dano
		_sumar(info["dano_por"], fuente, "dano", dano)
		_sumar(info["dano_por"], fuente, "golpes", 1)
	_zombi_tipo(tipo)["dano_recibido"] = int(_zombi_tipo(tipo).get("dano_recibido", 0)) + dano
	_sumar(_zombi_tipo(tipo).get("dano_por", {}), fuente, "dano", dano)
	_sumar(_ataques, fuente, "golpes", 1)
	_sumar(_ataques, fuente, "dano", dano)
	if mato:
		_sumar(_ataques, fuente, "muertes", 1)
	if _ola_activa:
		_sumar(_ola["ataques"], fuente, "golpes", 1)
		_sumar(_ola["ataques"], fuente, "dano", dano)
		if mato:
			_sumar(_ola["ataques"], fuente, "muertes", 1)
		var e := _enemigo_ola(tipo)
		e["dano_recibido"] = int(e.get("dano_recibido", 0)) + dano


func zombi_despawn(z: Zombie) -> void:
	if z == null:
		return
	_zombis.erase(z.get_instance_id())


func zombi_muere(z: Zombie) -> void:
	if not activo or z == null:
		return
	var id := z.get_instance_id()
	var info: Dictionary = _zombis.get(id, {})
	if info.is_empty():
		return
	var tipo: String = info.get("tipo", _tipo(z))
	var ttk := _ahora() - float(info["nacimiento"])
	var info_tipo := _zombi_tipo(tipo)
	info_tipo["muertes"] = int(info_tipo.get("muertes", 0)) + 1
	info_tipo["ttk_suma"] = float(info_tipo.get("ttk_suma", 0.0)) + ttk
	info_tipo["ttk_n"] = int(info_tipo.get("ttk_n", 0)) + 1
	info_tipo["golpes_suma"] = int(info_tipo.get("golpes_suma", 0)) + int(info["golpes"])
	info_tipo["golpes_n"] = int(info_tipo.get("golpes_n", 0)) + 1
	_zombis.erase(id)
	if _ola_activa:
		var e := _enemigo_ola(tipo)
		e["muertes"] = int(e.get("muertes", 0)) + 1
		e["ttk_suma"] = float(e.get("ttk_suma", 0.0)) + ttk
		e["ttk_n"] = int(e.get("ttk_n", 0)) + 1
		e["golpes_suma"] = int(e.get("golpes_suma", 0)) + int(info["golpes"])
		e["golpes_n"] = int(e.get("golpes_n", 0)) + 1


func zombi_ataque(z: Zombie, objetivo: String, dano: int, acerto: bool) -> void:
	if not activo or z == null:
		return
	var id := z.get_instance_id()
	var info: Dictionary = _zombis.get(id, {})
	var tipo: String = info.get("tipo", _tipo(z))
	var info_tipo := _zombi_tipo(tipo)
	info_tipo["ataques"] = int(info_tipo.get("ataques", 0)) + 1
	if acerto:
		info_tipo["pegaron"] = int(info_tipo.get("pegaron", 0)) + 1
		if objetivo == "tinaco":
			info_tipo["dano_tinaco"] = int(info_tipo.get("dano_tinaco", 0)) + dano
		else:
			info_tipo["dano_jugador"] = int(info_tipo.get("dano_jugador", 0)) + dano
	if not info.is_empty():
		var ahora := _ahora()
		if int(info["ultimo_ataque"]) > 0:
			var delta := ahora - float(info["ultimo_ataque"])
			info_tipo["cadencia_suma"] = float(info_tipo.get("cadencia_suma", 0.0)) + delta
			info_tipo["cadencia_n"] = int(info_tipo.get("cadencia_n", 0)) + 1
		info["ultimo_ataque"] = ahora
	if _ola_activa:
		var e := _enemigo_ola(tipo)
		e["ataques"] = int(e.get("ataques", 0)) + 1
		if acerto:
			e["pegaron"] = int(e.get("pegaron", 0)) + 1
			if objetivo == "tinaco":
				e["dano_tinaco"] = int(e.get("dano_tinaco", 0)) + dano
			else:
				e["dano_jugador"] = int(e.get("dano_jugador", 0)) + dano


# --- Compras ---

func compra(tienda: String, producto: String, precio: int) -> void:
	if not activo:
		return
	var linea := {"noche": noche, "modo": modo, "tienda": tienda, "producto": producto, "precio": precio, "tipo": "tienda"}
	_compras.append(linea)
	_escribir_compra(linea)


func mejora(id: String, costo: int, nivel: int) -> void:
	if not activo:
		return
	var linea := {"noche": noche, "modo": modo, "tienda": "punto", "producto": id, "precio": costo, "nivel": nivel, "tipo": "mejora"}
	_compras.append(linea)
	_escribir_compra(linea)


# --- Fin de noche y archivos ---

func noche_fin(gano: bool, dinero_final: int) -> void:
	if not activo:
		return
	_cerrar_ola()
	pesos_final = dinero_final
	_escribir_config()
	_escribir_olas()
	_escribir_enemigos()
	_escribir_ataques()
	_escribir_items()
	_escribir_resumen(gano)
	activo = false


func _escribir_compra(linea: Dictionary) -> void:
	if carpeta == "":
		return
	var ruta := carpeta.path_join("compras.csv")
	var nuevo := not FileAccess.file_exists(ruta)
	var archivo := FileAccess.open(ruta, FileAccess.WRITE if nuevo else FileAccess.READ_WRITE)
	if archivo == null:
		return
	if nuevo:
		archivo.store_line("noche,modo,tipo,tienda,producto,precio,nivel")
	if nuevo:
		archivo.store_line(_csv_linea(linea))
	else:
		archivo.seek_end()
		archivo.store_line(_csv_linea(linea))
	archivo.close()


func _escribir_config() -> void:
	if carpeta_noche == "":
		return
	var archivo := FileAccess.open(carpeta_noche.path_join("config.txt"), FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_line("Noche %d · modo %s · dificultad %s · duración %.0f s" % [noche, modo, dificultad, duracion])
	archivo.store_line("Dinero al empezar: %d" % pesos_inicio)
	if _config.has("enemigos_texto"):
		archivo.store_line("Enemigos: " + _config["enemigos_texto"])
	for clave in _config:
		if clave == "enemigos_texto":
			continue
		archivo.store_line("%s: %s" % [clave, str(_config[clave])])
	archivo.close()


func _escribir_olas() -> void:
	if carpeta_noche == "":
		return
	var archivo := FileAccess.open(carpeta_noche.path_join("olas_noche_%d.csv" % noche), FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_line("ola,tipo,hora,cuantos,corredores,duracion,vivos_max,intensidad_max,presion,bucket,vida_min,tinaco_perdido,detalle")
	for ola: Dictionary in _olas:
		var detalle := {
			"ataques": ola.get("ataques", {}), "mecanicas": ola.get("mecanicas", {}),
			"items": ola.get("items", {}), "enemigos": ola.get("enemigos", {}),
		}
		archivo.store_line(",".join([
			str(ola.get("ola", 0)), str(ola.get("tipo", "")), "%.2f" % float(ola.get("hora", 0.0)),
			str(ola.get("cuantos", 0)), "%.2f" % float(ola.get("corredores", 0.0)),
			"%.1f" % float(ola.get("duracion", 0.0)), str(ola.get("vivos_max", 0)),
			"%.2f" % float(ola.get("intensidad_max", 0.0)), "%.2f" % float(ola.get("presion", 0.0)),
			str(ola.get("bucket", "")), str(ola.get("vida_min", 0)), str(ola.get("tinaco_perdido", 0)),
			JSON.stringify(detalle).replace(",", ";"),
		]))
		_escribir_resumen_ola(ola)
	archivo.close()


func _escribir_resumen_ola(ola: Dictionary) -> void:
	var archivo := FileAccess.open(carpeta_noche.path_join("resumen_ola_%d.txt" % int(ola.get("ola", 0))), FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_line("Oleada %d (%s) · %s" % [int(ola.get("ola", 0)), str(ola.get("tipo", "")), str(ola.get("bucket", ""))])
	archivo.store_line("Hora %.2f · %d zombis · corredores %.2f · duración %.1f s" % [
		float(ola.get("hora", 0.0)), int(ola.get("cuantos", 0)), float(ola.get("corredores", 0.0)), float(ola.get("duracion", 0.0))])
	archivo.store_line("Vivos máx %d · intensidad máx %.2f · vida mín %d · tinaco perdido %d" % [
		int(ola.get("vivos_max", 0)), float(ola.get("intensidad_max", 0.0)), int(ola.get("vida_min", 0)), int(ola.get("tinaco_perdido", 0))])
	archivo.store_line("Ataques: " + str(ola.get("ataques", {})))
	archivo.store_line("Mecánicas: " + str(ola.get("mecanicas", {})))
	archivo.store_line("Ítems: " + str(ola.get("items", {})))
	archivo.store_line("Enemigos: " + str(ola.get("enemigos", {})))
	archivo.close()


func _escribir_enemigos() -> void:
	if carpeta_noche == "":
		return
	var archivo := FileAccess.open(carpeta_noche.path_join("zombis_noche_%d.csv" % noche), FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_line("tipo,rol,vida_max,dano,velocidad,ataque_dura,alcance,spawns,muertes,ttk_prom,golpes_para_matar,dano_jugador,dano_tinaco,ataques,pegaron,cadencia_prom,dano_recibido,dano_por")
	for tipo in _enemigos:
		var e: Dictionary = _enemigos[tipo]
		var ttk := float(e.get("ttk_suma", 0.0)) / maxi(int(e.get("ttk_n", 0)), 1)
		var golpes := float(e.get("golpes_suma", 0)) / maxi(int(e.get("golpes_n", 0)), 1)
		var cad := float(e.get("cadencia_suma", 0.0)) / maxi(int(e.get("cadencia_n", 0)), 1)
		archivo.store_line(",".join([
			tipo, str(e.get("rol", "")), str(e.get("vida_max", 0)), str(e.get("dano", 0)),
			"%.2f" % float(e.get("velocidad", 0.0)), "%.2f" % float(e.get("ataque_dura", 0.0)),
			"%.2f" % float(e.get("alcance", 0.0)), str(e.get("spawns", 0)), str(e.get("muertes", 0)),
			"%.2f" % ttk, "%.2f" % golpes, str(e.get("dano_jugador", 0)), str(e.get("dano_tinaco", 0)),
			str(e.get("ataques", 0)), str(e.get("pegaron", 0)), "%.2f" % cad,
			str(e.get("dano_recibido", 0)), JSON.stringify(e.get("dano_por", {})).replace(",", ";"),
		]))
	archivo.close()


func _escribir_ataques() -> void:
	if carpeta_noche == "":
		return
	var archivo := FileAccess.open(carpeta_noche.path_join("ataques_noche_%d.csv" % noche), FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_line("ataque,usos,golpes,dano,muertes")
	for fuente in _ataques:
		var a: Dictionary = _ataques[fuente]
		archivo.store_line("%s,%d,%d,%d,%d" % [fuente, int(a.get("usos", 0)), int(a.get("golpes", 0)), int(a.get("dano", 0)), int(a.get("muertes", 0))])
	archivo.close()


func _escribir_items() -> void:
	if carpeta_noche == "":
		return
	var archivo := FileAccess.open(carpeta_noche.path_join("items_noche_%d.csv" % noche), FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_line("item,usos,curado,usos_de_supervivencia")
	for nombre in _items:
		var i: Dictionary = _items[nombre]
		archivo.store_line("%s,%d,%d,%d" % [nombre, int(i.get("usos", 0)), int(i.get("curado", 0)), int(i.get("apuro", 0))])
	archivo.close()


func _escribir_resumen(gano: bool) -> void:
	if carpeta_noche == "":
		return
	var archivo := FileAccess.open(carpeta_noche.path_join("resumen_noche_%d.txt" % noche), FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_line("Noche %d · %s · %s" % [noche, modo, "ganó" if gano else "perdió"])
	archivo.store_line("Dinero al empezar: %d · al terminar: %d" % [pesos_inicio, pesos_final])
	archivo.store_line("Oleadas: %d" % _olas.size())
	archivo.store_line("Ataques: " + str(_ataques))
	archivo.store_line("Mecánicas: " + str(_mecanicas))
	archivo.store_line("Ítems: " + str(_items))
	archivo.store_line("Enemigos: " + str(_enemigos))
	archivo.close()


func _csv_linea(d: Dictionary) -> String:
	return "%s,%s,%s,%s,%s,%s,%s" % [
		str(d.get("noche", "")), str(d.get("modo", "")), str(d.get("tipo", "")),
		str(d.get("tienda", "")).replace(",", " "), str(d.get("producto", "")).replace(",", " "),
		str(d.get("precio", "")), str(d.get("nivel", "")),
	]


# --- Auxiliares ---

func _sumar(dic: Dictionary, clave: String, campo: String, valor: int) -> void:
	if not dic.has(clave):
		dic[clave] = {}
	var d: Dictionary = dic[clave]
	d[campo] = int(d.get(campo, 0)) + valor


func _zombi_tipo(tipo: String) -> Dictionary:
	if not _enemigos.has(tipo):
		_enemigos[tipo] = {"rol": "", "dano_recibido": 0, "dano_por": {}}
	return _enemigos[tipo]


func _enemigo(tipo: String) -> Dictionary:
	return _zombi_tipo(tipo)


func _enemigo_ola(tipo: String) -> Dictionary:
	if not _ola.has("enemigos"):
		_ola["enemigos"] = {}
	if not _ola["enemigos"].has(tipo):
		_ola["enemigos"][tipo] = {}
	return _ola["enemigos"][tipo]


func _tipo(z: Zombie) -> String:
	if z.es_jefe:
		return "jefe"
	if z.tipo == Zombie.Tipo.GORDO:
		return "gordo"
	var indice := z.skin
	var claves := Zombie.SKINS.keys()
	var nombre := "normal"
	if indice >= 0 and indice < claves.size():
		nombre = String(claves[indice]).get_file().get_basename()
	return nombre


func _rol(z: Zombie) -> String:
	if z.es_jefe:
		return "jefe"
	if z.emboscada:
		return "emboscada"
	if z.por_jugador:
		return "por_jugador"
	if z.cazador:
		return "cazador"
	return "normal"


func _ahora() -> float:
	return Time.get_ticks_msec() / 1000.0


func _vivos() -> int:
	var n := 0
	for z in Zombie.activos:
		if z.estado != Zombie.Estado.MUERTO:
			n += 1
	return n


func _intensidad() -> float:
	var zombis := get_tree().get_first_node_in_group("zombis_mando")
	if zombis and zombis.director:
		return zombis.director.intensidad
	return 0.0


func _vida() -> int:
	var salud := get_node_or_null("/root/Salud")
	return salud.vida if salud else 0


func _tinaco() -> int:
	var tinaco := get_tree().get_first_node_in_group("tinaco_defensa")
	return tinaco.vida if tinaco else 0
