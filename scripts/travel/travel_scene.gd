class_name TravelScene
extends Control
## Tela de viagem (apresentação). Envia comandos ao TravelSystem e mostra trechos, eventos com
## escolhas, descanso, combates e chegada. O estado da viagem fica no ExplorationManager para
## sobreviver à troca de cena durante um combate.

## Animações do herói na trilha. Desligadas nos testes; não alteram resultados.
@export var animations_enabled: bool = true
## Pausa antes de entrar num combate, para o jogador ler o aviso.
@export var combat_delay: float = 1.2

var travel: TravelSystem
var _party: Array[CharacterData] = []
var _inventory: Inventory
var _configured := false
var _busy := false
var _event_open := false

@onready var _title: Label = %Title
@onready var _clock: Label = %Clock
@onready var _strip: RouteStrip = %Strip
@onready var _status: Label = %Status
@onready var _log: RichTextLabel = %Log
@onready var _advance_button: Button = %AdvanceButton
@onready var _short_rest_button: Button = %ShortRestButton
@onready var _long_rest_button: Button = %LongRestButton
@onready var _arrive_button: Button = %ArriveButton
@onready var _event_panel: PanelContainer = %EventPanel
@onready var _event_title: Label = %EventTitle
@onready var _event_speaker: Label = %EventSpeaker
@onready var _event_text: RichTextLabel = %EventText
@onready var _event_choices: VBoxContainer = %EventChoices
@onready var _event_continue: Button = %EventContinue
@onready var _message: Label = %Message


## Configura antes de entrar na árvore (testes); sem isso, usa a viagem do ExplorationManager.
func setup(travel_system: TravelSystem, party: Array[CharacterData], inventory: Inventory) -> void:
	travel = travel_system
	_party = party
	_inventory = inventory
	_configured = true


func _ready() -> void:
	if not _configured:
		travel = ExplorationManager.current_travel()
		_party = PartyManager.members
		_inventory = PartyManager.inventory
	_event_panel.visible = false
	_advance_button.pressed.connect(advance)
	_short_rest_button.pressed.connect(short_rest)
	_long_rest_button.pressed.connect(long_rest)
	_arrive_button.pressed.connect(arrive)
	_event_continue.pressed.connect(close_event)
	if travel == null or _party.is_empty():
		_message.text = "Nenhuma viagem em andamento."
		_advance_button.disabled = true
		return
	var outcome := ExplorationManager.take_combat_outcome()
	if travel.pending.get("kind") == "combat" and outcome != CombatManager.Outcome.NONE:
		_message.text = travel.resolve_combat(outcome)
		_store()
	var route := travel.route(Content.registry)
	_strip.configure(travel.total_segments(Content.registry), travel.segments_done,
			Content.registry.get_entry("map", route["from_map"]).get("name", ""),
			Content.registry.get_entry("map", route["to_map"]).get("name", ""))
	_refresh()
	if travel.pending.get("kind") == "event":
		_show_event()
	_advance_button.grab_focus()


func is_busy() -> bool:
	return _busy


func advance() -> void:
	if _busy or _event_open:
		return
	var result := travel.advance(_party, Content.registry, _inventory)
	if not result["ok"]:
		_message.text = result["error"]
		return
	_store()
	_busy = true
	_refresh()
	await _strip.walk_to(travel.segments_done, animations_enabled)
	_busy = false
	_message.text = result["text"]
	match result["kind"]:
		"event":
			_show_event()
		"combat":
			_message.text = "%s Prepare-se!" % result["text"]
			_busy = true
			_refresh()
			if animations_enabled and combat_delay > 0.0:
				await get_tree().create_timer(combat_delay).timeout
			ExplorationManager.begin_travel_encounter(result["id"])
			_busy = false
	_refresh()


