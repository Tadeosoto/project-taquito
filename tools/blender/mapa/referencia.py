# Guia para bloquear una colonia: las calles de OSM (data/map/area.osm, ODbL) y las huellas de
# Google Open Buildings (data/map/google_buildings.csv) que caen en su recorte, como lineas
# planas en la coleccion "Referencia" de la escena de la colonia. Nunca se exporta.
# Misma proyeccion que tools/map_import/prepare_osm.py (local_xz): Mercator escalada por
# cos(lat0), origen en el centro del rectangulo de tools/map_import/area.env.
#
#   COLONIA = "santa_mugre"; exec(open(r"...\tools\blender\mapa\referencia.py", encoding="utf-8").read())
# (despues de colonia.py: se agrega a su escena)

import os
import bpy
import csv
import math
import re
import xml.etree.ElementTree as ET

_c = {"__name__": "comun"}
exec(open(os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "mapa", "comun.py"), encoding="utf-8").read(), _c)
globals().update({k: v for k, v in _c.items() if not k.startswith("__")})

OSM = os.path.join(RAIZ, "data", "map", "area.osm")
EDIFICIOS = os.path.join(RAIZ, "data", "map", "google_buildings.csv")
AREA = os.path.join(RAIZ, "tools", "map_import", "area.env")
RADIO_TIERRA = 6378137.0
CONFIANZA_MIN = 0.65
MARGEN = 30.0          # m de mas alrededor del recorte
# Ancho de calle por tipo de OSM (m), solo para la guia
ANCHOS = {"primary": 14.0, "secondary": 12.0, "tertiary": 10.0, "residential": 8.0,
          "living_street": 6.0, "service": 4.0, "footway": 2.0, "path": 2.0}


def _proyeccion():
    area = {}
    for linea in open(AREA, encoding="utf-8"):
        if "=" in linea and not linea.startswith("#"):
            k, v = linea.strip().split("=", 1)
            area[k] = float(v)
    lat0 = (area["SOUTH"] + area["NORTH"]) / 2
    lon0 = (area["WEST"] + area["EAST"]) / 2
    escala = math.cos(math.radians(lat0))
    merc = lambda la: RADIO_TIERRA * math.log(math.tan(math.pi / 4 + math.radians(la) / 2))
    y0 = merc(lat0)
    return lambda la, lo: (RADIO_TIERRA * math.radians(lo - lon0) * escala, -(merc(la) - y0) * escala)


def _malla(col, nombre, lineas, y, color, caras=None):
    verts, aristas = [], []
    for linea in lineas:
        base = len(verts)
        verts += [tuple(a_blender(x, z, y)) for x, z in linea]
        aristas += [(base + i, base + i + 1) for i in range(len(linea) - 1)]
    malla = bpy.data.meshes.new(nombre)
    malla.from_pydata(verts, aristas, caras or [])
    ob = bpy.data.objects.new(nombre, malla)
    ob.color = (color[0], color[1], color[2], 1.0)
    ob.hide_render = True
    col.objects.link(ob)
    return ob


def _franjas(lineas_anchos):
    """Cada calle como una franja plana de su ancho (caras), para ver el espacio que ocupa."""
    verts, caras = [], []
    for linea, ancho in lineas_anchos:
        for (ax, az), (bx, bz) in zip(linea, linea[1:]):
            dx, dz = bx - ax, bz - az
            largo = math.hypot(dx, dz) or 1.0
            nx, nz = -dz / largo * ancho / 2, dx / largo * ancho / 2
            base = len(verts)
            for x, z in ((ax + nx, az + nz), (bx + nx, bz + nz), (bx - nx, bz - nz), (ax - nx, az - nz)):
                verts.append(tuple(a_blender(x, z, 0.02)))
            caras.append((base, base + 1, base + 2, base + 3))
    return verts, caras


