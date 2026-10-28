class_name ContentRegistry
extends RefCounted
## Carrega e valida os dados de conteúdo (JSON em res://data). Nada é executado a
## partir dos arquivos: apenas dados são lidos, validados e indexados por id estável.
##
## Formato de cada arquivo: { "schema_version": 1, "entries": [ { "id": "...", ... } ] }

const SCHEMA_VERSION := 1
const DATA_ROOT := "res://data"

const ABILITIES := ["str", "dex", "con", "int", "wis", "cha"]

## Escolhas que uma característica pode conceder (ver CharacterChoices).
const GRANTS := ["", "fighting_style", "feat", "epic_boon", "subclass", "weapon_mastery", "expertise", "skill",
		"invocation", "metamagic", "option", "wild_shape", "magical_discoveries", "mystic_arcanum", "spell_mastery",
		"signature_spells"]

const FEATURE_FIELDS := {
	"id": {"type": "string"},
	"name": {"type": "string"},
	"level": {"type": "int", "min": 1, "max": 20, "required": false, "default": 1},
	"description": {"type": "string"},
	"implemented": {"type": "bool"},
	## Escolha concedida ao ganhar a característica e quantas opções escolher.
	"grants": {"type": "string", "enum": GRANTS, "required": false, "default": ""},
	"count": {"type": "int", "min": 0, "max": 10, "required": false, "default": 1},
	## Quantidade por nível de classe (1..20), quando muda com o nível (ex.: Invocações Místicas).
	"count_by_level": {"type": "array", "of": "int", "min": 0, "max": 20, "allow_duplicates": true,
			"required": false, "default": []},
	## Perícias permitidas em grants = "expertise"/"skill" (vazio = qualquer uma aplicável).
	"skill_filter": {"type": "array", "of": "string", "ref": "skill", "required": false, "default": []},
	## Opções de grants = "option" (ex.: Ordem Divina: Protetor ou Taumaturgo).
	"options": {"type": "object_array", "required": false, "default": [], "fields": {
		"id": {"type": "string"},
		"name": {"type": "string"},
		"description": {"type": "string"},
	}},
	## Magias sempre preparadas pela característica (não contam no limite) e o recurso que permite
	## conjurá-las sem espaço (ex.: Golpe do Paladino, Inimigo Favorito).
	"spells": {"type": "array", "of": "string", "required": false, "default": []},
	"free_resource": {"type": "string", "required": false, "default": ""},
}

## Recursos de classe: valores por nível (1..20) — número, dados ("1d6"), "cha"/"wis" (modificador,
## mínimo 1) ou "5x" (5 x nível) — e recarga: short (tudo no curto), short_one (um uso no curto,
## tudo no longo), long, none (só tabela, ex.: dano da Fúria).
const RESOURCE_FIELDS := {
	"id": {"type": "string"},
	"name": {"type": "string"},
	"values": {"type": "array", "of": "string", "allow_duplicates": true, "min_length": 20, "max_length": 20},
	"recharge": {"type": "string", "enum": ["short", "short_one", "long", "none"]},
}

const COMMON_FIELDS := {
	"id": {"type": "string"},
	"name": {"type": "string"},
	"description": {"type": "string"},
	"source": {"type": "string", "enum": ["SRD 5.2.1", "original"]},
}

