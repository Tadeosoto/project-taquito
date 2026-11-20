"""Texturas de las oficinas del palacio (PalacioOficinas.gd), estilo backrooms en ruinas (JJ, 2026-11-20).

    python3 -I tools/map_import/make_texturas_oficinas.py

Escribe en textures/palacio_oficinas/:
  papel_tapiz.png   128 px = 2 m: amarillo mostaza con rayas finas y un dibujito repetido, manchado de humedad
  alfombra.png      128 px = 2 m: alfombra de oficina mostaza, humeda, con fibras y manchones
  plafon.png        128 px = 1.2 m: placas de fibra amarillentas (la reja de aluminio la pone PalacioOficinas)
  mancha.png        alfa: mancha de humedad cafe con aro mas oscuro (paredes, techo, alfombra)
  escurrido.png     alfa: escurrimiento de humedad que baja del techo por la pared
  sangre.png        alfa: embarrado de sangre seca, de mano o arrastre
  boquete.png       alfa: hoyo en el muro de tablaroca: orilla rota, carton y hueco negro
Todo con semilla fija: se puede regenerar igual.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

SALIDA = os.path.join(os.path.dirname(__file__), "..", "..", "textures", "palacio_oficinas")
TAM = 128


def ruido(img, azar, fuerza):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b = px[x, y][:3]
            d = azar.randint(-fuerza, fuerza)
            px[x, y] = (max(0, min(255, r + d)), max(0, min(255, g + d)), max(0, min(255, b + d)))


def manchones(img, azar, cuantos, color, radio, alfa, envolver=True):
    """Manchones suaves que se repiten sin costura (se dibujan tambien del otro lado)."""
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    for _ in range(cuantos):
        cx, cy = azar.uniform(0, img.width), azar.uniform(0, img.height)
        r = azar.uniform(radio * 0.5, radio)
        for dx in ([-img.width, 0, img.width] if envolver else [0]):
            for dy in ([-img.height, 0, img.height] if envolver else [0]):
                d.ellipse([cx + dx - r, cy + dy - r * 0.8, cx + dx + r, cy + dy + r * 0.8], fill=color + (alfa,))
    capa = capa.filter(ImageFilter.GaussianBlur(radio * 0.4))
    img.paste(Image.alpha_composite(img.convert("RGBA"), capa).convert("RGB"))


def papel_tapiz():
    azar = random.Random(4701)
    img = Image.new("RGB", (TAM, TAM), (196, 178, 104))
    d = ImageDraw.Draw(img)
    # Rayas verticales finas, dos tonos (cada 16 px = 25 cm)
    for x in range(0, TAM, 16):
        d.line([(x, 0), (x, TAM)], fill=(182, 164, 92), width=2)
        d.line([(x + 8, 0), (x + 8, TAM)], fill=(204, 188, 116), width=1)
    # Un rombito repetido entre las rayas
    for y in range(4, TAM, 16):
        for x in range(4, TAM, 16):
            d.polygon([(x, y - 2), (x + 2, y), (x, y + 2), (x - 2, y)], fill=(176, 158, 88))
    ruido(img, azar, 6)
    manchones(img, azar, 5, (120, 100, 50), 22, 70)
    return img


def alfombra():
    azar = random.Random(4702)
    img = Image.new("RGB", (TAM, TAM), (150, 128, 70))
    ruido(img, azar, 14)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    ruido(img, azar, 8)
    manchones(img, azar, 6, (80, 66, 34), 18, 110)
    manchones(img, azar, 3, (60, 48, 28), 10, 120)
    return img


def plafon():
    azar = random.Random(4703)
    img = Image.new("RGB", (TAM, TAM), (200, 192, 160))
    ruido(img, azar, 10)
    # Los hoyitos de la placa de fibra
    px = img.load()
    for _ in range(900):
        x, y = azar.randrange(TAM), azar.randrange(TAM)
        r, g, b = px[x, y]
        px[x, y] = (r - 40, g - 40, b - 36)
    manchones(img, azar, 2, (140, 112, 60), 16, 120)
    return img


def mancha_alfa(semilla, color, aro, tam=128):
    azar = random.Random(semilla)
    alfa = Image.new("L", (tam, tam), 0)
    d = ImageDraw.Draw(alfa)
    c = tam / 2
    # Forma irregular: un poligono con radio que varia, varias capas
    for capa, (escala, valor) in enumerate([(1.0, 120), (0.75, 160), (0.45, 140)]):
        puntos = []
        for k in range(24):
            ang = k / 24 * math.tau
            r = c * 0.85 * escala * azar.uniform(0.7, 1.0)
            puntos.append((c + math.cos(ang) * r, c + math.sin(ang) * r))
        d.polygon(puntos, fill=valor)
    alfa = alfa.filter(ImageFilter.GaussianBlur(3))
    if aro:
        orilla = alfa.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(1.5))
        alfa = Image.eval(Image.merge("L", [alfa]), lambda v: v)
        alfa = Image.composite(Image.new("L", alfa.size, 230), alfa, orilla.point(lambda v: 255 if v > 18 else 0))
        alfa = alfa.filter(ImageFilter.GaussianBlur(1))
    img = Image.new("RGBA", (tam, tam), color + (0,))
    img.putalpha(alfa)
    return img


def escurrido():
    azar = random.Random(4705)
    w, h = 64, 256
    alfa = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(alfa)
    d.ellipse([4, -30, w - 4, 50], fill=150)
    for _ in range(7):
        x = azar.uniform(10, w - 10)
        largo = azar.uniform(60, h - 10)
        ancho = azar.uniform(2, 6)
        d.line([(x, 10), (x + azar.uniform(-3, 3), largo)], fill=azar.randint(90, 150), width=int(ancho))
        d.ellipse([x - ancho, largo - ancho, x + ancho, largo + ancho * 1.5], fill=130)
    alfa = alfa.filter(ImageFilter.GaussianBlur(1.6))
    img = Image.new("RGBA", (w, h), (70, 56, 28, 0))
    img.putalpha(alfa)
    return img


def sangre():
    azar = random.Random(4706)
    tam = 128
    alfa = Image.new("L", (tam, tam), 0)
    d = ImageDraw.Draw(alfa)
    # Cuatro dedos que se arrastran hacia abajo y una palma arriba
    for k in range(4):
        x = 34 + k * 16 + azar.uniform(-3, 3)
        d.line([(x, 30), (x + azar.uniform(-6, 6), azar.uniform(80, 124))], fill=210, width=int(azar.uniform(6, 10)))
    d.ellipse([26, 10, 100, 48], fill=220)
    for _ in range(14):
        x, y = azar.uniform(10, 118), azar.uniform(5, 60)
        r = azar.uniform(1.5, 4)
        d.ellipse([x - r, y - r, x + r, y + r], fill=200)
    alfa = alfa.filter(ImageFilter.GaussianBlur(1.2))
    img = Image.new("RGBA", (tam, tam), (78, 10, 8, 0))
    img.putalpha(alfa)
    return img


def boquete():
    azar = random.Random(4707)
    tam = 128
    img = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = tam / 2
    def contorno(radio, vari):
        return [(c + math.cos(k / 20 * math.tau) * radio * azar.uniform(1 - vari, 1.0),
                 c + math.sin(k / 20 * math.tau) * radio * azar.uniform(1 - vari, 1.0)) for k in range(20)]
    d.polygon(contorno(60, 0.3), fill=(214, 206, 180, 255))      # el yeso del canto, roto
    d.polygon(contorno(50, 0.35), fill=(150, 130, 90, 255))      # el carton de la tablaroca
    d.polygon(contorno(42, 0.4), fill=(8, 7, 6, 255))            # el hueco
    # Un poste de lamina adentro
    d.rectangle([c + 8, 20, c + 14, tam - 20], fill=(40, 40, 42, 255))
    return img


def main():
    os.makedirs(SALIDA, exist_ok=True)
    papel_tapiz().save(os.path.join(SALIDA, "papel_tapiz.png"))
    alfombra().save(os.path.join(SALIDA, "alfombra.png"))
    plafon().save(os.path.join(SALIDA, "plafon.png"))
    mancha_alfa(4704, (88, 70, 34), True).save(os.path.join(SALIDA, "mancha.png"))
    escurrido().save(os.path.join(SALIDA, "escurrido.png"))
    sangre().save(os.path.join(SALIDA, "sangre.png"))
    boquete().save(os.path.join(SALIDA, "boquete.png"))
    print("listo:", os.path.abspath(SALIDA))


if __name__ == "__main__":
    main()
