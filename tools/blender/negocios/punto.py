# El Punto en Blender: por fuera una cantina de dos pisos ("Cantina El Olvido") con aires en las
# ventanas, un anexo bajo con el mural de Santa Mugre, un lote enrejado con un carro viejo y sillas
# de plastico en la banqueta; adentro, la oficina de atras donde el patron vende fierros (armas y
# balas) sentado detras de su escritorio.
#
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\negocios"
#   exec(open(R + r"\punto.py", encoding="utf-8").read(), {"__name__": "punto", "EXPORTAR": True})
#
# Sale models/negocios/punto/punto_fuera.glb (PuntoMapa.gd) y punto_dentro.glb
# (scenes/interiores/punto.tscn). Afuera el origen es el centro de la fachada de la cantina, +Z a la
# calle, el edificio se mete hacia -Z. Lo opcional va por nombre para que PuntoMapa lo quite si el
# lote es angosto: "Anexo_*" (al oeste), "Lote_*" (al este) y "Banqueta_*" (en la banqueta, z > 0).
# El arte (mural, rotulo) lo pinta arte_punto.py en textures/negocios/.

import os
R_NEG = os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"),
                     "tools", "blender", "negocios")
exec(open(os.path.join(R_NEG, "yonke.py"), encoding="utf-8").read(), globals())   # carro(), mats()... sin armar el yonke

SALIDA = os.path.join(RAIZ, "models", "negocios", "punto")
CANTINA = (-3.0, 3.0, -9.0, 0.0)   # x0, x1, z0, z1
PISO_ALTO = 3.2
ALTO = 2 * PISO_ALTO + 0.3          # con el pretil
ANEXO = (-9.0, -3.0, 4.2)           # x0, x1, alto
LOTE = (3.0, 9.0)                   # x0, x1
PUERTA = (1.2, 2.2)                 # x de la puerta de la cantina
VIDRIO = (-2.75, 0.95)              # x del aparador
random.seed(21)


def mats_punto():
    M = mats()
    M.update({
        "aplanado": mat_tex("aplanado", "res://textures/mapa/aplanado_blanco.png", (0.86, 0.84, 0.78), 0.5),
        "aplanado_sucio": mat_tex("aplanado_sucio", "res://textures/mapa/aplanado_blanco.png", (0.62, 0.6, 0.56), 0.5),
        "zoclo": mat_tex("zoclo", "res://textures/mapa/block.png", (0.5, 0.5, 0.5), 0.7),
        "mural_punto": mat_tex("mural_punto", "res://textures/negocios/mural_punto.png", (1, 1, 1), 0.0),
        "cantina_punto": mat_tex("cantina_punto", "res://textures/negocios/cantina_punto.png", (1, 1, 1), 0.0),
        "vidrio_cantina": material("vidrio_cantina", (0.1, 0.12, 0.13)),
        "franja_amarilla": material("franja_amarilla", (0.85, 0.7, 0.15)),
        "marco_aluminio": material("marco_aluminio", (0.6, 0.62, 0.64)),
        "puerta_metal": material("puerta_metal", (0.3, 0.33, 0.35)),
        "aire": material("aire", (0.85, 0.84, 0.8)),
        "tinaco": material("tinaco", (0.07, 0.07, 0.08)),
        "plastico_blanco": material("plastico_blanco", (0.9, 0.9, 0.86)),
        "plastico_verde": material("plastico_verde", (0.1, 0.55, 0.5)),
        "reja_negra": material("reja_negra", (0.08, 0.08, 0.08)),
        "cromo": material("cromo", (0.75, 0.76, 0.78)),
        "moto_amarilla": material("moto_amarilla", (0.85, 0.65, 0.1)),
        "moto_roja": material("moto_roja", (0.6, 0.1, 0.08)),
        "neon_rojo": material("neon_rojo", (1.0, 0.2, 0.15), emision=4.0),
        "neon_azul": material("neon_azul", (0.3, 0.45, 1.0), emision=4.0),
        "cable": material("cable", (0.05, 0.05, 0.05)),
        "careta": material("careta", (0.1, 0.1, 0.12)),
    })
    for k in (1, 3, 5, 9, 12):
        M["grafiti_%02d" % k] = mat_tex("grafiti_%02d" % k, "res://textures/map/grafitis/grafiti_firma_%02d.png", (1, 1, 1), 0.0)
    return M


def ventana(nombre, x0, x1, y0, y1, z, M, col, aire=False, reja=False):
    """Ventana de aluminio en la fachada (z), con vidrio oscuro, y un aire de ventana o una reja."""
    caja(nombre + "_marco", x0 - .06, x1 + .06, y0 - .06, y1 + .06, z, z + .04, M["marco_aluminio"], col, choca=False)
    plano(nombre + "_vidrio", ((x0 + x1) / 2, (y0 + y1) / 2, z + .045), x1 - x0, y1 - y0, (0, 0, 1), M["vidrio_cantina"], col)
    caja(nombre + "_repisa", x0 - .1, x1 + .1, y0 - .12, y0 - .06, z, z + .12, M["aplanado_sucio"], col, choca=False)
    if aire:
        ax = (x0 + x1) / 2
        caja(nombre + "_aire", ax - .33, ax + .33, y0, y0 + .42, z - .2, z + .35, M["aire"], col, choca=False)
        plano(nombre + "_aire_rejilla", (ax, y0 + .21, z + .355), .56, .32, (0, 0, 1), M["hueco"], col)
        # El chorrete del aire en la pared
        plano(nombre + "_chorrete", (ax + .1, y0 - .7, z + .005), .12, 1.1, (0, 0, 1), M["aplanado_sucio"], col)
    if reja:
        barras = [caja(nombre + "_barra%d" % k, x0 + k * (x1 - x0) / 4 - .015, x0 + k * (x1 - x0) / 4 + .015, y0, y1, z + .08, z + .1,
                       M["reja_negra"], col, choca=False) for k in range(1, 4)]
        barras += [caja(nombre + "_barra_h%d" % k, x0, x1, y0 + k * (y1 - y0) / 3 - .015, y0 + k * (y1 - y0) / 3 + .015, z + .08, z + .1,
                        M["reja_negra"], col, choca=False) for k in range(1, 3)]
        juntar(nombre + "_reja", barras, col)


