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
#               "tienda" (cortina en la planta baja), "tinaco"; con choque (kit.casa_malla);
#               obra negra: "acabado" ("ladrillo" o "block"), "obra" ("castillos" o "losa": el piso
#               que falta, encima), "ventanal" y "tapado" (0-1, ventanas con lona o tabla)
#               "local": no se arma (su fachada de negocio la pone MapPuntos, ver bloqueo._tiendas)
#     suelo     "puntos": la mancha plana (pasto de la plaza, un baldio); sin choque
#     calle     "puntos": el eje, "ancho" del arroyo y "banqueta" de cada lado; sin choque (va
#               pintada sobre el piso). "material" (asfalto) y "material_banqueta" (banqueta)
#               son pisos de kit.PISOS: un andador de la plaza es una calle de banqueta
#     tinaco_comunitario, puesto, banca, jardinera, fuente, parroquia, palacio
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
    CARROS_MODELO.clear()
    sc = escena(nombre_escena(nombre))
    mundo = coleccion(sc, MUNDO)
    marcas = coleccion(sc, MARCAS)

    x1, z1, x2, z2 = datos["recorte"]
    ancho, fondo = x2 - x1, z2 - z1
    cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
    # El piso entre casas es concreto, como la banqueta (en Godot, ps1_suelo con banqueta.png),
    # con los huecos de los `hundidos` (la cancha hundida y la zanja de su bajada)
    huecos = _piso(mundo, datos)

    _arroyos(datos)
    terrazas = _terrazas(mundo, datos)
    for p in datos.get("piezas", []):
        if p.get("local"):
            continue    # la fachada de este negocio la pone MapPuntos (scripts/map/MapPuntos.gd)
        alto = _en_terraza(p, terrazas) - bajar_en_hundido(p, huecos)
        if alto:
            p = dict(p, y=p.get("y", 0.0) + alto)
        ob = _pieza(mundo, p)
        if ob is None:
            print("colonia: tipo de pieza desconocido", p["tipo"], p["nombre"])
        else:
            ob[DATO] = "pieza:" + p["nombre"]

    _juntar_grupos(mundo, datos)
    _postes_y_cables(sc, mundo, datos.get("postes", []))
    _tianguis_vista(sc, datos.get("tianguis", []))
    _carros(mundo, datos)
    _topes(mundo, datos)
    _tendederos(mundo, datos)
    _vida_callejones(mundo, datos)

    for m in datos.get("marcas", []):
        ob = vacio(marcas, m["nombre"], m["x"], m["z"], m.get("rot", 0.0), tamano=1.5)
        ob[DATO] = "marca:" + m["nombre"]

    # exportar.py carga colonia.py otra vez en su propio espacio: los carros viajan en la escena
    import json
    sc["carros_modelo"] = json.dumps(CARROS_MODELO)
    print("colonia %s: %d piezas, %d marcas, %d carros" % (nombre, len(datos.get("piezas", [])), len(datos.get("marcas", [])), len(CARROS_MODELO)))
    return sc


