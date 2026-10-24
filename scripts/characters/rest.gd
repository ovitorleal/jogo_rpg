class_name Rest
extends RefCounted
## Descansos (SRD 5.2.1) aplicados a um personagem.
## - Curto: gasta Dados de Vida, um por vez; cada um recupera 1 dado + Con.
## - Longo: recupera todos os PV, todos os Dados de Vida gastos e todos os espaços de magia.
## - Magia de Pacto (Bruxo) recupera os espaços também no descanso curto (Spellcasting.short_rest).
## Um personagem com 0 PV não pode gastar Dados de Vida (precisa de cura ou descanso longo).


## Gasta um Dado de Vida. Retorna {"ok", "error", "healed", "roll"}.
static func spend_hit_die(c: CharacterData, registry: ContentRegistry, roller: DiceRoller) -> Dictionary:
	var sheet := CharacterSheet.build(c, registry)
	if c.hit_dice_spent >= RulesEngine.hit_dice_total(c.level):
		return {"ok": false, "error": "Sem Dados de Vida disponíveis", "healed": 0}
	if c.current_hp <= 0:
		return {"ok": false, "error": "Inconsciente não pode gastar Dados de Vida", "healed": 0}
	if c.current_hp >= sheet.max_hp:
		return {"ok": false, "error": "PV já estão no máximo", "healed": 0}
	var amount := RulesEngine.spend_hit_die(roller, int(sheet.class_entry["hit_die"]), sheet.scores[Ability.CONSTITUTION])
	var before := c.current_hp
	c.current_hp = mini(sheet.max_hp, c.current_hp + amount)
	c.hit_dice_spent += 1
	return {"ok": true, "error": "", "healed": c.current_hp - before}


static func long_rest(c: CharacterData, registry: ContentRegistry) -> int:
	var before := c.current_hp
	c.current_hp = CharacterSheet.build(c, registry).max_hp
	c.hit_dice_spent = 0
	Spellcasting.long_rest(c)
	return c.current_hp - before


static func hit_dice_left(c: CharacterData) -> int:
	return RulesEngine.hit_dice_total(c.level) - c.hit_dice_spent
