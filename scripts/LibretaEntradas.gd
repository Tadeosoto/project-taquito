class_name LibretaEntradas
extends RefCounted
# Lo que dice la libreta del Nocturno (Libreta.gd, LibretaUI.gd): una entrada por bicho, con sus
# cuatro apartados escritos por el. Cada apartado se ve segun el nivel de la entrada en la
# Libreta: 1 visto (Que es), 2 peleado (Por que es asi), 3 matado (Como matarlo y los datos).
# Lo que no esta decidido en el canon (docs/revision-historia.md 4.10, 4.12, 4.13) va como
# corazonada suya, con un "creo" o un "dicen". Los numeros de "Datos" se leen de los scripts al
# abrirla, para que nunca digan otra cosa que el juego.

const NIVEL_VISTO := 1
const NIVEL_PELEADO := 2
const NIVEL_MATADO := 3

# id, titulo, apodo (lo que le dice la calle), dibujo, y los apartados.
# `pista` es lo que se lee en un apartado que todavia no sabes.
const ENTRADAS := [
	{
		"id": "zombi",
		"titulo": "Zombi",
		"apodo": "\"los de la madrugada\"",
		"que": "Uno de cada diez que toman el agua de GelA se muere en la madrugada y se levanta. No habla, no se cansa, no se acuerda de nadie. De día se mete a las bodegas y a los drenajes; de noche sale a caminar en bola.",
		"por_que": "Es el Serenol. A nueve los deja mansitos y agradecidos; al décimo lo mata y lo levanta. Tiene dos hambres: carne, y agua limpia que no le sirve. Por eso va por ti (caminas y cargas agua) y por los tinacos. Ojo: cada uno era alguien. El de la gorra era el del gas.",
		"como": "Deambula hasta que te ve (25 m, de frente), te oye (12 m) o oye un balazo (40 m); luego corre. Cuando gruñe, va a pegar: hazte a un lado o tapa con clic derecho. Tres machetazos lo tumban; a la cabeza, la pistola pega el triple. Una puerta cerrada lo para: empuja, no abre.",
		"pista_por_que": "Pelea con uno para entender qué le pasó.",
		"pista_como": "Mata a uno y anoto cómo.",
	},
	{
		"id": "cazador",
		"titulo": "Cazador",
		"apodo": "\"los que ya te olieron\"",
		"que": "Zombi con prisa. Llegan en turba, ya alertas, y no se distraen con nada: van derecho a ti. Traen una marca roja encima, como si algo los jalara.",
		"por_que": "Creo que son los recién levantados, todavía con la sed fresca. La noche les pega distinto: mientras más noches pasan, más salen así. Nadie sabe por qué, y GelA no lo va a decir.",
		"como": "Corren más que los otros, así que no te les escapes trotando: o corres de veras o te paras a pelear con la espalda contra algo. En bola, la pistola mientras llegan y el machete cuando ya están encima. El ataque cargado (deja apretado y suelta) abre la turba.",
		"pista_por_que": "Pelea con una turba.",
		"pista_como": "Mata a un cazador.",
	},
	{
		"id": "saltabardas",
		"titulo": "Saltabardas",
		"apodo": "\"el chavo de la esquina\"",
		"que": "Anda agachado, a cuatro patas cuando corre, con una sudadera vino y la capucha hasta los ojos. Se queda quieto y olfatea; cuando te ve de cerca, grita. Después del grito se te echa encima de un brinco y te tumba.",
		"por_que": "Era de los chavos de la esquina, de los que se brincaban las bardas por un mandado o para correrle a la patrulla. Creo que el Serenol le dejó eso: el cuerpo se acuerda de brincar. Todavía trae el rosario de su jefa.",
		"como": "El grito es el aviso: tienes un segundo. Rueda cuando se enrosca y se te pasa por encima, o cúbrete de frente (clic derecho) y rebota. Pégale en el aire y cae de espaldas. Si te agarra, machaca golpe o brinco hasta quitártelo. La pistola también le entra.",
		"pista_por_que": "Deja que se te eche encima, o pégale.",
		"pista_como": "Mata a uno.",
	},
	{
		"id": "infectado",
		"titulo": "Zombi montado",
		"apodo": "\"el del jinete\"",
		"que": "Un zombi con una lombriz del cárcamo pegada en el lomo, como jinete. Corre más que uno normal y te caza aunque no te haya visto.",
		"por_que": "No lo tengo claro. Las crías de la Madre buscan cuerpos calientes y, si no estás tú, se suben al primer muerto que pasa. Parece que lo manejan. Si es así, el cárcamo está más cerca de las calles de lo que pensamos.",
		"como": "Mátalo como a cualquier zombi: cuando cae, la lombriz se suelta y queda sola, chiquita, en el piso. Pisa o corta la lombriz antes de que se busque otro.",
		"pista_por_que": "Pelea con un zombi montado.",
		"pista_como": "Tumba a uno.",
	},
	{
		"id": "gordo",
		"titulo": "El gordo",
		"apodo": "\"el hinchado\"",
		"que": "Un zombi enorme, hinchado de agua. Lento para arrancar, pero pesa. Se oye antes de que se vea: chapotea por dentro.",
		"por_que": "Dicen que es uno que se murió cerca del agua buena (una cisterna, una purificadora) y no paró de tomar. El cuerpo ya no la retiene, pero él sigue bebiendo. Es lo que el agua de GelA le hace a uno con mucha sed.",
		"como": "Todavía no sé bien qué hace distinto; lo estoy anotando. Por lo pronto: no lo dejes llegar, guarda distancia y pégale de lejos.",
		"pista_por_que": "Pelea con un gordo.",
		"pista_como": "Mata a un gordo.",
	},
	{
		"id": "jefe",
		"titulo": "El de la tercera noche",
		"apodo": "\"el grandote\"",
		"que": "La tercera noche, cuando ya no amanece, sale uno más grande que todos. Lento, pero cada golpe tumba. Retumba al caminar y cuando llega, azota el piso.",
		"por_que": "Creo que era alguien de aquí: le vi una credencial colgando. Si es quien creo, no es un monstruo de película: es un vecino al que el agua le hizo esto. Por eso pesa tanto pelearle.",
		"como": "Es duro: aguanta cientos de golpes. No te quedes enfrente: rueda cuando levante el brazo, pégale por un lado y aléjate. La pistola mientras se acerca; el machete en sus ventanas. Matarlo trae el amanecer.",
		"pista_por_que": "Pelea con él.",
		"pista_como": "Aguanta la tercera noche.",
	},
	{
		"id": "crias",
		"titulo": "Crías del cárcamo",
		"apodo": "\"las lombrices\"",
		"que": "Lombrices del grueso de un brazo, a cientos. Trepan muros, rodean, se paran antes de aventarse y, si te alcanzan, se te pegan a chupar. Se juntan en bola para rodar hacia ti.",
		"por_que": "Nacieron en el lodo de Serenol que se asienta en los cárcamos de GelA, donde nadie limpia porque limpiar sería admitirlo. La vida de abajo también toma el agua blanca. Su madre vive en el fondo.",
		"como": "Pégales a la cabeza: así se mueren enteras. Partidas por la mitad, cada mitad sigue y vuelve a crecer; cortar a lo loco las multiplica. Sal y fuego las matan sin partirlas. Rodar te quita las pegadas; curarte (Q) las quema. A la bola: cuatro machetazos o un tajo cargado y quedan atontadas. Si te subes alto, buscan la rampa.",
		"pista_por_que": "Pelea con ellas.",
		"pista_como": "Mata una lombriz entera.",
	},
	{
		"id": "madre",
		"titulo": "La Madre del Cárcamo",
		"apodo": "\"la que vive en el lodo\"",
		"que": "La lombriz más vieja: del grueso de un tambo, con sacos de Serenol en el lomo que brillan en lo oscuro. Vive en el charco del fondo del cárcamo y sale a morder, a barrer y a escupir crías y lodo.",
		"por_que": "Es lo que el agua de GelA hizo con lo que vive en el fondo de sus pozos. Sus sacos son Serenol puro, concentrado. Si los revientas, se cae y sus crías se quedan sin madre. Nadie de GelA ha bajado a verla; o nadie que haya salido.",
		"como": "Solo le duelen los sacos, y solo cuando está afuera: tirada, barriendo o asomada. Antes de morder se oye un retumbo y sale tierra bajo tus pies: muévete. Cada saco cambia de turquesa a amarillo a rojo; cuando revienta uno, se desploma un ratito: ve por el que brilla más. Cada dos sacos se pone peor. Ten molotovs y sal a la mano.",
		"pista_por_que": "Pégale a un saco.",
		"pista_como": "Mátala.",
	},
	{
		"id": "remedios",
		"titulo": "Remedios",
		"apodo": "\"lo que sirve\"",
		"que": "Lo que he visto que funciona contra lo de abajo. La sal de grano (la tiendita), las molotovs (caguama con alcohol de la licorería) y los tambos prendidos. Se avientan con la tecla 3.",
		"por_que": "La abuela lo sabía: \"a las babosas, sal\". La sal les quita el agua del cuerpo; el fuego las seca sin partirlas. Los tambos no los quieren cerca. Nada de esto le sirve a un zombi: es para las del cárcamo.",
		"como": "Sal: un círculo que se come cabezas y no las deja pasar; si te cae encima, quema las que traes pegadas. Molotov: fuego que las encoge por la cola y le quema los sacos a la Madre, pero también te quema a ti. Patea un tambo y riega fuego. Tu estela de fuego, si la tienes, las quema en vez de partirlas.",
		"pista_por_que": "Usa uno contra ellas.",
		"pista_como": "Mata con fuego o con sal.",
	},
]


