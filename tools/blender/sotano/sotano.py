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

PISO = -2.6           # el piso del cuarto
TECHO = -0.5          # 2.1 de alto (2.6 m en el juego)
CUARTO = (6.6, 17.0, -1.5, 7.7)   # x0, x1, z0, z1
PASILLO = (2.3, 3.9)              # z del descanso y la escalera
ESCALERA = (2.8, 6.6)             # x donde baja
PELDANOS = 13
GRUESO = 0.2


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
    col = coleccion("Sotano")
    piso = material("concreto_piso", (0.42, 0.40, 0.37))
    muro = material("block", (0.55, 0.53, 0.5))
    techo = material("concreto_techo", (0.35, 0.34, 0.33))
    humedad = material("humedad", (0.18, 0.2, 0.17))
    x0, x1, z0, z1 = CUARTO
    za, zb = PASILLO
    # El descanso, a nivel de la calle, con la puerta en la pared oeste
    caja("Descanso_piso", 0.0, ESCALERA[0], -GRUESO, 0.0, za, zb, piso, col)
    caja("Descanso_techo", -0.2, ESCALERA[0], 2.3, 2.3 + GRUESO, za - 0.2, zb + 0.2, techo, col)
    caja("Descanso_muro_oeste_n", -0.2, 0.0, -0.2, 2.5, za - 0.2, 2.61, muro, col)
    caja("Descanso_muro_oeste_s", -0.2, 0.0, -0.2, 2.5, 3.61, zb + 0.2, muro, col)
    caja("Descanso_dintel", -0.2, 0.0, 2.0, 2.5, 2.61, 3.61, muro, col)
    # La puerta de lamina, cerrada detras de ti
    caja("Puerta", -0.25, -0.2, 0.0, 2.0, 2.61, 3.61, material("lamina_puerta", (0.25, 0.3, 0.28)), col)
    # Pasillo de la escalera: muros a los lados, de la puerta al cuarto
    for nombre, za0, zb0 in (("Pasillo_muro_n", za - GRUESO, za), ("Pasillo_muro_s", zb, zb + GRUESO)):
        caja(nombre, 0.0, x0, PISO, 2.3, za0, zb0, muro, col)
    # Los peldanos (se ven) y la rampa que se camina (no se ve)
    paso = (ESCALERA[1] - ESCALERA[0]) / PELDANOS
    alto = (0.0 - PISO) / PELDANOS
    concreto = material("concreto_escalon", (0.5, 0.48, 0.44))
    for i in range(PELDANOS):
        xa = ESCALERA[0] + i * paso
        ya = -alto * (i + 1)
        caja("Escalon_%02d" % i, xa, xa + paso, PISO, ya, za, zb, concreto, col, choca=False)
    largo = math.hypot(ESCALERA[1] - ESCALERA[0], -PISO)
    ang = math.atan2(-PISO, ESCALERA[1] - ESCALERA[0])
    rampa = caja("Rampa", 0.0, largo, -0.1, 0.0, za, zb, piso, col, choca=False)
    rampa.name = "Rampa-colonly"
    # la caja se armo centrada: se pone a media escalera y se inclina (baja hacia +x)
    rampa.location = _b((ESCALERA[0] + ESCALERA[1]) / 2, PISO / 2 - 0.05, (za + zb) / 2)
    rampa.rotation_euler = (0, ang, 0)
    # El techo del pasillo baja con la escalera, en tres tramos
    for i, (xa, xb, y) in enumerate(((ESCALERA[0], 4.1, 1.6), (4.1, 5.4, 0.7), (5.4, x0, -0.2))):
        caja("Pasillo_techo_%d" % i, xa, xb, y, y + GRUESO, za - GRUESO, zb + GRUESO, techo, col)
    # El cuarto
    caja("Piso", x0, x1, PISO - GRUESO, PISO, z0, z1, piso, col)
    caja("Techo", x0, x1, TECHO, TECHO + GRUESO, z0, z1, techo, col)
    caja("Muro_norte", x0 - GRUESO, x1 + GRUESO, PISO, TECHO, z0 - GRUESO, z0, muro, col)
    caja("Muro_sur", x0 - GRUESO, x1 + GRUESO, PISO, TECHO, z1, z1 + GRUESO, muro, col)
    caja("Muro_este", x1, x1 + GRUESO, PISO, TECHO, z0, z1, muro, col)
    caja("Muro_oeste_n", x0 - GRUESO, x0, PISO, TECHO, z0, za - GRUESO, muro, col)
    caja("Muro_oeste_s", x0 - GRUESO, x0, PISO, TECHO, zb + GRUESO, z1, muro, col)
    caja("Muro_oeste_dintel", x0 - GRUESO, x0, -0.2, TECHO, za - GRUESO, zb + GRUESO, muro, col)
    # Manchas de humedad al pie de los muros (tiras oscuras)
    for nombre, a, b, c, d in (("Humedad_n", x0, x1, z0, z0 + 0.01), ("Humedad_s", x0, x1, z1 - 0.01, z1)):
        caja(nombre, a, b, PISO, PISO + 0.35, c, d, humedad, col, choca=False)
    caja("Humedad_e", x1 - 0.01, x1, PISO, PISO + 0.45, z0, z1, humedad, col, choca=False)
    # Columnas que cargan la colonia de arriba
    for i, (cx, cz) in enumerate(((10.0, 2.6), (13.4, 2.6))):
        caja("Columna_%d" % i, cx - 0.18, cx + 0.18, PISO, TECHO, cz - 0.18, cz + 0.18, material("concreto_columna", (0.5, 0.49, 0.46)), col)
    return col


