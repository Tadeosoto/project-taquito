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
#     edificio  "puntos": [[x, z]...] relativos a (x, z), la huella; "alto"; con choque (gris)
#     casa      "puntos" (la huella), "pisos", "color" (nombre de kit.PALETA o [r, g, b]),
#               "frente" (indice del lado que da a la calle: del punto i al i+1), "desgaste" 0-1,
#               "tienda" (cortina en la planta baja), "tinaco"; con choque (kit.casa_malla)
#     suelo     "puntos": la mancha plana (pasto de la plaza, un baldio); sin choque
#     calle     "puntos": el eje, "ancho" del arroyo y "banqueta" de cada lado; sin choque (va
#               pintada sobre el piso). "material" (asfalto) y "material_banqueta" (banqueta)
#               son pisos de kit.PISOS: un andador de la plaza es una calle de banqueta
#     kiosco, puesto, banca, jardinera, fuente, parroquia, palacio
#               piezas armadas de piezas.py, con sus parametros (ver cada funcion)
#   "marcas": [{"nombre", "tipo": "spawn" | "puerta", "x", "z", "rot", ...}]
#     puerta: "giro" (llave de Interiores.escenas) y "texto" (el nombre del negocio); su +Z da a
#     la calle, como la flecha de las tiendas. Las marcas no van al .glb: exportar.py las escribe
#     en resources/mapa/<colonia>/marcas.json y scripts/mapa/Colonia.gd las arma en Godot.

import os
import bpy
import math

_c = {"__name__": "comun"}
exec(open(os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "mapa", "comun.py"), encoding="utf-8").read(), _c)
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
    # El piso entre casas es concreto, como la banqueta (en Godot, ps1_suelo con banqueta.png)
    piso = caja(mundo, "Piso", cx, cz, 0.0, (ancho, PISO_GRUESO, fondo), _kit()["mat_piso"]("banqueta"),
                y=-PISO_GRUESO, choca=True)
    piso[DATO] = "piso"

    _arroyos(datos)
    for p in datos.get("piezas", []):
        ob = _pieza(mundo, p)
        if ob is None:
            print("colonia: tipo de pieza desconocido", p["tipo"], p["nombre"])
        else:
            ob[DATO] = "pieza:" + p["nombre"]

    _postes_y_cables(sc, mundo, datos.get("postes", []))

    for m in datos.get("marcas", []):
        ob = vacio(marcas, m["nombre"], m["x"], m["z"], m.get("rot", 0.0), tamano=1.5)
        ob[DATO] = "marca:" + m["nombre"]

    print("colonia %s: %d piezas, %d marcas" % (nombre, len(datos.get("piezas", [])), len(datos.get("marcas", []))))
    return sc


_KIT = {}


def _kit():
    """kit.py, cargado una vez por armada."""
    if not _KIT:
        _KIT.update({"__name__": "kit", "SOLO_FUNCIONES": True})
        exec(open(os.path.join(MAPA, "kit.py"), encoding="utf-8").read(), _KIT)
    return _KIT


_PIEZAS = {}


def _piezas():
    """piezas.py (los lugares y adornos armados), cargado una vez por armada."""
    if not _PIEZAS:
        _PIEZAS.update({"__name__": "piezas"})
        exec(open(os.path.join(MAPA, "piezas.py"), encoding="utf-8").read(), _PIEZAS)
    return _PIEZAS


_PSM = {}


def _psm():
    """casa_psm.py (la casa base de Parques de Santa Maria), cargado una vez por armada. Deja su atlas
    en textures/mapa/casa_psm_atlas.png, que MapaPostImport le pone en Godot (el .glb va sin imagenes)."""
    if not _PSM:
        _PSM.update({"__name__": "casa_psm"})
        exec(open(os.path.join(MAPA, "casa_psm.py"), encoding="utf-8").read(), _PSM)
        _PSM["guardar_atlas"](os.path.join(RAIZ, "textures", "mapa", "casa_psm_atlas.png"))
    return _PSM


