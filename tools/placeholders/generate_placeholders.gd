extends SceneTree
## Gera os PNGs provisórios do projeto (arte original, desenhada neste arquivo).
## Uso: godot --headless --path . --script res://tools/placeholders/generate_placeholders.gd
## Saída determinística: rodar de novo produz os mesmos pixels.

const HERO_PATH := "res://assets/characters/placeholder_hero.png"
const TILES_PATH := "res://assets/tilesets/placeholder_tiles.png"
const SIGN_PATH := "res://assets/environments/placeholder_sign.png"
const PORTRAIT_PATH := "res://assets/portraits/placeholder_hero_portrait.png"
const WOLF_PATH := "res://assets/enemies/placeholder_wolf.png"
const GOBLIN_PATH := "res://assets/enemies/placeholder_goblin.png"

const PORTRAIT_BG := [Color8(43, 35, 64), Color8(58, 48, 80)]

## Mapas de pixels com largura livre: cada linha é centralizada no quadro 32x32 e a última
## linha fica na linha BOTTOM_ROW (pés no mesmo pivô do herói).
const BOTTOM_ROW := 27
const CREATURE_PALETTE := {
	"o": Color8(26, 20, 35),
	"g": Color8(122, 122, 133),
	"G": Color8(160, 160, 172),
	"d": Color8(74, 74, 85),
	"e": Color8(230, 214, 90),
	"k": Color8(111, 154, 74),
	"K": Color8(74, 107, 50),
	"r": Color8(214, 70, 60),
	"b": Color8(107, 74, 46),
	"B": Color8(61, 43, 31),
	"s": Color8(200, 200, 208),
	"x": Color(0.0, 0.0, 0.0, 0.3),
}

const WOLF_ROWS: Array[String] = [
	"...o.o...............",
	"..ogogo..............",
	".ogggggo.............",
	"oegggggooooooooooooo.",
	"ogggggggggggggggggggo",
	"oddoggggggggggggggggo",
	".oo.oGGGGGGGGGGgggggoo",
	"....oggggggggggggggo.go",
	"....ogggoooooooogggo..o",
	"....oggo.......oggo....",
	"....oggo.......oggo....",
	"....oddo.......oddo....",
	"....ooo........ooo.....",
	"...xxxxxxxxxxxxxxxx....",
]

const GOBLIN_ROWS: Array[String] = [
	"o..........o..",
	"ko.oooooo.ok..",
	".okkkkkkkko...",
	"..okrkkrko....",
	"..okkkkkko....",
	"...okKKko.....",
	"....oooo......",
	"..obbbbbbo..s.",
	".okbbbbbbkoss.",
	".okbBBBBbkos..",
	"..obbbbbbos...",
	"..obboobbo....",
	"..okko.okko...",
	"..ooo..ooo....",
	".xxxxxxxxxx...",
]

const TILE := 16
const TILE_COLUMNS := 4
const TILE_ROWS := 2
const RANDOM_SEED := 20261023

const PALETTE := {
	"o": Color8(26, 20, 35),        # contorno
	"h": Color8(107, 62, 38),       # cabelo
	"s": Color8(224, 180, 138),     # pele
	"a": Color8(90, 107, 140),      # armadura
	"A": Color8(133, 151, 184),     # armadura (luz)
	"c": Color8(140, 47, 57),       # capa
	"b": Color8(61, 43, 31),        # cinto e botas
	"x": Color(0.0, 0.0, 0.0, 0.3), # sombra
}

const GRASS := [Color8(74, 122, 58), Color8(63, 107, 50), Color8(90, 140, 69)]
const PATH := [Color8(156, 123, 82), Color8(138, 106, 69), Color8(176, 142, 98)]
const SAND := [Color8(216, 196, 138), Color8(200, 180, 122), Color8(228, 210, 158)]
const WATER := [Color8(58, 110, 165), Color8(48, 94, 146), Color8(90, 140, 192)]
const STONE := [Color8(107, 107, 120), Color8(74, 74, 85), Color8(133, 133, 154)]
const ROCK := [Color8(122, 122, 133), Color8(58, 58, 68), Color8(160, 160, 172)]
const BUSH := [Color8(47, 90, 42), Color8(31, 58, 28), Color8(74, 122, 58)]
const FLOWER_COLORS := [Color8(230, 214, 90), Color8(216, 216, 240), Color8(214, 110, 120)]
const WOOD := [Color8(156, 123, 82), Color8(61, 43, 31), Color8(107, 74, 46)]

