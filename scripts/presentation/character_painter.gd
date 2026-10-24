class_name CharacterPainter
extends RefCounted
## Desenha personagens modulares (arte original, gerada por código) a partir de:
## - perfil da espécie (proporções e paletas, de data/appearance/),
## - aparência escolhida (corpo, porte, pele, cabelo, olhos, barba, orelhas, chifres, cauda,
##   marcas, rosto, acessório, capa e cor da roupa),
## - equipamento visível (armadura, escudo, tipo de arma).
## Saídas: folha 9x4 de quadros (layout da SpriteLibrary) e retrato.
## As formas são descritas na grade lógica de 32 px e pintadas com SCALE pixels reais por pixel
## lógico (PixelCanvas k = SCALE): quadros e retrato de 64x64, exibidos no tamanho de 32 px no mundo.
## As peças da cabeça são posicionadas em relação à elipse do rosto, então o mesmo código
## desenha o sprite (cabeça pequena) e o retrato (cabeça grande).

const FRAME := 32
const SCALE := 2
const FRAME_PX := FRAME * SCALE
const COLUMNS := 9
const DIRECTIONS := ["down", "left", "right", "up"]

## Opções conhecidas por categoria (os dados de cada espécie escolhem um subconjunto).
const PARTS := {
	"body": ["masculine", "feminine"],
	"build": ["slim", "average", "broad"],
	"hair_style": ["bald", "short", "messy", "long", "ponytail", "bun", "braid", "twin_braids", "mohawk",
			"curly", "topknot", "wild"],
	"beard": ["none", "stubble", "mustache", "short", "full", "long", "braided", "forked"],
	"ears": ["round", "pointed_short", "pointed_long", "swept", "small_pointed"],
	"horns": ["none", "ram", "straight", "curved", "nubs", "crest", "frills"],
	"tail": ["none", "thin", "spade", "thick"],
	"marks": ["none", "lines", "spirals", "runes"],
	"face": ["none", "freckles", "tusks_small", "tusks_large", "scar", "blush"],
	"accessory": ["none", "headband", "circlet", "hood", "goggles", "flower", "earrings", "bandana"],
	"cloak": ["none", "cape"],
}

const NAMES := {
	"masculine": "Masculino", "feminine": "Feminino",
	"slim": "Esguio", "average": "Mediano", "broad": "Largo",
	"bald": "Careca", "short": "Curto", "messy": "Bagunçado", "long": "Longo", "ponytail": "Rabo de cavalo",
	"bun": "Coque", "braid": "Trança", "twin_braids": "Duas tranças", "mohawk": "Moicano", "curly": "Cacheado",
	"topknot": "Coque alto", "wild": "Juba",
	"none": "Nenhum", "stubble": "Barba rala", "mustache": "Bigode", "full": "Cheia", "braided": "Trançada",
	"forked": "Bifurcada",
	"round": "Arredondadas", "pointed_short": "Pontudas curtas", "pointed_long": "Pontudas longas",
	"swept": "Para trás", "small_pointed": "Pequenas pontudas",
	"ram": "De carneiro", "straight": "Retos", "curved": "Curvos", "nubs": "Pequenos", "crest": "Crista",
	"frills": "Babados",
	"thin": "Fina", "spade": "Ponta de lança", "thick": "Grossa com escamas",
	"lines": "Linhas", "spirals": "Espirais", "runes": "Runas",
	"freckles": "Sardas", "tusks_small": "Presas pequenas", "tusks_large": "Presas grandes", "scar": "Cicatriz",
	"blush": "Bochechas coradas",
	"headband": "Faixa", "circlet": "Diadema", "hood": "Capuz", "goggles": "Óculos de inventor", "flower": "Flor",
	"earrings": "Brincos", "bandana": "Bandana",
	"cape": "Capa",
}

const OUTFIT_COLORS: Array[String] = ["#3a66bc", "#b42e3c", "#2f7a46", "#6a3ea0", "#7a5a3a", "#5a6070", "#2a8a8a", "#c89a2a"]
const CLOAK_COLORS: Array[String] = ["#b42e3c", "#74482a", "#2f5a3a", "#2e3e7a", "#3a2e44"]
const EYE_COLORS: Array[String] = ["#3a6ec0", "#4a8a3a", "#6a4024", "#8a6a2a", "#7a3aa0", "#c03030", "#e0c040", "#40b0c0"]

const LEATHER := "#6a4024"
const METAL := "#a4b4ca"
const GOLD := "#d09c2c"
const PANTS := "#4a4462"
const HORN := "#d8ccb4"

## Tipo de arma desenhada para cada item.
const WEAPON_KIND := {
	"item.longsword": "sword", "item.shortsword": "sword", "item.scimitar": "curved", "item.rapier": "sword",
	"item.dagger": "dagger", "item.handaxe": "axe", "item.greataxe": "axe", "item.mace": "mace", "item.club": "mace",
	"item.quarterstaff": "staff", "item.spear": "spear", "item.javelin": "spear", "item.sickle": "curved",
	"item.shortbow": "bow", "item.longbow": "bow",
}


# --- Entrada ------------------------------------------------------------------

## Aparência padrão válida para o perfil (primeiras opções de cada categoria).
static func default_appearance(profile: Dictionary) -> Dictionary:
	var result := {"skin": 0, "hair_color": 0, "eye_color": 0, "outfit": 0, "cloak_color": 0}
	for category: String in PARTS:
		var options: Array = profile.get(category, PARTS[category])
		result[category] = options[0] if not options.is_empty() else PARTS[category][0]
	return result


## Equipamento visível a partir de um personagem e do registro de itens.
static func gear_for(c: CharacterData, registry: ContentRegistry) -> Dictionary:
	var armor := registry.get_entry("item", c.armor_id)
	var weapon_kind := "none"
	for weapon_id in c.weapon_ids:
		weapon_kind = WEAPON_KIND.get(weapon_id, "sword")
		break
	return {"armor": armor.get("armor_category", "none"), "shield": not c.shield_id.is_empty(), "weapon": weapon_kind}


## Rampa [sombra, base, luz] com desvio de matiz: sombras puxam para o violeta e ficam mais
## saturadas; luzes puxam para o amarelo quente (estilo 16 bits).
static func ramp_from(hex: String) -> Array:
	var base := Color(hex)
	var dark := base.darkened(0.36).lerp(Color("#2a1846"), 0.2)
	dark = Color.from_hsv(dark.h, clampf(dark.s * 1.12 + 0.04, 0.0, 1.0), dark.v)
	var light := base.lightened(0.3).lerp(Color("#fff2c4"), 0.16)
	light = Color.from_hsv(light.h, clampf(light.s * 0.9, 0.0, 1.0), light.v)
	return [dark, base, light]


# --- Folha ----------------------------------------------------------------------

static func paint_sheet(look: Dictionary, profile: Dictionary, gear: Dictionary) -> Image:
	var sheet := empty_sheet()
	for row in DIRECTIONS.size():
		paint_row(sheet, look, profile, gear, row)
	return sheet


static func empty_sheet() -> Image:
	return Image.create_empty(FRAME_PX * COLUMNS, FRAME_PX * DIRECTIONS.size(), false, Image.FORMAT_RGBA8)


