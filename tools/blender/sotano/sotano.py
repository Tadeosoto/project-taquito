# El Sotano: el casino clandestino de los Gotera bajo Santa Mugre (docs/lore.md 11, docs/sistemas/sotano.md).
# Arma en Blender el cuarto y lo exporta a models/sotano/sotano.glb; tools/construir_sotano.gd lo
# vuelve scenes/casas/sotano.tscn (materiales del juego, luces, lo que se juega).
#
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\sotano"
#   exec(open(R + r"\sotano.py", encoding="utf-8").read(), {"__name__": "sotano"})
#
# Todo va en metros de la ESCENA (CasaPropia la agranda x1.25 al entrar) y en coordenadas de
# Godot: x al este, y arriba, z al sur. Blender: (x, -z, y). La puerta es la de todas las casas
# (CasaPropia.PUERTA, x = 0, z = 3.11): un descanso a nivel de la calle, una escalera que baja al
# este y el cuarto 2.6 abajo.
#
# Nombres: el material de cada pieza es su nombre en el juego (construir_sotano.gd los cambia por
# los suyos). Sufijo "-convcol": la pieza choca (caja convexa); "-colonly": solo choca, no se ve.
# Los caballitos (Caballo_1..5) y los objetos "Marca_*" (vacios) los usa scripts/sotano/Sotano.gd.

import bpy
import math
import os
from mathutils import Vector

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
SALIDA = os.path.join(RAIZ, "models", "sotano")

PISO = -2.6           # el piso de los salones
TECHO = -0.2          # 2.4 de alto (3 m en el juego)
SALON = (6.6, 20.6, -2.0, 8.0)    # salon 1, las maquinitas: x0, x1, z0, z1
SALON2 = (21.0, 31.0, -1.0, 7.0)  # salon 2, poker y barra: x0, x1, z0, z1 (el muro de en medio va de 20.6 a 21.0)
ARCO = (2.0, 4.4, -0.6)           # el arco entre salones: z de las jambas y su alto
COLUMNAS = ((11.0, 3.0), (16.0, 3.0))
PASILLO = (2.3, 3.9)              # z del descanso y la escalera
ESCALERA = (2.8, 6.6)             # x donde baja
PELDANOS = 13
GRUESO = 0.4


def _b(x, y, z):
    return Vector((x, -z, y))


def limpiar():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    # Los materiales tambien: uno con una textura de vista previa la metia al .glb
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


def coleccion(nombre):
    col = bpy.data.collections.get(nombre) or bpy.data.collections.new(nombre)
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    return col


def material(nombre, color=(0.6, 0.6, 0.6), emision=0.0):
    m = bpy.data.materials.get(nombre)
    if m:
        return m
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if emision > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emision
    m.diffuse_color = (*color, 1.0)
    return m


