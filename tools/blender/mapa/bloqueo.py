# Siembra el bloqueo gris de una colonia en su .json, a partir de lo real (referencia.datos_osm):
#   - las calles de OSM recortadas al recorte (piezas "calle")
#   - los parques y plazas de OSM (piezas "suelo")
#   - las huellas de Google Open Buildings como edificios grises de 1 a 3 pisos ("edificio"),
#     menos las que caen sobre una calle, en un parque o plaza, o en una "reserva" del .json
#   - la barda alrededor del recorte y un tapon donde cada calle sale de el ("bordes" del .json)
# Todo lo que pone lleva "auto": true; al correr otra vez se borra y se rehace eso solo, y lo
# puesto a mano (los lugares de la ficha) se queda.
#
#   COLONIA = "santa_mugre"; exec(open(r"...\tools\blender\mapa\bloqueo.py", encoding="utf-8").read())
# Despues colonia.py para verlo y exportar.py para llevarlo a Godot.
#
# Lo que lee del .json, ademas del recorte:
#   "reservas": [{"nombre", "puntos": [[x, z]...]}]   areas sin edificios reales (los lugares)
#   "bordes": {"norte"|"sur"|"oriente"|"poniente": "gela"|"barda"|"derrumbe"|"camion"|"fieles"}
#   ("fieles": un altar de calle de la Virgen, piezas.nicho_virgen; Santa Mugre es fortaleza)
#            el tapon de las calles que salen por ese lado (norte = z chica)

import os
import math

_r = {"__name__": "referencia", "SOLO_FUNCIONES": True}
exec(open(os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "mapa", "referencia.py"), encoding="utf-8").read(), _r)
globals().update({k: v for k, v in _r.items() if not k.startswith("__") and k != "SOLO_FUNCIONES"})

# Calles de un sentido de las avenidas: dos arroyos juntos con camellon (OSM les da el ancho
# entero a cada uno)
ANCHO_SENTIDO = {"tertiary": 7.0, "secondary": 8.0, "primary": 9.0}
BANQUETA_TIPO = {"living_street": 1.0, "service": 0.0}
SIN_DIBUJAR = {"footway", "path", "steps", "cycleway"}
HUELLA_MIN = 6.0           # m2: menos que esto es un tinaco o un tejaban
# Colores de las casas (kit.PALETA), repetidos para que salgan mas: los de Guadalajara
COLORES = ["terracota", "mostaza", "turquesa", "rosa", "lima", "azul", "crema", "crema", "blanco",
           "naranja", "morado", "verde", "gris", "terracota", "mostaza", "rosa"]
# Desgaste de las casas (Santa Mugre: indice 0.55-0.70, docs/lore.md)
DESGASTE = (0.35, 0.8)
BARDA_ALTO = 2.6           # la barda de block de antes: hoy es la base de la muralla
MURALLA_TROZO = 30.0       # m: largo maximo de cada objeto de muralla
MURALLA_ALTO = 4.5         # hasta donde la subieron los fieles (piezas.muralla y el porton, piezas.reja)
# De que lado queda adentro en cada muralla (+Z o -Z de la pieza, que corre en x)
MURALLA_DENTRO = {"norte": 1, "sur": -1, "poniente": 1, "oriente": -1}
BARDA_GRUESO = 0.3
BARDA_ADENTRO = 0.4        # m del borde del recorte
TAPON = {"gela": ((0.9, 0.45, 0.1), 2.2), "barda": ((0.62, 0.6, 0.56), 2.6), "fieles": ((0.6, 0.6, 0.56), 3.2),
         "derrumbe": ((0.45, 0.36, 0.28), 2.8), "camion": ((0.75, 0.75, 0.72), 3.2)}


def _dentro_poligono(x, z, poligono):
    c = False
    for (x1, z1), (x2, z2) in zip(poligono, poligono[-1:] + poligono[:-1]):
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


def _cruzan(p1, p2, q1, q2):
    def lado(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return lado(p1, p2, q1) * lado(p1, p2, q2) < 0 and lado(q1, q2, p1) * lado(q1, q2, p2) < 0


def _se_enciman(a, b):
    """Dos poligonos se enciman: un vertice adentro del otro o dos lados que se cruzan (un
    callejon largo y angosto atraviesa una huella grande sin tener vertices adentro)."""
    if any(_dentro_poligono(x, z, b) for x, z in a) or any(_dentro_poligono(x, z, a) for x, z in b):
        return True
    return any(_cruzan(a[i], a[(i + 1) % len(a)], b[j], b[(j + 1) % len(b)]) for i in range(len(a)) for j in range(len(b)))


def _distancia_segmento(px, pz, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / (dx * dx + dz * dz or 1.0)))
    return math.hypot(px - a[0] - t * dx, pz - a[1] - t * dz)


