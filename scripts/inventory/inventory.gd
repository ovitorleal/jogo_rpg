class_name Inventory
extends RefCounted
## Inventário do grupo: pilhas de itens por id e ouro. O equipamento em uso fica em cada
## CharacterData (armadura, escudo, armas); equipar move o item do inventário para o
## personagem e devolve a peça trocada. Só lógica; independente da interface.

const RATIONS := "item.rations"
const POTION := "item.potion_of_healing"
const MAX_WEAPONS := 6

var stacks: Dictionary = {}  # item_id -> quantidade
var gold: int = 0


func count(item_id: String) -> int:
	return int(stacks.get(item_id, 0))


func add(item_id: String, quantity: int = 1) -> void:
	if quantity <= 0 or item_id.is_empty():
		return
	stacks[item_id] = count(item_id) + quantity


func remove(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0 or count(item_id) < quantity:
		return false
	stacks[item_id] = count(item_id) - quantity
	if stacks[item_id] == 0:
		stacks.erase(item_id)
	return true


## Ids em ordem: consumíveis, equipamento geral, armas, armaduras e escudos; depois por nome.
func ids(registry: ContentRegistry) -> Array[String]:
	var result: Array[String] = []
	result.assign(stacks.keys())
	var order := {"consumable": 0, "gear": 1, "weapon": 2, "armor": 3, "shield": 4}
	result.sort_custom(func(a: String, b: String) -> bool:
		var ea := registry.get_entry("item", a)
		var eb := registry.get_entry("item", b)
		var oa: int = order.get(ea.get("item_type"), 9)
		var ob: int = order.get(eb.get("item_type"), 9)
		return oa < ob if oa != ob else str(ea.get("name", a)) < str(eb.get("name", b)))
	return result


## Recompensa (ouro + lista de {"item_id", "count"}). Retorna as descrições dos ganhos.
func grant(gold_amount: int, items: Array, registry: ContentRegistry) -> Array[String]:
	var lines: Array[String] = []
	if gold_amount > 0:
		gold += gold_amount
		lines.append("+%d PO" % gold_amount)
	for entry: Dictionary in items:
		add(str(entry["item_id"]), int(entry["count"]))
		lines.append("+%d %s" % [int(entry["count"]), registry.get_entry("item", entry["item_id"]).get("name", entry["item_id"])])
	return lines


# --- Equipamento --------------------------------------------------------------

## Equipa um item do inventário no personagem. Retorna {"ok", "error"}.
func equip(c: CharacterData, item_id: String, registry: ContentRegistry) -> Dictionary:
	if count(item_id) <= 0:
		return _fail("Item não está no inventário")
	var item := registry.get_entry("item", item_id)
	var training: Array = registry.get_entry("class", c.class_id).get("armor_training", [])
	match item.get("item_type"):
		"armor":
			if not item["armor_category"] in training:
				return _fail("%s exige treinamento em armadura %s" % [item["name"], _category_name(item["armor_category"])])
			remove(item_id)
			add(c.armor_id)
			c.armor_id = item_id
		"shield":
			if not "shield" in training:
				return _fail("A classe não tem treinamento com escudo")
			remove(item_id)
			add(c.shield_id)
			c.shield_id = item_id
		"weapon":
			if c.weapon_ids.size() >= MAX_WEAPONS:
				return _fail("Já carrega o máximo de %d armas" % MAX_WEAPONS)
			remove(item_id)
			c.weapon_ids.append(item_id)
		_:
			return _fail("%s não pode ser equipado" % item.get("name", item_id))
	return {"ok": true, "error": ""}


## Desequipa: slot "armor", "shield" ou "weapon:<id>". O item volta ao inventário.
func unequip(c: CharacterData, slot: String) -> Dictionary:
	if slot == "armor" and not c.armor_id.is_empty():
		add(c.armor_id)
		c.armor_id = ""
	elif slot == "shield" and not c.shield_id.is_empty():
		add(c.shield_id)
		c.shield_id = ""
	elif slot.begins_with("weapon:") and slot.trim_prefix("weapon:") in c.weapon_ids:
		var weapon_id := slot.trim_prefix("weapon:")
		c.weapon_ids.erase(weapon_id)
		add(weapon_id)
	else:
		return _fail("Nada equipado em '%s'" % slot)
	return {"ok": true, "error": ""}


## Usa um consumível num personagem (fora do combate). Retorna {"ok", "error", "healed"}.
func use(c: CharacterData, item_id: String, registry: ContentRegistry, roller: DiceRoller) -> Dictionary:
	var item := registry.get_entry("item", item_id)
	if item.get("item_type") != "consumable":
		return _fail("%s não é consumível" % item.get("name", item_id))
	if count(item_id) <= 0:
		return _fail("Nenhum(a) %s no inventário" % item["name"])
	var max_hp := CharacterSheet.build(c, registry).max_hp
	if item["effect"] == "heal" and c.current_hp >= max_hp:
		return _fail("PV já estão no máximo")
	remove(item_id)
	var amount := DiceExpression.parse(item["effect_dice"]).roll(roller)
	var before := c.current_hp
	c.current_hp = mini(max_hp, c.current_hp + amount)
	return {"ok": true, "error": "", "healed": c.current_hp - before}


# --- Serialização -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"gold": gold, "stacks": stacks.duplicate()}


## Retorna [Inventory ou null, erros]. Itens desconhecidos e quantidades inválidas são erros.
static func from_dict(data: Dictionary, registry: ContentRegistry) -> Array:
	var errors: Array[String] = []
	var inv := Inventory.new()
	var gold_value: Variant = data.get("gold", 0)
	if not (gold_value is int or gold_value is float) or int(gold_value) < 0:
		errors.append("Ouro inválido no inventário")
	else:
		inv.gold = int(gold_value)
	var raw: Variant = data.get("stacks", {})
	if not raw is Dictionary:
		return [null, ["Inventário sem pilhas válidas"]]
	for key: Variant in raw:
		var item_id := str(key)
		var quantity: Variant = raw[key]
		if not registry.has("item", item_id):
			errors.append("Item desconhecido no inventário: '%s'" % item_id)
		elif not (quantity is int or quantity is float) or int(quantity) <= 0:
			errors.append("Quantidade inválida de '%s'" % item_id)
		else:
			inv.stacks[item_id] = int(quantity)
	return [inv if errors.is_empty() else null, errors]


static func starting_inventory() -> Inventory:
	var inv := Inventory.new()
	inv.add(RATIONS, 6)
	inv.add(POTION, 2)
	inv.gold = 10
	return inv


static func _category_name(category: String) -> String:
	return {"light": "leve", "medium": "média", "heavy": "pesada"}.get(category, category)


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
