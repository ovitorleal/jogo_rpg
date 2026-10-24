class_name CharacterSheet
extends RefCounted
## Ficha calculada (somente leitura) a partir de CharacterData + conteúdo.
## Toda a matemática vem do RulesEngine; esta classe apenas reúne os resultados.

var character: CharacterData
var species: Dictionary
var class_entry: Dictionary
var background: Dictionary

var scores: Dictionary = {}       # StringName -> int
var modifiers: Dictionary = {}    # StringName -> int
var proficiency_bonus: int = 0
var saving_throws: Dictionary = {}  # StringName -> {bonus, proficient}
var skills: Dictionary = {}         # StringName -> {bonus, proficient, expertise}
var armor_class: int = 0
var max_hp: int = 0
var initiative: int = 0
var speed: int = 0
var passive_perception: int = 0
var stealth_disadvantage: bool = false
var armor: Dictionary = {}
var shield: Dictionary = {}
var weapons: Array[Dictionary] = []
## Características de classe (até o nível atual), traços de espécie e talento de origem.
var features: Array[Dictionary] = []


static func build(c: CharacterData, registry: ContentRegistry) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.character = c
	sheet.species = registry.get_entry("species", c.species_id)
	sheet.class_entry = registry.get_entry("class", c.class_id)
	sheet.background = registry.get_entry("background", c.background_id)
	sheet.armor = registry.get_entry("item", c.armor_id)
	sheet.shield = registry.get_entry("item", c.shield_id)
	for weapon_id in c.weapon_ids:
		sheet.weapons.append(registry.get_entry("item", weapon_id))

	sheet.proficiency_bonus = RulesEngine.proficiency_bonus(c.level)
	for ability: StringName in Ability.ALL:
		sheet.scores[ability] = c.ability_score(ability)
		sheet.modifiers[ability] = Ability.modifier(sheet.scores[ability])

	var save_profs: Array = sheet.class_entry.get("saving_throws", [])
	for ability: StringName in Ability.ALL:
		var proficient := String(ability) in save_profs
		sheet.saving_throws[ability] = {
			"bonus": RulesEngine.test_bonus(sheet.scores[ability], proficient, false, c.level),
			"proficient": proficient,
		}

	var proficient_skills := sheet.skill_proficiencies()
	for skill: StringName in Skill.all():
		var proficient := skill in proficient_skills
		var has_expertise := proficient and skill in c.expertise
		sheet.skills[skill] = {
			"bonus": RulesEngine.test_bonus(sheet.scores[Skill.ability_for(skill)], proficient, has_expertise, c.level),
			"proficient": proficient,
			"expertise": has_expertise,
		}

	var dex: int = sheet.scores[Ability.DEXTERITY]
	sheet.armor_class = RulesEngine.armor_class(dex, sheet.armor, int(sheet.shield.get("ac_bonus", 0)))
	sheet.max_hp = RulesEngine.max_hit_points(c.level, int(sheet.class_entry.get("hit_die", 6)),
			sheet.scores[Ability.CONSTITUTION], int(sheet.species.get("hp_bonus_per_level", 0)))
	sheet.initiative = RulesEngine.initiative_bonus(dex)
	sheet.speed = RulesEngine.speed(int(sheet.species.get("speed", 30)), sheet.armor, sheet.scores[Ability.STRENGTH])
	sheet.passive_perception = RulesEngine.passive_score(sheet.skills[&"perception"]["bonus"])
	sheet.stealth_disadvantage = bool(sheet.armor.get("stealth_disadvantage", false))

	for feature: Dictionary in sheet.class_entry.get("features", []):
		if int(feature.get("level", 1)) <= c.level:
			sheet.features.append(feature)
	sheet.features.append_array(sheet.species.get("traits", []))
	sheet.features.append_array(sheet.background.get("origin_feat", []))
	return sheet


## União das perícias vindas da classe, do antecedente e da espécie.
func skill_proficiencies() -> Array[StringName]:
	var result: Array[StringName] = []
	for skill in character.class_skills + character.species_skills:
		if not skill in result:
			result.append(skill)
	for skill: Variant in background.get("skill_proficiencies", []):
		if not StringName(skill) in result:
			result.append(StringName(skill))
	return result


func skill_bonus(skill: StringName) -> int:
	return skills[skill]["bonus"]


func saving_throw_bonus(ability: StringName) -> int:
	return saving_throws[ability]["bonus"]


## Resolve um teste de perícia contra uma CD usando o rolador informado.
func roll_skill_check(skill: StringName, dc: int, roller: DiceRoller,
		advantage: D20Test.Advantage = D20Test.Advantage.NONE) -> D20Test:
	var state := advantage
	if skill == &"stealth" and stealth_disadvantage:
		var adv := 1 if advantage == D20Test.Advantage.ADVANTAGE else 0
		var dis := 1 + (1 if advantage == D20Test.Advantage.DISADVANTAGE else 0)
		state = D20Test.resolve_advantage(adv, dis)
	return D20Test.roll(roller, skill_bonus(skill), dc, state)


func roll_saving_throw(ability: StringName, dc: int, roller: DiceRoller,
		advantage: D20Test.Advantage = D20Test.Advantage.NONE) -> D20Test:
	return D20Test.roll(roller, saving_throw_bonus(ability), dc, advantage)


func roll_ability_check(ability: StringName, dc: int, roller: DiceRoller,
		advantage: D20Test.Advantage = D20Test.Advantage.NONE) -> D20Test:
	return D20Test.roll(roller, modifiers[ability], dc, advantage)
