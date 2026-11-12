# Por donde camina la gente (scripts/map/Gente.gd, resources/mapa/<colonia>/banquetas.json), sin
# atravesar casas: el medio de cada banqueta de cada calle, mas el medio de los callejones sin
# banqueta, recortado contra las huellas de las casas y los edificios grandes del .json (las casas
# puestas a mano pueden quedar encima de una calle y la gente las cruzaba).
# Python puro (sin bpy): exportar.py lo usa y tambien corre suelto, sin reexportar el .glb:
#
#   python3 tools/blender/mapa/caminos.py santa_mugre
#
# Reescribe resources/mapa/<colonia>/banquetas.json.

import json
import math
import os
import sys

MARGEN = 0.6        # m que se ensancha cada huella: la gente no pasa pegada a la pared
PASO = 0.5          # m entre los puntos con que se prueba cada tramo
MINIMO = 3.0        # m: un tramo mas corto se descarta
TOLERANCIA = 0.15   # m que puede separarse el camino simplificado del original
RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))


def _dentro(x, z, poligono):
    c = False
    for (x1, z1), (x2, z2) in zip(poligono, poligono[-1:] + poligono[:-1]):
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


def _ensanchar(poligono, m):
    """Cada vertice se aleja del centro m metros (basta para huellas chicas y convexas)."""
    cx = sum(p[0] for p in poligono) / len(poligono)
    cz = sum(p[1] for p in poligono) / len(poligono)
    salida = []
    for x, z in poligono:
        d = math.hypot(x - cx, z - cz) or 1.0
        salida.append((x + (x - cx) / d * m, z + (z - cz) / d * m))
    return salida


def _rectangulo(x, z, rot, ancho, fondo):
    """Huella de una caja de ancho (x local) por fondo (z local), girada rot en y como en Godot."""
    c, s = math.cos(rot), math.sin(rot)
    return [(x + lx * c + lz * s, z - lx * s + lz * c)
            for lx, lz in ((-ancho / 2, -fondo / 2), (ancho / 2, -fondo / 2), (ancho / 2, fondo / 2), (-ancho / 2, fondo / 2))]


def huellas(datos):
    """Las huellas en el mundo de todo lo que estorba al caminar: casas y edificios grandes."""
    salida = []
    for p in datos.get("piezas", []):
        t = p["tipo"]
        if t == "casa":
            salida.append(_ensanchar([(p["x"] + a, p["z"] + b) for a, b in p["puntos"]], MARGEN))
        elif t in ("palacio", "parroquia", "mercado") and "tam" in p:
            tam = p["tam"]
            ancho, fondo = (tam[0], tam[2]) if t == "palacio" else (tam[0], tam[1])
            salida.append(_rectangulo(p["x"], p["z"], p.get("rot", 0.0), ancho + 2 * MARGEN, fondo + 2 * MARGEN))
    return salida


def _caja(poligono):
    xs = [p[0] for p in poligono]
    zs = [p[1] for p in poligono]
    return min(xs), min(zs), max(xs), max(zs)


def _libre(x, z, huellas_caja):
    for (x0, z0, x1, z1), poligono in huellas_caja:
        if x0 <= x <= x1 and z0 <= z <= z1 and _dentro(x, z, poligono):
            return False
    return True


def recortar(linea, huellas_mundo):
    """Parte una polilinea en los tramos que no entran a ninguna huella."""
    cajas = [(_caja(h), h) for h in huellas_mundo]
    tramos, actual = [], []
    for a, b in zip(linea, linea[1:]):
        largo = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(math.ceil(largo / PASO)))
        for i in range(n + 1):
            if i == 0 and actual:
                continue
            t = i / n
            x, z = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            if _libre(x, z, cajas):
                actual.append((x, z))
            else:
                if actual:
                    tramos.append(actual)
                actual = []
    if actual:
        tramos.append(actual)
    return tramos


def _largo(linea):
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(linea, linea[1:]))


def _aligerar(linea):
    """Ramer-Douglas-Peucker: quita los puntos de 0.5 m que sobran (Gente.gd camina de vertice en
    vertice) sin separarse mas de TOLERANCIA m de la linea, para no cortar curvas hacia una casa."""
    if len(linea) <= 2:
        return linea
    a, b = linea[0], linea[-1]
    mejor, donde = -1.0, 0
    for i in range(1, len(linea) - 1):
        d = _distancia(linea[i], a, b)
        if d > mejor:
            mejor, donde = d, i
    if mejor <= TOLERANCIA:
        return [a, b]
    return _aligerar(linea[:donde + 1])[:-1] + _aligerar(linea[donde:])


def _distancia(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz or 1.0)))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz)


def _paralela(pts, d, lado):
    linea = []
    for i, (x, z) in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        ux, uz = b[0] - a[0], b[1] - a[1]
        l = math.hypot(ux, uz) or 1.0
        linea.append((x - uz / l * d * lado, z + ux / l * d * lado))
    return linea


def lineas_crudas(datos):
    """Antes de recortar: el medio de cada banqueta y la linea central de los callejones sin banqueta."""
    lineas = []
    for p in datos.get("piezas", []):
        if p["tipo"] != "calle":
            continue
        pts = [(p["x"] + x, p["z"] + z) for x, z in p["puntos"]]
        if p.get("banqueta", 0) > 0:
            d = p["ancho"] / 2 + p["banqueta"] / 2
            lineas += [_paralela(pts, d, 1), _paralela(pts, d, -1)]
        else:
            lineas.append(pts)
    return lineas


def banquetas(datos):
    """Los caminos de la gente ya recortados, como [[x, z], ...] redondeados."""
    h = huellas(datos)
    salida = []
    for linea in lineas_crudas(datos):
        for tramo in recortar(linea, h):
            if _largo(tramo) >= MINIMO:
                salida.append([[round(x, 2), round(z, 2)] for x, z in _aligerar(tramo)])
    return salida


def _principal():
    nombre = sys.argv[1] if len(sys.argv) > 1 else "santa_mugre"
    ruta = os.path.join(RAIZ, "tools", "blender", "mapa", "colonias", nombre + ".json")
    datos = json.load(open(ruta, encoding="utf-8"))
    antes = os.path.join(RAIZ, "resources", "mapa", nombre, "banquetas.json")
    viejo = json.load(open(antes, encoding="utf-8")).get("banquetas", []) if os.path.exists(antes) else []
    nuevo = banquetas(datos)
    json.dump({"banquetas": nuevo}, open(antes, "w", encoding="utf-8"), indent="\t")
    print("%s: %d caminos (%.0f m) -> %d caminos (%.0f m)" % (
        nombre, len(viejo), sum(_largo(l) for l in viejo), len(nuevo), sum(_largo(l) for l in nuevo)))


if __name__ == "__main__":
    _principal()
