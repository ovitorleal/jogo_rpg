extends SceneTree
## Gera o tema global da interface (assets/ui/arghaz_theme.tres) nas cores do logo de As Crônicas de
## Arghaz: fundo azul-petróleo escuro, molduras douradas e acento turquesa. Uso:
##   godot --headless --path . --script res://tools/art/build_ui_theme.gd

const OUT := "res://assets/ui/arghaz_theme.tres"

const BG := Color(0.067, 0.086, 0.110)
const BG_RAISED := Color(0.098, 0.133, 0.161)
const BG_HOVER := Color(0.137, 0.184, 0.212)
const GOLD := Color(0.851, 0.659, 0.302)
const GOLD_BRIGHT := Color(1.0, 0.843, 0.502)
const TEAL := Color(0.345, 0.812, 0.851)
const TEXT := Color(0.937, 0.910, 0.835)
const TEXT_MUTED := Color(0.604, 0.659, 0.698)


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font_size = 10
	for type in ["Label", "Button", "CheckBox", "OptionButton", "LineEdit", "RichTextLabel", "ItemList", "SpinBox"]:
		theme.set_color("font_color", type, TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))

	theme.set_stylebox("panel", "PanelContainer", _box(BG, GOLD, 1, 3))
	theme.set_stylebox("panel", "Panel", _box(BG, GOLD, 1, 3))

	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _box(BG_RAISED, GOLD.darkened(0.35), 1, 3, 6, 3))
		theme.set_stylebox("hover", type, _box(BG_HOVER, GOLD_BRIGHT, 1, 3, 6, 3))
		theme.set_stylebox("pressed", type, _box(BG, TEAL, 1, 3, 6, 3))
		theme.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), TEAL, 1, 3, 6, 3))
		theme.set_stylebox("disabled", type, _box(BG, Color(0.3, 0.32, 0.34), 1, 3, 6, 3))
		theme.set_color("font_hover_color", type, GOLD_BRIGHT)
		theme.set_color("font_pressed_color", type, TEAL)
		theme.set_color("font_focus_color", type, GOLD_BRIGHT)
		theme.set_color("font_disabled_color", type, TEXT_MUTED.darkened(0.3))

	theme.set_stylebox("normal", "LineEdit", _box(BG, GOLD.darkened(0.4), 1, 2, 4, 2))
	theme.set_stylebox("focus", "LineEdit", _box(BG, TEAL, 1, 2, 4, 2))
	theme.set_stylebox("panel", "ItemList", _box(BG, GOLD.darkened(0.4), 1, 2))
	theme.set_stylebox("panel", "PopupMenu", _box(BG_RAISED, GOLD, 1, 3, 4, 4))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	theme.set_stylebox("hover", "PopupMenu", _box(BG_HOVER, Color(0, 0, 0, 0), 0, 2))

	var grabber := _box(GOLD.darkened(0.3), Color(0, 0, 0, 0), 0, 3)
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, _box(BG, Color(0, 0, 0, 0), 0, 3))
		theme.set_stylebox("grabber", type, grabber)
		theme.set_stylebox("grabber_highlight", type, _box(GOLD, Color(0, 0, 0, 0), 0, 3))
		theme.set_stylebox("grabber_pressed", type, _box(TEAL, Color(0, 0, 0, 0), 0, 3))

	theme.set_stylebox("background", "ProgressBar", _box(BG, GOLD.darkened(0.4), 1, 2))
	theme.set_stylebox("fill", "ProgressBar", _box(TEAL.darkened(0.2), Color(0, 0, 0, 0), 0, 2))
	theme.set_stylebox("panel", "TooltipPanel", _box(BG_RAISED, GOLD, 1, 2, 4, 3))
	theme.set_color("font_color", "TooltipLabel", TEXT)

	var err := ResourceSaver.save(theme, OUT)
	print("build_ui_theme: %s" % ("ok" if err == OK else "erro %d" % err))
	quit(0 if err == OK else 1)


func _box(bg: Color, border: Color, border_width: int, radius: int, pad_x: int = 0, pad_y: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	box.anti_aliasing = true
	return box
