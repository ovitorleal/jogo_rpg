extends Control
## Cena de combate (apresentação). Monta o combate a partir de um encontro, envia os
## comandos do jogador ao CombatManager, executa os turnos dos inimigos e mostra o resultado.
## Clique numa casa azul para mover; clique num inimigo marcado para atacar com o ataque escolhido.

## Pausa entre ações dos inimigos, só para leitura; não altera resultados. 0 nos testes.
@export var ai_delay: float = 0.3
## Animações de movimento, ataque, dano e queda. Desligadas nos testes; não alteram resultados.
@export var animations_enabled: bool = true
## Segundos por casa ao andar.
const STEP_TIME := 0.11

var manager := CombatManager.new()
var encounter: Dictionary = {}

var _encounter_id: String = ""
var _party: Array[CharacterData] = []
var _roller: DiceRoller = null
var _configured := false
var _busy := false
var _selected_attack_id: String = ""
var _log_lines: PackedStringArray = []
var _inventory: Inventory = null
## Recompensas do encontro aplicadas na vitória (texto exibido no resultado).
var loot_lines: Array[String] = []

@onready var _board: CombatBoard = %Board
@onready var _title: Label = %Title
@onready var _order: RichTextLabel = %TurnOrder
@onready var _log: RichTextLabel = %Log
@onready var _status: Label = %Status
@onready var _attack_option: OptionButton = %AttackOption
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _flee_button: Button = %FleeButton
@onready var _potion_button: Button = %PotionButton
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _result_button: Button = %ResultButton


## Configura antes de entrar na árvore (testes). Sem isso, usa o encontro pendente
## do ExplorationManager e o grupo do PartyManager.
func setup(encounter_id: String, party: Array[CharacterData], roller: DiceRoller = null,
		inventory: Inventory = null) -> void:
	_inventory = inventory
	_encounter_id = encounter_id
	_party = party
	_roller = roller
	_configured = true


func _ready() -> void:
	if not _configured:
		_encounter_id = ExplorationManager.pending_encounter_id
		_party = PartyManager.members.duplicate()
	if _roller == null:
		_roller = DiceRoller.new()
	_result_panel.visible = false
	_board.cell_clicked.connect(_on_cell_clicked)
	_attack_option.item_selected.connect(_on_attack_selected)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_flee_button.pressed.connect(_on_flee_pressed)
	_potion_button.pressed.connect(press_potion)
	_result_button.pressed.connect(_on_result_pressed)

	var error := _build_combat()
	if not error.is_empty():
		_show_setup_error(error)
		return
	_add_log(encounter.get("intro_text", ""))
	_board.sync_tokens()
	_busy = true
	await _present(manager.start())
	_busy = false
	_refresh()
	_run_enemy_turns()


func get_manager() -> CombatManager:
	return manager


func is_busy() -> bool:
	return _busy


## Mesmo efeito de clicar na casa (usado também pelos testes).
func click_cell(cell: Vector2i) -> Dictionary:
	if _busy or not manager.is_party_turn():
		return {"ok": false, "error": "Aguarde o seu turno", "events": []}
	var actor := manager.current()
	var occupant := manager.combatant_at(cell)
	var result: Dictionary
	if occupant != null and occupant.is_hostile_to(actor):
		result = manager.submit({"type": "attack", "actor": actor.id, "target": occupant.id,
				"attack_id": _selected_attack_id})
	elif occupant == null:
		result = manager.submit({"type": "move", "actor": actor.id, "to": cell})
	else:
		result = {"ok": false, "error": "Casa ocupada", "events": []}
	_after_command(result)
	return result


func select_attack(attack_id: String) -> void:
	_selected_attack_id = attack_id
	_refresh()


func press_end_turn() -> void:
	_on_end_turn_pressed()


func press_flee() -> void:
	_on_flee_pressed()


func press_potion() -> void:
	if _busy or not manager.is_party_turn():
		return
	_after_command(manager.submit({"type": "use_item", "actor": manager.current().id, "item_id": Inventory.POTION}))


# --- Montagem -----------------------------------------------------------------

