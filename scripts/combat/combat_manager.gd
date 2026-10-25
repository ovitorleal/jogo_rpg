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
##   {"type": "offhand", "actor": id, "target": id} (ataque extra da propriedade Leve)
##   {"type": "dash" | "disengage" | "dodge", "actor": id, "bonus": bool} (ações padrão; "bonus" com Ação Astuta)
##   {"type": "feature", "actor": id, "feature": id, "target": id} (Fúria, Retomar o Fôlego, Rajada... ver CombatFeatures)
##   {"type": "option", "actor": id, "key": String, "value": Variant} (preferências: Golpe Astuto, Golpe Atordoante...)
## A ação de Ataque permite attacks_per_action() golpes (Ataque Extra) e pode-se mover entre eles.
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
const CONDITION_NAMES := {
	"blinded": "Cego", "charmed": "Enfeitiçado", "deafened": "Surdo", "frightened": "Amedrontado",
	"grappled": "Agarrado", "incapacitated": "Incapacitado", "invisible": "Invisível", "paralyzed": "Paralisado",
	"petrified": "Petrificado", "poisoned": "Envenenado", "prone": "Caído", "restrained": "Contido",
	"stunned": "Atordoado", "unconscious": "Inconsciente",
}

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
## Ação de Ataque do turno: já começou? quantos golpes restam?
var attack_action_used: bool = false
var attacks_left: int = 0
var disengaged: bool = false
## Arma Leve usada na ação de Ataque (para o ataque extra da propriedade Leve) e se ele já foi feito.
var light_weapon_used: String = ""
var offhand_used: bool = false
## Benefícios de "uma vez por turno" já usados (Trespassar, Talhar, Atacante Selvagem...).
var once_per_turn: Dictionary = {}
## Efeitos a aplicar depois do dano de um acerto (Golpe Astuto, Golpe Brutal), preenchidos pelo CombatFeatures.
var pending_after_hit: Array[Dictionary] = []
## A ação atual veio do Surto de Ação (não pode ser a ação de Magia).
var surge_action: bool = false
## Verdadeiro durante um ataque de oportunidade (Escapar da Horda).
var opportunity_attack: bool = false
## Conjuração atual gastou espaço (Discípulo da Vida, Curandeiro Abençoado) e curou outra criatura.
var _cast_with_slot: bool = false
var _healed_others: bool = false
## Combatentes com dois turnos na primeira rodada (Reflexos de Ladrão).
var _reflex_turns: Array[Combatant] = []
## Eventos gerados por reações a testes (Indomável...), entregues no próximo comando.
var _save_events: Array[Dictionary] = []
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
		var advantage := D20Test.Advantage.ADVANTAGE if CombatFeatures.initiative_advantage(unit) \
				or unit.has_condition("invisible") else D20Test.Advantage.NONE
		var test := D20Test.roll(_roller, unit.initiative_bonus, 0, advantage)
		unit.initiative = test.total
		events.append({"type": "initiative", "actor": unit.id, "natural": test.natural,
				"bonus": unit.initiative_bonus, "total": test.total})
	turn_order = combatants.duplicate()
	turn_order.sort_custom(_initiative_before)
	# Reflexos de Ladrão: um segundo turno na primeira rodada, na iniciativa - 10.
	for unit in combatants:
		if unit.has_feature("feature.thiefs_reflexes"):
			var index := turn_order.size()
			for i in turn_order.size():
				if turn_order[i].initiative <= unit.initiative - 10 and turn_order[i] != unit:
					index = i
					break
			turn_order.insert(index, unit)
			_reflex_turns.append(unit)
	for unit in combatants:
		CombatFeatures.on_initiative(self, unit, events)
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
	var result := _submit(command)
	_flush_save_events(result)
	return result


func _flush_save_events(result: Dictionary) -> void:
	if not _save_events.is_empty() and result.get("ok", false):
		var events: Array[Dictionary] = result["events"]
		events.append_array(_save_events)
	_save_events.clear()


func _submit(command: Dictionary) -> Dictionary:
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
		"offhand":
			return _do_offhand(actor, get_combatant(str(command.get("target", ""))))
		"dash", "disengage", "dodge":
			return _do_standard_action(actor, str(command["type"]), bool(command.get("bonus", false)))
		"feature":
			var feature_events: Array[Dictionary] = []
			var error := CombatFeatures.do_action(self, actor, str(command.get("feature", "")),
					get_combatant(str(command.get("target", ""))), feature_events)
			if not error.is_empty():
				return _fail(error)
			feature_events.append_array(_check_end())
			return {"ok": true, "error": "", "events": feature_events}
		"option":
			CombatFeatures.set_option(actor, str(command.get("key", "")), command.get("value"))
			return {"ok": true, "error": "", "events": [] as Array[Dictionary]}
	return _fail("Comando desconhecido: '%s'" % str(command.get("type", "")))


## Casas alcançáveis pelo participante neste turno: {Vector2i: custo em pés}.
## Pode atravessar aliados, mas não inimigos, e não pode terminar numa casa ocupada.
func reachable_cells(actor: Combatant) -> Dictionary:
	var budget := movement_left_feet if actor == current() else effective_speed(actor)
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
	if actor.is_incapacitated():
		return "Incapacitado"
	if not can_attack(actor):
		return "Sem ataques restantes nesta ação" if attack_action_used else "A ação deste turno já foi usada"
	return _target_error(actor, target, attack)


## Ainda há ataque da ação de Ataque (ou a ação está livre para começá-la).
func can_attack(actor: Combatant) -> bool:
	return not actor.is_incapacitated() and (attacks_left > 0 or action_available)


## Ataques por ação de Ataque: 1 + Ataque Extra (2, 3 ou 4 com as características do Guerreiro), ou os
## Ataques Múltiplos da fera (monstros e Forma Selvagem), o que for maior.
func attacks_per_action(actor: Combatant) -> int:
	var count := 1
	if actor.has_feature("feature.three_extra_attacks"):
		count = 4
	elif actor.has_feature("feature.two_extra_attacks"):
		count = 3
	elif actor.has_feature("feature.extra_attack"):
		count = 2
	return maxi(count, int(actor.state.get("multiattack", 1)))


