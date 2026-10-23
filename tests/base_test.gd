extends RefCounted
## Classe-base dos testes. Cada método iniciado por "test_" é executado
## em uma instância nova por tests/run_tests.gd.

var tree: SceneTree
var failures: Array[String] = []


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (esperado: %s, obtido: %s)" % [message, str(expected), str(actual)])
