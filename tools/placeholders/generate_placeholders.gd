extends SceneTree
## Gera o sprite provisório do herói (32x32, PNG com transparência).
## Uso: godot --headless --path . --script res://tools/placeholders/generate_placeholders.gd
## Arte original, desenhada pixel a pixel neste arquivo.

const OUTPUT_PATH := "res://assets/characters/placeholder_hero.png"
const SIZE := 32
const CORE_WIDTH := 14
const PAD_LEFT := 9
const TOP_ROW := 4

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

# Cada linha tem CORE_WIDTH colunas; "." é transparente.
const ROWS: Array[String] = [
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


func _initialize() -> void:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row_index in ROWS.size():
		var row: String = ROWS[row_index]
		if row.length() != CORE_WIDTH:
			push_error("Linha %d tem %d colunas (esperado %d)" % [row_index, row.length(), CORE_WIDTH])
			quit(1)
			return
		for col in CORE_WIDTH:
			var key := row[col]
			if key == ".":
				continue
			if not PALETTE.has(key):
				push_error("Cor desconhecida '%s' na linha %d" % [key, row_index])
				quit(1)
				return
			image.set_pixel(PAD_LEFT + col, TOP_ROW + row_index, PALETTE[key])

	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var err := image.save_png(OUTPUT_PATH)
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [OUTPUT_PATH, error_string(err)])
		quit(1)
		return
	print("Gerado: %s (%dx%d)" % [OUTPUT_PATH, SIZE, SIZE])
	quit(0)
