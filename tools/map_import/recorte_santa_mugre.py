"""Los datos de scenes/santa_mugre_psm.tscn: el pedazo de Parques de Santa Mugre del mapa de map_test (el
mismo recorte que tools/blender/mapa/colonias/santa_mugre.json), con la colonia hecha de hileras de
casas PSM pegadas (models/casas/psm/casas_psm.glb) en lugar de los lotes de prepare_osm.py:

    python3 -I tools/map_import/recorte_santa_mugre.py --osm <area_prepared.osm> --puntos <puntos_mapa.json> \\
        --bardas <bardas_mapa.json>

--osm es el que sale de prepare_osm.py (el que se horneo en los cuadros: sus calles y edificios);
--puntos y --bardas, los de esa misma corrida con data/map/casas.json usando las casas PSM (los
baldios y las tiendas cambian con los lotes). Los arboles, postes y cuadros son los de map_test, que
no cambian dentro del recorte. Escribe resources/map/santa_mugre_psm/.

Las hileras: por cada lado de cada calle, casas de ANCHO m una tras otra con la fachada en la orilla
de la banqueta (como en la colonia real), las que no topan con otra calle, un edificio de OSM, el
pasto de la plaza, una tienda, la parroquia o el kiosco (estos dos vienen del mapa de Alan,
tools/blender/mapa/extraer_kiosco_iglesia.gd) ni con otra casa ya puesta. Si la manzana es angosta,
cada casa se queda con la mitad del fondo, para que quepa la de espaldas. 66 % de un piso y 66 % con
reja, y lo demas al azar entre las variantes del glb (tools/blender/mapa/exportar_casas_psm.py).

Los negocios: los de --puntos (DENUE) y, de cada tipo que no venga, uno de FALTANTES (como los de
NEGOCIOS en scripts/map/Safehouse.gd). Los que son casita (CASITAS, las casa-local de MapPuntos) toman
el lugar de una casa de la hilera, la mas cercana a donde los puso el DENUE (o una al azar): de su
frente, ANCHO m, y con la fachada alineada a la de las vecinas, detras del espacio de la cochera. La
gasolinera va en la avenida, la purificadora en una calle antes que las casas, y los puestos y el
punto en huecos que dejen las casas junto a la banqueta, nunca detras de la malla de un baldio.
"""
import argparse
import json
import math
import os
import random
import xml.etree.ElementTree as ET

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MAPA = os.path.join(RAIZ, "resources", "map")
SALIDA = os.path.join(MAPA, "santa_mugre_psm")
X0, Z0, X1, Z1 = -420.0, 258.0, -185.0, 482.0
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
FONDO_TOPE = 16.0      # lo mas que se busca detras de un frente (la gasolinera)
# Las casas se amplian hacia atras (un cuarto de un piso, MapCasas "ampliacion") hasta tocar la de
# espaldas, a la mitad de la manzana, sin pasar de este fondo de lote ni encimarse con nada
FONDO_LOTE = 24.0
PASO_AMPLIA = 0.5
COCHERA = 5.0          # de la banqueta a la fachada
FONDO_CASA = 7.0       # de la fachada al fondo
# Las casa-local de scripts/map/MapPuntos.gd (GIROS_LOCAL)
CASITAS = {"abarrotes", "licoreria", "farmacia", "ferreteria", "oxxo", "taqueria"}
# Las mallas de baldio corren un poco metidas en la banqueta: lo que va en un hueco no puede tener una
# a menos de esto (m) frente a si
MALLA_FRENTE = 1.5
# Lo de Alan que se pone en la escena (x0, z0, x1, z1): la parroquia, su atrio y el kiosco
ALAN = [(-313.0, 405.0, -283.0, 435.0), (-322.0, 408.0, -310.0, 432.0), (-353.0, 396.0, -337.0, 412.0)]
VARIANTES = {1: (["psm_1p_a", "psm_1p_b", "psm_1p_c"], ["psm_1p_tablones", "psm_1p_barrotes", "psm_1p_persiana"]),
             2: (["psm_2p_a", "psm_2p_b", "psm_2p_c"], ["psm_2p_tablones", "psm_2p_barrotes", "psm_2p_persiana"])}
