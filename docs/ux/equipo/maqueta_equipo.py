# Maqueta de la pantalla de Equipo, v3: armas de fuego, dos amuletos y dos escondidos por fila
# (640x480, luego x2 sin suavizar)
import sys, random, math
from PIL import Image, ImageDraw, ImageFont
R, SAL, UI = sys.argv[1], sys.argv[2], sys.argv[3]
W, H = 640, 480
ORO, ORO_OSC, CREMA, GRIS, VERDE = (222, 172, 70), (140, 100, 35), (240, 228, 200), (150, 140, 125), (170, 220, 140)
fuente = lambda t: ImageFont.truetype(R + "/fonts/PixelifySans.ttf", t)
RUTAS = {"la_tinaquera": UI + "/armas/la_tinaquera.png", "la_chicharra": UI + "/armas/la_chicharra.png",
         "la_matraca": UI + "/armas/la_matraca.png"}
for m in ["resortera", "ballesta", "pistola_mk23", "pistola_colt", "cuerno_de_chivo"]:
    RUTAS[m] = R + "/models/armas/%s/preview.png" % m

def ruta(i):
    return RUTAS.get(i, R + "/models/taller/%s/preview.png" % i)

def icono(i, lado, oscuro=False):
    im = Image.open(ruta(i)).convert("RGBA")
    px = im.load()
    fondo = px[2, 2][:3]
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if abs(r - fondo[0]) + abs(g - fondo[1]) + abs(b - fondo[2]) < 40:
                px[x, y] = (0, 0, 0, 0)
    im = im.crop(im.getbbox())
    if max(im.width, im.height) > 2.2 * min(im.width, im.height):
        im = im.rotate(40 if im.width > im.height else -40, resample=Image.NEAREST, expand=True)
        im = im.crop(im.getbbox())
    k = lado / max(im.width, im.height)
    im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.NEAREST)
    if oscuro:
        a = im.split()[3]
        im = Image.new("RGBA", im.size, (84, 66, 54, 255))
        im.putalpha(a.point(lambda v: 255 if v > 60 else 0))
    return im

img = Image.new("RGB", (W, H), (20, 18, 26))
d = ImageDraw.Draw(img)
random.seed(3)
for i in range(120):
    d.point((random.randrange(W), random.randrange(H)), fill=(60, 56, 70))
panel = (16, 40, W - 16, H - 14)
cap = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(cap).rounded_rectangle(panel, 10, fill=(38, 26, 20, 235))
img.paste(cap, (0, 0), cap)
d = ImageDraw.Draw(img)
for i in range(2500):
    x, y = random.randrange(panel[0] + 6, panel[2] - 6), random.randrange(panel[1] + 6, panel[3] - 6)
    img.putpixel((x, y), tuple(max(0, v - 8) for v in img.getpixel((x, y))))
d.rounded_rectangle(panel, 10, outline=ORO, width=3)
d.rounded_rectangle((panel[0] + 6, panel[1] + 6, panel[2] - 6, panel[3] - 6), 7, outline=ORO_OSC, width=1)

f = fuente(13)
d.text((70, 14), "Q", font=fuente(14), fill=GRIS)
d.text((W - 80, 14), "E", font=fuente(14), fill=GRIS)
for x, t in zip([150, 250, 350, 450], ["Mochila", "EQUIPO", "Mapa", "Libreta"]):
    activa = t == "EQUIPO"
    d.rounded_rectangle((x - 44, 8, x + 44, 34), 6, fill=(70, 45, 28) if activa else (34, 26, 24), outline=ORO if activa else ORO_OSC, width=2 if activa else 1)
    d.text((x - d.textlength(t, font=f) / 2, 13), t, font=f, fill=ORO if activa else GRIS)

def estrella(cx, cy, r, color):
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=color)

# --- Rejilla. Cuerpo a cuerpo, armadura, botas y amuletos van por tier (I-IV); las de fuego se
# compran, de menos a mas. Las dos ultimas columnas (★) son lo escondido en el mapa
GRUPOS = [
    [("Filo", ["machete_oxidado", "machete_reforzado", "machete_canero", "macheton_84"]),
     ("Pesadas", ["tubo", "marro", "bate_clavos", "femur_cobalto"])],
    [("De fuego", ["resortera", "ballesta", "pistola_mk23", "pistola_colt"]),
     ("", ["la_tinaquera", "la_chicharra", "cuerno_de_chivo", "la_matraca"])],
    [("Armadura", ["coderas_rodilleras", "faja", "chaleco_llanta", "chamarra_machetes"]),
     ("Botas", ["tenis_tianguis", "botas_obra", "botas_casquillo", "botas_84"])],
    [("Amuletos", ["escapulario", "collar_obsidiana", "medalla_san_judas", "liston_virgen"]),
     ("", ["ojo_venado", "medalla_virgen", "pulsera_san_benito", "collar_santa_muerte"])],
]
TIENES = {"machete_oxidado", "machete_reforzado", "tubo", "resortera", "pistola_mk23", "coderas_rodilleras", "faja",
          "chaleco_llanta", "tenis_tianguis", "botas_obra", "escapulario", "ojo_venado", "collar_obsidiana",
          "medalla_virgen", "pulsera_san_benito"}
