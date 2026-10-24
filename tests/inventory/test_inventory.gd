extends "res://tests/base_test.gd"
## Inventário: pilhas, recompensas, equipar/trocar/remover com validação, consumíveis,
## poção no combate (ação bônus) e serialização.

const FACTORY_TESTS := preload("res://tests/characters/test_character_factory.gd")

var registry: ContentRegistry


func _registry() -> ContentRegistry:
	if registry == null:
		registry = ContentRegistry.new()
		registry.load_all()
	return registry


func _hero(rogue: bool = false) -> CharacterData:
	var fixtures := FACTORY_TESTS.new()
	return CharacterFactory.create(fixtures.rogue_choices() if rogue else fixtures.fighter_choices(), _registry())[0]


func test_stacks_and_grant() -> void:
	var inv := Inventory.new()
	inv.add("item.rations", 2)
	inv.add("item.rations")
	assert_eq(inv.count("item.rations"), 3, "Pilha de rações")
	assert_true(inv.remove("item.rations", 2) and inv.count("item.rations") == 1, "Remove 2")
	assert_true(not inv.remove("item.rations", 5), "Não remove mais do que tem")
	assert_true(inv.remove("item.rations") and not inv.stacks.has("item.rations"), "Pilha vazia some")
	var lines := inv.grant(15, [{"item_id": "item.potion_of_healing", "count": 2}], _registry())
	assert_eq([inv.gold, inv.count("item.potion_of_healing")], [15, 2], "Ouro e itens da recompensa")
	assert_eq(lines, ["+15 PO", "+2 Poção de Cura"] as Array[String], "Descrição dos ganhos")


func test_starting_inventory() -> void:
	var inv := Inventory.starting_inventory()
	assert_eq([inv.count(Inventory.RATIONS), inv.count(Inventory.POTION), inv.gold], [6, 2, 10], "Kit inicial do grupo")


func test_equip_swaps_armor_and_updates_ac() -> void:
	var c := _hero()
	var inv := Inventory.new()
	inv.add("item.leather_armor")
	assert_eq(CharacterSheet.build(c, _registry()).armor_class, 18, "Cota de Malha + escudo")
	var result := inv.equip(c, "item.leather_armor", _registry())
	assert_true(result["ok"], "Equipa couro: %s" % result.get("error", ""))
	assert_eq(c.armor_id, "item.leather_armor", "Armadura trocada")
	assert_eq(inv.count("item.chain_mail"), 1, "Cota de Malha volta para a mochila")
	assert_eq(CharacterSheet.build(c, _registry()).armor_class, 14, "Couro 11 + Des 1 + escudo 2")
	assert_true(inv.unequip(c, "shield")["ok"] and c.shield_id.is_empty(), "Remove o escudo")
	assert_eq(CharacterSheet.build(c, _registry()).armor_class, 12, "Sem escudo")
	assert_true(inv.equip(c, "item.shield", _registry())["ok"], "Escudo de volta")


func test_equip_requires_training() -> void:
	var rogue := _hero(true)
	var inv := Inventory.new()
	inv.add("item.chain_mail")
	inv.add("item.shield")
	var armor := inv.equip(rogue, "item.chain_mail", _registry())
	assert_true(not armor["ok"] and armor["error"].contains("treinamento"), "Ladino sem armadura pesada")
	assert_true(not inv.equip(rogue, "item.shield", _registry())["ok"], "Ladino sem escudo")
	assert_eq(rogue.armor_id, "item.leather_armor", "Nada mudou")
	assert_true(not inv.equip(rogue, "item.longsword", _registry())["ok"], "Item que não está na mochila")