## Pinta uma linha (direção) da folha; permite montar a folha aos poucos sem travar a tela.
static func paint_row(sheet: Image, look: Dictionary, profile: Dictionary, gear: Dictionary, row: int) -> void:
	var palette := _palette(look, profile)
	var direction: String = DIRECTIONS[row]
	for column in COLUMNS:
		var frame := _frame(look, profile, gear, palette, "right" if direction == "left" else direction, column)
		if direction == "left":
			frame.flip_x()
		sheet.blit_rect(frame, Rect2i(0, 0, FRAME_PX, FRAME_PX), Vector2i(column * FRAME_PX, row * FRAME_PX))


static func paint_portrait(look: Dictionary, profile: Dictionary, gear: Dictionary) -> Image:
	var palette := _palette(look, profile)
	var c := PixelCanvas.new(32, 32, SCALE)
	for py in c.ph:
		for px in c.pw:
			var d := Vector2(c.logical(px), c.logical(py)).distance_to(Vector2(16, 12))
			var t := clampf(1.0 - d / 18.0, 0.0, 1.0)
			c.set_fine(px, py, Color("#2b2340").lerp(Color("#4a3c6a"), snappedf(t, 0.125)))
	var figure := PixelCanvas.new(32, 32, SCALE)
	# Ombros: capa, roupa/armadura e pescoço.
	if look.get("cloak", "none") == "cape":
		var cape := figure.new_mask()
		figure.mask_ellipse(cape, 16, 33, 15, 9)
		figure.paint_part(cape, palette["cloak"], 1, 1)
	var chest := figure.new_mask()
	var shoulders := 9.0 + float(profile.get("width", 0)) + (1.0 if look.get("build") == "broad" else (-1.0 if look.get("build") == "slim" else 0.0))
	figure.mask_ellipse(chest, 16, 33, shoulders, 9)
	figure.paint_part(chest, _torso_ramp(gear, palette), 1, 1)
	var neck := figure.new_mask()
	figure.mask_rect(neck, 13, 19, 6, 5)
	figure.paint_part(neck, palette["skin"])
	_head(figure, look, profile, palette, "down", 16.0, 13.0, 7.5, 8.5, 2)
	figure.outline()
	c.blit(figure.image, 0, 0)
	return c.image


static func _palette(look: Dictionary, profile: Dictionary) -> Dictionary:
	var skins: Array = profile.get("skin_tones", ["#f0ac84"])
	var hairs: Array = profile.get("hair_colors", ["#8a4424"])
	return {
		"skin": ramp_from(skins[clampi(int(look.get("skin", 0)), 0, skins.size() - 1)]),
		"hair": ramp_from(hairs[clampi(int(look.get("hair_color", 0)), 0, hairs.size() - 1)]),
		"eye": Color(EYE_COLORS[clampi(int(look.get("eye_color", 0)), 0, EYE_COLORS.size() - 1)]),
		"outfit": ramp_from(OUTFIT_COLORS[clampi(int(look.get("outfit", 0)), 0, OUTFIT_COLORS.size() - 1)]),
		"cloak": ramp_from(CLOAK_COLORS[clampi(int(look.get("cloak_color", 0)), 0, CLOAK_COLORS.size() - 1)]),
		"leather": ramp_from(LEATHER),
		"metal": ramp_from(METAL),
		"gold": ramp_from(GOLD),
		"pants": ramp_from(PANTS),
		"horn": ramp_from(str(profile.get("horn_color", HORN))),
	}


## Proporções do corpo no quadro (pés na linha 28).
static func _layout(look: Dictionary, profile: Dictionary, bob: int) -> Dictionary:
	var leg_len := int(profile.get("leg_length", 7))
	var torso_len := int(profile.get("torso_length", 9))
	var legs_top := 29 - leg_len
	var torso_top := legs_top - torso_len + 1 + bob
	var width := int(profile.get("width", 0)) + (1 if look.get("build") == "broad" else (-1 if look.get("build") == "slim" else 0))
	var head_r := float(profile.get("head_radius", 6.0))
	return {
		"legs_top": legs_top, "leg_len": leg_len, "torso_top": torso_top, "torso_bottom": legs_top + bob,
		"half": 5 + width, "side_half": 3 + maxi(0, width), "arm_len": maxi(3, torso_len - 4),
		"cx": 16.0, "cy": torso_top - head_r + 0.5, "rx": head_r, "ry": head_r - 0.5,
	}


static func _pose(direction: String, column: int) -> Dictionary:
	var pose := {"bob": 0, "leg_a": Vector2i.ZERO, "leg_b": Vector2i.ZERO, "lift_a": 0, "lift_b": 0,
			"arm_a": Vector2i.ZERO, "arm_b": Vector2i.ZERO, "lean": 0, "weapon": "rest", "slash": false}
	if column == 1:
		pose["bob"] = 1
	elif column >= 2 and column <= 5:
		var side := direction == "right"
		match column - 2:
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
	return pose


