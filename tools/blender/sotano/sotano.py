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
import bmesh
import math
import os
import random
from mathutils import Matrix, Vector

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
SALIDA = os.path.join(RAIZ, "models", "sotano")

PISO = -2.6           # el piso de los salones
TECHO = -0.2          # 2.4 de alto (3 m en el juego)
SALON = (6.6, 20.6, -2.0, 8.0)    # salon 1, las maquinitas: x0, x1, z0, z1
SALON2 = (21.0, 35.0, -2.0, 8.0)  # salon 2, poker y barra: x0, x1, z0, z1 (el muro de en medio va de 20.6 a 21.0)
ARCO = (2.0, 4.4, -0.6)           # el arco entre salones: z de las jambas y su alto
COLUMNAS = ((11.0, 3.0), (16.0, 3.0))
PASILLO = (2.3, 3.9)              # z del descanso y la escalera
ESCALERA = (2.8, 6.6)             # x donde baja
PELDANOS = 13
GRUESO = 0.4
BANO_PUERTA = (4.6, 5.5)          # z del hueco de la puerta del bano en el muro este del salon 2
BANO = (35.4, 39.4, 3.0, 7.4)     # el bano: x0, x1, z0, z1 (detras del muro este)
BANO_ALTO = 2.2
BLACKJACK = (32.4, 2.4, 0.95)    # la mesa de blackjack: x del centro, z de la orilla recta (el crupier, al norte) y radio
RULETA = (32.6, 34.0, -0.9, 0.1)  # la mesa de la ruleta (esquina noreste del salon 2): x0, x1, z0, z1
RUEDA = (32.95, -0.4, 0.3)        # la rueda: x, z del centro y radio
REPISA_Y = 1.15                   # la primera repisa de la contrabarra (sobre el piso)
REPISA_SEPARA = 0.34
PISTA = (11.5, 17.0, 4.8, 6.0)    # la isla de los caballitos en el salon 1: x0, x1, z0, z1
PISTA_META = 16.5                 # x de la meta (Sotano.PISTA_META)
MESA = (27.5, 3.6)                # centro de la mesa del poker
ASIENTO = 0.5                     # alto del banquito y la silla: los muslos de Sitting_Idle van a 0.52 (tools/sotano/medir_sentado.gd)
BANCO_BARRA = 0.75                # los bancos altos de la barra (nadie se sienta ahi)
# Botellas: perfil (radio, alto) de abajo arriba que se gira, vidrio, etiqueta, de donde a donde
# va la etiqueta y la tapa (radio, alto)
BOTELLAS = {
    "tequila": ([(0, 0), (0.034, 0), (0.036, 0.008), (0.036, 0.16), (0.03, 0.18), (0.013, 0.2), (0.012, 0.245), (0, 0.245)],
                "vidrio_claro", "etiqueta_crema", (0.04, 0.12), "tapa_negra", (0.015, 0.025)),
    "mezcal": ([(0, 0), (0.04, 0), (0.042, 0.01), (0.042, 0.11), (0.035, 0.13), (0.014, 0.15), (0.013, 0.18), (0, 0.18)],
               "vidrio_mezcal", "etiqueta_roja", (0.03, 0.08), "tapa_corcho", (0.014, 0.02)),
    "whisky": ([(0, 0), (0.038, 0), (0.04, 0.01), (0.04, 0.15), (0.036, 0.165), (0.013, 0.185), (0.012, 0.225), (0, 0.225)],
               "vidrio_ambar", "etiqueta_negra", (0.04, 0.11), "tapa_dorada", (0.015, 0.02)),
    "ron": ([(0, 0), (0.033, 0), (0.035, 0.01), (0.035, 0.17), (0.022, 0.2), (0.012, 0.215), (0.011, 0.26), (0, 0.26)],
            "vidrio_cafe", "etiqueta_amarilla", (0.05, 0.13), "tapa_negra", (0.013, 0.02)),
    "cerveza": ([(0, 0), (0.026, 0), (0.028, 0.006), (0.028, 0.09), (0.022, 0.115), (0.011, 0.145), (0.01, 0.17), (0, 0.17)],
                "vidrio_ambar", "etiqueta_roja", (0.03, 0.075), "tapa_dorada", (0.012, 0.007)),
    "caguama": ([(0, 0), (0.038, 0), (0.04, 0.008), (0.04, 0.13), (0.032, 0.165), (0.015, 0.21), (0.014, 0.245), (0, 0.245)],
                "vidrio_ambar", "etiqueta_amarilla", (0.04, 0.11), "tapa_dorada", (0.016, 0.009)),
}


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