func _target_error(actor: Combatant, target: Combatant, attack: Dictionary) -> String:
	if target == null or not target.is_up():
		return "Alvo inválido"
	if not target.is_hostile_to(actor):
		return "Só é possível atacar inimigos"
	if actor.has_condition("charmed") and _condition_source(actor, "charmed") == target.id:
		return "Enfeitiçado: não pode atacar quem o enfeitiçou"
	var distance := Attack.grid_distance_feet(actor.position, target.position)
	if attack["attack_type"] == "melee":
		if distance > int(attack.get("reach", Attack.MELEE_REACH_FEET)):
			return "Alvo fora do alcance corpo a corpo"
	elif distance > int(attack.get("range_long", 0)):
		return "Alvo fora do alcance máximo"
	if str(attack.get("unarmed", "")) in ["grapple", "shove"] and Combatant.size_rank(target.size) > Combatant.size_rank(actor.size) + 1:
		return "Alvo grande demais"
	return ""


## Vantagem/desvantagem do ataque, com o motivo de cada fonte (condições, efeitos, posição).
func attack_advantage(actor: Combatant, target: Combatant, attack: Dictionary) -> Dictionary:
	var advantage: Array[String] = []
	var disadvantage: Array[String] = []
	var distance := Attack.grid_distance_feet(actor.position, target.position)
	if attack["attack_type"] == "ranged":
		if distance > int(attack.get("range_normal", 0)):
			disadvantage.append("além do alcance normal")
		for other in combatants:
			if other.is_up() and other.is_hostile_to(actor) and _adjacent(other, actor) and not other.is_incapacitated():
				disadvantage.append("inimigo adjacente")
				break
	if "heavy" in attack.get("properties", []):
		var needed := Ability.DEXTERITY if attack["attack_type"] == "ranged" else Ability.STRENGTH
		if int(actor.scores.get(needed, 10)) < 13:
			disadvantage.append("arma pesada (%s < 13)" % Ability.SHORT_NAMES.get(needed, String(needed)))
	# Condições de quem ataca (Percepção às Cegas ignora a cegueira dentro do alcance).
	var actor_blindsight := CombatFeatures.blindsight(actor) >= distance
	for condition: String in ["prone", "poisoned", "blinded", "restrained", "frightened"]:
		if actor.has_condition(condition) and not (condition == "blinded" and actor_blindsight):
			disadvantage.append(CONDITION_NAMES[condition].to_lower())
	if actor.has_condition("grappled") and _condition_source(actor, "grappled") != target.id:
		disadvantage.append("agarrado")
	if actor.has_condition("invisible") and CombatFeatures.blindsight(target) < distance:
		advantage.append("invisível")
	# Condições e efeitos do alvo.
	if target.has_condition("prone"):
		if distance <= Attack.MELEE_REACH_FEET:
			advantage.append("alvo caído")
		else:
			disadvantage.append("alvo caído à distância")
	for condition: String in ["restrained", "stunned", "paralyzed", "unconscious", "blinded", "petrified"]:
		if target.has_condition(condition):
			advantage.append("alvo %s" % CONDITION_NAMES[condition].to_lower())
	if target.has_condition("invisible") and not actor_blindsight:
		disadvantage.append("alvo invisível")
	if not target.effects_of("warded").is_empty() and actor.creature_type in CombatFeatures.WARD_TYPES:
		disadvantage.append("proteção contra o bem e o mal")
	if not target.effects_of("dodging").is_empty() and not target.is_incapacitated():
		disadvantage.append("alvo se esquivando")
	if not actor.effects_of("mocked").is_empty():
		disadvantage.append("zombaria")
	if not actor.effects_of("sapped").is_empty():
		disadvantage.append("enfraquecido")
	if not target.effects_of("guided").is_empty():
		advantage.append("raio guiador")
	for effect in target.effects_of("vexed"):
		if effect["source"] == actor.id:
			advantage.append("atormentar")
			break
	if actor.has_trait("trait.pack_tactics"):
		for ally in combatants:
			if ally != actor and ally.is_up() and not ally.is_hostile_to(actor) and _adjacent(ally, target):
				advantage.append("táticas de matilha")
				break
	CombatFeatures.attack_mods(self, actor, target, attack, advantage, disadvantage)
	if CombatFeatures.blocks_advantage(target):
		advantage.clear()
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
	if actor.is_incapacitated():
		events.append_array(_end_turn())
		return events
	if actor.has_condition("grappled") and _try_escape_grapple(actor, events):
		events.append_array(_end_turn())
		return events
	var target := _choose_target(actor)
	if target != null:
		var melee := _first_attack(actor, "melee")
		var ranged := _first_attack(actor, "ranged")
		var acted := _ai_try_attack(actor, target, melee, ranged, events)
		# Amedrontado não se aproxima da fonte do medo; Atordoado (Golpe Astuto) só move ou age.
		var afraid := actor.has_condition("frightened")
		if not acted and state == State.IN_PROGRESS and not afraid:
			var destination := _ai_destination(actor, target)
			if destination != actor.position:
				events.append_array(_do_move(actor, destination)["events"])
			_ai_try_attack(actor, target, melee, ranged, events)
	if state == State.IN_PROGRESS:
		events.append_array(_end_turn())
	events.append_array(_save_events)
	_save_events.clear()
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

