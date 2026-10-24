class_name Attack
extends RefCounted
## Jogadas de ataque e dano (SRD 5.2.1).
## - Ataque: d20 + bônus contra a CA. 20 natural sempre acerta e é Acerto Crítico;
##   1 natural sempre erra. (Diferente de testes e resistências, ver D20Test.)
## - Dano: rola os dados da arma; no crítico, os dados são rolados duas vezes
##   (o modificador fixo entra uma vez). Mínimo 0.
## - Resistência reduz à metade (arredondando para baixo); vulnerabilidade dobra.

const FEET_PER_SQUARE := 5
const MELEE_REACH_FEET := 5
## Propriedades de Maestria (SRD 5.2.1), usadas por quem tem a característica Maestria em Armas.
const MASTERY_NAMES := {
	"cleave": "Trespassar", "graze": "Raspar", "nick": "Talhar", "push": "Empurrar", "sap": "Enfraquecer",
	"slow": "Lentidão", "topple": "Derrubar", "vex": "Atormentar",
}
const MASTERY_DESCRIPTIONS := {
	"cleave": "Ao acertar, ataca outra criatura a até 1,5 m do alvo (sem somar o modificador ao dano); uma vez por turno.",
	"graze": "Ao errar, causa dano igual ao modificador de atributo do ataque.",
	"nick": "O ataque extra da propriedade Leve faz parte da ação de Ataque, não da ação bônus; uma vez por turno.",
	"push": "Ao acertar, empurra o alvo até 3 m (Grande ou menor).",
	"sap": "Ao acertar, o alvo tem desvantagem no próximo ataque antes do início do seu próximo turno.",
	"slow": "Ao acertar e causar dano, reduz o deslocamento do alvo em 3 m até o início do seu próximo turno.",
	"topple": "Ao acertar, o alvo faz teste de Constituição (CD 8 + modificador + proficiência) ou fica Caído.",
	"vex": "Ao acertar e causar dano, você tem vantagem no próximo ataque contra o alvo até o fim do seu próximo turno.",
}


## Retorna { rolls, natural, bonus, total, target_ac, advantage, hit, critical }.
## critical_from: menor d20 que é Acerto Crítico (20; 19 ou 18 com Crítico Aprimorado/Superior).
static func roll_attack(roller: DiceRoller, attack_bonus: int, target_ac: int,
		advantage: D20Test.Advantage = D20Test.Advantage.NONE, critical_from: int = 20) -> Dictionary:
	var test := D20Test.roll(roller, attack_bonus, target_ac, advantage)
	var critical := test.natural >= critical_from
	var hit := critical or (test.natural != 1 and test.total >= target_ac)
	return {
		"rolls": test.rolls,
		"natural": test.natural,
		"bonus": attack_bonus,
		"total": test.total,
		"target_ac": target_ac,
		"advantage": advantage,
		"hit": hit,
		"critical": critical,
	}


## Rola o dano de uma expressão ("1d8+3"). No crítico, a quantidade de dados dobra.
static func roll_damage(expression: DiceExpression, roller: DiceRoller, critical: bool) -> int:
	var dice_count := expression.count * (2 if critical else 1)
	var total := expression.bonus
	for value in roller.roll_dice(dice_count, expression.sides):
		total += value
	return maxi(0, total)


static func apply_damage_modifiers(amount: int, damage_type: String, resistances: Array,
		vulnerabilities: Array = []) -> int:
	var result := amount
	if damage_type in resistances:
		@warning_ignore("integer_division")
		result = result / 2
	if damage_type in vulnerabilities:
		result *= 2
	return maxi(0, result)


## Distância em pés na grade: cada quadrado vale 5 pés, inclusive na diagonal.
static func grid_distance_feet(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) * FEET_PER_SQUARE


