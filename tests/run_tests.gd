extends SceneTree
## Executor mínimo de testes, sem dependências externas.
## Uso: godot --headless --path . --script res://tests/run_tests.gd
## Código de saída 0 = todos passaram; 1 = houve falha.

const TEST_ROOT := "res://tests"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	var files: Array[String] = []
	_collect_test_files(TEST_ROOT, files)
	files.sort()
	for path in files:
		await _run_file(path)
	print("\nResultado: %d passou, %d falhou" % [_passed, _failed])
	quit(1 if _failed > 0 or _passed == 0 else 0)


func _collect_test_files(dir_path: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_collect_test_files(dir_path.path_join(sub), out)
	for file in DirAccess.get_files_at(dir_path):
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func _run_file(path: String) -> void:
	var script: GDScript = load(path)
	if script == null:
		_failed += 1
		print("FALHA  %s: não foi possível carregar o script" % path)
		return
	print("\n%s" % path)
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		var test_case: Object = script.new()
		test_case.set("tree", self)
		await test_case.call(method_name)
		var failures: Array[String] = test_case.get("failures")
		if failures.is_empty():
			_passed += 1
			print("  ok     %s" % method_name)
		else:
			_failed += 1
			print("  FALHA  %s" % method_name)
			for failure in failures:
				print("         - %s" % failure)
