class_name TinacoVida
extends Acompanante

## La vida del tinaco de la Virgen en el evento de la reja (F1): un Acompanante quieto y sin modelo puesto en el eje
## del TinacoComunitario de la plaza de Santa Mugre. Los zombis lo prefieren a ti si lo tienen mas cerca
## (Acompanante.el_mas_cercano, con `atrae` grande: van por el agua de toda la colonia) y le pegan desde la orilla
## del tinaco (`radio`, Zombie._decidir). Al llegar a 0 avisa con `cayo` y el evento se pierde
## (Misiones.acompanante_cayo). Lo crea MisionesMundo con `acompanante = "tinaco"` en un paso DEFENDER.

const ATRAE := 400.0


static func crear_tinaco(padre: Node, tinaco: Node3D, con_vida: int, vida_total: int) -> TinacoVida:
	var t := TinacoVida.new()
	t.name = "TinacoVida"
	t.quieto = true
	t.atrae = ATRAE
	t.vida = con_vida
	t.vida_max = vida_total
	t.radio = float(tinaco.get("radio")) if tinaco.get("radio") != null else 1.0
	padre.add_child(t)
	t.global_position = tinaco.global_position
	return t


func recibir_golpe(dano: int) -> void:
	if _cayo:
		return
	vida -= dano
	if vida <= 0:
		_cayo = true
		activos.erase(self)
		cayo.emit()