def _casa_psm(col, p):
    """La casa PSM (sustituir_psm.py) sobre la huella de la pieza: la fachada en su frente (o `retiro` m
    adentro), de su ancho y del fondo que queda, con la cochera de `cochera` m hacia la calle (0: sin
    cochera). La malla se arma desde el centro de la huella, como la de una casa, para que leer() la
    regrese igual."""
    from mathutils import Matrix
    k, psm = _kit(), _psm()
    color = p.get("color", "crema")
    color = k["PALETA"].get(color, (0.8, 0.8, 0.8)) if isinstance(color, str) else color
    a, b, _centro, (nx, nz), fondo = frente_de(p)
    ancho = math.hypot(b[0] - a[0], b[1] - a[1])
    cochera, retiro = p.get("cochera", 0.0), p.get("retiro", 0.0)
    fondo -= retiro
    pisos = min(p.get("pisos", 1), 2)
    ob = psm["casa_psm"](p["nombre"], pisos=pisos, color=color, puerta=p.get("puerta", "blanca"), lote=cochera > 0,
                         espejo=p.get("espejo", False), reja=p.get("reja") if cochera > 0 else None,
                         reja_color=p.get("reja_color", "negro"), herreria=p.get("herreria", "blanca"),
                         fondo=fondo, ancho=ancho, cochera=cochera or psm["COCHERA"])
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    col.objects.link(ob)
    # De la fachada (origen de casa_psm, viendo a -Y) a la pieza (centro de la huella, giro "rot")
    mx, mz = (a[0] + b[0]) / 2 - nx * retiro, (a[1] + b[1]) / 2 - nz * retiro
    giro, rot = math.atan2(nx, nz), p.get("rot", 0.0)
    dx, dz = mx - p["x"], mz - p["z"]
    lx, lz = dx * math.cos(rot) - dz * math.sin(rot), dx * math.sin(rot) + dz * math.cos(rot)
    ob.data.transform(Matrix.Translation(a_blender(lx, lz)) @ Matrix.Rotation(giro - rot, 4, "Z"))
    ob.location = a_blender(p["x"], p["z"], p.get("y", 0.0))
    ob.rotation_euler = (0.0, 0.0, rot)
    # Choque: el cuerpo de la casa hasta la losa (la azotea se camina, como las de kit)
    alto = psm["PISO1"] + (psm["PISO2"] if pisos == 2 else 0.0)
    colision(col, p["nombre"], mx - nx * fondo / 2, mz - nz * fondo / 2, giro, (ancho, alto, fondo), p.get("y", 0.0))
    return ob


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
    if tipo == "casa":
        k = _kit()
        color = p.get("color", "crema")
        color = k["PALETA"].get(color, (0.8, 0.8, 0.8)) if isinstance(color, str) else color
        malla = k["casa_malla"](nombre, p["puntos"], p.get("pisos", 1), color, p.get("frente", 0),
                                p.get("desgaste", 0.5), p.get("tienda", False), p.get("tinaco", True), p.get("varillas"))
        ob = bpy.data.objects.new(nombre, malla)
        ob.location = a_blender(x, z, y)
        ob.rotation_euler = (0.0, 0.0, rot)
        col.objects.link(ob)
        # Hasta la losa y no hasta el pretil: las azoteas se caminan (rutas por los techos)
        choque = bpy.data.objects.new(nombre + "-colonly", _malla_prisma(nombre + "_col", p["puntos"], p.get("pisos", 1) * k["PISO"] + 0.05))
        choque.location, choque.rotation_euler = ob.location, ob.rotation_euler
        choque.display_type = "WIRE"
        col.objects.link(choque)
        return ob
    if tipo == "casa_psm":
        return _casa_psm(col, p)
    piezas = _piezas()["PIEZAS"]
    if tipo in piezas:
        k = piezas[tipo](nombre, p)
        ob = bpy.data.objects.new(nombre, k.terminar())
        ob.location = a_blender(x, z, y)
        ob.rotation_euler = (0.0, 0.0, rot)
        col.objects.link(ob)
        c, s = math.cos(rot), math.sin(rot)
        for i, ((cx, cy, cz), tam, giro) in enumerate(k.choques):
            wx, wz = x + cx * c + cz * s, z - cx * s + cz * c
            colision(col, "%s_choque%d" % (nombre, i), wx, wz, rot + giro, tam, y + cy - tam[1] / 2)
        for i, puntos in enumerate(k.rampas):
            _casco(col, "%s_rampa%d" % (nombre, i), puntos, ob)
        return ob
    if tipo == "suelo":
        # Abajo de las calles y andadores (que van a 1-2 cm); "material" es un piso de kit.PISOS
        mat = _kit()["mat_piso"](p["material"]) if "material" in p else _mat(p, (0.3, 0.42, 0.25))
        return _objeto(col, nombre, _malla_plana(nombre, p["puntos"], 0.005), x, z, rot, y, mat, False)
    if tipo == "calle":
        return _calle(col, p)
    return None


