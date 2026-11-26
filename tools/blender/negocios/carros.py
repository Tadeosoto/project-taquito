# Carros deshuesados para el Yonke y el lote de El Punto (yonke.py lo carga despues de comun.py).
# Cada carro es una carroceria hecha de anillos a lo largo (lados redondos, cofre y cajuela que
# bajan, techo que se angosta), con vidrios, defensas, parrilla, faros, calaveras, espejos, llantas
# con rin y tapon, y su desgaste: abolladuras, oxido, cofre abierto con el motor, puertas que faltan
# (se ven los asientos), vidrios rotos, sin llantas (en blocks), aplastado o volteado.
# Unas 400-700 caras por carro (PS1 con mas detalle).
#
# Coordenadas de Godot: el carro se arma con el frente hacia +x, centrado en x = 0, z = 0, el piso
# en y = 0, y se mueve con matriz(x, y, z, giro). Devuelve (objeto, alto), para encimarlos.

COLORES_CARRO = [(0.55, 0.12, 0.1), (0.15, 0.3, 0.5), (0.75, 0.72, 0.65), (0.2, 0.22, 0.22),
                 (0.6, 0.5, 0.2), (0.25, 0.4, 0.25), (0.45, 0.45, 0.48), (0.7, 0.35, 0.1),
                 (0.85, 0.82, 0.75), (0.35, 0.15, 0.3)]

# Perfiles: anillos (u a lo largo desde la defensa de atras, medio ancho abajo, medio ancho en la
# cintura, alto de la cintura, medio ancho arriba, alto de arriba, que es la cara de arriba del
# tramo que SIGUE: "lamina", "vidrio" o "toldo") y el largo total
PERFILES = {
    "sedan": (4.3, [
        (0.00, .74, .80, .78, .74, .84, "lamina"),
        (0.25, .80, .86, .80, .80, .90, "lamina"),
        (1.00, .82, .88, .82, .80, .95, "vidrio"),     # sigue el medallon
        (1.45, .80, .87, .84, .62, 1.36, "toldo"),
        (2.60, .80, .87, .84, .62, 1.38, "vidrio"),    # sigue el parabrisas
        (3.05, .82, .88, .82, .78, .98, "lamina"),
        (4.05, .80, .86, .78, .76, .86, "lamina"),
        (4.30, .72, .78, .72, .66, .76, None),
    ]),
    "vocho": (4.0, [
        (0.00, .68, .74, .60, .55, .78, "lamina"),
        (0.40, .76, .80, .70, .66, 1.05, "vidrio"),
        (1.00, .78, .80, .75, .58, 1.38, "toldo"),
        (2.20, .78, .80, .75, .58, 1.40, "vidrio"),
        (2.75, .78, .80, .74, .70, 1.0, "lamina"),
        (3.60, .74, .76, .66, .62, .82, "lamina"),
        (4.00, .55, .60, .55, .45, .66, None),
    ]),
    "pickup": (2.9, [                                  # solo la cabina y el frente; la caja va aparte
        (0.00, .82, .88, .86, .80, .95, "lamina"),
        (0.08, .82, .88, .88, .66, 1.55, "toldo"),
        (1.05, .82, .88, .88, .66, 1.57, "vidrio"),
        (1.45, .84, .90, .88, .82, 1.02, "lamina"),
        (2.70, .82, .88, .84, .80, .94, "lamina"),
        (2.90, .74, .80, .76, .68, .82, None),
    ]),
}
CAJA_PICKUP = 2.0          # largo de la caja de la pickup (va detras de la cabina)
PISO = 0.36                # alto del piso del carro
RUEDA = 0.33
SALPICADERA = 0.40         # radio del hueco oscuro detras de la llanta


def _mat_carro(color, M):
    k = COLORES_CARRO.index(color) if color in COLORES_CARRO else 0
    return material("pintura_%d" % k, color)


def _anillo(bm, u, hw0, hw, yb, hwt, yt, giro_u=0.0):
    """Los 8 puntos de un corte de la carroceria (en orden alrededor), en coordenadas de Blender."""
    pts = [(-hw0, PISO), (-hw, PISO + .12), (-hw, yb), (-hwt, yt - .04), (-hwt + .05, yt),
           (hwt - .05, yt), (hwt, yt - .04), (hw, yb), (hw, PISO + .12), (hw0, PISO)]
    return [bm.verts.new(_b(u, y, z)) for z, y in pts]


