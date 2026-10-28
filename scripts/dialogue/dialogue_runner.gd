class_name DialogueRunner
extends RefCounted
## Conduz um diálogo definido em dados (data/dialogues/). Escolhe o nó inicial pela primeira
## entrada cuja condição é verdadeira, mostra só as escolhas cujas condições valem e aplica
## as ações (iniciar/concluir missão) no QuestLog. Só lógica; a interface exibe o resultado.
##
## Condições: quest_available:<id>, quest_active:<id> (ativa e ainda não pronta),
## quest_ready:<id>, quest_completed:<id>, quest_started:<id>, objective_open/objective_done:<id>#<objetivo>,
## companion_recruited/companion_available:<id>, gold_at_least/gold_below:<n>, trigger_resolved:<gatilho>.
## Ações (várias separadas por ";"): start_quest, complete_quest, give_item:<item>#<n>, recruit:<companion>,
## pay_gold:<n>. Escolhas com "check"/"dc" fazem um teste de perícia do melhor membro do grupo.

var dialogue: Dictionary = {}
var node: Dictionary = {}
var finished: bool = false

var _quests: QuestLog
var _party: Array[CharacterData] = []
var _inventory: Inventory
var _registry: ContentRegistry
var _roster: CompanionRoster
var _roller: DiceRoller
## Gatilhos de encontro já vencidos ({id: true}), para condições como "trigger_resolved".
var _resolved: Dictionary = {}


## Missões concluídas nesta conversa (para o mapa mostrar a conclusão da aventura).
var completed: Array[String] = []
## Recompensas dessas missões (XP, subida de nível, ouro, itens), sem a linha "Missão concluída".
var reward_lines: Array[String] = []


func begin(dialogue_entry: Dictionary, quests: QuestLog, party: Array[CharacterData], inventory: Inventory,
		registry: ContentRegistry, roster: CompanionRoster = null, roller: DiceRoller = null,
		resolved: Dictionary = {}) -> Dictionary:
	dialogue = dialogue_entry
	_quests = quests
	_party = party
	_inventory = inventory
	_registry = registry
	_roster = roster if roster != null else CompanionRoster.new()
	_roller = roller if roller != null else DiceRoller.new()
	_resolved = resolved
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
	var lines: Array[String] = []
	var next := str(choice.get("next", ""))
	var passed := true
	if not str(choice.get("check", "")).is_empty():
		var test := _skill_check(StringName(str(choice["check"])), int(choice.get("dc", 10)))
		lines.append(test["text"])
		passed = test["success"]
		if not passed:
			next = str(choice.get("fail_next", ""))
	if passed:
		lines.append_array(_apply(str(choice.get("action", ""))))
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
		"quest_started":
			return _quests.status(quest_id) != QuestLog.Status.NOT_STARTED
		"objective_done":
			var target := quest_id.split("#")
			return target.size() == 2 and _quests.is_objective_done(target[0], target[1])
		"companion_recruited":
			return _roster.is_recruited(quest_id)
		"companion_available":
			return not _roster.is_recruited(quest_id)
		"gold_at_least":
			return _inventory != null and _inventory.gold >= int(quest_id)
		"gold_below":
			return _inventory == null or _inventory.gold < int(quest_id)
		"trigger_resolved":
			return _resolved.has(quest_id)
		"quest_available":
			return _quests.status(quest_id) == QuestLog.Status.NOT_STARTED
		"quest_active":
			return _quests.status(quest_id) == QuestLog.Status.ACTIVE and not _quests.is_ready(quest_id, _registry)
		"quest_ready":
			return _quests.is_ready(quest_id, _registry)
		"quest_completed":
			return _quests.status(quest_id) == QuestLog.Status.COMPLETED
		"objective_open":
			# "objective_open:quest.x#objetivo": missão ativa com esse objetivo ainda não cumprido.
			var ids := quest_id.split("#")
			return ids.size() == 2 and _quests.status(ids[0]) == QuestLog.Status.ACTIVE \
					and not _quests.is_objective_done(ids[0], ids[1])
	return false


func _apply(action: String) -> Array[String]:
	var lines: Array[String] = []
	if action.is_empty():
		return lines
	if ";" in action:
		for piece in action.split(";"):
			lines.append_array(_apply(piece.strip_edges()))
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
				completed.append(parts[1])
				reward_lines.append_array(done["lines"].slice(1))
		"give_item":
			var spec := parts[1].split("#")
			var amount := int(spec[1]) if spec.size() > 1 else 1
			_inventory.add(spec[0], amount)
			lines.append("Recebeu %dx %s" % [amount, _registry.get_entry("item", spec[0]).get("name", spec[0])])
		"recruit":
			var joined := _roster.recruit(parts[1], _party, _registry)
			lines.append(joined["text"] if joined["ok"] else joined["error"])
		"pay_gold":
			var cost := int(parts[1])
			if _inventory != null and _inventory.gold >= cost:
				_inventory.gold -= cost
				lines.append("Pagou %d PO" % cost)
	return lines


## Teste de perícia feito pelo membro do grupo com o maior bônus. Retorna {success, text}.
func _skill_check(skill: StringName, dc: int) -> Dictionary:
	var best: CharacterSheet = null
	for c in _party:
		var sheet := CharacterSheet.build(c, _registry)
		if best == null or sheet.skill_bonus(skill) > best.skill_bonus(skill):
			best = sheet
	if best == null:
		return {"success": false, "text": "Ninguém para tentar."}
	var test := best.roll_skill_check(skill, dc, _roller)
	return {"success": test.success, "text": "Teste de %s (%s): %d %s = %d contra CD %d — %s" % [Skill.NAMES[skill],
			best.character.name, test.natural, Ability.format_modifier(test.modifier), test.total, dc,
			"sucesso" if test.success else "falha"]}


func _node(node_id: String) -> Dictionary:
	for candidate: Dictionary in dialogue.get("nodes", []):
		if candidate["id"] == node_id:
			return candidate
	return {}