def girar(nombre, perfil, mat, col, lados=10):
    """Una pieza de revolucion (torno): `perfil` es [(radio, alto)] de abajo arriba; un radio 0 es
    un polo (cierra la pieza)."""
    import bmesh
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    anillos = []
    for r, h in perfil:
        if r <= 0.0:
            anillos.append([bm.verts.new((0.0, 0.0, h))])
        else:
            anillos.append([bm.verts.new((r * math.cos(k * math.tau / lados), r * math.sin(k * math.tau / lados), h)) for k in range(lados)])
    for a, b in zip(anillos, anillos[1:]):
        for k in range(lados):
            j = (k + 1) % lados
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new((a[0], b[k], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[j], b[0]))
            else:
                bm.faces.new((a[k], a[j], b[j], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def juntar(nombre, piezas, col, matriz=None):
    """Junta varias piezas (con su posicion) en un solo objeto con varios materiales, movido por
    `matriz` (Blender); asi un banco o una botella es una sola malla, no cinco."""
    import bmesh
    bm = bmesh.new()
    mats = []
    for ob in piezas:
        tmp = bmesh.new()
        tmp.from_mesh(ob.data)
        bmesh.ops.transform(tmp, matrix=ob.matrix_basis, verts=tmp.verts)
        for f in tmp.faces:
            m = ob.data.materials[f.material_index] if ob.data.materials else None
            if m not in mats:
                mats.append(m)
            f.material_index = mats.index(m)
        me_tmp = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me_tmp)
        tmp.free()
        bm.from_mesh(me_tmp)
        bpy.data.meshes.remove(me_tmp)
    me = bpy.data.meshes.new(nombre)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    for ob in piezas:
        viejo = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if viejo.users == 0:
            bpy.data.meshes.remove(viejo)
    ob = bpy.data.objects.new(nombre, me)
    if matriz is not None:
        ob.matrix_basis = matriz
    col.objects.link(ob)
    return ob


def botella(nombre, tipo, x, y, z, col):
    """Una botella de BOTELLAS parada en (x, y, z): vidrio de revolucion, etiqueta y tapa; el
    mezcal trae su gusano (su vidrio se transparenta en el juego)."""
    perfil, vidrio, etiqueta, (e0, e1), tapa, (tr, ta) = BOTELLAS[tipo]
    r = max(p[0] for p in perfil if p[1] <= e1)
    alto = perfil[-1][1]
    piezas = [girar(nombre + "_v", perfil, material(vidrio, COLORES_BOTELLA[vidrio]), col),
              girar(nombre + "_e", [(0, e0), (r + 0.003, e0), (r + 0.003, e1), (0, e1)], material(etiqueta, COLORES_BOTELLA[etiqueta]), col),
              girar(nombre + "_t", [(0, alto - 0.004), (tr, alto - 0.004), (tr, alto + ta), (0, alto + ta)], material(tapa, COLORES_BOTELLA[tapa]), col, lados=8)]
    if tipo == "mezcal":
        piezas.append(girar(nombre + "_g", [(0, 0.012), (0.008, 0.016), (0.006, 0.05), (0, 0.055)], material("gusano", (0.85, 0.55, 0.25)), col, lados=5))
    return juntar(nombre, piezas, col, Matrix.Translation(_b(x, y, z)))


COLORES_BOTELLA = {
    "vidrio_claro": (0.8, 0.85, 0.82), "vidrio_mezcal": (0.75, 0.8, 0.6), "vidrio_ambar": (0.45, 0.22, 0.05),
    "vidrio_cafe": (0.25, 0.12, 0.05), "etiqueta_crema": (0.92, 0.86, 0.68), "etiqueta_roja": (0.8, 0.1, 0.1),
    "etiqueta_negra": (0.08, 0.07, 0.07), "etiqueta_amarilla": (0.95, 0.8, 0.15), "tapa_negra": (0.05, 0.05, 0.05),
    "tapa_corcho": (0.6, 0.45, 0.28), "tapa_dorada": (0.85, 0.7, 0.25),
}


def banco(nombre, x, y, z, alto, col):
    """Un banquito de cantina: base redonda, poste cromado, aro para los pies y cojin de vinil rojo."""
    cromo = material("cromo", (0.75, 0.77, 0.8))
    vinil = material("vinil_rojo", (0.65, 0.06, 0.06))
    piezas = [girar(nombre + "_base", [(0, 0), (0.17, 0), (0.17, 0.015), (0.06, 0.03), (0, 0.03)], cromo, col, lados=10),
              girar(nombre + "_poste", [(0, 0.03), (0.022, 0.03), (0.022, alto - 0.06), (0, alto - 0.06)], cromo, col, lados=6),
              girar(nombre + "_aro", [(0.13, alto * 0.42 - 0.012), (0.15, alto * 0.42 - 0.012), (0.15, alto * 0.42 + 0.012), (0.13, alto * 0.42 + 0.012)], cromo, col, lados=10),
              girar(nombre + "_cojin", [(0, alto - 0.07), (0.17, alto - 0.07), (0.19, alto - 0.05), (0.19, alto - 0.015), (0.17, alto), (0, alto)], vinil, col, lados=12)]
    for k in range(3):
        a = k * math.tau / 3
        piezas.append(cable_recto(nombre + "_rayo_%d" % k, Vector((0, alto * 0.42, 0)), Vector((math.cos(a) * 0.14, alto * 0.42, math.sin(a) * 0.14)), cromo, col, r=0.008))
    # girar() arma en Blender (z arriba); los cables en Godot: todo queda en el mismo origen
    return juntar(nombre, piezas, col, Matrix.Translation(_b(x, y, z)))


def silla_plegable(nombre, x, y, z, hacia, col):
    """Una silla plegable de lamina de las que regala la cerveceria, con el logo de la Coronela en
    el respaldo (del atlas de los carteles), con el frente hacia `hacia` (x, z: la mesa)."""
    lamina = material("lamina_silla", (0.7, 0.12, 0.1))
    tubo = material("tubo_silla", (0.3, 0.3, 0.32))
    logo = material("anuncios", (1, 1, 1))
    a = ASIENTO
    piezas = [caja(nombre + "_asiento", -0.2, 0.2, a - 0.035, a, -0.2, 0.2, lamina, col, choca=False),
              caja(nombre + "_respaldo", -0.25, -0.22, a + 0.15, a + 0.45, -0.2, 0.2, lamina, col, choca=False)]
    for lado in (-1, 1):
        piezas.append(cable_recto(nombre + "_pata_d%d" % lado, Vector((0.19, 0.0, lado * 0.19)), Vector((0.16, a - 0.03, lado * 0.19)), tubo, col, r=0.012))
        piezas.append(cable_recto(nombre + "_pata_t%d" % lado, Vector((-0.2, 0.0, lado * 0.19)), Vector((-0.26, a + 0.46, lado * 0.19)), tubo, col, r=0.012))
    piezas.append(cable_recto(nombre + "_travesano", Vector((0.17, 0.12, -0.19)), Vector((0.17, 0.12, 0.19)), tubo, col, r=0.01))
    piezas.append(plano(nombre + "_logo", (-0.255, a + 0.3, 0.0), 0.3, 0.26, (-1, 0, 0), logo, col, uv=(2 / 6 + 0.01, 0.42, 3 / 6 - 0.01, 0.82)))
    # Hecha con el frente a +x; girar en y de Godot es girar en z de Blender
    angulo = math.atan2(-(hacia[1] - z), hacia[0] - x)
    return juntar(nombre, piezas, col, Matrix.Translation(_b(x, y, z)) @ Matrix.Rotation(angulo, 4, "Z"))


def refri(x0, x1, y, z0, col):
    """El refri de la Tecatl en la barra: caja roja abierta al frente, marquesina luminosa con el
    logo (textures/sotano/refri.png, arriba), puerta de vidrio que se transparenta con su marco y
    jaladera, adentro luz blanca y tres parrillas llenas de cervezas y caguamas, patas, rejilla del
    motor y calcomanias. Frente en z0 + 0.7."""
    rojo = material("refri", (0.85, 0.1, 0.1))
    luz = material("refri_luz", (0.85, 0.95, 1.0), emision=1.5)
    cromo = material("cromo", (0.75, 0.77, 0.8))
    marca_m = material("refri_marca", (1, 1, 1))
    z1 = z0 + 0.7
    g = 0.05
    caja("Refri_choque", x0, x1, y, y + 2.05, z0, z1, rojo, col, choca=False).name = "Refri-colonly"
    for k, (xa, xb) in enumerate(((0.04, 0.1), (0.9, 0.96))):
        caja("Refri_pata_%d" % k, x0 + xa, x0 + xb, y, y + 0.05, z0 + 0.05, z0 + 0.11, cromo, col, choca=False)
        caja("Refri_pata_f%d" % k, x0 + xa, x0 + xb, y, y + 0.05, z1 - 0.11, z1 - 0.05, cromo, col, choca=False)
    # La caja: base con la rejilla, costados, fondo con luz, techo y la marquesina
    caja("Refri_base", x0, x1, y + 0.05, y + 0.22, z0, z1, rojo, col, choca=False)
    plano("Refri_rejilla", ((x0 + x1) / 2, y + 0.135, z1 + 0.003), x1 - x0 - 0.12, 0.12, (0, 0, 1), marca_m, col, uv=(0.5, 0.0, 1.0, 0.5))
    caja("Refri_lado_o", x0, x0 + g, y + 0.22, y + 1.8, z0, z1, rojo, col, choca=False)
    caja("Refri_lado_e", x1 - g, x1, y + 0.22, y + 1.8, z0, z1, rojo, col, choca=False)
    caja("Refri_fondo", x0 + g, x1 - g, y + 0.22, y + 1.8, z0, z0 + g, luz, col, choca=False)
    caja("Refri_techo", x0, x1, y + 1.8, y + 1.85, z0, z1, rojo, col, choca=False)
    caja("Refri_marquesina", x0, x1, y + 1.85, y + 2.05, z0 + 0.1, z1 + 0.02, rojo, col, choca=False)
    plano("Refri_marquesina_luz", ((x0 + x1) / 2, y + 1.95, z1 + 0.025), x1 - x0 - 0.04, 0.18, (0, 0, 1), material("refri_letrero", (1, 1, 1)), col, uv=(0.0, 0.5, 1.0, 1.0))
    # Tres parrillas de alambre con las botellas paradas en dos filas
    for n, py in enumerate((0.3, 0.82, 1.32)):
        caja("Refri_parrilla_%d" % n, x0 + g, x1 - g, y + py - 0.015, y + py, z0 + g, z1 - 0.08, cromo, col, choca=False)
        for fila, pz in enumerate((z0 + 0.22, z0 + 0.45)):
            bx = x0 + g + 0.05
            k = 0
            tipo = "caguama" if n == 0 else "cerveza"
            radio = BOTELLAS[tipo][0][1][0]
            while bx + radio * 2 < x1 - g - 0.02:
                botella("Refri_botella_%d_%d_%d" % (n, fila, k), tipo, bx + radio, y + py, pz, col)
                bx += radio * 2 + 0.015
                k += 1
    # La puerta: vidrio que se ve a traves, marco rojo y la jaladera cromada
    plano("Refri_vidrio", ((x0 + x1) / 2, y + 1.01, z1 + 0.01), x1 - x0 - 0.1, 1.5, (0, 0, 1), material("vidrio_refri", (0.75, 0.9, 1.0)), col)
    for nombre, a, b, c, d in (("o", x0, x0 + 0.06, y + 0.22, y + 1.8), ("e", x1 - 0.06, x1, y + 0.22, y + 1.8),
                               ("ab", x0, x1, y + 0.22, y + 0.27), ("ar", x0, x1, y + 1.75, y + 1.8)):
        caja("Refri_marco_" + nombre, a, b, c, d, z1, z1 + 0.03, rojo, col, choca=False)
    caja("Refri_jaladera", x1 - 0.1, x1 - 0.08, y + 0.75, y + 1.3, z1 + 0.03, z1 + 0.06, cromo, col, choca=False)
    # Calcomanias en el costado que se ve
    plano("Refri_calco_0", (x0 - 0.003, y + 1.3, z0 + 0.35), 0.3, 0.3, (-1, 0, 0), marca_m, col, uv=(0.0, 0.0, 0.25, 0.5))
    plano("Refri_calco_1", (x0 - 0.003, y + 0.85, z0 + 0.4), 0.25, 0.25, (-1, 0, 0), marca_m, col, uv=(0.25, 0.0, 0.5, 0.5))
    marca("Luz_refri", (x0 + x1) / 2, y + 1.0, z1 + 0.3, col, 0)


def esfera(nombre, radio, mat, col):
    """Una bola (sin operadores)."""
    import bmesh
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=radio)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def banho(col):
    """El bano, detras del muro este del salon 2: azulejo sucio, piso de cuadros, dos casetas (una
    cerrada, una con la puerta colgando), excusados, un mingitorio, dos lavabos con el espejo
    estrellado y un hueco donde estuvo el otro, tubos oxidados, la coladera con su mancha, el grafiti
    y un foco pelon que parpadea (Sotano.gd). Como en Silent Hill: sucio, chico y con algo raro."""
    x0, x1, z0, z1 = BANO
    y = PISO
    alto = y + BANO_ALTO
    g = 0.2
    azulejo = material("azulejo", (0.7, 0.7, 0.65))
    piso = material("azulejo_piso", (0.15, 0.2, 0.15))
    sucio = material("pintura_sucia", (0.35, 0.36, 0.3))
    lamina = material("lamina_bano", (0.25, 0.35, 0.28))
    porcelana = material("porcelana", (0.85, 0.85, 0.8))
    oxido = material("tubo_oxidado", (0.4, 0.22, 0.12))
    atlas = material("banho", (1, 1, 1))
    caja("Bano_piso", x0 - g, x1 + g, y - g, y, z0 - g, z1 + g, piso, col)
    caja("Bano_techo", x0 - g, x1 + g, alto, alto + g, z0 - g, z1 + g, sucio, col)
    caja("Bano_muro_n", x0, x1 + g, y, alto, z0 - g, z0, sucio, col)
    caja("Bano_muro_s", x0, x1 + g, y, alto, z1, z1 + g, sucio, col)
    caja("Bano_muro_e", x1, x1 + g, y, alto, z0, z1, sucio, col)
    # Azulejo hasta 1.4 en los tres muros de adentro (y el del lado de la puerta)
    for nombre, a, b, c, d in (("n", x0, x1, z0, z0 + 0.02), ("s", x0, x1, z1 - 0.02, z1), ("e", x1 - 0.02, x1, z0, z1),
                               ("o_n", x0, x0 + 0.02, z0, BANO_PUERTA[0]), ("o_s", x0, x0 + 0.02, BANO_PUERTA[1], z1)):
        caja("Bano_azulejo_" + nombre, a, b, y, y + 1.4, c, d, azulejo, col, choca=False)
    # Dos casetas contra el muro este: mamparas, frentes y puertas (la segunda cuelga de una bisagra)
    cx0 = x1 - 1.3
    for k, zc in enumerate((z0 + 0.1, z0 + 1.1, z0 + 2.1)):
        caja("Bano_mampara_%d" % k, cx0, x1, y + 0.15, y + 1.85, zc - 0.015, zc + 0.015, lamina, col)
    for k in range(2):
        za = z0 + 0.1 + k
        caja("Bano_frente_%d" % k, cx0 - 0.015, cx0 + 0.015, y + 1.6, y + 1.85, za, za + 1.0, lamina, col, choca=False)
        # El excusado: base, taza de torno y tanque
        tx, tz = x1 - 0.35, za + 0.5
        caja("Bano_excusado_base_%d" % k, tx - 0.12, tx + 0.12, y, y + 0.3, tz - 0.14, tz + 0.14, porcelana, col)
        girar("Bano_taza_%d" % k, [(0, 0.28), (0.17, 0.3), (0.2, 0.4), (0.16, 0.42), (0, 0.36)], porcelana, col, lados=10).location = _b(tx - 0.08, y, tz)
        caja("Bano_tanque_%d" % k, x1 - 0.18, x1 - 0.02, y + 0.42, y + 0.8, tz - 0.2, tz + 0.2, porcelana, col, choca=False)
    caja("Bano_caseta_puerta_0", cx0 - 0.02, cx0 + 0.01, y + 0.2, y + 1.6, z0 + 0.12, z0 + 1.08, lamina, col)
    colgada = caja("Bano_caseta_puerta_1", -0.015, 0.015, 0.0, 1.4, 0.0, 0.96, lamina, col, choca=False)
    colgada.location = _b(cx0 - 0.45, y + 0.9, z0 + 1.55)
    colgada.rotation_euler = (math.radians(9), 0, math.radians(-62))     # abierta y caida de una bisagra
    # Mingitorio en el muro norte y los dos lavabos en el sur, con el espejo estrellado y el hueco
    caja("Bano_mingitorio", x0 + 0.9, x0 + 1.3, y + 0.5, y + 1.2, z0 + 0.02, z0 + 0.3, porcelana, col)
    for k, lx in enumerate((x0 + 0.8, x0 + 1.9)):
        caja("Bano_lavabo_pie_%d" % k, lx - 0.06, lx + 0.06, y, y + 0.75, z1 - 0.25, z1 - 0.13, porcelana, col)
        girar("Bano_lavabo_%d" % k, [(0, 0.72), (0.2, 0.74), (0.24, 0.86), (0.2, 0.86), (0, 0.78)], porcelana, col, lados=10).location = _b(lx, y, z1 - 0.22)
        cable_recto("Bano_llave_%d" % k, Vector((lx, y + 0.86, z1 - 0.05)), Vector((lx, y + 1.0, z1 - 0.12)), oxido, col, r=0.012)
    plano("Bano_espejo", (x0 + 0.8, y + 1.45, z1 - 0.025), 0.5, 0.6, (0, 0, -1), atlas, col, uv=(0.0, 0.0, 0.5, 1.0))
    caja("Bano_espejo_hueco", x0 + 1.65, x0 + 2.15, y + 1.15, y + 1.75, z1 - 0.025, z1 - 0.02, material("concreto_techo", (0.35, 0.34, 0.33)), col, choca=False)
    plano("Bano_grafiti", (x0 + 1.25, y + 1.75, z0 + 0.025), 1.1, 0.55, (0, 0, 1), atlas, col, uv=(0.5, 0.5, 1.0, 1.0))
    # La coladera y la mancha que sale de ella; una mancha mas bajo el lavabo
    plano("Bano_coladera", ((x0 + cx0) / 2, y + 0.004, (z0 + z1) / 2), 0.3, 0.3, (0, 1, 0), atlas, col, uv=(0.75, 0.0, 1.0, 0.5))
    plano("Bano_mancha_0", ((x0 + cx0) / 2 + 0.2, y + 0.003, (z0 + z1) / 2 + 0.25), 1.1, 1.0, (0, 1, 0), material("banho_mancha", (1, 1, 1)), col, uv=(0.5, 0.0, 0.75, 0.5))
    plano("Bano_mancha_1", (x0 + 1.9, y + 0.003, z1 - 0.6), 0.7, 0.6, (0, 1, 0), material("banho_mancha"), col, uv=(0.5, 0.0, 0.75, 0.5))
    # Tubos oxidados por el techo y uno que baja al lavabo
    for k, (pa, pb) in enumerate((((x0 + 0.1, z0 + 0.2), (x1 - 0.1, z0 + 0.2)), ((x0 + 0.3, z0 + 0.2), (x0 + 0.3, z1 - 0.1)))):
        cable_recto("Bano_tubo_%d" % k, Vector((pa[0], alto - 0.12, pa[1])), Vector((pb[0], alto - 0.12, pb[1])), oxido, col, r=0.03)
    cable_recto("Bano_tubo_baja", Vector((x0 + 0.3, alto - 0.12, z1 - 0.1)), Vector((x0 + 0.3, y + 0.6, z1 - 0.1)), oxido, col, r=0.025)
    # El foco pelon colgando de su cable
    cable_recto("Bano_foco_cable", Vector((x0 + 1.6, alto, (z0 + z1) / 2)), Vector((x0 + 1.6, alto - 0.45, (z0 + z1) / 2)), material("cable", (0.05, 0.05, 0.05)), col, r=0.006)
    esfera("Bano_foco", 0.045, material("foco_bano", (1.0, 0.85, 0.5), emision=2.0), col).location = _b(x0 + 1.6, alto - 0.5, (z0 + z1) / 2)
    marca("Luz_bano", x0 + 1.6, alto - 0.55, (z0 + z1) / 2, col, 0)
    marca("Bano_espejo", x0 + 0.8, y, z1 - 0.7, col, 180)
    marca("Bano_caseta", cx0 - 0.5, y, z0 + 0.6, col, 90)
    marca("Bano_centro", (x0 + cx0) / 2, y, (z0 + z1) / 2, col, 0)