## Movimento casa a casa. Sair do alcance de um inimigo provoca Ataque de Oportunidade (reação),
## exceto após Desengajar; se cair, o movimento para ali.
func _do_move(actor: Combatant, destination: Variant) -> Dictionary:
	if not destination is Vector2i:
		return _fail("Destino inválido")
	if actor.is_incapacitated():
		return _fail("Incapacitado")
	var reachable := reachable_cells(actor)
	if not reachable.has(destination):
		return _fail("Casa fora do alcance de movimento ou ocupada")
	var events: Array[Dictionary] = []
	var path := _path_to(actor, destination)
	var segment_start := actor.position
	for cell in path:
		if not disengaged and actor != null:
			for enemy in combatants:
				if not _can_opportunity_attack(enemy, actor, cell):
					continue
				if actor.position != segment_start:
					events.append({"type": "move", "actor": actor.id, "from": segment_start, "to": actor.position,
							"movement_left": movement_left_feet})
					segment_start = actor.position
				enemy.reaction_available = false
				events.append({"type": "opportunity", "actor": enemy.id, "target": actor.id})
				opportunity_attack = true
				_resolve_weapon_attack(enemy, actor, _first_attack(enemy, "melee"), events, false)
				opportunity_attack = false
				if not actor.is_up() or state != State.IN_PROGRESS:
					events.append_array(_check_end())
					return {"ok": true, "error": "", "events": events}
		movement_left_feet -= Attack.FEET_PER_SQUARE
		actor.position = cell
	if actor.position != segment_start:
		events.append({"type": "move", "actor": actor.id, "from": segment_start, "to": actor.position,
				"movement_left": movement_left_feet})
	_check_grapples(events)
	return {"ok": true, "error": "", "events": events}


func _can_opportunity_attack(enemy: Combatant, mover: Combatant, next_cell: Vector2i) -> bool:
	if enemy == mover or not enemy.is_up() or not enemy.is_hostile_to(mover) or not enemy.reaction_available:
		return false
	if enemy.is_incapacitated() or _first_attack(enemy, "melee").is_empty() or not enemy.effects_of("addled").is_empty():
		return false
	# Ágil (rato): não provoca ataques de oportunidade.
	if mover.has_trait("trait.agile"):
		return false
	var reach := _melee_reach(enemy)
	return Attack.grid_distance_feet(enemy.position, mover.position) <= reach \
			and Attack.grid_distance_feet(enemy.position, next_cell) > reach


func _melee_reach(unit: Combatant) -> int:
	var reach := 0
	for attack in unit.attacks:
		if attack["attack_type"] == "melee" and str(attack.get("unarmed", "")) in ["", "damage"]:
			reach = maxi(reach, int(attack.get("reach", Attack.MELEE_REACH_FEET)))
	return reach


## Caminho mais curto (casas, sem a de partida) com as mesmas regras de reachable_cells.
func _path_to(actor: Combatant, destination: Vector2i) -> Array[Vector2i]:
	var parents := {actor.position: actor.position}
	var frontier: Array[Vector2i] = [actor.position]
	while not frontier.is_empty() and not parents.has(destination):
		var cell: Vector2i = frontier.pop_front()
		for offset in NEIGHBORS:
			var next := cell + offset
			if not _in_bounds(next) or parents.has(next):
				continue
			var occupant := combatant_at(next)
			if occupant != null and occupant.is_hostile_to(actor):
				continue
			parents[next] = cell
			frontier.append(next)
	var path: Array[Vector2i] = []
	if not parents.has(destination):
		return path
	var step := destination
	while step != actor.position:
		path.push_front(step)
		step = parents[step]
	return path


func _do_attack(actor: Combatant, target: Combatant, attack_id: String) -> Dictionary:
	var attack := actor.get_attack(attack_id)
	var error := attack_error(actor, target, attack)
	if not error.is_empty():
		return _fail(error)
	_use_attack(actor)
	var events: Array[Dictionary] = []
	if str(attack.get("unarmed", "")) in ["grapple", "shove"]:
		_resolve_unarmed_option(actor, target, attack, events)
	else:
		_resolve_weapon_attack(actor, target, attack, events, false)
		if "light" in attack.get("properties", []) and attack["attack_type"] == "melee":
			light_weapon_used = str(attack["weapon_id"])
	events.append_array(_check_end())
	return {"ok": true, "error": "", "events": events}


## Gasta um ataque da ação de Ataque (a primeira vez consome a ação).
func _use_attack(actor: Combatant) -> void:
	if not attack_action_used:
		action_available = false
		attack_action_used = true
		attacks_left = attacks_per_action(actor)
	attacks_left = maxi(0, attacks_left - 1)


## Jogada de ataque com arma (ou desarmada), dano, efeitos de maestria e concentração.
## offhand = ataque extra da propriedade Leve (sem modificador no dano, salvo Duas Armas).
func _resolve_weapon_attack(actor: Combatant, target: Combatant, attack: Dictionary, events: Array[Dictionary],
		offhand: bool, drop_modifier: bool = false) -> Dictionary:
	var adv := attack_advantage(actor, target, attack)
	var bless := _bless_roll(actor)
	var bonus := int(attack["attack_bonus"]) + bless - 2 * _exhaustion(actor) + CombatFeatures.attack_bonus_from_target(actor, target) \
			+ CombatFeatures.attack_bonus(actor, attack)
	if actor == current() and not str(attack.get("weapon_id", "")).is_empty():
		var attacked: Array = once_per_turn.get("attacked_ids", [])
		attacked.append(target.id)
		once_per_turn["attacked_ids"] = attacked
		once_per_turn["last_weapon_attack"] = str(attack["id"])
	var critical_from := CombatFeatures.crit_min(actor, attack)
	var roll := Attack.roll_attack(_roller, bonus, target.effective_ac(), adv["state"], critical_from)
	roll = CombatFeatures.adjust_attack_roll(self, actor, roll, bonus, target.effective_ac(), adv["state"], critical_from, events)
	roll = CombatFeatures.defend_attack_roll(self, actor, target, roll, target.effective_ac(), events)
	CombatFeatures.extend_rage(actor)
	if roll["hit"] and not roll["critical"] and _adjacent(actor, target) \
			and (target.has_condition("paralyzed") or target.has_condition("unconscious")):
		roll["critical"] = true
		roll["auto_critical"] = true
	_consume_attack_effects(actor, target)
	CombatFeatures.consume_attack(actor, target)
	var damage_type := CombatFeatures.damage_type_for(actor, target, attack)
	var event := {"type": "attack", "actor": actor.id, "target": target.id, "attack": attack["name"],
			"roll": roll, "advantage_reasons": adv["advantage"], "disadvantage_reasons": adv["disadvantage"],
			"damage": 0, "damage_type": damage_type, "target_hp": target.hp, "bless": bless,
			"offhand": offhand}
	if not roll["hit"]:
		events.append(event)
		CombatFeatures.on_miss(self, actor, target)
		once_per_turn.erase("brutal_pending")
		if _has_mastery(actor, attack, "graze"):
			var graze := maxi(0, int(attack["ability_modifier"]))
			if graze > 0:
				var graze_event := {"type": "mastery", "actor": actor.id, "target": target.id, "mastery": "graze",
						"damage": graze, "damage_type": attack["damage_type"], "target_hp": target.hp}
				_apply_damage(target, Attack.apply_damage_modifiers(graze, str(attack["damage_type"]), target.all_resistances()),
						events, graze_event)
		return roll
	var raw := _weapon_damage(actor, attack, roll["critical"], offhand and not actor.has_feat("feat.two_weapon_fighting")
			or drop_modifier)
	var damage := Attack.apply_damage_modifiers(raw, damage_type, target.all_resistances())
	var extra := _mark_damage(actor, target, roll["critical"])
	var total := damage + int(extra["damage"])
	var labels := PackedStringArray()
	for bonus_damage: Dictionary in CombatFeatures.extra_damage(self, actor, target, attack, roll, adv["state"], events):
		var amount := Attack.apply_damage_modifiers(int(bonus_damage["amount"]), str(bonus_damage["type"]), target.all_resistances())
		total += amount
		labels.append("%s +%d" % [bonus_damage["label"], amount])
	total = CombatFeatures.incoming_attack_damage(self, target, actor, attack, total, events)
	event["damage"] = total
	event["extra"] = extra
	event["features"] = ", ".join(labels)
	event["resisted"] = damage < raw
	_apply_damage(target, total, events, event)
	CombatFeatures.after_mark_damage(self, actor, target, extra, events)
	# Atleta Notável (Campeão 3): após um crítico, move até metade do deslocamento sem provocar ataques.
	if roll["critical"] and actor.has_feature("feature.remarkable_athlete") and actor == current():
		movement_left_feet += int(effective_speed(actor) / 2)
		disengaged = true
	if state == State.IN_PROGRESS:
		_apply_mastery_on_hit(actor, target, attack, damage, events)
		CombatFeatures.after_hit(self, actor, target, attack, events)
		if total > 0:
			CombatFeatures.on_damaged_by_attack(self, target, actor, events)
	pending_after_hit.clear()
	return roll


