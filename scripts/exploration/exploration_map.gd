class_name ExplorationMap
extends Node2D
## Controlador de um mapa de exploração: limites da câmera, aviso de interação,
## falas com retrato, ficha do personagem, companheiros (seguidores e estalagem) e início/retorno de
## encontros.
## Espera os nós únicos %Terrain (com a camada Ground), %Player e %Hud.

const NO_CHARACTER_MESSAGE := "Nenhum personagem no grupo. Use \"Novo jogo\" no menu para criar um."
const NO_CHARACTER_COMBAT_MESSAGE := "Algo se move entre as sombras... mas não há ninguém no grupo para lutar."
const PLAYER_PORTRAIT := preload("res://assets/portraits/hero_portrait.png")
const CONFIRM_HINT := "[E] Confirmar · [Esc] Cancelar"
const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"
const ENDING_SCENE := "res://scenes/menus/ending_screen.tscn"
const NEXT_MEMBER_HINT := "[Tab] próximo membro"
## Distância (px) entre pontos do rastro do líder e quantos pontos separam cada seguidor.
const TRAIL_STEP := 4.0
const TRAIL_GAP := 5

## Ação aguardando confirmação (texto do Interactable.action).
var _pending_action: String = ""
## Conversa em andamento (null fora de diálogo) e avisos acumulados durante ela.
var _dialogue: DialogueRunner = null
var _dialogue_notes: Array[String] = []
## Tamanho do grupo no início da conversa (recrutar muda o grupo e os seguidores).
var _dialogue_party_size: int = 0
## Recompensas da missão final, guardadas ao fim da conversa para a tela de conclusão.
var _ending_rewards: Array[String] = []
## Membro do grupo mostrado na ficha/inventário/escolhas (Tab troca) e painel aberto agora.
var _viewed: int = 0
var _open_kind: String = ""
## Companheiros andando atrás do líder e o rastro (mais recente por último) que eles seguem.
var _followers: Array[PartyFollower] = []
var _trail: Array[Vector2] = []

@onready var _ground: TileMapLayer = %Terrain.get_node("Ground")
@onready var _player: Player = %Player
@onready var _hud: ExplorationHud = %Hud


func _ready() -> void:
	var back: Variant = ExplorationManager.take_return_position(scene_file_path)
	var entrance := ExplorationManager.take_entrance(scene_file_path)
	if back is Vector2:
		_player.global_position = back
		_player.reset_physics_interpolation()
	elif not entrance.is_empty() and has_node("Entrances/%s" % entrance):
		_player.global_position = (get_node("Entrances/%s" % entrance) as Node2D).global_position
		_player.reset_physics_interpolation()
	_apply_backdrop()
	_configure_camera_limits()
	_player.interaction_target_changed.connect(_on_interaction_target_changed)
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var interactable := node as Interactable
		if interactable != null and is_ancestor_of(interactable):
			interactable.interacted.connect(_on_interacted)
	for node in get_tree().get_nodes_in_group(EncounterTrigger.GROUP):
		var trigger := node as EncounterTrigger
		if trigger != null and is_ancestor_of(trigger) and not trigger.is_queued_for_deletion():
			trigger.triggered.connect(_on_encounter_triggered)
	_hud.dialogue_choice.connect(choose_dialogue_option)
	_hud.pause_menu.resume_requested.connect(close_overlays)
	_hud.pause_menu.save_requested.connect(save_from_menu)
	_hud.pause_menu.title_requested.connect(return_to_title)
	_hud.inventory_panel.changed.connect(func() -> void: SaveManager.request_autosave("equipamento"))
	_hud.inventory_panel.changed.connect(_refresh_follower_looks)
	_hud.party_panel.join_requested.connect(_on_join_requested)
	_hud.party_panel.leave_requested.connect(_on_leave_requested)
	refresh_followers()
	var notes: Array[String] = []
	var message := ExplorationManager.take_return_message()
	if not message.is_empty():
		notes.append(message)
	notes.append_array(QuestManager.take_pending_messages())
	var map_id := _map_id()
	if not map_id.is_empty():
		notes.append_array(QuestManager.notify("reach_map", map_id))
	if not notes.is_empty():
		_show_player_line("\n".join(notes))
	refresh_objective()
	# Ponto seguro: chegada ao mapa (troca de área, volta de combate, missão atualizada).
	SaveManager.request_autosave("mapa")


## Tab troca o membro mostrado antes que a interface use a tecla para mudar o foco.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TAB \
			and _open_kind in ["sheet", "inventory", "choices"] and _hud.is_overlay_open():
		get_viewport().set_input_as_handled()
		cycle_member()