def media_luna(nombre, cx, y0, y1, cz, r, arriba, lados, col, pasos=16):
    """La mesa de media luna: la orilla recta en z = cz (al norte) y el arco hacia +z. La cara de
    arriba lleva el material `arriba` con UV en planta (la orilla recta arriba de la textura); los
    lados, `lados`."""
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UV")
    pts = [(cx + math.cos(math.radians(180 - 180 * k / pasos)) * r, cz + math.sin(math.radians(180 - 180 * k / pasos)) * r) for k in range(pasos + 1)]
    abajo = [bm.verts.new(_b(x, y0, z)) for x, z in pts]
    alto = [bm.verts.new(_b(x, y1, z)) for x, z in pts]
    tapa = bm.faces.new(alto)
    tapa.material_index = 0
    for loop, (x, z) in zip(tapa.loops, pts):
        loop[uv].uv = ((x - (cx - r)) / (2 * r), 1.0 - (z - cz) / r)
    bm.faces.new(list(reversed(abajo))).material_index = 1
    n = len(pts)
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((abajo[k], abajo[j], alto[j], alto[k])).material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(arriba)
    me.materials.append(lados)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def mesa_blackjack(col):
    """La mesa de blackjack: media luna con su pano impreso (textures/sotano/blackjack.png: "PAGA 3 A
    2", "EL CRUPIER SE PLANTA EN 17", los circulos de apuesta), el borde acolchado por el arco, la
    charola de fichas y el zapato de cartas del lado del crupier, dos bancos con jugadores y el tuyo
    al centro, y su lampara."""
    import bmesh as _bm
    cx, cz, r = BLACKJACK
    y = PISO
    pano = material("blackjack", (1, 1, 1))
    cuero = material("cuero_negro", (0.08, 0.06, 0.06))
    madera = material("madera", (0.45, 0.32, 0.2))
    caja("Blackjack_pata", cx - 0.2, cx + 0.2, y, y + 0.74, cz + 0.2, cz + 0.6, madera, col, choca=False)
    media_luna("Blackjack_mesa", cx, y + 0.74, y + 0.8, cz, r, pano, madera, col)
    for k in range(12):
        a0, a1 = math.radians(180 - 15 * k), math.radians(180 - 15 * (k + 1))
        cable_recto("Blackjack_borde_%d" % k, Vector((cx + math.cos(a0) * (r + 0.03), y + 0.82, cz + math.sin(a0) * (r + 0.03))),
                    Vector((cx + math.cos(a1) * (r + 0.03), y + 0.82, cz + math.sin(a1) * (r + 0.03))), cuero, col, r=0.045)
    choque = caja("Blackjack_choque", cx - r - 0.05, cx + r + 0.05, y, y + 0.85, cz - 0.05, cz + r + 0.05, madera, col, choca=False)
    choque.name = "Blackjack_choque-colonly"
    # La charola de fichas y el zapato, del lado del crupier
    caja("Blackjack_charola", cx - 0.32, cx + 0.32, y + 0.8, y + 0.83, cz + 0.04, cz + 0.16, cuero, col, choca=False)
    for k in range(8):
        for n in range(6):
            cilindro("Blackjack_ficha_%d_%d" % (k, n), cx - 0.28 + k * 0.08, y + 0.8 + 0.012 * n, y + 0.812 + 0.012 * n, cz + 0.1, 0.028,
                     material("ficha_%d" % (k % 3), ((0.85, 0.1, 0.1), (0.1, 0.3, 0.85), (0.95, 0.95, 0.9))[k % 3]), col, lados=8)
    caja("Blackjack_zapato", cx + 0.45, cx + 0.62, y + 0.8, y + 0.9, cz + 0.05, cz + 0.28, material("mazo", (0.45, 0.08, 0.1)), col, choca=False)
    marca("Crupier_bj", cx, y, cz - 0.45, col, 0)
    marca("Blackjack", cx, y, cz + r + 0.55, col, 180)
    marca("Blackjack_tu", cx, y, cz + r + 0.35, col, 180)
    for k, a in enumerate((140, 40)):
        bx, bz = cx + math.cos(math.radians(a)) * (r + 0.45), cz + math.sin(math.radians(a)) * (r + 0.45)
        banco("Banco_bj_%d" % k, bx, y, bz, ASIENTO, col)
        marca("Blackjack_%d" % k, bx, y, bz, col, 0)
    cilindro("Blackjack_lampara_cable", cx, TECHO - 0.45, TECHO, cz + 0.4, 0.01, material("cable", (0.05, 0.05, 0.05)), col, lados=4)
    cilindro("Blackjack_lampara", cx, TECHO - 0.6, TECHO - 0.45, cz + 0.4, 0.32, material("lampara_verde", (0.15, 0.45, 0.25)), col, lados=12)
    marca("Luz_blackjack", cx, TECHO - 0.7, cz + 0.4, col, 0)


