extends Node
## GameState: Singleton que persiste el estado del juego entre muertes y niveles.
## Almacena qué special coins ya fueron activadas y las estadísticas del nivel.

signal boss_defeated()
signal life_lost(lives_remaining: int)
signal life_gained(lives_remaining: int)
signal game_over()

## Conjunto de nombres de special coins que ya han sido usadas.
var used_special_coins: Dictionary = {}

## Vidas del jugador.
## MAX_LIVES  → vidas con las que empieza cada nivel.
## MAX_STORED_LIVES → tope máximo acumulable (p. ej. recogiendo manzanas).
## Modifica estos valores para ajustar la dificultad.
const MAX_LIVES: int = 3
const MAX_STORED_LIVES: int = 9
var lives: int = MAX_LIVES

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
	lives = MAX_LIVES


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


## Descuenta una vida. Retorna true si quedan vidas, false si es Game Over.
func lose_life() -> bool:
	record_death()
	lives = max(0, lives - 1)
	life_lost.emit(lives)
	if lives <= 0:
		game_over.emit()
		return false
	return true


## Añade una vida (hasta MAX_STORED_LIVES). Usada por las manzanas.
func gain_life() -> void:
	lives = min(MAX_STORED_LIVES, lives + 1)
	life_gained.emit(lives)


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
