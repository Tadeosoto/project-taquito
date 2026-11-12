"""Hileras de casas PSM para todo map_test: el algoritmo de recorte_santa_mugre.py (rama
santa-mugre-casas-detalle) sacado del recorte y puesto a trabajar sobre el mapa completo.

Corre DESPUES de build_glb.sh (lee lo que ese deja) y reescribe resources/map/casas_mapa.json y
resources/map/arboles_mapa.json:

    python3 -I tools/map_import/hileras_psm.py

Las casas PSM que dejo prepare_osm.place_casas se cambian por hileras: por cada lado de cada calle,
casas de ANCHO m una tras otra con la fachada en la orilla de la banqueta, las que no topan con otra
calle, un edificio de OSM, un muro, el pasto de una plaza, un negocio ni otra casa ya puesta. Si la
manzana es angosta, cada casa se queda con la mitad del fondo, para que quepa la de espaldas. 66 % de
un piso y 66 % con reja, y el resto al azar entre las variantes de casas_psm.glb. Despues cada casa se
alarga hacia atras (`ampliacion`, en pasos de 0.5 m, hasta 24 m de lote) hasta tocar la de espaldas.

Solo se llenan los lados de calle donde ya habia una casa PSM (a menos de CERCA m): las demas colonias
y modelos (semi_residencial en Parques del Bosque) se quedan como los puso place_casas, y la colonia
de cada hilera es la de la casa PSM mas cercana.
"""
import json
import math
import os
import random
import xml.etree.ElementTree as ET

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MAPA = os.path.join(RAIZ, "resources", "map")
OSM = os.path.join(RAIZ, "tools", "map_import", "bin", "area_prepared.osm")
SEMILLA = 7

# Como tools/map_import/banquetas.gd (los anchos con que OSM2World hornea las calles)
ANCHO_CALLE = {"primary": 14.0, "secondary": 12.0, "tertiary": 10.0, "residential": 7.0, "unclassified": 6.0,
               "living_street": 6.0, "footway": 2.0, "path": 1.5}
BANQUETA = {"primary": 2.0, "secondary": 2.0, "tertiary": 2.0, "residential": 1.5, "unclassified": 1.2,
            "living_street": 1.2, "footway": 0.0, "path": 0.0}
CON_CASAS = {"primary", "secondary", "tertiary", "residential", "unclassified", "living_street"}
# La casa PSM (tools/blender/mapa/casa_psm.py): frente, y de la banqueta al fondo (cochera + casa)
ANCHO = 5.0
FONDO = 12.0
FONDO_MIN = 8.0
FONDO_TOPE = 16.0
FONDO_LOTE = 24.0
PASO_AMPLIA = 0.5
# Solo donde hay una casa PSM de place_casas a menos de esto (m) del frente
CERCA = 20.0
# El muro de Santa Mugre (scripts/map/MuroColonia.gd): las casas no lo tocan
MURO = (-420.0, 258.0, -185.0, 482.0)
MURO_GRUESO = 0.3 + 0.6
VARIANTES = {1: (["psm_1p_a", "psm_1p_b", "psm_1p_c"], ["psm_1p_tablones", "psm_1p_barrotes", "psm_1p_persiana"]),
             2: (["psm_2p_a", "psm_2p_b", "psm_2p_c"], ["psm_2p_tablones", "psm_2p_barrotes", "psm_2p_persiana"])}
# prepare_osm.CASA_PALETTE
COLORES = ["#e8d7b9", "#5b8fd9", "#a47ad1", "#f2c94c", "#3fa7b5", "#d9608f", "#e05a47", "#f2994a", "#f7f4ec", "#7cc06a"]


def leer(ruta):
    return json.load(open(ruta, encoding="utf-8"))


# --- OSM, con la proyeccion de prepare_osm.py (Mercator por cos(lat0), origen al centro de <bounds>)
def leer_osm(ruta):
    raiz = ET.parse(ruta).getroot()
    b = raiz.find("bounds").attrib
    lat0 = (float(b["minlat"]) + float(b["maxlat"])) / 2
    lon0 = (float(b["minlon"]) + float(b["maxlon"])) / 2
    r, e = 6378137.0, math.cos(math.radians(lat0))
    merc = lambda la: r * math.log(math.tan(math.pi / 4 + math.radians(la) / 2))
    nodos = {n.get("id"): (r * math.radians(float(n.get("lon")) - lon0) * e,
                           -(merc(float(n.get("lat"))) - merc(lat0)) * e) for n in raiz.iter("node")}
    vias = []
    for w in raiz.iter("way"):
        pts = [nodos[n.get("ref")] for n in w.iter("nd") if n.get("ref") in nodos]
        if pts:
            vias.append(({t.get("k"): t.get("v") for t in w.iter("tag")}, pts))
    return vias