## Dano da arma: dados (críticos dobram), Armas Grandes (1 e 2 viram 3) e Atacante Selvagem
## (uma vez por turno, rola duas vezes e fica com o maior).
func _weapon_damage(actor: Combatant, attack: Dictionary, critical: bool, drop_modifier: bool) -> int:
	var expression := DiceExpression.parse(str(attack["damage"]))
	if drop_modifier and int(attack["ability_modifier"]) > 0:
		expression.bonus -= int(attack["ability_modifier"])
	var great_weapon: bool = actor.has_feat("feat.great_weapon_fighting") and attack["two_handed"] \
			and attack["attack_type"] == "melee"
	var total := _roll_damage_dice(expression, critical, great_weapon)
	if not str(attack.get("weapon_id", "")).is_empty() and actor.has_feat("feat.savage_attacker") \
			and not once_per_turn.has("savage_attacker"):
		once_per_turn["savage_attacker"] = true
		total = maxi(total, _roll_damage_dice(expression, critical, great_weapon))
	return maxi(0, total)


func _roll_damage_dice(expression: DiceExpression, critical: bool, great_weapon: bool) -> int:
	var total := expression.bonus
	for value in _roller.roll_dice(expression.count * (2 if critical else 1), expression.sides):
		total += 3 if great_weapon and value <= 2 else value
	return total


func _has_mastery(actor: Combatant, attack: Dictionary, mastery: String) -> bool:
	return attack.get("mastery", "") == mastery and str(attack.get("weapon_id", "")) in actor.masteries


## Propriedades de Maestria depois de um acerto (aplicadas automaticamente quando possível).
func _apply_mastery_on_hit(actor: Combatant, target: Combatant, attack: Dictionary, dealt: int,
		events: Array[Dictionary]) -> void:
	var mastery := str(attack.get("mastery", ""))
	if mastery.is_empty() or not str(attack.get("weapon_id", "")) in actor.masteries:
		return
	# Mestre Tático (Guerreiro 9): troca a propriedade por Empurrar, Enfraquecer ou Lentidão.
	if actor.has_feature("feature.tactical_master") and str(actor.options.get("tactical_master", "")) in ["push", "sap", "slow"]:
		mastery = str(actor.options["tactical_master"])
	match mastery:
		"cleave":
			if attack["attack_type"] != "melee" or once_per_turn.has("cleave"):
				return
			for other in combatants:
				if other != target and other.is_up() and other.is_hostile_to(actor) and _adjacent(other, target) \
						and Attack.grid_distance_feet(actor.position, other.position) <= int(attack.get("reach", 5)):
					once_per_turn["cleave"] = true
					events.append({"type": "mastery", "actor": actor.id, "target": other.id, "mastery": "cleave",
							"damage": 0, "damage_type": attack["damage_type"], "target_hp": other.hp})
					_resolve_weapon_attack(actor, other, attack, events, false, true)
					return
		"push":
			if target.is_up() and Combatant.size_rank(target.size) <= Combatant.size_rank("large"):
				_push(actor, target, 2, events)
		"sap":
			if target.is_up():
				target.effects.append({"kind": "sapped", "source": actor.id, "spell": "Enfraquecer", "on": "turn_start",
						"actor": actor.id, "count": 1})
				events.append(_mastery_event(actor, target, "sap"))
		"slow":
			if target.is_up() and dealt > 0:
				target.effects.append({"kind": "slowed", "source": actor.id, "spell": "Lentidão", "value": 10,
						"on": "turn_start", "actor": actor.id, "count": 1})
				events.append(_mastery_event(actor, target, "slow"))
		"topple":
			if target.is_up() and not target.has_condition("prone"):
				var dc := 8 + int(attack["ability_modifier"]) + actor.proficiency_bonus
				var save := _roll_save(target, Ability.CONSTITUTION, dc)
				var topple := _mastery_event(actor, target, "topple")
				topple["save"] = {"natural": save.natural, "modifier": save.modifier, "total": save.total, "dc": dc,
						"success": save.success, "ability": "con"}
				events.append(topple)
				if not save.success:
					add_condition(target, "prone", actor.id, events)
		"vex":
			if target.is_up() and dealt > 0:
				target.effects.append({"kind": "vexed", "source": actor.id, "spell": "Atormentar", "on": "turn_end",
						"actor": actor.id, "count": 2 if actor == current() else 1})
				events.append(_mastery_event(actor, target, "vex"))


