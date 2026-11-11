# Las carpas del tianguis (lona sobre tubos) que usa scripts/mapa/Tianguis.gd: cinco tipos (una
# agua, panza, dos aguas, rayas, remendada). Frente hacia +Y (en Godot -Z), espalda en y = 0, y
# los huecos de lona como materiales lona_0/1/2 que Godot pinta (textura: textura_lona.py).
#   blender --background --python carpas.py                      fotos de muestra en SALIDA
#   MODO=una TIPO=panza blender --background --python carpas.py  foto de una
#   MODO=exportar DESTINO=<proyecto>/models/tianguis/carpas blender --background --python carpas.py
# (en Linux con Flatpak: flatpak run --env=MODO=exportar --env=DESTINO=... org.blender.Blender ...)
# Blender Z arriba; cada carpa con el pasillo hacia +Y (su frente) y el ancho a lo largo de X.
import bpy, bmesh, math, random, os
from mathutils import Vector

SALIDA = os.environ.get("SALIDA", os.path.expanduser("~/tianguis_borrador"))
random.seed(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
esc = bpy.context.scene

# Colores de lona (los de piezas.LONAS mas desteñidos y rayas de mercado)
LONAS = {"rojo": (0.8, 0.18, 0.2), "azul": (0.15, 0.4, 0.78), "amarillo": (0.92, 0.75, 0.15),
         "verde": (0.2, 0.62, 0.32), "rosa": (0.9, 0.42, 0.62), "naranja": (0.92, 0.5, 0.15),
         "azul_palido": (0.45, 0.62, 0.8), "blanco": (0.85, 0.85, 0.82), "lila": (0.55, 0.4, 0.7)}

_mats = {}
def mat(nombre, color, rugoso=0.8, metal=0.0):
    if nombre in _mats:
        return _mats[nombre]
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rugoso
    b.inputs["Metallic"].default_value = metal
    # Las lonas dejan pasar algo de luz, como en el tianguis
    if nombre.startswith("lona"):
        b.inputs["Subsurface Weight"].default_value = 0.0
        b.inputs["Transmission Weight"].default_value = 0.05
    _mats[nombre] = m
    return m

FIERRO = mat("fierro", (0.42, 0.4, 0.38), 0.55, 0.7)
MESA = mat("madera", (0.45, 0.32, 0.2), 0.9)
PISO = mat("asfalto", (0.22, 0.22, 0.23), 0.95)
BANQ = mat("banqueta", (0.55, 0.53, 0.5), 0.95)
GENTE = mat("persona", (0.15, 0.15, 0.18), 0.8)
CUERDA = mat("cuerda", (0.85, 0.8, 0.6), 0.9)


def uv_metros(bm, plano="xy"):
    capa = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            c = l.vert.co
            l[capa].uv = (c.x, c.y) if plano == "xy" else (c.y, c.z)


def objeto(nombre, bm, mats, padre=None, uv=False):
    if uv:
        uv_metros(bm)
        # el faldon (cara vertical) en el plano yz
        capa = bm.loops.layers.uv.verify()
        for f in bm.faces:
            if abs(f.normal.z) < 0.3:
                for l in f.loops:
                    l[capa].uv = (l.vert.co.y, l.vert.co.z)
    me = bpy.data.meshes.new(nombre)
    bm.to_mesh(me); bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(nombre, me)
    esc.collection.objects.link(ob)
    if padre:
        ob.parent = padre
    for p in me.polygons:
        p.use_smooth = True
    return ob


def tubo(bm, a, b, r=0.024, lados=6):
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = d.to_track_quat('Z', 'Y')
    res = bmesh.ops.create_cone(bm, cap_ends=False, segments=lados, radius1=r, radius2=r, depth=d.length)
    for v in res["verts"]:
        v.co = rot @ v.co + (a + b) / 2


def caja(bm, c, t, mi=0):
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        v.co = Vector((v.co.x * t[0], v.co.y * t[1], v.co.z * t[2])) + Vector(c)
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = mi


def lona(bm, alto_f, ancho, y0, y1, z0, z1, panza=0.0, cresta=None, rayas=None, mi_base=0, nx=10, ny=8, onda=0.0):
    """Lona de x -ancho/2..ancho/2, y0 (atras, altura z0) a y1 (pasillo, altura z1).
    panza: cuanto cuelga al centro; cresta: (y, altura) para dos aguas; rayas: n de franjas a lo largo de y."""
    vs = []
    for j in range(ny + 1):
        v = j / ny
        y = y0 + (y1 - y0) * v
        if cresta:
            yc, zc = cresta
            z = z0 + (zc - z0) * (y - y0) / (yc - y0) if y <= yc else zc + (z1 - zc) * (y - yc) / (y1 - yc)
        else:
            z = z0 + (z1 - z0) * v
        fila = []
        for i in range(nx + 1):
            u = i / nx
            x = -ancho / 2 + ancho * u
            zz = z + 0.04 - panza * math.sin(math.pi * u) * math.sin(math.pi * v)
            # Arrugas y orillas que caen un poco entre amarre y amarre
            zz -= onda * (0.5 + 0.5 * math.sin(u * math.pi * 6 + v * 3)) * (1 if j in (0, ny) else 0.3)
            fila.append(bm.verts.new((x, y, zz)))
        vs.append(fila)
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
            f.material_index = mi_base + (((j * rayas) // ny) % 2 if rayas else 0)
    return vs


def faldon(bm, x, y0, y1, z, caida, mi):
    """Lona colgando de un lado (de sol), con la orilla de abajo dispareja."""
    n = 4
    arriba = [bm.verts.new((x, y0 + (y1 - y0) * k / n, z)) for k in range(n + 1)]
    abajo = [bm.verts.new((x + 0.03 * math.sin(k), y0 + (y1 - y0) * k / n, z - caida * (0.8 + 0.25 * math.sin(k * 2.1)))) for k in range(n + 1)]
    for k in range(n):
        bm.faces.new((arriba[k], arriba[k + 1], abajo[k + 1], abajo[k])).material_index = mi


def carpa(nombre, tipo, ancho, fondo, colores, en=(0, 0, 0), giro=0.0):
    """fondo: de la pared/banqueta al tubo del frente; el vuelo sale ~1.1 m mas hacia el pasillo.
    Atras baja (2.1 m), al frente sube (2.5) y el vuelo llega a 2.65: las lonas de las dos filas
    se juntan arriba del pasillo."""
    raiz = bpy.data.objects.new(nombre, None)
    esc.collection.objects.link(raiz)
    raiz.location = en
    raiz.rotation_euler.z = giro
    za, zf, vuelo, zv = 2.1, 2.5, 1.1, 2.65
    ya, yf = 0.0, fondo
    bm = bmesh.new()
    xs = (-ancho / 2 + 0.05, ancho / 2 - 0.05)
    for x in xs:
        tubo(bm, (x, ya, 0), (x, ya, za))
        tubo(bm, (x, yf, 0), (x, yf, zf + (0.35 if tipo == "dos_aguas" else 0)))
        tubo(bm, (x, ya, za), (x, yf, zf))              # larguero
        tubo(bm, (x, yf, zf), (x, yf + vuelo, zv))      # brazo del vuelo
    tubo(bm, (xs[0], ya, za), (xs[1], ya, za))
    tubo(bm, (xs[0], yf, zf), (xs[1], yf, zf))
    tubo(bm, (xs[0], yf + vuelo, zv), (xs[1], yf + vuelo, zv))
    if tipo == "dos_aguas":
        tubo(bm, (xs[0], fondo * 0.6, zf + 0.35), (xs[1], fondo * 0.6, zf + 0.35))
    # Mesa (tablon sobre burros) para escala; al exportar no va: en Godot el puesto pone la suya
    if not EXPORTAR:
      caja(bm, (0, fondo * 0.55, 0.82), (ancho - 0.5, 0.9, 0.05), 1)
    for x in ((-ancho / 2 + 0.45, ancho / 2 - 0.45) if not EXPORTAR else ()):
        caja(bm, (x, fondo * 0.55, 0.4), (0.06, 0.8, 0.8), 1)
    objeto(nombre + "_tubos", bm, [FIERRO, MESA], raiz)

    bm = bmesh.new()
    # Los huecos de lona se llaman lona_0/1/2: en Godot cada carpa les pone su color
    mats = [mat("lona_%d" % i, LONAS[c]) for i, c in enumerate(colores)] if EXPORTAR else [mat("lona_" + c, LONAS[c]) for c in colores]
    sobra = 0.15  # la lona es un poco mas ancha que los tubos
    if tipo == "una_agua":
        lona(bm, 0, ancho + sobra, ya - 0.25, yf + vuelo + 0.1, za - 0.05, zv + 0.02, panza=0.05, onda=0.03)
    elif tipo == "panza":
        lona(bm, 0, ancho + sobra, ya - 0.25, yf + vuelo + 0.1, za - 0.05, zv + 0.02, panza=0.32, onda=0.05)
    elif tipo == "dos_aguas":
        lona(bm, 0, ancho + sobra, ya - 0.3, yf + vuelo + 0.1, za - 0.1, zv + 0.02, panza=0.06,
             cresta=(fondo * 0.6, zf + 0.42), onda=0.03, ny=10)
    elif tipo == "rayas":
        lona(bm, 0, ancho + sobra, ya - 0.25, yf + vuelo + 0.1, za - 0.05, zv + 0.02, panza=0.12,
             rayas=8, onda=0.03, ny=16)
    elif tipo == "remendada":
        # Dos lonas encimadas: una vieja atras y otra de otro color al frente, y un faldon de sol
        lona(bm, 0, ancho + sobra, ya - 0.25, yf * 0.6, za - 0.05, za + (zf - za) * 0.6, panza=0.1, onda=0.04)
        lona(bm, 0, ancho + 0.3, yf * 0.5, yf + vuelo + 0.1, za + (zf - za) * 0.5 + 0.03, zv + 0.03,
             panza=0.15, onda=0.05, mi_base=1)
        faldon(bm, ancho / 2 + 0.08, yf * 0.2, yf + 0.3, za + 0.1, 1.1, 2 if len(colores) > 2 else 0)
    objeto(nombre + "_lona", bm, mats, raiz, uv=True)
    bm = bmesh.new()
    for x in xs:
        tubo(bm, (x * 1.03, yf + vuelo + 0.08, zv - 0.02), (x, yf, 1.6), r=0.008, lados=4)
    objeto(nombre + "_cuerdas", bm, [CUERDA], raiz)
    return raiz


def persona(en):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.22, radius2=0.18, depth=1.45)
    for v in bm.verts:
        v.co.z += 0.725
    res = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.13)
    for v in res["verts"]:
        v.co.z += 1.6
    ob = objeto("persona", bm, [GENTE])
    ob.location = en


# --- Las variantes, una al lado de otra para la hoja de muestras ---
TIPOS = [("una_agua", 3.0, 2.2, ["rosa"]),
         ("panza", 3.0, 2.2, ["azul"]),
         ("dos_aguas", 3.5, 2.4, ["amarillo"]),
         ("rayas", 4.0, 2.2, ["blanco", "azul"]),
         ("remendada", 3.0, 2.2, ["naranja", "verde", "azul_palido"])]


def luz_y_mundo():
    w = bpy.data.worlds.new("cielo"); esc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.7, 0.9, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    sol = bpy.data.lights.new("sol", "SUN"); sol.energy = 4.0; sol.angle = 0.1
    so = bpy.data.objects.new("sol", sol); esc.collection.objects.link(so)
    so.rotation_euler = (math.radians(40), math.radians(15), math.radians(30))
    esc.render.engine = "CYCLES"
    esc.cycles.device = "CPU"
    esc.cycles.samples = 48
    esc.cycles.use_denoising = True
    esc.render.resolution_x, esc.render.resolution_y = 1280, 720
    esc.view_settings.view_transform = "Standard"


def camara(pos, mira, lente=28):
    c = bpy.data.cameras.new("cam"); c.lens = lente
    co = bpy.data.objects.new("cam", c); esc.collection.objects.link(co)
    co.location = pos
    co.rotation_euler = (Vector(mira) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
    esc.camera = co
    return co


def render(archivo):
    esc.render.filepath = os.path.join(SALIDA, archivo)
    bpy.ops.render.render(write_still=True)
    print("RENDER", esc.render.filepath)


def suelo(x0, x1, y0, y1, banqueta=None):
    bm = bmesh.new()
    caja(bm, ((x0 + x1) / 2, (y0 + y1) / 2, -0.05), (x1 - x0, y1 - y0, 0.1))
    objeto("piso", bm, [PISO])
    if banqueta:
        for ya, yb in banqueta:
            bm = bmesh.new()
            caja(bm, ((x0 + x1) / 2, (ya + yb) / 2, 0.075), (x1 - x0, yb - ya, 0.15))
            objeto("banqueta", bm, [BANQ])


luz_y_mundo()
modo = os.environ.get("MODO", "muestras")
EXPORTAR = modo == "exportar"

if modo == "exportar":
    dest = os.environ["DESTINO"]
    for t, an, fo, col in TIPOS:
        for o in list(esc.objects):
            bpy.data.objects.remove(o)
        _mats.clear()
        for m in list(bpy.data.materials):
            bpy.data.materials.remove(m)
        globals().update(FIERRO=mat("fierro", (0.42, 0.4, 0.38), 0.55, 0.7), MESA=mat("madera", (0.45, 0.32, 0.2), 0.9),
                         CUERDA=mat("cuerda", (0.85, 0.8, 0.6), 0.9))
        carpa("carpa_" + t, t, an, fo, col)
        ruta = os.path.join(dest, f"carpa_{t}.glb")
        bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", export_apply=True, export_materials="EXPORT")
        print("GLB", ruta, an, fo)
    raise SystemExit

if modo == "una":
    t = os.environ["TIPO"]
    an, fo, col = next((a, f, c) for n, a, f, c in TIPOS if n == t)
    suelo(-5, 5, -3, 6)
    carpa(t, t, an, fo, col)
    persona((an / 2 + 0.5, fo + 1.6, 0))
    esc.render.resolution_x, esc.render.resolution_y = 800, 600
    esc.cycles.samples = 32
    camara((-3.6, fo + 5.2, 3.0), (0.2, fo * 0.5, 1.4), 24)
    render(f"carpa_{t}.png")
    raise SystemExit

if modo == "muestras":
    suelo(-14, 14, -3, 6)
    x = -11.0
    for i, (t, an, fo, col) in enumerate(TIPOS):
        carpa(t, t, an, fo, col, en=(x + an / 2, 0, 0))
        x += an + 1.3
    persona((-6.5, 3.6, 0))
    camara((0, 13.5, 6.0), (0, 0.8, 1.4), 24)
    render("muestras_frente.png")
    camara((0, -9.5, 4.5), (0, 1.0, 1.6), 24)
    render("muestras_atras.png")

elif modo == "pasillo":
    # Un tramo corto: dos filas encaradas, banquetas a los lados, pasillo libre en medio
    calle, banq, pasillo = 10.0, 1.5, 2.4
    fondo = (calle - pasillo) / 2 - 1.1  # el vuelo de 1.1 llega casi a media calle
    suelo(-10, 10, -calle / 2 - banq, calle / 2 + banq, [(-calle / 2 - banq, -calle / 2), (calle / 2, calle / 2 + banq)])
    for fila, (yb, giro) in enumerate(((-calle / 2, 0.0), (calle / 2, math.pi))):
        x = -9.5 + fila * 0.8
        while x < 9.0:
            t, an, fo, col = random.choice(TIPOS)
            an = an + random.uniform(-0.3, 0.3)
            if x + an > 9.6:
                break
            col = [random.choice(list(LONAS)) for _ in col] if t != "rayas" else ["blanco", random.choice(["azul", "rojo", "verde"])]
            yy = yb + random.uniform(0.0, 0.25) * (1 if giro == 0 else -1)
            carpa(f"{t}_{fila}_{x:.1f}", t, an, fondo, col,
                  en=(x + an / 2, yy, 0), giro=giro + random.uniform(-0.04, 0.04))
            x += an + random.uniform(0.0, 0.2)
    for p in ((-3, 0.3, 0), (1.5, -0.4, 0), (5, 0.2, 0)):
        persona(p)
    camara((-8.5, -0.2, 1.65), (4, 0.2, 1.8), 20)
    render("pasillo_jugador.png")
    camara((0, -9, 13), (0, 0, 0), 22)
    render("pasillo_arriba.png")

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SALIDA, f"carpas_{modo}.blend"))
