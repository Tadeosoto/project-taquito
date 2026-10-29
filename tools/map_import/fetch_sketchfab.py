"""Baja de Sketchfab los modelos del mapa: tiendas, casas, props, objetos, personajes, armas e interiores.

Sketchfab pide cuenta para descargar: copia tu API token de
https://sketchfab.com/settings/password (seccion "API Token") y corre:

    SKETCHFAB_TOKEN=xxxx python3 -I tools/map_import/fetch_sketchfab.py

o guardalo en ~/.config/sketchfab/token. Con carpetas como argumento (p. ej.
interiores/comida) solo procesa esas. Cada modelo queda en
models/<carpeta>/ (glTF con sus texturas, achicadas a 256 px, y un .import que
usa scripts/map/TiendaPostImport.gd para el shader PS1) y su credito se agrega a
CREDITS.md (los CC BY piden citar al autor). Los modelos con muchas caras se
reducen al importarlos en Godot (TiendaPostImport.MAX_TRIANGULOS).
Despues: godot --path . --headless --import y
tools/map_import/hornear_modelos.gd, que guarda models/<carpeta>/<modelo>.scn;
eso es lo que usa el juego y lo que va en git (los originales estan en el
.gitignore). Asignalos en los nodos Puntos y Casas de scenes/map_test.tscn.
"""

import glob
import io
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile

# Texturas PS1: nada mas grande que esto (px); Sketchfab trae hasta 2048
MAX_TEXTURE = 256

IMPORT_FILE = """[remap]

importer="scene"
importer_version=1

[params]

import_script/path="res://scripts/map/TiendaPostImport.gd"
"""

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "models")

