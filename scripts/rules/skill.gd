class_name Skill
extends RefCounted
## As 18 perícias do SRD 5.2.1 e o atributo associado a cada uma.

const ABILITY_BY_SKILL := {
	&"acrobatics": Ability.DEXTERITY,
	&"animal_handling": Ability.WISDOM,
	&"arcana": Ability.INTELLIGENCE,
	&"athletics": Ability.STRENGTH,
	&"deception": Ability.CHARISMA,
	&"history": Ability.INTELLIGENCE,
	&"insight": Ability.WISDOM,
	&"intimidation": Ability.CHARISMA,
	&"investigation": Ability.INTELLIGENCE,
	&"medicine": Ability.WISDOM,
	&"nature": Ability.INTELLIGENCE,
	&"perception": Ability.WISDOM,
	&"performance": Ability.CHARISMA,
	&"persuasion": Ability.CHARISMA,
	&"religion": Ability.INTELLIGENCE,
	&"sleight_of_hand": Ability.DEXTERITY,
	&"stealth": Ability.DEXTERITY,
	&"survival": Ability.WISDOM,
}

const NAMES := {
	&"acrobatics": "Acrobacia",
	&"animal_handling": "Adestrar Animais",
	&"arcana": "Arcanismo",
	&"athletics": "Atletismo",
	&"deception": "Enganação",
	&"history": "História",
	&"insight": "Intuição",
	&"intimidation": "Intimidação",
	&"investigation": "Investigação",
	&"medicine": "Medicina",
	&"nature": "Natureza",
	&"perception": "Percepção",
	&"performance": "Atuação",
	&"persuasion": "Persuasão",
	&"religion": "Religião",
	&"sleight_of_hand": "Prestidigitação",
	&"stealth": "Furtividade",
	&"survival": "Sobrevivência",
}


static func all() -> Array[StringName]:
	var result: Array[StringName] = []
	for skill: StringName in ABILITY_BY_SKILL:
		result.append(skill)
	return result


static func is_valid(skill: StringName) -> bool:
	return ABILITY_BY_SKILL.has(skill)


static func ability_for(skill: StringName) -> StringName:
	return ABILITY_BY_SKILL.get(skill, &"")
