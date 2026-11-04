extends SceneTree

# Todos los tazos salen de aqui. A partir de dibujitos de 16 x 16 hechos a mano abajo (TAZOS) y
# sus fichas (FICHAS: nombre, serie, que desbloquea) escribe:
#   textures/tazos/*.png           la cara, al doble, en un disco de 64 x 64 con la orilla de
#                                  la rareza y su numero; y reverso.png
#   textures/tazos/silueta/*.png   la sombra, para el album cuando no lo tienes
#   resources/tazos/*.tres         el TazoData (Tazos.gd lista la carpeta: uno nuevo sale solo)
#   textures/habilidades/*.png     los iconos de 16 x 16 de las habilidades (ICONOS)
# Revisa que cada dibujo mida 16 y que los numeros vayan seguidos. Diseños propios del mundo del
# juego (docs/lore.md, docs/personajes.md); nada copiado de los tazos de otras marcas.
#
#   godot --path . --headless -s tools/tazos/caras.gd
#   godot --path . --headless --import

const LADO := 64
const SALIDA := "res://textures/tazos/"

const PALETA := {
	"k": Color8(20, 16, 24), "w": Color8(240, 236, 224), "g": Color8(110, 150, 70),
	"G": Color8(60, 92, 40), "r": Color8(200, 40, 40), "R": Color8(120, 20, 24),
	"b": Color8(70, 140, 220), "B": Color8(30, 70, 140), "c": Color8(170, 220, 250),
	"y": Color8(250, 210, 40), "Y": Color8(200, 140, 20), "o": Color8(240, 120, 30),
	"n": Color8(130, 80, 40), "N": Color8(80, 48, 24), "s": Color8(160, 160, 170),
	"d": Color8(90, 90, 100), "p": Color8(230, 140, 150), "m": Color8(120, 50, 140),
	"t": Color8(214, 160, 116), "T": Color8(150, 98, 64), "l": Color8(200, 200, 208),
}

