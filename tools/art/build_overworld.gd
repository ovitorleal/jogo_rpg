extends SceneTree
## Monta o TileSet do terreno e o mapa de teste (terreno, muros e objetos de cenário).
## Pré-requisito: generate_environment.gd + --import.
## Uso: godot --headless --path . --script res://tools/art/build_overworld.gd [-- --force] [--layout forest_brook]
## Layouts: "test_map" (padrão, Clareira da Encruzilhada) e "forest_brook" (Bosque do Riacho).
##
## O terreno é definido nos VÉRTICES da grade (grama, terra, areia, água); cada tile escolhe a
## transição pelos 4 cantos (marching squares), o que dá bordas suaves e orgânicas.
## Saídas editáveis no editor do Godot; sem --force, nada é sobrescrito.

const ENV := preload("res://tools/art/generate_environment.gd")

const TILESET_PATH := "res://assets/tilesets/overworld_tileset.tres"
const TEXTURE_PATH := "res://assets/tilesets/overworld_tiles.png"

const LAYOUTS := {
	"test_map": {"size": Vector2i(60, 34), "seed": 20261024,
			"terrain": "res://scenes/world/test_map_terrain.tscn", "props": "res://scenes/world/test_map_props.tscn"},
	"forest_brook": {"size": Vector2i(44, 26), "seed": 20261025,
			"terrain": "res://scenes/world/forest_brook_terrain.tscn", "props": "res://scenes/world/forest_brook_props.tscn"},
}

enum V { GRASS, DIRT, SAND, WATER }

const BLOCKER := Vector2i(4, 0)
const WALL := Vector2i(5, 0)
const GRASS_WEIGHTS := [0.62, 0.24, 0.07, 0.07]

const PROP_SCENES := {
	"tree": "res://scenes/world/props/tree.tscn",
	"pine": "res://scenes/world/props/pine.tscn",
	"bush": "res://scenes/world/props/bush.tscn",
	"rock": "res://scenes/world/props/rock.tscn",
}

## Áreas sem objetos (em tiles) por layout.
const CLEAR := {
	"test_map": [Rect2i(25, 11, 12, 12), Rect2i(41, 18, 7, 7), Rect2i(10, 22, 9, 7), Rect2i(51, 13, 9, 7)],
	"forest_brook": [Rect2i(0, 10, 6, 7), Rect2i(23, 7, 11, 10)],
}
const RUIN := Rect2i(10, 23, 9, 6)
const GROVE := Rect2i(39, 20, 16, 11)

var MAP := Vector2i(60, 34)
var _layout := "test_map"
var _rng := RandomNumberGenerator.new()
var _vertices: Array = []
var _blocked := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var force := args.has("--force")
	var layout_index := args.find("--layout")
	if layout_index >= 0 and layout_index + 1 < args.size():
		_layout = args[layout_index + 1]
	if not LAYOUTS.has(_layout):
		push_error("Layout desconhecido: %s" % _layout)
		quit(1)
		return
	MAP = LAYOUTS[_layout]["size"]
	var TERRAIN_SCENE: String = LAYOUTS[_layout]["terrain"]
	var PROPS_SCENE: String = LAYOUTS[_layout]["props"]
	for path in [TILESET_PATH, TERRAIN_SCENE, PROPS_SCENE]:
		if FileAccess.file_exists(path) and not force:
			push_error("%s já existe. Use '-- --force' para sobrescrever (edições manuais serão perdidas)." % path)
			quit(1)
			return
	var texture: Texture2D = load(TEXTURE_PATH)
	if texture == null:
		push_error("Textura não encontrada: %s (rode generate_environment.gd e --import antes)" % TEXTURE_PATH)
		quit(1)
		return
	if ResourceSaver.save(_build_tile_set(texture), TILESET_PATH) != OK:
		quit(1)
		return
	print("Gerado: %s" % TILESET_PATH)
	var tile_set: TileSet = ResourceLoader.load(TILESET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)

	_rng.seed = int(LAYOUTS[_layout]["seed"])
	_build_vertices()
	var terrain := Node2D.new()
	terrain.name = "Terrain"
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tile_set
	terrain.add_child(ground)
	terrain.add_child(walls)
	ground.owner = terrain
	walls.owner = terrain
	for y in MAP.y:
		for x in MAP.x:
			ground.set_cell(Vector2i(x, y), 0, _ground_tile(x, y))
			var wall := _wall_tile(x, y)
			if wall != Vector2i(-1, -1):
				walls.set_cell(Vector2i(x, y), 0, wall)
				_blocked[Vector2i(x, y)] = true
	if not _pack(terrain, LAYOUTS[_layout]["terrain"]):
		quit(1)
		return
	if not _pack(_build_props(), LAYOUTS[_layout]["props"]):
		quit(1)
		return
	quit(0)