def carroceria(nombre, perfil, pintura, M, col, rng, aplastado=1.0, sin_puertas=(), vidrios_rotos=0.0,
               cofre_abierto=False, abolladuras=0.0):
    """La lamina, los vidrios y el interior oscuro de un perfil. Regresa (objeto, alto, largo)."""
    largo, anillos = PERFILES[perfil]
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    mats = [pintura, M["vidrio_sucio"], M["hueco"]]
    cortes = []
    for u, hw0, hw, yb, hwt, yt, _ in anillos:
        if yt > 1.1:
            yt = yb + (yt - yb) * aplastado
        cortes.append(_anillo(bm, u - largo / 2, hw0, hw, yb, hwt, yt))
    n = len(cortes[0])
    # Las caras: entre cada par de anillos; las de arriba del tramo segun su tipo, y los lados de la
    # cabina (entre la cintura y el techo) de vidrio donde el techo va arriba de 1.1
    puertas = set(sin_puertas)
    for i in range(len(cortes) - 1):
        a, b = cortes[i], cortes[i + 1]
        tipo = anillos[i][6]
        alto_tramo = max(anillos[i][5], anillos[i + 1][5])
        for k in range(n):
            j = (k + 1) % n
            if j == 0:
                continue          # el piso se cierra aparte
            f = bm.faces.new((a[k], a[j], b[j], b[k]))
            arriba = k == 4
            lado_cabina = k in (2, 3, 6, 7) and alto_tramo > 1.1 and tipo == "toldo"
            if arriba:
                if tipo == "vidrio":
                    f.material_index = 1 if rng.random() > vidrios_rotos else 2
                elif cofre_abierto and i == len(cortes) - 2 and perfil != "pickup":
                    f.material_index = 2
                elif cofre_abierto and i == len(cortes) - 3 and perfil != "pickup":
                    f.material_index = 2
            elif k in (2, 6) and lado_cabina:
                f.material_index = 1 if rng.random() > vidrios_rotos else 2
            elif k in (1, 7) and tipo == "toldo" and (k == 1 and "izq" in puertas or k == 7 and "der" in puertas):
                f.material_index = 2
    # Tapas de adelante y de atras y el piso
    bm.faces.new(list(reversed(cortes[0])))
    bm.faces.new(cortes[-1])
    piso = [c[0] for c in cortes] + [c[-1] for c in reversed(cortes)]
    try:
        bm.faces.new(piso)
    except ValueError:
        pass
    # Abolladuras: cada vertice se mueve un poco, y unos cuantos golpes grandes hacia adentro
    if abolladuras > 0:
        for v in bm.verts:
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.025 * abolladuras
        for _ in range(int(2 * abolladuras) + 1):
            centro = rng.choice(list(bm.verts)).co.copy()
            for v in bm.verts:
                d = (v.co - centro).length
                if d < .45 and v.co.z > .7:
                    v.co.z -= 0.07 * abolladuras * (1 - d / .45)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    _uv_caja(me)
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    return ob, max(a[5] for a in anillos) * (aplastado if max(a[5] for a in anillos) > 1.1 else 1.0), largo


def rueda(nombre, M, col, lados=12):
    """Llanta con su cara de rin y su tapon, viendo hacia +z (el lado del carro)."""
    llanta = cilindro_eje(nombre + "_llanta", RUEDA, .22, "z", M["llanta"], col, lados=lados)
    rin = cilindro_eje(nombre + "_rin", RUEDA * .62, .23, "z", M["rin"], col, lados=10)
    tapon = cilindro_eje(nombre + "_tapon", RUEDA * .25, .24, "z", M["cromo"] if "cromo" in M else M["rin"], col, lados=6)
    return juntar(nombre, [llanta, rin, tapon], col)