static func entrada(id: String) -> Dictionary:
	for e in ENTRADAS:
		if e.id == id:
			return e
	return {}


static func dibujo(id: String, conocida: bool) -> Texture2D:
	var ruta := "res://textures/libreta/%s%s.png" % ["" if conocida else "silueta/", id]
	return load(ruta) if ResourceLoader.exists(ruta) else null


# Los numeros, de los scripts de verdad (al abrir la pagina). Con load() y no por class_name:
# el autoload Libreta carga este archivo al arrancar y no debe arrastrar a Zombie y compania
static func datos(id: String) -> String:
	var _Z = load("res://scripts/map/Zombie.gd")
	var _SL = load("res://scripts/lombrices/SolverLombrices.gd")
	var _EL = load("res://scripts/lombrices/EnjambreLombrices.gd")
	var _MC = load("res://scripts/lombrices/MadreCarcamo.gd")
	var _AR = load("res://scripts/lombrices/Arrojadizo.gd")
	var _SB = load("res://scripts/map/Saltabardas.gd")
	match id:
		"zombi":
			return "Vida %d · pega %d · corre %.0f-%.0f m/s · te ve a %.0f m, te oye a %.0f m" % [
				_Z.VIDA, _Z.DANO, _Z.VELOCIDAD.x, _Z.VELOCIDAD.y, _Z.VE_DESDE, _Z.OYE_DESDE]
		"cazador":
			return "Vida %d · pega %d · corre x%.1f que uno normal" % [_Z.VIDA, _Z.DANO, _Z.CAZADOR_VELOCIDAD]
		"saltabardas":
			return "Vida %d · brinca desde %.0f m · el brinco pega %d, cada arañazo %d · %d apretones para quitártelo" % [
				_SB.VIDA, _SB.SALTA_DESDE, _SB.DANO_SALTO, _SB.DANO_GARRA, roundi(_SB.ZAFARSE)]
		"infectado":
			return "Vida %d · pega %d · corre x%.1f · siempre te caza" % [_Z.VIDA, _Z.DANO, _Z.INFECTADO_VELOCIDAD]
		"gordo":
			return "Vida %d · pega %d (todavía lo estoy midiendo)" % [_Z.GORDO_VIDA, _Z.GORDO_DANO]
		"jefe":
			return "Vida %d · pega %d · camina a %.0f m/s" % [_Z.JEFE_VIDA, _Z.JEFE_DANO, _Z.JEFE_VELOCIDAD]
		"crias":
			return "%d x %d puntos · se arrastran a %.0f m/s · muerden %d · la bola aguanta %.0f" % [
				80, 12, _SL.VELOCIDAD, _EL.DANO_SALTO, _EL.BOLA_VIDA]
		"madre":
			return "%d sacos de %.0f · muerde %d, choca %d · la bala le hace %.0f al saco" % [
				_MC.SACOS, _MC.SACO_VIDA, _MC.DANO_MORDIDA, _MC.DANO_CHOQUE, _MC.DANO_BALA]
		"remedios":
			return "Sal: %.1f m por %.0f s · molotov: %.1f m por %.0f s" % [
				_AR.SAL_RADIO, _AR.SAL_DURA, _AR.FUEGO_RADIO, _AR.FUEGO_DURA]
	return ""
