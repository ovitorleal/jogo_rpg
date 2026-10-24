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
	for t: Dictionary in entry.get("traits", []):
		if t.get("implemented", false):
			unit.trait_ids.append(str(t["id"]))
	for attack: Dictionary in entry.get("attacks", []):
		var copy := attack.duplicate()
		copy["reach"] = int(attack.get("reach", 5)) if attack["attack_type"] == "melee" else 0
		unit.attacks.append(copy)
	return unit
