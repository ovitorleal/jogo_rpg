extends SceneTree
## Gera as folhas de sprites animadas dos personagens (arte original, desenhada por código).
## Uso: godot --headless --path . --script res://tools/art/generate_characters.gd
##
## Layout (quadros 32x32, pivô nos pés na linha 29):
##   colunas: 0-1 parado · 2-5 caminhada · 6-8 ataque (preparação, golpe, recuperação)
##   humanoides: linhas baixo, esquerda, direita, cima · lobo: linhas esquerda, direita

const FRAME := 32
const COLUMNS := 9
const HUMANOID_DIRECTIONS := ["down", "left", "right", "up"]
const BEAST_DIRECTIONS := ["left", "right"]

const OUT_HERO := "res://assets/characters/hero_sheet.png"
const OUT_GOBLIN := "res://assets/enemies/goblin_sheet.png"
const OUT_WOLF := "res://assets/enemies/wolf_sheet.png"
const OUT_PORTRAIT := "res://assets/portraits/hero_portrait.png"
const OUT_AMARA := "res://assets/characters/npc_amara_sheet.png"
const OUT_AMARA_PORTRAIT := "res://assets/portraits/amara_portrait.png"

var HERO := {
	"skin": PixelCanvas.ramp("#b8694a", "#f0ac84", "#ffd6b4"),
	"hair": PixelCanvas.ramp("#4a2416", "#8a4424", "#c87442"),
	"tunic": PixelCanvas.ramp("#22386e", "#3a66bc", "#6ea2f2"),
	"cape": PixelCanvas.ramp("#6e1a28", "#b42e3c", "#ea5c5c"),
	"pants": PixelCanvas.ramp("#2e2644", "#4e4472", "#7268a0"),
	"leather": PixelCanvas.ramp("#36200f", "#6a4024", "#9c6a3c"),
	"metal": PixelCanvas.ramp("#5c6a84", "#b4c4da", "#f2f8ff"),
	"gold": PixelCanvas.ramp("#86560e", "#d09c2c", "#ffe27a"),
	"eye": PixelCanvas.hex("#1a1020"),
	"has_hair": true,
	"has_cape": true,
	"ears": false,
	"y_shift": 0,
	"curved_blade": false,
}

var AMARA := {
	"skin": PixelCanvas.ramp("#7a4a30", "#b8805a", "#e0b08a"),
	"hair": PixelCanvas.ramp("#1a1010", "#3a2420", "#6a4436"),
	"tunic": PixelCanvas.ramp("#1e4a2e", "#2f7a46", "#58b070"),
	"cape": PixelCanvas.ramp("#3c2414", "#74482a", "#a8723e"),
	"pants": PixelCanvas.ramp("#2a2a30", "#4a4a56", "#70707e"),
	"leather": PixelCanvas.ramp("#36200f", "#6a4024", "#9c6a3c"),
	"metal": PixelCanvas.ramp("#5c6a84", "#b4c4da", "#f2f8ff"),
	"gold": PixelCanvas.ramp("#86560e", "#d09c2c", "#ffe27a"),
	"eye": PixelCanvas.hex("#1a1020"),
	"has_hair": true,
	"has_cape": true,
	"ears": false,
	"y_shift": 0,
	"curved_blade": false,
}

var GOBLIN := {
	"skin": PixelCanvas.ramp("#2e5a1c", "#62a034", "#a6dc5e"),
	"hair": PixelCanvas.ramp("#2e5a1c", "#62a034", "#a6dc5e"),
	"tunic": PixelCanvas.ramp("#3c2414", "#74482a", "#a8723e"),
	"cape": PixelCanvas.ramp("#3c2414", "#74482a", "#a8723e"),
	"pants": PixelCanvas.ramp("#2a2a30", "#4a4a56", "#70707e"),
	"leather": PixelCanvas.ramp("#2a1a0e", "#55361e", "#7e5630"),
	"metal": PixelCanvas.ramp("#5a6070", "#a8b0c0", "#e4eaf4"),
	"gold": PixelCanvas.ramp("#5a3a10", "#8a6a2a", "#b89a50"),
	"eye": PixelCanvas.hex("#ffd23a"),
	"has_hair": false,
	"has_cape": false,
	"ears": true,
	"y_shift": 2,
	"curved_blade": true,
}

const SLASH := Color(1.0, 1.0, 0.92, 0.85)
const SLASH_FADE := Color(0.7, 0.9, 1.0, 0.45)


