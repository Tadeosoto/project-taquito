# Arma la escena de una colonia desde su .json (tools/blender/mapa/colonias/<nombre>.json) y
# regresa al .json lo que se movio a mano. El .json es la fuente: la escena se puede tirar y
# rehacer cuando sea.
#
# En Blender (o por el MCP):
#   COLONIA = "santa_mugre"; exec(open(r"...\tools\blender\mapa\colonia.py", encoding="utf-8").read())
# arma la escena "Colonia_santa_mugre". Para traer los cambios hechos a mano:
#   SOLO_FUNCIONES = True; exec(...); leer("santa_mugre")
#
# Lo que entiende el .json (todo en metros del juego, giros en radianes como en Godot):
#   "recorte": [x1, z1, x2, z2]      el piso de la colonia (con su caja de choque)
#   "piezas": todas con "nombre", "tipo", "x", "z", "rot" y opcionales "color" [r, g, b], "y"
#     (altura de la base) y "auto" (true = la puso bloqueo.py, que la rehace al correr otra vez):
#     caja      "tam": [ancho, alto, fondo]; con choque
#     cilindro  "radio", "alto"; con choque
#     edificio  "puntos": [[x, z]...] relativos a (x, z), la huella; "alto"; con choque
#     suelo     "puntos": la mancha plana (pasto de la plaza, un baldio); sin choque
#     calle     "puntos": el eje, "ancho" del arroyo y "banqueta" de cada lado; sin choque (va
#               pintada sobre el piso)
#   "marcas": [{"nombre", "tipo": "spawn" | "puerta", "x", "z", "rot", ...}]
#     puerta: "giro" (llave de Interiores.escenas) y "texto" (el nombre del negocio); su +Z da a
#     la calle, como la flecha de las tiendas. Las marcas no van al .glb: exportar.py las escribe
#     en resources/mapa/<colonia>/marcas.json y scripts/mapa/Colonia.gd las arma en Godot.

import bpy
import math

_c = {"__name__": "comun"}
exec(open(r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\mapa\comun.py", encoding="utf-8").read(), _c)
globals().update({k: v for k, v in _c.items() if not k.startswith("__")})

PISO_COLOR = (0.32, 0.32, 0.30)
GRIS = (0.6, 0.6, 0.6)
PISO_GRUESO = 0.5


def nombre_escena(nombre):
    return "Colonia_" + nombre


def armar(nombre):
    datos = leer_colonia(nombre)
    sc = escena(nombre_escena(nombre))
    mundo = coleccion(sc, MUNDO)
    marcas = coleccion(sc, MARCAS)

    x1, z1, x2, z2 = datos["recorte"]
    ancho, fondo = x2 - x1, z2 - z1
    cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
    piso = caja(mundo, "Piso", cx, cz, 0.0, (ancho, PISO_GRUESO, fondo), material("piso", PISO_COLOR),
                y=-PISO_GRUESO, choca=True)
    piso[DATO] = "piso"

    for p in datos.get("piezas", []):
        ob = _pieza(mundo, p)
        if ob is None:
            print("colonia: tipo de pieza desconocido", p["tipo"], p["nombre"])
        else:
            ob[DATO] = "pieza:" + p["nombre"]

    for m in datos.get("marcas", []):
        ob = vacio(marcas, m["nombre"], m["x"], m["z"], m.get("rot", 0.0), tamano=1.5)
        ob[DATO] = "marca:" + m["nombre"]

    print("colonia %s: %d piezas, %d marcas" % (nombre, len(datos.get("piezas", [])), len(datos.get("marcas", []))))
    return sc


def _mat(p, defecto=GRIS):
    color = p.get("color", defecto)
    return material("liso_" + "_".join("%02d" % int(c * 99) for c in color), color)


def _pieza(col, p):
    tipo, nombre = p["tipo"], p["nombre"]
    x, z, rot, y = p["x"], p["z"], p.get("rot", 0.0), p.get("y", 0.0)
    if tipo == "caja":
        return caja(col, nombre, x, z, rot, p["tam"], _mat(p), y=y)
    if tipo == "cilindro":
        return _objeto(col, nombre, _malla_cilindro(nombre, p["radio"], p["alto"]), x, z, rot, y, _mat(p), True)
    if tipo == "edificio":
        return _objeto(col, nombre, _malla_prisma(nombre, p["puntos"], p["alto"]), x, z, rot, y, _mat(p), True)
    if tipo == "suelo":
        return _objeto(col, nombre, _malla_plana(nombre, p["puntos"], 0.03), x, z, rot, y, _mat(p, (0.3, 0.42, 0.25)), False)
    if tipo == "calle":
        return _calle(col, p)
    return None


def _objeto(col, nombre, malla, x, z, rot, y, mat, choca):
    malla.materials.append(mat)
    ob = bpy.data.objects.new(nombre, malla)
    ob.location = a_blender(x, z, y)
    ob.rotation_euler = (0.0, 0.0, rot)
    col.objects.link(ob)
    if choca:
        sombra = bpy.data.objects.new(nombre + "-colonly", malla.copy())
        sombra.location, sombra.rotation_euler = ob.location, ob.rotation_euler
        sombra.display_type = "WIRE"
        col.objects.link(sombra)
    return ob


def _local(puntos):
    """[x, z] de Godot -> (x, y) de Blender, en sentido antihorario visto desde arriba."""
    pts = [(px, -pz) for px, pz in puntos]
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))
    return pts if area > 0 else pts[::-1]