# prepare_osm.CASA_PALETTE
COLORES = ["#e8d7b9", "#5b8fd9", "#a47ad1", "#f2c94c", "#3fa7b5", "#d9608f", "#e05a47", "#f2994a", "#f7f4ec", "#7cc06a"]
COLONIA = "PARQUES DE SANTA MARIA"
# [tipo, giro, nombre, frente, fondo, aire libre, donde]: "avenida" (de frente a una tertiary o mas),
# "hilera" (en una calle, antes que las casas), "casa" (en lugar de una casa al azar; frente y fondo
# los de la casa), "plaza" (dentro del pasto de la plaza, junto a la banqueta) o "hueco" (despues de
# las casas, donde quede lugar)
FALTANTES = [
    ["gasolinera", "gasolinera", "Gasolinera Santa Maria", 14.0, 16.0, False, "avenida"],
    ["abarrotes", "abarrotes", "Abarrotes", 6.0, 10.0, False, "casa"],
    ["licoreria", "licoreria", "Deposito La Guera", 6.0, 10.0, False, "casa"],
    ["farmacia", "farmacia", "Farmacia", 7.0, 10.0, False, "casa"],
    ["ferreteria", "ferreteria", "Ferreteria", 6.0, 10.0, False, "casa"],
    ["oxxo", "oxxo", "Oxo", 7.0, 10.0, False, "casa"],
    ["taqueria", "taqueria", "Taqueria", 6.5, 10.0, False, "casa"],
    ["purificadora", "purificadora", "Purificadora Agua Bendita", 7.0, 10.0, False, "hilera"],
    ["puesto_tacos", "puesto_tacos", "Tacos El Guero", 2.6, 1.6, True, "hueco"],
    ["puesto", "tejuino", "Tejuino", 2.5, 2.0, True, "hueco"],
    ["punto", "punto", "El punto", 3.0, 2.0, True, "hueco"],
]
AVENIDAS = {"primary", "secondary", "tertiary"}


def dentro(x, z):
    return X0 <= x <= X1 and Z0 <= z <= Z1


def leer(ruta):
    return json.load(open(ruta, encoding="utf-8"))


def escribir(nombre, datos):
    json.dump(datos, open(os.path.join(SALIDA, nombre), "w", encoding="utf-8"), ensure_ascii=False, indent="\t")


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
        if pts and any(X0 - 60 <= x <= X1 + 60 and Z0 - 60 <= z <= Z1 + 60 for x, z in pts):
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
        nx, nz = -dz / l, dx / l           # con x al este y z al sur, a la derecha
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