def _juntar_grupos(mundo, datos):
    """Las piezas con "grupo" (las casas de una manzana de la favela) se juntan en un solo objeto
    por grupo, y sus cajas de choque en otro: cientos de casas sueltas eran cientos de objetos y
    MapaPostImport ya las junta por cuadro, pero el .glb y la importacion pesaban. Todas las casas
    llevan los mismos materiales en el mismo orden (kit.casa_malla), asi que la union es directa.
    El objeto junto no se puede leer de regreso al .json (leer() lo salta)."""
    grupos = {}
    for p in datos.get("piezas", []):
        if p.get("grupo") and not p.get("local"):
            grupos.setdefault(p["grupo"], []).append(p["nombre"])
    for grupo, nombres in grupos.items():
        for sufijo, choque in (("", False), ("-colonly", True)):
            objetos = [mundo.objects.get(n + sufijo) for n in nombres]
            objetos = [ob for ob in objetos if ob is not None]
            if not objetos:
                continue
            bm = bmesh.new()
            mats = []
            for ob in objetos:
                malla = ob.data
                base = len(mats)
                for m in malla.materials:
                    if m not in mats:
                        mats.append(m)
                # Los indices de material de esta malla, en la lista junta
                indice = [mats.index(m) for m in malla.materials]
                tmp = bmesh.new()
                tmp.from_mesh(malla)
                # (ob.matrix_world no esta al dia hasta que corre el depsgraph: se arma de location y rotation)
                import mathutils
                matriz = mathutils.Matrix.LocRotScale(ob.location, mathutils.Euler(ob.rotation_euler), ob.scale)
                bmesh.ops.transform(tmp, matrix=matriz, verts=tmp.verts[:])
                for f in tmp.faces:
                    f.material_index = indice[f.material_index] if indice else 0
                junta = bpy.data.meshes.new("tmp")
                tmp.to_mesh(junta)
                tmp.free()
                bm.from_mesh(junta)
                bpy.data.meshes.remove(junta)
            nueva = bpy.data.meshes.new(grupo + sufijo)
            bm.to_mesh(nueva)
            bm.free()
            for m in mats:
                nueva.materials.append(m)
            if nueva.color_attributes:
                nueva.color_attributes.active_color = nueva.color_attributes[0]
                nueva.color_attributes.render_color_index = 0
            ob = bpy.data.objects.new(grupo + sufijo, nueva)
            if choque:
                ob.display_type = "WIRE"
            mundo.objects.link(ob)
            for viejo in objetos:
                datos_viejo = viejo.data
                bpy.data.objects.remove(viejo)
                if datos_viejo.users == 0:
                    bpy.data.meshes.remove(datos_viejo)


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
                                p.get("desgaste", 0.5), p.get("tienda", False), p.get("tinaco", True), p.get("varillas"),
                                p.get("detalles", True), _acabado(p), p.get("obra"), p.get("ventanal", False), p.get("tapado", 0.0),
                                p.get("ventanas"))
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
        for (cx, cz, giro, modelo, estado) in getattr(k, "coches", []):
            CARROS_MODELO.append([round(x + cx * c + cz * s, 2), round(z - cx * s + cz * c, 2), round(rot + giro, 4), modelo, estado, round(y, 2)])
        for i, puntos in enumerate(k.rampas):
            _casco(col, "%s_rampa%d" % (nombre, i), puntos, ob)
        # Lo que solo esta de dia (la lona y la mercancia de un puesto): otro objeto, "Dia_<nombre>",
        # que MapaPostImport junta aparte y Colonia.gd esconde de noche
        dia = getattr(k, "dia", None)
        if dia is not None:
            de_dia = bpy.data.objects.new("Dia_" + nombre, dia.terminar())
            de_dia.location, de_dia.rotation_euler = ob.location, ob.rotation_euler
            col.objects.link(de_dia)
        # Lo chico de una pieza grande (postes, alambre y pintas de la muralla): otro objeto,
        # "Detalle_<nombre>", que MapaPostImport junta en cuadros chicos que no se dibujan de lejos
        detalle = getattr(k, "detalle", None)
        if detalle is not None:
            chico = bpy.data.objects.new("Detalle_" + nombre, detalle.terminar())
            chico.location, chico.rotation_euler = ob.location, ob.rotation_euler
            col.objects.link(chico)
        return ob
    if tipo == "suelo":
        # Abajo de las calles y andadores (que van a 1-2 cm); "material" es un piso de kit.PISOS
        mat = _kit()["mat_piso"](p["material"]) if "material" in p else _mat(p, (0.3, 0.42, 0.25))
        return _objeto(col, nombre, _malla_plana(nombre, p["puntos"], 0.005), x, z, rot, y, mat, False)
    if tipo == "calle":
        return _calle(col, p)
    return None



def poligono_hundido(h, datos):
    """El poligono [(x, z)...] de un hundido: su `poligono`, el rectangulo de `puntos`, o la huella
    de la pieza `pieza` (un jardin de la plaza)."""
    if "poligono" in h:
        return [tuple(q) for q in h["poligono"]]
    if "pieza" in h:
        p = next(q for q in datos.get("piezas", []) if q["nombre"] == h["pieza"])
        return [(p["x"] + a, p["z"] + b) for a, b in p["puntos"]]
    (a, b), (c_, d) = h["puntos"]
    return [(min(a, c_), min(b, d)), (max(a, c_), min(b, d)), (max(a, c_), max(b, d)), (min(a, c_), max(b, d))]


def _area(pol):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pol, pol[1:] + pol[:1])) / 2


def _hacia_adentro(pol, d):
    """El poligono recorrido `d` m hacia adentro (cada vertice por la bisectriz de sus lados)."""
    if d <= 0:
        return list(pol)
    signo = 1.0 if _area(pol) > 0 else -1.0
    n = len(pol)
    nuevo = []
    for i in range(n):
        a, b, c = pol[i - 1], pol[i], pol[(i + 1) % n]
        normales = []
        for p0, p1 in ((a, b), (b, c)):
            dx, dz = p1[0] - p0[0], p1[1] - p0[1]
            l = math.hypot(dx, dz) or 1.0
            normales.append((-dz / l * signo, dx / l * signo))
        mx, mz = normales[0][0] + normales[1][0], normales[0][1] + normales[1][1]
        l = math.hypot(mx, mz) or 1.0
        mx, mz = mx / l, mz / l
        coseno = max(0.35, mx * normales[0][0] + mz * normales[0][1])
        nuevo.append((b[0] + mx * d / coseno, b[1] + mz * d / coseno))
    return nuevo


def bajar_en_hundido(p, huecos):
    """Cuanto baja la pieza `p` por caer en un hundido con `bajar_piezas` (un jardin)."""
    if not huecos or p["tipo"] == "calle":
        return 0.0
    x, z = p["x"], p["z"]
    if p.get("puntos") and p["tipo"] in ("casa", "suelo"):
        x += sum(q[0] for q in p["puntos"]) / len(p["puntos"])
        z += sum(q[1] for q in p["puntos"]) / len(p["puntos"])
    for pol, hondo, bajar in huecos:
        if bajar and _dentro(x, z, pol):
            return hondo
    return 0.0


def _dentro(x, z, pol):
    dentro = False
    j = len(pol) - 1
    for i in range(len(pol)):
        xi, zi = pol[i]
        xj, zj = pol[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi or 1e-9) + xi:
            dentro = not dentro
        j = i
    return dentro