def _recortar(puntos, recorte):
    """Tramos de la linea dentro del rectangulo (Liang-Barsky por segmento)."""
    x1, z1, x2, z2 = recorte
    tramos, actual = [], []
    for a, b in zip(puntos, puntos[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        t0, t1, bien = 0.0, 1.0, True
        for p, q in ((-dx, a[0] - x1), (dx, x2 - a[0]), (-dz, a[1] - z1), (dz, z2 - a[1])):
            if p == 0:
                bien = bien and q >= 0
            else:
                t = q / p
                if p < 0:
                    t0 = max(t0, t)
                else:
                    t1 = min(t1, t)
        if not bien or t0 > t1:
            if len(actual) > 1:
                tramos.append(actual)
            actual = []
            continue
        ini = (a[0] + t0 * dx, a[1] + t0 * dz)
        fin = (a[0] + t1 * dx, a[1] + t1 * dz)
        if not actual:
            actual = [ini]
        actual.append(fin)
        if t1 < 1.0:
            tramos.append(actual)
            actual = []
    if len(actual) > 1:
        tramos.append(actual)
    return tramos


def _centro(puntos):
    return sum(p[0] for p in puntos) / len(puntos), sum(p[1] for p in puntos) / len(puntos)


def _area(puntos):
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(puntos, puntos[1:] + puntos[:1]))) / 2


def _relativos(puntos, cx, cz):
    return [[round(x - cx, 2), round(z - cz, 2)] for x, z in puntos]


def _frente(huella, calles):
    """El lado de la huella (del punto i al i+1) cuyo medio queda mas cerca de una calle."""
    mejor, mejor_d = 0, 1e9
    for i in range(len(huella)):
        a, b = huella[i], huella[(i + 1) % len(huella)]
        if math.hypot(b[0] - a[0], b[1] - a[1]) < 2.0:
            continue
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        d = min((_distancia_segmento(mx, mz, p, q) - medio for tramo, medio in calles for p, q in zip(tramo, tramo[1:])), default=1e9)
        if d < mejor_d:
            mejor, mejor_d = i, d
    return mejor


def _casa(nombre, huella, frente, k):
    cx, cz = _centro(huella)
    dado = int(abs(cx * 7.13 + cz * 3.71) * 10) % 100
    pisos = 1 if dado < 50 else 2 if dado < 92 else 3
    return {"nombre": nombre, "tipo": "casa", "auto": True, "x": round(cx, 2), "z": round(cz, 2),
            "puntos": _relativos(huella, cx, cz), "pisos": pisos, "frente": frente,
            "color": COLORES[(dado * 7 + k) % len(COLORES)],
            "desgaste": round(DESGASTE[0] + (DESGASTE[1] - DESGASTE[0]) * ((dado * 13) % 100) / 100, 2)}


# Postes de luz por las banquetas ("postes" del .json, con el esquema de
# resources/map/alumbrado_mapa.json: los arma MapAlumbrado en Godot, con su luz de noche, sus
# fallas segun el deterioro y los tambos): uno cada POSTE_CADA m en cada calle, turnando el lado,
# junto a la guarnicion y con el brazo (+Z local) hacia el arroyo. Los mismos de prepare_osm.py.
POSTE = (8.0, 1.5)
POSTE_AVENIDA = (10.0, 2.5)
POSTE_CADA = 26.0
POSTE_GUARNICION = 0.4      # m de la guarnicion hacia adentro de la banqueta


def _postes(calles_osm_dibujadas, todas):
    postes = []
    for ic, (tramo, medio, ancho, avenida) in enumerate(calles_osm_dibujadas):
        recorrido = 0.0
        lado = 1 if ic % 2 else -1
        for p, q in zip(tramo, tramo[1:]):
            dx, dz = q[0] - p[0], q[1] - p[1]
            largo = math.hypot(dx, dz)
            if largo < 1.0:
                continue
            ux, uz = dx / largo, dz / largo
            s = (POSTE_CADA / 2 - recorrido) % POSTE_CADA
            while s < largo:
                nx, nz = -uz * lado, ux * lado
                d = ancho / 2 + POSTE_GUARNICION
                x, z = p[0] + ux * s + nx * d, p[1] + uz * s + nz * d
                # No en medio de un cruce (sobre el arroyo de otra calle)
                if not any(_distancia_segmento(x, z, a, b) < m2 + 0.3 for tr, m2 in todas if tr is not tramo for a, b in zip(tr, tr[1:])):
                    alto, brazo = POSTE_AVENIDA if avenida else POSTE
                    semilla = int(abs(x * 13.7 + z * 7.3)) % 100000
                    postes.append({"x": round(x, 2), "z": round(z, 2), "rotacion_y": round(math.atan2(-nx, -nz), 4),
                                   "alto": alto, "brazo": brazo, "doble": False, "avenida": avenida, "semilla": semilla})
                lado = -lado
                s += POSTE_CADA
            recorrido = (recorrido + largo) % POSTE_CADA
    return postes


# Negocios ("tiendas" del .json, a mano: giro, tipo, nombre y un punto `cerca`): cada uno se queda
# con la casa mas cercana a ese punto (su frente), que lleva cortina (tienda), y de ahi salen su
# puerta (marca "puerta", con "auto") y su entrada en "negocios" (el esquema de MapPuntos, para el
# minimapa, la gente, las misiones y Partida). El punto es una casa en obra negra, sin cortina.
PUERTA_AFUERA = 0.8         # m de la fachada a la flecha
TIRA = 2.0                  # m: las reservas mas angostas (pasillos) se revisan lado por lado
PUESTO_LIBRE = 2.5          # m alrededor de una puerta sin puestos del tianguis
# Un local de MapPuntos (scripts/map/MapPuntos.gd, LOCAL_MIN) no baja de este frente y fondo (m): el
# negocio se queda con la casa mas cercana a su punto que los tenga, dentro de LOCAL_RADIO m
LOCAL_MIN = (4.5, 6.0)
LOCAL_MAX = (14.0, 16.0)    # y no mas grande que esto (un mini super no es un mercado)
LOCAL_RADIO = 25.0


