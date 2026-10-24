class_name RulesEngine
extends RefCounted
## Cálculos de regras sem estado (SRD 5.2.1). Não conhece cenas nem interface.
## Fontes e adaptações: docs/RULES_POLICY.md.

const MIN_LEVEL := 1
const MAX_LEVEL := 20

## Arranjo padrão para gerar atributos.
const STANDARD_ARRAY: Array[int] = [15, 14, 13, 12, 10, 8]

## Compra de pontos: custo de cada valor (8 a 15) e orçamento total.
const POINT_BUY_COSTS := {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9}
const POINT_BUY_BUDGET := 27

## Penalidade de deslocamento ao usar armadura pesada sem a Força exigida.
const HEAVY_ARMOR_SPEED_PENALTY := 10

const PASSIVE_BASE := 10
const PASSIVE_ADVANTAGE_BONUS := 5

const UNARMORED_BASE_AC := 10


## Bônus de proficiência: +2 nos níveis 1-4, +3 nos 5-8, ... +6 nos 17-20.
static func proficiency_bonus(level: int) -> int:
	var clamped := clampi(level, MIN_LEVEL, MAX_LEVEL)
	@warning_ignore("integer_division")
	return 2 + (clamped - 1) / 4


## Bônus de um teste de atributo, perícia ou resistência.
## Especialização dobra o bônus de proficiência (só se houver proficiência).
static func test_bonus(ability_score: int, proficient: bool, expertise: bool, level: int) -> int:
	var bonus := Ability.modifier(ability_score)
	if proficient:
		bonus += proficiency_bonus(level) * (2 if expertise else 1)
	return bonus


## Valor passivo: 10 + bônus, +5 com vantagem, -5 com desvantagem.
static func passive_score(bonus: int, advantage: D20Test.Advantage = D20Test.Advantage.NONE) -> int:
	var value := PASSIVE_BASE + bonus
	match advantage:
		D20Test.Advantage.ADVANTAGE:
			value += PASSIVE_ADVANTAGE_BONUS
		D20Test.Advantage.DISADVANTAGE:
			value -= PASSIVE_ADVANTAGE_BONUS
	return value


## Classe de Armadura. "armor" é o registro de conteúdo da armadura (ou vazio = sem armadura):
## - leve: base_ac + Destreza;
## - média: base_ac + Destreza limitada por dex_cap (penalidade negativa se aplica);
## - pesada: só base_ac (a Destreza não se aplica, nem negativa).
## shield_bonus vem do registro do escudo (0 = sem escudo).
## unarmored_defense_score: valor do atributo da Defesa sem Armadura (Bárbaro: Con; Monge: Sab),
## ou -1 se não se aplica. Só vale sem armadura; com vários cálculos possíveis, usa-se o maior.
static func armor_class(dexterity_score: int, armor: Dictionary, shield_bonus: int = 0,
		unarmored_defense_score: int = -1) -> int:
	var dex_mod := Ability.modifier(dexterity_score)
	var ac := UNARMORED_BASE_AC + dex_mod
	if armor.is_empty() and unarmored_defense_score >= 0:
		ac = maxi(ac, UNARMORED_BASE_AC + dex_mod + Ability.modifier(unarmored_defense_score))
	if not armor.is_empty():
		var applied_dex := dex_mod
		if armor.get("armor_category") == "heavy":
			applied_dex = 0
		else:
			var cap: int = int(armor.get("dex_cap", -1))
			if cap >= 0:
				applied_dex = mini(dex_mod, cap)
		ac = int(armor["base_ac"]) + applied_dex
	return ac + shield_bonus


## Pontos de vida máximos com média fixa por nível:
## nível 1 = face máxima do dado + Con; cada nível seguinte = (face / 2 + 1) + Con.
## Cada nível concede no mínimo 1 PV. bonus_per_level soma traços como Robustez Anã.
static func max_hit_points(level: int, hit_die: int, constitution_score: int, bonus_per_level: int = 0) -> int:
	var clamped := clampi(level, MIN_LEVEL, MAX_LEVEL)
	var con_mod := Ability.modifier(constitution_score)
	@warning_ignore("integer_division")
	var average := hit_die / 2 + 1
	var total := maxi(1, hit_die + con_mod + bonus_per_level)
	for i in range(1, clamped):
		total += maxi(1, average + con_mod + bonus_per_level)
	return total


