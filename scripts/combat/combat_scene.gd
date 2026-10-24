extends Control
## Cena de combate (apresentação). Monta o combate a partir de um encontro, envia os
## comandos do jogador ao CombatManager, executa os turnos dos inimigos e mostra o resultado.
## Clique numa casa azul para mover; clique num inimigo marcado para atacar com o ataque escolhido.
## Magias aparecem no mesmo menu ("✦"): clique no alvo marcado ou, em cone/cubo, numa casa vizinha
## (laranja) para escolher a direção.

## Pausa entre ações dos inimigos, só para leitura; não altera resultados. 0 nos testes.
@export var ai_delay: float = 0.3
## Animações de movimento, ataque, dano e queda. Desligadas nos testes; não alteram resultados.
@export var animations_enabled: bool = true
## Segundos por casa ao andar.
const STEP_TIME := 0.11
const SPELL_PREFIX := "spell:"
const OFFHAND_ID := "offhand"
const FEATURE_PREFIX := "feature:"
const FEATURE_BASE := 100
const TOGGLE_BASE := 200
## Itens do menu "Ações": [comando, rótulo, como ação bônus?].
const STANDARD_ACTIONS := [["dash", "Disparada (ação)", false], ["disengage", "Desengajar (ação)", false],
		["dodge", "Esquivar (ação)", false], ["dash", "Disparada (ação bônus)", true],
		["disengage", "Desengajar (ação bônus)", true]]
const SCHOOL_LEVEL := ["truque", "1º", "2º", "3º", "4º", "5º", "6º", "7º", "8º", "9º"]

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
var _actions_button: MenuButton
var _menu_features: Array[Dictionary] = []
var _menu_toggles: Array[Dictionary] = []

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
	_actions_button = MenuButton.new()
	_actions_button.name = "ActionsButton"
	_actions_button.text = "Ações ▾"
	_actions_button.flat = false
	_actions_button.get_popup().id_pressed.connect(_on_action_menu)
	_end_turn_button.get_parent().add_child(_actions_button)
	_end_turn_button.get_parent().move_child(_actions_button, _end_turn_button.get_index())

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
	if _selected_attack_id.begins_with(FEATURE_PREFIX):
		if occupant != null and occupant.is_hostile_to(actor):
			result = manager.submit({"type": "feature", "actor": actor.id, "feature": _selected_attack_id.trim_prefix(FEATURE_PREFIX),
					"target": occupant.id})
			_selected_attack_id = ""
		elif occupant == null:
			result = manager.submit({"type": "move", "actor": actor.id, "to": cell})
		else:
			result = {"ok": false, "error": "Escolha um inimigo", "events": []}
		_after_command(result)
		return result
	if _selected_attack_id == OFFHAND_ID:
		if occupant != null and occupant.is_hostile_to(actor):
			result = manager.submit({"type": "offhand", "actor": actor.id, "target": occupant.id})
		elif occupant == null:
			result = manager.submit({"type": "move", "actor": actor.id, "to": cell})
		else:
			result = {"ok": false, "error": "Casa ocupada", "events": []}
		_after_command(result)
		return result
	var spell_id := selected_spell_id()
	if not spell_id.is_empty():
		var entry: Dictionary = actor.get_spell(spell_id)["entry"]
		if CombatManager.is_area_spell(entry):
			result = manager.submit({"type": "cast", "actor": actor.id, "spell_id": spell_id, "cell": cell})
		elif occupant != null and (occupant.is_hostile_to(actor) == (entry["target"] == "enemy")):
			result = manager.submit({"type": "cast", "actor": actor.id, "spell_id": spell_id, "target": occupant.id})
		elif occupant == null:
			result = manager.submit({"type": "move", "actor": actor.id, "to": cell})
		else:
			result = {"ok": false, "error": "Alvo inválido para %s" % entry["name"], "events": []}
		_after_command(result)
		return result
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


## Disparada, Desengajar ou Esquivar (use_bonus = como ação bônus, ex.: Ação Astuta).
func press_standard_action(action: String, use_bonus: bool = false) -> Dictionary:
	if _busy or not manager.is_party_turn():
		return {"ok": false, "error": "Aguarde o seu turno", "events": []}
	var result := manager.submit({"type": action, "actor": manager.current().id, "bonus": use_bonus})
	_after_command(result)
	return result