# carpeta (dentro de models/) -> uid de Sketchfab. Los pesados se reducen al
# importarlos (TiendaPostImport.MAX_TRIANGULOS).
MODELS = {
	"tiendas/tienda_3b": "e3c3ac9a198349479429d5bcee2f39c9",        # Mexican Store (Tienda 3B) PSX, 1k caras
	"tiendas/oxxo": "636c02e80d7f4ebea822808c002fe26b",             # Tienda Oxxo, 838
	"tiendas/oxxo_abandonado": "0d9e953705b444e8b1706dc4048ca130",  # abandoned oxxo, 2k
	"tiendas/oxxo_letrero": "d444a16b316b4b18b9de9c372379a83e",     # Letrero de tienda Oxxo, 570
	"tiendas/farmacia_guadalajara": "d98a5671fec34796a6a5d26d3a37b83f",  # 2.7k
	"tiendas/oxxo_mexican": "07f02fc1feee42e380a528f75c44613b",     # Mexican Oxxo, 7k
	"tiendas/barrio_mexicano": "bd02bfb9db374065a53b1eeb168ef925",  # Small Mexican Neighborhood, 9k
	"tiendas/puesto_tacos": "03046667e027461baaaa47697d502e74",     # Cara1 Puesto de Tacos, 40k
	"tiendas/tacos_props": "f8bbafe18488483f8ab79bc52d1edc79",      # Tacos_ Props, 25k
	"tiendas/pemex": "1e070d51657e4c169c517f81de973e41",            # Pemex Low Poly, 3.6k
	"tiendas/carrito": "a74ed86472c945328f3f2cf98fb26977",          # Low Poly Street Food Cart, 3.7k
	"casas/urbi": "641be90fcbd14bcb997dac56671081a8",               # Casa Urbi / Infonavit, 7.9k
	"casas/semi_residencial": "4431db9690aa4d6ea23f50b8fdfa0cd3",   # Casa Tipo Semi Residencial, 398
	"casas/mexican_house_3": "8f7b73d6ba1e4642b3230ed15f3db421",    # Mexican House 3, 7.3k
	"casas/multifamiliar": "afff4fd9e05549f6b1d5668b9eb36af7",      # Edificio multifamiliar, 1.3k (aun sin usar)
	"props/alto": "d2de3788e5f24c3e8189001d2a1f6e92",               # Senal Alto, 1.3k
	"objetos/takis": "7426e5fa188344668ec3b9dbab348bae",            # Takis Fuego, 44k
	"objetos/moneda_peso": "5b0b33e49fa84d96b6e0d82beac694f3",      # 1 Peso MXN, 2k
	"objetos/jarritos": "44a5150acb0b4109af1378c74bfdde5c",         # Jarritos Grapefruit, 141k
	# Sketchfab solo baja el pack entero; separar_pack.gd saca la mochila y el
	# mazapan (lo demas no se usa)
	"objetos/mexican_starter_pack": "8a0b37c7d64448c1aa9b533cdea0283a",  # Mexican Starter Pack!, 46k
	"personajes/soldado": "7ef42de5636443399f3f06ff8b98d5a7",       # soldado del ejercito mexicano, 6.6k
	"personajes/amerindios": "cdb4d27bd4154712968eb3f0961bb375",    # Free ps2 style isthmid amerindian characters, 8.1k, rig
	"personajes/dr_simi": "00e3a472abf546bd97adcc83f29b82bf",       # Farmica Similares Dr Simi, 223k, 1 animacion
	"personajes/cholo": "e6de11b017104307b1940e2f178d5bda",         # cholo, 1.2k, 1 animacion
	"personajes/psx_man": "41b0580d4d5c4cc183cfeae523ea0a09",       # psx man, 2.7k, 1 animacion
	"personajes/policia": "5576b8cbd33343f998c8b86d8bcfda48",       # Cop Character PSX Style, 2.3k
	"personajes/indian_gangster": "76553b4f0dc84c6386e997c80b9b0017",  # Indian Gangster, 53k, 1 animacion
	"personajes/gangster_dealer": "1eed0758ec3d45a7ae5613db8b59eb7b",  # Gangster Dealer Musculo, 43k, 1 animacion
	"personajes/gang_member": "d696194c574241f6bb8f08f5f89e8718",   # Gang Member, 32k
	# Lo que falta de docs/especificaciones.md (seccion 10.2)
	"personajes/zombie_ripper": "c5a77a38545543ce9c64eaa534afc23b",  # Ripper Zombie, 1.5k, 5 animaciones
	"personajes/zombie_psx": "e5780c5c161c461783d978aee98a865b",    # PSX style zombie, 1.6k, 1 animacion
	"personajes/zombie_gordo": "d21f6917d40944a7b92b56a94d474d1e",  # Fat Man Zombie, 4.7k, 6 animaciones (hinchado)
	"personajes/simi_muneco": "42c358b269d74533909bb2835f812ac5",   # dr_simi_muneco, 2k (botarga, sin rig)
	"personajes/mujer_psx": "08dea1dcd280451da4a8e621588409a3",     # PSX Low Poly Woman, 894, 1 animacion
	"personajes/chava_psx": "07986f66480e46a8a8182adb35d6e7e8",     # PSX Alt Girl, 1k, 1 animacion
	"personajes/hombre_psx": "f9acca1dc1ec411699ffd6337889e058",    # [PS1/PSX/Retro] Male Base v2, 880
	"armas/machete": "bec7ee80bac24cc19b1e79cf8b57c50a",            # PS1 Style Machete, 102
	"armas/melee_psx": "79cae670d515469a947617d18e5a6c89",          # Retro / PSX-like Horror Melee Weapons Pack, 1.4k
	"armas/pistola_mk23": "a2f7ab3209a1409f8ea932c7851f1a20",       # MK23 SOCOM Low Poly PS1, 194
	"armas/pistola_colt": "f9fc36a1f07b47faaadb761702f703b0",       # LOWPOLY Colt M1911 PS1/PSX, 806
	"armas/cuerno_de_chivo": "a7260926fb0a40f8bba5f651b03d23f1",    # Low-Poly AK-47 Type 2, 5.5k
	"armas/ballesta": "3a2010edc90346448017be61940eedfc",           # Medieval crossbow 01, 1.6k
	"armas/bate": "f3c3c73529e14dc59d525a9a6a2220cd",               # Bloody post-apo baseball bat, 1.6k
	"armas/balas": "bb1f5649dfa74315977e9706d5079a6f",              # Ammo Boxes Pack, 9.9k
	"objetos/botella": "03d9062085214988b2e984470c7c0d28",          # Dusty Beer Bottle, 1.4k (molotov)
	"objetos/galon_agua": "9d69e59b7eeb4d7e9e2e5388960fdd9f",       # gallon of water, 4k
	"objetos/cigarro": "27d7beefb2314e2c970f0622b5ca8752",          # Marlboro Gold, 20
	"objetos/bocina": "d9f19a9ddce04dac8586b34869d0c1ba",           # Low Poly Boombox PS1/PS2, 194
	"objetos/vaporub": "9e1a3cfe9ad947cb88c483495bc0cf5c",          # Vick Vaporub (bajo poligono), 162
	"objetos/cloralex": "5b227d8679544e4bb3ce8e992e830787",         # Bleach bottle, 1.9k
	"objetos/cinta": "f80243ec33674f0f9d96c09fa2e19abe",            # Blue Electrical Tape, 184
	"objetos/tablas": "4859a76994cc49e2ba451d204e24574d",           # Stylized Wood Pack, 696
	"objetos/botiquin": "4f27c0f45c704cdb9858c073fe961ade",         # Soviet first aid kit, 2.1k
	# Objetos de misiones y NPCs (especificaciones.md, secciones 5 y 6)
	"objetos/paquete": "e2bfa6f3822241a49553b44c55ef3082",          # Cardboard Boxes Pack - Taped, 2.8k
	"objetos/patito": "3100647808744cadb13a6847eb721e3b",           # Rubber duck, 72
	"objetos/tachas": "4892b8f61b0c4b27a65b0dfd489d6af5",           # CC0 - Pill, 1.3k (pastilla suelta)
	"objetos/llave": "a2ba7ef56ec04eaebf3acda251101442",            # PSX Tower Key, 264
	"objetos/refrescos": "00c7ef57a8544b9b9ba0c42fda7a47e2",        # Soda & Energy Drink Pack, 440
	"objetos/carrito_super": "b96f896453b240ae804d0399f1faf027",    # Shopping Cart, 2.2k
	"objetos/gansito": "ba692654d1ae417cb2e72da0aaf9445b",          # Gansito Modelado 3d, 60k
	"objetos/chancla": "000074a334c541878360457c672b6c2e",          # Worn Flip Flop, 15k
	"objetos/trapo": "35b76b90614d49a3aa92eeeb6afec60f",            # White Towel, 828 (TiendaPostImport.TINTES)
	"objetos/tejuino": "654c719c6bf0487c9b392d1dfad8ac6d",          # Iced Coffee, 1k (TiendaPostImport.TINTES)
	"armas/resortera": "7c00a1667b2c4413b4dcb24500f05892",          # Slingshot, 6k
	"props/despachador_agua": "25bdfe807c8e437885ed3be6ec0d11d8",   # water dispenser, 724
	"props/coladera": "bbf5c9aa04c24fbaba328728d955777d",           # Manhole, 72
	"personajes/perro": "647fa9e3f53b4898826ef398f0a9f6dd",         # French Bulldog PSX, 770, 1 animacion
	"personajes/taquero": "452927fd544d476eaf2c00a11e18965c",       # Chef Erik (Walking), 2.7k, 1 animacion
	"personajes/encargada": "8898a87225604a1fb335b47efff9c088",     # Female Secretary Character PSX, 932
	"personajes/cientifico": "b6b7e7f4f6774354941bc1e84833c302",    # Half-Life Scientist Luther, 672
	"personajes/garrafonero": "a9eff8aee05e48d8b1f31cafd408215f",   # Construction Worker In A Blue Jacket, 336k
	"interiores/maquina_refrescos": "aff31f282155471d8222287596c7ac59",  # PSX - Vending Machine, 92
	"interiores/estante_fruta": "8f1624e9ba6c443e8448b2a2db20eeb7", # PSX Style Fruit Shelve, 1.1k
	"interiores/mostrador": "47e1be52888640f89ab6dd8eeb008b35",     # Counter, 7.9k
	"interiores/m3_mart": "833699c4a15b4d1ab3e3d79068972431",       # M3 Mart, 11.7k
	"interiores/comida": "e25d5b9877da4cb4ae0c2474e7e67ca9",         # Comida Low Poly, 5.7k (mercancia de los abarrotes)
	# Ferreteria: herramientas colgadas y pintura en las repisas (Estante.gd)
	"interiores/herramientas": "59c5e176b95b4a0c9e0d9bd0f577a837",   # tools pack (martillo, perica, desarmadores), 1.5k
	"interiores/herramientas_2": "8c28443ed04c4564b570f3acc529102c", # Tools pack 2 (pinzas, llaves), 3.5k
	"interiores/herramientas_psx": "c2a01052f23d438d9a3c65e649e2829d",  # Old Tools PSX (machete, mazo, martillo), 404
	"interiores/bote_pintura": "f5d97bc88d99451c87665ddb1edd4292",   # Metal Paint Can, 464
	"interiores/bote_pintura_2": "3f418f347ddb4f9594f24c4599a0d1d2", # Paint Can Scan LOWPOLY, 572
	"interiores/aerosol": "5d1678b1fe454c389a571cb06d91bab9",       # Low Poly Spray Paint, 634
	"interiores/aerosol_2": "4c8af55af44c4e888fa9e3ca037f65e3",     # Spray Paint Can, 830
	"interiores/silla_plegable": "54bd0acd7c524d678128367a25a0f504", # Folding Chair - Low Poly, 270 (sillas de la taqueria, pintadas de rojo en Mesa.gd)
	# Bodegas huecas (MapBodegas.gd): de la bodega solo se usa un vano del frente
	"bodegas/bodega_industrial": "e6049139a2dd412a88d127541808e1e2",  # Industrial Warehouse, 1.9k
	"bodegas/rack": "593e7d15f27346efa2dcc0149edb6ef2",             # Pallet Racking, 1.3k
	"bodegas/cajas": "5d3d508061e544739e37c685af235684",            # Cardboard Box Set- Low Poly, 110
	"bodegas/estante_oxidado": "3ce07d0518154759841236045efafd72",  # Old Rusty Shelving Unit, 160
}

