extends CharacterBody3D
class_name Player

@export var camera_sensitivity: float = 2.5
@export var mouse_sensitivity: float = 0.0025
@export var rotation_speed: float = 16.0
@export var speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var gravity: float = 40.0
@export var acceleration: float = 15.0
@export var jump_velocity: float = 13.0
# Initial downward pitch. Includes the +10.4 deg that used to be baked into the
# Camera3D node's transform, so removing that offset keeps the same view.
var camera_pitch: float = -4.6

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var frijol: Node3D = $Frijol
@onready var figura: Node3D = $Frijol/Modelo

# Con que le pega a los zombis (Zombie.gd): el mejor `dano` del inventario, o a puño limpio.
# Inventario y Salud se piden por su ruta: los scripts de tools/ cargan esta clase antes
# de que existan los autoloads
const DANO_PUNO := 5
const ATAQUE_ENFRIAR := 0.6
# Medido (tools/_combo_tmp): la hoja pasa por enfrente entre 0.233 y 0.25 s del clip, con la mano
# a 45 m/s; a los 0.22 todavia iba acelerando
const ATAQUE_PEGA_EN := 0.24
const ATAQUE_ALCANCE := 2.4
const ATAQUE_ANGULO := 0.35   # coseno: lo que abarca hacia los lados
const ATAQUE_MAXIMO := 1       # zombis a los que le pega un mismo golpe: el mas cercano
const INVULNERABLE := 0.7     # s despues de recibir un golpe
# Q (accion curarse) se come la curacion que mejor llene lo que falta, sin abrir el
# inventario (pausar rompia la tension). Mientras, no caminas ni pegas
# Drink dura 3 s: el brazo sube hasta 0.6 s, sostiene el trago hasta ~2 y baja. A 2x son 1.5 s; te
# suelta a 1.2 s (el brazo ya va bajando, el fundido de salida lo termina)
const CURAR_VELOCIDAD := 2.0
const CURAR_DURA := 1.2
# El punado de sal es Sword_Heavy_A (UAL2 Source, 0.73 s), medido en el_compa: se arma girando
# a la derecha hasta 0.37 s, la mano da casi toda la vuelta entre 0.38 y 0.57 (pasa por enfrente
# de la izquierda a la derecha hacia 0.40-0.53, a ~0.85 m, hasta 30 m/s) y se queda quieto desde
# 0.63. El arco de humo y la sal solo van enfrente (JJ): la parte del recorrido de la mano que cae
# dentro de AVIENTA_ARCO a cada lado de donde ves
const AVIENTA_ESTELA := Vector2(0.385, 0.57)  # s del clip en que se sigue a la mano
const AVIENTA_ARCO := deg_to_rad(75.0)  # rad a cada lado del frente
const AVIENTA_PASO := deg_to_rad(5.0)   # rad entre pedazo y pedazo del arco de humo
const AVIENTA_HUMO := Vector2(0.9, 3.1) # m del cuerpo: orilla de adentro y de afuera del arco
const AVIENTA_BAJA := Vector2(0.1, 0.55) # m bajo la mano de cada orilla: se avienta al piso
const AVIENTA_SUELTA := 0.45    # suena la sal (la mano pasa por enfrente)
const AVIENTA_DURA := 0.66      # ya te puedes mover
# La molotov es OverhandThrow (UAL2, 1.33 s), medido en el_compa: echa la mano atras hasta 0.27 s,
# la suelta arriba y adelante a 0.33 (lo mas rapido, 20 m/s), termina abajo a 0.43 y regresa
const MOLOTOV_SUELTA := 0.33
const MOLOTOV_DURA := 0.6
const ARMA_TAMANO := 0.95    # m; con 0.6 el machete parecia cuchillo
# El mango va en el puño: crear_modelo centra y deja lo largo en X con el mango en +X. En la mano
# (RightHand del retarget) X es hacia el pulgar, Y hacia los dedos y Z la palma: la hoja sale del
# lado del pulgar con el filo hacia los dedos, como la agarran los clips de espada de Quaternius
const ARMA_GIRO := Vector3(-90.0, 180.0, 0.0)
const ARMA_MANGO := ARMA_TAMANO * 0.4
# Lo que se siente al pegar: `fuerza` es 1 con el machete y cambia con el dano del arma
const DANO_MACHETE := 12.0
const FUERZA_MIN := 0.5
const FUERZA_MAX := 1.5
const SWING_VOLUMEN := -14.0  # dB: para que resalte el whack (JJ lo bajo a la mitad: -6 dB)
const WHACK_VOLUMEN := -6.0   # dB: a la mitad, como el swing
# m/s que rebotas hacia atras al pegarle a algo. En 0 a peticion de JJ: tu no te mueves con
# el golpe (el zombi si retrocede un poco, Zombie.EMPUJON)
const RETROCESO := 0.0
const RETROCESO_CAIDA := 14.0 # por segundo
const RETROCESO_TIRO := 0.6   # m/s para atras por balazo (0 = nada)
const RETROCESO_TIRO_FRENO := 8.0 # se va en 1/8 s
const ARMAS_TECLAS := 5       # arma_1..arma_5
const PATADA_VUELVE := 0.2    # s en que la camara regresa de la patada de un balazo
# Sangre (pixelfx sangre_arma) que gotea de la punta del arma un rato tras pegarle a un zombi
const SANGRE_DURA_MS := 2500
const SANGRE_ESCALA := 0.4
const SACUDE := 0.05          # m de la camara
const SACUDE_MATA := 2.0
const SACUDE_DURA := 0.15
const CONGELA := 0.05         # s de reloj real
const CONGELA_MATA := 0.08
const CONGELA_ESCALA := 0.02
# Cuando le pegan a el. El empujon va frenando: v * v / (2 * freno) = 1.5 m
const GOLPEADO_EMPUJE := 7.0
const GOLPEADO_FRENO := 16.3
const CONGELA_GOLPEADO := 0.06
const SACUDE_GOLPEADO := 0.09
const FLASH_MS := 55
const SANGRE := 12
const SANGRE_RADIO := 0.2
const SANGRE_ABRE := 0.45
const SANGRE_VELOCIDAD := Vector2(4.0, 9.0)
const SANGRE_ALTO := 0.3      # m sobre el centro del modelo
const COLOR_SANGRE := Color(0.62, 0.02, 0.03)

signal golpeado
# Un zombi cayo a filo de espada (el machete, no a punos): la defensa del tinaco cuenta para la estela
signal mato_con_espada

const CARGA_LUGAR := Vector3(0.0, -0.35, -0.55)
const ESTELA := preload("res://scripts/EstelaBarrido.gd")
const ESTELA_PUNO := 0.2      # m de la estela mas alla del puno, a mano limpia
# Los que pelean a punos (Personaje.A_PUNOS, Felipe) si sacan estela al pegar: de la muneca
# (ESTELA_MUNECA atras del puno) a ESTELA_PUNO adelante de los nudillos, pareja, sin la caida de
# la del machete. Ventanas medidas con los punos (PUNOS): de cuando sale el puno a cuando llega.
# El jab es con la izquierda (ESTELA_IZQUIERDA)
const ESTELA_MUNECA := 0.12
const ESTELA_PUNOS := {"Punch_Jab": Vector2(0.10, 0.22), "Punch_Cross": Vector2(0.13, 0.28),
	"Melee_Hook": Vector2(0.08, 0.32)}
const ESTELA_IZQUIERDA := ["Punch_Jab"]
# Un punetazo va derecho, en la misma linea que muneca-nudillos: esa estela salia como rayita. En
# los punetazos la estela va atravesada (PUNO_ANCHO, de lado al golpe y a la camara) y arrastra una
# banda del largo del recorrido; al pegar el puno suelta PUNO_ESTALLIDO de lo que suelte la estela
# (rayos, chispas) de golpe, para que se sienta como el machetazo (JJ)
const PUNO_ANCHO := 0.7
const PUNO_ADELANTE := 0.08   # m adelante del hueso de la mano: los nudillos
const PUNO_PASO := 0.04       # m entre pedazos
const PUNO_ESTALLIDO := 3       # con los rayos (Emiliano); son grandes
# Con las demas estelas (fuego), sin rayos que den fuerza: una llamarada de PUNO_LLAMAS nubes mas
# grandes (PUNO_LLAMAS_ESCALA) disparadas hacia el golpe, y un fogonazo de luz en el puno
const PUNO_LLAMAS := 7
const PUNO_LLAMAS_ESCALA := 1.8
const FOGONAZO_ENERGIA := 4.0
const FOGONAZO_RANGO := 4.0
const FOGONAZO_DURA := 0.15     # s
const ESTALLIDO_ADELANTE := 0.3  # m frente al puno: revienta donde pega, no tapando a Felipe
# La estela del machetazo sigue la punta del arma mientras barre (s del clip, desde-hasta): no
# al llevar el brazo atras ni al regresarlo
const ESTELA_GOLPE := {"Sword_Regular_A": Vector2(0.10, 0.30), "Sword_Regular_B": Vector2(0.10, 0.32),
	"Sword_Regular_C": Vector2(0.05, 0.75), "Sword_Dash_RM": Vector2(0.10, 0.60),
	"Sword_Attack": Vector2(0.31, 0.50)}   # el tajo cargado: solo la bajada, no la subida ni el regreso
const ESTELA_PASO := 6.0      # grados entre pedazos: con pocos cuadros salia en tiras rectas
# Hacia donde corre el efecto de la barrida: de la derecha a la izquierda del personaje, un poco
# al frente para que de lado a la camara no se voltee al azar
const BARRE_AL_FRENTE := 0.3
# Combo a mano limpia (sin arma en el inventario): jab, cruzado y gancho, y otra vez. Medido con
# los punos (medido en una escena de prueba): el jab saca el izquierdo a los 0.13-0.20 s, el cruzado el
# derecho a los 0.17-0.27, el gancho sube el derecho a los 0.10-0.30 embistiendo. pega = s del clip
# en que pega, desde = s en que ya puede salir el siguiente, dano = por el DANO_PUNO
const PUNOS := [
	{"paso": 0, "pega": 0.18, "desde": 0.25, "dano": 1.0},   # Punch_Jab
	{"paso": 1, "pega": 0.22, "desde": 0.30, "dano": 1.0},   # Punch_Cross
	{"paso": 2, "pega": 0.26, "desde": 0.40, "dano": 1.6},   # Melee_Hook, el remate
]
const COMBO_VENTANA := 0.5   # s despues del enfriamiento en que el siguiente golpe todavia va al reves
# s desde un golpe en que ya puede salir el siguiente: al terminar de barrer, sin
# esperar el enfriamiento. Si pegas antes, se guarda y sale entonces
const COMBO_DESDE := 0.3
# B (el de regreso) termina de barrer despues: a los 0.30 iba a 17 m/s y el corte se notaba
const COMBO_DESDE_B := 0.33
# Buffer corto (como Smash): solo se guarda el clic que llega en los ultimos BUFFER_GOLPE s antes
# de COMBO_DESDE; uno mas temprano se ignora para pegar (machacar no adelanta el combo), aunque
# si lo dejas apretado si cuenta para cargar
const BUFFER_GOLPE := 0.15
# s desde que empieza un golpe en que caminas lento (GOLPE_VELOCIDAD), sin correr y viendo hacia
# la camara, con el barrido solo en la parte de arriba del cuerpo. Antes (JJ) no se podia caminar
# y con pelea_a_tiempo moverte cortaba el combo; AG lo cambio el 2026-11-04
const ATAQUE_LENTO := 0.42
const ATAQUE_LENTO_A_TIEMPO := ATAQUE_PEGA_EN
const GOLPE_VELOCIDAD := 0.6  # de la velocidad al caminar
# S a medio machetazo o con la pistola camina en reversa (JJ): sigues viendo hacia donde ve la
# camara y retrocedes, sin correr. Sin hacer nada mas, S te voltea y corres hacia la camara.
# Las piernas tocan Walk al reves (Quaternius no trae caminar atras)
const RETROCEDE_VELOCIDAD := 0.55  # de la velocidad al caminar
# m/s como mucho al caminar haciendo otra cosa (pistola en mano, machetazos, la pose de carga) o
# retrocediendo: las piernas tocan Walk, que avanza ~1.3 m/s y se acelera hasta 1.6x
# (character_animation.PASO_MAX); mas rapido patinaba (en el mapa caminas a 10). Correr y el
# trote son solo para cuando no haces nada mas (JJ)
const CAMINA_MAXIMO := 2.0
# Apuntando con la pistola, o bloqueando a punos, mas lento: a 2 m/s el Walk iba a 1.54x y se
# veia como trote (JJ)
const CAMINA_PISTOLA := 1.4
# Shift a medio machetazo: trote normal en cualquier direccion (ves hacia donde corres y el golpe
# sale para alla), agachado hacia adelante como embistiendo (JJ)
# Rodada para esquivar: con Alt sostenido, cada direccion (WASD) que aprietes rueda para alla
# (JJ); Alt con una direccion ya apretada tambien. B del gamepad rueda hacia el stick, o para
# atras si no. Quaternius Roll, que rueda en su lugar; el avance lo hace el cuerpo, asi choca con
# paredes y zombis. Los tiempos son del clip (medidos con la cadera): se clava 0-0.4, rueda
# pegado al piso 0.55-0.85, se levanta agachado hasta 1.05 y luego se endereza lento hasta 1.47,
# que ya no se espera: ahi se suelta y te puedes mover o pegar
# Buffer de acciones (JJ, como Smash): espadazo, brinco, rodada y estocada que pidas mientras
# otra cosa no te deja (rodando, estocada, giro, curandote, o un espadazo antes de terminar de
# barrer) se guardan y salen en cuanto se pueda. Solo la ultima que pediste, y vale BUFFER_ACCION
# s: machacar desde antes no adelanta nada. El ataque que sigues sosteniendo no caduca: al
# quedar libre sale la pose de carga (con lo que ya llevabas apretado) o, si lo soltaste
# cargado, la estocada. Entre espadazos sigue el buffer corto del combo (BUFFER_GOLPE)
const BUFFER_ACCION := 0.3
const RODAR_VELOCIDAD := 1.6            # x el clip: 1.47 s eran demasiado para esquivar
const RODAR_AVANCE := 3.0               # m
const RODAR_AVANZA := Vector2(0.05, 0.85)  # s del clip en que avanzas
const RODAR_ESQUIVA := Vector2(0.3, 0.8)   # s del clip en que no te pegan (~0.3 s reales)
const RODAR_SUELTA := 1.05              # s del clip en que se suelta
# Tambien rueda con doble toque a cualquier WASD (JJ): la misma tecla dos veces en DOBLE_TOQUE s
const DOBLE_TOQUE := 0.25
const RODAR_ENFRIA := 0.4               # s reales despues de una antes de poder otra
# Bloquear (clic derecho / LT con el machete; JJ): Sword_Block en guardia mientras lo sostienes,
# caminando lento viendo hacia la camara. Un golpe de frente parado te quita BLOQUEO_DANO del
# dano y te arrastra hacia donde iba el golpe, mas lejos entre mas fuerte (BLOQUEO_EMPUJE m por
# punto de dano), agachado mientras te deslizas, con su sonido, sacudida y una congelada corta
const BLOQUEO_DANO := 0.25
const BLOQUEO_EMPUJE := 0.06          # m por punto de dano (un zombi pega 12: 0.72 m; JJ lo bajo a la mitad)
const BLOQUEO_EMPUJE_MIN := 0.2
const BLOQUEO_EMPUJE_MAX := 1.5
const BLOQUEO_DESLIZA := 0.35         # s que dura el arrastre
const BLOQUEO_AGACHA := 22.0          # grados (InclinarCuerpo.gd) mientras te arrastra
const BLOQUEO_FRENTE := 0.0           # coseno: de frente es la mitad de adelante
const BLOQUEO_VELOCIDAD := 0.4        # de la velocidad al caminar, en guardia
const BLOQUEO_INVULNERABLE := 0.3     # s sin que otro golpe cuente, tras uno parado
const BLOQUEO_SACUDE := 0.06
const CARGA_INCLINA := 28.0   # grados que se dobla la columna (InclinarCuerpo.gd)

