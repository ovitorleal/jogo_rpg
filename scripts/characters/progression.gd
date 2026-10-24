class_name Progression
extends RefCounted
## Experiência e níveis (tabela de avanço de personagem do SRD 5.2.1).
## Ao subir de nível: PV máximos sobem pela média fixa do dado de vida + Con (via
## RulesEngine.max_hit_points), os PV atuais sobem na mesma quantidade, o total de Dados de
## Vida acompanha o nível e o bônus de proficiência é recalculado pela ficha.

## XP mínimo para cada nível (índice = nível).
const XP_FOR_LEVEL: Array[int] = [0, 0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
		85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000]


static func level_for_xp(xp: int) -> int:
	var level := 1
	for candidate in range(2, XP_FOR_LEVEL.size()):
		if xp >= XP_FOR_LEVEL[candidate]:
			level = candidate
	return level


## XP que falta para o próximo nível (0 no nível máximo).
static func xp_to_next(c: CharacterData) -> int:
	if c.level >= RulesEngine.MAX_LEVEL:
		return 0
	return maxi(0, XP_FOR_LEVEL[c.level + 1] - c.experience)


## Concede XP e sobe os níveis alcançados. Retorna a lista de subidas:
## [{"level": int, "hp_gained": int, "features": Array[Dictionary]}].
static func award_xp(c: CharacterData, amount: int, registry: ContentRegistry) -> Array[Dictionary]:
	c.experience += maxi(0, amount)
	var ups: Array[Dictionary] = []
	while c.level < RulesEngine.MAX_LEVEL and c.experience >= XP_FOR_LEVEL[c.level + 1]:
		ups.append(level_up(c, registry))
	return ups


static func level_up(c: CharacterData, registry: ContentRegistry) -> Dictionary:
	var before := CharacterSheet.build(c, registry).max_hp
	c.level += 1
	var after := CharacterSheet.build(c, registry)
	var gained := after.max_hp - before
	if c.current_hp > 0:
		c.current_hp = mini(after.max_hp, c.current_hp + gained)
	var features: Array[Dictionary] = []
	for feature: Dictionary in after.class_entry.get("features", []) + after.species.get("traits", []):
		if int(feature.get("level", 1)) == c.level:
			features.append(feature)
	# Adaptação: truques e magias novas da subida de nível são escolhidas automaticamente.
	var spells := Spellcasting.fill_defaults(c, registry)
	# Escolhas novas do nível (talento, subclasse, estilo...) recebem o padrão; o jogador pode trocá-las.
	var new_choices := CharacterChoices.fill_defaults(c, registry)
	var spell_names: Array = spells.map(func(id: String) -> String: return registry.get_entry("spell", id).get("name", id))
	return {"level": c.level, "hp_gained": gained, "features": features, "spells": spells, "spell_names": spell_names,
			"choices": new_choices}


## Texto curto para avisos de subida de nível.
static func describe(c: CharacterData, up: Dictionary) -> String:
	var text := "%s subiu para o nível %d! +%d PV máximos." % [c.name, up["level"], up["hp_gained"]]
	var names: Array = up["features"].map(func(f: Dictionary) -> String: return f["name"])
	if not names.is_empty():
		text += " Novas características: %s." % ", ".join(names)
	if not (up.get("choices", []) as Array).is_empty():
		text += " Há escolhas novas de nível: veja com a tecla L."
	var spell_names: Array = up.get("spell_names", [])
	if not spell_names.is_empty():
		text += " Novas magias: %s." % ", ".join(spell_names)
	return text
