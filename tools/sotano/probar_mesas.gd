extends SceneTree

# Revisa las reglas del blackjack (scripts/sotano/Blackjack.gd) y de la ruleta (Ruleta.gd), sin
# ventana: godot --path . --headless -s tools/sotano/probar_mesas.gd  ->  RESULTADO: BIEN

var _mal := 0


func _ver(cond: bool, que: String, detalle := "") -> void:
	print(("ok    " if cond else "MAL   ") + que + ("  " + detalle if detalle != "" else ""))
	if not cond:
		_mal += 1


func _initialize() -> void:
	var BJ = load("res://scripts/sotano/Blackjack.gd")
	var RU = load("res://scripts/sotano/Ruleta.gd")
	# Cartas: palo * 13 + (rango - 2); as = 12, rey = 11, reina = 10, 9 = 7, 5 = 3
	_ver(BJ.valor([12, 11]) == 21 and BJ.es_blackjack([12, 11]), "as y rey: blackjack")
	_ver(BJ.valor([12, 12 + 13, 7]) == 21, "as, as y 9: 21", str(BJ.valor([12, 25, 7])))
	_ver(BJ.valor([11, 10, 3]) == 25, "rey, reina y 5: 25 (te pasas)")
	_ver(BJ.valor([12, 3, 11]) == 16, "as, 5 y rey: 16 (el as vale 1)")
	# Muchas manos: pide hasta 17; las fichas cuadran y la trampa solo con apuesta fuerte
	var bj = BJ.new(7)
	var puesto := 0
	var regresado := 0
	var cargadas_chicas := 0
	var cargadas_fuertes := 0
	for i in 4000:
		var apuesta := 1 + i % 10
		bj.empezar(apuesta)
		puesto += apuesta
		var vueltas := 0
		while bj.fase == BJ.Fase.JUGANDO and vueltas < 20:
			if BJ.valor(bj.tuyas) < 17:
				bj.pedir()
			else:
				bj.plantarte()
			vueltas += 1
		if bj.fase != BJ.Fase.FIN:
			_ver(false, "una mano se atoro", str(i))
			break
		regresado += bj.pago
		if bj.cargado:
			if apuesta < BJ.CARGADO_DESDE:
				cargadas_chicas += 1
			else:
				cargadas_fuertes += 1
		if BJ.valor(bj.crupier) < BJ.PLANTA and bj.resultado != "te pasaste" and not BJ.es_blackjack(bj.tuyas):
			_ver(false, "la crupier se planto antes de 17", str(bj.crupier))
			break
	var regreso := float(regresado) / puesto
	_ver(regreso > 0.75 and regreso < 1.0, "la casa gana poco a poco", "regresa %.1f %%" % (regreso * 100.0))
	_ver(cargadas_chicas == 0 and cargadas_fuertes > 0, "carga el zapato solo con apuesta fuerte", "%d fuertes" % cargadas_fuertes)
	# Doblar: con dos cartas, una mas y se acaba
	bj.empezar(2)
	while bj.fase != BJ.Fase.JUGANDO:
		bj.empezar(2)
	_ver(bj.doblar() and bj.apuesta == 4 and bj.tuyas.size() == 3 and bj.fase == BJ.Fase.FIN, "doblar: apuesta doble, una carta y se acaba")
	# Ruleta: 18 rojos, 18 negros, 1 verde; pagos; la trampa
	var cuentas := {"rojo": 0, "negro": 0, "verde": 0}
	for n in RU.ORDEN:
		cuentas[RU.color(n)] += 1
	_ver(cuentas.rojo == 18 and cuentas.negro == 18 and cuentas.verde == 1, "37 casillas: 18, 18 y el verde")
	var vecinas_bien := true
	for k in RU.ORDEN.size():
		var a: int = RU.ORDEN[k]
		var b: int = RU.ORDEN[(k + 1) % RU.ORDEN.size()]
		if a != 0 and b != 0 and RU.color(a) == RU.color(b):
			vecinas_bien = false
	_ver(vecinas_bien, "las casillas vecinas son de otro color")
	_ver(RU.premio("rojo", 3, 1) == 6 and RU.premio("verde", 2, 0) == 72 and RU.premio("negro", 5, 1) == 0, "pagos: 1 a 1 y 35 a 1")
	var ru = RU.new(11)
	var rojos_chico := 0
	var rojos_fuerte := 0
	var frenos_chicos := 0
	for i in 20000:
		if RU.color(ru.tirar("rojo", 1)) == "rojo":
			rojos_chico += 1
		if ru.freno:
			frenos_chicos += 1
		if RU.color(ru.tirar("rojo", 20)) == "rojo":
			rojos_fuerte += 1
	_ver(frenos_chicos == 0, "con poco en juego no hay trampa")
	_ver(absf(rojos_chico / 20000.0 - 18.0 / 37.0) < 0.02, "rojo sale 18 de 37", "%.3f" % (rojos_chico / 20000.0))
	_ver(rojos_fuerte < rojos_chico * 0.85, "con mucho en juego la casa frena", "%d contra %d" % [rojos_fuerte, rojos_chico])
	# Baccarat: valores, la tabla de la banca, pagos y la trampa
	var BA = load("res://scripts/sotano/Baccarat.gd")
	_ver(BA.valor([12, 7]) == 0 and BA.valor([3, 4]) == 1 and BA.valor([11, 6]) == 8, "baccarat: as 1, figuras 0, sin decenas",
		"%d %d %d" % [BA.valor([12, 7]), BA.valor([3, 4]), BA.valor([11, 6])])
	# (la tercera va como carta: la de valor v es la v - 2 de picas)
	_ver(BA.banca_pide(3, 4) and not BA.banca_pide(3, 6) and not BA.banca_pide(6, 0) and BA.banca_pide(6, 4) and not BA.banca_pide(7, -1)
		and BA.banca_pide(5, -1), "la banca pide segun su tabla")
	var ba = BA.new(5)
	var ganados := {"punto": 0, "banca": 0, "empate": 0}
	var puesto_b := 0
	var regreso_b := 0
	var arreglos_chicos := 0
	var naturales_bien := true
	for i in 6000:
		ba.jugar("banca", 1)
		ganados[ba.ganador] += 1
		puesto_b += 1
		regreso_b += ba.pago("banca", 1)
		if ba.arreglo:
			arreglos_chicos += 1
		if (BA.valor(ba.punto.slice(0, 2)) >= 8 or BA.valor(ba.banca.slice(0, 2)) >= 8) and (ba.punto.size() > 2 or ba.banca.size() > 2):
			naturales_bien = false
	_ver(naturales_bien, "con natural nadie pide")
	_ver(arreglos_chicos == 0, "con apuesta chica no hay arreglo")
	var p_banca: float = ganados.banca / 6000.0
	var p_punto: float = ganados.punto / 6000.0
	_ver(p_banca > p_punto and absf(p_banca - 0.458) < 0.03 and absf(ganados.empate / 6000.0 - 0.095) < 0.025, "banca gana un poco mas que punto, empate ~9.5 %",
		"banca %.3f punto %.3f empate %.3f" % [p_banca, p_punto, ganados.empate / 6000.0])
	ba.ganador = "banca"
	_ver(ba.pago("banca", 10) == 19 and ba.pago("punto", 10) == 0, "la banca paga menos el 5 %")
	ba.ganador = "empate"
	_ver(ba.pago("empate", 2) == 18 and ba.pago("punto", 3) == 3, "empate: 8 a 1, y a punto y banca se les regresa")
	var gana_fuerte := 0
	for i in 6000:
		ba.jugar("punto", 10)
		if ba.ganador == "punto":
			gana_fuerte += 1
	_ver(gana_fuerte / 6000.0 < p_punto - 0.05, "con apuesta fuerte la casa vuelve a barajar", "punto %.3f" % (gana_fuerte / 6000.0))
	print("RESULTADO: " + ("BIEN" if _mal == 0 else "MAL (%d)" % _mal))
	quit()
