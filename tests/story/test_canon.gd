extends "res://tests/base_test.gd"
## Trava do cânone (onda livros-de-arghaz): nenhum texto que o jogador vê pode contradizer os Livros I e II do
## mestre ou o compêndio (docs/livros/). Varre os dados (data/**/*.json), as strings dos scripts do jogo e os textos
## das cenas. Nomes internos (ids como dialogue.ione, nós de cena) não são texto visível e ficam de fora.

const BANNED := [
	["\\bIone\\b", "Ione não está em nenhuma fonte: é \"a chefe da vila\""],
	["Sussurrante", "Floresta Sussurrante não está em nenhuma fonte"],
	["Ganso Dourado", "Estalagem do Ganso Dourado não está em nenhuma fonte"],
	["Martelo do Fundo", "o deus do Doran não está em nenhuma fonte"],
	["Era dos Homens", "a era atual é a Era do Despertar (Livro I)"],
	["1\\.214", "as fontes não usam ano: as Seis Eras importam mais que datas (Livro I)"],
	["Era da Criação", "não é uma das eras dos livros"],
	["Guerra das Escamas", "não está nas fontes"],
	["Brasa que Dorme", "Vermeth é a Brasa Coroada, acordada (compêndio, §7)"],
	["Segunda Corrente", "não está nas fontes"],
	["Primeiro Dragão", "nenhuma fonte chama o Arauto de Primeiro Dragão"],
	["[Mm]inha garra", "nenhuma fonte diz que a Garra é de Vermeth (compêndio, §12)"],
	["chamado da escama", "não está nas fontes"],
	["montanhas do leste", "Vermeth não dorme sob as montanhas do leste"],
	["\\b[OoDd][o]? Silêncio\\b|desde o Silêncio|\\bdo Silêncio\\b", "o Silêncio dos dragões não está nas fontes"],
	["três vezes maior", "o Livro II proíbe inventar números"],
	["Volte a |Voltar a ", "frase do diário trocada por \"Volte até\" (D1)"],
]

## Propriedades de cena que aparecem na tela.
const SCENE_TEXT := ["text = ", "message_text = ", "prompt_text = ", "title = "]


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() == ext:
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), ext))
	return out


func _strings(value: Variant, into: Array[String]) -> void:
	if value is String:
		into.append(value)
	elif value is Array:
		for v: Variant in value:
			_strings(v, into)
	elif value is Dictionary:
		for v: Variant in (value as Dictionary).values():
			_strings(v, into)


## [onde, texto] de tudo que o jogador pode ler.
func _visible_texts() -> Array:
	var texts: Array = []
	for path in _files("res://data", "json"):
		var found: Array[String] = []
		_strings(JSON.parse_string(FileAccess.get_file_as_string(path)), found)
		for s in found:
			texts.append([path, s])
	for path in _files("res://scripts", "gd"):
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := line.strip_edges()
			if code.begins_with("#") or not code.contains("\""):
				continue
			texts.append(["%s:%d" % [path, n], code])
	for path in _files("res://scenes", "tscn"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			for prop in SCENE_TEXT:
				if line.begins_with(prop):
					texts.append([path, line])
	return texts


func test_no_player_text_contradicts_the_books() -> void:
	var texts := _visible_texts()
	assert_true(texts.size() > 200, "A varredura encontrou os textos do jogo (%d)" % texts.size())
	for rule: Array in BANNED:
		var re := RegEx.create_from_string(rule[0])
		var hits: Array[String] = []
		for t: Array in texts:
			if re.search(str(t[1])) != null:
				hits.append("%s: %s" % [t[0], str(t[1]).left(90)])
		assert_eq(hits.size(), 0, "%s — %s" % [rule[1], "; ".join(hits.slice(0, 3))])


func test_new_text_has_no_accidental_bbcode() -> void:
	# CM-LA-02: os textos de história e diálogo não trazem colchetes que o RichTextLabel interpretaria.
	var re := RegEx.create_from_string("\\[[^\\]]*\\]")
	for dir in ["res://data/lore", "res://data/story", "res://data/dialogues", "res://data/quests"]:
		for path in _files(dir, "json"):
			var found: Array[String] = []
			_strings(JSON.parse_string(FileAccess.get_file_as_string(path)), found)
			for s in found:
				assert_true(re.search(s) == null, "Colchetes no texto de %s: %s" % [path, s.left(80)])
