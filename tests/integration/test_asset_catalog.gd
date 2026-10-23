extends "res://tests/base_test.gd"
## Valida o catálogo de assets: campos obrigatórios, IDs únicos, arquivos e dimensões.

const CATALOG_PATH := "res://assets/asset_catalog.json"
const REQUIRED_FIELDS: Array[String] = [
	"asset_id", "category", "file_path", "dimensions", "format", "transparency",
	"source_type", "license", "approval_status",
]


func _load_assets() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	assert_true(data is Dictionary, "Catálogo deve ser um objeto JSON válido")
	if not data is Dictionary:
		return []
	return data.get("assets", [])


func test_catalog_entries_are_complete_and_unique() -> void:
	var assets := _load_assets()
	assert_true(not assets.is_empty(), "Catálogo não deve estar vazio")
	var seen: Dictionary = {}
	for entry: Dictionary in assets:
		for field in REQUIRED_FIELDS:
			assert_true(entry.has(field), "%s: campo obrigatório ausente '%s'" % [entry.get("asset_id", "?"), field])
		var id: String = entry.get("asset_id", "")
		assert_true(not seen.has(id), "asset_id duplicado: %s" % id)
		seen[id] = true
		assert_true(not String(entry.get("license", "")).is_empty(), "%s: licença não registrada" % id)


func test_catalog_files_exist_with_expected_dimensions() -> void:
	for entry: Dictionary in _load_assets():
		var path: String = entry.get("file_path", "")
		assert_true(ResourceLoader.exists(path), "%s: arquivo ausente %s" % [entry.get("asset_id"), path])
		if entry.get("format") != "png" or not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path)
		var dims: Array = entry.get("dimensions", [])
		assert_eq(Vector2i(texture.get_size()), Vector2i(int(dims[0]), int(dims[1])),
				"%s: dimensões" % entry.get("asset_id"))