def _malla_caras(nombre, caras, arriba=True, abajo=False):
    """Una malla de caras [[(x, y, z) de Godot...]...], cada una volteada para que vea hacia
    arriba (si `arriba`), hacia abajo (si `abajo`) o como venga."""
    bm = bmesh.new()
    for cara in caras:
        f = bm.faces.new([bm.verts.new(a_blender(x, z, y)) for x, y, z in cara])
        f.normal_update()
        if (arriba and f.normal.z < 0) or (abajo and f.normal.z > 0):
            f.normal_flip()
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    return malla


def _con_choque(mundo, nombre, caras, mat, arriba=True):
    ob = bpy.data.objects.new(nombre, _malla_caras(nombre, caras, arriba))
    ob.data.materials.append(mat)
    mundo.objects.link(ob)
    ob[DATO] = "piso"
    choque = bpy.data.objects.new(nombre + "-colonly", _malla_caras(nombre + "_col", caras, arriba))
    choque.display_type = "WIRE"
    mundo.objects.link(choque)
    return ob


def _piso(mundo, datos):
    """El piso del recorte: una malla a y = 0 con los huecos de `hundidos` (poligonos: `poligono`,
    el rectangulo de `puntos` o la huella de una `pieza`), triangulada con tessellate_polygon, y en
    cada hueco su fondo a -`fondo` y sus orillas: verticales, o en talud de `borde` m (los jardines
    de la plaza: se entra y se sale caminando). Todo con su choque de malla. Devuelve los huecos
    [(poligono, fondo, bajar_piezas)] para bajar lo que cae adentro."""
    import mathutils
    from mathutils.geometry import tessellate_polygon
    mat = _kit()["mat_piso"]("banqueta")
    x1, z1, x2, z2 = datos["recorte"]
    afuera = [(x1, z1), (x2, z1), (x2, z2), (x1, z2)]
    huecos = []
    for h in datos.get("hundidos", []):
        huecos.append((poligono_hundido(h, datos), h.get("fondo", 1.0), h.get("bajar_piezas", False), h.get("borde", 0.0), h["nombre"], h.get("abiertos", [])))
    lineas = [afuera] + [hueco[0] for hueco in huecos]
    planos = [[mathutils.Vector((x, z, 0.0)) for x, z in linea] for linea in lineas]
    todos = [q for linea in lineas for q in linea]
    caras = [[(todos[i][0], 0.0, todos[i][1]) for i in tri] for tri in tessellate_polygon(planos)]
    _con_choque(mundo, "Piso", caras, mat)
    # Si hay tuneles (un hundido abierto), el piso tambien se ve por abajo: una copia volteada, sin choque,
    # para no ver el cielo desde la galeria por las rendijas
    if any(h[5] for h in huecos):
        abajo = bpy.data.objects.new("Piso_Abajo", _malla_caras("Piso_Abajo", [[(x, -0.02, z) for x, _y, z in cara] for cara in caras], arriba=False, abajo=True))
        abajo.data.materials.append(_kit()["foto"]("tierra") if "tierra" in _kit()["FOTOS"] else mat)
        mundo.objects.link(abajo)
        abajo[DATO] = "piso"
    for pol, hondo, bajar, borde, nombre, abiertos in huecos:
        fondo_pol = _hacia_adentro(pol, borde)
        tris = tessellate_polygon([[mathutils.Vector((x, z, 0.0)) for x, z in fondo_pol]])
        caras = [[(fondo_pol[i][0], -hondo, fondo_pol[i][1]) for i in tri] for tri in tris]
        # Orillas: de la orilla a y 0 al fondo (recorrido `borde` hacia adentro); las de "abiertos"
        # (indice del lado, del punto i al i+1) no se hacen: por ahi sigue un tunel
        n = len(pol)
        for i in range(n):
            if i in abiertos:
                continue
            j = (i + 1) % n
            caras.append([(pol[i][0], 0.0, pol[i][1]), (pol[j][0], 0.0, pol[j][1]),
                          (fondo_pol[j][0], -hondo, fondo_pol[j][1]), (fondo_pol[i][0], -hondo, fondo_pol[i][1])])
        fondo_caras, orillas = caras[:len(tris)], caras[len(tris):]
        _con_choque(mundo, "Piso_" + nombre, fondo_caras, mat)
        _con_choque(mundo, "Piso_%s_Orilla" % nombre, orillas, mat, arriba=borde > 0)
    return [(pol, hondo, bajar) for pol, hondo, bajar, borde, nombre, abiertos in huecos]


