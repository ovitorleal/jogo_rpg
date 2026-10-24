extends "res://tests/base_test.gd"
## Regras de ataque e dano (SRD 5.2.1): críticos, erro automático, dados dobrados,
## resistência, bônus de arma (proficiência, acuidade, versátil, arremesso).

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


func _sheet(rogue: bool) -> CharacterSheet:
	var fixtures := FACTORY_TESTS.new()
	var c: CharacterData = CharacterFactory.create(fixtures.rogue_choices() if rogue else fixtures.fighter_choices(), _registry())[0]
	return CharacterSheet.build(c, _registry())


func _find(attacks: Array[Dictionary], attack_id: String) -> Dictionary:
	for attack in attacks:
		if attack["id"] == attack_id:
			return attack
	return {}


func test_attack_roll_hits_and_misses() -> void:
	assert_true(Attack.roll_attack(DiceRoller.scripted([10]), 5, 15)["hit"], "10 + 5 = 15 contra CA 15 acerta")
	assert_true(not Attack.roll_attack(DiceRoller.scripted([9]), 5, 15)["hit"], "9 + 5 = 14 contra CA 15 erra")


func test_natural_20_always_hits_and_is_critical() -> void:
	var roll := Attack.roll_attack(DiceRoller.scripted([20]), -2, 30)
	assert_true(roll["hit"] and roll["critical"], "20 natural acerta mesmo contra CA 30 e é crítico")


func test_natural_1_always_misses() -> void:
	var roll := Attack.roll_attack(DiceRoller.scripted([1]), 20, 5)
	assert_true(not roll["hit"] and not roll["critical"], "1 natural erra mesmo com total acima da CA")


func test_attack_with_advantage_uses_higher_die() -> void:
	var roll := Attack.roll_attack(DiceRoller.scripted([3, 20]), 0, 25, D20Test.Advantage.ADVANTAGE)
	assert_eq(roll["natural"], 20, "Usa o maior dado")
	assert_true(roll["critical"], "20 com vantagem é crítico")


func test_damage_and_critical_doubles_dice_not_modifier() -> void:
	var expr := DiceExpression.parse("1d8+3")
	assert_eq(Attack.roll_damage(expr, DiceRoller.scripted([5]), false), 8, "5 + 3")
	assert_eq(Attack.roll_damage(expr, DiceRoller.scripted([5, 6]), true), 14, "Crítico: 5 + 6 + 3 (modificador uma vez)")
	assert_eq(Attack.roll_damage(DiceExpression.parse("1d4-3"), DiceRoller.scripted([1]), false), 0, "Dano mínimo 0")


func test_resistance_and_vulnerability() -> void:
	assert_eq(Attack.apply_damage_modifiers(7, "poison", ["poison"]), 3, "Resistência: metade arredondada para baixo")
	assert_eq(Attack.apply_damage_modifiers(7, "fire", ["poison"]), 7, "Sem resistência ao tipo")
	assert_eq(Attack.apply_damage_modifiers(7, "fire", [], ["fire"]), 14, "Vulnerabilidade dobra")


func test_grid_distance() -> void:
	assert_eq(Attack.grid_distance_feet(Vector2i(0, 0), Vector2i(1, 1)), 5, "Diagonal adjacente = 5 pés")
	assert_eq(Attack.grid_distance_feet(Vector2i(0, 0), Vector2i(3, 1)), 15, "Maior eixo × 5")


func test_fighter_weapon_attacks() -> void:
	# Guerreiro: FOR 17 (+3), DES 13 (+1), proficiência +2, com escudo.
	var sheet := _sheet(false)
	var attacks := Attack.weapon_attacks(sheet, _registry().get_entry("item", "item.longsword"))
	assert_eq(attacks.size(), 1, "Espada longa não é arremessável")
	assert_eq(attacks[0]["attack_bonus"], 5, "FOR 3 + proficiência 2")
	assert_eq(attacks[0]["damage"], "1d8+3", "Com escudo, versátil usa uma mão")
	assert_eq(attacks[0]["reach"], 5, "Alcance corpo a corpo")
	sheet.shield = {}
	assert_eq(Attack.weapon_attacks(sheet, _registry().get_entry("item", "item.longsword"))[0]["damage"], "1d10+3",
			"Sem escudo, versátil usa duas mãos")


func test_rogue_finesse_ranged_and_thrown() -> void:
	# Ladino: FOR 8 (-1), DES 17 (+3).
	var sheet := _sheet(true)
	var shortsword := Attack.weapon_attacks(sheet, _registry().get_entry("item", "item.shortsword"))[0]
	assert_eq(shortsword["ability"], Ability.DEXTERITY, "Acuidade usa Destreza quando é maior")
	assert_eq(shortsword["attack_bonus"], 5, "DES 3 + proficiência 2 (marcial com acuidade)")
	assert_eq(shortsword["damage"], "1d6+3", "Dano com Destreza")
	var bow := Attack.weapon_attacks(sheet, _registry().get_entry("item", "item.shortbow"))[0]
	assert_eq([bow["attack_type"], bow["range_normal"], bow["range_long"]], ["ranged", 80, 320], "Arco curto à distância")
	var dagger := Attack.weapon_attacks(sheet, _registry().get_entry("item", "item.dagger"))
	assert_eq(dagger.size(), 2, "Adaga: corpo a corpo e arremesso")
	var thrown := _find(dagger, "item.dagger.thrown")
	assert_eq([thrown["attack_type"], thrown["range_normal"], thrown["range_long"]], ["ranged", 20, 60], "Arremesso 20/60")
	assert_eq(thrown["attack_bonus"], 5, "Arremesso com acuidade usa Destreza")


func test_unarmed_strike() -> void:
	var sheet := _sheet(false)
	var unarmed := Attack.unarmed_strike(sheet)
	assert_eq(unarmed["attack_bonus"], 5, "FOR 3 + proficiência 2")
	assert_eq(unarmed["damage"], "4", "1 + FOR")


func test_weapon_proficiency_by_training() -> void:
	var longsword := _registry().get_entry("item", "item.longsword")
	var scimitar := _registry().get_entry("item", "item.scimitar")
	var rapier := _registry().get_entry("item", "item.rapier")
	var dagger := _registry().get_entry("item", "item.dagger")
	var rogue := ["simple", "martial_finesse_or_light"]
	var monk := ["simple", "martial_light"]
	assert_true(not Attack.is_proficient_with(rogue, longsword), "Ladino não é proficiente com espada longa")
	assert_true(Attack.is_proficient_with(rogue, rapier), "Ladino é proficiente com rapieira (acuidade)")
	assert_true(Attack.is_proficient_with(monk, scimitar), "Monge é proficiente com cimitarra (leve)")
	assert_true(not Attack.is_proficient_with(monk, rapier), "Monge não é proficiente com rapieira (não é leve)")
	assert_true(Attack.is_proficient_with(["simple"], dagger), "Arma simples com treinamento simples")
	assert_true(not Attack.is_proficient_with(["simple"], longsword), "Arma marcial sem treinamento")
