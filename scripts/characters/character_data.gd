class_name CharacterData
extends RefCounted
## Estado persistente de um personagem: só escolhas e valores que não podem ser
## recalculados. Valores derivados (CA, PV máximos, bônus) ficam em CharacterSheet.
## Serializa para Dictionary compatível com JSON, com versão de esquema.

const SCHEMA_VERSION := 1
const MAX_NAME_LENGTH := 32

var id: String = ""
var name: String = ""
var species_id: String = ""
var class_id: String = ""
var background_id: String = ""
var level: int = 1
var experience: int = 0
## "standard_array" ou "point_buy"
var ability_method: String = "standard_array"
var base_scores: Dictionary = {}           # StringName -> int
var background_increases: Dictionary = {}  # StringName -> int
var class_skills: Array[StringName] = []
var species_skills: Array[StringName] = []
var expertise: Array[StringName] = []
var armor_id: String = ""
var shield_id: String = ""
var weapon_ids: Array[String] = []
var current_hp: int = 0


func ability_score(ability: StringName) -> int:
	return int(base_scores.get(ability, 0)) + int(background_increases.get(ability, 0))


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"name": name,
		"species_id": species_id,
		"class_id": class_id,
		"background_id": background_id,
		"level": level,
		"experience": experience,
		"ability_method": ability_method,
		"base_scores": _scores_to_json(base_scores),
		"background_increases": _scores_to_json(background_increases),
		"class_skills": _names_to_json(class_skills),
		"species_skills": _names_to_json(species_skills),
		"expertise": _names_to_json(expertise),
		"armor_id": armor_id,
		"shield_id": shield_id,
		"weapon_ids": weapon_ids.duplicate(),
		"current_hp": current_hp,
	}


## Reconstrói a partir de um Dictionary (ex.: JSON carregado). Valida estrutura e tipos;
## a validade das escolhas em relação ao conteúdo é checada por CharacterFactory.validate.
## Retorna [CharacterData ou null, erros].
static func from_dict(data: Dictionary) -> Array:
	var errors: Array[String] = []
	var version := int(data.get("schema_version", -1))
	if version != SCHEMA_VERSION:
		return [null, ["Versão de esquema do personagem não suportada: %s" % str(data.get("schema_version"))]]
	var c := CharacterData.new()
	c.id = _read_string(data, "id", errors)
	c.name = _read_string(data, "name", errors)
	c.species_id = _read_string(data, "species_id", errors)
	c.class_id = _read_string(data, "class_id", errors)
	c.background_id = _read_string(data, "background_id", errors)
	c.level = _read_int(data, "level", errors)
	c.experience = _read_int(data, "experience", errors)
	c.ability_method = _read_string(data, "ability_method", errors)
	c.base_scores = _read_scores(data, "base_scores", errors)
	c.background_increases = _read_scores(data, "background_increases", errors)
	c.class_skills = _read_names(data, "class_skills", errors)
	c.species_skills = _read_names(data, "species_skills", errors)
	c.expertise = _read_names(data, "expertise", errors)
	c.armor_id = _read_string(data, "armor_id", errors)
	c.shield_id = _read_string(data, "shield_id", errors)
	c.weapon_ids.assign(_read_array(data, "weapon_ids", errors).map(func(v: Variant) -> String: return str(v)))
	c.current_hp = _read_int(data, "current_hp", errors)
	var known := c.to_dict().keys()
	for key: Variant in data:
		if not key in known:
			errors.append("Campo desconhecido no personagem: '%s'" % str(key))
	if not errors.is_empty():
		return [null, errors]
	return [c, errors]


static func _scores_to_json(scores: Dictionary) -> Dictionary:
	var out := {}
	for ability: StringName in Ability.ALL:
		if scores.has(ability):
			out[String(ability)] = int(scores[ability])
	return out


static func _names_to_json(names: Array[StringName]) -> Array:
	return names.map(func(n: StringName) -> String: return String(n))


static func _read_string(data: Dictionary, key: String, errors: Array[String]) -> String:
	if not data.get(key) is String:
		errors.append("Campo '%s' ausente ou não é texto" % key)
		return ""
	return data[key]


static func _read_int(data: Dictionary, key: String, errors: Array[String]) -> int:
	var value: Variant = data.get(key)
	if value is int or (value is float and is_equal_approx(value, roundf(value))):
		return int(value)
	errors.append("Campo '%s' ausente ou não é número inteiro" % key)
	return 0


static func _read_array(data: Dictionary, key: String, errors: Array[String]) -> Array:
	if not data.get(key) is Array:
		errors.append("Campo '%s' ausente ou não é lista" % key)
		return []
	return data[key]


static func _read_names(data: Dictionary, key: String, errors: Array[String]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in _read_array(data, key, errors):
		if value is String:
			result.append(StringName(value))
		else:
			errors.append("Campo '%s' contém valor que não é texto" % key)
	return result


static func _read_scores(data: Dictionary, key: String, errors: Array[String]) -> Dictionary:
	var result := {}
	var raw: Variant = data.get(key)
	if not raw is Dictionary:
		errors.append("Campo '%s' ausente ou não é objeto" % key)
		return result
	for ability_key: Variant in raw:
		var ability := StringName(str(ability_key))
		var value: Variant = raw[ability_key]
		if not Ability.is_valid(ability):
			errors.append("'%s': atributo desconhecido '%s'" % [key, str(ability_key)])
		elif not (value is int or (value is float and is_equal_approx(value, roundf(value)))):
			errors.append("'%s.%s' não é número inteiro" % [key, str(ability_key)])
		else:
			result[ability] = int(value)
	return result
