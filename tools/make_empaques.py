"""Genera textures/interiores/empaques.png: las etiquetas de la mercancia de los
estantes y mostradores de los interiores (scripts/interiores/Mostrador.gd y
Estante.gd), dibujadas con ImageMagick. Marcas inventadas, sin logos reales.

Atlas de COLUMNAS x FILAS etiquetas de ANCHO x ALTO px (el frente de cada empaque):
  fila 0  botanas (bolsas de papitas, dulces)
  fila 1  abarrotes (latas, frascos, cajas)
  fila 2  medicinas (cajitas blancas con franja de color)
  fila 3  ferreteria (blisters colgados con la pieza en su burbuja)
shaders/ps1_empaque.gdshader pone en cada empaque la etiqueta que le toca (su
INSTANCE_CUSTOM) y estira la orilla de la etiqueta en los lados y arriba.

Uso: python3 -I tools/make_empaques.py
"""

import os
import random
import subprocess
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "textures", "interiores", "empaques.png")
ANCHO, ALTO = 48, 64
COLUMNAS = 8
FUENTE = "NimbusSansNarrow-Bold"

BOTANAS = [("PAPITAS", "#e8302a", "#ffd23a"), ("CRUJIS", "#f2a516", "#7a1e10"),
           ("CHURRITOS", "#2a4fbf", "#ffe14d"), ("CACAHUA-\nTES", "#c8862e", "#fff4d0"),
           ("PALOMI-\nTAS", "#f4f0e0", "#d8262a"), ("TOTOPOS", "#2f8a3a", "#ffdf4a"),
           ("PICOSITOS", "#5a2a8a", "#ff8a1a"), ("GOMITAS", "#ff6aa8", "#ffffff")]
ABARROTES = [("FRIJOLES", "#5a2c18", "#f0e6c8"), ("ATÚN", "#1e5aa8", "#f4f4f4"),
             ("CHILES", "#2e7a2e", "#f2d040"), ("ARROZ", "#f2ede0", "#2a5aa8"),
             ("SOPA", "#e8b020", "#c8261e"), ("LECHE", "#f6f6f6", "#3a7ad8"),
             ("ACEITE", "#f0c830", "#2e6a2e"), ("CAFÉ", "#4a2a18", "#e8c070")]
MEDICINAS = [("PARACE-\nTAMOL", "#2a6ad0"), ("IBUPRO-\nFENO", "#d83030"), ("AMOXI-\nCILINA", "#2a9a4a"),
             ("SUERO\nORAL", "#28a8d8"), ("OMEPRA-\nZOL", "#8a3ab0"), ("LORATA-\nDINA", "#e88a1a"),
             ("VITAMI-\nNA C", "#f0b818"), ("ALCOHOL", "#3a3a8a")]
FERRETERIA = [("PINZAS", "#e8c018"), ("DESARMA-\nDOR", "#2a5ac8"), ("TORNI-\nLLOS", "#d8302a"),
              ("BROCAS", "#2a8a3a"), ("CINTA", "#f08a18"), ("CLAVOS", "#3a3a3a"),
              ("LLAVE", "#c8302a"), ("CANDADO", "#1a6ab0")]


def magick(*args: str) -> None:
    subprocess.run(["magick", *args], check=True)


def texto(cadena: str, color: str, y: int, tamano: int) -> list:
    return ["-font", FUENTE, "-fill", color, "-pointsize", str(tamano), "-gravity", "north",
            "-interline-spacing", "-3", "-annotate", f"+0+{y}", cadena]


def botana(nombre, fondo, letra, rng):
    # Bolsa: fondo brillante, franja de arriba, nombre grande y la botana en un ovalo
    oscuro = letra
    return ["-size", f"{ANCHO}x{ALTO}", f"xc:{fondo}",
            "-fill", oscuro, "-draw", f"rectangle 0,0 {ANCHO},5",
            "-fill", "#ffffff40", "-draw", f"rectangle 3,0 7,{ALTO}",
            "-fill", "#e8b04a", "-draw", f"ellipse {ANCHO // 2},{ALTO - 15} 15,9 0,360",
            "-fill", "#c88a2a", "-draw", f"ellipse {ANCHO // 2 + 4},{ALTO - 13} 6,4 0,360",
            *texto(nombre, letra, 9, 11 if "\n" not in nombre else 10),
            "-fill", oscuro, "-draw", f"rectangle 0,{ALTO - 4} {ANCHO},{ALTO}"]


def abarrote(nombre, fondo, franja, rng):
    # Lata/frasco: tapa gris arriba, etiqueta con franja de color y el nombre
    claro = "#f6f0dc" if fondo != "#f6f6f6" else "#ffffff"
    return ["-size", f"{ANCHO}x{ALTO}", f"xc:{fondo}",
            "-fill", "#9a9a9a", "-draw", f"rectangle 0,0 {ANCHO},6",
            "-fill", claro, "-draw", f"rectangle 0,18 {ANCHO},46",
            "-fill", franja, "-draw", f"rectangle 0,40 {ANCHO},46",
            "-fill", franja, "-draw", f"circle {ANCHO // 2},54 {ANCHO // 2 + 5},54",
            *texto(nombre, "#202020", 22, 11)]


def medicina(nombre, franja, rng):
    # Cajita blanca: franja de color, nombre, gramos y una raya de abajo
    mg = rng.choice(["500 mg", "400 mg", "250 mg", "10 tab", "20 cáps"])
    return ["-size", f"{ANCHO}x{ALTO}", "xc:#f6f6f2",
            "-fill", franja, "-draw", f"rectangle 0,0 {ANCHO},10",
            "-fill", franja, "-draw", f"polygon 0,{ALTO} {ANCHO},{ALTO - 14} {ANCHO},{ALTO}",
            *texto(nombre, "#1a1a2a", 14, 10),
            *texto(mg, franja, 40, 8)]


def blister(nombre, color, rng):
    # Carton con agujero para el gancho, nombre y la pieza gris en su burbuja
    pieza = rng.choice([
        f"rectangle 21,34 27,58",
        f"polygon 16,36 24,58 32,36 28,36 24,48 20,36",
        f"circle 24,46 24,36",
        f"rectangle 14,40 34,52"])
    return ["-size", f"{ANCHO}x{ALTO}", f"xc:{color}",
            "-fill", "#202020", "-draw", f"ellipse {ANCHO // 2},5 5,2 0,360",
            *texto(nombre, "#ffffff" if color not in ("#e8c018", "#f08a18") else "#1a1a1a", 9, 10),
            "-fill", "#dfe8ee", "-draw", f"roundrectangle 8,30 40,61 5,5",
            "-fill", "#7a7c80", "-draw", pieza]


def main() -> None:
    rng = random.Random(7)
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    filas = [[botana(*b, rng) for b in BOTANAS], [abarrote(*a, rng) for a in ABARROTES],
             [medicina(*m, rng) for m in MEDICINAS], [blister(*f, rng) for f in FERRETERIA]]
    with tempfile.TemporaryDirectory() as tmp:
        renglones = []
        for f, fila in enumerate(filas):
            celdas = []
            for c, args in enumerate(fila[:COLUMNAS]):
                ruta = os.path.join(tmp, f"{f}_{c}.png")
                magick(*args, "-alpha", "off", ruta)
                celdas.append(ruta)
            renglon = os.path.join(tmp, f"fila_{f}.png")
            magick(*celdas, "+append", renglon)
            renglones.append(renglon)
        magick(*renglones, "-append", "-depth", "8", "-define", "png:color-type=2", SALIDA)
    print(SALIDA)


if __name__ == "__main__":
    main()
