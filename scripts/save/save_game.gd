class_name SaveGame
extends RefCounted
## Formato do salvamento (um único slot) e as regras para montá-lo, validá-lo e aplicá-lo.
## Sem acesso a arquivos: o SaveManager cuida da gravação; aqui só há dados.
##
## Arquivo = JSON externo {"format", "checksum", "body"}, em que body é o texto JSON do estado e
## checksum é o SHA-256 desse texto. Assim qualquer corte ou alteração do arquivo é detectado
## antes de interpretar o conteúdo (os números do JSON não voltam idênticos, o texto sim).
##
## Estado (body): save_version, game_version, saved_at, summary, location, party, inventory,
## quests, exploration e travel. Personagens usam CharacterData.to_dict() (com migração própria).

const FORMAT := "fantasy_rpg_save"
const SAVE_VERSION := 1
const KIND_MAP := "map"
const KIND_TRAVEL := "travel"
const TRAVEL_SCENE := "res://scenes/travel/travel_scene.tscn"


## Estado atual do jogo (autoloads) no local informado ({"kind", "scene", "position"}).
static func capture(location: Dictionary) -> Dictionary:
	var party: Array = []
	for member in PartyManager.members:
		party.append(member.to_dict())
	var leader: CharacterData = PartyManager.get_leader()
	return {
		"save_version": SAVE_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"saved_at": int(Time.get_unix_time_from_system()),
		"summary": summary_for(leader, location, Content.registry),
		"location": location.duplicate(true),
		"party": party,
		"inventory": PartyManager.inventory.to_dict(),
		"companions": PartyManager.roster.to_dict(),
		"quests": QuestManager.log.to_dict(),
		"exploration": {
			"resolved_triggers": ExplorationManager.resolved_triggers.keys(),
			"disarmed_trigger": ExplorationManager.disarmed_trigger_id,
			"once_events": ExplorationManager.once_events.keys(),
		},
		"travel": ExplorationManager.travel_state.duplicate(true),
	}


## Resumo exibido no título ("Continuar") sem precisar aplicar o save.
static func summary_for(leader: CharacterData, location: Dictionary, registry: ContentRegistry) -> Dictionary:
	if leader == null:
		return {}
	var place := "Em viagem"
	if location.get("kind") == KIND_MAP:
		var map_id := map_for_scene(str(location.get("scene", "")), registry)
		place = registry.get_entry("map", map_id).get("name", "?")
	return {
		"name": leader.name,
		"level": leader.level,
		"species": registry.get_entry("species", leader.species_id).get("name", ""),
		"class": registry.get_entry("class", leader.class_id).get("name", ""),
		"place": place,
	}


static func map_for_scene(scene: String, registry: ContentRegistry) -> String:
	for id in registry.ids("map"):
		if registry.get_entry("map", id).get("scene") == scene:
			return id
	return ""


# --- Texto do arquivo -----------------------------------------------------------

static func encode(state: Dictionary) -> String:
	var body := JSON.stringify(state, "\t")
	return JSON.stringify({"format": FORMAT, "checksum": body.sha256_text(), "body": body}, "\t")


## Lê o texto do arquivo e valida tudo. Retorna {ok, errors, data (estado migrado), state (objetos prontos)}.
static func decode(text: String, registry: ContentRegistry) -> Dictionary:
	var outer: Variant = JSON.parse_string(text)
	if not outer is Dictionary:
		return _fail("o arquivo não é um JSON válido (pode ter sido cortado durante a gravação)")
	if outer.get("format") != FORMAT:
		return _fail("o arquivo não é um salvamento deste jogo")
	var body: Variant = outer.get("body")
	if not body is String or str(outer.get("checksum", "")) != (body as String).sha256_text():
		return _fail("a soma de verificação não confere (arquivo incompleto ou alterado)")
	var data: Variant = JSON.parse_string(body)
	if not data is Dictionary:
		return _fail("o conteúdo do salvamento é inválido")
	var migrated := migrate(data)
	if not migrated["ok"]:
		return migrated
	return validate(migrated["data"], registry)