def cantina(col, M):
    x0, x1, z0, z1 = CANTINA
    # El bloque: muros de aplanado, losa y pretil
    caja("Cantina_cuerpo", x0, x1, 0, 2 * PISO_ALTO, z0, z1 - .02, M["aplanado"], col)
    caja("Cantina_pretil", x0 - .05, x1 + .05, 2 * PISO_ALTO, ALTO, z1 - .2, z1 + .03, M["aplanado"], col, choca=False)
    for s in (x0, x1):
        caja("Cantina_pretil_lado", s - .1, s + .1, 2 * PISO_ALTO, ALTO, z0, z1, M["aplanado"], col, choca=False)
    caja("Cantina_pretil_atras", x0, x1, 2 * PISO_ALTO, ALTO, z0, z0 + .2, M["aplanado"], col, choca=False)
    caja("Cantina_losa", x0 - .15, x1 + .15, PISO_ALTO - .12, PISO_ALTO + .08, z1, z1 + .25, M["aplanado_sucio"], col, choca=False)
    # Planta baja: el aparador de vidrio con la franja amarilla y el rotulo, y la puerta de metal
    vx0, vx1 = VIDRIO
    caja("Cantina_zoclo", x0, x1, 0, .45, z1, z1 + .05, M["zoclo"], col, choca=False)
    caja("Cantina_aparador_marco", vx0 - .06, vx1 + .06, .4, 2.7, z1, z1 + .05, M["marco_aluminio"], col, choca=False)
    plano("Cantina_aparador", ((vx0 + vx1) / 2, 1.55, z1 + .055), vx1 - vx0, 2.2, (0, 0, 1), M["vidrio_cantina"], col)
    caja("Cantina_parteluz", (vx0 + vx1) / 2 - .04, (vx0 + vx1) / 2 + .04, .45, 2.65, z1 + .05, z1 + .09, M["marco_aluminio"], col, choca=False)
    caja("Cantina_franja", vx0, vx1, 1.35, 1.43, z1 + .06, z1 + .07, M["franja_amarilla"], col, choca=False)
    plano("Cantina_rotulo", ((vx0 + vx1) / 2, 2.15, z1 + .065), 2.4, .6, (0, 0, 1), M["cantina_punto"], col)
    # Neones en el vidrio (una cerveza y un ABIERTO)
    tubo_curva("Cantina_neon_cerveza", [Vector((vx0 + .5 + .25 * math.cos(t), 1.75 + .18 * math.sin(t), z1 + .08)) for t in [k * math.tau / 14 for k in range(14)]],
               .02, M["neon_rojo"], col, lados=4, cerrado=True)
    caja("Cantina_neon_abierto", vx1 - 1.0, vx1 - .3, 1.62, 1.66, z1 + .07, z1 + .09, M["neon_azul"], col, choca=False)
    caja("Cantina_neon_abierto2", vx1 - 1.0, vx1 - .3, 1.82, 1.86, z1 + .07, z1 + .09, M["neon_azul"], col, choca=False)
    px0, px1 = PUERTA
    caja("Cantina_puerta_marco", px0 - .08, px1 + .08, 0, 2.35, z1, z1 + .06, M["marco_aluminio"], col, choca=False)
    caja("Cantina_puerta", px0, px1, 0, 2.25, z1 + .02, z1 + .08, M["puerta_metal"], col, choca=False)
    caja("Cantina_chapa", px1 - .18, px1 - .1, 1.0, 1.1, z1 + .08, z1 + .11, M["cromo"], col, choca=False)
    plano("Cantina_letrero_puerta", ((px0 + px1) / 2, 1.65, z1 + .085), .5, .3, (0, 0, 1), M["letrero_rojo"], col)
    # Planta alta: tres ventanas, dos con aire y la de en medio con reja de cuadros
    for k, xv in enumerate((-1.9, 0.0, 1.9)):
        ventana("Cantina_ventana%d" % k, xv - .65, xv + .65, PISO_ALTO + .9, PISO_ALTO + 2.1, z1, M, col, aire=(k != 1), reja=(k == 1))
    # Bajante y cables
    cilindro("Cantina_bajante", x0 + .15, 0, ALTO, z1 + .1, .05, M["marco_aluminio"], col, lados=6)
    tubo_curva("Cantina_cable", [Vector((x1 + .4, 5.8, z1 + 1.0)), Vector((x1 - .2, 5.2, z1 + .08)), Vector((x0 + .3, 5.4, z1 + .08))],
               .015, M["cable"], col, lados=4)
    # Manchas, grietas y grafitis en los macizos de abajo
    for k in range(6):
        plano("Cantina_mancha%d" % k, (random.uniform(x0 + .3, x1 - .3), random.uniform(.5, 2.8), z1 + .004),
              random.uniform(.4, 1.0), random.uniform(.2, .5), (0, 0, 1), M["aplanado_sucio"], col)
    plano("Cantina_tag1", (2.6, .9, z1 + .07), .55, .32, (0, 0, 1), M["grafiti_03"], col)
    plano("Cantina_tag2", (x1 + .004, 1.2, -2.0), 1.2, .6, (1, 0, 0), M["grafiti_09"], col)
    # La azotea: tinaco (con su base), antena y tendedero
    caja("Azotea_base", -2.2, -1.0, 2 * PISO_ALTO, 2 * PISO_ALTO + .5, -6.8, -5.6, M["block"], col, choca=False)
    girar("Azotea_tinaco", [(0, 0), (.55, 0), (.6, .1), (.6, 1.1), (.5, 1.25), (.25, 1.32), (.25, 1.4), (0, 1.4)], M["tinaco"], col, lados=12)
    bpy.data.objects["Azotea_tinaco"].location = _b(-1.6, 2 * PISO_ALTO + .5, -6.2)
    cilindro("Azotea_antena", 1.8, 2 * PISO_ALTO, 2 * PISO_ALTO + 2.4, -3.0, .025, M["fierro"], col, lados=4)
    for k in range(3):
        caja("Azotea_antena_brazo%d" % k, 1.2, 2.4, 2 * PISO_ALTO + 1.6 + k * .3, 2 * PISO_ALTO + 1.62 + k * .3, -3.01, -2.99, M["fierro"], col, choca=False)


def anexo(col, M):
    x0, x1, alto = ANEXO
    z0, z1 = CANTINA[2], CANTINA[3]
    caja("Anexo_cuerpo", x0, x1, 0, alto, z0, z1 - .3, M["aplanado"], col)
    caja("Anexo_techo", x0 - .1, x1, alto, alto + .1, z0, z1 - .1, M["lamina_techo"], col, choca=False)
    # El mural en todo el frente y el que sigue por el costado
    plano("Anexo_mural", ((x0 + x1) / 2, .2 + (alto - .5) / 2, z1 - .29), x1 - x0 - .1, alto - .5, (0, 0, 1), M["mural_punto"], col)
    plano("Anexo_mural_lado", (x0 - .005, .2 + (alto - .5) / 2, z1 - .3 - 3.0), 6.0, alto - .5, (-1, 0, 0), M["mural_punto"], col, uv=(0, 0, .75, 1))
    caja("Anexo_zoclo", x0, x1, 0, .2, z1 - .3, z1 - .27, M["zoclo"], col, choca=False)
    # Los postes amarillos de la banqueta
    for k, px in enumerate((-8.4, -6.6, -4.8)):
        cilindro("Anexo_poste%d" % k, px, 0, .7, z1 + .2, .05, M["franja_amarilla"], col, lados=6)
    plano("Anexo_tag", (-3.6, 1.0, z1 - .28), .8, .45, (0, 0, 1), M["grafiti_12"], col)


