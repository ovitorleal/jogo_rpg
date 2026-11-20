extends "res://tests/base_test.gd"
## Posição salva segura (onda livros-de-arghaz, Fase 4, CM-LA-01): ao voltar de um save ou de um combate, o jogador
## nunca nasce dentro de um objeto ou ladrilho com colisão; valor inválido ou fora do mapa vai para a entrada; uma
## posição livre continua exatamente igual.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")
const FOREST := "res://scenes/world/forest_brook.tscn"

var exploration: Node
var party: Node


func _begin() -> void:
	exploration = tree.root.get_node("ExplorationManager")
	party = tree.root.get_node("PartyManager")
	exploration.reset()
	exploration.scene_changes_enabled = false
	var hero: CharacterData = CharacterFactory.create(FACTORY_TESTS.new().fighter_choices(), tree.root.get_node("Content").registry)[0]
	party.start_new_party(hero)


func _end(map: Node) -> void:
	map.queue_free()
	await tree.process_frame
	exploration.scene_changes_enabled = true
	exploration.reset()
	party.clear()


func _open() -> ExplorationMap:
	var map: ExplorationMap = (load(FOREST) as PackedScene).instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	return map


## Centro da colisão do primeiro objeto sólido do cenário (uma árvore, pinheiro, arbusto ou pedra).
func _blocked_spot(map: ExplorationMap) -> Vector2:
	for node in map.get_node("Objects/Props").get_children():
		var shape := node.get_node_or_null("Collision") as CollisionShape2D
		if shape != null:
			# O pé do jogador fica 3 px acima da posição; mira o centro da colisão.
			return shape.global_position + Vector2(0, 3)
	return Vector2.INF


func _first_entrance(map: ExplorationMap) -> Vector2:
	return (map.get_node("Entrances").get_child(0) as Node2D).global_position


func test_blocked_position_moves_to_nearest_free_spot() -> void:
	_begin()
	var map := await _open()
	var spot := _blocked_spot(map)
	assert_true(spot.is_finite(), "Achou um objeto sólido no mapa")
	assert_true(map.is_spot_blocked(spot), "A posição sobre o objeto está bloqueada")
	var safe := map.safe_spawn(spot)
	assert_true(not map.is_spot_blocked(safe), "A posição corrigida está livre")
	assert_true(safe.distance_to(spot) <= 16.0 * 8.0, "E fica perto (no máximo 8 casas): %s" % [safe.distance_to(spot)])
	await _end(map)


func test_free_position_is_kept_exactly() -> void:
	_begin()
	var map := await _open()
	var free := _first_entrance(map)
	assert_true(not map.is_spot_blocked(free), "A entrada está livre")
	assert_eq(map.safe_spawn(free), free, "Posição livre não muda (comportamento de hoje)")
	await _end(map)


func test_invalid_or_outside_positions_go_to_the_entrance() -> void:
	_begin()
	var map := await _open()
	var entrance := _first_entrance(map)
	assert_eq(map.safe_spawn(Vector2(-5000, -5000)), entrance, "Fora do mapa: entrada")
	assert_eq(map.safe_spawn(Vector2(NAN, 10)), entrance, "NaN: entrada")
	assert_eq(map.safe_spawn(Vector2(INF, 10)), entrance, "Infinito: entrada")
	await _end(map)


func test_returning_onto_a_prop_is_corrected_on_load() -> void:
	_begin()
	var probe := await _open()
	var spot := _blocked_spot(probe)
	await _end(probe)
	_begin()
	exploration.begin_encounter("encounter.lone_wolf", "probe", FOREST, spot)
	exploration.finish_encounter(CombatManager.Outcome.VICTORY, 0)
	var map := await _open()
	var player := map.get_node("%Player") as Node2D
	assert_true(not map.is_spot_blocked(player.global_position), "Ao voltar, o jogador não fica preso no objeto")
	await _end(map)
