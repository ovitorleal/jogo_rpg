class_name ClassFeatures
extends RefCounted
## Recursos de classe e subclasse (SRD 5.2.1): Fúria, Inspiração de Bardo, Canalizar Divindade,
## Forma Selvagem, Retomar o Fôlego, Pontos de Foco e de Feitiçaria, Cura pelas Mãos...
## Os valores por nível vêm dos dados ("resources" da classe/subclasse); os usos gastos ficam em
## CharacterData.resources_spent. Recursos com recarga "none" são só tabelas (dano da Fúria, dados
## do Ataque Furtivo, dado de Artes Marciais...).


## Definições ativas (classe + subclasse): [{id, name, values, recharge}].
static func definitions(c: CharacterData, registry: ContentRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for resource: Dictionary in registry.get_entry("class", c.class_id).get("resources", []):
		result.append(resource)
	if not c.subclass_id.is_empty():
		for resource: Dictionary in registry.get_entry("subclass", c.subclass_id).get("resources", []):
			result.append(resource)
	return result


static func definition(c: CharacterData, registry: ContentRegistry, resource_id: String) -> Dictionary:
	for resource in definitions(c, registry):
		if resource["id"] == resource_id:
			return resource
	return {}


## Valor da tabela no nível atual, como texto ("2", "+3", "1d8", "cha", "5x").
static func raw_value(c: CharacterData, registry: ContentRegistry, resource_id: String) -> String:
	var resource := definition(c, registry, resource_id)
	if resource.is_empty():
		return ""
	var values: Array = resource["values"]
	return str(values[clampi(c.level, 1, values.size()) - 1])


## Máximo de usos no nível atual (tokens: "cha"/"wis" = modificador com mínimo 1; "5x" = 5 x nível).
static func maximum(c: CharacterData, registry: ContentRegistry, resource_id: String) -> int:
	var value := raw_value(c, registry, resource_id)
	match value:
		"":
			return 0
		"cha", "wis", "int":
			return maxi(1, Ability.modifier(c.ability_score(StringName(value))))
		"5x":
			return 5 * c.level
	return int(value) if value.is_valid_int() else 0


static func remaining(c: CharacterData, registry: ContentRegistry, resource_id: String) -> int:
	return maxi(0, maximum(c, registry, resource_id) - c.resource_spent(resource_id))


static func spend(c: CharacterData, resource_id: String, amount: int = 1) -> void:
	c.resources_spent[resource_id] = c.resource_spent(resource_id) + amount


static func restore(c: CharacterData, resource_id: String, amount: int) -> void:
	c.resources_spent[resource_id] = maxi(0, c.resource_spent(resource_id) - amount)


## Recarga efetiva: Fonte de Inspiração (Bardo 5+) faz a Inspiração voltar no descanso curto.
static func recharge(c: CharacterData, registry: ContentRegistry, resource: Dictionary) -> String:
	if resource["id"] == "bardic_inspiration" and has_feature(c, registry, "feature.font_of_inspiration"):
		return "short"
	return str(resource["recharge"])


## Descanso curto: recursos "short" voltam todos; "short_one" recuperam um uso. Retorna os nomes.
static func short_rest(c: CharacterData, registry: ContentRegistry) -> Array[String]:
	var restored: Array[String] = []
	for resource in definitions(c, registry):
		var spent := c.resource_spent(resource["id"])
		if spent <= 0:
			continue
		match recharge(c, registry, resource):
			"short":
				c.resources_spent[resource["id"]] = 0
				restored.append(str(resource["name"]))
			"short_one":
				c.resources_spent[resource["id"]] = spent - 1
				restored.append(str(resource["name"]))
	# Recuperação Natural (Círculo da Terra 6): recupera espaços somando até metade do nível
	# (arredondado para cima), nenhum de 6º círculo ou mais; uma vez por descanso longo.
	# Recuperação Arcana (Mago 1) segue a mesma regra.
	for recovery: Array in [["feature.natural_recovery", "natural_recovery_rest", "Recuperação Natural"],
			["feature.arcane_recovery", "arcane_recovery", "Recuperação Arcana"]]:
		if has_feature(c, registry, recovery[0]) and remaining(c, registry, recovery[1]) > 0:
			@warning_ignore("integer_division")
			var recovered := recover_slots(c, (c.level + 1) / 2)
			if recovered > 0:
				spend(c, recovery[1])
				restored.append("%s (%d círculos de espaços)" % [recovery[2], recovered])
	# Restauração Feiticeira (Feiticeiro 5): Pontos de Feitiçaria até metade do nível; uma vez por descanso longo.
	if has_feature(c, registry, "feature.sorcerous_restoration") and remaining(c, registry, "sorcerous_restoration") > 0 \
			and c.resource_spent("sorcery_points") > 0:
		@warning_ignore("integer_division")
		var points := mini(c.resource_spent("sorcery_points"), c.level / 2)
		if points > 0:
			restore(c, "sorcery_points", points)
			spend(c, "sorcerous_restoration")
			restored.append("Restauração Feiticeira (%d pontos)" % points)
	# Incansável (Patrulheiro 10): o descanso curto reduz a Exaustão em 1.
	if c.exhaustion > 0 and has_feature(c, registry, "feature.tireless"):
		c.exhaustion -= 1
		restored.append("Exaustão -1")
	return restored


## Recupera espaços gastos (os maiores primeiro, nenhum de 6º+) até somar "budget" círculos.
static func recover_slots(c: CharacterData, budget: int) -> int:
	var recovered := 0
	for slot_level in range(mini(5, c.spell_slots_spent.size()), 0, -1):
		while c.spell_slots_spent[slot_level - 1] > 0 and slot_level <= budget:
			c.spell_slots_spent[slot_level - 1] -= 1
			budget -= slot_level
			recovered += slot_level
	return recovered


## Astúcia Mágica (Bruxo 2): rito de 1 minuto que recupera espaços de pacto até metade do máximo
## (todos com Mestre Místico); uma vez por descanso longo. Retorna quantos espaços voltaram.
static func magical_cunning(c: CharacterData, registry: ContentRegistry) -> int:
	if not has_feature(c, registry, "feature.magical_cunning") or remaining(c, registry, "magical_cunning") <= 0:
		return 0
	var total := 0
	for count in Spellcasting.slots_for(registry.get_entry("class", c.class_id), c.level):
		total += count
	@warning_ignore("integer_division")
	var allowed := total if has_feature(c, registry, "feature.eldritch_master") else (total + 1) / 2
	var restored := 0
	for i in c.spell_slots_spent.size():
		while c.spell_slots_spent[i] > 0 and restored < allowed:
			c.spell_slots_spent[i] -= 1
			restored += 1
	if restored > 0:
		spend(c, "magical_cunning")
	return restored


static func has_feature(c: CharacterData, registry: ContentRegistry, feature_id: String) -> bool:
	for feature in CharacterChoices.active_features(c, registry):
		if feature["id"] == feature_id:
			return true
	return false


## Opção escolhida numa característica do tipo "option" (ex.: Ordem Divina), ou "".
static func option(c: CharacterData, feature_id: String) -> String:
	var chosen := c.choice("option.%s" % feature_id)
	return chosen[0] if not chosen.is_empty() else ""


## Resumo para a ficha: "Fúria 2/3 · Retomar o Fôlego 1/2" (só recursos com usos).
static func summary(c: CharacterData, registry: ContentRegistry) -> String:
	var parts := PackedStringArray()
	for resource in definitions(c, registry):
		if resource["recharge"] == "none":
			continue
		var maximum_uses := maximum(c, registry, resource["id"])
		if maximum_uses > 0:
			parts.append("%s %d/%d" % [resource["name"], remaining(c, registry, resource["id"]), maximum_uses])
	return " · ".join(parts)
