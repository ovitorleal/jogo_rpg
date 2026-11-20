extends "res://tests/base_test.gd"
## Testes contra a morte na tela de combate: o caído aparece na ordem de iniciativa com a contagem, e dá para
## clicar nele para Poupar os Moribundos ou para Estabilizar (modo do menu de ações).

const ENGINE_TESTS := preload("res://tests/combat/test_combat_engine.gd")

var _engine: Object


func _e() -> Object:
	if _engine == null:
		_engine = ENGINE_TESTS.new()
		_engine.tree = tree
	return _engine


## Clériga (com Poupar os Moribundos) age primeiro; guerreiro em segundo; um goblin. Depois: `dice`.
func _open(dice: Array[int]) -> Control:
	var cleric: CharacterData = _e()._hero("class.cleric")
	if not "spell.spare_the_dying" in cleric.cantrips:
		cleric.cantrips.append("spell.spare_the_dying")
	var fighter: CharacterData = _e()._hero("class.fighter")
	var all_dice: Array[int] = [20, 2, 1]
	all_dice.append_array(dice)
	var scene: Control = (load("res://scenes/combat/combat_scene.tscn") as PackedScene).instantiate()
	scene.ai_delay = 0.0
	scene.animations_enabled = false
	scene.setup("encounter.ruin_goblin", [cleric, fighter] as Array[CharacterData], DiceRoller.scripted(all_dice))
	tree.root.add_child(scene)
	await tree.process_frame
	return scene


func _down_fighter(scene: Control) -> Combatant:
	var manager: CombatManager = scene.get_manager()
	var fighter: Combatant = manager.combatants[1]
	var events: Array[Dictionary] = []
	manager._apply_damage(fighter, fighter.hp, events, {"type": "attack", "actor": "x", "target": fighter.id})
	var cleric: Combatant = manager.combatants[0]
	cleric.position = Vector2i(3, 3)
	fighter.position = Vector2i(4, 3)
	manager.living(Combatant.Team.ENEMY)[0].position = Vector2i(9, 6)
	scene.select_attack("")
	return fighter


func test_turn_order_shows_the_death_save_count() -> void:
	var scene := await _open([])
	var fighter := _down_fighter(scene)
	fighter.death_failures = 2
	scene.select_attack("")
	var order := (scene.get_node("%TurnOrder") as RichTextLabel).get_parsed_text()
	assert_true(order.contains("caído: 0 sucessos, 2 falhas"), "Ordem de iniciativa mostra a contagem: %s" % order)
	scene.queue_free()
	await tree.process_frame


func test_click_on_the_fallen_ally_casts_spare_the_dying() -> void:
	var scene := await _open([])
	var fighter := _down_fighter(scene)
	scene.select_attack("spell:spell.spare_the_dying")
	var result: Dictionary = scene.click_cell(fighter.position)
	await tree.process_frame
	assert_true(result["ok"], "Clique no caído conjura: %s" % result.get("error", ""))
	assert_true(fighter.stable, "Estável")
	scene.queue_free()
	await tree.process_frame


func test_stabilize_mode_from_the_actions_menu() -> void:
	var scene := await _open([15])
	var fighter := _down_fighter(scene)
	scene._on_action_menu(scene.STABILIZE_MENU)
	var result: Dictionary = scene.click_cell(fighter.position)
	await tree.process_frame
	assert_true(result["ok"], "Estabilizar pelo clique: %s" % result.get("error", ""))
	assert_true(fighter.stable, "Medicina 15 + bônus contra CD 10: estável")
	var log_text := (scene.get_node("%Log") as RichTextLabel).get_parsed_text()
	assert_true(log_text.contains("tenta estabilizar"), "O registro mostra a tentativa")
	scene.queue_free()
	await tree.process_frame
