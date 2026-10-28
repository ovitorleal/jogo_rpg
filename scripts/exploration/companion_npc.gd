class_name CompanionNpc
extends Npc
## Companheiro recrutável no mapa (dados em data/companions/). O sprite é pintado em runtime a
## partir da aparência dele; some depois de recrutado e pode exigir um encontro vencido para aparecer
## (ex.: Ignis só fica livre depois de Garra-Rubra). A conversa é a ação "talk:<dialogue_id>".

@export var companion_id: String = ""
## Gatilho de encontro que precisa estar vencido para o companheiro aparecer (vazio = sempre).
@export var required_trigger: String = ""

## Personagens de prévia (nível 1) por companheiro, para pintar o sprite e o retrato só uma vez.
static var _previews: Dictionary = {}


func _ready() -> void:
	super._ready()
	var entry := Content.registry.get_entry("companion", companion_id)
	if entry.is_empty():
		push_error("Companheiro desconhecido: %s" % companion_id)
		return
	action = "talk:%s" % entry["dialogue_id"]
	prompt_text = "Conversar com %s" % str(entry["name"]).get_slice(" ", 0)
	var c := preview(companion_id, Content.registry)
	var sprite := get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite != null and c != null:
		SpriteLibrary.attach(sprite, SpriteLibrary.frames_for_texture(Appearance.key_for(c, Content.registry),
				Appearance.sheet_texture(c, Content.registry)))
		sprite.play(SpriteLibrary.animation_name(sprite.sprite_frames, "idle", facing))
	refresh()


## Personagem de prévia do companheiro (aparência e equipamento inicial).
static func preview(id: String, registry: ContentRegistry) -> CharacterData:
	if not _previews.has(id):
		var entry := registry.get_entry("companion", id)
		_previews[id] = CompanionRoster.build(entry, 1, registry) if not entry.is_empty() else null
	return _previews[id]


## Presente no mapa enquanto não foi recrutado e o encontro exigido (se houver) já foi vencido.
func is_present() -> bool:
	return not PartyManager.roster.is_recruited(companion_id) \
			and (required_trigger.is_empty() or ExplorationManager.is_resolved(required_trigger))


## Mostra ou esconde o companheiro (chamado ao entrar no mapa e depois de cada conversa).
func refresh() -> void:
	var present := is_present()
	visible = present
	enabled = present
	set_deferred("monitorable", present)
	var body_shape := get_node_or_null("Body/Shape") as CollisionShape2D
	if body_shape != null:
		body_shape.set_deferred("disabled", not present)