func _mastery_event(actor: Combatant, target: Combatant, mastery: String) -> Dictionary:
	return {"type": "mastery", "actor": actor.id, "target": target.id, "mastery": mastery, "damage": 0,
			"damage_type": "", "target_hp": target.hp}


## Agarrar ou Empurrar (Ataque Desarmado): teste de Força ou Destreza do alvo (o melhor) contra a CD.
func _resolve_unarmed_option(actor: Combatant, target: Combatant, attack: Dictionary, events: Array[Dictionary]) -> void:
	var ability := Ability.STRENGTH if target.save_bonus(Ability.STRENGTH) >= target.save_bonus(Ability.DEXTERITY) \
			else Ability.DEXTERITY
	var dc := int(attack["save_dc"])
	var save := _roll_save(target, ability, dc)
	var option := str(attack["unarmed"])
	events.append({"type": "unarmed", "actor": actor.id, "target": target.id, "option": option,
			"save": {"natural": save.natural, "modifier": save.modifier, "total": save.total, "dc": dc,
			"success": save.success, "ability": String(ability)}})
	if save.success:
		return
	if option == "grapple":
		add_condition(target, "grappled", actor.id, events, {"escape_dc": dc})
	else:
		add_condition(target, "prone", actor.id, events)


## Ataque extra da propriedade Leve (com outra arma Leve): ação bônus, ou parte da ação de Ataque
## com a maestria Talhar (uma vez por turno). Sem o modificador no dano, salvo Duas Armas.
func offhand_error(actor: Combatant, target: Combatant = null) -> String:
	if light_weapon_used.is_empty():
		return "Ataque primeiro com uma arma Leve"
	if offhand_used:
		return "O ataque extra já foi feito"
	var attack := offhand_attack(actor)
	if attack.is_empty():
		return "Sem outra arma Leve"
	if not _offhand_uses_nick(actor, attack) and not bonus_action_available:
		return "A ação bônus deste turno já foi usada"
	if target != null:
		return _target_error(actor, target, attack)
	return ""


## Ataque com a outra arma Leve (outra arma do mesmo tipo vale se houver duas no equipamento).
func offhand_attack(actor: Combatant) -> Dictionary:
	if actor.character == null:
		return {}
	for attack in actor.attacks:
		if attack["attack_type"] != "melee" or not "light" in attack.get("properties", []):
			continue
		var copies := actor.character.weapon_ids.count(str(attack["weapon_id"]))
		if str(attack["weapon_id"]) != light_weapon_used or copies >= 2:
			return attack
	return {}


func _offhand_uses_nick(actor: Combatant, attack: Dictionary) -> bool:
	if once_per_turn.has("nick"):
		return false
	var first := actor.get_attack(light_weapon_used)
	return _has_mastery(actor, attack, "nick") or (not first.is_empty() and _has_mastery(actor, first, "nick"))


func _do_offhand(actor: Combatant, target: Combatant) -> Dictionary:
	var error := offhand_error(actor, target)
	if not error.is_empty():
		return _fail(error)
	var attack := offhand_attack(actor)
	if _offhand_uses_nick(actor, attack):
		once_per_turn["nick"] = true
	else:
		bonus_action_available = false
	offhand_used = true
	var events: Array[Dictionary] = []
	_resolve_weapon_attack(actor, target, attack, events, true)
	events.append_array(_check_end())
	return {"ok": true, "error": "", "events": events}


## Disparada, Desengajar e Esquivar. use_bonus = como ação bônus (Ação Astuta do Ladino etc.).
func standard_action_error(actor: Combatant, action: String, use_bonus: bool = false) -> String:
	if actor.is_incapacitated():
		return "Incapacitado"
	if use_bonus:
		if not bonus_action_available:
			return "A ação bônus deste turno já foi usada"
		if not _bonus_standard_action_allowed(actor, action):
			return "Sem característica para fazer isso como ação bônus"
	elif not action_available:
		return "A ação deste turno já foi usada"
	return ""


## Características que permitem ações padrão como ação bônus (preenchidas pelas classes).
func _bonus_standard_action_allowed(actor: Combatant, action: String) -> bool:
	if actor.has_feature("feature.cunning_action") and action in ["dash", "disengage"]:
		return true
	return false


func _do_standard_action(actor: Combatant, action: String, use_bonus: bool) -> Dictionary:
	var error := standard_action_error(actor, action, use_bonus)
	if not error.is_empty():
		return _fail(error)
	if use_bonus:
		bonus_action_available = false
	else:
		action_available = false
	var event := {"type": "standard_action", "actor": actor.id, "action": action, "bonus": use_bonus}
	match action:
		"dash":
			movement_left_feet += effective_speed(actor)
			event["movement_left"] = movement_left_feet
		"disengage":
			disengaged = true
		"dodge":
			actor.effects.append({"kind": "dodging", "source": actor.id, "spell": "Esquivar", "on": "turn_start",
					"actor": actor.id, "count": 1})
	return {"ok": true, "error": "", "events": [event] as Array[Dictionary]}


# --- Condições ------------------------------------------------------------------------

## Aplica uma condição (sem duração própria: dura até ser encerrada por outra regra, salvo "extra").
## extra pode ter: on/actor/count (expiração), save_ends {ability, dc}, escape_dc.
func add_condition(target: Combatant, condition: String, source_id: String, events: Array[Dictionary],
		extra: Dictionary = {}) -> void:
	if target.has_condition(condition) and condition != "frightened":
		return
	if condition in target.condition_immunities:
		return
	if CombatFeatures.condition_blocked(self, target, condition, source_id):
		return
	var effect := {"kind": "condition", "condition": condition, "source": source_id, "spell": CONDITION_NAMES[condition],
			"on": "none", "actor": "", "count": 0}
	effect.merge(extra, true)
	target.effects.append(effect)
	events.append({"type": "condition", "actor": target.id, "condition": condition, "source": source_id})
	if condition in ["incapacitated", "stunned", "paralyzed", "unconscious", "petrified"]:
		_end_concentration(target, events, "incapacitado")
		CombatFeatures.revert_form(self, target, events, "incapacitado")


