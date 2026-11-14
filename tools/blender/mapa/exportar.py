# Exporta una colonia armada por colonia.py:
#   models/mapa/<colonia>/<colonia>.glb       la coleccion "Mundo" (piezas y cajas "-colonly")
#   models/mapa/<colonia>/fuente/<colonia>.blend   la escena (detras de .gdignore)
#   resources/mapa/<colonia>/marcas.json      las marcas, para scripts/mapa/Colonia.gd
#                                            (y los tramos de tianguis, tianguis_marcas)
#   resources/mapa/<colonia>/puntos.json      los negocios, con el esquema de MapPuntos (para el
#                                            minimapa, la gente, las misiones y Partida)
# Antes de exportar trae al .json lo movido a mano (colonia.leer), asi que el .json y el .glb
# siempre dicen lo mismo.
#
#   COLONIA = "santa_mugre"; exec(open(r"...\tools\blender\mapa\exportar.py", encoding="utf-8").read())

import bpy
import json
import os

_k = {"__name__": "colonia", "SOLO_FUNCIONES": True}
exec(open(os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "mapa", "colonia.py"), encoding="utf-8").read(), _k)
globals().update({k: v for k, v in _k.items() if not k.startswith("__") and k != "SOLO_FUNCIONES"})


# Carros que se quitan a mano de cada colonia: [x, z] (la combi que tapaba la entrada de la vecindad
# de Santa Mugre). Su caja de choque tambien se borra al cargar (Colonia.CARROS_OMITIDOS).
CARROS_OMITIDOS = {"santa_mugre": [(-214.91, 373.78)]}


def casas_juego(datos):
    """Las casas con el esquema de resources/map/casas_mapa.json (MisionesMundo: a donde mandar a
    visitar; Partida: las de obra negra), con su frente hacia la calle."""
    casas = []
    for p in datos.get("piezas", []):
        if p["tipo"] != "casa":
            continue
        a, b, (cx, cz), (nx, nz), fondo = frente_de(p)
        casas.append({"modelo": "blender", "x": round(cx, 2), "z": round(cz, 2), "rotacion_y": round(math.atan2(nx, nz), 4),
                      "ancho": round(math.hypot(b[0] - a[0], b[1] - a[1]), 2), "fondo": round(fondo, 2),
                      "pisos": p.get("pisos", 1), "colonia": datos["nombre"].upper()})
    return casas


