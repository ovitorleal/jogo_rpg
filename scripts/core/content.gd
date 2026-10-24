extends Node
## Autoload "Content": carrega e valida res://data uma vez na inicialização.
## Erros de conteúdo são reportados no console e ficam em "registry.errors".

var registry := ContentRegistry.new()


func _ready() -> void:
	if not registry.load_all():
		for problem in registry.errors:
			push_error("[Content] %s" % problem)
	else:
		print("[Content] conteúdo carregado: %d classes, %d espécies, %d antecedentes, %d itens, %d monstros, %d encontros" % [
				registry.ids("class").size(), registry.ids("species").size(),
				registry.ids("background").size(), registry.ids("item").size(),
				registry.ids("monster").size(), registry.ids("encounter").size()])


func is_valid() -> bool:
	return registry.errors.is_empty()
