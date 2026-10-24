class_name DiceRoller
extends RefCounted
## Fonte única de aleatoriedade das regras. Semente configurável para reprodutibilidade
## e resultados roteirizados para testes determinísticos.

var _rng := RandomNumberGenerator.new()
var _scripted: Array[int] = []


## seed_value < 0 usa uma semente aleatória.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Cria um rolador que devolve os valores na ordem dada; depois, usa a semente 0.
static func scripted(values: Array[int]) -> DiceRoller:
	var roller := DiceRoller.new(0)
	roller._scripted = values.duplicate()
	return roller


func get_seed() -> int:
	return _rng.seed


func roll_die(sides: int) -> int:
	assert(sides >= 1, "Dado precisa de ao menos 1 face")
	if not _scripted.is_empty():
		var value: int = _scripted.pop_front()
		assert(value >= 1 and value <= sides, "Valor roteirizado %d fora de 1..%d" % [value, sides])
		return clampi(value, 1, sides)
	return _rng.randi_range(1, sides)


func roll_dice(count: int, sides: int) -> Array[int]:
	var results: Array[int] = []
	for i in count:
		results.append(roll_die(sides))
	return results