static func _frame(look: Dictionary, profile: Dictionary, gear: Dictionary, palette: Dictionary, direction: String,
		column: int) -> Image:
	var c := PixelCanvas.new(FRAME, FRAME, SCALE)
	var pose := _pose(direction, column)
	var L := _layout(look, profile, int(pose["bob"]))
	var lean: int = pose["lean"]
	var lean_x := lean if direction == "right" else 0
	var lean_y := lean if direction == "down" else (-lean if direction == "up" else 0)
	var feminine: bool = look.get("body") == "feminine"
	var torso_ramp := _torso_ramp(gear, palette)
	var arm_ramp: Array = palette["metal"] if gear.get("armor") in ["medium", "heavy"] else palette["outfit"]

	if direction == "up":
		_weapon(c, gear, palette, direction, pose, L, lean_x, lean_y)

	# Cauda atrás do corpo (frente e lado).
	if direction != "up":
		_tail(c, look, palette, direction, L)

	# Capa atrás do corpo.
	if look.get("cloak", "none") == "cape" and direction != "up":
		var cape := c.new_mask()
		if direction == "down":
			c.mask_round_rect(cape, 16 - L["half"] - 0.5, L["torso_top"] + 1, L["half"] * 2 + 1.0, L["legs_top"] - L["torso_top"] + 2, 1.5)
		else:
			c.mask_round_rect(cape, 10 + lean_x, L["torso_top"] + 1, 4, L["legs_top"] - L["torso_top"] + 3, 1.5)
			c.mask_round_rect(cape, 8.5 + lean_x, L["legs_top"] - 1, 4, 4, 1.5)
		c.paint_part(cape, palette["cloak"])

	# Pernas.
	var legs := []
	if direction == "right":
		legs = [[Vector2i(14, L["legs_top"]) + pose["leg_b"], pose["lift_b"], true], [Vector2i(16, L["legs_top"]) + pose["leg_a"], pose["lift_a"], false]]
	else:
		var gap := 1 if L["half"] <= 4 else 2
		legs = [[Vector2i(16 - gap - 2, L["legs_top"]) + pose["leg_a"], pose["lift_a"], false], [Vector2i(16 + gap - 1, L["legs_top"]) + pose["leg_b"], pose["lift_b"], false]]
	var leg_ramp: Array = palette["metal"] if gear.get("armor") == "heavy" else palette["pants"]
	for leg: Array in legs:
		var origin: Vector2i = leg[0]
		var lift: int = leg[1]
		var back: bool = leg[2]
		var boot_h := 3 if L["leg_len"] >= 6 else 2
		var pants := c.new_mask()
		c.mask_round_rect(pants, origin.x, origin.y - 1, 3, maxi(1, L["leg_len"] - boot_h - lift) + 1.5, 1.0)
		c.paint_part(pants, _darker(leg_ramp) if back else leg_ramp)
		var boot := c.new_mask()
		var boot_y: float = origin.y + L["leg_len"] - boot_h - lift
		c.mask_round_rect(boot, origin.x - 0.25, boot_y, 3.5, boot_h, 1.0)
		if direction == "right":
			c.mask_round_rect(boot, origin.x + 1, boot_y + boot_h - 2, 3.5, 2, 1.0)
		c.paint_part(boot, _darker(palette["leather"]) if back else palette["leather"])

	# Tronco.
	var torso := c.new_mask()
	var top: int = L["torso_top"]
	var bottom: int = L["torso_bottom"]
	if direction == "right":
		c.mask_round_rect(torso, 16 - L["side_half"] + lean_x, top - 0.5, L["side_half"] * 2 + 1, bottom - top + 1.5, 2.0)
	else:
		var half: int = L["half"]
		c.mask_round_rect(torso, 16 - half, top - 1 + lean_y, half * 2, bottom - top + 2, 2.0)
		c.mask_rect(torso, 16 - half, top + 3 + lean_y, half * 2, bottom - top - 3)
		if feminine:
			# Cintura mais fina e quadril.
			for side_x in [16 - half, 16 + half - 1]:
				c.mask_set(torso, side_x, top + 4 + lean_y, 0)
				c.mask_set(torso, side_x, top + 5 + lean_y, 0)
		if gear.get("armor") == "heavy":
			c.mask_ellipse(torso, 16 - half + 0.5, top + 0.5 + lean_y, 1.8, 1.4)
			c.mask_ellipse(torso, 16 + half - 0.5, top + 0.5 + lean_y, 1.8, 1.4)
	c.paint_part(torso, torso_ramp, 1, 1)
	_armor_detail(c, gear, palette, direction, L, lean_x, lean_y)
	var belt := c.new_mask()
	var belt_y := bottom - 2 + lean_y
	if direction == "right":
		c.mask_rect(belt, 16 - L["side_half"] + lean_x, belt_y, L["side_half"] * 2 + 1, 2)
	else:
		c.mask_rect(belt, 16 - L["half"], belt_y, L["half"] * 2, 2)
	c.paint_part(belt, palette["leather"])
	if direction != "up":
		var bx: int = 16 + L["side_half"] - 1 + lean_x if direction == "right" else 15
		for i in 3:
			for j in 3:
				c.set_fine(bx * SCALE + i, belt_y * SCALE + j, palette["gold"][2] if i + j < 2 else palette["gold"][1])

	# Capa sobre as costas.
	if look.get("cloak", "none") == "cape" and direction == "up":
		var back_cape := c.new_mask()
		c.mask_round_rect(back_cape, 16 - L["half"] - 0.5, top - 0.5 + lean_y, L["half"] * 2 + 1, bottom - top + 3.5, 1.5)
		c.paint_part(back_cape, palette["cloak"], 1, 2)
	if direction == "up":
		_tail(c, look, palette, direction, L)

	# Braços e mãos.
	var arms := []
	if direction == "right":
		arms = [Vector2i(15 + lean_x, top + 1) + pose["arm_a"]]
	else:
		arms = [Vector2i(16 - L["half"] - 2, top + 1 + lean_y) + pose["arm_a"], Vector2i(16 + L["half"], top + 1 + lean_y) + pose["arm_b"]]
	for arm_origin: Vector2i in arms:
		var w := 3 if direction == "right" else 2
		var arm := c.new_mask()
		c.mask_round_rect(arm, arm_origin.x, arm_origin.y - 0.5, w, L["arm_len"] + 1.0, w * 0.5)
		c.paint_part(arm, arm_ramp)
		var hand := c.new_mask()
		c.mask_ellipse(hand, arm_origin.x + w * 0.5, arm_origin.y + L["arm_len"] + 1.0, w * 0.5 + 0.1, 1.2)
		c.paint_part(hand, palette["skin"])
	_body_marks(c, look, palette, direction, arms, L)

	# Escudo no braço esquerdo (lado direito da tela na frente).
	if gear.get("shield", false) and direction == "down":
		var shield := c.new_mask()
		var sx: int = 16 + L["half"] + 1
		c.mask_round_rect(shield, sx, top + 2 + lean_y, 4, 5, 1.0)
		c.mask_ellipse(shield, sx + 2.0, top + 6.5 + lean_y, 1.6, 1.5)
		c.paint_part(shield, palette["cloak"], 1, 1)
		var boss := c.new_mask()
		c.mask_ellipse(boss, sx + 2.0, top + 4.5 + lean_y, 1.0, 1.0)
		c.paint_part(boss, palette["gold"], 1, 1, false)

	_head(c, look, profile, palette, direction, L["cx"] + (0.5 + lean_x if direction == "right" else 0.0),
			L["cy"] + lean_y, L["rx"], L["ry"], 1)

	if direction != "up":
		_weapon(c, gear, palette, direction, pose, L, lean_x, lean_y)

	c.outline()
	if pose["slash"] and gear.get("weapon", "none") != "none":
		_slash(c, direction, int(L["torso_top"]) + 4)
	c.shadow(16, 29.5, 7 + mini(2, L["half"] - 5), 2)
	return c.image


static func _torso_ramp(gear: Dictionary, palette: Dictionary) -> Array:
	match gear.get("armor", "none"):
		"light":
			return palette["leather"]
		"medium":
			return [palette["metal"][0], palette["metal"][0].lerp(palette["metal"][1], 0.6), palette["metal"][1]]
		"heavy":
			return palette["metal"]
	return palette["outfit"]


static func _armor_detail(c: PixelCanvas, gear: Dictionary, palette: Dictionary, direction: String, L: Dictionary,
		lean_x: int, lean_y: int) -> void:
	var top: int = L["torso_top"] + lean_y
	match gear.get("armor", "none"):
		"light":
			# Gola da túnica aparecendo sob o colete.
			if direction == "down":
				for x in range(14, 18):
					c.set_px(x, top, palette["outfit"][1])
		"medium":
			# Elos da malha.
			for py in range((top + 1) * SCALE, (int(L["torso_bottom"]) - 2 + lean_y) * SCALE):
				for px in range((16 - L["half"] + 1) * SCALE, (16 + L["half"] - 1) * SCALE):
					if (px + py * 2) % 4 == 0 and c.get_fine(px, py).a > 0.0:
						c.set_fine(px, py, palette["metal"][0].lerp(palette["metal"][1], 0.35))
		"heavy":
			if direction == "down":
				for py in range((top + 1) * SCALE, (top + 5) * SCALE):
					c.set_fine(16 * SCALE - 1, py, palette["metal"][2])
					c.set_fine(16 * SCALE, py, palette["metal"][0])


