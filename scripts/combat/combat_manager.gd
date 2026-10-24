class_name CombatManager
extends RefCounted
## Controla a sequência do combate por turnos: posicionamento, iniciativa, turnos,
## validação de comandos, IA dos inimigos e fim do combate. Os cálculos vêm do motor
## de regras (Attack, D20Test); a interface só envia comandos e exibe os eventos.
## O resultado não depende de animação nem de tempo real.
##
## Comandos (submit):
##   {"type": "move", "actor": id, "to": Vector2i}
##   {"type": "attack", "actor": id, "target": id, "attack_id": id}
##   {"type": "end_turn", "actor": id}
##   {"type": "flee", "actor": id}
##   {"type": "use_item", "actor": id, "item_id": id} (consumível do inventário do grupo; ação bônus)
##   {"type": "cast", "actor": id, "spell_id": id, "target": id} (magia de alvo; "targets": [ids] extras)
##   {"type": "cast", "actor": id, "spell_id": id, "cell": Vector2i} (cone/cubo na direção da casa)
## Cada comando devolve {"ok": bool, "error": String, "events": Array[Dictionary]}.

enum State { SETUP, IN_PROGRESS, FINISHED }
enum Outcome { NONE, VICTORY, DEFEAT, FLED }

const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
## Proteção contra laços infinitos (ex.: dois lados que não conseguem se ferir).
const MAX_ROUNDS := 100

var state: State = State.SETUP
var outcome: Outcome = Outcome.NONE
var round_number: int = 0
var combatants: Array[Combatant] = []
var turn_order: Array[Combatant] = []
var arena_size := Vector2i(12, 8)
var flee_allowed: bool = true
var action_available: bool = false
var bonus_action_available: bool = false
var movement_left_feet: int = 0
## Regra de 2024: só um espaço de magia gasto por turno.
var slot_used_this_turn: bool = false
## Inventário do grupo, para consumíveis (opcional).
var inventory: Inventory = null
var registry: ContentRegistry = null

var _turn_index: int = -1
var _roller: DiceRoller
var _results_applied := false


func setup(party: Array[Combatant], enemies: Array[Combatant], arena: Vector2i, allow_flee: bool,
		roller: DiceRoller) -> void:
	assert(state == State.SETUP, "setup() só pode ser chamado uma vez")
	arena_size = arena
	flee_allowed = allow_flee
	_roller = roller
	combatants.clear()
	_place_column(party, 1)
	_place_column(enemies, arena.x - 2)
	combatants.append_array(party)
	combatants.append_array(enemies)


## Rola iniciativa (d20 + bônus) e começa o primeiro turno.
## Empates: maior bônus, depois maior Destreza, depois o grupo antes dos inimigos, depois o id.
func start() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for unit in combatants:
		var test := D20Test.roll(_roller, unit.initiative_bonus, 0)
		unit.initiative = test.total
		events.append({"type": "initiative", "actor": unit.id, "natural": test.natural,
				"bonus": unit.initiative_bonus, "total": test.total})
	turn_order = combatants.duplicate()
	turn_order.sort_custom(_initiative_before)
	state = State.IN_PROGRESS
	round_number = 1
	_turn_index = -1
	events.append({"type": "round_start", "round": round_number})
	events.append_array(_advance_turn())
	return events


func current() -> Combatant:
	if state != State.IN_PROGRESS or _turn_index < 0:
		return null
	return turn_order[_turn_index]


func is_party_turn() -> bool:
	var unit := current()
	return unit != null and unit.team == Combatant.Team.PARTY


func get_combatant(unit_id: String) -> Combatant:
	for unit in combatants:
		if unit.id == unit_id:
			return unit
	return null


func combatant_at(cell: Vector2i) -> Combatant:
	for unit in combatants:
		if unit.is_up() and unit.position == cell:
			return unit
	return null


func living(team: Combatant.Team) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for unit in combatants:
		if unit.team == team and unit.is_up():
			result.append(unit)
	return result


func total_xp() -> int:
	var total := 0
	for unit in combatants:
		if unit.team == Combatant.Team.ENEMY:
			total += unit.xp
	return total


