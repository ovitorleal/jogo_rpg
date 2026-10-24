class_name DiceExpression
extends RefCounted
## Expressão de dados simples: "NdM", "NdM+K", "NdM-K" ou uma constante "K".
## Usada por dados de conteúdo (ex.: dano de armas). Não executa código arbitrário.

const VALID_SIDES: Array[int] = [4, 6, 8, 10, 12, 20, 100]
const MAX_COUNT := 100

var count: int = 0
var sides: int = 0
var bonus: int = 0
var is_valid: bool = false
var error: String = ""

static var _pattern: RegEx


static func parse(text: String) -> DiceExpression:
	var expr := DiceExpression.new()
	if _pattern == null:
		_pattern = RegEx.create_from_string("^(?:(\\d+)d(\\d+))?([+-]?\\d+)?$")
	var cleaned := text.strip_edges().to_lower().replace(" ", "")
	var match := _pattern.search(cleaned)
	if cleaned.is_empty() or match == null:
		expr.error = "Expressão de dados inválida: '%s'" % text
		return expr
	if not match.get_string(1).is_empty():
		expr.count = match.get_string(1).to_int()
		expr.sides = match.get_string(2).to_int()
		if expr.count < 1 or expr.count > MAX_COUNT:
			expr.error = "Quantidade de dados fora de 1..%d em '%s'" % [MAX_COUNT, text]
			return expr
		if not expr.sides in VALID_SIDES:
			expr.error = "Dado d%d não suportado em '%s'" % [expr.sides, text]
			return expr
	var bonus_text := match.get_string(3)
	if not bonus_text.is_empty():
		if expr.count > 0 and not (bonus_text.begins_with("+") or bonus_text.begins_with("-")):
			expr.error = "Bônus precisa de sinal em '%s'" % text
			return expr
		expr.bonus = bonus_text.to_int()
	expr.is_valid = true
	return expr


func roll(roller: DiceRoller) -> int:
	var total := bonus
	for value in roller.roll_dice(count, sides):
		total += value
	return total


func minimum() -> int:
	return count + bonus


func maximum() -> int:
	return count * sides + bonus


func _to_string() -> String:
	if count == 0:
		return str(bonus)
	var text := "%dd%d" % [count, sides]
	if bonus != 0:
		text += Ability.format_modifier(bonus)
	return text