def _casco(col, nombre, puntos, padre):
    """Caja de choque convexa (rampa) de puntos en coordenadas de Godot de la pieza `padre`."""
    cb = bmesh.new()
    for px, py, pz in puntos:
        cb.verts.new((px, -pz, py))
    bmesh.ops.convex_hull(cb, input=cb.verts[:])
    malla = bpy.data.meshes.new(nombre)
    cb.to_mesh(malla)
    cb.free()
    ob = bpy.data.objects.new(nombre + "-colonly", malla)
    ob.location, ob.rotation_euler = padre.location, padre.rotation_euler
    ob.display_type = "WIRE"
    col.objects.link(ob)


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


BANQUETA_ALTO = 0.15       # m de la guarnicion
BANQUETA_RAMPA = 0.26      # m que avanza el bisel de la caja de choque (30 grados): el
                           # CharacterBody3D no sube escalones, asi que la guarnicion es rampa
BANQUETA_MUESTRA = 0.5     # m entre muestras al recortar la banqueta en los cruces
# Arroyos de todas las calles en metros del mundo: (a, b, medio ancho). Los llena armar() antes
# de las piezas, para cortar cada banqueta donde atraviesa el arroyo de otra calle
_ARROYOS = []


def _arroyos(datos):
    _ARROYOS.clear()
    for p in datos.get("piezas", []):
        if p["tipo"] == "calle" and p.get("material", "asfalto") == "asfalto":
            pts = [(p["x"] + x, p["z"] + z) for x, z in p["puntos"]]
            for a, b in zip(pts, pts[1:]):
                _ARROYOS.append((a, b, p["ancho"] / 2, p["nombre"]))


def _dist_seg(px, pz, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / (dx * dx + dz * dz or 1.0)))
    return math.hypot(px - a[0] - t * dx, pz - a[1] - t * dz)


