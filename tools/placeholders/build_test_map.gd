extends SceneTree
## Gera o TileSet provisório (com colisões) e a camada de terreno do mapa de teste.
## Pré-requisito: PNGs gerados e importados (generate_placeholders.gd + --import).
## Uso: godot --headless --path . --script res://tools/placeholders/build_test_map.gd [-- --force]
##
## Os arquivos gerados são editáveis no editor do Godot. Sem --force, o script não
## sobrescreve arquivos existentes para não apagar edições manuais.

const TILE_SIZE := 16
const TEXTURE_PATH := "res://assets/tilesets/placeholder_tiles.png"
const TILESET_PATH := "res://assets/tilesets/placeholder_tileset.tres"
const GROUND_SCENE_PATH := "res://scenes/world/test_map_ground.tscn"

const MAP_SIZE := Vector2i(60, 34)
const RANDOM_SEED := 20261023

# Coordenadas no atlas (devem coincidir com generate_placeholders.gd).
const GRASS := Vector2i(0, 0)
const FLOWERS := Vector2i(1, 0)
const PATH := Vector2i(2, 0)
const WATER := Vector2i(3, 0)
const WALL := Vector2i(0, 1)
const ROCK := Vector2i(1, 1)
const BUSH := Vector2i(2, 1)
const SAND := Vector2i(3, 1)

const ALL_TILES: Array[Vector2i] = [GRASS, FLOWERS, PATH, WATER, WALL, ROCK, BUSH, SAND]
const FULL_BLOCK: Array[Vector2i] = [WATER, WALL]
const PARTIAL_BLOCK: Array[Vector2i] = [ROCK, BUSH]

# Área sem obstáculos ao redor do ponto inicial e da placa (em tiles).
const CLEAR_AREA := Rect2i(26, 12, 10, 10)

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	for path in [TILESET_PATH, GROUND_SCENE_PATH]:
		if FileAccess.file_exists(path) and not force:
			push_error("%s já existe. Use '-- --force' para sobrescrever (edições manuais serão perdidas)." % path)
			quit(1)
			return

	var texture: Texture2D = load(TEXTURE_PATH)
	if texture == null:
		push_error("Textura não encontrada: %s (rode generate_placeholders.gd e --import antes)" % TEXTURE_PATH)
		quit(1)
		return

	var err := ResourceSaver.save(_build_tile_set(texture), TILESET_PATH)
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [TILESET_PATH, error_string(err)])
		quit(1)
		return
	print("Gerado: %s" % TILESET_PATH)

	# Recarrega do disco para que a cena referencie o .tres em vez de embutir uma cópia.
	var tile_set: TileSet = ResourceLoader.load(TILESET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = tile_set
	_rng.seed = RANDOM_SEED
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			layer.set_cell(Vector2i(x, y), 0, _tile_at(x, y))

	var scene := PackedScene.new()
	scene.pack(layer)
	DirAccess.make_dir_recursive_absolute(GROUND_SCENE_PATH.get_base_dir())
	err = ResourceSaver.save(scene, GROUND_SCENE_PATH)
	layer.free()
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [GROUND_SCENE_PATH, error_string(err)])
		quit(1)
		return
	print("Gerado: %s (%dx%d tiles)" % [GROUND_SCENE_PATH, MAP_SIZE.x, MAP_SIZE.y])
	quit(0)


func _build_tile_set(texture: Texture2D) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)  # camada "world"
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)

	var half := TILE_SIZE / 2.0
	for coords in ALL_TILES:
		source.create_tile(coords)
		var extent := -1.0
		if coords in FULL_BLOCK:
			extent = half
		elif coords in PARTIAL_BLOCK:
			extent = half - 2.0
		if extent > 0.0:
			var data := source.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-extent, -extent), Vector2(extent, -extent),
				Vector2(extent, extent), Vector2(-extent, extent),
			]))
	return tile_set


func _tile_at(x: int, y: int) -> Vector2i:
	var cell := Vector2i(x, y)
	if x == 0 or y == 0 or x == MAP_SIZE.x - 1 or y == MAP_SIZE.y - 1:
		return WALL
	# Lago com margem de areia.
	if Rect2i(8, 5, 8, 5).has_point(cell):
		return WATER
	if Rect2i(7, 4, 10, 7).has_point(cell):
		return SAND
	# Ruína: muro em U, aberto ao norte.
	var ruin := Rect2i(10, 23, 9, 6)
	if ruin.has_point(cell):
		var on_edge := x == ruin.position.x or x == ruin.end.x - 1 or y == ruin.end.y - 1
		if on_edge:
			return WALL
	# Estradas: leste-oeste e norte-sul.
	if y == 16 or y == 17 or ((x == 29 or x == 30) and y >= 3 and y <= 30):
		return PATH
	if ruin.has_point(cell) or CLEAR_AREA.has_point(cell):
		return GRASS
	# Bosque de arbustos a sudeste.
	if Rect2i(40, 22, 13, 7).has_point(cell) and (x + y) % 3 == 0:
		return BUSH
	var roll := _rng.randf()
	if roll < 0.03:
		return ROCK
	if roll < 0.10:
		return FLOWERS
	return GRASS
