class_name SpriteLibrary
extends RefCounted
## Monta SpriteFrames a partir das folhas de sprites geradas por tools/art/generate_characters.gd.
## Layout: quadros 32x32; colunas 0-1 parado, 2-5 caminhada, 6-8 ataque.
## Folhas com 4 linhas: baixo, esquerda, direita, cima. Com 2 linhas: esquerda, direita.
## Animações: "idle_<dir>", "walk_<dir>", "attack_<dir>".

const FRAME := Vector2i(32, 32)
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


static func directions_for(texture: Texture2D) -> Array[String]:
	return FOUR_DIRECTIONS if texture.get_height() >= FRAME.y * 4 else TWO_DIRECTIONS


static func frames_for(sheet_path: String) -> SpriteFrames:
	if _cache.has(sheet_path):
		return _cache[sheet_path]
	var texture: Texture2D = load(sheet_path) if ResourceLoader.exists(sheet_path) else null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	if texture == null:
		push_error("Folha de sprites inexistente: %s" % sheet_path)
		return frames
	var directions := directions_for(texture)
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
				atlas.region = Rect2(Vector2((int(spec["first"]) + i) * FRAME.x, row * FRAME.y), Vector2(FRAME))
				frames.add_frame(anim, atlas)
	_cache[sheet_path] = frames
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
