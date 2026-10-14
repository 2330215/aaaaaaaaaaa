extends Node
## GameState: Singleton que persiste el estado del juego entre muertes.
## Almacena qué special coins ya fueron activadas, para que no reaparezcan.

## Conjunto de nombres de special coins que ya han sido usadas.
var used_special_coins: Dictionary = {}


func mark_coin_used(coin_name: String) -> void:
	used_special_coins[coin_name] = true


func is_coin_used(coin_name: String) -> bool:
	return used_special_coins.has(coin_name)


func reset() -> void:
	## Llama esto si reinicias el juego desde el principio.
	used_special_coins.clear()
