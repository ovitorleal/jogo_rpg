extends SceneTree
## Importa a arte de As Crônicas de Arghaz (originais em art_source/arghaz, ignorados pelo Godot) para
## assets/: limpa cada personagem (mantém só a figura principal, sem pedaços dos vizinhos da folha
## original), recorta, reduz para ALTURA px com os pés na base e grava em assets/characters/arghaz/.
## Também copia o logo (recortado) e o fundo da vila. Uso:
##   godot --headless --path . --script res://tools/art/import_arghaz.gd

const SOURCE := "res://art_source/arghaz"
const OUT_CHARACTERS := "res://assets/characters/arghaz"
## Altura final dos personagens (px). Exibidos com ~64 px de altura no mundo; a sobra dá nitidez.
const HEIGHT := 256
const ALPHA_CUT := 24

const CLASSES := {
	"barbaro": "barbarian", "bardo": "bard", "bruxo": "warlock", "clerigo": "cleric", "druida": "druid",
	"feiticeiro": "sorcerer", "guerreiro": "fighter", "ladino": "rogue", "mago": "wizard", "monge": "monk",
	"paladino": "paladin", "patrulheiro": "ranger",
}
## Aasimar fica de fora: não faz parte do SRD 5.2.1.
const SPECIES := {
	"anao": "dwarf", "draconato": "dragonborn", "elfo": "elf", "gnomo": "gnome", "golias": "goliath",
	"halfling": "halfling", "humano": "human", "orc": "orc", "tiefling": "tiefling",
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_CHARACTERS))
	var count := 0
	for name: String in CLASSES:
		count += _character("%s/sprites/classes/%s.png" % [SOURCE, name], "%s/class_%s.png" % [OUT_CHARACTERS, CLASSES[name]])
	for name: String in SPECIES:
		count += _character("%s/sprites/especies/%s.png" % [SOURCE, name], "%s/species_%s.png" % [OUT_CHARACTERS, SPECIES[name]])
	var logo := _load("%s/logo-arghaz.png" % SOURCE)
	if logo != null:
		logo = logo.get_region(logo.get_used_rect())
		_fit(logo, 1200, 600)
		_save(logo, "res://assets/ui/logo_arghaz.png")
		count += 1
	var village := _load("%s/fundo-vila.png" % SOURCE)
	if village != null:
		_save(village, "res://assets/backgrounds/village.png")
		count += 1
	print("import_arghaz: %d imagens" % count)
	quit(0 if count == CLASSES.size() + SPECIES.size() + 2 else 1)


func _character(source: String, target: String) -> int:
	var image := _load(source)
	if image == null:
		return 0
	_keep_main_figure(image)
	image = image.get_region(image.get_used_rect())
	_fit(image, HEIGHT * 2, HEIGHT)
	_save(image, target)
	return 1


func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		push_error("Não encontrei %s" % path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


## Apaga as manchas soltas que encostam nas laterais (pedaços do vizinho na folha original), menos a
## maior, e pixels quase transparentes.
func _keep_main_figure(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var sizes: Array[int] = []
	var touches: Array[bool] = []
	for start in w * h:
		if label[start] != -1 or image.get_pixel(start % w, start / w).a8 < ALPHA_CUT:
			continue
		var id := sizes.size()
		var size := 0
		var edge := false
		var stack := PackedInt32Array([start])
		label[start] = id
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			size += 1
			var x := p % w
			var y := p / w
			if x == 0 or x == w - 1:
				edge = true
			for n in [p - 1 if x > 0 else -1, p + 1 if x < w - 1 else -1, p - w if y > 0 else -1, p + w if y < h - 1 else -1]:
				if n >= 0 and label[n] == -1 and image.get_pixel(n % w, n / w).a8 >= ALPHA_CUT:
					label[n] = id
					stack.append(n)
		sizes.append(size)
		touches.append(edge)
	var biggest := sizes.find(sizes.max()) if not sizes.is_empty() else -1
	for p in w * h:
		var id := label[p]
		if id == -1 or (id != biggest and touches[id]):
			image.set_pixel(p % w, p / w, Color(0, 0, 0, 0))


## Reduz para caber em max_w × max_h mantendo a proporção (nunca amplia).
func _fit(image: Image, max_w: int, max_h: int) -> void:
	var factor := minf(1.0, minf(float(max_w) / image.get_width(), float(max_h) / image.get_height()))
	if factor < 1.0:
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)),
				Image.INTERPOLATE_LANCZOS)


func _save(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Falha ao gravar %s" % path)