def _cabe_local(casa):
    a, b, _c, _n, fondo = frente_de(casa)
    ancho = math.hypot(b[0] - a[0], b[1] - a[1])
    return LOCAL_MIN[0] <= ancho <= LOCAL_MAX[0] and LOCAL_MIN[1] <= fondo <= LOCAL_MAX[1]


def _da_a_calle(casa, casas, calles):
    """El frente de la casa da a una calle de verdad (no a un callejon ni a otra casa): a 2 m de la
    puerta, el punto queda a menos de 3.5 m de la banqueta de una calle y no dentro de una casa."""
    a, b, _c, (nx, nz), _f = frente_de(casa)
    px, pz = (a[0] + b[0]) / 2 + nx * (PUERTA_AFUERA + 2.0), (a[1] + b[1]) / 2 + nz * (PUERTA_AFUERA + 2.0)
    if any(otra is not casa and _dentro_poligono(px, pz, _huella_mundo(otra)) for otra in casas):
        return False
    return any(_distancia_segmento(px, pz, p, q) <= medio + 3.5 for tramo, medio in calles for p, q in zip(tramo, tramo[1:]))


def _huella_mundo(casa):
    return [(casa["x"] + x, casa["z"] + z) for x, z in casa["puntos"]]


def _tiendas(tiendas, casas, usadas=None, calles=None):
    marcas, negocios = [], []
    usadas = set() if usadas is None else usadas
    for i, t in enumerate(tiendas):
        mejor, mejor_d = None, 1e9
        cabe, cabe_d = None, LOCAL_RADIO
        for casa in casas:
            if id(casa) in usadas:
                continue
            a, b, _c, _n, _f = frente_de(casa)
            d = math.hypot((a[0] + b[0]) / 2 - t["cerca"][0], (a[1] + b[1]) / 2 - t["cerca"][1])
            if d < mejor_d:
                mejor, mejor_d = casa, d
            if d < cabe_d and t["tipo"] != "punto" and _cabe_local(casa) and (calles is None or _da_a_calle(casa, casas, calles)):
                cabe, cabe_d = casa, d
        if cabe is not None:
            mejor = cabe
        elif mejor is not None and t["tipo"] != "punto":
            print("negocio %s: ninguna casa libre a %d m alcanza %s m; se queda la mas cercana" % (t["nombre"], LOCAL_RADIO, LOCAL_MIN))
        if mejor is None:
            continue
        usadas.add(id(mejor))
        a, b, (cx, cz), (nx, nz), fondo = frente_de(mejor)
        punto = t["tipo"] == "punto"
        mejor["tienda"] = not punto
        mejor["local"] = not punto   # su fachada la pone MapPuntos (colonia.py salta la casa)
        if punto:
            mejor["desgaste"], mejor["pisos"] = 1.0, 1
        giro = math.atan2(nx, nz)
        mx, mz = (a[0] + b[0]) / 2 + nx * PUERTA_AFUERA, (a[1] + b[1]) / 2 + nz * PUERTA_AFUERA
        marcas.append({"nombre": "Puerta_%s_%d" % (t["giro"], i), "tipo": "puerta", "auto": True, "giro": t["giro"],
                       "texto": t["nombre"], "x": round(mx, 2), "z": round(mz, 2), "rot": round(giro, 4)})
        if mejor.get("local"):
            marcas[-1]["local"] = True   # la flecha y el letrero los pone MapPuntos, no Colonia.gd
        negocios.append({"tipo": t["tipo"], "giro": t["giro"], "nombre": t["nombre"], "x": round(cx, 2), "z": round(cz, 2),
                         "rotacion_y": round(giro, 4), "ancho": round(math.hypot(b[0] - a[0], b[1] - a[1]), 2),
                         "fondo": round(fondo, 2), "pisos": mejor.get("pisos", 1), "interactivo": True,
                         "aire_libre": False, "origen": t["nombre"]})
        if mejor.get("local"):
            negocios[-1]["ajustado"] = True   # MapPuntos: la huella tal cual y las alturas de las casas
        elif punto:
            negocios[-1]["sin_flecha"] = True   # su casa y su flecha son de Blender (Colonia.gd)
    return marcas, negocios


