extends SceneTree

# Dibuja los iconos de 16 x 16 de los materiales del taller (Materiales.gd) en
# textures/materiales/<id>.png. Cada familia comun tiene su forma (PLANTILLAS) y cada nivel sus
# colores, con 1-3 puntitos abajo a la derecha; los especiales y trofeos tienen la suya.
# En las plantillas: 1 color principal, 2 sombra, 3 brillo; las demas letras son de PALETA.
#
#   godot --path . --headless -s tools/taller/iconos.gd
#   godot --path . --headless --import

const SALIDA := "res://textures/materiales/"
const PALETA := {
	"k": Color8(20, 16, 24), "w": Color8(240, 236, 224), "y": Color8(250, 210, 40), "o": Color8(240, 120, 30),
	"s": Color8(160, 160, 170), "d": Color8(90, 90, 100),
}
const PUNTITO := Color8(250, 210, 40)

const PLANTILLAS := {
	"tuerca": [
		".....kkkkkk.....",
		"....k333311k....",
		"...k33311111k...",
		"..k3311kk1111k..",
		"..k311k..k111k..",
		"..k311k..k112k..",
		"..k1111kk1122k..",
		"...k11111222k...",
		"....k112222k....",
		".....kkkkkk....."],
	"trapo": [
		"..kkkkkkkkkkk...",
		"..k333331111k...",
		"..k311111111k...",
		"..k111111111k...",
		"..k112111211k...",
		"..k111111111k...",
		"..k111111112k...",
		"..k111111122k...",
		"..k111111kkk....",
		"..k11111k2k.....",
		"..k1111k2k......",
		"..kkkkkkk......."],
	"rollo": [
		".....kkkkk......",
		"...kk11111kk....",
		"..k11kkkkk11k...",
		".k1kk33333kk1k..",
		".k1k3kkkkk3k1k..",
		".k1k3k...k3k1k..",
		".k1k3kkkkk3k1k..",
		".k1kk33333kk1k..",
		"..k11kkkkk11k...",
		"...kk11111kk.222",
		".....kkkkk....22"],
	"llama": [
		".......k........",
		"......k3k.......",
		"......k3k.......",
		".....k331k......",
		"....k3311k......",
		"...k331111k.....",
		"..k3311k111k....",
		"..k311k2k11k....",
		"..k31k222k1k....",
		"..k11k222k1k....",
		"...k11k2k1k.....",
		"....kkkkkk......"],
	"gota": [
		".......kk.......",
		"......k31k......",
		".....k3111k.....",
		"....k311111k....",
		"...k31111111k...",
		"...k31111111k...",
		"..k3111111112k..",
		"..k1111111112k..",
		"..k1111111122k..",
		"...k11111122k...",
		"....k111222k....",
		".....kkkkkk....."],
	"vela": [
		".......o........",
		"......oyo.......",
		"......oyo.......",
		".......k........",
		".....kkkkk......",
		".....k311k......",
		".....k311k......",
		".....k311k......",
		".....k312k......",
		".....k112k......",
		"....kkkkkkk.....",
		"....k11122k....."],
	"varilla": [
		"...........kk...",
		"..........k31k..",
		".........k31k...",
		"........k31k....",
		".......k31k.....",
		"......k31k......",
		".....k31k.......",
		"....k31k........",
		"...k31k.........",
		"..k31k..........",
		"..kkk..........."],
	"rejilla": [
		"..1...1...1.....",
		"1111111111111...",
		"..1...1...1.....",
		"..1...1...1.....",
		"1111111111111...",
		"..1...1...1.....",
		"..1...1...1.....",
		"1111111111111...",
		"..1...1...1....."],
	"lingote": [
		"....kkkkkkkk....",
		"...k33333331k...",
		"..k3333333111k..",
		".kkkkkkkkkkkk2k.",
		".k1111111111k2k.",
		".k1111111111kk..",
		".kkkkkkkkkkkk..."],
	"bolsita": [
		"...kkkkkkkkk....",
		"...k2222222k....",
		"...kkkkkkkkk....",
		"...k3111111k....",
		"...k3111111k....",
		"...k1111111k....",
		"...k1111111k....",
		"...k1111112k....",
		"...k1111122k....",
		"...kkkkkkkkk...."],
	"rasguno": [
		"1...1...1.......",
		".1...1...1......",
		".1...1...1......",
		"..1...1...1.....",
		"..1...1...1.....",
		"...1...1...1....",
		"...1...1...1....",
		"....1...1...1...",
		"....1...1...1...",
		".....2...2...2.."],
	"ojo": [
		".....kkkkkk.....",
		"...kkwwwwwwkk...",
		"..kwwwkkkkwwwk..",
		".kwwwk1111kwwwk.",
		"kwwwk11kk11kwwwk",
		".kwwwk1111kwwwk.",
		"..kwwwkkkkwwwk..",
		"...kkwwwwwwkk...",
		".....kkkkkk....."],
	"ceniza": [
		"......2..2......",
		".......2........",
		"................",
		"......kkkk......",
		"....kk3311kk....",
		"...k33111111k...",
		"..k3111111112k..",
		".k111111111122k.",
		"kkkkkkkkkkkkkkkk"],
	"tapa": [
		".......kk.......",
		"......k33k......",
		"...kkkkkkkkkk...",
		"..k3333311111k..",
		".k311111111112k.",
		".k111111111122k.",
		"..kk11111112kk..",
		"....kkkkkkkk...."],
	"diente": [
		"..kkkk..kkkk....",
		".k3331kk1111k...",
		".k331111111111k.",
		".k311111111112k.",
		".k111111111112k.",
		"..k1111111112k..",
		"..k111k..k112k..",
		"..k11k....k12k..",
		"..k1k......k2k..",
		"...k........k..."],
	"chancla": [
		".....kkkkk......",
		"....k31111k.....",
		"...k3122211k....",
		"...k1222221k....",
		"...k1121211k....",
		"...k1111111k....",
		"...k1111111k....",
		"....k111111k....",
		"....k111111k....",
		"....k111112k....",
		".....k1112k.....",
		"......kkkk......"],
	"casco": [
		"......kkkk......",
		"....kk3311kk....",
		"...k33111111k...",
		"..k3111111111k..",
		"..k1111111112k..",
		"..k1111111122k..",
		"kkkkkkkkkkkkkkkk",
		"k22222222222222k",
		"kkkkkkkkkkkkkkkk"],
	"cristal": [
		".......k........",
		"......k3k.......",
		".....k331k......",
		"....k33111k.....",
		"...k3311111k....",
		"...k3111112k....",
		"...k1111122k....",
		"....k11122k.....",
		".....k112k......",
		"......k2k.......",
		".......k........"],
}

