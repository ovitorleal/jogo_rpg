extends "res://tests/base_test.gd"
## Todo script do jogo compila. Um erro de sintaxe num script que nenhum teste carrega
## passaria despercebido sem esta verificação.


func _collect(dir_path: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), out)
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func test_all_game_scripts_compile() -> void:
	var files: Array[String] = []
	_collect("res://scripts", files)
	assert_true(files.size() > 30, "Encontrou os scripts do jogo (%d)" % files.size())
	for path in files:
		var script: GDScript = load(path)
		assert_true(script != null and script.can_instantiate(), "Script não compila: %s" % path)


func test_all_scenes_load() -> void:
	var scenes: Array[String] = []
	for dir_path in ["res://scenes"]:
		var stack: Array[String] = [dir_path]
		while not stack.is_empty():
			var current: String = stack.pop_back()
			for sub in DirAccess.get_directories_at(current):
				stack.append(current.path_join(sub))
			for file in DirAccess.get_files_at(current):
				if file.ends_with(".tscn"):
					scenes.append(current.path_join(file))
	assert_true(scenes.size() > 10, "Encontrou as cenas (%d)" % scenes.size())
	for path in scenes:
		var scene: PackedScene = load(path)
		assert_true(scene != null and scene.can_instantiate(), "Cena não carrega: %s" % path)