# Casas de los vecinos ("vecinos" del .json: nombre, escena, texto, un punto `cerca` y si abren
# siempre, de dia o de noche): como los negocios, cada una se queda con la casa mas cercana que no
# sea negocio y de ahi sale su marca "casa_vecino" (Colonia.gd la entra con CasaPropia).
def _vecinos(vecinos, casas, usadas):
    marcas = []
    for i, v in enumerate(vecinos):
        mejor, mejor_d = None, 1e9
        for casa in casas:
            if id(casa) in usadas:
                continue
            a, b, _c, _n, _f = frente_de(casa)
            d = math.hypot((a[0] + b[0]) / 2 - v["cerca"][0], (a[1] + b[1]) / 2 - v["cerca"][1])
            if d < mejor_d:
                mejor, mejor_d = casa, d
        if mejor is None:
            continue
        usadas.add(id(mejor))
        a, b, _c, (nx, nz), _f = frente_de(mejor)
        mx, mz = (a[0] + b[0]) / 2 + nx * PUERTA_AFUERA, (a[1] + b[1]) / 2 + nz * PUERTA_AFUERA
        marca = {"nombre": "Casa_" + v["nombre"], "tipo": "casa_vecino", "auto": True, "escena": v["escena"],
                 "texto": v["texto"], "abierto": v.get("abierto", "siempre"),
                 "x": round(mx, 2), "z": round(mz, 2), "rot": round(math.atan2(nx, nz), 4)}
        if "cerrado" in v:
            marca["cerrado"] = v["cerrado"]
        marcas.append(marca)
    return marcas


# Relleno de las calles: una fila corrida de casas angostas en cada lado de cada calle, donde no
# hay huella real (las de Google dejan huecos: las calles mexicanas son una fachada tras otra)
LOTE_FRENTE = (6.0, 9.0)       # m
LOTE_FONDO = (10.0, 14.0)
# Si no cabe, se prueba con menos fondo (4 m: las fachadas de la avenida contra la barda del
# recorte) y con un frente angosto (los huecos entre casas reales)
LOTE_FONDOS_MENOS = (7.0, 4.0)
LOTE_ANGOSTO = 4.5
BALDIO_CADA = 9                # uno de cada tantos lotes se queda baldio, con su barda de lamina
ESQUINA = 2.0                  # m sin lotes en cada punta de un tramo (las esquinas)


def _encima(rect, poligonos):
    """El rectangulo se encima a algun poligono: muestras del rectangulo dentro del poligono o
    vertices del poligono dentro del rectangulo."""
    a, b, c, d = rect
    muestras = []
    for u in (0.1, 0.5, 0.9):
        for v in (0.1, 0.5, 0.9):
            muestras.append((a[0] + (b[0] - a[0]) * u + (d[0] - a[0]) * v, a[1] + (b[1] - a[1]) * u + (d[1] - a[1]) * v))
    for pol in poligonos:
        xs, zs = [p[0] for p in pol], [p[1] for p in pol]
        rx, rz = [p[0] for p in rect], [p[1] for p in rect]
        if max(xs) < min(rx) or min(xs) > max(rx) or max(zs) < min(rz) or min(zs) > max(rz):
            continue
        if any(_dentro_poligono(x, z, pol) for x, z in muestras) or any(_dentro_poligono(x, z, rect) for x, z in pol):
            return True
        # Una tira angosta (un pasillo de menos de TIRA m) puede cruzar entre las muestras sin
        # tener vertices adentro. Solo para esas: con todas, el relleno perdia 40 casas
        if min(max(xs) - min(xs), max(zs) - min(zs)) < TIRA and _se_enciman(list(rect), pol):
            return True
    return False


def _en_calle(rect, calles):
    a, b, c, d = rect
    puntos = list(rect) + [((a[0] + c[0]) / 2, (a[1] + c[1]) / 2), ((c[0] + d[0]) / 2, (c[1] + d[1]) / 2)]
    # El frente va pegado a su banqueta: se mide un poco adentro
    return any(_distancia_segmento(x, z, p, q) < medio - 0.3 for x, z in puntos for tramo, medio in calles for p, q in zip(tramo, tramo[1:]))


