class_name Combatant
extends RefCounted
## Participante de um combate. Montado a partir de um personagem (CharacterData) ou de um
## monstro (registro de conteúdo). Só dados; quem altera o estado é o CombatManager.

enum Team { PARTY, ENEMY }

const HERO_SPRITE := "res://assets/characters/hero_sheet.png"

var id: String = ""
var name: String = ""
var team: Team = Team.ENEMY
var max_hp: int = 1
var hp: int = 1
var armor_class: int = 10
var initiative_bonus: int = 0
var dexterity_score: int = 10
var speed_feet: int = 30
var position := Vector2i.ZERO
var attacks: Array[Dictionary] = []
## Magias que o personagem pode conjurar (truques + preparadas): {id, name, level, entry}.
var spells: Array[Dictionary] = []
## CD, bônus de ataque e modificador de conjuração (personagens conjuradores).
var spell_dc: int = 0
var spell_attack: int = 0
var spell_modifier: int = 0
var character_level: int = 1
## Bônus de teste de resistência por atributo (StringName -> int).
var save_bonuses: Dictionary = {}
## Efeitos ativos: {kind, source, spell, value, damage_type, on, actor, count}.
## on = "turn_start" / "turn_end" (expira no início/fim do turno de actor, após count ocorrências),
## "concentration" (dura enquanto source mantiver a concentração) ou "use" (some ao ser usado).
var effects: Array[Dictionary] = []
## Magia em concentração: {} ou {"spell_id", "name"}.
var concentration: Dictionary = {}
## Reação disponível (uma por rodada; volta no início do próprio turno).
var reaction_available: bool = true
var temp_hp: int = 0
var proficiency_bonus: int = 2
## Modificadores de atributo (StringName -> int).
var modifiers: Dictionary = {}
## Talentos, armas com maestria e características ativas (ids), para as regras de combate.
var feat_ids: Array[String] = []
var masteries: Array[String] = []
var feature_ids: Array[String] = []
## Tamanho (para empurrar/agarrar): tiny, small, medium, large, huge.
var size: String = "medium"
## Valores de atributo (StringName -> int) e condições a que é imune.
var scores: Dictionary = {}
var condition_immunities: Array = []
## Estado de características (Fúria prolongada, CD da Fúria Implacável...) e preferências do jogador
## (Golpe Atordoante ligado, efeitos do Golpe Astuto...). Ver CombatFeatures.
var state: Dictionary = {}
var options: Dictionary = {}

const SIZES := ["tiny", "small", "medium", "large", "huge", "gargantuan"]


static func size_rank(size_name: String) -> int:
	return maxi(0, SIZES.find(size_name))
var resistances: Array = []
var trait_ids: Array[String] = []
var sprite_path: String = ""
## Folha gerada pela aparência (personagens); tem prioridade sobre sprite_path.
var sprite_texture: Texture2D = null
var sprite_key: String = ""
var xp: int = 0
var initiative: int = 0
## Personagem de origem (null para monstros); recebe PV e XP ao fim do combate.
var character: CharacterData = null


func is_up() -> bool:
	return hp > 0


func is_hostile_to(other: Combatant) -> bool:
	return team != other.team


func has_trait(trait_id: String) -> bool:
	return trait_id in trait_ids


func get_spell(spell_id: String) -> Dictionary:
	for spell in spells:
		if spell["id"] == spell_id:
			return spell
	return {}


func has_feat(feat_id: String) -> bool:
	return feat_id in feat_ids


func has_feature(feature_id: String) -> bool:
	return feature_id in feature_ids


## Condição ativa (Caído, Amedrontado...), vinda de um efeito "condition".
func has_condition(condition: String) -> bool:
	for effect in effects:
		if effect["kind"] == "condition" and effect.get("condition") == condition:
			return true
	if condition == "incapacitated":
		for other in ["stunned", "paralyzed", "unconscious", "petrified"]:
			if has_condition(other):
				return true
	return false


func is_incapacitated() -> bool:
	return has_condition("incapacitated")


