class_name CombatToken
extends Node2D
## Representação animada de um combatente na grade (apresentação). A posição do nó fica nos
## pés do personagem. As animações não alteram o estado do combate.

const HP_BACK := Color8(26, 16, 32)
const HP_PARTY := Color8(111, 200, 90)
const HP_ENEMY := Color8(230, 80, 70)
const HP_LOW := Color8(240, 200, 60)

var unit: Combatant
var facing: String = "right"
var downed := false
## PV mostrados na barra; só acompanham o estado real quando a animação de dano acontece.
var shown_hp: int = 0

var _sprite: AnimatedSprite2D


func setup(combatant: Combatant) -> void:
	unit = combatant
	shown_hp = combatant.hp
	facing = "right" if combatant.team == Combatant.Team.PARTY else "left"
	_sprite = AnimatedSprite2D.new()
	SpriteLibrary.attach(_sprite, SpriteLibrary.frames_for_texture(combatant.sprite_key, combatant.sprite_texture)
			if combatant.sprite_texture != null else SpriteLibrary.frames_for(combatant.sprite_path))
	add_child(_sprite)
	play("idle")


## Troca a folha de sprite depois que o combatente muda de aparência (Forma Selvagem).
func reload_sprite() -> void:
	SpriteLibrary.attach(_sprite, SpriteLibrary.frames_for_texture(unit.sprite_key, unit.sprite_texture)
			if unit.sprite_texture != null else SpriteLibrary.frames_for(unit.sprite_path))
	play("idle")


func play(action: String) -> void:
	if _sprite.sprite_frames == null:
		return
	_sprite.play(SpriteLibrary.animation_name(_sprite.sprite_frames, action, facing))


func face_towards(point: Vector2) -> void:
	var delta := point - position
	if absf(delta.x) >= 1.0:
		facing = "right" if delta.x > 0.0 else "left"
	elif _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"idle_down"):
		facing = "down" if delta.y > 0.0 else "up"


func walk_to(point: Vector2, duration: float) -> void:
	face_towards(point)
	play("walk")
	var tween := create_tween()
	tween.tween_property(self, "position", point, duration)
	await tween.finished
	play("idle")


## Investida curta na direção do alvo com a animação de ataque.
func attack_towards(point: Vector2) -> void:
	face_towards(point)
	var origin := position
	var lunge := origin + (point - origin).normalized() * 7.0
	play("attack")
	var tween := create_tween()
	tween.tween_property(self, "position", lunge, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.12)
	tween.tween_property(self, "position", origin, 0.16).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	play("idle")


## Pisca em vermelho e treme ao receber dano; a barra desce para new_hp.
func hurt(new_hp: int) -> void:
	shown_hp = new_hp
	queue_redraw()
	var origin := position
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.8, 0.5, 0.5), 0.06)
	tween.tween_property(self, "position", origin + Vector2(2, 0), 0.04)
	tween.tween_property(self, "position", origin - Vector2(2, 0), 0.04)
	tween.tween_property(self, "position", origin, 0.04)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	await tween.finished


## Personagem caído: tomba e fica acinzentado. Inimigo morto: some.
func fall(dead: bool) -> void:
	downed = true
	_sprite.stop()
	var tween := create_tween()
	tween.tween_property(_sprite, "rotation", PI / 2.0 if facing != "left" else -PI / 2.0, 0.25)
	tween.parallel().tween_property(_sprite, "modulate", Color(0.55, 0.55, 0.6, 0.9), 0.25)
	if dead:
		tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
	if dead:
		visible = false
	queue_redraw()


func refresh(snap_hp: bool = false) -> void:
	if snap_hp:
		shown_hp = unit.hp
	queue_redraw()


func _draw() -> void:
	if unit == null or downed:
		return
	var bar := Rect2(Vector2(-11, 2), Vector2(22, 3))
	draw_rect(bar.grow(1), HP_BACK)
	var ratio := clampf(float(shown_hp) / float(maxi(1, unit.max_hp)), 0.0, 1.0)
	var color := HP_PARTY if unit.team == Combatant.Team.PARTY else HP_ENEMY
	if unit.team == Combatant.Team.PARTY and ratio <= 0.34:
		color = HP_LOW
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), color)
