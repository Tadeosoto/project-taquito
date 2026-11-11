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
#   "bordes": {"norte"|"sur"|"oriente"|"poniente": "gela"|"barda"|"derrumbe"|"camion"}
#            el tapon de las calles que salen por ese lado (norte = z chica)

import math

_r = {"__name__": "referencia", "SOLO_FUNCIONES": True}
exec(open(r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\mapa\referencia.py", encoding="utf-8").read(), _r)
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
BARDA_ALTO = 2.6
BARDA_GRUESO = 0.3
BARDA_ADENTRO = 0.4        # m del borde del recorte
TAPON = {"gela": ((0.9, 0.45, 0.1), 2.2), "barda": ((0.62, 0.6, 0.56), 2.6),
         "derrumbe": ((0.45, 0.36, 0.28), 2.8), "camion": ((0.75, 0.75, 0.72), 3.2)}


def _dentro_poligono(x, z, poligono):
    c = False
    for (x1, z1), (x2, z2) in zip(poligono, poligono[-1:] + poligono[:-1]):
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


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
    return False


def _en_calle(rect, calles):
    a, b, c, d = rect
    puntos = list(rect) + [((a[0] + c[0]) / 2, (a[1] + c[1]) / 2), ((c[0] + d[0]) / 2, (c[1] + d[1]) / 2)]
    # El frente va pegado a su banqueta: se mide un poco adentro
    return any(_distancia_segmento(x, z, p, q) < medio - 0.3 for x, z in puntos for tramo, medio in calles for p, q in zip(tramo, tramo[1:]))


def _rellenar(calles, ocupado, recorte, nuevas):
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
                        if n % BALDIO_CADA == 0:
                            nuevas.extend(_baldio("Baldio_%d" % n, rect))
                            baldios += 1
                        else:
                            nuevas.append(_casa("Lote_%d" % n, rect, 0, n))
                            lotes += 1
                        t += frente
                    else:
                        t += 1.0
    return lotes, baldios


def _baldio(nombre, rect):
    """Lote baldio: tierra y una barda de lamina al frente (lado a-b)."""
    a, b, c, d = rect
    cx, cz = _centro(rect)
    mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    largo = math.hypot(b[0] - a[0], b[1] - a[1])
    giro = math.atan2(b[0] - a[0], b[1] - a[1]) - math.pi / 2
    return [{"nombre": nombre, "tipo": "suelo", "auto": True, "x": round(cx, 2), "z": round(cz, 2),
             "puntos": _relativos(rect, cx, cz), "material": "tierra"},
            {"nombre": nombre + "_Barda", "tipo": "caja", "auto": True, "x": round(mx, 2), "z": round(mz, 2), "rot": round(giro, 4),
             "tam": [round(largo, 2), 2.2, 0.12], "color": [0.55, 0.5, 0.42]}]


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
    reservas = [r["puntos"] for r in datos.get("reservas", [])]
    bordes = datos.get("bordes", {})
    calles_osm, areas, huellas = datos_osm(recorte)
    piezas = [p for p in datos.get("piezas", []) if not p.get("auto")]
    nuevas = []

    calles = []   # (puntos, medio ancho con banqueta) para quitar edificios
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
            for punta in (tramo[0], tramo[-1]):
                lado = _lado(punta[0], punta[1], recorte)
                if lado and bordes.get(lado) in TAPON:
                    color, alto = TAPON[bordes[lado]]
                    a, b = (tramo[0], tramo[1]) if punta is tramo[0] else (tramo[-1], tramo[-2])
                    rot = math.atan2(b[0] - a[0], b[1] - a[1])
                    adentro = 1.5
                    largo = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
                    px, pz = a[0] + (b[0] - a[0]) / largo * adentro, a[1] + (b[1] - a[1]) / largo * adentro
                    nuevas.append({"nombre": "Tapon_%d_%d_%s" % (i, j, "a" if punta is tramo[0] else "b"), "tipo": "caja", "auto": True,
                                   "x": round(px, 2), "z": round(pz, 2), "rot": round(rot, 4),
                                   "tam": [ancho + 2 * banqueta, alto, 1.2], "color": list(color), "borde": bordes[lado]})

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
        if any(_dentro_poligono(cx, cz, r) for r in reservas):
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

    lotes, baldios = _rellenar(calles, ocupado + reservas + verdes, recorte, nuevas)

    # Barda alrededor
    a = BARDA_ADENTRO
    for lado, (cx, cz, ancho, fondo) in {"norte": ((x1 + x2) / 2, z1 + a, x2 - x1, BARDA_GRUESO),
                                          "sur": ((x1 + x2) / 2, z2 - a, x2 - x1, BARDA_GRUESO),
                                          "poniente": (x1 + a, (z1 + z2) / 2, BARDA_GRUESO, z2 - z1),
                                          "oriente": (x2 - a, (z1 + z2) / 2, BARDA_GRUESO, z2 - z1)}.items():
        nuevas.append({"nombre": "Barda_" + lado, "tipo": "caja", "auto": True, "x": round(cx, 2), "z": round(cz, 2),
                       "tam": [round(ancho, 2), BARDA_ALTO, round(fondo, 2)], "color": [0.62, 0.6, 0.56]})

    datos["piezas"] = nuevas + piezas
    guardar_json(ruta_colonia(nombre), datos)
    cuenta = {}
    for p in nuevas:
        cuenta[p["tipo"]] = cuenta.get(p["tipo"], 0) + 1
    print("bloqueo %s: %s; huellas quitadas %s; relleno: %d casas y %d baldios; %d piezas a mano" % (
        nombre, cuenta, quitadas, lotes, baldios, len(piezas)))


if not globals().get("SOLO_FUNCIONES"):
    bloquear(globals().get("COLONIA", "santa_mugre"))
