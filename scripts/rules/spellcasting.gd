class_name Spellcasting
extends RefCounted
## Conjuração (SRD 5.2.1, regras de 2024).
## - CD de magia = 8 + modificador do atributo de conjuração + bônus de proficiência.
## - Bônus de ataque mágico = modificador do atributo + bônus de proficiência.
## - Espaços de magia por nível: conjuradores completos (Bardo, Clérigo, Druida, Feiticeiro, Mago),
##   meio-conjuradores (Paladino, Patrulheiro, desde o nível 1 em 2024) e Magia de Pacto (Bruxo:
##   todos os espaços no mesmo círculo, recuperados em descanso curto ou longo).
## - Truques: dano aumenta nos níveis 5, 11 e 17 (2, 3 e 4 vezes os dados).
## - No mesmo turno só se gasta um espaço de magia (regra de 2024; aplicada pelo CombatManager).
## - Magias de círculo maior que 1 ainda não existem; espaços maiores servem para conjurar
##   magias de 1º círculo em círculo superior (dados extras de "upcast_dice").

## Espaços por círculo (índice 0 = 1º círculo) para conjuradores completos, níveis 1..20.
const FULL_SLOTS: Array = [
	[2], [3], [4, 2], [4, 3], [4, 3, 2], [4, 3, 3], [4, 3, 3, 1], [4, 3, 3, 2], [4, 3, 3, 3, 1], [4, 3, 3, 3, 2],
	[4, 3, 3, 3, 2, 1], [4, 3, 3, 3, 2, 1], [4, 3, 3, 3, 2, 1, 1], [4, 3, 3, 3, 2, 1, 1], [4, 3, 3, 3, 2, 1, 1, 1],
	[4, 3, 3, 3, 2, 1, 1, 1], [4, 3, 3, 3, 2, 1, 1, 1, 1], [4, 3, 3, 3, 3, 1, 1, 1, 1], [4, 3, 3, 3, 3, 2, 1, 1, 1],
	[4, 3, 3, 3, 3, 2, 2, 1, 1],
]
## Meio-conjuradores (Paladino, Patrulheiro), níveis 1..20.
const HALF_SLOTS: Array = [
	[2], [2], [3], [3], [4, 2], [4, 2], [4, 3], [4, 3], [4, 3, 2], [4, 3, 2],
	[4, 3, 3], [4, 3, 3], [4, 3, 3, 1], [4, 3, 3, 1], [4, 3, 3, 2], [4, 3, 3, 2], [4, 3, 3, 3, 1], [4, 3, 3, 3, 1],
	[4, 3, 3, 3, 2], [4, 3, 3, 3, 2],
]
## Magia de Pacto: quantidade de espaços e círculo deles, níveis 1..20.
const PACT_COUNT: Array[int] = [1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4]
const PACT_LEVEL: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
const MAX_SPELL_LEVEL := 9


static func is_caster(class_entry: Dictionary) -> bool:
	return not str(class_entry.get("spellcasting_type", "")).is_empty()


static func ability(class_entry: Dictionary) -> StringName:
	return StringName(class_entry.get("spellcasting_ability", ""))


static func save_dc(sheet: CharacterSheet) -> int:
	return 8 + attack_bonus(sheet)


static func attack_bonus(sheet: CharacterSheet) -> int:
	if not is_caster(sheet.class_entry):
		return 0
	return int(sheet.modifiers[ability(sheet.class_entry)]) + sheet.proficiency_bonus


static func ability_modifier(sheet: CharacterSheet) -> int:
	return int(sheet.modifiers[ability(sheet.class_entry)]) if is_caster(sheet.class_entry) else 0


## Espaços por círculo no nível (índice 0 = 1º círculo). Vazio se a classe não conjura.
static func slots_for(class_entry: Dictionary, level: int) -> Array[int]:
	var result: Array[int] = []
	var i := clampi(level, 1, 20) - 1
	match str(class_entry.get("spellcasting_type", "")):
		"full":
			result.assign(FULL_SLOTS[i])
		"half":
			result.assign(HALF_SLOTS[i])
		"pact":
			result.resize(PACT_LEVEL[i])
			result.fill(0)
			result[PACT_LEVEL[i] - 1] = PACT_COUNT[i]
	return result