def banquetas(datos):
    """Por donde camina la gente (Gente.gd): el medio de cada banqueta y de cada callejon, recortado
    contra las casas y edificios grandes para que no los atraviese (tools/blender/mapa/caminos.py,
    que tambien corre suelto: python3 caminos.py santa_mugre)."""
    k = {"__name__": "caminos"}
    exec(open(os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"), "tools", "blender", "mapa", "caminos.py"), encoding="utf-8").read(), k)
    return k["banquetas"](datos)

# Las fondas (lote "fonda") llevan las mesas de la taqueria (Mesa.gd: cubierta roja, sillas
# plegables, salseros) como marcas "mesa", y cada patio una silla plegable de la libreria como
# prop: las de cajas de piezas.py se veian como cubos de colores (JJ, 2026-11-14)
MESAS_FONDA_PASO = 2.0                         # m entre mesas
MESA_SILLAS = [15, 15, 7, 11, 13, 14, 6, 9]    # flags de Mesa.sillas: atras, izquierda, derecha, adelante
SILLA_PATIO = ["silla", "", [0.5, 0.85]]


def _en_mundo(p, lx, lz):
    c, s = math.cos(p.get("rot", 0.0)), math.sin(p.get("rot", 0.0))
    return p["x"] + lx * c + lz * s, p["z"] - lx * s + lz * c


def mesas_fondas(datos):
    """Una fila de una a tres marcas "mesa" bajo la lona de cada fonda (piezas.lote)."""
    import random
    marcas = []
    for p in datos.get("piezas", []):
        if p.get("tipo") != "lote" or p.get("variante") != "fonda":
            continue
        rng = random.Random(p["nombre"])
        ancho = p.get("tam", [8.0, 12.0])[0]
        n = max(1, min(3, int((ancho - 1.6) / MESAS_FONDA_PASO)))
        for i in range(n):
            lx = (i - (n - 1) / 2.0) * MESAS_FONDA_PASO + rng.uniform(-0.15, 0.15)
            x, z = _en_mundo(p, lx, -0.25 + rng.uniform(-0.2, 0.2))     # bajo el centro de la lona
            marcas.append({"nombre": "Mesa_%s_%d" % (p["nombre"], i), "tipo": "mesa",
                           "x": round(x, 2), "z": round(z, 2), "y": round(float(p.get("y", 0.0)), 2),
                           "rot": round(p.get("rot", 0.0) + rng.uniform(-0.25, 0.25), 3),
                           "semilla": rng.randint(0, 999), "sillas": rng.choice(MESA_SILLAS)})
    return marcas


def sillas_patios(datos):
    """La silla plegable de cada patio (piezas.patio), donde iba la de cajas: [x, z, giro, pack,
    nodo, y, choca, medida] como los props de PropsColonia."""
    import random
    props = []
    for p in datos.get("piezas", []):
        if p.get("tipo") != "patio" or not p.get("tam"):
            continue
        rng = random.Random(p["nombre"])
        x, z = _en_mundo(p, p["tam"][0] / 2.0 - 1.2, p["tam"][1] / 2.0 - 1.0)
        props.append([round(x, 2), round(z, 2), round(p.get("rot", 0.0) + math.pi + rng.uniform(-0.6, 0.6), 3),
                      SILLA_PATIO[0], SILLA_PATIO[1], round(float(p.get("y", 0.0)), 2), False, SILLA_PATIO[2]])
    return props


# Frente a una puerta o un negocio el tianguis deja un hueco de 2 * PUESTO_LIBRE m de ese lado
PUESTO_LIBRE = 2.5


def tianguis_marcas(datos):
    """Los tramos de "tianguis" del .json como marcas para Colonia.gd (scripts/mapa/Tianguis.gd):
    la marca va en "a" (en medio del arroyo) con su +X hacia "b". Los huecos (lado, desde, hasta,
    en metros a lo largo del tramo) salen de las puertas de las marcas y los negocios, mas los
    "libres" a mano ([x, z, ancho]: las calles que cruzan); los reservados, de los puestos_calle con
    "bajo_carpa" (una carpa vacia encima del carrito de MapPuntos)."""
    puertas = [(m["x"], m["z"]) for m in datos.get("marcas", [])
               if m.get("tipo") in ("puerta", "casa_vecino", "casa_propia", "yonke")]
    for n in datos.get("negocios", []):
        r, f = n.get("rotacion_y", 0.0), n.get("fondo", 0.0) / 2
        puertas.append((n["x"] + math.sin(r) * f, n["z"] + math.cos(r) * f))
    marcas = []
    for t in datos.get("tianguis", []):
        (ax, az), (bx, bz) = t["a"], t["b"]
        largo = math.hypot(bx - ax, bz - az)
        rot = math.atan2(-(bz - az), bx - ax)
        arroyo = t.get("arroyo", 8.0)

        def local(x, z):
            dx, dz = x - ax, z - az
            return dx * math.cos(rot) - dz * math.sin(rot), dx * math.sin(rot) + dz * math.cos(rot)

        huecos = []
        libres = [(x, z, PUESTO_LIBRE * 2) for x, z in puertas] + [tuple(l) for l in t.get("libres", [])]
        for x, z, ancho in libres:
            lx, lz = local(x, z)
            if -ancho / 2 < lx < largo + ancho / 2 and abs(lz) < arroyo / 2 + t.get("banqueta", 1.5) + 3.0:
                huecos.append([1 if lz > 0 else -1, round(lx - ancho / 2, 2), round(lx + ancho / 2, 2)])
        reservados = []
        for p in datos.get("puestos_calle", []):
            if p.get("bajo_carpa"):
                lx, lz = local(p["x"], p["z"])
                if 0 < lx < largo and abs(lz) < arroyo / 2:
                    reservados.append([1 if lz > 0 else -1, round(lx, 2), round(p["ancho"] + 0.5, 2)])
        marca = {"nombre": t["nombre"], "tipo": "tianguis", "x": ax, "z": az, "rot": round(rot, 4),
                 "largo": round(largo, 2), "arroyo": arroyo, "pasillo": t.get("pasillo", 2.6),
                 "semilla": t.get("semilla", 7), "huecos": huecos, "reservados": reservados}
        # Tramos por giro (el tianguis de La Gotera): solo esos giros y el color de sus lonas
        for llave in ("giros", "lona"):
            if llave in t:
                marca[llave] = t[llave]
        marcas.append(marca)
    return marcas


def exportar(nombre):
    leer(nombre)
    datos = leer_colonia(nombre)
    sc = bpy.data.scenes[nombre_escena(nombre)]
    salida = os.path.join(MODELOS, nombre)
    os.makedirs(salida, exist_ok=True)

    # Blender le pone ".001" al nombre si la coleccion ya existia en otra escena
    mundo = next(c for c in sc.collection.children if c.name.startswith(MUNDO))
    with bpy.context.temp_override(scene=sc, view_layer=sc.view_layers[0]):
        for ob in sc.objects:
            ob.select_set(False)
        for ob in mundo.all_objects:
            ob.hide_set(False)
            ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(salida, nombre + ".glb"), export_format="GLB",
                                  use_selection=True, use_active_scene=True, export_animations=False,
                                  export_yup=True, export_materials="EXPORT", export_apply=True,
                                  export_image_format="NONE", export_vertex_color="ACTIVE")
        # Las cajas de choque se vuelven a esconder (para exportar tenian que verse) y no se deja
        # nada seleccionado
        for ob in mundo.all_objects:
            ob.select_set(False)
            if ob.name.endswith("-colonly"):
                ob.hide_set(True)

    # RAPIDO=1 (al estar probando): sin guardar el .blend ni rehacer el minimapa, que son lo lento
    # y no los usa el juego para correr. Antes de commitear hay que correrlo una vez sin RAPIDO.
    rapido = os.environ.get("RAPIDO", "") not in ("", "0")
    carpeta = os.path.join(salida, "fuente")
    os.makedirs(carpeta, exist_ok=True)
    open(os.path.join(carpeta, ".gdignore"), "w").close()
    if rapido:
        print("RAPIDO: sin .blend ni minimapa")
    else:
        bpy.data.libraries.write(os.path.join(carpeta, nombre + ".blend"), {sc}, fake_user=True, compress=True)

    datos_dir = os.path.join(DATOS, nombre)
    # Los focos colgados de los callejones (colonia.focos_callejones) van como marcas "foco"
    focos = [{"nombre": "Foco_%d" % i, "tipo": "foco", "x": x, "z": z, "y": round(y - 0.36, 2)}
             for i, (x, y, z, *_resto) in enumerate(focos_callejones(datos))]
    # Y los de los tuneles de La Gotera (piezas tunel y tunel_cuarto: piezas.focos_de_tunel)
    pz = _piezas()
    for p in datos.get("piezas", []):
        if p["tipo"] in ("tunel", "tunel_cuarto"):
            c, s = math.cos(p.get("rot", 0.0)), math.sin(p.get("rot", 0.0))
            for lx, ly, lz in pz["focos_de_tunel"](p):
                focos.append({"nombre": "Foco_%d" % len(focos), "tipo": "foco", "x": round(p["x"] + lx * c + lz * s, 2),
                              "z": round(p["z"] - lx * s + lz * c, 2), "y": round(p.get("y", 0.0) + ly, 2)})
    # Y el botin de las azoteas (colonia.botin_azoteas) como marcas "botin"
    botin = [{"nombre": "Botin_%d" % i, "tipo": "botin", "que": que, "x": x, "z": z, "y": y}
             for i, (x, y, z, que) in enumerate(botin_azoteas(datos))]
    # Y las placas de las calles (colonia.placas_calles) como marcas "placa"
    placas = [dict(pl, nombre="Placa_%d" % i, tipo="placa") for i, pl in enumerate(placas_calles(datos))]
    # Y los tramos de tianguis como marcas "tianguis"
    tianguis = tianguis_marcas(datos)
    # El recorte va tambien: MapaColonia.gd le da ese rectangulo al Horizonte
    # "abierto_24h": MapaColonia.abierto_24h (tiendas y tianguis de noche, sin zombis)
    salida = {"colonia": nombre, "recorte": datos["recorte"]}
    if datos.get("abierto_24h"):
        salida["abierto_24h"] = True
    # "ambiente": niebla, lejos (camara) y gente de una colonia cerrada (MapaColonia._ambiente)
    if datos.get("ambiente"):
        salida["ambiente"] = datos["ambiente"]
    # Las marcas que ponen las piezas (el tambo de MapAlumbrado de las plazas: piezas._tambo)
    de_piezas = [dict(m, nombre="%s_p%d" % (m["tipo"], i)) for i, m in enumerate(json.loads(sc.get("marcas_pieza", "[]")))]
    salida["marcas"] = datos.get("marcas", []) + focos + botin + placas + tianguis + mesas_fondas(datos) + de_piezas
    guardar_json(os.path.join(datos_dir, "marcas.json"), salida)
    guardar_json(os.path.join(datos_dir, "puntos.json"), {"puntos": datos.get("negocios", []) + datos.get("puestos_calle", [])})
    # Los arboles de Sketchfab (tipos 1 a 3 de kit.arbol_tipo): [x, z, altura, ancho de copa, nombre]
    arbol_tipo, extra = _kit()["arbol_tipo"], _kit()["ARBOLES_EXTRA"]
    modelo = [[p["x"], p["z"], round((p.get("alto", 4.2) + p.get("radio", 2.0)) * 1.5, 1), round(p.get("radio", 2.0) * 4.6, 1), extra[arbol_tipo(p["nombre"]) - 1]]
              for p in datos.get("piezas", []) if p["tipo"] == "ficus" and arbol_tipo(p["nombre"]) >= 1]
    guardar_json(os.path.join(datos_dir, "arboles_modelo.json"), {"arboles": modelo})
    # Props de la libreria puestos por el generador (las cuevas de la favela), la silla de cada
    # patio y los que ponen las piezas y la basura de los callejones (colonia.PROPS_PIEZA: llantas,
    # bolsas, garrafones, cubetas): [x, z, giro, pack, nodo, y, choca, medida(, tumbada)]; los pone
    # scripts/mapa/PropsColonia.gd
    props = datos.get("props", []) + sillas_patios(datos) + json.loads(sc.get("props_pieza", "[]"))
    if props:
        guardar_json(os.path.join(datos_dir, "props_modelo.json"), {"props": props})
    # Los carros de Sketchfab (models/vehiculos): [x, z, giro, modelo, estado, y]; los dibuja scripts/mapa/CarrosColonia.gd
    carros = [c for c in json.loads(sc.get("carros_modelo", "[]"))
              if not any(abs(c[0] - ox) < 0.05 and abs(c[1] - oz) < 0.05 for ox, oz in CARROS_OMITIDOS.get(nombre, []))]
    guardar_json(os.path.join(datos_dir, "carros_modelo.json"), {"carros": carros})
    guardar_json(os.path.join(datos_dir, "alumbrado.json"), {"postes": datos.get("postes", [])})
    guardar_json(os.path.join(datos_dir, "casas.json"), {"casas": casas_juego(datos)})
    guardar_json(os.path.join(datos_dir, "banquetas.json"), {"banquetas": banquetas(datos)})
    # El minimapa propio de la favela (sin OSM): callejones, claros, tuneles, tablones e iconos
    if datos.get("favela") and not rapido:
        _mm = {"__name__": "minimapa_colonia"}
        raiz = os.environ.get("TAQUITO_RAIZ", "") or os.getcwd()
        exec(open(os.path.join(raiz, "tools", "blender", "mapa", "minimapa_colonia.py"), encoding="utf-8").read(), _mm)
        _mm["generar"](datos)
    print("colonia %s exportada: %d objetos, %d marcas" % (nombre, len(mundo.all_objects), len(datos.get("marcas", []))))


if not globals().get("SOLO_FUNCIONES"):
    exportar(globals().get("COLONIA", "santa_mugre"))