func _build_combat() -> String:
	var registry: ContentRegistry = Content.registry
	encounter = registry.get_entry("encounter", _encounter_id)
	if encounter.is_empty():
		return "Encontro desconhecido: '%s'" % _encounter_id
	var party_units: Array[Combatant] = []
	for c in _party:
		if c.current_hp > 0:
			party_units.append(Combatant.from_character(c, registry))
	if party_units.is_empty():
		return "Nenhum personagem em condições de lutar."
	var enemies: Array[Combatant] = []
	for group: Dictionary in encounter["enemies"]:
		var monster := registry.get_entry("monster", group["monster_id"])
		for i in int(group["count"]):
			enemies.append(Combatant.from_monster(monster, i + 1, int(group["count"])))
	manager.inventory = PartyManager.inventory if not _configured or _inventory == null else _inventory
	manager.registry = registry
	manager.setup(party_units, enemies, Vector2i(int(encounter["arena_width"]), int(encounter["arena_height"])),
			bool(encounter["flee_allowed"]), _roller)
	_board.manager = manager
	_title.text = encounter.get("name", "Combate")
	return ""


func _show_setup_error(error: String) -> void:
	push_error("[Combate] %s" % error)
	_result_label.text = error
	_result_button.text = "Voltar"
	_result_panel.visible = true


# --- Fluxo --------------------------------------------------------------------

func _after_command(result: Dictionary) -> void:
	if not result["ok"]:
		_status.text = result["error"]
		return
	_busy = true
	_refresh()
	await _present(result["events"])
	_busy = false
	_refresh()
	_run_enemy_turns()


func _run_enemy_turns() -> void:
	if _busy:
		return
	_busy = true
	while manager.state == CombatManager.State.IN_PROGRESS and not manager.is_party_turn():
		_refresh()
		if ai_delay > 0.0:
			await get_tree().create_timer(ai_delay).timeout
		await _present(manager.run_enemy_turn())
	_busy = false
	_refresh()
	if manager.state == CombatManager.State.FINISHED:
		_show_result()


## Mostra os eventos em ordem: registro e, se ligadas, animações. O estado já foi resolvido
## pelo CombatManager; aqui só se apresenta o que aconteceu.
func _present(events: Array) -> void:
	for event: Dictionary in events:
		_add_log(CombatLog.describe(event, manager))
		if animations_enabled and is_inside_tree():
			await _animate(event)
	_board.sync_tokens(not animations_enabled)
	_board.refresh()