func _on_action_menu(id: int) -> void:
	if id >= TOGGLE_BASE:
		var toggle: Dictionary = _menu_toggles[id - TOGGLE_BASE]
		manager.submit({"type": "option", "actor": manager.current().id, "key": toggle["key"], "value": toggle["value"]})
		_refresh()
		return
	if id >= FEATURE_BASE:
		var action: Dictionary = _menu_features[id - FEATURE_BASE]
		if action["target"] == "enemy":
			select_attack(FEATURE_PREFIX + str(action["id"]))
			_status.text = "%s: clique num inimigo marcado." % action["name"]
			return
		press_feature(str(action["id"]))
		return
	var entry: Array = STANDARD_ACTIONS[id]
	press_standard_action(entry[0], entry[2])


## Usa uma característica de classe (Fúria, Retomar o Fôlego...), com alvo se precisar.
func press_feature(feature_id: String, target_id: String = "") -> Dictionary:
	if _busy or not manager.is_party_turn():
		return {"ok": false, "error": "Aguarde o seu turno", "events": []}
	var result := manager.submit({"type": "feature", "actor": manager.current().id, "feature": feature_id, "target": target_id})
	_after_command(result)
	return result


func select_spell(spell_id: String) -> void:
	select_attack(SPELL_PREFIX + spell_id)


## Magia escolhida no menu ("" se for um ataque).
func selected_spell_id() -> String:
	return _selected_attack_id.trim_prefix(SPELL_PREFIX) if _selected_attack_id.begins_with(SPELL_PREFIX) else ""


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
		"cast":
			await _animate_cast(event)
		"spell_effect":
			var target_token := _board.token_for(manager.get_combatant(event["target"]))
			if int(event["damage"]) > 0:
				target_token.hurt(int(event["target_hp"]))
				_board.float_text(str(event["damage"]), target_token.position, Color8(255, 240, 230))
			elif int(event["healed"]) > 0:
				target_token.refresh(false)
				_board.float_text("+%d" % event["healed"], target_token.position, Color8(140, 255, 150))
			elif event.has("roll") and not event["roll"]["hit"]:
				_board.float_text("Errou", target_token.position, Color8(190, 200, 230))
			elif event.has("save") and event["save"]["success"]:
				_board.float_text("Resistiu", target_token.position, Color8(190, 200, 230))
			elif not str(event["effect"]).is_empty():
				_board.float_text(event["spell"], target_token.position, Color8(200, 180, 255))
			await get_tree().create_timer(0.15).timeout
		"feature":
			var feature_unit := manager.get_combatant(str(event.get("target", event["actor"])))
			var feature_token := _board.token_for(feature_unit)
			if event.has("vfx"):
				var colors := {"rage": "#ff4a3a", "heal": "#7aff9a", "aura": "#9ad0ff", "fear": "#b04aff"}
				var style: String = {"rage": "aura", "fear": "mock"}.get(event["vfx"], event["vfx"])
				var fx := SpellVfx.create(style, Color(colors.get(event["vfx"], "#ffffff")), feature_token.position + Vector2(0, -14),
						[feature_token.position + Vector2(0, -12)] as Array[Vector2], [] as Array[Rect2])
				_board.add_child(fx)
				await fx.finished
			if int(event.get("damage", 0)) > 0 and event.has("target"):
				feature_token.hurt(int(feature_unit.hp))
				_board.float_text(str(event["damage"]), feature_token.position, Color8(255, 240, 230))
			elif int(event.get("healed", 0)) > 0:
				feature_token.refresh(false)
				_board.float_text("+%d" % event["healed"], feature_token.position, Color8(140, 255, 150))
			await get_tree().create_timer(0.1).timeout
		"mastery", "unarmed", "condition", "standard_action":
			var shown := manager.get_combatant(str(event.get("target", event.get("actor", ""))))
			if shown != null:
				var label := CombatLog.short_label(event)
				if not label.is_empty():
					_board.float_text(label, _board.token_for(shown).position, Color8(255, 210, 140))
			await get_tree().create_timer(0.12).timeout
		"opportunity":
			_board.float_text("Ataque de oportunidade!", _board.token_for(manager.get_combatant(event["actor"])).position,
					Color8(255, 170, 120))
			await get_tree().create_timer(0.15).timeout
		"pushed":
			var pushed_token := _board.token_for(manager.get_combatant(event["actor"]))
			await pushed_token.walk_to(_board.cell_feet(event["to"]), STEP_TIME)
		"concentration_end":
			var token_end := _board.token_for(manager.get_combatant(event["actor"]))
			_board.float_text("Concentração encerrada", token_end.position, Color8(200, 180, 255))
		"turn_start":
			_refresh_highlights_only()