static func _body_marks(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, arms: Array, L: Dictionary) -> void:
	var mark: String = look.get("marks", "none")
	if mark == "none":
		return
	var color: Color = palette["skin"][0].lerp(Color("#203a6a"), 0.5)
	for arm_origin: Vector2i in arms:
		match mark:
			"lines":
				for i in 3:
					c.dot(arm_origin.x + 0.5 + i * 0.5, arm_origin.y + L["arm_len"] - 1.5, color)
			"spirals", "runes":
				c.dot(arm_origin.x + 1.0, arm_origin.y + L["arm_len"] - 2.0, color)
				c.dot(arm_origin.x + 1.5, arm_origin.y + L["arm_len"] - 1.5, color)
				c.dot(arm_origin.x + 1.0, arm_origin.y + L["arm_len"] - 1.0, color)


# --- Cabeça ---------------------------------------------------------------------

## Cabeça e todas as peças. s = escala dos detalhes (1 no sprite, 2 no retrato).
static func _head(c: PixelCanvas, look: Dictionary, profile: Dictionary, palette: Dictionary, direction: String,
		cx: float, cy: float, rx: float, ry: float, s: int) -> void:
	var snout: bool = profile.get("snout", false)
	_ears(c, look, palette, direction, cx, cy, rx, ry, s)
	_horns(c, look, palette, direction, cx, cy, rx, ry, s, true)
	_hair_back(c, look, palette, direction, cx, cy, rx, ry, s)
	var head := c.new_mask()
	c.mask_ellipse(head, cx, cy, rx * (0.92 if snout else 1.0), ry)
	c.paint_part(head, palette["skin"], 1, 1 if s == 1 else 2)
	if snout:
		_scales(c, head, palette, s)
		_snout(c, palette, direction, cx, cy, rx, ry, s)
	_marks_face(c, look, palette, direction, cx, cy, rx, ry, s)
	_face(c, look, profile, palette, direction, cx, cy, rx, ry, s)
	_beard(c, look, palette, direction, cx, cy, rx, ry, s)
	_hair_front(c, look, palette, direction, cx, cy, rx, ry, s, head)
	_horns(c, look, palette, direction, cx, cy, rx, ry, s, false)
	_accessory(c, look, palette, direction, cx, cy, rx, ry, s)


## Focinho de draconato: alongado para frente, parte de baixo clara, narinas e boca.
static func _snout(c: PixelCanvas, palette: Dictionary, direction: String, cx: float, cy: float, rx: float, ry: float, s: int) -> void:
	if direction == "up":
		return
	var muzzle := c.new_mask()
	var belly := c.new_mask()
	var dark := Color("#1a1020")
	if direction == "down":
		c.mask_ellipse(muzzle, cx, cy + ry * 0.55, rx * 0.5, ry * 0.42)
		c.mask_ellipse(belly, cx, cy + ry * 0.72, rx * 0.36, ry * 0.22)
	else:
		c.mask_rect(muzzle, int(cx + rx * 0.2), int(cy + ry * 0.05), int(rx * 0.95) + s, int(ry * 0.55) + 1)
		c.mask_rect(belly, int(cx + rx * 0.3), int(cy + ry * 0.45), int(rx * 0.8) + s, maxi(1, s))
	c.paint_part(muzzle, palette["skin"], 1, 1)
	c.paint_part(belly, [palette["skin"][2], palette["skin"][2].lerp(Color("#fff0d0"), 0.35), Color("#fff4dc")])
	if direction == "down":
		c.set_px(int(cx - rx * 0.2), int(cy + ry * 0.45), dark)
		c.set_px(int(cx + rx * 0.2), int(cy + ry * 0.45), dark)
		for x in range(int(cx - rx * 0.3), int(cx + rx * 0.3) + 1):
			c.set_px(x, int(cy + ry * 0.82), palette["skin"][0].darkened(0.3))
	else:
		c.set_px(int(cx + rx * 1.1) + s - 1, int(cy + ry * 0.15), dark)
		for x in range(int(cx + rx * 0.4), int(cx + rx * 1.1) + s):
			c.set_px(x, int(cy + ry * 0.4), palette["skin"][0].darkened(0.3))


static func _scales(c: PixelCanvas, head: PackedByteArray, palette: Dictionary, s: int) -> void:
	var step := 3 * s
	for py in c.ph:
		for px in c.pw:
			if (px + (py / 2) * 3) % (step * 2) == 0 and py % 2 == 0 and c.fine_get(head, px, py) \
					and c.fine_get(head, px + 2, py) and c.fine_get(head, px, py - 2) and c.fine_get(head, px, py + 2):
				c.set_fine(px, py, palette["skin"][0].lerp(palette["skin"][1], 0.45))
				c.set_fine(px + 1, py, palette["skin"][0].lerp(palette["skin"][1], 0.7))


static func _style(look: Dictionary) -> Dictionary:
	var name: String = look.get("hair_style", "short")
	var styles := {
		"bald": {"cap": false},
		"short": {"cap": true, "bangs": "side", "length": "short"},
		"messy": {"cap": true, "bangs": "spiky", "length": "short"},
		"long": {"cap": true, "bangs": "full", "length": "long"},
		"ponytail": {"cap": true, "bangs": "side", "length": "short", "extra": "ponytail"},
		"bun": {"cap": true, "bangs": "none", "length": "short", "extra": "bun"},
		"braid": {"cap": true, "bangs": "side", "length": "medium", "extra": "braid"},
		"twin_braids": {"cap": true, "bangs": "full", "length": "medium", "extra": "twin"},
		"mohawk": {"cap": false, "extra": "mohawk"},
		"curly": {"cap": true, "puffy": true, "bangs": "full", "length": "medium"},
		"topknot": {"cap": true, "bangs": "none", "length": "short", "extra": "topknot"},
		"wild": {"cap": true, "puffy": true, "bangs": "spiky", "length": "long"},
	}
	return styles.get(name, styles["short"])


## Partes do cabelo que ficam atrás da cabeça (comprimento longo, rabo, tranças).
static func _hair_back(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, cx: float, cy: float,
		rx: float, ry: float, s: int) -> void:
	var style := _style(look)
	if look.get("accessory") == "hood":
		return
	var hair := c.new_mask()
	var length: String = style.get("length", "")
	var extra: String = style.get("extra", "")
	var long_len := 5 * s
	if length == "long" or length == "medium":
		var drop := long_len if length == "long" else 2 * s
		match direction:
			"down":
				c.mask_round_rect(hair, cx - rx - 1.0, cy - ry * 0.4, 2 * s + 1.0, ry * 1.2 + drop, 1.0 * s)
				c.mask_round_rect(hair, cx + rx - 2 * s, cy - ry * 0.4, 2 * s + 1.0, ry * 1.2 + drop, 1.0 * s)
			"up":
				c.mask_round_rect(hair, cx - rx - 0.5, cy - ry * 0.2, rx * 2 + 1.0, ry * 1.2 + drop, 1.5 * s)
			"right":
				c.mask_round_rect(hair, cx - rx - 1.0, cy - ry * 0.5, rx + 1.5, ry * 1.5 + drop, 1.5 * s)
	if direction == "up" or direction == "right":
		match extra:
			"ponytail", "braid":
				var bx := cx if direction == "up" else cx - rx
				var length_px := (6 if extra == "braid" else 5) * s
				c.mask_line(hair, Vector2(bx, cy + ry * 0.2), Vector2(bx - (s if direction == "right" else 0), cy + ry * 0.2 + length_px), 2 * s)
			"twin":
				for sx in [-1.0, 1.0]:
					c.mask_line(hair, Vector2(cx + sx * rx * 0.6, cy + ry * 0.3), Vector2(cx + sx * rx * 0.7, cy + ry + 3 * s), 2 * s)
	if direction == "down" and extra == "twin":
		for sx in [-1.0, 1.0]:
			c.mask_line(hair, Vector2(cx + sx * (rx + 0.5), cy), Vector2(cx + sx * (rx + 0.5), cy + ry + 3 * s), 2 * s)
	if style.get("cap", false) or extra == "mohawk":
		c.paint_part(hair, palette["hair"])