def _calle(col, p):
    """El arroyo (pintado sobre el piso, alargado en las puntas para tapar el cruce) y, si tiene
    "banqueta", las dos banquetas: losas de BANQUETA_ALTO con su guarnicion, cortadas donde
    atraviesan el arroyo de otra calle, cada tramo con su caja de choque en rampa."""
    bm = bmesh.new()
    pts = p["puntos"]
    ox, oz = p["x"], p["z"]
    medio = p["ancho"] / 2
    banq = p.get("banqueta", 1.5)
    for k_seg, ((ax, az), (bx, bz)) in enumerate(zip(pts, pts[1:])):
        dx, dz = bx - ax, bz - az
        largo = math.hypot(dx, dz) or 1.0
        ux, uz = dx / largo, dz / largo
        ex = medio if banq > 0 else 0.0
        nx, nz = -uz * medio, ux * medio
        esquinas = [(ax - ux * ex + nx, az - uz * ex + nz), (bx + ux * ex + nx, bz + uz * ex + nz),
                    (bx + ux * ex - nx, bz + uz * ex - nz), (ax - ux * ex - nx, az - uz * ex - nz)]
        cara = bm.faces.new([bm.verts.new((x_, y_, 0.02)) for x_, y_ in _local(esquinas)])
        cara.material_index = 0
        if banq <= 0:
            continue
        # Banquetas: una por lado, de medio a medio + banq, alargadas hasta el otro arroyo
        largo_ext = banq + 6.0
        for lado in (1, -1):
            centro = medio + banq / 2
            tramos, actual = [], None
            s = -largo_ext
            while s <= largo + largo_ext:
                wx = ox + ax + ux * s - uz * lado * centro
                wz = oz + az + uz * s + ux * lado * centro
                # Fuera: sobre un arroyo que no es este tramo (otra calle o el tramo de al lado)
                libre = not any(_dist_seg(wx, wz, a, b) < m + 0.1 for a, b, m, n in _ARROYOS
                                if not (n == p["nombre"] and _misma(a, b, ox + ax, oz + az, ox + bx, oz + bz)))
                # Mas alla de las puntas de la calle solo si toca otra banqueta (no a media nada)
                if libre and (s < 0 or s > largo) and not any(_dist_seg(wx, wz, a, b) < m + banq + 0.5 for a, b, m, n in _ARROYOS if n != p["nombre"]):
                    libre = False
                if libre and actual is None:
                    actual = s
                if not libre and actual is not None:
                    tramos.append((actual, s - BANQUETA_MUESTRA))
                    actual = None
                s += BANQUETA_MUESTRA
            if actual is not None:
                tramos.append((actual, s - BANQUETA_MUESTRA))
            for s0, s1 in tramos:
                if s1 - s0 < 0.6:
                    continue
                _losa(bm, col, p, (ax, az), (ux, uz), lado, medio, medio + banq, s0, s1)
    malla = bpy.data.meshes.new(p["nombre"])
    bm.to_mesh(malla)
    bm.free()
    k = _kit()
    malla.materials.append(k["mat_piso"](p.get("material", "asfalto")))
    malla.materials.append(k["mat_piso"](p.get("material_banqueta", "banqueta")))
    ob = bpy.data.objects.new(p["nombre"], malla)
    ob.location = a_blender(ox, oz, p.get("y", 0.0))
    col.objects.link(ob)
    return ob


def _misma(a, b, ax, az, bx, bz):
    return abs(a[0] - ax) + abs(a[1] - az) + abs(b[0] - bx) + abs(b[1] - bz) < 0.01


def _losa(bm, col, p, a, u, lado, dentro, fuera, s0, s1):
    """Losa de banqueta de s0 a s1 a lo largo del tramo, entre las distancias `dentro` y `fuera`
    del eje (en coordenadas de la pieza), y su caja de choque con biseles."""
    ax, az = a
    ux, uz = u
    nx, nz = -uz * lado, ux * lado
    def punto(s, d):
        return (ax + ux * s + nx * d, az + uz * s + nz * d)
    h = BANQUETA_ALTO
    def vert(s, d, y):
        x, z = punto(s, d)
        return bm.verts.new((x, -z, y))
    # Cara de arriba, guarnicion (hacia el arroyo), cara de afuera y las dos puntas
    caras = []
    caras.append([vert(s0, dentro, h), vert(s1, dentro, h), vert(s1, fuera, h), vert(s0, fuera, h)])
    caras.append([vert(s0, dentro, 0.02), vert(s1, dentro, 0.02), vert(s1, dentro, h), vert(s0, dentro, h)])
    caras.append([vert(s1, fuera, 0.0), vert(s0, fuera, 0.0), vert(s0, fuera, h), vert(s1, fuera, h)])
    caras.append([vert(s0, fuera, 0.0), vert(s0, dentro, 0.0), vert(s0, dentro, h), vert(s0, fuera, h)])
    caras.append([vert(s1, dentro, 0.0), vert(s1, fuera, 0.0), vert(s1, fuera, h), vert(s1, dentro, h)])
    for vs in caras:
        f = bm.faces.new(vs)
        f.material_index = 1
        f.normal_update()
    # Que todas vean hacia afuera de la losa (el lado cambia el sentido)
    centro = Vector(((punto((s0 + s1) / 2, (dentro + fuera) / 2))[0], -(punto((s0 + s1) / 2, (dentro + fuera) / 2))[1], h / 2))
    for f in bm.faces[-5:]:
        if (f.calc_center_median() - centro).dot(f.normal) < 0:
            f.normal_flip()
    # Caja de choque: el mismo perfil con rampas de BANQUETA_RAMPA en los dos bordes
    r = BANQUETA_RAMPA
    perfil = [(dentro - r, 0.0), (dentro, h), (fuera, h), (fuera + r, 0.0)]
    cb = bmesh.new()
    def cv(s, d, y):
        x, z = punto(s, d)
        return cb.verts.new((x, -z, y))
    a0 = [cv(s0, d, y) for d, y in perfil]
    a1 = [cv(s1, d, y) for d, y in perfil]
    for i in range(3):
        cb.faces.new([a0[i], a1[i], a1[i + 1], a0[i + 1]])
    cb.faces.new([a0[3], a1[3], a1[0], a0[0]])
    cb.faces.new(a0[::-1])
    cb.faces.new(a1)
    bmesh.ops.recalc_face_normals(cb, faces=cb.faces[:])
    malla = bpy.data.meshes.new(p["nombre"] + "_banqueta_col")
    cb.to_mesh(malla)
    cb.free()
    ob = bpy.data.objects.new("%s_banqueta%d-colonly" % (p["nombre"], len(col.objects)), malla)
    ob.location = a_blender(p["x"], p["z"], p.get("y", 0.0))
    ob.display_type = "WIRE"
    col.objects.link(ob)


