extends "res://tests/base_test.gd"
## Testes contra a morte (SRD 5.2.1, pp. 17-18): personagem a 0 PV fica Inconsciente e rola no início do turno;
## dano a 0 PV conta falha (crítico, duas); dano massivo mata; curar levanta; estabilizar (Medicina CD 10) e Poupar os
## Moribundos; Revivificar só em quem morreu há até 1 minuto; inimigos inteligentes às vezes finalizam caídos.

const ENGINE_TESTS := preload("res://tests/combat/test_combat_engine.gd")

var _engine: Object


func _e() -> Object:
	if _engine == null:
		_engine = ENGINE_TESTS.new()
		_engine.tree = tree
	return _engine


## Guerreiro (herói) e clérigo de nível 5 (aliado, com espaço de 3º círculo) contra 2 goblins.
## Iniciativa: herói 20, aliado 19, goblins 1.
func _setup(dice: Array[int] = [], enemies: Array[Combatant] = []) -> CombatManager:
	var reg: ContentRegistry = _e()._registry()
	var manager := CombatManager.new()
	manager.registry = reg
	var cleric: CharacterData = _e()._hero("class.cleric")
	for i in 4:
		Progression.level_up(cleric, reg)
	cleric.current_hp = CharacterSheet.build(cleric, reg).max_hp
	var party: Array[Combatant] = [Combatant.from_character(_e()._hero("class.fighter"), reg),
			Combatant.from_character(cleric, reg)]
	var foes: Array[Combatant] = enemies if not enemies.is_empty() else _e()._goblins(2)
	var all_dice: Array[int] = [20, 19]
	for f in foes:
		all_dice.append(1)
	all_dice.append_array(dice)
	manager.setup(party, foes, Vector2i(12, 8), true, DiceRoller.scripted(all_dice))
	manager.start()
	return manager


func _hero(m: CombatManager) -> Combatant:
	return m.combatants[0]


func _ally(m: CombatManager) -> Combatant:
	return m.combatants[1]


func _goblin(m: CombatManager) -> Combatant:
	return m.living(Combatant.Team.ENEMY)[0]