# [archivo, numero, rareza (0 comun, 1 raro, 2 holo), fondo, dibujo]
const TAZOS := [
	["zombi", 1, 0, Color8(225, 214, 180), [
		"................",
		".....kkkkkk.....",
		"...kkggggggkk...",
		"..kggggggggggk..",
		"..kgggGggggggk..",
		".kgkkkgggkkkggk.",
		".kgkwkgggkwkggk.",
		".kggkggGggkgggk.",
		".kgggggggggGggk.",
		".kgggkkkkkkgggk.",
		"..kggkRwRwkggk..",
		"..kggkRRRRkggk..",
		"...kggkkkkggk...",
		"....kkggggkk....",
		"......kkkk......",
		"................"]],
	["garrafon", 2, 0, Color8(225, 214, 180), [
		"......kkkk......",
		"......kbbk......",
		".....kkkkkk.....",
		"....kcccccck....",
		"...kccbbbbcck...",
		"..kcbbbbbbbbck..",
		"..kcbwwbbbbbck..",
		"..kcbwbbbbbbck..",
		"..kbbbbbbbbbbk..",
		"..kcbbbbbbbbck..",
		"..kcbbbbbbbbck..",
		"..kbbbbbbbbbbk..",
		"..kcbbbbbbbbck..",
		"..kBbbbbbbbbBk..",
		"...kkkkkkkkkk...",
		"................"]],
	["paloma", 3, 0, Color8(225, 214, 180), [
		"................",
		"..........kkk...",
		".........kssskk.",
		".........kskwyy.",
		"........ksssk...",
		"......kkssssk...",
		"....kksssssssk..",
		"..kksdddsssssk..",
		".kdddddddsssk...",
		"..kkddddssssk...",
		"....kkkssssk....",
		".......kkkk.....",
		"........o.o.....",
		".......oo.oo....",
		"................",
		"................"]],
	["takis", 4, 0, Color8(225, 214, 180), [
		"................",
		"....kkkkkkkk....",
		"...kmmmmmmmmk...",
		"...kmyyyyyymk...",
		"...kmmmmmmmmk...",
		"...kmmrrrrmmk...",
		"...kmrooorrmk...",
		"...kmroyyorRk...",
		"...kmrooyorRk...",
		"...kmmrrorRmk...",
		"...kmmmrRRmmk...",
		"...kmmmmmmmmk...",
		"...kmwwmwwmwk...",
		"...kmmmmmmmmk...",
		"....kkkkkkkk....",
		"................"]],
	["machete", 5, 0, Color8(225, 214, 180), [
		"................",
		"............kk..",
		"...........kssk.",
		"..........kswsk.",
		".........kswsk..",
		"........kswsk...",
		".......kswsk....",
		"......kswsk.....",
		".....kswsk......",
		"....kswsk.......",
		"...kkssk........",
		"..knkkk.........",
		".knNk...........",
		"knNk............",
		"kNk.............",
		".k.............."]],
	["poste", 6, 0, Color8(225, 214, 180), [
		"................",
		"...kkkkkkk......",
		"...kddddddkk....",
		"...kkkkkkddk....",
		"....kyyyykdk....",
		".....kyyk.dk....",
		"..........dk....",
		"..........dk....",
		"..........dk....",
		"..........dk....",
		"..........dk....",
		"..........dk....",
		"..........dk....",
		".........kddk...",
		"........kddddk..",
		"................"]],
	["tinaco", 7, 1, Color8(200, 220, 240), [
		"................",
		".....kkkkkk.....",
		"....kddddddk....",
		"...kkkkkkkkkk...",
		"...kddddddddk...",
		"...kdkkkkkkdk...",
		"...kddddddddk...",
		"...kdkkkkkkdk...",
		"...kddddddddk...",
		"...kdkkkkkkdk...",
		"...kddddddddk...",
		"...kkkkkkkkkk...",
		"...kdk....kdk...",
		"...kdk....kdk...",
		"...kkk....kkk...",
		"................"]],
	["perro", 8, 1, Color8(200, 220, 240), [
		"................",
		"..kk........kk..",
		".knnk......knnk.",
		".knNnkkkkkknNnk.",
		"..knnnnnnnnnnk..",
		"..knnnnnnnnnnk..",
		"..knkwknnkwknk..",
		"..knkkknnkkknk..",
		"..knnnnwwnnnnk..",
		"...knnwkkwnnk...",
		"...knnwwwwnnk...",
		"....knnppnnk....",
		".....knppnk.....",
		"......kkkk......",
		"................",
		"................"]],
	["gota", 9, 1, Color8(200, 220, 240), [
		".......kk.......",
		"......kbbk......",
		"......kbbk......",
		".....kbbbbk.....",
		".....kbcbbk.....",
		"....kbcbbbbk....",
		"...kbcbbbbbbk...",
		"...kbcbbbbbbk...",
		"..kbbbbbbbbbbk..",
		"..kbbwbbbbbbbk..",
		"..kbbwbbbbbbBk..",
		"..kbbbbbbbbbBk..",
		"...kbbbbbbbBk...",
		"....kBbbbbBk....",
		".....kkkkkk.....",
		"................"]],
	["luna", 10, 1, Color8(40, 44, 80), [
		"................",
		"......kkkk......",
		"....kkyyyyk.....",
		"...kyyyyyk......",
		"..kyyyyyk....w..",
		"..kyyyyk........",
		".kyyyyyk........",
		".kyyyyk.....w...",
		".kyyyyk.........",
		".kyyyyyk........",
		"..kyyyyk........",
		"..kyyyyyk...w...",
		"...kYyyyyk......",
		"....kkYyyyk.....",
		"......kkkk......",
		"................"]],
	["virgen", 11, 2, Color8(60, 30, 70), [
		".......yy.......",
		"...y...yy...y...",
		"....y.kkkk.y....",
		"y....kGGGGk....y",
		".y..kGGppGGk..y.",
		"....kGpkkpGk....",
		"...kGGGppGGGk...",
		"yy.kGrGGGGrGk.yy",
		"...kGrrrrrrGk...",
		"...kGGrrrrGGk...",
		".y.kGGGrrGGGk.y.",
		"...kGGGGGGGGk...",
		"y...kGGGGGGk...y",
		"....kkRRRRkk....",
		"...y.kRkkRk.y...",
		".......kk......."]],
	["jefe", 12, 2, Color8(70, 20, 24), [
		"....kkkkkkkk....",
		"..kkbbbbbbbbkk..",
		".kbbbbbbbbbbbbk.",
		".kbbBbbbbbbBbbk.",
		"kbbkkkbbbbkkkbbk",
		"kbkrrrkbbkrrrkbk",
		"kbkrwrkbbkrwrkbk",
		"kbbkkkbBbbkkkbbk",
		"kbbbbbbBbbbbbbbk",
		"kbbkkkkkkkkkkbbk",
		"kbkwkwkwkwkwkkbk",
		"kbkRRRRRRRRRRkbk",
		"kbkwkwkwkwkwkkbk",
		".kbkkkkkkkkkkbk.",
		"..kkbbbbbbbbkk..",
		"....kkkkkkkk...."]],

	# --- Serie 2: La noche ---
	["gordo", 13, 0, Color8(72, 76, 104), [
		"................",
		".....kkkkkk.....",
		"....kggggggk....",
		"....kgkggkgk....",
		"....kggggggk....",
		"....kgRRRRgk....",
		"..kkkkggggkkkk..",
		".kggggggggggggk.",
		"kgggGggggggGgggk",
		"kggGggggggggGggk",
		"kggggggggggggggk",
		".kgggggGGgggggk.",
		".kggggggggggggk.",
		"..kgggk..kgggk..",
		"..kkkkk..kkkkk..",
		"................"]],
	["tambo", 14, 0, Color8(72, 76, 104), [
		"......o...y.....",
		"....o.yo.oyo....",
		"...oyoyyooyyo...",
		"...oyyyyyyyyo...",
		"..kkkkkkkkkkkk..",
		"..knnnnnnnnnnk..",
		"..kNNNNNNNNNNk..",
		"..knnnnnnnnnnk..",
		"..knnnnnnnnnnk..",
		"..kNNNNNNNNNNk..",
		"..knnnnnnnnnnk..",
		"..knnnnnnnnnnk..",
		"..kNNNNNNNNNNk..",
		"..knnnnnnnnnnk..",
		"..kkkkkkkkkkkk..",
		"................"]],
	["tablas", 15, 0, Color8(72, 76, 104), [
		"................",
		"kkkkkkkkkkkkkkkk",
		"knnnnnnnsnnnnnnk",
		"kNNNNNNNNNNNNNNk",
		"kkkkkkkkkkkkkkkk",
		"...knk....knk...",
		"kkkkkkkkkkkkkkkk",
		"knsnnnnnnnnnnsnk",
		"kNNNNNNNNNNNNNNk",
		"kkkkkkkkkkkkkkkk",
		"...knk....knk...",
		"kkkkkkkkkkkkkkkk",
		"knnnnnnsnnnnnnnk",
		"kNNNNNNNNNNNNNNk",
		"kkkkkkkkkkkkkkkk",
		"................"]],
	["rata", 16, 0, Color8(72, 76, 104), [
		"................",
		"................",
		"................",
		"................",
		"..........kk....",
		".....kkkkkkpkk..",
		"....kdddddddddk.",
		"...kddddddddkddk",
		"..kdddddddddddpk",
		".kddddddddddddk.",
		"pkdddddddddddk..",
		"p.kkdkkkkdkkk...",
		".p..pk....pk....",
		"..pp............",
		"................",
		"................"]],
	["foco", 17, 0, Color8(72, 76, 104), [
		"................",
		".....kkkkkk.....",
		"....kcccccck....",
		"...kcwccckcck...",
		"...kcwcckccck...",
		"...kccckcccck...",
		"...kcccckccck...",
		"....kcckccck....",
		".....kcccck.....",
		"......kkkk......",
		".....kssssk.....",
		".....kddddk.....",
		".....kssssk.....",
		"......kddk......",
		".......kk.......",
		"................"]],
	["huesos", 18, 0, Color8(72, 76, 104), [
		"................",
		".....kkkkkk.....",
		"....kwwwwwwk....",
		"...kwwwwwwwwk...",
		"...kwkkwwkkwk...",
		"...kwkkwwkkwk...",
		"...kwwwkkwwwk...",
		"....kwwwwwwk....",
		".....kwkwkk.....",
		"kk....kkkk....kk",
		"kwk..........kwk",
		".kwkk......kkwk.",
		"...kwwkkkkwwk...",
		".kwkk......kkwk.",
		"kwk..........kwk",
		"kk............kk"]],
	["cazador", 19, 1, Color8(90, 30, 30), [
		"....r......r....",
		".....kkkkkk.....",
		"...kkggggggkk...",
		"..kggggggggggk..",
		"..kgkkggggkkgk..",
		"..kgkrkggkrkgk..",
		"..kggggggggggk..",
		"..kgggGggggggk..",
		"..kggkkkkkkggk..",
		"..kgkwRwRwRkgk..",
		"..kggkkkkkkggk..",
		"...kggggggggk...",
		"....kkggggkk....",
		"......kkkk......",
		"...r........r...",
		"................"]],
	["buho", 20, 1, Color8(40, 44, 80), [
		"................",
		"..kk........kk..",
		"..knk......knk..",
		"..knnkkkkkknnk..",
		"..knnnnnnnnnnk..",
		"..knkkknnkkknk..",
		"..kkyyykkyyykk..",
		"..kkykykkykykk..",
		"..kkyyykkyyykk..",
		"..knkkkookkknk..",
		"..knnnnkknnnnk..",
		"..knwnwnnwnwnk..",
		"...knwnwwnwnk...",
		"....knnnnnnk....",
		".....kokkok.....",
		"................"]],
	["gato", 21, 1, Color8(230, 140, 50), [
		"................",
		"...k........k...",
		"...kk......kk...",
		"...kdk....kdk...",
		"...kddkkkkddk...",
		"...kddddddddk...",
		"..kdyyddddyydk..",
		"..kdykddddykdk..",
		"..kddddppddddk..",
		"...kddwkkwddk...",
		"....kddddddk....",
		"...kddddddddk...",
		"..kddddddddddk..",
		"..kddddddddddkk.",
		"..kddkkkkkkddkdk",
		"...kkk....kkk.k."]],
	["amanecer", 22, 1, Color8(250, 200, 140), [
		"................",
		".......y........",
		"..y....y....y...",
		"...y...y...y....",
		"....y..y..y.....",
		"................",
		"......kkkk......",
		"....kkyyyykk....",
		"...kyyyyyyyyk...",
		"..kyyyywyyyyyk..",
		"..kyyyyyyyyyyk..",
		"kkkkkkkkkkkkkkkk",
		"oooooooooooooooo",
		"rrrrrrrrrrrrrrrr",
		"RRRRRRRRRRRRRRRR",
		"................"]],
	["luna_roja", 23, 2, Color8(30, 10, 20), [
		"................",
		"......kkkk......",
		"....kkrrrrk.....",
		"...krrrrrk......",
		"..krrrrrk....w..",
		"..krrrrk........",
		".krrrrrk........",
		".krrrrk.....w...",
		".krrrrk.........",
		".krrrrrk........",
		"..krrrrk........",
		"..krrrrrk...w...",
		"...kRrrrrk......",
		"....kkRrrrk.....",
		"......kkkk......",
		"................"]],
	["calavera", 24, 2, Color8(120, 40, 140), [
		"................",
		".....kkkkkk.....",
		"...kkwwwwwwkk...",
		"..kwwwpwwpwwwk..",
		"..kwwwwwwwwwwk..",
		"..kwkkkwwkkkwk..",
		"..kkbybkkbybkk..",
		"..kwkkkwwkkkwk..",
		"..kwwwwkkwwwwk..",
		"...kwrwwwwrwk...",
		"...kwwwwwwwwk...",
		"....kwkwkwkk....",
		"....kwkwkwkk....",
		".....kkkkkk.....",
		"...y..g..g..y...",
		"................"]],

	# --- Serie 3: Los vecinos (docs/personajes.md) ---
	["garrafonero", 25, 0, Color8(230, 200, 170), [
		"................",
		"....kkkkkkk.....",
		"...kbbbbbbbk....",
		"...kbbwbbbbbkkk.",
		"...kkkkkkkkkkk..",
		"...kttttttttk...",
		"...kttkttkttk...",
		"...kttttttttk...",
		"...kttttTtttk...",
		"...ktNNNNNNtk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkbbbbbbkk...",
		"..kbbbbwwbbbbk..",
		"..kbbbbbbbbbbk.."]],
	["dona_rosa", 26, 0, Color8(230, 200, 170), [
		"......kkkk......",
		".....kllllk.....",
		"....kkllllkk....",
		"...kllllllllk...",
		"...kllttttllk...",
		"...klttttttlk...",
		"...kttkttkttk...",
		"...kttttttttk...",
		"...kpttTtttpk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"....kmmmmmmk....",
		"...kmmwmmwmmk...",
		"..kmmmmmmmmmmk..",
		"..kmmmmmmmmmmk.."]],
	["beto", 27, 0, Color8(230, 200, 170), [
		"................",
		"....kkkkkkkk....",
		"...krrrrrrrrk...",
		"...krrwrrrwrrkk.",
		"...kkkkkkkkkkrk.",
		"...kTTTTTTTTk...",
		"...kTTkTTkTTk...",
		"...kTTTTTTTTk...",
		"...kTTTTnTTTk...",
		"...kTkkkkkkTk...",
		"...kTTkkkkTTk...",
		"....kTTTTTTk....",
		".....kkkkkk.....",
		"...kkwwwwwwkk...",
		"..kTkwwwwwwkTk..",
		"..kTkwwwwwwkTk.."]],
	["karla", 28, 0, Color8(230, 200, 170), [
		"................",
		".....kkkkkk.....",
		"....kddddddk....",
		"...kddwddwddk...",
		"..kddkkkkkkddk..",
		"..kdkttttttkdk..",
		"..kdktkttktkdk..",
		"..kdkttttttkdk..",
		"..kdkttppttkdk..",
		"..kdkttttttkdk..",
		"..kddkttttkddk..",
		"..kdddkkkkdddk..",
		"..kddddyyddddk..",
		"..kdddyyyydddk..",
		"..kddddyyddddk..",
		"..kkkkkkkkkkkk.."]],
	["taquero", 29, 0, Color8(230, 200, 170), [
		"....kkkkkkk.....",
		"...kwwwwwwwk....",
		"...kwwwwwwwk....",
		"...kkkkkkkkkk...",
		"...kttttttttk...",
		"...kttkttkttk...",
		"...kttttttttk...",
		"...ktttnntttk...",
		"...kNNNNNNNNk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkwwwwwwkk...",
		"..kwwwwrrwwwwk..",
		"..kwwwrrrrwwwk..",
		"..kwwwwwwwwwwk.."]],
	["radio", 30, 0, Color8(230, 200, 170), [
		"..........k.....",
		"...........k....",
		"............k...",
		"..kkkkkkkkkkkk..",
		"..knnnnnnnnnnk..",
		"..kndddddnyynk..",
		"..kndkdkdnyynk..",
		"..kndddddnnnnk..",
		"..kndkdkdnrrnk..",
		"..kndddddnrrnk..",
		"..knnnnnnnnnnk..",
		"..kNNNNNNNNNNk..",
		"..kkkkkkkkkkkk..",
		"...kk......kk...",
		"................",
		"................"]],
	["padre_chuy", 31, 1, Color8(200, 220, 240), [
		"................",
		".....kkkkkk.....",
		"....kNNNNNNk....",
		"...kNNNNNNNNk...",
		"...kNttttttNk...",
		"...kttttttttk...",
		"...kttkttkttk...",
		"...kttttttttk...",
		"...ktttnntttk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkkkwwkkkk...",
		"..kddddwwddddk..",
		"..kddddddddddk..",
		"..kddddddddddk.."]],
	["dr_lopez", 32, 1, Color8(200, 220, 240), [
		"................",
		".....kkkkkk.....",
		"....klllllkk....",
		"...kllttttllk...",
		"...kttttttttk...",
		"...kkkkttkkkk...",
		"...kkckkkkckk...",
		"...ktkkttkktk...",
		"...ktttnntttk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkwwbbwwkk...",
		"..kwwwwbbwwwwk..",
		"..kwwwwbbwwwwk..",
		"..kwwwwwwwwwwk.."]],
	["nava", 33, 1, Color8(200, 220, 240), [
		"................",
		".....kkkkkk.....",
		"....kNNNNNNk....",
		"...kNNNNNNNNk...",
		"...kNtttttttk...",
		"...kttttttttk...",
		"...kkkkkkkkkk...",
		"...kkdkkkkdkk...",
		"...kttttttttk...",
		"...ktttnntttk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkddwwddkk...",
		"..kddddwwddddk..",
		"..kddddrrddddk.."]],
	["patron", 34, 1, Color8(200, 220, 240), [
		"................",
		".....kkkkkk.....",
		"....knnnnnnk....",
		"....knnnnnnk....",
		"kkkkkkkkkkkkkkkk",
		"knnnnnnnnnnnnnnk",
		"kkkkttttttttkkkk",
		"...kttkttkttk...",
		"...kttttttttk...",
		"...ktttnntttk...",
		"...kNNNNNNNNk...",
		"...kNttkkttNk...",
		"....kNNNNNNk....",
		".....kkkkkk.....",
		"...kkwwyywwkk...",
		"..kwwwwyywwwwk.."]],
	["obispo", 35, 2, Color8(90, 20, 40), [
		".......kk.......",
		"......kwwk......",
		".....kwyywk.....",
		"....kwwyywwk....",
		"....kyyyyyyk....",
		"....kwwyywwk....",
		"...kkkkkkkkkk...",
		"...kttttttttk...",
		"...kttkttkttk...",
		"...ktttnntttk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkyywwyykk...",
		"..kwwyywwyywwk..",
		"..kwwwyyyywwwk.."]],
	["nocturno", 36, 2, Color8(20, 20, 40), [
		"................",
		".....kkkkkk.....",
		"....kddddddk....",
		"...kddddddddk...",
		"..kddkkkkkkddk..",
		"..kdkttttttkdk..",
		"..kdktkttktkdk..",
		"..kdkrrrrrrkdk..",
		"..kdkrRrrRrkdk..",
		"..kdkrrrrrrkdk..",
		"..kddkrrrrkddk..",
		"..kdddkkkkdddk..",
		"..kddddddddddk..",
		"..kdddyddydddk..",
		"..kddddddddddk..",
		"..kkkkkkkkkkkk.."]],

	# --- Serie 4: GelA (docs/lore.md) ---
	["garrafon_gela", 37, 0, Color8(180, 215, 235), [
		"......kkkk......",
		"......kbbk......",
		".....kkkkkk.....",
		"....kcccccck....",
		"...kcccccccck...",
		"..kcbbbbbbbbck..",
		"..kcbbwwwwbbck..",
		"..kcbwbbbbbbck..",
		"..kcbwbbwwbbck..",
		"..kcbwbbbwbbck..",
		"..kcbbwwwwbbck..",
		"..kcbbbbbbbbck..",
		"..kBbbbbbbbbBk..",
		"...kkkkkkkkkk...",
		"................",
		"................"]],
	["serenol", 38, 0, Color8(180, 215, 235), [
		"................",
		"....kkkkkkkk....",
		"....kwwwwwwk....",
		"....kkkkkkkk....",
		"...kooooooook...",
		"...kooooooook...",
		"...kwwwwwwwwk...",
		"...kwbbbbbbwk...",
		"...kwbwbwbbwk...",
		"...kwbbbbbbwk...",
		"...kwwwwwwwwk...",
		"...kooooooook...",
		"...kooooooook...",
		"...kYooooooYk...",
		"....kkkkkkkk....",
		"................"]],
	["decreto", 39, 0, Color8(180, 215, 235), [
		"................",
		".....kkkkkk.....",
		"...kkrrrrrrkk...",
		"..krrwwwwwwrrk..",
		"..krwwwwwwwwrk..",
		".krwwrwwwrrrwrk.",
		".krwwrwrwwwrwrk.",
		".krwwrrrwwrwwrk.",
		".krwwwwrwwrwwrk.",
		".krwwwwrwwrwwrk.",
		"..krwwwwwwwwrk..",
		"..krrwwwwwwrrk..",
		"...kkrrrrrrkk...",
		".....kkkkkk.....",
		"................",
		"................"]],
	["varilla", 40, 0, Color8(180, 215, 235), [
		"c..............c",
		"cbc..........cbc",
		".cbBc......cBbc.",
		"..cbBc....cBbc..",
		"...cBbc..cbBc...",
		"....cbBccBbc....",
		".....cBbbBc.....",
		"......cbBc......",
		"......cBbc......",
		".....cbBBbc.....",
		"....cBbccbBc....",
		"...cbBc..cBbc...",
		"..cBbc....cbBc..",
		".cbBc......cBbc.",
		"cbc..........cbc",
		"c..............c"]],
	["puri_gela", 41, 0, Color8(180, 215, 235), [
		"................",
		"kkkkkkkkkkkkkkkk",
		"kbbbbbbbbbbbbbbk",
		"kbwbbwbwbbwbwwbk",
		"kbbbbbbbbbbbbbbk",
		"kkkkkkkkkkkkkkkk",
		"kwbwbwbwbwbwbwbk",
		".kbwbwbwbwbwbwk.",
		".kssssssssssssk.",
		".kscccsssskkksk.",
		".kscccsssskdksk.",
		".kscccsssskdksk.",
		".ksssssssskdksk.",
		".kkkkkkkkkkkkkk.",
		"dddddddddddddddd",
		"................"]],
	["pipa", 42, 0, Color8(180, 215, 235), [
		"................",
		"................",
		"................",
		"...kkkkkkkk.....",
		"..kbbbbbbbbk....",
		".kbbwbbbbbbbkkk.",
		".kbbbbbbbbbbkck.",
		".kbbbbbbbbbbkcck",
		".kkkkkkkkkkkkkkk",
		".kssssssssssssk.",
		".kkdkkkkkkkkdkk.",
		"..kdk......kdk..",
		"...k........k...",
		"................",
		"................",
		"................"]],
	["buenrostro", 43, 1, Color8(200, 220, 240), [
		"................",
		".....kkkkkk.....",
		"....kNNNNNNk....",
		"...kNNNNNNNNk...",
		"...kNNtttttNk...",
		"...kttttttttk...",
		"...kttkttkttk...",
		"...kttttttttk...",
		"...ktttnntttk...",
		"...ktwwwwwwtk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkBwrrwBkk...",
		"..kBBBwrrwBBBk..",
		"..kBBBBrrBBBBk..",
		"..kBBBBBBBBBBk.."]],
	["gerardo", 44, 1, Color8(200, 220, 240), [
		"................",
		".....kkkkkk.....",
		"....knnnnnnk....",
		"...kkkkkkkkkk...",
		"...kndkkkkdnk...",
		"...kttttttttk...",
		"...kttkttkttk...",
		"...kttttttttk...",
		"...ktttnntttk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkpyyyypkk...",
		"..kppppyyppppk..",
		"..kppppppppppk..",
		"..kppppppppppk.."]],
	["german", 45, 1, Color8(200, 220, 240), [
		"................",
		".....kkkkkk.....",
		"....kwwwwwwk....",
		"...kwwwwwwwwk...",
		"...kwttttttwk...",
		"...kttttttttk...",
		"...kttkttkttk...",
		"...kttttttttk...",
		"...ktttnntttk...",
		"...kwwwwwwwwk...",
		"...kttkkkkttk...",
		"....kttttttk....",
		".....kkkkkk.....",
		"...kkddwwddkk...",
		"..kddddbbddddk..",
		"..kddddbbddddk.."]],
	["gota_negra", 46, 1, Color8(150, 200, 120), [
		".......kk.......",
		"......kddk......",
		"......kddk......",
		".....kddddk.....",
		".....kdmddk.....",
		"....kdmddddk....",
		"...kdmddddddk...",
		"...kdmddddddk...",
		"..kddddddddddk..",
		"..kddgddddddk...",
		"..kddgddddddkk..",
		"..kddddddddddk..",
		"...kddddddddk...",
		"....kkddddkk....",
		".....kkkkkk.....",
		"................"]],
	["gela", 47, 2, Color8(40, 80, 140), [
		"....kkkkkkkk....",
		"...kNNNNNNNNk...",
		"..kNNNNNNNNNNk..",
		"..kNNNNNNNNNNk..",
		"..kNNttttttNNk..",
		"..kNttttttttNk..",
		"..kNtkkttkktNk..",
		"..kNttttttttNk..",
		"..kytttnntttyk..",
		"..kNttrrrrttNk..",
		"..kNNttrrttNNk..",
		"..kNNkttttkNNk..",
		"..kNNNkkkkNNNk..",
		"...kkbbwwbbkk...",
		"..kbbbbwwbbbbk..",
		"..kbbbbbbbbbbk.."]],
	["tinaco_eterno", 48, 2, Color8(20, 40, 80), [
		"...y..cccc..y...",
		"....ccbbbbcc....",
		"...cbkkkkkkbc...",
		"...ckddddddkc...",
		"..ckkkkkkkkkkc..",
		"..ckddddddddkc..",
		"..ckdkkkkkkdkc..",
		"..ckddddddddkc..",
		"..ckdkkkkkkdkc..",
		"..ckddddddddkc..",
		"..ckkkkkkkkkkc..",
		"..ckdk....kdkc..",
		"..ckdk....kdkc..",
		".cckkk....kkkcc.",
		"cbbbbbbbbbbbbbbc",
		".cccccccccccccc."]],
]

