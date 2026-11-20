extends "res://tests/base_test.gd"
## Ressurreição paga com a chefe da vila (decisão do responsável: 100 PO). O morto volta com 1 PV; sem ouro
## suficiente ela diz quanto custa; sem morto no grupo a opção não aparece.

const ENGINE_TESTS := preload("res://tests/combat/test_combat_engine.gd")

var _engine: Object


func _e() -> Object:
	if _engine == null:
		_engine = ENGINE_TESTS.new()
		_engine.tree = tree
	return _engine


func _party() -> Array[CharacterData]:
	var hero: CharacterData = _e()._hero("class.fighter")
	var cleric: CharacterData = _e()._hero("class.cleric")
	cleric.id = "companion.test_cleric"
	cleric.name = "Clériga"
	cleric.dead = true
	cleric.current_hp = 0
	return [hero, cleric]


func _talk(party: Array[CharacterData], gold: int) -> DialogueRunner:
	var inv := Inventory.new()
	inv.gold = gold
	var runner := DialogueRunner.new()
	runner.begin(_e()._registry().get_entry("dialogue", "dialogue.ione"), QuestLog.new(), party, inv, _e()._registry())
	return runner


func _index_of(runner: DialogueRunner, text: String) -> int:
	var visible := runner.choices()
	for i in visible.size():
		if str(visible[i]["text"]).contains(text):
			return i
	return -1


func test_price_matches_the_party_manager_constant() -> void:
	assert_eq(PartyManager.RESURRECTION_PRICE, 100, "Preço decidido pelo responsável")


func test_paying_brings_the_dead_back_with_one_hp() -> void:
	var party := _party()
	var runner := _talk(party, 150)
	var i := _index_of(runner, "ressuscitar")
	assert_true(i >= 0, "Com morto e ouro, a opção aparece: %s" % [runner.choices()])
	var result := runner.choose(i)
	assert_true(result["ok"], "Escolha aceita")
	assert_true(not party[1].dead, "Voltou à vida")
	assert_eq(party[1].current_hp, 1, "Com 1 PV")
	assert_eq(runner._inventory.gold, 50, "Pagou 100 PO")
	assert_true(str(result["lines"]).contains("Clériga"), "Diz quem voltou: %s" % [result["lines"]])


func test_without_enough_gold_she_names_the_price() -> void:
	var party := _party()
	var runner := _talk(party, 40)
	assert_eq(_index_of(runner, "ressuscitar"), -1, "Sem ouro, não oferece pagar")
	var i := _index_of(runner, "Quem morreu")
	assert_true(i >= 0, "Mas dá para perguntar")
	runner.choose(i)
	assert_true(str(runner.node["text"]).contains("100"), "Ela diz o preço")
	assert_true(party[1].dead, "Ninguém volta sem pagar")


func test_no_option_when_nobody_is_dead() -> void:
	var party := _party()
	party[1].dead = false
	party[1].current_hp = 5
	var runner := _talk(party, 500)
	assert_eq(_index_of(runner, "ressuscitar"), -1, "Sem morto, sem a opção")
	assert_eq(_index_of(runner, "Quem morreu"), -1, "Nem a pergunta")