func choose(choice_id: String) -> Dictionary:
	var result := travel.choose_option(choice_id, _party, Content.registry, _inventory)
	if not result["ok"]:
		_message.text = result["error"]
		return result
	_store()
	for child in _event_choices.get_children():
		child.queue_free()
	var lines := PackedStringArray()
	var check: D20Test = result["check"]
	if check != null:
		lines.append("[color=#8597b8]Teste: %d %s = %d contra CD %d — %s[/color]" % [check.natural,
				Ability.format_modifier(check.modifier), check.total, check.dc, "sucesso" if check.success else "falha"])
	lines.append(result["text"])
	if not result["effects"].is_empty():
		lines.append("[b]%s[/b]" % ", ".join(result["effects"]))
	_event_text.text = "\n\n".join(lines)
	_event_continue.visible = true
	_event_continue.grab_focus()
	_refresh()
	return result


func close_event() -> void:
	_event_panel.visible = false
	_event_open = false
	_refresh()
	_advance_button.grab_focus()


func short_rest() -> void:
	if _busy or _event_open:
		return
	var result := travel.short_rest(_party, Content.registry)
	_message.text = result["error"] if not result["ok"] else "Descanso curto: +%d PV." % result["healed"]
	_store()
	_refresh()


func long_rest() -> void:
	if _busy or _event_open:
		return
	var result := travel.long_rest(_party, Content.registry, _inventory)
	_message.text = result["error"] if not result["ok"] else "Acampamento: +%d PV, Dados de Vida recuperados." % result["healed"]
	_store()
	_refresh()


func arrive() -> void:
	if not travel.is_arrived(Content.registry):
		return
	ExplorationManager.finish_travel()


# --- Exibição -----------------------------------------------------------------

func _show_event() -> void:
	var event := Content.registry.get_entry("event", travel.pending["id"])
	_event_open = true
	_event_title.text = event["name"]
	_event_speaker.text = event.get("speaker_name", "")
	_event_speaker.visible = not _event_speaker.text.is_empty()
	_event_text.text = event["text"]
	_event_continue.visible = false
	for child in _event_choices.get_children():
		child.queue_free()
	for choice: Dictionary in event["choices"]:
		var button := Button.new()
		button.text = choice["label"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(choose.bind(choice["id"]))
		_event_choices.add_child(button)
	_event_panel.visible = true
	_refresh()
	if _event_choices.get_child_count() > 0:
		(_event_choices.get_child(0) as Button).grab_focus.call_deferred()


func _refresh() -> void:
	var route := travel.route(Content.registry)
	_title.text = route.get("name", "Viagem")
	_clock.text = travel.time_label()
	var leader := _party[0]
	var sheet := CharacterSheet.build(leader, Content.registry)
	_status.text = "%s · PV %d/%d · Dados de Vida %d/%d · Rações %d%s" % [leader.name, leader.current_hp, sheet.max_hp,
			Rest.hit_dice_left(leader), RulesEngine.hit_dice_total(leader.level), _inventory.count(Inventory.RATIONS),
			" · com fome" if travel.hungry else ""]
	_log.text = "\n".join(PackedStringArray(travel.log))
	var arrived := travel.is_arrived(Content.registry)
	var blocked := _busy or _event_open or not travel.pending.is_empty()
	_advance_button.visible = not arrived
	_advance_button.disabled = blocked
	_arrive_button.visible = arrived
	_arrive_button.disabled = _busy or _event_open
	var can_heal := Rest.hit_dice_left(leader) > 0 and leader.current_hp < sheet.max_hp
	_short_rest_button.disabled = blocked or not (can_heal or Spellcasting.short_rest_would_restore(leader, Content.registry))
	_long_rest_button.disabled = blocked or _inventory.count(Inventory.RATIONS) < _party.size()


func _store() -> void:
	if not _configured:
		ExplorationManager.store_travel(travel)
		SaveManager.request_autosave("viagem")


## Motivo para não salvar agora ("" se a viagem está num estado consistente).
func save_blocker() -> String:
	if travel == null:
		return "não há viagem em andamento"
	if _busy:
		return "o grupo está se deslocando"
	if travel.pending.get("kind") == "combat":
		return "um combate está começando"
	return ""
