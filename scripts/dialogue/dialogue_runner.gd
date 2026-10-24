class_name DialogueRunner
extends RefCounted
## Conduz um diálogo definido em dados (data/dialogues/). Escolhe o nó inicial pela primeira
## entrada cuja condição é verdadeira, mostra só as escolhas cujas condições valem e aplica
## as ações (iniciar/concluir missão) no QuestLog. Só lógica; a interface exibe o resultado.
##
## Condições: quest_available:<id>, quest_active:<id> (ativa e ainda não pronta),
## quest_ready:<id>, quest_completed:<id>. Ações: start_quest:<id>, complete_quest:<id>.

var dialogue: Dictionary = {}
var node: Dictionary = {}
var finished: bool = false

var _quests: QuestLog
var _party: Array[CharacterData] = []
var _inventory: Inventory
var _registry: ContentRegistry


func begin(dialogue_entry: Dictionary, quests: QuestLog, party: Array[CharacterData], inventory: Inventory,
		registry: ContentRegistry) -> Dictionary:
	dialogue = dialogue_entry
	_quests = quests
	_party = party
	_inventory = inventory
	_registry = registry
	finished = false
	node = {}
	for entry: Dictionary in dialogue.get("entries", []):
		if check(str(entry.get("condition", ""))):
			node = _node(entry["node"])
			break
	finished = node.is_empty()
	return node


func speaker() -> String:
	return str(dialogue.get("speaker", ""))


## Escolhas visíveis no nó atual (com condição verdadeira).
func choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for choice: Dictionary in node.get("choices", []):
		if check(str(choice.get("condition", ""))):
			result.append(choice)
	return result


## Escolhe a opção visível de índice "index". Retorna {"ok", "error", "lines", "finished"}.
func choose(index: int) -> Dictionary:
	var visible := choices()
	if finished or index < 0 or index >= visible.size():
		return {"ok": false, "error": "Escolha inválida", "lines": [] as Array[String], "finished": finished}
	var choice := visible[index]
	var lines := _apply(str(choice.get("action", "")))
	var next := str(choice.get("next", ""))
	if next.is_empty():
		finished = true
		node = {}
	else:
		node = _node(next)
		finished = node.is_empty()
	return {"ok": true, "error": "", "lines": lines, "finished": finished}


func check(condition: String) -> bool:
	if condition.is_empty():
		return true
	var parts := condition.split(":", true, 1)
	if parts.size() != 2:
		return false
	var quest_id := parts[1]
	match parts[0]:
		"quest_available":
			return _quests.status(quest_id) == QuestLog.Status.NOT_STARTED
		"quest_active":
			return _quests.status(quest_id) == QuestLog.Status.ACTIVE and not _quests.is_ready(quest_id, _registry)
		"quest_ready":
			return _quests.is_ready(quest_id, _registry)
		"quest_completed":
			return _quests.status(quest_id) == QuestLog.Status.COMPLETED
	return false


func _apply(action: String) -> Array[String]:
	var lines: Array[String] = []
	if action.is_empty():
		return lines
	var parts := action.split(":", true, 1)
	match parts[0]:
		"start_quest":
			var started := _quests.start(parts[1], _registry)
			if started["ok"]:
				lines.append(started["text"])
		"complete_quest":
			var done := _quests.complete(parts[1], _party, _inventory, _registry)
			if done["ok"]:
				lines.append_array(done["lines"])
	return lines


func _node(node_id: String) -> Dictionary:
	for candidate: Dictionary in dialogue.get("nodes", []):
		if candidate["id"] == node_id:
			return candidate
	return {}