def carro(nombre, x, y, z, giro, color, col, M, tipo="sedan", aplastado=1.0, sin_llantas=False,
          cofre_abierto=False, sin_puerta=False, volteado=False, semilla=None, oxido=0.5, vidrios_rotos=0.25,
          sin_defensa=False, abollado=0.6, apilado=False):
    """Un carro completo en (x, y, z) girado `giro` grados. Regresa (objeto, alto). `apilado`: va
    encima de otro, sin llantas ni blocks y con el piso pegado al techo del de abajo."""
    rng = random.Random(semilla if semilla is not None else hash(nombre) & 0xffff)
    if tipo == "pickup":
        largo_total = PERFILES["pickup"][0] + CAJA_PICKUP
    else:
        largo_total = PERFILES[tipo][0]
    pintura = _mat_carro(color, M)
    piezas = []
    lados = ("izq",) if sin_puerta else ()
    cuerpo, alto, largo = carroceria(nombre + "_cuerpo", tipo, pintura, M, col, rng, aplastado, lados, vidrios_rotos,
                                     cofre_abierto, abollado)
    if tipo == "pickup":
        # La cabina va adelante; la caja abierta detras (piso, costados y la puerta de atras)
        cuerpo.location = _b(largo_total / 2 - largo / 2, 0, 0)
        cx0, cx1 = -largo_total / 2, -largo_total / 2 + CAJA_PICKUP
        piezas += [caja(nombre + "_caja_piso", cx0, cx1, PISO, PISO + .08, -.82, .82, pintura, col, choca=False),
                   caja(nombre + "_caja_izq", cx0, cx1, PISO, .95, -.86, -.8, pintura, col, choca=False),
                   caja(nombre + "_caja_der", cx0, cx1, PISO, .95, .8, .86, pintura, col, choca=False),
                   caja(nombre + "_caja_puerta", cx0, cx0 + .06, PISO + .05, .92, -.8, .8, pintura, col, choca=False),
                   caja(nombre + "_caja_fondo", cx1 - .04, cx1, PISO, .95, -.8, .8, pintura, col, choca=False)]
        if rng.random() < .6:
            piezas.append(caja(nombre + "_caja_carga", cx0 + .3, cx0 + 1.2, PISO + .08, PISO + .5, -.6, .3, M["madera"], col, choca=False))
    piezas.append(cuerpo)
    x0, x1 = -largo_total / 2, largo_total / 2
    ancho = .88
    # Defensas (cromo o negras), parrilla, faros y calaveras
    defensa = M["cromo"] if rng.random() < .6 else M["fierro"]
    if not sin_defensa:
        piezas.append(caja(nombre + "_def_frente", x1 - .02, x1 + .1, .38, .55, -ancho + .04, ancho - .04, defensa, col, choca=False))
    piezas.append(caja(nombre + "_def_atras", x0 - .1, x0 + .02, .38, .55, -ancho + .04, ancho - .04, defensa, col, choca=False))
    frente_alto = PERFILES[tipo][1][-1][3]
    piezas.append(caja(nombre + "_parrilla", x1 - .01, x1 + .02, .57, frente_alto - .04, -.42, .42, M["hueco"], col, choca=False))
    for s in (-1, 1):
        piezas.append(caja(nombre + "_faro%d" % s, x1 - .01, x1 + .025, .58, frente_alto - .06, s * .62 - .14, s * .62 + .14, M["faro"], col, choca=False))
        piezas.append(caja(nombre + "_calavera%d" % s, x0 - .025, x0 + .01, .6, .74, s * .6 - .13, s * .6 + .13, M["letrero_rojo"], col, choca=False))
    # Espejos en las puertas
    u_espejo = (x1 - 1.35) if tipo != "pickup" else (x1 - 1.55)
    for s in (-1, 1):
        if rng.random() < .75:
            piezas.append(caja(nombre + "_espejo%d" % s, u_espejo - .06, u_espejo + .06, .92, 1.02, s * (ancho + .02), s * (ancho + .1), M["fierro"], col, choca=False))
    # El interior oscuro (se ve por los vidrios rotos y las puertas que faltan) y los asientos
    piezas.append(caja(nombre + "_interior", x0 + .6, x1 - 1.0, PISO + .02, .95, -.72, .72, M["hueco"], col, choca=False))
    if sin_puerta or vidrios_rotos > .3:
        for k, u in enumerate((x1 - 2.1, x1 - 2.9) if tipo != "pickup" else (x1 - 2.2,)):
            piezas.append(caja(nombre + "_asiento%d" % k, u - .25, u + .25, .5, .72, -.66, .66, M["asiento"], col, choca=False))
            piezas.append(caja(nombre + "_respaldo%d" % k, u - .32, u - .2, .72, 1.12, -.66, .66, M["asiento"], col, choca=False))
    # Cofre abierto: la tapa levantada y el motor
    if cofre_abierto and tipo != "pickup":
        tapa = caja(nombre + "_cofre", -1.0, 0, -.02, .02, -.76, .76, pintura, col, choca=False)
        tapa.data.transform(Matrix.Rotation(math.radians(-60), 4, "Y"))
        tapa.location = _b(x1 - 1.25, .92, 0)
        piezas.append(tapa)
        piezas.append(caja(nombre + "_motor", x1 - 1.1, x1 - .25, .45, .78, -.45, .45, M["motor"], col, choca=False))
        piezas.append(caja(nombre + "_filtro", x1 - .85, x1 - .55, .78, .86, -.15, .15, M["fierro"], col, choca=False))
    # Llantas (o blocks) con su hueco de salpicadera
    for u in (x0 + .85, x1 - .85):
        for s in (-1, 1):
            arco = cilindro_eje(nombre + "_arco", SALPICADERA, .02, "z", M["hueco"], col, lados=10)
            arco.location = _b(u, RUEDA + .02, s * (ancho + .005))
            piezas.append(arco)
            if apilado:
                pass
            elif sin_llantas:
                piezas.append(caja(nombre + "_blk", u - .2, u + .2, 0, PISO, s * .6 - .1, s * .6 + .1, M["block"], col, choca=False))
            else:
                r = rueda(nombre + "_rueda", M, col)
                r.location = _b(u, RUEDA, s * (ancho - .1))
                piezas.append(r)
    # Oxido en manchas por los lados
    for k in range(int(oxido * 6)):
        s = rng.choice((-1, 1))
        piezas.append(plano(nombre + "_ox%d" % k, (rng.uniform(x0 + .3, x1 - .3), rng.uniform(.45, .8), s * (ancho + .012)),
                            rng.uniform(.25, .7), rng.uniform(.12, .3), (0, 0, s), M["oxido"], col))
    if apilado:
        y -= PISO - .02
    ob = juntar(nombre + "-convcol", piezas, col, matriz(x, y, z, giro))
    if volteado:
        ob.matrix_basis = matriz(x, y + alto, z, giro) @ Matrix.Rotation(math.pi, 4, "X")
    return ob, alto - (PISO - .02 if apilado else 0.0)


