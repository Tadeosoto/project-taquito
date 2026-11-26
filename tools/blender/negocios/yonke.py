# El Yonke de Don Chava en Blender (docs/sistemas/taller.md): el patio de fierro viejo con carros
# deshuesados, llantas, un tejaban de lamina con refacciones y la oficina en un contenedor
# madreado; adentro del contenedor, el mostrador donde La Chava arma lo que pides.
#
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\negocios"
#   exec(open(R + r"\yonke.py", encoding="utf-8").read(), {"__name__": "yonke"})
#
# Sale models/negocios/yonke/yonke_fuera.glb (YonkeMapa.gd lo pone en el mapa y el safehouse) y
# yonke_dentro.glb (scenes/interiores/yonke.tscn). El nodo de YonkeMapa tiene +Z a la calle: la
# flecha va en z = +3 y el patio se mete hacia -Z. Lo que se llama "Barda_*" es la barda de lamina
# propia (en el mapa ya hay barda del baldio: YonkeMapa la quita si con_barda es false).
# Sufijo "-convcol": choca. Los "Marca_*" (vacios) los usa YonkeMapa / Yonke.gd.

import os
R_NEG = os.path.join(os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito"),
                     "tools", "blender", "negocios")
exec(open(os.path.join(R_NEG, "comun.py"), encoding="utf-8").read(), globals())
exec(open(os.path.join(R_NEG, "carros.py"), encoding="utf-8").read(), globals())

SALIDA = os.path.join(RAIZ, "models", "negocios", "yonke")
PATIO = (-14.0, 14.0, -40.0, 0.0)     # x0, x1, z0, z1
PORTON = (-3.0, 3.0)                  # x del porton abierto en la barda del frente
CONTENEDOR = (4.5, 10.56, -5.4, -2.96)  # x0, x1, z0, z1 (un contenedor de 20 pies: 6.06 x 2.44)
CONT_ALTO = 2.59
CONT_BASE = 0.25                      # sobre blocks
PUERTA_CONT = (5.9, 6.8)              # x del hueco de la puerta (cara sur, a la calle)
VENTANA_CONT = (8.1, 9.7, 1.0, 1.8)   # x0, x1, y0, y1 (cara sur, el corte con soplete)
REFACCIONARIA = (-13.6, -6.5, -30.0, -12.0)  # x0, x1, z0, z1: el tejaban de las refacciones
REFA_ALTO = (3.6, 3.0)                # alto contra la barda y al frente (abierto al este)
PRENSA = (-3.2, 3.2, -31.2, -27.8)    # la base de la prensa de carros
CUBOS = (5.0, 7.8, -33.4, -26.6)      # donde se apilan los carros ya aplastados
LLANTERO = (-13.4, -6.8, -39.4, -32.8)  # la montana de llantas
FILAS = (12.2, 10.2)                  # x de las dos filas de carros encimados (al este)
LUGARES = (-9.8, -14.8, -19.8, -24.8, -29.8, -34.8)  # z de cada lugar de la fila (una pickup mide 4.9)
# Lo que ningun carro puede pisar (x0, x1, z0, z1); el porton y la entrada tambien
OCUPADO = {"contenedor": (4.3, 10.8, -5.6, -2.0), "prensa": (-3.4, 4.8, -31.5, -27.5), "cubos": (4.8, 8.0, -33.6, -26.4),
           "refaccionaria": (-13.8, -6.3, -30.2, -11.8), "llantero": (-13.6, -6.6, -39.6, -32.6),
           "entrada": (-3.0, 3.0, -4.0, 0.0)}
# La prensa (YonkeMapa la anima leyendo las piezas Prensa_mov_*): alto del marco, alto de abajo de
# la placa arriba (sobre el techo del carro, 0.3 + 1.38) y alto de abajo de los pistones
PRENSA_ALTO = 4.0
PRENSA_PLACA_Y = 1.95
PRENSA_CILINDRO = 2.75
# Los chalanes (chalanes()): clip de Quaternius y numero, donde se paran y lo que ven
CHALANES = [("Fixing_Kneeling_1", 0.89, -10.0, 0.36, -11.13),     # hincado en el motor del Suelto_1
            ("Interact_1", 4.02, -12.71, 4.5, -10.0),             # metido en el cofre del Suelto_4
            ("Interact_2", 4.1, -28.2, 4.1, -28.9),               # el operador en el tablero de la prensa
            ("Idle_TalkingPhone_1", 7.6, -2.0, 7.6, 2.0),          # al telefono en la puerta de la oficina
            ("Crouch_Idle_1", 2.6, -35.0, 2.2, -36.0),            # escogiendo llantas
            ("PickUp_Kneeling_1", 6.6, -20.3, 7.2, -21.0),        # juntando fierro
            ("Idle_FoldArms_1", -1.0, -26.4, 0.0, -29.5)]         # viendo como aplasta la prensa
# Celdas del atlas de carteles (arte_yonke.py): (columna, fila desde arriba)
CARTELES = {"precios": (0, 0), "refacciones": (1, 0), "robado": (0, 1), "rines": (1, 1), "hojalateria": (0, 2),
            "lucha": (1, 2), "virgen": (0, 3), "perro": (1, 3)}
random.seed(7)


def mats():
    return {
        "tierra": mat_tex("tierra", "res://textures/mapa/tierra.png", (0.8, 0.72, 0.62), 0.35),
        "charco": material("charco", (0.08, 0.08, 0.07)),
        "lamina": mat_tex("lamina", "res://textures/map/lamina.png", (0.85, 0.85, 0.85), 0.5),
        "lamina_oxido": mat_tex("lamina_oxido", "res://textures/map/lamina.png", (0.7, 0.45, 0.3), 0.5),
        "lamina_techo": mat_tex("lamina_techo", "res://textures/map/lamina_techo.png", (0.75, 0.6, 0.5), 0.4),
        "oxido": mat_tex("oxido", "res://textures/sotano/oxido.png", (1, 1, 1), 0.6),
        "contenedor": mat_tex("contenedor", "res://textures/map/lamina.png", (0.78, 0.36, 0.22), 0.6),
        "block": mat_tex("block", "res://textures/mapa/block.png", (0.7, 0.68, 0.64), 0.7),
        "madera": mat_tex("madera", "res://textures/mapa/madera.png", (0.7, 0.55, 0.4), 1.0),
        "llanta": material("llanta", (0.06, 0.06, 0.06)),
        "rin": material("rin", (0.55, 0.56, 0.58)),
        "vidrio_sucio": material("vidrio_sucio", (0.12, 0.16, 0.17)),
        "hueco": material("hueco", (0.04, 0.04, 0.04)),
        "fierro": material("fierro", (0.22, 0.2, 0.19)),
        "letrero_amarillo": material("letrero_amarillo", (0.95, 0.78, 0.1)),
        "letrero_blanco": material("letrero_blanco", (0.92, 0.9, 0.85)),
        "letrero_rojo": material("letrero_rojo", (0.75, 0.1, 0.08)),
        "tambo_azul": material("tambo_azul", (0.12, 0.25, 0.55)),
        "tambo_rojo": material("tambo_rojo", (0.6, 0.12, 0.08)),
        "motor": material("motor", (0.3, 0.3, 0.32)),
        "cadena": material("cadena", (0.35, 0.33, 0.3)),
        "faro": material("faro", (0.8, 0.8, 0.7)),
        "cromo": material("cromo", (0.75, 0.76, 0.78)),
        "asiento": material("asiento", (0.25, 0.18, 0.14)),
        "concreto": mat_tex("concreto", "res://textures/mapa/casa_psm_concreto.png", (0.62, 0.6, 0.56), 0.5),
        "amarillo_maquina": material("amarillo_maquina", (0.9, 0.68, 0.08)),
        "carton": mat_tex("carton", "res://textures/mapa/carton.png", (0.85, 0.75, 0.6), 1.0),
        "bateria": material("bateria", (0.1, 0.1, 0.1)),
        "manguera": material("manguera", (0.15, 0.5, 0.2)),
        "llanta_blanca": material("llanta_blanca", (0.9, 0.9, 0.86)),
        "llanta_amarilla": material("llanta_amarilla", (0.95, 0.75, 0.1)),
        "llanta_roja": material("llanta_roja", (0.8, 0.15, 0.1)),
        "llanta_azul": material("llanta_azul", (0.15, 0.35, 0.75)),
        "llanta_verde": material("llanta_verde", (0.2, 0.6, 0.25)),
        "carteles_yonke": mat_tex("carteles_yonke", "res://textures/negocios/yonke_carteles.png", (1, 1, 1), 0.0),
    }


def llantas(nombre, x, z, n, col, M, ladeo=0.0):
    """Una pila de llantas (con forma: llanta_rica), un poco chuecas."""
    piezas = []
    for i in range(n):
        d = llanta_rica(nombre + "_%d" % i, M, col, lados=10, gastada=random.random())
        d.location = Vector((random.uniform(-.04, .04), random.uniform(-.04, .04), .112 + i * .224))
        d.rotation_euler = (random.uniform(-.05, .05), random.uniform(-.05, .05), random.uniform(0, 3))
        piezas.append(d)
    return juntar(nombre + "-convcol", piezas, col, matriz(x, 0, z, random.uniform(0, 90), giro_x=ladeo))


def tambo(nombre, x, z, mat, col, acostado=False):
    t = cilindro_eje(nombre, .3, .88, "z" if acostado else "y", mat, col, lados=10)
    t.name = nombre + "-convcol"
    t.location = _b(x, .3 if acostado else .44, z)
    t.rotation_euler = (0, 0, random.uniform(0, 3))
    return t