def _malla_prisma(nombre, puntos, alto):
    bm = bmesh.new()
    abajo = [bm.verts.new((px, py, 0.0)) for px, py in _local(puntos)]
    base = bm.faces.new(abajo)
    hecho = bmesh.ops.extrude_face_region(bm, geom=[base])
    arriba = [v for v in hecho["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=arriba, vec=(0.0, 0.0, alto))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    return malla


def _malla_plana(nombre, puntos, alto):
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((px, py, alto)) for px, py in _local(puntos)])
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    return malla


def _malla_cilindro(nombre, radio, alto, lados=12):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=lados, radius1=radio, radius2=radio, depth=alto)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=(0.0, 0.0, alto / 2))
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    return malla


ASFALTO = (0.16, 0.16, 0.17)
BANQUETA = (0.55, 0.53, 0.5)


def _calle(col, p):
    """Arroyo (oscuro) sobre su banqueta (clara), en franjas por tramo. Las esquinas se enciman."""
    bm = bmesh.new()
    capas = [(p["ancho"] / 2 + p.get("banqueta", 1.5), 0.01, 1), (p["ancho"] / 2, 0.02, 0)]
    pts = p["puntos"]
    for medio, alto, indice in capas:
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            dx, dz = bx - ax, bz - az
            largo = math.hypot(dx, dz) or 1.0
            # Se alarga medio ancho de banqueta en cada punta para tapar la esquina
            ex, ez = dx / largo * (medio if indice else 0.0), dz / largo * (medio if indice else 0.0)
            nx, nz = -dz / largo * medio, dx / largo * medio
            esquinas = [(ax - ex + nx, az - ez + nz), (bx + ex + nx, bz + ez + nz), (bx + ex - nx, bz + ez - nz), (ax - ex - nx, az - ez - nz)]
            cara = bm.faces.new([bm.verts.new((bx_, by_, alto)) for bx_, by_ in _local(esquinas)])
            cara.material_index = indice
    malla = bpy.data.meshes.new(p["nombre"])
    bm.to_mesh(malla)
    bm.free()
    malla.materials.append(material("asfalto", ASFALTO))
    malla.materials.append(material("banqueta", BANQUETA))
    ob = bpy.data.objects.new(p["nombre"], malla)
    ob.location = a_blender(p["x"], p["z"], p.get("y", 0.0))
    col.objects.link(ob)
    return ob


def leer(nombre):
    """Lo movido a mano en Blender (piezas y marcas) regresa al .json."""
    datos = leer_colonia(nombre)
    sc = bpy.data.scenes[nombre_escena(nombre)]
    piezas = {p["nombre"]: p for p in datos.get("piezas", [])}
    marcas = {m["nombre"]: m for m in datos.get("marcas", [])}
    cambios = 0
    for ob in sc.objects:
        dato = ob.get(DATO, "")
        if ":" not in dato:
            continue
        clase, clave = dato.split(":", 1)
        entrada = (piezas if clase == "pieza" else marcas).get(clave)
        if entrada is None:
            continue
        x, _y, z = a_godot(ob.location)
        rot = giro_de_vacio(ob) if clase == "marca" else ob.rotation_euler.z
        nuevo = {"x": round(x, 2), "z": round(z, 2), "rot": round(math.remainder(rot, math.tau), 4)}
        if any(abs(entrada.get(k, 0.0) - v) > 0.005 for k, v in nuevo.items()):
            entrada.update(nuevo)
            cambios += 1
    guardar_json(ruta_colonia(nombre), datos)
    print("colonia %s: %d cambios al .json" % (nombre, cambios))
    return cambios


if not globals().get("SOLO_FUNCIONES"):
    armar(globals().get("COLONIA", "santa_mugre"))