func submit(command: Dictionary) -> Dictionary:
	if state != State.IN_PROGRESS:
		return _fail("O combate não está em andamento")
	var actor := current()
	if actor == null or str(command.get("actor", "")) != actor.id:
		return _fail("Não é o turno deste participante")
	match str(command.get("type", "")):
		"move":
			return _do_move(actor, command.get("to", Vector2i(-1, -1)))
		"attack":
			return _do_attack(actor, get_combatant(str(command.get("target", ""))), str(command.get("attack_id", "")))
		"end_turn":
			return {"ok": true, "error": "", "events": _end_turn()}
		"flee":
			return _do_flee(actor)
		"use_item":
			return _do_use_item(actor, str(command.get("item_id", "")))
		"cast":
			return _do_cast(actor, str(command.get("spell_id", "")), str(command.get("target", "")),
					command.get("cell"), command.get("targets", []))
	return _fail("Comando desconhecido: '%s'" % str(command.get("type", "")))


## Casas alcançáveis pelo participante neste turno: {Vector2i: custo em pés}.
## Pode atravessar aliados, mas não inimigos, e não pode terminar numa casa ocupada.
func reachable_cells(actor: Combatant) -> Dictionary:
	var budget := movement_left_feet if actor == current() else actor.speed_feet
	var costs := {actor.position: 0}
	var frontier: Array[Vector2i] = [actor.position]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		for offset in NEIGHBORS:
			var next := cell + offset
			var cost: int = costs[cell] + Attack.FEET_PER_SQUARE
			if cost > budget or not _in_bounds(next) or costs.has(next):
				continue
			var occupant := combatant_at(next)
			if occupant != null and occupant.is_hostile_to(actor):
				continue
			costs[next] = cost
			frontier.append(next)
	var result := {}
	for cell: Vector2i in costs:
		if cell != actor.position and combatant_at(cell) == null:
			result[cell] = costs[cell]
	return result


## Mensagem de erro se o ataque não for possível agora; "" se for válido.
func attack_error(actor: Combatant, target: Combatant, attack: Dictionary) -> String:
	if attack.is_empty():
		return "Ataque desconhecido"
	if not action_available:
		return "A ação deste turno já foi usada"
	if target == null or not target.is_up():
		return "Alvo inválido"
	if not target.is_hostile_to(actor):
		return "Só é possível atacar inimigos"
	var distance := Attack.grid_distance_feet(actor.position, target.position)
	if attack["attack_type"] == "melee":
		if distance > int(attack.get("reach", Attack.MELEE_REACH_FEET)):
			return "Alvo fora do alcance corpo a corpo"
	elif distance > int(attack.get("range_long", 0)):
		return "Alvo fora do alcance máximo"
	return ""


## Vantagem/desvantagem do ataque, com o motivo de cada fonte.
func attack_advantage(actor: Combatant, target: Combatant, attack: Dictionary) -> Dictionary:
	var advantage: Array[String] = []
	var disadvantage: Array[String] = []
	if attack["attack_type"] == "ranged":
		if Attack.grid_distance_feet(actor.position, target.position) > int(attack.get("range_normal", 0)):
			disadvantage.append("além do alcance normal")
		for other in combatants:
			if other.is_up() and other.is_hostile_to(actor) and _adjacent(other, actor):
				disadvantage.append("inimigo adjacente")
				break
	if not actor.effects_of("mocked").is_empty():
		disadvantage.append("zombaria")
	if not target.effects_of("guided").is_empty():
		advantage.append("raio guiador")
	if actor.has_trait("trait.pack_tactics"):
		for ally in combatants:
			if ally != actor and ally.is_up() and not ally.is_hostile_to(actor) and _adjacent(ally, target):
				advantage.append("táticas de matilha")
				break
	return {"state": D20Test.resolve_advantage(advantage.size(), disadvantage.size()),
			"advantage": advantage, "disadvantage": disadvantage}


## Executa o turno do inimigo atual com IA determinística por prioridades:
## 1. corpo a corpo se já estiver adjacente ao alvo; 2. à distância se o alvo estiver no
## alcance normal e ninguém estiver adjacente; 3. aproximar-se e atacar; 4. encerrar o turno.
## Alvo: o personagem mais próximo; empate pelo menor PV e depois pelo id.
func run_enemy_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var actor := current()
	if actor == null or actor.team != Combatant.Team.ENEMY:
		return events
	var target := _choose_target(actor)
	if target != null:
		var melee := _first_attack(actor, "melee")
		var ranged := _first_attack(actor, "ranged")
		var acted := _ai_try_attack(actor, target, melee, ranged, events)
		if not acted and state == State.IN_PROGRESS:
			var destination := _ai_destination(actor, target)
			if destination != actor.position:
				events.append_array(_do_move(actor, destination)["events"])
			_ai_try_attack(actor, target, melee, ranged, events)
	if state == State.IN_PROGRESS:
		events.append_array(_end_turn())
	return events


