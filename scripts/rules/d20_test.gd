class_name D20Test
extends RefCounted
## Teste de d20 (SRD 5.2.1): rolar 1d20, somar modificadores e comparar com a CD.
## Vale para testes de atributo, perícia e resistência. Nesses testes um 20 natural
## NÃO garante sucesso e um 1 natural NÃO garante falha (isso só vale para ataques).

enum Advantage { NONE, ADVANTAGE, DISADVANTAGE }

var rolls: Array[int] = []
var natural: int = 0
var modifier: int = 0
var total: int = 0
var dc: int = 0
var advantage: Advantage = Advantage.NONE
var success: bool = false


## Qualquer número de fontes de vantagem e de desvantagem se anula: se houver ao menos
## uma de cada, o teste é feito sem nenhuma das duas.
static func resolve_advantage(advantage_sources: int, disadvantage_sources: int) -> Advantage:
	if advantage_sources > 0 and disadvantage_sources > 0:
		return Advantage.NONE
	if advantage_sources > 0:
		return Advantage.ADVANTAGE
	if disadvantage_sources > 0:
		return Advantage.DISADVANTAGE
	return Advantage.NONE


static func roll(roller: DiceRoller, test_modifier: int, difficulty: int,
		advantage_state: Advantage = Advantage.NONE) -> D20Test:
	var result := D20Test.new()
	result.modifier = test_modifier
	result.dc = difficulty
	result.advantage = advantage_state
	result.rolls.append(roller.roll_die(20))
	if advantage_state != Advantage.NONE:
		result.rolls.append(roller.roll_die(20))
	if advantage_state == Advantage.ADVANTAGE:
		result.natural = result.rolls.max()
	elif advantage_state == Advantage.DISADVANTAGE:
		result.natural = result.rolls.min()
	else:
		result.natural = result.rolls[0]
	result.total = result.natural + test_modifier
	result.success = result.total >= difficulty
	return result
