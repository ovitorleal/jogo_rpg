extends "res://tests/base_test.gd"
## Morte persistente fora do combate: o morto continua morto ao salvar e carregar, não se cura no descanso, não segue
## o grupo, e o primeiro companheiro vivo assume o mapa enquanto o herói está morto. Saves antigos: todos vivos.

const ENGINE_TESTS := preload("res://tests/combat/test_combat_engine.gd")

var _engine: Object
var party: Node


func _e() -> Object:
	if _engine == null:
		_engine = ENGINE_TESTS.new()
		_engine.tree = tree
	return _engine


func _begin() -> Array[CharacterData]:
	party = tree.root.get_node("PartyManager")
	var hero: CharacterData = _e()._hero("class.fighter")
	var cleric: CharacterData = _e()._hero("class.cleric")
	cleric.id = "companion.test_cleric"
	party.start_new_party(hero)
	party.members.append(cleric)
	return [hero, cleric]


func _end() -> void:
	party.clear()


func test_dead_survives_save_round_trip_and_old_saves_read_alive() -> void:
	var hero: CharacterData = _e()._hero("class.fighter")
	hero.dead = true
	hero.current_hp = 0
	var back: Array = CharacterData.from_dict(hero.to_dict())
	assert_true(back[0] != null and (back[0] as CharacterData).dead, "Morto continua morto depois de salvar e carregar")
	var old := hero.to_dict()
	old.erase("dead")
	var legacy: Array = CharacterData.from_dict(old)
	assert_true(legacy[0] != null and not (legacy[0] as CharacterData).dead, "Save antigo sem o campo: vivo")


func test_first_living_member_leads_while_the_hero_is_dead() -> void:
	var both := _begin()
	assert_eq(party.get_leader(), both[0], "Com todos vivos, o herói lidera")
	both[0].dead = true
	assert_eq(party.get_leader(), both[1], "Herói morto: o primeiro companheiro vivo assume")
	both[0].dead = false
	assert_eq(party.get_leader(), both[0], "Ressuscitado, o herói volta a liderar")
	_end()


func test_long_rest_does_not_revive_the_dead() -> void:
	var both := _begin()
	both[1].dead = true
	both[1].current_hp = 0
	assert_eq(Rest.long_rest(both[1], _e()._registry()), 0, "Descanso não cura morto")
	assert_eq(both[1].current_hp, 0, "Continua com 0 PV")
	_end()