def mesa_ruleta(col):
    """La ruleta: mesa con su pano (textures/sotano/ruleta.png: ROJO, NEGRO y VERDE, nada mas), el
    plato de madera y la rueda (Ruleta_rueda, 37 casillas de colores en el orden de la ruleta, la gira
    Sotano.gd) con la bola (Ruleta_bola). El crupier al norte; tu al sur."""
    x0, x1, z0, z1 = RULETA
    rx, rz, rr = RUEDA
    y = PISO
    madera = material("madera", (0.45, 0.32, 0.2))
    caja("Ruleta_mesa", x0, x1, y, y + 0.85, z0, z1, madera, col)
    plano("Ruleta_pano", ((x0 + x1) / 2, y + 0.852, (z0 + z1) / 2), x1 - x0 - 0.04, z1 - z0 - 0.04, (0, 1, 0), material("ruleta", (1, 1, 1)), col)
    # El plato de madera: un aro que levanta la rueda
    girar("Ruleta_plato", [(0, 0), (rr + 0.08, 0), (rr + 0.08, 0.06), (rr + 0.02, 0.06), (rr + 0.02, 0.03), (0, 0.03)],
          material("madera_oscura", (0.3, 0.2, 0.12)), col, lados=24).location = _b(rx, y + 0.852, rz)
    # La rueda: casillas en el orden europeo, rojo, negro y la verde (el cero)
    rojos = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}
    orden = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
    me = bpy.data.meshes.new("Ruleta_rueda")
    bm = bmesh.new()
    centro = bm.verts.new((0, 0, 0.035))
    n = len(orden)
    borde = [bm.verts.new((math.cos(k * math.tau / n) * rr, math.sin(k * math.tau / n) * rr, 0.035)) for k in range(n)]
    for k, numero in enumerate(orden):
        f = bm.faces.new((centro, borde[k], borde[(k + 1) % n]))
        f.material_index = 2 if numero == 0 else (0 if numero in rojos else 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for nombre, c in (("ruleta_rojo", (0.75, 0.06, 0.05)), ("ruleta_negro", (0.05, 0.05, 0.05)), ("ruleta_verde", (0.05, 0.5, 0.15))):
        me.materials.append(material(nombre, c))
    rueda = bpy.data.objects.new("Ruleta_rueda", me)
    rueda.location = _b(rx, y + 0.852, rz)
    col.objects.link(rueda)
    torre = girar("Ruleta_torre", [(0, 0.035), (0.06, 0.035), (0.03, 0.08), (0.012, 0.13), (0.03, 0.15), (0, 0.16)], material("tapa_dorada", (0.85, 0.7, 0.25)), col, lados=8)
    torre.parent = rueda
    bola = esfera("Ruleta_bola", 0.018, material("plastico_blanco", (0.9, 0.9, 0.86)), col)
    bola.location = _b(rx + rr - 0.03, y + 0.852 + 0.05, rz)
    marca("Crupier_ruleta", (x0 + x1) / 2, y, z0 - 0.45, col, 0)
    marca("Ruleta", (x0 + x1) / 2, y, z1 + 0.6, col, 180)


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
    # El muro este, con el hueco de la puerta del bano (BANO_PUERTA: z de las jambas)
    p0, p1 = BANO_PUERTA
    caja("Muro2_este_n", a1, a1 + g, PISO, TECHO, b0, p0, muro, col)
    caja("Muro2_este_s", a1, a1 + g, PISO, TECHO, p1, b1, muro, col)
    caja("Muro2_este_dintel", a1, a1 + g, PISO + 2.0, TECHO, p0, p1, muro, col)
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
    # Las EL GORDO (OlPley en el codigo): ocho en el muro norte y dos en el sur, viendo al salon,
    # cada una con su banquito
    for k in range(8):
        marca("OlPley_%d" % k, 11.0 + k * 1.2, y, z0 + 0.45, col, 0)
        banco("Silla_%d" % k, 11.0 + k * 1.2, y, z0 + 1.25, ASIENTO, col)
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
    # La pista de los caballitos: una isla en la mitad sur del salon 1 (entre las columnas y el
    # altar), se mira desde el norte; los caballitos corren a lo largo de x
    px0, px1, pz0, pz1 = PISTA
    caja("Pista_mesa", px0, px1, y + 0.85, y + 0.92, pz0, pz1, material("fieltro_verde", (0.1, 0.35, 0.15)), col)
    caja("Pista_choque", px0, px1, y, y + 0.92, pz0, pz1, madera, col, choca=False).name = "Pista_choque-colonly"
    caja("Pista_faldon", px0 + 0.05, px1 - 0.05, y, y + 0.85, pz0 + 0.05, pz1 - 0.05, madera, col, choca=False)
    caja("Pista_meta", PISTA_META, PISTA_META + 0.05, y + 0.92, y + 0.93, pz0, pz1, material("pintura_blanca", (0.95, 0.95, 0.9)), col, choca=False)
    caja("Pista_salida", px0 + 0.2, px0 + 0.25, y + 0.92, y + 0.93, pz0, pz1, material("pintura_blanca"), col, choca=False)
    colores = ((0.85, 0.15, 0.1), (0.1, 0.35, 0.85), (0.95, 0.8, 0.1), (0.1, 0.7, 0.25), (0.8, 0.4, 0.9))
    for k in range(5):
        zr = pz0 + 0.2 + k * 0.2
        caja("Riel_%d" % k, px0 + 0.2, px1 - 0.2, y + 0.92, y + 0.95, zr - 0.01, zr + 0.01, metal, col, choca=False)
        caballo(k, px0 + 0.5, y + 0.95, zr, material("caballo_%d" % (k + 1), colores[k]), col)
    marca("Pista", (px0 + px1) / 2, y, pz0 - 0.8, col, 0)
    # Salon 2: la barra en el muro norte (contrabarra con botellas, refri con luz, barra, bancos)
    caja("Contrabarra", 23.0, 30.0, y, y + 0.9, b0, b0 + 0.45, madera, col)
    caja("Contrabarra_tapa", 22.95, 30.05, y + 0.9, y + 0.94, b0, b0 + 0.5, material("madera_oscura", (0.3, 0.2, 0.12)), col, choca=False)
    rnd = random.Random(11)
    tipos = list(BOTELLAS)
    # Tres repisas; la de arriba en y + 1.83: la botella mas alta (ron, 0.28) llega a y + 2.11, abajo
    # de las vigas (TECHO - 0.25 = y + 2.15). Las botellas no pasan de la orilla de la repisa
    for nivel in range(3):
        ry = y + REPISA_Y + nivel * REPISA_SEPARA
        caja("Repisa_%d" % nivel, 23.0, 29.0, ry - 0.03, ry, b0, b0 + 0.3, madera, col, choca=False)
        bx = 23.08
        k = 0
        while True:
            tipo = rnd.choice(tipos)
            radio = BOTELLAS[tipo][0][1][0]
            if bx + radio * 2 > 28.94:
                break
            botella("Botella_%d_%02d" % (nivel, k), tipo, bx + radio, ry, b0 + 0.15 + rnd.uniform(-0.04, 0.04), col)
            bx += radio * 2 + rnd.choice((0.02, 0.04, 0.04, 0.1))
            k += 1
    for k, (tipo, bx) in enumerate((("tequila", 23.4), ("cerveza", 23.6), ("ron", 29.5), ("whisky", 29.7))):
        botella("Botella_contra_%d" % k, tipo, bx, y + 0.94, b0 + 0.25, col)
    refri(30.2, 31.2, y, b0, col)
    caja("Barra", 23.0, 29.0, y, y + 1.05, b0 + 1.2, b0 + 1.65, madera, col)
    caja("Barra_tapa", 22.95, 29.05, y + 1.05, y + 1.1, b0 + 1.15, b0 + 1.75, material("madera_oscura"), col, choca=False)
    for k in range(3):
        cilindro("Grifo_%d" % k, 25.2 + k * 0.3, y + 1.1, y + 1.4, b0 + 1.35, 0.025, metal, col, lados=6)
    for k, (tipo, bx) in enumerate((("cerveza", 23.8), ("cerveza", 23.95), ("tequila", 27.4), ("caguama", 28.3))):
        botella("Botella_barra_%d" % k, tipo, bx, y + 1.1, b0 + 1.45, col)
    for k in range(5):
        banco("Banco_barra_%d" % k, 23.6 + k * 1.2, y, b0 + 2.25, BANCO_BARRA, col)
        marca("Banco_barra_%d" % k, 23.6 + k * 1.2, y, b0 + 2.25, col, 0)
    # Tiras de neon de colores en la barra: debajo de la orilla de la barra (rosa), debajo de cada
    # repisa (cian y morado), al pie de la contrabarra (azul) y por la orilla del refri. Brillan solas
    # (SotanoPostImport: neon_*) y Sotano.gd pone luces de color en Luz_barra_*
    caja("Led_barra", 22.95, 29.05, y + 1.03, y + 1.05, b0 + 1.76, b0 + 1.78, material("neon_rosa", (1.0, 0.25, 0.75)), col, choca=False)
    caja("Led_barra_pie", 23.0, 29.0, y + 0.08, y + 0.1, b0 + 1.66, b0 + 1.68, material("neon_morado", (0.6, 0.3, 1.0)), col, choca=False)
    for nivel in range(3):
        ry = y + REPISA_Y + nivel * REPISA_SEPARA
        caja("Led_repisa_%d" % nivel, 23.0, 29.0, ry - 0.045, ry - 0.03, b0 + 0.29, b0 + 0.3,
             material("neon_cian" if nivel % 2 == 0 else "neon_morado", (0.3, 0.9, 1.0) if nivel % 2 == 0 else (0.6, 0.3, 1.0)), col, choca=False)
    caja("Led_contrabarra", 23.0, 30.0, y + 0.92, y + 0.935, b0 + 0.49, b0 + 0.5, material("neon_azul", (0.3, 0.4, 1.0)), col, choca=False)
    for k, (lx, lz) in enumerate(((24.0, b0 + 0.6), (26.5, b0 + 0.6), (28.8, b0 + 0.6), (26.0, b0 + 2.0))):
        marca("Luz_barra_%d" % k, lx, y + 1.0 + (k == 3) * -0.7, lz, col, 0)
    marca("Neon_dados", 32.6, y + 1.55, b0 + 0.05, col, 0)
    marca("Cantinero", 26.2, y, b0 + 0.85, col, 0)
    marca("Barra", 26.2, y, b0 + 2.6, col, 0)
    marca("Neon_barra", 26.0, y + 0.55, b0 + 1.68, col, 0)     # en el frente de la barra
    # La mesa del poker, al centro con espacio alrededor: pano verde, borde acolchado, fichas
    mx, mz = MESA
    caja("Poker_pata", mx - 0.25, mx + 0.25, y, y + 0.72, mz - 0.25, mz + 0.25, madera, col, choca=False)
    caja("Poker_pano", mx - 1.3, mx + 1.3, y + 0.72, y + 0.78, mz - 0.75, mz + 0.75, material("fieltro_verde"), col, choca=False)
    for nombre, xa, xb, za_, zb_ in (("n", mx - 1.4, mx + 1.4, mz - 0.85, mz - 0.75), ("s", mx - 1.4, mx + 1.4, mz + 0.75, mz + 0.85),
                                     ("o", mx - 1.4, mx - 1.3, mz - 0.75, mz + 0.75), ("e", mx + 1.3, mx + 1.4, mz - 0.75, mz + 0.75)):
        caja("Poker_borde_%s" % nombre, xa, xb, y + 0.72, y + 0.84, za_, zb_, material("cuero_negro", (0.08, 0.06, 0.06)), col, choca=False)
    caja("Poker_choque", mx - 1.4, mx + 1.4, y, y + 0.84, mz - 0.85, mz + 0.85, madera, col, choca=False).name = "Poker_choque-colonly"
    for k, (fx, fz) in enumerate(((mx - 0.9, mz - 0.3), (mx + 0.9, mz - 0.3), (mx - 0.6, mz + 0.4), (mx + 0.6, mz + 0.4))):
        for n in range(4):
            cilindro("Ficha_%d_%d" % (k, n), fx, y + 0.78 + n * 0.012, y + 0.79 + n * 0.012, fz, 0.03, material("ficha_%d" % (n % 3), ((0.85, 0.1, 0.1), (0.1, 0.3, 0.85), (0.95, 0.95, 0.9))[n % 3]), col, lados=8)
    botella("Botella_poker", "tequila", mx + 1.0, y + 0.78, mz + 0.5, col)
    # Mas cosas en la mesa: torres de fichas frente a cada lugar, cervezas, una caguama, el
    # cenicero con colillas y el mazo del crupier
    torres = ((mx - 1.0, mz + 0.15, 9), (mx - 1.05, mz - 0.1, 6), (mx - 0.7, mz - 0.55, 8), (mx - 0.45, mz - 0.6, 5),
              (mx + 1.0, mz + 0.15, 10), (mx + 1.05, mz - 0.12, 7), (mx + 0.15, mz + 0.6, 6), (mx - 0.1, mz + 0.62, 4),
              (mx - 0.05, mz - 0.33, 12), (mx + 0.05, mz - 0.27, 8))   # las dos ultimas: el bote, arriba de las de en medio
    for k, (fx, fz, alto) in enumerate(torres):
        for n in range(alto):
            cilindro("Torre_%d_%02d" % (k, n), fx, y + 0.78 + n * 0.012, y + 0.79 + n * 0.012, fz, 0.03,
                     material("ficha_%d" % ((n + k) % 3), ((0.85, 0.1, 0.1), (0.1, 0.3, 0.85), (0.95, 0.95, 0.9))[(n + k) % 3]), col, lados=8)
    for k, (tipo, bx, bz) in enumerate((("cerveza", mx - 1.15, mz + 0.45), ("cerveza", mx + 1.18, mz - 0.45),
                                         ("caguama", mx - 1.0, mz - 0.62), ("cerveza", mx + 0.6, mz - 0.66))):
        botella("Botella_mesa_poker_%d" % k, tipo, bx, y + 0.78, bz, col)
    girar("Cenicero", [(0, 0), (0.07, 0), (0.075, 0.025), (0.06, 0.025), (0.06, 0.01), (0, 0.01)],
          material("vidrio_ambar", (0.45, 0.22, 0.05)), col, lados=10).location = _b(mx + 0.55, y + 0.78, mz - 0.4)
    for k in range(3):
        a_ = k * 2.1
        cable_recto("Colilla_%d" % k, Vector((mx + 0.55 + math.cos(a_) * 0.02, y + 0.8, mz - 0.4 + math.sin(a_) * 0.02)),
                    Vector((mx + 0.55 + math.cos(a_) * 0.06, y + 0.81, mz - 0.4 + math.sin(a_) * 0.06)), material("colilla", (0.9, 0.85, 0.75)), col, r=0.005)
    caja("Mazo", mx + 0.62, mx + 0.7, y + 0.78, y + 0.81, mz - 0.75 + 0.2, mz - 0.75 + 0.32, material("mazo", (0.45, 0.08, 0.1)), col, choca=False)
    lugares = {"Poker_tu": (mx, mz + 1.35, 180), "Poker_0": (mx - 1.9, mz, 90), "Poker_1": (mx - 0.9, mz - 1.35, 0), "Poker_2": (mx + 1.9, mz, -90)}
    for nombre, (px, pz, giro) in lugares.items():
        marca(nombre, px, y, pz, col, giro)
        if nombre != "Poker_tu":
            silla_plegable("Silla_" + nombre, px, y, pz, MESA, col)
    marca("Crupier", mx + 0.9, y, mz - 1.3, col, 0)
    marca("Poker", mx, y, mz + 1.8, col, 180)
    # La lampara alta: la camara del poker (PokerUI) ve la mesa por debajo de ella
    cilindro("Poker_lampara_cable", mx, TECHO - 0.45, TECHO, mz, 0.01, cable, col, lados=4)
    cilindro("Poker_lampara", mx, TECHO - 0.6, TECHO - 0.45, mz, 0.4, material("lampara_verde", (0.15, 0.45, 0.25)), col, lados=12)
    marca("Luz_poker", mx, TECHO - 0.7, mz, col, 0)
    mesa_blackjack(col)
    mesa_ruleta(col)
    # El congelador de las caguamas (esquina suroeste del salon 2) y la puerta del bano (este)
    caja("Congelador", a0 + 0.3, a0 + 1.7, y, y + 0.9, b1 - 1.1, b1 - 0.4, material("congelador", (0.85, 0.85, 0.88)), col)
    caja("Congelador_tapa", a0 + 0.35, a0 + 1.65, y + 0.9, y + 0.93, b1 - 1.07, b1 - 0.43, material("vidrio", (0.4, 0.55, 0.6)), col, choca=False)
    plano("Congelador_calco", (a0 + 0.75, y + 0.5, b1 - 1.115), 0.36, 0.36, (0, 0, -1), material("refri_marca", (1, 1, 1)), col, uv=(0.0, 0.0, 0.25, 0.5))
    plano("Congelador_calco_2", (a0 + 1.3, y + 0.55, b1 - 1.115), 0.3, 0.3, (0, 0, -1), material("refri_marca"), col, uv=(0.25, 0.0, 0.5, 0.5))
    caja("Congelador_jaladera", a0 + 0.8, a0 + 1.2, y + 0.86, y + 0.9, b1 - 1.14, b1 - 1.1, material("cromo", (0.75, 0.77, 0.8)), col, choca=False)
    marca("Congelador", a0 + 1.0, y, b1 - 1.7, col, 180)
    # La puerta del bano en su bisagra (orilla norte): Sotano.gd la gira para abrirla hacia el salon
    p0, p1 = BANO_PUERTA
    bisagra = bpy.data.objects.new("Bano_bisagra", None)
    bisagra.empty_display_size = 0.1
    bisagra.location = _b(a1 - 0.03, y, p0)
    col.objects.link(bisagra)
    puerta = caja("Bano_puerta", -0.03, 0.03, 0.0, 2.0, 0.0, p1 - p0, material("lamina_puerta", (0.25, 0.3, 0.28)), col, choca=False)
    puerta.parent = bisagra
    puerta.location = _b(0.0, 1.0, (p1 - p0) / 2)
    jaladera = caja("Bano_puerta_jaladera", -0.07, -0.03, 0.95, 1.05, 0.0, 0.03, material("cromo", (0.75, 0.77, 0.8)), col, choca=False)
    jaladera.parent = bisagra
    jaladera.location = _b(-0.05, 1.0, p1 - p0 - 0.1)
    marca("Bano", a1 - 0.6, y, b1 - 2.95, col, -90)
    banho(col)
    marca("Neon_bano", a1 - 0.02, y + 2.15, b1 - 2.95, col, -90)
    # Una mesa alta para los que esperan, junto al muro sur
    cilindro("Mesa_alta_pata", 29.0, y, y + 1.0, b1 - 0.9, 0.04, metal, col, lados=6)
    cilindro("Mesa_alta_base", 29.0, y, y + 0.03, b1 - 0.9, 0.22, metal, col, lados=8)
    cilindro("Mesa_alta", 29.0, y + 1.0, y + 1.04, b1 - 0.9, 0.35, material("madera_oscura"), col, lados=10)
    for k, tipo in enumerate(("cerveza", "cerveza", "caguama")):
        botella("Botella_mesa_%d" % k, tipo, 28.85 + k * 0.14, y + 1.04, b1 - 0.95 + (k % 2) * 0.1, col)
    # Tubos de luz en los dos salones
    tubos = [(9.0, 3.0), (12.6, 0.6), (16.6, 0.6), (12.6, 5.4), (16.6, 5.4), (19.6, 3.0),
             (24.4, b0 + 1.0), (30.4, b0 + 1.0), (24.4, b1 - 2.0), (32.4, b1 - 2.0)]
    for k, (tx, tz) in enumerate(tubos):
        caja("Tubo_%d" % k, tx - 0.6, tx + 0.6, TECHO - 0.33, TECHO - 0.29, tz - 0.03, tz + 0.03, tubo, col, choca=False)
        marca("Luz_%d" % k, tx, TECHO - 0.4, tz, col, 0)
    # Neones (los arma Sotano.gd con models/sotano/neones.glb en los vacios)
    # EL GORDO cuelga de la viga de en medio, viendo a la entrada (en el muro lo tapaban los gabinetes)
    # (junto a la viga, no en ella: el letrero llega casi al techo y la pasaba)
    marca("Neon", 12.92, TECHO - 0.5, 3.0, col, -90)
    marca("Neon_atras", 13.08, TECHO - 0.5, 3.0, col, 90)      # el mismo, espalda con espalda
    for k, zc in enumerate((2.3, 3.7)):
        cable_recto("Cadena_neon_%d" % k, Vector((13.0, TECHO, zc)), Vector((13.0, TECHO - 0.07, zc)), metal, col, r=0.01)
    marca("Neon_premio", 17.8, TECHO - 0.5, z1 - 0.05, col, 180)
    marca("Neon_abierto", 8.6, TECHO - 0.75, z1 - 0.05, col, 180)
    marca("Neon_poker", a1 - 0.05, TECHO - 0.8, MESA[1], col, -90)
    # Anuncios de cerveza (Sotano.gd pone el cartel en cada vacio)
    for k, (ax, ay, az, giro) in enumerate(((x0 + 0.03, y + 1.5, 0.9, 90), (11.6, y + 1.6, z1 - 0.03, 180), (15.4, y + 1.6, z1 - 0.03, 180),
                                             (a0 + 0.03, y + 1.6, b0 + 1.0, 90), (a1 - 0.03, y + 1.6, b0 + 1.6, -90), (25.2, y + 1.7, b1 - 0.03, 180),
                                             (28.6, y + 1.7, b1 - 0.03, 180))):
        marca("Anuncio_%d" % k, ax, ay, az, col, giro)
    # Cables por el techo y extensiones
    for k, (pa, pb) in enumerate((((9.0, 3.0), (12.6, 0.6)), ((12.6, 0.6), (16.6, 0.6)), ((12.6, 0.6), (12.6, 5.4)), ((16.6, 0.6), (19.6, 3.0)),
                                  ((24.4, b0 + 1.0), (30.4, b0 + 1.0)), ((24.4, b0 + 1.0), (24.4, b1 - 2.0)))):
        cable_recto("Cable_techo_%d" % k, Vector((pa[0], TECHO - 0.27, pa[1])), Vector((pb[0], TECHO - 0.27, pb[1])), cable, col)
    for k, (pa, pb) in enumerate((((10.6, z0 + 0.3), (20.2, z0 + 0.3)), ((x0 + 0.3, 5.3), (x0 + 0.3, 6.9)), ((PISTA[0], PISTA[2] + 0.6), (12.0, z1 - 0.3)))):
        cable_recto("Extension_%d" % k, Vector((pa[0], y + 0.01, pa[1])), Vector((pb[0], y + 0.01, pb[1])), cable, col)
    # Ventiladores de techo (uno por salon)
    for v, (vx, vz) in enumerate(((14.6, 3.0), (24.4, MESA[1]))):
        cilindro("Ventilador_%d_eje" % v, vx, TECHO - 0.5, TECHO - 0.25, vz, 0.03, metal, col)
        for k in range(3):
            a = math.radians(k * 120)
            aspa = caja("Ventilador_%d_aspa_%d" % (v, k), -0.05, 0.55, TECHO - 0.52, TECHO - 0.5, -0.07, 0.07, madera, col, choca=False)
            aspa.location = _b(vx + math.cos(a) * 0.3, TECHO - 0.51, vz + math.sin(a) * 0.3)
            aspa.rotation_euler = (0, 0, -a)
    # Puntos por donde camina la gente (GenteSotano.gd): rodean la pista y la mesa del poker
    for k, (px, pz) in enumerate(((8.0, 3.1), (12.0, 2.0), (15.0, 2.2), (18.5, 2.6), (19.0, 5.6), (14.5, 7.0), (10.0, 6.4),
                                  (22.4, 3.2), (24.0, b0 + 3.2), (31.0, b0 + 3.2), (34.3, b0 + 3.0), (24.0, b1 - 1.2), (34.3, b1 - 1.6))):
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
    """La maquinita EL GORDO (antes OL PLEY), como las de la foto de AG: base de lamina antiderrapante, cuerpo,
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
    # La palanca, al lado derecho: placa cromada, brazo que gira en el vacio "Palanca" (rotacion en x
    # de Godot: positivo la jala hacia ti) y la bola roja. GabineteOlPley.jalar_palanca la mueve
    caja("Palanca_placa", 0.3, 0.33, 0.95, 1.2, -0.08, 0.1, metal, col, choca=False)
    cilindro("Palanca_eje", 0.0, 0.0, 0.06, 0.0, 0.03, metal, col, lados=8).rotation_euler = (0, math.radians(90), 0)
    eje = bpy.data.objects["Palanca_eje"]
    eje.location = _b(0.36, 1.07, 0.01)
    pivote = bpy.data.objects.new("Palanca", None)
    pivote.empty_display_size = 0.05
    pivote.location = _b(0.37, 1.07, 0.01)
    col.objects.link(pivote)
    brazo = cilindro("Palanca_brazo", 0.0, 0.0, 0.36, 0.0, 0.011, material("cromo", (0.75, 0.77, 0.8)), col, lados=6)
    brazo.parent = pivote
    brazo.location = _b(0.0, 0.18, 0.0)
    bola = esfera("Palanca_bola", 0.042, material("boton_0", (0.9, 0.1, 0.1), emision=0.6), col)
    bola.parent = pivote
    bola.location = _b(0.0, 0.38, 0.0)
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


def exportar_botellas():
    """Una botella de cada tipo en el origen (models/sotano/botellas.glb): la charola de la mesera
    y lo que haga falta en el juego las toma de ahi por nombre (Botella_cerveza...)."""
    col = coleccion("Botellas")
    for tipo in BOTELLAS:
        botella("Botella_" + tipo, tipo, 0.0, 0.0, 0.0, col)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in col.all_objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(SALIDA, "botellas.glb"), export_format="GLB", use_selection=True,
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
    exportar_botellas()
    exportar()
    print("sotano: %d objetos" % len(bpy.data.collections["Sotano"].all_objects))
