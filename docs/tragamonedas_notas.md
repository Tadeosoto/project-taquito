# Notas de tragamonedas

Texto original de `scripts/tragamonedas.gd` (copiado de un chat, no era un script que corriera; le faltaba la seccion 1). La logica de la caja y los DIP switches ya esta en `scripts/tragamonedas.gd`; quedan aqui las ideas de los dias de la semana y de los NPCs que juegan.

```

# --- SISTEMA DE CONTROL DE LA PLACA REAL ---
enum ModoDojo { DOJO_1_FACIL, DOJO_2_NORMAL, DOJO_3_DIFICIL, DOJO_4_MUY_DIFICIL }

var dip_switch_actual: ModoDojo = ModoDojo.DOJO_2_NORMAL
var caja_monedas_interna: int = 100 # Monedas que tiene la máquina en su interior al iniciar

# Filtro inteligente basado en la alcancía real
func validar_y_ajustar_premio(destino_original: int, fruta_original: String) -> int:
	var costo_premio = 0
	if apuestas.has(fruta_original):
		costo_premio = apuestas[fruta_original] * MULTIPLICADORES[fruta_original]
	
	# REGLA 1: Si la máquina no tiene suficientes monedas físicas para pagar el premio, FORZAR PÉRDIDA
	if costo_premio > caja_monedas_interna:
		return buscar_casilla_manzana_cercana(destino_original)
		
	# REGLA 2: Control de probabilidad por DIP Switches (Dojo)
	var probabilidad_bloqueo = 0.0
	match dip_switch_actual:
		ModoDojo.DOJO_1_FACIL:        probabilidad_bloqueo = 0.10 # Solo bloquea el 10% de premios grandes
		ModoDojo.DOJO_2_NORMAL:       probabilidad_bloqueo = 0.35 # Bloquea el 35%
		ModoDojo.DOJO_3_DIFICIL:      probabilidad_bloqueo = 0.60 # Bloquea el 60%
		ModoDojo.DOJO_4_MUY_DIFICIL:  probabilidad_bloqueo = 0.85 # Bloquea el 85% de premios mayores
		
	if fruta_original in ["BAR", "SIETE", "SANDIA"] and randf() < probabilidad_bloqueo:
		# El algoritmo intercepta el premio del casino y te manda a una manzana (paga poco o nada)
		return buscar_casilla_manzana_cercana(destino_original)
		
	return destino_original

func buscar_casilla_manzana_cercana(origen: int) -> int:
	# Busca la manzana más cercana en el arreglo para simular el efecto "Near Miss" (Casi ganas)
	for i in range(1, 24):
		var chequeo = (origen + i) % 24
		if TABLERO[chequeo] == "MANZANA":
			return chequeo
	return origen

# Ajustar la entrada/salida de dinero de la alcancía física
func registrar_apuesta_en_caja(cantidad: int):
	caja_monedas_interna += cantidad

func restar_premio_de_caja(cantidad: int):
	caja_monedas_interna -= cantidad
Usa el código con precaución.
Debes llamar a registrar_apuesta_en_caja(1) en tu función apostar_a_fruta(), y restar los puntos con restar_premio_de_caja(1) dentro del bucle de cantar_monedas() cada vez que una moneda caiga.

2. El Administrador del Local (Cambio de Switches diario)

Si tienes un sistema de tiempo o calendario en tu juego (días de la semana), puedes hacer que un script global o el NPC del tendero cambie la dificultad de la máquina por las mañanas.
gdscript
extends Node
# Script de control de días o IA del dueño de la tienda

@onready var maquinita_3d = get_node("/root/Mundo/MuebleMaquinita3D")

func _on_nuevo_dia_comenzado(dia_semana: String):
	var interfaz_maquinita = maquinita_3d.get_node("SubViewportContainer/SubViewport").get_child(0)
	
	match dia_semana:
		"Lunes", "Martes":
			# Días de poca clientela: la pone fácil para que la gente se enganche
			interfaz_maquinita.dip_switch_actual = interfaz_maquinita.ModoDojo.DOJO_1_FACIL
			print("El tendero puso la máquina en modo FÁCIL.")
		"Viernes", "Sábado":
			# Fin de semana de quincena: modo rudo para recaudar el máximo dinero
			interfaz_maquinita.dip_switch_actual = interfaz_maquinita.ModoDojo.DOJO_4_MUY_DIFICIL
			print("El tendero activó el modo MUY DIFICIL para exprimir los bolsillos.")
		_:
			interfaz_maquinita.dip_switch_actual = interfaz_maquinita.ModoDojo.DOJO_2_NORMAL
Usa el código con precaución.

3. Sistema para que los NPCs jueguen de forma autónoma

Para que los aldeanos o ciudadanos caminen hacia ella y la usen (haciendo que tú escuches los sonidos de fondo mientras exploras el mapa), crearemos una función de Simulación de IA. Cuando un NPC use la máquina, el código simulará sus decisiones sin necesidad de abrir la pantalla visual:
gdscript
extends CharacterBody3D
# Script pegado en la IA de tus NPCs ciudadanos

var dinero_npc: int = 30
var jugando_en_maquinita: bool = false

func intentar_jugar_tragamonedas(mueble_maquinita):
	if dinero_npc <= 5 or jugando_en_maquinita: return
	
	jugando_en_maquinita = true
	var maquinitas_logic = mueble_maquinita.get_node("SubViewportContainer/SubViewport").get_child(0)
	
	# El NPC decide cuántas monedas meter y a qué frutas (Simulando su cerebro de tiendita)
	var presupuesto_ronda = randi_range(2, 6)
	if presupuesto_ronda > dinero_npc: presupuesto_ronda = dinero_npc
	
	dinero_npc -= presupuesto_ronda
	maquinitas_logic.registrar_apuesta_en_caja(presupuesto_ronda)
	
	# Repartir apuestas de forma aleatoria en el diccionario simulado
	var opciones_frutas = ["MANZANA", "MANZANA", "NARANJA", "SIETE"] # Prefieren la manzana por instinto
	var apuestas_simuladas = {"MANZANA": 0, "NARANJA": 0, "CEREZA": 0, "CAMPANA": 0, "MELON": 0, "SANDIA": 0, "SIETE": 0, "BAR": 0}
	
	for i in presupuesto_ronda:
		var eleccion = opciones_frutas.pick_random()
		apuestas_simuladas[eleccion] += 1
		
	# --- PASO CRUCIAL: El procesador decide el destino bajo las reglas de la caja ---
	var destino_aleatorio = randi() % 24
	var fruta_ganadora = maquinitas_logic.TABLERO[destino_aleatorio]
	
	# Pasar el tiro por el filtro de los DIP Switches de la máquina
	var destino_final = maquinitas_logic.validar_y_ajustar_premio(destino_aleatorio, fruta_ganadora)
	var fruta_final = maquinitas_logic.TABLERO[destino_final]
	
	# Calcular premio del NPC
	var premio_ganado = 0
	if apuestas_simuladas[fruta_final] > 0:
		premio_ganado = apuestas_simuladas[fruta_final] * maquinitas_logic.MULTIPLICADORES[fruta_final]
		
	# Simular el tiempo que tarda la luz en girar en el mundo 3D
	# Hacemos sonar los "bips" espaciados desde el mueble para ambientar el mapa
	mueble_maquinita.get_node("AudioPaso").play()
	await get_tree().create_timer(2.0).timeout 
	
	if premio_ganado > 0:
		# La máquina le paga al NPC: El dinero sale de la alcancía y va al bolsillo del aldeano
		maquinitas_logic.restar_premio_de_caja(premio_ganado)
		dinero_npc += premio_ganado
		
		# Hacer que la máquina haga ruidos de monedas de fondo en la tienda ("Clack-clack")
		for clack in premio_ganado:
			mueble_maquinita.get_node("AudioMoneda").play()
			await get_tree().create_timer(0.06).timeout
	else:
		mueble_maquinita.get_node("AudioPerder").play()
		
	jugando_en_maquinita = false

```