## Tipos de conteúdo: pasta, prefixo obrigatório do id e campos específicos.
const TYPES := {
	"species": {
		"dir": "species",
		"prefix": "species.",
		"fields": {
			"size": {"type": "string", "enum": ["small", "medium"]},
			"speed": {"type": "int", "min": 5, "max": 120},
			"darkvision": {"type": "int", "min": 0, "max": 300},
			"hp_bonus_per_level": {"type": "int", "min": 0, "max": 5},
			"damage_resistances": {"type": "array", "of": "string", "ref": "damage_type"},
			"extra_skill_choices": {"type": "int", "min": 0, "max": 4},
			## Perícias permitidas na escolha da espécie; vazio = qualquer perícia.
			"extra_skill_options": {"type": "array", "of": "string", "ref": "skill", "required": false, "default": []},
			"traits": {"type": "object_array", "fields": FEATURE_FIELDS},
		},
	},
	"class": {
		"dir": "classes",
		"prefix": "class.",
		"fields": {
			"hit_die": {"type": "int", "enum": [6, 8, 10, 12]},
			"primary_abilities": {"type": "array", "of": "string", "ref": "ability", "min_length": 1},
			"saving_throws": {"type": "array", "of": "string", "ref": "ability", "min_length": 2, "max_length": 2},
			"skill_choice_count": {"type": "int", "min": 0, "max": 6},
			"skill_options": {"type": "array", "of": "string", "ref": "skill", "min_length": 1},
			"expertise_choices": {"type": "int", "min": 0, "max": 4},
			"armor_training": {"type": "array", "of": "string", "enum": ["light", "medium", "heavy", "shield"]},
			"weapon_training": {"type": "array", "of": "string",
					"enum": ["simple", "martial", "martial_finesse_or_light", "martial_light"]},
			## Defesa sem Armadura: atributo somado à CA sem armadura ("" = não tem).
			"unarmored_defense_ability": {"type": "string", "enum": ["", "con", "wis"], "required": false, "default": ""},
			"unarmored_defense_allows_shield": {"type": "bool", "required": false, "default": true},
			"suggested_scores": {"type": "array", "of": "int", "min_length": 6, "max_length": 6,
					"allow_duplicates": true},
			"starting_armor": {"type": "string", "ref": "item", "ref_item_type": "armor"},
			"starting_shield": {"type": "bool"},
			"starting_weapons": {"type": "array", "of": "string", "ref": "item", "ref_item_type": "weapon",
					"allow_duplicates": true},
			"features": {"type": "object_array", "fields": FEATURE_FIELDS},
			## Conjuração (SRD 5.2.1): atributo, tipo de progressão de espaços e quantidades por nível (1..20).
			"spellcasting_ability": {"type": "string", "enum": ["", "int", "wis", "cha"], "required": false, "default": ""},
			"spellcasting_type": {"type": "string", "enum": ["", "full", "half", "pact"], "required": false, "default": ""},
			"cantrips_known": {"type": "array", "of": "int", "min": 0, "max": 10, "allow_duplicates": true,
					"required": false, "default": []},
			"prepared_spells": {"type": "array", "of": "int", "min": 0, "max": 30, "allow_duplicates": true,
					"required": false, "default": []},
			## Maestria em Armas: quantas armas por nível (1..20) e quais armas podem ser escolhidas.
			"weapon_mastery_counts": {"type": "array", "of": "int", "min": 0, "max": 10, "allow_duplicates": true,
					"required": false, "default": []},
			"weapon_mastery_rule": {"type": "string", "enum": ["", "melee", "proficient", "finesse_or_light"],
					"required": false, "default": ""},
			## Recursos com usos (Fúria, Inspiração, Foco...): valores por nível (1..20) e recarga.
			"resources": {"type": "object_array", "required": false, "default": [], "fields": RESOURCE_FIELDS},
		},
	},
	"spell": {
		"dir": "spells",
		"prefix": "spell.",
		"fields": {
			"level": {"type": "int", "min": 0, "max": 9},
			"school": {"type": "string", "enum": ["abjuration", "conjuration", "divination", "enchantment", "evocation",
					"illusion", "necromancy", "transmutation"]},
			"classes": {"type": "array", "of": "string", "ref": "class", "min_length": 1},
			"casting_time": {"type": "string", "enum": ["action", "bonus_action"]},
			## 0 = pessoal (área a partir do conjurador), 5 = toque.
			"range_feet": {"type": "int", "min": 0, "max": 300},
			## enemy/ally/any = criaturas; self = o conjurador; cone/cube/line = área a partir do conjurador;
			## sphere = esfera de raio area_feet num ponto ao alcance; emanation = em volta do conjurador (aliados);
			## point = casa livre ao alcance (teletransporte).
			"target": {"type": "string", "enum": ["enemy", "ally", "any", "self", "cone", "cube", "line", "sphere",
					"emanation", "point"]},
			"area_feet": {"type": "int", "min": 0, "max": 120, "required": false, "default": 0},
			## Alvos a mais por círculo acima do mínimo (Imobilizar Pessoa, Voo, Enfeitiçar Monstro).
			"upcast_targets": {"type": "bool", "required": false, "default": false},
			## Raios com jogada de ataque própria (Raio Ardente); +1 por círculo acima.
			"rays": {"type": "int", "min": 0, "max": 10, "required": false, "default": 0},
			## Segundo dano da magia (Tempestade de Gelo, Coluna de Chamas) e seu aumento por círculo.
			"extra_damage": {"type": "string", "dice": true, "required": false, "default": ""},
			"extra_damage_type": {"type": "string", "required": false, "default": ""},
			"upcast_extra": {"type": "string", "dice": true, "required": false, "default": ""},
			## Condição imposta: repete o teste no fim de cada turno, acaba ao sofrer dano, piora se falhar de novo.
			"repeat_save": {"type": "bool", "required": false, "default": false},
			"ends_on_damage": {"type": "bool", "required": false, "default": false},
			"escalate": {"type": "string", "required": false, "default": ""},
			"save_advantage": {"type": "bool", "required": false, "default": false},
			## Só afeta estes tipos de criatura (ex.: Imobilizar Pessoa: humanoide).
			"creature_types": {"type": "array", "of": "string", "required": false, "default": []},
			## Condições que a magia remove (Restauração Menor/Maior), uma por conjuração.
			"cleanse": {"type": "array", "of": "string", "required": false, "default": []},
			## Palavras de Poder: limite de PV para o efeito (abaixo dele) e dano acima.
			"hp_threshold": {"type": "int", "min": 0, "max": 999, "required": false, "default": 0},
			"max_targets": {"type": "int", "min": 1, "max": 6, "required": false, "default": 1},
			## "smite" = dano extra conjurado logo após acertar (Golpe Divino), não pelo menu de magias.
			## "condition_save" = teste de resistência sem dano; a falha aplica o efeito (ex.: Comando);
			## revive = volta com 1 PV; cleanse = remove condição; teleport = move o conjurador;
			## power_word = efeito abaixo de hp_threshold; full_heal = recupera todos os PV.
			"resolution": {"type": "string", "enum": ["spell_attack", "save", "auto", "heal", "buff", "smite", "condition_save",
					"revive", "cleanse", "teleport", "power_word", "full_heal"]},
			"save_ability": {"type": "string", "enum": ["", "str", "dex", "con", "int", "wis", "cha"], "required": false, "default": ""},
			"half_on_save": {"type": "bool", "required": false, "default": false},
			"damage": {"type": "string", "dice": true, "required": false, "default": ""},
			"damage_type": {"type": "string", "enum": ["", "acid", "bludgeoning", "cold", "fire", "force", "lightning",
					"necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder"], "required": false, "default": ""},
			## Tipos que o conjurador pode escolher (ex.: Orbe Cromático); o jogo usa o primeiro que o alvo não resiste.
			"damage_types": {"type": "array", "of": "string", "ref": "damage_type", "required": false, "default": []},
			"heal": {"type": "string", "dice": true, "required": false, "default": ""},
			"darts": {"type": "int", "min": 0, "max": 10, "required": false, "default": 0},
			"upcast_dice": {"type": "string", "dice": true, "required": false, "default": ""},
			"effect": {"type": "string", "enum": ["", "slowed", "mocked", "guided", "pushed", "ac_bonus", "blessed", "marked",
					"warded", "no_reactions", "poisoned", "prone", "paralyzed", "restrained", "frightened", "charmed",
					"incapacitated", "stunned", "kill", "blurred", "aid", "hope", "flying", "death_ward", "freedom", "fire_shield",
					"necrotic_ward", "dispel"],
					"required": false, "default": ""},
			"effect_value": {"type": "string", "required": false, "default": ""},
			"concentration": {"type": "bool", "required": false, "default": false},
			"vfx": {"type": "string", "enum": ["bolt", "ray", "darts", "pillar", "cone", "wave", "heal", "aura", "mark", "mock", "spray"]},
			"color": {"type": "string"},
		},
	},
	"background": {
		"dir": "backgrounds",
		"prefix": "background.",
		"fields": {
			"ability_options": {"type": "array", "of": "string", "ref": "ability", "min_length": 3, "max_length": 3},
			"skill_proficiencies": {"type": "array", "of": "string", "ref": "skill", "min_length": 2, "max_length": 2},
			"tool_proficiency": {"type": "string"},
			"feat_id": {"type": "string", "ref": "feat"},
			## Lista de magias do Iniciado em Magia concedido pelo antecedente ("" se outro talento).
			"feat_spell_list": {"type": "string", "enum": ["", "class.cleric", "class.druid", "class.wizard"],
					"required": false, "default": ""},
		},
	},
	"feat": {
		"dir": "feats",
		"prefix": "feat.",
		"fields": {
			"category": {"type": "string", "enum": ["origin", "general", "fighting_style", "epic_boon"]},
			"prerequisite_level": {"type": "int", "min": 1, "max": 20, "required": false, "default": 1},
			"prerequisite_ability": {"type": "string", "enum": ["", "str_or_dex_13"], "required": false, "default": ""},
			"requires_feature": {"type": "string", "enum": ["", "spellcasting"], "required": false, "default": ""},
			"repeatable": {"type": "bool", "required": false, "default": false},
			"ability_choices": {"type": "array", "of": "string", "ref": "ability", "required": false, "default": []},
			"ability_points": {"type": "int", "min": 0, "max": 2, "required": false, "default": 0},
			"ability_max": {"type": "int", "min": 20, "max": 30, "required": false, "default": 20},
			"implemented": {"type": "bool"},
		},
	},
	"subclass": {
		"dir": "subclasses",
		"prefix": "subclass.",
		"fields": {
			"class_id": {"type": "string", "ref": "class"},
			"features": {"type": "object_array", "fields": FEATURE_FIELDS},
			"resources": {"type": "object_array", "required": false, "default": [], "fields": RESOURCE_FIELDS},
			## Magias sempre preparadas por nível de classe (Domínio, Juramento, Patrono...).
			"always_prepared": {"type": "object_array", "required": false, "default": [], "fields": {
				"level": {"type": "int", "min": 1, "max": 20},
				"spells": {"type": "array", "of": "string"},
				## Só com esta opção escolhida (ex.: tipo de terra do Círculo da Terra).
				"option": {"type": "string", "required": false, "default": ""},
				## Recurso que permite conjurar uma delas sem espaço (Recuperação Natural).
				"free_resource": {"type": "string", "required": false, "default": ""},
			}},
		},
	},
	"monster": {
		"dir": "monsters",
		"prefix": "monster.",
		"fields": {
			"size": {"type": "string", "enum": ["tiny", "small", "medium", "large", "huge"]},
			"creature_type": {"type": "string"},
			"armor_class": {"type": "int", "min": 1, "max": 30},
			"hit_points": {"type": "int", "min": 1, "max": 999},
			"hit_dice": {"type": "string", "dice": true},
			"speed": {"type": "int", "min": 0, "max": 120},
			"fly_speed": {"type": "int", "min": 0, "max": 120, "required": false, "default": 0},
			## Ataques por ação de Ataque (Ataques Múltiplos do bloco); usado pela Forma Selvagem.
			"multiattack": {"type": "int", "min": 1, "max": 4, "required": false, "default": 1},
			"ability_scores": {"type": "array", "of": "int", "min": 1, "max": 30, "min_length": 6, "max_length": 6,
					"allow_duplicates": true},
			"challenge_rating": {"type": "string", "enum": ["0", "1/8", "1/4", "1/2", "1", "2", "3", "4", "5"]},
			"xp": {"type": "int", "min": 0},
			"damage_resistances": {"type": "array", "of": "string", "ref": "damage_type"},
			"attacks": {"type": "object_array", "min_length": 1, "fields": {
				"id": {"type": "string"},
				"name": {"type": "string"},
				"attack_type": {"type": "string", "enum": ["melee", "ranged"]},
				"attack_bonus": {"type": "int", "min": -5, "max": 20},
				"damage": {"type": "string", "dice": true},
				"damage_type": {"type": "string", "ref": "damage_type"},
				"reach": {"type": "int", "min": 0, "required": false, "default": 5},
				"range_normal": {"type": "int", "min": 0, "required": false, "default": 0},
				"range_long": {"type": "int", "min": 0, "required": false, "default": 0},
				## Dano adicional do acerto (ex.: veneno da mordida da aranha).
				"extra_damage": {"type": "string", "dice": true, "required": false, "default": ""},
				"extra_damage_type": {"type": "string", "required": false, "default": ""},
				## Condição imposta ao acertar (Caído, Agarrado) em alvos até o tamanho dado.
				"on_hit_condition": {"type": "string", "enum": ["", "prone", "grappled"], "required": false, "default": ""},
				"on_hit_max_size": {"type": "string", "enum": ["", "tiny", "small", "medium", "large", "huge"],
						"required": false, "default": ""},
				"escape_dc": {"type": "int", "min": 0, "max": 30, "required": false, "default": 0},
			}},
			"traits": {"type": "object_array", "fields": FEATURE_FIELDS},
			## Folha de sprite ("" = sem arte própria; só formas da Forma Selvagem).
			"sprite": {"type": "string", "required": false, "default": ""},
		},
	},
	"encounter": {
		"dir": "encounters",
		"prefix": "encounter.",
		"fields": {
			"enemies": {"type": "object_array", "min_length": 1, "fields": {
				"monster_id": {"type": "string", "ref": "monster"},
				"count": {"type": "int", "min": 1, "max": 8},
			}},
			"flee_allowed": {"type": "bool"},
			"arena_width": {"type": "int", "min": 6, "max": 16},
			"arena_height": {"type": "int", "min": 4, "max": 10},
			"intro_text": {"type": "string"},
			"reward_gold": {"type": "int", "min": 0, "max": 1000, "required": false, "default": 0},
			"reward_items": {"type": "object_array", "required": false, "default": [], "fields": {
				"item_id": {"type": "string", "ref": "item"},
				"count": {"type": "int", "min": 1, "max": 20},
			}},
		},
	},
	"map": {
		"dir": "maps",
		"prefix": "map.",
		"fields": {
			"scene": {"type": "string"},
			"region_id": {"type": "string", "ref": "region"},
		},
	},
	"region": {
		"dir": "regions",
		"prefix": "region.",
		"fields": {
			"danger": {"type": "int", "min": 1, "max": 5},
			## Peso de um trecho sem acontecimentos.
			"quiet_weight": {"type": "int", "min": 0, "max": 100},
			"table": {"type": "object_array", "min_length": 1, "fields": {
				"kind": {"type": "string", "enum": ["combat", "event"]},
				"id": {"type": "string"},
				"weight": {"type": "int", "min": 1, "max": 100},
				"time": {"type": "string", "enum": ["any", "day", "night"], "required": false, "default": "any"},
				"once": {"type": "bool", "required": false, "default": false},
			}},
		},
	},
	"route": {
		"dir": "routes",
		"prefix": "route.",
		"fields": {
			"from_map": {"type": "string", "ref": "map"},
			"to_map": {"type": "string", "ref": "map"},
			## Nome do Marker2D de chegada no mapa de destino.
			"to_entrance": {"type": "string"},
			"region_id": {"type": "string", "ref": "region"},
			"segments": {"type": "int", "min": 1, "max": 8},
			"hours_per_segment": {"type": "int", "min": 1, "max": 12},
			"start_hour": {"type": "int", "min": 0, "max": 23},
			## Acontecimentos garantidos em um trecho (uma vez por jogo), antes do sorteio.
			"scripted_events": {"type": "object_array", "required": false, "default": [], "fields": {
				"segment": {"type": "int", "min": 1, "max": 8},
				"kind": {"type": "string", "enum": ["event", "combat"]},
				"id": {"type": "string"},
			}},
		},
	},
	"event": {
		"dir": "events",
		"prefix": "event.",
		"fields": {
			"kind": {"type": "string", "enum": ["discovery", "npc", "hazard"]},
			"text": {"type": "string"},
			"speaker_name": {"type": "string", "required": false, "default": ""},
			"choices": {"type": "object_array", "min_length": 1, "max_length": 4, "fields": {
				"id": {"type": "string"},
				"label": {"type": "string"},
				"skill": {"type": "string", "ref": "skill", "required": false, "default": ""},
				"dc": {"type": "int", "min": 0, "max": 30, "required": false, "default": 0},
				"success_text": {"type": "string"},
				"failure_text": {"type": "string", "required": false, "default": ""},
				"success_rations": {"type": "int", "min": -5, "max": 10, "required": false, "default": 0},
				"success_xp": {"type": "int", "min": 0, "max": 500, "required": false, "default": 0},
				"success_heal": {"type": "string", "dice": true, "required": false, "default": ""},
				"failure_damage": {"type": "string", "dice": true, "required": false, "default": ""},
				"failure_damage_type": {"type": "string", "ref": "damage_type", "required": false, "default": "bludgeoning"},
				"failure_rations": {"type": "int", "min": -5, "max": 0, "required": false, "default": 0},
			}},
		},
	},
	"companion": {
		"dir": "companions",
		"prefix": "companion.",
		"fields": {
			"species_id": {"type": "string", "ref": "species"},
			"class_id": {"type": "string", "ref": "class"},
			"background_id": {"type": "string", "ref": "background"},
			## Papel no grupo e como recrutar (texto mostrado na tela do grupo).
			"role": {"type": "string"},
			"how_to_recruit": {"type": "string"},
			"map_id": {"type": "string", "ref": "map"},
			"dialogue_id": {"type": "string", "ref": "dialogue"},
			## Perícias preferidas (as que a classe permitir entram primeiro).
			"skills": {"type": "array", "of": "string", "ref": "skill", "required": false, "default": []},
			## Aparência (mesmas chaves de CharacterData.appearance; conferida pelos testes).
			"appearance": {"type": "object", "required": false, "default": {}},
		},
	},
	"quest": {
		"dir": "quests",
		"prefix": "quest.",
		"fields": {
			"giver": {"type": "string"},
			"objectives": {"type": "object_array", "min_length": 1, "fields": {
				"id": {"type": "string"},
				"text": {"type": "string"},
				## talk = começar a conversa com o diálogo de id "target".
				"type": {"type": "string", "enum": ["defeat_encounter", "reach_map", "talk"]},
				"target": {"type": "string"},
			}},
			## Missão principal: concluí-la mostra a tela de conclusão da aventura.
			"final": {"type": "bool", "required": false, "default": false},
			"reward_xp": {"type": "int", "min": 0, "max": 10000},
			"reward_gold": {"type": "int", "min": 0, "max": 10000},
			"reward_items": {"type": "object_array", "required": false, "default": [], "fields": {
				"item_id": {"type": "string", "ref": "item"},
				"count": {"type": "int", "min": 1, "max": 20},
			}},
		},
	},
	"dialogue": {
		"dir": "dialogues",
		"prefix": "dialogue.",
		"fields": {
			"speaker": {"type": "string"},
			"portrait": {"type": "string", "required": false, "default": ""},
			## Companheiro que fala: o retrato é pintado a partir da aparência dele.
			"companion": {"type": "string", "ref": "companion", "required": false, "default": ""},
			## Primeira entrada cuja condição é verdadeira define o nó inicial.
			"entries": {"type": "object_array", "min_length": 1, "fields": {
				"condition": {"type": "string", "required": false, "default": ""},
				"node": {"type": "string"},
			}},
			"nodes": {"type": "object_array", "min_length": 1, "fields": {
				"id": {"type": "string"},
				"text": {"type": "string"},
				"choices": {"type": "object_array", "required": false, "default": [], "fields": {
					"text": {"type": "string"},
					"next": {"type": "string", "required": false, "default": ""},
					"condition": {"type": "string", "required": false, "default": ""},
					## Ações separadas por ";" (ex.: "pay_gold:15;recruit:companion.kael").
					"action": {"type": "string", "required": false, "default": ""},
					## Teste de perícia do melhor membro do grupo: sucesso vai para "next" (e aplica a ação),
					## falha vai para "fail_next".
					"check": {"type": "string", "ref": "skill", "required": false, "default": ""},
					"dc": {"type": "int", "min": 0, "max": 30, "required": false, "default": 0},
					"fail_next": {"type": "string", "required": false, "default": ""},
				}},
			}},
		},
	},
	"appearance": {
		"dir": "appearance",
		"prefix": "appearance.",
		"fields": {
			"species_id": {"type": "string", "ref": "species"},
			"skin_tones": {"type": "array", "of": "string", "min_length": 1},
			"hair_colors": {"type": "array", "of": "string", "min_length": 1},
			"horn_color": {"type": "string", "required": false, "default": "#d8ccb4"},
			"snout": {"type": "bool", "required": false, "default": false},
			"leg_length": {"type": "int", "min": 4, "max": 8, "required": false, "default": 7},
			"torso_length": {"type": "int", "min": 6, "max": 11, "required": false, "default": 9},
			"width": {"type": "int", "min": -1, "max": 2, "required": false, "default": 0},
			"head_radius": {"type": "number", "min": 4.5, "max": 7.0, "required": false, "default": 6.0},
			"body": {"type": "array", "of": "string", "min_length": 1}, "build": {"type": "array", "of": "string", "min_length": 1}, "hair_style": {"type": "array", "of": "string", "min_length": 1}, "beard": {"type": "array", "of": "string", "min_length": 1}, "ears": {"type": "array", "of": "string", "min_length": 1}, "horns": {"type": "array", "of": "string", "min_length": 1},
			"tail": {"type": "array", "of": "string", "min_length": 1}, "marks": {"type": "array", "of": "string", "min_length": 1}, "face": {"type": "array", "of": "string", "min_length": 1}, "accessory": {"type": "array", "of": "string", "min_length": 1}, "cloak": {"type": "array", "of": "string", "min_length": 1},
		},
	},
	"item": {
		"dir": "items",
		"prefix": "item.",
		"fields": {
			"item_type": {"type": "string", "enum": ["armor", "shield", "weapon", "consumable", "gear"]},
			"weight_lb": {"type": "number", "min": 0},
			"cost_gp": {"type": "number", "min": 0},
		},
		"variants_by": "item_type",
		"variants": {
			"armor": {
				"armor_category": {"type": "string", "enum": ["light", "medium", "heavy"]},
				"base_ac": {"type": "int", "min": 10, "max": 20},
				"dex_cap": {"type": "int", "min": -1, "max": 10},
				"strength_requirement": {"type": "int", "min": 0, "max": 20},
				"stealth_disadvantage": {"type": "bool"},
			},
			"shield": {
				"ac_bonus": {"type": "int", "min": 1, "max": 5},
			},
			"consumable": {
				"effect": {"type": "string", "enum": ["heal"]},
				"effect_dice": {"type": "string", "dice": true},
				"use_time": {"type": "string", "enum": ["action", "bonus_action"]},
			},
			"gear": {},
			"weapon": {
				"weapon_category": {"type": "string", "enum": ["simple", "martial"]},
				"attack_type": {"type": "string", "enum": ["melee", "ranged"]},
				"damage": {"type": "string", "dice": true},
				"damage_type": {"type": "string", "ref": "damage_type"},
				"properties": {"type": "array", "of": "string", "enum": [
						"ammunition", "finesse", "heavy", "light", "loading", "reach",
						"thrown", "two_handed", "versatile"]},
				"versatile_damage": {"type": "string", "dice": true, "required": false, "default": ""},
				"range_normal": {"type": "int", "min": 0, "required": false, "default": 0},
				"range_long": {"type": "int", "min": 0, "required": false, "default": 0},
				"mastery": {"type": "string", "enum": [
						"cleave", "graze", "nick", "push", "sap", "slow", "topple", "vex"]},
			},
		},
	},
}