# id -> [nombre, serie, habilidad que desbloquea]. Lo usa _ficha para escribir resources/tazos/*.tres
const FICHAS := {
	"zombi": ["Zombi", 0, ""], "garrafon": ["Garrafón", 0, ""], "paloma": ["Paloma", 0, ""],
	"takis": ["Takis", 0, ""], "machete": ["Machete", 0, ""], "poste": ["Poste", 0, ""],
	"tinaco": ["Tinaco", 0, "iman"], "perro": ["Perro del barrio", 0, ""],
	"gota": ["Gota limpia", 0, ""], "luna": ["Luna", 0, ""],
	"virgen": ["Virgen del Tinaco", 0, "segundo_aire"], "jefe": ["El Jefe", 0, ""],
	"gordo": ["Zombi gordo", 1, ""], "tambo": ["Tambo prendido", 1, ""], "tablas": ["Tablas", 1, ""],
	"rata": ["Rata", 1, ""], "foco": ["Foco fundido", 1, ""], "huesos": ["Huesos", 1, ""],
	"cazador": ["Cazador", 1, ""], "buho": ["Búho", 1, "ojo_halcon"],
	"gato": ["Gato negro", 1, "pies_de_gato"], "amanecer": ["Amanecer", 1, ""],
	"luna_roja": ["Luna roja", 1, ""], "calavera": ["Calavera de azúcar", 1, ""],
	"garrafonero": ["El garrafonero", 2, ""], "dona_rosa": ["Doña Rosa", 2, ""],
	"beto": ["Beto Ríos", 2, ""], "karla": ["Karla la beata", 2, ""], "taquero": ["El taquero", 2, ""],
	"radio": ["La radio de Sofía", 2, ""], "padre_chuy": ["Padre Chuy", 2, ""],
	"dr_lopez": ["Dr. López", 2, ""], "nava": ["Inspector Nava", 2, ""], "patron": ["El Patrón", 2, ""],
	"obispo": ["Obispo Marín", 2, ""], "nocturno": ["El Nocturno", 2, ""],
	"garrafon_gela": ["Garrafón GelA", 3, ""], "serenol": ["Serenol", 3, ""],
	"decreto": ["Decreto 47", 3, ""], "varilla": ["Varilla del 84", 3, ""],
	"puri_gela": ["Puri-GelA", 3, ""], "pipa": ["La pipa", 3, ""],
	"buenrostro": ["Lic. Buenrostro", 3, ""], "gerardo": ["Gerardo Lazcano", 3, ""],
	"german": ["Germán Lazcano", 3, ""], "gota_negra": ["Gota negra", 3, ""],
	"gela": ["Georgina Lazcano", 3, ""], "tinaco_eterno": ["El tinaco que no se vacía", 3, ""],
}
# Comun 0: los comunes dan un punto por cada Tazos.COMUNES_POR_PUNTO nuevos
const PUNTOS_RAREZA := [0, 1, 2]
const FICHAS_DIR := "res://resources/tazos/"
const SILUETAS := "res://textures/tazos/silueta/"
const SILUETA_FONDO := Color8(34, 34, 40)
const SILUETA_DIBUJO := Color8(16, 16, 20)
const SILUETA_ORILLA := Color8(70, 70, 78)