def barda(col, M):
    """Barda de lamina de colores parchada, con porton abierto al frente y postes de tubo."""
    x0, x1, z0, z1 = PATIO
    tramos = []
    # frente (z = 0) en dos tramos, lados y fondo
    def corrido(a, b, eje_z, fijo, normal):
        pos = a
        i = 0
        # Lo que queda debe medir mas que el traslape (0.05): si no, pos no avanza y se cicla
        while pos < b - 0.1:
            ancho = min(random.uniform(0.9, 1.3), b - pos)
            if b - pos - ancho < 0.3:
                ancho = b - pos
            # El frente mas bajo: desde la calle se ven los carros encimados
            alto = random.uniform(1.5, 1.8) if normal == "frente" else random.uniform(2.0, 2.5)
            m = random.choice((M["lamina"], M["lamina_oxido"], M["lamina_oxido"], M["contenedor"]))
            if eje_z:
                o = caja("Barda_%s_%d" % (normal, len(tramos)), fijo - .03, fijo + .03, 0, alto, pos, pos + ancho, m, col)
            else:
                o = caja("Barda_%s_%d" % (normal, len(tramos)), pos, pos + ancho, 0, alto, fijo - .03, fijo + .03, m, col)
            o.rotation_euler.z = random.uniform(-.03, .03)
            tramos.append(o)
            pos += ancho - 0.05
            i += 1
    corrido(x0, PORTON[0], False, z1, "frente")
    corrido(PORTON[1], x1, False, z1, "frente")
    corrido(z0, z1, True, x0, "oeste")
    corrido(z0, z1, True, x1, "este")
    corrido(x0, x1, False, z0, "fondo")
    # Postes del porton y la hoja de malla abierta
    for s, xp in ((-1, PORTON[0]), (1, PORTON[1])):
        p = cilindro("Barda_poste%d" % s, xp, 0, 2.9, z1, .07, M["fierro"], col)
    hoja = caja("Barda_hoja", 0, 2.4, 0.1, 2.2, -.02, .02, M["fierro"], col)
    hoja.location = _b(PORTON[1] - .05, 1.15, z1 - 1.2)
    hoja.rotation_euler.z = math.radians(80)
    # Tapones (rines de adorno) colgados en la barda del frente, por fuera
    for i in range(9):
        xx = random.uniform(x0 + .5, PORTON[0] - .5) if i % 2 else random.uniform(PORTON[1] + .5, x1 - .5)
        t = cilindro_eje("Barda_tapon%d" % i, .19, .03, "z", M["rin"], col, lados=10)
        t.location = _b(xx, random.uniform(0.9, 1.3), z1 + .05)


def letrero_yonke(col, M):
    """El letrero pintado a mano sobre una hoja de lamina, arriba del porton."""
    tabla = caja("Letrero_tabla", -3.3, 3.3, 2.75, 3.95, -.05, .05, M["lamina_oxido"], col, choca=False)
    for s in (-1, 1):
        cilindro("Letrero_pata%d" % s, s * 3.0, 2.4, 3.95, -.1, .05, M["fierro"], col)
    t = letrero("Letrero_texto", "EL YONKE", .62, M["letrero_amarillo"], col)
    t.location = _b(0, 3.25, .07)
    t2 = letrero("Letrero_don", "DON CHAVA", .26, M["letrero_blanco"], col)
    t2.location = _b(0, 2.92, .07)


def contenedor(col, M):
    """La oficina: un contenedor de 20 pies madreado sobre blocks, con puerta cortada, ventana
    con barrotes, minisplit viejo y un toldo de lona."""
    x0, x1, z0, z1 = CONTENEDOR
    y0, y1 = CONT_BASE, CONT_BASE + CONT_ALTO
    m = M["contenedor"]
    g = .05
    # Piso, techo y muros (la cara sur con el hueco de la puerta y la ventana)
    caja("Cont_piso", x0, x1, y0 - g, y0, z0, z1, M["fierro"], col)
    caja("Cont_techo", x0, x1, y1, y1 + g, z0, z1, m, col)
    caja("Cont_norte", x0, x1, y0, y1, z0, z0 + g, m, col)
    caja("Cont_oeste", x0, x0 + g, y0, y1, z0, z1, m, col)
    caja("Cont_este", x1 - g, x1, y0, y1, z0, z1, m, col)
    px0, px1 = PUERTA_CONT
    vx0, vx1, vy0, vy1 = VENTANA_CONT
    caja("Cont_sur_a", x0, px0, y0, y1, z1 - g, z1, m, col)
    caja("Cont_sur_b", px1, vx0, y0, y1, z1 - g, z1, m, col)
    caja("Cont_sur_c", vx1, x1, y0, y1, z1 - g, z1, m, col)
    caja("Cont_sur_d", px0, px1, y0 + 2.05, y1, z1 - g, z1, m, col, choca=False)
    caja("Cont_sur_e", vx0, vx1, y0, y0 + vy0, z1 - g, z1, m, col, choca=False)
    caja("Cont_sur_f", vx0, vx1, y0 + vy1, y1, z1 - g, z1, m, col, choca=False)
    # Costillas (el corrugado del contenedor) en las caras largas
    costillas = []
    xx = x0 + .15
    i = 0
    while xx < x1 - .1:
        for zc, nom in ((z0 - .03, "n"), (z1 + .03, "s")):
            if nom == "s" and (px0 - .05 < xx < px1 + .05 or vx0 - .05 < xx < vx1 + .05):
                continue
            costillas.append(caja("Cont_cost_%s%d" % (nom, i), xx - .04, xx + .04, y0 + .08, y1 - .08, zc - .02, zc + .02, m, col, choca=False))
        xx += .28
        i += 1
    juntar("Cont_costillas", costillas, col)
    # Marcos de esquina, oxido y abolladuras (manchas)
    for xc in (x0, x1):
        for zc in (z0, z1):
            caja("Cont_esq", xc - .08, xc + .08, y0, y1 + .02, zc - .08, zc + .08, M["oxido"], col, choca=False)
    for k in range(7):
        plano("Cont_ox%d" % k, (random.uniform(x0 + .3, x1 - .3), random.uniform(y0 + .2, y0 + 1.0), z1 + .06),
              random.uniform(.4, 1.2), random.uniform(.2, .6), (0, 0, 1), M["oxido"], col)
    # Barrotes en la ventana y una lamina de puerta abierta
    barrotes = [caja("Cont_barrote%d" % k, vx0 + .1 + k * .2, vx0 + .13 + k * .2, y0 + vy0, y0 + vy1, z1 - .02, z1 + .01, M["fierro"], col, choca=False)
                for k in range(int((vx1 - vx0) / .2))]
    juntar("Cont_barrotes", barrotes, col)
    puerta = caja("Cont_puerta", 0, px1 - px0, y0, y0 + 2.05, -.02, .02, M["lamina_oxido"], col)
    puerta.location = _b(px0, y0 + 1.025, z1 + .02)
    puerta.data.transform(Matrix.Translation(Vector(((px1 - px0) / 2, 0, 0))))
    puerta.rotation_euler.z = math.radians(-70)
    # Blocks debajo
    for xb in (x0 + .3, (x0 + x1) / 2, x1 - .3):
        for zb in (z0 + .3, z1 - .3):
            caja("Cont_blk", xb - .2, xb + .2, 0, CONT_BASE, zb - .1, zb + .1, M["block"], col, choca=False)
    # Escalon de tarimas frente a la puerta
    caja("Cont_tarima", px0 - .3, px1 + .3, 0, .14, z1, z1 + .9, M["madera"], col)
    # Minisplit viejo en la cara este y su chorrete
    caja("Cont_aire", x1, x1 + .35, 1.4, 2.0, z0 + .5, z0 + 1.3, M["letrero_blanco"], col)
    plano("Cont_rejilla", (x1 + .355, 1.7, z0 + .9), .7, .5, (1, 0, 0), M["hueco"], col)
    # Toldo de lona sobre la puerta (con dos palos)
    toldo = caja("Cont_toldo", px0 - .6, px1 + .9, -.02, .02, 0, 1.6, M["lamina_techo"], col, choca=False)
    toldo.location = _b((px0 + px1) / 2 + .15, y1 - .1, z1 + .8)
    toldo.rotation_euler.x = math.radians(-12)
    for xp in (px0 - .5, px1 + .8):
        cilindro("Cont_palo", xp, 0, y1 - .25, z1 + 1.5, .03, M["madera"], col)
    # Letrero de OFICINA y uno de NO HAY FIADO pintados sobre el contenedor
    t = letrero("Cont_oficina", "OFICINA", .3, M["letrero_blanco"], col)
    t.location = _b((px0 + px1) / 2, y0 + 2.15, z1 + .04)
    t = letrero("Cont_fiado", "NO HAY FIADO", .22, M["letrero_rojo"], col)
    t.location = _b((vx0 + vx1) / 2, y0 + vy1 + .15, z1 + .04)


def cartel(nombre, que, centro, ancho, normal, col, M):
    """Un cartel del atlas (CARTELES) de `ancho` m (2:1) viendo hacia `normal`."""
    c, f = CARTELES[que]
    u0, v1 = c * .5, 1.0 - f * .25
    return plano(nombre, centro, ancho, ancho / 2, normal, M["carteles_yonke"], col, uv=(u0, v1 - .25, u0 + .5, v1))


# ---------------------------------------------------------------- refacciones con detalle