def lote(col, M):
    x0, x1 = LOTE
    z0, z1 = CANTINA[2], CANTINA[3]
    # Barda del fondo y del lado, de block, y la reja negra del frente con su porton
    caja("Lote_barda_fondo", x0, x1, 0, 2.2, z0, z0 + .15, M["block"], col)
    caja("Lote_barda_lado", x1 - .15, x1, 0, 2.2, z0, z1 - .3, M["block"], col)
    caja("Lote_piso", x0, x1, -.02, .02, z0, z1 - .2, M["zoclo"], col, choca=False)
    barras = []
    for k in range(int((x1 - x0) / .14)):
        bx = x0 + .1 + k * .14
        if x0 + 1.5 < bx < x0 + 4.0:
            continue          # el porton (abierto)
        barras.append(caja("Lote_barra%d" % k, bx - .012, bx + .012, 0, 2.0, z1 - .27, z1 - .25, M["reja_negra"], col, choca=False))
    for yy in (.15, 1.85):
        barras.append(caja("Lote_travesano_a", x0, x0 + 1.5, yy, yy + .04, z1 - .28, z1 - .24, M["reja_negra"], col, choca=False))
        barras.append(caja("Lote_travesano_b", x0 + 4.0, x1, yy, yy + .04, z1 - .28, z1 - .24, M["reja_negra"], col, choca=False))
    juntar("Lote_reja", barras, col)
    for px in (x0 + .05, x0 + 1.5, x0 + 4.0, x1 - .05):
        caja("Lote_poste", px - .05, px + .05, 0, 2.15, z1 - .3, z1 - .2, M["reja_negra"], col)
    # Choque de la reja (las barras no chocan una por una)
    caja("Lote_reja_choque_a", x0, x0 + 1.5, 0, 2.0, z1 - .3, z1 - .22, M["reja_negra"], col).hide_render = True
    caja("Lote_reja_choque_b", x0 + 4.0, x1, 0, 2.0, z1 - .3, z1 - .22, M["reja_negra"], col).hide_render = True
    for nombre in ("Lote_reja_choque_a-convcol", "Lote_reja_choque_b-convcol"):
        ob = bpy.data.objects[nombre]
        ob.name = nombre.replace("-convcol", "-colonly")
    hoja = caja("Lote_porton", 0, 2.4, 0, 2.0, -.02, .02, M["reja_negra"], col, choca=False)
    hoja.data.transform(Matrix.Translation(Vector((1.2, 0, 0))))
    hoja.location = _b(x0 + 4.0, 1.0, z1 - .26)
    hoja.rotation_euler.z = math.radians(-110)
    # El carro viejo (un Caprice gris, como de los ochentas) y unas llantas
    carro("Lote_carro", 6.0, 0, -4.0, 92, COLORES_CARRO[6], col, M)
    # La troca del patron, nuevecita, junto al Caprice
    carro("Lote_troca", 6.2, 0, -7.6, 88, COLORES_CARRO[3], col, M, tipo="pickup", vidrios_rotos=0.0, oxido=0.0, abollado=0.0, semilla=12)
    llantas("Lote_llantas", 8.3, -7.8, 3, col, M)


def banqueta(col, M):
    # Dos mesas de plastico con sus sillas y dos motos en la banqueta, frente al aparador
    for k, (mx, mz) in enumerate(((-1.6, 1.3), (.1, 1.5))):
        piezas = [caja("Banqueta_mesa_tapa", -.4, .4, .72, .76, -.4, .4, M["plastico_blanco"], col, choca=False)]
        for sx in (-1, 1):
            for sz in (-1, 1):
                piezas.append(caja("Banqueta_mesa_pata", sx * .34 - .025, sx * .34 + .025, 0, .72, sz * .34 - .025, sz * .34 + .025, M["plastico_blanco"], col, choca=False))
        juntar("Banqueta_mesa%d" % k, piezas, col, matriz(mx, 0, mz, random.uniform(-10, 10)))
        for j, (sx, sz, giro) in enumerate(((-.65, 0, 90), (.65, 0, -90), (0, .65, 180))):
            silla = [caja("Banqueta_silla_asiento", -.22, .22, .42, .46, -.22, .22, M["plastico_verde"], col, choca=False),
                     caja("Banqueta_silla_respaldo", -.22, .22, .46, .9, -.24, -.2, M["plastico_verde"], col, choca=False)]
            for px in (-.19, .19):
                for pz in (-.19, .19):
                    silla.append(caja("Banqueta_silla_pata", px - .02, px + .02, 0, .42, pz - .02, pz + .02, M["plastico_verde"], col, choca=False))
            juntar("Banqueta_silla%d%d" % (k, j), silla, col, matriz(mx + sx, 0, mz + sz, giro + random.uniform(-15, 15)))
    for k, (mx, mz, mat) in enumerate(((2.8, 1.6, M["moto_amarilla"]), (4.0, 1.7, M["moto_roja"]))):
        piezas = []
        for u in (-.65, .65):
            r = cilindro_eje("Banqueta_moto_rueda", .32, .1, "z", M["llanta"], col, lados=10)
            r.location = _b(u, .32, 0)
            piezas.append(r)
        piezas.append(prisma("Banqueta_moto_tanque", [(-.2, .7), (.4, .72), (.3, .95), (-.15, .92)], .3, mat, col))
        piezas.append(caja("Banqueta_moto_asiento", -.6, -.15, .72, .82, -.13, .13, M["careta"], col, choca=False))
        piezas.append(caja("Banqueta_moto_motor", -.25, .3, .3, .65, -.15, .15, M["cromo"], col, choca=False))
        piezas.append(caja("Banqueta_moto_horquilla", .55, .62, .3, 1.15, -.05, .05, M["cromo"], col, choca=False))
        piezas.append(caja("Banqueta_moto_manubrio", .5, .6, 1.12, 1.18, -.38, .38, M["cromo"], col, choca=False))
        juntar("Banqueta_moto%d-convcol" % k, piezas, col, matriz(mx, 0, mz, 75 + k * 20, giro_z=6))
    # Una hielera junto a la puerta
    caja("Banqueta_hielera", 2.35, 2.95, 0, .45, .15, .55, M["letrero_rojo"], col)
    caja("Banqueta_hielera_tapa", 2.33, 2.97, .45, .52, .13, .57, M["plastico_blanco"], col, choca=False)
    # --- Ronda 3: letrero de neon, foquitos colgados, basura, el lowrider, y las marcas de la noche
    z1 = CANTINA[3]
    caja("Cantina_neon_caja", -1.6, 1.6, 2.75, 3.15, z1 + .05, z1 + .15, M["hueco"], col, choca=False)
    t = letrero("Cantina_neon_texto", "CANTINA", .32, M["neon_rojo"], col)
    t.location = _b(0, 2.82, z1 + .16)
    t2 = letrero("Cantina_neon_olvido", "EL OLVIDO", .14, M["neon_azul"], col)
    t2.location = _b(0, 2.62, z1 + .16)
    foco = material("foco_serie", (1.0, 0.85, 0.45), emision=4.0)
    for k, (xa, xb) in enumerate(((-2.9, 2.9), (-8.8, -3.2))):
        pts = []
        for i in range(13):
            u = i / 12
            pts.append(Vector((xa + (xb - xa) * u, 2.55 - .35 * math.sin(u * math.pi), z1 + 1.2)))
        tubo_curva("Banqueta_cable_focos%d" % k, pts, .008, M["cable"], col, lados=3)
        for i, p in enumerate(pts[1:-1]):
            esfera("Banqueta_foco_%d_%d" % (k, i), .045, foco, col, lados=6, anillos=4).location = _b(p.x, p.y - .06, p.z)
    for xp in (-2.9, 2.9, -8.8):
        cilindro("Banqueta_poste_focos", xp, 0, 2.6, z1 + 1.2, .035, M["fierro"], col, lados=6)
    # Bolsas de basura y una caja de cartones junto al lote
    for k in range(4):
        girar("Banqueta_basura%d" % k, [(0, 0), (.25, 0), (.28, .2), (.18, .45), (.05, .5), (0, .5)], M["hueco"], col, lados=8).location = \
            _b(3.4 + k * .35, 0, z1 + .4 + (k % 2) * .25)
    caja("Banqueta_cartones", 4.6, 5.3, 0, .35, z1 + .2, z1 + .8, M["carton"] if "carton" in M else M["madera"], col, choca=False)
    # El lowrider color dulce frente al anexo, rines cromados (un sedan aplastado de suspension)
    lr, _ = carro("Banqueta_lowrider", -6.0, -.12, z1 + 2.6, 0, COLORES_CARRO[9], col, M, sin_llantas=False, vidrios_rotos=0.0,
                  oxido=0.0, abollado=0.0, semilla=99)
    lr.name = "Banqueta_lowrider-convcol"
    # Marcas de la noche (PuntoMapa): los halcones en la puerta, los que toman afuera y las luces
    marca("Noche_halcon_0", PUERTA[0] - .9, 0, z1 + .5, col, giro_y=180)
    marca("Noche_halcon_1", PUERTA[1] + .9, 0, z1 + .6, col, giro_y=160)
    marca("Noche_toma_0", -1.6, 0, 1.3 + .65, col, giro_y=90)
    marca("Noche_toma_1", .1, 0, 1.5 + .65, col, giro_y=-90)
    marca("Noche_luz_0", 0, 2.4, z1 + 1.0, col)
    marca("Noche_luz_1", -6.0, 2.4, z1 + 1.2, col)
    marca("Flecha", (PUERTA[0] + PUERTA[1]) / 2, 0, 1.0, col)