# Herói: cada linha tem 14 colunas; "." é transparente. Colado em (9, 4) num quadro 32x32.
const HERO_ROWS: Array[String] = [
	"....oooooo....",
	"...ohhhhhho...",
	"..ohhhhhhhho..",
	"..ohhhhhhhho..",
	"..ohssssssho..",
	"..ossossosso..",
	"..osssssssso..",
	"...osssssso...",
	"....oossoo....",
	"..ocaaaaaaco..",
	".ocaAAaaAAaco.",
	".ocaAaaaaAaco.",
	".ocaaaaaaaaco.",
	".osabbbbbbaso.",
	".oscaaaaaacso.",
	"..ocaaaaaaco..",
	"..ocaaaaaaco..",
	"..ocaaooaaco..",
	"..occaooacco..",
	"...obbo..obbo.",
	"...obbo..obbo.",
	"..obbbo..obbbo",
	"...ooo....ooo.",
	"....xxxxxx....",
]

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = RANDOM_SEED
	var ok := _save(_build_hero(), HERO_PATH)
	ok = ok and _save(_build_tiles(), TILES_PATH)
	ok = ok and _save(_build_sign(), SIGN_PATH)
	ok = ok and _save(_build_portrait(), PORTRAIT_PATH)
	ok = ok and _save(_build_from_rows(WOLF_ROWS, "Lobo"), WOLF_PATH)
	ok = ok and _save(_build_from_rows(GOBLIN_ROWS, "Goblin"), GOBLIN_PATH)
	quit(0 if ok else 1)


func _build_from_rows(rows: Array[String], label: String) -> Image:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var top := BOTTOM_ROW - rows.size() + 1
	for row_index in rows.size():
		var row: String = rows[row_index]
		if row.length() > 32:
			push_error("%s: linha %d com mais de 32 colunas" % [label, row_index])
			return null
		@warning_ignore("integer_division")
		var left := (32 - row.length()) / 2
		for col in row.length():
			var key := row[col]
			if key == ".":
				continue
			if not CREATURE_PALETTE.has(key):
				push_error("%s: cor desconhecida '%s' na linha %d" % [label, key, row_index])
				return null
			image.set_pixel(left + col, top + row_index, CREATURE_PALETTE[key])
	return image


## Retrato do herói (rosto e ombros), 32x32 com fundo controlado. Exibido em 2x na interface.
func _build_portrait() -> Image:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var outline: Color = PALETTE["o"]
	for y in 32:
		for x in 32:
			var lit := Vector2(x, y).distance_to(Vector2(16, 13)) < 13.0
			image.set_pixel(x, y, PORTRAIT_BG[1] if lit else PORTRAIT_BG[0])
	# Ombros: capa nas laterais, armadura no centro, contorno no topo.
	for y in range(23, 32):
		for x in range(2, 30):
			var dx := absf(x - 15.5)
			var top := 23.0 + pow(dx / 14.0, 2.0) * 4.0
			if y < top:
				continue
			var color: Color = PALETTE["c"] if dx > 9.0 else PALETTE["a"]
			if dx <= 9.0 and dx > 6.0 and y < 27:
				color = PALETTE["A"]
			if y < top + 1.0:
				color = outline
			image.set_pixel(x, y, color)
	# Pescoço.
	for y in range(19, 24):
		for x in range(13, 19):
			image.set_pixel(x, y, outline if x == 13 or x == 18 else PALETTE["s"])
	# Cabeça (elipse) com contorno.
	var center := Vector2(15.5, 13.0)
	for y in range(3, 22):
		for x in range(6, 26):
			var d := pow((x - center.x) / 6.5, 2.0) + pow((y - center.y) / 7.5, 2.0)
			if d <= 0.82:
				image.set_pixel(x, y, PALETTE["s"])
			elif d <= 1.0:
				image.set_pixel(x, y, outline)
	# Cabelo: topo da cabeça e laterais.
	for y in range(4, 13):
		for x in range(9, 23):
			var d := pow((x - center.x) / 6.5, 2.0) + pow((y - center.y) / 7.5, 2.0)
			var fringe := y <= 8 or (y <= 12 and (x <= 10 or x >= 21))
			if d <= 0.82 and fringe:
				image.set_pixel(x, y, PALETTE["h"])
	# Olhos, sobrancelhas e boca.
	for eye_x in [12, 19]:
		image.set_pixel(eye_x, 13, outline)
		image.set_pixel(eye_x, 12, PALETTE["h"])
		image.set_pixel(eye_x + 1, 12, PALETTE["h"])
	image.set_pixel(15, 15, Color8(200, 150, 110))
	image.set_pixel(16, 15, Color8(200, 150, 110))
	for x in range(14, 18):
		image.set_pixel(x, 17, Color8(160, 100, 80))
	return image