def caja_aplastada(nombre, x, y, z, giro, color, col, M, rng):
    """Un cubo de carro aplastado (lo que sale de la prensa): bloque de lamina con costillas,
    vidrio y llanta asomando."""
    pintura = _mat_carro(color, M)
    w, h, l = rng.uniform(1.1, 1.3), rng.uniform(.5, .7), rng.uniform(1.6, 2.0)
    piezas = [caja(nombre + "_bloque", -l / 2, l / 2, 0, h, -w / 2, w / 2, pintura, col, choca=False)]
    for k in range(4):
        yy = rng.uniform(.08, h - .08)
        piezas.append(caja(nombre + "_pliegue%d" % k, -l / 2 - .02, l / 2 + .02, yy - .02, yy + .02, -w / 2 - .02, w / 2 + .02,
                           rng.choice((M["oxido"], M["hueco"], pintura)), col, choca=False))
    piezas.append(plano(nombre + "_vidrio", (rng.uniform(-.4, .4), h * .6, w / 2 + .025), .5, .12, (0, 0, 1), M["vidrio_sucio"], col))
    if rng.random() < .5:
        ll = cilindro_eje(nombre + "_llanta", .3, .05, "z", M["llanta"], col, lados=10)
        ll.location = _b(rng.uniform(-.5, .5), h * .5, -w / 2 - .02)
        piezas.append(ll)
    return juntar(nombre + "-convcol", piezas, col, matriz(x, y, z, giro)), h


LLANTA_PERFIL = [(.20, -.09), (.25, -.112), (.33, -.11), (.36, -.075), (.36, .075), (.33, .11), (.25, .112), (.20, .09)]


def llanta_rica(nombre, M, col, mat=None, lados=12, rin=False, gastada=0.0):
    """Una llanta con forma: seccion redondeada girada (costado, hombro y banda), con el dibujo de
    la banda en relieve (cada otro gajo se hunde) y, si `rin`, su rin con birlos. Acostada (eje
    vertical de Blender, como dona()). ~200 caras sin rin."""
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    anillos = []
    for k in range(lados * 2):
        a = k * math.tau / (lados * 2)
        relieve = .012 if k % 2 else 0.0
        pts = []
        for r, h in LLANTA_PERFIL:
            if r > .35:
                r -= relieve * (1.0 - gastada)
            pts.append(bm.verts.new((r * math.cos(a), r * math.sin(a), h)))
        anillos.append(pts)
    n = len(LLANTA_PERFIL)
    for k in range(len(anillos)):
        a, b = anillos[k], anillos[(k + 1) % len(anillos)]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat or M["llanta"])
    ob = bpy.data.objects.new(nombre, me)
    col.objects.link(ob)
    if not rin:
        return ob
    disco = cilindro_eje(nombre + "_rin", .205, .16, "y", M["rin"], col, lados=10)
    centro = cilindro_eje(nombre + "_maza", .07, .18, "y", M["hueco"], col, lados=6)
    piezas = [ob, disco, centro]
    for k in range(5):
        a = k * math.tau / 5
        b = cilindro_eje(nombre + "_birlo%d" % k, .012, .19, "y", M["cromo"] if "cromo" in M else M["rin"], col, lados=4)
        b.location = Vector((math.cos(a) * .11, math.sin(a) * .11, 0))
        piezas.append(b)
    return juntar(nombre, piezas, col)