def datos_osm(recorte, margen=MARGEN):
    """Lo real que cae en el recorte (+ margen): calles [{puntos, ancho, tipo, nombre, sentido}],
    areas de OSM con etiqueta [{puntos, etiquetas}] y huellas de edificios [[(x, z)...]]."""
    x1, z1, x2, z2 = recorte
    dentro = lambda x, z: x1 - margen < x < x2 + margen and z1 - margen < z < z2 + margen
    proyecta = _proyeccion()
    raiz = ET.parse(OSM).getroot()
    nodos = {n.get("id"): proyecta(float(n.get("lat")), float(n.get("lon"))) for n in raiz.findall("node")}
    calles, areas = [], []
    for via in raiz.findall("way"):
        etiquetas = {t.get("k"): t.get("v") for t in via.findall("tag")}
        puntos = [nodos[nd.get("ref")] for nd in via.findall("nd") if nd.get("ref") in nodos]
        if "highway" not in etiquetas:
            if len(puntos) > 2 and any(dentro(x, z) for x, z in puntos) and etiquetas:
                areas.append({"puntos": puntos, "etiquetas": etiquetas})
            continue
        # Solo los tramos que tocan el recorte (un punto de afuera en cada punta)
        tramo = []
        for i, (x, z) in enumerate(puntos):
            cerca = dentro(x, z) or (i > 0 and dentro(*puntos[i - 1])) or (i + 1 < len(puntos) and dentro(*puntos[i + 1]))
            if cerca:
                tramo.append((x, z))
            if (not cerca or i + 1 == len(puntos)) and len(tramo) > 1:
                calles.append({"puntos": tramo, "ancho": ANCHOS.get(etiquetas["highway"], 5.0),
                               "tipo": etiquetas["highway"], "nombre": etiquetas.get("name", ""),
                               "sentido": etiquetas.get("oneway") == "yes"})
            if not cerca:
                tramo = []
    huellas = []
    with open(EDIFICIOS, encoding="utf-8") as f:
        for fila in csv.DictReader(f):
            if float(fila["confidence"]) < CONFIANZA_MIN:
                continue
            pares = re.findall(r"(-?\d+\.\d+) (-?\d+\.\d+)", fila["geometry"])
            puntos = [proyecta(float(la), float(lo)) for lo, la in pares]
            if puntos and puntos[0] == puntos[-1]:
                puntos = puntos[:-1]
            if any(dentro(x, z) for x, z in puntos):
                huellas.append(puntos)
    return calles, areas, huellas


def importar(nombre):
    datos = leer_colonia(nombre)
    sc = bpy.data.scenes["Colonia_" + nombre]   # la arma colonia.py
    for hija in list(sc.collection.children):
        if hija.name.startswith(REFERENCIA):
            for ob in list(hija.objects):
                bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.collections.remove(hija)
    col = coleccion(sc, REFERENCIA)
    calles_osm, _areas, huellas = datos_osm(datos["recorte"])
    calles = [(c["puntos"], c["ancho"]) for c in calles_osm]
    nombres = [(c["nombre"], c["puntos"][len(c["puntos"]) // 2]) for c in calles_osm if c["nombre"]]
    _malla(col, "Ref_Ejes", [p for p, _ in calles], 0.04, (1.0, 0.9, 0.2))
    verts, caras = _franjas(calles)
    malla = bpy.data.meshes.new("Ref_Calles")
    malla.from_pydata(verts, [], caras)
    ob = bpy.data.objects.new("Ref_Calles", malla)
    ob.color = (0.75, 0.72, 0.6, 1.0)
    ob.hide_render = True
    col.objects.link(ob)
    for texto, (x, z) in nombres:
        letrero = bpy.data.objects.new("Ref_" + texto, None)
        letrero.empty_display_type = "PLAIN_AXES"
        letrero.location = a_blender(x, z, 0.5)
        col.objects.link(letrero)
    _malla(col, "Ref_Huellas", [h + h[:1] for h in huellas], 0.06, (0.9, 0.3, 0.3))
    # En modo solido, el color de cada objeto
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type == "VIEW_3D":
            area.spaces[0].shading.color_type = "OBJECT"
    print("referencia %s: %d calles, %d huellas" % (nombre, len(calles), len(huellas)))


if not globals().get("SOLO_FUNCIONES"):
    importar(globals().get("COLONIA", "santa_mugre"))