def _pieza(nombre, piezas, col, x, y, z, giro=0.0, giro_x=0.0, giro_z=0.0):
    return juntar(nombre, piezas, col, matriz(x, y, z, giro, giro_x=giro_x, giro_z=giro_z))


def radiador(nombre, col, M, x, y, z, giro=0.0):
    """Radiador parado: tanques arriba y abajo, panal de aletas, tapon y las dos bocas."""
    p = [caja(nombre + "_tanque_a", -.04, .04, .42, .5, -.32, .32, M["hueco"], col, choca=False),
         caja(nombre + "_tanque_b", -.04, .04, 0, .08, -.32, .32, M["hueco"], col, choca=False)]
    for k in range(9):
        zz = -.28 + k * .07
        p.append(caja(nombre + "_aleta", -.03, .03, .08, .42, zz - .012, zz + .012, M["rin"], col, choca=False))
    for yy in (.18, .32):
        p.append(caja(nombre + "_tubo", -.035, .035, yy - .01, yy + .01, -.3, .3, M["fierro"], col, choca=False))
    for yy, zz in ((.46, .25), (.04, -.25)):
        b = cilindro_eje(nombre + "_boca", .03, .12, "x", M["fierro"], col, lados=6)
        b.location = _b(.06, yy, zz)
        p.append(b)
    p.append(cilindro(nombre + "_tapon", 0, .5, .54, -.1, .03, M["cromo"], col, lados=6))
    return _pieza(nombre, p, col, x, y, z, giro)


def faro_pieza(nombre, col, M, x, y, z, giro=0.0):
    """Faro suelto: carcasa, mica y aro cromado."""
    p = [caja(nombre + "_carcasa", -.08, .02, 0, .16, -.14, .14, M["hueco"], col, choca=False),
         caja(nombre + "_mica", .02, .035, .02, .14, -.12, .12, M["faro"], col, choca=False),
         caja(nombre + "_aro_a", .02, .04, .14, .16, -.14, .14, M["cromo"], col, choca=False),
         caja(nombre + "_aro_b", .02, .04, 0, .02, -.14, .14, M["cromo"], col, choca=False)]
    return _pieza(nombre, p, col, x, y, z, giro)


def alternador(nombre, col, M, x, y, z):
    """Alternador: cuerpo con aros de enfriamiento, polea y la oreja de montar."""
    p = [cilindro_eje(nombre + "_cuerpo", .09, .16, "x", M["rin"], col, lados=10)]
    for k in range(3):
        a = cilindro_eje(nombre + "_aro%d" % k, .095, .015, "x", M["fierro"], col, lados=10)
        a.location = _b(-.06 + k * .06, 0, 0)
        p.append(a)
    pol = cilindro_eje(nombre + "_polea", .05, .04, "x", M["hueco"], col, lados=8)
    pol.location = _b(.11, 0, 0)
    p.append(pol)
    p.append(caja(nombre + "_oreja", -.03, .03, .08, .14, -.03, .03, M["fierro"], col, choca=False))
    return _pieza(nombre, p, col, x, y + .09, z, random.uniform(0, 360))


def caja_refa(nombre, col, M, x0, x1, y0, y1, z0, z1):
    """Caja de carton con su etiqueta blanca y cinta."""
    p = [caja(nombre, x0, x1, y0, y1, z0, z1, M["carton"], col, choca=False),
         caja(nombre + "_cinta", x0 - .002, x1 + .002, y1 - .01, y1 + .002, (z0 + z1) / 2 - .03, (z0 + z1) / 2 + .03, M["fierro"], col, choca=False)]
    p.append(plano(nombre + "_etiqueta", (x1 + .003, (y0 + y1) / 2, (z0 + z1) / 2), (z1 - z0) * .5, (y1 - y0) * .35, (1, 0, 0), M["letrero_blanco"], col))
    return juntar(nombre, p, col)


def motor(nombre, col, M, x, z, giro):
    """Motor V8 en su base de taller: bloque, tapas de punterias, multiple, filtro de aire, poleas
    con banda, multiples de escape oxidados, carter y la base de tubo con rueditas."""
    tapa = random.choice((M["letrero_rojo"], M["cromo"], M["tambo_azul"]))
    p = [caja(nombre + "_bloque", -.38, .38, .55, 1.0, -.22, .22, M["motor"], col, choca=False),
         caja(nombre + "_carter", -.34, .34, .42, .55, -.18, .18, M["fierro"], col, choca=False),
         caja(nombre + "_multiple", -.3, .3, 1.0, 1.12, -.1, .1, M["motor"], col, choca=False)]
    for s in (-1, 1):
        t = caja(nombre + "_tapa%d" % s, -.36, .36, -.04, .04, -.08, .08, tapa, col, choca=False)
        t.location = _b(0, 1.04, s * .19)
        t.rotation_euler.x = math.radians(35 * s)
        p.append(t)
        e = caja(nombre + "_escape%d" % s, -.32, .32, .7, .8, s * .23, s * .28, M["oxido"], col, choca=False)
        p.append(e)
    filtro = cilindro(nombre + "_filtro", 0, 1.12, 1.22, 0, .17, M["cromo"], col, lados=10)
    p.append(filtro)
    for k, (yy, r) in enumerate(((.62, .1), (.85, .07), (.95, .06))):
        pol = cilindro_eje(nombre + "_polea%d" % k, r, .04, "x", M["hueco"], col, lados=8)
        pol.location = _b(.41, yy, (k - 1) * .09)
        p.append(pol)
    p.append(tubo_curva(nombre + "_banda", [Vector((.43, .52, 0)), Vector((.43, .92, -.15)), Vector((.43, 1.0, .1)), Vector((.43, .72, .12))],
                        .012, M["hueco"], col, lados=4, cerrado=True))
    # La base: poste, travesano y patas con ruedas
    p += [caja(nombre + "_poste", -.05, .05, 0, .55, -.05, .05, M["letrero_rojo"], col, choca=False),
          caja(nombre + "_pata_a", -.5, .5, 0, .05, -.03, .03, M["letrero_rojo"], col, choca=False),
          caja(nombre + "_pata_b", -.03, .03, 0, .05, -.4, .4, M["letrero_rojo"], col, choca=False)]
    for xr, zr in ((-.5, 0), (.5, 0), (0, -.4), (0, .4)):
        r = cilindro_eje(nombre + "_rueda", .04, .03, "z", M["hueco"], col, lados=6)
        r.location = _b(xr, .04, zr)
        p.append(r)
    return _pieza(nombre + "-convcol", p, col, x, 0, z, giro)


def transmision(nombre, col, M, x, y, z, giro):
    """Transmision acostada: campana, cuerpo, cola y su charola."""
    p = [girar(nombre + "_campana", [(0, 0), (.24, 0), (.26, .06), (.2, .3), (0, .3)], M["rin"], col, lados=10),
         girar(nombre + "_cuerpo", [(0, .3), (.15, .3), (.14, .75), (0, .75)], M["rin"], col, lados=8),
         girar(nombre + "_cola", [(0, .75), (.06, .75), (.05, 1.05), (0, 1.05)], M["fierro"], col, lados=6)]
    return juntar(nombre, p, col, matriz(x, y, z, giro, giro_z=90))


def puerta_auto(nombre, color, col, M, x, z, giro, recarga=8.0):
    """Puerta de carro parada: lamina, marco y vidrio, manija y espejo."""
    pintura = _mat_carro(color, M)
    p = [caja(nombre + "_lamina", -.04, .04, 0, .62, -.55, .55, pintura, col, choca=False),
         caja(nombre + "_marco_a", -.03, .03, .62, 1.05, .48, .55, pintura, col, choca=False),
         caja(nombre + "_marco_b", -.03, .03, .98, 1.05, -.3, .55, pintura, col, choca=False),
         caja(nombre + "_marco_c", -.03, .03, .62, 1.0, -.38, -.3, pintura, col, choca=False),
         caja(nombre + "_manija", .04, .06, .5, .53, .2, .35, M["cromo"], col, choca=False),
         caja(nombre + "_espejo", .04, .14, .66, .76, -.42, -.3, M["fierro"], col, choca=False)]
    if random.random() < .7:
        p.append(plano(nombre + "_vidrio", (.0, .82, .1), .8, .34, (1, 0, 0), M["vidrio_sucio"], col))
    ob = juntar(nombre, p, col)
    ob.matrix_basis = matriz(x, .02, z, giro) @ Matrix.Rotation(math.radians(-recarga), 4, "Y")
    return ob


def asiento_auto(nombre, col, M, x, z, giro):
    """Asiento de carro: cojin con costura, respaldo en dos piezas y cabecera."""
    m = M["asiento"]
    p = [caja(nombre + "_riel", -.22, .22, 0, .06, -.24, .24, M["fierro"], col, choca=False),
         caja(nombre + "_cojin", -.25, .25, .06, .2, -.26, .26, m, col, choca=False),
         caja(nombre + "_costura", -.255, .255, .14, .15, -.265, .265, M["hueco"], col, choca=False),
         caja(nombre + "_respaldo", -.25, .25, .2, .62, -.32, -.2, m, col, choca=False),
         caja(nombre + "_lumbar", -.22, .22, .25, .45, -.2, -.16, m, col, choca=False),
         caja(nombre + "_cabecera", -.15, .15, .66, .84, -.3, -.22, m, col, choca=False),
         caja(nombre + "_poste_a", -.08, -.06, .6, .68, -.27, -.25, M["cromo"], col, choca=False),
         caja(nombre + "_poste_b", .06, .08, .6, .68, -.27, -.25, M["cromo"], col, choca=False)]
    return _pieza(nombre, p, col, x, 0, z, giro)


