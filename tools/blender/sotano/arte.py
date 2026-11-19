# El arte del Sotano (docs/sistemas/sotano.md), renderizado en Blender con Workbench plano y sin
# suavizado (pixeles duros, como todo el juego):
#   textures/sotano/cartas.png        las cartas de la loteria (CARTAS, 8 x 3 de 96 x 144 px, sin
#                                     nombre: OlPleyUI lo escribe encima con letra de pixel)
#   textures/sotano/calcomanias.png   el gabinete EL GORDO (marquesina, puerta, costado, etiquetas)
#   textures/sotano/pantalla.png      lo que la maquinita muestra sola ("inserte ficha")
# Los dibujos son los glifos de linea de Segoe UI Emoji (Windows) sobre fondos de color; los
# nombres, en Arial Black / Impact. Corre en el archivo que sea (usa escenas propias y las borra):
#   R = r"C:\Users\Big Boss\Documents\GitHub\project-taquito\tools\blender\sotano"
#   exec(open(R + r"\arte.py", encoding="utf-8").read(), {"__name__": "arte"})
# Si cambia CARTAS, cambia tambien scripts/sotano/Cartas.gd (mismo orden).

import bpy
import os
import random

RAIZ = os.environ.get("TAQUITO_RAIZ", r"C:\Users\Big Boss\Documents\GitHub\project-taquito")
SALIDA = os.path.join(RAIZ, "textures", "sotano")
FUENTES = r"C:\Windows\Fonts"

# nombre, glifo (Segoe UI Emoji), color del fondo. Las ultimas son de este mundo.
CARTAS = [
    ("El Gallo", "\U0001F413", (0.95, 0.55, 0.15)),
    ("El Diablito", "\U0001F608", (0.85, 0.15, 0.15)),
    ("La Sirena", "\U0001F9DC", (0.2, 0.6, 0.75)),
    ("El Paraguas", "\u2602", (0.55, 0.35, 0.75)),
    ("La Calavera", "\U0001F480", (0.9, 0.85, 0.7)),
    ("El Nopal", "\U0001F335", (0.35, 0.7, 0.3)),
    ("La Luna", "\U0001F319", (0.15, 0.2, 0.45)),
    ("El Sol", "\u2600", (1.0, 0.8, 0.2)),
    ("El Corazón", "\u2764", (0.9, 0.3, 0.4)),
    ("La Campana", "\U0001F514", (0.95, 0.75, 0.3)),
    ("La Estrella", "\u2B50", (0.25, 0.35, 0.7)),
    ("El Venado", "\U0001F98C", (0.7, 0.5, 0.3)),
    ("La Rana", "\U0001F438", (0.45, 0.75, 0.35)),
    ("El Pescado", "\U0001F41F", (0.3, 0.55, 0.85)),
    ("La Araña", "\U0001F577", (0.6, 0.6, 0.55)),
    ("La Rosa", "\U0001F339", (0.95, 0.6, 0.7)),
    ("El Cotorro", "\U0001F99C", (0.3, 0.8, 0.45)),
    ("La Corona", "\U0001F451", (0.95, 0.8, 0.35)),
    ("El Apagado", "\U0001F9DF", (0.45, 0.55, 0.65)),
    ("La Pipa", "\U0001F69A", (0.25, 0.65, 0.85)),
    ("El Machete", "\U0001F5E1", (0.7, 0.7, 0.72)),
    ("La Garrafa", "\U0001FAD9", (0.55, 0.8, 0.95)),
    ("El Camión", "\U0001F68C", (0.95, 0.65, 0.2)),
    ("El Tinaco", "\U0001F6E2", (0.1, 0.1, 0.12)),
]
COLUMNAS = 8
CARTA = (96, 144)     # del tamano en que se ve en la pantalla (384 x 288): sin escalar, se lee
CREMA = (0.95, 0.9, 0.78)
TINTA = (0.08, 0.06, 0.06)


def _mat(nombre, color):
    m = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    m.diffuse_color = (*color, 1.0)
    return m


def _fuente(archivo):
    return bpy.data.fonts.load(os.path.join(FUENTES, archivo), check_existing=True)


def _escena(nombre, ancho_px, alto_px, unidad_px):
    vieja = bpy.data.scenes.get(nombre)
    if vieja:
        bpy.data.scenes.remove(vieja)
    sc = bpy.data.scenes.new(nombre)
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.render_aa = "OFF"
    sc.render.resolution_x = ancho_px
    sc.render.resolution_y = alto_px
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    cam = bpy.data.cameras.new(nombre + "_cam")
    cam.type = "ORTHO"
    cam.ortho_scale = max(ancho_px, alto_px) / unidad_px
    ob = bpy.data.objects.new(nombre + "_cam", cam)
    ob.location = (ancho_px / unidad_px / 2, -alto_px / unidad_px / 2, 10)
    sc.collection.objects.link(ob)
    sc.camera = ob
    return sc


