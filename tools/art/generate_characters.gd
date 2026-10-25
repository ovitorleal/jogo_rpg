extends SceneTree
## Gera as folhas de sprites dos personagens fixos (arte original, desenhada por código).
## Uso: godot --headless --path . --script res://tools/art/generate_characters.gd
##
## Humanoides (herói padrão, Guarda Amara, goblin) usam o mesmo CharacterPainter dos personagens
## jogáveis; o lobo é desenhado aqui. Todos em alta resolução (quadros 64x64, exibidos com 32 px).
## Layout: colunas 0-1 parado · 2-5 caminhada · 6-8 ataque; humanoides com 4 linhas
## (baixo, esquerda, direita, cima), lobo com 2 (esquerda, direita).

const FRAME := 32
const FRAME_PX := FRAME * CharacterPainter.SCALE
const COLUMNS := 9
const BEAST_DIRECTIONS := ["left", "right"]
const APPEARANCE_DATA := "res://data/appearance/species_appearance.json"

const OUT_HERO := "res://assets/characters/hero_sheet.png"
const OUT_GOBLIN := "res://assets/enemies/goblin_sheet.png"
const OUT_WOLF := "res://assets/enemies/wolf_sheet.png"
const OUT_PORTRAIT := "res://assets/portraits/hero_portrait.png"
const OUT_AMARA := "res://assets/characters/npc_amara_sheet.png"
const OUT_AMARA_PORTRAIT := "res://assets/portraits/amara_portrait.png"
const OUT_IONE := "res://assets/characters/npc_ione_sheet.png"
const OUT_IONE_PORTRAIT := "res://assets/portraits/ione_portrait.png"
const OUT_GOBLIN_BOSS := "res://assets/enemies/goblin_boss_sheet.png"

const HERO_LOOK := {"body": "masculine", "hair_style": "short", "skin": 1, "hair_color": 0, "eye_color": 0,
		"outfit": 0, "cloak": "cape", "cloak_color": 0}
const HERO_GEAR := {"armor": "none", "shield": false, "weapon": "sword"}
const AMARA_LOOK := {"body": "feminine", "hair_style": "ponytail", "skin": 3, "hair_color": 2, "eye_color": 1,
		"outfit": 2, "cloak": "cape", "cloak_color": 1}
const AMARA_GEAR := {"armor": "light", "shield": false, "weapon": "spear"}
## Ione, chefe da Vila de Ribeira: senhora de cabelo grisalho em coque, vestido verde e cajado.
const IONE_LOOK := {"body": "feminine", "hair_style": "bun", "skin": 2, "hair_color": 6, "eye_color": 2,
		"outfit": 2, "cloak": "cape", "cloak_color": 2}
const IONE_GEAR := {"armor": "none", "shield": false, "weapon": "staff"}
## Goblin: perfil próprio (não é espécie jogável), baixo e magro, pele verde e orelhas longas.
const GOBLIN_PROFILE := {
	"id": "appearance.goblin", "skin_tones": ["#62a034"], "hair_colors": ["#2e5a1c"],
	"leg_length": 5, "torso_length": 7, "head_radius": 5.5, "width": -1,
}
const GOBLIN_LOOK := {"body": "masculine", "build": "slim", "hair_style": "bald", "ears": "pointed_long",
		"face": "tusks_small", "eye_color": 6, "outfit": 4, "cloak": "none", "beard": "none"}
const GOBLIN_GEAR := {"armor": "light", "shield": false, "weapon": "curved"}
## Garra-Rubra, chefe goblin: camisão de malha, escudo e capa vermelha.
const GOBLIN_BOSS_LOOK := {"body": "masculine", "build": "slim", "hair_style": "mohawk", "ears": "pointed_long",
		"face": "tusks_small", "eye_color": 6, "outfit": 1, "cloak": "cape", "cloak_color": 0, "beard": "none"}