## Mensagens de subida de nível geradas ao aplicar o XP da vitória.
var level_up_messages: Array[String] = []


## Copia PV e XP de volta para os personagens (subindo de nível se for o caso). Idempotente.
func apply_results_to_party(registry: ContentRegistry = null) -> void:
	if _results_applied or state != State.FINISHED:
		return
	_results_applied = true
	var party := combatants.filter(func(u: Combatant) -> bool: return u.team == Combatant.Team.PARTY)
	for unit: Combatant in party:
		if unit.character != null:
			unit.character.current_hp = unit.hp
	if outcome == Outcome.VICTORY and not party.is_empty():
		@warning_ignore("integer_division")
		var share := total_xp() / party.size()
		for unit: Combatant in party:
			if unit.character == null:
				continue
			if registry == null:
				unit.character.experience += share
				continue
			for up in Progression.award_xp(unit.character, share, registry):
				level_up_messages.append(Progression.describe(unit.character, up))


# --- Comandos -----------------------------------------------------------------

func _do_move(actor: Combatant, destination: Variant) -> Dictionary:
	if not destination is Vector2i:
		return _fail("Destino inválido")
	var reachable := reachable_cells(actor)
	if not reachable.has(destination):
		return _fail("Casa fora do alcance de movimento ou ocupada")
	var from := actor.position
	movement_left_feet -= int(reachable[destination])
	actor.position = destination
	return {"ok": true, "error": "", "events": [{"type": "move", "actor": actor.id, "from": from,
			"to": destination, "movement_left": movement_left_feet}] as Array[Dictionary]}


func _do_attack(actor: Combatant, target: Combatant, attack_id: String) -> Dictionary:
	var attack := actor.get_attack(attack_id)
	var error := attack_error(actor, target, attack)
	if not error.is_empty():
		return _fail(error)
	action_available = false
	var adv := attack_advantage(actor, target, attack)
	var bless := _bless_roll(actor)
	var roll := Attack.roll_attack(_roller, int(attack["attack_bonus"]) + bless, target.effective_ac(), adv["state"])
	_consume_attack_effects(actor, target)
	var event := {"type": "attack", "actor": actor.id, "target": target.id, "attack": attack["name"],
			"roll": roll, "advantage_reasons": adv["advantage"], "disadvantage_reasons": adv["disadvantage"],
			"damage": 0, "damage_type": attack["damage_type"], "target_hp": target.hp, "bless": bless}
	var events: Array[Dictionary] = []
	if roll["hit"]:
		var raw := Attack.roll_damage(DiceExpression.parse(str(attack["damage"])), _roller, roll["critical"])
		var damage := Attack.apply_damage_modifiers(raw, str(attack["damage_type"]), target.resistances)
		var extra := _mark_damage(actor, target, roll["critical"])
		event["damage"] = damage + int(extra["damage"])
		event["extra"] = extra
		event["resisted"] = damage < raw
		_apply_damage(target, damage + int(extra["damage"]), events, event)
	else:
		events.append(event)
	events.append_array(_check_end())
	return {"ok": true, "error": "", "events": events}


## Bebe um consumível: ação bônus (SRD 2024) ou ação, conforme o item.
func _do_use_item(actor: Combatant, item_id: String) -> Dictionary:
	if actor.team != Combatant.Team.PARTY or inventory == null or registry == null:
		return _fail("Sem acesso ao inventário")
	var item := registry.get_entry("item", item_id)
	if item.get("item_type") != "consumable":
		return _fail("Item não pode ser usado em combate")
	if inventory.count(item_id) <= 0:
		return _fail("Nenhum(a) %s no inventário" % item["name"])
	var uses_bonus: bool = item["use_time"] == "bonus_action"
	if uses_bonus and not bonus_action_available:
		return _fail("A ação bônus deste turno já foi usada")
	if not uses_bonus and not action_available:
		return _fail("A ação deste turno já foi usada")
	if actor.hp >= actor.max_hp:
		return _fail("PV já estão no máximo")
	inventory.remove(item_id)
	if uses_bonus:
		bonus_action_available = false
	else:
		action_available = false
	var amount := DiceExpression.parse(item["effect_dice"]).roll(_roller)
	var before := actor.hp
	actor.hp = mini(actor.max_hp, actor.hp + amount)
	return {"ok": true, "error": "", "events": [{"type": "heal", "actor": actor.id, "item": item["name"],
			"amount": actor.hp - before, "hp": actor.hp}] as Array[Dictionary]}


