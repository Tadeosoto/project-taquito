"""La piedra de la plaza (textures/mapa/piedra_plaza.png) pintada del rosa de la cantera de los andadores
(textures/mapa/cantera_rosa.png): misma textura, cada pixel llevado al color promedio de la cantera conservando
su luz relativa. Sale a textures/mapa/piedra_plaza_rosa.png (la glorieta del tinaco comunitario).

    python3 -I tools/map_import/make_piedra_plaza_rosa.py
"""
import os
from PIL import Image, ImageStat

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEX = os.path.join(RAIZ, "textures", "mapa")
CONTRASTE = 0.8   # cuanto de las juntas y manchas de la piedra se queda

piedra = Image.open(os.path.join(TEX, "piedra_plaza.png")).convert("RGB")
rosa = [v / 255 for v in ImageStat.Stat(Image.open(os.path.join(TEX, "cantera_rosa.png")).convert("RGB")).mean]
gris = Image.open(os.path.join(TEX, "piedra_plaza.png")).convert("L")
medio = ImageStat.Stat(gris).mean[0]
salida = Image.new("RGB", piedra.size)
for y in range(piedra.height):
    for x in range(piedra.width):
        luz = 1.0 + (gris.getpixel((x, y)) / medio - 1.0) * CONTRASTE
        salida.putpixel((x, y), tuple(max(0, min(255, round(c * luz * 255 * 0.95))) for c in rosa))
salida.save(os.path.join(TEX, "piedra_plaza_rosa.png"))
print("guardado", os.path.join(TEX, "piedra_plaza_rosa.png"))
