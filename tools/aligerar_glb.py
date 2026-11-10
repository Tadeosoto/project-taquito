"""Aligera los .glb de una carpeta (en su sitio): se queda solo con los mapas de color (base, emisivo
y el difuso de specular-glossiness), tira los de normal, rugosidad, oclusion y brillo, baja las
imagenes a MAX px por lado y las guarda como JPG; sin esos mapas deja el material mate y sin metal. El juego es de 640x480 con look PS1: no se nota
y un modelo de Sketchfab de 4 MB queda en unos 300 KB. Uso:

    python3 -I tools/aligerar_glb.py models/casa_personaje [MAX]

Despues borra las texturas extraidas viejas (png/jpg junto al .glb) y corre
godot --path . --headless --import. Los .glb no se pueden volver a su estado: guarda una copia antes.
"""
import glob
import io
import json
import os
import struct
import sys

from PIL import Image

MAX = 512
CALIDAD = 88
ROUGOSIDAD = 0.85   # sin mapa de rugosidad: madera y tela mate
# materiales: donde puede colgar una textura que si se conserva
COLOR = ("baseColorTexture", "emissiveTexture")


def leer(ruta: str):
	d = open(ruta, "rb").read()
	n = struct.unpack("<I", d[12:16])[0]
	j = json.loads(d[20:20 + n])
	m = struct.unpack("<I", d[20 + n:24 + n])[0]
	return j, d[28 + n:28 + n + m]


def texturas_de_color(j: dict) -> set:
	"""Indices de textura que se conservan; borra del JSON las referencias a las demas."""
	usadas = set()
	for m in j["materials"]:
		pbr = m.setdefault("pbrMetallicRoughness", {})
		# sin el mapa de metal/rugosidad glTF asume metal al 100 % y todo sale casi negro
		pbr["metallicFactor"] = 0.0
		pbr["roughnessFactor"] = ROUGOSIDAD
		for k in list(pbr):
			if k == "baseColorTexture":
				usadas.add(pbr[k]["index"])
			elif k.endswith("Texture"):
				del pbr[k]
		for k in list(m):
			if k == "emissiveTexture":
				usadas.add(m[k]["index"])
			elif k.endswith("Texture") and isinstance(m[k], dict) and "index" in m[k]:
				del m[k]
		sg = m.get("extensions", {}).get("KHR_materials_pbrSpecularGlossiness")
		if sg:
			sg.pop("specularGlossinessTexture", None)
			if "diffuseTexture" in sg:
				usadas.add(sg["diffuseTexture"]["index"])
	return usadas


def aligerar(ruta: str, maximo: int) -> None:
	j, binario = leer(ruta)
	usadas = texturas_de_color(j)
	# texturas e imagenes que quedan, con su nuevo indice
	nuevas_tex = {}
	nuevas_img = {}
	texturas = []
	imagenes = []
	for i in sorted(usadas):
		t = dict(j["textures"][i])
		src = t["source"]
		if src not in nuevas_img:
			nuevas_img[src] = len(imagenes)
			imagenes.append(dict(j["images"][src]))
		t["source"] = nuevas_img[src]
		nuevas_tex[i] = len(texturas)
		texturas.append(t)
	for m in j["materials"]:
		pbr = m.get("pbrMetallicRoughness", {})
		for d in [pbr, m, m.get("extensions", {}).get("KHR_materials_pbrSpecularGlossiness", {})]:
			for k, v in d.items():
				if k.endswith("Texture") and isinstance(v, dict) and "index" in v:
					v["index"] = nuevas_tex[v["index"]]
	# imagenes nuevas: reducidas y en JPG
	datos_img = {}
	for viejo, nuevo in nuevas_img.items():
		bv = j["bufferViews"][j["images"][viejo]["bufferView"]]
		img = Image.open(io.BytesIO(binario[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])).convert("RGB")
		img.thumbnail((maximo, maximo), Image.LANCZOS)
		sal = io.BytesIO()
		img.save(sal, "JPEG", quality=CALIDAD, optimize=True)
		datos_img[j["images"][viejo]["bufferView"]] = sal.getvalue()
		imagenes[nuevo]["mimeType"] = "image/jpeg"
	# buffer nuevo: todo lo de geometria igual, las imagenes que sobran fuera
	vistas_de_imagen = {im["bufferView"] for im in j["images"]}
	nuevo_bin = bytearray()
	vistas = []
	mapa = {}
	for i, bv in enumerate(j["bufferViews"]):
		if i in vistas_de_imagen and i not in datos_img:
			continue
		datos = datos_img.get(i)
		if datos is None:
			ini = bv.get("byteOffset", 0)
			datos = binario[ini:ini + bv["byteLength"]]
		while len(nuevo_bin) % 4:
			nuevo_bin.append(0)
		nv = {k: v for k, v in bv.items() if k not in ("byteOffset", "byteLength")}
		nv["buffer"] = 0
		nv["byteOffset"] = len(nuevo_bin)
		nv["byteLength"] = len(datos)
		mapa[i] = len(vistas)
		vistas.append(nv)
		nuevo_bin += datos
	for a in j.get("accessors", []):
		if "bufferView" in a:
			a["bufferView"] = mapa[a["bufferView"]]
	for im in imagenes:
		im["bufferView"] = mapa[im["bufferView"]]
	j["bufferViews"] = vistas
	j["images"] = imagenes
	j["textures"] = texturas
	while len(nuevo_bin) % 4:
		nuevo_bin.append(0)
	j["buffers"] = [{"byteLength": len(nuevo_bin)}]
	cabeza = json.dumps(j, separators=(",", ":")).encode()
	cabeza += b" " * (-len(cabeza) % 4)
	total = 12 + 8 + len(cabeza) + 8 + len(nuevo_bin)
	with open(ruta, "wb") as f:
		f.write(struct.pack("<4sII", b"glTF", 2, total))
		f.write(struct.pack("<I4s", len(cabeza), b"JSON") + cabeza)
		f.write(struct.pack("<I4s", len(nuevo_bin), b"BIN\x00") + bytes(nuevo_bin))


if __name__ == "__main__":
	carpeta = sys.argv[1]
	tope = int(sys.argv[2]) if len(sys.argv) > 2 else MAX
	for ruta in sorted(glob.glob(os.path.join(carpeta, "**", "*.glb"), recursive=True)):
		antes = os.path.getsize(ruta)
		aligerar(ruta, tope)
		print("%-45s %6.0f KB -> %6.0f KB" % (ruta, antes / 1024, os.path.getsize(ruta) / 1024))
