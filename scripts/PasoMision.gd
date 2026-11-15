class_name PasoMision
extends Resource

# Un paso de una mision (MisionData.gd). Se escribe en el .tres de la mision, sin programar.
# TENER_OBJETOS: traer `objetos` en el inventario; `lugar` dice donde conseguirlos.
# ENTREGAR: volver con el que dio la mision; si hay `objetos`, se los queda.
# VISITAR: pasar por `cuantos` lugares (`lugar`), en `segundos` si no es 0.
# RECOGER: buscar la cosa `lugar` en un area y levantarla con Espacio: "perro", o
# "marca:<nombre>" (una marca "mision" de la colonia: ahi esta la cosa, con flecha; `objetos`[0]
# da su modelo y su nombre, o una pelota si no hay).
# ESCOLTAR: alguien (`acompanante`, un civil de Civiles.gd; vacio, uno al azar) sale de donde el
# que dio la mision y te sigue, mas lento que tu, hasta `lugar` ("casas", "giro:<giro>" o
# "marca:<nombre>"). Los zombis lo atacan; si cae, o si se acaba la hora con el en camino,
# la mision falla.
# DEFENDER: aguantar `segundos` cerca de `lugar` ("casas", "giro:<giro>" o "marca:<nombre>"; a
# 20 m, fuera de ahi el tiempo no corre) mientras llegan turbas de `cuantos` zombis cada
# `ola_cada` s (Zombis.aparecer_turba). Si `acompanante` no esta vacio, ese alguien se queda en
# el lugar (quien sube la torre, quien baja el agua): los zombis lo atraen y, si cae, falla. Si
# la hora se acaba antes o te desmayas, tambien.
# CAZAR: un zombi marcado (con un "!" rojo) ronda cerca de `lugar` ("casas", "giro:<giro>" o
# "marca:<nombre>"); los mapas marcan el area, no el punto. Al bajarlo se cumple el paso. Si lo
# matan al amanecer no cuenta, y si se aleja o se acaba la hora vuelve a salir.
# ENTRAR_A: llegar a la entrada de `lugar` (una flecha, como VISITAR con un solo punto). Hoy solo
# llega. Con `escena` entra a esa pelea de jefe (PasoJefe) y el paso se cumple al ganarla: `lugar`
# puede ser "entrada:<id>", una EntradaJefe fija del mapa (la flecha ya esta ahi; solo se apunta),
# o cualquiera de las otras formas (la mision pone su propia flecha).
# CAMIONETA: la camioneta del gremio (CamionetaReparto) sale de donde el que dio la mision y hace
# una ruta de hasta `cuantos` entregas a casas (`lugar`: "casas"), por las calles y a tu trote, sin
# esperarte: hay que seguirla toda la noche. En cada casa se para `descarga_s` segundos (el tinaco
# movil) y llegan turbas de `turba` zombis cada `ola_cada` s; andando tambien llegan, de
# `turba_andando` cada `ola_andando` s. La ruta se arma para acabar antes del amanecer. Con `lugar`
# "salida_colonia" (el chofer de Santa Mugre, se acepta de dia en la colonia): se corta la pantalla
# y apareces de noche afuera de una de las rejas, al azar, con la camioneta arrancando. Cada entrega paga `pesos_por_entrega`. Los zombis la atacan (lleva agua): la vida de la
# camioneta es `vida_acompanante`; si cae, o te amanece en la ruta, o te desmayas, la mision falla.
# LLEVAR_CARGA: lo de VISITAR (`lugar`, `cuantos` entregas) con la `carga` en brazos, y cada
# entrega paga `pesos_por_entrega`. Es de una hora: si se acaba con la carga encima (amanecer =
# los cuicos) o te desmayas, se pierde y la mision falla. Con `lugar` "punto:<origen>" la entrega es en
# ese negocio "punto" (el `origen` de su JSON); con `cuando` CUALQUIERA no hay hora que se acabe.

# `cuando`: a que hora se puede cumplir este paso. Fuera de su hora la mision espera (no falla
# y su tiempo no corre): una entrega de noche con un ENTREGAR de dia se acaba con el que te la
# dio a la mañana siguiente.

enum Tipo { TENER_OBJETOS, ENTREGAR, VISITAR, RECOGER, ESCOLTAR, LLEVAR_CARGA, DEFENDER, CAZAR, ENTRAR_A, CAMIONETA }
enum Cuando { DIA, NOCHE, CUALQUIERA }

@export var tipo: Tipo = Tipo.ENTREGAR
@export var cuando: Cuando = Cuando.DIA
# Lo que se lee en pantalla mientras dura este paso
@export var texto := ""
@export var objetos: Array[InventoryItemData] = []
# "giro:farmacia" la tienda mas cercana de ese giro, "casas" casas cerca, "perro" el perro.
# Los resuelve scripts/map/MisionesMundo.gd
@export var lugar := ""
@export var cuantos := 1
@export var segundos := 0.0
# Lo que trae en las manos durante este paso
@export var carga: InventoryItemData
# ESCOLTAR: quien te sigue, su vida (los zombis le pegan 3 por golpe) y que tan rapido camina
@export var acompanante := ""
@export var vida_acompanante := 60
# ENTRAR_A: la escena de jefe a la que se entra (vacio: solo llegar)
@export_file("*.tscn") var escena := ""
# DEFENDER y CAMIONETA: cada cuantos segundos llega otra turba
@export var ola_cada := 14.0
# CAMIONETA: cuantos zombis trae cada turba y cuanto dura la descarga en cada casa
@export var turba := 4
@export var descarga_s := 20.0
# CAMIONETA: las turbas que la alcanzan mientras va por la calle (0 = ninguna)
@export var ola_andando := 18.0
@export var turba_andando := 3
# LLEVAR_CARGA: lo que paga cada entrega, aparte de los `pesos` de la mision
@export var pesos_por_entrega := 0
# LLEVAR_CARGA: la carga se puede dejar en el piso para pelear (el clic de ataque la suelta y Espacio la
# levanta); sin ella en brazos el punto de entrega no cuenta. La caja de la mafia (M7)
@export var soltable := false
# LLEVAR_CARGA de noche con carga ilegal (el agua sin Serenol del reparto, S3): si te amanece en camino
# no falla, sigue de dia (Misiones.sigue_de_dia), y los cuicos te disparan si te ven con ella
@export var ilegal := false