# Pelea con golpe a tiempo (Zombie.CORTE) y salirte del combo moviendote. En false, la prueba
# anterior: nunca se aturde y te quedas quieto todo el barrido. La cambia la tecla 9 del safehouse
static var pelea_a_tiempo := true
# Ataque cargado (JJ, 2026-11-06): con el machete, deja apretado atacar: el arma sube detras de la
# cabeza (la pose de carga) y a los CARGA_DURA s brilla; al soltar, el tajo pesado de arriba abajo
# con avance (TAJO_*, abajo). Antes salia la estocada, que ya no tenia sentido: el giro y la
# estocada aerea pegan a varios con el dano del espadazo. El tajo es el que pega fuerte (TAJO_DANO).
# Lo prenden el safehouse (tecla 7) y la defensa del tinaco
static var golpe_cargado := false
# PRUEBA (JJ): golpe con brinco. Pegar en el aire con el machete: espadazo giratorio
# (Sword_Regular_C, la cadera da la vuelta entre 0 y 0.7 s) que pega en redondo al caer.
# Solo lo prende el safehouse (tecla 6)
static var giro_aereo := false
# El giro con la estela de agua: pensada como mejora que se gana (JJ). false = la estela normal
const CARGA_DURA := 0.4       # s con el boton apretado (JJ: 0.7 era mucho)
# Apretado al menos esto cuando toca el siguiente golpe = lo estas sosteniendo: en vez del golpe
# entras a la pose de carga (golpe, golpe, carga). Un clic rapido dura menos
const CARGA_DECIDE := 0.12
const CARGA_POSE_EN := 0.29   # s de Sword_Attack en que se queda quieta la pose: el arma arriba, atras
const CARGA_COLOR := Color(1.0, 0.55, 0.12)   # naranja monarca (antes azul)
const CARGA_LUZ := 2.5        # energia de la luz al estar cargado
# Ya cargado a todo, la punta del arma echa las nubes de la estela del protagonista (llamas,
# chispas, rayos, polvo: EstelaBarrido.estallar): un estallido de CARGA_ESTALLIDO al llenarse y
# luego una cada CARGA_LLAMA_CADA s mientras sostienes (JJ). El tajo suelta TAJO_LLAMAS al bajar
const CARGA_ESTALLIDO := 6
const CARGA_LLAMA_CADA := 0.06   # s
const CARGA_LLAMA_ESCALA := 0.8
const TAJO_LLAMAS := 9
const TAJO_LLAMAS_ESCALA := 1.6
const GIRO_PEGA_EN := 0.35    # s del clip: a media vuelta
const GIRO_DURA := 0.95       # s: ahi se suelta el clip (lo demas es enderezarse) y ya puedes moverte
const GIRO_ALCANCE := 1.3     # x el alcance normal, en redondo
const GIRO_DANO := 1.5        # x el dano del arma
const GIRO_MAXIMO := 6        # zombis a los que le pega
# En el aire: el clip arranca lento (38 grados en 0.1 s), asi que empieza ya en GIRO_AIRE_DESDE s,
# girando, y un poco mas rapido; el salto sigue igual. El golpe pega al caer al piso
const GIRO_AIRE_DESDE := 0.12
const GIRO_AIRE_VELOCIDAD := 1.5
# El giro en el aire siempre termina en el piso (JJ): a los GIRO_AIRE_CAE s del clip la espada
# baja de golpe y se agacha (medido: la cadera llega abajo y la mano cae de 4.1 a 1.6), y ese
# cuadro debe coincidir con tocar el suelo. Al hacer clic se calcula cuanto falta para caer:
# si sobra aire, el brinco se corta (baja la velocidad vertical) para caer justo ahi; si falta,
# el giro se acelera hasta GIRO_AIRE_VEL_MAX y, si ni asi, termina ya en el piso. Pega en ese
# cuadro, y lo demas (agachado y levantarse) va a velocidad normal
const GIRO_AIRE_CAE := 0.7
const AZOTE_RADIO := 3.5        # m: el giro al caer levanta lombrices (EnjambreLombrices)
const AZOTE_FUERZA := 9.0
const GIRO_AIRE_VEL_MAX := 2.5
const PIES := 1.0             # m del centro del cuerpo a los pies (la capsula mide 2)
# La estocada con avance, que sale al soltar el ataque cargado:
# Sword_Dash_RM, te lanza ESTOCADA_AVANCE m hacia donde ve la camara (el clip avanza 3.7 m con
# su hueso Root, que la biblioteca quita; aqui lo hace el cuerpo, asi choca con las paredes) y
# atraviesa: le pega a cada zombi que tengas enfrente mientras avanzas, hasta ESTOCADA_MAXIMO.
# Su estela es la de todos los golpes (EstelaBarrido.estilo); con la de la monarca, ademas sale
# volando una monarca chiquita de la punta del arma (MariposaMonarca.gd)
const ESTOCADA_AVANCE := 3.5   # m
const ESTOCADA_DESDE := 0.12   # s del clip en que arranca el avance (el amago antes)
const ESTOCADA_HASTA := 0.55   # s en que ya llegaste
const ESTOCADA_PEGA := Vector2(0.15, 0.6)  # s del clip en que la punta hace dano
# Atraviesa a varios (JJ): a 1.4 m y en un cono angosto casi siempre le pegaba a uno solo
const ESTOCADA_RADIO := 2.0    # m enfrente de ti en que le pega a un zombi
const ESTOCADA_CONO := 0.0     # coseno: toda la mitad de enfrente
const ESTOCADA_DURA := 0.8     # s: ahi se suelta el clip y ya puedes moverte
const ESTOCADA_DANO := 1.5     # x el dano del arma
# Desde aqui (s del clip) otra accion (espadazo, rodada, brinco) corta lo que queda de la estocada,
# del piso o del aire, sin esperar a ESTOCADA_DURA (JJ: mas fluido). Ya acabo el avance (0.55) y
# la punta deja de pegar en 0.6
const ESTOCADA_LIBRE := 0.62
const ESTOCADA_MAXIMO := 6
# Estocada desde el aire (JJ): brincando con Shift apretado, el clic no hace el giro sino la
# estocada, como un clavado: el clip a velocidad normal y el mismo desliz que la estocada en el
# piso (ESTOCADA_AVANCE con su curva), y a la vez bajas en linea recta hasta el piso que hay donde
# termina el desliz, tocandolo justo al terminar (ESTOCADA_AIRE_CAE). Empieza en el amago agachado
# (ESTOCADA_AIRE_DESDE). Si estas muy alto, baja a lo mas ESTOCADA_AIRE_BAJA m en el desliz y lo
# demas cae normal en la pose de la estocada; en el piso lo demas sigue a velocidad normal
const ESTOCADA_AIRE_DESDE := 0.1
const ESTOCADA_AIRE_CAE := ESTOCADA_HASTA
const ESTOCADA_AIRE_BAJA := 4.0
const ESTOCADA_AIRE_AVANCE := 5.0   # m: mas que en el piso (ESTOCADA_AVANCE), para que valga el brinco
# El tajo cargado (JJ, 2026-11-06): Sword_Attack de Quaternius, que no se habia usado. Medido en
# el_compa: sube el arma detras de la cabeza hasta 0.29 s (ahi se queda la pose de carga), baja en
# diagonal de arriba a la derecha hasta la cadera izquierda entre 0.33 y 0.50 (la mano a 59 m/s en
# 0.40), se queda abajo hasta 0.77 y regresa a la guardia. Usa lo de la estocada (avance con
# smoothstep, pega una vez a cada uno), con sus numeros. Es el unico con multiplicador fuerte
const TAJO_AVANCE := 1.8       # m que avanza al bajar el arma
const TAJO_DESDE := 0.30       # s del clip en que arranca el avance
const TAJO_HASTA := 0.48
const TAJO_PEGA := Vector2(0.36, 0.48)   # s del clip en que la hoja hace dano
const TAJO_RADIO := 2.4        # m enfrente
const TAJO_CONO := 0.2         # coseno: casi toda la mitad de enfrente (barre en diagonal)
const TAJO_DURA := 0.85        # s: ahi se suelta el clip (antes del regreso) y ya te mueves
const TAJO_LIBRE := 0.6        # s: desde aqui otra accion lo corta
const TAJO_DANO := 2.5         # x el dano del arma (machete 12 = 30: mata a un zombi normal)
const TAJO_MAXIMO := 4
const BARRE_ALTO := 0.7       # m: la hoja barre a ras de piso; asi pasa por donde va el brazo
# La pistola (Pistola.gd): R cambia entre ella y el arma de golpe. Se ve en la mano en vez del
# machete; no es objeto del inventario por ahora
const PISTOLA := preload("res://scripts/Pistola.gd")
const PISTOLA_MODELO := preload("res://models/armas/pistola_mk23/pistola_mk23.scn")
# En el modelo el canon va hacia -X y la cacha abajo en +X. Con el ninja cabezon median 0.55 m
# para distinguirse en su puno enorme; el protagonista tiene manos de tamano normal
const PISTOLA_TAMANO := 0.4
# En la mano: lo de arriba de la pistola hacia el pulgar (X) y el canon hacia los dedos (Y)
const PISTOLA_GIRO := Vector3(0.0, 0.0, -90.0)
const PISTOLA_ROLL := 0.0     # grados sobre el canon, si la cacha saliera hacia arriba
# Del largo: la parte alta de la cacha (modelo 0.30, -0.04; medido de la malla) queda en el puno,
# 7 cm hacia los dedos y 3 hacia la palma; la corredera arriba de la mano y el canon sobre los nudillos
const PISTOLA_MANGO := Vector3(-0.47, 0.04, 0.07)
const PISTOLA_CANON := Vector3(-0.5, 0.12, 0.0) # la boca, del largo, desde el centro del modelo
# Por donde salta el casquillo (Pistola._expulsar_casquillo): arriba de la corredera, atras de la boca
const PISTOLA_EXPULSION := Vector3(-0.2, 0.12, 0.0)
# De donde sale el cargador al recargar (Pistola._soltar_cargador): la base de la cacha, medida de la malla
const PISTOLA_CARGADOR := Vector3(0.4, -0.16, 0.0)
# El cargador nuevo en la mano izquierda (Pistola, TOMA_EN a METE_EN), en m y grados en el
# hueso LeftHand (dedos +Y, palma +Z)
const CARGADOR_MANO := Vector3(-0.09, 0.06, 0.03)
# La corredera, cortada de la malla al vuelo (_cortar_corredera): los triangulos cuyo centro cae en
# esta caja (del largo, en el marco del modelo como PISTOLA_CANON: x de la boca a atras, y desde el
# centro) se vuelven una pieza aparte que Pistola.rack recorre RACK_ATRAS m hacia atras
const CORREDERA_X := Vector2(-0.12, 0.5)
const CORREDERA_Y := 0.07
const RACK_PUNTO := Vector3(0.3, 0.17, 0.0) # donde la agarra la izquierda: arriba, atras
const CARGADOR_MANO_GIRO := Vector3(0.0, 0.0, 90.0) # lo largo hacia el pulgar (-X en la izquierda), saliendo del puno
const ARRIBA_TRAS_TIRO := 0.8 # s que sigue apuntando despues de disparar desde la cadera
const MIRA_LEJOS := 20.0      # m: a donde apuntan los brazos sobre el rayo de la mira
const PECHO := 0.5            # m sobre el centro del cuerpo: de ahi se mide a que altura apunta
# Con la pistola, camara al hombro como Fortnite: mas cerca y mas alta, a la derecha (con el
# personaje al centro la mira le caia en la espalda), y el personaje siempre ve hacia donde
# apunta la camara, caminando de lado. Con apuntar (clic derecho, LT) se acerca mas, cierra
# el angulo, caminas mas lento y el raton se mueve mas fino
const HOMBRO := 0.8           # m a la derecha
const HOMBRO_ALTO := 0.85     # m que sube el pivote: a la altura de la cabeza
const HOMBRO_BRAZO := 2.6     # m del resorte (sin pistola, el de la escena)
const APUNTA_HOMBRO := 1.1
const APUNTA_BRAZO := 2.0
const APUNTA_FOV := 45.0      # grados (sin apuntar, el de la camara)
const APUNTA_VELOCIDAD := 0.5 # de la velocidad al caminar
const APUNTA_RATON := 0.55    # de la sensibilidad
const CAMARA_CAMBIA := 10.0   # que tan rapido llega la camara a su lugar (por segundo)

static var _material_blanco: StandardMaterial3D

