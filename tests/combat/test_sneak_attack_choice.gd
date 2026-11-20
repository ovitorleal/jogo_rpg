extends "res://tests/base_test.gd"
## Ataque Furtivo opcional: com interactive_choices, o ataque do jogador que acerta e pode usar o Ataque Furtivo
## pausa e espera o comando "choose" (SRD 5.2.1: o dano extra é opcional). Sem a opção, tudo segue automático.

const ENGINE_TESTS := preload("res://tests/combat/test_combat_engine.gd")

var _engine: Object


func _e() -> Object:
	if _engine == null:
		_engine = ENGINE_TESTS.new()
		_engine.tree = tree
	return _engine


## Ladino nível 1 e um guerreiro aliado encostado no goblin; o ladino age primeiro.
## dice = dados depois da iniciativa (ataque, dano da arma, dano furtivo...).
func _setup(dice: Array[int], interactive: bool = true) -> CombatManager:
	var reg: ContentRegistry = _e()._registry()
	var manager := CombatManager.new()
	manager.registry = reg
	manager.interactive_choices = interactive
	var rogue: CharacterData = _e()._hero("class.rogue")
	var party: Array[Combatant] = [Combatant.from_character(rogue, reg),
			Combatant.from_character(_e()._hero("class.fighter"), reg)]
	var all_dice: Array[int] = [20, 2, 1, 1]
	all_dice.append_array(dice)
	manager.setup(party, _e()._goblins(2), Vector2i(12, 8), true, DiceRoller.scripted(all_dice))
	manager.start()
	var hero := _rogue(manager)
	var goblin := _goblin(manager)
	goblin.position = hero.position + Vector2i(1, 0)
	_ally(manager).position = goblin.position + Vector2i(0, 1)
	return manager