## Migrações entre versões do esquema. Versões futuras desconhecidas são recusadas.
static func migrate(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var version := int(result.get("save_version", -1))
	if version < 1:
		return _fail("versão de salvamento ausente ou inválida")
	if version > SAVE_VERSION:
		return _fail("salvo por uma versão mais nova do jogo (esquema %d)" % version)
	# Exemplo para o futuro: if version == 1: ...; version = 2
	result["save_version"] = SAVE_VERSION
	return {"ok": true, "errors": [] as Array[String], "data": result}


## Confere cada parte e monta os objetos. Nada é aplicado ao jogo aqui.
static func validate(data: Dictionary, registry: ContentRegistry) -> Dictionary:
	var errors: Array[String] = []
	var location: Variant = data.get("location")
	var travel: Variant = data.get("travel", {})
	if not travel is Dictionary:
		errors.append("estado de viagem inválido")
		travel = {}
	if not location is Dictionary:
		errors.append("local do salvamento ausente")
	elif location.get("kind") == KIND_MAP:
		var position: Variant = location.get("position")
		if map_for_scene(str(location.get("scene", "")), registry).is_empty():
			errors.append("mapa desconhecido: %s" % location.get("scene", ""))
		if not position is Array or position.size() != 2 or not (position[0] is float or position[0] is int) \
				or not (position[1] is float or position[1] is int):
			errors.append("posição do jogador inválida")
	elif location.get("kind") == KIND_TRAVEL:
		if (travel as Dictionary).is_empty():
			errors.append("salvo em viagem, mas sem estado de viagem")
	else:
		errors.append("tipo de local desconhecido")
	if not (travel as Dictionary).is_empty():
		var route_id := str((travel as Dictionary).get("route_id", ""))
		if not registry.has("route", route_id):
			errors.append("rota desconhecida: %s" % route_id)
		var pending: Variant = (travel as Dictionary).get("pending", {})
		if pending is Dictionary and pending.get("kind") == "combat":
			errors.append("salvo no meio de um combate de viagem")

	var members: Array[CharacterData] = []
	var party: Variant = data.get("party")
	if not party is Array or party.is_empty():
		errors.append("grupo vazio")
	else:
		for entry: Variant in party:
			if not entry is Dictionary:
				errors.append("personagem inválido")
				continue
			var result := CharacterData.from_dict(entry)
			var c: CharacterData = result[0]
			if c == null:
				errors.append("personagem inválido: %s" % "; ".join(result[1]))
				continue
			# Saves anteriores às magias (esquema 3): o conjurador recebe as magias padrão da classe.
			if c.cantrips.is_empty() and c.prepared_spells.is_empty():
				Spellcasting.fill_defaults(c, registry)
			# Saves anteriores às escolhas (esquema 4): talentos, maestria e subclasse recebem o padrão.
			CharacterChoices.fill_defaults(c, registry)
			var problems := CharacterFactory.validate(c, registry)
			if not problems.is_empty():
				errors.append("%s: %s" % [c.name, "; ".join(problems)])
			members.append(c)

	var inventory: Inventory = null
	var raw_inventory: Variant = data.get("inventory")
	if raw_inventory is Dictionary:
		var result := Inventory.from_dict(raw_inventory, registry)
		inventory = result[0]
		if inventory == null:
			errors.append("inventário: %s" % "; ".join(result[1]))
	else:
		errors.append("inventário ausente")

	var quests: QuestLog = null
	var raw_quests: Variant = data.get("quests")
	if raw_quests is Dictionary:
		var result := QuestLog.from_dict(raw_quests, registry)
		quests = result[0]
		if quests == null:
			errors.append("missões: %s" % "; ".join(result[1]))
	else:
		errors.append("diário de missões ausente")

	var roster_result := CompanionRoster.from_dict(data.get("companions", {}), registry)
	for problem: String in roster_result[1]:
		errors.append("companheiros: %s" % problem)

	var resolved: Array[String] = []
	var exploration: Variant = data.get("exploration", {})
	if exploration is Dictionary and exploration.get("resolved_triggers", []) is Array:
		for trigger: Variant in exploration["resolved_triggers"]:
			resolved.append(str(trigger))
	else:
		errors.append("estado de exploração inválido")

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "data": data, "state": {}}
	return {"ok": true, "errors": errors, "data": data, "state": {
		"members": members,
		"inventory": inventory,
		"roster": roster_result[0],
		"quests": quests,
		"resolved_triggers": resolved,
		"disarmed_trigger": str((exploration as Dictionary).get("disarmed_trigger", "")),
		"once_events": Array((exploration as Dictionary).get("once_events", [])).map(func(v: Variant) -> String: return str(v)),
		"travel": travel,
		"location": location,
		"summary": data.get("summary", {}),
		"saved_at": int(data.get("saved_at", 0)),
	}}


## Aplica um estado validado aos autoloads. Retorna a cena a carregar.
static func apply(state: Dictionary) -> String:
	PartyManager.restore(state["members"], state["inventory"], state.get("roster"))
	QuestManager.reset()
	QuestManager.log = state["quests"]
	ExplorationManager.reset()
	for trigger: String in state["resolved_triggers"]:
		ExplorationManager.resolved_triggers[trigger] = true
	ExplorationManager.disarmed_trigger_id = state["disarmed_trigger"]
	for id: String in state.get("once_events", []):
		ExplorationManager.once_events[id] = true
	ExplorationManager.travel_state = (state["travel"] as Dictionary).duplicate(true)
	var location: Dictionary = state["location"]
	if location["kind"] == KIND_TRAVEL:
		return TRAVEL_SCENE
	var position: Array = location["position"]
	ExplorationManager.return_scene = location["scene"]
	ExplorationManager.return_position = Vector2(float(position[0]), float(position[1]))
	ExplorationManager.has_return_position = true
	return location["scene"]


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "errors": [message] as Array[String], "data": {}, "state": {}}