# Iconos de las habilidades (Habilidades.LISTA), 16 x 16 centrados, en textures/habilidades/
const ICONOS_DIR := "res://textures/habilidades/"
const ICONOS := {
	"vida": [
		"..kkkk..kkkk....",
		".krrrrkkrrrrk...",
		"krrwrrrrrrrrrk..",
		"krwrrrrrrrrrrk..",
		"krrrrrrrrrrrrk..",
		".krrrrrrrrrrk...",
		"..krrrrrrrrk....",
		"...krrrrrrk.....",
		"....krrrrk......",
		".....krrk.......",
		"......kk........"],
	"fuerza": [
		"...kkkkkkkkk....",
		"..kttkttkttk....",
		"..kttkttkttkk...",
		"..kttttttttttk..",
		"..kkkkkkkktttk..",
		"..kttttttktttk..",
		"...kttttttttk...",
		"....kttttttk....",
		"....kssssssk....",
		"....kssssssk....",
		"....kkkkkkkk...."],
	"velocidad": [
		"........kk......",
		"........kyk.....",
		"kkkkkkkkkyyk....",
		"kyyyyyyyyyyyk...",
		"kyyyyyyyyyyyyk..",
		"kyyyyyyyyyyyk...",
		"kkkkkkkkkyyk....",
		"........kyk.....",
		"........kk......"],
	"alcance": [
		"..........kkkk..",
		"kkkkkkkkkkttttk.",
		"ssssssssskttttk.",
		"kkkkkkkkkkttttk.",
		"..........kkkk.."],
	"segundo_aire": [
		".........ccc....",
		"........c...c...",
		"............c...",
		"cccccccccccc....",
		"................",
		"cccccccccccccc..",
		"..............c.",
		"...........c..c.",
		"............cc.."],
	"buen_diente": [
		"....kkkkkkkk....",
		"..kkyyyyyyyykk..",
		".kyygrgrgrgryyk.",
		"kyyggrgrgrggyyk.",
		"kyyyyyyyyyyyyyyk",
		".kkkkkkkkkkkkkk."],
	"piel_dura": [
		"..kkkkkkkkkkkk..",
		"..kssssssssssk..",
		"..kswwssssssdk..",
		"..kswsssssssdk..",
		"..ksssssssssdk..",
		"..ksssssssssdk..",
		"...kssssssssk...",
		"...ksssssssdk...",
		"....ksssssdk....",
		".....ksssdk.....",
		"......kssk......",
		".......kk......."],
	"mas_pesos": [
		".....kkkkkk.....",
		"...kkyyyyyykk...",
		"..kyyYYYYYYyyk..",
		"..kyYyykyyyYyk..",
		".kyYyykkkkyyYyk.",
		".kyYyykyyyyyYyk.",
		".kyYyykkkkyyYyk.",
		".kyYyyyyykyyYyk.",
		".kyYyykkkkyyYyk.",
		"..kyYyykyyyYyk..",
		"..kyyYYYYYYyyk..",
		"...kkyyyyyykk...",
		".....kkkkkk....."],
	"regateo": [
		"...kkkkkkkkkk...",
		"..kwwwwwwwwwwk..",
		".kwkwwrrwwwrwwk.",
		"kwwwwwrrwwrwwwk.",
		".kwwwwwwwrwwwwk.",
		"..kwwwwwrwwrrwk.",
		"...kwwwrwwwrrwk.",
		"....kkkkkkkkkkk."],
	"iman": [
		"..kkkk....kkkk..",
		"..kssk....kssk..",
		"..kssk....kssk..",
		"..krrk....krrk..",
		"..krrk....krrk..",
		"..krrk....krrk..",
		"..krrkkkkkkrrk..",
		"..krrrrrrrrrrk..",
		"...krrrrrrrrk...",
		"....kkkkkkkk...."],
	"ojo_halcon": [
		".....kkkkkk.....",
		"...kkwwwwwwkk...",
		"..kwwwkkkkwwwk..",
		".kwwwkyyyykwwwk.",
		"kwwwkyykkyykwwwk",
		".kwwwkyyyykwwwk.",
		"..kwwwkkkkwwwk..",
		"...kkwwwwwwkk...",
		".....kkkkkk....."],
	"mochilero": [
		"......kkkk......",
		".....kk..kk.....",
		"...kkkkkkkkkk...",
		"..knnnnnnnnnnk..",
		"..knNNNNNNNNnk..",
		"..knnnnnnnnnnk..",
		"..knkkkkkkkknk..",
		"..knknnnnnnknk..",
		"..knknnyynnknk..",
		"..knkkkkkkkknk..",
		"..knnnnnnnnnnk..",
		"..kkkkkkkkkkkk.."],
	"pies_de_gato": [
		"....kk....kk....",
		"...kddk..kddk...",
		"...kddk..kddk...",
		".kk.kk....kk.kk.",
		"kddk........kddk",
		"kddk..kkkk..kddk",
		".kk..kddddk..kk.",
		"....kddddddk....",
		"...kddddddddk...",
		"...kddddddddk...",
		"....kddkkddk....",
		".....kk..kk....."],
	"buena_racha": [
		"...kkkkkkkkkk...",
		"..kwwwwwwwwwwk..",
		"..kwkkwwwwwwwk..",
		"..kwkkwwwwwwwk..",
		"..kwwwwwwwwwwk..",
		"..kwwwwkkwwwwk..",
		"..kwwwwkkwwwwk..",
		"..kwwwwwwwwwwk..",
		"..kwwwwwwwkkwk..",
		"..kwwwwwwwkkwk..",
		"..kwwwwwwwwwwk..",
		"...kkkkkkkkkk..."],
}