func remove_condition(target: Combatant, condition: String, events: Array[Dictionary]) -> void:
	var kept: Array[Dictionary] = []
	var removed := false
	for effect in target.effects:
		if effect["kind"] == "condition" and effect.get("condition") == condition:
			removed = true
			continue
		kept.append(effect)
	target.effects = kept
	if removed:
		events.append({"type": "condition_end", "actor": target.id, "condition": condition})


func _condition_source(unit: Combatant, condition: String) -> String:
	for effect in unit.effects:
		if effect["kind"] == "condition" and effect.get("condition") == condition:
			return str(effect["source"])
	return ""


## Agarrar acaba se o agarrador cair, ficar incapacitado ou se afastar além de 1,5 m.
func _check_grapples(events: Array[Dictionary]) -> void:
	for unit in combatants:
		for effect in unit.effects.duplicate():
			if effect["kind"] != "condition" or effect.get("condition") != "grappled":
				continue
			var grappler := get_combatant(str(effect["source"]))
			if grappler == null or not grappler.is_up() or grappler.is_incapacitated() or not _adjacent(grappler, unit):
				remove_condition(unit, "grappled", events)


## Deslocamento efetivo: lentidão, Exaustão e condições que zeram o deslocamento.
func effective_speed(unit: Combatant) -> int:
	for condition: String in ["grappled", "restrained", "paralyzed", "stunned", "unconscious", "petrified"]:
		if unit.has_condition(condition):
			return 0
	return maxi(0, unit.speed_feet - _slowed_feet(unit) - 5 * _exhaustion(unit))


func _exhaustion(unit: Combatant) -> int:
	return unit.character.exhaustion if unit.character != null else 0


## Fim do turno: quem tem condição com "save_ends" repete o teste para encerrá-la.
func _repeat_end_of_turn_saves(unit: Combatant, events: Array[Dictionary]) -> void:
	for effect in unit.effects.duplicate():
		if effect["kind"] != "condition" or not effect.has("save_ends"):
			continue
		var spec: Dictionary = effect["save_ends"]
		var save := _roll_save(unit, StringName(spec["ability"]), int(spec["dc"]))
		events.append({"type": "condition_save", "actor": unit.id, "condition": effect["condition"],
				"natural": save.natural, "modifier": save.modifier, "total": save.total, "dc": save.dc, "success": save.success})
		if save.success:
			remove_condition(unit, str(effect["condition"]), events)


## Ação para escapar de quem agarra: Atletismo (Força) ou Acrobacia (Destreza), o melhor, contra a CD.
func _try_escape_grapple(unit: Combatant, events: Array[Dictionary]) -> bool:
	for effect in unit.effects:
		if effect["kind"] == "condition" and effect.get("condition") == "grappled":
			var bonus := maxi(int(unit.modifiers.get(Ability.STRENGTH, 0)), int(unit.modifiers.get(Ability.DEXTERITY, 0)))
			var check := D20Test.roll(_roller, bonus, int(effect.get("escape_dc", 10)))
			action_available = false
			events.append({"type": "escape", "actor": unit.id, "natural": check.natural, "modifier": check.modifier,
					"total": check.total, "dc": check.dc, "success": check.success})
			if check.success:
				remove_condition(unit, "grappled", events)
			return true
	return false


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
	if actor.is_incapacitated():
		return _fail("Incapacitado")
	return {"ok": true, "error": "", "events": _finish(Outcome.FLED)}


func _end_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = [{"type": "turn_end", "actor": current().id}]
	_repeat_end_of_turn_saves(current(), events)
	CombatFeatures.on_turn_end(self, current(), events)
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
			# Depois da primeira rodada, sai o turno extra dos Reflexos de Ladrão.
			for unit in _reflex_turns:
				var first := turn_order.find(unit)
				var second := turn_order.find(unit, first + 1)
				if second >= 0:
					turn_order.remove_at(second)
			_reflex_turns.clear()
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
			attack_action_used = false
			attacks_left = 0
			disengaged = false
			light_weapon_used = ""
			offhand_used = false
			once_per_turn.clear()
			surge_action = false
			pending_after_hit.clear()
			unit.reaction_available = true
			movement_left_feet = effective_speed(unit)
			events.append({"type": "turn_start", "actor": unit.id, "round": round_number})
			CombatFeatures.on_turn_start(self, unit, events)
			if not unit.is_up():
				events.append_array(_check_end())
				if state != State.IN_PROGRESS:
					return events
				continue
			# Atordoar (Golpe Astuto): só mover ou agir; sem ação bônus.
			if not unit.effects_of("dazed").is_empty():
				bonus_action_available = false
			# Caído: levantar custa metade do deslocamento (se houver deslocamento).
			if unit.has_condition("prone") and movement_left_feet > 0:
				@warning_ignore("integer_division")
				movement_left_feet -= effective_speed(unit) / 2
				remove_condition(unit, "prone", events)
			if unit.is_incapacitated():
				action_available = false
				bonus_action_available = false
				movement_left_feet = 0
				unit.reaction_available = false
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
	if entry["resolution"] == "smite":
		return "Conjurada ao acertar um ataque corpo a corpo (opção no menu Ações)"
	if CombatFeatures.in_wild_shape(actor) and not actor.has_feature("feature.beast_spells"):
		return "Em Forma Selvagem não é possível conjurar"
	if spell.get("intervention", false) and not _free_cast_available(actor, spell):
		return "Intervenção Divina já usada"
	if _casting_time(spell) == "bonus_action":
		if not bonus_action_available:
			return "A ação bônus deste turno já foi usada"
	elif not action_available:
		return "A ação deste turno já foi usada"
	if actor.is_incapacitated():
		return "Incapacitado"
	if CombatFeatures.is_raging(actor):
		return "Em Fúria não é possível conjurar"
	if surge_action and _casting_time(spell) == "action":
		return "A ação do Surto de Ação não pode ser a ação de Magia"
	if int(entry["level"]) > 0 and not _free_cast_available(actor, spell):
		if actor.character == null or registry == null:
			return "Sem espaços de magia"
		if slot_used_this_turn:
			return "Só um espaço de magia pode ser gasto por turno"
		if Spellcasting.lowest_slot(actor.character, registry, int(entry["level"])) == 0:
			return "Sem espaços de magia disponíveis"
	return ""


