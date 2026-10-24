extends "res://tests/base_test.gd"
## Dados, expressões de dados e testes de d20 com vantagem/desvantagem.


func test_resolve_advantage() -> void:
	assert_eq(D20Test.resolve_advantage(0, 0), D20Test.Advantage.NONE, "Nenhuma fonte")
	assert_eq(D20Test.resolve_advantage(1, 0), D20Test.Advantage.ADVANTAGE, "Só vantagem")
	assert_eq(D20Test.resolve_advantage(0, 2), D20Test.Advantage.DISADVANTAGE, "Só desvantagem")
	assert_eq(D20Test.resolve_advantage(3, 1), D20Test.Advantage.NONE, "Várias vantagens contra uma desvantagem se anulam")


func test_d20_normal_roll() -> void:
	var result := D20Test.roll(DiceRoller.scripted([12]), 3, 15)
	assert_eq(result.rolls, [12] as Array[int], "Um dado")
	assert_eq(result.total, 15, "12 + 3")
	assert_true(result.success, "Total igual à CD é sucesso")
	result = D20Test.roll(DiceRoller.scripted([11]), 3, 15)
	assert_true(not result.success, "14 contra CD 15 falha")


func test_d20_advantage_and_disadvantage() -> void:
	var adv := D20Test.roll(DiceRoller.scripted([5, 17]), 0, 10, D20Test.Advantage.ADVANTAGE)
	assert_eq(adv.rolls.size(), 2, "Vantagem rola dois dados")
	assert_eq(adv.natural, 17, "Vantagem usa o maior")
	var dis := D20Test.roll(DiceRoller.scripted([5, 17]), 0, 10, D20Test.Advantage.DISADVANTAGE)
	assert_eq(dis.natural, 5, "Desvantagem usa o menor")
	assert_true(not dis.success, "5 contra CD 10 falha")


func test_natural_20_and_1_are_not_automatic_in_checks() -> void:
	var nat20 := D20Test.roll(DiceRoller.scripted([20]), -5, 30)
	assert_true(not nat20.success, "20 natural não garante sucesso em teste/resistência")
	var nat1 := D20Test.roll(DiceRoller.scripted([1]), 10, 5)
	assert_true(nat1.success, "1 natural não garante falha em teste/resistência")


func test_seeded_roller_is_reproducible_and_in_range() -> void:
	var a := DiceRoller.new(42)
	var b := DiceRoller.new(42)
	assert_eq(a.roll_dice(20, 20), b.roll_dice(20, 20), "Mesma semente, mesma sequência")
	var faces := {}
	var roller := DiceRoller.new(7)
	for i in 600:
		var value := roller.roll_die(6)
		assert_true(value >= 1 and value <= 6, "d6 fora do intervalo: %d" % value)
		faces[value] = true
	assert_eq(faces.size(), 6, "Todas as faces do d6 aparecem em 600 rolagens")


func test_dice_expression_parsing() -> void:
	var expr := DiceExpression.parse("2d4+2")
	assert_true(expr.is_valid, "2d4+2 é válida")
	assert_eq([expr.count, expr.sides, expr.bonus], [2, 4, 2], "Partes de 2d4+2")
	assert_eq([expr.minimum(), expr.maximum()], [4, 10], "Mínimo e máximo de 2d4+2")
	assert_eq(str(expr), "2d4+2", "Texto normalizado")
	assert_eq(DiceExpression.parse("1d8-1").bonus, -1, "Bônus negativo")
	assert_eq(DiceExpression.parse(" 1D10 ").sides, 10, "Maiúsculas e espaços")
	var constant := DiceExpression.parse("3")
	assert_true(constant.is_valid and constant.count == 0 and constant.bonus == 3, "Constante")
	for bad in ["", "d6", "2d7", "abc", "2d6+", "1d6 2", "0d6", "1d6*2", "2d62"]:
		assert_true(not DiceExpression.parse(bad).is_valid, "Deveria ser inválida: '%s'" % bad)


func test_dice_expression_roll() -> void:
	var expr := DiceExpression.parse("2d4+2")
	assert_eq(expr.roll(DiceRoller.scripted([1, 4])), 7, "1 + 4 + 2")
	var roller := DiceRoller.new(3)
	for i in 200:
		var value := expr.roll(roller)
		assert_true(value >= 4 and value <= 10, "2d4+2 fora do intervalo: %d" % value)