func _do_flee(actor: Combatant) -> Dictionary:
	if not flee_allowed:
		return _fail("Não é possível fugir deste combate")
	if actor.team != Combatant.Team.PARTY:
		return _fail("Só o grupo pode fugir")
	if not action_available:
		return _fail("Fugir exige a ação do turno")
	return {"ok": true, "error": "", "events": _finish(Outcome.FLED)}


func _end_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = [{"type": "turn_end", "actor": current().id}]
	_expire_effects("turn_end", current().id)
	events.append_array(_advance_turn())
	return events


func _advance_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in turn_order.size():
		_turn_index += 1
		if _turn_index >= turn_order.size():
			_turn_index = 0
			round_number += 1
			if round_number > MAX_ROUNDS:
				events.append_array(_finish(Outcome.FLED))
				return events
			events.append({"type": "round_start", "round": round_number})
		var unit := turn_order[_turn_index]
		_expire_effects("turn_start", unit.id)
		if unit.is_up():
			action_available = true
			bonus_action_available = true
			slot_used_this_turn = false
			movement_left_feet = maxi(0, unit.speed_feet - _slowed_feet(unit))
			events.append({"type": "turn_start", "actor": unit.id, "round": round_number})
			return events
	return events


func _check_end() -> Array[Dictionary]:
	if living(Combatant.Team.ENEMY).is_empty():
		return _finish(Outcome.VICTORY)
	if living(Combatant.Team.PARTY).is_empty():
		return _finish(Outcome.DEFEAT)
	return []


func _finish(result: Outcome) -> Array[Dictionary]:
	state = State.FINISHED
	outcome = result
	action_available = false
	bonus_action_available = false
	movement_left_feet = 0
	return [{"type": "combat_end", "outcome": result, "xp": total_xp() if result == Outcome.VICTORY else 0}]


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "events": [] as Array[Dictionary]}


# --- Magias -------------------------------------------------------------------

## Erro se a magia não pode ser conjurada agora (custos e ação); "" se pode.
func spell_error(actor: Combatant, spell_id: String) -> String:
	var spell := actor.get_spell(spell_id)
	if spell.is_empty():
		return "Magia desconhecida"
	var entry: Dictionary = spell["entry"]
	if entry["casting_time"] == "bonus_action":
		if not bonus_action_available:
			return "A ação bônus deste turno já foi usada"
	elif not action_available:
		return "A ação deste turno já foi usada"
	if int(entry["level"]) > 0:
		if actor.character == null or registry == null:
			return "Sem espaços de magia"
		if slot_used_this_turn:
			return "Só um espaço de magia pode ser gasto por turno"
		if Spellcasting.lowest_slot(actor.character, registry, int(entry["level"])) == 0:
			return "Sem espaços de magia disponíveis"
	return ""


## Erro se o alvo não serve para esta magia (alcance, inimigo/aliado); "" se serve.
func spell_target_error(actor: Combatant, spell_id: String, target: Combatant) -> String:
	var error := spell_error(actor, spell_id)
	if not error.is_empty():
		return error
	var entry: Dictionary = actor.get_spell(spell_id)["entry"]
	if is_area_spell(entry):
		return "Escolha uma direção para a área"
	if target == null:
		return "Alvo inválido"
	if entry["target"] == "enemy":
		if not target.is_up() or not target.is_hostile_to(actor):
			return "Escolha um inimigo"
	elif target.is_hostile_to(actor):
		return "Escolha um aliado"
	elif not target.is_up() and entry["resolution"] != "heal":
		return "Aliado caído"
	var reach := maxi(Attack.MELEE_REACH_FEET, int(entry["range_feet"]))
	if Attack.grid_distance_feet(actor.position, target.position) > reach:
		return "Alvo fora do alcance da magia (%d pés)" % reach
	return ""


