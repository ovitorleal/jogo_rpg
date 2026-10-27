extends SceneTree
## Escreve os avisos de licença do Godot Engine (MIT e componentes de terceiros) num arquivo de texto
## que é publicado junto do build Web.
## Uso: godot --headless --path . --script res://tools/publish/write_engine_licenses.gd -- <arquivo de saída>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Informe o arquivo de saída depois de --")
		quit(1)
		return
	var info := Engine.get_version_info()
	var lines := PackedStringArray()
	lines.append("Godot Engine %s (%s, %s)" % [info["string"], info.get("status", ""), str(info.get("hash", "")).left(9)])
	lines.append("https://godotengine.org/license")
	lines.append("")
	lines.append(Engine.get_license_text())
	lines.append("")
	lines.append("=== Componentes de terceiros incluídos no motor ===")
	var licenses := Engine.get_license_info()
	for part: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append("- %s" % part["name"])
		for piece: Dictionary in part["parts"]:
			for owner: String in piece.get("copyright", []):
				lines.append("  Copyright %s" % owner)
			lines.append("  Licença: %s" % piece.get("license", ""))
	lines.append("")
	lines.append("=== Textos das licenças ===")
	var names := licenses.keys()
	names.sort()
	for license_name: String in names:
		lines.append("")
		lines.append("--- %s ---" % license_name)
		lines.append(str(licenses[license_name]))
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível escrever %s" % args[0])
		quit(1)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("Avisos do motor escritos em %s" % args[0])
	quit(0)