def disco_freno(nombre, col, M, x, y, z, n=4):
    """Una pila de discos de freno (disco con su copa)."""
    p = []
    for k in range(n):
        d = cilindro(nombre + "_disco%d" % k, 0, k * .07, k * .07 + .025, 0, .15, M["oxido"], col, lados=10)
        c = cilindro(nombre + "_copa%d" % k, 0, k * .07 + .025, k * .07 + .06, 0, .07, M["rin"], col, lados=8)
        p += [d, c]
    return _pieza(nombre, p, col, x, y, z)


def resorte(nombre, col, M, x, y, z, color):
    """Resorte de suspension (helice)."""
    pts = [Vector((.07 * math.cos(t * .5), .02 + t * .012, .07 * math.sin(t * .5))) for t in range(0, 30)]
    return _pieza(nombre, [tubo_curva(nombre + "_h", pts, .012, color, col, lados=4)], col, x, y, z)


def volante(nombre, col, M):
    """Volante con aro y tres rayos (de canto, viendo a +x)."""
    aro = tubo_curva(nombre + "_aro", [Vector((0, .19 * math.sin(k * math.tau / 12), .19 * math.cos(k * math.tau / 12))) for k in range(12)],
                     .018, M["hueco"], col, lados=4, cerrado=True)
    p = [aro, cilindro_eje(nombre + "_centro", .05, .04, "x", M["fierro"], col, lados=6)]
    for k in range(3):
        a = math.radians(90 + k * 120)
        r = caja(nombre + "_rayo%d" % k, -.01, .01, -.012, .012, 0, .17, M["fierro"], col, choca=False)
        r.rotation_euler.x = a
        p.append(r)
    return juntar(nombre, p, col)


