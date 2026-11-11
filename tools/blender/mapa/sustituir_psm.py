"""Cambia algunas casas de una colonia por la casa base de Parques de Santa Maria (casa_psm.py): piezas
"casa_psm" en lugar de "casa" en el .json. Python solo (sin Blender):

    python3 -I tools/blender/mapa/sustituir_psm.py santa_mugre

bloqueo.py la corre al final, asi que al rehacer el bloqueo se vuelve a hacer el cambio. Para quitarla,
basta con correr bloqueo.py sin ella: las casas_psm llevan "auto" y se rehacen como casas.

La casa PSM va sobre la misma huella que tenia la casa: mismo frente y fondo, y el frente repartido en
casas de FRENTE m (una, dos o las que quepan), asi que nada se mueve: ni las calles, ni los callejones, ni
las vecinas. La cochera, que es lo que distingue a la colonia (y el revoltijo de casas con y sin cochera,
con distintas rejas), sale de una de tres maneras, en este orden:
  1. del lugar libre entre la fachada y la banqueta (COCHERA_MIN m o mas);
  2. de ese mismo lugar, si lo que lo ocupa son solo lotes del relleno (Lote_*, sin tienda ni puerta): se
     quitan;
  3. de la huella misma, si tiene fondo (COCHERA_DENTRO): la fachada se mete y lo de enfrente es cochera.
Si no, va sin cochera, con la fachada donde estaba. Se quedan como las dejo bloqueo.py, para no romper
nada:
  - las de las rutas por las azoteas (su azotea pareja y su escalera), las de la parroquia y las
    huellas que no son rectangulo;
  - las tiendas y las casas con una puerta (negocio, vecino, la casa del jugador) cerca del frente;
  - las que dan a un callejon (las privadas se quedan como las armo Alan);
  - las de 3 pisos, las de menos de FRENTE[0] m de frente y las de menos de FONDO_MIN m de fondo.
La casa_psm guarda la huella ("puntos", "frente") como la casa, asi que exportar.py y leer() la tratan
igual; colonia.py la arma con casa_psm.py sobre esa huella, con "cochera" (m de la banqueta a la fachada)
y "retiro" (cuanto de eso queda dentro de la huella).
"""
import json
import math
import os
import re
import sys

FRENTE = (4.5, 7.0)        # el ancho de cada casa PSM
FRENTE_IDEAL = 5.5
FONDO_MIN = 4.5            # de la fachada al fondo de la casa
COCHERA_MIN = 4.0          # lo minimo de la banqueta a la fachada para que lleve cochera
COCHERA_MAX = 6.0
COCHERA_DENTRO = 5.0       # la cochera que se mete en la huella (si queda FONDO_MIN de casa)
PUERTA_CERCA = 5.0         # m de una marca al frente
REJA = 0.66                # como data/map/casas.json: dos tercios con reja
PUERTAS = ("blanca", "negra", "cafe")
HERRERIAS = ("blanca", "negra")
REJAS = ("tablones", "barrotes", "persiana")
COLORES_REJA = ("blanco", "negro", "gris", "cafe")


def _mundo(p):
    c, s = math.cos(p.get("rot", 0.0)), math.sin(p.get("rot", 0.0))
    return [(p["x"] + x * c + z * s, p["z"] - x * s + z * c) for x, z in p["puntos"]]


def _d_segmento(px, pz, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / (dx * dx + dz * dz or 1.0)))
    return math.hypot(px - a[0] - dx * t, pz - a[1] - dz * t)