# --- Geometria 2D -------------------------------------------------------------------------------
def casco(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts
    cruz = lambda o, a, b: (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    abajo, arriba = [], []
    for q in pts:
        while len(abajo) >= 2 and cruz(abajo[-2], abajo[-1], q) <= 0:
            abajo.pop()
        abajo.append(q)
    for q in reversed(pts):
        while len(arriba) >= 2 and cruz(arriba[-2], arriba[-1], q) <= 0:
            arriba.pop()
        arriba.append(q)
    return abajo[:-1] + arriba[:-1]


def se_tocan(a, b):
    """Separacion de ejes entre dos poligonos convexos."""
    for p in (a, b):
        for k in range(len(p)):
            (x1, z1), (x2, z2) = p[k], p[(k + 1) % len(p)]
            nx, nz = z1 - z2, x2 - x1
            pa = [x * nx + z * nz for x, z in a]
            pb = [x * nx + z * nz for x, z in b]
            if max(pa) <= min(pb) + 1e-6 or max(pb) <= min(pa) + 1e-6:
                return False
    return True


def caja(cx, cz, ux, uz, ancho, fondo):
    """Rectangulo con el frente centrado en (cx, cz), u hacia la calle, el fondo hacia atras."""
    tx, tz, h = uz, -ux, ancho / 2
    return [(cx + tx * h, cz + tz * h), (cx - tx * h, cz - tz * h),
            (cx - tx * h - ux * fondo, cz - tz * h - uz * fondo), (cx + tx * h - ux * fondo, cz + tz * h - uz * fondo)]


def tramos(pts, derecha, izquierda=None):
    """Rectangulos de cada tramo de una linea, `derecha` m a su derecha (segun su sentido) e
    `izquierda` a su izquierda (lo mismo si no se da)."""
    izquierda = derecha if izquierda is None else izquierda
    rects = []
    for a, b in zip(pts, pts[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dz) or 1
        nx, nz = -dz / l, dx / l
        d, i = derecha, izquierda
        rects.append([(a[0] + nx * d, a[1] + nz * d), (b[0] + nx * d, b[1] + nz * d),
                      (b[0] - nx * i, b[1] - nz * i), (a[0] - nx * i, a[1] - nz * i)])
    return rects


def _metros(v):
    try:
        return float(str(v).split()[0])
    except (ValueError, IndexError):
        return None


def medio_ancho(t):
    """Del eje de la calle a la orilla de afuera de su banqueta, (a la derecha, a la izquierda): el
    ancho y las banquetas de OSM si los trae (asi las hornea OSM2World), si no los de su tipo."""
    h = t["highway"]
    ancho = _metros(t.get("width")) or ANCHO_CALLE[h]
    acera = t.get("sidewalk")
    lados = []
    for lado in ("right", "left"):
        if acera is None:
            b = BANQUETA[h]
        elif acera in (lado, "both"):
            b = _metros(t.get("sidewalk:%s:width" % lado)) or _metros(t.get("sidewalk:width")) or BANQUETA[h]
        else:
            b = 0.0
        lados.append(ancho / 2 + b)
    return tuple(lados)


def en_poligono(x, z, pts):
    dentro_ = False
    for (x1, z1), (x2, z2) in zip(pts, pts[1:] + pts[:1]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            dentro_ = not dentro_
    return dentro_


class Indice:
    """Poligonos en una rejilla de CELDA m: solo se prueba contra los que caen en las mismas celdas
    (el mapa tiene decenas de miles; el recorte de Santa Mugre, unos cientos)."""
    CELDA = 25.0

    def __init__(self):
        self.celdas = {}
        self.todos = []

    def _claves(self, poli):
        xs = [p[0] for p in poli]
        zs = [p[1] for p in poli]
        c = self.CELDA
        return [(i, j) for i in range(int(min(xs) // c), int(max(xs) // c) + 1)
                for j in range(int(min(zs) // c), int(max(zs) // c) + 1)]

    def agregar(self, poli):
        self.todos.append(poli)
        for k in self._claves(poli):
            self.celdas.setdefault(k, []).append(poli)

    def cerca(self, poli):
        vistos = {}
        for k in self._claves(poli):
            for q in self.celdas.get(k, ()):
                vistos[id(q)] = q
        return vistos.values()

    def toca(self, poli):
        return any(se_tocan(poli, q) for q in self.cerca(poli))


class Hileras:
    def __init__(self, vias, otros_lotes, puntos, bardas):
        self.calles = []                # [(tipo, puntos, medio ancho)]
        self.rect_calles = Indice()
        self.estorbos = Indice()        # poligonos convexos
        self.areas = []                 # poligonos (no convexos) donde no va casa: pasto, plazas
        self.puestas = Indice()
        self.casas = []
        for t, pts in vias:
            h = t.get("highway")
            if h in ANCHO_CALLE:
                m = medio_ancho(t)
                for r in tramos(pts, *m):
                    self.rect_calles.agregar(r)
                if h in CON_CASAS:
                    self.calles.append((h, pts, m))
            elif "building" in t and len(pts) >= 3:
                self.estorbos.agregar(casco(pts))
            elif t.get("barrier") == "wall":
                for r in tramos(pts, 0.2):
                    self.estorbos.agregar(r)
            elif (t.get("landuse") == "grass" or t.get("place") == "square" or "leisure" in t) and len(pts) >= 4:
                self.areas.append(pts[:-1] if pts[0] == pts[-1] else pts)
        # El muro de Santa Mugre: cuatro bandas
        x0, z0, x1, z1 = MURO
        g = MURO_GRUESO / 2
        for a, b in (((x0, z0), (x1, z0)), ((x0, z1), (x1, z1)), ((x0, z0), (x0, z1)), ((x1, z0), (x1, z1))):
            for r in tramos([a, b], g):
                self.estorbos.agregar(r)
        # Los negocios del mapa (cada uno con su lote, como los de recorte_santa_mugre.py)
        for p in puntos:
            r = p.get("rotacion_y", 0.0)
            ux, uz = math.sin(r), math.cos(r)
            f = p.get("fondo", 8.0)
            self.estorbos.agregar(caja(p["x"] + ux * f / 2, p["z"] + uz * f / 2, ux, uz, p.get("ancho", 6.0) + 0.5, f))
        # Las casas que place_casas dejo (otros modelos): ocupan su lote
        for c in otros_lotes:
            r = c["rotacion_y"]
            self.estorbos.agregar(caja(c["x"], c["z"], math.sin(r), math.cos(r), c["ancho"], c["fondo"]))
        # Las bardas de baldio y de cotos
        for e in bardas:
            if len(e.get("puntos", [])) >= 2:
                for r in tramos(e["puntos"], 0.3):
                    self.estorbos.agregar(r)

    def fondo_libre(self, cx, cz, ux, uz, tope=FONDO_TOPE):
        """Cuanto fondo cabe antes de topar con otra calle: la mitad si la manzana es angosta."""
        for d10 in range(10, int(tope * 20) - 20, 5):
            d = d10 / 10
            q = caja(cx - ux * d, cz - uz * d, ux, uz, ANCHO * 0.6, 0.2)
            if self.rect_calles.toca(q):
                return min(tope, d / 2)
        return tope

    def cabe(self, cx, cz, ux, uz):
        fondo = self.fondo_libre(cx, cz, ux, uz)
        if fondo < FONDO_MIN:
            return False
        fondo = min(fondo, FONDO)
        r = caja(cx - ux * 0.02, cz - uz * 0.02, ux, uz, ANCHO - 0.06, fondo - 0.04)
        mx, mz = sum(q[0] for q in r) / 4, sum(q[1] for q in r) / 4
        if any(en_poligono(x, z, a) for a in self.areas for x, z in r + [(mx, mz)]):
            return False
        if self.estorbos.toca(r) or self.rect_calles.toca(r) or self.puestas.toca(r):
            return False
        self.puestas.agregar(r)
        return True

    def poner(self, azar, cx, cz, ux, uz, colonia):
        pisos = 1 if azar.random() < 0.66 else 2
        sin_reja, con_reja = VARIANTES[pisos]
        modelo = azar.choice(con_reja if azar.random() < 0.66 else sin_reja)
        self.casas.append({"modelo": modelo, "x": round(cx, 2), "z": round(cz, 2),
                           "rotacion_y": round(math.atan2(ux, uz), 4), "ancho": ANCHO, "fondo": FONDO,
                           "pisos": pisos, "color": azar.choice(COLORES), "colonia": colonia})

    def ampliar(self):
        """Alarga cada casa hacia atras, de PASO_AMPLIA en PASO_AMPLIA, hasta la mitad de la manzana (donde
        llega la de espaldas) o hasta topar con otra casa, su ampliacion, un estorbo, una calle o el pasto."""
        for c in self.casas:
            r = c["rotacion_y"]
            ux, uz = math.sin(r), math.cos(r)
            cx, cz = c["x"], c["z"]
            tope = self.fondo_libre(cx, cz, ux, uz, FONDO_LOTE)
            d = FONDO
            while d + PASO_AMPLIA <= tope:
                q = caja(cx - ux * (d + 0.03), cz - uz * (d + 0.03), ux, uz, ANCHO - 0.06, PASO_AMPLIA - 0.06)
                if any(en_poligono(x, z, a) for a in self.areas for x, z in q) \
                        or self.estorbos.toca(q) or self.rect_calles.toca(q) or self.puestas.toca(q):
                    break
                d += PASO_AMPLIA
            if d - FONDO >= 1.0:
                c["ampliacion"] = round(d - FONDO, 2)
                self.puestas.agregar(caja(cx - ux * (FONDO + 0.03), cz - uz * (FONDO + 0.03), ux, uz, ANCHO - 0.06,
                                          d - FONDO - 0.06))

    def casas_en_hileras(self, azar, viejas):
        """`viejas`: (x, z, colonia) de las casas PSM de place_casas; solo se llena donde hay una cerca."""
        c = 40.0
        rejilla = {}
        for x, z, col in viejas:
            rejilla.setdefault((int(x // c), int(z // c)), []).append((x, z, col))

        def colonia_cerca(x, z):
            mejor, dmin = None, CERCA
            for i in range(int(x // c) - 1, int(x // c) + 2):
                for j in range(int(z // c) - 1, int(z // c) + 2):
                    for vx, vz, col in rejilla.get((i, j), ()):
                        d = math.hypot(vx - x, vz - z)
                        if d < dmin:
                            mejor, dmin = col, d
            return mejor

        for h, pts, m in self.calles:
            for a, b in zip(pts, pts[1:]):
                dx, dz = b[0] - a[0], b[1] - a[1]
                l = math.hypot(dx, dz)
                if l < ANCHO:
                    continue
                ex, ez = dx / l, dz / l
                for lado in (1, -1):
                    ux, uz = -ez * lado, ex * lado        # de la casa hacia la calle
                    fx, fz = a[0] - ux * m[lado > 0], a[1] - uz * m[lado > 0]
                    t = 0.0
                    while t + ANCHO <= l:
                        cx, cz = fx + ex * (t + ANCHO / 2), fz + ez * (t + ANCHO / 2)
                        colonia = colonia_cerca(cx, cz)
                        if colonia and self.cabe(cx, cz, ux, uz):
                            self.poner(azar, cx, cz, ux, uz, colonia)
                            t += ANCHO
                        else:
                            t += 0.5        # no cupo: se recorre medio metro y prueba otra vez


def main():
    casas_viejas = leer(os.path.join(MAPA, "casas_mapa.json"))["casas"]
    psm = [c for c in casas_viejas if c["modelo"].startswith("psm_")]
    otras = [c for c in casas_viejas if not c["modelo"].startswith("psm_")]
    puntos = leer(os.path.join(MAPA, "puntos_mapa.json"))["puntos"]
    bardas = leer(os.path.join(MAPA, "bardas_mapa.json")).get("bardas", [])
    h = Hileras(leer_osm(OSM), otras, puntos, bardas)
    azar = random.Random(SEMILLA)
    h.casas_en_hileras(azar, [(c["x"], c["z"], c["colonia"]) for c in psm])
    h.ampliar()
    nuevas = h.casas
    print("casas PSM: %d de place_casas -> %d en hileras (%d con ampliacion); otras casas: %d" % (
        len(psm), len(nuevas), sum("ampliacion" in c for c in nuevas), len(otras)))
    with open(os.path.join(MAPA, "casas_mapa.json"), "w", encoding="utf-8") as f:
        f.write('{"casas": [\n' + ",\n".join(json.dumps(c, ensure_ascii=False) for c in otras + nuevas) + "\n]}\n")
    # Los arboles que quedarian dentro de una casa
    ruta = os.path.join(MAPA, "arboles_mapa.json")
    arboles = leer(ruta)
    antes = len(arboles["arboles"])
    arboles["arboles"] = [t for t in arboles["arboles"]
                          if not any(en_poligono(t[0], t[1], r) for r in h.puestas.cerca(
                              [(t[0] - 1, t[1] - 1), (t[0] + 1, t[1] - 1), (t[0] + 1, t[1] + 1), (t[0] - 1, t[1] + 1)]))]
    json.dump(arboles, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
    print("arboles: %d -> %d" % (antes, len(arboles["arboles"])))


if __name__ == "__main__":
    main()