# id -> [plantilla, color 1, color 2, color 3]. Los comunes llevan ademas sus puntitos de nivel
const ICONOS := {
	"rebaba": ["tuerca", Color8(150, 80, 40), Color8(90, 46, 24), Color8(200, 120, 70)],
	"tuerca": ["tuerca", Color8(150, 150, 160), Color8(90, 90, 100), Color8(220, 220, 230)],
	"engrane": ["tuerca", Color8(200, 170, 60), Color8(130, 100, 30), Color8(250, 230, 140)],
	"hilacha": ["trapo", Color8(200, 190, 170), Color8(140, 130, 115), Color8(240, 235, 220)],
	"trapo": ["trapo", Color8(200, 60, 60), Color8(130, 30, 30), Color8(240, 120, 110)],
	"cuero": ["trapo", Color8(120, 70, 35), Color8(70, 40, 20), Color8(170, 110, 60)],
	"alambrito": ["rollo", Color8(170, 170, 180), Color8(100, 100, 110), Color8(230, 230, 240)],
	"cable": ["rollo", Color8(60, 60, 70), Color8(200, 40, 40), Color8(120, 120, 130)],
	"cobre": ["rollo", Color8(210, 110, 50), Color8(140, 60, 25), Color8(250, 170, 110)],
	"cerillo": ["llama", Color8(240, 140, 40), Color8(250, 220, 80), Color8(250, 200, 120)],
	"thinner": ["llama", Color8(210, 50, 40), Color8(250, 180, 60), Color8(250, 120, 90)],
	"polvora": ["llama", Color8(110, 60, 140), Color8(250, 230, 120), Color8(180, 120, 220)],
	"agua_sucia": ["gota", Color8(120, 110, 70), Color8(80, 70, 40), Color8(170, 160, 110)],
	"agua_llave": ["gota", Color8(90, 150, 220), Color8(40, 80, 150), Color8(170, 210, 250)],
	"agua_destilada": ["gota", Color8(200, 240, 250), Color8(120, 190, 220), Color8(255, 255, 255)],
	"pabilo": ["vela", Color8(230, 225, 210), Color8(170, 165, 150), Color8(255, 255, 245)],
	"veladora": ["vela", Color8(200, 40, 50), Color8(130, 20, 30), Color8(240, 110, 110)],
	"agua_bendita": ["vela", Color8(90, 160, 230), Color8(40, 90, 160), Color8(200, 230, 255)],
	"varilla_corta": ["varilla", Color8(120, 110, 105), Color8(60, 55, 50), Color8(170, 160, 150)],
	"alambron": ["rollo", Color8(110, 110, 115), Color8(60, 60, 65), Color8(160, 160, 170)],
	"varilla_armada": ["rejilla", Color8(150, 140, 130), Color8(0, 0, 0), Color8(0, 0, 0)],
	"plata_taxco": ["lingote", Color8(200, 205, 215), Color8(120, 125, 135), Color8(250, 250, 255)],
	"baba_verde": ["gota", Color8(110, 200, 60), Color8(50, 120, 30), Color8(190, 250, 120)],
	"polvo_serenol": ["bolsita", Color8(235, 235, 240), Color8(60, 120, 200), Color8(255, 255, 255)],
	"varilla_84": ["varilla", Color8(80, 220, 230), Color8(30, 120, 140), Color8(210, 255, 255)],
	"marca_cazador": ["rasguno", Color8(220, 40, 40), Color8(120, 20, 20), Color8(0, 0, 0)],
	"ojo_turba": ["ojo", Color8(200, 40, 40), Color8(0, 0, 0), Color8(0, 0, 0)],
	"ceniza": ["ceniza", Color8(110, 110, 115), Color8(240, 120, 30), Color8(170, 170, 175)],
	"tapa_tinaco": ["tapa", Color8(70, 70, 80), Color8(40, 40, 46), Color8(120, 120, 130)],
	"diente_jefe": ["diente", Color8(230, 225, 200), Color8(170, 160, 120), Color8(255, 255, 245)],
	"chancla_oro": ["chancla", Color8(240, 200, 50), Color8(170, 120, 20), Color8(255, 240, 150)],
	"casco_gela": ["casco", Color8(60, 120, 210), Color8(30, 60, 120), Color8(140, 190, 250)],
	"cobalto": ["cristal", Color8(60, 200, 240), Color8(20, 100, 150), Color8(200, 250, 255)],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	if not _revisar():
		quit(1)
		return
	var materiales: Dictionary = load("res://scripts/Materiales.gd").LISTA
	for id: String in materiales:
		if not ICONOS.has(id):
			push_error("falta el icono de %s" % id)
			continue
		var icono: Array = ICONOS[id]
		var img := _dibujar(PLANTILLAS[icono[0]], [icono[1], icono[2], icono[3]])
		var nivel: int = materiales[id]["nivel"]
		for p in nivel + 1:
			if nivel >= 0:
				img.set_pixel(14 - p * 2, 14, PUNTITO)
				img.set_pixel(14 - p * 2, 15, PUNTITO.darkened(0.3))
		img.save_png(SALIDA + id + ".png")
		print("material ", id)
	quit()


func _revisar() -> bool:
	var bien := true
	for nombre: String in PLANTILLAS:
		var filas: Array = PLANTILLAS[nombre]
		for f in filas.size():
			var fila: String = filas[f]
			if fila.length() != 16:
				push_error("plantilla %s fila %d: %d de ancho" % [nombre, f, fila.length()])
				bien = false
			for letra in fila:
				if letra != "." and not letra in "123" and not PALETA.has(letra):
					push_error("plantilla %s fila %d: letra '%s'" % [nombre, f, letra])
					bien = false
	return bien


# Centrado por lo que ocupa el dibujo; deja libre el renglon de abajo para los puntitos
func _dibujar(filas: Array, colores: Array) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var x0 := 16
	var x1 := -1
	for fila: String in filas:
		for x in fila.length():
			if fila[x] != ".":
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
	var dx := (16 - (x1 - x0 + 1)) / 2 - x0
	var dy := maxi((14 - filas.size()) / 2, 0)
	for y in filas.size():
		var fila: String = filas[y]
		for x in fila.length():
			var letra := fila[x]
			var color := Color(0, 0, 0, 0)
			if letra in "123":
				color = colores[int(letra) - 1]
			elif PALETA.has(letra):
				color = PALETA[letra]
			if color.a > 0.0 and x + dx >= 0 and x + dx < 16:
				img.set_pixel(x + dx, y + dy, color)
	return img