## Tempo de conjuração: a Intervenção Divina é sempre uma ação de Magia.
func _casting_time(spell: Dictionary) -> String:
	return "action" if spell.get("intervention", false) else str(spell["entry"]["casting_time"])


## Uso gratuito (sem espaço) da magia ainda disponível: Iniciado em Magia ("mi.<chave>", um uso) ou
## recurso de classe ("res.<id>", como Golpe do Paladino e Inimigo Favorito).
func _free_cast_available(actor: Combatant, spell: Dictionary) -> bool:
	var resource := str(spell.get("free", ""))
	if resource.is_empty() or actor.character == null:
		return false
	if resource.begins_with("res."):
		return registry != null and ClassFeatures.remaining(actor.character, registry, resource.trim_prefix("res.")) > 0
	return actor.character.resource_spent(resource) == 0


func _spend_free_cast(actor: Combatant, spell: Dictionary) -> void:
	var resource := str(spell["free"])
	if resource.begins_with("res."):
		ClassFeatures.spend(actor.character, resource.trim_prefix("res."))
	else:
		actor.character.resources_spent[resource] = 1


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
	var reach := maxi(Attack.MELEE_REACH_FEET, int(entry["range_feet"])) \
			+ CombatFeatures.spell_range_bonus(actor, actor.get_spell(spell_id))
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
	var free_cast := spell_level > 0 and _free_cast_available(actor, spell)
	if free_cast:
		slot_level = spell_level
		_spend_free_cast(actor, spell)
	elif spell_level > 0:
		slot_level = Spellcasting.lowest_slot(actor.character, registry, spell_level)
		Spellcasting.spend_slot(actor.character, slot_level)
		slot_used_this_turn = true
	if _casting_time(spell) == "bonus_action":
		bonus_action_available = false
	else:
		action_available = false
	_cast_with_slot = spell_level > 0 and not free_cast
	_healed_others = false
	var target_ids: Array = targets.map(func(u: Combatant) -> String: return u.id)
	var events: Array[Dictionary] = [{"type": "cast", "actor": actor.id, "spell_id": spell_id, "spell": entry["name"],
			"level": spell_level, "slot_level": slot_level, "vfx": entry["vfx"], "color": entry["color"],
			"targets": target_ids, "cells": cells, "darts": _dart_count(entry, slot_level), "free": free_cast}]
	CombatFeatures.extend_rage(actor)
	if entry["concentration"]:
		_end_concentration(actor, events, "nova magia de concentração")
		actor.concentration = {"spell_id": spell_id, "name": entry["name"]}
	for target in targets:
		if state != State.IN_PROGRESS:
			break
		_resolve_spell_on(actor, spell, target, slot_level, events)
	CombatFeatures.after_cast(self, actor, slot_level, _cast_with_slot, _healed_others, events)
	events.append_array(_check_end())
	return {"ok": true, "error": "", "events": events}


func _dart_count(entry: Dictionary, slot_level: int) -> int:
	if int(entry["darts"]) == 0:
		return 0
	return int(entry["darts"]) + maxi(0, slot_level - int(entry["level"]))


func _resolve_spell_on(actor: Combatant, spell: Dictionary, target: Combatant, slot_level: int,
		events: Array[Dictionary]) -> void:
	var entry: Dictionary = spell["entry"]
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
			var roll := Attack.roll_attack(_roller, int(spell.get("attack", actor.spell_attack)) + bless, target.effective_ac(), adv["state"])
			_consume_attack_effects(actor, target)
			event["roll"] = roll
			event["bless"] = bless
			event["advantage_reasons"] = adv["advantage"]
			event["disadvantage_reasons"] = adv["disadvantage"]
			if roll["hit"]:
				var raw := Attack.roll_damage(damage_dice, _roller, roll["critical"]) + CombatFeatures.cantrip_bonus(actor, spell)
				damage = Attack.apply_damage_modifiers(raw, str(entry["damage_type"]), target.all_resistances())
				event["resisted"] = damage < raw
				var extra := _mark_damage(actor, target, roll["critical"])
				event["extra"] = extra
				damage += int(extra["damage"])
				affected = true
				event["mark_extra"] = extra
		"save":
			var save := _roll_save(target, StringName(entry["save_ability"]), int(spell.get("dc", actor.spell_dc)))
			event["save"] = {"natural": save.natural, "modifier": save.modifier, "total": save.total, "dc": save.dc,
					"success": save.success, "ability": entry["save_ability"]}
			var raw := damage_dice.roll(_roller) + CombatFeatures.cantrip_bonus(actor, spell)
			# Evasão (Ladino/Monge 7): em teste de Destreza para metade, nada com sucesso e metade com falha.
			var evasion: bool = entry["save_ability"] == "dex" and entry["half_on_save"] and not target.is_incapacitated() 					and (target.has_feature("feature.evasion_rogue") or target.has_feature("feature.evasion_monk"))
			if save.success:
				@warning_ignore("integer_division")
				raw = 0 if evasion else (raw / 2 if entry["half_on_save"] else 0)
			elif evasion:
				@warning_ignore("integer_division")
				raw = raw / 2
			affected = not save.success
			damage = Attack.apply_damage_modifiers(raw, str(entry["damage_type"]), target.all_resistances())
			event["resisted"] = damage < raw
		"auto":
			var darts := _dart_count(entry, slot_level)
			for i in darts:
				damage += Attack.apply_damage_modifiers(damage_dice.roll(_roller), str(entry["damage_type"]), target.all_resistances())
			event["darts"] = darts
		"heal":
			var heal_dice := Spellcasting.scaled_dice(entry, str(entry["heal"]), actor.character_level, slot_level)
			# Cura Suprema (Vida 17): dados de cura no máximo; Discípulo da Vida (Vida 3): +2 + círculo com espaço.
			var rolled := heal_dice.maximum() if actor.has_feature("feature.supreme_healing") else heal_dice.roll(_roller)
			var amount := maxi(0, rolled + int(spell.get("modifier", actor.spell_modifier)))
			if _cast_with_slot and actor.has_feature("feature.disciple_of_life"):
				amount += 2 + slot_level
			var before := target.hp
			target.hp = mini(target.max_hp, target.hp + amount)
			event["healed"] = target.hp - before
			if target != actor and target.hp > before:
				_healed_others = true
			event["target_hp"] = target.hp
		"buff":
			affected = true
	if affected:
		event["effect"] = _apply_spell_effect(actor, entry, target)
	event["damage"] = damage
	if damage > 0:
		_apply_damage(target, damage, events, event)
		CombatFeatures.after_spell_damage(self, actor, spell, events)
		if event.has("mark_extra"):
			CombatFeatures.after_mark_damage(self, actor, target, event["mark_extra"], events)
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
			# Matador de Inimigos (Patrulheiro 20): o dado da Marca do Caçador vira d10.
			if entry["id"] == "spell.hunters_mark" and actor.has_feature("feature.foe_slayer"):
				value = "1d10"
			target.effects.append({"kind": "marked", "source": actor.id, "spell": entry["name"], "spell_id": entry["id"],
					"value": value, "damage_type": entry["damage_type"], "on": "concentration"})
			return "marcado (+%s de dano)%s" % [value, CombatFeatures.hunters_lore(actor, target, entry)]
		"no_reactions":
			target.effects.append({"kind": "addled", "source": actor.id, "spell": entry["name"], "on": "turn_start",
					"actor": target.id, "count": 1})
			return "sem ataques de oportunidade até o próximo turno"
		"poisoned":
			if "poisoned" in target.condition_immunities:
				return "imune a Envenenado"
			target.effects.append({"kind": "condition", "condition": "poisoned", "source": actor.id, "spell": "Envenenado",
					"on": "turn_end", "actor": actor.id, "count": 2 if actor == current() else 1})
			return "Envenenado até o fim do próximo turno de %s" % actor.name
		"warded":
			target.effects.append({"kind": "warded", "source": actor.id, "spell": entry["name"], "on": "concentration"})
			return "protegido contra aberrações, celestiais, elementais, feéricos, corruptores e mortos-vivos"
	return ""