func _hit(m: CombatManager, target: Combatant, damage: int, critical: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	m._apply_damage(target, damage, events, {"type": "attack", "actor": _goblin(m).id, "target": target.id,
			"roll": {"critical": critical, "hit": true}})
	return events


func _down(m: CombatManager, unit: Combatant) -> void:
	_hit(m, unit, unit.hp)


func _of(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


# --- Cair a 0 PV -------------------------------------------------------------------------------

func test_character_at_zero_is_unconscious_not_dead() -> void:
	var m := _setup()
	var hero := _hero(m)
	var events := _hit(m, hero, hero.hp)
	assert_eq(hero.hp, 0, "PV zerados")
	assert_true(hero.has_condition("unconscious"), "Inconsciente a 0 PV")
	assert_true(hero.is_downed() and not hero.dead, "Caído, mas vivo")
	assert_true(not bool(_of(events, "down")[0]["dead"]), "O aviso de queda diz que não morreu")


func test_monster_dies_at_zero() -> void:
	var m := _setup()
	var goblin := _goblin(m)
	var events := _hit(m, goblin, goblin.hp)
	assert_true(bool(_of(events, "down")[0]["dead"]), "Monstro morre a 0 PV")
	assert_true(not goblin.is_downed(), "Monstro não rola testes contra a morte")


func test_massive_damage_kills_instantly() -> void:
	var m := _setup()
	var hero := _hero(m)
	_hit(m, hero, hero.hp + hero.max_hp)
	assert_true(hero.dead, "Dano restante igual aos PV máximos: morte instantânea")
	assert_true(not hero.is_downed(), "Morto não está caído-vivo")


# --- Testes contra a morte ------------------------------------------------------------------------

func test_death_save_success_failure_and_natural_one() -> void:
	var m := _setup([10, 9, 1])
	var hero := _hero(m)
	_down(m, hero)
	var events: Array[Dictionary] = []
	m.roll_death_save(hero, events)
	assert_eq(hero.death_successes, 1, "10 é sucesso")
	m.roll_death_save(hero, events)
	assert_eq(hero.death_failures, 1, "9 é falha")
	m.roll_death_save(hero, events)
	assert_true(hero.dead, "1 natural conta duas falhas: 3 falhas, morte")
	assert_eq(_of(events, "death_save").size(), 3, "Cada teste aparece no registro")


func test_three_successes_stabilize() -> void:
	var m := _setup([12, 15, 18])
	var hero := _hero(m)
	_down(m, hero)
	var events: Array[Dictionary] = []
	for i in 3:
		m.roll_death_save(hero, events)
	assert_true(hero.stable, "Três sucessos: estável")
	assert_true(not hero.dead and hero.hp == 0, "Estável continua a 0 PV, inconsciente")


func test_natural_twenty_wakes_with_one_hp() -> void:
	var m := _setup([20])
	var hero := _hero(m)
	_down(m, hero)
	var events: Array[Dictionary] = []
	m.roll_death_save(hero, events)
	assert_eq(hero.hp, 1, "20 natural: volta com 1 PV")
	assert_true(not hero.has_condition("unconscious"), "Não está mais inconsciente")
	assert_eq(hero.death_successes + hero.death_failures, 0, "Contagem zerada")


func test_downed_unit_rolls_at_turn_start_and_skips_the_turn() -> void:
	var m := _setup([5])
	var hero := _hero(m)
	_down(m, hero)
	m._turn_index = m.turn_order.find(hero) - 1
	var events := m._advance_turn()
	assert_eq(_of(events, "death_save").size(), 1, "Rola no início do turno")
	assert_eq(hero.death_failures, 1, "5 é falha")
	assert_true(m.current() != hero, "Caído não age: o turno passa")


func test_natural_twenty_at_turn_start_gives_the_turn() -> void:
	var m := _setup([20])
	var hero := _hero(m)
	_down(m, hero)
	m._turn_index = m.turn_order.find(hero) - 1
	m._advance_turn()
	assert_eq(m.current(), hero, "Com o 20 natural, levanta e joga o turno")
	assert_true(m.action_available, "Tem a ação")


func test_stable_unit_does_not_roll() -> void:
	var m := _setup()
	var hero := _hero(m)
	_down(m, hero)
	hero.stable = true
	m._turn_index = m.turn_order.find(hero) - 1
	var events := m._advance_turn()
	assert_eq(_of(events, "death_save").size(), 0, "Estável não rola")


# --- Dano e cura em quem está caído -----------------------------------------------------------------

func test_damage_while_down_adds_failures_and_critical_adds_two() -> void:
	var m := _setup()
	var hero := _hero(m)
	_down(m, hero)
	_hit(m, hero, 2)
	assert_eq(hero.death_failures, 1, "Dano a 0 PV: uma falha")
	_hit(m, hero, 2, true)
	assert_true(hero.dead, "Crítico: duas falhas (3 no total), morte")


func test_damage_equal_to_max_while_down_kills() -> void:
	var m := _setup()
	var hero := _hero(m)
	_down(m, hero)
	_hit(m, hero, hero.max_hp)
	assert_true(hero.dead, "Dano a 0 PV igual aos PV máximos: morte")


func test_stable_unit_hit_rolls_again() -> void:
	var m := _setup()
	var hero := _hero(m)
	_down(m, hero)
	hero.stable = true
	_hit(m, hero, 1)
	assert_true(not hero.stable, "Levou dano: deixa de estar estável")
	assert_eq(hero.death_failures, 1, "E conta uma falha")


func test_healing_wakes_and_resets() -> void:
	var m := _setup()
	var hero := _hero(m)
	_down(m, hero)
	hero.death_failures = 2
	var events: Array[Dictionary] = []
	m.heal_unit(hero, 5, events)
	assert_eq(hero.hp, 5, "Curado")
	assert_true(not hero.has_condition("unconscious") and hero.is_up(), "Acorda")
	assert_eq(hero.death_failures, 0, "Falhas zeradas")


func test_dead_cannot_be_healed() -> void:
	var m := _setup()
	var hero := _hero(m)
	_hit(m, hero, hero.hp + hero.max_hp)
	var events: Array[Dictionary] = []
	m.heal_unit(hero, 5, events)
	assert_eq(hero.hp, 0, "Cura comum não levanta morto")


# --- Estabilizar e Poupar os Moribundos ---------------------------------------------------------------

func test_stabilize_with_medicine_check() -> void:
	var m := _setup([15])
	var hero := _hero(m)
	var ally := _ally(m)
	_down(m, hero)
	ally.position = hero.position + Vector2i(1, 0)
	m._turn_index = m.turn_order.find(ally)
	m.action_available = true
	var result := m.submit({"type": "stabilize", "actor": ally.id, "target": hero.id})
	assert_true(result["ok"], "Estabilizar aceito: %s" % result.get("error", ""))
	assert_true(hero.stable, "Medicina 15 + bônus contra CD 10: estável")
	assert_true(not m.action_available, "Gasta a ação")


func test_stabilize_fails_on_low_roll_and_needs_adjacency() -> void:
	var m := _setup([1])
	var hero := _hero(m)
	var ally := _ally(m)
	_down(m, hero)
	ally.position = hero.position + Vector2i(3, 0)
	m._turn_index = m.turn_order.find(ally)
	m.action_available = true
	assert_true(not m.submit({"type": "stabilize", "actor": ally.id, "target": hero.id})["ok"], "Longe: recusado")
	ally.position = hero.position + Vector2i(1, 0)
	var result := m.submit({"type": "stabilize", "actor": ally.id, "target": hero.id})
	assert_true(result["ok"], "Encostado: tenta")
	assert_true(not hero.stable, "1 natural: falha no teste")


func test_spare_the_dying_stabilizes_without_roll() -> void:
	var m := _setup()
	var hero := _hero(m)
	var ally := _ally(m)
	var entry: Dictionary = _e()._registry().get_entry("spell", "spell.spare_the_dying")
	assert_true(not entry.is_empty(), "Poupar os Moribundos existe nos dados")
	ally.spells.append({"id": "spell.spare_the_dying", "name": entry["name"], "level": 0, "entry": entry,
			"dc": ally.spell_dc, "attack": ally.spell_attack, "modifier": ally.spell_modifier, "free": ""})
	_down(m, hero)
	ally.position = hero.position + Vector2i(2, 0)
	m._turn_index = m.turn_order.find(ally)
	m.action_available = true
	var result := m.submit({"type": "cast", "actor": ally.id, "spell_id": "spell.spare_the_dying", "target": hero.id})
	assert_true(result["ok"], "Conjuração aceita: %s" % result.get("error", ""))
	assert_true(hero.stable, "Estável sem rolar")
	assert_true(not m.spell_target_error(ally, "spell.spare_the_dying", ally).is_empty(), "Não serve em quem está de pé")


# --- Revivificar ---------------------------------------------------------------------------------

func test_revivify_only_for_recent_death() -> void:
	var m := _setup()
	var hero := _hero(m)
	var ally := _ally(m)
	var entry: Dictionary = _e()._registry().get_entry("spell", "spell.revivify")
	ally.spells.append({"id": "spell.revivify", "name": entry["name"], "level": 3, "entry": entry,
			"dc": ally.spell_dc, "attack": ally.spell_attack, "modifier": ally.spell_modifier, "free": ""})
	ally.position = hero.position + Vector2i(1, 0)
	_down(m, hero)
	assert_true(not m.spell_target_error(ally, "spell.revivify", hero).is_empty(), "Caído vivo: Revivificar não serve")
	_hit(m, hero, hero.max_hp)
	assert_true(hero.dead, "Morreu")
	assert_eq(m.spell_target_error(ally, "spell.revivify", hero), "", "Morto agora: serve")
	m.round_number += 11
	assert_true(not m.spell_target_error(ally, "spell.revivify", hero).is_empty(), "Mais de 1 minuto: não serve")


# --- Inimigos que finalizam caídos ------------------------------------------------------------------

func test_smart_enemy_sometimes_finishes_the_downed() -> void:
	var boss: Combatant = _e()._monster("monster.goblin_boss")
	assert_true(boss.finishes_downed, "Garra-Rubra finaliza caídos")
	# d100: 30 (finaliza, até 50), depois 80 (não finaliza).
	var m := _setup([30, 80], [boss])
	var hero := _hero(m)
	var ally := _ally(m)
	_down(m, hero)
	hero.position = boss.position + Vector2i(-1, 0)
	ally.position = boss.position + Vector2i(0, 1)
	assert_eq(m._choose_target(boss), hero, "Com 30 em d100: ataca o caído ao lado")
	assert_eq(m._choose_target(boss), ally, "Com 80: ataca quem está de pé")


func test_common_goblin_ignores_the_downed() -> void:
	var m := _setup()
	var hero := _hero(m)
	var ally := _ally(m)
	var goblin := _goblin(m)
	assert_true(not goblin.finishes_downed, "Goblin comum não finaliza")
	_down(m, hero)
	hero.position = goblin.position + Vector2i(-1, 0)
	ally.position = goblin.position + Vector2i(0, 3)
	assert_eq(m._choose_target(goblin), ally, "Ignora o caído")


# --- Depois do combate --------------------------------------------------------------------------------

func test_after_victory_downed_wake_and_dead_stay_dead() -> void:
	var m := _setup()
	var hero := _hero(m)
	var ally := _ally(m)
	_down(m, hero)
	_hit(m, ally, ally.hp + ally.max_hp)
	m.state = CombatManager.State.FINISHED
	m.outcome = CombatManager.Outcome.VICTORY
	m.apply_results_to_party()
	assert_eq(hero.character.current_hp, 1, "Caído vivo: acorda com 1 PV")
	assert_true(not hero.character.dead, "E está vivo")
	assert_true(ally.character.dead, "Morto continua morto")
	assert_eq(ally.character.current_hp, 0, "Com 0 PV")
