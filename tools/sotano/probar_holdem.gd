extends SceneTree
# Prueba de Holdem.gd (scripts/sotano/): manos conocidas y miles de manos entre IAs, sin trabarse y
# sin perder fichas (lo de la mesa + la comision de la casa = lo del principio).
#   godot --path . --headless -s tools/sotano/probar_holdem.gd

const H := preload("res://scripts/sotano/Holdem.gd")
var _bien := true


func _ver(cond: bool, que: String) -> void:
	print(("ok    " if cond else "MAL   ") + que)
	_bien = _bien and cond


# "Ah" -> carta (rango y palo: s h d c)
func c(t: String) -> int:
	var r := "23456789TJQKA".find(t[0]) + 2
	return "shdc".find(t[1]) * 13 + (r - 2)


func m(ts: String) -> Array:
	return Array(ts.split(" ")).map(func(t: String) -> int: return c(t))


func _init() -> void:
	_ver(H.mejor(m("Ah Kh Qh Jh Th 2c 3d"))[0] == 8, "escalera de color")
	_ver(H.mejor(m("As Ad Ah Ac 2c 3d 9h"))[0] == 7, "poquer")
	_ver(H.mejor(m("As Ad Ah Kc Kd 3d 9h"))[0] == 6, "full")
	_ver(H.mejor(m("2h 7h 9h Jh Kh 3d 4c"))[0] == 5, "color")
	_ver(H.mejor(m("Ah 2d 3c 4s 5h 9d Kc")) == [4, 5], "escalera chica (as abajo)")
	_ver(H.mejor(m("9h 9d 9c 4s 5h 2d Kc"))[0] == 3, "tercia")
	_ver(H.mejor(m("9h 9d 4c 4s 5h 2d Kc")) == [2, 9, 4, 13], "dos pares con su carta")
	_ver(H.comparar(H.mejor(m("Ah Ad 4c 7s 9h 2d Kc")), H.mejor(m("Kh Kd 4c 7s 9h 2d Qc"))) > 0, "par de ases gana a par de reyes")
	_ver(H.nombre(H.mejor(m("Qh Qd Qc 4s 4h 2d 9c"))) == "Full de reinas", "nombre del full")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var manos := 0
	var trabadas := 0
	var casa := 0
	var h := H.new(11)
	for n in ["Tu", "Doña Cuca", "El Güero", "Tacho"]:
		h.agregar(n, 100, ["cerrado", "flojo", "tramposo", "farol"][h.jugadores.size()])
	var total := 400
	var gano_tramposo := 0
	for k in 2000:
		for j: Dictionary in h.jugadores:
			if j.fichas < 4:
				total += 100 - j.fichas
				j.fichas = 100
		if not h.empezar():
			break
		var pasos := 0
		while h.fase != H.Fase.FIN and pasos < 200:
			var i := h.turno
			var acc: String = h.decidir(i) if i != 0 else ["pasar", "subir", "retirarse"][rng.randi_range(0, 2)]
			h.actuar(i, acc)
			pasos += 1
		if pasos >= 200:
			trabadas += 1
		casa += h.rake
		manos += 1
		if h.ganadores.has(2):
			gano_tramposo += 1
		var suma := 0
		for j: Dictionary in h.jugadores:
			suma += j.fichas
		if suma + casa != total:
			_ver(false, "fichas cuadran en la mano %d (%d + %d != %d)" % [k, suma, casa, total])
			break
	_ver(trabadas == 0 and manos == 2000, "2000 manos sin trabarse (%d trabadas)" % trabadas)
	print("   la casa se quedo %d fichas; el de la gorra gano %d manos de %d" % [casa, gano_tramposo, manos])
	print("RESULTADO: " + ("BIEN" if _bien else "MAL"))
	quit()