func _physics_process(_delta: float) -> void:
	if _followers.is_empty():
		return
	var here := _player.global_position
	if _trail.is_empty() or _trail[-1].distance_to(here) >= TRAIL_STEP:
		_trail.append(here)
		if _trail.size() > TRAIL_GAP * CompanionRoster.MAX_PARTY + 1:
			_trail.pop_front()
	for i in _followers.size():
		_followers[i].target = _trail[maxi(0, _trail.size() - 1 - TRAIL_GAP * (i + 1))]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"character_sheet"):
		get_viewport().set_input_as_handled()
		toggle_character_sheet()
	elif event.is_action_pressed(&"inventory"):
		get_viewport().set_input_as_handled()
		toggle_inventory()
	elif event.is_action_pressed(&"journal"):
		get_viewport().set_input_as_handled()
		toggle_journal()
	elif event.is_action_pressed(&"level_choices"):
		get_viewport().set_input_as_handled()
		toggle_choices()
	elif event.is_action_pressed(&"ui_cancel") and _hud.is_overlay_open():
		get_viewport().set_input_as_handled()
		close_overlays()
	elif event.is_action_pressed(&"ui_cancel") and _dialogue != null:
		get_viewport().set_input_as_handled()
		end_dialogue()
	elif event.is_action_pressed(&"ui_cancel") and _hud.is_message_open():
		get_viewport().set_input_as_handled()
		cancel_message()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		open_pause_menu()
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		handle_interact()


## Fecha a mensagem aberta ou, se não houver, aciona o objeto próximo ao jogador.
## Com a ficha aberta, não faz nada.
func handle_interact() -> void:
	if _hud.is_overlay_open():
		return
	if _dialogue != null:
		# Nó sem escolhas: E encerra; com escolhas, o jogador escolhe pelos botões.
		if _dialogue.choices().is_empty():
			end_dialogue()
		return
	if _hud.is_message_open():
		var action := _pending_action
		_pending_action = ""
		_hud.hide_message()
		_player.input_enabled = true
		_on_interaction_target_changed(_player.get_interaction_target())
		if not action.is_empty():
			_execute_action(action)
		return
	_player.try_interact()


## Fecha a mensagem sem executar a ação pendente.
func cancel_message() -> void:
	_pending_action = ""
	_hud.hide_message()
	_player.input_enabled = true
	_on_interaction_target_changed(_player.get_interaction_target())


# --- Menu e salvamento --------------------------------------------------------------

func open_pause_menu() -> void:
	_player.input_enabled = false
	_hud.hide_prompt()
	_hud.show_pause_menu(_save_status())


func is_pause_menu_open() -> bool:
	return _hud.pause_menu.visible


func save_from_menu() -> Dictionary:
	var result := SaveManager.save_now()
	_hud.pause_menu.set_status(result["message"] if not result["ok"] else "%s\n%s" % [result["message"], _save_status()])
	return result


## Volta ao título; o que não foi salvo se perde (o menu avisa).
func return_to_title() -> void:
	PartyManager.clear()
	QuestManager.reset()
	ExplorationManager.reset()
	if ExplorationManager.scene_changes_enabled:
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)


func _save_status() -> String:
	if SaveManager.last_saved_at <= 0:
		return "Ainda não há salvamento deste jogo."
	return "Último salvamento: %s. Ao voltar ao título, o que veio depois é perdido." % \
			_format_time(SaveManager.last_saved_at)