def _terrazas(mundo, datos):
    """Las `terrazas` del .json ([{"nombre", "puntos": [[x0, z0], [x1, z1]] o "poligono": [[x, z]...],
    "alto"}]): una manzana subida sobre su muro de contencion de mamposteria, con piso de concreto
    encima. Lo que cae adentro sube `alto` (_en_terraza). Sus escalinatas son piezas aparte. Devuelve
    [(poligono, alto)]. Con "poligono" (las manzanas sesgadas de la favela) el cuerpo es un prisma de
    mamposteria con su tapa de concreto, en vez de la caja."""
    k = _kit()
    lista = []
    for t in datos.get("terrazas", []):
        alto = t.get("alto", 0.75)
        if "poligono" in t:
            pol = [tuple(q) for q in t["poligono"]]
            cx = sum(q[0] for q in pol) / len(pol)
            cz = sum(q[1] for q in pol) / len(pol)
            rel = [(x - cx, z - cz) for x, z in pol]
            # El muro de contencion (prisma, con choque) y la tapa de concreto apenas encima
            _objeto(mundo, t["nombre"] + "_Muro", _malla_prisma(t["nombre"] + "_Muro", rel, alto), cx, cz, 0.0, 0.0, k["foto"]("mamposteria"), True)
            _objeto(mundo, t["nombre"], _malla_plana(t["nombre"], rel, alto + 0.005), cx, cz, 0.0, 0.0, k["mat_piso"]("banqueta"), False)
            lista.append((pol, alto))
            continue
        (a, b), (c_, d) = t["puntos"]
        x0, z0, x1, z1 = min(a, c_), min(b, d), max(a, c_), max(b, d)
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        caja(mundo, t["nombre"], cx, cz, 0.0, (x1 - x0, alto, z1 - z0), k["mat_piso"]("banqueta"), choca=True)
        muro = k["foto"]("mamposteria")
        for nombre, mx, mz, tam in (("N", cx, z0 - 0.06, (x1 - x0 + 0.24, alto + 0.12, 0.12)), ("S", cx, z1 + 0.06, (x1 - x0 + 0.24, alto + 0.12, 0.12)),
                                    ("O", x0 - 0.06, cz, (0.12, alto + 0.12, z1 - z0)), ("E", x1 + 0.06, cz, (0.12, alto + 0.12, z1 - z0))):
            caja(mundo, "%s_Muro%s" % (t["nombre"], nombre), mx, mz, 0.0, tam, muro, choca=False)
        lista.append(([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], alto))
    return lista


def _en_terraza(p, terrazas):
    """Cuanto sube la pieza `p` por caer en una terraza (por su centro; una casa por el de su huella;
    un callejon por el medio de su tramo)."""
    if not terrazas or p["tipo"] in ("suelo", "escalinata", "tunel", "tunel_cuarto", "bajada"):
        return 0.0
    x, z = p["x"], p["z"]
    if p.get("puntos") and p["tipo"] == "casa":
        x += sum(q[0] for q in p["puntos"]) / len(p["puntos"])
        z += sum(q[1] for q in p["puntos"]) / len(p["puntos"])
    elif p["tipo"] == "calle":
        # Solo los callejones de la favela suben con su manzana; las calles reales van a nivel
        if not p.get("favela"):
            return 0.0
        pts = p["puntos"]
        x += (pts[0][0] + pts[-1][0]) / 2
        z += (pts[0][1] + pts[-1][1]) / 2
    for pol, alto in terrazas:
        if _dentro(x, z, pol):
            return alto
    return 0.0

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




BOTIN_TIPOS = ["chatarra", "bolsa", "curacion"]   # Colonia.gd: Chatarra, Takis con tazo, tacos/caguama
BOTIN_EXTRA = ["Cancha_Mirador"]                   # azoteas fuera de las rutas que tambien llevan


def botin_azoteas(datos):
    """Botin para el que sube: uno en una casa de cada ruta de azoteas (las "Ruta_<nombre>_Casa_n"
    de bloqueo.py) y en cada casa de BOTIN_EXTRA, turnando BOTIN_TIPOS. Fijo por nombre.
    [(x, y, z, que), ...]; exportar.py los escribe como marcas "botin"."""
    rutas = {}
    casas = {p["nombre"]: p for p in datos.get("piezas", []) if p["tipo"] == "casa"}
    for nombre in casas:
        if nombre.startswith("Ruta_") and "_Casa_" in nombre:
            rutas.setdefault(nombre.split("_Casa_")[0], []).append(nombre)
    elegidas = []
    for ruta in sorted(rutas):
        lista = sorted(rutas[ruta])
        semilla = sum((i + 1) * ord(ch) for i, ch in enumerate(ruta))
        elegidas.append(lista[semilla % len(lista)])
    elegidas += [n for n in BOTIN_EXTRA if n in casas]
    botin = []
    for i, nombre in enumerate(elegidas):
        p = casas[nombre]
        pts = p["puntos"]
        cx = p["x"] + sum(q[0] for q in pts) / len(pts)
        cz = p["z"] + sum(q[1] for q in pts) / len(pts)
        botin.append((round(cx, 2), round(p.get("pisos", 1) * 2.75 + 0.05, 2), round(cz, 2), BOTIN_TIPOS[i % len(BOTIN_TIPOS)]))
    return botin


CARRO_CADA = (28.0, 50.0)     # m entre carros estacionados a lo largo de una calle
CARRO_LIBRE = 7.0             # m sin carros alrededor de marcas (puertas, flechas) y de puestos
CARRO_ESQUINA = 9.0           # m sin carros desde las puntas de cada tramo (los cruces)
CARRO_COLORES = ["rojo", "lona_azul", "lona_amarillo", "blanco_cal", "lona_verde", "naranja_gela"]