class Hileras:
    def __init__(self, vias, puntos):
        self.calles = []          # [(tipo, puntos)]
        self.rect_calles = []
        self.estorbos = []        # poligonos convexos
        self.areas = []           # poligonos (no convexos) donde no va casa: pasto, plazas
        for t, pts in vias:
            h = t.get("highway")
            if h in ANCHO_CALLE:
                m = medio_ancho(t)
                self.rect_calles += tramos(pts, *m)
                if h in CON_CASAS:
                    self.calles.append((h, pts, m))
            elif "building" in t and len(pts) >= 3:
                self.estorbos.append(casco(pts))
            elif t.get("barrier") == "wall":
                self.estorbos += tramos(pts, 0.2)
            elif (t.get("landuse") == "grass" or t.get("place") == "square" or "leisure" in t) and len(pts) >= 4:
                self.areas.append(pts[:-1] if pts[0] == pts[-1] else pts)
        for x0, z0, x1, z1 in ALAN:
            self.estorbos.append([(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
        self.casitas = [p for p in puntos if p["tipo"] in CASITAS]
        for p in puntos:
            if p["tipo"] in CASITAS:
                continue
            r = p.get("rotacion_y", 0.0)
            ux, uz = math.sin(r), math.cos(r)
            f = p.get("fondo", 8.0)
            # (x, z) es el centro del local; la fachada, fondo / 2 hacia +Z
            self.estorbos.append(caja(p["x"] + ux * f / 2, p["z"] + uz * f / 2, ux, uz, p.get("ancho", 6.0) + 0.5, f))
        self.puestas = []
        self.casas = []

    def fondo_libre(self, cx, cz, ux, uz, tope=FONDO_TOPE):
        """Cuanto fondo cabe antes de topar con otra calle: la mitad si la manzana es angosta."""
        for d10 in range(10, int(tope * 20) - 20, 5):
            d = d10 / 10
            q = caja(cx - ux * d, cz - uz * d, ux, uz, ANCHO * 0.6, 0.2)
            if any(se_tocan(q, r) for r in self.rect_calles):
                return min(tope, d / 2)
        return tope

    def cabe(self, cx, cz, ux, uz, ancho=ANCHO, fondo_min=FONDO_MIN, en_plaza=False):
        fondo = self.fondo_libre(cx, cz, ux, uz)
        if fondo < fondo_min:
            return False
        fondo = fondo_min if ancho != ANCHO else min(fondo, FONDO)
        r = caja(cx - ux * 0.02, cz - uz * 0.02, ux, uz, ancho - 0.06, fondo - 0.04)
        mx, mz = sum(q[0] for q in r) / 4, sum(q[1] for q in r) / 4
        en_area = [any(en_poligono(x, z, a) for a in self.areas) for x, z in r + [(mx, mz)]]
        if (not all(en_area)) if en_plaza else any(en_area):
            return False
        if any(se_tocan(r, e) for e in self.estorbos) or any(se_tocan(r, q) for q in self.rect_calles) \
                or any(se_tocan(r, q) for q in self.puestas):
            return False
        self.puestas.append(r)
        return True

    def poner(self, azar, cx, cz, ux, uz):
        pisos = 1 if azar.random() < 0.66 else 2
        sin_reja, con_reja = VARIANTES[pisos]
        modelo = azar.choice(con_reja if azar.random() < 0.66 else sin_reja)
        self.casas.append({"modelo": modelo, "x": round(cx, 2), "z": round(cz, 2),
                           "rotacion_y": round(math.atan2(ux, uz), 4), "ancho": ANCHO, "fondo": FONDO,
                           "pisos": pisos, "color": azar.choice(COLORES), "colonia": COLONIA})

    def lugares(self, tipos, ancho, paso):
        """Frentes posibles: (centro del frente, hacia la calle) cada `paso` m por los dos lados de las
        calles de esos tipos, dentro del recorte."""
        for h, pts, m in self.calles:
            if h not in tipos:
                continue
            for a, b in zip(pts, pts[1:]):
                dx, dz = b[0] - a[0], b[1] - a[1]
                l = math.hypot(dx, dz)
                ex, ez = dx / max(l, 1e-6), dz / max(l, 1e-6)
                for lado in (1, -1):
                    ux, uz = -ez * lado, ex * lado
                    t = ancho / 2
                    while t + ancho / 2 <= l:
                        cx, cz = a[0] - ux * m[lado > 0] + ex * t, a[1] - uz * m[lado > 0] + ez * t
                        if dentro(cx - ux * 3, cz - uz * 3):
                            yield cx, cz, ux, uz
                        t += paso

    def negocio(self, azar, n, mas):
        tipo, giro, nombre, ancho, fondo, aire, donde = n
        tipos = AVENIDAS if donde == "avenida" else CON_CASAS
        sitios = list(self.lugares(tipos, ancho, 1.0))
        azar.shuffle(sitios)
        for cx, cz, ux, uz in sitios:
            if donde == "hueco" and any(se_tocan(caja(cx + ux * MALLA_FRENTE, cz + uz * MALLA_FRENTE, ux, uz, ancho,
                                                      fondo + MALLA_FRENTE), r) for r in self.rect_bardas):
                continue
            if donde == "plaza":
                # adentro del pasto, a medio metro de la banqueta
                cx, cz = cx - ux * 0.5, cz - uz * 0.5
            if self.cabe(cx, cz, ux, uz, ancho, fondo, donde == "plaza"):
                mas.append({"tipo": tipo, "nombre": nombre, "x": round(cx - ux * fondo / 2, 2),
                            "z": round(cz - uz * fondo / 2, 2), "rotacion_y": round(math.atan2(ux, uz), 4),
                            "ancho": ancho, "fondo": fondo, "casa_reemplazada": None, "origen": "santa_mugre_psm",
                            "pisos": 1, "giro": giro, "aire_libre": aire, "interactivo": False})
                return True
        print("no cupo:", nombre)
        return False

    def en_casa(self, punto, casa):
        """Pone el local en el lote de la casa (y la quita): su frente, la fachada donde la de ella."""
        self.casas.remove(casa)
        r = casa["rotacion_y"]
        ux, uz = math.sin(r), math.cos(r)
        atras = COCHERA + FONDO_CASA / 2
        punto.update({"x": round(casa["x"] - ux * atras, 2), "z": round(casa["z"] - uz * atras, 2), "rotacion_y": r,
                      "ancho": ANCHO, "fondo": FONDO_CASA, "pisos": casa["pisos"], "casa_reemplazada": None})

    def armar(self, faltan, bardas):
        azar = random.Random(SEMILLA)
        mas = []
        for n in faltan:
            if n[6] not in ("hueco", "casa"):
                self.negocio(azar, n, mas)
        self.casas_en_hileras(azar)
        # Las casitas del DENUE, en la casa mas cercana a donde estaban (a su frente); las que faltan,
        # en una al azar
        for p in self.casitas:
            r = p.get("rotacion_y", 0.0)
            fx, fz = p["x"] + math.sin(r) * p["fondo"] / 2, p["z"] + math.cos(r) * p["fondo"] / 2
            self.en_casa(p, min(self.casas, key=lambda c: math.hypot(c["x"] - fx, c["z"] - fz)))
        for n in faltan:
            if n[6] == "casa":
                p = {"tipo": n[0], "nombre": n[2], "origen": "santa_mugre_psm", "giro": n[1], "aire_libre": n[5],
                     "interactivo": False}
                self.en_casa(p, azar.choice(self.casas))
                mas.append(p)
        # Las bardas de baldio que no quedaron dentro de una casa se quedan, y lo que va en un hueco
        # no puede quedar detras de su malla
        toca = lambda e: any(se_tocan(t, r) for t in tramos(e["puntos"], 0.2) for r in self.puestas)
        self.bardas = [e for e in bardas if any(dentro(*pt) for pt in e["puntos"]) and not toca(e)]
        self.rect_bardas = [r for e in self.bardas for r in tramos(e["puntos"], 0.3)]
        self.estorbos += self.rect_bardas
        self.ampliar()
        for n in faltan:
            if n[6] == "hueco":
                self.negocio(azar, n, mas)
        return self.casas, mas

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
                if any(any(en_poligono(x, z, a) for a in self.areas) for x, z in q) \
                        or any(se_tocan(q, e) for e in self.estorbos) or any(se_tocan(q, e) for e in self.rect_calles) \
                        or any(se_tocan(q, e) for e in self.puestas):
                    break
                d += PASO_AMPLIA
            if d - FONDO >= 1.0:
                c["ampliacion"] = round(d - FONDO, 2)
                self.puestas.append(caja(cx - ux * (FONDO + 0.03), cz - uz * (FONDO + 0.03), ux, uz, ANCHO - 0.06,
                                         d - FONDO - 0.06))

    def casas_en_hileras(self, azar):
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
                        if dentro(cx - ux * 6, cz - uz * 6) and self.cabe(cx, cz, ux, uz):
                            self.poner(azar, cx, cz, ux, uz)
                            t += ANCHO
                        else:
                            t += 0.5        # no cupo: se recorre medio metro y prueba otra vez


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--osm", required=True)
    p.add_argument("--puntos", required=True)
    p.add_argument("--bardas", required=True)
    a = p.parse_args()
    os.makedirs(SALIDA, exist_ok=True)
    puntos = [dict(q, interactivo=False) for q in leer(a.puntos)["puntos"] if dentro(q["x"], q["z"])]
    h = Hileras(leer_osm(a.osm), puntos)
    hay = {q["tipo"] if q["tipo"] != "puesto" else q.get("giro") for q in puntos}
    faltan = [n for n in FALTANTES if (n[0] if n[0] != "puesto" else n[1]) not in hay]
    casas, mas = h.armar(faltan, leer(a.bardas)["bardas"])
    puntos += mas
    print("negocios agregados:", ", ".join(q["nombre"] for q in mas))
    # Los arboles que quedarian dentro de una casa
    pisado = lambda x, z: any(en_poligono(x, z, r) for r in h.puestas)
    arboles = [t for t in leer(os.path.join(MAPA, "arboles_mapa.json"))["arboles"]
               if dentro(t[0], t[1]) and not pisado(t[0], t[1])]
    postes = [q for q in leer(os.path.join(MAPA, "alumbrado_mapa.json"))["postes"] if dentro(q["x"], q["z"])]
    bardas = {"bardas": h.bardas, "plumas": [], "casetas": []}
    cuadros = [c for c in leer(os.path.join(MAPA, "cuadros", "indice.json"))["cuadros"]
               if c["min_x"] <= X1 and c["max_x"] >= X0 and c["min_z"] <= Z1 and c["max_z"] >= Z0]
    escribir("casas.json", {"casas": casas})
    escribir("puntos.json", {"puntos": puntos})
    escribir("arboles.json", {"arboles": arboles})
    escribir("alumbrado.json", {"postes": postes})
    escribir("bardas.json", bardas)
    escribir("indice.json", {"cuadros": cuadros})
    un_piso = sum(c["pisos"] == 1 for c in casas)
    reja = sum(not c["modelo"][-2:] in ("_a", "_b", "_c") for c in casas)
    print("casas %d (%d %% de un piso, %d %% con reja), puntos %d, arboles %d, postes %d, bardas %d, cuadros %d" % (
        len(casas), 100 * un_piso // max(1, len(casas)), 100 * reja // max(1, len(casas)), len(puntos),
        len(arboles), len(postes), len(bardas["bardas"]), len(cuadros)))


if __name__ == "__main__":
    main()
