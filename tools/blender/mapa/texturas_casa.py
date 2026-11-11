"""Las texturas de la casa base de Parques de Santa Maria (casa_psm.py), de Poly Haven (CC0).

    python3 -I tools/blender/mapa/texturas_casa.py

Baja el mapa de color a 1K de cada una (queda en tools/blender/cache/, que no se versiona), lo pasa a
gris y le ajusta el brillo medio, para que el color de vertice de cada casa la pinte, lo reduce a
512 px y lo guarda en textures/mapa/. Los creditos estan en CREDITS.md.

  casa_psm_muro     white_stucco_02        cemento enjarrado (aplanado), tambien el de los arcos (se repite cada 2.5 m)
  casa_psm_azotea   concrete_wall_008      losa de concreto (cada 2 m)
  casa_psm_metal    painted_metal_shutter  pintura de metal con rayones: el detalle de las rejas,
                                           la herreria y las puertas (casa_psm.py lo normaliza)
  casa_psm_tela     rough_linen            el tejido de la cortina
  casa_psm_concreto concrete_floor_01      el piso de la cochera (cada 2 m)
  casa_psm_madera   oak_veneer_01          la veta de las puertas (de madera pintada; casa_psm.py la normaliza)
  casa_psm_pasto    leafy_grass            el pasto del jardin (cada 2 m); este va a color, no en gris
"""
import json
import os
import urllib.request

from PIL import Image, ImageEnhance, ImageStat

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
CACHE = os.path.join(RAIZ, "tools", "blender", "cache", "polyhaven")
SALIDA = os.path.join(RAIZ, "textures", "mapa")
LADO = 512

# archivo: (id en Poly Haven, brillo medio al que se lleva, de 0 a 1)
# (las de A_COLOR conservan su color, con este realce de saturacion y este tinte por canal: el
# leafy_grass tal cual se veia pasto seco, cafe)
A_COLOR = {"casa_psm_pasto": (1.6, (0.88, 1.1, 0.8))}
TEXTURAS = {
    "casa_psm_muro": ("white_stucco_02", 0.88),
    "casa_psm_azotea": ("concrete_wall_008", 0.62),
    "casa_psm_metal": ("painted_metal_shutter", 0.6),
    "casa_psm_tela": ("rough_linen", 0.6),
    "casa_psm_concreto": ("concrete_floor_01", 0.62),
    "casa_psm_madera": ("oak_veneer_01", 0.6),
    "casa_psm_pasto": ("leafy_grass", 0.42),
}


def _bajar(id_ph):
    ruta = os.path.join(CACHE, id_ph, "diffuse_1k.jpg")
    if not os.path.exists(ruta):
        os.makedirs(os.path.dirname(ruta), exist_ok=True)
        pedir = lambda url: urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "taquito-texturas"}), timeout=60).read()
        info = json.loads(pedir("https://api.polyhaven.com/files/" + id_ph))
        open(ruta, "wb").write(pedir(info["Diffuse"]["1k"]["jpg"]["url"]))
    return ruta


def main():
    os.makedirs(SALIDA, exist_ok=True)
    for nombre, (id_ph, brillo) in TEXTURAS.items():
        im = Image.open(_bajar(id_ph)).convert("RGB" if nombre in A_COLOR else "L").resize((LADO, LADO), Image.LANCZOS)
        k = brillo * 255 / ImageStat.Stat(im.convert("L")).mean[0]
        im = im.point(lambda v: min(255, int(v * k + 0.5))).convert("RGB")
        if nombre in A_COLOR:
            saturacion, tinte = A_COLOR[nombre]
            im = ImageEnhance.Color(im).enhance(saturacion)
            im = Image.merge("RGB", [c.point(lambda v, f=f: min(255, int(v * f + 0.5))) for c, f in zip(im.split(), tinte)])
        im.save(os.path.join(SALIDA, nombre + ".png"), optimize=True)
        print(nombre, "<-", id_ph)


if __name__ == "__main__":
    main()