func _rogue(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[0]


func _ally(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.PARTY)[1]


func _goblin(manager: CombatManager) -> Combatant:
	return manager.living(Combatant.Team.ENEMY)[0]


func _attack(manager: CombatManager, attack_id: String = "item.shortsword") -> Dictionary:
	return manager.submit({"type": "attack", "actor": _rogue(manager).id, "target": _goblin(manager).id, "attack_id": attack_id})


func _of(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


func test_hit_pauses_and_asks() -> void:
	var manager := _setup([15, 3, 4])
	var goblin := _goblin(manager)
	var hp := goblin.hp
	var result := _attack(manager)
	assert_true(result["ok"], "Ataque aceito: %s" % result.get("error", ""))
	var choices := _of(result, "choice")
	assert_eq(choices.size(), 1, "Acertou com Ataque Furtivo possível: pergunta")
	assert_eq(str(choices[0]["kind"]), "sneak_attack", "A pergunta é sobre o Ataque Furtivo")
	assert_eq(str(choices[0]["dice"]), "1d6", "Mostra os dados do nível 1")
	assert_true(not bool(choices[0]["critical"]), "Não foi crítico")
	assert_eq(_of(result, "attack").size(), 0, "O dano ainda não foi aplicado")
	assert_eq(goblin.hp, hp, "Goblin intacto enquanto o jogador decide")
	assert_true(manager.has_pending_choice(), "Escolha pendente")


func test_other_commands_wait_for_the_choice() -> void:
	var manager := _setup([15, 3, 4])
	_attack(manager)
	var move := manager.submit({"type": "move", "actor": _rogue(manager).id, "to": _rogue(manager).position + Vector2i(0, 1)})
	assert_true(not move["ok"], "Com a escolha pendente, outro comando é recusado")
	var end := manager.submit({"type": "end_turn", "actor": _rogue(manager).id})
	assert_true(not end["ok"], "Nem encerrar o turno")


func test_choose_yes_adds_sneak_damage() -> void:
	var manager := _setup([15, 3, 4])
	var hero := _rogue(manager)
	var goblin := _goblin(manager)
	_attack(manager)
	var result := manager.submit({"type": "choose", "actor": hero.id, "value": true})
	assert_true(result["ok"], "Escolha aceita: %s" % result.get("error", ""))
	var attack: Dictionary = _of(result, "attack")[0]
	assert_true(str(attack["features"]).contains("Ataque Furtivo"), "Ataque Furtivo aplicado")
	assert_eq(attack["damage"], 3 + hero.modifiers[Ability.DEXTERITY] + 4, "Arma + Destreza + 1d6 furtivo")
	assert_eq(goblin.hp, maxi(0, goblin.max_hp - int(attack["damage"])), "Dano aplicado ao goblin")
	assert_true(not manager.has_pending_choice(), "Escolha resolvida")


func test_choose_no_keeps_it_for_the_next_attack() -> void:
	# Ataque com a espada curta (acerta), recusa; ataque extra com a adaga (acerta) pergunta de novo e usa.
	# A espada curta tem Atormentar: o ataque seguinte tem vantagem (dois d20).
	var manager := _setup([15, 3, 15, 15, 2, 5])
	var hero := _rogue(manager)
	_attack(manager)
	var first := manager.submit({"type": "choose", "actor": hero.id, "value": false})
	var hit: Dictionary = _of(first, "attack")[0]
	assert_true(not str(hit["features"]).contains("Ataque Furtivo"), "Recusado: sem Ataque Furtivo")
	assert_eq(hit["damage"], 3 + hero.modifiers[Ability.DEXTERITY], "Só a arma")
	var extra := manager.submit({"type": "offhand", "actor": hero.id, "target": _goblin(manager).id})
	assert_true(extra["ok"], "Ataque extra aceito: %s" % extra.get("error", ""))
	assert_eq(_of(extra, "choice").size(), 1, "Ainda disponível no turno: pergunta de novo")
	var second := manager.submit({"type": "choose", "actor": hero.id, "value": true})
	var offhand: Dictionary = _of(second, "attack")[0]
	assert_true(str(offhand["features"]).contains("Ataque Furtivo"), "Usado no ataque extra")
	assert_eq(offhand["damage"], 2 + 5, "Ataque extra sem modificador + 1d6 furtivo")


func test_critical_is_shown_and_doubles_the_dice() -> void:
	var manager := _setup([20, 3, 3, 4, 5])
	var hero := _rogue(manager)
	var result := _attack(manager)
	assert_true(bool(_of(result, "choice")[0]["critical"]), "A pergunta avisa que foi crítico")
	var done := manager.submit({"type": "choose", "actor": hero.id, "value": true})
	var attack: Dictionary = _of(done, "attack")[0]
	assert_eq(attack["damage"], 3 + 3 + hero.modifiers[Ability.DEXTERITY] + 4 + 5, "Crítico: 2d6 da arma + 2d6 furtivo")


func test_miss_does_not_ask() -> void:
	var manager := _setup([2])
	var result := _attack(manager)
	assert_eq(_of(result, "choice").size(), 0, "Errou: nada a perguntar")
	assert_eq(_of(result, "attack").size(), 1, "O erro é registrado normalmente")
	assert_true(not manager.has_pending_choice(), "Sem escolha pendente")


func test_choose_without_pending_choice_fails() -> void:
	var manager := _setup([15, 3, 4])
	var result := manager.submit({"type": "choose", "actor": _rogue(manager).id, "value": true})
	assert_true(not result["ok"], "Sem pergunta aberta, choose é recusado")


func test_combat_scene_asks_with_a_popup() -> void:
	var reg: ContentRegistry = _e()._registry()
	var rogue: CharacterData = _e()._hero("class.rogue")
	var fighter: CharacterData = _e()._hero("class.fighter")
	var scene: Control = (load("res://scenes/combat/combat_scene.tscn") as PackedScene).instantiate()
	scene.ai_delay = 0.0
	scene.animations_enabled = false
	# Iniciativa: ladino 20, guerreiro 2, goblin 1. Depois: ataque 15, espada curta 3, furtivo 4.
	scene.setup("encounter.ruin_goblin", [rogue, fighter] as Array[CharacterData], DiceRoller.scripted([20, 2, 1, 15, 3, 4]))
	tree.root.add_child(scene)
	await tree.process_frame
	var manager: CombatManager = scene.get_manager()
	assert_true(manager.interactive_choices, "A tela liga as perguntas")
	var hero: Combatant = manager.living(Combatant.Team.PARTY)[0]
	var ally: Combatant = manager.living(Combatant.Team.PARTY)[1]
	var goblin: Combatant = manager.living(Combatant.Team.ENEMY)[0]
	assert_eq(manager.current(), hero, "Turno do ladino")
	hero.position = Vector2i(3, 3)
	goblin.position = Vector2i(4, 3)
	ally.position = Vector2i(4, 4)
	var hp := goblin.hp
	scene.select_attack("item.shortsword")
	scene.click_cell(goblin.position)
	await tree.process_frame
	assert_true(scene.is_choice_open(), "Acertou: o pop-up do Ataque Furtivo aparece")
	assert_eq(goblin.hp, hp, "O dano espera a resposta")
	assert_true(scene.is_busy(), "O tabuleiro fica travado enquanto pergunta")
	scene.answer_choice(true)
	await tree.process_frame
	await tree.process_frame
	assert_true(not scene.is_choice_open(), "O pop-up fecha")
	assert_eq(goblin.hp, maxi(0, hp - (3 + hero.modifiers[Ability.DEXTERITY] + 4)), "Dano com o Ataque Furtivo")
	var log_text := (scene.get_node("%Log") as RichTextLabel).get_parsed_text()
	assert_true(log_text.contains("Ataque Furtivo +4"), "O registro mostra o dano do Ataque Furtivo")
	scene.queue_free()
	await tree.process_frame


func test_without_interactive_choices_it_stays_automatic() -> void:
	var manager := _setup([15, 3, 4], false)
	var hero := _rogue(manager)
	var result := _attack(manager)
	assert_eq(_of(result, "choice").size(), 0, "Sem interactive_choices não pergunta (testes e IA)")
	var attack: Dictionary = _of(result, "attack")[0]
	assert_true(str(attack["features"]).contains("Ataque Furtivo"), "Usa automaticamente, como antes")
	assert_eq(attack["damage"], 3 + hero.modifiers[Ability.DEXTERITY] + 4, "Mesmo dano de antes")