static func cantrips_known(class_entry: Dictionary, level: int) -> int:
	var table: Array = class_entry.get("cantrips_known", [])
	return int(table[clampi(level, 1, table.size()) - 1]) if not table.is_empty() else 0


static func prepared_count(class_entry: Dictionary, level: int) -> int:
	var table: Array = class_entry.get("prepared_spells", [])
	return int(table[clampi(level, 1, table.size()) - 1]) if not table.is_empty() else 0


## Magias da lista da classe com círculo entre min_level e max_level, por círculo e nome.
static func class_spells(class_id: String, registry: ContentRegistry, min_level: int, max_level: int) -> Array[String]:
	var result: Array[String] = []
	for id in registry.ids("spell"):
		var spell := registry.get_entry("spell", id)
		if class_id in spell["classes"] and int(spell["level"]) >= min_level and int(spell["level"]) <= max_level:
			result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool:
		var sa := registry.get_entry("spell", a)
		var sb := registry.get_entry("spell", b)
		if int(sa["level"]) != int(sb["level"]):
			return int(sa["level"]) < int(sb["level"])
		return str(sa["name"]) < str(sb["name"]))
	return result


## Maior círculo de espaço que o personagem tem.
static func max_slot_level(class_entry: Dictionary, level: int) -> int:
	return slots_for(class_entry, level).size()


## Quantos truques e magias preparadas o personagem pode ter agora, limitados ao que existe
## na lista da classe (adaptação: o jogo ainda tem poucas magias).
static func limits(c: CharacterData, registry: ContentRegistry) -> Dictionary:
	var class_entry := registry.get_entry("class", c.class_id)
	if not is_caster(class_entry):
		return {"cantrips": 0, "prepared": 0}
	var max_level := max_slot_level(class_entry, c.level)
	return {
		"cantrips": mini(cantrips_known(class_entry, c.level), class_spells(c.class_id, registry, 0, 0).size()),
		"prepared": mini(prepared_count(class_entry, c.level), class_spells(c.class_id, registry, 1, max_level).size()),
	}


## Completa truques e magias preparadas que faltam com as primeiras da lista da classe
## (novo personagem sem escolha, save antigo ou subida de nível). Retorna as magias novas.
static func fill_defaults(c: CharacterData, registry: ContentRegistry) -> Array[String]:
	var added: Array[String] = []
	var lim := limits(c, registry)
	var class_entry := registry.get_entry("class", c.class_id)
	for id in class_spells(c.class_id, registry, 0, 0):
		if c.cantrips.size() >= int(lim["cantrips"]):
			break
		if not id in c.cantrips:
			c.cantrips.append(id)
			added.append(id)
	for id in class_spells(c.class_id, registry, 1, max_slot_level(class_entry, c.level)):
		if c.prepared_spells.size() >= int(lim["prepared"]):
			break
		if not id in c.prepared_spells:
			c.prepared_spells.append(id)
			added.append(id)
	return added


## Erros nas escolhas de magia do personagem.
static func validate(c: CharacterData, registry: ContentRegistry) -> Array[String]:
	var errors: Array[String] = []
	var class_entry := registry.get_entry("class", c.class_id)
	var lim := limits(c, registry)
	if c.cantrips.size() > int(lim["cantrips"]):
		errors.append("Truques demais: %d (máximo %d)" % [c.cantrips.size(), lim["cantrips"]])
	if c.prepared_spells.size() > int(lim["prepared"]):
		errors.append("Magias preparadas demais: %d (máximo %d)" % [c.prepared_spells.size(), lim["prepared"]])
	var max_level := max_slot_level(class_entry, c.level)
	for id in c.cantrips:
		if not id in class_spells(c.class_id, registry, 0, 0):
			errors.append("Truque fora da lista da classe: %s" % id)
	for id in c.prepared_spells:
		if not id in class_spells(c.class_id, registry, 1, max_level):
			errors.append("Magia fora da lista da classe ou acima do círculo disponível: %s" % id)
	var slots := slots_for(class_entry, c.level)
	for i in c.spell_slots_spent.size():
		var available := slots[i] if i < slots.size() else 0
		if c.spell_slots_spent[i] < 0 or c.spell_slots_spent[i] > available:
			errors.append("Espaços de magia gastos inválidos no %dº círculo" % (i + 1))
	return errors