const ORILLAS := [Color8(150, 145, 130), Color8(40, 100, 200), Color8(230, 170, 20)]
const ORILLA_OSCURA := [Color8(90, 86, 76), Color8(20, 50, 110), Color8(140, 90, 10)]

# Digitos de 3 x 5 para el numero
const DIGITOS := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001001001001", "111101111101111", "111101111001111"]


func _init() -> void:
	for dir in [SALIDA, SILUETAS, ICONOS_DIR, FICHAS_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if not _revisar():
		quit(1)
		return
	for t: Array in TAZOS:
		var img := _disco(t[3], t[2])
		_dibujo(img, t[4])
		# Numero oscuro sobre fondo claro de los comunes; blanco en los demas y en fondos oscuros
		var claro: bool = t[2] == 0 and (t[3] as Color).get_luminance() > 0.45
		_numero(img, t[1], ORILLA_OSCURA[t[2]] if claro else Color.WHITE)
		img.save_png(SALIDA + t[0] + ".png")
		var sombra := _disco(SILUETA_FONDO, 0, SILUETA_ORILLA)
		_dibujo(sombra, t[4], SILUETA_DIBUJO)
		_numero(sombra, t[1], SILUETA_ORILLA)
		sombra.save_png(SILUETAS + t[0] + ".png")
		_ficha(t)
		print("tazo ", t[0])
	img_reverso().save_png(SALIDA + "reverso.png")
	for id: String in ICONOS:
		_icono(ICONOS[id]).save_png(ICONOS_DIR + id + ".png")
		print("icono ", id)
	quit()


# Que cada dibujo mida 16 de ancho (y los tazos 16 de alto), con letras de la paleta y numeros seguidos
func _revisar() -> bool:
	var bien := true
	var dibujos := {}
	for t: Array in TAZOS:
		dibujos["tazo " + t[0]] = t[4]
		if (t[4] as Array).size() != 16:
			push_error("tazo %s: %d filas" % [t[0], (t[4] as Array).size()])
			bien = false
		if not FICHAS.has(t[0]):
			push_error("tazo %s: falta en FICHAS" % t[0])
			bien = false
	for i in TAZOS.size():
		if TAZOS[i][1] != i + 1:
			push_error("tazo %s: numero %d, deberia ser %d" % [TAZOS[i][0], TAZOS[i][1], i + 1])
			bien = false
	for id: String in ICONOS:
		dibujos["icono " + id] = ICONOS[id]
	for nombre: String in dibujos:
		var filas: Array = dibujos[nombre]
		for f in filas.size():
			var fila: String = filas[f]
			if fila.length() != 16:
				push_error("%s fila %d: %d de ancho" % [nombre, f, fila.length()])
				bien = false
			for letra in fila:
				if letra != "." and not PALETA.has(letra):
					push_error("%s fila %d: letra '%s' fuera de la paleta" % [nombre, f, letra])
					bien = false
	return bien


# El .tres del tazo: lo que lee Tazos.gd (que lista la carpeta, asi que uno nuevo sale solo)
func _ficha(t: Array) -> void:
	var ficha: Array = FICHAS[t[0]]
	var texto := "[gd_resource type=\"Resource\" script_class=\"TazoData\" load_steps=4 format=3]\n\n"
	texto += "[ext_resource type=\"Script\" path=\"res://scripts/TazoData.gd\" id=\"1_tazo\"]\n"
	texto += "[ext_resource type=\"Texture2D\" path=\"%s%s.png\" id=\"2_cara\"]\n" % [SALIDA, t[0]]
	texto += "[ext_resource type=\"Texture2D\" path=\"%s%s.png\" id=\"3_silueta\"]\n\n" % [SILUETAS, t[0]]
	texto += "[resource]\nscript = ExtResource(\"1_tazo\")\n"
	texto += "id = \"%s\"\nnombre = \"%s\"\nnumero = %d\nserie = %d\nrareza = %d\npuntos = %d\n" % [
		t[0], ficha[0], t[1], ficha[1], t[2], PUNTOS_RAREZA[t[2]]]
	texto += "desbloquea = \"%s\"\ncara = ExtResource(\"2_cara\")\nsilueta = ExtResource(\"3_silueta\")\n" % ficha[2]
	var archivo := FileAccess.open(FICHAS_DIR + t[0] + ".tres", FileAccess.WRITE)
	archivo.store_string(texto)


# Un icono de 16 x 16, centrado por lo que ocupa el dibujo
func _icono(filas: Array) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var x0 := 16
	var x1 := -1
	for fila: String in filas:
		for x in fila.length():
			if fila[x] != ".":
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
	var dx := (16 - (x1 - x0 + 1)) / 2 - x0
	var dy := (16 - filas.size()) / 2
	for y in filas.size():
		var fila: String = filas[y]
		for x in fila.length():
			if PALETA.has(fila[x]):
				img.set_pixel(x + dx, y + dy, PALETA[fila[x]])
	return img


# El disco: fondo, un aro de orilla con luz arriba a la izquierda y fuera del disco transparente.
# `orilla` cambia el color del aro (las siluetas)
func _disco(fondo: Color, rareza: int, orilla := Color(0, 0, 0, 0)) -> Image:
	var img := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
	var c := LADO / 2.0
	for y in LADO:
		for x in LADO:
			var dx := x + 0.5 - c
			var dy := y + 0.5 - c
			var r := sqrt(dx * dx + dy * dy)
			if r > c:
				continue
			var color := fondo
			var aro: Color = ORILLAS[rareza] if orilla.a == 0.0 else orilla
			var aro_oscuro: Color = ORILLA_OSCURA[rareza] if orilla.a == 0.0 else orilla.darkened(0.4)
			if r > c - 4.0:
				color = aro.lightened(0.25) if dx + dy < 0.0 else aro
				if r > c - 1.0:
					color = aro_oscuro
			elif r > c - 5.0:
				color = aro_oscuro
			else:
				# Un poco de luz arriba a la izquierda y rayitas como de carton impreso
				color = fondo.lightened(0.08) if dx + dy < -c * 0.6 else fondo
				if (x + y) % 6 == 0:
					color = color.darkened(0.05)
			img.set_pixel(x, y, color)
	return img


# El dibujito de 16 x 16 al doble, centrado un poco abajo para que quepa el numero. Con
# `solo` (alfa > 0) todo el dibujo sale de ese color: la silueta de los que no tienes
func _dibujo(img: Image, filas: Array, solo := Color(0, 0, 0, 0)) -> void:
	var x0 := (LADO - 32) / 2
	var y0 := (LADO - 32) / 2 + 3
	for fy in filas.size():
		var fila: String = filas[fy]
		for fx in fila.length():
			var letra := fila[fx]
			if not PALETA.has(letra):
				continue
			for oy in 2:
				for ox in 2:
					img.set_pixel(x0 + fx * 2 + ox, y0 + fy * 2 + oy, PALETA[letra] if solo.a == 0.0 else solo)


func _numero(img: Image, numero: int, color: Color) -> void:
	var texto := "%02d" % numero
	var x := LADO / 2 - 4
	for ch in texto:
		var d: String = DIGITOS[int(ch)]
		for i in 15:
			if d[i] == "1":
				img.set_pixel(x + i % 3, 7 + i / 3, color)
		x += 4


# El reverso: igual para todos, una espiral de Takis y "TAZO" en letras de pixel
func img_reverso() -> Image:
	var img := _disco(Color8(120, 50, 140), 2)
	var c := LADO / 2.0
	for y in LADO:
		for x in LADO:
			var dx := x + 0.5 - c
			var dy := y + 0.5 - c
			var r := sqrt(dx * dx + dy * dy)
			if r < c - 6.0 and int(r + atan2(dy, dx) * 3.0) % 7 == 0:
				img.set_pixel(x, y, Color8(240, 120, 30))
	var letras := {
		"T": "111010010010010", "A": "010101111101101", "Z": "111001010100111", "O": "111101101101111",
	}
	var x0 := LADO / 2 - 16
	for letra in "TAZO":
		var d: String = letras[letra]
		for i in 15:
			if d[i] == "1":
				for oy in 2:
					for ox in 2:
						img.set_pixel(x0 + (i % 3) * 2 + ox, 27 + (i / 3) * 2 + oy, Color8(250, 210, 40))
		x0 += 8
	return img