def _rect(sc, x0, y0, x1, y1, color, z=0.0, nombre="r"):
    """Rectangulo en unidades (y hacia abajo: 0 arriba)."""
    me = bpy.data.meshes.new(nombre)
    me.from_pydata([(x0, -y0, z), (x1, -y0, z), (x1, -y1, z), (x0, -y1, z)], [], [(0, 1, 2, 3)])
    me.materials.append(_mat("m_%.2f_%.2f_%.2f" % color, color))
    ob = bpy.data.objects.new(nombre, me)
    sc.collection.objects.link(ob)
    return ob


def _circulo(sc, cx, cy, r, color, z=0.0, lados=24, nombre="c"):
    import math
    me = bpy.data.meshes.new(nombre)
    v = [(cx, -cy, z)] + [(cx + r * math.cos(a * math.tau / lados), -cy + r * math.sin(a * math.tau / lados), z) for a in range(lados)]
    caras = [(0, i + 1, (i + 1) % lados + 1) for i in range(lados)]
    me.from_pydata(v, [], caras)
    me.materials.append(_mat("m_%.2f_%.2f_%.2f" % color, color))
    ob = bpy.data.objects.new(nombre, me)
    sc.collection.objects.link(ob)
    return ob


def _texto(sc, cuerpo, x, y, tam, color, fuente, z=0.01, centro=True, contorno=None, ancho_max=None):
    cu = bpy.data.curves.new("t", "FONT")
    cu.body = cuerpo
    cu.font = fuente
    cu.size = tam
    cu.align_x = "CENTER" if centro else "LEFT"
    cu.align_y = "CENTER"
    ob = bpy.data.objects.new("t", cu)
    ob.location = (x, -y, z)
    cu.materials.append(_mat("m_%.2f_%.2f_%.2f" % color, color))
    sc.collection.objects.link(ob)
    if ancho_max:
        bpy.context.view_layer.update() if bpy.context.scene == sc else None
        dims = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).dimensions
        if dims.x > ancho_max:
            cu.size = tam * ancho_max / dims.x
    if contorno:
        # El contorno: la misma letra corrida en 8 direcciones (curve.offset dejaba picos)
        import math
        grueso, color_c = contorno
        c2 = cu.copy()
        c2.materials.clear()
        c2.materials.append(_mat("m_%.2f_%.2f_%.2f" % color_c, color_c))
        for k in range(8):
            a = k * math.tau / 8
            ob2 = bpy.data.objects.new("t_borde", c2)
            ob2.location = (x + math.cos(a) * grueso, -y + math.sin(a) * grueso, z - 0.005)
            sc.collection.objects.link(ob2)
    return ob