## Cabelo sobre a cabeça: topo, laterais, franja, coque, moicano.
static func _hair_front(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, cx: float, cy: float,
		rx: float, ry: float, s: int, head: PackedByteArray) -> void:
	var style := _style(look)
	if look.get("accessory") == "hood":
		return
	var hair := c.new_mask()
	var extra: String = style.get("extra", "")
	if style.get("cap", false):
		var top_line := cy - ry * 0.25
		if style.get("puffy", false):
			var puff := c.new_mask()
			c.mask_ellipse(puff, cx, cy - ry * 0.3, rx + 1.0 * s, ry * 0.8)
			for py in c.ph:
				for px in c.pw:
					var over_face := absf(c.logical(px) - cx) < rx * 0.72 and c.logical(py) >= top_line
					if c.fine_get(puff, px, py) and (direction != "down" or not over_face):
						c.fine_set(hair, px, py)
		for py in c.ph:
			for px in c.pw:
				if not c.fine_get(head, px, py):
					continue
				var x := c.logical(px)
				var y := c.logical(py)
				# Linha da testa levemente curva (mais alta no meio).
				var brow := top_line + absf(x - cx) / rx * ry * 0.18
				var inside_top := y < brow
				match direction:
					"down":
						var sides := (x < cx - rx * 0.72 or x > cx + rx * 0.72) and y < cy + ry * 0.2
						if inside_top or sides:
							c.fine_set(hair, px, py)
					"up":
						c.fine_set(hair, px, py)
					"right":
						if inside_top or x < cx - rx * 0.1:
							c.fine_set(hair, px, py)
		if direction == "down":
			var bang_y := int(cy - ry * 0.25)
			match style.get("bangs", "none"):
				"full":
					c.mask_rect(hair, int(cx - rx * 0.7), bang_y, int(rx * 1.4) + 1, s)
				"side":
					c.mask_rect(hair, int(cx - rx * 0.7), bang_y, int(rx * 0.8), s)
					c.mask_rect(hair, int(cx + rx * 0.35), bang_y, s, s)
				"spiky":
					for i in range(-2, 3):
						var tip := Vector2(cx + i * rx * 0.32 + 0.4 * i, cy - ry - 1.0 * s + absi(i) * 0.4 * s)
						var root := Vector2(cx + i * rx * 0.22, cy - ry * 0.55)
						c.mask_line(hair, root, tip, 1.6 * s)
						c.mask_line(hair, root, tip.lerp(root, 0.3), 2.2 * s)
	match extra:
		"mohawk":
			if direction == "down" or direction == "up":
				c.mask_round_rect(hair, cx - s, cy - ry - 2.0 * s, 2.0 * s, ry * 0.9 + 2.0 * s, 1.0 * s)
			else:
				for i in 5:
					c.mask_round_rect(hair, cx - rx * 0.6 + i * rx * 0.3, cy - ry - 2.0 * s + absi(i - 2) * s * 0.5, s + 1.0, 2.5 * s, 0.8 * s)
		"bun", "topknot":
			var by := cy - ry - (1.0 if extra == "bun" else 2.0) * s
			var bx := cx if direction != "right" else cx - rx * 0.4
			c.mask_ellipse(hair, bx, by, 2.0 * s, 1.8 * s)
	c.paint_part(hair, palette["hair"], 1, 1)


static func _ears(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, cx: float, cy: float,
		rx: float, ry: float, s: int) -> void:
	var kind: String = look.get("ears", "round")
	var ears := c.new_mask()
	if kind == "round":
		for side: int in ([-1, 1] if direction != "right" else [0]):
			var ex := cx + side * (rx - 0.2 * s) if side != 0 else cx - rx * 0.15
			c.mask_ellipse(ears, ex, cy + ry * 0.12, 0.6 * s + 0.5, 0.85 * s + 0.6)
		c.paint_part(ears, palette["skin"])
		return
	var specs := {"pointed_short": [2.0, 2.0], "pointed_long": [4.0, 3.0], "swept": [4.0, 1.0], "small_pointed": [2.0, 1.0]}
	var spec: Array = specs.get(kind, [2.0, 2.0])
	var scale := 1.0 if s == 1 else 1.4
	var out := int(round(spec[0] * scale))
	var up := int(round(spec[1] * scale))
	var sides: Array = [-1, 1] if direction != "right" else [0]
	for side: int in sides:
		var base_x := cx + side * (rx - 0.6) if side != 0 else cx - rx * 0.15
		var dir_x := side if side != 0 else -1
		var tip := Vector2(base_x + dir_x * (out + 0.5), cy + ry * 0.05 - up)
		c.mask_polygon(ears, PackedVector2Array([Vector2(base_x, cy - ry * 0.2), tip,
				Vector2(base_x + dir_x * out * 0.35, cy + ry * 0.4), Vector2(base_x, cy + ry * 0.45)]))
	c.paint_part(ears, palette["skin"])


static func _horns(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, cx: float, cy: float,
		rx: float, ry: float, s: int, behind: bool) -> void:
	var kind: String = look.get("horns", "none")
	# Chifres ficam na frente da cabeça, exceto de costas; babados ficam sempre atrás.
	var draw_now := behind == (direction == "up")
	if kind == "frills":
		draw_now = behind
	if kind == "none" or not draw_now:
		return
	var horns := c.new_mask()
	var sides := [-1, 1] if direction != "right" else [-1]
	for side: int in sides:
		var base := Vector2(cx + side * rx * 0.5, cy - ry * 0.75)
		if direction == "right":
			base = Vector2(cx - rx * 0.1, cy - ry * 0.8)
		match kind:
			"ram":
				# Espiral: raio e espessura diminuem até a ponta.
				var center := base + Vector2(side * 2.0 * s, 0.6 * s)
				var previous := Vector2.ZERO
				for i in 17:
					var t := i / 16.0
					var a := lerpf(PI * 1.1, PI * 2.75, t)
					var p := center + Vector2(cos(a) * side, sin(a)) * (2.0 * s * (1.0 - t * 0.35))
					if i > 0:
						c.mask_line(horns, previous, p, (1.6 - t * 0.7) * s)
					previous = p
			"straight":
				c.mask_line(horns, base, base + Vector2(side * 1.5 * s, -4.0 * s), s + (1 if s > 1 else 0))
			"curved":
				var mid := base + Vector2(side * 0.5 * s, -3.0 * s)
				c.mask_line(horns, base, mid, s + (1 if s > 1 else 0))
				c.mask_line(horns, mid, mid + Vector2(side * 2.5 * s, -1.0 * s), s)
			"nubs":
				c.mask_rect(horns, int(base.x), int(base.y) - s, s + 1, s + 1)
			"crest":
				if side == sides[0]:
					c.mask_line(horns, Vector2(cx, cy - ry - 2.0 * s), Vector2(cx - (rx * 0.6 if direction == "right" else 0.0), cy - ry * 0.2), 2 * s)
			"frills":
				for i in 3:
					c.mask_rect(horns, int(cx + side * (rx + 0.5)), int(cy - ry * 0.4 + i * 1.5 * s), s + 1, s)
	c.paint_part(horns, palette["horn"] if kind != "frills" and kind != "crest" else palette["skin"], 1, 1)


