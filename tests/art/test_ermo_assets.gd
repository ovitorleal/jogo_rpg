extends "res://tests/base_test.gd"
## Peças do Ermo (onda livros-de-arghaz, Fase 3): objetos de cenário e ladrilhos de calçamento antigo gerados por
## tools/art/generate_environment.gd, no formato dos objetos que já existem.

const PIECES := {
	"ancestral_tree": [Vector2i(128, 104), true],
	"young_tree": [Vector2i(20, 32), true],
	"sapling": [Vector2i(12, 16), false],
	"wall_base": [Vector2i(48, 28), true],
	"fallen_column": [Vector2i(56, 20), true],
}
const ATLAS := "res://assets/tilesets/overworld_tiles.png"
const PAVING_COLUMNS := [6, 7, 8, 9]


func test_pieces_exist_with_size_and_transparent_background() -> void:
	for piece: String in PIECES:
		var path := "res://assets/environments/%s.png" % piece
		assert_true(ResourceLoader.exists(path), "Existe %s" % path)
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		assert_eq(Vector2i(img.get_width(), img.get_height()), PIECES[piece][0], "Tamanho de %s" % piece)
		assert_true(img.get_pixel(0, 0).a == 0.0, "Fundo transparente em %s" % piece)


func test_prop_scenes_have_sprite_and_expected_collision() -> void:
	for piece: String in PIECES:
		var path := "res://scenes/world/props/%s.tscn" % piece
		assert_true(ResourceLoader.exists(path), "Existe %s" % path)
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate()
		assert_true(node.get_node_or_null("Sprite") is Sprite2D, "%s tem Sprite" % piece)
		var blocks: bool = PIECES[piece][1]
		assert_eq(node.get_node_or_null("Collision") != null, blocks,
				"%s %s a passagem" % [piece, "bloqueia" if blocks else "não bloqueia"])
		node.free()


func test_paving_tiles_use_only_the_free_atlas_cells() -> void:
	var img := (load(ATLAS) as Texture2D).get_image()
	for col: int in PAVING_COLUMNS:
		var opaque := 0
		var clear := 0
		for y in 16:
			for x in 16:
				if img.get_pixel(col * 16 + x, y).a > 0.5:
					opaque += 1
				else:
					clear += 1
		assert_true(opaque > 100, "Ladrilho de calçamento %d tem pedras (%d px)" % [col, opaque])
		if col != PAVING_COLUMNS[0]: # a primeira variação é a estrada inteira; as outras são gastas
			assert_true(clear > 0, "Ladrilho %d deixa a grama aparecer onde faltam pedras" % col)
	# As colunas seguintes da linha 0 continuam livres.
	for col in range(10, 16):
		var any := false
		for y in 16:
			for x in 16:
				any = any or img.get_pixel(col * 16 + x, y).a > 0.0
		assert_true(not any, "Coluna %d da linha 0 continua livre" % col)