def exterior():
    col = coleccion("PuntoFuera")
    M = mats_punto()
    cantina(col, M)
    anexo(col, M)
    lote(col, M)
    banqueta(col, M)
    return col


# ---------------------------------------------------------------- adentro: la oficina del patron
# Coordenadas de Interior.gd: el frente del escritorio (el Mostrador) en z = 0, piso en y = 0, la
# camara en +Z viendo a -Z. Madera oscura, alfombra, la persiana con rayas de luz, la pared de
# fierros detras de el y lo suyo en el escritorio.
OFICINA = (-2.4, 2.4, -3.4, 2.9)     # x0, x1, z0, z1
OFICINA_ALTO = 2.7


def mats_oficina():
    M = mats_punto()
    M.update({
        "lambrin": mat_tex("lambrin", "res://textures/mapa/madera.png", (0.42, 0.26, 0.16), 1.0),
        "lambrin_oscuro": mat_tex("lambrin_oscuro", "res://textures/mapa/madera.png", (0.25, 0.15, 0.1), 1.2),
        "alfombra": material("alfombra", (0.35, 0.08, 0.07)),
        "piel_negra": material("piel_negra", (0.06, 0.05, 0.05)),
        "pano_verde": material("pano_verde", (0.08, 0.28, 0.16)),
        "oro": material("oro", (0.95, 0.72, 0.2)),
        "polvo": material("polvo", (0.95, 0.95, 0.93)),
        "bolsa": material("bolsa", (0.85, 0.88, 0.9)),
        "billetes": material("billetes", (0.45, 0.6, 0.4)),
        "caja_balas": material("caja_balas", (0.35, 0.4, 0.2)),
        "caja_balas_roja": material("caja_balas_roja", (0.55, 0.15, 0.1)),
        "fierro_negro": material("fierro_negro", (0.1, 0.1, 0.11)),
        "culata": material("culata", (0.35, 0.2, 0.1)),
        "persiana": material("persiana", (0.75, 0.7, 0.6)),
        "foco_luz_dia": material("foco_luz_dia", (1.0, 0.9, 0.7), emision=4.0),
        "lampara_verde": material("lampara_verde", (0.1, 0.45, 0.25)),
        "foco_lampara": material("foco_lampara", (1.0, 0.85, 0.5), emision=5.0),
        "manchado_leopardo": material("manchado_leopardo", (0.8, 0.6, 0.3)),
        "estampa_virgen": material("estampa_virgen", (0.9, 0.85, 0.7)),
        "caja_fuerte": material("caja_fuerte", (0.2, 0.22, 0.2)),
    })
    return M


def rifle(nombre, largo, col, M, culata=True):
    """Un cuerno o una escopeta de perfil (a lo largo de x), para la pared de fierros."""
    p = [caja(nombre + "_canon", 0, largo * .55, -.012, .012, -.012, .012, M["fierro_negro"], col, choca=False),
         caja(nombre + "_cuerpo", largo * .45, largo * .78, -.05, .03, -.02, .02, M["fierro_negro"], col, choca=False),
         caja(nombre + "_cargador", largo * .55, largo * .62, -.15, -.04, -.018, .018, M["fierro_negro"], col, choca=False)]
    if culata:
        p.append(prisma(nombre + "_culata", [(largo * .78, -.05), (largo, -.11), (largo, .02), (largo * .78, .03)], .035, M["culata"], col))
    return p