func _save(image: Image, path: String) -> bool:
	if image == null:
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [path, error_string(err)])
		return false
	print("Gerado: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	return true


func _build_hero() -> Image:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for row_index in HERO_ROWS.size():
		var row: String = HERO_ROWS[row_index]
		if row.length() != 14:
			push_error("Herói: linha %d tem %d colunas (esperado 14)" % [row_index, row.length()])
			return null
		for col in row.length():
			var key := row[col]
			if key == ".":
				continue
			if not PALETTE.has(key):
				push_error("Herói: cor desconhecida '%s' na linha %d" % [key, row_index])
				return null
			image.set_pixel(9 + col, 4 + row_index, PALETTE[key])
	return image


## Atlas 4x2 de tiles 16x16. A ordem deve coincidir com tools/placeholders/build_test_map.gd.
## Linha 0: grama, grama com flores, caminho, água. Linha 1: muro, rocha, arbusto, areia.
func _build_tiles() -> Image:
	var image := Image.create_empty(TILE * TILE_COLUMNS, TILE * TILE_ROWS, false, Image.FORMAT_RGBA8)
	_paint_speckled(image, Vector2i(0, 0), GRASS, 0.18)
	_paint_speckled(image, Vector2i(1, 0), GRASS, 0.18)
	_paint_flowers(image, Vector2i(1, 0))
	_paint_speckled(image, Vector2i(2, 0), PATH, 0.22)
	_paint_water(image, Vector2i(3, 0))
	_paint_wall(image, Vector2i(0, 1))
	_paint_speckled(image, Vector2i(1, 1), GRASS, 0.18)
	_paint_blob(image, Vector2i(1, 1), ROCK, 5.5)
	_paint_speckled(image, Vector2i(2, 1), GRASS, 0.18)
	_paint_blob(image, Vector2i(2, 1), BUSH, 6.5)
	_paint_speckled(image, Vector2i(3, 1), SAND, 0.2)
	return image


func _origin(cell: Vector2i) -> Vector2i:
	return cell * TILE


func _paint_speckled(image: Image, cell: Vector2i, colors: Array, density: float) -> void:
	var o := _origin(cell)
	for y in TILE:
		for x in TILE:
			var color: Color = colors[0]
			if _rng.randf() < density:
				color = colors[1 + _rng.randi_range(0, 1)]
			image.set_pixel(o.x + x, o.y + y, color)


func _paint_flowers(image: Image, cell: Vector2i) -> void:
	var o := _origin(cell)
	for i in 5:
		var p := Vector2i(_rng.randi_range(1, TILE - 2), _rng.randi_range(1, TILE - 2))
		image.set_pixel(o.x + p.x, o.y + p.y, FLOWER_COLORS[i % FLOWER_COLORS.size()])


func _paint_water(image: Image, cell: Vector2i) -> void:
	var o := _origin(cell)
	for y in TILE:
		for x in TILE:
			var color: Color = WATER[0] if (x + y * 3) % 7 != 0 else WATER[1]
			# Ondas: segmentos claros em linhas alternadas, deslocados para não formar grade.
			if y % 5 == 2 and (x + y) % 8 < 3:
				color = WATER[2]
			image.set_pixel(o.x + x, o.y + y, color)


func _paint_wall(image: Image, cell: Vector2i) -> void:
	var o := _origin(cell)
	for y in TILE:
		for x in TILE:
			var offset := 4 if (y % 8) >= 4 else 0
			var mortar := y % 4 == 3 or (x + offset) % 8 == 7
			var color: Color = STONE[1] if mortar else STONE[0]
			if not mortar and y % 4 == 0:
				color = STONE[2]
			image.set_pixel(o.x + x, o.y + y, color)


## Forma arredondada com contorno, luz no alto à esquerda e sombra projetada embaixo.
func _paint_blob(image: Image, cell: Vector2i, colors: Array, radius: float) -> void:
	var o := _origin(cell)
	var center := Vector2(7.5, 7.0)
	for y in TILE:
		for x in TILE:
			var d := Vector2(x, y).distance_to(center)
			var shadow_d := Vector2(x, y).distance_to(center + Vector2(0, 2.5))
			if d <= radius - 1.0:
				var lit := Vector2(x, y).distance_to(center + Vector2(-2, -2)) < radius * 0.45
				image.set_pixel(o.x + x, o.y + y, colors[2] if lit else colors[0])
			elif d <= radius:
				image.set_pixel(o.x + x, o.y + y, colors[1])
			elif shadow_d <= radius:
				var under := image.get_pixel(o.x + x, o.y + y)
				image.set_pixel(o.x + x, o.y + y, under.darkened(0.3))


## Placa de madeira 16x16 com a base do poste na linha 15.
func _build_sign() -> Image:
	var image := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in range(9, 15):
		for x in range(7, 9):
			image.set_pixel(x, y, WOOD[2])
	for y in range(2, 10):
		for x in range(1, 15):
			var border := y == 2 or y == 9 or x == 1 or x == 14
			image.set_pixel(x, y, WOOD[1] if border else WOOD[0])
	for line_y in [4, 6]:
		for x in range(4, 12):
			image.set_pixel(x, line_y, WOOD[1])
	for x in range(5, 11):
		image.set_pixel(x, 15, Color(0, 0, 0, 0.3))
	return image