def carros_estacionados(datos):
    """Carros abandonados junto a la banqueta de las calles con banqueta: la mitad enteros, los
    demas sobre ladrillos o quemados, alguna combi. Lejos de puertas, puestos, el reten de GelA y
    los cruces. Fijos por nombre de calle. Son piezas "carro" (con choque) que no van al .json."""
    import random
    estorban = [(m["x"], m["z"]) for m in datos.get("marcas", [])]
    estorban += [(p["x"], p["z"]) for p in datos.get("piezas", []) if p["tipo"] in ("puesto", "base_gela", "tiendita", "tortilleria", "puesto_guardia", "mirador_muro", "nicho_virgen")]
    carros = []
    for p in datos.get("piezas", []):
        if p["tipo"] != "calle" or p.get("banqueta", 0) <= 0 or p.get("material", "asfalto") != "asfalto":
            continue
        r = random.Random(sum((i + 1) * ord(ch) for i, ch in enumerate(p["nombre"])) * 13 + 7)
        pts = [(p["x"] + a, p["z"] + b) for a, b in p["puntos"]]
        for k, ((ax, az), (bx, bz)) in enumerate(zip(pts, pts[1:])):
            largo = math.hypot(bx - ax, bz - az)
            if largo < 2 * CARRO_ESQUINA + 4.0:
                continue
            ux, uz = (bx - ax) / largo, (bz - az) / largo
            s = CARRO_ESQUINA + r.uniform(0.0, 12.0)
            while s < largo - CARRO_ESQUINA:
                lado = r.choice((-1, 1))
                d = p["ancho"] / 2 - 1.1
                x, z = ax + ux * s - uz * lado * d, az + uz * s + ux * lado * d
                if all(math.hypot(x - ex, z - ez) > CARRO_LIBRE for ex, ez in estorban):
                    tiro = r.random()
                    estado = "normal" if tiro < 0.5 else ("ladrillos" if tiro < 0.8 else "quemado")
                    carro = {"nombre": "Carro_%s_%d_%d" % (p["nombre"], k, int(s)), "tipo": "carro",
                             "x": round(x, 2), "z": round(z, 2), "rot": round(math.atan2(ux, uz) + r.uniform(-0.12, 0.12), 4),
                             "color": r.choice(CARRO_COLORES), "estado": estado}
                    q = r.random()
                    # Cual de los cuatro (la van, una de cada 5; el mismo tiro de antes: las posiciones no cambian)
                    carro["modelo"] = "van_blanca" if q < 0.2 else ("tsuru" if q < 0.47 else ("vocho" if q < 0.74 else "grand_vitara"))
                    carros.append(carro)
                s += r.uniform(*CARRO_CADA)
    return carros



TOPE_DESDE = 40.0     # m: los tramos de calle mas largos llevan un tope a la mitad


def topes(datos):
    """Un tope a media cuadra en cada tramo largo de las calles de asfalto con banqueta, si no cae
    junto a una marca, un puesto o un carro estacionado. Piezas "tope" que no van al .json."""
    estorban = [(m["x"], m["z"]) for m in datos.get("marcas", [])]
    estorban += [(p["x"], p["z"]) for p in datos.get("piezas", []) if p["tipo"] in ("puesto", "base_gela", "puesto_guardia", "mirador_muro", "nicho_virgen")]
    estorban += [(c["x"], c["z"]) for c in carros_estacionados(datos)]
    lista = []
    for p in datos.get("piezas", []):
        if p["tipo"] != "calle" or p.get("banqueta", 0) <= 0 or p.get("material", "asfalto") != "asfalto":
            continue
        pts = [(p["x"] + a, p["z"] + b) for a, b in p["puntos"]]
        for k, ((ax, az), (bx, bz)) in enumerate(zip(pts, pts[1:])):
            largo = math.hypot(bx - ax, bz - az)
            if largo < TOPE_DESDE:
                continue
            x, z = (ax + bx) / 2, (az + bz) / 2
            if any(math.hypot(x - ex, z - ez) < 5.0 for ex, ez in estorban):
                continue
            # Atravesado: su x a lo ancho de la calle
            ux, uz = (bx - ax) / largo, (bz - az) / largo
            lista.append({"nombre": "Tope_%s_%d" % (p["nombre"], k), "tipo": "tope", "x": round(x, 2), "z": round(z, 2),
                          "rot": round(math.atan2(ux, uz), 4), "ancho": p["ancho"]})
    return lista


def _topes(mundo, datos):
    for p in topes(datos):
        _pieza(mundo, p)

# Donde va cada carro de modelo de Sketchfab: [x, z, giro, modelo, estado, y]. _pieza lo llena con lo
# que pone cada pieza (`k.coches`: carros sueltos, el taller, la casa derrumbada) y exportar.py lo
# escribe en resources/mapa/<colonia>/carros_modelo.json (scripts/mapa/CarrosColonia.gd).
CARROS_MODELO = []


def _carros(mundo, datos):
    for p in carros_estacionados(datos):
        _pieza(mundo, p)


PLACA_CADA = 60.0      # m: ademas de las puntas, una placa a medio tramo en los tramos mas largos
PLACA_LIBRE = 2.5      # m sin placas alrededor de otras marcas (flechas de negocio)


