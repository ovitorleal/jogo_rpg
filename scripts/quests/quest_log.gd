class_name QuestLog
extends RefCounted
## Estado das missões do jogador: ativas (com objetivos cumpridos) e concluídas.
## Objetivos avançam por notificações ("defeat_encounter", "reach_map"); a missão fica
## "pronta" quando todos os objetivos estão cumpridos e é entregue por um diálogo, que
## concede as recompensas. Só lógica; serializável.

enum Status { NOT_STARTED, ACTIVE, COMPLETED }

## quest_id -> {"status": "active"|"completed", "done": Array[String]}
var quests: Dictionary = {}


func status(quest_id: String) -> Status:
	match str(quests.get(quest_id, {}).get("status", "")):
		"active":
			return Status.ACTIVE
		"completed":
			return Status.COMPLETED
	return Status.NOT_STARTED


func is_objective_done(quest_id: String, objective_id: String) -> bool:
	return objective_id in quests.get(quest_id, {}).get("done", [])


## Ativa e com todos os objetivos cumpridos.
func is_ready(quest_id: String, registry: ContentRegistry) -> bool:
	if status(quest_id) != Status.ACTIVE:
		return false
	for objective: Dictionary in registry.get_entry("quest", quest_id).get("objectives", []):
		if not is_objective_done(quest_id, objective["id"]):
			return false
	return true


func start(quest_id: String, registry: ContentRegistry) -> Dictionary:
	if not registry.has("quest", quest_id):
		return _fail("Missão desconhecida: '%s'" % quest_id)
	if status(quest_id) != Status.NOT_STARTED:
		return _fail("Missão já iniciada")
	quests[quest_id] = {"status": "active", "done": []}
	return {"ok": true, "error": "", "text": "Nova missão: %s" % registry.get_entry("quest", quest_id)["name"]}


## Registra algo que aconteceu no jogo; retorna mensagens de objetivos cumpridos.
func notify(kind: String, target: String, registry: ContentRegistry) -> Array[String]:
	var messages: Array[String] = []
	for quest_id: String in quests:
		if status(quest_id) != Status.ACTIVE:
			continue
		var quest := registry.get_entry("quest", quest_id)
		for objective: Dictionary in quest.get("objectives", []):
			if objective["type"] == kind and objective["target"] == target and not is_objective_done(quest_id, objective["id"]):
				quests[quest_id]["done"].append(objective["id"])
				messages.append("Objetivo cumprido: %s" % objective["text"])
		if is_ready(quest_id, registry):
			messages.append("Volte a %s para concluir \"%s\"." % [quest["giver"], quest["name"]])
	return messages


## Conclui e entrega as recompensas (XP para todos, ouro e itens para o inventário).
func complete(quest_id: String, party: Array[CharacterData], inventory: Inventory, registry: ContentRegistry) -> Dictionary:
	if not is_ready(quest_id, registry):
		return _fail("A missão ainda não pode ser concluída")
	var quest := registry.get_entry("quest", quest_id)
	quests[quest_id]["status"] = "completed"
	var lines: Array[String] = ["Missão concluída: %s" % quest["name"]]
	var xp := int(quest.get("reward_xp", 0))
	if xp > 0:
		lines.append("+%d XP" % xp)
		for c in party:
			for up in Progression.award_xp(c, xp, registry):
				lines.append(Progression.describe(c, up))
	lines.append_array(inventory.grant(int(quest.get("reward_gold", 0)), quest.get("reward_items", []), registry))
	return {"ok": true, "error": "", "lines": lines}


func active_ids() -> Array[String]:
	var result: Array[String] = []
	for quest_id: String in quests:
		if status(quest_id) == Status.ACTIVE:
			result.append(quest_id)
	return result


func completed_ids() -> Array[String]:
	var result: Array[String] = []
	for quest_id: String in quests:
		if status(quest_id) == Status.COMPLETED:
			result.append(quest_id)
	return result


func to_dict() -> Dictionary:
	return {"quests": quests.duplicate(true)}


static func from_dict(data: Dictionary, registry: ContentRegistry) -> Array:
	var log := QuestLog.new()
	var errors: Array[String] = []
	var raw: Variant = data.get("quests", {})
	if not raw is Dictionary:
		return [null, ["Diário de missões inválido"]]
	for key: Variant in raw:
		var quest_id := str(key)
		var entry: Variant = raw[key]
		if not registry.has("quest", quest_id):
			errors.append("Missão desconhecida no diário: '%s'" % quest_id)
		elif not entry is Dictionary or not str(entry.get("status", "")) in ["active", "completed"]:
			errors.append("Estado inválido da missão '%s'" % quest_id)
		else:
			log.quests[quest_id] = {"status": entry["status"], "done": Array(entry.get("done", [])).map(func(v: Variant) -> String: return str(v))}
	return [log if errors.is_empty() else null, errors]


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