static func _face(c: PixelCanvas, look: Dictionary, profile: Dictionary, palette: Dictionary, direction: String,
		cx: float, cy: float, rx: float, ry: float, s: int) -> void:
	if direction == "up":
		return
	var k := c.k
	var eye: Color = palette["eye"]
	var dark := Color("#1a1020")
	var lid: Color = palette["skin"][0].darkened(0.45).lerp(dark, 0.5)
	var white := Color("#f4f0ec")
	var feminine: bool = look.get("body") == "feminine"
	var snout: bool = profile.get("snout", false)
	var skin_dark: Color = palette["skin"][0]
	var lip: Color = skin_dark.lerp(Color("#b04048"), 0.45)
	var ey := floori((cy + ry * 0.12) * k)
	if direction == "down":
		var big := s > 1
		for side in [-1, 1]:
			var center := floori((cx + side * rx * 0.42) * k)
			if not big:
				# Olho do sprite: 2x3 pixels reais (pálpebra, brilho + pupila, íris).
				var x0 := center - 1
				c.set_fine(x0, ey - 1, lid)
				c.set_fine(x0 + 1, ey - 1, lid)
				c.set_fine(x0, ey, white if side < 0 else eye)
				c.set_fine(x0 + 1, ey, eye if side < 0 else white)
				c.set_fine(x0, ey + 1, eye.darkened(0.25))
				c.set_fine(x0 + 1, ey + 1, eye.darkened(0.25))
				if feminine:
					c.set_fine(x0 + (-1 if side < 0 else 2), ey - 1, lid)
			else:
				# Olho do retrato: 4x4 com esclera, íris, pupila e brilho.
				var x0 := center - 2
				for i in 4:
					c.set_fine(x0 + i, ey - 1, lid)
				var row1 := [white, eye.lightened(0.15), dark, white] if side < 0 else [white, dark, eye.lightened(0.15), white]
				var row2 := [white, eye, eye.darkened(0.35), skin_dark] if side < 0 else [skin_dark, eye.darkened(0.35), eye, white]
				for i in 4:
					c.set_fine(x0 + i, ey, row1[i])
					c.set_fine(x0 + i, ey + 1, row2[i])
				c.set_fine(x0 + (1 if side < 0 else 2), ey, Color.WHITE)
				c.set_fine(x0 + (2 if side < 0 else 1), ey + 2, eye.darkened(0.5))
				if feminine:
					c.set_fine(x0 + (-1 if side < 0 else 4), ey - 1, lid)
					c.set_fine(x0 + (-1 if side < 0 else 4), ey - 2, lid)
				# Sobrancelha.
				var brow: Color = palette["hair"][0] if not snout else palette["skin"][0]
				for i in 4:
					var lift := 1 if (side < 0 and i == 0) or (side > 0 and i == 3) else 0
					c.set_fine(x0 + i, ey - 4 + lift, brow)
		var mouth_y := floori((cy + ry * 0.58) * k)
		if snout:
			for side in [-1, 1]:
				c.set_fine(floori(cx * k) + side * (s + 1) - (1 if side < 0 else 0), floori((cy + ry * 0.5) * k), dark)
		else:
			if s > 1:
				# Nariz e boca do retrato.
				c.set_fine(floori(cx * k), floori((cy + ry * 0.36) * k), skin_dark)
				c.set_fine(floori(cx * k) - 1, floori((cy + ry * 0.36) * k) + 1, skin_dark.lerp(palette["skin"][1], 0.4))
				for x in range(floori(cx * k) - 2, floori(cx * k) + 2):
					c.set_fine(x, mouth_y, lip)
				c.set_fine(floori(cx * k) - 1, mouth_y + 1, palette["skin"][2])
				c.set_fine(floori(cx * k), mouth_y + 1, palette["skin"][2])
			else:
				c.set_fine(floori(cx * k) - 1, mouth_y, lip)
				c.set_fine(floori(cx * k), mouth_y, lip)
		match look.get("face", "none"):
			"tusks_small", "tusks_large":
				var h := (1 if look["face"] == "tusks_small" else 2) * s + 1
				for side in [-1, 1]:
					var tx: int = floori(cx * k) + side * (s + 1) - (1 if side < 0 else 0)
					for i in h:
						c.set_fine(tx, mouth_y + 2 - i, Color("#f4f0e0") if i > 0 else Color("#c8c0a8"))
						if s > 1:
							c.set_fine(tx + side, mouth_y + 1 - i, Color("#d8d0bc"))
			"freckles":
				for side in [-1, 1]:
					for o: Vector2 in [Vector2(0.55, 0.42), Vector2(0.42, 0.5), Vector2(0.62, 0.52)]:
						c.dot(cx + side * rx * o.x, cy + ry * o.y, skin_dark.lerp(palette["skin"][1], 0.3))
			"blush":
				var pink: Color = palette["skin"][2].lerp(Color("#ff7a8a"), 0.5)
				for side in [-1, 1]:
					for i in s + 1:
						c.dot(cx + side * rx * 0.6 + i * 0.5 - 0.25, cy + ry * 0.42, pink)
			"scar":
				for i in 4 * s:
					c.set_fine(floori((cx + rx * 0.3) * k) + i / 2, floori((cy - ry * 0.15) * k) + i, skin_dark.lerp(Color("#c06060"), 0.5))
	else:
		var x0 := floori((cx + rx * 0.45) * k)
		c.set_fine(x0, ey - 1, lid)
		c.set_fine(x0 + 1, ey - 1, lid)
		c.set_fine(x0, ey, eye)
		c.set_fine(x0 + 1, ey, white)
		c.set_fine(x0, ey + 1, eye.darkened(0.25))
		if feminine:
			c.set_fine(x0 + 2, ey - 1, lid)
		if not snout:
			# Nariz e boca de perfil.
			c.set_fine(floori((cx + rx) * k), ey + 2, palette["skin"][1])
			c.set_fine(floori((cx + rx) * k), ey + 3, skin_dark)
			c.set_fine(floori((cx + rx * 0.75) * k), floori((cy + ry * 0.58) * k), lip)
		if look.get("face", "none") in ["tusks_small", "tusks_large"]:
			for i in (2 if look["face"] == "tusks_small" else 3):
				c.set_fine(floori((cx + rx * 0.6) * k), floori((cy + ry * 0.62) * k) - i, Color("#f4f0e0"))