var errors: Array[String] = []
var _entries := {}  # tipo -> { id -> registro }
var _source_file := {}  # id -> arquivo de origem


## Carrega todos os tipos a partir de root. Retorna true se não houve erros.
func load_all(root: String = DATA_ROOT) -> bool:
	errors.clear()
	_entries.clear()
	_source_file.clear()
	var pending_refs: Array[Dictionary] = []
	for type_name: String in TYPES:
		_entries[type_name] = {}
		var dir_path := root.path_join(TYPES[type_name]["dir"])
		if not DirAccess.dir_exists_absolute(dir_path):
			errors.append("%s: pasta de conteúdo ausente" % dir_path)
			continue
		var files := Array(DirAccess.get_files_at(dir_path))
		files.sort()
		for file: String in files:
			if file.ends_with(".json"):
				_load_file(type_name, dir_path.path_join(file), pending_refs)
	_check_references(pending_refs)
	_check_consistency()
	return errors.is_empty()


## Carrega registros a partir de dicionários já em memória (para testes).
func load_from_dictionaries(data_by_type: Dictionary) -> bool:
	errors.clear()
	_entries.clear()
	_source_file.clear()
	var pending_refs: Array[Dictionary] = []
	for type_name: String in TYPES:
		_entries[type_name] = {}
		_load_document(type_name, {"schema_version": SCHEMA_VERSION, "entries": data_by_type.get(type_name, [])},
				"<memória:%s>" % type_name, pending_refs)
	_check_references(pending_refs)
	_check_consistency()
	return errors.is_empty()