## Bônus de ataque e dano de uma arma para um personagem.
## Corpo a corpo usa Força; à distância usa Destreza; Acuidade usa o maior dos dois.
## Proficiência entra no ataque se a classe tiver treinamento com a arma.
## Versátil usa o dano de duas mãos quando não há escudo.
## Retorna { id, name, attack_type, ability, proficient, attack_bonus, damage, damage_type,
##           reach, range_normal, range_long, weapon_id, mastery, properties, two_handed,
##           ability_modifier } ou várias entradas (arremesso gera uma extra).
static func weapon_attacks(sheet: CharacterSheet, weapon: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var properties: Array = weapon.get("properties", [])
	var strength: int = sheet.modifiers[Ability.STRENGTH]
	var dexterity: int = sheet.modifiers[Ability.DEXTERITY]
	var ranged: bool = weapon.get("attack_type") == "ranged"
	var ability := Ability.DEXTERITY if ranged else Ability.STRENGTH
	if "finesse" in properties and dexterity > strength:
		ability = Ability.DEXTERITY
	var proficient := is_proficient_with(sheet.class_entry.get("weapon_training", []), weapon)
	var bonus: int = sheet.modifiers[ability] + (sheet.proficiency_bonus if proficient else 0)
	var damage := DiceExpression.parse(str(weapon["damage"]))
	var two_hands := "two_handed" in properties
	if "versatile" in properties and sheet.shield.is_empty() and not str(weapon.get("versatile_damage", "")).is_empty():
		damage = DiceExpression.parse(str(weapon["versatile_damage"]))
		two_hands = true
	damage.bonus += sheet.modifiers[ability]
	var base := {
		"id": str(weapon["id"]),
		"name": str(weapon["name"]),
		"attack_type": "ranged" if ranged else "melee",
		"ability": ability,
		"proficient": proficient,
		"attack_bonus": bonus,
		"damage": str(damage),
		"damage_type": str(weapon["damage_type"]),
		"reach": 0 if ranged else MELEE_REACH_FEET,
		"range_normal": int(weapon.get("range_normal", 0)) if ranged else 0,
		"range_long": int(weapon.get("range_long", 0)) if ranged else 0,
		"weapon_id": str(weapon["id"]),
		"mastery": str(weapon.get("mastery", "")),
		"properties": properties.duplicate(),
		"two_handed": two_hands and not ranged,
		"ability_modifier": int(sheet.modifiers[ability]),
	}
	results.append(base)
	if not ranged and "thrown" in properties:
		var thrown := base.duplicate()
		thrown["id"] = "%s.thrown" % weapon["id"]
		thrown["name"] = "%s (arremesso)" % weapon["name"]
		thrown["attack_type"] = "ranged"
		thrown["reach"] = 0
		thrown["range_normal"] = int(weapon.get("range_normal", 0))
		thrown["range_long"] = int(weapon.get("range_long", 0))
		# Arremesso de arma versátil usa o dano de uma mão.
		var one_hand := DiceExpression.parse(str(weapon["damage"]))
		one_hand.bonus += sheet.modifiers[ability]
		thrown["damage"] = str(one_hand)
		thrown["two_handed"] = false
		results.append(thrown)
	return results


## Ataque desarmado: Força + proficiência; dano 1 + Força (contundente).
static func unarmed_strike(sheet: CharacterSheet) -> Dictionary:
	var strength: int = sheet.modifiers[Ability.STRENGTH]
	return {
		"id": "attack.unarmed_strike",
		"name": "Ataque Desarmado",
		"attack_type": "melee",
		"ability": Ability.STRENGTH,
		"proficient": true,
		"attack_bonus": strength + sheet.proficiency_bonus,
		"damage": str(maxi(0, 1 + strength)),
		"damage_type": "bludgeoning",
		"reach": MELEE_REACH_FEET,
		"range_normal": 0,
		"range_long": 0,
		"weapon_id": "",
		"mastery": "",
		"properties": [],
		"two_handed": false,
		"ability_modifier": strength,
		"unarmed": "damage",
	}


## Opções Agarrar e Empurrar do Ataque Desarmado: teste de resistência de Força ou Destreza
## (o alvo escolhe; aqui, o maior) contra CD 8 + Força + proficiência.
static func unarmed_options(sheet: CharacterSheet) -> Array[Dictionary]:
	var dc := 8 + int(sheet.modifiers[Ability.STRENGTH]) + sheet.proficiency_bonus
	var result: Array[Dictionary] = []
	for option: Array in [["grapple", "Agarrar"], ["shove", "Empurrar (derrubar)"]]:
		result.append({
			"id": "attack.unarmed_%s" % option[0], "name": "Desarmado: %s" % option[1], "attack_type": "melee",
			"ability": Ability.STRENGTH, "proficient": true, "attack_bonus": 0, "damage": "0",
			"damage_type": "bludgeoning", "reach": MELEE_REACH_FEET, "range_normal": 0, "range_long": 0,
			"weapon_id": "", "mastery": "", "properties": [], "two_handed": false,
			"ability_modifier": int(sheet.modifiers[Ability.STRENGTH]), "unarmed": option[0], "save_dc": dc,
		})
	return result


static func is_proficient_with(training: Array, weapon: Dictionary) -> bool:
	var properties: Array = weapon.get("properties", [])
	match weapon.get("weapon_category"):
		"simple":
			return "simple" in training
		"martial":
			if "martial" in training:
				return true
			if "martial_finesse_or_light" in training and ("finesse" in properties or "light" in properties):
				return true
			if "martial_light" in training and "light" in properties:
				return true
	return false