def _render(sc, archivo):
    os.makedirs(SALIDA, exist_ok=True)
    sc.render.filepath = os.path.join(SALIDA, archivo)
    ventana = bpy.context.window
    anterior = ventana.scene
    ventana.scene = sc
    bpy.ops.render.render(write_still=True, scene=sc.name)
    ventana.scene = anterior
    for ob in list(sc.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.scenes.remove(sc)
    print("arte:", archivo)


def cartas():
    """Las cartas del tamano en que se ven: marco, el dibujo grande y abajo una banda crema donde
    OlPleyUI escribe el nombre con fonts/PixelifySans.ttf (texto de Blender a 96 px no se leia)."""
    u = 96  # px por unidad: una carta mide 1 x 1.5
    filas = (len(CARTAS) + COLUMNAS - 1) // COLUMNAS
    sc = _escena("Cartas", COLUMNAS * CARTA[0], filas * CARTA[1], u)
    emoji = _fuente("seguiemj.ttf")
    for i, (nombre, glifo, color) in enumerate(CARTAS):
        cx, cy = (i % COLUMNAS) * 1.0, (i // COLUMNAS) * 1.5
        tinaco = nombre == "El Tinaco"
        _rect(sc, cx, cy, cx + 1, cy + 1.5, (0.55, 0.12, 0.1) if not tinaco else (0.85, 0.7, 0.2), -0.02)   # el marco
        _rect(sc, cx + 0.05, cy + 0.05, cx + 0.95, cy + 1.45, CREMA, -0.015)
        _rect(sc, cx + 0.09, cy + 0.09, cx + 0.91, cy + 1.16, color, -0.01)
        # El dibujo ya no va aqui: es el pixel art de tools/sotano/dibujar_cartas.gd
        # (cartas_dibujos.png), que OlPleyUI pone encima del campo de color
    _render(sc, "cartas.png")


def calcomanias():
    """1024 x 1024: marquesina (arriba, 1024 x 256), puerta (512 x 512, izq), costado (512 x 512,
    der) y la tira de etiquetas (abajo, 1024 x 256). Las coordenadas UV salen de estas regiones
    (construir_sotano.gd / sotano.py, gabinete)."""
    u = 128
    sc = _escena("Calcomanias", 1024, 1024, u)
    emoji = _fuente("seguiemj.ttf")
    negra = _fuente("ariblk.ttf")
    impacto = _fuente("impact.ttf")
    rnd = random.Random(7)
    morado, verde, amarillo, rosa = (0.4, 0.1, 0.55), (0.2, 0.75, 0.2), (1.0, 0.85, 0.1), (0.95, 0.3, 0.6)
    # Marquesina: EL GORDO con contorno sobre manchas de colores
    _rect(sc, 0, 0, 8, 2, morado, -0.03)
    for _ in range(26):
        r = rnd.uniform(0.15, 0.55)
        _circulo(sc, rnd.uniform(r, 8 - r), rnd.uniform(r, 2 - r), r, rnd.choice((verde, rosa, (0.2, 0.5, 0.95), (0.95, 0.5, 0.1))), -0.025)
    for g, x in (("\U0001F352", 0.7), ("\U0001F3B2", 7.3)):
        _texto(sc, g, x, 1.0, 1.0, amarillo, emoji)
    _texto(sc, "EL GORDO", 4.0, 1.05, 1.45, amarillo, impacto, contorno=(0.06, (0.1, 0.02, 0.1)), ancho_max=5.6)
    # Puerta de abajo: EL GORDO chico, una ruleta y las cartas
    _rect(sc, 0, 2, 4, 6, (0.15, 0.1, 0.35), -0.03)
    for _ in range(18):
        r = rnd.uniform(0.15, 0.45)
        _circulo(sc, rnd.uniform(r, 4 - r), rnd.uniform(2 + r, 6 - r), r, rnd.choice((verde, rosa, morado, (0.95, 0.5, 0.1))), -0.025)
    import math
    for k in range(12):
        a0, a1 = k * math.tau / 12, (k + 1) * math.tau / 12
        me = bpy.data.meshes.new("ruleta")
        cx, cy, r = 2.0, 4.6, 1.05
        me.from_pydata([(cx, -cy, 0), (cx + r * math.cos(a0), -cy + r * math.sin(a0), 0), (cx + r * math.cos(a1), -cy + r * math.sin(a1), 0)], [], [(0, 1, 2)])
        col = (0.85, 0.1, 0.1) if k % 2 else (0.05, 0.05, 0.05)
        me.materials.append(_mat("m_%.2f_%.2f_%.2f" % col, col))
        ob = bpy.data.objects.new("ruleta", me)
        sc.collection.objects.link(ob)
    _circulo(sc, 2.0, 4.6, 0.25, (0.95, 0.8, 0.3), 0.005)
    _texto(sc, "EL GORDO", 2.0, 2.75, 0.85, amarillo, impacto, contorno=(0.05, (0.1, 0.02, 0.1)), ancho_max=3.4)
    # Costado: un revoltijo de cartas, sietes y cerezas
    _rect(sc, 4, 2, 8, 6, (0.1, 0.45, 0.25), -0.03)
    for _ in range(14):
        x, y = rnd.uniform(4.3, 7.7), rnd.uniform(2.3, 5.7)
        _rect(sc, x - 0.3, y - 0.42, x + 0.3, y + 0.42, CREMA, rnd.uniform(-0.02, -0.005))
        g = rnd.choice(("\U0001F413", "\U0001F335", "\U0001F480", "\U0001F514", "\U0001F608", "\u2764"))
        _texto(sc, g, x, y, 0.45, TINTA, emoji, z=0.0)
    for _ in range(5):
        _texto(sc, "7", rnd.uniform(4.4, 7.6), rnd.uniform(2.4, 5.6), 0.7, (0.9, 0.1, 0.1), impacto, z=0.01, contorno=(0.03, amarillo))
    # Etiquetas (abajo): "ACEPTA FICHAS", "PREMIOS EN FICHAS", "NO GOLPEAR", la del tinaco
    _rect(sc, 0, 6, 8, 8, (0.12, 0.12, 0.12), -0.03)
    etiquetas = [("ACEPTA\nFICHAS", amarillo, TINTA), ("PREMIOS\nEN FICHAS", amarillo, TINTA),
                 ("NO LE\nPEGUE", (0.9, 0.15, 0.1), CREMA), ("EL TINACO\nPAGA DOBLE", (0.2, 0.6, 0.9), CREMA)]
    for k, (texto, fondo, tinta) in enumerate(etiquetas):
        x0 = k * 2.0
        _rect(sc, x0 + 0.1, 6.1, x0 + 1.9, 7.9, fondo, -0.02)
        _texto(sc, texto, x0 + 1.0, 7.0, 0.32, tinta, negra)
    _render(sc, "calcomanias.png")


def pantalla():
    """256 x 192: la pantalla cuando nadie juega."""
    u = 64
    sc = _escena("Pantalla", 256, 192, u)
    emoji = _fuente("seguiemj.ttf")
    impacto = _fuente("impact.ttf")
    negra = _fuente("ariblk.ttf")
    _rect(sc, 0, 0, 4, 3, (0.05, 0.06, 0.25), -0.03)
    _texto(sc, "EL GORDO", 2.0, 0.35, 0.36, (1.0, 0.85, 0.1), impacto, contorno=(0.02, (0.6, 0.1, 0.1)), ancho_max=3.7)
    for k, g in enumerate(("\U0001F413", "\U0001F6E2", "\U0001F335")):
        x = 0.75 + k * 1.25
        _rect(sc, x - 0.5, 0.8, x + 0.5, 2.2, CREMA, -0.02)
        _texto(sc, g, x, 1.5, 0.7, TINTA, emoji)
    _texto(sc, "INSERTE FICHA", 2.0, 2.65, 0.28, (0.95, 0.95, 0.95), negra)
    _render(sc, "pantalla.png")


# Las cervezas de este mundo (parodias), para los carteles del Sotano: nombre, lema, glifo, fondo,
# letra. El orden es el de textures/sotano/anuncios.png (6 de 256 x 384, en fila) y el de
# Sotano.ANUNCIOS.
CERVEZAS = [
    ("TECATL", "La que aguanta\nla noche", "\U0001F985", (0.75, 0.08, 0.08), (1.0, 0.9, 0.75)),
    ("INDITA", "Bien fría,\nbien nuestra", "\U0001F33D", (0.95, 0.75, 0.1), (0.35, 0.12, 0.05)),
    ("CORONELA", "La que manda\nen la mesa", "\U0001F451", (0.1, 0.2, 0.55), (1.0, 0.85, 0.2)),
    ("MODELITO", "Para los de\nconfianza", "\U0001F37A", (0.85, 0.6, 0.15), (0.15, 0.08, 0.03)),
    ("PACÍFICA", "Oscura, del puerto\na tu sótano", "⚓", (0.08, 0.1, 0.12), (0.95, 0.75, 0.3)),
    ("3 CAGUAMAS", "por 10 fichas\nsolo aquí abajo", "\U0001F37E", (0.95, 0.95, 0.9), (0.7, 0.05, 0.05)),
]


def anuncios():
    """1536 x 384: seis carteles de cerveza de 256 x 384 (CERVEZAS)."""
    u = 128
    sc = _escena("Anuncios", 1536, 384, u)
    emoji = _fuente("seguiemj.ttf")
    impacto = _fuente("impact.ttf")
    negra = _fuente("ariblk.ttf")
    for k, (marca, lema, glifo, fondo, letra) in enumerate(CERVEZAS):
        x0 = k * 2.0
        _rect(sc, x0, 0, x0 + 2, 3, letra, -0.03)                    # el marco
        _rect(sc, x0 + 0.08, 0.08, x0 + 1.92, 2.92, fondo, -0.025)
        _circulo(sc, x0 + 1.0, 1.2, 0.62, letra, -0.02)
        _texto(sc, glifo, x0 + 1.0, 1.2, 0.85, fondo, emoji)
        _texto(sc, marca, x0 + 1.0, 0.42, 0.36, letra, impacto, ancho_max=1.75)
        _texto(sc, lema, x0 + 1.0, 2.35, 0.2, letra, negra, ancho_max=1.75)
    _render(sc, "anuncios.png")


def refri():
    """256 x 128: la marquesina luminosa del refri de la barra (arriba, 256 x 64: TECATL "BIEN
    HELADA" con el aguila) y abajo dos calcomanias de 64 x 64 (Indita y "SOLO BOTELLA CERRADA") y la
    tira de la rejilla del motor (128 x 64). La usa sotano.py (refri y congelador)."""
    u = 64
    sc = _escena("Refri", 256, 128, u)
    emoji = _fuente("seguiemj.ttf")
    impacto = _fuente("impact.ttf")
    negra = _fuente("ariblk.ttf")
    rojo, crema, oro = (0.78, 0.06, 0.06), (1.0, 0.92, 0.78), (0.95, 0.75, 0.2)
    # Marquesina
    _rect(sc, 0, 0, 4, 1, oro, -0.03)
    _rect(sc, 0.05, 0.05, 3.95, 0.95, rojo, -0.025)
    _circulo(sc, 0.5, 0.5, 0.36, crema, -0.02)
    _texto(sc, "\U0001F985", 0.5, 0.5, 0.48, rojo, emoji)
    _texto(sc, "TECATL", 2.25, 0.4, 0.5, crema, impacto, contorno=(0.025, (0.3, 0.02, 0.02)), ancho_max=2.6)
    _texto(sc, "BIEN HELADA", 2.25, 0.8, 0.17, oro, negra)
    # Calcomania Indita
    _rect(sc, 0, 1, 1, 2, (0.95, 0.75, 0.1), -0.03)
    _circulo(sc, 0.5, 1.45, 0.3, (0.35, 0.12, 0.05), -0.02)
    _texto(sc, "\U0001F33D", 0.5, 1.45, 0.36, (0.95, 0.75, 0.1), emoji)
    _texto(sc, "INDITA", 0.5, 1.88, 0.17, (0.35, 0.12, 0.05), impacto)
    # Calcomania "solo botella cerrada"
    _rect(sc, 1, 1, 2, 2, (0.95, 0.95, 0.9), -0.03)
    _texto(sc, "SOLO\nBOTELLA\nCERRADA", 1.5, 1.5, 0.15, rojo, negra)
    # Rejilla del motor: rayas negras sobre gris
    _rect(sc, 2, 1, 4, 2, (0.25, 0.25, 0.27), -0.03)
    for k in range(9):
        _rect(sc, 2.05, 1.07 + k * 0.1, 3.95, 1.12 + k * 0.1, (0.05, 0.05, 0.06), -0.02)
    _render(sc, "refri.png")


def banho():
    """El bano del Sotano, a lo Silent Hill (sotano.py banho()):
    textures/sotano/azulejo.png (128 x 128, se repite): azulejo blanco sucio con junta negra,
    manchas de humo y oxido escurrido; azulejo_piso.png (128 x 128): cuadros verde y negro gastados;
    banho.png (512 x 256): el espejo estrellado (0-256), el grafiti (256-512 arriba), la mancha
    (256-384 abajo) y la coladera (384-512 abajo)."""
    rnd = random.Random(13)
    negra = _fuente("ariblk.ttf")
    # Azulejo de pared: 4 x 4 cuadros con junta, cada uno un poco distinto, y lo sucio encima
    u = 32
    sc = _escena("Azulejo", 128, 128, u)
    _rect(sc, 0, 0, 4, 4, (0.12, 0.12, 0.1), -0.04)
    for i in range(4):
        for j in range(4):
            t = rnd.uniform(0.62, 0.78)
            _rect(sc, i + 0.06, j + 0.06, i + 0.94, j + 0.94, (t, t * 0.98, t * 0.9), -0.03)
            if rnd.random() < 0.25:    # azulejo estrellado
                _rect(sc, i + rnd.uniform(0.2, 0.6), j + 0.06, i + rnd.uniform(0.62, 0.7), j + 0.94, (0.2, 0.2, 0.18), -0.025)
    for _ in range(10):                # humo y mugre
        _circulo(sc, rnd.uniform(0, 4), rnd.uniform(0, 4), rnd.uniform(0.2, 0.6), (0.32, 0.3, 0.24), -0.02, lados=10)
    for _ in range(5):                 # oxido que escurre
        x = rnd.uniform(0.2, 3.8)
        _rect(sc, x, rnd.uniform(0, 1.5), x + rnd.uniform(0.06, 0.14), 4, (0.45, 0.22, 0.08), -0.015)
    _render(sc, "azulejo.png")
    # Piso: cuadros verde y negro gastados
    sc = _escena("AzulejoPiso", 128, 128, u)
    for i in range(4):
        for j in range(4):
            c = (0.18, 0.28, 0.2) if (i + j) % 2 == 0 else (0.06, 0.07, 0.06)
            _rect(sc, i, j, i + 1, j + 1, c, -0.03)
    for _ in range(14):
        _circulo(sc, rnd.uniform(0, 4), rnd.uniform(0, 4), rnd.uniform(0.15, 0.5), (0.22, 0.2, 0.14), -0.02, lados=9)
    _render(sc, "azulejo_piso.png")
    # Espejo, grafiti, mancha y coladera
    u = 64
    sc = _escena("Banho", 512, 256, u)
    import math
    _rect(sc, 0, 0, 4, 4, (0.35, 0.38, 0.38), -0.04)          # el marco
    _rect(sc, 0.15, 0.15, 3.85, 3.85, (0.42, 0.5, 0.52), -0.035)
    for _ in range(14):                                        # manchas del azogue
        _circulo(sc, rnd.uniform(0.3, 3.7), rnd.uniform(0.3, 3.7), rnd.uniform(0.1, 0.45), (0.2, 0.22, 0.2), -0.03, lados=8)
    cx, cy = 2.6, 1.4                                          # el golpe y sus grietas
    for k in range(11):
        a = k * math.tau / 11 + rnd.uniform(-0.2, 0.2)
        largo = rnd.uniform(1.2, 2.6)
        me = bpy.data.meshes.new("grieta")
        ancho = 0.035
        x1, y1 = cx + math.cos(a) * largo, cy + math.sin(a) * largo
        nx, ny = -math.sin(a) * ancho, math.cos(a) * ancho
        me.from_pydata([(cx + nx, -(cy + ny), -0.02), (cx - nx, -(cy - ny), -0.02), (x1, -y1, -0.02)], [], [(0, 1, 2)])
        me.materials.append(_mat("m_grieta", (0.9, 0.95, 0.95)))
        ob = bpy.data.objects.new("grieta", me)
        sc.collection.objects.link(ob)
    _circulo(sc, cx, cy, 0.25, (0.85, 0.9, 0.9), -0.015, lados=7)
    # Grafiti (arriba a la derecha)
    _rect(sc, 4, 0, 8, 2, (0.62, 0.6, 0.52), -0.04)
    _texto(sc, "NO ESTAS SOLO", 6.0, 0.6, 0.42, (0.45, 0.04, 0.04), negra, ancho_max=3.7)
    _texto(sc, "la virgen del tinaco\nte esta viendo", 6.0, 1.4, 0.22, (0.08, 0.08, 0.08), negra, ancho_max=3.6)
    # Mancha (abajo, 256-384): oscura, escurrida
    _rect(sc, 4, 2, 6, 4, (1, 1, 1), -0.04)
    _circulo(sc, 5.0, 3.0, 0.75, (0.22, 0.04, 0.03), -0.03, lados=12)
    for _ in range(9):
        _circulo(sc, 5.0 + rnd.uniform(-0.9, 0.9), 3.0 + rnd.uniform(-0.9, 0.9), rnd.uniform(0.1, 0.3), (0.25, 0.05, 0.03), -0.025, lados=8)
    # Coladera (384-512)
    _rect(sc, 6, 2, 8, 4, (0.1, 0.1, 0.1), -0.04)
    _circulo(sc, 7.0, 3.0, 0.8, (0.35, 0.33, 0.3), -0.03, lados=16)
    for k in range(5):
        _rect(sc, 6.4, 2.55 + k * 0.2, 7.6, 2.62 + k * 0.2, (0.05, 0.05, 0.05), -0.02)
    _render(sc, "banho.png")


def mesas():
    """Los panos de las mesas nuevas (sotano.py mesa_blackjack y mesa_ruleta):
    blackjack.png (512 x 256): la media luna vista desde arriba con la orilla recta arriba (el
    crupier): verde, "BLACKJACK PAGA 3 A 2" en arco, "EL CRUPIER SE PLANTA EN 17", tres circulos de
    apuesta; la parte fuera del arco va del color de la madera.
    ruleta.png (384 x 256): el pano de la ruleta (la rueda a la izquierda, sobre un circulo oscuro)
    con tres casillas grandes: ROJO, NEGRO y VERDE, y lo que pagan."""
    import math
    negra = _fuente("ariblk.ttf")
    impacto = _fuente("impact.ttf")
    verde, verde_osc = (0.08, 0.38, 0.16), (0.05, 0.25, 0.1)
    blanco, amarillo, madera = (0.95, 0.93, 0.85), (1.0, 0.82, 0.2), (0.45, 0.32, 0.2)
    u = 64
    sc = _escena("Blackjack", 512, 256, u)
    _rect(sc, 0, 0, 8, 4, madera, -0.05)
    # La media luna: centro arriba al medio (4, 0), radio 4 (la textura mide 2r x r)
    _circulo(sc, 4.0, 0.0, 4.0, verde, -0.04, lados=48)
    _circulo(sc, 4.0, 0.0, 2.2, verde_osc, -0.035, lados=40)
    _circulo(sc, 4.0, 0.0, 2.12, verde, -0.03, lados=40)
    for k, a in enumerate((140, 90, 40)):
        x, y = 4.0 + math.cos(math.radians(a)) * 3.1, math.sin(math.radians(a)) * 3.1
        _circulo(sc, x, y, 0.36, blanco, -0.025, lados=20)
        _circulo(sc, x, y, 0.3, verde, -0.02, lados=20)
    _texto(sc, "BLACKJACK PAGA 3 A 2", 4.0, 1.45, 0.34, amarillo, impacto, ancho_max=3.8)
    _texto(sc, "EL CRUPIER SE PLANTA EN 17", 4.0, 1.95, 0.17, blanco, negra, ancho_max=3.4)
    _texto(sc, "EL SÓTANO", 4.0, 0.55, 0.16, blanco, negra)
    _render(sc, "blackjack.png")
    # La ruleta
    sc = _escena("Ruleta", 384, 256, u)
    _rect(sc, 0, 0, 6, 4, verde, -0.05)
    _rect(sc, 0.06, 0.06, 5.94, 3.94, blanco, -0.045)
    _rect(sc, 0.1, 0.1, 5.9, 3.9, verde, -0.04)
    _circulo(sc, 1.6, 2.0, 1.45, verde_osc, -0.035, lados=40)
    for k, (nombre, fondo, letra, paga) in enumerate((("ROJO", (0.75, 0.06, 0.05), blanco, "PAGA 1 A 1"),
                                                       ("NEGRO", (0.06, 0.06, 0.06), blanco, "PAGA 1 A 1"),
                                                       ("VERDE", (0.05, 0.5, 0.15), amarillo, "PAGA 35 A 1"))):
        y0 = 0.35 + k * 1.15
        _rect(sc, 3.25, y0, 5.7, y0 + 1.0, blanco, -0.03)
        _rect(sc, 3.3, y0 + 0.05, 5.65, y0 + 0.95, fondo, -0.025)
        _texto(sc, nombre, 4.47, y0 + 0.42, 0.42, letra, impacto)
        _texto(sc, paga, 4.47, y0 + 0.8, 0.13, letra, negra)
    _render(sc, "ruleta.png")


def pantalla_juego():
    """384 x 288: el fondo del juego en la pantalla de EL GORDO (scripts/sotano/OlPleyUI.gd encima
    pone los carretes y los numeros). Marco de neon con focos, el logo, tres ventanas de carrete de
    96 x 168 en x = 36, 144, 252 (y de 51 a 219) con sus flechas de la linea de premio, y abajo
    tres recuadros (APUESTA, FICHAS, PREMIO) de 96 x 27 en x = 24, 144, 264, y = 249. Las medidas
    de abajo van en los px de la version de 256 x 192 (/ V): todo x1.5."""
    u = 48
    V = 32.0
    sc = _escena("PantallaJuego", 384, 288, u)
    emoji = _fuente("seguiemj.ttf")
    impacto = _fuente("impact.ttf")
    negra = _fuente("ariblk.ttf")
    morado, rosa, amarillo, oscuro = (0.18, 0.04, 0.3), (1.0, 0.3, 0.75), (1.0, 0.85, 0.1), (0.04, 0.02, 0.08)
    _rect(sc, 0, 0, 8, 6, rosa, -0.04)
    _rect(sc, 0.12, 0.12, 7.88, 5.88, morado, -0.035)
    for k in range(20):    # focos del marco
        for (x, y) in ((0.2 + k * 0.4, 0.06), (0.2 + k * 0.4, 5.94)):
            _circulo(sc, x, y, 0.09, amarillo if k % 2 == 0 else (1, 1, 1), -0.03, lados=6)
    _texto(sc, "EL GORDO", 4.0, 0.55, 0.7, amarillo, impacto, contorno=(0.04, (0.6, 0.05, 0.1)), ancho_max=6.2)
    for x in (0.55, 7.45):
        _texto(sc, "\U0001F6E2", x, 0.55, 0.6, amarillo, emoji)
    for k in range(3):
        x0 = (24 + k * 72) / V
        _rect(sc, x0 - 0.1, 34 / V - 0.1, x0 + 2 + 0.1, 146 / V + 0.1, amarillo, -0.03)
        _rect(sc, x0, 34 / V, x0 + 2, 146 / V, oscuro, -0.025)
    for x, g in ((0.35, "▶"), (7.65, "◀")):
        _texto(sc, g, x, 90 / V, 0.9, rosa, _fuente("seguisym.ttf"))
    for k, nombre in enumerate(("APUESTA", "FICHAS", "PREMIO")):
        x0 = (16 + k * 80) / V
        _texto(sc, nombre, x0 + 1.0, 156 / V, 0.3, amarillo, negra)
        _rect(sc, x0, 166 / V, x0 + 2, 184 / V, oscuro, -0.03)
    _render(sc, "pantalla_juego.png")


def baraja():
    """896 x 384: la baraja del poker, 13 columnas (2..10, J, Q, K, A) x 4 filas (picas, corazones,
    diamantes, treboles) de 64 x 96, y en la columna 14 el reverso (El Tinaco sobre rojo vino) arriba.
    Sale a textures/sotano/baraja.png; scripts/sotano/Holdem.gd usa el mismo orden."""
    u = 64
    sc = _escena("Baraja", 896, 384, u)
    simbolos = _fuente("seguisym.ttf")
    negra = _fuente("ariblk.ttf")
    emoji = _fuente("seguiemj.ttf")
    rangos = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
    palos = [("♠", TINTA), ("♥", (0.8, 0.08, 0.1)), ("♦", (0.8, 0.08, 0.1)), ("♣", TINTA)]
    caras = {"J": "\U0001F934", "Q": "\U0001F478", "K": "\U0001F451", "A": None}
    for fila, (palo, color) in enumerate(palos):
        for col, r in enumerate(rangos):
            x0, y0 = col * 1.0, fila * 1.5
            _rect(sc, x0, y0, x0 + 1, y0 + 1.5, (0.2, 0.2, 0.2), -0.02)
            _rect(sc, x0 + 0.04, y0 + 0.04, x0 + 0.96, y0 + 1.46, CREMA, -0.015)
            _texto(sc, r, x0 + 0.22, y0 + 0.2, 0.26 if r != "10" else 0.2, color, negra)
            _texto(sc, palo, x0 + 0.22, y0 + 0.47, 0.5, color, simbolos)
            _texto(sc, r, x0 + 0.78, y0 + 1.3, 0.26 if r != "10" else 0.2, color, negra)
            if caras.get(r):
                _texto(sc, caras[r], x0 + 0.55, y0 + 0.82, 0.55, color, emoji)
            else:
                _texto(sc, palo, x0 + 0.55, y0 + 0.85, 1.5 if r == "A" else 1.1, color, simbolos)
    # El reverso
    x0 = 13.0
    _rect(sc, x0, 0, x0 + 1, 1.5, (0.2, 0.2, 0.2), -0.02)
    _rect(sc, x0 + 0.04, 0.04, x0 + 0.96, 1.46, (0.45, 0.05, 0.12), -0.015)
    _rect(sc, x0 + 0.1, 0.1, x0 + 0.9, 1.4, (0.95, 0.75, 0.25), -0.012)
    _rect(sc, x0 + 0.14, 0.14, x0 + 0.86, 1.36, (0.45, 0.05, 0.12), -0.01)
    _texto(sc, "\U0001F6E2", x0 + 0.5, 0.75, 0.55, (0.95, 0.75, 0.25), emoji)
    _render(sc, "baraja.png")


def frutas():
    """512 x 512 para el adorno de la maquinita de frutas (tools/blender/sotano/maquinita.py):
    copete (arriba, 512 x 128), costado alto (izq) y costado bajo (der) de 256 x 256, y abajo tres
    etiquetas de 128 x 128 y los colores lisos (rojo, verde, cromo, negro) en la ultima. Sale a
    textures/maquinita/adorno_frutas.png."""
    u = 64
    sc = _escena("Frutas", 512, 512, u)
    emoji = _fuente("seguiemj.ttf")
    negra = _fuente("ariblk.ttf")
    impacto = _fuente("impact.ttf")
    rnd = random.Random(11)
    rojo, azul, amarillo, naranja = (0.8, 0.1, 0.1), (0.12, 0.35, 0.85), (1.0, 0.85, 0.1), (0.95, 0.5, 0.1)
    frutas = ("\U0001F352", "\U0001F353", "\U0001F34B", "\U0001F349", "\U0001F34A", "\U0001F514", "\U0001F347")
    # Copete: el letrero con sus frutas
    _rect(sc, 0, 0, 8, 2, azul, -0.03)
    _rect(sc, 0, 1.75, 8, 2, rojo, -0.025)
    _texto(sc, "CÓCTEL DE FRUTAS", 4.0, 0.85, 0.9, amarillo, impacto, contorno=(0.05, rojo), ancho_max=6.6)
    for k, g in enumerate(frutas[:4]):
        _texto(sc, g, 0.45 if k < 2 else 7.55, 0.55 + (k % 2) * 0.75, 0.55, amarillo, emoji)
    # Costado alto: frutas regadas sobre naranja
    _rect(sc, 0, 2, 4, 6, naranja, -0.03)
    for _ in range(12):
        x, y = rnd.uniform(0.4, 3.6), rnd.uniform(2.4, 5.6)
        _circulo(sc, x, y, 0.42, (1.0, 0.95, 0.85), -0.02)
        _texto(sc, rnd.choice(frutas), x, y, 0.55, (0.15, 0.08, 0.05), emoji)
    _texto(sc, "7", 2.0, 4.0, 1.4, rojo, impacto, z=0.01, contorno=(0.05, amarillo))
    # Costado bajo: la fresa grande y "¡GANA!"
    _rect(sc, 4, 2, 8, 6, (0.95, 0.2, 0.35), -0.03)
    for _ in range(10):
        r = rnd.uniform(0.15, 0.4)
        _circulo(sc, rnd.uniform(4 + r, 8 - r), rnd.uniform(2 + r, 6 - r), r, rnd.choice((amarillo, naranja, (1.0, 0.6, 0.7))), -0.025)
    _circulo(sc, 6.0, 3.7, 1.2, (1.0, 0.95, 0.85), -0.02)
    _texto(sc, "\U0001F353", 6.0, 3.7, 1.7, rojo, emoji)
    _texto(sc, "¡GANA!", 6.0, 5.35, 0.75, amarillo, impacto, contorno=(0.04, (0.3, 0.05, 0.1)))
    # Etiquetas
    etiquetas = [("ACEPTA\nMONEDAS\nDE $1", amarillo, (0.1, 0.08, 0.06)), ("NO LE\nPEGUE", rojo, (1, 1, 1)),
                 ("SE PAGA\nEN EL\nMOSTRADOR", (0.95, 0.95, 0.9), (0.1, 0.08, 0.06))]
    for k, (texto, fondo, tinta) in enumerate(etiquetas):
        _rect(sc, k * 2.0 + 0.08, 6.08, k * 2.0 + 1.92, 7.92, fondo, -0.02)
        _texto(sc, texto, k * 2.0 + 1.0, 7.0, 0.3, tinta, negra)
    # Colores lisos: rojo, verde, cromo, negro (2 x 2 en la ultima casilla)
    for k, c in enumerate(((0.85, 0.1, 0.12), (0.2, 0.65, 0.2), (0.78, 0.8, 0.84), (0.06, 0.06, 0.07))):
        x0, y0 = 6.0 + (k % 2), 6.0 + (k // 2)
        _rect(sc, x0, y0, x0 + 1, y0 + 1, c, -0.02)
    global SALIDA
    anterior = SALIDA
    SALIDA = os.path.join(RAIZ, "textures", "maquinita")
    _render(sc, "adorno_frutas.png")
    SALIDA = anterior


if __name__ == "arte":
    for hacer in (globals().get("SOLO") or ("cartas", "calcomanias", "pantalla")):
        globals()[hacer]()
