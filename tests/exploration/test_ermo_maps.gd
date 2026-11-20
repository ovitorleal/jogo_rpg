extends "res://tests/base_test.gd"
## O Ermo nos mapas (onda livros-de-arghaz, Fase 5): calçamento antigo numa camada sem colisão, peças novas de
## cenário, e nada do que já existia muda de lugar. A lista de antes está em tests/fixtures/props_before_ermo.json.

const FIXTURE := "res://tests/fixtures/props_before_ermo.json"
const LAYOUTS := ["test_map", "forest_brook", "village"]
const ERMO_MAPS := ["test_map", "forest_brook"]
const NEW_SOLIDS := ["ancestral_tree", "wall_base", "fallen_column"]
const PAVING := [Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0)]
const PROTECTED_RADIUS := 32.0


func _kind(node: Node) -> String:
	return node.scene_file_path.get_file().get_basename()


func _props(layout: String) -> Array[Node]:
	var root := (load("res://scenes/world/%s_props.tscn" % layout) as PackedScene).instantiate()
	var out: Array[Node] = []
	for child in root.get_children():
		root.remove_child(child)
		out.append(child)
	root.free()
	return out


func _free_all(nodes: Array[Node]) -> void:
	for n in nodes:
		n.free()


func test_old_props_keep_kind_and_position() -> void:
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for layout: String in LAYOUTS:
		var now := _props(layout)
		var swaps := 0
		for old: Dictionary in before[layout]:
			var pos := Vector2(old["position"][0], old["position"][1])
			var match_kind := ""
			for n in now:
				if (n as Node2D).position == pos and (_kind(n) == old["kind"] or (old["kind"] == "tree" and _kind(n) == "young_tree")):
					match_kind = _kind(n)
					break
			assert_true(not match_kind.is_empty(), "%s: %s em %s continua no lugar" % [layout, old["kind"], pos])
			if match_kind == "young_tree":
				swaps += 1
		if layout == "village":
			assert_eq(swaps, 0, "A vila não troca árvores")
		_free_all(now)


func test_ermo_pieces_are_on_the_forest_and_clearing() -> void:
	for layout: String in ERMO_MAPS:
		var kinds := {}
		var now := _props(layout)
		for n in now:
			kinds[_kind(n)] = int(kinds.get(_kind(n), 0)) + 1
		_free_all(now)
		assert_true(int(kinds.get("ancestral_tree", 0)) >= 1, "%s tem árvore ancestral (%s)" % [layout, kinds])
		assert_true(int(kinds.get("wall_base", 0)) + int(kinds.get("fallen_column", 0)) >= 2, "%s tem ruínas" % layout)
		assert_true(int(kinds.get("young_tree", 0)) >= 3, "%s tem árvores jovens" % layout)
		assert_true(int(kinds.get("sapling", 0)) >= 1, "%s tem mudas no calçamento" % layout)
	var village := _props("village")
	for n in village:
		assert_true(not (_kind(n) in NEW_SOLIDS), "A vila não ganha objetos sólidos novos")
	_free_all(village)


func test_paving_is_a_detail_layer_without_collision() -> void:
	for layout: String in LAYOUTS:
		var terrain := (load("res://scenes/world/%s_terrain.tscn" % layout) as PackedScene).instantiate()
		var detail := terrain.get_node_or_null("Detail") as TileMapLayer
		assert_true(detail != null, "%s tem a camada Detail" % layout)
		if detail != null:
			assert_true(not detail.collision_enabled, "%s: a camada Detail não tem colisão" % layout)
			var paving := 0
			for cell in detail.get_used_cells():
				assert_true(detail.get_cell_atlas_coords(cell) in PAVING, "%s: Detail só tem calçamento" % layout)
				paving += 1
			assert_true(paving >= 12, "%s tem calçamento (%d casas)" % [layout, paving])
			var source := detail.tile_set.get_source(0) as TileSetAtlasSource
			for coords: Vector2i in PAVING:
				assert_eq(source.get_tile_data(coords, 0).get_collision_polygons_count(0), 0, "Calçamento %s sem colisão" % coords)
		terrain.free()


func test_new_solid_pieces_keep_clear_of_protected_spots() -> void:
	for layout: String in ERMO_MAPS:
		var map := (load("res://scenes/world/%s.tscn" % layout) as PackedScene).instantiate()
		var spots: Array[Vector2] = []
		for e in map.get_node("Entrances").get_children():
			spots.append((e as Node2D).position)
		for o in map.get_node("Objects").get_children():
			if o.name != "Props":
				spots.append((o as Node2D).position)
		for prop in map.get_node("Objects/Props").get_children():
			if not (_kind(prop) in NEW_SOLIDS):
				continue
			var shape := prop.get_node("Collision") as CollisionShape2D
			var r := shape.shape.get_rect()
			var rect := Rect2((prop as Node2D).position + shape.position + r.position, r.size).grow(PROTECTED_RADIUS)
			for spot in spots:
				assert_true(not rect.has_point(spot), "%s: %s em %s longe de %s" % [layout, prop.name, (prop as Node2D).position, spot])
		map.free()