def _rellenar(calles, ocupado, recorte, nuevas, filas, callejones_desde):
    """Pone los lotes del relleno. En `filas` deja cada fila corrida de casas (una pegada a la
    otra) de cada lado de cada tramo: (casas, p, u, n, medio, es_callejon); de ahi salen las rutas
    por las azoteas. Las calles desde `callejones_desde` son los callejones puestos a mano."""
    x1, z1, x2, z2 = recorte
    dentro = lambda r: all(x1 + 1.0 < x < x2 - 1.0 and z1 + 1.0 < z < z2 - 1.0 for x, z in r)
    puestos = []
    lotes = baldios = n = 0
    for ic, (tramo, medio) in enumerate(calles):
        for p, q in zip(tramo, tramo[1:]):
            dx, dz = q[0] - p[0], q[1] - p[1]
            largo = math.hypot(dx, dz)
            if largo < LOTE_FRENTE[0] + 2 * ESQUINA:
                continue
            ux, uz = dx / largo, dz / largo
            for lado in (1, -1):
                nx, nz = -uz * lado, ux * lado            # hacia afuera de la calle
                t = ESQUINA
                fila, fin = [], None
                while True:
                    semilla = int(abs(p[0] * 3.1 + p[1] * 7.7 + t * 13.3 + lado * 5)) % 1000
                    frente0 = LOTE_FRENTE[0] + (LOTE_FRENTE[1] - LOTE_FRENTE[0]) * (semilla % 100) / 100
                    fondo0 = LOTE_FONDO[0] + (LOTE_FONDO[1] - LOTE_FONDO[0]) * ((semilla // 7) % 100) / 100
                    if t + LOTE_ANGOSTO > largo - ESQUINA:
                        break
                    ax, az = p[0] + ux * t + nx * medio, p[1] + uz * t + nz * medio
                    puesto = False
                    for frente in (frente0, LOTE_ANGOSTO):
                        if t + frente > largo - ESQUINA:
                            continue
                        for fondo in (fondo0,) + LOTE_FONDOS_MENOS:
                            a = (ax, az)
                            b = (ax + ux * frente, az + uz * frente)
                            c = (b[0] + nx * fondo, b[1] + nz * fondo)
                            d = (ax + nx * fondo, az + nz * fondo)
                            rect = [a, b, c, d]
                            if dentro(rect) and not _en_calle(rect, calles) and not _encima(rect, ocupado + puestos):
                                puesto = True
                                break
                        if puesto:
                            break
                    if puesto:
                        n += 1
                        puestos.append(rect)
                        # Una fila se corta con un hueco o con un baldio
                        if fin is None or abs(t - fin) > 0.01 or n % BALDIO_CADA == 0:
                            if len(fila) > 1:
                                filas.append((fila, p, (ux, uz), (nx, nz), medio, ic >= callejones_desde))
                            fila = []
                        if n % BALDIO_CADA == 0:
                            nuevas.extend(_baldio("Baldio_%d" % n, rect, VARIANTES_LOTE[(n // BALDIO_CADA) % len(VARIANTES_LOTE)]))
                            baldios += 1
                            fin = None
                        else:
                            casa = _casa("Lote_%d" % n, rect, 0, n)
                            nuevas.append(casa)
                            fila.append(casa)
                            lotes += 1
                            fin = t + frente
                        t += frente
                    else:
                        t += 1.0
                if len(fila) > 1:
                    filas.append((fila, p, (ux, uz), (nx, nz), medio, ic >= callejones_desde))
    return lotes, baldios


# Rutas por las azoteas ("rutas" del .json, a mano): un tramo de frente de calle de `a` a `b`
# (puntos en la orilla de la banqueta) con las casas hacia `lado` (1: a la izquierda viendo de a a b;
# -1: a la derecha) y `fondo` m. Se reserva (las huellas reales de ahi se quitan y el relleno no
# entra) y se arma una fila corrida de casas de RUTA_PISOS pisos con la azotea pareja, que se camina
# de punta a punta, y una escalera de fierro desde la banqueta en la punta `a`.
RUTA_PISOS = 2
ALTO_AZOTEA = RUTA_PISOS * 2.75 + 0.05     # kit.PISO por piso, mas la losa
RUTA_FRENTES = (6.0, 8.0)


def _banda_ruta(r):
    (ax, az), (bx, bz) = r["a"], r["b"]
    largo = math.hypot(bx - ax, bz - az)
    ux, uz = (bx - ax) / largo, (bz - az) / largo
    nx, nz = -uz * r.get("lado", 1), ux * r.get("lado", 1)
    f = r.get("fondo", 10.0)
    return [(ax, az), (bx, bz), (bx + nx * f, bz + nz * f), (ax + nx * f, az + nz * f)], (ux, uz), (nx, nz), largo


def _rutas(rutas, nuevas):
    escaleras = casas = 0
    for i, r in enumerate(rutas):
        banda, (ux, uz), (nx, nz), largo = _banda_ruta(r)
        (ax, az) = r["a"]
        f = r.get("fondo", 10.0)
        t, k = 0.0, 0
        while t < largo - 3.0:
            frente = RUTA_FRENTES[0] + (RUTA_FRENTES[1] - RUTA_FRENTES[0]) * ((k * 37 + i * 11) % 10) / 10
            frente = min(frente, largo - t)
            a = (ax + ux * t, az + uz * t)
            b = (a[0] + ux * frente, a[1] + uz * frente)
            rect = [a, b, (b[0] + nx * f, b[1] + nz * f), (a[0] + nx * f, a[1] + nz * f)]
            casa = _casa("%s_Casa_%d" % (r["nombre"], k), rect, 0, k + i * 7)
            casa["pisos"] = RUTA_PISOS
            nuevas.append(casa)
            casas += 1
            t += frente
            k += 1
        # Escalera pegada a la fachada en la punta `a`, sobre la banqueta, subiendo hacia `b`
        giro = math.atan2(-nx, -nz)       # +Z de la escalera hacia la calle
        eje_x = (math.cos(giro), -math.sin(giro))
        sentido = 1 if eje_x[0] * ux + eje_x[1] * uz > 0 else -1
        nuevas.append({"nombre": r["nombre"] + "_Escalera", "tipo": "escalera", "auto": True,
                       "x": round(ax + ux * 0.4, 2), "z": round(az + uz * 0.4, 2), "rot": round(giro, 4),
                       "alto": ALTO_AZOTEA, "ancho": 1.0, "sentido": sentido})
        escaleras += 1
    return escaleras, casas


# Los baldios del relleno se turnan estas variantes (piezas.lote): taller mecanico al aire libre,
# juegos oxidados, fonda de lona, baldio con basura y barda de lamina, media canchita de basquet
VARIANTES_LOTE = ["taller", "baldio", "juegos", "fonda", "basquet"]


def _baldio(nombre, rect, variante):
    """Un lote del relleno que no es casa: la pieza lote (de frente a la calle, lado a-b) y, si es
    baldio o juegos, su barda de lamina al frente."""
    a, b, c, d = rect
    cx, cz = _centro(rect)
    frente = math.hypot(b[0] - a[0], b[1] - a[1])
    fondo = math.hypot(d[0] - a[0], d[1] - a[1])
    nx, nz = (d[0] - a[0]) / fondo, (d[1] - a[1]) / fondo      # de la calle hacia el fondo
    giro = round(math.atan2(-nx, -nz), 4)
    piezas = [{"nombre": nombre, "tipo": "lote", "auto": True, "x": round(cx, 2), "z": round(cz, 2),
               "rot": giro, "tam": [round(frente, 2), round(fondo, 2)], "variante": variante}]
    if variante in ("baldio", "juegos"):
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        piezas.append({"nombre": nombre + "_Barda", "tipo": "barda", "auto": True, "x": round(mx, 2), "z": round(mz, 2),
                       "rot": giro, "largo": round(frente, 2), "alto": 2.2 if variante == "baldio" else 1.2,
                       "grueso": 0.12, "material": "foto_lamina_verde", "murales": 70})
    return piezas


def _lado(x, z, recorte):
    """De que borde sale un punto del final de una calle."""
    x1, z1, x2, z2 = recorte
    d = {"poniente": abs(x - x1), "oriente": abs(x - x2), "norte": abs(z - z1), "sur": abs(z - z2)}
    lado = min(d, key=d.get)
    return lado if d[lado] < 0.5 else None


def bloquear(nombre):
    datos = leer_colonia(nombre)
    recorte = datos["recorte"]
    x1, z1, x2, z2 = recorte
    rutas = datos.get("rutas", [])
    reservas = [r["puntos"] for r in datos.get("reservas", [])] + [_banda_ruta(r)[0] for r in rutas]
    bordes = datos.get("bordes", {})
    # "rejas": [{"nombre", "lado", "z0", "z1" (o "x0", "x1" en norte y sur), "calles": ["Calle_1_0", ...]}]
    # una reja en la barda donde sale una avenida: sustituye al tapon de esas calles y parte la barda
    rejas = datos.get("rejas", [])
    sin_tapon = {c for r in rejas for c in r.get("calles", [])}
    calles_osm, areas, huellas = datos_osm(recorte)
    piezas = [p for p in datos.get("piezas", []) if not p.get("auto")]
    nuevas = []

    calles = []   # (puntos, medio ancho con banqueta) para quitar edificios
    para_postes = []   # (puntos, medio con banqueta, ancho del arroyo, avenida)
    for i, c in enumerate(calles_osm):
        if c["tipo"] in SIN_DIBUJAR:
            continue
        ancho = ANCHO_SENTIDO.get(c["tipo"], c["ancho"]) if c["sentido"] else c["ancho"]
        banqueta = BANQUETA_TIPO.get(c["tipo"], 1.5)
        for j, tramo in enumerate(_recortar(c["puntos"], recorte)):
            cx, cz = tramo[0]
            nuevas.append({"nombre": "Calle_%d_%d" % (i, j), "tipo": "calle", "auto": True, "x": round(cx, 2), "z": round(cz, 2),
                           "puntos": _relativos(tramo, cx, cz), "ancho": ancho, "banqueta": banqueta, "real": c["nombre"]})
            calles.append((tramo, ancho / 2 + banqueta))
            if banqueta > 0:
                para_postes.append((tramo, ancho / 2 + banqueta, ancho, c["tipo"] in ("tertiary", "secondary", "primary")))
            for punta in (tramo[0], tramo[-1]):
                lado = _lado(punta[0], punta[1], recorte)
                if lado and bordes.get(lado) in TAPON and "Calle_%d_%d" % (i, j) not in sin_tapon:
                    color, alto = TAPON[bordes[lado]]
                    a, b = (tramo[0], tramo[1]) if punta is tramo[0] else (tramo[-1], tramo[-2])
                    rot = math.atan2(b[0] - a[0], b[1] - a[1])
                    adentro = 1.5
                    largo = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
                    px, pz = a[0] + (b[0] - a[0]) / largo * adentro, a[1] + (b[1] - a[1]) / largo * adentro
                    pieza = {"nombre": "Tapon_%d_%d_%s" % (i, j, "a" if punta is tramo[0] else "b"), "auto": True,
                             "x": round(px, 2), "z": round(pz, 2), "rot": round(rot, 4), "borde": bordes[lado]}
                    largo_tapon = round(ancho + 2 * banqueta, 2)
                    # Cada borde con su pieza (piezas.py); la barda es la de block con murales
                    pieza.update({"gela": {"tipo": "valla_gela", "largo": largo_tapon},
                                  "fieles": {"tipo": "nicho_virgen", "largo": largo_tapon},
                                  "camion": {"tipo": "camion_volteado", "largo": largo_tapon},
                                  "derrumbe": {"tipo": "escombro", "largo": largo_tapon},
                                  "barda": {"tipo": "barda", "largo": largo_tapon, "alto": alto, "murales": 80}}[bordes[lado]])
                    nuevas.append(pieza)

    # Los callejones puestos a mano (calles de empedrado sin banqueta) tambien se rellenan: casas
    # que les dan el frente, como en una privada
    callejones = []
    for p in piezas:
        if p["tipo"] == "calle" and p.get("material") == "empedrado":
            tramo = [(p["x"] + x, p["z"] + z) for x, z in p["puntos"]]
            callejones.append((tramo, p["ancho"] / 2))

    verdes = []
    for k, area in enumerate(areas):
        e = area["etiquetas"]
        if e.get("leisure") in ("park", "garden", "playground") or e.get("place") == "square" or e.get("landuse") == "grass":
            verdes.append(area["puntos"])
            cx, cz = _centro(area["puntos"])
            nuevas.append({"nombre": "Verde_%d" % k, "tipo": "suelo", "auto": True, "x": round(cx, 2), "z": round(cz, 2),
                           "puntos": _relativos(area["puntos"], cx, cz), "real": e.get("name", ""),
                           # Las plazas van empedradas (como la de Arandas); parques y camellones, pasto
                           "material": "adoquin" if e.get("place") == "square" else "pasto_seco"})

    quitadas = {"calle": 0, "verde": 0, "reserva": 0, "chica": 0, "fuera": 0}
    ocupado = []     # huellas puestas (para que el relleno no se les encime)
    for k, h in enumerate(huellas):
        cx, cz = _centro(h)
        if not (x1 + 1 < cx < x2 - 1 and z1 + 1 < cz < z2 - 1):
            quitadas["fuera"] += 1
            continue
        if _area(h) < HUELLA_MIN:
            quitadas["chica"] += 1
            continue
        if any(_se_enciman(h, r) for r in reservas):
            quitadas["reserva"] += 1
            continue
        if any(_dentro_poligono(cx, cz, v) for v in verdes):
            quitadas["verde"] += 1
            continue
        if any(_distancia_segmento(cx, cz, a, b) < medio for tramo, medio in calles for a, b in zip(tramo, tramo[1:])):
            quitadas["calle"] += 1
            continue
        nuevas.append(_casa("Casa_%d" % k, h, _frente(h, calles), k))
        ocupado.append(h)

    filas = []
    lotes, baldios = _rellenar(calles + callejones, ocupado + reservas + verdes, recorte, nuevas, filas, len(calles))
    escaleras, casas_ruta = _rutas(rutas, nuevas)

    # Barda alrededor
    a = BARDA_ADENTRO
    for lado, (cx, cz, ancho, fondo) in {"norte": ((x1 + x2) / 2, z1 + a, x2 - x1, BARDA_GRUESO),
                                          "sur": ((x1 + x2) / 2, z2 - a, x2 - x1, BARDA_GRUESO),
                                          "poniente": (x1 + a, (z1 + z2) / 2, BARDA_GRUESO, z2 - z1),
                                          "oriente": (x2 - a, (z1 + z2) / 2, BARDA_GRUESO, z2 - z1)}.items():
        a_lo_largo_x = ancho > fondo
        # Los huecos de las rejas de este lado (de menor a mayor) parten la barda en tramos
        huecos = sorted((r.get("x0", r.get("z0")), r.get("x1", r.get("z1"))) for r in rejas if r["lado"] == lado)
        desde, hasta = (x1, x2) if a_lo_largo_x else (z1, z2)
        tramos, cursor = [], desde
        for h0, h1 in huecos:
            tramos.append((cursor, h0))
            cursor = h1
        tramos.append((cursor, hasta))
        for n, (t0, t1) in enumerate(tramos):
            nombre_barda = "Barda_" + lado if len(tramos) == 1 else "Barda_%s_%s" % (lado, "abcdefgh"[n])
            # En trozos de hasta MURALLA_TROZO m: un objeto de 235 m caia en un solo cuadro de
            # MapaPostImport y se dibujaba desde toda la colonia
            trozos = max(1, math.ceil((t1 - t0) / MURALLA_TROZO))
            for k in range(trozos):
                s0, s1 = t0 + (t1 - t0) * k / trozos, t0 + (t1 - t0) * (k + 1) / trozos
                medio = (s0 + s1) / 2
                nuevas.append({"nombre": "%s_%d" % (nombre_barda, k), "tipo": "muralla", "auto": True,
                               "x": round(medio if a_lo_largo_x else cx, 2), "z": round(cz if a_lo_largo_x else medio, 2),
                               "rot": 0.0 if a_lo_largo_x else round(math.pi / 2, 4), "largo": round(s1 - s0, 2),
                               "alto": MURALLA_ALTO, "base": BARDA_ALTO, "dentro": MURALLA_DENTRO[lado],
                               "grueso": BARDA_GRUESO, "murales": 60})
        for r in rejas:
            if r["lado"] != lado:
                continue
            h0, h1 = r.get("x0", r.get("z0")), r.get("x1", r.get("z1"))
            medio = (h0 + h1) / 2
            nuevas.append({"nombre": r["nombre"], "tipo": "reja", "auto": True,
                           "x": round(medio if a_lo_largo_x else cx, 2), "z": round(cz if a_lo_largo_x else medio, 2),
                           "rot": 0.0 if a_lo_largo_x else round(math.pi / 2, 4), "largo": round(h1 - h0, 2),
                           "alto": MURALLA_ALTO, "grueso": BARDA_GRUESO})

    datos["postes"] = _postes(para_postes, [(t, a / 2) for t, m, a, av in para_postes])
    todas_casas = [p for p in nuevas + piezas if p["tipo"] == "casa"]
    usadas = set()
    marcas, datos["negocios"] = _tiendas(datos.get("tiendas", []), todas_casas, usadas, calles)
    marcas += _vecinos(datos.get("vecinos", []), todas_casas, usadas)
    marcas += salidas_colonia(rejas, recorte)
    datos["marcas"] = [m for m in datos.get("marcas", []) if not m.get("auto")] + marcas
    # Ningun puesto del tianguis enfrente de una puerta (si no, no se llega a la flecha)
    # (las puertas puestas a mano tambien: la tortilleria)
    puertas = [m for m in datos["marcas"] if m.get("tipo") == "puerta"]
    tapan = [p for p in piezas if p["tipo"] == "puesto" and any(math.hypot(p["x"] - m["x"], p["z"] - m["z"]) < PUESTO_LIBRE for m in puertas)]
    piezas = [p for p in piezas if p not in tapan]
    datos["piezas"] = nuevas + piezas
    guardar_json(ruta_colonia(nombre), datos)
    cuenta = {}
    for p in nuevas:
        cuenta[p["tipo"]] = cuenta.get(p["tipo"], 0) + 1
    print("bloqueo %s: %s; huellas quitadas %s; relleno: %d casas y %d baldios; azoteas: %d rutas con %d casas; %d postes; %d negocios; %d piezas a mano" % (
        nombre, cuenta, quitadas, lotes, baldios, escaleras, casas_ruta, len(datos["postes"]), len(datos["negocios"]), len(piezas)))


SALIDA_DENTRO = 2.2    # m de la reja a la flecha de salida
LLEGADA_DENTRO = 5.4   # m de la reja a donde aparece el jugador al entrar por ella


def salidas_colonia(rejas, recorte):
    """La flecha amarilla de adentro de cada reja (Colonia.gd, "salida_colonia"): al pisarla se sale
    al mapa grande (map_test) por el mismo lado, y "llegada" es donde se aparece al entrar por esa reja."""
    x1, z1, x2, z2 = recorte
    marcas = []
    for r in rejas:
        lado = r["lado"]
        h0, h1 = r.get("x0", r.get("z0")), r.get("x1", r.get("z1"))
        medio = (h0 + h1) / 2
        # (x, z) de la reja y hacia donde queda "adentro" (poniente: +x, oriente: -x, norte: +z, sur: -z)
        base, (dx, dz) = {"poniente": ((x1 + BARDA_ADENTRO, medio), (1, 0)), "oriente": ((x2 - BARDA_ADENTRO, medio), (-1, 0)),
                          "norte": ((medio, z1 + BARDA_ADENTRO), (0, 1)), "sur": ((medio, z2 - BARDA_ADENTRO), (0, -1))}[lado]
        marcas.append({"nombre": "Salida_" + lado, "tipo": "salida_colonia", "auto": True, "lado": lado,
                       "x": round(base[0] + dx * SALIDA_DENTRO, 2), "z": round(base[1] + dz * SALIDA_DENTRO, 2),
                       "rot": round(math.atan2(dx, dz), 4),
                       "llegada": [round(base[0] + dx * LLEGADA_DENTRO, 2), round(base[1] + dz * LLEGADA_DENTRO, 2)],
                       "texto": "Salir de Santa Mugre"})
    return marcas


def reasignar_negocios(nombre):
    """Vuelve a elegir la casa de cada negocio (y de cada vecino) sin rehacer el resto del bloqueo:
    el relleno, las calles y lo puesto a mano se quedan como estan en el .json."""
    datos = leer_colonia(nombre)
    casas = [p for p in datos["piezas"] if p["tipo"] == "casa"]
    for casa in casas:
        casa.pop("local", None)
        casa.pop("tienda", None)
    usadas = set()
    calles = [([(p["x"] + x, p["z"] + z) for x, z in p["puntos"]], p["ancho"] / 2 + p.get("banqueta", 0.0))
              for p in datos["piezas"] if p["tipo"] == "calle" and p["nombre"].startswith("Calle") and p["ancho"] >= 6.0]
    marcas, datos["negocios"] = _tiendas(datos.get("tiendas", []), casas, usadas, calles)
    marcas += _vecinos(datos.get("vecinos", []), casas, usadas)
    datos["marcas"] = [m for m in datos.get("marcas", []) if not m.get("auto")] + marcas
    puertas = [m for m in datos["marcas"] if m.get("tipo") == "puerta"]
    antes = len(datos["piezas"])
    datos["piezas"] = [p for p in datos["piezas"]
                       if not (p["tipo"] == "puesto" and any(math.hypot(p["x"] - m["x"], p["z"] - m["z"]) < PUESTO_LIBRE for m in puertas))]
    guardar_json(ruta_colonia(nombre), datos)
    print("negocios de %s reasignados: %d; puestos quitados de las puertas: %d" % (nombre, len(datos["negocios"]), antes - len(datos["piezas"])))
    for n in datos["negocios"]:
        print("  %-28s %6.1f x %5.1f  en (%.0f, %.0f)" % (n["nombre"][:28], n["ancho"], n["fondo"], n["x"], n["z"]))


if not globals().get("SOLO_FUNCIONES"):
    if globals().get("REASIGNAR"):
        reasignar_negocios(globals().get("COLONIA", "santa_mugre"))
    else:
        bloquear(globals().get("COLONIA", "santa_mugre"))