var _velocidad_base := Vector2.ZERO
var _factor_dano := 1.0
var _alcance := ATAQUE_ALCANCE
var _enfriar := 0.0
var _pega_en := -1.0
var _apretado := -1.0           # s que llevas apretando atacar; -1 = no estas cargando
var _cargado := false
var _pose_carga := false     # en la pose de carga: el siguiente golpe se cambio por cargar
var _giro := -1.0            # s desde que salio el giro; -1 = no hay
var _giro_pego := false
var _giro_vel := 1.0         # GIRO_AIRE_VELOCIDAD si salio en el aire
var _giro_aire := false      # salio en el aire: pega al caer (_revisar_carga)
var _luz_carga: OmniLight3D
# Con la estela de la monarca, cada ataque suelta una monarca chiquita donde termina el machete,
# cerca del final de la barrida (_estela_golpe)
var _mariposa_pendiente := false
const MARIPOSA_EN := 0.9      # de la ventana de la estela: cerca del final de la barrida
var _estocada_t := -1.0      # s desde que salio la estocada; -1 = no hay
var _estocada_vel := 1.0     # 0 = quieta en el aire esperando el piso
var _estocada_aire := false  # salio del aire: vuelve a 1x al caer
var _estocada_quieta := false  # del aire, ya en su pose final y todavia sin piso: espera
var _estocada_avance := ESTOCADA_AVANCE  # m del desliz: mas largo desde el brinco
var _tajo := false             # la que va es el tajo cargado (TAJO_*), no la estocada del aire
var _tajo_estallo := false     # ya solto sus llamas al bajar el arma
var _llama_t := 0.0            # s para la siguiente llama de la carga
var _clavando := false         # la estocada del aire va deslizandose y bajando
var _clavado_baja := 0.0       # m que baja durante el desliz
var _estocada_dir := Vector3.ZERO
var _estocada_pegados: Array = []
var _estocada_lombrices := false   # esta estocada ya corto lombrices
# Lo que te frena (lombrices pegadas, lodo de la Madre): fuente -> factor; se multiplican
var lastres := {}
var _lanzador: Lanzador
var _rodada_t := -1.0        # s del clip Roll desde que salio la rodada; -1 = no hay
var _rodada_dir := Vector3.ZERO
var _rodar_espera := 0.0
var _bloqueando := false
var _agachado := 0.0        # s que le quedan al agachado del arrastre por un golpe parado
var _buffer := ""            # "golpe", "brinco", "rodar" o "estocada"; "" = nada
var _buffer_edad := 0.0       # s de juego desde que se pidio (la congelada tambien la frena)
var _buffer_dir := Vector2.ZERO   # las teclas de direccion al pedir la rodada
var _invulnerable := 0.0
var _curando := 0.0
var _aturdido := 0.0           # s que quedan aturdido: te tronó la palomita en la mano (aturdirte)
var sin_combate := false       # la casa propia (CasaPropia.gd): sin armas, rodadas ni curarse, y nada te hace daño
var _aventando := -1.0          # s del punado de sal; -1 = no
var _avienta_dir := Vector3.FORWARD
var _avienta_solto := false
var _avienta_molotov := false  # lo que se esta aventando es la molotov (si no, la sal)
var _avienta_ang := INF        # angulo de la mano respecto al frente (en planta) el cuadro pasado
var _humo: Node              # EstelaBarrido.gd con humo: el arco de la sal
var golpes := 0           # para medir el balance (MonitorDefensa)
var golpes_pegaron := 0
var muertes_espada := 0
const SALTO := 3.0   # m entre dos ticks: mas que esto no es caminar
var _pos_antes := Vector3.ZERO
var _pos_ahora := Vector3.ZERO
var _frijol_base := Vector3.ZERO
var _pivote_base := Vector3.ZERO
var _carga: Node3D
var _retroceso := Vector3.ZERO
var _retroceso_freno := 42.0
var _flash_hasta := 0
var _sacude_fuerza := 0.0
var _sacude_hasta := 0
var _patada := 0.0            # grados de patada que la camara aun debe regresar
var _patada_vel := 0.0
var _sangre_arma: MeshInstance3D
var _sangre_hasta := 0        # ms de reloj real
var _congelado_hasta := 0
var _escala_antes := 1.0
var _camara: Camera3D
var _voz: AudioStreamPlayer3D
var _mano: BoneAttachment3D
var _estela: Node            # EstelaBarrido.gd
var _punta: Node3D           # la punta de lo que traes en la mano, para la estela
var _mano_izq: BoneAttachment3D   # la izquierda, para la estela del jab a punos
var _luz_fogonazo: OmniLight3D
var _tween_fogonazo: Tween
var _estela_antes := []      # [mano, de la mano a la punta] del cuadro anterior
var _lado_golpe := 1.0        # 1: de derecha a izquierda; -1: el de regreso del combo
var _combo_hasta := 0.0       # s de juego en que se acaba la ventana del combo
var _puno := -1               # paso del combo a mano limpia que va (PUNOS); -1 = con arma
var _golpe_guardado := false
var _golpe_tras_brinco := false
var _toque_accion := ""          # la ultima direccion que apretaste en el teclado (doble toque)
var _toque_ms := -100000  # el espadazo guardado que cedio su turno al brinco: sale en el aire
var _combo_roto := false      # te moviste a medio combo: el siguiente empieza de nuevo
var _arma_visible: InventoryItemData
var _pistola: Node
var _dato_pistola: InventoryItemData
var _hombro := 0.0
var _alzar := 0.0
var _brazo_base := 4.0
var _fov_base := 75.0
var _apuntando := false
var _canon: Node3D
var _expulsion: Node3D
var _salida_cargador: Node3D   # la base de la cacha
var _cargador_mano: MeshInstance3D
var _corredera: Node3D             # la pieza que se recorre (hija del arma, en m, +X hacia atras)
var _agarre_corredera: Node3D      # donde va la izquierda, se mueve con la corredera
static var _cortes := {}           # malla de la pistola -> [lo demas, la corredera]
var _canon_local := Vector3.LEFT # hacia donde tira la pistola, en el hueso de la mano (AgarrePistola.gd)
var _tiro_hasta := 0


func _ready() -> void:
	add_to_group("jugador")
	_frijol_base = frijol.position
	_pivote_base = camera_pivot.position
	_camara = spring_arm.find_child("Camera3D", true, false) as Camera3D
	_brazo_base = spring_arm.spring_length
	_fov_base = _camara.fov
	var reloj := RelojCongelada.new()
	reloj.jugador = self
	reloj.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(reloj)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_voz = AudioStreamPlayer3D.new()
	add_child(_voz)
	_armar_mano()
	_armar_estela()
	_pistola = PISTOLA.new()
	_pistola.name = "Pistola"
	_pistola.jugador = self
	add_child(_pistola)
	_lanzador = Lanzador.new()
	_lanzador.name = "Lanzador"
	_lanzador.jugador = self
	add_child(_lanzador)
	_dato_pistola = InventoryItemData.new()
	_dato_pistola.item_name = "Pistola"
	_dato_pistola.inspection_model = PISTOLA_MODELO
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		inventario.inventory_changed.connect(_mostrar_arma)
	_mostrar_arma()
	aplicar_personaje()
	var tazos := get_node_or_null("/root/Tazos")
	if tazos:
		tazos.cambio.connect(aplicar_habilidades)


# Tu cuerpo (autoload Personaje): se ve en el modelo y cambia vida, velocidad y golpe. Sobre los
# valores de la escena, que no son iguales en todas. Encima van las habilidades de los tazos
# (Tazos.gd). Te deja con la vida llena
func aplicar_personaje() -> void:
	var personaje := get_node_or_null("/root/Personaje")
	if personaje:
		personaje.vestir(figura)
		# La estela de tus golpes va con el protagonista (Personaje.ESTELAS)
		ESTELA.estilo = personaje.estela()
	_mostrar_arma()
	_aplicar_cuerpo(true)


# Cuando gastas o regresas puntos: igual, pero te quedas con la misma fraccion de vida
func aplicar_habilidades() -> void:
	_aplicar_cuerpo(false)


# Por nombre de nodo y no por clase: los scripts de tools/ cargan este archivo sin autoloads
func _aplicar_cuerpo(llenar: bool) -> void:
	if _velocidad_base == Vector2.ZERO:
		_velocidad_base = Vector2(speed, sprint_speed)
	var personaje := get_node_or_null("/root/Personaje")
	var tazos := get_node_or_null("/root/Tazos")
	if personaje == null and tazos == null:
		return
	var velocidad: float = (personaje.factor_velocidad() if personaje else 1.0) * (tazos.factor_velocidad() if tazos else 1.0)
	speed = _velocidad_base.x * velocidad
	sprint_speed = _velocidad_base.y * velocidad
	_factor_dano = (personaje.factor_dano() if personaje else 1.0) * (tazos.factor_dano() if tazos else 1.0)
	_alcance = ATAQUE_ALCANCE * (personaje.factor_alcance() if personaje else 1.0) * (tazos.factor_alcance() if tazos else 1.0)
	var salud := get_node_or_null("/root/Salud")
	if salud == null:
		return
	var fraccion: float = float(salud.vida) / maxf(salud.vida_max, 1.0)
	var base: int = personaje.vida_max() if personaje else salud.vida_max
	salud.vida_max = roundi(base * (tazos.factor_vida() if tazos else 1.0))
	salud.vida = salud.vida_max if llenar else maxi(roundi(fraccion * salud.vida_max), 1)


# Vida, dano del arma que traes, velocidad al caminar y alcance con el personaje pero sin
# tazos: la pagina de habilidades les aplica cada nivel para mostrar numeros de verdad
func valores_sin_tazos() -> Dictionary:
	var personaje := get_node_or_null("/root/Personaje")
	var valores := {}
	var velocidad_base := _velocidad_base.x if _velocidad_base != Vector2.ZERO else speed
	valores["velocidad"] = velocidad_base * (personaje.factor_velocidad() if personaje else 1.0)
	valores["alcance"] = ATAQUE_ALCANCE * (personaje.factor_alcance() if personaje else 1.0)
	var dano := DANO_PUNO
	var inventario := get_node_or_null("/root/Inventory")
	if inventario and inventario.arma():
		dano = inventario.arma().dano
	valores["dano"] = dano * (personaje.factor_dano() if personaje else 1.0)
	var salud := get_node_or_null("/root/Salud")
	if personaje:
		valores["vida"] = personaje.vida_max()
	elif salud:
		valores["vida"] = salud.vida_max
	return valores


# --- Pelear ---

func _atacar() -> void:
	# El siguiente sale encadenado, sin esperar todo el enfriamiento del anterior
	var encadena := _enfriar > 0.0 and not _combo_roto
	if _enfriar > 0.0 and not encadena:
		return
	if encadena and ATAQUE_ENFRIAR - _enfriar < _combo_desde():
		if ATAQUE_ENFRIAR - _enfriar >= _combo_desde() - BUFFER_GOLPE:
			_golpe_guardado = true
		return
	_golpe_guardado = false
	_combo_roto = false
	_enfriar = ATAQUE_ENFRIAR
	_pega_en = ATAQUE_PEGA_EN
	# Combo: mientras sigas pegando a tiempo, cada golpe va al reves del anterior; si tardas,
	# empieza otra vez de derecha a izquierda
	var ahora := Time.get_ticks_msec() / 1000.0
	var sigue := encadena or ahora <= _combo_hasta
	_lado_golpe = -_lado_golpe if sigue else 1.0
	_combo_hasta = ahora + ATAQUE_ENFRIAR + COMBO_VENTANA
	# Sin arma (o si el protagonista pelea a punos), a punetazos: jab, cruzado, gancho (y vuelve)
	if _punos() and figura.has_method("punetazo"):
		_puno = (_puno + 1) % PUNOS.size() if sigue and _puno >= 0 else 0
		_pega_en = PUNOS[_puno]["pega"]
		figura.punetazo(_puno)
	else:
		_puno = -1
		# Encadenado, el clip nuevo sale de donde va el brazo (character_animation.gd)
		if figura.has_method("golpe"):
			figura.golpe(_lado_golpe)
	_estela_antes = []
	_mariposa_pendiente = true
	_sonar("machetazo", SWING_VOLUMEN)


func _sin_arma() -> bool:
	var inventario := get_node_or_null("/root/Inventory")
	return inventario == null or inventario.arma() == null


# El protagonista pelea a punos aunque traiga arma (Personaje.A_PUNOS, Felipe): no se le ve el
# machete, pero pega con su dano (golpes potenciados), y tiene carga, giro y golpe en el aire
func _a_punos() -> bool:
	var personaje := get_node_or_null("/root/Personaje")
	return personaje != null and personaje.a_punos()


# Pega a punetazos: sin arma, o porque asi pelea
func _punos() -> bool:
	return _sin_arma() or _a_punos()


# La carga, el giro y pegar en el aire: con arma, o a punos si asi pelea. A mano limpia porque no
# traes arma no (JJ)
func _especiales() -> bool:
	return not _sin_arma() or _a_punos()


func _golpear(giro := false) -> void:
	var dano := DANO_PUNO
	var con_arma := false
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		var arma: InventoryItemData = inventario.arma()
		if arma:
			dano = arma.dano
			con_arma = not _a_punos()
	var remate: float = PUNOS[_puno]["dano"] if _puno >= 0 and not con_arma and not giro else 1.0
	dano = maxi(roundi(dano * _factor_dano * (GIRO_DANO if giro else 1.0) * remate), 1)
	var frente := -frijol.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var barre := -frijol.global_basis.x * _lado_golpe + frente * BARRE_AL_FRENTE
	barre.y = 0.0
	if not giro:
		efecto("golpe", barre, "" if con_arma else "puno", BARRE_ALTO)
	# A punos (Felipe), el puno suelta de golpe lo que suelte su estela al pegar
	if _puno >= 0 and _a_punos() and _estela and _mano:
		var clip: String = figura.clip_golpe() if figura.has_method("clip_golpe") else ""
		var hueso: BoneAttachment3D = _mano_izq if clip in ESTELA_IZQUIERDA and _mano_izq else _mano
		var frente_puno := -frijol.global_transform.basis.z
		var donde := _nudillos(hueso) + frente_puno * ESTALLIDO_ADELANTE
		if ESTELA.estilo == ESTELA.Estilo.RAYOS:
			_estela.estallar(donde, PUNO_ESTALLIDO)
		else:
			_estela.estallar(_nudillos(hueso), PUNO_LLAMAS, frente_puno, PUNO_LLAMAS_ESCALA)
		_fogonazo(_nudillos(hueso))
	var fuerza := clampf(float(dano) / DANO_MACHETE, FUERZA_MIN, FUERZA_MAX)
	# Un zombi muerto en este golpe truena justo al soltar la congelada
	var truena_en := int(CONGELA_MATA * 1000.0)
	var pego := false
	var mato := false
	var alcanzados: Array[Node3D] = []
	for zombi: Node3D in get_tree().get_nodes_in_group("zombis"):
		if zombi is Zombie and zombi.estado == Zombie.Estado.MUERTO:
			continue
		var hacia := zombi.global_position - global_position
		hacia.y = 0.0
		if giro:
			if hacia.length() <= _alcance * GIRO_ALCANCE:
				alcanzados.append(zombi)
		elif hacia.length() <= _alcance and hacia.normalized().dot(frente) >= ATAQUE_ANGULO:
			alcanzados.append(zombi)
	# Solo a los ATAQUE_MAXIMO mas cercanos: amontonados, un combo mataba hasta 5
	alcanzados.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	for zombi in alcanzados.slice(0, GIRO_MAXIMO if giro else ATAQUE_MAXIMO):
		var resultado: int = zombi.recibir_golpe(dano, global_position, fuerza, truena_en)
		pego = pego or resultado != 0
		mato = mato or resultado == 2
		if resultado == 2 and con_arma:
			_conto_espada()
	# Las lombrices (EnjambreLombrices, MadreCarcamo) no estan en "zombis": el golpe les corta los
	# hilos aparte
	for enjambre in get_tree().get_nodes_in_group("lombrices"):
		if enjambre.golpe_cuerpo(global_position, frente, _alcance * (GIRO_ALCANCE if giro else 1.0), ATAQUE_ANGULO, dano, giro):
			pego = true
	# Un tambo prendido de la pelea con la Madre: patearlo riega fuego (ZonaLombrices.patear)
	for tambo: Node3D in get_tree().get_nodes_in_group("tambos_lombriz"):
		var al_tambo := tambo.global_position - global_position
		al_tambo.y = 0.0
		if al_tambo.length() < _alcance and (giro or al_tambo.normalized().dot(frente) >= ATAQUE_ANGULO):
			tambo.patear(al_tambo)
	golpes += 1
	if pego:
		golpes_pegaron += 1
		_sentir_golpe(frente, fuerza, mato)
		_sangre_hasta = Time.get_ticks_msec() + SANGRE_DURA_MS


