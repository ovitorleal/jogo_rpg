extends SceneTree
## Executor mínimo de testes, sem dependências externas.
## Uso: godot --headless --path . --script res://tests/run_tests.gd
## Código de saída 0 = todos passaram; 1 = houve falha.

const TEST_ROOT := "res://tests"


## Captura erros de script em tempo de execução: um teste interrompido por erro reprova,
## mesmo sem nenhuma asserção falhar. Erros comuns (push_error) não reprovam.
class ScriptErrorCatcher extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			errors.append("%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file.get_file(), line])


const TEST_SAVE_DIR := "user://test_save"

var _passed: int = 0
var _failed: int = 0
var _catcher := ScriptErrorCatcher.new()


func _initialize() -> void:
	OS.add_logger(_catcher)
	# Testes nunca tocam no salvamento real do jogador: pasta própria, sem autosave nem indicador.
	var saves: Node = root.get_node("SaveManager")
	saves.save_dir = TEST_SAVE_DIR
	saves.autosave_enabled = false
	saves.indicator_enabled = false
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
	if script == null or not script.can_instantiate():
		_failed += 1
		print("FALHA  %s: o script não compila (veja o erro acima)" % path)
		return
	print("\n%s" % path)
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		var test_case: Object = script.new()
		test_case.set("tree", self)
		_catcher.errors.clear()
		await test_case.call(method_name)
		var failures: Array[String] = test_case.get("failures")
		for error in _catcher.errors:
			failures.append("Erro de script durante o teste: %s" % error)
		if failures.is_empty():
			_passed += 1
			print("  ok     %s" % method_name)
		else:
			_failed += 1
			print("  FALHA  %s" % method_name)
			for failure in failures:
				print("         - %s" % failure)