static func _marks_face(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, cx: float, cy: float,
		rx: float, ry: float, s: int) -> void:
	if direction == "up":
		return
	var color: Color = palette["skin"][0].lerp(Color("#203a6a"), 0.55)
	var step := 1.0 / c.k
	match look.get("marks", "none"):
		"lines":
			for side in ([-1, 1] if direction == "down" else [1]):
				for i in 4 * s:
					c.dot(cx + side * rx * 0.62, cy + ry * 0.1 + i * step, color)
		"spirals":
			var center := Vector2(cx - rx * 0.55, cy + ry * 0.42)
			for i in 10 * s:
				var a := i * 0.75
				c.dot(center.x + cos(a) * (0.2 + i * 0.09), center.y + sin(a) * (0.2 + i * 0.09), color)
		"runes":
			var top := Vector2(cx, cy - ry * 0.55)
			for i in 3 * s:
				c.dot(top.x, top.y + i * step, color)
				c.dot(top.x - i * step, top.y + i * step + step, color)
				c.dot(top.x + i * step, top.y + i * step + step, color)


static func _beard(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, cx: float, cy: float,
		rx: float, ry: float, s: int) -> void:
	var kind: String = look.get("beard", "none")
	if kind == "none" or direction == "up":
		return
	var beard := c.new_mask()
	var jaw_top := cy + ry * 0.35
	var mouth_y := int(cy + ry * 0.58)
	var lengths := {"stubble": 0, "mustache": 0, "short": 1, "full": 2, "long": 5, "braided": 5, "forked": 5}
	var extra_len: int = lengths.get(kind, 0) * s
	if kind == "stubble":
		for py in range(int(jaw_top * SCALE), int((cy + ry) * SCALE)):
			for px in range(int((cx - rx * 0.7) * SCALE), int((cx + rx * 0.7) * SCALE) + 1):
				if (px + py) % 2 == 0 and c.get_fine(px, py).a > 0.0:
					c.set_fine(px, py, palette["hair"][0].lerp(c.get_fine(px, py), 0.45))
		return
	if direction == "down":
		if kind != "mustache":
			for y in range(int(jaw_top), int(cy + ry) + extra_len + 1):
				var t := clampf((y - jaw_top) / maxf(1.0, cy + ry + extra_len - jaw_top), 0.0, 1.0)
				var half := rx * (0.85 - 0.45 * t)
				for x in range(int(cx - half), int(cx + half) + 1):
					c.mask_set(beard, x, y)
			if kind == "forked":
				for y in range(int(cy + ry) + 1, int(cy + ry) + extra_len + 1):
					c.mask_set(beard, int(cx), y, 0)
		for x in range(int(cx) - 2 * s, int(cx) + 2 * s):
			c.mask_set(beard, x, mouth_y - 1)
		# A boca continua visível.
		for x in range(int(cx) - s, int(cx) + s):
			c.mask_set(beard, x, mouth_y, 0)
	else:
		if kind != "mustache":
			for y in range(int(jaw_top), int(cy + ry) + extra_len + 1):
				for x in range(int(cx - rx * 0.1), int(cx + rx * 0.9) + 1):
					c.mask_set(beard, x, y)
		c.mask_rect(beard, int(cx + rx * 0.4), mouth_y - 1, 2 * s, s)
	c.paint_part(beard, palette["hair"], 1, 1)
	if kind == "braided":
		var ring := c.new_mask()
		c.mask_rect_f(ring, cx - 0.75 * s, cy + ry + extra_len - 1.5 * s, 1.5 * s, 0.75 * s)
		c.paint_part(ring, palette["gold"], 1, 1, false)


static func _accessory(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, cx: float, cy: float,
		rx: float, ry: float, s: int) -> void:
	var kind: String = look.get("accessory", "none")
	var band_y := int(cy - ry * 0.45)
	match kind:
		"headband", "bandana":
			var band := c.new_mask()
			c.mask_rect(band, int(cx - rx), band_y, int(rx * 2) + 1, s)
			if kind == "bandana" and direction != "down":
				c.mask_line(band, Vector2(cx - rx, band_y), Vector2(cx - rx - 2 * s, band_y + 3 * s), s)
			c.paint_part(band, palette["outfit"])
		"circlet":
			var circ := c.new_mask()
			c.mask_rect(circ, int(cx - rx * 0.9), band_y, int(rx * 1.8) + 1, s)
			c.paint_part(circ, palette["gold"])
			if direction == "down":
				c.dot(cx - 0.5, band_y + 0.0, Color("#bff4ff"))
				c.dot(cx, band_y + 0.0, Color("#40c0e0"))
				c.dot(cx - 0.5, band_y + 0.5, Color("#40c0e0"))
				c.dot(cx, band_y + 0.5, Color("#2080a8"))
		"hood":
			var hood := c.new_mask()
			c.mask_ellipse(hood, cx, cy - ry * 0.1, rx + 1.0 * s, ry + 1.0 * s)
			var face := c.new_mask()
			if direction == "down":
				c.mask_ellipse(face, cx, cy + ry * 0.2, rx * 0.72, ry * 0.75)
			elif direction == "right":
				c.mask_ellipse(face, cx + rx * 0.5, cy + ry * 0.2, rx * 0.6, ry * 0.7)
			for py in c.ph:
				for px in c.pw:
					if c.fine_get(face, px, py):
						c.fine_set(hood, px, py, 0)
			c.paint_part(hood, palette["cloak"], 1, 1)
		"goggles":
			if direction == "up":
				return
			var gog := c.new_mask()
			for side in ([-1, 1] if direction == "down" else [1]):
				c.mask_ellipse(gog, cx + side * rx * 0.4, cy - ry * 0.5, 1.4 * s, 1.2 * s)
			c.paint_part(gog, palette["leather"])
			for side in ([-1, 1] if direction == "down" else [1]):
				var lens := c.new_mask()
				c.mask_ellipse(lens, cx + side * rx * 0.4, cy - ry * 0.5, 0.8 * s, 0.7 * s)
				c.paint_part(lens, [Color("#4a90c0"), Color("#9ad0f0"), Color("#e8fbff")], 1, 1, false)
		"flower":
			var fx := int(cx + rx * 0.6)
			var fy := int(cy - ry * 0.55)
			var petals := c.new_mask()
			for o: Vector2 in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]:
				c.mask_ellipse(petals, fx + 0.5 + o.x * 0.9 * s, fy + 0.5 + o.y * 0.9 * s, 0.75 * s, 0.75 * s)
			c.paint_part(petals, [Color("#d04a6a"), Color("#ff8ca0"), Color("#ffd0da")], 1, 1, false)
			var heart := c.new_mask()
			c.mask_ellipse(heart, fx + 0.5, fy + 0.5, 0.6 * s, 0.6 * s)
			c.paint_part(heart, [Color("#d09c2c"), Color("#ffe066"), Color("#fff6c0")], 1, 1, false)
		"earrings":
			if direction == "up":
				return
			for side in ([-1, 1] if direction == "down" else [0]):
				var ex := int(cx + side * rx) if side != 0 else int(cx - rx * 0.15)
				var ring := c.new_mask()
				c.mask_ellipse(ring, ex + 0.5, cy + ry * 0.45 + 0.5 * s, 0.5 * s, 0.6 * s)
				c.paint_part(ring, palette["gold"], 1, 1, false)