## Descanso curto: gasta um Dado de Vida e recupera dado + Con (mínimo 0 por dado).
## Retorna os PV recuperados (antes de limitar ao máximo; quem chama limita).
static func spend_hit_die(roller: DiceRoller, hit_die: int, constitution_score: int) -> int:
	return maxi(0, roller.roll_die(hit_die) + Ability.modifier(constitution_score))


## Total de Dados de Vida = nível do personagem.
static func hit_dice_total(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)


static func initiative_bonus(dexterity_score: int) -> int:
	return Ability.modifier(dexterity_score)


## Deslocamento em pés, aplicando a penalidade de armadura pesada sem Força suficiente.
static func speed(base_speed: int, armor: Dictionary, strength_score: int) -> int:
	var required: int = int(armor.get("strength_requirement", 0))
	if required > 0 and strength_score < required:
		return maxi(0, base_speed - HEAVY_ARMOR_SPEED_PENALTY)
	return base_speed


## Valida um arranjo padrão: cada valor de STANDARD_ARRAY usado exatamente uma vez.
static func validate_standard_array(scores: Dictionary) -> Array[String]:
	var errors := _validate_ability_keys(scores)
	if not errors.is_empty():
		return errors
	var values: Array = scores.values().map(func(v: Variant) -> int: return int(v))
	values.sort()
	var expected: Array = []
	expected.append_array(STANDARD_ARRAY)
	expected.sort()
	if values != expected:
		errors.append("Arranjo padrão deve usar exatamente os valores %s, um por atributo" % str(STANDARD_ARRAY))
	return errors


## Valida compra de pontos: valores 8-15 e custo total até POINT_BUY_BUDGET.
static func validate_point_buy(scores: Dictionary) -> Array[String]:
	var errors := _validate_ability_keys(scores)
	if not errors.is_empty():
		return errors
	var spent := 0
	for ability: StringName in Ability.ALL:
		var value := int(scores[ability])
		if not POINT_BUY_COSTS.has(value):
			errors.append("%s: valor %d fora do intervalo 8-15 da compra de pontos" % [Ability.NAMES[ability], value])
		else:
			spent += int(POINT_BUY_COSTS[value])
	if errors.is_empty() and spent > POINT_BUY_BUDGET:
		errors.append("Compra de pontos gasta %d pontos (máximo %d)" % [spent, POINT_BUY_BUDGET])
	return errors


static func point_buy_cost(scores: Dictionary) -> int:
	var spent := 0
	for ability: StringName in Ability.ALL:
		spent += int(POINT_BUY_COSTS.get(int(scores.get(ability, 8)), 0))
	return spent


## Aumento de atributos do antecedente: +2 em um e +1 em outro, ou +1 em três,
## sempre entre os atributos listados pelo antecedente e sem passar de 20.
static func validate_background_increase(increases: Dictionary, allowed: Array,
		base_scores: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var values: Array = []
	for ability: Variant in increases:
		var key := StringName(ability)
		var amount := int(increases[ability])
		if amount == 0:
			continue
		if not key in allowed.map(func(a: Variant) -> StringName: return StringName(a)):
			errors.append("Antecedente não permite aumentar %s" % Ability.NAMES.get(key, str(key)))
		values.append(amount)
		if int(base_scores.get(key, 0)) + amount > Ability.PLAYER_MAX_SCORE:
			errors.append("%s passaria de %d" % [Ability.NAMES.get(key, str(key)), Ability.PLAYER_MAX_SCORE])
	values.sort()
	if values != [1, 2] and values != [1, 1, 1]:
		errors.append("Aumento do antecedente deve ser +2/+1 ou +1/+1/+1")
	return errors


static func _validate_ability_keys(scores: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for ability: StringName in Ability.ALL:
		if not scores.has(ability):
			errors.append("Atributo ausente: %s" % Ability.NAMES[ability])
	for key: Variant in scores:
		if not Ability.is_valid(StringName(key)):
			errors.append("Atributo desconhecido: %s" % str(key))
	return errors