# Titulo de la seccion de CREDITS.md para cada carpeta de primer nivel
CREDIT_HEADERS = {
	"tiendas": "## Tiendas (`models/tiendas/`, Sketchfab)",
	"casas": "## Casas (`models/casas/`, Sketchfab)",
	"props": "## Props de calle (`models/props/`, Sketchfab)",
	"objetos": "## Objetos (`models/objetos/`, Sketchfab)",
	"personajes": "## Personajes (`models/personajes/`, Sketchfab)",
	"armas": "## Armas (`models/armas/`, Sketchfab)",
	"interiores": "## Interiores (`models/interiores/`, Sketchfab)",
	"bodegas": "## Bodegas (`models/bodegas/`, Sketchfab)",
}


def read_token() -> str:
	token = os.environ.get("SKETCHFAB_TOKEN", "").strip()
	path = os.path.expanduser("~/.config/sketchfab/token")
	if not token and os.path.exists(path):
		with open(path, encoding="utf-8") as f:
			token = f.read().strip()
	if not token:
		sys.exit("ERROR: falta SKETCHFAB_TOKEN (ver el inicio de este archivo)")
	return token


def get_json(url: str, token: str | None = None) -> dict:
	headers = {"User-Agent": "taquito-map-import/1.0"}
	if token:
		headers["Authorization"] = f"Token {token}"
	# Sketchfab contesta 429 si se piden muchas descargas seguidas: esperar y reintentar
	for intento in range(5):
		try:
			with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
				return json.load(response)
		except urllib.error.HTTPError as error:
			if error.code != 429 or intento == 4:
				raise
			print("  Sketchfab pide esperar (429), 60 s...")
			time.sleep(60)


