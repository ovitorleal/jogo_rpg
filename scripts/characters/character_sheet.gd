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
## Talentos (antecedente, níveis e Estilo de Luta).
var feat_ids: Array[String] = []
## Características ativas (classe + subclasse) até o nível atual.
var feature_ids: Array[String] = []
## Treinamento com armas e armaduras (classe + Ordem Divina/Primal).
var weapon_training: Array = []
var armor_training: Array = []


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
	var trained := CharacterChoices.training(c, registry)
	sheet.weapon_training = trained["weapons"]
	sheet.armor_training = trained["armor"]
	for feature in CharacterChoices.active_features(c, registry):
		sheet.feature_ids.append(str(feature["id"]))
	for ability: StringName in Ability.ALL:
		sheet.scores[ability] = c.ability_score(ability)
	# Campeão Primal (Bárbaro 20) e Corpo e Mente (Monge 20): +4, máximo 25.
	for boost: Array in [["feature.primal_champion", [Ability.STRENGTH, Ability.CONSTITUTION]],
			["feature.body_and_mind", [Ability.DEXTERITY, Ability.WISDOM]]]:
		if boost[0] in sheet.feature_ids:
			for ability: StringName in boost[1]:
				sheet.scores[ability] = mini(25, sheet.scores[ability] + 4)
	for ability: StringName in Ability.ALL:
		sheet.modifiers[ability] = Ability.modifier(sheet.scores[ability])

	var save_profs: Array = sheet.class_entry.get("saving_throws", []).duplicate()
	# Mente Escorregadia (Ladino 15): Sabedoria e Carisma; Sobrevivente Disciplinado (Monge 14): todos.
	if "feature.slippery_mind" in sheet.feature_ids:
		save_profs.append_array(["wis", "cha"])
	if "feature.disciplined_survivor" in sheet.feature_ids:
		save_profs = ["str", "dex", "con", "int", "wis", "cha"]
	for ability: StringName in Ability.ALL:
		var proficient := String(ability) in save_profs
		sheet.saving_throws[ability] = {
			"bonus": RulesEngine.test_bonus(sheet.scores[ability], proficient, false, c.level),
			"proficient": proficient,
		}

	var proficient_skills := sheet.skill_proficiencies()
	var all_expertise := CharacterChoices.expertise(c)
	for skill: StringName in Skill.all():
		var proficient := skill in proficient_skills
		var has_expertise := proficient and skill in all_expertise
		var skill_bonus_value := RulesEngine.test_bonus(sheet.scores[Skill.ability_for(skill)], proficient, has_expertise, c.level)
		# Pau para Toda Obra (Bardo 2): metade da proficiência em perícias sem proficiência.
		if not proficient and "feature.jack_of_all_trades" in sheet.feature_ids:
			@warning_ignore("integer_division")
			skill_bonus_value += sheet.proficiency_bonus / 2
		# Taumaturgo (Arcanismo/Religião) e Mago da Ordem Primal (Arcanismo/Natureza): +Sabedoria (mínimo +1).
		if (skill in [&"arcana", &"religion"] and CharacterChoices.has_option(c, "divine_order.thaumaturge")) \
				or (skill in [&"arcana", &"nature"] and CharacterChoices.has_option(c, "primal_order.magician")):
			skill_bonus_value += maxi(1, sheet.modifiers[Ability.WISDOM])
		sheet.skills[skill] = {
			"bonus": skill_bonus_value,
			"proficient": proficient,
			"expertise": has_expertise,
		}

	var dex: int = sheet.scores[Ability.DEXTERITY]
	var unarmored_score := -1
	var unarmored_ability := StringName(sheet.class_entry.get("unarmored_defense_ability", ""))
	if not unarmored_ability.is_empty() and (sheet.shield.is_empty()
			or sheet.class_entry.get("unarmored_defense_allows_shield", true)):
		unarmored_score = sheet.scores[unarmored_ability]
	sheet.armor_class = RulesEngine.armor_class(dex, sheet.armor, int(sheet.shield.get("ac_bonus", 0)), unarmored_score)
	sheet.max_hp = RulesEngine.max_hit_points(c.level, int(sheet.class_entry.get("hit_die", 6)),
			sheet.scores[Ability.CONSTITUTION], int(sheet.species.get("hp_bonus_per_level", 0)))
	# Resiliência Dracônica (Dracônica 3): +1 PV por nível de feiticeiro; sem armadura, CA 10 + Des + Car.
	var shield_bonus := int(sheet.shield.get("ac_bonus", 0))
	if "feature.draconic_resilience" in sheet.feature_ids:
		sheet.max_hp += c.level
		if sheet.armor.is_empty():
			sheet.armor_class = maxi(sheet.armor_class, 10 + sheet.modifiers[Ability.DEXTERITY] + sheet.modifiers[Ability.CHARISMA] + shield_bonus)
	# Armadura das Sombras (invocação): Armadura Arcana permanente, CA 13 + Des sem armadura.
	if "invocation.armor_of_shadows" in CharacterChoices.invocations(c) and sheet.armor.is_empty():
		sheet.armor_class = maxi(sheet.armor_class, 13 + sheet.modifiers[Ability.DEXTERITY] + shield_bonus)
	sheet.initiative = RulesEngine.initiative_bonus(dex)
	sheet.feat_ids.assign(CharacterChoices.feats(c, registry).map(func(f: Dictionary) -> String: return f["feat_id"]))
	# Alerta: proficiência na iniciativa. Defesa: +1 na CA com armadura.
	if "feat.alert" in sheet.feat_ids:
		sheet.initiative += sheet.proficiency_bonus
	if "feat.defense" in sheet.feat_ids and not sheet.armor.is_empty():
		sheet.armor_class += 1
	sheet.speed = RulesEngine.speed(int(sheet.species.get("speed", 30)), sheet.armor, sheet.scores[Ability.STRENGTH])
	var heavy: bool = sheet.armor.get("armor_category") == "heavy"
	# Movimento Rápido (Bárbaro 5) e Andarilho (Patrulheiro 6): +3 m sem armadura pesada.
	for fast in ["feature.fast_movement", "feature.roving"]:
		if fast in sheet.feature_ids and not heavy:
			sheet.speed += 10
	# Movimento sem Armadura (Monge 2+): bônus da tabela sem armadura nem escudo.
	if "feature.unarmored_movement" in sheet.feature_ids and sheet.armor.is_empty() and sheet.shield.is_empty():
		sheet.speed += int(ClassFeatures.raw_value(c, registry, "unarmored_movement"))
	sheet.passive_perception = RulesEngine.passive_score(sheet.skills[&"perception"]["bonus"])
	sheet.stealth_disadvantage = bool(sheet.armor.get("stealth_disadvantage", false))

	sheet.features.append_array(CharacterChoices.active_features(c, registry))
	for feature: Dictionary in sheet.species.get("traits", []):
		if int(feature.get("level", 1)) <= c.level:
			sheet.features.append(feature)
	for feat_id in sheet.feat_ids:
		var feat := registry.get_entry("feat", feat_id)
		if not feat.is_empty():
			sheet.features.append({"id": feat_id, "name": feat["name"], "description": feat["description"],
					"implemented": feat["implemented"], "level": 1})
	return sheet


