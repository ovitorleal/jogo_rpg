class_name CharacterFactory
extends RefCounted
## Criação e validação de personagens (nível 1) segundo o SRD 5.2.1 e o conteúdo carregado.
##
## Escolhas aceitas por create():
##   name, species_id, class_id, background_id: String
##   ability_method: "standard_array" | "point_buy"
##   base_scores, background_increases: { StringName -> int }
##   class_skills, species_skills, expertise: Array[StringName]
##   id (opcional)

const ABILITY_METHODS: Array[String] = ["standard_array", "point_buy"]


## Retorna [CharacterData ou null, erros]. O equipamento é o kit inicial da classe e os
## PV atuais começam no máximo.
static func create(choices: Dictionary, registry: ContentRegistry) -> Array:
	var c := CharacterData.new()
	c.id = str(choices.get("id", "character.%d" % Time.get_ticks_usec()))
	c.name = str(choices.get("name", "")).strip_edges()
	c.species_id = str(choices.get("species_id", ""))
	c.class_id = str(choices.get("class_id", ""))
	c.background_id = str(choices.get("background_id", ""))
	c.ability_method = str(choices.get("ability_method", "standard_array"))
	c.base_scores = _to_score_dict(choices.get("base_scores", {}))
	c.background_increases = _to_score_dict(choices.get("background_increases", {}))
	c.class_skills = _to_names(choices.get("class_skills", []))
	c.species_skills = _to_names(choices.get("species_skills", []))
	c.expertise = _to_names(choices.get("expertise", []))

	var class_entry := registry.get_entry("class", c.class_id)
	if not class_entry.is_empty():
		c.armor_id = class_entry.get("starting_armor", "")
		c.shield_id = "item.shield" if class_entry.get("starting_shield", false) else ""
		c.weapon_ids.assign(class_entry.get("starting_weapons", []))

	var errors := validate(c, registry, false)
	if not errors.is_empty():
		return [null, errors]
	c.current_hp = CharacterSheet.build(c, registry).max_hp
	return [c, errors]


## Verifica se o personagem é coerente com as regras e com o conteúdo.
## check_hp = false ignora os PV atuais (usado durante a criação).
static func validate(c: CharacterData, registry: ContentRegistry, check_hp: bool = true) -> Array[String]:
	var errors: Array[String] = []
	if c.name.strip_edges().is_empty():
		errors.append("Informe um nome")
	elif c.name.length() > CharacterData.MAX_NAME_LENGTH:
		errors.append("Nome com mais de %d caracteres" % CharacterData.MAX_NAME_LENGTH)
	if c.level < RulesEngine.MIN_LEVEL or c.level > RulesEngine.MAX_LEVEL:
		errors.append("Nível %d fora de %d-%d" % [c.level, RulesEngine.MIN_LEVEL, RulesEngine.MAX_LEVEL])
	if c.experience < 0:
		errors.append("Experiência negativa")
	elif c.level > Progression.level_for_xp(c.experience):
		errors.append("Nível %d exige mais experiência que %d XP" % [c.level, c.experience])

	var species := registry.get_entry("species", c.species_id)
	var class_entry := registry.get_entry("class", c.class_id)
	var background := registry.get_entry("background", c.background_id)
	if species.is_empty():
		errors.append("Espécie desconhecida: '%s'" % c.species_id)
	if class_entry.is_empty():
		errors.append("Classe desconhecida: '%s'" % c.class_id)
	if background.is_empty():
		errors.append("Antecedente desconhecido: '%s'" % c.background_id)
	if not errors.is_empty():
		return errors

	match c.ability_method:
		"standard_array":
			errors.append_array(RulesEngine.validate_standard_array(c.base_scores))
		"point_buy":
			errors.append_array(RulesEngine.validate_point_buy(c.base_scores))
		_:
			errors.append("Método de atributos desconhecido: '%s'" % c.ability_method)
	if errors.is_empty():
		errors.append_array(RulesEngine.validate_background_increase(
				c.background_increases, background["ability_options"], c.base_scores))

	var background_skills: Array[StringName] = _to_names(background["skill_proficiencies"])
	var class_options: Array[StringName] = _to_names(class_entry["skill_options"])
	errors.append_array(_validate_skill_choices(c.class_skills, int(class_entry["skill_choice_count"]),
			class_options, background_skills, "classe"))
	errors.append_array(_validate_skill_choices(c.species_skills, int(species["extra_skill_choices"]),
			species_skill_options(species), _concat([background_skills, c.class_skills]), "espécie"))

	var proficient := _concat([background_skills, c.class_skills, c.species_skills])
	var expertise_count := int(class_entry["expertise_choices"])
	if c.expertise.size() != expertise_count:
		errors.append("Escolha %d perícia(s) para Especialização (escolhidas: %d)" % [expertise_count, c.expertise.size()])
	for skill in c.expertise:
		if not skill in proficient:
			errors.append("Especialização exige proficiência em %s" % Skill.NAMES.get(skill, str(skill)))
	if _has_duplicates(c.expertise):
		errors.append("Especialização repetida")

	errors.append_array(_validate_equipment(c, registry, class_entry))

	if check_hp and errors.is_empty():
		var max_hp := CharacterSheet.build(c, registry).max_hp
		if c.current_hp < 0 or c.current_hp > max_hp:
			errors.append("PV atuais %d fora de 0-%d" % [c.current_hp, max_hp])
	if c.hit_dice_spent < 0 or c.hit_dice_spent > RulesEngine.hit_dice_total(c.level):
		errors.append("Dados de Vida gastos %d fora de 0-%d" % [c.hit_dice_spent, RulesEngine.hit_dice_total(c.level)])
	return errors