func effects_of(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect in effects:
		if effect["kind"] == kind:
			result.append(effect)
	return result


## CA com bônus de efeitos (ex.: Escudo da Fé).
func effective_ac() -> int:
	var bonus := 0
	for effect in effects_of("ac_bonus"):
		bonus += int(effect["value"])
	return armor_class + bonus


## Resistências: as próprias + as de características e efeitos (Fúria, Defesa Superior...).
func all_resistances() -> Array:
	var result := resistances.duplicate()
	for damage_type: Variant in CombatFeatures.resistances(self):
		if not damage_type in result:
			result.append(damage_type)
	return result


func save_bonus(ability: StringName) -> int:
	return int(save_bonuses.get(ability, 0))


func get_attack(attack_id: String) -> Dictionary:
	for attack in attacks:
		if attack["id"] == attack_id:
			return attack
	return {}


static func from_character(c: CharacterData, registry: ContentRegistry) -> Combatant:
	var sheet := CharacterSheet.build(c, registry)
	var unit := Combatant.new()
	unit.id = c.id
	unit.name = c.name
	unit.team = Team.PARTY
	unit.max_hp = sheet.max_hp
	unit.hp = clampi(c.current_hp, 0, sheet.max_hp)
	unit.armor_class = sheet.armor_class
	unit.initiative_bonus = sheet.initiative
	unit.dexterity_score = sheet.scores[Ability.DEXTERITY]
	unit.speed_feet = sheet.speed
	unit.resistances = sheet.species.get("damage_resistances", []).duplicate()
	unit.sprite_path = HERO_SPRITE
	if registry.has("appearance", c.species_id.replace("species.", "appearance.")):
		unit.sprite_texture = Appearance.sheet_texture(c, registry)
		unit.sprite_key = Appearance.key_for(c, registry)
	unit.character = c
	var seen := {}
	for weapon in sheet.weapons:
		if weapon.is_empty() or seen.has(weapon["id"]):
			continue
		seen[weapon["id"]] = true
		unit.attacks.append_array(Attack.weapon_attacks(sheet, weapon))
	unit.attacks.append(Attack.unarmed_strike(sheet))
	unit.attacks.append_array(Attack.unarmed_options(sheet))
	unit.character_level = c.level
	unit.proficiency_bonus = sheet.proficiency_bonus
	unit.modifiers = sheet.modifiers.duplicate()
	unit.scores = sheet.scores.duplicate()
	unit.feat_ids = sheet.feat_ids.duplicate()
	unit.masteries = CharacterChoices.weapon_masteries(c)
	unit.size = str(sheet.species.get("size", "medium"))
	for feature in CharacterChoices.active_features(c, registry):
		unit.feature_ids.append(str(feature["id"]))
	unit.state["unarmored"] = sheet.armor.is_empty() and sheet.shield.is_empty()
	# Artes Marciais (Monge): sem armadura e escudo, armas de monge e desarmado usam o maior entre
	# Força e Destreza e o dado de Artes Marciais quando ele for maior que o dano da arma.
	if unit.has_feature("feature.martial_arts") and bool(unit.state["unarmored"]):
		var die := DiceExpression.parse(ClassFeatures.raw_value(c, registry, "martial_arts_die"))
		var best: StringName = Ability.DEXTERITY if int(sheet.modifiers[Ability.DEXTERITY]) > int(sheet.modifiers[Ability.STRENGTH]) \
				else Ability.STRENGTH
		var modifier: int = sheet.modifiers[best]
		for attack in unit.attacks:
			if not CombatFeatures.is_monk_weapon(attack, registry) and not str(attack.get("unarmed", "")) in ["grapple", "shove"]:
				continue
			if str(attack.get("unarmed", "")) in ["grapple", "shove"]:
				attack["save_dc"] = 8 + modifier + sheet.proficiency_bonus
				continue
			var weapon := DiceExpression.parse(str(attack["damage"]))
			var dice := die if die.count * (die.sides + 1) > maxi(1, weapon.count) * (weapon.sides + 1) else weapon
			attack["ability"] = best
			attack["ability_modifier"] = modifier
			attack["attack_bonus"] = modifier + sheet.proficiency_bonus
			attack["damage"] = "%dd%d%s" % [dice.count, dice.sides, "%+d" % modifier if modifier != 0 else ""] \
					if dice.sides > 0 else str(maxi(0, 1 + modifier))
	# Estilo de Luta Arquearia: +2 nos ataques com armas à distância.
	if unit.has_feat("feat.archery"):
		for attack in unit.attacks:
			if not str(attack.get("weapon_id", "")).is_empty() and attack["attack_type"] == "ranged" \
					and not "thrown" in attack.get("properties", []):
				attack["attack_bonus"] = int(attack["attack_bonus"]) + 2
	for ability: StringName in Ability.ALL:
		unit.save_bonuses[ability] = sheet.saving_throw_bonus(ability)
	if Spellcasting.is_caster(sheet.class_entry):
		unit.spell_dc = Spellcasting.save_dc(sheet)
		unit.spell_attack = Spellcasting.attack_bonus(sheet)
		unit.spell_modifier = Spellcasting.ability_modifier(sheet)
		for spell_id in c.cantrips + c.prepared_spells:
			var entry := registry.get_entry("spell", spell_id)
			if not entry.is_empty():
				unit.spells.append({"id": spell_id, "name": entry["name"], "level": int(entry["level"]), "entry": entry,
						"dc": unit.spell_dc, "attack": unit.spell_attack, "modifier": unit.spell_modifier, "free": ""})
	# Iniciado em Magia: atributo próprio; a magia de 1º círculo tem um uso gratuito por descanso longo.
	for initiate in CharacterChoices.magic_initiates(c, registry):
		var modifier: int = sheet.modifiers[StringName(initiate["ability"])]
		var ids: Array = initiate["cantrips"] + initiate["spell"]
		for spell_id: String in ids:
			var entry := registry.get_entry("spell", spell_id)
			if entry.is_empty() or not unit.get_spell(spell_id).is_empty():
				continue
			unit.spells.append({"id": spell_id, "name": entry["name"], "level": int(entry["level"]), "entry": entry,
					"dc": 8 + modifier + sheet.proficiency_bonus, "attack": modifier + sheet.proficiency_bonus,
					"modifier": modifier, "free": "mi.%s" % initiate["key"] if int(entry["level"]) > 0 else ""})
	return unit


## index diferencia várias cópias do mesmo monstro ("Lobo 1", "Lobo 2").
static func from_monster(entry: Dictionary, index: int, total_of_kind: int) -> Combatant:
	var unit := Combatant.new()
	unit.id = "%s#%d" % [entry["id"], index]
	unit.name = entry["name"] if total_of_kind <= 1 else "%s %d" % [entry["name"], index]
	unit.team = Team.ENEMY
	unit.max_hp = int(entry["hit_points"])
	unit.hp = unit.max_hp
	unit.armor_class = int(entry["armor_class"])
	unit.dexterity_score = int(entry["ability_scores"][1])
	unit.initiative_bonus = Ability.modifier(unit.dexterity_score)
	unit.speed_feet = int(entry["speed"])
	unit.resistances = entry.get("damage_resistances", []).duplicate()
	unit.sprite_path = str(entry.get("sprite", ""))
	unit.xp = int(entry.get("xp", 0))
	unit.size = str(entry.get("size", "medium"))
	for i in Ability.ALL.size():
		unit.modifiers[Ability.ALL[i]] = Ability.modifier(int(entry["ability_scores"][i]))
		unit.scores[Ability.ALL[i]] = int(entry["ability_scores"][i])
	# Monstros sem proficiência em resistências: modificador do atributo (como goblin e lobo no SRD).
	for i in Ability.ALL.size():
		unit.save_bonuses[Ability.ALL[i]] = Ability.modifier(int(entry["ability_scores"][i]))
	for t: Dictionary in entry.get("traits", []):
		if t.get("implemented", false):
			unit.trait_ids.append(str(t["id"]))
	for attack: Dictionary in entry.get("attacks", []):
		var copy := attack.duplicate()
		copy["reach"] = int(attack.get("reach", 5)) if attack["attack_type"] == "melee" else 0
		for key: String in ["weapon_id", "mastery"]:
			copy[key] = ""
		copy["properties"] = []
		copy["two_handed"] = false
		copy["ability_modifier"] = 0
		unit.attacks.append(copy)
	return unit