const GOBLIN_BOSS_GEAR := {"armor": "medium", "shield": true, "weapon": "curved"}


func _initialize() -> void:
	var human := _profile("appearance.human")
	var hero := _look(human, HERO_LOOK)
	var amara := _look(human, AMARA_LOOK)
	var goblin := _look(GOBLIN_PROFILE, GOBLIN_LOOK)
	var ok := _save(CharacterPainter.paint_sheet(hero, human, HERO_GEAR), OUT_HERO)
	ok = ok and _save(CharacterPainter.paint_sheet(goblin, GOBLIN_PROFILE, GOBLIN_GEAR), OUT_GOBLIN)
	ok = ok and _save(_wolf_sheet(), OUT_WOLF)
	ok = ok and _save(CharacterPainter.paint_portrait(hero, human, HERO_GEAR), OUT_PORTRAIT)
	ok = ok and _save(CharacterPainter.paint_sheet(amara, human, AMARA_GEAR), OUT_AMARA)
	ok = ok and _save(CharacterPainter.paint_portrait(amara, human, AMARA_GEAR), OUT_AMARA_PORTRAIT)
	var ione := _look(human, IONE_LOOK)
	ok = ok and _save(CharacterPainter.paint_sheet(ione, human, IONE_GEAR), OUT_IONE)
	ok = ok and _save(CharacterPainter.paint_portrait(ione, human, IONE_GEAR), OUT_IONE_PORTRAIT)
	var boss := _look(GOBLIN_PROFILE, GOBLIN_BOSS_LOOK)
	ok = ok and _save(CharacterPainter.paint_sheet(boss, GOBLIN_PROFILE, GOBLIN_BOSS_GEAR), OUT_GOBLIN_BOSS)
	quit(0 if ok else 1)


func _profile(id: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(APPEARANCE_DATA))
	for entry: Dictionary in data["entries"]:
		if entry["id"] == id:
			return entry
	push_error("Perfil de aparência inexistente: %s" % id)
	return {}


func _look(profile: Dictionary, overrides: Dictionary) -> Dictionary:
	var look := CharacterPainter.default_appearance(profile)
	look.merge(overrides, true)
	return look