func has(type_name: String, id: String) -> bool:
	return _entries.get(type_name, {}).has(id)


func get_entry(type_name: String, id: String) -> Dictionary:
	return _entries.get(type_name, {}).get(id, {})


## Ids de um tipo, em ordem alfabética.
func ids(type_name: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(_entries.get(type_name, {}).keys())
	result.sort()
	return result


func _load_file(type_name: String, path: String, pending_refs: Array[Dictionary]) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("%s: arquivo vazio ou ilegível (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s:%d: JSON inválido: %s" % [path, json.get_error_line(), json.get_error_message()])
		return
	if not json.data is Dictionary:
		errors.append("%s: esperado objeto com 'schema_version' e 'entries'" % path)
		return
	_load_document(type_name, json.data, path, pending_refs)


func _load_document(type_name: String, document: Dictionary, path: String,
		pending_refs: Array[Dictionary]) -> void:
	if int(document.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("%s: schema_version %s não suportada (esperado %d)" % [
				path, str(document.get("schema_version")), SCHEMA_VERSION])
		return
	if not document.get("entries") is Array:
		errors.append("%s: 'entries' deve ser uma lista" % path)
		return
	var type_def: Dictionary = TYPES[type_name]
	for i in document["entries"].size():
		var raw: Variant = document["entries"][i]
		var context := "%s[%d]" % [path.get_file(), i]
		if not raw is Dictionary:
			errors.append("%s: registro deve ser um objeto" % context)
			continue
		var id: String = str(raw.get("id", ""))
		if not id.is_empty():
			context = "%s (%s)" % [context, id]
		var schema: Dictionary = COMMON_FIELDS.duplicate()
		schema.merge(type_def["fields"])
		if type_def.has("variants_by"):
			var variant_key: String = str(raw.get(type_def["variants_by"], ""))
			schema.merge(type_def["variants"].get(variant_key, {}))
		var result := ContentSchema.validate(raw, schema, context, pending_refs)
		errors.append_array(result[1])
		if not id.begins_with(type_def["prefix"]):
			errors.append("%s: id deve começar com '%s'" % [context, type_def["prefix"]])
			continue
		if _entries[type_name].has(id):
			errors.append("%s: id duplicado (já definido em %s)" % [context, _source_file[id]])
			continue
		_entries[type_name][id] = result[0]
		_source_file[id] = path


func _check_references(pending_refs: Array[Dictionary]) -> void:
	for ref in pending_refs:
		var target: Dictionary = get_entry(ref["type"], ref["id"])
		if target.is_empty():
			errors.append("%s: referência a %s inexistente '%s'" % [ref["where"], ref["type"], ref["id"]])
		elif not ref["item_type"].is_empty() and target.get("item_type") != ref["item_type"]:
			errors.append("%s: '%s' deveria ser do tipo %s" % [ref["where"], ref["id"], ref["item_type"]])


const DIALOGUE_CONDITIONS: Array[String] = ["quest_available", "quest_active", "quest_ready", "quest_completed",
		"objective_open", "quest_started", "objective_done", "companion_recruited", "companion_available",
		"gold_at_least", "gold_below", "trigger_resolved"]
## give_item:<item_id>#<quantidade> entrega um item ao grupo; recruit:<companion_id> recruta;
## pay_gold:<n> paga ouro do grupo.
const DIALOGUE_ACTIONS: Array[String] = ["start_quest", "complete_quest", "give_item", "recruit", "pay_gold"]


## Diálogos: nós referenciados existem, condições e ações conhecidas apontam para missões existentes.
func _check_dialogue(id: String, dialogue: Dictionary) -> void:
	var node_ids := {}
	for node: Dictionary in dialogue.get("nodes", []):
		node_ids[node.get("id")] = true
	if not str(dialogue.get("portrait", "")).is_empty() and not ResourceLoader.exists(dialogue["portrait"]):
		errors.append("%s: retrato inexistente '%s'" % [id, dialogue["portrait"]])
	for entry: Dictionary in dialogue.get("entries", []):
		if not node_ids.has(entry.get("node")):
			errors.append("%s: entrada aponta para nó inexistente '%s'" % [id, entry.get("node")])
		_check_rule(id, str(entry.get("condition", "")), DIALOGUE_CONDITIONS, "condição")
	for node: Dictionary in dialogue.get("nodes", []):
		for choice: Dictionary in node.get("choices", []):
			var next := str(choice.get("next", ""))
			if not next.is_empty() and not node_ids.has(next):
				errors.append("%s.%s: escolha aponta para nó inexistente '%s'" % [id, node.get("id"), next])
			_check_rule(id, str(choice.get("condition", "")), DIALOGUE_CONDITIONS, "condição")
			_check_rule(id, str(choice.get("action", "")), DIALOGUE_ACTIONS, "ação")
			var fail_next := str(choice.get("fail_next", ""))
			if not str(choice.get("check", "")).is_empty():
				if int(choice.get("dc", 0)) <= 0:
					errors.append("%s.%s: teste de perícia sem CD" % [id, node.get("id")])
				if not fail_next.is_empty() and not node_ids.has(fail_next):
					errors.append("%s.%s: falha aponta para nó inexistente '%s'" % [id, node.get("id"), fail_next])


func _check_rule(id: String, rule: String, allowed: Array[String], label: String) -> void:
	if rule.is_empty():
		return
	# Ações podem vir encadeadas: "pay_gold:15;recruit:companion.kael".
	if ";" in rule:
		for piece in rule.split(";"):
			_check_rule(id, piece.strip_edges(), allowed, label)
		return
	var parts := rule.split(":", true, 1)
	if parts.size() != 2 or not parts[0] in allowed:
		errors.append("%s: %s desconhecida '%s'" % [id, label, rule])
	elif parts[0] == "give_item":
		if not has("item", parts[1].split("#")[0]):
			errors.append("%s: %s com item inexistente '%s'" % [id, label, parts[1]])
	elif parts[0] in ["recruit", "companion_recruited", "companion_available"]:
		if not has("companion", parts[1]):
			errors.append("%s: %s com companheiro inexistente '%s'" % [id, label, parts[1]])
	elif parts[0] in ["gold_at_least", "gold_below", "pay_gold"]:
		if not parts[1].is_valid_int() or int(parts[1]) < 0:
			errors.append("%s: %s com valor inválido '%s'" % [id, label, parts[1]])
	elif parts[0] == "trigger_resolved":
		if parts[1].is_empty():
			errors.append("%s: %s sem gatilho" % [id, label])
	elif not has("quest", parts[1].split("#")[0]):
		errors.append("%s: %s com missão inexistente '%s'" % [id, label, parts[1]])
	elif "#" in parts[1]:
		# "objective_open:quest.x#objetivo": o objetivo precisa existir na missão.
		var ids := parts[1].split("#")
		var objectives: Array = get_entry("quest", ids[0]).get("objectives", []).map(func(o: Dictionary) -> String: return str(o["id"]))
		if not ids[1] in objectives:
			errors.append("%s: %s com objetivo inexistente '%s'" % [id, label, parts[1]])


## Regras entre campos que o esquema sozinho não expressa.
func _check_consistency() -> void:
	for id in ids("class"):
		var entry := get_entry("class", id)
		if entry.is_empty() or not entry.has("skill_options"):
			continue
		if int(entry["skill_choice_count"]) > entry["skill_options"].size():
			errors.append("%s: skill_choice_count maior que o número de opções" % id)
		var armor := get_entry("item", entry.get("starting_armor", ""))
		if not armor.is_empty() and not armor.get("armor_category") in entry["armor_training"]:
			errors.append("%s: armadura inicial '%s' exige treinamento que a classe não tem" % [id, armor["id"]])
		if entry.get("starting_shield", false) and not "shield" in entry["armor_training"]:
			errors.append("%s: escudo inicial sem treinamento com escudo" % id)
		var suggested: Array = entry.get("suggested_scores", [])
		if suggested.size() == 6:
			var scores := {}
			for i in 6:
				scores[Ability.ALL[i]] = suggested[i]
			for problem in RulesEngine.validate_standard_array(scores):
				errors.append("%s: suggested_scores: %s" % [id, problem])
	for id in ids("species"):
		var species := get_entry("species", id)
		var options: Array = species.get("extra_skill_options", [])
		if not options.is_empty() and int(species.get("extra_skill_choices", 0)) > options.size():
			errors.append("%s: extra_skill_choices maior que o número de opções" % id)
		if not options.is_empty() and int(species.get("extra_skill_choices", 0)) == 0:
			errors.append("%s: extra_skill_options sem extra_skill_choices" % id)
	for id in ids("monster"):
		var monster := get_entry("monster", id)
		if monster.has("hit_dice") and DiceExpression.parse(str(monster["hit_dice"])).is_valid:
			var dice := DiceExpression.parse(str(monster["hit_dice"]))
			var hp := int(monster.get("hit_points", 0))
			if hp < dice.minimum() or hp > dice.maximum():
				errors.append("%s: hit_points %d fora do intervalo de %s" % [id, hp, monster["hit_dice"]])
		if not str(monster.get("sprite", "")).is_empty() and not ResourceLoader.exists(str(monster["sprite"])):
			errors.append("%s: sprite inexistente '%s'" % [id, monster["sprite"]])
		for attack: Dictionary in monster.get("attacks", []):
			if attack.get("attack_type") == "ranged" and int(attack.get("range_normal", 0)) <= 0:
				errors.append("%s: ataque à distância '%s' sem range_normal" % [id, attack.get("id")])
	for id in ids("encounter"):
		var encounter := get_entry("encounter", id)
		var total := 0
		for group: Dictionary in encounter.get("enemies", []):
			total += int(group.get("count", 0))
		if encounter.has("arena_width") and total > int(encounter["arena_height"]):
			errors.append("%s: %d inimigos não cabem na coluna inicial da arena" % [id, total])
	for id in ids("map"):
		var map := get_entry("map", id)
		if map.has("scene") and not ResourceLoader.exists(str(map["scene"])):
			errors.append("%s: cena inexistente '%s'" % [id, map["scene"]])
	for id in ids("region"):
		var table: Array = get_entry("region", id).get("table", [])
		for i in table.size():
			var row: Dictionary = table[i]
			var type_name := "encounter" if row.get("kind") == "combat" else "event"
			if not has(type_name, str(row.get("id", ""))):
				errors.append("%s.table[%d]: %s inexistente '%s'" % [id, i, type_name, row.get("id", "")])
	for id in ids("route"):
		var route := get_entry("route", id)
		if route.get("from_map") == route.get("to_map"):
			errors.append("%s: origem e destino iguais" % id)
	for id in ids("event"):
		for choice: Dictionary in get_entry("event", id).get("choices", []):
			var has_check := not str(choice.get("skill", "")).is_empty()
			if has_check and int(choice.get("dc", 0)) <= 0:
				errors.append("%s.%s: teste de perícia sem CD" % [id, choice.get("id")])
			if has_check and str(choice.get("failure_text", "")).is_empty():
				errors.append("%s.%s: teste de perícia sem failure_text" % [id, choice.get("id")])
	for id in ids("quest"):
		for objective: Dictionary in get_entry("quest", id).get("objectives", []):
			var target_type: String = {"defeat_encounter": "encounter", "reach_map": "map", "talk": "dialogue"}.get(
					str(objective.get("type")), "map")
			if not has(target_type, str(objective.get("target", ""))):
				errors.append("%s.%s: %s inexistente '%s'" % [id, objective.get("id"), target_type, objective.get("target")])
	for id in ids("dialogue"):
		_check_dialogue(id, get_entry("dialogue", id))
	for id in ids("spell"):
		var spell := get_entry("spell", id)
		if not Color.html_is_valid(str(spell["color"])):
			errors.append("%s: cor inválida" % id)
		if spell["resolution"] in ["spell_attack", "save", "auto"] and (str(spell["damage"]).is_empty() or str(spell["damage_type"]).is_empty()):
			errors.append("%s: magia de dano sem dano/tipo" % id)
		if spell["resolution"] == "condition_save" and (str(spell["save_ability"]).is_empty() or str(spell["effect"]).is_empty()):
			errors.append("%s: magia de condição sem atributo ou efeito" % id)
		if spell["resolution"] == "save" and str(spell["save_ability"]).is_empty():
			errors.append("%s: magia com teste de resistência sem atributo" % id)
		if spell["resolution"] == "heal" and str(spell["heal"]).is_empty():
			errors.append("%s: magia de cura sem dados de cura" % id)
		if spell["target"] in ["sphere", "emanation", "line"] and int(spell["area_feet"]) <= 0:
			errors.append("%s: área sem tamanho (area_feet)" % id)
		if spell["resolution"] == "buff" and str(spell["effect"]).is_empty():
			errors.append("%s: magia de efeito sem efeito" % id)
		for class_id: String in spell["classes"]:
			if has("class", class_id) and str(get_entry("class", class_id).get("spellcasting_type", "")).is_empty():
				errors.append("%s: classe %s não conjura magias" % [id, class_id])
	for id in ids("class"):
		var entry := get_entry("class", id)
		if not str(entry.get("spellcasting_type", "")).is_empty():
			if str(entry["spellcasting_ability"]).is_empty():
				errors.append("%s: conjurador sem atributo de conjuração" % id)
			if entry["cantrips_known"].size() != 20 or entry["prepared_spells"].size() != 20:
				errors.append("%s: tabelas de conjuração devem ter 20 níveis" % id)
	for id in ids("appearance"):
		var profile := get_entry("appearance", id)
		for category: String in CharacterPainter.PARTS:
			for option: Variant in profile.get(category, []):
				if not str(option) in CharacterPainter.PARTS[category]:
					errors.append("%s.%s: peça desconhecida '%s'" % [id, category, option])
		for key in ["skin_tones", "hair_colors"]:
			for color: Variant in profile.get(key, []):
				if not Color.html_is_valid(str(color)):
					errors.append("%s.%s: cor inválida '%s'" % [id, key, color])
		if profile.has("horn_color") and not Color.html_is_valid(str(profile["horn_color"])):
			errors.append("%s: horn_color inválida" % id)
	for species_id in ids("species"):
		if not has("appearance", species_id.replace("species.", "appearance.")):
			errors.append("%s: sem perfil de aparência (data/appearance/)" % species_id)
	for id in ids("item"):
		var item := get_entry("item", id)
		if item.get("item_type") != "weapon":
			continue
		var props: Array = item.get("properties", [])
		if "versatile" in props and str(item.get("versatile_damage", "")).is_empty():
			errors.append("%s: arma versátil sem versatile_damage" % id)
		if ("ammunition" in props or "thrown" in props) and int(item.get("range_normal", 0)) <= 0:
			errors.append("%s: arma de alcance sem range_normal" % id)
		if int(item.get("range_long", 0)) < int(item.get("range_normal", 0)):
			errors.append("%s: range_long menor que range_normal" % id)
