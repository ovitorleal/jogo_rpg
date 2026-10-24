extends Node
## Autoload "Content": carrega e valida res://data uma vez na inicialização.
## Erros de conteúdo são reportados no console e ficam em "registry.errors".

var registry := ContentRegistry.new()


func _ready() -> void:
	if not registry.load_all():
		for problem in registry.errors:
			push_error("[Content] %s" % problem)
	else:
		var counts := PackedStringArray()
		for type_name: String in ContentRegistry.TYPES:
			counts.append("%s: %d" % [type_name, registry.ids(type_name).size()])
		print("[Content] conteúdo carregado (%s)" % ", ".join(counts))


func is_valid() -> bool:
	return registry.errors.is_empty()
