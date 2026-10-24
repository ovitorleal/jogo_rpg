class_name SpriteLibrary
extends RefCounted
## Monta SpriteFrames a partir das folhas de sprites geradas por tools/art/generate_characters.gd.
## Layout: 9 colunas (0-1 parado, 2-5 caminhada, 6-8 ataque); quadros de 32x32 ou em alta resolução
## (64x64, personagens do CharacterPainter). O tamanho do quadro vem da largura da folha e
## attach() ajusta escala e offset para que todo quadro ocupe 32 px no mundo.
## Folhas com 4 linhas: baixo, esquerda, direita, cima. Com 2 linhas: esquerda, direita.
## Animações: "idle_<dir>", "walk_<dir>", "attack_<dir>".

const FRAME := Vector2i(32, 32)
const COLUMNS := 9
const FOUR_DIRECTIONS: Array[String] = ["down", "left", "right", "up"]
const TWO_DIRECTIONS: Array[String] = ["left", "right"]
const ACTIONS := {
	"idle": {"first": 0, "count": 2, "fps": 2.5, "loop": true},
	"walk": {"first": 2, "count": 4, "fps": 8.0, "loop": true},
	"attack": {"first": 6, "count": 3, "fps": 10.0, "loop": false},
}
## Distância do centro do quadro até os pés (linha 29): use como offset do sprite.
const FEET_OFFSET := Vector2(0, -13)

static var _cache := {}


## Lado do quadro em pixels da textura (32 nas folhas antigas, 64 nas de alta resolução).
static func frame_size_for(texture: Texture2D) -> int:
	return maxi(1, texture.get_width() / COLUMNS)


static func directions_for(texture: Texture2D) -> Array[String]:
	return FOUR_DIRECTIONS if texture.get_height() >= frame_size_for(texture) * 4 else TWO_DIRECTIONS


## Coloca as animações no sprite com escala e offset dos pés corretos para o tamanho do quadro.
## A escala original do nó (definida na cena) é preservada como base.
static func attach(sprite: AnimatedSprite2D, frames: SpriteFrames) -> void:
	if not sprite.has_meta("base_scale"):
		sprite.set_meta("base_scale", sprite.scale)
	var size := float(frames.get_meta("frame_size", FRAME.x))
	var base: Vector2 = sprite.get_meta("base_scale")
	sprite.sprite_frames = frames
	sprite.scale = base * (FRAME.x / size)
	sprite.offset = FEET_OFFSET * (size / FRAME.x)


static func frames_for(sheet_path: String) -> SpriteFrames:
	if _cache.has(sheet_path):
		return _cache[sheet_path]
	var texture: Texture2D = load(sheet_path) if ResourceLoader.exists(sheet_path) else null
	if texture == null:
		push_error("Folha de sprites inexistente: %s" % sheet_path)
		var empty := SpriteFrames.new()
		empty.remove_animation(&"default")
		return empty
	return frames_for_texture(sheet_path, texture)


## Animações a partir de uma textura já carregada ou gerada (ex.: aparência do personagem).
static func frames_for_texture(key: String, texture: Texture2D, cache: bool = true) -> SpriteFrames:
	if cache and _cache.has(key):
		return _cache[key]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var directions := directions_for(texture)
	var size := frame_size_for(texture)
	frames.set_meta("frame_size", size)
	for row in directions.size():
		for action: String in ACTIONS:
			var spec: Dictionary = ACTIONS[action]
			var anim := StringName("%s_%s" % [action, directions[row]])
			frames.add_animation(anim)
			frames.set_animation_speed(anim, spec["fps"])
			frames.set_animation_loop(anim, spec["loop"])
			for i in int(spec["count"]):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(Vector2((int(spec["first"]) + i) * size, row * size), Vector2(size, size))
				frames.add_frame(anim, atlas)
	if cache:
		_cache[key] = frames
	return frames


## Nome da animação para a ação e direção, com fallback para folhas de 2 direções.
static func animation_name(frames: SpriteFrames, action: String, direction: String) -> StringName:
	var wanted := StringName("%s_%s" % [action, direction])
	if frames.has_animation(wanted):
		return wanted
	var horizontal := "left" if direction == "left" else "right"
	return StringName("%s_%s" % [action, horizontal])


## Direção dominante de um vetor ("down", "up", "left", "right").
static func direction_of(vector: Vector2, fallback: String = "down") -> String:
	if vector.length_squared() < 0.0001:
		return fallback
	if absf(vector.x) > absf(vector.y):
		return "right" if vector.x > 0.0 else "left"
	return "down" if vector.y > 0.0 else "up"
