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


## Centro global da primeira casa da camada com colisão que satisfaz `wanted` (ou INF).
func _tile_spot(map: ExplorationMap, layer_path: String, wanted: Callable) -> Vector2:
	var layer := map.get_node(layer_path) as TileMapLayer
	for cell in layer.get_used_cells():
		var data := layer.get_cell_tile_data(cell)
		if data != null and data.get_collision_polygons_count(0) > 0 and wanted.call(layer, cell):
			return layer.to_global(layer.map_to_local(cell))
	return Vector2.INF


func test_collision_tiles_block_and_are_escaped() -> void:
	# Borda do mapa (camada Walls) e água do riacho (camada Ground, quadrantes com colisão).
	_begin()
	var map := await _open()
	var wall := _tile_spot(map, "%Terrain/Walls", func(l: TileMapLayer, c: Vector2i) -> bool: return c.x == 0 and c.y == 12)
	var water := _tile_spot(map, "%Terrain/Ground",
			func(l: TileMapLayer, c: Vector2i) -> bool: return l.get_cell_tile_data(c).get_collision_polygons_count(0) >= 2)
	for spot: Vector2 in [wall, water]:
		assert_true(spot.is_finite(), "Achou um ladrilho com colisão")
		# O pé fica acima da posição: mira o centro do ladrilho com o pé.
		var p := spot + Vector2(0, 3)
		assert_true(map.is_spot_blocked(p), "Ladrilho com colisão bloqueia em %s" % p)
		var safe := map.safe_spawn(p)
		assert_true(not map.is_spot_blocked(safe), "Sai do ladrilho para um ponto livre (%s -> %s)" % [p, safe])
	await _end(map)


func test_every_free_spot_is_kept_even_touching_a_prop() -> void:
	# Quem já tem save num lugar livre não pode ser mexido: nem colado num objeto, nem em lugar nenhum do mapa.
	_begin()
	var map := await _open()
	var bounds := Rect2(map.get_map_rect())
	var inner := bounds.grow(-64.0)
	var shape: CollisionShape2D = null
	for node in map.get_node("Objects/Props").get_children():
		var candidate := node.get_node_or_null("Collision") as CollisionShape2D
		if candidate != null and inner.has_point(candidate.global_position):
			shape = candidate
			break
	var r := shape.shape.get_rect()
	var solid := Rect2(shape.global_position + r.position, r.size)
	# Pé (10x6, 3 px acima da posição) encostando na borda esquerda do objeto, sem sobrepor.
	var touching := Vector2(solid.position.x - 5.0, solid.end.y - 3.0)
	if not map.is_spot_blocked(touching):
		assert_eq(map.safe_spawn(touching), touching, "Encostado no objeto, mas livre: não muda")
	assert_true(map.is_spot_blocked(touching + Vector2(1, 0)), "1 px para dentro do objeto já bloqueia")
	var checked := 0
	var y := bounds.position.y + 8.0
	while y < bounds.end.y:
		var x := bounds.position.x + 8.0
		while x < bounds.end.x:
			var p := Vector2(x, y)
			if not map.is_spot_blocked(p):
				checked += 1
				if map.safe_spawn(p) != p:
					assert_true(false, "Posição livre %s foi alterada" % p)
			x += 16.0
		y += 16.0
	assert_true(checked > 300, "Varreu as posições livres do mapa (%d)" % checked)
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