def _dentro(x, z, pol):
    dentro = False
    j = len(pol) - 1
    for i in range(len(pol)):
        (xi, zi), (xj, zj) = pol[i], pol[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            dentro = not dentro
        j = i
    return dentro


def _encima(rect, pol):
    """Como bloqueo._encima: muestras del rectangulo dentro del poligono o vertices del poligono dentro
    del rectangulo."""
    a, b, _c, d = rect
    muestras = [(a[0] + (b[0] - a[0]) * u + (d[0] - a[0]) * v, a[1] + (b[1] - a[1]) * u + (d[1] - a[1]) * v)
                for u in (0.1, 0.5, 0.9) for v in (0.1, 0.5, 0.9)]
    return any(_dentro(x, z, pol) for x, z in muestras) or any(_dentro(x, z, rect) for x, z in pol)


def _huella(p):
    """Del rectangulo de la casa: esquinas del frente (a, b) y del fondo (c, d) y la normal hacia la
    calle, o None si no es rectangulo."""
    pts = _mundo(p)
    if len(pts) != 4:
        return None
    i = p.get("frente", 0) % 4
    a, b, c, d = pts[i], pts[(i + 1) % 4], pts[(i + 2) % 4], pts[(i + 3) % 4]
    ux, uz = b[0] - a[0], b[1] - a[1]
    vx, vz = a[0] - d[0], a[1] - d[1]          # del fondo al frente
    lu, lv = math.hypot(ux, uz), math.hypot(vx, vz)
    if lu < 0.1 or lv < 0.1 or abs(ux * vx + uz * vz) > 0.05 * lu * lv:
        return None
    return a, b, c, d, (vx / lv, vz / lv)


def _pieza(p, nombre, a, b, c, d, cochera, retiro, k):
    cx, cz = (a[0] + b[0] + c[0] + d[0]) / 4, (a[1] + b[1] + c[1] + d[1]) / 4
    dado = lambda n: int(abs(math.sin((k + 1) * 12.9898 + n * 78.233) * 43758.5453) * 1000) % 1000 / 1000
    pieza = {"nombre": nombre, "tipo": "casa_psm", "auto": True, "x": round(cx, 2), "z": round(cz, 2),
             "puntos": [[round(x - cx, 2), round(z - cz, 2)] for x, z in (a, b, c, d)], "frente": 0,
             "pisos": p.get("pisos", 1), "color": p.get("color", "crema"), "cochera": round(cochera, 2),
             "retiro": round(retiro, 2),
             "puerta": PUERTAS[int(dado(1) * 3)], "herreria": HERRERIAS[int(dado(2) * 2)], "espejo": dado(3) < 0.5}
    if cochera and dado(4) < REJA:
        pieza.update({"reja": REJAS[int(dado(5) * 3)], "reja_color": COLORES_REJA[int(dado(6) * 4)]})
    return pieza


def _partes(frente):
    """En cuantas casas de FRENTE m se reparte un frente (0 si no cabe ni una)."""
    if frente < FRENTE[0]:
        return 0
    n = max(1, round(frente / FRENTE_IDEAL))
    while n > 1 and frente / n < FRENTE[0]:
        n -= 1
    while frente / n > FRENTE[1]:
        n += 1
    return n


def sustituir(datos):
    """Cambia en datos["piezas"] las casas que quedan por casas_psm (y quita los lotes del relleno que
    estorban una cochera). Devuelve cuantas casas se cambiaron, cuantas casas PSM quedaron y cuantas
    llevan cochera."""
    piezas = datos.get("piezas", [])
    callejones, calles = [], []
    for p in piezas:
        if p["tipo"] == "calle":
            tramo = [(p["x"] + x, p["z"] + z) for x, z in p["puntos"]]
            if p.get("material") == "empedrado":
                callejones.append((tramo, p["ancho"] / 2))
            else:
                calles.append((tramo, p["ancho"] / 2 + p.get("banqueta", 1.5)))
    con_huella = [(q, _mundo(q)) for q in piezas if "puntos" in q and q["tipo"] not in ("calle", "suelo")]
    marcas = [(m["x"], m["z"]) for m in datos.get("marcas", [])]
    puerta_cerca = lambda a, b: any(_d_segmento(x, z, a, b) < PUERTA_CERCA for x, z in marcas)

    def estorba(q):
        """Un lote del relleno que se puede quitar para la cochera de otra casa."""
        h = _huella(q) if q["tipo"] == "casa" and q["nombre"].startswith("Lote_") and not q.get("tienda") else None
        return h is not None and not puerta_cerca(h[0], h[1])

    planes, quitar = {}, set()
    for p in piezas:
        es = p["tipo"] == "casa" and p.get("auto") and p.get("pisos", 1) <= 2 and not p.get("tienda") \
            and (p["nombre"].startswith("Lote_") or (p["nombre"].startswith("Casa_") and "Parroquia" not in p["nombre"]))
        h = _huella(p) if es else None
        if h is None:
            continue
        a, b, c, d, (nx, nz) = h
        frente, fondo = math.hypot(b[0] - a[0], b[1] - a[1]), math.hypot(d[0] - a[0], d[1] - a[1])
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        cerca = lambda tramos: min((_d_segmento(mx, mz, q, r) - medio for tramo, medio in tramos
                                    for q, r in zip(tramo, tramo[1:])), default=1e9)
        partes, a_calle = _partes(frente), cerca(calles)
        if not partes or fondo < FONDO_MIN or cerca(callejones) < a_calle or puerta_cerca(a, b):
            continue
        # 1 y 2: la cochera entre la fachada y la banqueta, libre o quitando lotes del relleno
        cochera, retiro, quita = min(a_calle, COCHERA_MAX), 0.0, []
        if cochera >= COCHERA_MIN:
            rect = [(a[0] + nx * cochera, a[1] + nz * cochera), (b[0] + nx * cochera, b[1] + nz * cochera),
                    (b[0] + nx * 0.1, b[1] + nz * 0.1), (a[0] + nx * 0.1, a[1] + nz * 0.1)]
            quita = [q for q, pol in con_huella if q is not p and _encima(rect, pol)]
            if not all(estorba(q) for q in quita):
                cochera, quita = 0.0, []
        else:
            cochera = 0.0
        # 3: la cochera dentro de la huella
        if not cochera and fondo - COCHERA_DENTRO >= FONDO_MIN:
            cochera = retiro = COCHERA_DENTRO
        planes[p["nombre"]] = (h, partes, cochera, retiro, quita)
    # Las que se quitan para una cochera ya no se cambian (ni ponen su propia cochera encima de nada)
    for nombre, (_h, _n, _c, _r, quita) in list(planes.items()):
        if nombre in quitar:
            continue
        if any(q["nombre"] in planes and q["nombre"] not in quitar and planes[q["nombre"]][4] for q in quita):
            planes[nombre] = planes[nombre][:2] + (0.0, 0.0, [])
            continue
        quitar.update(q["nombre"] for q in quita)
    nuevas, cambiadas, casas, con_cochera = [], 0, 0, 0
    for k, p in enumerate(piezas):
        if p["nombre"] in quitar:
            continue
        if p["nombre"] not in planes:
            nuevas.append(p)
            continue
        (a, b, c, d, _n), partes, cochera, retiro, _q = planes[p["nombre"]]
        for j in range(partes):
            t0, t1 = j / partes, (j + 1) / partes
            ea = (a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0)
            eb = (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)
            ed = (d[0] + (c[0] - d[0]) * t0, d[1] + (c[1] - d[1]) * t0)
            ec = (d[0] + (c[0] - d[0]) * t1, d[1] + (c[1] - d[1]) * t1)
            sufijo = "_psm" if partes == 1 else "_psm_%d" % j
            nuevas.append(_pieza(p, p["nombre"] + sufijo, ea, eb, ec, ed, cochera, retiro, k * 8 + j))
            casas += 1
            con_cochera += cochera > 0
        cambiadas += 1
    datos["piezas"] = nuevas
    return cambiadas, casas, con_cochera, len(quitar)


if __name__ == "__main__":
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "colonias", sys.argv[1] + ".json")
    datos = json.load(open(ruta, encoding="utf-8"))
    cambiadas, casas, con_cochera, quitados = sustituir(datos)
    # Como comun.guardar_json (sin bpy): las listas de puros numeros en una sola linea
    texto = json.dumps(datos, ensure_ascii=False, indent="\t")
    texto = re.sub(r"\[\s+(-?[\d.eE+-]+(?:,\s+-?[\d.eE+-]+)*)\s+\]",
                   lambda m: "[" + ", ".join(m.group(1).split()).replace(",,", ",") + "]", texto)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto + "\n")
    print("sustituir_psm %s: %d casas -> %d casas PSM (%d con cochera); %d lotes del relleno quitados" % (
        sys.argv[1], cambiadas, casas, con_cochera, quitados))