func _conto_espada() -> void:
	muertes_espada += 1
	mato_con_espada.emit()


# Ataque cargado: cada cuadro de fisica mientras cargas o giras
func _revisar_carga(delta: float) -> void:
	if _apretado >= 0.0:
		if _pistola.activa or not is_physics_processing() or not _especiales():
			_cancelar_carga()
		elif not Input.is_action_pressed("attack"):
			var soltar := _cargado
			var en_pose := _pose_carga
			_cancelar_carga(false)
			if _ocupado():
				# Lo soltaste rodando o a media estocada o giro: cargado, la estocada espera en el
				# buffer; si no, el golpe que pediste cuenta desde que soltaste
				if soltar:
					_guardar("estocada")
				elif _buffer == "golpe":
					_buffer_edad = 0.0
			elif soltar:
				_estocar(CARGA_POSE_EN if en_pose else 0.0)
			elif en_pose:
				# Soltaste antes de cargar: sale el golpe que habias pedido
				_atacar()
		else:
			_apretado += delta
			if not _cargado and _apretado >= CARGA_DURA:
				_cargado = true
				Sonidos.tocar(self, "machetazo", SWING_VOLUMEN - 4.0, 1.6)
				if _estela:
					_estela.estallar(_punta_arma(), CARGA_ESTALLIDO, Vector3.UP, CARGA_LLAMA_ESCALA)
					_fogonazo(_punta_arma())
				_llama_t = CARGA_LLAMA_CADA
			elif _cargado and _estela:
				_llama_t -= delta
				if _llama_t <= 0.0:
					_llama_t = CARGA_LLAMA_CADA
					_estela.estallar(_punta_arma(), 1, Vector3.UP, CARGA_LLAMA_ESCALA)
			_brillo_carga()
	if _giro >= 0.0:
		_giro += delta * _giro_vel
		# El de aire pega en el cuadro del azote (GIRO_AIRE_CAE), que se calculo para caer ahi.
		# Si todavia vas en el aire (la cuenta fallo: caiste de una orilla), espera al piso
		if _giro_aire and _giro >= GIRO_AIRE_CAE and (is_on_floor() or _giro >= GIRO_DURA * 2.0):
			_giro_aire = false
			if not _giro_pego:
				_giro_pego = true
				_golpear(true)
			# El azote en el piso levanta a las lombrices en redondo (sin matarlas)
			for enjambre in get_tree().get_nodes_in_group("lombrices"):
				enjambre.apply_explosion_impulse(global_position - Vector3.UP * 0.9, AZOTE_RADIO, AZOTE_FUERZA, false)
			_giro_vel = 1.0
			if figura.has_method("velocidad_giro"):
				figura.velocidad_giro(1.0)
			_enfriar = maxf(GIRO_DURA - _giro, 0.0)
		if not _giro_pego and _giro >= GIRO_PEGA_EN and not _giro_aire:
			_giro_pego = true
			_golpear(true)
		if _giro >= GIRO_DURA and not _giro_aire:
			_giro = -1.0
			_soltar_combo()


func _cancelar_carga(soltar_pose := true) -> void:
	_apretado = -1.0
	if _pose_carga:
		_pose_carga = false
		if soltar_pose and figura.has_method("soltar_golpe"):
			figura.soltar_golpe()
	_cargado = false
	if _luz_carga:
		_luz_carga.visible = false


# Un machetazo llego a donde ya puede salir el siguiente y sigues apretando: en vez del golpe,
# la pose de carga. Asi clic, clic, sostener es golpe, golpe, carga, y lo que llevabas apretado
# ya cuenta
func _toca_pose_carga() -> bool:
	return golpe_cargado and not _pose_carga and _apretado >= CARGA_DECIDE and _especiales() \
			and _enfriar > 0.0 and not _combo_roto and _giro < 0.0 and _estocada_t < 0.0 \
			and ATAQUE_ENFRIAR - _enfriar >= _combo_desde() and figura.has_method("pose_carga")


# s del golpe que va en que ya puede salir el siguiente: al terminar de barrer, segun el clip
func _combo_desde() -> float:
	if _puno >= 0:
		return PUNOS[_puno]["desde"]
	return COMBO_DESDE if _lado_golpe > 0.0 else COMBO_DESDE_B


func _empezar_pose_carga() -> void:
	_pose_carga = true
	_golpe_guardado = false
	_enfriar = 0.0
	figura.pose_carga(CARGA_POSE_EN)


# Una luz azul en la punta del arma: crece mientras cargas y late ya cargado
func _brillo_carga() -> void:
	if _luz_carga == null:
		_luz_carga = OmniLight3D.new()
		_luz_carga.light_color = CARGA_COLOR
		_luz_carga.omni_range = 2.5
		_luz_carga.shadow_enabled = false
		_luz_carga.top_level = true
		add_child(_luz_carga)
	_luz_carga.global_position = _punta_arma()
	_luz_carga.visible = true
	if _cargado:
		_luz_carga.light_energy = CARGA_LUZ * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.025))
	else:
		_luz_carga.light_energy = CARGA_LUZ * 0.4 * _apretado / CARGA_DURA


func _punta_arma() -> Vector3:
	if _punta and is_instance_valid(_punta) and _punta.is_inside_tree():
		return _punta.global_position
	return _mano.global_position if _mano else frijol.global_position + Vector3.UP


func _girar(aire := false) -> void:
	if not figura.has_method("golpe_giro"):
		return
	var velocidad := GIRO_AIRE_VELOCIDAD if aire else 1.0
	if aire:
		velocidad = _ajustar_caida(velocidad, GIRO_AIRE_DESDE, GIRO_AIRE_CAE, GIRO_AIRE_VEL_MAX)
	_giro_aire = aire
	_giro = GIRO_AIRE_DESDE if aire else 0.0
	_giro_vel = velocidad
	_giro_pego = false
	_pega_en = -1.0
	_golpe_guardado = false
	_combo_roto = true
	_combo_hasta = 0.0
	_puno = -1
	_enfriar = (GIRO_DURA - _giro) / velocidad
	figura.golpe_giro(velocidad, _giro)
	_estela_antes = []
	_mariposa_pendiente = true
	Sonidos.tocar(self, "machetazo", SWING_VOLUMEN, 0.8)


# Para que el azote del giro (o la estocada desde el aire) caiga justo al tocar el piso: el clip
# va de `desde` a `cae` s; corta el brinco si sobra aire, o regresa una velocidad mayor para el
# clip si falta (hasta `vel_max`). Sin piso abajo (30 m) no cambia nada
func _ajustar_caida(velocidad: float, desde_clip: float, cae: float, vel_max: float) -> float:
	var desde := global_position + Vector3.DOWN * PIES
	var rayo := PhysicsRayQueryParameters3D.create(desde + Vector3.UP * 0.1, desde + Vector3.DOWN * 30.0, 1, [get_rid()])
	var choque := get_world_3d().direct_space_state.intersect_ray(rayo)
	if choque.is_empty():
		return velocidad
	var alto := maxf(desde.y - choque.position.y, 0.0)
	var vy := velocity.y
	var al_piso := (vy + sqrt(vy * vy + 2.0 * gravity * alto)) / gravity
	var falta := (cae - desde_clip) / velocidad
	if al_piso > falta:
		# Sobra aire: la velocidad vertical que cae en `falta` s desde esta altura
		velocity.y = minf(vy, (0.5 * gravity * falta * falta - alto) / falta)
		return velocidad
	return minf((cae - desde_clip) / maxf(al_piso, 0.01), vel_max)


# El clavado: cuanto hay que bajar para tocar el piso donde termina el desliz
func _empezar_clavado() -> void:
	var pies := global_position + Vector3.DOWN * PIES
	var llega := pies + _estocada_dir * _estocada_avance
	var espacio := get_world_3d().direct_space_state
	var choque := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(
			llega + Vector3.UP * 0.5, llega + Vector3.DOWN * 30.0, 1, [get_rid()]))
	if choque.is_empty():
		# Nada alla (una orilla): el piso de abajo
		choque = espacio.intersect_ray(PhysicsRayQueryParameters3D.create(
				pies, pies + Vector3.DOWN * 30.0, 1, [get_rid()]))
	_clavado_baja = clampf(pies.y - choque.position.y, 0.0, ESTOCADA_AIRE_BAJA) if not choque.is_empty() \
			else ESTOCADA_AIRE_BAJA
	_clavando = true
	velocity = Vector3.ZERO


# aire: la estocada desde el brinco con Shift (ESTOCADA_AIRE_*), en vez del giro
func _estocar(desde := 0.0, aire := false) -> void:
	if not figura.has_method("golpe_estocada"):
		return
	_estocada_vel = 1.0
	_estocada_aire = aire
	_estocada_quieta = false
	_clavando = false
	# En el piso (al soltar la carga) ya no es estocada sino el tajo
	_tajo = not aire
	_tajo_estallo = false
	_estocada_avance = ESTOCADA_AIRE_AVANCE if aire else TAJO_AVANCE
	if aire:
		_cancelar_carga(false)
		desde = ESTOCADA_AIRE_DESDE
	_estocada_t = desde
	_estocada_pegados.clear()
	_estocada_lombrices = false
	_pega_en = -1.0
	_golpe_guardado = false
	_combo_roto = true
	_combo_hasta = 0.0
	_puno = -1
	_enfriar = (ESTOCADA_DURA + 1.0) if aire else (TAJO_DURA - desde)  # del aire se recalcula al caer
	# Hacia donde ve el personaje (JJ): caminando a medio golpe ves al frente aunque vayas para
	# atras con S, y sale al frente. Con Shift corres viendo hacia donde vas: sale hacia las
	# teclas (no hacia donde iba volteando el modelo a medio giro)
	var teclas := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if Input.is_action_pressed("sprint") and teclas.length_squared() > 0.01:
		var frente := -camera_pivot.global_transform.basis.z
		var lado := camera_pivot.global_transform.basis.x
		_estocada_dir = lado * teclas.x - frente * teclas.y
	else:
		_estocada_dir = -frijol.global_transform.basis.z
	_estocada_dir.y = 0.0
	_estocada_dir = _estocada_dir.normalized()
	frijol.global_transform = frijol.global_transform.looking_at(frijol.global_position + _estocada_dir, Vector3.UP)
	if aire:
		_empezar_clavado()
		figura.golpe_estocada(desde, _estocada_vel)
	elif figura.has_method("golpe_tajo"):
		figura.golpe_tajo(desde)
	_estela_antes = []
	_mariposa_pendiente = true
	Sonidos.tocar(self, "machetazo", SWING_VOLUMEN, 0.55 if _tajo else 0.7)


# Esquivar rodando: corta lo que estuvieras haciendo con el machete (combo, carga)
func _rodar(teclas: Vector2) -> void:
	if not figura.has_method("rodar"):
		return
	if teclas.length_squared() > 0.01:
		var frente := -camera_pivot.global_transform.basis.z
		var lado := camera_pivot.global_transform.basis.x
		_rodada_dir = lado * teclas.x - frente * teclas.y
	else:
		# Sin teclas, para atras: lo normal es alejarte del que te va a pegar
		_rodada_dir = frijol.global_transform.basis.z
	_rodada_dir.y = 0.0
	_rodada_dir = _rodada_dir.normalized()
	_cancelar_carga(false)
	_soltar_combo()
	_pega_en = -1.0
	_enfriar = 0.0
	_rodada_t = 0.0
	frijol.global_transform = frijol.global_transform.looking_at(frijol.global_position + _rodada_dir, Vector3.UP)
	figura.rodar(RODAR_VELOCIDAD)


# --- Buffer de acciones ---

func _pedir_accion(accion: String) -> void:
	# Sin pelea (la casa propia) solo se puede brincar
	if sin_combate and accion != "brinco":
		return
	if accion == "rodar":
		_buffer_dir = _teclas_mover()
	if _puede(accion):
		_hacer(accion)
	else:
		_guardar(accion)


func _guardar(accion: String) -> void:
	_buffer = accion
	_buffer_edad = 0.0
	if accion == "rodar":
		_buffer_dir = _teclas_mover() if _teclas_mover().length_squared() > 0.01 else _buffer_dir


# Cada cuadro de fisica: lo guardado sale en cuanto se pueda, o caduca
func _probar_buffer(delta: float) -> void:
	if _buffer == "":
		return
	_buffer_edad += delta
	var sostenido := _buffer == "golpe" and _apretado >= 0.0 and Input.is_action_pressed("attack")
	if not sostenido and _buffer_edad > BUFFER_ACCION:
		_buffer = ""
		return
	if _puede(_buffer):
		# Lo apretaste a media accion y lo sigues sosteniendo: todavia no se sabe si es clic o
		# carga. Espera a CARGA_DECIDE (sostenido = la pose de carga de una vez) o a que lo
		# sueltes (el espadazo). Sin esto, si el tajo se soltaba antes de los 0.12 s salia un
		# espadazo primero y la carga despues
		if sostenido and golpe_cargado and _apretado < CARGA_DECIDE and is_on_floor() and _especiales():
			_buffer_edad = 0.0
			return
		var accion := _buffer
		_buffer = ""
		_hacer(accion)


# Rodando, a media estocada o giro, o curandote: nada mas sale
func _ocupado() -> bool:
	return _rodada_t >= 0.0 or (_estocada_t >= 0.0 and _estocada_t < (TAJO_LIBRE if _tajo else ESTOCADA_LIBRE)) \
			or _giro >= 0.0 or _curando > 0.0 or _aventando >= 0.0 or _aturdido > 0.0


