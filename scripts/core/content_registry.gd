class_name ContentRegistry
extends RefCounted
## Carrega e valida os dados de conteúdo (JSON em res://data). Nada é executado a
## partir dos arquivos: apenas dados são lidos, validados e indexados por id estável.
##
## Formato de cada arquivo: { "schema_version": 1, "entries": [ { "id": "...", ... } ] }

const SCHEMA_VERSION := 1
const DATA_ROOT := "res://data"

const ABILITIES := ["str", "dex", "con", "int", "wis", "cha"]

const FEATURE_FIELDS := {
	"id": {"type": "string"},
	"name": {"type": "string"},
	"level": {"type": "int", "min": 1, "max": 20, "required": false, "default": 1},
	"description": {"type": "string"},
	"implemented": {"type": "bool"},
}

const COMMON_FIELDS := {
	"id": {"type": "string"},
	"name": {"type": "string"},
	"description": {"type": "string"},
	"source": {"type": "string", "enum": ["SRD 5.2.1", "original"]},
}

## Tipos de conteúdo: pasta, prefixo obrigatório do id e campos específicos.
const TYPES := {
	"species": {
		"dir": "species",
		"prefix": "species.",
		"fields": {
			"size": {"type": "string", "enum": ["small", "medium"]},
			"speed": {"type": "int", "min": 5, "max": 120},
			"darkvision": {"type": "int", "min": 0, "max": 300},
			"hp_bonus_per_level": {"type": "int", "min": 0, "max": 5},
			"damage_resistances": {"type": "array", "of": "string", "ref": "damage_type"},
			"extra_skill_choices": {"type": "int", "min": 0, "max": 4},
			## Perícias permitidas na escolha da espécie; vazio = qualquer perícia.
			"extra_skill_options": {"type": "array", "of": "string", "ref": "skill", "required": false, "default": []},
			"traits": {"type": "object_array", "fields": FEATURE_FIELDS},
		},
	},
	"class": {
		"dir": "classes",
		"prefix": "class.",
		"fields": {
			"hit_die": {"type": "int", "enum": [6, 8, 10, 12]},
			"primary_abilities": {"type": "array", "of": "string", "ref": "ability", "min_length": 1},
			"saving_throws": {"type": "array", "of": "string", "ref": "ability", "min_length": 2, "max_length": 2},
			"skill_choice_count": {"type": "int", "min": 0, "max": 6},
			"skill_options": {"type": "array", "of": "string", "ref": "skill", "min_length": 1},
			"expertise_choices": {"type": "int", "min": 0, "max": 4},
			"armor_training": {"type": "array", "of": "string", "enum": ["light", "medium", "heavy", "shield"]},
			"weapon_training": {"type": "array", "of": "string",
					"enum": ["simple", "martial", "martial_finesse_or_light", "martial_light"]},
			## Defesa sem Armadura: atributo somado à CA sem armadura ("" = não tem).
			"unarmored_defense_ability": {"type": "string", "enum": ["", "con", "wis"], "required": false, "default": ""},
			"unarmored_defense_allows_shield": {"type": "bool", "required": false, "default": true},
			"suggested_scores": {"type": "array", "of": "int", "min_length": 6, "max_length": 6,
					"allow_duplicates": true},
			"starting_armor": {"type": "string", "ref": "item", "ref_item_type": "armor"},
			"starting_shield": {"type": "bool"},
			"starting_weapons": {"type": "array", "of": "string", "ref": "item", "ref_item_type": "weapon",
					"allow_duplicates": true},
			"features": {"type": "object_array", "fields": FEATURE_FIELDS},
		},
	},
	"background": {
		"dir": "backgrounds",
		"prefix": "background.",
		"fields": {
			"ability_options": {"type": "array", "of": "string", "ref": "ability", "min_length": 3, "max_length": 3},
			"skill_proficiencies": {"type": "array", "of": "string", "ref": "skill", "min_length": 2, "max_length": 2},
			"tool_proficiency": {"type": "string"},
			"origin_feat": {"type": "object_array", "fields": FEATURE_FIELDS, "min_length": 1, "max_length": 1},
		},
	},
	"item": {
		"dir": "items",
		"prefix": "item.",
		"fields": {
			"item_type": {"type": "string", "enum": ["armor", "shield", "weapon"]},
			"weight_lb": {"type": "number", "min": 0},
			"cost_gp": {"type": "number", "min": 0},
		},
		"variants_by": "item_type",
		"variants": {
			"armor": {
				"armor_category": {"type": "string", "enum": ["light", "medium", "heavy"]},
				"base_ac": {"type": "int", "min": 10, "max": 20},
				"dex_cap": {"type": "int", "min": -1, "max": 10},
				"strength_requirement": {"type": "int", "min": 0, "max": 20},
				"stealth_disadvantage": {"type": "bool"},
			},
			"shield": {
				"ac_bonus": {"type": "int", "min": 1, "max": 5},
			},
			"weapon": {
				"weapon_category": {"type": "string", "enum": ["simple", "martial"]},
				"attack_type": {"type": "string", "enum": ["melee", "ranged"]},
				"damage": {"type": "string", "dice": true},
				"damage_type": {"type": "string", "ref": "damage_type"},
				"properties": {"type": "array", "of": "string", "enum": [
						"ammunition", "finesse", "heavy", "light", "loading", "reach",
						"thrown", "two_handed", "versatile"]},
				"versatile_damage": {"type": "string", "dice": true, "required": false, "default": ""},
				"range_normal": {"type": "int", "min": 0, "required": false, "default": 0},
				"range_long": {"type": "int", "min": 0, "required": false, "default": 0},
				"mastery": {"type": "string", "enum": [
						"cleave", "graze", "nick", "push", "sap", "slow", "topple", "vex"]},
			},
		},
	},
}