## Dano em um alvo: PV, queda e teste de concentração. "event" (o que causou o dano) entra antes.
func _apply_damage(target: Combatant, damage: int, events: Array[Dictionary], event: Dictionary) -> void:
	var absorbed := mini(target.temp_hp, damage)
	if absorbed > 0:
		target.temp_hp -= absorbed
		event["temp_absorbed"] = absorbed
	target.hp = maxi(0, target.hp - (damage - absorbed))
	event["target_hp"] = target.hp
	events.append(event)
	if damage > 0:
		for effect in target.effects.duplicate():
			if effect.get("ends_on_damage", false):
				remove_condition(target, str(effect.get("condition", "")), events)
	if not target.is_up() and CombatFeatures.on_zero_hp(self, target, events):
		event["target_hp"] = target.hp
	if not target.is_up():
		events.append({"type": "down", "actor": target.id, "dead": target.team == Combatant.Team.ENEMY})
		CombatFeatures.on_unit_down(self, target)
		_end_concentration(target, events, "caiu")
	elif damage > 0 and not target.concentration.is_empty() and not CombatFeatures.keeps_concentration(target):
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
## Teste de resistência do alvo: Bênção, Exaustão, Esquivar (vantagem em Destreza), Contido
## (desvantagem em Destreza) e falha automática em Força/Destreza para Atordoado, Paralisado,
## Inconsciente e Petrificado.
func _roll_save(target: Combatant, ability: StringName, dc: int, condition: String = "") -> D20Test:
	var advantage := 0
	var disadvantage := 0
	if ability == Ability.DEXTERITY:
		if not target.effects_of("dodging").is_empty() and not target.is_incapacitated():
			advantage += 1
		if target.has_condition("restrained"):
			disadvantage += 1
	advantage += CombatFeatures.save_advantage(target, ability)
	disadvantage += CombatFeatures.save_disadvantage(target)
	var test := D20Test.roll(_roller, target.save_bonus(ability) + _bless_roll(target) - 2 * _exhaustion(target)
			+ CombatFeatures.save_bonus(self, target, ability), dc,
			D20Test.resolve_advantage(advantage, disadvantage))
	if ability in [Ability.STRENGTH, Ability.DEXTERITY]:
		for blocking: String in ["stunned", "paralyzed", "unconscious", "petrified"]:
			if target.has_condition(blocking):
				test.success = false
				return test
	return CombatFeatures.after_save(self, target, ability, test, _save_events, condition)


## 1d4 da Bênção para ataques e resistências (0 sem Bênção).
func _bless_roll(unit: Combatant) -> int:
	var blessings := unit.effects_of("blessed")
	if blessings.is_empty():
		return 0
	return DiceExpression.parse(str(blessings[0]["value"])).roll(_roller)


## Zombaria some depois do próximo ataque de quem a sofreu; Raio Guiador, do próximo ataque contra o alvo.
func _consume_attack_effects(actor: Combatant, target: Combatant) -> void:
	_remove_effects(actor, "mocked")
	_remove_effects(actor, "sapped")
	var kept: Array[Dictionary] = []
	for effect in target.effects:
		if not (effect["kind"] == "vexed" and effect["source"] == actor.id):
			kept.append(effect)
	target.effects = kept
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
			return {"damage": Attack.apply_damage_modifiers(raw, str(effect["damage_type"]), target.all_resistances()),
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
		if attack["attack_type"] == attack_type and str(attack.get("unarmed", "")) in ["", "damage"]:
			return attack
	return {}


func _ai_try_attack(actor: Combatant, target: Combatant, melee: Dictionary, ranged: Dictionary,
		events: Array[Dictionary]) -> bool:
	if not can_attack(actor) or state != State.IN_PROGRESS:
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