# --- Espaços -------------------------------------------------------------------

## Espaços restantes por círculo (índice 0 = 1º).
static func slots_left(c: CharacterData, registry: ContentRegistry) -> Array[int]:
	var slots := slots_for(registry.get_entry("class", c.class_id), c.level)
	var result: Array[int] = []
	for i in slots.size():
		result.append(maxi(0, slots[i] - (c.spell_slots_spent[i] if i < c.spell_slots_spent.size() else 0)))
	return result


## Menor círculo com espaço livre que comporta a magia (0 se não houver).
static func lowest_slot(c: CharacterData, registry: ContentRegistry, spell_level: int) -> int:
	var left := slots_left(c, registry)
	for i in range(maxi(0, spell_level - 1), left.size()):
		if left[i] > 0:
			return i + 1
	return 0


static func spend_slot(c: CharacterData, slot_level: int) -> void:
	while c.spell_slots_spent.size() < slot_level:
		c.spell_slots_spent.append(0)
	c.spell_slots_spent[slot_level - 1] += 1


## Descanso longo: todos os espaços voltam.
static func long_rest(c: CharacterData) -> void:
	c.spell_slots_spent.clear()


## Descanso curto: Magia de Pacto recupera todos os espaços. Retorna quantos voltaram.
static func short_rest(c: CharacterData, registry: ContentRegistry) -> int:
	if registry.get_entry("class", c.class_id).get("spellcasting_type") != "pact":
		return 0
	var restored := 0
	for spent in c.spell_slots_spent:
		restored += spent
	c.spell_slots_spent.clear()
	return restored


static func short_rest_would_restore(c: CharacterData, registry: ContentRegistry) -> bool:
	if registry.get_entry("class", c.class_id).get("spellcasting_type") != "pact":
		return false
	for spent in c.spell_slots_spent:
		if spent > 0:
			return true
	return false


static func slots_text(c: CharacterData, registry: ContentRegistry) -> String:
	var slots := slots_for(registry.get_entry("class", c.class_id), c.level)
	var left := slots_left(c, registry)
	var parts := PackedStringArray()
	for i in slots.size():
		if slots[i] > 0:
			parts.append("%dº %d/%d" % [i + 1, left[i], slots[i]])
	return " · ".join(parts)


# --- Dados -----------------------------------------------------------------------

## Multiplicador de dados dos truques pelo nível do personagem.
static func cantrip_multiplier(character_level: int) -> int:
	if character_level >= 17:
		return 4
	if character_level >= 11:
		return 3
	if character_level >= 5:
		return 2
	return 1


## Expressão de dados final da magia: truques escalam com o nível; magias em círculo
## superior somam upcast_dice por círculo acima do da magia.
static func scaled_dice(spell: Dictionary, base: String, character_level: int, slot_level: int) -> DiceExpression:
	var expression := DiceExpression.parse(base)
	if int(spell["level"]) == 0:
		expression.count *= cantrip_multiplier(character_level)
		return expression
	var extra := slot_level - int(spell["level"])
	if extra > 0 and not str(spell["upcast_dice"]).is_empty() and int(spell.get("darts", 0)) == 0:
		var upcast := DiceExpression.parse(str(spell["upcast_dice"]))
		if upcast.sides == expression.sides:
			expression.count += upcast.count * extra
	return expression