def placas_calles(datos):
    """Placas con el nombre de la calle (`nombres_calles` del .json: nombre de pieza -> nombre
    parodiado) en la banqueta, en cada punta de cada calle con nombre y a medio tramo en los
    largos, turnando lado. [{x, z, rot, texto}]; exportar.py las vuelve marcas "placa"."""
    nombres = datos.get("nombres_calles", {})
    estorban = [(m["x"], m["z"]) for m in datos.get("marcas", [])]
    placas = []
    for p in datos.get("piezas", []):
        texto = nombres.get(p["nombre"])
        if p["tipo"] != "calle" or not texto:
            continue
        pts = [(p["x"] + a, p["z"] + b) for a, b in p["puntos"]]
        d = p["ancho"] / 2 + 0.35
        lado = 1
        for k, ((ax, az), (bx, bz)) in enumerate(zip(pts, pts[1:])):
            largo = math.hypot(bx - ax, bz - az)
            if largo < 6.0:
                continue
            ux, uz = (bx - ax) / largo, (bz - az) / largo
            paradas = [4.0] + ([largo / 2] if largo > PLACA_CADA else []) + ([largo - 4.0] if k == len(pts) - 2 else [])
            for s in paradas:
                x, z = ax + ux * s - uz * lado * d, az + uz * s + ux * lado * d
                if all(math.hypot(x - ex, z - ez) > PLACA_LIBRE for ex, ez in estorban):
                    # La placa corre a lo largo de la calle: su +Z ve hacia el arroyo
                    placas.append({"x": round(x, 2), "z": round(z, 2), "rot": round(math.atan2(uz * lado, -ux * lado), 4), "texto": texto})
                lado = -lado
    return placas

LADRILLO_CADA = 5        # una de cada tantas casas "auto" de dos pisos o mas sale de ladrillo


def _acabado(p):
    """El "acabado" de una casa: el suyo, o ladrillo para una de cada LADRILLO_CADA de las que
    puso bloqueo.py con dos pisos o mas (fijo por nombre)."""
    if "acabado" in p:
        return p["acabado"]
    if p.get("auto") and p.get("pisos", 1) >= 2 and sum((i + 1) * ord(ch) for i, ch in enumerate(p["nombre"])) % LADRILLO_CADA == 0:
        return "ladrillo"
    return None

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


def _tianguis_vista(sc, tramos):
    """Donde van las lonas del tianguis, para verlas en Blender (no se exporta): las carpas, los
    puestos y los huecos frente a las puertas los arma Godot (scripts/mapa/Tianguis.gd con las
    marcas de exportar.tianguis_marcas)."""
    if not tramos:
        return
    vista = next((c for c in sc.collection.children if c.name.startswith(VISTA)), None) or coleccion(sc, VISTA)
    lona = material("lona_tianguis", (0.85, 0.2, 0.45))
    for t in tramos:
        (ax, az), (bx, bz) = t["a"], t["b"]
        largo = math.hypot(bx - ax, bz - az)
        rot = math.atan2(-(bz - az), bx - ax)
        arroyo, pasillo = t.get("arroyo", 8.0), t.get("pasillo", 2.6)
        fondo = arroyo / 2 - pasillo / 2
        for lado in (1, -1):
            d = lado * (arroyo / 2 - fondo / 2)
            x = (ax + bx) / 2 + math.sin(rot) * d
            z = (az + bz) / 2 + math.cos(rot) * d
            caja(vista, "%s_%d" % (t["nombre"], lado), x, z, rot, (largo, 0.05, fondo), lona, y=2.5, choca=False)


DETALLE_TROZO = 20.0          # m: lo de los callejones va en objetos de este largo