def utileria(col):
    metal = material("metal", (0.35, 0.36, 0.38))
    madera = material("madera", (0.45, 0.32, 0.2))
    reja = material("reja", (0.15, 0.15, 0.16))
    tubo = material("tubo", (0.95, 0.97, 1.0), emision=3.0)
    neon_rosa = material("neon_rosa", (1.0, 0.2, 0.7), emision=6.0)
    neon_verde = material("neon_verde", (0.2, 1.0, 0.35), emision=6.0)
    cable = material("cable", (0.05, 0.05, 0.05))
    x0, x1, z0, z1 = CUARTO
    y = PISO
    # La ventanilla del Primo: un cuartito de block con reja al sur, en la esquina noroeste
    caja("Ventanilla_muro_e", 9.4, 9.6, y, TECHO, z0, 0.4, material("block"), col)
    caja("Ventanilla_mostrador", 6.6, 9.6, y, y + 1.0, 0.2, 0.45, madera, col)
    for i in range(14):
        xi = 6.75 + i * 0.2
        caja("Ventanilla_barrote_%02d" % i, xi - 0.012, xi + 0.012, y + 1.0, TECHO, 0.31, 0.34, reja, col, choca=False)
    caja("Ventanilla_reja_choque", 6.6, 9.4, y + 1.0, TECHO, 0.3, 0.35, reja, col)
    caja("Ventanilla_hueco", 7.7, 8.5, y + 1.0, y + 1.25, 0.28, 0.37, material("madera"), col, choca=False)
    marca("Primo", 8.1, y, -0.4, col, 0)
    marca("Ventanilla", 8.1, y, 0.9, col, 0)
    # El guardia al pie de la escalera y su cadena (la cadena choca hasta que lo dejas pasar)
    marca("Guardia", 7.3, y, 1.7, col, 180)
    caja("CadenaChoque-colonly", 6.5, 6.7, y, y + 2.0, PASILLO[0], PASILLO[1], reja, col, choca=False)
    for i in range(2):
        cilindro("Poste_cadena_%d" % i, 6.75, y, y + 0.9, PASILLO[0] + 0.1 + i * 1.4, 0.04, metal, col)
    caja("Cadena", 6.73, 6.77, y + 0.78, y + 0.82, PASILLO[0] + 0.1, PASILLO[1] - 0.1, reja, col, choca=False)
    # Las maquinitas OL PLEY: seis contra el muro norte (los gabinetes son otro .glb)
    for i in range(6):
        marca("OlPley_%d" % i, 10.4 + i * 1.05, y, z0 + 0.45, col, 0)
    # Dos de frutas en el muro oeste, al sur del pasillo
    marca("Frutas_0", x0 + 0.45, y, 5.3, col, -90)
    marca("Frutas_1", x0 + 0.45, y, 6.6, col, -90)
    # La mesa de la loteria con sus bancos y el griton
    caja("Loteria_mesa", 9.6, 12.2, y + 0.72, y + 0.78, 4.6, 6.0, madera, col)
    for i, (px, pz) in enumerate(((9.8, 4.8), (12.0, 4.8), (9.8, 5.8), (12.0, 5.8))):
        caja("Loteria_pata_%d" % i, px - 0.04, px + 0.04, y, y + 0.72, pz - 0.04, pz + 0.04, metal, col, choca=False)
    caja("Loteria_choque", 9.6, 12.2, y, y + 0.78, 4.6, 6.0, madera, col, choca=False).name = "Loteria_choque-colonly"
    for i, (px, pz) in enumerate(((10.2, 4.1), (11.6, 4.1), (10.2, 6.5), (11.6, 6.5))):
        cilindro("Banco_%d" % i, px, y, y + 0.45, pz, 0.17, material("plastico_rojo", (0.75, 0.1, 0.1)), col)
        marca("Banco_%d" % i, px, y, pz, col, 0 if pz > 5 else 180)
    marca("Griton", 12.75, y, 5.3, col, 90)
    marca("Loteria", 10.9, y, 3.6, col, 180)
    # La pista de los caballitos contra el muro este: una mesa larga con cinco rieles
    caja("Pista_mesa", 15.4, 16.9, y + 0.85, y + 0.92, 1.0, 6.6, material("fieltro_verde", (0.1, 0.35, 0.15)), col)
    caja("Pista_choque", 15.4, 16.9, y, y + 0.92, 1.0, 6.6, madera, col, choca=False).name = "Pista_choque-colonly"
    caja("Pista_faldon", 15.38, 15.42, y, y + 0.85, 1.0, 6.6, madera, col, choca=False)
    caja("Pista_meta", 15.4, 16.9, y + 0.92, y + 0.93, 6.2, 6.25, material("pintura_blanca", (0.95, 0.95, 0.9)), col, choca=False)
    colores = ((0.85, 0.15, 0.1), (0.1, 0.35, 0.85), (0.95, 0.8, 0.1), (0.1, 0.7, 0.25), (0.8, 0.4, 0.9))
    for i in range(5):
        xr = 15.6 + i * 0.27
        caja("Riel_%d" % i, xr - 0.01, xr + 0.01, y + 0.92, y + 0.95, 1.1, 6.5, metal, col, choca=False)
        caballo(i, xr, y + 0.95, 1.4, material("caballo_%d" % (i + 1), colores[i]), col)
    marca("Pista", 14.8, y, 3.8, col, 90)
    # El altar de la Virgen del Tinaco con billetes, en el muro sur
    caja("Altar_repisa", 13.6, 14.8, y + 1.0, y + 1.06, z1 - 0.35, z1, madera, col, choca=False)
    plano("Altar_estampa", (14.2, y + 1.5, z1 - 0.02), 0.7, 0.9, (0, 0, -1), material("estampa_virgen", (0.3, 0.5, 0.8)), col)
    for i in range(9):
        bx = 13.75 + (i % 3) * 0.45
        by = y + 1.2 + (i // 3) * 0.4
        plano("Billete_%d" % i, (bx, by, z1 - 0.015), 0.16, 0.07, (0, 0, -1), material("billete", (0.55, 0.75, 0.55)), col)
    for i in range(5):
        cilindro("Veladora_%d" % i, 13.75 + i * 0.22, y + 1.06, y + 1.18, z1 - 0.15, 0.03, material("veladora", (1.0, 0.75, 0.3), emision=2.0), col, lados=6)
    marca("Altar", 14.2, y, z1 - 0.9, col, 180)
    # El congelador de las caguamas, en el muro sur al oeste
    caja("Congelador", 7.0, 8.4, y, y + 0.9, z1 - 0.75, z1 - 0.05, material("congelador", (0.85, 0.85, 0.88)), col)
    caja("Congelador_tapa", 7.05, 8.35, y + 0.9, y + 0.93, z1 - 0.72, z1 - 0.08, material("vidrio", (0.4, 0.55, 0.6)), col, choca=False)
    marca("Congelador", 7.7, y, z1 - 1.3, col, 180)
    # La bocina sobre un huacal, junto a la columna
    caja("Huacal_bocina", 13.1, 13.6, y, y + 0.35, 6.7, 7.2, material("plastico_amarillo", (0.9, 0.75, 0.1)), col)
    caja("Bocina", 13.15, 13.55, y + 0.35, y + 1.0, 6.75, 7.15, material("bocina", (0.08, 0.08, 0.09)), col)
    marca("Bocina", 13.35, y + 0.7, 6.95, col, 0)
    # Huacales de refresco apilados en el pasillo de abajo y en las esquinas
    for i, (hx, hy, hz) in enumerate(((16.4, 0, 7.1), (16.4, 0.3, 7.1), (16.0, 0, 7.2), (6.9, 0, -1.1), (6.9, 0.3, -1.1))):
        caja("Huacal_%d" % i, hx - 0.25, hx + 0.25, y + hy, y + hy + 0.3, hz - 0.18, hz + 0.18, material("plastico_rojo"), col)
    # Tubos de luz (fluorescentes) colgados del techo y el neon OL PLEY sobre las maquinitas
    for i, (tx, tz) in enumerate(((8.2, 3.0), (11.0, 1.0), (13.8, 1.0), (11.0, 5.3), (15.2, 3.8), (8.2, 6.2))):
        caja("Tubo_%d" % i, tx - 0.6, tx + 0.6, TECHO - 0.08, TECHO - 0.04, tz - 0.03, tz + 0.03, tubo, col, choca=False)
        marca("Luz_%d" % i, tx, TECHO - 0.15, tz, col, 0)
    plano("Neon_marco", (13.0, TECHO - 0.45, z0 + 0.02), 3.2, 0.5, (0, 0, 1), neon_rosa, col)
    marca("Neon", 13.0, TECHO - 0.45, z0 + 0.3, col, 0)
    # Cables: por el techo de tubo a tubo y extensiones por el piso
    for i, (a, b) in enumerate((((8.2, 3.0), (11.0, 1.0)), ((11.0, 1.0), (13.8, 1.0)), ((11.0, 1.0), (11.0, 5.3)), ((13.8, 1.0), (15.2, 3.8)))):
        cable_recto("Cable_techo_%d" % i, Vector((a[0], TECHO - 0.02, a[1])), Vector((b[0], TECHO - 0.02, b[1])), cable, col)
    for i, (a, b) in enumerate((((10.4, z0 + 0.3), (16.0, z0 + 0.3)), ((16.0, z0 + 0.3), (16.2, 1.0)), ((13.35, 6.95), (15.0, 6.9)), ((x0 + 0.3, 5.3), (x0 + 0.3, 6.6)))):
        cable_recto("Extension_%d" % i, Vector((a[0], y + 0.01, a[1])), Vector((b[0], y + 0.01, b[1])), cable, col)
    # El ventilador de techo, al centro
    cilindro("Ventilador_eje", 11.7, TECHO - 0.3, TECHO, 2.6, 0.03, metal, col)
    for i in range(3):
        a = math.radians(i * 120)
        aspa = caja("Ventilador_aspa_%d" % i, -0.05, 0.55, TECHO - 0.32, TECHO - 0.3, -0.07, 0.07, madera, col, choca=False)
        aspa.location = _b(11.7 + math.cos(a) * 0.3, TECHO - 0.31, 2.6 + math.sin(a) * 0.3)
        aspa.rotation_euler = (0, 0, -a)
    # Sillas de plastico frente a las maquinitas
    for i in range(6):
        cilindro("Silla_%d" % i, 10.4 + i * 1.05, y, y + 0.45, z0 + 1.25, 0.18, material("plastico_blanco", (0.9, 0.9, 0.86)), col)
        marca("Silla_%d" % i, 10.4 + i * 1.05, y, z0 + 1.25, col, 0)


def cable_recto(nombre, a, b, mat, col):
    """Un cable delgado de a a b (Godot)."""
    d = b - a
    largo = d.length
    me = bpy.data.meshes.new(nombre)
    r = 0.012
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
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob


def caballo(i, x, y, z, mat, col):
    """Un caballito de lamina (silueta gruesa) parado en su riel, viendo al sur (+z)."""
    nombre = "Caballo_%d" % (i + 1)
    padre = bpy.data.objects.new(nombre, None)
    padre.location = _b(x, y, z)
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