def _afuera(me):
    """Las caras viendo hacia afuera (las cajas salian al reves: se veian huecas y el piso visible
    quedaba 0.4 abajo del de verdad, todo parecia flotar)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()


def caja(nombre, x0, x1, y0, y1, z0, z1, mat, col, choca=True, giro=None):
    """Una caja de x0..x1, y0..y1, z0..z1 (Godot). `giro`: (eje, grados, pivote) opcional."""
    me = bpy.data.meshes.new(nombre)
    sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
    v = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5),
         (-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5)]
    # en Blender: x = x, y = -z, z = y
    verts = [Vector((a * sx, b * sz, c * sy)) for a, b, c in v]
    caras = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    me.from_pydata(verts, [], caras)
    me.update()
    _afuera(me)
    _uv_caja(me)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre + ("-convcol" if choca else ""), me)
    ob.location = _b((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    if giro:
        ob.rotation_euler = giro
    col.objects.link(ob)
    return ob


def _uv_caja(me):
    """UV por cara en metros (triplanar a mano): el juego usa texturas que se repiten."""
    uv = me.uv_layers.new(name="UV")
    for poly in me.polygons:
        n = poly.normal
        for li in poly.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            if abs(n.z) > 0.7:
                uv.data[li].uv = (p.x, p.y)
            elif abs(n.x) > 0.7:
                uv.data[li].uv = (p.y, p.z)
            else:
                uv.data[li].uv = (p.x, p.z)


def plano(nombre, centro, ancho, alto, normal, mat, col, uv=(0, 0, 1, 1)):
    """Un cuadro vertical (o del techo) de `ancho` x `alto`, viendo hacia `normal` (Godot), con su
    UV en `uv` = (u0, v0, u1, v1) de un atlas."""
    me = bpy.data.meshes.new(nombre)
    n = Vector(normal).normalized()
    arriba = Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((0, 0, -1))
    lado = arriba.cross(n).normalized()
    arriba = n.cross(lado).normalized()
    c = Vector(centro)
    pts = [c - lado * ancho / 2 - arriba * alto / 2, c + lado * ancho / 2 - arriba * alto / 2,
           c + lado * ancho / 2 + arriba * alto / 2, c - lado * ancho / 2 + arriba * alto / 2]
    me.from_pydata([_b(*p) for p in pts], [], [(0, 1, 2, 3)])
    me.update()
    u0, v0, u1, v1 = uv
    capa = me.uv_layers.new(name="UV")
    for li, (u, v) in zip(me.polygons[0].loop_indices, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]):
        capa.data[li].uv = (u, v)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def marca(nombre, x, y, z, col, giro_y=0.0):
    ob = bpy.data.objects.new("Marca_" + nombre, None)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = 0.3
    ob.location = _b(x, y, z)
    ob.rotation_euler = (0, 0, math.radians(giro_y))
    col.objects.link(ob)
    return ob


def cilindro(nombre, x, y0, y1, z, radio, mat, col, lados=8):
    """Un cilindro de pie (sin operadores: corre en un archivo vacio)."""
    import bmesh
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=lados, radius1=radio, radius2=radio, depth=y1 - y0)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    ob.location = _b(x, (y0 + y1) / 2, z)
    col.objects.link(ob)
    return ob


def cuarto():
    """Los muros (GRUESO, 0.4), el descanso, la escalera con zancas y barandal, el salon de las
    maquinitas (SALON) y, por un arco en su muro este, el salon del poker y la barra (SALON2)."""
    col = coleccion("Sotano")
    piso = material("concreto_piso", (0.42, 0.40, 0.37))
    muro = material("block", (0.55, 0.53, 0.5))
    techo = material("concreto_techo", (0.35, 0.34, 0.33))
    humedad = material("humedad", (0.18, 0.2, 0.17))
    viga = material("concreto_columna", (0.5, 0.49, 0.46))
    metal = material("metal", (0.35, 0.36, 0.38))
    g = GRUESO
    za, zb = PASILLO
    x0, x1, z0, z1 = SALON
    a0, a1, b0, b1 = SALON2
    # El descanso, a nivel de la calle, con la puerta en la pared oeste (CasaPropia.PUERTA)
    caja("Descanso_piso", 0.0, ESCALERA[0], -g, 0.0, za, zb, piso, col)
    caja("Descanso_techo", -g, ESCALERA[0], 2.3, 2.3 + g, za - g, zb + g, techo, col)
    caja("Descanso_muro_oeste_n", -g, 0.0, -g, 2.5, za - g, 2.61, muro, col)
    caja("Descanso_muro_oeste_s", -g, 0.0, -g, 2.5, 3.61, zb + g, muro, col)
    caja("Descanso_dintel", -g, 0.0, 2.0, 2.5, 2.61, 3.61, muro, col)
    caja("Puerta", -0.25, -0.2, 0.0, 2.0, 2.61, 3.61, material("lamina_puerta", (0.25, 0.3, 0.28)), col)
    caja("Puerta_marco_n", -0.05, 0.05, 0.0, 2.08, 2.53, 2.61, metal, col, choca=False)
    caja("Puerta_marco_s", -0.05, 0.05, 0.0, 2.08, 3.61, 3.69, metal, col, choca=False)
    caja("Puerta_marco_arriba", -0.05, 0.05, 2.0, 2.08, 2.53, 3.69, metal, col, choca=False)
    # Pasillo de la escalera: muros gruesos a los lados, de la puerta al salon
    caja("Pasillo_muro_n", 0.0, x0, PISO, 2.3, za - g, za, muro, col)
    caja("Pasillo_muro_s", 0.0, x0, PISO, 2.3, zb, zb + g, muro, col)
    # Los peldanos: cada uno macizo hasta el piso, con su nariz mas oscura (se ven) y la rampa
    # que se camina (no se ve)
    paso = (ESCALERA[1] - ESCALERA[0]) / PELDANOS
    alto = (0.0 - PISO) / PELDANOS
    concreto = material("concreto_escalon", (0.5, 0.48, 0.44))
    nariz = material("concreto_nariz", (0.3, 0.29, 0.27))
    zancas = 0.12
    for i in range(PELDANOS):
        xa = ESCALERA[0] + i * paso
        ya = -alto * (i + 1)
        caja("Escalon_%02d" % i, xa, xa + paso, PISO, ya, za + zancas, zb - zancas, concreto, col, choca=False)
        caja("Escalon_nariz_%02d" % i, xa - 0.02, xa + 0.04, ya - 0.04, ya + 0.005, za + zancas, zb - zancas, nariz, col, choca=False)
    # Zancas: el concreto de los lados, que sube con la escalera (en tres tramos escalonados)
    for i in range(PELDANOS):
        xa = ESCALERA[0] + i * paso
        ya = -alto * (i + 1)
        for nombre, c0, c1 in (("n", za, za + zancas), ("s", zb - zancas, zb)):
            caja("Zanca_%s_%02d" % (nombre, i), xa, xa + paso, PISO, ya + 0.12, c0, c1, viga, col, choca=False)
    largo = math.hypot(ESCALERA[1] - ESCALERA[0], -PISO)
    ang = math.atan2(-PISO, ESCALERA[1] - ESCALERA[0])
    rampa = caja("Rampa", 0.0, largo, -0.1, 0.0, za, zb, piso, col, choca=False)
    rampa.name = "Rampa-colonly"
    rampa.location = _b((ESCALERA[0] + ESCALERA[1]) / 2, PISO / 2 - 0.05, (za + zb) / 2)
    rampa.rotation_euler = (0, ang, 0)
    # El barandal: un tubo en la pared norte, con sus soportes
    ya, yb = 0.9, PISO + 0.9
    cable_recto("Barandal", Vector((ESCALERA[0], ya, za + 0.08)), Vector((ESCALERA[1], yb, za + 0.08)), metal, col, r=0.025)
    for k in range(4):
        t = (k + 0.5) / 4
        xs = ESCALERA[0] + (ESCALERA[1] - ESCALERA[0]) * t
        ys = ya + (yb - ya) * t
        cable_recto("Barandal_soporte_%d" % k, Vector((xs, ys, za + 0.08)), Vector((xs, ys, za + 0.0)), metal, col, r=0.015)
    # El techo del pasillo baja con la escalera, en tramos
    for i, (xa, xb, y) in enumerate(((ESCALERA[0], 4.1, 1.6), (4.1, 5.4, 0.7), (5.4, x0, TECHO + 0.3))):
        caja("Pasillo_techo_%d" % i, xa, xb, y, y + g, za - g, zb + g, techo, col)
    # Salon 1 (maquinitas)
    caja("Piso", x0, x1, PISO - g, PISO, z0, z1, piso, col)
    caja("Techo", x0 - g, x1 + g, TECHO, TECHO + g, z0 - g, z1 + g, techo, col)
    caja("Muro_norte", x0 - g, x1 + g, PISO, TECHO, z0 - g, z0, muro, col)
    caja("Muro_sur", x0 - g, x1 + g, PISO, TECHO, z1, z1 + g, muro, col)
    caja("Muro_oeste_n", x0 - g, x0, PISO, TECHO, z0, za - g, muro, col)
    caja("Muro_oeste_s", x0 - g, x0, PISO, TECHO, zb + g, z1, muro, col)
    caja("Muro_oeste_dintel", x0 - g, x0, TECHO + 0.3, TECHO, za - g, zb + g, muro, col)
    # El muro entre los salones, con el arco (ARCO: z de las jambas, y el alto)
    c0, c1, arco_y = ARCO
    caja("Muro_medio_n", x1, a0, PISO, TECHO, z0, c0, muro, col)
    caja("Muro_medio_s", x1, a0, PISO, TECHO, c1, z1, muro, col)
    caja("Muro_medio_arco", x1, a0, arco_y, TECHO, c0, c1, muro, col)
    for nombre, ca, cb in (("Jamba_n", c0 - 0.06, c0 + 0.06), ("Jamba_s", c1 - 0.06, c1 + 0.06)):
        caja(nombre, x1 - 0.06, a0 + 0.06, PISO, arco_y, ca, cb, viga, col, choca=False)
    caja("Arco_dintel", x1 - 0.06, a0 + 0.06, arco_y - 0.12, arco_y, c0 - 0.06, c1 + 0.06, viga, col, choca=False)
    # Salon 2 (poker y barra)
    caja("Piso2", x1, a1, PISO - g, PISO, b0, b1, piso, col)
    caja("Techo2", a0, a1 + g, TECHO, TECHO + g, b0 - g, b1 + g, techo, col)
    caja("Muro2_norte", a0, a1 + g, PISO, TECHO, b0 - g, b0, muro, col)
    caja("Muro2_sur", a0, a1 + g, PISO, TECHO, b1, b1 + g, muro, col)
    caja("Muro2_este", a1, a1 + g, PISO, TECHO, b0, b1, muro, col)
    # Lo que tapa el hueco entre los salones donde sus muros no coinciden (arriba y abajo del salon 2)
    if b0 > z0:
        caja("Muro_medio_tapa_n", a0, a0 + g, PISO, TECHO, z0, b0, muro, col)
    if b1 < z1:
        caja("Muro_medio_tapa_s", a0, a0 + g, PISO, TECHO, b1, z1, muro, col)
    # Vigas del techo
    for i, xv in enumerate((9.6, 13.6, 17.6)):
        caja("Viga_%d" % i, xv - 0.15, xv + 0.15, TECHO - 0.25, TECHO, z0, z1, viga, col, choca=False)
    for i, xv in enumerate((24.0, 28.0)):
        caja("Viga2_%d" % i, xv - 0.15, xv + 0.15, TECHO - 0.25, TECHO, b0, b1, viga, col, choca=False)
    # Rodapie de humedad
    for nombre, a, b, c, d in (("Humedad_n", x0, x1, z0, z0 + 0.01), ("Humedad_s", x0, x1, z1 - 0.01, z1),
                               ("Humedad2_n", a0, a1, b0, b0 + 0.01), ("Humedad2_s", a0, a1, b1 - 0.01, b1)):
        caja(nombre, a, b, PISO, PISO + 0.35, c, d, humedad, col, choca=False)
    # Columnas del salon 1
    for i, (cx, cz) in enumerate(COLUMNAS):
        caja("Columna_%d" % i, cx - 0.2, cx + 0.2, PISO, TECHO, cz - 0.2, cz + 0.2, viga, col)
    return col


def utileria(col):
    metal = material("metal", (0.35, 0.36, 0.38))
    madera = material("madera", (0.45, 0.32, 0.2))
    reja = material("reja", (0.15, 0.15, 0.16))
    tubo = material("tubo", (0.95, 0.97, 1.0), emision=3.0)
    cable = material("cable", (0.05, 0.05, 0.05))
    x0, x1, z0, z1 = SALON
    a0, a1, b0, b1 = SALON2
    y = PISO
    # La ventanilla del Primo, esquina noroeste: mostrador a 1 m y reja de barrotes separados
    # (se le ve de la cintura para arriba), su lampara, la caja del dinero y un ventilador de mesa
    caja("Ventanilla_muro_e", 9.8, 10.2, y, TECHO, z0, 0.0, material("block"), col)
    caja("Ventanilla_mostrador", x0, 9.8, y, y + 1.0, -0.25, 0.1, madera, col)
    caja("Ventanilla_mostrador_tapa", x0, 9.85, y + 1.0, y + 1.05, -0.3, 0.16, material("madera_oscura", (0.3, 0.2, 0.12)), col, choca=False)
    xs = x0 + 0.1
    i = 0
    while xs < 9.75:
        caja("Ventanilla_barrote_%02d" % i, xs - 0.012, xs + 0.012, y + 1.05, TECHO, -0.07, -0.04, reja, col, choca=False)
        xs += 0.2
        i += 1
    caja("Ventanilla_travesano", x0, 9.8, y + 1.85, y + 1.9, -0.08, -0.03, reja, col, choca=False)
    caja("Ventanilla_reja_choque", x0, 9.8, y + 1.05, TECHO, -0.08, -0.03, reja, col, choca=False).name = "Ventanilla_reja-colonly"
    caja("Ventanilla_caja_dinero", 8.6, 9.0, y + 1.05, y + 1.15, -0.25, 0.0, material("metal_verde", (0.2, 0.35, 0.25)), col, choca=False)
    caja("Ventanilla_ventilador", 7.2, 7.4, y + 1.05, y + 1.35, -0.25, -0.1, material("plastico_blanco", (0.9, 0.9, 0.86)), col, choca=False)
    cilindro("Ventanilla_lampara_cable", 8.2, TECHO - 0.5, TECHO, -0.9, 0.01, cable, col, lados=4)
    cilindro("Ventanilla_lampara", 8.2, TECHO - 0.62, TECHO - 0.5, -0.9, 0.16, material("lampara_verde", (0.15, 0.45, 0.25)), col, lados=10)
    marca("Primo", 8.2, y, -0.85, col, 0)
    marca("Ventanilla", 8.2, y, 0.9, col, 0)
    marca("Luz_ventanilla", 8.2, TECHO - 0.7, -0.9, col, 0)
    # El de la puerta y su cadena al pie de la escalera
    marca("Guardia", 7.3, y, 1.6, col, 180)
    caja("CadenaChoque-colonly", 6.5, 6.7, y, y + 2.0, PASILLO[0], PASILLO[1], reja, col, choca=False)
    for k in range(2):
        cilindro("Poste_cadena_%d" % k, 6.75, y, y + 0.9, PASILLO[0] + 0.15 + k * 1.3, 0.04, metal, col)
    caja("Cadena", 6.73, 6.77, y + 0.78, y + 0.82, PASILLO[0] + 0.15, PASILLO[1] - 0.15, reja, col, choca=False)
    # Las OL PLEY: ocho en el muro norte y dos en el sur, viendo al salon
    for k in range(8):
        marca("OlPley_%d" % k, 11.0 + k * 1.2, y, z0 + 0.45, col, 0)
        cilindro("Silla_%d" % k, 11.0 + k * 1.2, y, y + 0.45, z0 + 1.25, 0.18, material("plastico_blanco"), col)
        marca("Silla_%d" % k, 11.0 + k * 1.2, y, z0 + 1.25, col, 0)
    for k in range(2):
        marca("OlPley_%d" % (8 + k), 17.2 + k * 1.2, y, z1 - 0.45, col, 180)
    # Dos de frutas en el muro oeste, al sur del pasillo, viendo al este (al salon)
    marca("Frutas_0", x0 + 0.45, y, 5.6, col, 90)
    marca("Frutas_1", x0 + 0.45, y, 6.9, col, 90)
    # El altar de la Virgen del Tinaco, muro sur
    caja("Altar_repisa", 12.6, 13.8, y + 1.0, y + 1.06, z1 - 0.35, z1, madera, col, choca=False)
    plano("Altar_estampa", (13.2, y + 1.5, z1 - 0.02), 0.7, 0.9, (0, 0, -1), material("estampa_virgen", (0.3, 0.5, 0.8)), col)
    for k in range(9):
        plano("Billete_%d" % k, (12.75 + (k % 3) * 0.45, y + 1.2 + (k // 3) * 0.4, z1 - 0.015), 0.16, 0.07, (0, 0, -1), material("billete", (0.55, 0.75, 0.55)), col)
    for k in range(5):
        cilindro("Veladora_%d" % k, 12.75 + k * 0.22, y + 1.06, y + 1.18, z1 - 0.15, 0.03, material("veladora", (1.0, 0.75, 0.3), emision=2.0), col, lados=6)
    marca("Altar", 13.2, y, z1 - 0.9, col, 180)
    # Huacales y la bocina
    caja("Huacal_bocina", 9.6, 10.1, y, y + 0.35, z1 - 0.6, z1 - 0.1, material("plastico_amarillo", (0.9, 0.75, 0.1)), col)
    caja("Bocina", 9.65, 10.05, y + 0.35, y + 1.0, z1 - 0.55, z1 - 0.15, material("bocina", (0.08, 0.08, 0.09)), col)
    marca("Bocina", 9.85, y + 0.7, z1 - 0.35, col, 0)
    for k, (hx, hy, hz) in enumerate(((x1 - 0.4, 0, z1 - 0.3), (x1 - 0.4, 0.3, z1 - 0.3), (x1 - 0.95, 0, z1 - 0.3), (x0 + 0.4, 0, z0 + 2.6), (x0 + 0.4, 0.3, z0 + 2.6))):
        caja("Huacal_%d" % k, hx - 0.25, hx + 0.25, y + hy, y + hy + 0.3, hz - 0.18, hz + 0.18, material("plastico_rojo", (0.75, 0.1, 0.1)), col)
    # Salon 2: la barra en el muro norte (contrabarra con botellas, refri con luz, barra, bancos)
    caja("Contrabarra", 22.6, 29.4, y, y + 0.9, b0, b0 + 0.45, madera, col)
    for nivel in range(2):
        caja("Repisa_%d" % nivel, 22.6, 28.4, y + 1.3 + nivel * 0.4, y + 1.33 + nivel * 0.4, b0, b0 + 0.3, madera, col, choca=False)
        for k in range(16):
            bx = 22.75 + k * 0.35
            color = ((0.25, 0.45, 0.15), (0.45, 0.25, 0.1), (0.85, 0.75, 0.6), (0.2, 0.2, 0.55))[(k + nivel) % 4]
            cilindro("Botella_%d_%02d" % (nivel, k), bx, y + 1.33 + nivel * 0.4, y + 1.55 + nivel * 0.4, b0 + 0.15, 0.035, material("botella_%d" % ((k + nivel) % 4), color), col, lados=6)
    caja("Refri", 28.6, 29.6, y, y + 1.9, b0, b0 + 0.7, material("refri", (0.85, 0.1, 0.1)), col)
    caja("Refri_vidrio", 28.68, 29.52, y + 0.15, y + 1.75, b0 + 0.7, b0 + 0.72, material("refri_luz", (0.85, 0.95, 1.0), emision=1.5), col, choca=False)
    caja("Barra", 22.6, 28.4, y, y + 1.05, b0 + 1.2, b0 + 1.65, madera, col)
    caja("Barra_tapa", 22.55, 28.45, y + 1.05, y + 1.1, b0 + 1.15, b0 + 1.75, material("madera_oscura"), col, choca=False)
    for k in range(3):
        cilindro("Grifo_%d" % k, 24.6 + k * 0.3, y + 1.1, y + 1.4, b0 + 1.35, 0.025, metal, col, lados=6)
    for k in range(5):
        cilindro("Banco_barra_%d" % k, 23.2 + k * 1.1, y, y + 0.75, b0 + 2.25, 0.17, material("plastico_rojo"), col)
        marca("Banco_barra_%d" % k, 23.2 + k * 1.1, y, b0 + 2.25, col, 0)
    marca("Cantinero", 25.6, y, b0 + 0.85, col, 0)
    marca("Barra", 25.6, y, b0 + 2.6, col, 0)
    marca("Neon_barra", 25.5, y + 1.95, b0 + 0.05, col, 0)
    # La mesa del poker al centro: pano verde, borde acolchado, fichas y los lugares
    mx, mz = 26.0, b0 + 4.6
    caja("Poker_pata", mx - 0.25, mx + 0.25, y, y + 0.72, mz - 0.25, mz + 0.25, madera, col, choca=False)
    caja("Poker_pano", mx - 1.3, mx + 1.3, y + 0.72, y + 0.78, mz - 0.75, mz + 0.75, material("fieltro_verde", (0.1, 0.35, 0.15)), col, choca=False)
    for nombre, xa, xb, za_, zb_ in (("n", mx - 1.4, mx + 1.4, mz - 0.85, mz - 0.75), ("s", mx - 1.4, mx + 1.4, mz + 0.75, mz + 0.85),
                                     ("o", mx - 1.4, mx - 1.3, mz - 0.75, mz + 0.75), ("e", mx + 1.3, mx + 1.4, mz - 0.75, mz + 0.75)):
        caja("Poker_borde_%s" % nombre, xa, xb, y + 0.72, y + 0.84, za_, zb_, material("cuero_negro", (0.08, 0.06, 0.06)), col, choca=False)
    caja("Poker_choque", mx - 1.4, mx + 1.4, y, y + 0.84, mz - 0.85, mz + 0.85, madera, col, choca=False).name = "Poker_choque-colonly"
    for k, (fx, fz) in enumerate(((mx - 0.9, mz - 0.3), (mx + 0.9, mz - 0.3), (mx - 0.6, mz + 0.4), (mx + 0.6, mz + 0.4))):
        for n in range(4):
            cilindro("Ficha_%d_%d" % (k, n), fx, y + 0.78 + n * 0.012, y + 0.79 + n * 0.012, fz, 0.03, material("ficha_%d" % (n % 3), ((0.85, 0.1, 0.1), (0.1, 0.3, 0.85), (0.95, 0.95, 0.9))[n % 3]), col, lados=8)
    lugares = {"Poker_tu": (mx, mz + 1.35, 180), "Poker_0": (mx - 1.9, mz, 90), "Poker_1": (mx - 0.9, mz - 1.35, 0), "Poker_2": (mx + 1.9, mz, -90)}
    for nombre, (px, pz, giro) in lugares.items():
        marca(nombre, px, y, pz, col, giro)
        if nombre != "Poker_tu":
            cilindro("Silla_" + nombre, px, y, y + 0.45, pz, 0.2, material("plastico_blanco"), col)
    marca("Crupier", mx + 0.9, y, mz - 1.3, col, 0)
    marca("Poker", mx, y, mz + 1.8, col, 180)
    cilindro("Poker_lampara_cable", mx, TECHO - 0.7, TECHO, mz, 0.01, cable, col, lados=4)
    cilindro("Poker_lampara", mx, TECHO - 0.85, TECHO - 0.7, mz, 0.4, material("lampara_verde"), col, lados=12)
    marca("Luz_poker", mx, TECHO - 0.95, mz, col, 0)
    # La pista de los caballitos en el muro sur del salon 2: corren a lo largo de x
    caja("Pista_mesa", 22.0, 29.6, y + 0.85, y + 0.92, b1 - 1.5, b1 - 0.1, material("fieltro_verde"), col)
    caja("Pista_choque", 22.0, 29.6, y, y + 0.92, b1 - 1.5, b1 - 0.1, madera, col, choca=False).name = "Pista_choque-colonly"
    caja("Pista_faldon", 22.0, 29.6, y, y + 0.85, b1 - 1.52, b1 - 1.48, madera, col, choca=False)
    caja("Pista_meta", 28.9, 28.95, y + 0.92, y + 0.93, b1 - 1.5, b1 - 0.1, material("pintura_blanca", (0.95, 0.95, 0.9)), col, choca=False)
    colores = ((0.85, 0.15, 0.1), (0.1, 0.35, 0.85), (0.95, 0.8, 0.1), (0.1, 0.7, 0.25), (0.8, 0.4, 0.9))
    for k in range(5):
        zr = b1 - 1.3 + k * 0.27
        caja("Riel_%d" % k, 22.2, 29.4, y + 0.92, y + 0.95, zr - 0.01, zr + 0.01, metal, col, choca=False)
        caballo(k, 22.5, y + 0.95, zr, material("caballo_%d" % (k + 1), colores[k]), col)
    marca("Pista", 25.8, y, b1 - 2.2, col, 0)
    # El congelador de las caguamas y la puerta del bano
    caja("Congelador", a0 + 0.3, a0 + 1.7, y, y + 0.9, b0 + 2.6, b0 + 3.3, material("congelador", (0.85, 0.85, 0.88)), col)
    caja("Congelador_tapa", a0 + 0.35, a0 + 1.65, y + 0.9, y + 0.93, b0 + 2.63, b0 + 3.27, material("vidrio", (0.4, 0.55, 0.6)), col, choca=False)
    marca("Congelador", a0 + 1.0, y, b0 + 3.9, col, 180)
    caja("Bano_puerta", a1 - 0.06, a1, y, y + 2.0, b1 - 3.4, b1 - 2.5, material("lamina_puerta"), col, choca=False)
    marca("Bano", a1 - 0.6, y, b1 - 2.95, col, -90)
    marca("Neon_bano", a1 - 0.02, y + 2.15, b1 - 2.95, col, -90)
    # Tubos de luz en los dos salones
    tubos = [(9.0, 3.0), (12.6, 0.6), (16.6, 0.6), (12.6, 5.4), (16.6, 5.4), (19.6, 3.0), (23.6, b0 + 1.0), (28.4, b1 - 1.0)]
    for k, (tx, tz) in enumerate(tubos):
        caja("Tubo_%d" % k, tx - 0.6, tx + 0.6, TECHO - 0.33, TECHO - 0.29, tz - 0.03, tz + 0.03, tubo, col, choca=False)
        marca("Luz_%d" % k, tx, TECHO - 0.4, tz, col, 0)
    # Neones del salon 1 (los arma Sotano.gd en los vacios)
    marca("Neon", 15.2, TECHO - 0.55, z0 + 0.25, col, 0)
    marca("Neon_abierto", 8.6, TECHO - 0.6, z1 - 0.25, col, 180)
    marca("Neon_poker", a1 - 0.03, TECHO - 0.55, b0 + 4.6, col, -90)
    # Anuncios de cerveza (Sotano.gd pone el cartel en cada vacio)
    for k, (ax, ay, az, giro) in enumerate(((x0 + 0.03, y + 1.5, 0.9, 90), (11.6, y + 1.6, z1 - 0.03, 180), (15.4, y + 1.6, z1 - 0.03, 180),
                                             (a0 + 0.23, y + 1.6, b0 + 1.0, 90), (a1 - 0.03, y + 1.6, b0 + 1.6, -90), (24.2, y + 1.7, b1 - 0.03, 180))):
        marca("Anuncio_%d" % k, ax, ay, az, col, giro)
    # Cables por el techo y extensiones
    for k, (pa, pb) in enumerate((((9.0, 3.0), (12.6, 0.6)), ((12.6, 0.6), (16.6, 0.6)), ((12.6, 0.6), (12.6, 5.4)), ((16.6, 0.6), (19.6, 3.0)))):
        cable_recto("Cable_techo_%d" % k, Vector((pa[0], TECHO - 0.27, pa[1])), Vector((pb[0], TECHO - 0.27, pb[1])), cable, col)
    for k, (pa, pb) in enumerate((((10.6, z0 + 0.3), (20.2, z0 + 0.3)), ((x0 + 0.3, 5.3), (x0 + 0.3, 6.9)), ((22.8, b1 - 1.6), (29.0, b1 - 1.6)))):
        cable_recto("Extension_%d" % k, Vector((pa[0], y + 0.01, pa[1])), Vector((pb[0], y + 0.01, pb[1])), cable, col)
    # Ventiladores de techo (uno por salon)
    for v, (vx, vz) in enumerate(((14.6, 3.0), (26.0, b0 + 2.4))):
        cilindro("Ventilador_%d_eje" % v, vx, TECHO - 0.5, TECHO - 0.25, vz, 0.03, metal, col)
        for k in range(3):
            a = math.radians(k * 120)
            aspa = caja("Ventilador_%d_aspa_%d" % (v, k), -0.05, 0.55, TECHO - 0.52, TECHO - 0.5, -0.07, 0.07, madera, col, choca=False)
            aspa.location = _b(vx + math.cos(a) * 0.3, TECHO - 0.51, vz + math.sin(a) * 0.3)
            aspa.rotation_euler = (0, 0, -a)
    # Puntos por donde camina la gente (Sotano.gd: Gente del sotano)
    for k, (px, pz) in enumerate(((8.0, 3.1), (12.0, 2.0), (15.0, 2.2), (18.5, 2.6), (19.0, 5.6), (14.0, 6.2), (10.0, 5.0),
                                  (22.4, 3.2), (24.0, b0 + 2.9), (27.5, b0 + 2.9), (29.6, b1 - 2.4), (23.0, b1 - 2.0))):
        marca("Camino_%d" % k, px, y, pz, col, 0)


def cable_recto(nombre, a, b, mat, col, r=0.012):
    """Un cable delgado de a a b (Godot)."""
    d = b - a
    largo = d.length
    me = bpy.data.meshes.new(nombre)
    verts, caras = [], []
    lado = d.cross(Vector((0, 1, 0)))
    if lado.length < 0.001:
        lado = Vector((1, 0, 0))
    lado = lado.normalized() * r
    arriba = Vector((0, r, 0)) if abs(d.normalized().y) < 0.9 else Vector((r, 0, 0))
    for p in (a, b):
        verts += [_b(*(p + lado)), _b(*(p + arriba)), _b(*(p - lado)), _b(*(p - arriba))]
    for i in range(4):
        j = (i + 1) % 4
        caras.append((i, j, j + 4, i + 4))
    me.from_pydata(verts, [], caras)
    me.update()
    _afuera(me)
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def caballo(i, x, y, z, mat, col):
    """Un caballito de lamina (silueta gruesa) parado en su riel, viendo al sur (+z)."""
    nombre = "Caballo_%d" % (i + 1)
    padre = bpy.data.objects.new(nombre, None)
    padre.location = _b(x, y, z)
    # Corre hacia +x (la pista va a lo largo del muro sur del salon 2): girado 90 grados
    padre.rotation_euler = (0, 0, math.radians(90))
    col.objects.link(padre)
    piezas = [
        ("cuerpo", -0.02, 0.02, 0.06, 0.13, -0.08, 0.08),
        ("cuello", -0.02, 0.02, 0.12, 0.2, 0.05, 0.1),
        ("cabeza", -0.02, 0.02, 0.18, 0.22, 0.08, 0.16),
        ("pata_a", -0.015, 0.015, 0.0, 0.07, 0.04, 0.07),
        ("pata_b", -0.015, 0.015, 0.0, 0.07, -0.07, -0.04),
        ("cola", -0.01, 0.01, 0.08, 0.12, -0.12, -0.08),
        ("base", -0.03, 0.03, -0.01, 0.0, -0.08, 0.08),
    ]
    for parte, a0, a1, b0, b1, c0, c1 in piezas:
        ob = caja("%s_%s" % (nombre, parte), a0, a1, b0, b1, c0, c1, mat, col, choca=False)
        ob.location = _b((a0 + a1) / 2, (b0 + b1) / 2, (c0 + c1) / 2)
        ob.parent = padre
    return padre


def gabinete():
    """La maquinita OL PLEY, como las de la foto de AG: base de lamina antiderrapante, cuerpo,
    tablero con botones, monitor con bisel y monedero, marquesina, y las calcomanias de
    textures/sotano/calcomanias.png (marquesina arriba, puerta a la izquierda, costado a la derecha,
    etiquetas abajo). Origen al centro de la base, viendo a +Z. Se exporta aparte
    (models/sotano/gabinete_olpley.glb); "gabinete" es el color del cuerpo (lo cambia el juego)."""
    col = coleccion("Gabinete")
    lamina = material("antiderrapante", (0.7, 0.72, 0.75))
    cuerpo = material("gabinete", (0.7, 0.1, 0.1))
    panel = material("panel_negro", (0.06, 0.06, 0.07))
    metal = material("metal")
    calco = material("calcomanias", (1, 1, 1))
    pantalla = material("pantalla", (0.2, 0.3, 0.9), emision=1.0)
    caja("Base", -0.33, 0.33, 0.0, 0.08, -0.3, 0.3, lamina, col, choca=False)
    caja("Cuerpo", -0.3, 0.3, 0.08, 0.92, -0.27, 0.25, cuerpo, col, choca=False)
    caja("Tablero", -0.31, 0.31, 0.92, 0.97, -0.1, 0.36, panel, col, choca=False)
    caja("Tablero_canto", -0.31, 0.31, 0.9, 0.97, 0.35, 0.37, lamina, col, choca=False)
    colores = ((0.9, 0.1, 0.1), (0.1, 0.8, 0.2), (1.0, 0.85, 0.1), (0.2, 0.4, 0.95), (0.95, 0.95, 0.95), (0.9, 0.1, 0.1))
    for i, c in enumerate(colores):
        bx = -0.24 + i * 0.075
        caja("Boton_%d" % i, bx - 0.025, bx + 0.025, 0.97, 0.985, 0.2, 0.25, material("boton_%d" % i, c, emision=0.6), col, choca=False)
    cilindro("Boton_grande", 0.2, 0.97, 0.99, 0.12, 0.045, material("boton_grande", (1.0, 0.85, 0.1), emision=0.8), col, lados=10)
    caja("Arriba", -0.3, 0.3, 0.97, 1.6, -0.27, 0.1, cuerpo, col, choca=False)
    caja("Bisel", -0.27, 0.27, 1.03, 1.52, 0.1, 0.112, panel, col, choca=False)
    plano("Pantalla", (0.0, 1.275, 0.114), 0.42, 0.33, (0, 0, 1), pantalla, col)
    caja("Monedero", 0.21, 0.28, 1.2, 1.38, 0.1, 0.14, metal, col, choca=False)
    caja("Billetero", 0.1, 0.24, 0.6, 0.72, 0.25, 0.29, metal, col, choca=False)
    caja("Marquesina", -0.31, 0.31, 1.6, 1.8, -0.27, 0.14, cuerpo, col, choca=False)
    caja("Marquesina_tapa", -0.32, 0.32, 1.8, 1.83, -0.28, 0.15, lamina, col, choca=False)
    # Calcomanias (UV en el atlas: v hacia arriba)
    plano("Calco_marquesina", (0.0, 1.7, 0.142), 0.6, 0.18, (0, 0, 1), calco, col, uv=(0.0, 0.75, 1.0, 1.0))
    plano("Calco_puerta", (0.0, 0.48, 0.252), 0.5, 0.5, (0, 0, 1), calco, col, uv=(0.0, 0.25, 0.5, 0.75))
    plano("Calco_etiqueta", (-0.2, 0.84, 0.253), 0.12, 0.12, (0, 0, 1), calco, col, uv=(0.01, 0.01, 0.24, 0.24))
    plano("Calco_tinaco", (-0.22, 1.12, 0.113), 0.07, 0.07, (0, 0, 1), calco, col, uv=(0.76, 0.01, 0.99, 0.24))
    plano("Calco_nopegue", (0.245, 0.4, 0.26), 0.09, 0.09, (0, 0, 1), calco, col, uv=(0.51, 0.01, 0.74, 0.24))
    for lado in (-1, 1):
        plano("Calco_costado_%d" % (lado + 1), (lado * 0.302, 0.5, -0.01), 0.45, 0.7, (lado, 0, 0), calco, col, uv=(0.5, 0.25, 1.0, 0.75))
        plano("Calco_costado_alto_%d" % (lado + 1), (lado * 0.302, 1.3, -0.08), 0.3, 0.45, (lado, 0, 0), calco, col, uv=(0.0, 0.25, 0.5, 0.75))
    return col


def exportar_gabinete():
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections["Gabinete"].all_objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(SALIDA, "gabinete_olpley.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT")


def exportar():
    os.makedirs(SALIDA, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections["Sotano"].all_objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(SALIDA, "sotano.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT", export_extras=False)
    fuente = os.path.join(SALIDA, "fuente")
    os.makedirs(fuente, exist_ok=True)
    open(os.path.join(fuente, ".gdignore"), "w").close()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(fuente, "sotano.blend"))


if __name__ == "sotano":
    # Corre en un archivo nuevo y vacio (File > New, o antes y aparte:
    # bpy.ops.wm.read_homefile(use_empty=True)): limpiar() borra todo lo que haya
    if bpy.data.filepath and not bpy.data.filepath.endswith("sotano.blend"):
        raise RuntimeError("sotano.py borraria " + bpy.data.filepath + ": abre un archivo nuevo primero")
    limpiar()
    utileria(cuarto())
    gabinete()
    os.makedirs(SALIDA, exist_ok=True)
    exportar_gabinete()
    exportar()
    print("sotano: %d objetos" % len(bpy.data.collections["Sotano"].all_objects))