## Pose de conjuração e efeito visual da magia, das mãos do conjurador até os alvos.
func _animate_cast(event: Dictionary) -> void:
	var caster := _board.token_for(manager.get_combatant(event["actor"]))
	var aim := caster.position + Vector2(24, 0)
	var target_points: Array[Vector2] = []
	for id: String in event["targets"]:
		var token := _board.token_for(manager.get_combatant(id))
		if token != null:
			target_points.append(token.position + Vector2(0, -12))
	var cells: Array[Rect2] = []
	for cell: Vector2i in event["cells"]:
		cells.append(Rect2(_board.cell_to_local(cell), Vector2(CombatBoard.CELL, CombatBoard.CELL)))
	if not target_points.is_empty():
		aim = target_points[0]
	elif not cells.is_empty():
		aim = cells[0].get_center()
	# Magia em si mesmo: sem golpe na direção do alvo.
	if aim.distance_to(caster.position + Vector2(0, -12)) > 4.0:
		caster.attack_towards(aim)
		await get_tree().create_timer(0.15).timeout
	var fx := SpellVfx.create(str(event["vfx"]), Color(str(event["color"])), caster.position + Vector2(0, -14),
			target_points, cells, int(event.get("darts", 3)))
	_board.add_child(fx)
	await fx.finished


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
		var conditions := PackedStringArray()
		for effect in unit.effects:
			if effect["kind"] == "condition":
				conditions.append(CombatManager.CONDITION_NAMES[effect["condition"]])
		if unit.temp_hp > 0:
			conditions.append("+%d PV temp." % unit.temp_hp)
		if not conditions.is_empty() and unit.is_up():
			state += " [%s]" % ", ".join(conditions)
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
	_actions_button.disabled = not party_turn
	var popup := _actions_button.get_popup()
	popup.clear()
	if party_turn:
		for i in STANDARD_ACTIONS.size():
			var entry: Array = STANDARD_ACTIONS[i]
			var error := manager.standard_action_error(actor, entry[0], entry[2])
			if entry[2] and error.contains("característica"):
				continue
			popup.add_item(entry[1], i)
			popup.set_item_disabled(popup.get_item_index(i), not error.is_empty())
		_menu_features = CombatFeatures.actions(manager, actor)
		if not _menu_features.is_empty():
			popup.add_separator("Classe")
		for i in _menu_features.size():
			var action: Dictionary = _menu_features[i]
			popup.add_item(str(action["name"]), FEATURE_BASE + i)
			var index := popup.get_item_index(FEATURE_BASE + i)
			popup.set_item_disabled(index, not str(action["error"]).is_empty())
			popup.set_item_tooltip(index, str(action["error"]))
		_menu_toggles = CombatFeatures.toggles(actor)
		if not _menu_toggles.is_empty():
			popup.add_separator("Opções")
		for i in _menu_toggles.size():
			popup.add_check_item(str(_menu_toggles[i]["name"]), TOGGLE_BASE + i)
			popup.set_item_checked(popup.get_item_index(TOGGLE_BASE + i), bool(_menu_toggles[i]["checked"]))
		if not actor.concentration.is_empty():
			pass
	if manager.state == CombatManager.State.FINISHED:
		_status.text = "Combate encerrado."
	elif party_turn:
		var action_text := "✓" if manager.action_available else "usada"
		if manager.attack_action_used and manager.attacks_left > 0:
			action_text = "%d ataque(s)" % manager.attacks_left
		_status.text = "%s · Mov. %d pés · Ação %s · Bônus %s · Reação %s" % [actor.name,
				manager.movement_left_feet, action_text, "✓" if manager.bonus_action_available else "usada",
				"✓" if actor.reaction_available else "usada"]
		if actor.character != null and not actor.spells.is_empty():
			var slots := Spellcasting.slots_text(actor.character, Content.registry)
			if not slots.is_empty():
				_status.text += " · Espaços: %s" % slots
			if not actor.concentration.is_empty():
				_status.text += " · Concentração: %s" % actor.concentration["name"]
	elif actor != null:
		_status.text = "Turno de %s..." % actor.name