var errors: Array[String] = []
var _entries := {}  # tipo -> { id -> registro }
var _source_file := {}  # id -> arquivo de origem


## Carrega todos os tipos a partir de root. Retorna true se não houve erros.
func load_all(root: String = DATA_ROOT) -> bool:
	errors.clear()
	_entries.clear()
	_source_file.clear()
	var pending_refs: Array[Dictionary] = []
	for type_name: String in TYPES:
		_entries[type_name] = {}
		var dir_path := root.path_join(TYPES[type_name]["dir"])
		if not DirAccess.dir_exists_absolute(dir_path):
			errors.append("%s: pasta de conteúdo ausente" % dir_path)
			continue
		var files := Array(DirAccess.get_files_at(dir_path))
		files.sort()
		for file: String in files:
			if file.ends_with(".json"):
				_load_file(type_name, dir_path.path_join(file), pending_refs)
	_check_references(pending_refs)
	_check_consistency()
	return errors.is_empty()


## Carrega registros a partir de dicionários já em memória (para testes).
func load_from_dictionaries(data_by_type: Dictionary) -> bool:
	errors.clear()
	_entries.clear()
	_source_file.clear()
	var pending_refs: Array[Dictionary] = []
	for type_name: String in TYPES:
		_entries[type_name] = {}
		_load_document(type_name, {"schema_version": SCHEMA_VERSION, "entries": data_by_type.get(type_name, [])},
				"<memória:%s>" % type_name, pending_refs)
	_check_references(pending_refs)
	_check_consistency()
	return errors.is_empty()


func has(type_name: String, id: String) -> bool:
	return _entries.get(type_name, {}).has(id)


func get_entry(type_name: String, id: String) -> Dictionary:
	return _entries.get(type_name, {}).get(id, {})