def prepare_for_godot(dest: str, shrink: bool) -> None:
	"""Achica las texturas (solo recien bajadas: mogrify reescribe el archivo aunque
	no cambie de tamano) y hace que Godot importe con TiendaPostImport (shader PS1)."""
	# Solo imagenes: despues de abrir Godot tambien hay .png.import ahi
	textures = [path for path in glob.glob(os.path.join(dest, "textures", "*"))
		if path.lower().endswith((".png", ".jpg", ".jpeg"))]
	if shrink and textures:
		subprocess.run(["magick", "mogrify", "-resize", f"{MAX_TEXTURE}x{MAX_TEXTURE}>", *textures], check=True)
	import_path = os.path.join(dest, "scene.gltf.import")
	if not os.path.exists(import_path):
		with open(import_path, "w", encoding="utf-8") as f:
			f.write(IMPORT_FILE)


def main() -> None:
	token = read_token()
	os.makedirs(OUT_DIR, exist_ok=True)
	credits = {}
	solo = sys.argv[1:]
	for carpeta in solo:
		if carpeta not in MODELS:
			sys.exit(f"ERROR: {carpeta} no esta en MODELS")
	for folder, uid in MODELS.items():
		if solo and folder not in solo:
			continue
		dest = os.path.join(OUT_DIR, folder)
		info = get_json(f"https://api.sketchfab.com/v3/models/{uid}")
		license_label = (info.get("license") or {}).get("label", "?")
		author = (info.get("user") or {}).get("displayName") or (info.get("user") or {}).get("username", "?")
		credits.setdefault(folder.split("/")[0], []).append(
			f"- [{info['name']}](https://sketchfab.com/3d-models/{uid}) de {author}, "
			f"licencia {license_label} (`models/{folder}/`).")
		# En git solo esta la .scn horneada: si falta el original se vuelve a bajar
		if os.path.exists(os.path.join(dest, "scene.gltf")):
			print(f"  ya estaba: {folder}")
			prepare_for_godot(dest, shrink=False)
			continue

		download = get_json(f"https://api.sketchfab.com/v3/models/{uid}/download", token)
		# El zip de glTF trae scene.gltf + scene.bin + textures/
		url = download["gltf"]["url"]
		print(f"  bajando {folder} ({download['gltf'].get('size', 0) / 1e6:.1f} MB)...")
		with urllib.request.urlopen(url, timeout=600) as response:
			data = response.read()
		with zipfile.ZipFile(io.BytesIO(data)) as archive:
			for name in archive.namelist():
				target = os.path.normpath(os.path.join(dest, name))
				if not target.startswith(dest + os.sep):
					sys.exit(f"ERROR: ruta rara en el zip de {folder}: {name}")
			archive.extractall(dest)
		# Godot importa license.txt como texto suelto; no hace falta en el proyecto
		license_txt = os.path.join(dest, "license.txt")
		if os.path.exists(license_txt):
			os.rename(license_txt, os.path.join(dest, "LICENSE_sketchfab.txt"))
		prepare_for_godot(dest, shrink=True)

	credits_path = os.path.join(ROOT, "CREDITS.md")
	with open(credits_path, encoding="utf-8") as f:
		text = f.read()
	for group, lines in credits.items():
		header = CREDIT_HEADERS[group]
		new_lines = [line for line in lines if line not in text]
		if not new_lines:
			continue
		if header not in text:
			text = text.rstrip() + f"\n\n{header}\n\n"
		# Las lineas nuevas van al final de su seccion
		start = text.index(header)
		end = text.find("\n## ", start + len(header))
		end = len(text) if end < 0 else end
		section = text[start:end].rstrip() + "\n" + "\n".join(new_lines) + "\n"
		text = text[:start] + section + ("\n" + text[end:].lstrip("\n") if end < len(text) else "")
	with open(credits_path, "w", encoding="utf-8") as f:
		f.write(text.rstrip() + "\n")
	print(f"OK: {len(solo) or len(MODELS)} modelos en {OUT_DIR}; creditos en CREDITS.md")


if __name__ == "__main__":
	main()