def refaccionaria(col, M):
    """El tejaban de las refacciones contra la barda oeste, abierto al patio: anaqueles de fierro
    llenos (radiadores, faros, alternadores, cajas con etiqueta, discos, resortes), un tablero con
    volantes y espejos, defensas colgadas, motores V8 en sus bases, transmisiones, puertas, cofres,
    un rack de rines, asientos, baterias, mofles y el banco de trabajo con su prensa."""
    x0, x1, z0, z1 = REFACCIONARIA
    ha, hf = REFA_ALTO
    for k, zp in enumerate([z0 + i * (z1 - z0) / 4 for i in range(5)]):
        cilindro("Refa_poste%d-convcol" % k, x1, 0, hf, zp, .07, M["fierro"], col)
        cilindro("Refa_poste_atras%d" % k, x0 + .1, 0, ha, zp, .06, M["fierro"], col)
    techo = prisma("Refa_techo", [(x0 - .3, ha + .05), (x1 + .6, hf - .08), (x1 + .6, hf), (x0 - .3, ha + .13)],
                   z1 - z0 + .8, M["lamina_techo"], col)
    techo.location = _b(0, 0, (z0 + z1) / 2)
    # Largueros de fierro bajo la lamina
    for k in range(6):
        zz = z0 + k * (z1 - z0) / 5
        caja("Refa_larguero%d" % k, x0, x1, hf - .12 + (ha - hf) * 0, hf, zz - .03, zz + .03, M["fierro"], col, choca=False).rotation_euler.y = math.atan2(ha - hf, x1 - x0)
    caja("Refa_viga", x1 - .06, x1 + .06, hf - .2, hf, z0, z1, M["fierro"], col, choca=False)
    t = letrero("Refa_letrero", "REFACCIONES", .45, M["letrero_amarillo"], col)
    t.matrix_basis = matriz(x1 + .08, hf - .55, (z0 + z1) / 2, 90)
    cartel("Refa_cartel_virgen", "virgen", (x1 + .09, 1.7, z1 - 1.0), 1.0, (1, 0, 0), col, M)
    # Anaqueles: tres secciones contra la barda, cuatro repisas cada una
    resortes = (M["letrero_rojo"], M["hueco"], M["amarillo_maquina"])
    for s, (za, zb) in enumerate(((z0 + .3, z0 + 4.6), (z0 + 5.0, z0 + 9.3), (z0 + 9.7, z0 + 14.0))):
        for zp in (za, zb, (za + zb) / 2):
            for xp in (x0 + .15, x0 + .85):
                caja("Refa_pata", xp - .03, xp + .03, 0, 2.5, zp - .03, zp + .03, M["fierro"], col, choca=False)
        caja("Refa_anaquel%d" % s, x0 + .1, x0 + .9, 0, 2.5, za, zb, M["fierro"], col, choca=False).name = "Refa_anaquel%d-colonly" % s
        for yy in (.3, .9, 1.5, 2.1):
            caja("Refa_repisa", x0 + .12, x0 + .88, yy, yy + .03, za, zb, M["fierro"], col, choca=False)
            caja("Refa_orilla", x0 + .86, x0 + .9, yy - .06, yy + .03, za, zb, M["amarillo_maquina"], col, choca=False)
            zz = za + .1
            while zz < zb - .4:
                que = random.random()
                if que < .18:
                    radiador("Refa_radiador", col, M, x0 + .5, yy + .03, zz + .32, 0)
                    zz += .72
                elif que < .36:
                    for k in range(3):
                        faro_pieza("Refa_faro", col, M, x0 + .72, yy + .03, zz + .14 + k * .3, 0)
                    zz += .92
                elif que < .52:
                    for k in range(2):
                        alternador("Refa_alternador", col, M, x0 + .5, yy + .03, zz + .12 + k * .25)
                    zz += .55
                elif que < .64:
                    disco_freno("Refa_discos", col, M, x0 + .5, yy + .03, zz + .17, n=random.randint(2, 5))
                    zz += .38
                elif que < .74:
                    for k in range(2):
                        resorte("Refa_resorte", col, M, x0 + .5, yy + .03, zz + .1 + k * .17, random.choice(resortes))
                    zz += .4
                else:
                    w = random.uniform(.3, .5)
                    caja_refa("Refa_caja", col, M, x0 + .2, x0 + .82, yy + .03, yy + random.uniform(.2, .45), zz, zz + w)
                    zz += w + .05
    # Tablero en la barda arriba de los anaqueles del fondo: volantes y espejos colgados
    caja("Refa_tablero", x0 + .02, x0 + .06, 2.6, 3.3, z0 + 9.7, z0 + 14.0, M["madera"], col, choca=False)
    for k in range(5):
        v = volante("Refa_volante%d" % k, col, M)
        v.location = _b(x0 + .1, 2.95, z0 + 10.1 + k * .8)
    for k in range(4):
        caja("Refa_espejo%d" % k, x0 + .06, x0 + .14, 2.7, 2.8, z0 + 10.4 + k * .9, z0 + 10.6 + k * .9, M["vidrio_sucio"], col, choca=False)
    # Defensas cromadas colgadas por fuera del anaquel, en la barda
    for k in range(3):
        caja("Refa_defensa%d" % k, x0 + .06, x0 + .16, 2.7 + k * .0, 2.85, z0 + .4 + k * 1.5, z0 + 1.8 + k * 1.5, M["cromo"], col, choca=False)
    # Motores V8 en sus bases
    for k, zm in enumerate((z0 + 2.5, z0 + 6.0, z0 + 9.5)):
        motor("Refa_motor%d" % k, col, M, x0 + 2.6, zm, random.uniform(-20, 20))
    # Transmisiones en una tarima
    caja("Refa_tarima_trans", x0 + 3.6, x0 + 4.8, 0, .14, z0 + 11.5, z0 + 12.7, M["madera"], col)
    for k in range(2):
        transmision("Refa_transmision%d" % k, col, M, x0 + 3.9 + k * .6, .4, z0 + 12.1, 0)
    # Puertas de colores paradas en fila y cofres en una tarima
    for k in range(6):
        puerta_auto("Refa_puerta%d" % k, COLORES_CARRO[(k * 3) % len(COLORES_CARRO)], col, M, x1 - 1.2 - k * .12, z1 - 2.2, 0)
    caja("Refa_tarima_cofres", x1 - 2.6, x1 - 1.0, 0, .14, z0 + 15.0, z0 + 16.2, M["madera"], col)
    for k in range(5):
        color = COLORES_CARRO[(k * 2 + 1) % len(COLORES_CARRO)]
        yy = .14 + k * .05
        caja("Refa_cofre%d" % k, x1 - 2.55, x1 - 1.05, yy, yy + .04, z0 + 15.05, z0 + 16.15, _mat_carro(color, M), col, choca=False)
        caja("Refa_cofre_costilla%d" % k, x1 - 2.5, x1 - 1.1, yy + .04, yy + .05, z0 + 15.55, z0 + 15.65, _mat_carro(color, M), col, choca=False)
    # Rack de rines: un tubo con rines colgados (llanta_rica sin llanta: solo el rin con birlos)
    rx, rz = x1 - .6, z0 + 13.6
    caja("Refa_rack", rx - .03, rx + .03, 1.7, 1.75, rz - 1.4, rz + 1.4, M["fierro"], col, choca=False)
    for k in range(7):
        r = cilindro_eje("Refa_rin%d" % k, .21, .14, "x", M["rin"], col, lados=12)
        r.location = _b(rx, 1.5, rz - 1.2 + k * .4)
        m = cilindro_eje("Refa_rin_centro%d" % k, .07, .16, "x", M["hueco"], col, lados=6)
        m.location = _b(rx, 1.5, rz - 1.2 + k * .4)
    for zp in (rz - 1.4, rz + 1.4):
        cilindro("Refa_rack_pata", rx, 0, 1.75, zp, .03, M["fierro"], col, lados=6)
    # Asientos de carro en fila, baterias en tarima, mofles y un mazo de escapes
    for k in range(3):
        asiento_auto("Refa_asiento%d" % k, col, M, x1 - .9, z0 + 1.0 + k * .7, 100)
    caja("Refa_tarima_bat", x0 + 3.2, x0 + 4.4, 0, .14, z0 + .4, z0 + 1.6, M["madera"], col)
    for k in range(6):
        bx, bz = x0 + 3.3 + (k % 3) * .38, z0 + .55 + (k // 3) * .5
        caja("Refa_bateria", bx, bx + .32, .14, .38, bz, bz + .2, M["bateria"], col, choca=False)
        caja("Refa_bateria_tapa", bx, bx + .32, .38, .4, bz, bz + .2, random.choice((M["letrero_rojo"], M["tambo_azul"], M["amarillo_maquina"])), col, choca=False)
        for s in (.06, .26):
            cilindro("Refa_borne", bx + s, .4, .44, bz + .1, .015, M["cromo"], col, lados=4)
    for k in range(5):
        e = cilindro_eje("Refa_escape%d" % k, .04, 2.2, "z", M["oxido"], col, lados=6)
        e.location = _b(x0 + 1.4 + (k % 3) * .09, .1 + (k // 3) * .08, z0 + 16.5)
    for k in range(3):
        mf = cilindro_eje("Refa_mofle%d" % k, .13, .6, "z", M["oxido"], col, lados=8)
        mf.location = _b(x0 + 2.0 + k * .32, .13, z0 + 16.5)
        mf.scale = (1.0, 1.0, .7)
    # Banco de trabajo con su prensa y herramienta
    bx0, bz0 = x0 + 1.6, z0 + 14.4
    caja("Refa_banco", bx0, bx0 + .7, .85, .92, bz0, bz0 + 1.6, M["madera"], col)
    for xp in (bx0 + .05, bx0 + .65):
        for zp in (bz0 + .05, bz0 + 1.55):
            caja("Refa_banco_pata", xp - .03, xp + .03, 0, .85, zp - .03, zp + .03, M["fierro"], col, choca=False)
    caja("Refa_prensa_banco", bx0 + .5, bx0 + .7, .92, 1.06, bz0 + .2, bz0 + .4, M["tambo_azul"], col, choca=False)
    caja("Refa_llave_banco", bx0 + .1, bx0 + .4, .92, .935, bz0 + .9, bz0 + .94, M["cromo"], col, choca=False)
    caja("Refa_martillo_banco", bx0 + .15, bx0 + .45, .92, .95, bz0 + 1.2, bz0 + 1.24, M["madera"], col, choca=False)


def prensa(col, M):
    """La prensa de carros que trabaja: base de concreto y marco amarillo fijos; la placa, los
    vastagos y el carro de abajo son piezas aparte ("Prensa_mov_*") que YonkeMapa mueve en ciclo
    (baja, aplasta, sube). La caseta del operador con su tablero de botones al sur."""
    x0, x1, z0, z1 = PRENSA
    zc = (z0 + z1) / 2
    caja("Prensa_base", x0, x1, 0, .3, z0, z1, M["concreto"], col, choca=False)
    alto = PRENSA_ALTO
    for xc in (x0 + .2, x1 - .2):
        for zp in (z0 + .2, z1 - .2):
            caja("Prensa_columna", xc - .16, xc + .16, .3, alto, zp - .16, zp + .16, M["amarillo_maquina"], col, choca=False)
            for k in range(4):     # remaches / refuerzos
                yy = .6 + k * (alto - 1.0) / 3
                caja("Prensa_refuerzo", xc - .18, xc + .18, yy, yy + .05, zp - .18, zp + .18, M["fierro"], col, choca=False)
    caja("Prensa_viga_a", x0, x1, alto - .35, alto, z0, z0 + .35, M["amarillo_maquina"], col, choca=False)
    caja("Prensa_viga_b", x0, x1, alto - .35, alto, z1 - .35, z1, M["amarillo_maquina"], col, choca=False)
    caja("Prensa_travesano", -2.0, 2.0, alto - .3, alto, zc - .35, zc + .35, M["amarillo_maquina"], col, choca=False)
    for x in (x0 + .2, x1 - .2):
        caja("Prensa_travesano_l", x - .16, x + .16, alto - .3, alto, z0, z1, M["amarillo_maquina"], col, choca=False)
    # Rayas de peligro en las vigas
    for k in range(10):
        xx = x0 + .3 + k * (x1 - x0 - .6) / 9
        caja("Prensa_raya", xx - .08, xx + .08, alto - .33, alto - .02, z1 + .001, z1 + .01, M["hueco"], col, choca=False)
    caja("Prensa_pared_n", x0 + .4, x1 - .4, .3, 1.0, z0 + .2, z0 + .3, M["fierro"], col, choca=False)
    caja("Prensa_pared_s", x0 + .4, x1 - .4, .3, .6, z1 - .3, z1 - .2, M["fierro"], col, choca=False)
    # Los pistones (fijos) y lo que se mueve: la placa con sus costillas, los vastagos (con el origen
    # arriba, para estirarlos) y el carro de abajo (con el origen en su piso, para aplastarlo)
    placa = []
    placa_y = PRENSA_PLACA_Y
    placa.append(caja("Prensa_placa", x0 + .35, x1 - .35, placa_y, placa_y + .25, z0 + .35, z1 - .35, M["amarillo_maquina"], col, choca=False))
    for k in range(6):
        xx = x0 + .7 + k * (x1 - x0 - 1.4) / 5
        placa.append(caja("Prensa_costilla", xx - .05, xx + .05, placa_y + .25, placa_y + .45, z0 + .4, z1 - .4, M["amarillo_maquina"], col, choca=False))
    placa.append(caja("Prensa_dientes", x0 + .4, x1 - .4, placa_y - .04, placa_y, z0 + .4, z1 - .4, M["fierro"], col, choca=False))
    juntar("Prensa_mov_placa", placa, col)
    tope = placa_y + .45
    for s in (-1, 1):
        cilindro("Prensa_cilindro%d" % s, s * 1.6, PRENSA_CILINDRO, alto - .3, zc, .2, M["hueco"], col, lados=10)
        cilindro("Prensa_tapa_cil%d" % s, s * 1.6, PRENSA_CILINDRO - .05, PRENSA_CILINDRO, zc, .23, M["cromo"], col, lados=10)
        largo = PRENSA_CILINDRO - tope
        v = cilindro_eje("Prensa_mov_vastago%d" % (0 if s < 0 else 1), .08, largo, "y", M["cromo"], col, lados=8)
        v.data.transform(Matrix.Translation(Vector((0, 0, -largo / 2))))
        v.location = _b(s * 1.6, PRENSA_CILINDRO, zc)
    ob, _ = carro("Prensa_mov_carro", 0, .3, zc, 0, COLORES_CARRO[1], col, M, sin_llantas=False, vidrios_rotos=.9,
                  abollado=1.5, semilla=77)
    ob.name = "Prensa_mov_carro"
    for k in range(14):
        plano("Prensa_vidrio%d" % k, (random.uniform(x0, x1), .305, random.uniform(z1, z1 + 1.4)), .08, .08, (0, 1, 0), M["vidrio_sucio"], col)
    # Caseta del operador: ventana al oeste y el tablero de botones al sur (alli se para el operador)
    bx0, bx1, bz0, bz1 = x1 + .3, x1 + 1.5, zc - .6, zc + .6
    caja("Prensa_caseta", bx0, bx1, 0, 2.1, bz0, bz1, M["amarillo_maquina"], col)
    caja("Prensa_caseta_techo", bx0 - .1, bx1 + .1, 2.1, 2.18, bz0 - .1, bz1 + .1, M["fierro"], col, choca=False)
    plano("Prensa_caseta_vidrio", (bx0 - .005, 1.5, zc), 1.0, .6, (-1, 0, 0), M["vidrio_sucio"], col)
    caja("Prensa_tablero", bx0 + .2, bx1 - .2, .9, 1.25, bz1, bz1 + .22, M["fierro"], col, choca=False)
    for k, c in enumerate((M["letrero_rojo"], M["letrero_amarillo"], M["tambo_azul"], M["manguera"])):
        caja("Prensa_boton%d" % k, bx0 + .3 + k * .17, bx0 + .38 + k * .17, 1.12, 1.18, bz1 + .22, bz1 + .25, c, col, choca=False)
    caja("Prensa_palanca", bx1 - .35, bx1 - .32, 1.25, 1.5, bz1 + .1, bz1 + .13, M["hueco"], col, choca=False)
    for s in (-1, 1):
        tubo_curva("Prensa_manguera%d" % s, [Vector((bx0, 1.6, zc + s * .3)), Vector((x1 - .2, 2.4, zc + s * .5)),
                                             Vector((s * 1.6 + .25, alto - .4, zc + s * .1))], .035, M["hueco"], col, lados=5)
    caja("Prensa_choque", x0, x1, 0, alto, z0, z1, M["fierro"], col, choca=False).name = "Prensa_choque-colonly"
    # Los carros ya aplastados, en pilas junto a la prensa
    cx0, cx1, cz0, cz1 = CUBOS
    rng = random.Random(11)
    for i in range(2):
        for j in range(3):
            y = 0.0
            for k in range(rng.randint(2, 4)):
                ob, h = caja_aplastada("Cubo_%d%d%d" % (i, j, k), cx0 + .7 + i * 1.4 + rng.uniform(-.05, .05), y,
                                       cz0 + 1.1 + j * 2.25, 90 + rng.uniform(-6, 6), rng.choice(COLORES_CARRO), col, M, rng)
                y += h


def montacargas(col, M, x, z, giro):
    """Montacargas viejo con un cubo de carro en las unas."""
    p = [caja("Monta_cuerpo", -.9, .5, .25, 1.0, -.55, .55, M["amarillo_maquina"], col, choca=False),
         caja("Monta_contrapeso", -1.2, -.85, .25, 1.05, -.55, .55, M["fierro"], col, choca=False),
         caja("Monta_asiento", -.6, -.2, 1.0, 1.15, -.25, .25, M["hueco"], col, choca=False),
         caja("Monta_respaldo", -.65, -.55, 1.15, 1.55, -.25, .25, M["hueco"], col, choca=False),
         caja("Monta_toldo", -.8, .45, 2.1, 2.15, -.55, .55, M["fierro"], col, choca=False),
         caja("Monta_mastil_a", .55, .65, .1, 2.4, -.4, -.3, M["fierro"], col, choca=False),
         caja("Monta_mastil_b", .55, .65, .1, 2.4, .3, .4, M["fierro"], col, choca=False),
         caja("Monta_una_a", .65, 1.75, .25, .3, -.35, -.25, M["fierro"], col, choca=False),
         caja("Monta_una_b", .65, 1.75, .25, .3, .25, .35, M["fierro"], col, choca=False),
         caja("Monta_volante", .1, .15, 1.2, 1.5, -.02, .02, M["hueco"], col, choca=False)]
    for xp in (-.75, .45):
        for zp in (-.5, .5):
            p.append(caja("Monta_toldo_poste", xp - .03, xp + .03, 1.0, 2.1, zp - .03, zp + .03, M["fierro"], col, choca=False))
    for xr, r in ((-.75, .3), (.3, .25)):
        for s in (-1, 1):
            ll = cilindro_eje("Monta_llanta", r, .22, "z", M["llanta"], col, lados=10)
            ll.location = _b(xr, r, s * .5)
            p.append(ll)
    juntar("Montacargas-convcol", p, col, matriz(x, 0, z, giro))
    a = math.radians(giro)
    caja_aplastada("Monta_cubo", x + math.cos(a) * 1.2, .3, z - math.sin(a) * 1.2, giro, COLORES_CARRO[1], col, M, random.Random(5))


def perrera(col, M, x, z):
    """La casa del perro (de triplay), su plato y su cadena."""
    caja("Perro_casa", x - .5, x + .5, 0, .7, z - .45, z + .45, M["madera"], col)
    techo = prisma("Perro_techo", [(-.6, .7), (.6, .7), (0, 1.05)], 1.0, M["lamina_oxido"], col)
    techo.matrix_basis = matriz(x, 0, z, 90)
    plano("Perro_puerta", (x, .3, z + .455), .35, .45, (0, 0, 1), M["hueco"], col)
    cilindro("Perro_plato", x + .8, 0, .06, z + .6, .12, M["tambo_rojo"], col, lados=8)
    tubo_curva("Perro_cadena", [Vector((x + .4, .35, z)), Vector((x + 1.0, .02, z + .6)), Vector((x + 1.6, .02, z + .2))], .012, M["cadena"], col, lados=4)


def llantas_pintadas(col, M):
    """Llantas medio enterradas y pintadas de colores a los lados de la entrada, como en las colonias."""
    colores = [M["llanta_blanca"], M["llanta_amarilla"], M["llanta_roja"], M["llanta_azul"], M["llanta_verde"]]
    k = 0
    for s in (-1, 1):
        zz = -.5
        while zz > -6.6:
            if s > 0 and zz < -2.6:
                break          # del lado del contenedor se acaba antes
            ll = llanta_rica("Pintada_%d" % k, M, col, mat=colores[k % len(colores)], lados=10)
            ll.matrix_basis = matriz(s * 3.4, .1, zz, 90, giro_x=90)
            zz -= .62
            k += 1


def llantero(col, M):
    """La montana de llantas en la esquina del fondo: llantas con forma, unas con rin, y su choque."""
    lx0, lx1, lz0, lz1 = LLANTERO
    cx, cz = (lx0 + lx1) / 2, (lz0 + lz1) / 2
    for k in range(80):
        d = llanta_rica("Llantero_%d" % k, M, col, lados=10, rin=k % 9 == 0, gastada=random.random())
        r = random.uniform(0, 1) ** .7
        a = random.uniform(0, math.tau)
        px, pz = cx + math.cos(a) * r * (lx1 - lx0) / 2.2, cz + math.sin(a) * r * (lz1 - lz0) / 2.2
        d.location = _b(px, .12 + (1 - r) * 1.9 + random.uniform(-.1, .1), pz)
        d.rotation_euler = (random.uniform(-.9, .9), random.uniform(-.9, .9), random.uniform(0, 3))
    # Algunas paradas recargadas en la montana
    for k in range(6):
        a = random.uniform(0, math.tau)
        d = llanta_rica("Llantero_parada%d" % k, M, col, lados=10)
        d.matrix_basis = matriz(cx + math.cos(a) * 3.0, .35, cz + math.sin(a) * 2.8, math.degrees(a), giro_x=75)
    caja("Llantero_choque", lx0 + .5, lx1 - .5, 0, 1.6, lz0 + .5, lz1 - .5, M["llanta"], col, choca=False).name = "Llantero_choque-colonly"


def chalanes():
    """Las marcas donde trabajan los chalanes (YonkeMapa los pone de dia): "Marca_Chalan_<clip>_<n>"
    con el clip de Quaternius en el nombre y girada para que el chalan (que ve hacia -Z) vea su
    trabajo; "Marca_Ruta_A/B" es el camino del que carga cajas y "Marca_Platica" el que te habla."""
    col = bpy.data.collections["YonkeFuera"]

    def ver(x, z, tx, tz):
        return math.degrees(math.atan2(-(tx - x), -(tz - z)))
    for nombre, x, z, tx, tz in CHALANES:
        marca("Chalan_%s" % nombre, x, 0, z, col, giro_y=ver(x, z, tx, tz))
    marca("Ruta_A", -5.7, 0, -14.0, col)
    marca("Ruta_B", -5.7, 0, -27.5, col)
    marca("Platica", 2.0, 0, -3.6, col, giro_y=ver(2.0, -3.6, 0, 0))


def patio(col, M):
    x0, x1, z0, z1 = PATIO
    caja("Patio_tierra", x0, x1, -.02, .015, z0, z1, M["tierra"], col, choca=False)
    # Manchas de aceite y charcos
    for k in range(12):
        ch = cilindro("Patio_charco%d" % k, random.uniform(x0 + 1, x1 - 1), .016, .02, random.uniform(z0 + 1, z1 - 1),
                      random.uniform(.4, 1.4), M["charco"], col, lados=8)
        ch.scale = (1.0, random.uniform(.5, .9), 1.0)
    rng = random.Random(42)
    carros = []
    # Las dos filas del este: carros pegados, encimados de 1 a 3, los de arriba aplastados
    for fx in FILAS:
        for lugar, lz in enumerate(LUGARES):
            y = 0.0
            for nivel in range(rng.choice((1, 2, 2, 3))):
                tipo = rng.choice(("sedan", "sedan", "vocho", "pickup")) if nivel == 0 else rng.choice(("sedan", "vocho"))
                aplastado = 1.0 if nivel == 0 else rng.uniform(.5, .65)
                ob, alto = carro("Fila_%d_%d_%d" % (int(fx), lugar, nivel), fx + rng.uniform(-.08, .08), y, lz + rng.uniform(-.15, .15),
                                 90 + rng.uniform(-4, 4), rng.choice(COLORES_CARRO), col, M, tipo=tipo, aplastado=aplastado,
                                 sin_llantas=nivel > 0 or rng.random() < .5, cofre_abierto=nivel == 0 and rng.random() < .3,
                                 vidrios_rotos=rng.uniform(.1, .7), sin_puerta=rng.random() < .25,
                                 semilla=rng.randint(0, 9999), abollado=rng.uniform(.3, 1.2), apilado=nivel > 0)
                carros.append(ob)
                y += alto + .02
    # Sueltos en medio: uno en blocks con el cofre abierto, un vocho, uno volteado, una pickup
    sueltos = [("Suelto_1", -1.0, -10.5, 25, "sedan", dict(sin_llantas=True, cofre_abierto=True)),
               ("Suelto_2", 4.2, -16.0, -60, "vocho", dict(sin_puerta=True)),
               ("Suelto_3", -2.5, -18.5, 80, "sedan", dict(volteado=True, abollado=1.5)),
               ("Suelto_4", 4.5, -10.0, 100, "sedan", dict(vidrios_rotos=.6, cofre_abierto=True)),
               ("Suelto_5", -2.6, -24.6, 10, "sedan", dict(sin_llantas=True, sin_puerta=True, sin_defensa=True))]
    for nombre, sx, sz, giro, tipo, extra in sueltos:
        ob, _ = carro(nombre, sx, 0, sz, giro, rng.choice(COLORES_CARRO), col, M, tipo=tipo, semilla=rng.randint(0, 9999), **extra)
        carros.append(ob)
    revisar(carros)
    montacargas(col, M, 1.5, -21.5, 30)
    # La montana de llantas, pilas sueltas y las pintadas de la entrada
    llantero(col, M)
    llantas_pintadas(col, M)
    for k, (lx, lz, n) in enumerate(((-12.6, -2.4, 5), (-11.8, -2.6, 4), (2.2, -36.0, 6), (3.0, -36.4, 5), (8.0, -38.6, 4))):
        llantas("Llantas_%d" % k, lx, lz, n, col, M)
    # Tambos
    for k, (tx, tz) in enumerate(((3.8, -4.4), (3.8, -3.7), (-5.5, -31.5), (-5.5, -32.2), (8.6, -24.0), (8.6, -24.7))):
        tambo("Tambo_%d" % k, tx, tz, M["tambo_azul"] if k % 2 else M["tambo_rojo"], col)
    tambo("Tambo_acostado", -.5, -14.5, M["tambo_azul"], col, acostado=True)
    # Cosas regadas: tapones y una manguera verde junto al contenedor
    for k in range(10):
        t = cilindro_eje("Patio_tapon%d" % k, .18, .03, "y", M["rin"], col, lados=8)
        t.location = _b(random.uniform(-5, 7), .02, random.uniform(-22, -7))
    tubo_curva("Patio_manguera", [Vector((CONTENEDOR[1] + .1, .03, -3.5)), Vector((11.5, .03, -5.0)), Vector((10.8, .03, -7.0)),
                                   Vector((8.5, .03, -6.6))], .02, M["manguera"], col, lados=4)
    perrera(col, M, -11.5, -6.0)
    # Montones de fierro (Chatarra.gd pone los que se recogen en las marcas)
    marca("Chatarra_1", -3.5, 0, -14.5, col)
    marca("Chatarra_2", 7.2, 0, -21.0, col)
    marca("Chatarra_3", -3.0, 0, -36.5, col)
    marca("Flecha", 0, 0, 3.0, col)
    marca("Contenedor", (PUERTA_CONT[0] + PUERTA_CONT[1]) / 2, CONT_BASE, CONTENEDOR[3], col)


def revisar(carros):
    """Ningun carro se sale de la barda ni pisa el contenedor, la prensa, las refacciones, las
    llantas o la entrada (un carro atravesaba la barda este, 2026-11-25)."""
    x0, x1, z0, z1 = PATIO
    margen = .3
    malos = []
    bpy.context.view_layer.update()
    for ob in carros:
        pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        # Blender (x, -z, y): x es x de Godot, -y es z de Godot
        ax0, ax1 = min(p.x for p in pts), max(p.x for p in pts)
        az0, az1 = min(-p.y for p in pts), max(-p.y for p in pts)
        if ax0 < x0 + margen or ax1 > x1 - margen or az0 < z0 + margen or az1 > z1 - margen:
            malos.append("%s se sale del patio" % ob.name)
        for que, (ox0, ox1, oz0, oz1) in OCUPADO.items():
            if ax0 < ox1 and ax1 > ox0 and az0 < oz1 and az1 > oz0:
                malos.append("%s pisa %s" % (ob.name, que))
    if malos:
        raise RuntimeError("yonke.py: " + "; ".join(malos))


def juntar_por_material(col):
    """Para pocas llamadas de dibujo: todo lo que se ve se junta en dos mallas (la barda propia y el
    resto), con un material por superficie. Cada pieza que chocaba ("-convcol") deja antes su casco
    convexo como "-convcolonly" (solo choca); los vacios "Marca_*" y lo "-colonly" se quedan."""
    barda, resto = [], []
    for ob in list(col.all_objects):
        # Lo que YonkeMapa mueve (la placa, los vastagos y el carro de la prensa) se queda aparte
        if ob.type != "MESH" or ob.name.endswith(("-colonly", "-convcolonly")) or ob.name.startswith("Prensa_mov_"):
            continue
        base = ob.name
        if base.endswith("-convcol"):
            base = base[:-len("-convcol")]
            bm = bmesh.new()
            bm.from_mesh(ob.data)
            bmesh.ops.transform(bm, matrix=ob.matrix_basis, verts=bm.verts)
            casco = bmesh.ops.convex_hull(bm, input=bm.verts[:])
            sobran = set(casco["geom_interior"]) | set(casco["geom_unused"])
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v in sobran], context="VERTS")
            me = bpy.data.meshes.new(base + "_casco")
            bm.to_mesh(me)
            bm.free()
            choque = bpy.data.objects.new(base + "-convcolonly", me)
            col.objects.link(choque)
            ob.name = base
        (barda if base.startswith("Barda_") else resto).append(ob)
    juntar("Barda_todo", barda, col)
    juntar("Patio_todo", resto, col)


def carteles(col, M):
    """Los carteles: por fuera en la barda del frente, en el contenedor y por dentro."""
    z1 = PATIO[3]
    afuera = (0, 0, 1)
    cartel("Cartel_precios", "precios", (-8.0, .95, z1 + .06), 1.5, afuera, col, M)
    cartel("Cartel_lucha", "lucha", (-5.3, .9, z1 + .06), 1.0, afuera, col, M)
    cartel("Cartel_rines", "rines", (-11.6, .95, z1 + .06), 1.3, afuera, col, M)
    cartel("Cartel_refacciones", "refacciones", (7.6, .95, z1 + .06), 1.6, afuera, col, M)
    cartel("Cartel_hojalateria", "hojalateria", (11.5, .95, z1 + .06), 1.3, afuera, col, M)
    cartel("Cartel_perro", "perro", (4.6, .85, z1 + .06), .9, afuera, col, M)
    cartel("Cartel_robado", "robado", (PUERTA_CONT[0] - .7, 1.6, CONTENEDOR[3] + .07), 1.0, afuera, col, M)
    cartel("Cartel_virgen", "virgen", (PUERTA_CONT[1] + .55, 2.2, CONTENEDOR[3] + .07), .7, afuera, col, M)
    # Por dentro: en la barda del este, la del fondo y junto a la perrera
    cartel("Cartel_precios_dentro", "precios", (PATIO[1] - .06, 1.4, -7.0), 1.4, (-1, 0, 0), col, M)
    cartel("Cartel_lucha_dentro", "lucha", (-6.0, 1.5, PATIO[2] + .06), 1.2, (0, 0, 1), col, M)
    cartel("Cartel_perro_dentro", "perro", (PATIO[0] + .06, 1.2, -5.0), .8, (1, 0, 0), col, M)


def exterior():
    col = coleccion("YonkeFuera")
    M = mats()
    patio(col, M)
    barda(col, M)
    letrero_yonke(col, M)
    contenedor(col, M)
    refaccionaria(col, M)
    prensa(col, M)
    carteles(col, M)
    chalanes()
    juntar_por_material(col)
    return col


# ---------------------------------------------------------------- adentro: la oficina-contenedor
# Coordenadas de Interior.gd: el frente del mostrador en z = 0, piso en y = 0, la camara en +Z
# viendo a -Z. Es el contenedor visto a lo largo: angosto y apretado, como debe ser.
DENTRO = (-1.17, 1.17, -3.0, 2.9)     # x0, x1, z0, z1 (la puerta queda detras de la camara)
DENTRO_ALTO = 2.4
VENTANA_DENTRO = (-2.4, -0.9, 1.0, 1.75)  # z0, z1, y0, y1 del corte en el muro oeste


def mats_dentro():
    M = mats()
    M.update({
        "pintura_dentro": mat_tex("pintura_dentro", "res://textures/map/lamina.png", (0.72, 0.7, 0.6), 0.8),
        "triplay": mat_tex("triplay", "res://textures/mapa/madera.png", (0.75, 0.62, 0.45), 1.2),
        "pegboard": material("pegboard", (0.55, 0.42, 0.3)),
        "foco_yonke": material("foco_yonke", (1.0, 0.85, 0.55), emision=6.0),
        "ventana_luz": material("ventana_luz", (0.95, 0.9, 0.75), emision=2.5),
        "pantalla_tele": material("pantalla_tele", (0.35, 0.55, 0.65), emision=1.5),
        "estampa_virgen": material("estampa_virgen", (0.9, 0.85, 0.7)),
        "calendario": material("calendario", (0.92, 0.9, 0.86)),
        "tanque_verde": material("tanque_verde", (0.15, 0.4, 0.2)),
        "tanque_negro": material("tanque_negro", (0.08, 0.08, 0.09)),
        "locker": material("locker", (0.4, 0.45, 0.42)),
        "cable": material("cable", (0.05, 0.05, 0.05)),
        "careta": material("careta", (0.1, 0.1, 0.12)),
        "bateria": material("bateria", (0.1, 0.1, 0.1)),
    })
    return M


def interior():
    col = coleccion("YonkeDentro")
    M = mats_dentro()
    x0, x1, z0, z1 = DENTRO
    a = DENTRO_ALTO
    g = .06
    # Cascaron: piso de triplay, techo, muros corrugados por dentro y la ventana cortada a soplete
    caja("D_piso", x0, x1, -g, 0, z0, z1, M["triplay"], col)
    caja("D_techo", x0, x1, a, a + g, z0, z1, M["pintura_dentro"], col)
    caja("D_fondo", x0, x1, 0, a, z0 - g, z0, M["pintura_dentro"], col)
    caja("D_frente", x0, x1, 0, a, z1, z1 + g, M["pintura_dentro"], col)
    caja("D_este", x1, x1 + g, 0, a, z0, z1, M["pintura_dentro"], col)
    vz0, vz1, vy0, vy1 = VENTANA_DENTRO
    caja("D_oeste_a", x0 - g, x0, 0, a, z0, vz0, M["pintura_dentro"], col)
    caja("D_oeste_b", x0 - g, x0, 0, a, vz1, z1, M["pintura_dentro"], col)
    caja("D_oeste_c", x0 - g, x0, 0, vy0, vz0, vz1, M["pintura_dentro"], col, choca=False)
    caja("D_oeste_d", x0 - g, x0, vy1, a, vz0, vz1, M["pintura_dentro"], col, choca=False)
    # Afuera de la ventana: la luz del dia y la silueta de un carro encimado
    plano("D_luz", (x0 - 1.5, 1.4, (vz0 + vz1) / 2), 3.0, 2.0, (1, 0, 0), M["ventana_luz"], col)
    caja("D_carro_fuera", x0 - 1.2, x0 - .9, .6, 1.25, vz0 - .2, vz0 + .9, material("pintura_0", COLORES_CARRO[0]), col, choca=False)
    barrotes = [caja("D_barrote%d" % k, x0 - .04, x0 - .01, vy0, vy1, vz0 + .12 + k * .18, vz0 + .15 + k * .18, M["fierro"], col, choca=False)
                for k in range(int((vz1 - vz0) / .18))]
    juntar("D_barrotes", barrotes, col)
    # Costillas del corrugado en los muros largos
    cost = []
    zz = z0 + .1
    while zz < z1:
        for xc, s in ((x0 + .02, 1), (x1 - .02, -1)):
            if s == 1 and vz0 - .05 < zz < vz1 + .05:
                pass   # el hueco de la ventana
            else:
                cost.append(caja("D_cost", xc - .02, xc + .02, .05, a - .05, zz - .035, zz + .035, M["pintura_dentro"], col, choca=False))
        zz += .28
    juntar("D_costillas", cost, col)
    # El mostrador: tablones sobre dos tambos, con una lamina al frente llena de calcomanias
    for k, tx in enumerate((-.85, .15)):
        t = cilindro_eje("D_tambo%d" % k, .29, .86, "y", M["tambo_azul"] if k else M["tambo_rojo"], col, lados=10)
        t.location = _b(tx, .43, -.35)
    caja("D_tablon", -1.15, .55, .86, .93, -.75, .05, M["madera"], col)
    caja("D_lamina_mostrador", -1.15, .55, .5, .86, .0, .03, M["lamina_oxido"], col, choca=False)
    # Prensa de banco en la esquina del mostrador y un ventilador
    caja("D_prensa", .3, .5, .93, 1.05, -.25, -.05, M["tambo_azul"], col, choca=False)
    caja("D_prensa_quijada", .28, .52, 1.05, 1.12, -.2, -.1, M["fierro"], col, choca=False)
    vent = [cilindro("D_vent_pata", -.95, .93, 1.15, -.55, .02, M["fierro"], col),
            caja("D_vent_base", -1.05, -.85, .93, .96, -.65, -.45, M["fierro"], col, choca=False)]
    rejilla = cilindro_eje("D_vent_rejilla", .11, .06, "z", M["fierro"], col, lados=10)
    rejilla.location = _b(-.95, 1.25, -.5)
    rejilla.rotation_euler.z = math.radians(-25)
    vent.append(rejilla)
    juntar("D_ventilador", vent, col)
    # Pared del fondo: tablero perforado con herramienta, repisa con la tele y la radio
    caja("D_pegboard", -1.1, .4, .95, 2.15, z0 + .01, z0 + .04, M["pegboard"], col, choca=False)
    herr = []
    for k in range(7):
        hx = -1.0 + k * .2
        largo = random.uniform(.18, .36)
        herr.append(caja("D_llave%d" % k, hx, hx + .03, 1.6 - largo, 1.6, z0 + .04, z0 + .06, M["rin"], col, choca=False))
    herr.append(caja("D_serrucho", -.95, -.45, 1.75, 1.88, z0 + .04, z0 + .06, M["rin"], col, choca=False))
    herr.append(caja("D_serrucho_mango", -.45, -.32, 1.73, 1.9, z0 + .04, z0 + .07, M["madera"], col, choca=False))
    herr.append(caja("D_marro", .05, .1, 1.1, 1.55, z0 + .04, z0 + .07, M["madera"], col, choca=False))
    herr.append(caja("D_marro_cabeza", -.02, .17, 1.5, 1.6, z0 + .04, z0 + .12, M["fierro"], col, choca=False))
    juntar("D_herramienta", herr, col)
    careta = caja("D_careta", .18, .38, 1.75, 2.0, z0 + .04, z0 + .14, M["careta"], col, choca=False)
    caja("D_careta_vidrio", .22, .34, 1.85, 1.9, z0 + .14, z0 + .145, M["vidrio_sucio"], col, choca=False)
    # Repisa alta a la derecha: tele chiquita encendida, radio, botes
    caja("D_repisa", .45, 1.15, 1.6, 1.64, z0 + .02, z0 + .4, M["madera"], col, choca=False)
    caja("D_tele", .55, .9, 1.64, 1.94, z0 + .05, z0 + .35, M["careta"], col, choca=False)
    plano("D_tele_pantalla", (.72, 1.79, z0 + .355), .28, .22, (0, 0, 1), M["pantalla_tele"], col)
    caja("D_radio", .95, 1.12, 1.64, 1.74, z0 + .1, z0 + .3, M["fierro"], col, choca=False)
    # Estampita de la Virgen y calendario de refaccionaria
    plano("D_virgen", (-.2, 2.12, z0 + .045), .22, .3, (0, 0, 1), M["estampa_virgen"], col)
    plano("D_calendario", (x1 - .03, 1.55, -1.7), .4, .55, (-1, 0, 0), M["calendario"], col)
    # Lado este: locker, soldadora y tanques de gas
    caja("D_locker", x1 - .5, x1, 0, 1.8, -2.25, -1.65, M["locker"], col)
    for k in range(3):
        plano("D_locker_ranura%d" % k, (x1 - .505, 1.55 - k * .06, -1.95), .3, .02, (-1, 0, 0), M["hueco"], col)
    caja("D_soldadora", x1 - .55, x1 - .05, 0, .55, -1.5, -1.0, M["letrero_rojo"], col)
    plano("D_soldadora_panel", (x1 - .555, .4, -1.25), .3, .15, (-1, 0, 0), M["careta"], col)
    for k, (tz, m) in enumerate(((-2.75, M["tanque_verde"]), (-2.45, M["tanque_negro"]))):
        cilindro("D_tanque%d" % k, x0 + .2, 0, 1.25, tz, .11, m, col, lados=10)
    # Cable de la soldadora enrollado en el piso
    tubo_curva("D_cable_suelo", [Vector((x1 - .55 - .3 * math.cos(t), .03, -1.0 + .3 * math.sin(t))) for t in [k * .5 for k in range(14)]],
               .015, M["cable"], col, lados=4)
    # El foco pelon lo cuelga Interior.gd (foco = true: parpadea y alumbra) en (0.3, alto - 0.5,
    # -fondo / 2); aqui solo el cable que va por el techo de ahi hasta la puerta
    tubo_curva("D_cable_techo", [Vector((.3, a - .02, -.5)), Vector((.3, a - .02, .5)), Vector((x1 - .1, a - .02, 2.0))], .012, M["cable"], col, lados=4)
    # Piso: manchas de aceite, una bateria, una llanta y rines recargados
    for k in range(4):
        ch = cilindro("D_mancha%d" % k, random.uniform(x0 + .3, x1 - .3), .001, .004, random.uniform(-2.5, 1.5),
                      random.uniform(.15, .35), M["charco"], col, lados=8)
    caja("D_bateria", -.55, -.25, 0, .22, -1.6, -1.4, M["bateria"], col, choca=False)
    d = dona("D_llanta", .36, .14, .22, M["llanta"], col)
    d.location = _b(x0 + .4, .11, 1.3)
    for k in range(2):
        r = cilindro_eje("D_rin%d" % k, .2, .04, "x", M["rin"], col, lados=10)
        r.location = _b(x0 + .05, .2, .5 + k * .3)
        r.rotation_euler.y = math.radians(10)
    # Lo que usa Yonke.gd (Interior.gd: Camara, Mostrador, Vendedor; y el Banco donde flota lo que haces)
    marca("Camara", .3, 1.6, 2.3, col)
    marca("Mostrador", -.3, 0, -.35, col)
    marca("Vendedor", -.4, 0, -1.25, col)
    marca("Banco", -.3, 1.02, -.3, col)
    return col


def exportar():
    exportar_coleccion("YonkeFuera", os.path.join(SALIDA, "yonke_fuera.glb"))
    exportar_coleccion("YonkeDentro", os.path.join(SALIDA, "yonke_dentro.glb"))
    preparar_vista("YonkeFuera", ["YonkeDentro"])
    guardar_fuente(os.path.join(SALIDA, "fuente", "yonke.blend"))


if __name__ == "yonke":
    if bpy.data.filepath and not bpy.data.filepath.endswith(("yonke.blend", "punto.blend")):
        raise RuntimeError("yonke.py borraria " + bpy.data.filepath + ": abre un archivo nuevo primero")
    limpiar()
    exterior()
    interior()
    print("yonke: %d objetos afuera, %d adentro" % (len(bpy.data.collections["YonkeFuera"].all_objects),
                                                   len(bpy.data.collections["YonkeDentro"].all_objects)))
    if globals().get("EXPORTAR"):
        exportar()
    else:
        preparar_vista("YonkeFuera", ["YonkeDentro"])
