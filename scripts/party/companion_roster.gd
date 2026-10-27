class_name CompanionRoster
extends RefCounted
## Companheiros recrutáveis (dados em data/companions/): quem já foi recrutado e quem espera na
## estalagem. O grupo ativo tem o protagonista e até dois companheiros (MAX_PARTY); os demais
## recrutados ficam no banco. Ao entrar no grupo, o companheiro acompanha o nível do protagonista.
## Só lógica; o PartyManager guarda a instância e o grupo ativo.

const MAX_PARTY := 3
const INN_NAME := "Estalagem do Ganso Dourado, em Ribeira"

## Ids dos companheiros já recrutados (no grupo ou no banco).
var recruited: Array[String] = []
## Recrutados fora do grupo, esperando na estalagem.
var bench: Array[CharacterData] = []


func is_recruited(companion_id: String) -> bool:
	return companion_id in recruited


## Id do personagem criado para o companheiro ("companion.doran" -> "character.companion_doran").
static func character_id(companion_id: String) -> String:
	return "character.companion_%s" % companion_id.trim_prefix("companion.")


static func companion_id_of(c: CharacterData) -> String:
	return "companion.%s" % c.id.trim_prefix("character.companion_") if c.id.begins_with("character.companion_") else ""


## Monta o personagem do companheiro no nível pedido: arranjo padrão sugerido da classe, aumentos do
## antecedente, perícias da classe que o antecedente não dá, aparência dos dados e escolhas padrão.
static func build(entry: Dictionary, level: int, registry: ContentRegistry) -> CharacterData:
	var class_entry := registry.get_entry("class", entry["class_id"])
	var background := registry.get_entry("background", entry["background_id"])
	var species := registry.get_entry("species", entry["species_id"])
	var blocked: Array = background.get("skill_proficiencies", []).duplicate()
	var class_skills: Array[StringName] = []
	for skill: Variant in entry.get("skills", []) + class_entry.get("skill_options", []):
		if class_skills.size() < int(class_entry["skill_choice_count"]) and not skill in blocked \
				and not StringName(skill) in class_skills and skill in class_entry["skill_options"]:
			class_skills.append(StringName(skill))
	var species_skills: Array[StringName] = []
	for skill in CharacterFactory.species_skill_options(species):
		if species_skills.size() < int(species.get("extra_skill_choices", 0)) and not skill in class_skills \
				and not String(skill) in blocked:
			species_skills.append(skill)
	var expertise: Array[StringName] = []
	for skill in class_skills:
		if expertise.size() < int(class_entry.get("expertise_choices", 0)):
			expertise.append(skill)
	var scores := {}
	for i in Ability.ALL.size():
		scores[Ability.ALL[i]] = int(class_entry["suggested_scores"][i])
	var options: Array = background["ability_options"]
	var result := CharacterFactory.create({
		"id": character_id(entry["id"]), "name": entry["name"], "species_id": entry["species_id"],
		"class_id": entry["class_id"], "background_id": entry["background_id"], "ability_method": "standard_array",
		"base_scores": scores, "background_increases": {StringName(options[0]): 2, StringName(options[1]): 1},
		"class_skills": class_skills, "species_skills": species_skills, "expertise": expertise,
		"appearance": entry.get("appearance", {}),
	}, registry)
	var c: CharacterData = result[0]
	if c == null:
		push_error("Companheiro inválido %s: %s" % [entry["id"], result[1]])
		return null
	for i in maxi(0, level - 1):
		Progression.level_up(c, registry)
	c.experience = Progression.XP_FOR_LEVEL[clampi(level, 1, Progression.XP_FOR_LEVEL.size() - 1)]
	c.current_hp = CharacterSheet.build(c, registry).max_hp
	return c


## Recruta: entra no grupo se houver vaga, senão vai esperar na estalagem. Retorna {ok, error, text, joined}.
func recruit(companion_id: String, party: Array[CharacterData], registry: ContentRegistry) -> Dictionary:
	var entry := registry.get_entry("companion", companion_id)
	if entry.is_empty():
		return {"ok": false, "error": "Companheiro desconhecido: %s" % companion_id, "text": "", "joined": false}
	if is_recruited(companion_id):
		return {"ok": false, "error": "%s já está com você" % entry["name"], "text": "", "joined": false}
	var leader: CharacterData = party[0] if not party.is_empty() else null
	var c := build(entry, leader.level if leader != null else 1, registry)
	if c == null:
		return {"ok": false, "error": "Não foi possível criar %s" % entry["name"], "text": "", "joined": false}
	recruited.append(companion_id)
	if party.size() < MAX_PARTY:
		party.append(c)
		return {"ok": true, "error": "", "text": "%s entrou para o grupo!" % entry["name"], "joined": true}
	bench.append(c)
	return {"ok": true, "error": "", "joined": false,
			"text": "%s se junta a você e vai esperar na %s (o grupo está cheio)." % [entry["name"], INN_NAME]}


## Companheiro do banco entra no grupo, alcançando a experiência do protagonista.
func join(c: CharacterData, party: Array[CharacterData], registry: ContentRegistry) -> Dictionary:
	if not c in bench:
		return {"ok": false, "error": "%s não está na estalagem" % c.name, "lines": [] as Array[String]}
	if party.size() >= MAX_PARTY:
		return {"ok": false, "error": "O grupo já tem %d membros" % MAX_PARTY, "lines": [] as Array[String]}
	bench.erase(c)
	party.append(c)
	var lines: Array[String] = ["%s entrou para o grupo." % c.name]
	if not party.is_empty() and party[0].experience > c.experience:
		for up in Progression.award_xp(c, party[0].experience - c.experience, registry):
			lines.append(Progression.describe(c, up))
	return {"ok": true, "error": "", "lines": lines}


## Companheiro do grupo vai esperar na estalagem (o protagonista nunca sai).
func leave(c: CharacterData, party: Array[CharacterData]) -> Dictionary:
	var index := party.find(c)
	if index <= 0:
		return {"ok": false, "error": "O protagonista não pode deixar o grupo"}
	party.remove_at(index)
	bench.append(c)
	return {"ok": true, "error": ""}


func to_dict() -> Dictionary:
	return {"recruited": recruited.duplicate(), "bench": bench.map(func(c: CharacterData) -> Dictionary: return c.to_dict())}


## Estado salvo -> [CompanionRoster, erros]. Os personagens do banco passam pela mesma validação do grupo.
static func from_dict(data: Variant, registry: ContentRegistry) -> Array:
	var roster := CompanionRoster.new()
	var errors: Array[String] = []
	if not data is Dictionary:
		return [roster, errors]
	for id: Variant in (data as Dictionary).get("recruited", []):
		if registry.has("companion", str(id)):
			roster.recruited.append(str(id))
		else:
			errors.append("companheiro desconhecido: %s" % id)
	for raw: Variant in (data as Dictionary).get("bench", []):
		if not raw is Dictionary:
			errors.append("companheiro inválido na estalagem")
			continue
		var result := CharacterData.from_dict(raw)
		var c: CharacterData = result[0]
		if c == null:
			errors.append("companheiro inválido: %s" % "; ".join(result[1]))
			continue
		CharacterChoices.fill_defaults(c, registry)
		var problems := CharacterFactory.validate(c, registry)
		if not problems.is_empty():
			errors.append("%s: %s" % [c.name, "; ".join(problems)])
		roster.bench.append(c)
	return [roster, errors]