static func _format_time(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var local := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d/%02d %02d:%02d" % [local["day"], local["month"], local["hour"], local["minute"]]


## Motivo para não salvar agora ("" se o estado está consistente).
func save_blocker() -> String:
	if _dialogue != null:
		return "há uma conversa em andamento"
	if not _pending_action.is_empty():
		return "há uma ação aguardando confirmação"
	return ""


func player_position() -> Vector2:
	return _player.global_position


## Abre ou fecha a ficha do líder do grupo. Não abre por cima de uma mensagem.
func toggle_character_sheet() -> void:
	_toggle_overlay("sheet")


func toggle_inventory() -> void:
	_toggle_overlay("inventory")


func toggle_choices() -> void:
	_toggle_overlay("choices")


func toggle_journal() -> void:
	_toggle_overlay("journal")


func close_overlays() -> void:
	_open_kind = ""
	_hud.hide_overlays()
	_player.input_enabled = true
	_on_interaction_target_changed(_player.get_interaction_target())


## Ficha, inventário e diário: um por vez; a mesma tecla fecha.
func _toggle_overlay(kind: String) -> void:
	var open := {"sheet": _hud.is_sheet_open(), "inventory": _hud.inventory_panel.visible,
			"journal": _hud.journal_panel.visible, "choices": _hud.choices_overlay.visible}
	if open[kind]:
		close_overlays()
		return
	if _hud.is_message_open():
		return
	_player.input_enabled = false
	_hud.hide_prompt()
	if not PartyManager.has_party() and kind != "journal":
		_hud.show_message(NO_CHARACTER_MESSAGE)
		return
	_show_overlay(kind)


## Membro do grupo mostrado nos painéis (o líder por padrão).
func viewed_member() -> CharacterData:
	if not PartyManager.has_party():
		return null
	_viewed = clampi(_viewed, 0, PartyManager.members.size() - 1)
	return PartyManager.members[_viewed]


## Mostra o próximo membro do grupo no painel aberto (ficha, inventário ou escolhas).
func cycle_member() -> void:
	if PartyManager.members.size() <= 1 or not _open_kind in ["sheet", "inventory", "choices"]:
		return
	_viewed = (_viewed + 1) % PartyManager.members.size()
	_show_overlay(_open_kind)


func _show_overlay(kind: String) -> void:
	var leader := viewed_member()
	_open_kind = kind
	match kind:
		"sheet":
			_hud.show_sheet(CharacterSheet.build(leader, Content.registry))
		"inventory":
			_hud.show_inventory(PartyManager.inventory, leader, Content.registry)
			if not _hud.inventory_panel.changed.is_connected(_player.refresh_appearance):
				_hud.inventory_panel.changed.connect(_player.refresh_appearance)
		"journal":
			_hud.show_journal(QuestManager.log, Content.registry)
		"choices":
			_hud.show_choices(leader, Content.registry)
			if not _hud.choices_panel.changed.is_connected(_on_choices_changed):
				_hud.choices_panel.changed.connect(_on_choices_changed)
	if kind != "journal" and PartyManager.members.size() > 1:
		_hud.extend_overlay_hint(NEXT_MEMBER_HINT)


## Estalagem: quem vai no grupo e quem fica esperando.
func open_party_panel(status: String = "") -> void:
	if not PartyManager.has_party():
		_show_player_line(NO_CHARACTER_MESSAGE)
		return
	_player.input_enabled = false
	_hud.hide_prompt()
	_open_kind = "party"
	_hud.show_party(PartyManager.roster, PartyManager.members, Content.registry, status)


func _on_join_requested(c: CharacterData) -> void:
	var result := PartyManager.roster.join(c, PartyManager.members, Content.registry)
	_after_party_change(" ".join(result["lines"]) if result["ok"] else result["error"])


func _on_leave_requested(c: CharacterData) -> void:
	var result := PartyManager.roster.leave(c, PartyManager.members)
	_after_party_change("%s vai esperar na estalagem." % c.name if result["ok"] else result["error"])


func _after_party_change(status: String) -> void:
	PartyManager.party_changed.emit()
	refresh_followers()
	SaveManager.request_autosave("grupo")
	open_party_panel(status)


# --- Companheiros no mapa -------------------------------------------------------

## Cria (ou recria) os seguidores para os companheiros do grupo ativo.
func refresh_followers() -> void:
	for follower in _followers:
		follower.queue_free()
	_followers.clear()
	_trail.clear()
	if not PartyManager.has_party():
		return
	var parent: Node = _player.get_parent()
	for i in range(1, PartyManager.members.size()):
		var follower := PartyFollower.new()
		follower.name = "Follower%d" % i
		parent.add_child(follower)
		follower.setup(PartyManager.members[i], _player.global_position + Vector2(-6.0 * i, -2.0 * i))
		_followers.append(follower)


func followers() -> Array[PartyFollower]:
	return _followers


func _refresh_follower_looks() -> void:
	for follower in _followers:
		follower.refresh_appearance()


## Companheiros recrutados somem do mapa; os que dependem de um encontro aparecem depois dele.
func refresh_companions() -> void:
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if node is CompanionNpc and is_ancestor_of(node):
			(node as CompanionNpc).refresh()


# --- Diálogo ------------------------------------------------------------------

func start_dialogue(dialogue_id: String) -> void:
	var entry := Content.registry.get_entry("dialogue", dialogue_id)
	if entry.is_empty() or not PartyManager.has_party():
		_show_player_line(NO_CHARACTER_MESSAGE if not PartyManager.has_party() else "...")
		return
	_dialogue = DialogueRunner.new()
	_dialogue_notes.clear()
	_dialogue_party_size = PartyManager.members.size()
	_dialogue.begin(entry, QuestManager.log, PartyManager.members, PartyManager.inventory, Content.registry,
			PartyManager.roster, null, ExplorationManager.resolved_triggers)
	# Objetivo "conversar com": cumprido ao começar a conversa (depois de escolher a fala de abertura).
	_dialogue_notes.append_array(QuestManager.notify("talk", dialogue_id))
	_player.input_enabled = false
	_hud.hide_prompt()
	_show_dialogue_node()


func choose_dialogue_option(index: int) -> void:
	if _dialogue == null:
		return
	var result := _dialogue.choose(index)
	if not result["ok"]:
		return
	_dialogue_notes.append_array(result["lines"])
	if _dialogue.finished:
		end_dialogue()
	else:
		_show_dialogue_node()


func end_dialogue() -> void:
	var finished_final := _completed_final_quest()
	_dialogue = null
	refresh_objective()
	refresh_companions()
	if PartyManager.members.size() != _dialogue_party_size:
		PartyManager.party_changed.emit()
		refresh_followers()
	if finished_final:
		show_ending()
		return
	SaveManager.request_autosave("diálogo")
	_hud.hide_message()
	_player.input_enabled = true
	if not _dialogue_notes.is_empty():
		var notes := "\n".join(_dialogue_notes)
		_dialogue_notes.clear()
		_hud.show_message(notes)
		_player.input_enabled = false
		return
	_on_interaction_target_changed(_player.get_interaction_target())


func _completed_final_quest() -> bool:
	if _dialogue == null:
		return false
	_ending_rewards = _dialogue.reward_lines.duplicate()
	for quest_id in _dialogue.completed:
		if bool(Content.registry.get_entry("quest", quest_id).get("final", false)):
			return true
	return false


## Fim da aventura: salva o jogo (a missão final já está concluída) e abre a tela de conclusão.
func show_ending() -> void:
	ExplorationManager.ending_lines = _ending_rewards.duplicate()
	_dialogue_notes.clear()
	_hud.hide_message()
	SaveManager.save_now()
	if ExplorationManager.scene_changes_enabled:
		get_tree().change_scene_to_file.call_deferred(ENDING_SCENE)


## Atualiza o objetivo mostrado no canto da tela.
func refresh_objective() -> void:
	if not PartyManager.has_party():
		_hud.set_objective("")
		return
	var text := QuestManager.log.current_objective(Content.registry)
	if text.is_empty() and QuestManager.log.status("quest.goblin_chief") == QuestLog.Status.NOT_STARTED:
		text = "Fale com Ione, a chefe da vila, perto do poço de Ribeira"
	_hud.set_objective(text)


func is_in_dialogue() -> bool:
	return _dialogue != null


func _show_dialogue_node() -> void:
	var portrait_path := str(_dialogue.dialogue.get("portrait", ""))
	var portrait: Texture2D = load(portrait_path) if not portrait_path.is_empty() else null
	var companion_id := str(_dialogue.dialogue.get("companion", ""))
	if portrait == null and not companion_id.is_empty():
		var preview := CompanionNpc.preview(companion_id, Content.registry)
		if preview != null:
			portrait = Appearance.portrait_texture(preview, Content.registry)
	var options: Array[String] = []
	for choice in _dialogue.choices():
		options.append(choice["text"])
	var text: String = _dialogue.node["text"]
	if not _dialogue_notes.is_empty():
		text = "%s\n[%s]" % [text, " · ".join(_dialogue_notes)]
	_hud.show_dialogue(_dialogue.speaker(), portrait, text, options)


## Escolhas mudaram (talento, estilo...): PV máximos podem mudar e o progresso é salvo.
func _on_choices_changed() -> void:
	var member := viewed_member()
	if member != null:
		member.current_hp = mini(member.current_hp, CharacterSheet.build(member, Content.registry).max_hp)
	_player.refresh_appearance()
	_refresh_follower_looks()
	SaveManager.request_autosave("escolhas")


## Retrato do líder conforme a aparência escolhida.
func _leader_portrait() -> Texture2D:
	var leader: CharacterData = PartyManager.get_leader()
	if leader == null:
		return null
	if not Content.registry.has("species", leader.species_id):
		return PLAYER_PORTRAIT
	return Appearance.portrait_texture(leader, Content.registry)


func _map_id() -> String:
	for id in Content.registry.ids("map"):
		if Content.registry.get_entry("map", id).get("scene") == scene_file_path:
			return id
	return ""


## Fundo pintado (nó "Backdrop"), ou null em mapas ainda desenhados com tiles.
func backdrop() -> MapBackdrop:
	return get_node_or_null("Backdrop") as MapBackdrop


## Com fundo pintado, tiles, adereços e objetos fixos param de ser desenhados (as colisões continuam);
## personagens continuam visíveis por cima da pintura.
func _apply_backdrop() -> void:
	if backdrop() == null:
		return
	var transparent := Color(1, 1, 1, 0)
	%Terrain.modulate = transparent
	var props := get_node_or_null("Objects/Props") as CanvasItem
	if props != null:
		props.modulate = transparent
	for child in get_node("Objects").get_children():
		if child is Interactable and not child is Npc:
			var sprite := child.get_node_or_null("Sprite") as CanvasItem
			if sprite != null:
				sprite.visible = false


## Área do mapa em pixels: a do fundo pintado ou a dos tiles usados.
func get_map_rect() -> Rect2i:
	if backdrop() != null:
		return Rect2i(backdrop().map_rect)
	var used := _ground.get_used_rect()
	var tile_size := _ground.tile_set.tile_size
	return Rect2i(used.position * tile_size, used.size * tile_size)


func _configure_camera_limits() -> void:
	var camera := _player.get_node("Camera") as Camera2D
	var rect := get_map_rect()
	camera.limit_left = rect.position.x
	camera.limit_top = rect.position.y
	camera.limit_right = rect.end.x
	camera.limit_bottom = rect.end.y


func _on_interaction_target_changed(target: Interactable) -> void:
	if target == null or _hud.is_message_open() or _hud.is_overlay_open():
		_hud.hide_prompt()
	else:
		_hud.show_prompt(target.prompt_text)


func _on_interacted(source: Interactable) -> void:
	if source.action.begins_with("talk:"):
		start_dialogue(source.action.trim_prefix("talk:"))
		return
	if source.message_text.is_empty():
		return
	if not source.action.is_empty():
		_pending_action = source.action
		_player.input_enabled = false
		_hud.hide_prompt()
		var leader: CharacterData = PartyManager.get_leader()
		_hud.show_message(source.message_text, leader.name if leader != null else "",
				_leader_portrait(), CONFIRM_HINT)
		return
	if source.speaker_name.is_empty() and source.speaker_portrait == null:
		_show_player_line(source.message_text)
	else:
		_player.input_enabled = false
		_hud.hide_prompt()
		_hud.show_message(source.message_text, source.speaker_name, source.speaker_portrait)


## Fala do personagem do jogador, com nome e retrato em destaque (sem grupo, mensagem simples).
func _show_player_line(text: String) -> void:
	var leader: CharacterData = PartyManager.get_leader()
	_player.input_enabled = false
	_hud.hide_prompt()
	if leader == null:
		_hud.show_message(text)
	else:
		_hud.show_message(text, leader.name, _leader_portrait())


func _execute_action(action: String) -> void:
	if not PartyManager.has_party():
		_show_player_line(NO_CHARACTER_MESSAGE)
		return
	if action.begins_with("travel:"):
		_player.input_enabled = false
		ExplorationManager.begin_travel.call_deferred(action.trim_prefix("travel:"))
	elif action == "party":
		open_party_panel()
	elif action == "rest_long":
		var healed := 0
		for c in PartyManager.members:
			healed += Rest.long_rest(c, Content.registry)
		# Quem espera na estalagem também descansa.
		for c in PartyManager.roster.bench:
			Rest.long_rest(c, Content.registry)
		_show_player_line("Você descansa junto à fogueira até o amanhecer. PV e Dados de Vida restaurados (+%d PV)." % healed)
		SaveManager.request_autosave("descanso")
	else:
		push_error("Ação desconhecida: %s" % action)


func _on_encounter_triggered(trigger: EncounterTrigger) -> void:
	var leader: CharacterData = PartyManager.get_leader()
	if leader == null or leader.current_hp <= 0:
		_player.input_enabled = false
		_hud.hide_prompt()
		_hud.show_message(NO_CHARACTER_COMBAT_MESSAGE)
		return
	_player.input_enabled = false
	# Adiado: o sinal vem de um callback de física, onde não se pode remover a cena atual.
	ExplorationManager.begin_encounter.call_deferred(trigger.encounter_id, trigger.trigger_id, scene_file_path,
			_player.global_position)