func test_weapons_equip_and_unequip() -> void:
	var c := _hero()
	var inv := Inventory.new()
	inv.add("item.dagger")
	assert_true(inv.equip(c, "item.dagger", _registry())["ok"], "Equipa adaga")
	assert_true("item.dagger" in c.weapon_ids, "Adaga equipada")
	assert_true(inv.unequip(c, "weapon:item.longsword")["ok"], "Guarda a espada longa")
	assert_eq([c.weapon_ids.has("item.longsword"), inv.count("item.longsword")], [false, 1], "Espada na mochila")
	assert_true(not inv.unequip(c, "weapon:item.greataxe")["ok"], "Não remove o que não está equipado")
	assert_true(not inv.equip(c, "item.rations", _registry())["ok"] or inv.count("item.rations") == 0, "Ração não se equipa")


func test_use_potion_out_of_combat() -> void:
	var c := _hero()
	var inv := Inventory.new()
	inv.add(Inventory.POTION, 1)
	assert_true(not inv.use(c, Inventory.POTION, _registry(), DiceRoller.scripted([2, 2]))["ok"], "PV cheios: não usa")
	c.current_hp = 3
	var result := inv.use(c, Inventory.POTION, _registry(), DiceRoller.scripted([2, 3]))
	assert_true(result["ok"] and result["healed"] == 7, "2d4+2 = 2 + 3 + 2")
	assert_eq([c.current_hp, inv.count(Inventory.POTION)], [10, 0], "Cura e consome")
	assert_true(not inv.use(c, Inventory.POTION, _registry(), DiceRoller.scripted([2, 2]))["ok"], "Sem poções")
	assert_true(not inv.use(c, "item.dagger", _registry(), DiceRoller.scripted([1]))["ok"], "Adaga não é consumível")


func test_serialization() -> void:
	var inv := Inventory.starting_inventory()
	inv.add("item.longsword")
	var copy: Inventory = Inventory.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())), _registry())[0]
	assert_true(copy != null and copy.to_dict() == inv.to_dict(), "Ida e volta em JSON")
	var bad := Inventory.from_dict({"gold": 5, "stacks": {"item.excalibur": 1}}, _registry())
	assert_true(bad[0] == null and str(bad[1]).contains("Item desconhecido"), "Item inexistente rejeitado")
	bad = Inventory.from_dict({"gold": -3, "stacks": {}}, _registry())
	assert_true(bad[0] == null, "Ouro negativo rejeitado")
	bad = Inventory.from_dict({"gold": 0, "stacks": {"item.rations": 0}}, _registry())
	assert_true(bad[0] == null, "Quantidade zero rejeitada")


func test_potion_in_combat_uses_bonus_action() -> void:
	var manager := CombatManager.new()
	var hero := _hero()
	hero.current_hp = 2
	var inv := Inventory.new()
	inv.add(Inventory.POTION, 2)
	manager.inventory = inv
	manager.registry = _registry()
	var party: Array[Combatant] = [Combatant.from_character(hero, _registry())]
	var enemies: Array[Combatant] = [Combatant.from_monster(_registry().get_entry("monster", "monster.wolf"), 1, 1)]
	manager.setup(party, enemies, Vector2i(12, 8), true, DiceRoller.scripted([20, 1, 3, 4]))
	manager.start()
	var unit := manager.current()
	var drink := manager.submit({"type": "use_item", "actor": unit.id, "item_id": Inventory.POTION})
	assert_true(drink["ok"], "Bebe a poção: %s" % drink["error"])
	assert_eq(unit.hp, 11, "2 + (3 + 4 + 2)")
	assert_true(not manager.bonus_action_available and manager.action_available, "Gasta a ação bônus, não a ação")
	var again := manager.submit({"type": "use_item", "actor": unit.id, "item_id": Inventory.POTION})
	assert_true(not again["ok"] and again["error"].contains("ação bônus"), "Só uma ação bônus por turno")
	assert_eq(inv.count(Inventory.POTION), 1, "Uma poção consumida")
	assert_true(not manager.submit({"type": "use_item", "actor": unit.id, "item_id": "item.dagger"})["ok"], "Adaga não é consumível")
	manager.submit({"type": "end_turn", "actor": unit.id})
	assert_true(CombatLog.describe(drink["events"][0], manager).contains("recupera 9 PV"), "Registro da cura")