static func is_area_spell(entry: Dictionary) -> bool:
	return entry["target"] in ["cone", "cube"]


## Casas atingidas por um cone/cubo a partir do conjurador, na direção da casa "aim".
## Adaptação para a grade: cone de 4,5 m = 7 casas (1, 3, 3) na reta ou 3x3 na diagonal;
## cubo de 4,5 m = 3x3 casas encostadas no conjurador.
func area_cells(actor: Combatant, entry: Dictionary, aim: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := aim - actor.position
	var dir := Vector2i(signi(delta.x), signi(delta.y))
	if dir == Vector2i.ZERO:
		return cells
	@warning_ignore("integer_division")
	var size := maxi(1, int(entry["area_feet"]) / Attack.FEET_PER_SQUARE)
	@warning_ignore("integer_division")
	var half_size := size / 2
	var diagonal := dir.x != 0 and dir.y != 0
	var side := Vector2i(-dir.y, dir.x)
	for forward in range(1, size + 1):
		if diagonal:
			for lateral in range(1, size + 1):
				var diag_cell := actor.position + Vector2i(dir.x * forward, dir.y * lateral)
				if _in_bounds(diag_cell) and not diag_cell in cells:
					cells.append(diag_cell)
			continue
		@warning_ignore("integer_division")
		var half := half_size if entry["target"] == "cube" else mini(forward / 2, half_size)
		for lateral in range(-half, half + 1):
			var cell := actor.position + dir * forward + side * lateral
			if _in_bounds(cell) and not cell in cells:
				cells.append(cell)
	return cells


func _do_cast(actor: Combatant, spell_id: String, target_id: String, aim: Variant, extra_ids: Variant) -> Dictionary:
	var error := spell_error(actor, spell_id)
	if not error.is_empty():
		return _fail(error)
	var spell := actor.get_spell(spell_id)
	var entry: Dictionary = spell["entry"]
	var spell_level := int(entry["level"])
	var targets: Array[Combatant] = []
	var cells: Array[Vector2i] = []
	if is_area_spell(entry):
		if not aim is Vector2i or aim == actor.position:
			return _fail("Escolha a direção da magia")
		cells = area_cells(actor, entry, aim)
		for unit in combatants:
			if unit.is_up() and unit != actor and unit.position in cells:
				targets.append(unit)
	else:
		var ids: Array[String] = [target_id]
		if extra_ids is Array:
			for extra: Variant in extra_ids:
				if not str(extra) in ids:
					ids.append(str(extra))
		var slot_preview := 0
		if spell_level > 0:
			slot_preview = Spellcasting.lowest_slot(actor.character, registry, spell_level)
		var max_targets := int(entry["max_targets"])
		if max_targets > 1:
			max_targets += maxi(0, slot_preview - spell_level)
		if ids.size() > max_targets:
			return _fail("Alvos demais para esta magia (máximo %d)" % max_targets)
		for id in ids:
			var unit := get_combatant(id)
			var target_error := spell_target_error(actor, spell_id, unit)
			if not target_error.is_empty():
				return _fail(target_error)
			targets.append(unit)
	var slot_level := 0
	if spell_level > 0:
		slot_level = Spellcasting.lowest_slot(actor.character, registry, spell_level)
		Spellcasting.spend_slot(actor.character, slot_level)
		slot_used_this_turn = true
	if entry["casting_time"] == "bonus_action":
		bonus_action_available = false
	else:
		action_available = false
	var target_ids: Array = targets.map(func(u: Combatant) -> String: return u.id)
	var events: Array[Dictionary] = [{"type": "cast", "actor": actor.id, "spell_id": spell_id, "spell": entry["name"],
			"level": spell_level, "slot_level": slot_level, "vfx": entry["vfx"], "color": entry["color"],
			"targets": target_ids, "cells": cells, "darts": _dart_count(entry, slot_level)}]
	if entry["concentration"]:
		_end_concentration(actor, events, "nova magia de concentração")
		actor.concentration = {"spell_id": spell_id, "name": entry["name"]}
	for target in targets:
		if state != State.IN_PROGRESS:
			break
		_resolve_spell_on(actor, entry, target, slot_level, events)
	events.append_array(_check_end())
	return {"ok": true, "error": "", "events": events}


func _dart_count(entry: Dictionary, slot_level: int) -> int:
	if int(entry["darts"]) == 0:
		return 0
	return int(entry["darts"]) + maxi(0, slot_level - int(entry["level"]))


func _resolve_spell_on(actor: Combatant, entry: Dictionary, target: Combatant, slot_level: int,
		events: Array[Dictionary]) -> void:
	var event := {"type": "spell_effect", "actor": actor.id, "target": target.id, "spell": entry["name"],
			"resolution": entry["resolution"], "damage": 0, "damage_type": entry["damage_type"], "healed": 0,
			"target_hp": target.hp, "effect": ""}
	var damage_dice: DiceExpression = null
	if not str(entry["damage"]).is_empty():
		damage_dice = Spellcasting.scaled_dice(entry, str(entry["damage"]), actor.character_level, slot_level)
	var damage := 0
	var affected := false
	match str(entry["resolution"]):
		"spell_attack":
			var pseudo := {"attack_type": "ranged" if int(entry["range_feet"]) > Attack.MELEE_REACH_FEET else "melee",
					"range_normal": int(entry["range_feet"])}
			var adv := attack_advantage(actor, target, pseudo)
			var bless := _bless_roll(actor)
			var roll := Attack.roll_attack(_roller, actor.spell_attack + bless, target.effective_ac(), adv["state"])
			_consume_attack_effects(actor, target)
			event["roll"] = roll
			event["bless"] = bless
			event["advantage_reasons"] = adv["advantage"]
			event["disadvantage_reasons"] = adv["disadvantage"]
			if roll["hit"]:
				var raw := Attack.roll_damage(damage_dice, _roller, roll["critical"])
				damage = Attack.apply_damage_modifiers(raw, str(entry["damage_type"]), target.resistances)
				event["resisted"] = damage < raw
				var extra := _mark_damage(actor, target, roll["critical"])
				event["extra"] = extra
				damage += int(extra["damage"])
				affected = true
		"save":
			var save := _roll_save(target, StringName(entry["save_ability"]), actor.spell_dc)
			event["save"] = {"natural": save.natural, "modifier": save.modifier, "total": save.total, "dc": save.dc,
					"success": save.success, "ability": entry["save_ability"]}
			var raw := damage_dice.roll(_roller)
			if save.success:
				@warning_ignore("integer_division")
				raw = raw / 2 if entry["half_on_save"] else 0
			affected = not save.success
			damage = Attack.apply_damage_modifiers(raw, str(entry["damage_type"]), target.resistances)
			event["resisted"] = damage < raw
		"auto":
			var darts := _dart_count(entry, slot_level)
			for i in darts:
				damage += Attack.apply_damage_modifiers(damage_dice.roll(_roller), str(entry["damage_type"]), target.resistances)
			event["darts"] = darts
		"heal":
			var heal_dice := Spellcasting.scaled_dice(entry, str(entry["heal"]), actor.character_level, slot_level)
			var amount := maxi(0, heal_dice.roll(_roller) + actor.spell_modifier)
			var before := target.hp
			target.hp = mini(target.max_hp, target.hp + amount)
			event["healed"] = target.hp - before
			event["target_hp"] = target.hp
		"buff":
			affected = true
	if affected:
		event["effect"] = _apply_spell_effect(actor, entry, target)
	event["damage"] = damage
	if damage > 0:
		_apply_damage(target, damage, events, event)
	else:
		events.append(event)
	if affected and entry["effect"] == "pushed" and target.is_up():
		@warning_ignore("integer_division")
		var squares := maxi(1, int(str(entry["effect_value"])) / Attack.FEET_PER_SQUARE)
		_push(actor, target, squares, events)


## Aplica o efeito da magia ao alvo. Retorna uma descrição curta (registro).
func _apply_spell_effect(actor: Combatant, entry: Dictionary, target: Combatant) -> String:
	var value := str(entry["effect_value"])
	match str(entry["effect"]):
		"slowed":
			target.effects.append({"kind": "slowed", "source": actor.id, "spell": entry["name"], "value": int(value),
					"on": "turn_start", "actor": actor.id, "count": 1})
			if target == current():
				movement_left_feet = maxi(0, movement_left_feet - int(value))
			return "deslocamento -%d pés" % int(value)
		"mocked":
			target.effects.append({"kind": "mocked", "source": actor.id, "spell": entry["name"],
					"on": "turn_end", "actor": target.id, "count": 1})
			return "desvantagem no próximo ataque"
		"guided":
			target.effects.append({"kind": "guided", "source": actor.id, "spell": entry["name"],
					"on": "turn_end", "actor": actor.id, "count": 2 if actor == current() else 1})
			return "próximo ataque contra o alvo com vantagem"
		"pushed":
			return "empurrado"
		"ac_bonus":
			target.effects.append({"kind": "ac_bonus", "source": actor.id, "spell": entry["name"], "value": int(value),
					"on": "concentration"})
			return "+%d na CA" % int(value)
		"blessed":
			target.effects.append({"kind": "blessed", "source": actor.id, "spell": entry["name"], "value": value,
					"on": "concentration"})
			return "+%s em ataques e resistências" % value
		"marked":
			target.effects.append({"kind": "marked", "source": actor.id, "spell": entry["name"], "value": value,
					"damage_type": entry["damage_type"], "on": "concentration"})
			return "marcado (+%s de dano)" % value
	return ""


## Dano em um alvo: PV, queda e teste de concentração. "event" (o que causou o dano) entra antes.
func _apply_damage(target: Combatant, damage: int, events: Array[Dictionary], event: Dictionary) -> void:
	target.hp = maxi(0, target.hp - damage)
	event["target_hp"] = target.hp
	events.append(event)
	if not target.is_up():
		events.append({"type": "down", "actor": target.id, "dead": target.team == Combatant.Team.ENEMY})
		_end_concentration(target, events, "caiu")
	elif damage > 0 and not target.concentration.is_empty():
		@warning_ignore("integer_division")
		var dc := clampi(damage / 2, 10, 30)
		var save := _roll_save(target, Ability.CONSTITUTION, dc)
		events.append({"type": "concentration_check", "actor": target.id, "spell": target.concentration["name"],
				"natural": save.natural, "modifier": save.modifier, "total": save.total, "dc": dc, "success": save.success})
		if not save.success:
			_end_concentration(target, events, "perdeu a concentração")


func _end_concentration(unit: Combatant, events: Array[Dictionary], reason: String) -> void:
	if unit.concentration.is_empty():
		return
	for other in combatants:
		var kept: Array[Dictionary] = []
		for effect in other.effects:
			if not (effect["on"] == "concentration" and effect["source"] == unit.id):
				kept.append(effect)
		other.effects = kept
	events.append({"type": "concentration_end", "actor": unit.id, "spell": unit.concentration["name"], "reason": reason})
	unit.concentration = {}


## Teste de resistência do alvo (com Bênção, se houver).
func _roll_save(target: Combatant, ability: StringName, dc: int) -> D20Test:
	return D20Test.roll(_roller, target.save_bonus(ability) + _bless_roll(target), dc)


## 1d4 da Bênção para ataques e resistências (0 sem Bênção).
func _bless_roll(unit: Combatant) -> int:
	var blessings := unit.effects_of("blessed")
	if blessings.is_empty():
		return 0
	return DiceExpression.parse(str(blessings[0]["value"])).roll(_roller)


## Zombaria some depois do próximo ataque de quem a sofreu; Raio Guiador, do próximo ataque contra o alvo.
func _consume_attack_effects(actor: Combatant, target: Combatant) -> void:
	_remove_effects(actor, "mocked")
	_remove_effects(target, "guided")


func _remove_effects(unit: Combatant, kind: String) -> void:
	var kept: Array[Dictionary] = []
	for effect in unit.effects:
		if effect["kind"] != kind:
			kept.append(effect)
	unit.effects = kept


## Dano extra de Marca do Caçador/Maldição do atacante sobre o alvo: {damage, damage_type, spell}.
func _mark_damage(actor: Combatant, target: Combatant, critical: bool) -> Dictionary:
	for effect in target.effects_of("marked"):
		if effect["source"] == actor.id:
			var raw := Attack.roll_damage(DiceExpression.parse(str(effect["value"])), _roller, critical)
			return {"damage": Attack.apply_damage_modifiers(raw, str(effect["damage_type"]), target.resistances),
					"damage_type": effect["damage_type"], "spell": effect["spell"]}
	return {"damage": 0, "damage_type": "", "spell": ""}


func _slowed_feet(unit: Combatant) -> int:
	var total := 0
	for effect in unit.effects_of("slowed"):
		total = maxi(total, int(effect["value"]))
	return total


## Remove efeitos que expiram no início/fim do turno de unit_id (após "count" ocorrências).
func _expire_effects(moment: String, unit_id: String) -> void:
	for unit in combatants:
		var kept: Array[Dictionary] = []
		for effect in unit.effects:
			if effect["on"] == moment and effect["actor"] == unit_id:
				effect["count"] = int(effect["count"]) - 1
				if int(effect["count"]) <= 0:
					continue
			kept.append(effect)
		unit.effects = kept


## Empurra o alvo para longe do conjurador, casa a casa, até "squares" casas livres.
func _push(actor: Combatant, target: Combatant, squares: int, events: Array[Dictionary]) -> void:
	var delta := target.position - actor.position
	var dir := Vector2i(signi(delta.x), signi(delta.y))
	if dir == Vector2i.ZERO:
		return
	var from := target.position
	for i in squares:
		var next := target.position + dir
		if not _in_bounds(next) or combatant_at(next) != null:
			break
		target.position = next
	if target.position != from:
		events.append({"type": "pushed", "actor": target.id, "from": from, "to": target.position})


# --- IA -----------------------------------------------------------------------

func _choose_target(actor: Combatant) -> Combatant:
	var best: Combatant = null
	for unit in living(Combatant.Team.PARTY if actor.team == Combatant.Team.ENEMY else Combatant.Team.ENEMY):
		if best == null:
			best = unit
			continue
		var d := Attack.grid_distance_feet(actor.position, unit.position)
		var best_d := Attack.grid_distance_feet(actor.position, best.position)
		if d < best_d or (d == best_d and (unit.hp < best.hp or (unit.hp == best.hp and unit.id < best.id))):
			best = unit
	return best


func _first_attack(actor: Combatant, attack_type: String) -> Dictionary:
	for attack in actor.attacks:
		if attack["attack_type"] == attack_type:
			return attack
	return {}


func _ai_try_attack(actor: Combatant, target: Combatant, melee: Dictionary, ranged: Dictionary,
		events: Array[Dictionary]) -> bool:
	if not action_available or state != State.IN_PROGRESS:
		return false
	if not melee.is_empty() and attack_error(actor, target, melee).is_empty():
		events.append_array(_do_attack(actor, target, melee["id"])["events"])
		return true
	if not ranged.is_empty() and attack_error(actor, target, ranged).is_empty():
		var distance := Attack.grid_distance_feet(actor.position, target.position)
		var threatened := false
		for other in combatants:
			if other.is_up() and other.is_hostile_to(actor) and _adjacent(other, actor):
				threatened = true
		if distance <= int(ranged.get("range_normal", 0)) and not threatened:
			events.append_array(_do_attack(actor, target, ranged["id"])["events"])
			return true
	return false


## Casa alcançável mais próxima do alvo; empate pelo menor custo e depois pela posição.
func _ai_destination(actor: Combatant, target: Combatant) -> Vector2i:
	var best := actor.position
	var best_key: Array[int] = [Attack.grid_distance_feet(actor.position, target.position), 0,
			actor.position.y, actor.position.x]
	var reachable := reachable_cells(actor)
	for cell: Vector2i in reachable:
		var key: Array[int] = [Attack.grid_distance_feet(cell, target.position), int(reachable[cell]), cell.y, cell.x]
		if _key_less(key, best_key):
			best_key = key
			best = cell
	return best


static func _key_less(a: Array[int], b: Array[int]) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


# --- Auxiliares ---------------------------------------------------------------

func _place_column(units: Array[Combatant], column: int) -> void:
	@warning_ignore("integer_division")
	var top := (arena_size.y - units.size()) / 2
	for i in units.size():
		units[i].position = Vector2i(column, top + i)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < arena_size.x and cell.y < arena_size.y


func _adjacent(a: Combatant, b: Combatant) -> bool:
	return Attack.grid_distance_feet(a.position, b.position) <= Attack.MELEE_REACH_FEET


static func _initiative_before(a: Combatant, b: Combatant) -> bool:
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	if a.initiative_bonus != b.initiative_bonus:
		return a.initiative_bonus > b.initiative_bonus
	if a.dexterity_score != b.dexterity_score:
		return a.dexterity_score > b.dexterity_score
	if a.team != b.team:
		return a.team == Combatant.Team.PARTY
	return a.id < b.id