VISTA = "Vista"          # coleccion que solo se ve en Blender (no se exporta): los postes los arma Godot
CABLE_COLGADO = 0.7      # m que cuelga un cable a la mitad
CABLE_LARGO_MAX = 40.0   # m: postes mas lejos no se cablean


def _postes_y_cables(sc, mundo, postes):
    """Postes de vista (en Godot los pone MapAlumbrado con su luz) y los cables colgados de poste
    a poste, en el orden en que se pusieron (zigzaguean de banqueta a banqueta), que si se exportan."""
    if not postes:
        return
    vista = coleccion(sc, VISTA)
    k = _kit()
    for i, p in enumerate(postes):
        c = k["Constructor"]("Poste_%d" % i)
        c.cilindro((0, 0, 0), 0.14, p["alto"], "concreto", lados=6, radio_arriba=0.09)
        c.caja((0, p["alto"] - 0.2, p["brazo"] / 2), (0.08, 0.08, p["brazo"]), "fierro")
        c.caja((0, p["alto"] - 0.3, p["brazo"] - 0.1), (0.3, 0.12, 0.6), "farol")
        ob = bpy.data.objects.new("Poste_%d" % i, c.terminar())
        ob.location = a_blender(p["x"], p["z"])
        ob.rotation_euler = (0.0, 0.0, p["rotacion_y"])
        vista.objects.link(ob)
    bm = bmesh.new()
    pasos = 8
    def punta(p):
        return (p["x"], p["alto"] - 0.5, p["z"])
    for a, b in zip(postes, postes[1:]):
        pa, pb = punta(a), punta(b)
        if math.hypot(pb[0] - pa[0], pb[2] - pa[2]) > CABLE_LARGO_MAX:
            continue
        for hilo in (0.0, 0.25):
            puntos = []
            for j in range(pasos + 1):
                t = j / pasos
                y = pa[1] + (pb[1] - pa[1]) * t - CABLE_COLGADO * 4 * t * (1 - t) - hilo
                puntos.append((pa[0] + (pb[0] - pa[0]) * t, y, pa[2] + (pb[2] - pa[2]) * t))
            for (x0, y0, z0), (x1, y1, z1) in zip(puntos, puntos[1:]):
                g = 0.025
                cara = [a_blender(x0, z0, y0 - g), a_blender(x1, z1, y1 - g), a_blender(x1, z1, y1 + g), a_blender(x0, z0, y0 + g)]
                bm.faces.new([bm.verts.new(v) for v in cara])
                bm.faces.new([bm.verts.new(v) for v in cara[::-1]])
    malla = bpy.data.meshes.new("Cables")
    bm.to_mesh(malla)
    bm.free()
    malla.materials.append(material("cable", (0.05, 0.05, 0.05)))
    ob = bpy.data.objects.new("Cables", malla)
    mundo.objects.link(ob)


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