# Lo que queda de la estocada (pasado ESTOCADA_LIBRE) se corta para que salga otra accion.
# soltar: regresa el cuerpo a caminar (si lo que sigue no trae su propio clip)
func _cortar_estocada(soltar: bool) -> void:
	_estocada_t = -1.0
	_estocada_aire = false
	_estocada_quieta = false
	_clavando = false
	_enfriar = 0.0
	if soltar:
		_soltar_combo()
	else:
		_combo_roto = true
		_golpe_guardado = false


# Un espadazo que todavia no termina de barrer
func _barriendo() -> bool:
	return _enfriar > 0.0 and not _combo_roto and not _pose_carga \
			and ATAQUE_ENFRIAR - _enfriar < _combo_desde()


func _puede(accion: String) -> bool:
	if _ocupado():
		return false
	match accion:
		"golpe":
			# entre espadazos manda el buffer corto del combo (_atacar); a puno limpio no se pega
			# en el aire
			return is_on_floor() or _especiales()
		"rodar":
			return is_on_floor() and _rodar_espera <= 0.0 and not _barriendo()
		"brinco":
			return is_on_floor() and not _barriendo()
		"estocada":
			return not _barriendo()
	return false


func _hacer(accion: String) -> void:
	if _estocada_t >= 0.0:
		_cortar_estocada(accion == "brinco")
	match accion:
		"golpe":
			if giro_aereo and not is_on_floor() and _especiales():
				# En el aire sale de una vez el espadazo giratorio; con Shift, la estocada que te
				# lanza hacia adelante y cae con ella (JJ)
				if Input.is_action_pressed("sprint"):
					_estocar(0.0, true)
				else:
					_girar(true)
			elif golpe_cargado and Input.is_action_pressed("attack") and _apretado >= CARGA_DECIDE \
					and figura.has_method("pose_carga") and _especiales():
				# Lo sigues sosteniendo desde antes: de una vez a la pose de carga
				_soltar_combo()
				_combo_roto = false
				_empezar_pose_carga()
			else:
				if _combo_roto and _enfriar > 0.0:
					_enfriar = 0.0
				_atacar()
		"rodar":
			_rodar(_buffer_dir)
		"brinco":
			# Brincar ya no rompe la carga (JJ): sigues en la pose y al soltar sale el tajo en el aire
			velocity.y = jump_velocity
			if _golpe_tras_brinco:
				_golpe_tras_brinco = false
				_guardar("golpe")
		"estocada":
			_estocar()


func _teclas_mover() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


# Una tecla de direccion recien apretada (no la repeticion de dejarla apretada)
# true en el segundo toque de la misma WASD dentro de DOBLE_TOQUE s (solo teclado: el stick no)
func _doble_toque(event: InputEvent) -> bool:
	if not event is InputEventKey or event.is_echo() or not event.is_pressed():
		return false
	for accion: String in ["move_forward", "move_backward", "move_left", "move_right"]:
		if event.is_action_pressed(accion):
			var ahora := Time.get_ticks_msec()
			var doble := accion == _toque_accion and ahora - _toque_ms <= int(DOBLE_TOQUE * 1000.0)
			# Tras rodar, el siguiente toque empieza de cero: tres toques no son dos rodadas
			_toque_accion = "" if doble else accion
			_toque_ms = ahora
			return doble
	return false


func _es_direccion(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	for accion: String in ["move_forward", "move_backward", "move_left", "move_right"]:
		if event.is_action_pressed(accion):
			return true
	return false


func _revisar_rodada(delta: float) -> void:
	_rodar_espera = maxf(_rodar_espera - delta, 0.0)
	if _rodada_t < 0.0:
		return
	_rodada_t += delta * RODAR_VELOCIDAD
	if _rodada_t >= RODAR_SUELTA:
		_rodada_t = -1.0
		_rodar_espera = RODAR_ENFRIA
		if figura.has_method("soltar_golpe"):
			figura.soltar_golpe()


# En la parte de la rodada en que vas pegado al piso no te pegan
func esquivando() -> bool:
	return _rodada_t >= RODAR_ESQUIVA.x and _rodada_t <= RODAR_ESQUIVA.y


# Cada cuadro de fisica de la estocada: la punta pega a los que tengas enfrente, una vez a cada uno
func _revisar_estocada(delta: float) -> void:
	if _estocada_t < 0.0:
		return
	_estocada_t += delta * _estocada_vel
	# Desde el aire: al caer, lo demas a velocidad normal. Si llego a su pose final todavia en el
	# aire (caiste de una orilla), se queda ahi hasta tocar el piso
	if _clavando and (is_on_floor() or _estocada_t >= ESTOCADA_AIRE_CAE):
		_clavando = false
	if _estocada_aire:
		if is_on_floor() and _estocada_t > ESTOCADA_AIRE_DESDE + 0.05:
			_estocada_aire = false
			_estocada_quieta = false
			_estocada_vel = 1.0
			if figura.has_method("velocidad_estocada"):
				figura.velocidad_estocada(1.0)
			_enfriar = maxf(ESTOCADA_DURA - _estocada_t, 0.0)
		elif _estocada_t >= ESTOCADA_AIRE_CAE and not is_on_floor():
			_estocada_t = ESTOCADA_AIRE_CAE
			if not _estocada_quieta:
				_estocada_quieta = true
				_estocada_vel = 0.0
				if figura.has_method("velocidad_estocada"):
					figura.velocidad_estocada(0.0)
			_enfriar = maxf(_enfriar, ESTOCADA_DURA - _estocada_t)
	var pega := TAJO_PEGA if _tajo else ESTOCADA_PEGA
	if _tajo and not _tajo_estallo and _estocada_t >= pega.x and _estela:
		# El arma va bajando: un chorro de llamas hacia adelante y el fogonazo
		_tajo_estallo = true
		_estela.estallar(_punta_arma(), TAJO_LLAMAS, _estocada_dir, TAJO_LLAMAS_ESCALA)
		_fogonazo(_punta_arma())
	if _estocada_t >= pega.x and _estocada_t <= pega.y \
			and _estocada_pegados.size() < (TAJO_MAXIMO if _tajo else ESTOCADA_MAXIMO):
		_pegar_estocada()
	if _estocada_t >= (TAJO_DURA if _tajo else ESTOCADA_DURA):
		_estocada_t = -1.0
		_soltar_combo()


func _pegar_estocada() -> void:
	var dano := DANO_PUNO
	var inventario := get_node_or_null("/root/Inventory")
	if inventario and inventario.arma():
		dano = inventario.arma().dano
	dano = maxi(roundi(dano * _factor_dano * (TAJO_DANO if _tajo else ESTOCADA_DANO)), 1)
	var maximo := TAJO_MAXIMO if _tajo else ESTOCADA_MAXIMO
	var radio := TAJO_RADIO if _tajo else ESTOCADA_RADIO
	var cono := TAJO_CONO if _tajo else ESTOCADA_CONO
	var fuerza := clampf(float(dano) / DANO_MACHETE, FUERZA_MIN, FUERZA_MAX)
	var pego := false
	var mato := false
	for zombi: Node3D in get_tree().get_nodes_in_group("zombis"):
		if _estocada_pegados.size() >= maximo:
			break
		if zombi in _estocada_pegados or (zombi is Zombie and zombi.estado == Zombie.Estado.MUERTO):
			continue
		var hacia := zombi.global_position - global_position
		hacia.y = 0.0
		if hacia.length() <= radio and hacia.normalized().dot(_estocada_dir) >= cono:
			_estocada_pegados.append(zombi)
			var resultado: int = zombi.recibir_golpe(dano, global_position, fuerza, int(CONGELA_MATA * 1000.0))
			pego = pego or resultado != 0
			mato = mato or resultado == 2
			if resultado == 2 and not _sin_arma():
				_conto_espada()
	# Lombrices: una vez por estocada o tajo, en cuanto alcanza alguna
	if not _estocada_lombrices:
		for enjambre in get_tree().get_nodes_in_group("lombrices"):
			# El tajo cargado corta todo lo que alcanza
			if enjambre.golpe_cuerpo(global_position, _estocada_dir, radio, cono, dano, false, _tajo):
				_estocada_lombrices = true
				pego = true
	if pego:
		golpes_pegaron += 1
		_sentir_golpe(_estocada_dir, fuerza, mato)
		_sangre_hasta = Time.get_ticks_msec() + SANGRE_DURA_MS


# Lo que avanza la estocada en este cuadro, como el hueso Root del clip: arranca de golpe y frena
func _velocidad_estocada(delta: float) -> Vector3:
	var desde := TAJO_DESDE if _tajo else ESTOCADA_DESDE
	var hasta := TAJO_HASTA if _tajo else ESTOCADA_HASTA
	var antes := _estocada_avance * smoothstep(desde, hasta, _estocada_t - delta * _estocada_vel)
	var ahora := _estocada_avance * smoothstep(desde, hasta, _estocada_t)
	return _estocada_dir * ((ahora - antes) / maxf(delta, 0.0001))


# Una vez por golpe, aunque le pegue a varios: el whack, el rebote, la sacudida y la congelada
func _sentir_golpe(frente: Vector3, fuerza: float, mato: bool) -> void:
	_voz.pitch_scale = randf_range(0.9, 1.12)
	_sonar("whack", WHACK_VOLUMEN)
	_retroceso = -frente * RETROCESO * fuerza
	_retroceso_freno = RETROCESO * RETROCESO_CAIDA
	_sacude_fuerza = SACUDE * fuerza * (SACUDE_MATA if mato else 1.0)
	_sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	_congelar(CONGELA_MATA if mato else CONGELA)


# El juego casi se detiene unos cuadros. Un SceneTreeTimer no servia para soltarlo: con la
# escala de tiempo tan baja se quedaba en camara lenta varios segundos
# Al soltar regresa a la escala que habia (una noche acelerada para probar), no a 1
func _congelar(segundos: float) -> void:
	if _congelado_hasta == 0:
		_escala_antes = Engine.time_scale
	_congelado_hasta = maxi(_congelado_hasta, Time.get_ticks_msec() + int(segundos * 1000.0))
	Engine.time_scale = CONGELA_ESCALA * _escala_antes


func _revisar_congelada() -> void:
	var ahora := Time.get_ticks_msec()
	if _congelado_hasta > 0 and ahora >= _congelado_hasta:
		_congelado_hasta = 0
		Engine.time_scale = _escala_antes
	if _flash_hasta > 0 and ahora >= _flash_hasta:
		_flash_hasta = 0
		_pintar_blanco(false)


func _exit_tree() -> void:
	if _congelado_hasta > 0:
		_congelado_hasta = 0
		Engine.time_scale = _escala_antes


# Mira el reloj en cada cuadro aunque el juego este en pausa o el jugador apagado (el
# inventario, una tienda): la congelada siempre se suelta
class RelojCongelada extends Node:
	var jugador: Player

	func _process(_delta: float) -> void:
		jugador._revisar_congelada()


# Un golpe de zombi (Zombie.gd), con todo lo que se siente: congelada, flash, sacudida,
# empujon y sangre hacia donde iba el golpe; Supervivencia.gd hace el cuadro de impacto
func recibir_dano(dano: int, desde: Vector3, empuja := 1.0) -> void:
	if sin_combate or _invulnerable > 0.0 or esquivando():
		return
	if _bloqueando:
		var hacia_mi := global_position - desde
		hacia_mi.y = 0.0
		var frente := -frijol.global_basis.z
		frente.y = 0.0
		if hacia_mi.length_squared() < 0.001 or frente.normalized().dot(-hacia_mi.normalized()) > BLOQUEO_FRENTE:
			_parar_golpe(dano, hacia_mi, empuja)
			return
	_invulnerable = INVULNERABLE
	# Te pegan cargando: se pierde la carga (el golpe que recibes tapa la pose)
	if _pose_carga:
		_cancelar_carga(false)
	# Aventando sal no se interrumpe: el arco y la sal siguen a la mano, y el golpe la tapaba
	if figura.has_method("accion") and _aventando < 0.0:
		figura.accion("RecieveHit")
	_sonar("dolor")
	var hacia := global_position - desde
	hacia.y = 0.0
	hacia = hacia.normalized() if hacia.length_squared() > 0.001 else frijol.global_basis.z
	_flash_hasta = Time.get_ticks_msec() + FLASH_MS
	_pintar_blanco(true)
	_retroceso = hacia * GOLPEADO_EMPUJE * empuja
	_retroceso_freno = GOLPEADO_FRENO
	_sacude_fuerza = SACUDE_GOLPEADO
	_sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	_congelar(CONGELA_GOLPEADO)
	_sangrar(hacia)
	efecto("herido", hacia)
	golpeado.emit()
	# Piel dura (Tazos.gd): de noche duele menos
	var tazos := get_node_or_null("/root/Tazos")
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if tazos and ciclo and ciclo.es_noche():
		dano = maxi(roundi(dano * tazos.factor_dano_noche()), 1)
	get_node("/root/Salud").vida -= dano


# Te tronó la palomita en la mano (Lanzador.soltar_molotov): `segundos` sin moverte ni hacer nada
# (lo que dura el zumbido), tapandote la cara (Crying), y te baja `dano` aunque estes
# invulnerable o rodando: no es un golpe de nadie, ni se bloquea
func aturdirte(segundos: float, dano: int) -> void:
	if _pose_carga:
		_cancelar_carga(false)
	_soltar_combo()
	# Truena a medio OverhandThrow: se corta, o al acabar (_seguir_aventada) soltaba el Crying
	_aventando = -1.0
	_avienta_molotov = false
	_aturdido = segundos
	if figura.has_method("accion"):
		figura.accion("aturdido")
	_sonar("dolor")
	_flash_hasta = Time.get_ticks_msec() + FLASH_MS
	_pintar_blanco(true)
	_sacude_fuerza = SACUDE_GOLPEADO
	_sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	efecto("herido", frijol.global_basis.z)
	golpeado.emit()
	get_node("/root/Salud").vida -= dano


# Un golpe de frente parado con el machete: poco dano y un arrastre hacia donde iba el golpe
func _parar_golpe(dano: int, hacia: Vector3, empuja: float) -> void:
	_invulnerable = BLOQUEO_INVULNERABLE
	hacia = hacia.normalized() if hacia.length_squared() > 0.001 else frijol.global_basis.z
	var tazos := get_node_or_null("/root/Tazos")
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if tazos and ciclo and ciclo.es_noche():
		dano = maxi(roundi(dano * tazos.factor_dano_noche()), 1)
	# Distancia del arrastre por el dano completo (lo fuerte del golpe), no por lo que te quita
	var lejos := clampf(dano * BLOQUEO_EMPUJE * empuja, BLOQUEO_EMPUJE_MIN, BLOQUEO_EMPUJE_MAX)
	var arranque := 2.0 * lejos / BLOQUEO_DESLIZA
	_retroceso = hacia * arranque
	_retroceso_freno = arranque / BLOQUEO_DESLIZA
	_agachado = BLOQUEO_DESLIZA + 0.1
	if figura.has_method("bloqueo_golpe"):
		figura.bloqueo_golpe()
	Sonidos.tocar(self, "bloqueo", 0.0, randf_range(0.92, 1.08))
	_sacude_fuerza = BLOQUEO_SACUDE
	_sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	_congelar(CONGELA)
	get_node("/root/Salud").vida -= maxi(roundi(dano * BLOQUEO_DANO), 1)


# Cada cuadro de fisica: en guardia mientras sostengas bloquear con el machete y nada mas te
# ocupe. Un espadazo, la rodada o la estocada la tapan; al terminar, si sigues apretando, vuelve
func _revisar_bloqueo(delta: float) -> void:
	_agachado = maxf(_agachado - delta, 0.0)
	var quiere: bool = Input.is_action_pressed("bloquear") and not _pistola.activa and not _ocupado() \
			and not _barriendo() and is_on_floor() and not sin_combate
	if quiere == _bloqueando:
		return
	_bloqueando = quiere
	if quiere:
		_cancelar_carga(false)
		_golpe_guardado = false
	if figura.has_method("bloquear"):
		figura.bloquear(quiere)


func bloqueando() -> bool:
	return _bloqueando


# Sale de adentro del modelo, que es lo que se ve (frijol va suavizado). Por grupo y sin el
# tipo: los scripts de tools/ cargan esta clase
func _sangrar(hacia: Vector3) -> void:
	var liquido := get_tree().get_first_node_in_group("liquido")
	if liquido:
		liquido.salpicar(frijol.global_position + Vector3.UP * SANGRE_ALTO, SANGRE_RADIO, global_position.y - 1.0,
			(hacia + Vector3.UP * 0.3).normalized(), SANGRE, COLOR_SANGRE, SANGRE_VELOCIDAD, SANGRE_ABRE)


# Un efecto de pixel (EfectosPixel.gd) a los pies del modelo, que es lo que se ve. Por grupo y
# sin el tipo, como el liquido
func efecto(lugar: String, hacia: Vector3, opcion := "", alto := 0.0) -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos:
		efectos.lanzar(lugar, Vector3(frijol.global_position.x, global_position.y - 1.0 + alto, frijol.global_position.z), hacia, 1.0, opcion)


# Todo el modelo, con el arma que traiga en la mano
func _pintar_blanco(prendido: bool) -> void:
	if _material_blanco == null:
		_material_blanco = StandardMaterial3D.new()
		_material_blanco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_blanco.albedo_color = Color.WHITE
		_material_blanco.disable_fog = true
	for malla: MeshInstance3D in frijol.find_children("*", "MeshInstance3D", true, false):
		malla.material_overlay = _material_blanco if prendido else null


# Algo en las manos, enfrente: una mision (MisionesMundo.gd)
func cargar(cosa: Node3D) -> void:
	soltar_carga()
	_carga = cosa
	frijol.add_child(cosa)
	cosa.position = CARGA_LUGAR
	cosa.rotation = Vector3.ZERO
	figura.set("cargando", true)


func soltar_carga() -> void:
	if _carga:
		_carga.queue_free()
		_carga = null
	figura.set("cargando", false)


# La tecla de curarse: lo que mejor llene la vida que falta (Inventory.mejor_curacion)
func _curarse() -> void:
	if _curando > 0.0 or sin_combate:
		return
	var inventario := get_node_or_null("/root/Inventory")
	var salud := get_node_or_null("/root/Salud")
	if inventario == null or salud == null:
		return
	var cual: int = inventario.mejor_curacion(salud.vida_max - salud.vida)
	if salud.llena() or cual < 0:
		Sonidos.tocar(self, "ui_error", -6.0)
		return
	inventario.usar_curacion(cual)
	Sonidos.tocar(self, "inv_usar", -4.0)
	beber()


# La animacion de curarse (Drink), tambien desde el inventario (InventoryUI._utilizar): puedes
# caminar mientras tanto, el brazo va solo arriba
func beber() -> void:
	_soltar_combo()
	_curando = CURAR_DURA
	if figura.has_method("curar"):
		figura.curar(CURAR_VELOCIDAD)


# El punado de sal: voltea hacia `dir` y barre la mano con Sword_Heavy_A; mientras la mano pasa por
# enfrente (_seguir_aventada) deja un arco de humo blanco como la estela del machete y sala ese
# mismo pedazo de arco (Lanzador.salar_tramo): el golpe sigue a la animacion. false si ya andaba
func aventar_sal(dir: Vector3) -> bool:
	if _aventando >= 0.0 or not is_on_floor():
		return false
	_aventando = 0.0
	_avienta_molotov = false
	_avienta_dir = dir
	_avienta_solto = false
	_avienta_ang = INF
	_lanzador.empezar_punado()
	_soltar_combo()
	frijol.global_transform = frijol.global_transform.looking_at(frijol.global_position + dir, Vector3.UP)
	if figura.has_method("accion"):
		figura.accion("aventar")
	if _humo == null:
		_humo = ESTELA.new()
		_humo.humo = true
		add_child(_humo)
	return true


# La molotov (Lanzador.soltar_clic): voltea hacia `dir` y avienta por encima del hombro; a
# MOLOTOV_SUELTA sale de la mano (Lanzador.soltar_molotov). false si ya andaba
func aventar_molotov(dir: Vector3) -> bool:
	if _aventando >= 0.0 or not is_on_floor():
		return false
	_aventando = 0.0
	_avienta_molotov = true
	_avienta_dir = dir
	_avienta_solto = false
	_soltar_combo()
	frijol.global_transform = frijol.global_transform.looking_at(frijol.global_position + dir, Vector3.UP)
	if figura.has_method("accion"):
		figura.accion("molotov")
	return true


func _seguir_aventada(delta: float) -> void:
	_aventando += delta
	if _avienta_molotov:
		if not _avienta_solto and _aventando >= MOLOTOV_SUELTA:
			_avienta_solto = true
			_lanzador.soltar_molotov()
		if _aventando >= MOLOTOV_DURA:
			_aventando = -1.0
			_avienta_molotov = false
			if figura.has_method("terminar_accion"):
				figura.terminar_accion()
		return
	var mano := _mano.global_position if _mano and _mano.is_inside_tree() else frijol.global_position + Vector3.UP
	if _aventando >= AVIENTA_ESTELA.x and _aventando <= AVIENTA_ESTELA.y:
		_arco_sal(mano)
	if not _avienta_solto and _aventando >= AVIENTA_SUELTA:
		_avienta_solto = true
		_lanzador.sonar_punado()
	if _aventando >= AVIENTA_DURA:
		_aventando = -1.0
		if figura.has_method("terminar_accion"):
			figura.terminar_accion()


# La mano esta en `mano`: lo que barrio desde el cuadro pasado, recortado a AVIENTA_ARCO del
# frente, deja pedazos del arco de humo cada AVIENTA_PASO y sala ese sector
func _arco_sal(mano: Vector3) -> void:
	var centro := global_position
	var hacia := Vector3(mano.x - centro.x, 0.0, mano.z - centro.z)
	if hacia.length_squared() < 0.0025:
		return
	var ang := _avienta_dir.signed_angle_to(hacia, Vector3.UP)
	var antes := _avienta_ang
	_avienta_ang = ang
	# El primer cuadro, o si da la vuelta por atras (de 180 a -180), no hay tramo
	if is_inf(antes) or absf(ang - antes) > PI:
		return
	var a := clampf(antes, -AVIENTA_ARCO, AVIENTA_ARCO)
	var b := clampf(ang, -AVIENTA_ARCO, AVIENTA_ARCO)
	if is_equal_approx(a, b):
		return
	_lanzador.salar_tramo(_avienta_dir.rotated(Vector3.UP, a), _avienta_dir.rotated(Vector3.UP, b))
	var pasos := maxi(1, ceili(absf(b - a) / AVIENTA_PASO))
	for k in pasos + 1:
		var d := _avienta_dir.rotated(Vector3.UP, lerpf(a, b, float(k) / pasos))
		var adentro := Vector3(centro.x, mano.y - AVIENTA_BAJA.x, centro.z) + d * AVIENTA_HUMO.x
		var afuera := Vector3(centro.x, mano.y - AVIENTA_BAJA.y, centro.z) + d * AVIENTA_HUMO.y
		_humo.agregar(adentro, afuera, true)


# Se queda quieto y deja de contestar (al desmayarse, Supervivencia.gd)
func detener() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)