func _animate(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"move":
			var token := _board.token_for(manager.get_combatant(event["actor"]))
			var from: Vector2i = event["from"]
			var to: Vector2i = event["to"]
			var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
			await token.walk_to(_board.cell_feet(to), STEP_TIME * steps)
		"attack":
			var attacker := _board.token_for(manager.get_combatant(event["actor"]))
			var target_unit := manager.get_combatant(event["target"])
			var target := _board.token_for(target_unit)
			await attacker.attack_towards(target.position)
			var roll: Dictionary = event["roll"]
			if roll["hit"]:
				target.hurt(int(event["target_hp"]))
				if roll["critical"]:
					_board.float_text("CRÍTICO! %d" % event["damage"], target.position, Color8(255, 226, 90), true)
				else:
					_board.float_text(str(event["damage"]), target.position, Color8(255, 240, 230))
			else:
				_board.float_text("Errou", target.position, Color8(190, 200, 230))
			await get_tree().create_timer(0.2).timeout
		"down":
			var unit := manager.get_combatant(event["actor"])
			await _board.token_for(unit).fall(bool(event["dead"]))
		"turn_start":
			_refresh_highlights_only()


func _show_result() -> void:
	manager.apply_results_to_party(Content.registry)
	match manager.outcome:
		CombatManager.Outcome.VICTORY:
			loot_lines = manager.inventory.grant(int(encounter.get("reward_gold", 0)), encounter.get("reward_items", []),
					Content.registry) if manager.inventory != null else []
			_result_label.text = "Vitória!\n+%d XP" % manager.total_xp()
			if not loot_lines.is_empty():
				_result_label.text += "\n" + ", ".join(loot_lines)
			for message in manager.level_up_messages:
				_result_label.text += "\n" + message
			_result_button.text = "Continuar"
		CombatManager.Outcome.DEFEAT:
			_result_label.text = "Derrota.\nSeu grupo caiu em combate."
			_result_button.text = "Voltar ao título"
		CombatManager.Outcome.FLED:
			_result_label.text = "Você fugiu do combate."
			_result_button.text = "Continuar"
	_result_panel.visible = true
	_result_button.grab_focus()


func _on_result_pressed() -> void:
	if manager.state != CombatManager.State.FINISHED:
		get_tree().change_scene_to_file(ExplorationManager.TITLE_SCENE)
		return
	ExplorationManager.finish_encounter(manager.outcome, manager.total_xp() if manager.outcome == CombatManager.Outcome.VICTORY else 0)


func _on_cell_clicked(cell: Vector2i) -> void:
	click_cell(cell)


func _on_attack_selected(index: int) -> void:
	select_attack(str(_attack_option.get_item_metadata(index)))


func _on_end_turn_pressed() -> void:
	if _busy or not manager.is_party_turn():
		return
	_after_command(manager.submit({"type": "end_turn", "actor": manager.current().id}))


func _on_flee_pressed() -> void:
	if _busy or not manager.is_party_turn():
		return
	_after_command(manager.submit({"type": "flee", "actor": manager.current().id}))


# --- Exibição -----------------------------------------------------------------

func _add_events(events: Array) -> void:
	for event: Dictionary in events:
		_add_log(CombatLog.describe(event, manager))


func _add_log(line: String) -> void:
	if line.is_empty():
		return
	_log_lines.append(line)
	_log.text = "\n".join(_log_lines)
	_log.scroll_to_line(_log.get_line_count() - 1)


func _refresh() -> void:
	var actor := manager.current()
	var party_turn := manager.is_party_turn() and not _busy
	_refresh_attack_options(actor if party_turn else null)

	_refresh_highlights(actor, party_turn)
	_board.sync_tokens(not _busy)

	var lines := PackedStringArray()
	for unit in manager.turn_order:
		var marker := "> " if unit == actor else "   "
		var state := "" if unit.is_up() else (" (morto)" if unit.team == Combatant.Team.ENEMY else " (caído)")
		var text := "%s%d  %s  %d/%d PV%s" % [marker, unit.initiative, unit.name, unit.hp, unit.max_hp, state]
		lines.append("[b]%s[/b]" % text if unit == actor else text)
	_order.text = "\n".join(lines)

	_end_turn_button.disabled = not party_turn
	_flee_button.disabled = not party_turn or not manager.flee_allowed or not manager.action_available
	var potions := manager.inventory.count(Inventory.POTION) if manager.inventory != null else 0
	_potion_button.text = "Poção (%d)" % potions
	_potion_button.disabled = not party_turn or potions <= 0 or not manager.bonus_action_available \
			or actor.hp >= actor.max_hp
	_attack_option.disabled = not party_turn
	if manager.state == CombatManager.State.FINISHED:
		_status.text = "Combate encerrado."
	elif party_turn:
		_status.text = "Seu turno: %s · Movimento %d pés · Ação %s · Ação bônus %s" % [actor.name,
				manager.movement_left_feet, "disponível" if manager.action_available else "usada",
				"disponível" if manager.bonus_action_available else "usada"]
	elif actor != null:
		_status.text = "Turno de %s..." % actor.name


func _refresh_highlights(actor: Combatant, party_turn: bool) -> void:
	_board.reachable = manager.reachable_cells(actor) if party_turn else {}
	_board.targets.clear()
	if party_turn:
		var attack := actor.get_attack(_selected_attack_id)
		for unit in manager.combatants:
			if manager.attack_error(actor, unit, attack).is_empty():
				_board.targets.append(unit)
	_board.refresh()


func _refresh_highlights_only() -> void:
	_board.reachable = {}
	_board.targets.clear()
	_board.refresh()


func _refresh_attack_options(actor: Combatant) -> void:
	_attack_option.clear()
	if actor == null:
		return
	for attack in actor.attacks:
		var reach := "%d/%d pés" % [attack["range_normal"], attack["range_long"]] if attack["attack_type"] == "ranged" \
				else "%d pés" % attack["reach"]
		_attack_option.add_item("%s %s · %s · %s" % [attack["name"], Ability.format_modifier(attack["attack_bonus"]),
				attack["damage"], reach])
		_attack_option.set_item_metadata(_attack_option.item_count - 1, attack["id"])
	if actor.get_attack(_selected_attack_id).is_empty():
		_selected_attack_id = actor.attacks[0]["id"]
	for i in _attack_option.item_count:
		if _attack_option.get_item_metadata(i) == _selected_attack_id:
			_attack_option.select(i)
