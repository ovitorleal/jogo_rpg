class_name CharacterChoices
extends RefCounted
## Escolhas de criação e de subida de nível (SRD 5.2.1): talento do antecedente e suas opções,
## talentos nos níveis de Aumento no Valor de Atributo e Dádiva Épica, Estilo de Luta, Maestria
## em Armas, perícias, Especialização, subclasse e opções de características ("grants" nos dados).
##
## Cada escolha é uma "especificação": {key, label, count, options [{id, name, description}],
## allow_duplicates, max}. O que foi escolhido fica em CharacterData.choices[key] (lista de ids).
## Instâncias de talento têm uma chave própria ("bg" = talento do antecedente, "feat.L4", ...) e as
## sub-escolhas usam essa chave como prefixo ("feat.L4.abilities", "bg.cantrips"...).
## Aumentos de atributo: cada valor em "<chave>.abilities" soma +1 (CharacterData.ability_score).

const MAGIC_INITIATE_LISTS := ["class.cleric", "class.druid", "class.wizard"]
const CASTING_ABILITIES := ["int", "wis", "cha"]
const DEFAULT_FEAT := "feat.ability_score_improvement"


# --- Instâncias de talento --------------------------------------------------------

## Talentos do personagem: [{key, feat_id}] (antecedente, níveis e Estilo de Luta).
static func feats(c: CharacterData, registry: ContentRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var background := registry.get_entry("background", c.background_id)
	if not str(background.get("feat_id", "")).is_empty():
		result.append({"key": "bg", "feat_id": background["feat_id"]})
	for feature in granted_features(c, registry):
		var key := feature_key(feature)
		if feature["grants"] in ["feat", "epic_boon", "fighting_style"] and not c.choice(key).is_empty():
			result.append({"key": key, "feat_id": c.choice(key)[0]})
	return result


static func has_feat(c: CharacterData, registry: ContentRegistry, feat_id: String) -> bool:
	for instance in feats(c, registry):
		if instance["feat_id"] == feat_id:
			return true
	return false


## Características (da classe e da subclasse, até o nível atual) que concedem alguma escolha.
static func granted_features(c: CharacterData, registry: ContentRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for feature in active_features(c, registry):
		if not str(feature.get("grants", "")).is_empty():
			result.append(feature)
	return result


## Características de classe e subclasse até o nível atual.
static func active_features(c: CharacterData, registry: ContentRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lists: Array = [registry.get_entry("class", c.class_id).get("features", [])]
	if not c.subclass_id.is_empty():
		lists.append(registry.get_entry("subclass", c.subclass_id).get("features", []))
	for list: Array in lists:
		for feature: Dictionary in list:
			if int(feature.get("level", 1)) <= c.level:
				result.append(feature)
	return result


## Chave da escolha de uma característica ("feat.L4", "fighting_style.feature.x", ...).
static func feature_key(feature: Dictionary) -> String:
	match str(feature["grants"]):
		"feat", "epic_boon":
			return "feat.L%d" % int(feature["level"])
		"subclass":
			return "subclass"
		"weapon_mastery":
			return "weapon_mastery"
	return "%s.%s" % [feature["grants"], feature["id"]]


# --- Especificações ---------------------------------------------------------------

## Todas as escolhas disponíveis agora, na ordem em que devem ser feitas.
static func specs(c: CharacterData, registry: ContentRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var class_entry := registry.get_entry("class", c.class_id)
	var background := registry.get_entry("background", c.background_id)
	if not str(background.get("feat_id", "")).is_empty():
		result.append_array(_feat_specs(c, registry, "bg", str(background["feat_id"]), "Talento do antecedente",
				str(background.get("feat_spell_list", ""))))
	for feature in granted_features(c, registry):
		var key := feature_key(feature)
		var count := int(feature.get("count", 1))
		var by_level: Array = feature.get("count_by_level", [])
		if not by_level.is_empty():
			count = int(by_level[clampi(c.level, 1, by_level.size()) - 1])
		match str(feature["grants"]):
			"subclass":
				result.append(_spec(key, "Subclasse", 1, _subclass_options(c, registry)))
			"feat", "epic_boon":
				result.append(_spec(key, "%s (nível %d)" % [feature["name"], feature["level"]], 1,
						_feat_options(c, registry, key, feature["grants"] == "epic_boon")))
			"fighting_style":
				result.append(_spec(key, feature["name"], 1, _fighting_style_options(c, registry, key)))
			"weapon_mastery":
				var table: Array = class_entry.get("weapon_mastery_counts", [])
				var amount := int(table[clampi(c.level, 1, table.size()) - 1]) if not table.is_empty() else count
				result.append(_spec(key, "Maestria em Armas", amount, _mastery_options(c, registry)))
			"expertise":
				result.append(_spec(key, "%s (nível %d)" % [feature["name"], feature["level"]], count,
						_filtered(_expertise_options(c, registry, key), feature)))
			"skill":
				var pool: Array = feature.get("skill_filter", []) if not feature.get("skill_filter", []).is_empty() 						else class_entry.get("skill_options", [])
				result.append(_spec(key, feature["name"], count, _skill_options(pool, c, registry, key)))
			"wild_shape":
				result.append(_spec(key, "Formas da Forma Selvagem", count, _wild_shape_options(c, registry)))
			"magical_discoveries":
				result.append(_spec(key, feature["name"], count, _discovery_options(c, registry)))
			"invocation":
				result.append(_spec(key, feature["name"], count, _invocation_options(c, key, feature.get("options", []))))
			"mystic_arcanum":
				for spell_level: int in ARCANUM_LEVELS:
					if c.level >= int(ARCANUM_LEVELS[spell_level]):
						result.append(_spec("arcanum.%d" % spell_level, "Arcano Místico (%dº círculo)" % spell_level, 1,
								_spell_options(registry, c.class_id, spell_level)))
			"spell_mastery":
				for spell_level in [1, 2]:
					result.append(_spec("spell_mastery.%d" % spell_level, "Maestria em Magia (%dº círculo)" % spell_level, 1,
							_spell_options(registry, c.class_id, spell_level).filter(func(o: Dictionary) -> bool:
								return registry.get_entry("spell", str(o["id"]))["casting_time"] == "action")))
			"signature_spells":
				result.append(_spec("signature", "Magias Assinatura (3º círculo)", 2, _spell_options(registry, c.class_id, 3)))
			_:
				result.append(_spec(key, feature["name"], count, _level_options(c, feature.get("options", []))))
		if feature["grants"] in ["feat", "epic_boon", "fighting_style"] and not c.choice(key).is_empty():
			result.append_array(_feat_specs(c, registry, key, c.choice(key)[0], "", ""))
	return result


## Feras que o druida pode aprender: ND até 1/4 (sem voo), 1/2 no nível 4 e 1 (com voo) no nível 8.
static func _wild_shape_options(c: CharacterData, registry: ContentRegistry) -> Array:
	var max_cr := 1.0 if c.level >= 8 else (0.5 if c.level >= 4 else 0.25)
	var options: Array = []
	for id in registry.ids("monster"):
		var beast := registry.get_entry("monster", id)
		if beast.get("creature_type") != "fera" or challenge_value(str(beast["challenge_rating"])) > max_cr:
			continue
		if int(beast.get("fly_speed", 0)) > 0 and c.level < 8:
			continue
		options.append({"id": id, "name": beast["name"], "description": "ND %s · CA %d · %d pés" % [beast["challenge_rating"],
				beast["armor_class"], maxi(int(beast["speed"]), int(beast.get("fly_speed", 0)))]})
	return options


static func challenge_value(rating: String) -> float:
	if "/" in rating:
		var parts := rating.split("/")
		return float(parts[0]) / float(parts[1])
	return float(rating)


## Descobertas Mágicas (Conhecimento 6): truques ou magias com espaço das listas de Clérigo, Druida ou Mago.
static func _discovery_options(c: CharacterData, registry: ContentRegistry) -> Array:
	var max_level := Spellcasting.max_slot_level(registry.get_entry("class", c.class_id), c.level)
	var seen := {}
	var options: Array = []
	for class_id in ["class.cleric", "class.druid", "class.wizard"]:
		for id in Spellcasting.class_spells(class_id, registry, 0, max_level):
			if seen.has(id) or id in Spellcasting.class_spells(c.class_id, registry, 0, 9):
				continue
			seen[id] = true
			var spell := registry.get_entry("spell", id)
			options.append({"id": id, "name": spell["name"], "description": spell["description"]})
	return options


## Arcano Místico: círculo da magia -> nível de bruxo em que se ganha.
const ARCANUM_LEVELS := {6: 11, 7: 13, 8: 15, 9: 17}


## Invocações que exigem outra invocação (Pacto da Lâmina, do Tomo, da Corrente ou Lâmina Sedenta).
const INVOCATION_REQUIRES := {
	"invocation.devouring_blade": "invocation.thirsting_blade", "invocation.eldritch_smite": "invocation.pact_of_the_blade",
	"invocation.lifedrinker": "invocation.pact_of_the_blade", "invocation.thirsting_blade": "invocation.pact_of_the_blade",
	"invocation.gift_of_the_protectors": "invocation.pact_of_the_tome",
	"invocation.investment_of_the_chain_master": "invocation.pact_of_the_chain",
}


## Invocações disponíveis: nível mínimo ("@5") e invocação exigida já escolhida.
static func _invocation_options(c: CharacterData, key: String, options: Array) -> Array:
	var chosen: Array[String] = []
	for id in c.choice(key):
		chosen.append(id.split("@")[0])
	return _level_options(c, options).filter(func(option: Dictionary) -> bool:
		var required: String = INVOCATION_REQUIRES.get(str(option["id"]).split("@")[0], "")
		return required.is_empty() or required in chosen)


## Opção escolhida em qualquer característica do tipo "option" (Ordem Divina, tipo de terra...).
static func has_option(c: CharacterData, option_id: String) -> bool:
	for key: String in c.choices:
		if key.begins_with("option.") and option_id in c.choices[key]:
			return true
	return false


## Invocações Místicas escolhidas, sem o pré-requisito de nível ("invocation.agonizing_blast").
static func invocations(c: CharacterData) -> Array[String]:
	var result: Array[String] = []
	for id in c.choice("invocation.feature.eldritch_invocations"):
		result.append(id.split("@")[0])
	return result


## Formas de fera conhecidas da Forma Selvagem (ids de monstros).
static func wild_shape_forms(c: CharacterData) -> Array[String]:
	return c.choice("wild_shape.feature.wild_shape")


## Magias das Descobertas Mágicas (sempre preparadas).
static func magical_discoveries(c: CharacterData) -> Array[String]:
	return c.choice("magical_discoveries.feature.magical_discoveries")


## Treinamento com armas e armaduras: o da classe mais Ordem Divina (Protetor: armas marciais e armadura
## pesada) e Ordem Primal (Guardião: armas marciais e armadura média).
static func training(c: CharacterData, registry: ContentRegistry) -> Dictionary:
	var class_entry := registry.get_entry("class", c.class_id)
	var weapons: Array = class_entry.get("weapon_training", []).duplicate()
	var armor: Array = class_entry.get("armor_training", []).duplicate()
	var extra: Array = []
	if has_option(c, "divine_order.protector"):
		extra = [["martial"], ["heavy"]]
	elif has_option(c, "primal_order.warden"):
		extra = [["martial"], ["medium"]]
	if not extra.is_empty():
		for item: String in extra[0]:
			if not item in weapons:
				weapons.append(item)
		for item: String in extra[1]:
			if not item in armor:
				armor.append(item)
	return {"weapons": weapons, "armor": armor}


static func _filtered(options: Array, feature: Dictionary) -> Array:
	var allowed: Array = feature.get("skill_filter", [])
	if allowed.is_empty():
		return options
	return options.filter(func(o: Dictionary) -> bool: return o["id"] in allowed)


## Opções com pré-requisito de nível no id ("...@5" = nível 5+), como as Invocações Místicas.
static func _level_options(c: CharacterData, options: Array) -> Array:
	var result: Array = []
	for option: Dictionary in options:
		var parts := str(option["id"]).split("@")
		if parts.size() > 1 and c.level < int(parts[1]):
			continue
		result.append(option)
	return result


static func _spec(key: String, label: String, count: int, options: Array, allow_duplicates: bool = false) -> Dictionary:
	return {"key": key, "label": label, "count": count, "options": options, "allow_duplicates": allow_duplicates}


## Sub-escolhas de um talento: atributos, lista e magias do Iniciado em Magia, perícias do Habilidoso.
static func _feat_specs(c: CharacterData, registry: ContentRegistry, key: String, feat_id: String, label: String,
		fixed_list: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var feat := registry.get_entry("feat", feat_id)
	if feat.is_empty():
		return result
	var title := label if not label.is_empty() else str(feat["name"])
	if int(feat["ability_points"]) > 0:
		var options: Array = []
		for ability: Variant in feat["ability_choices"]:
			options.append({"id": ability, "name": Ability.NAMES[StringName(ability)], "description": ""})
		result.append(_spec(key + ".abilities", "%s: atributos (+1 cada)" % title, int(feat["ability_points"]), options, true))
	match feat_id:
		"feat.magic_initiate":
			var list := fixed_list
			if list.is_empty():
				var lists: Array = []
				for class_id in MAGIC_INITIATE_LISTS:
					lists.append({"id": class_id, "name": registry.get_entry("class", class_id).get("name", class_id), "description": ""})
				result.append(_spec(key + ".list", "%s: lista de magias" % title, 1, lists))
				list = c.choice(key + ".list")[0] if not c.choice(key + ".list").is_empty() else MAGIC_INITIATE_LISTS[0]
			var abilities: Array = []
			for ability in CASTING_ABILITIES:
				abilities.append({"id": ability, "name": Ability.NAMES[StringName(ability)], "description": ""})
			result.append(_spec(key + ".ability", "%s: atributo de conjuração" % title, 1, abilities))
			var cantrips := _spell_options(registry, list, 0)
			result.append(_spec(key + ".cantrips", "%s: truques" % title, mini(2, cantrips.size()), cantrips))
			var spells := _spell_options(registry, list, 1)
			result.append(_spec(key + ".spell", "%s: magia de 1º círculo" % title, mini(1, spells.size()), spells))
		"feat.skilled":
			result.append(_spec(key + ".skills", "%s: perícias" % title, 3, _skill_options(Skill.all(), c, registry, key + ".skills")))
	return result


static func _spell_options(registry: ContentRegistry, class_id: String, level: int) -> Array:
	var options: Array = []
	for id in Spellcasting.class_spells(class_id, registry, level, level):
		var spell := registry.get_entry("spell", id)
		options.append({"id": id, "name": spell["name"], "description": spell["description"]})
	return options


static func _subclass_options(c: CharacterData, registry: ContentRegistry) -> Array:
	var options: Array = []
	for id in registry.ids("subclass"):
		var entry := registry.get_entry("subclass", id)
		if entry["class_id"] == c.class_id:
			options.append({"id": id, "name": entry["name"], "description": entry["description"]})
	return options


## Talentos que o personagem pode escolher num nível de talento (pré-requisitos e repetição).
static func _feat_options(c: CharacterData, registry: ContentRegistry, key: String, epic: bool) -> Array:
	var taken := {}
	for instance in feats(c, registry):
		if instance["key"] != key:
			taken[instance["feat_id"]] = true
	var fighting := has_fighting_style_feature(c, registry)
	var options: Array = []
	var ids := registry.ids("feat")
	# Aumento no Valor de Atributo primeiro (padrão); Dádivas Épicas primeiro no nível 19.
	ids.sort_custom(func(a: String, b: String) -> bool:
		return _feat_order(registry.get_entry("feat", a), epic) < _feat_order(registry.get_entry("feat", b), epic))
	for id in ids:
		var feat := registry.get_entry("feat", id)
		if taken.has(id) and not feat["repeatable"]:
			continue
		if feat["category"] == "fighting_style" and not fighting:
			continue
		if not qualifies(c, registry, feat):
			continue
		options.append({"id": id, "name": feat["name"], "description": feat["description"]})
	return options


static func _feat_order(feat: Dictionary, epic: bool) -> String:
	var order := {"general": 1, "origin": 2, "fighting_style": 3, "epic_boon": 0 if epic else 4}
	var first := 0 if feat["id"] == DEFAULT_FEAT and not epic else 1
	return "%d%d%s" % [first, order[feat["category"]], feat["name"]]


static func qualifies(c: CharacterData, registry: ContentRegistry, feat: Dictionary) -> bool:
	if c.level < int(feat["prerequisite_level"]):
		return false
	if feat["prerequisite_ability"] == "str_or_dex_13" and maxi(c.ability_score(Ability.STRENGTH), c.ability_score(Ability.DEXTERITY)) < 13:
		return false
	if feat["requires_feature"] == "spellcasting" and not Spellcasting.is_caster(registry.get_entry("class", c.class_id)):
		return false
	return true


static func has_fighting_style_feature(c: CharacterData, registry: ContentRegistry) -> bool:
	for feature in granted_features(c, registry):
		if feature["grants"] == "fighting_style":
			return true
	return false


static func _fighting_style_options(c: CharacterData, registry: ContentRegistry, key: String) -> Array:
	var taken := {}
	for instance in feats(c, registry):
		if instance["key"] != key:
			taken[instance["feat_id"]] = true
	var options: Array = []
	for id in registry.ids("feat"):
		var feat := registry.get_entry("feat", id)
		if feat["category"] == "fighting_style" and not taken.has(id):
			options.append({"id": id, "name": feat["name"], "description": feat["description"]})
	return options


## Armas que a classe pode escolher para Maestria em Armas.
static func _mastery_options(c: CharacterData, registry: ContentRegistry) -> Array:
	var class_entry := registry.get_entry("class", c.class_id)
	var rule := str(class_entry.get("weapon_mastery_rule", ""))
	var options: Array = []
	for id in registry.ids("item"):
		var item := registry.get_entry("item", id)
		if item.get("item_type") != "weapon" or str(item.get("mastery", "")).is_empty():
			continue
		var properties: Array = item.get("properties", [])
		var proficient := Attack.is_proficient_with(training(c, registry)["weapons"], item)
		var allowed := proficient
		match rule:
			"melee":
				allowed = proficient and item["attack_type"] == "melee"
			"finesse_or_light":
				allowed = proficient and ("finesse" in properties or "light" in properties)
		if allowed:
			options.append({"id": id, "name": "%s (%s)" % [item["name"], Attack.MASTERY_NAMES.get(item["mastery"], item["mastery"])],
					"description": Attack.MASTERY_DESCRIPTIONS.get(item["mastery"], "")})
	# Armas do kit inicial primeiro (padrão mais útil).
	var kit: Array = class_entry.get("starting_weapons", [])
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (0 if a["id"] in kit else 1) < (0 if b["id"] in kit else 1) or \
				((0 if a["id"] in kit else 1) == (0 if b["id"] in kit else 1) and str(a["name"]) < str(b["name"])))
	return options


static func _skill_options(pool: Array, c: CharacterData, registry: ContentRegistry, own_key: String) -> Array:
	var known := skills_without(c, registry, own_key)
	var options: Array = []
	for skill: Variant in pool:
		var name := StringName(skill)
		if not name in known:
			options.append({"id": String(name), "name": Skill.NAMES[name], "description": ""})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return options


static func _expertise_options(c: CharacterData, registry: ContentRegistry, own_key: String) -> Array:
	var current := expertise(c)
	for value in c.choice(own_key):
		current.erase(StringName(value))
	var options: Array = []
	for skill in proficient_skills(c, registry):
		if not skill in current:
			options.append({"id": String(skill), "name": Skill.NAMES[skill], "description": ""})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return options


# --- Resultados das escolhas ---------------------------------------------------------

## Perícias vindas de escolhas (Habilidoso, Conhecimento Primal...).
static func chosen_skills(c: CharacterData) -> Array[StringName]:
	var result: Array[StringName] = []
	for key: String in c.choices:
		if key.ends_with(".skills") or key.begins_with("skill."):
			for value: Variant in c.choices[key]:
				if not StringName(value) in result:
					result.append(StringName(value))
	return result


## Todas as perícias proficientes (classe, espécie, antecedente e escolhas).
static func proficient_skills(c: CharacterData, registry: ContentRegistry) -> Array[StringName]:
	return skills_without(c, registry, "")


static func skills_without(c: CharacterData, registry: ContentRegistry, ignored_key: String) -> Array[StringName]:
	var result: Array[StringName] = []
	result.append_array(c.class_skills)
	for skill in c.species_skills:
		if not skill in result:
			result.append(skill)
	for skill: Variant in registry.get_entry("background", c.background_id).get("skill_proficiencies", []):
		if not StringName(skill) in result:
			result.append(StringName(skill))
	for key: String in c.choices:
		if key == ignored_key or not (key.ends_with(".skills") or key.begins_with("skill.")):
			continue
		for value: Variant in c.choices[key]:
			if not StringName(value) in result:
				result.append(StringName(value))
	return result


## Especialização: escolhas de criação (Ladino nível 1) + escolhas de nível.
static func expertise(c: CharacterData) -> Array[StringName]:
	var result: Array[StringName] = []
	result.append_array(c.expertise)
	for key: String in c.choices:
		if key.begins_with("expertise."):
			for value: Variant in c.choices[key]:
				if not StringName(value) in result:
					result.append(StringName(value))
	return result


static func weapon_masteries(c: CharacterData) -> Array[String]:
	return c.choice("weapon_mastery")


## Iniciado em Magia: [{key, list, ability, cantrips, spell}] de cada instância do talento.
static func magic_initiates(c: CharacterData, registry: ContentRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var background := registry.get_entry("background", c.background_id)
	for instance in feats(c, registry):
		if instance["feat_id"] != "feat.magic_initiate":
			continue
		var key: String = instance["key"]
		var list := str(background.get("feat_spell_list", "")) if key == "bg" else ""
		if list.is_empty():
			list = c.choice(key + ".list")[0] if not c.choice(key + ".list").is_empty() else MAGIC_INITIATE_LISTS[0]
		result.append({"key": key, "list": list,
				"ability": c.choice(key + ".ability")[0] if not c.choice(key + ".ability").is_empty() else "wis",
				"cantrips": c.choice(key + ".cantrips"), "spell": c.choice(key + ".spell")})
	return result


## Limite de atributo: 20, ou 30 com Dádiva Épica.
static func ability_cap(c: CharacterData, registry: ContentRegistry) -> int:
	for instance in feats(c, registry):
		if registry.get_entry("feat", instance["feat_id"]).get("category") == "epic_boon":
			return 30
	return 20


# --- Padrões e validação ---------------------------------------------------------------

## Completa as escolhas que faltam (primeiras opções; atributos no principal da classe) e remove
## escolhas que deixaram de existir. Repete até estabilizar (talento escolhido gera sub-escolhas).
## Retorna as chaves que foram preenchidas automaticamente.
static func fill_defaults(c: CharacterData, registry: ContentRegistry) -> Array[String]:
	var filled: Array[String] = []
	for round in 6:
		var changed := false
		if not str(registry.get_entry("class", c.class_id).get("id", "")).is_empty():
			for feature in granted_features(c, registry):
				if feature["grants"] == "subclass" and c.subclass_id.is_empty():
					var options := _subclass_options(c, registry)
					if not options.is_empty():
						c.subclass_id = options[0]["id"]
						filled.append("subclass")
						changed = true
		var current := specs(c, registry)
		var keys := {}
		for spec in current:
			keys[spec["key"]] = true
			if spec["key"] == "subclass":
				continue
			var chosen := c.choice(spec["key"])
			var valid: Array[String] = []
			var option_ids: Array = spec["options"].map(func(o: Dictionary) -> String: return str(o["id"]))
			for value in chosen:
				if value in option_ids and (spec["allow_duplicates"] or not value in valid) and valid.size() < int(spec["count"]):
					valid.append(value)
			if valid.size() < mini(int(spec["count"]), option_ids.size() if not spec["allow_duplicates"] else int(spec["count"])):
				var defaults := _defaults_for(c, registry, spec, valid)
				for value in defaults:
					valid.append(value)
				filled.append(spec["key"])
			if valid != chosen:
				c.choices[spec["key"]] = valid
				changed = true
		for key: String in c.choices.keys():
			if not keys.has(key):
				c.choices.erase(key)
				changed = true
		if not changed:
			break
	return filled


static func _defaults_for(c: CharacterData, registry: ContentRegistry, spec: Dictionary, current: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var needed := int(spec["count"]) - current.size()
	if spec["allow_duplicates"]:
		# Pontos de atributo: no atributo principal da classe enquanto couber; senão no maior possível.
		var cap := ability_cap(c, registry)
		var order: Array = registry.get_entry("class", c.class_id).get("primary_abilities", []).duplicate()
		for option: Dictionary in spec["options"]:
			if not option["id"] in order:
				order.append(option["id"])
		var option_ids: Array = spec["options"].map(func(o: Dictionary) -> String: return str(o["id"]))
		var extra := {}
		for i in needed:
			for ability: Variant in order:
				if not str(ability) in option_ids:
					continue
				var score := c.ability_score(StringName(ability)) + int(extra.get(ability, 0))
				if score < cap:
					result.append(str(ability))
					extra[ability] = int(extra.get(ability, 0)) + 1
					break
		return result
	for option: Dictionary in spec["options"]:
		if result.size() >= needed:
			break
		if not str(option["id"]) in current:
			result.append(str(option["id"]))
	return result


## Erros nas escolhas atuais.
static func validate(c: CharacterData, registry: ContentRegistry) -> Array[String]:
	var errors: Array[String] = []
	for spec in specs(c, registry):
		if spec["key"] == "subclass":
			var ids: Array = spec["options"].map(func(o: Dictionary) -> String: return str(o["id"]))
			# Subclasse ausente é preenchida por fill_defaults; só uma subclasse de outra classe é erro.
			if not c.subclass_id.is_empty() and not c.subclass_id in ids:
				errors.append("Subclasse inválida para a classe")
			continue
		var chosen := c.choice(spec["key"])
		var option_ids: Array = spec["options"].map(func(o: Dictionary) -> String: return str(o["id"]))
		for value in chosen:
			if not value in option_ids:
				errors.append("%s: opção inválida '%s'" % [spec["label"], value])
		if chosen.size() > int(spec["count"]):
			errors.append("%s: escolha até %d" % [spec["label"], spec["count"]])
		if not spec["allow_duplicates"]:
			var seen := {}
			for value in chosen:
				if seen.has(value):
					errors.append("%s: opção repetida '%s'" % [spec["label"], value])
				seen[value] = true
	if not c.subclass_id.is_empty():
		var subclass := registry.get_entry("subclass", c.subclass_id)
		if subclass.is_empty() or subclass["class_id"] != c.class_id:
			errors.append("Subclasse inválida para a classe")
	var cap := ability_cap(c, registry)
	for ability: StringName in Ability.ALL:
		var score := c.ability_score(ability)
		var base := int(c.base_scores.get(ability, 0)) + int(c.background_increases.get(ability, 0))
		if score > maxi(cap, base):
			errors.append("%s passaria de %d" % [Ability.NAMES[ability], cap])
	return errors