func _pack(root: Node, path: String) -> bool:
	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, path)
	root.free()
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [path, error_string(err)])
		return false
	print("Gerado: %s" % path)
	return true


# --- TileSet ------------------------------------------------------------------

func _build_tile_set(texture: Texture2D) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)
	tile_set.add_source(source, 0)

	for v in 4:
		source.create_tile(Vector2i(v, 0))
	for coords in [BLOCKER, WALL]:
		source.create_tile(coords)
		_add_quadrants(source, coords, 15)
	for mask in 16:
		var cell := Vector2i(mask % 4, mask / 4)
		source.create_tile(ENV.DIRT_ORIGIN + cell)
		source.create_tile(ENV.SAND_ORIGIN + cell)
		var water: Vector2i = ENV.water_coords(mask)
		source.create_tile(water)
		source.set_tile_animation_frames_count(water, ENV.WATER_FRAMES)
		source.set_tile_animation_speed(water, 3.0)
		_add_quadrants(source, water, mask)
	return tile_set


## Colisão por quadrante: cada canto marcado bloqueia um quadrado 8x8 daquele canto.
func _add_quadrants(source: TileSetAtlasSource, coords: Vector2i, mask: int) -> void:
	if mask == 0:
		return
	var data := source.get_tile_data(coords, 0)
	var corners := {1: Vector2(-8, -8), 2: Vector2(0, -8), 4: Vector2(0, 0), 8: Vector2(-8, 0)}
	if mask == 15:
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
		return
	var index := 0
	for bit: int in corners:
		if mask & bit:
			var o: Vector2 = corners[bit]
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, index, PackedVector2Array([o, o + Vector2(8, 0), o + Vector2(8, 8), o + Vector2(0, 8)]))
			index += 1


# --- Terreno nos vértices -----------------------------------------------------

func _build_vertices() -> void:
	_vertices.clear()
	for y in MAP.y + 1:
		var row := []
		for x in MAP.x + 1:
			row.append(_vertex(x, y))
		_vertices.append(row)


func _vertex(x: int, y: int) -> int:
	if _layout == "forest_brook":
		return _vertex_forest(x, y)
	var lake := Vector2((x - 12.5) / 7.0, (y - 7.0) / 5.0)
	var water := Vector2((x - 12.5) / 4.8, (y - 7.0) / 3.0)
	if water.length() <= 1.0:
		return V.WATER
	if lake.length() <= 1.0:
		return V.SAND
	# Estrada leste-oeste (sinuosa) e norte-sul.
	var road_y := 17.0 + sin(x * 0.25) * 0.8
	if absf(y - road_y) <= 1.2:
		return V.DIRT
	var road_x := 30.0 + sin(y * 0.3) * 0.8
	if absf(x - road_x) <= 1.2 and y >= 2 and y <= 32:
		return V.DIRT
	# Chão de terra batida dentro da ruína.
	if x >= 11 and x <= 18 and y >= 24 and y <= 28:
		return V.DIRT
	return V.GRASS


## Bosque do Riacho: trilha do oeste até o acampamento; riacho com margens de areia a leste.
func _vertex_forest(x: int, y: int) -> int:
	var brook_x := 37.0 + sin(y * 0.35) * 1.6
	var d := absf(x - brook_x)
	if d <= 1.1:
		return V.WATER
	if d <= 2.4:
		return V.SAND
	var camp := Vector2(x - 28.0, (y - 12.0) * 1.2)
	if camp.length() <= 3.6:
		return V.DIRT
	var trail_y := 13.0 + sin(x * 0.3) * 0.9
	if x <= 26 and absf(y - trail_y) <= 1.1:
		return V.DIRT
	return V.GRASS