def oficina():
    col = coleccion("PuntoDentro")
    M = mats_oficina()
    x0, x1, z0, z1 = OFICINA
    a = OFICINA_ALTO
    g = .08
    caja("O_piso", x0, x1, -g, 0, z0, z1, M["lambrin_oscuro"], col)
    caja("O_alfombra", -1.8, 1.8, 0, .01, -2.6, 1.6, M["alfombra"], col, choca=False)
    caja("O_techo", x0, x1, a, a + g, z0, z1, M["aplanado_sucio"], col)
    caja("O_fondo", x0, x1, 0, a, z0 - g, z0, M["lambrin"], col)
    caja("O_frente", x0, x1, 0, a, z1, z1 + g, M["lambrin"], col)
    caja("O_oeste", x0 - g, x0, 0, a, z0, z1, M["lambrin"], col)
    caja("O_este", x1, x1 + g, 0, a, z0, z1, M["lambrin"], col)
    # Molduras: zoclo y cornisa de madera oscura
    for nombre, (ax0, ax1, az0, az1) in (("fondo", (x0, x1, z0, z0 + .03)), ("oeste", (x0, x0 + .03, z0, z1)), ("este", (x1 - .03, x1, z0, z1))):
        caja("O_zoclo_" + nombre, ax0, ax1, 0, .15, az0, az1, M["lambrin_oscuro"], col, choca=False)
        caja("O_cornisa_" + nombre, ax0, ax1, a - .12, a, az0, az1, M["lambrin_oscuro"], col, choca=False)
    # Persiana en el muro oeste: tablillas con la luz de la calle colandose entre ellas
    plano("O_ventana_luz", (x0 + .01, 1.55, -1.6), 1.4, 1.1, (1, 0, 0), M["foco_luz_dia"], col)
    tablillas = [caja("O_tablilla%d" % k, x0 + .02, x0 + .06, 1.0 + k * .085, 1.04 + k * .085, -2.3, -.9, M["persiana"], col, choca=False)
                 for k in range(13)]
    juntar("O_persiana", tablillas, col)
    # El escritorio (el Mostrador): madera oscura con cubierta de pano verde
    caja("O_escritorio", -1.2, 1.2, 0, .74, -.95, 0, M["lambrin_oscuro"], col)
    caja("O_escritorio_cubierta", -1.15, 1.15, .74, .77, -.9, -.05, M["pano_verde"], col, choca=False)
    caja("O_escritorio_tapa", -1.25, 1.25, .77, .8, -1.0, .05, M["lambrin_oscuro"], col, choca=False)
    for k in range(3):
        caja("O_cajon%d" % k, .45, 1.1, .1 + k * .2, .27 + k * .2, .0, .02, M["lambrin"], col, choca=False)
        caja("O_jaladera%d" % k, .72, .82, .17 + k * .2, .2 + k * .2, .02, .04, M["oro"], col, choca=False)
    # Lo de encima: la bolsa de polvo con su navaja, la bascula, fajos, la lampara de banquero,
    # el cenicero con el puro y una escuadra dorada
    girar("O_bolsa", [(0, 0), (.08, 0), (.1, .06), (.09, .14), (.035, .18), (.02, .22), (0, .22)], M["bolsa"], col, lados=8)
    bpy.data.objects["O_bolsa"].location = _b(.35, .8, -.5)
    cilindro("O_polvo_monton", -.05, .8, .83, -.35, .1, M["polvo"], col, lados=8)
    caja("O_navaja", -.25, .05, .8, .815, -.32, -.29, M["cromo"], col, choca=False)
    caja("O_bascula", .65, .9, .8, .86, -.7, -.5, M["fierro_negro"], col, choca=False)
    cilindro("O_bascula_plato", .78, .86, .87, -.6, .09, M["cromo"], col, lados=10)
    for k in range(4):
        caja("O_fajo%d" % k, -1.0 + (k % 2) * .2, -.83 + (k % 2) * .2, .8 + (k // 2) * .05, .85 + (k // 2) * .05, -.75, -.65, M["billetes"], col, choca=False)
    cilindro("O_lampara_pie", -.75, .8, 1.15, -.78, .015, M["oro"], col, lados=6)
    caja("O_lampara_base", -.85, -.65, .8, .83, -.85, -.7, M["oro"], col, choca=False)
    pantalla = prisma("O_lampara_pantalla", [(-.2, 1.12), (.2, 1.12), (.12, 1.22), (-.12, 1.22)], .16, M["lampara_verde"], col)
    pantalla.location = _b(-.75, 0, -.78)
    caja("O_lampara_foco", -.88, -.62, 1.1, 1.12, -.83, -.73, M["foco_lampara"], col, choca=False)
    cilindro("O_cenicero", .95, .8, .83, -.2, .07, M["cromo"], col, lados=8)
    puro = cilindro_eje("O_puro", .012, .14, "x", M["culata"], col, lados=6)
    puro.location = _b(.95, .845, -.2)
    pistola = [caja("O_escuadra_corredera", 0, .19, 0, .035, -.014, .014, M["oro"], col, choca=False),
               caja("O_escuadra_mango", .13, .18, -.1, 0, -.013, .013, M["oro"], col, choca=False)]
    juntar("O_escuadra", pistola, col, matriz(-.35, .815, -.75, 25, giro_x=90))
    # La silla de piel del patron (detras del escritorio, donde se sienta el Vendedor)
    caja("O_silla_asiento", -.35, .35, .38, .52, -1.65, -1.05, M["piel_negra"], col)
    caja("O_silla_respaldo", -.38, .38, .52, 1.55, -1.75, -1.6, M["piel_negra"], col, choca=False)
    caja("O_silla_cabecera", -.32, .32, 1.55, 1.68, -1.78, -1.62, M["piel_negra"], col, choca=False)
    for s in (-1, 1):
        caja("O_silla_brazo", s * .38 - .05, s * .38 + .05, .52, .72, -1.6, -1.05, M["piel_negra"], col, choca=False)
    cilindro("O_silla_pie", 0, 0, .38, -1.35, .04, M["cromo"], col, lados=6)
    caja("O_silla_estrella", -.3, .3, 0, .04, -1.38, -1.32, M["cromo"], col, choca=False)
    # La pared de fierros: tablero con cuernos y escopetas, y repisas con cajas de balas
    caja("O_tablero", -1.9, 1.9, .95, 2.35, z0 + .01, z0 + .05, M["lambrin_oscuro"], col, choca=False)
    for k, (yy, largo) in enumerate(((2.12, 1.05), (1.82, .95), (1.52, 1.0), (1.22, .9))):
        for j, xx in enumerate((-1.75, .55)):
            piezas = rifle("O_rifle%d%d" % (k, j), largo, col, M, culata=(k + j) % 3 != 0)
            juntar("O_rifle%d%d" % (k, j), piezas, col, matriz(xx, yy, z0 + .08, 0, giro_z=0))
    for k, yy in enumerate((.35, .7)):
        caja("O_repisa%d" % k, -2.3, -1.4, yy, yy + .03, z0 + .02, z0 + .4, M["lambrin_oscuro"], col, choca=False)
        caja("O_repisa_d%d" % k, 1.4, 2.3, yy, yy + .03, z0 + .02, z0 + .4, M["lambrin_oscuro"], col, choca=False)
        for j in range(4):
            for lado, bx in ((0, -2.25), (1, 1.45)):
                m = M["caja_balas_roja"] if (j + k + lado) % 3 == 0 else M["caja_balas"]
                caja("O_balas%d%d%d" % (k, j, lado), bx + j * .21, bx + j * .21 + .18, yy + .03, yy + .03 + random.uniform(.1, .16),
                     z0 + .06, z0 + .3, m, col, choca=False)
    # La Virgen del Tinaco en su marco dorado, y una veladora
    caja("O_marco_virgen", -.28, .28, 2.38, 2.62, z0 + .01, z0 + .04, M["oro"], col, choca=False)
    plano("O_virgen", (0, 2.5, z0 + .045), .44, .2, (0, 0, 1), M["estampa_virgen"], col)
    # Caja fuerte en la esquina y un tapete de leopardo
    caja("O_caja_fuerte", x1 - .7, x1 - .05, 0, .8, -2.4, -1.75, M["caja_fuerte"], col)
    cilindro_eje("O_perilla", .07, .04, "x", M["cromo"], col, lados=10).location = _b(x1 - .72, .5, -2.07)
    # Un letrero de neon en el muro este y el ventilador de techo
    tubo_curva("O_neon", [Vector((x1 - .02, 1.9, -1.2)), Vector((x1 - .02, 2.2, -.9)), Vector((x1 - .02, 1.9, -.6)),
                          Vector((x1 - .02, 2.2, -.3))], .018, M["neon_rojo"], col, lados=4)
    caja("O_ventilador_tubo", -.02, .02, a - .3, a, .3, .34, M["oro"], col, choca=False)
    for k in range(4):
        aspa = caja("O_aspa%d" % k, 0, .55, a - .32, a - .3, -.06, .06, M["lambrin_oscuro"], col, choca=False)
        aspa.location = _b(0, a - .31, .32)
        aspa.data.transform(Matrix.Translation(Vector((-0.0, 0, 0))))
        aspa.rotation_euler.z = math.radians(k * 90 + 20)
    # --- Lo de narco de lujo (ronda 3): tapete de tigre, pecera, telefono de oro, contadora de
    # billetes, caja fuerte abierta con fajos, tele grande, el altar con veladoras y flores, la
    # caja de puros, el whisky y la escuadra de oro en su vitrina
    naranja = material("tigre", (0.9, 0.5, 0.12))
    caja("O_tigre", -.95, .95, .012, .02, .3, 1.5, naranja, col, choca=False)
    for k in range(9):
        zz = .4 + k * .12
        caja("O_tigre_raya%d" % k, -.8 + (k % 2) * .1, .7 - (k % 3) * .1, .02, .024, zz, zz + .04, M["hueco"], col, choca=False)
    girar("O_tigre_cabeza", [(0, 0), (.18, 0), (.16, .08), (0, .1)], naranja, col, lados=8).location = _b(0, .02, 1.65)
    # Pecera sobre un mueble bajo en el muro oeste (cerca de la camara)
    caja("O_mueble_pecera", x0 + .02, x0 + .55, 0, .8, .2, 1.6, M["lambrin_oscuro"], col)
    agua = material("agua_pecera", (0.2, 0.55, 0.85), emision=1.5)
    caja("O_pecera_agua", x0 + .08, x0 + .5, .82, 1.32, .3, 1.5, agua, col, choca=False)
    caja("O_pecera_tapa", x0 + .06, x0 + .52, 1.32, 1.36, .28, 1.52, M["hueco"], col, choca=False)
    caja("O_pecera_grava", x0 + .08, x0 + .5, .8, .86, .3, 1.5, M["letrero_amarillo"], col, choca=False)
    for k in range(5):
        pez = caja("O_pez%d" % k, -.04, .04, -.015, .015, -.01, .01, random.choice((M["letrero_amarillo"], M["letrero_rojo"], M["letrero_blanco"])), col, choca=False)
        pez.location = _b(x0 + random.uniform(.15, .45), random.uniform(.95, 1.25), random.uniform(.4, 1.4))
    # Telefono de oro, contadora de billetes y la caja de puros en el escritorio
    caja("O_telefono_base", .45, .7, .8, .86, -.9, -.72, M["oro"], col, choca=False)
    tubo_curva("O_telefono_bocina", [Vector((.42, .9, -.88)), Vector((.57, .95, -.81)), Vector((.72, .9, -.74))], .025, M["oro"], col, lados=6)
    caja("O_contadora", -1.1, -.85, .8, .95, -.35, -.1, M["letrero_blanco"], col, choca=False)
    caja("O_contadora_fajo", -1.05, -.9, .95, .99, -.3, -.15, M["billetes"], col, choca=False)
    caja("O_puros", .15, .4, .8, .86, -.5, -.32, M["lambrin"], col, choca=False)
    for k in range(4):
        cilindro_eje("O_puro_caja%d" % k, .012, .2, "x", M["culata"], col, lados=5).location = _b(.27, .875, -.47 + k * .04)
    # La caja fuerte abierta: puerta girada y fajos adentro
    sx0, sx1, sz0, sz1 = x1 - .7, x1 - .05, -2.4, -1.75
    caja("O_caja_hueco", sx0 - .005, sx0, .1, .7, sz0 + .05, sz1 - .05, M["hueco"], col, choca=False)
    for k in range(6):
        caja("O_fajo_caja%d" % k, sx0 + .01, sx0 + .25, .15 + (k // 3) * .25, .25 + (k // 3) * .25, sz0 + .1 + (k % 3) * .17, sz0 + .24 + (k % 3) * .17, M["billetes"], col, choca=False)
    puerta = caja("O_caja_puerta", 0, .06, .05, .75, 0, .65, M["caja_fuerte"], col, choca=False)
    puerta.matrix_basis = matriz(sx0, 0, sz1, -100)
    # Tele grande en el muro este
    caja("O_tele", x1 - .1, x1 - .02, 1.3, 2.1, -.6, .8, M["careta"], col, choca=False)
    plano("O_tele_pantalla", (x1 - .105, 1.7, .1), 1.3, .7, (-1, 0, 0), material("pantalla_tele", (0.45, 0.65, 0.75), emision=1.5), col)
    # El altar: la Virgen del Tinaco con veladoras y flores en una repisa bajo su marco
    caja("O_altar", -.45, .45, 2.2, 2.25, z0 + .02, z0 + .25, M["lambrin"], col, choca=False)
    for k in range(5):
        cilindro("O_veladora%d" % k, -.35 + k * .17, 2.25, 2.33, z0 + .15, .025, M["foco_lampara"], col, lados=6)
    for k in range(2):
        cilindro("O_florero%d" % k, -.4 + k * .8, 2.25, 2.4, z0 + .12, .04, M["vidrio_sucio"], col, lados=6)
        esfera("O_flores%d" % k, .07, material("flores", (0.95, 0.4, 0.15)), col, lados=6, anillos=4).location = _b(-.4 + k * .8, 2.45, z0 + .12)
    # Whisky en un carrito de servicio junto al escritorio
    caja("O_carrito", -2.2, -1.6, .6, .63, -1.6, -1.1, M["oro"], col, choca=False)
    for k in range(3):
        botella("O_whisky%d" % k, "whisky", -2.1 + k * .2, .63, -1.35, col)
    # La escuadra de oro en su vitrina, sobre la caja fuerte
    caja("O_vitrina", x1 - .12, x1 - .02, 1.25, 1.65, sz0, sz1, M["lambrin_oscuro"], col, choca=False)
    caja("O_vitrina_pistola", x1 - .14, x1 - .12, 1.4, 1.48, sz0 + .15, sz1 - .2, M["oro"], col, choca=False)
    plano("O_vitrina_vidrio", (x1 - .15, 1.45, (sz0 + sz1) / 2), .6, .38, (-1, 0, 0), M["vidrio_sucio"], col)
    marca("Camara", .1, 1.55, 2.35, col)
    marca("Mostrador", 0, 0, -.45, col)
    marca("Vendedor", 0, .0, -1.35, col)
    marca("Vitrina", .05, 1.25, .9, col)
    return col


# ---------------------------------------------------------------- la cantina (se camina)
# Coordenadas de la escena de CasaPropia (scenes/casas/cantina.tscn): la puerta de la calle en la
# pared oeste (x = 0, z = 3.11, CasaPropia.PUERTA) y el cuarto hacia +x; CasaPropia la agranda x1.25.
# La barra al norte, mesas al sur, la rocola y la puerta de atras (a la oficina de Don Lalo) al este.
CANTINA_CUARTO = (0.0, 11.0, 0.0, 7.6)     # x0, x1, z0, z1
CANTINA_ALTO = 3.0
CANTINA_PUERTA = (2.5, 3.72)               # z del hueco de la puerta de la calle (pared oeste)
CANTINA_ATRAS = (5.9, 6.9)                 # z del hueco de la puerta de atras (pared este)
BARRA = (2.6, 8.6, 1.5, 2.1)               # x0, x1, z0, z1


def mats_cantina():
    M = mats_oficina()
    M.update({
        "piso_cantina": mat_tex("piso_cantina", "res://textures/mapa/azulejo_amarillo.png", (0.7, 0.62, 0.5), 1.0),
        "muro_cantina": mat_tex("muro_cantina", "res://textures/mapa/aplanado_rojo.png", (0.75, 0.55, 0.45), 0.5),
        "zoclo_cantina": mat_tex("zoclo_cantina", "res://textures/mapa/azulejo_amarillo.png", (0.35, 0.5, 0.45), 2.0),
        "techo_cantina": mat_tex("techo_cantina", "res://textures/mapa/aplanado_blanco.png", (0.5, 0.48, 0.45), 0.5),
        "pano_billar": material("pano_billar", (0.05, 0.35, 0.18)),
        "rocola": material("rocola", (0.45, 0.08, 0.1)),
        "rocola_luz": material("rocola_luz", (1.0, 0.55, 0.15), emision=3.0),
        "foco_billar": material("foco_billar", (1.0, 0.9, 0.6), emision=4.0),
        "pantalla_futbol": material("pantalla_futbol", (0.2, 0.6, 0.25), emision=2.0),
        "colchon": material("colchon", (0.55, 0.5, 0.65)),
        "cobija": material("cobija", (0.6, 0.15, 0.12)),
        "espejo": material("espejo", (0.55, 0.6, 0.62)),
        "laton": material("laton", (0.8, 0.62, 0.25)),
        "papel_rosa": material("papel_rosa", (0.95, 0.4, 0.7)),
        "papel_verde": material("papel_verde", (0.3, 0.8, 0.35)),
        "papel_amarillo": material("papel_amarillo", (0.98, 0.85, 0.2)),
        "papel_azul": material("papel_azul", (0.25, 0.5, 0.95)),
    })
    return M


def cantina_dentro():
    col = coleccion("PuntoCantina")
    M = mats_cantina()
    x0, x1, z0, z1 = CANTINA_CUARTO
    a = CANTINA_ALTO
    g = .15
    # Cascaron: piso de mosaico, techo, muros de aplanado rojo con zoclo de azulejo y los dos huecos
    caja("C_piso", x0 - g, x1 + g, -g, 0, z0 - g, z1 + g, M["piso_cantina"], col)
    caja("C_techo", x0 - g, x1 + g, a, a + g, z0 - g, z1 + g, M["techo_cantina"], col)
    caja("C_norte", x0, x1, 0, a, z0 - g, z0, M["muro_cantina"], col)
    caja("C_sur", x0, x1, 0, a, z1, z1 + g, M["muro_cantina"], col)
    p0, p1 = CANTINA_PUERTA
    caja("C_oeste_a", x0 - g, x0, 0, a, z0, p0, M["muro_cantina"], col)
    caja("C_oeste_b", x0 - g, x0, 0, a, p1, z1, M["muro_cantina"], col)
    caja("C_oeste_c", x0 - g, x0, 2.3, a, p0, p1, M["muro_cantina"], col, choca=False)
    t0, t1 = CANTINA_ATRAS
    caja("C_este_a", x1, x1 + g, 0, a, z0, t0, M["muro_cantina"], col)
    caja("C_este_b", x1, x1 + g, 0, a, t1, z1, M["muro_cantina"], col)
    caja("C_este_c", x1, x1 + g, 2.2, a, t0, t1, M["muro_cantina"], col, choca=False)
    for nombre, (ax0, ax1, az0, az1) in (("n", (x0, x1, z0, z0 + .02)), ("s", (x0, x1, z1 - .02, z1)),
                                         ("o", (x0, x0 + .02, z0, z1)), ("e", (x1 - .02, x1, z0, z1))):
        caja("C_zoclo_" + nombre, ax0, ax1, 0, 1.1, az0, az1, M["zoclo_cantina"], col, choca=False)
    # Puerta de la calle: hojas de vaiven (de cantina) y la de atras con su letrero PRIVADO
    for s, zz in ((-1, p0 + .3), (1, p1 - .3)):
        caja("C_vaiven%d" % s, x0 + .05, x0 + .1, .5, 1.6, zz - .29, zz + .29, M["lambrin"], col, choca=False)
    caja("C_puerta_atras", x1 - .05, x1, 0, 2.15, t0 + .05, t1 - .05, M["lambrin_oscuro"], col, choca=False)
    caja("C_marco_atras", x1 - .08, x1 - .02, 2.15, 2.25, t0, t1, M["lambrin"], col, choca=False)
    t = letrero("C_privado", "PRIVADO", .14, M["letrero_rojo"], col)
    t.matrix_basis = matriz(x1 - .07, 1.75, (t0 + t1) / 2, -90)
    # La barra: frente de madera con riel de laton, cubierta, y los bancos
    bx0, bx1, bz0, bz1 = BARRA
    caja("C_barra_frente", bx0, bx1, 0, 1.05, bz1 - .1, bz1, M["lambrin"], col)
    caja("C_barra_cuerpo", bx0, bx1, 0, 1.05, bz0, bz1 - .1, M["lambrin_oscuro"], col)
    caja("C_barra_cubierta", bx0 - .05, bx1 + .05, 1.05, 1.11, bz0 - .05, bz1 + .08, M["lambrin"], col, choca=False)
    tubo_curva("C_riel", [Vector((bx0, .22, bz1 + .14)), Vector((bx1, .22, bz1 + .14))], .02, M["laton"], col, lados=6)
    for k in range(7):
        banco("C_banco%d" % k, bx0 + .5 + k * .85, 0, bz1 + .5, BANCO_BARRA, col)
    # Atras de la barra: repisas con botellas, el espejo, la caja registradora y el refri
    caja("C_espejo", 3.2, 7.0, 1.3, 2.4, z0 + .01, z0 + .03, M["espejo"], col, choca=False)
    tipos = list(BOTELLAS)
    for k, yy in enumerate((1.25, 1.75, 2.25)):
        caja("C_repisa%d" % k, 3.0, 7.2, yy, yy + .03, z0, z0 + .3, M["lambrin_oscuro"], col, choca=False)
        for j in range(15):
            botella("C_botella_%d_%d" % (k, j), tipos[(j + k) % len(tipos)], 3.15 + j * .27, yy + .03, z0 + .15, col)
    caja("C_registradora", 4.0, 4.45, 1.11, 1.38, bz0 + .05, bz0 + .4, M["fierro"], col, choca=False)
    caja("C_registradora_pantalla", 4.05, 4.4, 1.38, 1.46, bz0 + .1, bz0 + .2, M["pantalla_futbol"], col, choca=False)
    refri(8.9, 9.9, 0, z0 + .05, col)
    # Caguamas y vasos en la barra, un plato de cacahuates
    for k in range(5):
        botella("C_barra_caguama%d" % k, "caguama", bx0 + .7 + k * 1.2, 1.11, bz1 - .25, col)
    cilindro("C_cacahuates", 5.3, 1.11, 1.15, bz1 - .3, .1, M["tambo_rojo"], col, lados=8)
    # El colchon en la esquina noreste, con su cobija hecha bola
    caja("C_colchon", 9.7, 10.95, 0, .22, 4.0, 5.9, M["colchon"], col)
    girar("C_cobija", [(0, 0), (.35, 0), (.32, .2), (0, .25)], M["cobija"], col, lados=8).location = _b(10.2, .22, 5.2)
    # Mesas de madera con sillas plegables (y donde se sientan los borrachos: Marca_Bebedor_*)
    mesas = [(2.2, 5.6), (4.6, 6.2), (2.4, 4.0)]
    n = 0
    for k, (mx, mz) in enumerate(mesas):
        caja("C_mesa%d" % k, mx - .45, mx + .45, .74, .78, mz - .45, mz + .45, M["lambrin"], col)
        cilindro("C_mesa_pata%d" % k, mx, 0, .74, mz, .06, M["fierro"], col, lados=6)
        for j, (sx, sz) in enumerate(((-.75, 0), (.75, 0), (0, .75))):
            silla_plegable("C_silla%d%d" % (k, j), mx + sx, 0, mz + sz, (mx, mz), col)
            if (k + j) % 2 == 0:
                marca("Bebedor_%d" % n, mx + sx, 0, mz + sz, col, giro_y=math.degrees(math.atan2(-(mx - (mx + sx)), -(mz - (mz + sz)))))
                n += 1
        for j in range(random.randint(2, 4)):
            botella("C_mesa_cerveza%d%d" % (k, j), random.choice(("cerveza", "caguama")), mx + random.uniform(-.3, .3), .78,
                    mz + random.uniform(-.3, .3), col)
    # El billar al centro-este con su lampara, bolas y taco; la rocola contra el muro este
    px, pz = 7.2, 4.6
    caja("C_billar_cuerpo", px - 1.1, px + 1.1, .55, .78, pz - .6, pz + .6, M["lambrin_oscuro"], col)
    caja("C_billar_pano", px - 1.0, px + 1.0, .78, .8, pz - .5, pz + .5, M["pano_billar"], col, choca=False)
    for sx in (-1, 1):
        caja("C_billar_banda%d" % sx, px + sx * 1.05 - .05, px + sx * 1.05 + .05, .78, .86, pz - .6, pz + .6, M["lambrin"], col, choca=False)
        caja("C_billar_banda_z%d" % sx, px - 1.1, px + 1.1, .78, .86, pz + sx * .55 - .05, pz + sx * .55 + .05, M["lambrin"], col, choca=False)
        for sz in (-1, 1):
            caja("C_billar_pata", px + sx * .95 - .07, px + sx * .95 + .07, 0, .55, pz + sz * .45 - .07, pz + sz * .45 + .07, M["lambrin_oscuro"], col, choca=False)
    colores_bola = [M["letrero_amarillo"], M["tambo_azul"], M["letrero_rojo"], M["papel_verde"], M["letrero_blanco"], M["hueco"]]
    for k in range(9):
        b = esfera("C_bola%d" % k, .03, colores_bola[k % len(colores_bola)], col, lados=8, anillos=5)
        b.location = _b(px + random.uniform(-.8, .8), .83, pz + random.uniform(-.35, .35))
    taco = cilindro_eje("C_taco", .012, 1.45, "x", M["lambrin"], col, lados=5)
    taco.matrix_basis = matriz(px - .2, .84, pz + .1, 15)
    caja("C_lampara_billar", px - .7, px + .7, 2.3, 2.42, pz - .18, pz + .18, M["papel_verde"], col, choca=False)
    caja("C_lampara_billar_foco", px - .6, px + .6, 2.28, 2.3, pz - .12, pz + .12, M["foco_billar"], col, choca=False)
    for sx in (-.5, .5):
        cilindro("C_lampara_cadena", px + sx, 2.42, a, pz, .008, M["cadena"], col, lados=4)
    rx, rz = x1 - .35, 2.6
    caja("C_rocola", rx - .3, rx + .3, 0, 1.55, rz - .45, rz + .45, M["rocola"], col)
    arco = cilindro_eje("C_rocola_arco", .45, .6, "x", M["rocola"], col, lados=14)
    arco.location = _b(rx, 1.4, rz)
    arco_luz = cilindro_eje("C_rocola_arco_luz", .38, .02, "x", M["rocola_luz"], col, lados=14)
    arco_luz.location = _b(rx - .31, 1.4, rz)
    caja("C_rocola_ventana", rx - .32, rx - .3, .9, 1.35, rz - .3, rz + .3, M["rocola_luz"], col, choca=False)
    for k in range(4):
        caja("C_rocola_tubo%d" % k, rx - .33, rx - .3, .2, .85, rz - .38 + k * .25, rz - .33 + k * .25, M["rocola_luz"], col, choca=False)
    marca("Rocola", rx - .8, 0, rz, col, giro_y=-90)
    # La tele en la esquina pasando el futbol, el ventilador de techo y la Virgen del Tinaco
    caja("C_tele", .3, .9, 2.1, 2.55, z1 - .7, z1 - .1, M["careta"], col, choca=False)
    plano("C_tele_pantalla", (.91, 2.32, z1 - .4), .5, .36, (1, 0, 0), M["pantalla_futbol"], col)
    caja("C_tele_repisa", 0, .95, 2.05, 2.1, z1 - .75, z1, M["fierro"], col, choca=False)
    for k in range(4):
        aspa = caja("C_aspa%d" % k, 0, .6, -.01, .01, -.07, .07, M["lambrin"], col, choca=False)
        aspa.matrix_basis = matriz(4.5, a - .35, 4.8, k * 90 + 15)
    cilindro("C_ventilador", 4.5, a - .38, a, 4.8, .06, M["laton"], col, lados=8)
    plano("C_virgen", (x0 + .02, 2.0, 1.2), .45, .6, (1, 0, 0), M["estampa_virgen"], col)
    for k in range(3):
        cilindro("C_veladora%d" % k, x0 + .15, 1.45, 1.55, 1.0 + k * .2, .03, M["foco_lampara"], col, lados=6)
    caja("C_repisa_virgen", x0, x0 + .25, 1.4, 1.45, .8, 1.6, M["lambrin"], col, choca=False)
    # Carteles (el atlas del Yonke: la lucha y la cerveza) y una diana
    cartel_y = material("carteles_yonke", (1, 1, 1))
    plano("C_cartel_lucha", (x1 - .02, 1.9, 4.6), 1.1, .55, (-1, 0, 0), cartel_y, col, uv=(.5, .5, 1.0, .75))
    plano("C_cartel_hojalateria", (6.0, 1.8, z1 - .02), 1.0, .5, (0, 0, -1), cartel_y, col, uv=(0, .5, .5, .75))
    cilindro_eje("C_diana", .22, .03, "z", M["letrero_rojo"], col, lados=12).location = _b(8.5, 1.6, z1 - .02)
    # Papel picado cruzando el techo en cuatro hileras
    colores = [M["papel_rosa"], M["papel_verde"], M["papel_amarillo"], M["papel_azul"]]
    for h, zz in enumerate((1.2, 3.0, 4.8, 6.6)):
        for k in range(18):
            xx = .3 + k * .58
            y = a - .25 - .12 * math.sin(k / 17 * math.pi)
            plano("C_papel_%d_%d" % (h, k), (xx, y, zz), .4, .3, (0, 0, 1), colores[(k + h) % 4], col)
    # Neon de cerveza sobre el espejo
    tubo_curva("C_neon", [Vector((4.2 + .4 * math.cos(t), 2.65 + .18 * math.sin(t), z0 + .05)) for t in [k * math.tau / 16 for k in range(16)]],
               .02, M["neon_rojo"], col, lados=4, cerrado=True)
    # Marcas: el de la barra, los parados, la puerta de atras y la rocola (Cantina.gd)
    marca("Colchonero", 5.6, 0, .75, col, giro_y=180)
    marca("Parado_0", 6.6, 0, 3.2, col, giro_y=90)
    marca("Parado_1", 9.2, 0, 4.8, col, giro_y=90)
    marca("Dormido", 10.3, .22, 4.9, col, giro_y=0)
    marca("Puerta_atras", x1 - .7, 0, (t0 + t1) / 2, col, giro_y=-90)
    for k, (zz, que) in enumerate(((bz1 + .05, "caguama"), (bz1 + .05, "cigarros"), (bz1 + .05, "tachas"))):
        marca("Venta_%s" % que, 4.6 + k * .9, 0, bz1 + .9, col)
    return col


def exportar():
    exportar_coleccion("PuntoFuera", os.path.join(SALIDA, "punto_fuera.glb"))
    exportar_coleccion("PuntoDentro", os.path.join(SALIDA, "punto_dentro.glb"))
    exportar_coleccion("PuntoCantina", os.path.join(SALIDA, "cantina.glb"))
    preparar_vista("PuntoFuera", ["PuntoDentro", "PuntoCantina"])
    guardar_fuente(os.path.join(SALIDA, "fuente", "punto.blend"))


if __name__ == "punto":
    if bpy.data.filepath and not bpy.data.filepath.endswith(("punto.blend", "yonke.blend")):
        raise RuntimeError("punto.py borraria " + bpy.data.filepath + ": abre un archivo nuevo primero")
    limpiar()
    exterior()
    oficina()
    cantina_dentro()
    print("punto: %d objetos afuera, %d adentro" % (len(bpy.data.collections["PuntoFuera"].all_objects),
                                                   len(bpy.data.collections["PuntoDentro"].all_objects)))
    if globals().get("EXPORTAR"):
        exportar()
    else:
        preparar_vista("PuntoFuera", ["PuntoDentro", "PuntoCantina"])