## Ids de um tipo, em ordem alfabética.
func ids(type_name: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(_entries.get(type_name, {}).keys())
	result.sort()
	return result


func _load_file(type_name: String, path: String, pending_refs: Array[Dictionary]) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("%s: arquivo vazio ou ilegível (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s:%d: JSON inválido: %s" % [path, json.get_error_line(), json.get_error_message()])
		return
	if not json.data is Dictionary:
		errors.append("%s: esperado objeto com 'schema_version' e 'entries'" % path)
		return
	_load_document(type_name, json.data, path, pending_refs)


func _load_document(type_name: String, document: Dictionary, path: String,
		pending_refs: Array[Dictionary]) -> void:
	if int(document.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("%s: schema_version %s não suportada (esperado %d)" % [
				path, str(document.get("schema_version")), SCHEMA_VERSION])
		return
	if not document.get("entries") is Array:
		errors.append("%s: 'entries' deve ser uma lista" % path)
		return
	var type_def: Dictionary = TYPES[type_name]
	for i in document["entries"].size():
		var raw: Variant = document["entries"][i]
		var context := "%s[%d]" % [path.get_file(), i]
		if not raw is Dictionary:
			errors.append("%s: registro deve ser um objeto" % context)
			continue
		var id: String = str(raw.get("id", ""))
		if not id.is_empty():
			context = "%s (%s)" % [context, id]
		var schema: Dictionary = COMMON_FIELDS.duplicate()
		schema.merge(type_def["fields"])
		if type_def.has("variants_by"):
			var variant_key: String = str(raw.get(type_def["variants_by"], ""))
			schema.merge(type_def["variants"].get(variant_key, {}))
		var result := ContentSchema.validate(raw, schema, context, pending_refs)
		errors.append_array(result[1])
		if not id.begins_with(type_def["prefix"]):
			errors.append("%s: id deve começar com '%s'" % [context, type_def["prefix"]])
			continue
		if _entries[type_name].has(id):
			errors.append("%s: id duplicado (já definido em %s)" % [context, _source_file[id]])
			continue
		_entries[type_name][id] = result[0]
		_source_file[id] = path


func _check_references(pending_refs: Array[Dictionary]) -> void:
	for ref in pending_refs:
		var target: Dictionary = get_entry(ref["type"], ref["id"])
		if target.is_empty():
			errors.append("%s: referência a %s inexistente '%s'" % [ref["where"], ref["type"], ref["id"]])
		elif not ref["item_type"].is_empty() and target.get("item_type") != ref["item_type"]:
			errors.append("%s: '%s' deveria ser do tipo %s" % [ref["where"], ref["id"], ref["item_type"]])


## Regras entre campos que o esquema sozinho não expressa.
func _check_consistency() -> void:
	for id in ids("class"):
		var entry := get_entry("class", id)
		if entry.is_empty() or not entry.has("skill_options"):
			continue
		if int(entry["skill_choice_count"]) > entry["skill_options"].size():
			errors.append("%s: skill_choice_count maior que o número de opções" % id)
		var armor := get_entry("item", entry.get("starting_armor", ""))
		if not armor.is_empty() and not armor.get("armor_category") in entry["armor_training"]:
			errors.append("%s: armadura inicial '%s' exige treinamento que a classe não tem" % [id, armor["id"]])
		if entry.get("starting_shield", false) and not "shield" in entry["armor_training"]:
			errors.append("%s: escudo inicial sem treinamento com escudo" % id)
		var suggested: Array = entry.get("suggested_scores", [])
		if suggested.size() == 6:
			var scores := {}
			for i in 6:
				scores[Ability.ALL[i]] = suggested[i]
			for problem in RulesEngine.validate_standard_array(scores):
				errors.append("%s: suggested_scores: %s" % [id, problem])
	for id in ids("species"):
		var species := get_entry("species", id)
		var options: Array = species.get("extra_skill_options", [])
		if not options.is_empty() and int(species.get("extra_skill_choices", 0)) > options.size():
			errors.append("%s: extra_skill_choices maior que o número de opções" % id)
		if not options.is_empty() and int(species.get("extra_skill_choices", 0)) == 0:
			errors.append("%s: extra_skill_options sem extra_skill_choices" % id)
	for id in ids("item"):
		var item := get_entry("item", id)
		if item.get("item_type") != "weapon":
			continue
		var props: Array = item.get("properties", [])
		if "versatile" in props and str(item.get("versatile_damage", "")).is_empty():
			errors.append("%s: arma versátil sem versatile_damage" % id)
		if ("ammunition" in props or "thrown" in props) and int(item.get("range_normal", 0)) <= 0:
			errors.append("%s: arma de alcance sem range_normal" % id)
		if int(item.get("range_long", 0)) < int(item.get("range_normal", 0)):
			errors.append("%s: range_long menor que range_normal" % id)
