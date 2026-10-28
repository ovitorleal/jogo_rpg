class_name Appearance
extends RefCounted
## Aparência modular do personagem: resolve escolhas (com padrões da espécie), valida contra
## o perfil da espécie (data/appearance/), sorteia combinações e gera/guarda em cache as
## texturas (folha animada e retrato) desenhadas pelo CharacterPainter.
## Com a arte de As Crônicas de Arghaz, o personagem usa a ilustração da classe (ou a "figure" do
## companheiro) como sprite e um recorte do busto como retrato; o CharacterPainter fica de reserva.

const COLOR_KEYS := {"skin": "skin_tones", "hair_color": "hair_colors"}
const FIXED_COLOR_COUNTS := {"eye_color": 8, "outfit": 8, "cloak_color": 5}

const MAX_CACHED := 48
const FIGURE_DIR := "res://assets/characters/arghaz"
## Parte de cima da ilustração usada como retrato (busto).
const PORTRAIT_FRACTION := 0.42

static var _sheet_cache := {}
static var _portrait_cache := {}


static func profile_for(species_id: String, registry: ContentRegistry) -> Dictionary:
	return registry.get_entry("appearance", species_id.replace("species.", "appearance."))


## Aparência completa: escolhas salvas + padrão da espécie para o que faltar.
static func resolve(c: CharacterData, registry: ContentRegistry) -> Dictionary:
	var profile := profile_for(c.species_id, registry)
	var look := CharacterPainter.default_appearance(profile)
	for key: String in c.appearance:
		look[key] = c.appearance[key]
	return look


## Erros nas escolhas de aparência para a espécie do personagem.
static func validate(c: CharacterData, registry: ContentRegistry) -> Array[String]:
	var errors: Array[String] = []
	var profile := profile_for(c.species_id, registry)
	if profile.is_empty():
		return ["Sem perfil de aparência para %s" % c.species_id]
	for key: String in c.appearance:
		var value: Variant = c.appearance[key]
		if CharacterPainter.PARTS.has(key):
			if not str(value) in profile.get(key, CharacterPainter.PARTS[key]):
				errors.append("Aparência: '%s' não é opção de %s para esta espécie" % [str(value), key])
		elif COLOR_KEYS.has(key):
			var count: int = profile.get(COLOR_KEYS[key], []).size()
			if not (value is int or value is float) or int(value) < 0 or int(value) >= count:
				errors.append("Aparência: índice de cor inválido em %s" % key)
		elif FIXED_COLOR_COUNTS.has(key):
			if not (value is int or value is float) or int(value) < 0 or int(value) >= FIXED_COLOR_COUNTS[key]:
				errors.append("Aparência: índice inválido em %s" % key)
		else:
			errors.append("Aparência: campo desconhecido '%s'" % key)
	return errors


## Combinação aleatória válida para a espécie (barba só no corpo masculino).
static func random_look(profile: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var look := {}
	for category: String in CharacterPainter.PARTS:
		var options: Array = profile.get(category, CharacterPainter.PARTS[category])
		look[category] = options[rng.randi_range(0, options.size() - 1)]
	if look.get("body") == "feminine" and "none" in profile.get("beard", ["none"]):
		look["beard"] = "none"
	for key: String in COLOR_KEYS:
		look[key] = rng.randi_range(0, maxi(0, profile.get(COLOR_KEYS[key], []).size() - 1))
	for key: String in FIXED_COLOR_COUNTS:
		look[key] = rng.randi_range(0, FIXED_COLOR_COUNTS[key] - 1)
	return look


## Ilustração do personagem: a "figure" do companheiro ou a da classe. null = sem ilustração.
static func figure_path(c: CharacterData, registry: ContentRegistry) -> String:
	var companion := CompanionRoster.companion_id_of(c)
	if not companion.is_empty():
		var figure := str(registry.get_entry("companion", companion).get("figure", ""))
		if not figure.is_empty():
			return "%s/%s.png" % [FIGURE_DIR, figure]
	return class_figure_path(c.class_id)


static func class_figure_path(class_id: String) -> String:
	return "%s/class_%s.png" % [FIGURE_DIR, class_id.trim_prefix("class.")]


static func species_figure_path(species_id: String) -> String:
	return "%s/species_%s.png" % [FIGURE_DIR, species_id.trim_prefix("species.")]


static func figure_texture(c: CharacterData, registry: ContentRegistry) -> Texture2D:
	var path := figure_path(c, registry)
	return load(path) if ResourceLoader.exists(path) else null


## Busto (parte de cima) de uma ilustração, para retratos.
static func bust_of(figure: Texture2D) -> Texture2D:
	var key := "bust:%s" % figure.resource_path
	if not _portrait_cache.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = figure
		var size := figure.get_size()
		var side := minf(size.x, size.y * PORTRAIT_FRACTION)
		atlas.region = Rect2((size.x - side) / 2.0, 0.0, side, side)
		_portrait_cache[key] = atlas
	return _portrait_cache[key]


static func sheet_texture(c: CharacterData, registry: ContentRegistry) -> Texture2D:
	var figure := figure_texture(c, registry)
	if figure != null:
		return figure
	var look := resolve(c, registry)
	var gear := CharacterPainter.gear_for(c, registry)
	return sheet_for(look, profile_for(c.species_id, registry), gear)


static func portrait_texture(c: CharacterData, registry: ContentRegistry) -> Texture2D:
	var figure := figure_texture(c, registry)
	if figure != null:
		return bust_of(figure)
	return portrait_for(resolve(c, registry), profile_for(c.species_id, registry), CharacterPainter.gear_for(c, registry))


static func portrait_for(look: Dictionary, profile: Dictionary, gear: Dictionary) -> Texture2D:
	var key := key_of(look, profile, gear)
	if not _portrait_cache.has(key):
		if _portrait_cache.size() >= MAX_CACHED:
			_portrait_cache.clear()
		_portrait_cache[key] = ImageTexture.create_from_image(CharacterPainter.paint_portrait(look, profile, gear))
	return _portrait_cache[key]


static func sheet_for(look: Dictionary, profile: Dictionary, gear: Dictionary) -> Texture2D:
	var key := key_of(look, profile, gear)
	if not _sheet_cache.has(key):
		if _sheet_cache.size() >= MAX_CACHED:
			_sheet_cache.clear()
		_sheet_cache[key] = ImageTexture.create_from_image(CharacterPainter.paint_sheet(look, profile, gear))
	return _sheet_cache[key]


## Chave estável para cache e para a SpriteLibrary.
static func key_for(c: CharacterData, registry: ContentRegistry) -> String:
	if ResourceLoader.exists(figure_path(c, registry)):
		return "figure:%s" % figure_path(c, registry)
	return key_of(resolve(c, registry), profile_for(c.species_id, registry), CharacterPainter.gear_for(c, registry))


static func key_of(look: Dictionary, profile: Dictionary, gear: Dictionary) -> String:
	var keys := look.keys()
	keys.sort()
	var parts := PackedStringArray([str(profile.get("id", "")), JSON.stringify(gear)])
	for k: Variant in keys:
		parts.append("%s=%s" % [k, look[k]])
	return "appearance:%d" % hash("|".join(parts))