class _Trozos:
    """Objetos "Detalle_<que>_<callejon>_<n>" de DETALLE_TROZO m a lo largo de cada callejon: en
    Godot MapaPostImport junta lo que empieza con "Detalle_" en cuadros chicos que se dejan de
    dibujar de lejos, y un objeto de 60 m caeria en un solo cuadro."""
    def __init__(self, que):
        self.que = que
        self.constructores = {}

    def __call__(self, callejon, s):
        nombre = "Detalle_%s_%s_%d" % (self.que, callejon, int(s // DETALLE_TROZO))
        if nombre not in self.constructores:
            self.constructores[nombre] = _piezas()["Constructor"](nombre)
        return self.constructores[nombre]

    def poner(self, mundo):
        for nombre, c in self.constructores.items():
            mundo.objects.link(bpy.data.objects.new(nombre, c.terminar()))


TENDEDERO_CADA = (4.5, 8.0)   # m entre cuerdas a lo largo de un callejon
TENDEDERO_ALTO = (3.4, 5.2)   # m de alto en las puntas (del primer al segundo piso)
BASURA_CADA = (8.0, 16.0)
FOCO_CADA = (10.0, 15.0)      # m entre focos colgados a lo largo de un callejon


def _cada(datos, que, defecto):
    """"callejones" del .json: {"tendedero_cada", "basura_cada", "foco_cada": [min, max]} para colonias
    con cientos de callejones (la favela de La Gotera), donde lo de siempre pesaba demasiado."""
    v = datos.get("callejones", {}).get(que)
    return tuple(v) if v else defecto


def _tendederos(mundo, datos):
    """Cuerdas de un lado al otro de cada callejon (calles de empedrado sin banqueta), de fachada
    a fachada, colgadas a la mitad, la mayoria con ropa y algunas solo cable de luz, en trozos
    (_Trozos). Mismo azar en cada armada (semilla por callejon)."""
    pz = _piezas()
    trozo = _Trozos("Tendedero")
    colores = ["lona_" + n for n in pz["LONAS"]] + ["blanco_cal"]
    hubo = False
    for p in datos.get("piezas", []):
        if p["tipo"] != "calle" or p.get("material") != "empedrado" or p.get("banqueta", 0) > 0:
            continue
        semilla = sum((i + 1) * ord(ch) for i, ch in enumerate(p["nombre"]))
        r = __import__("random").Random(semilla)
        medio = p["ancho"] / 2 + 0.5
        for (ax, az), (bx, bz) in zip(p["puntos"], p["puntos"][1:]):
            ax, az, bx, bz = ax + p["x"], az + p["z"], bx + p["x"], bz + p["z"]
            largo = math.hypot(bx - ax, bz - az)
            if largo < 3.0:
                continue
            ux, uz = (bx - ax) / largo, (bz - az) / largo
            nx, nz = -uz, ux
            s = r.uniform(1.5, 4.0)
            while s < largo - 1.5:
                hubo = True
                c = trozo(p["nombre"], s)
                mx, mz = ax + ux * s, az + uz * s
                y0, y1 = r.uniform(*TENDEDERO_ALTO), r.uniform(*TENDEDERO_ALTO)
                cuelga = r.uniform(0.25, 0.5)
                pa = (mx - nx * medio, y0, mz - nz * medio)
                pb = (mx + nx * medio, y1, mz + nz * medio)
                def punto(t):
                    return (pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t - cuelga * 4 * t * (1 - t),
                            pa[2] + (pb[2] - pa[2]) * t)
                pasos = 4
                giro = math.atan2(-nz, nx)
                for j in range(pasos):
                    q0, q1 = punto(j / pasos), punto((j + 1) / pasos)
                    lx = math.hypot(q1[0] - q0[0], q1[2] - q0[2])
                    c.caja(((q0[0] + q1[0]) / 2, (q0[1] + q1[1]) / 2 - 0.01, (q0[2] + q1[2]) / 2), (lx, 0.02, 0.02), "cable", giro)
                if r.random() < 0.75:
                    prendas = r.randint(*tuple(int(b) for b in _cada(datos, "prendas", (2, 5))))
                    for i in range(prendas):
                        t = (i + r.uniform(0.2, 0.8)) / prendas * 0.8 + 0.1
                        q = punto(t)
                        ancho, colgado = r.uniform(0.3, 0.55), r.uniform(0.35, 0.7)
                        # Una prenda es un quad por las dos caras (era una caja: seis caras)
                        col = r.choice(colores)
                        hx, hz = math.cos(giro) * ancho / 2, -math.sin(giro) * ancho / 2
                        esq = [(q[0] - hx, q[1] - colgado, q[2] - hz), (q[0] + hx, q[1] - colgado, q[2] + hz), (q[0] + hx, q[1], q[2] + hz), (q[0] - hx, q[1], q[2] - hz)]
                        c.cara(esq, col)
                        c.cara(esq[::-1], col)
                s += r.uniform(*_cada(datos, "tendedero_cada", TENDEDERO_CADA))
    if hubo:
        trozo.poner(mundo)


FOCO_ALTO = (3.7, 4.3)        # m del cable que lo cuelga


def focos_callejones(datos):
    """Donde cuelga un foco en cada callejon: [(x, y, z), ...] en metros del juego. colonia.py
    dibuja el foco y su cable; exportar.py los vuelve marcas "foco" (Colonia.gd pone la luz)."""
    focos = []
    for p in datos.get("piezas", []):
        if p["tipo"] != "calle" or p.get("material") != "empedrado" or p.get("banqueta", 0) > 0:
            continue
        semilla = sum((i + 1) * ord(ch) for i, ch in enumerate(p["nombre"]))
        r = __import__("random").Random(semilla * 11 + 5)
        (ax, az), (bx, bz) = [(p["x"] + a, p["z"] + b) for a, b in p["puntos"][:2]]
        largo = math.hypot(bx - ax, bz - az)
        ux, uz = (bx - ax) / (largo or 1.0), (bz - az) / (largo or 1.0)
        s = r.uniform(4.0, 8.0)
        while s < largo - 2.0:
            focos.append((round(ax + ux * s, 2), round(r.uniform(*FOCO_ALTO), 2), round(az + uz * s, 2), p["ancho"], ux, uz,
                          p["nombre"], s))
            s += r.uniform(*_cada(datos, "foco_cada", FOCO_CADA))
    return focos


def _focos(trozo, datos):
    """El cable de fachada a fachada y el foco colgando de un cordon, en su trozo de callejon."""
    for x, y, z, ancho, ux, uz, callejon, s in focos_callejones(datos):
        c = trozo(callejon, s)
        nx, nz = -uz, ux
        medio = ancho / 2 + 0.5
        giro = math.atan2(-nz, nx)
        c.caja((x, y, z), (medio * 2, 0.02, 0.02), "cable", giro)
        c.caja((x, y - 0.15, z), (0.015, 0.3, 0.015), "cable")
        c.esfera((x, y - 0.36, z), 0.08, "farol", seg=5, anillos=3)


def _capilla(c, x, z, giro):
    """Capillita de la Virgen del Tinaco (lore: el culto se cuela en Santa Mugre): pedestal,
    nicho de cal con techito azul, un tinaquito de yeso con su aureola, veladoras y flores.
    Su frente (+Z local) ve al callejon."""
    co, si = math.cos(giro), math.sin(giro)
    def p(lx, ly, lz):
        return (x + lx * co + lz * si, ly, z - lx * si + lz * co)
    c.caja(p(0, 0.5, 0), (0.7, 1.0, 0.5), "concreto", giro)
    c.caja(p(0, 1.0 + 0.45, -0.22), (0.6, 0.9, 0.06), "blanco_cal", giro)
    for lx in (-0.28, 0.28):
        c.caja(p(lx, 1.45, -0.02), (0.06, 0.9, 0.42), "blanco_cal", giro)
    c.caja(p(0, 1.93, -0.02), (0.8, 0.06, 0.55), "azul_gela", giro)
    c.cono(p(0, 1.96, -0.02), 0.45, 0.3, "azul_gela", lados=4)
    c.cilindro(p(0, 1.02, -0.05), 0.11, 0.24, "tinaco", lados=8)
    c.esfera(p(0, 1.4, -0.05), 0.09, "blanco_cal", seg=6, anillos=4)
    c.caja(p(0, 1.4, -0.13), (0.34, 0.34, 0.02), "oro", giro)
    for i in range(5):
        c.caja(p(-0.24 + i * 0.12, 1.06, 0.14), (0.05, 0.1, 0.05), "veladora", giro)
    for lx, col in ((-0.3, "lona_rosa"), (0.3, "lona_amarillo"), (0.22, "lona_rojo")):
        c.esfera(p(lx, 1.08, 0.18), 0.08, col, seg=5, anillos=3)


def _basura(c, x, z, r, bolsas=(2, 5)):
    """Montón de basura junto a la pared: bolsas negras, cajas de cartón y llantas."""
    for i in range(r.randint(*bolsas)):
        rad = r.uniform(0.2, 0.32)
        c.esfera((x + r.uniform(-0.5, 0.5), rad * 0.7, z + r.uniform(-0.4, 0.4)), rad, "bolsa_negra", seg=5, anillos=3, aplastar=0.75)
    for i in range(r.randint(0, 2)):
        lado = r.uniform(0.3, 0.5)
        c.caja((x + r.uniform(-0.6, 0.6), lado / 2, z + r.uniform(-0.4, 0.4)), (lado, lado * 0.8, lado), "carton", r.uniform(0, 3))
    if r.random() < 0.4:
        lx, lz = x + r.uniform(-0.6, 0.6), z + r.uniform(-0.4, 0.4)
        for i in range(r.randint(1, 3)):
            c.cilindro((lx, i * 0.24, lz), 0.33, 0.22, "fierro", lados=8)


def _vida_callejones(mundo, datos):
    """Basura junto a las paredes de cada callejon, una capillita cerca de la entrada (en los de
    semilla par) y los focos colgados. Sin choque (no estorban el paso). Mismo azar en cada armada."""
    pz = _piezas()
    trozo = _Trozos("Callejon")
    hubo = False
    for p in datos.get("piezas", []):
        if p["tipo"] != "calle" or p.get("material") != "empedrado" or p.get("banqueta", 0) > 0:
            continue
        semilla = sum((i + 1) * ord(ch) for i, ch in enumerate(p["nombre"]))
        r = __import__("random").Random(semilla * 7 + 3)
        orilla = p["ancho"] / 2 - 0.35
        pts = [(p["x"] + a, p["z"] + b) for a, b in p["puntos"]]
        (ax, az), (bx, bz) = pts[0], pts[1]
        largo = math.hypot(bx - ax, bz - az)
        if largo < 4.0:
            continue
        hubo = True
        ux, uz = (bx - ax) / largo, (bz - az) / largo
        nx, nz = -uz, ux
        # "basura_min": en callejones mas cortos no hay basura (la favela tiene cientos de 7 m)
        sin_basura = largo < _cada(datos, "basura_min", (0.0,))[0]
        # Una capillita en uno de cada "capilla_cada" callejones (dos, salvo que la colonia diga otra cosa)
        if semilla % int(_cada(datos, "capilla_cada", (2,))[0]) == 0:
            lado = 1 if semilla % 4 == 0 else -1
            s = min(2.5, largo / 3)
            # Su frente (+Z local) hacia el centro del callejon: -n * lado
            fx, fz = -nx * lado, -nz * lado
            _capilla(trozo(p["nombre"], s), ax + ux * s + nx * lado * (orilla + 0.1), az + uz * s + nz * lado * (orilla + 0.1), math.atan2(fx, fz))
        s = r.uniform(3.0, 6.0)
        while s < largo - 1.0 and not sin_basura:
            lado = r.choice((-1, 1))
            _basura(trozo(p["nombre"], s), ax + ux * s + nx * lado * orilla, az + uz * s + nz * lado * orilla, r,
                    tuple(int(b) for b in _cada(datos, "bolsas", (2, 5))))
            s += r.uniform(*_cada(datos, "basura_cada", BASURA_CADA))
    _focos(trozo, datos)
    trozo.poner(mundo)


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
