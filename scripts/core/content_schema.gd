class_name ContentSchema
extends RefCounted
## Validador declarativo de registros de conteúdo (JSON). Cada campo é descrito por um
## dicionário com:
##   type: "string" | "int" | "number" | "bool" | "array" | "object_array"
##   required: bool (padrão true)
##   enum: valores permitidos (para string/int ou elementos de array)
##   of: tipo dos elementos de "array" ("string" | "int")
##   ref: categoria cujo id deve existir ("ability" | "skill" | "damage_type" | tipo de conteúdo)
##   min / max: limites numéricos; min_length / max_length: tamanho de arrays
##   dice: true para strings que devem ser expressões de dados válidas
##   fields: sub-esquema dos objetos de "object_array"
## Também normaliza números inteiros vindos do JSON (float -> int).

const DAMAGE_TYPES: Array[String] = [
	"acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic",
	"piercing", "poison", "psychic", "radiant", "slashing", "thunder",
]


## Valida "entry" contra "schema". Retorna [entrada normalizada, erros].
## "pending_refs" recebe referências a outros conteúdos, para checar após carregar tudo.
static func validate(entry: Dictionary, schema: Dictionary, context: String,
		pending_refs: Array[Dictionary]) -> Array:
	var errors: Array[String] = []
	var normalized := {}
	for key: Variant in entry:
		if not schema.has(key):
			errors.append("%s: campo desconhecido '%s'" % [context, key])
	for field: String in schema:
		var spec: Dictionary = schema[field]
		var where := "%s.%s" % [context, field]
		if not entry.has(field):
			if spec.get("required", true):
				errors.append("%s: campo obrigatório ausente" % where)
			elif spec.has("default"):
				normalized[field] = spec["default"]
			continue
		var result := _validate_value(entry[field], spec, where, pending_refs)
		errors.append_array(result[1])
		normalized[field] = result[0]
	return [normalized, errors]


static func _validate_value(value: Variant, spec: Dictionary, where: String,
		pending_refs: Array[Dictionary]) -> Array:
	var errors: Array[String] = []
	var type_name: String = spec["type"]
	match type_name:
		"string":
			if not value is String:
				return [value, ["%s: esperado texto, obtido %s" % [where, type_string(typeof(value))]]]
			_check_enum(value, spec, where, errors)
			_check_ref(value, spec, where, errors, pending_refs)
			var optional_empty: bool = value.is_empty() and not spec.get("required", true)
			if spec.get("dice", false) and not optional_empty and not DiceExpression.parse(value).is_valid:
				errors.append("%s: %s" % [where, DiceExpression.parse(value).error])
		"int":
			if not (value is int or (value is float and is_equal_approx(value, roundf(value)))):
				return [value, ["%s: esperado número inteiro, obtido %s" % [where, str(value)]]]
			value = int(value)
			_check_enum(value, spec, where, errors)
			_check_range(value, spec, where, errors)
		"number":
			if not (value is int or value is float):
				return [value, ["%s: esperado número, obtido %s" % [where, str(value)]]]
			value = float(value)
			_check_range(value, spec, where, errors)
		"bool":
			if not value is bool:
				return [value, ["%s: esperado verdadeiro/falso, obtido %s" % [where, str(value)]]]
		"array":
			if not value is Array:
				return [value, ["%s: esperado lista" % where]]
			var element_spec := spec.duplicate()
			element_spec["type"] = spec.get("of", "string")
			var items: Array = []
			var seen := {}
			for i in value.size():
				var item_result := _validate_value(value[i], element_spec, "%s[%d]" % [where, i], pending_refs)
				errors.append_array(item_result[1])
				items.append(item_result[0])
				if seen.has(item_result[0]) and not spec.get("allow_duplicates", false):
					errors.append("%s: valor repetido '%s'" % [where, str(item_result[0])])
				seen[item_result[0]] = true
			_check_length(items, spec, where, errors)
			value = items
		"object_array":
			if not value is Array:
				return [value, ["%s: esperado lista de objetos" % where]]
			var objects: Array = []
			for i in value.size():
				if not value[i] is Dictionary:
					errors.append("%s[%d]: esperado objeto" % [where, i])
					continue
				var object_result := validate(value[i], spec["fields"], "%s[%d]" % [where, i], pending_refs)
				errors.append_array(object_result[1])
				objects.append(object_result[0])
			_check_length(objects, spec, where, errors)
			value = objects
		_:
			errors.append("%s: tipo de esquema desconhecido '%s'" % [where, type_name])
	return [value, errors]


static func _check_enum(value: Variant, spec: Dictionary, where: String, errors: Array[String]) -> void:
	if spec.has("enum") and not value in spec["enum"]:
		errors.append("%s: valor '%s' inválido (permitidos: %s)" % [where, str(value), str(spec["enum"])])


static func _check_range(value: Variant, spec: Dictionary, where: String, errors: Array[String]) -> void:
	if spec.has("min") and value < spec["min"]:
		errors.append("%s: %s menor que o mínimo %s" % [where, str(value), str(spec["min"])])
	if spec.has("max") and value > spec["max"]:
		errors.append("%s: %s maior que o máximo %s" % [where, str(value), str(spec["max"])])


static func _check_length(items: Array, spec: Dictionary, where: String, errors: Array[String]) -> void:
	if spec.has("min_length") and items.size() < spec["min_length"]:
		errors.append("%s: precisa de ao menos %d itens" % [where, spec["min_length"]])
	if spec.has("max_length") and items.size() > spec["max_length"]:
		errors.append("%s: aceita no máximo %d itens" % [where, spec["max_length"]])


static func _check_ref(value: String, spec: Dictionary, where: String, errors: Array[String],
		pending_refs: Array[Dictionary]) -> void:
	if not spec.has("ref") or value.is_empty():
		return
	match spec["ref"]:
		"ability":
			if not Ability.is_valid(StringName(value)):
				errors.append("%s: atributo desconhecido '%s'" % [where, value])
		"skill":
			if not Skill.is_valid(StringName(value)):
				errors.append("%s: perícia desconhecida '%s'" % [where, value])
		"damage_type":
			if not value in DAMAGE_TYPES:
				errors.append("%s: tipo de dano desconhecido '%s'" % [where, value])
		_:
			pending_refs.append({"where": where, "type": spec["ref"], "id": value,
					"item_type": spec.get("ref_item_type", "")})