func reanudar() -> void:
	set_physics_process(true)
	set_process_unhandled_input(true)
	if figura.has_method("terminar_accion"):
		figura.terminar_accion()


func caer() -> void:
	if figura.has_method("accion"):
		figura.accion("Defeat")


# La mano derecha del modelo; el arma se ve en ella
func _armar_mano() -> void:
	var esqueleto := _esqueleto()
	if esqueleto == null:
		return
	for nombre in ["RightHand", "Fist.R", "Hand.R", "Wrist.R", "LowerArm.R"]:
		if esqueleto.find_bone(nombre) >= 0:
			_mano = BoneAttachment3D.new()
			esqueleto.add_child(_mano)
			_mano.bone_name = nombre
			break
	if esqueleto.find_bone("LeftHand") >= 0:
		_mano_izq = BoneAttachment3D.new()
		esqueleto.add_child(_mano_izq)
		_mano_izq.bone_name = "LeftHand"


# Te moviste a medio combo: el brazo se suelta desde donde va y lo que habias picado se olvida
func _soltar_combo() -> void:
	if _pose_carga:
		_cancelar_carga(false)
	_combo_roto = true
	_golpe_guardado = false
	_combo_hasta = 0.0
	_puno = -1
	if figura.has_method("soltar_golpe"):
		figura.soltar_golpe()


# El esqueleto del modelo: con el retarget se llama GeneralSkeleton, no Skeleton3D
func _esqueleto() -> Skeleton3D:
	var esqueletos := figura.find_children("*", "Skeleton3D", true, false)
	return esqueletos[0] as Skeleton3D if not esqueletos.is_empty() else null


func _armar_estela() -> void:
	_estela = ESTELA.new()
	_estela.name = "Estela"
	add_child(_estela)


# La estela sigue la punta del arma mientras el machetazo barre (character_animation.gd dice
# cuanto lleva). Entre un cuadro y otro se rellena el arco en pedazos de ESTELA_PASO grados
func _estela_golpe() -> void:
	if _estela == null or _mano == null or not figura.has_method("tiempo_golpe"):
		return
	var t: float = figura.tiempo_golpe()
	var clip: String = figura.clip_golpe()
	var ventana: Vector2 = ESTELA_GOLPE.get(clip, Vector2.ZERO)
	if _a_punos() and ESTELA_PUNOS.has(clip):
		ventana = ESTELA_PUNOS[clip]
	if t < 0.0 or t < ventana.x or t > ventana.y:
		_estela_antes = []
		return
	var hueso: BoneAttachment3D = _mano_izq if clip in ESTELA_IZQUIERDA and _mano_izq else _mano
	var con_punta := _punta and is_instance_valid(_punta) and _punta.is_inside_tree()
	if not con_punta and ESTELA_PUNOS.has(clip):
		_estela_puno(hueso)
		return
	var mano := hueso.global_position
	var punta: Vector3
	if con_punta:
		punta = _punta.global_position
	else:
		# A punos: de la muneca a adelante de los nudillos (los dedos son la Y del hueso)
		var dedos := hueso.global_basis.y.normalized()
		punta = mano + dedos * ESTELA_PUNO
		mano -= dedos * ESTELA_MUNECA
	var hacia := punta - mano
	if _estela_antes.is_empty():
		_estela_antes = [mano, hacia]
		return
	var mano_antes: Vector3 = _estela_antes[0]
	var hacia_antes: Vector3 = _estela_antes[1]
	if _mariposa_pendiente and t >= lerpf(ventana.x, ventana.y, MARIPOSA_EN):
		_mariposa_pendiente = false
		if ESTELA.estilo == ESTELA.Estilo.MONARCA:
			# Sale de donde quedo la punta del machete y vuela hacia adelante del personaje (JJ:
			# hacia afuera de la estela se iban para atras)
			MariposaMonarca.soltar(get_tree().current_scene, punta, -frijol.global_transform.basis.z)
	var pasos := maxi(ceili(rad_to_deg(hacia_antes.angle_to(hacia)) / ESTELA_PASO), 1)
	for i in range(1, pasos + 1):
		var f := float(i) / pasos
		var donde := mano_antes.lerp(mano, f)
		_estela.agregar(donde, donde + hacia_antes.slerp(hacia, f), not con_punta)
	_estela_antes = [mano, hacia]


# La estela atravesada del punetazo (PUNO_ANCHO): el puno arrastra una banda de lado
func _estela_puno(hueso: BoneAttachment3D) -> void:
	var puno := _nudillos(hueso)
	if _estela_antes.is_empty():
		_estela_antes = [puno, Vector3.ZERO]
		return
	var antes: Vector3 = _estela_antes[0]
	var mov := puno - antes
	if mov.length() < 0.005:
		return
	var lado := mov.cross(puno - _camara.global_position)
	if lado.length_squared() < 0.000001:
		lado = Vector3.UP
	lado = lado.normalized() * PUNO_ANCHO * 0.5
	var pasos := maxi(ceili(mov.length() / PUNO_PASO), 1)
	for i in range(1, pasos + 1):
		var p := antes.lerp(puno, float(i) / pasos)
		_estela.agregar(p - lado, p + lado, true)
	_estela_antes = [puno, Vector3.ZERO]


# El puno truena con luz: un instante de luz del color de la estela que se apaga en FOGONAZO_DURA
func _fogonazo(donde: Vector3) -> void:
	if _luz_fogonazo == null:
		_luz_fogonazo = OmniLight3D.new()
		_luz_fogonazo.shadow_enabled = false
		_luz_fogonazo.top_level = true
		add_child(_luz_fogonazo)
	var colores := {ESTELA.Estilo.FUEGO: Color(1.0, 0.55, 0.15), ESTELA.Estilo.AGUA: Color(0.5, 0.75, 1.0),
		ESTELA.Estilo.RAYOS: Color(1.0, 0.75, 0.5), ESTELA.Estilo.FLAMAS_FELIPE: Color(0.9, 0.92, 1.0),
		ESTELA.Estilo.MONARCA: Color(1.0, 0.6, 0.2)}
	_luz_fogonazo.light_color = colores.get(ESTELA.estilo, Color(1.0, 0.95, 0.85))
	_luz_fogonazo.omni_range = FOGONAZO_RANGO
	_luz_fogonazo.global_position = donde
	_luz_fogonazo.light_energy = FOGONAZO_ENERGIA
	_luz_fogonazo.visible = true
	if _tween_fogonazo:
		_tween_fogonazo.kill()
	_tween_fogonazo = create_tween()
	_tween_fogonazo.tween_property(_luz_fogonazo, "light_energy", 0.0, FOGONAZO_DURA)
	_tween_fogonazo.tween_callback(func() -> void: _luz_fogonazo.visible = false)


