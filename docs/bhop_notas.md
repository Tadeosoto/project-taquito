# Bunnyhop (quitado por ahora)

Se probó y se quitó porque se sentía raro. Quedó anotado por si se retoma.

Versión estilo Counter-Strike, el `PM_AirAccelerate` de Source en `player.gd`, cada tick en el aire:

```gdscript
var deseo := direction.normalized()   # hacia donde aprietas, relativo a la camara
var falta := aire_tope - velocity.dot(deseo)
if falta > 0.0:
	velocity += deseo * minf(falta, aire_aceleracion * speed * delta)
```

- Valores probados: `aire_tope` 0.76 m/s (30 unidades de Source), `aire_aceleracion` 12, tope de velocidad 35 m/s.
- Al caer: 0.12 s sin fricción para volver a saltar, o una tecla guardada desde 0.12 s antes. Después, fricción de Source (5) hasta la velocidad normal: `rapidez -= rapidez * friccion * delta`.
- Medido con un bot soltando W, alternando A/D y girando la cámara, en 10 brincos desde 10 m/s: 90°/s llega a 16 m/s, 150°/s a 18, 300°/s a 16 y 450°/s a 12. Sin girar pierde velocidad.
- Se probó también un multiplicador de +10 % por salto a tiempo: no se sintió como Counter-Strike.
