Pruebas de progreso local y desbloqueo:

```sh
XDG_DATA_HOME=/tmp/platformer_progression_test_data XDG_CONFIG_HOME=/tmp/platformer_progression_test_config godot --headless --path . --fixed-fps 120 --log-file /tmp/progression_tests_engine.log res://tests/progression_test.tscn
```

Ejecutar desde la raíz del proyecto. Las partidas de prueba se escriben y borran únicamente en `/tmp/platformer_progression_regression`; las variables XDG también aíslan las preferencias de audio y controles. No se utiliza el guardado real.

La prueba comprueba bloqueo inicial, victoria y desbloqueo en orden, persistencia al recargar, migración del formato anterior, selección individual/compartida, cancelación del borrado, eliminación de progreso y recetas, descarte de la sesión suspendida y retorno al inicio desde una partida activa.
