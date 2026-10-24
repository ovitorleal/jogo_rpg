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
var movement_left_feet: int = 0

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


## Copia PV e XP de volta para os personagens. Idempotente.
func apply_results_to_party() -> void:
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
			if unit.character != null:
				unit.character.experience += share


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
	var roll := Attack.roll_attack(_roller, int(attack["attack_bonus"]), target.armor_class, adv["state"])
	var event := {"type": "attack", "actor": actor.id, "target": target.id, "attack": attack["name"],
			"roll": roll, "advantage_reasons": adv["advantage"], "disadvantage_reasons": adv["disadvantage"],
			"damage": 0, "damage_type": attack["damage_type"], "target_hp": target.hp}
	var events: Array[Dictionary] = [event]
	if roll["hit"]:
		var raw := Attack.roll_damage(DiceExpression.parse(str(attack["damage"])), _roller, roll["critical"])
		var damage := Attack.apply_damage_modifiers(raw, str(attack["damage_type"]), target.resistances)
		target.hp = maxi(0, target.hp - damage)
		event["damage"] = damage
		event["resisted"] = damage < raw
		event["target_hp"] = target.hp
		if not target.is_up():
			events.append({"type": "down", "actor": target.id,
					"dead": target.team == Combatant.Team.ENEMY})
	events.append_array(_check_end())
	return {"ok": true, "error": "", "events": events}


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
		if unit.is_up():
			action_available = true
			movement_left_feet = unit.speed_feet
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
	movement_left_feet = 0
	return [{"type": "combat_end", "outcome": result, "xp": total_xp() if result == Outcome.VICTORY else 0}]


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "events": [] as Array[Dictionary]}


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