func _nudillos(hueso: BoneAttachment3D) -> Vector3:
	return hueso.global_position + hueso.global_basis.y.normalized() * PUNO_ADELANTE


func _mostrar_arma() -> void:
	if _mano == null:
		return
	var inventario := get_node_or_null("/root/Inventory")
	var arma: InventoryItemData = inventario.arma() if inventario else null
	var pistola: bool = _pistola != null and _pistola.activa
	if pistola:
		arma = _dato_pistola
	elif _a_punos() or (_lanzador and _lanzador.activo):
		# Con la sal o la molotov en la mano no se ve el machete
		arma = null
	if sin_combate:
		arma = null
	if arma == _arma_visible:
		return
	_arma_visible = arma
	_canon = null
	_expulsion = null
	_salida_cargador = null
	_corredera = null
	_agarre_corredera = null
	_punta = null
	for hijo in _mano.get_children():
		hijo.queue_free()
	if arma == null:
		return
	var modelo := arma.crear_modelo(PISTOLA_TAMANO if pistola else ARMA_TAMANO)
	if modelo:
		_mano.add_child(modelo)
		modelo.visible = false
		# Un cuadro despues: antes el hueso todavia no tiene su transformacion. Sin la
		# escala del hueso, y con la hoja hacia adelante del puño
		await get_tree().process_frame
		if not is_instance_valid(modelo):
			return
		var escala := _mano.global_transform.basis.get_scale()
		modelo.scale = Vector3.ONE / maxf(escala.x, 0.001)
		modelo.rotation_degrees = PISTOLA_GIRO if pistola else ARMA_GIRO
		if pistola:
			modelo.basis = modelo.basis * Basis(Vector3.RIGHT, deg_to_rad(PISTOLA_ROLL))
		if pistola:
			(modelo.get_child(0) as Node3D).position += PISTOLA_MANGO * PISTOLA_TAMANO
			_canon = Marker3D.new()
			_canon.position = (PISTOLA_MANGO + PISTOLA_CANON) * PISTOLA_TAMANO
			modelo.add_child(_canon)
			_expulsion = Marker3D.new()
			_expulsion.position = (PISTOLA_MANGO + PISTOLA_EXPULSION) * PISTOLA_TAMANO
			modelo.add_child(_expulsion)
			_salida_cargador = Marker3D.new()
			_salida_cargador.position = (PISTOLA_MANGO + PISTOLA_CARGADOR) * PISTOLA_TAMANO
			modelo.add_child(_salida_cargador)
			# La boca es -X del modelo: en el espacio del hueso, lo gira el modelo
			_canon_local = (modelo.basis * Vector3.LEFT).normalized()
			_cortar_corredera(modelo)
		else:
			(modelo.get_child(0) as Node3D).position.x -= ARMA_MANGO
			# El mango queda en el puno y la hoja hacia -X
			_punta = Marker3D.new()
			_punta.position = Vector3(-(ARMA_TAMANO * 0.5 + ARMA_MANGO), 0.0, 0.0)
			modelo.add_child(_punta)
		modelo.visible = true


func _sonar(nombre: String, volumen := 0.0) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.volume_db = volumen
	_voz.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensibilidad := mouse_sensitivity * (APUNTA_RATON if _apuntando else 1.0)
		camera_pivot.rotation.y -= event.relative.x * sensibilidad
		camera_pitch -= event.relative.y * sensibilidad * 100.0
		camera_pitch = clampf(camera_pitch, -60.0, 30.0)
		spring_arm.rotation_degrees.x = camera_pitch
	elif _aturdido > 0.0:
		# Aturdido solo puedes voltear la camara
		pass
	elif event.is_action_pressed("cambiar_arma") and is_physics_processing() and not sin_combate:
		_lanzador.soltar()
		_pistola.cambiar()
		_soltar_combo()
		_mostrar_arma()
	elif event.is_action_pressed("recargar") and is_physics_processing():
		if _pistola.activa:
			_pistola.recargar()
	elif _tecla_arma(event) >= 0 and is_physics_processing():
		cambiar_arma(_tecla_arma(event))
	elif event.is_action_pressed("rodar") and is_physics_processing():
		# Alt (teclado) es un modificador: rueda si ya traes una direccion apretada, si no espera
		# a que aprietes una (abajo). B del gamepad rueda de una vez, hacia el stick o para atras
		if event is InputEventJoypadButton or _teclas_mover().length_squared() > 0.01:
			_pedir_accion("rodar")
	elif _es_direccion(event) and Input.is_action_pressed("rodar") and is_physics_processing():
		# Alt sostenido: cada direccion que aprietes es una rodada para alla
		_pedir_accion("rodar")
	elif _doble_toque(event) and is_physics_processing():
		# La misma tecla de direccion dos veces seguidas: rodada para alla
		_pedir_accion("rodar")
	elif event.is_action_pressed("curarse") and is_physics_processing() and _rodada_t < 0.0:
		_curarse()
	elif event.is_action_released("attack") and _lanzador.activo:
		# La molotov cargada sale al soltar el clic
		_lanzador.soltar_clic()
	elif event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _lanzador.activo:
			if _curando <= 0.0 and _rodada_t < 0.0 and _aventando < 0.0:
				_lanzador.lanzar()
		elif _pistola.activa:
			# Viendo al personaje de frente la mira apunta hacia ti: no dispara
			if _curando <= 0.0 and _rodada_t < 0.0 and not mirando_atras():
				_pistola.disparar()
		else:
			# A puno limpio no hay carga ni giro, y en el aire no se pega (JJ)
			var especiales := _especiales()
			# La carga cuenta desde que aprietas, aunque el golpe espere en el buffer
			if golpe_cargado and especiales:
				_apretado = 0.0
			if is_on_floor() or especiales:
				_pedir_accion("golpe")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and is_physics_processing() and not get_tree().paused:
		# Con el raton suelto (Esc), un clic en la ventana lo vuelve a agarrar sin pegar
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# El cuerpo se mueve a 60 por segundo y la pantalla mas seguido: sin esto el personaje y la
# camara avanzan a saltitos aunque haya muchos FPS. Solo se suaviza lo que se ve (modelo y
# camara), entre las dos ultimas posiciones del cuerpo; la fisica no cambia.
func _process(_delta: float) -> void:
	var ahora := global_position
	# Lo movieron de golpe (reaparecer, salir de una tienda) o esta congelado: sin suavizar
	if not is_physics_processing() or _pos_ahora.distance_squared_to(ahora) > SALTO * SALTO:
		_pos_antes = ahora
		_pos_ahora = ahora
	var fraccion := Engine.get_physics_interpolation_fraction()
	var desfase := global_basis.inverse() * (_pos_antes.lerp(_pos_ahora, fraccion) - ahora)
	frijol.position = _frijol_base + desfase
	camera_pivot.position = _pivote_base + desfase + Vector3.UP * _alzar
	_camara_al_hombro()
	_sacudir()
	_posar()
	_regresar_patada(_delta)
	_gotear_sangre()
	_estela_golpe()


# Los brazos con la pistola (clips Pistol_* de Quaternius, character_animation.gd): sosteniendola,
# o apuntando a la mira al apuntar o recien disparado desde la cadera, a la altura de la mira
func _posar() -> void:
	if not figura.has_method("pistola"):
		return
	var centro := get_viewport().get_visible_rect().size / 2.0
	var blanco := _camara.project_ray_origin(centro) + _camara.project_ray_normal(centro) * MIRA_LEJOS
	var hacia := blanco - (frijol.global_position + Vector3.UP * PECHO)
	var inclinacion := rad_to_deg(atan2(hacia.y, Vector2(hacia.x, hacia.z).length()))
	var arriba := _apuntando or Time.get_ticks_msec() < _tiro_hasta
	figura.pistola(_pistola.activa and is_physics_processing(), arriba, inclinacion)
	# Las dos manos solo apuntando o recien disparado; recargando, rodando o tirado, suelta. En la
	# corredera de la recarga en seco la izquierda va a ella, sin enderezar el canon
	if figura.has_method("agarre"):
		var rack: Dictionary = _pistola.rack() if _pistola.activa else {}
		if not rack.is_empty():
			figura.agarre(true, blanco, _canon_local, 0.0)
			figura.corredera(_agarre_corredera, rack["peso"])
			corredera(rack["d"])
		else:
			figura.agarre(_pistola.activa and arriba and is_physics_processing()
				and not _pistola.recargando() and _rodada_t < 0.0, blanco, _canon_local)
			figura.corredera(null, 0.0)


# Pistola.gd en cada tiro: sube el arma a la mira un rato y la patea
func pose_tiro() -> void:
	_tiro_hasta = Time.get_ticks_msec() + int(ARRIBA_TRAS_TIRO * 1000.0)
	if figura.has_method("tiro"):
		figura.tiro()


# Pistola.gd al empezar a recargar
func pose_recarga() -> void:
	if figura.has_method("recarga"):
		figura.recarga()


# De donde sale el tiro: la boca de la pistola, o la mano
# Retroceso de la pistola: la camara sube `grados` (la mira apunta de veras mas arriba) y
# regresa sola en PATADA_VUELVE; solo regresa lo que subio, sin pelearse con el raton
func patear_mira(grados: float) -> void:
	camera_pitch = clampf(camera_pitch + grados, -60.0, 30.0)
	spring_arm.rotation_degrees.x = camera_pitch
	_patada += grados
	_patada_vel = _patada / PATADA_VUELVE


func _regresar_patada(delta: float) -> void:
	if _patada <= 0.0:
		return
	var vuelve := minf(_patada, _patada_vel * delta)
	_patada -= vuelve
	camera_pitch = clampf(camera_pitch - vuelve, -60.0, 30.0)
	spring_arm.rotation_degrees.x = camera_pitch


# Tras pegarle a un zombi, la punta del arma gotea sangre un rato (con la pistola, nada)
func _gotear_sangre() -> void:
	var gotea: bool = Time.get_ticks_msec() < _sangre_hasta and not (_pistola and _pistola.activa) and _mano != null
	if not gotea:
		if _sangre_arma:
			_sangre_arma.visible = false
		return
	if _sangre_arma == null:
		_sangre_arma = EfectosPixel.cuadro_bucle("sangre_arma", SANGRE_ESCALA)
		if _sangre_arma == null:
			return
		_sangre_arma.top_level = true
		add_child(_sangre_arma)
	var punta: Vector3 = _punta.global_position if _punta and is_instance_valid(_punta) and _punta.is_inside_tree() 		else _mano.global_position + _mano.global_basis.y.normalized() * ESTELA_PUNO
	_sangre_arma.global_position = punta
	_sangre_arma.visible = true


# 1-5 (arma_1..arma_5), aunque traigas Shift (corriendo) o Alt (rodar) apretados: con la coincidencia
# exacta, corriendo no cambiaba de arma (JJ). Solo en el safehouse Shift+1/2/3 son de las maquinitas
func _tecla_arma(event: InputEvent) -> int:
	if event is InputEventKey and event.shift_pressed and _en_safehouse():
		return -1
	for i in ARMAS_TECLAS:
		if event.is_action_pressed("arma_%d" % (i + 1)):
			return i
	return -1


func _en_safehouse() -> bool:
	var escena := get_tree().current_scene
	return escena != null and escena.scene_file_path.ends_with("safehouse.tscn")


# La casa propia (CasaPropia.gd) no es lugar de pelea: al entrar se guardan las armas y quedas
# sin ellas, sin rodar, sin curarte y sin que nada te lastime; al salir todo vuelve
func poner_sin_combate(valor: bool) -> void:
	if valor:
		cambiar_arma(0)
		_soltar_combo()
	sin_combate = valor
	_mostrar_arma()


# 0 = el arma de golpe (machete o puño), 1 = la pistola, 2 = lo que se avienta (Lanzador:
# sal, molotov); 3-4 aun no hay nada
func cambiar_arma(indice: int) -> void:
	if sin_combate:
		return
	if indice == 2:
		if _pistola.activa:
			_pistola.cambiar()
			_mostrar_arma()
		_soltar_combo()
		_lanzador.tomar()
		_mostrar_arma()
		return
	if indice > 2:
		return
	var traia := _lanzador.activo
	_lanzador.soltar()
	if (indice == 1) == _pistola.activa:
		if traia:
			_mostrar_arma()
		return
	_pistola.cambiar()
	_soltar_combo()
	_mostrar_arma()


# Cada tiro te recorre tantito para atras de a donde apuntas
func empujar_tiro(hacia: Vector3) -> void:
	hacia.y = 0.0
	if RETROCESO_TIRO <= 0.0 or hacia.length_squared() < 0.0001:
		return
	_retroceso = -hacia.normalized() * RETROCESO_TIRO
	_retroceso_freno = RETROCESO_TIRO * RETROCESO_TIRO_FRENO


# Parte la malla de la pistola en la corredera y lo demas (una vez por malla) y pone la
# corredera en su propio nodo, para que Pistola.rack la recorra
func _cortar_corredera(modelo: Node3D) -> void:
	var mallas := modelo.find_children("*", "MeshInstance3D", true, false)
	if mallas.is_empty():
		return
	var instancia := mallas[0] as MeshInstance3D
	var relativo := modelo.global_transform.affine_inverse() * instancia.global_transform
	if not _cortes.has(instancia.mesh):
		var arreglos := instancia.mesh.surface_get_arrays(0)
		var puntos: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arreglos[Mesh.ARRAY_INDEX] if arreglos[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(puntos.size()))
		var resto := PackedInt32Array()
		var pieza := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			var centro := (puntos[indices[t]] + puntos[indices[t + 1]] + puntos[indices[t + 2]]) / 3.0
			var p := relativo * centro / PISTOLA_TAMANO - PISTOLA_MANGO
			var es := p.y > CORREDERA_Y and p.x > CORREDERA_X.x and p.x < CORREDERA_X.y
			for k in 3:
				(pieza if es else resto).append(indices[t + k])
		var material := instancia.get_active_material(0)
		var partes := []
		for lista: PackedInt32Array in [resto, pieza]:
			var copia := arreglos.duplicate()
			copia[Mesh.ARRAY_INDEX] = lista
			var malla := ArrayMesh.new()
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, copia)
			malla.surface_set_material(0, material)
			partes.append(malla)
		_cortes[instancia.mesh] = partes
		print("Pistola: corredera de %d triangulos, lo demas %d" % [pieza.size() / 3, resto.size() / 3])
	var partes: Array = _cortes[instancia.mesh]
	instancia.mesh = partes[0]
	_corredera = Node3D.new()
	_corredera.name = "Corredera"
	modelo.add_child(_corredera)
	var pieza := MeshInstance3D.new()
	pieza.mesh = partes[1]
	pieza.transform = relativo
	pieza.cast_shadow = instancia.cast_shadow
	_corredera.add_child(pieza)
	_agarre_corredera = Marker3D.new()
	_agarre_corredera.position = (PISTOLA_MANGO + RACK_PUNTO) * PISTOLA_TAMANO
	_corredera.add_child(_agarre_corredera)