func _refresh_highlights(actor: Combatant, party_turn: bool) -> void:
	_board.reachable = manager.reachable_cells(actor) if party_turn else {}
	_board.targets.clear()
	_board.aim_cells.clear()
	if party_turn:
		var spell_id := selected_spell_id()
		if not spell_id.is_empty() and not actor.get_spell(spell_id).is_empty():
			var entry: Dictionary = actor.get_spell(spell_id)["entry"]
			if CombatManager.is_area_spell(entry):
				if manager.spell_error(actor, spell_id).is_empty():
					for offset in CombatManager.NEIGHBORS:
						var cell: Vector2i = actor.position + offset
						if cell.x >= 0 and cell.y >= 0 and cell.x < manager.arena_size.x and cell.y < manager.arena_size.y:
							_board.aim_cells.append(cell)
			else:
				for unit in manager.combatants:
					if manager.spell_target_error(actor, spell_id, unit).is_empty():
						_board.targets.append(unit)
		elif _selected_attack_id == OFFHAND_ID:
			for unit in manager.combatants:
				if manager.offhand_error(actor, unit).is_empty():
					_board.targets.append(unit)
		elif _selected_attack_id.begins_with(FEATURE_PREFIX):
			for unit in manager.combatants:
				var reach := 5
				if unit.is_up() and unit.is_hostile_to(actor) and Attack.grid_distance_feet(actor.position, unit.position) <= reach:
					_board.targets.append(unit)
		else:
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
	var offhand := manager.offhand_attack(actor)
	if not offhand.is_empty() and not manager.light_weapon_used.is_empty():
		_attack_option.add_item("↺ Ataque extra (Leve): %s · %s" % [offhand["name"], offhand["damage"]])
		var offhand_index := _attack_option.item_count - 1
		_attack_option.set_item_metadata(offhand_index, OFFHAND_ID)
		var offhand_error := manager.offhand_error(actor)
		_attack_option.set_item_disabled(offhand_index, not offhand_error.is_empty())
		_attack_option.set_item_tooltip(offhand_index, offhand_error)
	for spell in actor.spells:
		var entry: Dictionary = spell["entry"]
		var detail := ""
		match str(entry["resolution"]):
			"spell_attack":
				detail = "%s · %s" % [Ability.format_modifier(actor.spell_attack), entry["damage"]]
			"save":
				detail = "CD %d · %s" % [actor.spell_dc, entry["damage"]]
			"auto":
				detail = "%d× %s" % [entry["darts"], entry["damage"]]
			"heal":
				detail = "cura %s%s" % [entry["heal"], Ability.format_modifier(actor.spell_modifier)]
			"buff":
				match str(entry["effect"]):
					"ac_bonus":
						detail = "+%s CA" % entry["effect_value"]
					"blessed":
						detail = "+%s em ataques e resistências" % entry["effect_value"]
					"marked":
						detail = "+%s de dano" % entry["effect_value"]
					_:
						detail = "efeito"
		var reach := "área %d pés" % entry["area_feet"] if CombatManager.is_area_spell(entry) \
				else ("toque" if int(entry["range_feet"]) <= 5 else "%d pés" % entry["range_feet"])
		var timing := " · bônus" if entry["casting_time"] == "bonus_action" else ""
		_attack_option.add_item("✦ %s (%s) · %s · %s%s" % [entry["name"], SCHOOL_LEVEL[int(entry["level"])], detail,
				reach, timing])
		var index := _attack_option.item_count - 1
		_attack_option.set_item_metadata(index, SPELL_PREFIX + str(spell["id"]))
		var error := manager.spell_error(actor, str(spell["id"]))
		_attack_option.set_item_disabled(index, not error.is_empty())
		_attack_option.set_item_tooltip(index, error if not error.is_empty() else str(entry["description"]))
	var spell_selected := selected_spell_id()
	var valid_spell := not spell_selected.is_empty() and not actor.get_spell(spell_selected).is_empty() \
			and manager.spell_error(actor, spell_selected).is_empty()
	if _selected_attack_id == OFFHAND_ID and manager.offhand_error(actor).is_empty():
		valid_spell = true
	if _selected_attack_id.begins_with(FEATURE_PREFIX):
		valid_spell = true
	if actor.get_attack(_selected_attack_id).is_empty() and not valid_spell:
		_selected_attack_id = actor.attacks[0]["id"]
	for i in _attack_option.item_count:
		if _attack_option.get_item_metadata(i) == _selected_attack_id:
			_attack_option.select(i)