func _initialize() -> void:
	var ok := _save(_humanoid_sheet(HERO), OUT_HERO)
	ok = ok and _save(_humanoid_sheet(GOBLIN), OUT_GOBLIN)
	ok = ok and _save(_wolf_sheet(), OUT_WOLF)
	ok = ok and _save(_portrait(HERO, "#3a6ec0"), OUT_PORTRAIT)
	ok = ok and _save(_humanoid_sheet(AMARA), OUT_AMARA)
	ok = ok and _save(_portrait(AMARA, "#4a8a3a"), OUT_AMARA_PORTRAIT)
	quit(0 if ok else 1)


func _save(image: Image, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	if err != OK:
		push_error("Falha ao salvar %s: %s" % [path, error_string(err)])
		return false
	print("Gerado: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	return true


# --- Humanoides ---------------------------------------------------------------

func _humanoid_sheet(look: Dictionary) -> Image:
	var sheet := Image.create_empty(FRAME * COLUMNS, FRAME * HUMANOID_DIRECTIONS.size(), false, Image.FORMAT_RGBA8)
	for row in HUMANOID_DIRECTIONS.size():
		var direction: String = HUMANOID_DIRECTIONS[row]
		for column in COLUMNS:
			var frame := _humanoid_frame(look, "right" if direction == "left" else direction, column)
			sheet.blend_rect(frame.image, Rect2i(0, 0, FRAME, FRAME), Vector2i(column * FRAME, row * FRAME)) \
					if direction != "left" else _blit_flipped(sheet, frame.image, column * FRAME, row * FRAME)
	return sheet


func _blit_flipped(sheet: Image, frame: Image, ox: int, oy: int) -> void:
	var flipped := frame.duplicate() as Image
	flipped.flip_x()
	sheet.blend_rect(flipped, Rect2i(0, 0, FRAME, FRAME), Vector2i(ox, oy))


## Pose do quadro: deslocamentos de pernas/braços, balanço do corpo e ângulo da arma.
func _pose(direction: String, column: int) -> Dictionary:
	var pose := {"bob": 0, "leg_a": Vector2i.ZERO, "leg_b": Vector2i.ZERO, "lift_a": 0, "lift_b": 0,
			"arm_a": Vector2i.ZERO, "arm_b": Vector2i.ZERO, "lean": 0, "weapon": "rest", "slash": false}
	if column == 1:
		pose["bob"] = 1
	elif column >= 2 and column <= 5:
		var step := column - 2
		var side := direction == "right"
		match step:
			0:
				pose["leg_a"] = Vector2i(2, 0) if side else Vector2i.ZERO
				pose["leg_b"] = Vector2i(-2, 0) if side else Vector2i.ZERO
				pose["lift_b"] = 0 if side else 2
				pose["arm_a"] = Vector2i(-1, 0) if side else Vector2i(0, 1)
				pose["arm_b"] = Vector2i(0, -1)
			1:
				pose["bob"] = -1
				pose["lift_b"] = 1
			2:
				pose["leg_a"] = Vector2i(-2, 0) if side else Vector2i.ZERO
				pose["leg_b"] = Vector2i(2, 0) if side else Vector2i.ZERO
				pose["lift_a"] = 0 if side else 2
				pose["arm_a"] = Vector2i(1, 0) if side else Vector2i(0, -1)
				pose["arm_b"] = Vector2i(0, 1)
			3:
				pose["bob"] = -1
				pose["lift_a"] = 1
	elif column >= 6:
		pose["weapon"] = ["windup", "strike", "recover"][column - 6]
		pose["lean"] = [-1, 1, 0][column - 6]
		pose["slash"] = column == 7
		pose["leg_a"] = Vector2i(1, 0) if direction == "right" and column == 7 else Vector2i.ZERO
	return pose


func _humanoid_frame(look: Dictionary, direction: String, column: int) -> PixelCanvas:
	var c := PixelCanvas.new(FRAME, FRAME)
	var pose := _pose(direction, column)
	var ys: int = look["y_shift"]
	var bob: int = pose["bob"] + ys
	var lean: int = pose["lean"]
	var lean_x := lean if direction == "right" else 0
	var lean_y := lean if direction == "down" else (-lean if direction == "up" else 0)
	var weapon_behind := direction == "up"

	if weapon_behind:
		_draw_weapon(c, look, direction, pose, bob + lean_y, lean_x)

	# Capa atrás do corpo (frente e lado).
	if look["has_cape"] and direction != "up":
		var cape := c.new_mask()
		if direction == "down":
			c.mask_rect(cape, 10, 15 + bob, 12, 9)
		else:
			c.mask_rect(cape, 10 + lean_x, 15 + bob, 4, 10)
			c.mask_rect(cape, 9 + lean_x, 21 + bob, 3, 4)
		c.paint_part(cape, look["cape"])

	# Pernas (a perna "b" fica atrás na vista lateral).
	var legs := []
	if direction == "right":
		legs = [[Vector2i(14, 22) + pose["leg_b"], pose["lift_b"], true], [Vector2i(16, 22) + pose["leg_a"], pose["lift_a"], false]]
	else:
		legs = [[Vector2i(12, 22) + pose["leg_a"], pose["lift_a"], false], [Vector2i(17, 22) + pose["leg_b"], pose["lift_b"], false]]
	for leg: Array in legs:
		var origin: Vector2i = leg[0] + Vector2i(0, ys)
		var lift: int = leg[1]
		var back: bool = leg[2]
		var pants := c.new_mask()
		c.mask_rect(pants, origin.x, origin.y, 3, 4 - lift)
		c.paint_part(pants, _darker(look["pants"]) if back else look["pants"])
		var boot := c.new_mask()
		c.mask_rect(boot, origin.x, origin.y + 4 - lift, 3, 3)
		if direction == "right":
			c.mask_rect(boot, origin.x + 3, origin.y + 6 - lift, 1, 1)
		c.paint_part(boot, _darker(look["leather"]) if back else look["leather"])

	# Tronco com cinto.
	var torso := c.new_mask()
	if direction == "right":
		c.mask_rect(torso, 13 + lean_x, 14 + bob, 7, 9)
	else:
		c.mask_rect(torso, 11, 14 + bob + lean_y, 10, 9)
		c.mask_rect(torso, 12, 13 + bob + lean_y, 8, 1)
	c.paint_part(torso, look["tunic"], 1, 1)
	var belt := c.new_mask()
	if direction == "right":
		c.mask_rect(belt, 13 + lean_x, 20 + bob, 7, 2)
	else:
		c.mask_rect(belt, 11, 20 + bob + lean_y, 10, 2)
	c.paint_part(belt, look["leather"])
	if direction != "up":
		var buckle_x := 18 + lean_x if direction == "right" else 15
		c.set_px(buckle_x, 20 + bob + lean_y, look["gold"][2])
		c.set_px(buckle_x + 1, 20 + bob + lean_y, look["gold"][1])
		c.set_px(buckle_x, 21 + bob + lean_y, look["gold"][1])
		c.set_px(buckle_x + 1, 21 + bob + lean_y, look["gold"][0])

	# Capa por cima nas costas.
	if look["has_cape"] and direction == "up":
		var back_cape := c.new_mask()
		c.mask_rect(back_cape, 10, 14 + bob + lean_y, 12, 11)
		c.mask_rect(back_cape, 11, 25 + bob + lean_y, 10, 1)
		c.paint_part(back_cape, look["cape"], 1, 2)

	# Braços (com mãos).
	var arms := []
	if direction == "right":
		arms = [Vector2i(15 + lean_x, 15) + pose["arm_a"]]
	else:
		arms = [Vector2i(9, 15 + lean_y) + pose["arm_a"], Vector2i(21, 15 + lean_y) + pose["arm_b"]]
	for arm_origin: Vector2i in arms:
		var arm := c.new_mask()
		c.mask_rect(arm, arm_origin.x, arm_origin.y + bob, 2 if direction != "right" else 3, 5)
		c.paint_part(arm, look["tunic"])
		var hand := c.new_mask()
		c.mask_rect(hand, arm_origin.x, arm_origin.y + 5 + bob, 2 if direction != "right" else 3, 2)
		c.paint_part(hand, look["skin"])

	_draw_head(c, look, direction, bob + lean_y, lean_x)

	if not weapon_behind:
		_draw_weapon(c, look, direction, pose, bob + lean_y, lean_x)

	c.outline()
	if pose["slash"]:
		_draw_slash(c, direction, bob)
	c.shadow(16, 29.5, 7, 2)
	return c


func _draw_head(c: PixelCanvas, look: Dictionary, direction: String, bob: int, lean_x: int) -> void:
	var cx := 16.0 + (0.5 + lean_x if direction == "right" else 0.0)
	var cy := 8.5 + bob
	if look["ears"]:
		var ears := c.new_mask()
		for i in 4:
			if direction != "right":
				c.mask_rect(ears, 6 + i, 8 + bob - i / 2, 3 - i / 2, 2)
				c.mask_rect(ears, 24 - i, 8 + bob - i / 2, 3 - i / 2, 2)
			else:
				c.mask_rect(ears, 11 - i + lean_x, 8 + bob - i / 2, 3 - i / 2, 2)
		c.paint_part(ears, look["skin"])
	var head := c.new_mask()
	c.mask_ellipse(head, cx, cy, 6.0, 5.5)
	c.paint_part(head, look["skin"], 1, 1)

	if look["has_hair"]:
		var hair := c.new_mask()
		for y in range(c.height):
			for x in range(c.width):
				if not c.mask_get(head, x, y):
					continue
				var top := y < cy - 1.5
				var sides := (x <= 11 or x >= 20) and y < cy + 2.5 and direction == "down"
				var back := direction == "up"
				var profile := direction == "right" and (x < cx - 1.0 or y < cy - 1.5)
				if top or sides or back or profile:
					c.mask_set(hair, x, y)
		# Franja e mechas.
		if direction == "down":
			c.mask_rect(hair, 13, int(cy) - 2, 2, 1)
			c.mask_rect(hair, 18, int(cy) - 2, 1, 1)
		c.paint_part(hair, look["hair"], 1, 1)

	var eye: Color = look["eye"]
	var ey := int(cy) + 1
	match direction:
		"down":
			for ex in [13, 18]:
				c.set_px(ex, ey, eye)
				c.set_px(ex, ey + 1, eye)
				c.set_px(ex + 1, ey, Color.WHITE if not look["ears"] else eye)
			c.set_px(15, ey + 3, look["skin"][0])
			c.set_px(16, ey + 3, look["skin"][0])
			c.set_px(12, ey + 2, look["skin"][2].lerp(look["cape"][2], 0.4))
			c.set_px(20, ey + 2, look["skin"][2].lerp(look["cape"][2], 0.4))
		"right":
			c.set_px(19 + lean_x, ey, eye)
			c.set_px(19 + lean_x, ey + 1, eye)
			c.set_px(22 + lean_x, ey + 1, look["skin"][1])
			c.set_px(20 + lean_x, ey + 3, look["skin"][0])
			if look["ears"]:
				for nx in range(22, 25):
					c.set_px(nx + lean_x, ey + 1, look["skin"][1])
				c.set_px(24 + lean_x, ey + 2, look["skin"][0])


func _draw_weapon(c: PixelCanvas, look: Dictionary, direction: String, pose: Dictionary, bob: int, lean_x: int) -> void:
	var state: String = pose["weapon"]
	var hand := Vector2(22, 21 + bob)
	var angle := 100.0
	match direction:
		"right":
			hand = Vector2(17 + lean_x, 21 + bob) + Vector2(pose["arm_a"])
			angle = {"rest": 70.0, "windup": -125.0, "strike": -5.0, "recover": 40.0}[state]
			if state == "windup":
				hand = Vector2(14, 15 + bob)
			elif state == "strike":
				hand = Vector2(20 + lean_x, 18 + bob)
		"down":
			hand = Vector2(22, 21 + bob) + Vector2(pose["arm_b"])
			angle = {"rest": 95.0, "windup": -75.0, "strike": 100.0, "recover": 140.0}[state]
			if state == "windup":
				hand = Vector2(22, 13 + bob)
			elif state == "strike":
				hand = Vector2(18, 22 + bob)
		"up":
			hand = Vector2(22, 20 + bob) + Vector2(pose["arm_b"])
			angle = {"rest": 95.0, "windup": -100.0, "strike": -90.0, "recover": -40.0}[state]
			if state == "strike":
				hand = Vector2(17, 11 + bob)
	var direction_vec := Vector2.RIGHT.rotated(deg_to_rad(angle))
	var blade_length := 9.0 if state == "rest" else 10.0
	var tip := hand + direction_vec * blade_length
	var blade := c.new_mask()
	c.mask_line(blade, hand + direction_vec * 2.0, tip, 1)
	if look["curved_blade"]:
		var normal := direction_vec.rotated(PI / 2.0)
		c.mask_line(blade, hand + direction_vec * 5.0 + normal, tip + normal * 1.5, 1)
	else:
		c.mask_line(blade, hand + direction_vec * 2.0 + direction_vec.rotated(PI / 2.0), tip - direction_vec, 1)
	c.paint_part(blade, look["metal"])
	var guard := c.new_mask()
	var cross := direction_vec.rotated(PI / 2.0)
	c.mask_line(guard, hand + direction_vec * 1.5 - cross * 1.5, hand + direction_vec * 1.5 + cross * 1.5, 1)
	c.paint_part(guard, look["gold"])
	var grip := c.new_mask()
	c.mask_line(grip, hand - direction_vec, hand + direction_vec * 0.5, 1)
	c.paint_part(grip, look["leather"])


## Rastro do golpe: arco semitransparente, sem contorno.
func _draw_slash(c: PixelCanvas, direction: String, bob: int) -> void:
	var center := Vector2(16, 18 + bob)
	var from := -60.0
	var to := 60.0
	match direction:
		"down":
			center = Vector2(16, 20 + bob)
			from = 20.0
			to = 160.0
		"up":
			center = Vector2(16, 12 + bob)
			from = -160.0
			to = -20.0
	for i in 40:
		var a := deg_to_rad(lerpf(from, to, i / 39.0))
		for r in [12.0, 13.0]:
			var p: Vector2 = center + Vector2.RIGHT.rotated(a) * r
			c.blend_px(int(p.x), int(p.y), SLASH if r == 12.0 else SLASH_FADE)


static func _darker(ramp: Array) -> Array:
	return [ramp[0].darkened(0.25), ramp[0], ramp[1].darkened(0.15)]


# --- Lobo ---------------------------------------------------------------------

func _wolf_sheet() -> Image:
	var sheet := Image.create_empty(FRAME * COLUMNS, FRAME * BEAST_DIRECTIONS.size(), false, Image.FORMAT_RGBA8)
	for column in COLUMNS:
		var frame := _wolf_frame(column).image
		_blit_flipped(sheet, frame, column * FRAME, 0)
		sheet.blend_rect(frame, Rect2i(0, 0, FRAME, FRAME), Vector2i(column * FRAME, FRAME))
	return sheet


func _wolf_frame(column: int) -> PixelCanvas:
	var c := PixelCanvas.new(FRAME, FRAME)
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


# --- Retrato --------------------------------------------------------------------

## Retrato 32x32 (rosto e ombros), mesmo estilo dos sprites; exibido em 2x.
func _portrait(look: Dictionary, iris: String) -> Image:
	var c := PixelCanvas.new(32, 32)
	for y in 32:
		for x in 32:
			var d := Vector2(x, y).distance_to(Vector2(16, 12))
			c.set_px(x, y, PixelCanvas.hex("#2b2340").lerp(PixelCanvas.hex("#4a3c6a"), clampf(1.0 - d / 18.0, 0.0, 1.0)))
	var bg := c.image.duplicate() as Image
	var figure := PixelCanvas.new(32, 32)
	var cape := figure.new_mask()
	figure.mask_ellipse(cape, 16, 33, 15, 9)
	figure.paint_part(cape, look["cape"], 1, 1)
	var tunic := figure.new_mask()
	figure.mask_ellipse(tunic, 16, 33, 9, 9)
	figure.paint_part(tunic, look["tunic"], 1, 1)
	var neck := figure.new_mask()
	figure.mask_rect(neck, 13, 19, 6, 5)
	figure.paint_part(neck, look["skin"])
	var head := figure.new_mask()
	figure.mask_ellipse(head, 16, 13, 7.5, 8.5)
	figure.paint_part(head, look["skin"], 1, 2)
	var hair := figure.new_mask()
	for y in 32:
		for x in 32:
			if figure.mask_get(head, x, y) and (y < 9 or ((x <= 10 or x >= 22) and y < 15)):
				figure.mask_set(hair, x, y)
	figure.mask_rect(hair, 11, 9, 4, 2)
	figure.mask_rect(hair, 17, 9, 2, 1)
	figure.mask_ellipse(hair, 16, 6, 8.5, 4)
	figure.paint_part(hair, look["hair"], 1, 1)
	for ex in [12, 18]:
		figure.set_px(ex, 13, Color.WHITE)
		figure.set_px(ex + 1, 13, look["eye"])
		figure.set_px(ex + 1, 14, look["eye"])
		figure.set_px(ex, 14, PixelCanvas.hex(iris))
		figure.set_px(ex, 12, look["hair"][0])
		figure.set_px(ex + 1, 12, look["hair"][0])
	figure.set_px(15, 16, look["skin"][0])
	figure.set_px(16, 17, look["skin"][0])
	for mx in range(14, 18):
		figure.set_px(mx, 19, PixelCanvas.hex("#a8504a"))
	figure.set_px(11, 16, look["skin"][2].lerp(look["cape"][2], 0.5))
	figure.set_px(21, 16, look["skin"][2].lerp(look["cape"][2], 0.5))
	var clasp := figure.new_mask()
	figure.mask_rect(clasp, 15, 25, 2, 2)
	figure.paint_part(clasp, look["gold"])
	figure.outline()
	c.blit(figure.image, 0, 0)
	return c.image