## União das perícias vindas da classe, do antecedente, da espécie e das escolhas (talentos, características).
func skill_proficiencies() -> Array[StringName]:
	var result: Array[StringName] = []
	for skill in character.class_skills + character.species_skills:
		if not skill in result:
			result.append(skill)
	for skill: Variant in background.get("skill_proficiencies", []):
		if not StringName(skill) in result:
			result.append(StringName(skill))
	for skill in CharacterChoices.chosen_skills(character):
		if not skill in result:
			result.append(skill)
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
	var test := D20Test.roll(roller, skill_bonus(skill), dc, state)
	# Talento Confiável (Ladino 7): em perícia proficiente, d20 de 9 ou menos vale 10.
	if "feature.reliable_talent" in feature_ids and skills[skill]["proficient"] and test.natural < 10:
		test.natural = 10
		test.total = 10 + test.modifier
		test.success = test.total >= dc
	return test


func roll_saving_throw(ability: StringName, dc: int, roller: DiceRoller,
		advantage: D20Test.Advantage = D20Test.Advantage.NONE) -> D20Test:
	return D20Test.roll(roller, saving_throw_bonus(ability), dc, advantage)


func roll_ability_check(ability: StringName, dc: int, roller: DiceRoller,
		advantage: D20Test.Advantage = D20Test.Advantage.NONE) -> D20Test:
	return D20Test.roll(roller, modifiers[ability], dc, advantage)