static func _tail(c: PixelCanvas, look: Dictionary, palette: Dictionary, direction: String, L: Dictionary) -> void:
	var kind: String = look.get("tail", "none")
	if kind == "none":
		return
	var tail := c.new_mask()
	var base := Vector2(16, L["torso_bottom"] - 1)
	var thickness := 3 if kind == "thick" else 1
	match direction:
		"down":
			c.mask_line(tail, base + Vector2(L["half"] - 1, 2), base + Vector2(L["half"] + 4, 4), thickness)
			c.mask_line(tail, base + Vector2(L["half"] + 4, 4), base + Vector2(L["half"] + 5, 0), maxi(1, thickness - 1))
		"right":
			c.mask_line(tail, base + Vector2(-3, 0), base + Vector2(-8, 3), thickness)
			c.mask_line(tail, base + Vector2(-8, 3), base + Vector2(-10, -1), maxi(1, thickness - 1))
		"up":
			c.mask_line(tail, base, base + Vector2(2, 5), thickness)
			c.mask_line(tail, base + Vector2(2, 5), base + Vector2(6, 4), maxi(1, thickness - 1))
	c.paint_part(tail, palette["skin"])
	if kind == "spade":
		var tip := c.new_mask()
		var tip_pos: Vector2 = {"down": base + Vector2(L["half"] + 5, 0), "right": base + Vector2(-10, -1), "up": base + Vector2(6, 4)}[direction]
		c.mask_ellipse(tip, tip_pos.x, tip_pos.y, 1.6, 1.6)
		c.paint_part(tip, palette["skin"])


# --- Armas ----------------------------------------------------------------------

static func _weapon(c: PixelCanvas, gear: Dictionary, palette: Dictionary, direction: String, pose: Dictionary,
		L: Dictionary, lean_x: int, lean_y: int) -> void:
	var kind: String = gear.get("weapon", "none")
	if kind == "none":
		return
	var state: String = pose["weapon"]
	var top: int = L["torso_top"]
	var hand_y: int = top + L["arm_len"] + 1
	var hand := Vector2(16 + L["half"] + 1, hand_y + lean_y)
	var angle := 100.0
	match direction:
		"right":
			hand = Vector2(17 + lean_x, hand_y) + Vector2(pose["arm_a"])
			angle = {"rest": 70.0, "windup": -125.0, "strike": -5.0, "recover": 40.0}[state]
			if state == "windup":
				hand = Vector2(14, top + 1)
			elif state == "strike":
				hand = Vector2(20 + lean_x, top + 4)
		"down":
			hand = Vector2(16 + L["half"] + 1, hand_y + lean_y) + Vector2(pose["arm_b"])
			angle = {"rest": 95.0, "windup": -75.0, "strike": 100.0, "recover": 140.0}[state]
			if state == "windup":
				hand = Vector2(16 + L["half"] + 1, top - 1)
			elif state == "strike":
				hand = Vector2(18, hand_y + lean_y)
		"up":
			hand = Vector2(16 + L["half"] + 1, hand_y - 1 + lean_y) + Vector2(pose["arm_b"])
			angle = {"rest": 95.0, "windup": -100.0, "strike": -90.0, "recover": -40.0}[state]
			if state == "strike":
				hand = Vector2(17, top - 3)
	if kind == "bow":
		_bow(c, palette, direction, state, hand)
		return
	var dir := Vector2.RIGHT.rotated(deg_to_rad(angle))
	var lengths := {"sword": 10.0, "curved": 9.0, "dagger": 5.0, "axe": 9.0, "mace": 8.0, "staff": 13.0, "spear": 13.0}
	var length: float = lengths.get(kind, 9.0) - (1.0 if state == "rest" else 0.0)
	var tip := hand + dir * length
	var cross := dir.rotated(PI / 2.0)
	if kind in ["staff", "spear"]:
		var shaft := c.new_mask()
		c.mask_line(shaft, hand - dir * 3.0, tip, 1.0)
		c.paint_part(shaft, palette["leather"])
		if kind == "spear":
			var head := c.new_mask()
			c.mask_line(head, tip - dir * 2.0, tip + dir, 2)
			c.paint_part(head, palette["metal"])
		return
	var grip := c.new_mask()
	c.mask_line(grip, hand - dir, hand + dir * (0.5 if kind in ["sword", "curved", "dagger"] else length * 0.6), 1)
	c.paint_part(grip, palette["leather"])
	match kind:
		"sword", "dagger", "curved":
			var blade := c.new_mask()
			c.mask_line(blade, hand + dir * 2.0, tip, 1.0)
			if kind == "curved":
				c.mask_line(blade, hand + dir * 4.0 + cross * 0.75, tip + cross * 1.25, 1.0)
			else:
				c.mask_line(blade, hand + dir * 2.0 + cross * 0.75, tip - dir * 0.5, 1.0)
			c.paint_part(blade, palette["metal"])
			var guard := c.new_mask()
			c.mask_line(guard, hand + dir * 1.5 - cross * 1.5, hand + dir * 1.5 + cross * 1.5, 1)
			c.paint_part(guard, palette["gold"])
		"axe":
			var head := c.new_mask()
			c.mask_line(head, tip - dir * 2.5 + cross * 0.5, tip - dir * 2.5 + cross * 3.0, 3)
			c.paint_part(head, palette["metal"])
		"mace":
			var head := c.new_mask()
			c.mask_ellipse(head, tip.x, tip.y, 2.0, 2.0)
			c.paint_part(head, palette["metal"])


static func _bow(c: PixelCanvas, palette: Dictionary, direction: String, state: String, hand: Vector2) -> void:
	var bow := c.new_mask()
	var forward := Vector2.RIGHT if direction == "right" else (Vector2.DOWN if direction == "down" else Vector2.UP)
	var center := hand + forward * (2.0 if state != "rest" else 0.0)
	var axis := forward.rotated(PI / 2.0)
	for i in 9:
		var t := lerpf(-1.0, 1.0, i / 8.0)
		var p := center + axis * (t * 5.0) + forward * ((1.0 - t * t) * 2.0)
		c.mask_set(bow, int(p.x), int(p.y))
	c.paint_part(bow, palette["leather"])
	if state == "strike" or state == "windup":
		var arrow := c.new_mask()
		c.mask_line(arrow, center - forward * (3.0 if state == "windup" else 0.0), center + forward * 7.0, 1)
		c.paint_part(arrow, palette["metal"])


static func _slash(c: PixelCanvas, direction: String, center_y: int) -> void:
	var center := Vector2(16, center_y)
	var from := -60.0
	var to := 60.0
	match direction:
		"down":
			from = 20.0
			to = 160.0
			center.y += 2
		"up":
			from = -160.0
			to = -20.0
			center.y -= 6
	for i in 120:
		var t := i / 119.0
		var a := deg_to_rad(lerpf(from, to, t))
		var fade := sin(t * PI)
		for r in [11.5, 12.0, 12.5, 13.0]:
			var p: Vector2 = center + Vector2.RIGHT.rotated(a) * r
			var alpha := (0.9 if r <= 12.0 else 0.45) * fade
			var color := Color(1.0, 1.0, 0.94, alpha) if r <= 12.0 else Color(0.7, 0.9, 1.0, alpha)
			c.set_fine(int(p.x * SCALE), int(p.y * SCALE), c.get_fine(int(p.x * SCALE), int(p.y * SCALE)).blend(color))


static func _darker(ramp: Array) -> Array:
	return [ramp[0].darkened(0.25), ramp[0], ramp[1].darkened(0.15)]
