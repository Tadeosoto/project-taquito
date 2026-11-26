"""Texturas hechas a mano para tiliches de Sketchfab que llegan sin textura o con una que no
sirve, y marcas tapadas en las que traen logo (TAPAR) (Fase T de docs/plan-noche.md). Pinta la textura en models/tiliches/<id>/textures/ y la
engancha en el scene.gltf. Correr despues de fetch_sketchfab.py y antes de importar y hornear:

    python3 -I tools/taller/texturas_tiliches.py
    godot --path . --headless --import
    godot --path . --headless -s tools/map_import/hornear_modelos.gd -- --solo=lata

El scene.gltf esta en el .gitignore: si se vuelve a bajar el modelo, hay que correr esto otra vez.
"""

import json
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TAM = 64   # px: PS1, se ve en pixeles a proposito


def aluminio(semilla: int) -> Image.Image:
	"""Aluminio cepillado: gris frio con rayas verticales finas y dos brillos."""
	rnd = random.Random(semilla)
	img = Image.new("RGB", (TAM, TAM))
	px = img.load()
	columnas = [rnd.randint(-14, 14) for _ in range(TAM)]
	for x in range(TAM):
		# Brillos anchos: el metal refleja en dos franjas
		brillo = 38 * max(0.0, 1.0 - abs(x - TAM * 0.3) / 7.0) + 22 * max(0.0, 1.0 - abs(x - TAM * 0.72) / 5.0)
		for y in range(TAM):
			v = 118 + columnas[x] + rnd.randint(-6, 6) + brillo
			px[x, y] = (int(min(255, v * 0.97)), int(min(255, v)), int(min(255, v * 1.05)))
	return img


# id del tilich -> (textura, {material del gltf: color que multiplica la textura})
TILICHES = {
	"lata": (lambda: aluminio(84), {
		"Material.011": [1.0, 1.0, 1.0, 1.0],     # el cuerpo (venia turquesa)
		"Material.012": [0.9, 0.9, 0.9, 1.0],     # tapa
		"Material.016": [0.6, 0.6, 0.6, 1.0],     # bordes y el fondo
	}),
}


# Marcas que se tapan en texturas de Sketchfab: carpeta (models/<carpeta>) -> (textura, cajas en px
# (x0, y0, x1, y1[, color a mano]) de la textura de 256). Cada caja se rellena con el color de su orilla y algo de
# ruido, para que quede como el material de alrededor
TAPAR = {
	# La bota de Carhartt: el logo de la suela, la etiqueta del costado, la de la lengueta, la tira
	# de atras con el nombre, la etiqueta chica del talon y la marca de agua de Sketchfab
	"taller/botas_casquillo": ("textures/sh_carharttWorkBoot_diffuse.jpeg", [
		(30, 110, 52, 132), (97, 94, 119, 117), (216, 52, 248, 82), (53, 158, 70, 192, (32, 28, 26)),
		(198, 222, 222, 241), (222, 0, 256, 7)]),
}


def tapar(img: Image.Image, caja: tuple, semilla: int) -> None:
	rnd = random.Random(semilla)
	x0, y0, x1, y1 = caja[:4]
	px = img.load()
	w, h = img.size
	orilla = []
	for x in range(max(0, x0 - 2), min(w, x1 + 2)):
		for y in (max(0, y0 - 2), min(h - 1, y1 + 1)):
			orilla.append(px[x, y])
	for y in range(max(0, y0 - 2), min(h, y1 + 2)):
		for x in (max(0, x0 - 2), min(w - 1, x1 + 1)):
			orilla.append(px[x, y])
	# La mediana de cada canal: no la jala lo blanco de la etiqueta si se asoma en la orilla
	color = [sorted(c[k] for c in orilla)[len(orilla) // 2] for k in range(3)]
	if len(caja) > 4:
		color = list(caja[4])   # a mano: la tira negra de atras, rodeada de cafe
	for y in range(max(0, y0), min(h, y1)):
		for x in range(max(0, x0), min(w, x1)):
			n = rnd.randint(-8, 8)
			px[x, y] = tuple(max(0, min(255, c + n)) for c in color)


def main() -> None:
	for carpeta, (archivo, cajas) in TAPAR.items():
		ruta = os.path.join(ROOT, "models", carpeta, archivo)
		if not os.path.exists(ruta):
			print(f"  falta {ruta}: bajalo con fetch_sketchfab.py")
			continue
		img = Image.open(ruta).convert("RGB")
		for i, caja in enumerate(cajas):
			tapar(img, caja, i)
		img.save(ruta, quality=92)
		print(f"  {carpeta}: {len(cajas)} marcas tapadas")
	for id_, (pintar, materiales) in TILICHES.items():
		carpeta = os.path.join(ROOT, "models", "tiliches", id_)
		gltf_path = os.path.join(carpeta, "scene.gltf")
		if not os.path.exists(gltf_path):
			print(f"  falta {gltf_path}: bajalo con fetch_sketchfab.py")
			continue
		os.makedirs(os.path.join(carpeta, "textures"), exist_ok=True)
		nombre = f"textures/{id_}_baseColor.png"
		pintar().save(os.path.join(carpeta, nombre))
		with open(gltf_path, encoding="utf-8") as f:
			gltf = json.load(f)
		gltf["images"] = [{"uri": nombre}]
		gltf["samplers"] = [{"magFilter": 9728, "minFilter": 9728}]   # nearest
		gltf["textures"] = [{"source": 0, "sampler": 0}]
		for material in gltf["materials"]:
			if material["name"] in materiales:
				pbr = material.setdefault("pbrMetallicRoughness", {})
				pbr["baseColorFactor"] = materiales[material["name"]]
				pbr["baseColorTexture"] = {"index": 0}
		with open(gltf_path, "w", encoding="utf-8") as f:
			json.dump(gltf, f)
		print(f"  {id_}: {nombre}")


if __name__ == "__main__":
	main()