# La corredera `d` m hacia atras (Pistola.rack)
func corredera(d: float) -> void:
	if _corredera and is_instance_valid(_corredera):
		_corredera.position = Vector3(d, 0.0, 0.0)


# De donde sale el cargador vacio: la base de la cacha, con el giro del arma (sin su escala)
func cargador() -> Transform3D:
	if _salida_cargador and is_instance_valid(_salida_cargador) and _salida_cargador.is_inside_tree():
		var t := _salida_cargador.global_transform
		return Transform3D(t.basis.orthonormalized(), t.origin)
	return Transform3D(Basis(), canon())


# El cargador nuevo en la mano izquierda, de TOMA_EN a METE_EN de la recarga
func cargador_en_mano(si: bool) -> void:
	if _mano_izq == null:
		return
	if si and _cargador_mano == null:
		_cargador_mano = MeshInstance3D.new()
		_cargador_mano.mesh = Cargador.malla()
		_cargador_mano.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mano_izq.add_child(_cargador_mano)
	if _cargador_mano == null:
		return
	if si:
		# Sin la escala del hueso, como el arma en la otra mano
		var escala := _mano_izq.global_transform.basis.get_scale().x
		var inversa := 1.0 / maxf(escala, 0.001)
		_cargador_mano.transform = Transform3D(Basis.from_euler(CARGADOR_MANO_GIRO * PI / 180.0).scaled(Vector3.ONE * inversa), CARGADOR_MANO * inversa)
	_cargador_mano.visible = si


# De donde salta el casquillo
func expulsion() -> Transform3D:
	if _expulsion and is_instance_valid(_expulsion) and _expulsion.is_inside_tree():
		return _expulsion.global_transform
	return Transform3D(Basis(), canon())


func canon() -> Vector3:
	if _canon and is_instance_valid(_canon) and _canon.is_inside_tree():
		return _canon.global_position
	return _mano.global_position if _mano else global_position + Vector3.UP * 1.2


# Con la pistola la camara se va al hombro, y mas cerca al apuntar. En reloj real: la
# congelada del golpe no debe dejarla a medio camino
func _camara_al_hombro() -> void:
	var paso := clampf(CAMARA_CAMBIA * get_process_delta_time() / maxf(Engine.time_scale, 0.001), 0.0, 1.0)
	var pistola: bool = _pistola.activa
	_apuntando = pistola and is_physics_processing() and Input.is_action_pressed("apuntar")
	_hombro = lerpf(_hombro, (APUNTA_HOMBRO if _apuntando else HOMBRO) if pistola else 0.0, paso)
	_alzar = lerpf(_alzar, HOMBRO_ALTO if pistola else 0.0, paso)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, (APUNTA_BRAZO if _apuntando else HOMBRO_BRAZO) if pistola else _brazo_base, paso)
	_camara.fov = lerpf(_camara.fov, APUNTA_FOV if _apuntando else _fov_base, paso)


# Corrimiento de la camara, no de su nodo: el resorte ni se entera. En reloj real, porque el
# golpe tambien congela el juego
func _sacudir() -> void:
	if _sacude_hasta == 0:
		_camara.h_offset = _hombro
		_camara.v_offset = 0.0
		return
	var queda := float(_sacude_hasta - Time.get_ticks_msec()) / (SACUDE_DURA * 1000.0)
	if queda <= 0.0:
		_sacude_hasta = 0
		_camara.h_offset = _hombro
		_camara.v_offset = 0.0
		return
	_camara.h_offset = _hombro + randf_range(-1.0, 1.0) * _sacude_fuerza * queda
	_camara.v_offset = randf_range(-1.0, 1.0) * _sacude_fuerza * queda


func _physics_process(delta: float) -> void:
	_enfriar = maxf(_enfriar - delta, 0.0)
	_revisar_carga(delta)
	_revisar_estocada(delta)
	_revisar_rodada(delta)
	_revisar_bloqueo(delta)
	if _toca_pose_carga():
		_empezar_pose_carga()
	elif _golpe_guardado and ATAQUE_ENFRIAR - _enfriar >= _combo_desde():
		# Un brinco o rodada pedidos a media barrida le ganan al espadazo guardado (JJ): machacando,
		# el golpe guardado salia primero, volvia a tapar el brinco y este caducaba, asi que habia
		# que pausar para brincar. El espadazo guardado se vuelve el golpe en el aire (giro, o
		# clavado con Shift) para encadenar sin pausa
		if (_buffer == "brinco" or _buffer == "rodar") and _puede(_buffer):
			_golpe_guardado = false
			_golpe_tras_brinco = _buffer == "brinco" and giro_aereo and _especiales()
		else:
			_atacar()
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_curando = maxf(_curando - delta, 0.0)
	if _aturdido > 0.0:
		_aturdido -= delta
		if _aturdido <= 0.0 and figura.has_method("terminar_accion"):
			figura.terminar_accion()
	if _aventando >= 0.0:
		_seguir_aventada(delta)
	if _pega_en >= 0.0:
		_pega_en -= delta
		if _pega_en < 0.0:
			_golpear()
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	var lento := ATAQUE_LENTO_A_TIEMPO if pelea_a_tiempo else ATAQUE_LENTO
	var golpeando := (_enfriar > 0.0 and ATAQUE_ENFRIAR - _enfriar < lento) or _pose_carga
	# Girando en el aire sigues tu salto (y lo puedes dirigir); en el suelo te quedas en tu lugar
	if (_giro >= 0.0 and is_on_floor()) or _estocada_t >= 0.0 or _rodada_t >= 0.0 or _aventando >= 0.0 \
			or _aturdido > 0.0:
		input_direction = Vector2.ZERO

	var forward: Vector3 = -camera_pivot.global_transform.basis.z
	var right: Vector3 = camera_pivot.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction: Vector3 = right * input_direction.x + forward * -input_direction.y

	var is_moving: bool = direction.length_squared() > 0.01
	# Haciendo otra cosa a la vez, caminas (Walk, sin correr). Todo el enfriamiento del golpe, no
	# solo `golpeando`: con golpe a tiempo eso dura 0.24 s y machacando las piernas brincaban
	# de caminar a trotar en cada golpe
	var en_golpe: bool = (_enfriar > 0.0 and _giro < 0.0 and _estocada_t < 0.0) or _pose_carga
	# A punetazos, mientras siga el golpe: el gancho dura mas que el enfriamiento y las piernas se
	# iban a trotar con el brazo todavia pegando
	if _puno >= 0 and figura.has_method("tiempo_golpe") and figura.tiempo_golpe() >= 0.0:
		en_golpe = true
	# Los punetazos van como la pistola (JJ): pegando trotas y corres normal, viendo hacia donde vas
	# (solo las piernas siguen, el golpe va arriba); con clic derecho bloqueas, ves al frente y
	# caminas. Lo que sigue de "a medio golpe" (caminar, ver a la camara) es solo del machete
	var machetazo: bool = en_golpe and _puno < 0
	var machete_lento: bool = golpeando and _puno < 0
	# Shift a medio machetazo: trote normal hacia donde vayas, agachado (CARGA_INCLINA)
	var corre_pegando: bool = machetazo and is_moving and Input.is_action_pressed("sprint") \
			and not _pistola.activa
	# Con S (sola o en diagonal) a medio machetazo o apuntando retrocedes viendo al lado
	# contrario de hacia donde vas; sin hacer nada mas, S te voltea y corres hacia la camara (JJ)
	var retrocede: bool = is_moving and input_direction.y > 0.3 and (machetazo or _apuntando) \
			and not corre_pegando
	# La pistola en la mano sola no cambia nada: trotas y corres normal. Walk solo apuntando
	# (clic derecho), a medio machetazo o bloqueando (JJ)
	var camina: bool = (_apuntando or machetazo or _bloqueando or _curando > 0.0) and not corre_pegando
	var is_sprinting: bool = is_moving and Input.is_action_pressed("sprint") and not machete_lento and not camina \
			and not corre_pegando
	var move_speed: float = sprint_speed if is_sprinting else speed
	if _apuntando:
		move_speed = speed * APUNTA_VELOCIDAD
	elif machete_lento and not corre_pegando:
		move_speed = speed * GOLPE_VELOCIDAD
	if retrocede:
		move_speed = minf(move_speed, speed * RETROCEDE_VELOCIDAD)
	if camina:
		move_speed = minf(move_speed, CAMINA_PISTOLA if _apuntando or (_bloqueando and _punos()) else CAMINA_MAXIMO)
	if _bloqueando:
		move_speed = minf(move_speed, speed * BLOQUEO_VELOCIDAD)
	for factor: float in lastres.values():
		move_speed *= factor
	# Caminando, el barrido va solo arriba: las piernas siguen trotando
	if figura.has_method("golpe_caminando"):
		figura.golpe_caminando(is_moving and (en_golpe or _bloqueando or _curando > 0.0))
	var target_horizontal := Vector3.ZERO
	# Apuntando, o a medio machetazo, ve siempre hacia donde apunta la camara, aunque camine
	# para otro lado: el golpe sale hacia donde ves. Con la pistola sin apuntar, solo parado (para
	# que el tiro de cadera salga a la mira); trotando ves hacia donde vas
	var apunta: bool = (_apuntando or (_pistola.activa and not is_moving) or machete_lento \
			or (golpeando and not is_moving) or _bloqueando) \
			and _estocada_t < 0.0 \
			and not corre_pegando and _rodada_t < 0.0
	if figura.has_method("inclinar"):
		figura.inclinar(CARGA_INCLINA if corre_pegando else (BLOQUEO_AGACHA if _agachado > 0.0 else 0.0))
	# A punetazos embistiendo, los punos al frente y no al piso (JJ)
	if figura.has_method("enderezar_brazos"):
		figura.enderezar_brazos(_puno >= 0)
	if is_moving or apunta:
		var mira: Vector3 = forward if apunta else (-direction if retrocede else direction)
		var look_target: Vector3 = frijol.global_position + mira
		var target_transform: Transform3D = frijol.global_transform.looking_at(look_target, Vector3.UP)
		frijol.global_transform = frijol.global_transform.interpolate_with(
			target_transform,
			clampf(rotation_speed * delta, 0.0, 1.0)
		)
		var facing: Vector3 = -frijol.global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		if apunta or retrocede:
			facing = direction.normalized()
		target_horizontal = facing * move_speed if is_moving else Vector3.ZERO

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var braking: bool = not is_moving or horizontal.length() > target_horizontal.length() + 0.05
	if not braking and horizontal.length_squared() > 0.01 and target_horizontal.length_squared() > 0.01:
		braking = horizontal.normalized().dot(target_horizontal.normalized()) < 0.92
	if braking:
		velocity.x = target_horizontal.x
		velocity.z = target_horizontal.z
	else:
		velocity.x = move_toward(velocity.x, target_horizontal.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_horizontal.z, acceleration * delta)
	if _estocada_t >= 0.0 and not _estocada_quieta:
		var avance := _velocidad_estocada(delta)
		velocity.x = avance.x
		velocity.z = avance.z
	if _rodada_t >= 0.0:
		var antes := RODAR_AVANCE * smoothstep(RODAR_AVANZA.x, RODAR_AVANZA.y, _rodada_t - delta * RODAR_VELOCIDAD)
		var ahora := RODAR_AVANCE * smoothstep(RODAR_AVANZA.x, RODAR_AVANZA.y, _rodada_t)
		var rueda := _rodada_dir * ((ahora - antes) / maxf(delta, 0.0001))
		velocity.x = rueda.x
		velocity.z = rueda.z

	# Gravity is applied exactly once per frame; on the floor we snap to zero.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	# El clavado: baja con la misma curva que el desliz, asi va en linea recta al piso
	if _clavando:
		velocity.y = -_clavado_baja * (smoothstep(ESTOCADA_DESDE, ESTOCADA_HASTA, _estocada_t) \
				- smoothstep(ESTOCADA_DESDE, ESTOCADA_HASTA, _estocada_t - delta)) / maxf(delta, 0.0001)

	# Keyboard / gamepad camera rotation (mouse-look is handled above).
	var camera_input: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down",
		0.2
	)
	if camera_input.length() > 0.2:
		camera_pivot.rotation.y -= camera_input.x * camera_sensitivity * delta
		camera_pitch -= camera_input.y * camera_sensitivity * 50.0 * delta
	camera_pitch = clampf(camera_pitch, -60.0, 30.0)
	spring_arm.rotation_degrees.x = camera_pitch

	if Input.is_action_just_pressed("jump") and is_on_floor():
		var cercano := _nearby_interactable()
		if cercano != null:
			cercano.interact()
		else:
			_pedir_accion("brinco")
	_probar_buffer(delta)

	# El rebote va aparte: el frenado de arriba lo borraria
	velocity += _retroceso
	move_and_slide()
	velocity -= _retroceso
	_retroceso = _retroceso.move_toward(Vector3.ZERO, _retroceso_freno * delta)
	_pos_antes = _pos_ahora
	_pos_ahora = global_position

	if figura.has_method("update_animation"):
		# Las piernas van al reves si te mueves hacia la espalda del modelo (retroceder, o
		# caminar para atras con la pistola o a medio golpe)
		var plano := Vector3(velocity.x, 0.0, velocity.z)
		var espalda := frijol.global_transform.basis.z
		var al_reves := is_moving and plano.length_squared() > 0.25 \
				and plano.normalized().dot(Vector3(espalda.x, 0.0, espalda.z).normalized()) > 0.3
		figura.update_animation(is_moving, not is_on_floor(), is_sprinting, plano.length(), camina, al_reves)
	_mirar_atras()


# Mientras sostienes mirar_atras (boton de en medio del raton, R3) la camara se pone enfrente
# del personaje para verlo de frente; al soltar regresa. Solo se voltea el brazo de la camara:
# los controles siguen relativos a donde veias (CameraPivot)
func _mirar_atras() -> void:
	var atras := Input.is_action_pressed("mirar_atras") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var giro := PI if atras else 0.0
	if spring_arm.rotation.y != giro:
		spring_arm.rotation.y = giro


func mirando_atras() -> bool:
	return spring_arm.rotation.y != 0.0


# El NPC o el objeto para recoger (WorldItem) mas cercano que tenga al jugador en su area
func _nearby_interactable() -> Node:
	var closest: Node = null
	var closest_distance := INF
	for grupo: String in ["npc", "interactuable"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if not nodo.has_method("is_player_inside") or not nodo.is_player_inside():
				continue
			var distance := global_position.distance_squared_to(nodo.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest = nodo
	return closest
