extends Node
## GameState: Singleton que persiste el estado del juego entre muertes y niveles.
## Almacena qué special coins ya fueron activadas y las estadísticas del nivel.

signal boss_defeated()

## Conjunto de nombres de special coins que ya han sido usadas.
var used_special_coins: Dictionary = {}

## Nivel actual, usado para las estadísticas y la pantalla de victoria.
var current_level: int = 1

var _level_elapsed: float = 0.0
var _level_timer_running: bool = false

var _shots_fired: int = 0
var _enemies_defeated: int = 0
var _coins_collected: int = 0
var _special_coins_used: int = 0
var _deaths: int = 0
var _boss_defeated: bool = false


func _process(delta: float) -> void:
	if _level_timer_running:
		_level_elapsed += delta


## Reinicia las estadísticas al empezar un nivel nuevo.
func begin_level(level_number: int) -> void:
	current_level = level_number
	_level_elapsed = 0.0
	_level_timer_running = true
	_shots_fired = 0
	_enemies_defeated = 0
	_coins_collected = 0
	_special_coins_used = 0
	_deaths = 0
	_boss_defeated = false


func record_shot(count: int = 1) -> void:
	_shots_fired += count


func record_enemy_defeated() -> void:
	_enemies_defeated += 1


func record_coin() -> void:
	_coins_collected += 1


func record_special_coin() -> void:
	_special_coins_used += 1


func record_death() -> void:
	_deaths += 1


## El jefe avisa una sola vez y detiene el cronómetro del nivel.
func notify_boss_defeated() -> void:
	if _boss_defeated:
		return
	_boss_defeated = true
	_level_timer_running = false
	boss_defeated.emit()


## Devuelve una copia lista para mostrar en la pantalla de victoria.
func get_level_stats() -> Dictionary:
	return {
		"level_number": current_level,
		"time_seconds": _level_elapsed,
		"rows": [
			{"label": "Tiempo del nivel", "value": _format_time(_level_elapsed)},
			{"label": "Balas disparadas", "value": str(_shots_fired)},
			{"label": "Enemigos eliminados", "value": str(_enemies_defeated)},
			{"label": "Monedas recogidas", "value": str(_coins_collected)},
			{"label": "Monedas especiales", "value": str(_special_coins_used)},
			{"label": "Muertes", "value": str(_deaths)},
		],
	}


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var minutes := floori(float(total) / 60.0)
	return "%02d:%02d" % [minutes, total % 60]


func mark_coin_used(coin_name: String) -> void:
	used_special_coins[coin_name] = true


func is_coin_used(coin_name: String) -> bool:
	return used_special_coins.has(coin_name)


func reset() -> void:
	## Llama esto si reinicias el juego desde el principio.
	used_special_coins.clear()
	begin_level(1)