ENCONTRADO = {(0, 1)}   # (fila, columna escondida) ya encontrado: el Machete de la Llorona, inventado
PUESTO = {"machete_reforzado", "pistola_mk23", "chaleco_llanta", "botas_obra", "collar_obsidiana", "escapulario"}
CURSOR = "pistola_mk23"
S, G = 33, 5
x0, y0 = 100, 82
for c, t in enumerate(["I", "II", "III", "IV"]):
    d.text((x0 + c * (S + G) + S / 2 - d.textlength(t, font=fuente(12)) / 2, y0 - 16), t, font=fuente(12), fill=GRIS)
for c in (4, 5):
    estrella(x0 + c * (S + G) + S / 2 + 2, y0 - 9, 6, ORO)
pos = {}
y = y0
fila = 0
for g, grupo in enumerate(GRUPOS):
    for nombre, ids in grupo:
        if nombre:
            d.text((x0 - 9 - d.textlength(nombre, font=fuente(13)), y + 9), nombre, font=fuente(13), fill=CREMA)
        for c, i in enumerate(ids):
            x = x0 + c * (S + G)
            pos[i] = (x, y)
            tiene = i in TIENES
            d.rounded_rectangle((x, y, x + S, y + S), 5, fill=(58, 40, 30) if tiene else (30, 22, 20), outline=(96, 70, 44), width=1)
            ic = icono(i, S - 6, oscuro=not tiene)
            img.paste(ic, (x + (S - ic.width) // 2, y + (S - ic.height) // 2), ic)
            if i in PUESTO:
                d.rounded_rectangle((x - 1, y - 1, x + S + 1, y + S + 1), 6, outline=ORO, width=2)
                d.polygon([(x + S - 10, y + 1), (x + S - 1, y + 1), (x + S - 1, y + 10)], fill=ORO)
        for e in range(2):
            x = x0 + (4 + e) * (S + G) + 4
            if (fila, e) in ENCONTRADO:
                d.rounded_rectangle((x, y, x + S, y + S), 5, fill=(58, 40, 30), outline=ORO_OSC, width=1)
                ic = icono("machete_oxidado", S - 6)
                ic = Image.merge("RGBA", (*[c.point(lambda v: min(255, int(v * 0.6 + 60))) for c in ic.split()[:3]], ic.split()[3]))
                img.paste(ic, (x + (S - ic.width) // 2, y + (S - ic.height) // 2), ic)
                estrella(x + S - 6, y + 6, 4, ORO)
                continue
            for k in range(0, S, 6):
                d.line([(x + k, y), (x + min(k + 3, S), y)], fill=ORO_OSC)
                d.line([(x + k, y + S), (x + min(k + 3, S), y + S)], fill=ORO_OSC)
                d.line([(x, y + k), (x, y + min(k + 3, S))], fill=ORO_OSC)
                d.line([(x + S, y + k), (x + S, y + min(k + 3, S))], fill=ORO_OSC)
            d.text((x + S / 2 - d.textlength("?", font=fuente(17)) / 2, y + 6), "?", font=fuente(17), fill=ORO_OSC)
        y += S + G
        fila += 1
    y += 6
d = ImageDraw.Draw(img)
estrella(x0 + 4, y + 2, 5, ORO_OSC)
d.text((x0 + 12, y - 5), "escondidos en el mapa: 1 de 16", font=fuente(11), fill=ORO_OSC)

cx, cy = pos[CURSOR]
for (ax, ay, sx, sy) in [(cx - 4, cy - 4, 1, 1), (cx + S + 4, cy - 4, -1, 1), (cx - 4, cy + S + 4, 1, -1), (cx + S + 4, cy + S + 4, -1, -1)]:
    d.line([(ax, ay), (ax + 8 * sx, ay)], fill=(255, 236, 120), width=3)
    d.line([(ax, ay), (ax, ay + 8 * sy)], fill=(255, 236, 120), width=3)

# --- Derecha: el compa con sus seis puestos
caja = (352, 60, 610, 246)
d.rounded_rectangle(caja, 8, fill=(24, 18, 16), outline=ORO_OSC, width=1)
fig = Image.open(R + "/models/personajes/protagonistas/el_compa/preview.png").convert("RGBA").crop((60, 40, 200, 345))
px = fig.load()
fondo = px[2, 2][:3]
for yy in range(fig.height):
    for xx in range(fig.width):
        r_, g_, b_, a_ = px[xx, yy]
        if abs(r_ - fondo[0]) + abs(g_ - fondo[1]) + abs(b_ - fondo[2]) < 30:
            px[xx, yy] = (0, 0, 0, 0)
fig = fig.crop(fig.getbbox())
k = 166 / fig.height
fig = fig.resize((int(fig.width * k), 166), Image.NEAREST)
d.ellipse((450, 226, 512, 236), fill=(14, 10, 9))
img.paste(fig, (481 - fig.width // 2, 68), fig)
d = ImageDraw.Draw(img)
def puesto(x, y, t, i, cursor=False):
    global d
    d.rounded_rectangle((x, y, x + S, y + S), 5, fill=(58, 40, 30), outline=ORO, width=2)
    ic = icono(i, S - 6)
    img.paste(ic, (x + (S - ic.width) // 2, y + (S - ic.height) // 2), ic)
    d = ImageDraw.Draw(img)
    d.text((x + S / 2 - d.textlength(t, font=fuente(10)) / 2, y + S + 1), t, font=fuente(10), fill=GRIS)
    if cursor:
        d.rounded_rectangle((x - 3, y - 3, x + S + 3, y + S + 3), 7, outline=(255, 236, 120), width=1)
for k_, (t, i, c) in enumerate([("Arma", "machete_reforzado", False), ("De fuego", "pistola_mk23", True), ("Amuleto 1", "collar_obsidiana", False)]):
    puesto(366, 70 + k_ * 58, t, i, c)
for k_, (t, i) in enumerate([("Armadura", "chaleco_llanta"), ("Botas", "botas_obra"), ("Amuleto 2", "escapulario")]):
    puesto(564, 70 + k_ * 58, t, i)

# numeros
d.rounded_rectangle((352, 252, 610, 286), 6, fill=(24, 18, 16), outline=ORO_OSC, width=1)
x = 362
for t, v, extra in [("Vida", "140", "+40"), ("Daño", "-25 %", ""), ("Velocidad", "+10 %", ""), ("Golpe", "16", "")]:
    d.text((x, 254), t, font=fuente(10), fill=GRIS)
    d.text((x, 266), v, font=fuente(13), fill=CREMA)
    if extra:
        d.text((x + d.textlength(v, font=fuente(13)) + 3, 268), extra, font=fuente(10), fill=VERDE)
    x += 62

# --- Lo que esta bajo el cursor
info = (352, 292, 610, H - 44)
d.rounded_rectangle(info, 8, fill=(24, 18, 16), outline=ORO, width=2)
ic = icono("pistola_mk23", 52)
img.paste(ic, (364, 300 + (52 - ic.height) // 2), ic)
d = ImageDraw.Draw(img)
d.text((424, 300), "Pistola", font=fuente(18), fill=ORO)
d.text((424, 322), "De fuego  ·  Puesta", font=fuente(11), fill=GRIS)
lineas = [("Escuadra con silenciador.", CREMA), ("Daño medio, hace poco ruido.", VERDE),
          ("Balas: 34 en la mochila", GRIS), ("Se compra con el armero.", GRIS),
          ("Espacio: quitártela", ORO)]
for k_, (t, c) in enumerate(lineas):
    d.text((364, 358 + k_ * 15), t, font=fuente(12), fill=c)

x = 40
for b, t in [("Espacio", "Equipar / Quitar"), ("Q E", "Pestaña"), ("Tab", "Salir")]:
    bw = d.textlength(b, font=fuente(11)) + 10
    d.rounded_rectangle((x, H - 38, x + bw, H - 24), 4, fill=(70, 45, 28), outline=ORO_OSC)
    d.text((x + 5, H - 38), b, font=fuente(11), fill=CREMA)
    d.text((x + bw + 5, H - 38), t, font=fuente(11), fill=GRIS)
    x += bw + d.textlength(t, font=fuente(11)) + 22
img.resize((W * 2, H * 2), Image.NEAREST).save(SAL)