func _save(image: Image, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [path, error_string(err)])
		return false
	print("Gerado: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	return true


func _blit_flipped(sheet: Image, frame: Image, ox: int, oy: int) -> void:
	var flipped := frame.duplicate() as Image
	flipped.flip_x()
	sheet.blend_rect(flipped, Rect2i(0, 0, FRAME_PX, FRAME_PX), Vector2i(ox, oy))


# --- Lobo -----------------------------------------------------------------------

func _wolf_sheet() -> Image:
	var sheet := Image.create_empty(FRAME_PX * COLUMNS, FRAME_PX * BEAST_DIRECTIONS.size(), false, Image.FORMAT_RGBA8)
	for column in COLUMNS:
		var frame := _wolf_frame(column).image
		_blit_flipped(sheet, frame, column * FRAME_PX, 0)
		sheet.blend_rect(frame, Rect2i(0, 0, FRAME_PX, FRAME_PX), Vector2i(column * FRAME_PX, FRAME_PX))
	return sheet


func _wolf_frame(column: int) -> PixelCanvas:
	var c := PixelCanvas.new(FRAME, FRAME, CharacterPainter.SCALE)
	var fur := PixelCanvas.ramp("#3e3e50", "#7e7e94", "#c4c4d6")
	var belly := PixelCanvas.ramp("#7e7e94", "#b8b8c8", "#e6e6f0")
	var dark := PixelCanvas.ramp("#24242e", "#3e3e50", "#5a5a6c")
	var bob := 0
	var dx := 0
	var head_drop := 0
	var mouth_open := false
	var legs := [0, 0, 0, 0]  # deslocamento x de cada pata: tras-longe, tras-perto, frente-longe, frente-perto
	if column == 1:
		bob = 1
	elif column >= 2 and column <= 5:
		var cycle := [[2, -2, -2, 2], [0, 0, 0, 0], [-2, 2, 2, -2], [0, 0, 0, 0]]
		legs = cycle[column - 2]
		bob = 0 if (column - 2) % 2 == 0 else -1
	elif column == 6:
		bob = 1
		dx = -1
		head_drop = 1
	elif column == 7:
		dx = 3
		head_drop = -1
		mouth_open = true
		legs = [-2, -2, 2, 2]
	elif column == 8:
		dx = 1

	# Cauda.
	var tail := c.new_mask()
	c.mask_line(tail, Vector2(7 + dx, 17 + bob), Vector2(2 + dx, 20 + bob), 3)
	c.mask_line(tail, Vector2(2 + dx, 20 + bob), Vector2(1 + dx, 23 + bob), 2)
	c.paint_part(tail, fur)

	# Patas do lado de longe (mais escuras).
	for i in [0, 2]:
		var x: int = (9 if i == 0 else 20) + dx + legs[i]
		var leg := c.new_mask()
		c.mask_rect(leg, x, 21 + bob, 2, 7 - bob)
		c.paint_part(leg, dark)

	# Corpo e barriga.
	var body := c.new_mask()
	c.mask_ellipse(body, 15.0 + dx, 18.5 + bob, 9.5, 4.5)
	c.mask_ellipse(body, 21.0 + dx, 17.0 + bob, 4.5, 4.5)
	c.paint_part(body, fur, 1, 1)
	var under := c.new_mask()
	c.mask_ellipse(under, 16.0 + dx, 21.5 + bob, 6.5, 1.5)
	c.paint_part(under, belly)
	# Listras do dorso.
	for sx in [11, 14, 17]:
		c.set_px(sx + dx, 14 + bob, fur[0])
		c.set_px(sx + dx + 1, 15 + bob, fur[0])

	# Patas do lado de perto.
	for i in [1, 3]:
		var x: int = (11 if i == 1 else 22) + dx + legs[i]
		var leg := c.new_mask()
		c.mask_rect(leg, x, 21 + bob, 2, 7 - bob)
		c.mask_rect(leg, x, 27, 3, 1)
		c.paint_part(leg, fur)

	# Cabeça, orelhas e focinho.
	var hy := 13 + bob + head_drop
	var ears := c.new_mask()
	for i in 4:
		c.mask_rect(ears, 22 + dx + i / 2, hy - 5 + i, 3 - i / 2, 1)
		c.mask_rect(ears, 25 + dx + i / 2, hy - 5 + i, 3 - i / 2, 1)
	c.paint_part(ears, fur)
	var head := c.new_mask()
	c.mask_ellipse(head, 24.5 + dx, hy + 0.5, 4.0, 3.5)
	c.mask_rect(head, 26 + dx, hy + 1, 5, 2 if not mouth_open else 1)
	c.mask_rect(head, 27 + dx, hy + 3, 3, 1 if not mouth_open else 0)
	c.paint_part(head, fur, 1, 1)
	if mouth_open:
		var jaw := c.new_mask()
		c.mask_rect(jaw, 27 + dx, hy + 3, 4, 1)
		c.paint_part(jaw, fur)
		for tx in [28, 30]:
			c.set_px(tx + dx, hy + 2, Color.WHITE)
		c.set_px(29 + dx, hy + 2, PixelCanvas.hex("#c03040"))
	c.set_px(30 + dx, hy + 1, PixelCanvas.hex("#1a1020"))
	c.set_px(25 + dx, hy, PixelCanvas.hex("#ffd23a"))
	c.set_px(26 + dx, hy, PixelCanvas.hex("#1a1020"))
	c.set_px(25 + dx, hy - 1, fur[0])
	c.set_px(26 + dx, hy - 1, fur[0])

	c.outline()
	c.shadow(16 + dx, 29.0, 11, 2)
	return c