static func _validate_skill_choices(chosen: Array[StringName], count: int, options: Array[StringName],
		already_proficient: Array[StringName], source: String) -> Array[String]:
	var errors: Array[String] = []
	if chosen.size() != count:
		errors.append("Escolha %d perícia(s) da %s (escolhidas: %d)" % [count, source, chosen.size()])
	if _has_duplicates(chosen):
		errors.append("Perícia repetida nas escolhas da %s" % source)
	for skill in chosen:
		if not Skill.is_valid(skill):
			errors.append("Perícia desconhecida: '%s'" % skill)
		elif not skill in options:
			errors.append("%s não é opção da %s" % [Skill.NAMES[skill], source])
		elif skill in already_proficient:
			errors.append("%s já é proficiente por outra fonte; escolha outra" % Skill.NAMES[skill])
	return errors


static func _validate_equipment(c: CharacterData, registry: ContentRegistry, class_entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var training: Array = class_entry["armor_training"]
	if not c.armor_id.is_empty():
		var armor := registry.get_entry("item", c.armor_id)
		if armor.get("item_type") != "armor":
			errors.append("Armadura inválida: '%s'" % c.armor_id)
		elif not armor["armor_category"] in training:
			errors.append("%s exige treinamento que a classe não tem" % armor["name"])
	if not c.shield_id.is_empty():
		if registry.get_entry("item", c.shield_id).get("item_type") != "shield":
			errors.append("Escudo inválido: '%s'" % c.shield_id)
		elif not "shield" in training:
			errors.append("A classe não tem treinamento com escudo")
	for weapon_id in c.weapon_ids:
		if registry.get_entry("item", weapon_id).get("item_type") != "weapon":
			errors.append("Arma inválida: '%s'" % weapon_id)
	return errors


## Perícias que a espécie permite escolher (lista vazia nos dados = qualquer perícia).
static func species_skill_options(species: Dictionary) -> Array[StringName]:
	var options := _to_names(species.get("extra_skill_options", []))
	return Skill.all() if options.is_empty() else options


## Concatena listas mantendo o tipo Array[StringName] (o operador + perde o tipo).
static func _concat(lists: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for list: Array in lists:
		result.append_array(list)
	return result


static func _has_duplicates(values: Array) -> bool:
	var seen := {}
	for v: Variant in values:
		if seen.has(v):
			return true
		seen[v] = true
	return false


static func _to_names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for v: Variant in values:
			result.append(StringName(str(v)))
	return result


static func _to_score_dict(values: Variant) -> Dictionary:
	var result := {}
	if values is Dictionary:
		for key: Variant in values:
			result[StringName(str(key))] = int(values[key])
	return result