func _ground_tile(x: int, y: int) -> Vector2i:
	var corners: Array = [_vertices[y][x], _vertices[y][x + 1], _vertices[y + 1][x + 1], _vertices[y + 1][x]]
	var bits := [1, 2, 4, 8]
	for kind in [V.WATER, V.SAND, V.DIRT]:
		if kind in corners:
			var mask := 0
			for i in 4:
				if corners[i] == kind or (kind == V.SAND and corners[i] == V.WATER):
					mask |= bits[i]
			match kind:
				V.WATER:
					return ENV.water_coords(mask)
				V.SAND:
					return ENV.SAND_ORIGIN + Vector2i(mask % 4, mask / 4)
				V.DIRT:
					return ENV.DIRT_ORIGIN + Vector2i(mask % 4, mask / 4)
	var roll := _rng.randf()
	var acc := 0.0
	for v in 4:
		acc += GRASS_WEIGHTS[v]
		if roll <= acc:
			return Vector2i(v, 0)
	return Vector2i(0, 0)


func _wall_tile(x: int, y: int) -> Vector2i:
	if x == 0 or y == 0 or x == MAP.x - 1 or y == MAP.y - 1:
		return BLOCKER
	if _layout != "test_map":
		return Vector2i(-1, -1)
	if RUIN.has_point(Vector2i(x, y)):
		var edge := x == RUIN.position.x or x == RUIN.end.x - 1 or y == RUIN.end.y - 1
		# Ruína: muro em U aberto ao norte, com um vão na parede leste.
		if edge and not (x == RUIN.end.x - 1 and y == 25):
			return WALL
	return Vector2i(-1, -1)


func _is_open_grass(cell: Vector2i) -> bool:
	if _blocked.has(cell):
		return false
	for rect: Rect2i in CLEAR[_layout]:
		if rect.has_point(cell):
			return false
	for dy in 2:
		for dx in 2:
			if _vertices[cell.y + dy][cell.x + dx] != V.GRASS:
				return false
	return true


# --- Objetos -------------------------------------------------------------------

func _build_props() -> Node2D:
	var root := Node2D.new()
	root.name = "Props"
	root.y_sort_enabled = true
	var taken := {}
	# Moldura de floresta nas bordas (as bordas também têm bloqueio invisível).
	var x := 4
	while x < MAP.x * 16:
		_add_prop(root, "tree" if (x / 20) % 3 != 0 else "pine", Vector2(x + _rng.randi_range(-2, 2), 14))
		_add_prop(root, "pine" if (x / 20) % 2 == 0 else "tree", Vector2(x + _rng.randi_range(-2, 2), MAP.y * 16 - 1))
		x += 20
	var y := 30
	while y < MAP.y * 16 - 16:
		_add_prop(root, "pine", Vector2(6, y))
		_add_prop(root, "pine", Vector2(MAP.x * 16 - 6, y))
		y += 22
	if _layout == "forest_brook":
		_scatter(root, taken, Rect2i(2, 2, MAP.x - 4, MAP.y - 4), ["tree", "pine", "tree"], 46, 2)
		_scatter(root, taken, Rect2i(2, 2, MAP.x - 4, MAP.y - 4), ["bush"], 14, 1)
		_scatter(root, taken, Rect2i(2, 2, MAP.x - 4, MAP.y - 4), ["rock"], 8, 1)
		return root
	# Bosque a sudeste, árvores espalhadas, pedras e arbustos.
	_scatter(root, taken, GROVE, ["tree", "tree", "pine"], 16, 2)
	_scatter(root, taken, Rect2i(2, 13, 22, 8), ["tree", "pine"], 5, 3)
	_scatter(root, taken, Rect2i(34, 2, 24, 13), ["tree", "pine"], 6, 3)
	_scatter(root, taken, Rect2i(2, 2, MAP.x - 4, MAP.y - 4), ["rock"], 18, 1)
	_scatter(root, taken, Rect2i(2, 2, MAP.x - 4, MAP.y - 4), ["bush"], 22, 1)
	return root


func _scatter(root: Node2D, taken: Dictionary, area: Rect2i, kinds: Array, count: int, spacing: int) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 40:
		attempts += 1
		var cell := Vector2i(_rng.randi_range(area.position.x, area.end.x - 1), _rng.randi_range(area.position.y, area.end.y - 1))
		if not _is_open_grass(cell):
			continue
		var crowded := false
		for other: Vector2i in taken:
			if maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < spacing:
				crowded = true
				break
		if crowded:
			continue
		taken[cell] = true
		_add_prop(root, kinds[placed % kinds.size()], Vector2(cell * 16) + Vector2(8, 14))
		placed += 1


func _add_prop(root: Node2D, kind: String, position: Vector2) -> void:
	var prop: Node2D = (load(PROP_SCENES[kind]) as PackedScene).instantiate()
	prop.name = "%s_%d" % [kind, root.get_child_count()]
	prop.position = position
	root.add_child(prop)
	prop.owner = root
