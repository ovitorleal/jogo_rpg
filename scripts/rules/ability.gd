class_name Ability
extends RefCounted
## Os seis atributos (SRD 5.2.1) e o cálculo do modificador.

const STRENGTH := &"str"
const DEXTERITY := &"dex"
const CONSTITUTION := &"con"
const INTELLIGENCE := &"int"
const WISDOM := &"wis"
const CHARISMA := &"cha"

const ALL: Array[StringName] = [STRENGTH, DEXTERITY, CONSTITUTION, INTELLIGENCE, WISDOM, CHARISMA]

const NAMES := {
	STRENGTH: "Força",
	DEXTERITY: "Destreza",
	CONSTITUTION: "Constituição",
	INTELLIGENCE: "Inteligência",
	WISDOM: "Sabedoria",
	CHARISMA: "Carisma",
}

const SHORT_NAMES := {
	STRENGTH: "FOR",
	DEXTERITY: "DES",
	CONSTITUTION: "CON",
	INTELLIGENCE: "INT",
	WISDOM: "SAB",
	CHARISMA: "CAR",
}

const MIN_SCORE := 1
const MAX_SCORE := 30
## Teto para personagens jogadores ao aplicar bônus comuns (ex.: antecedente).
const PLAYER_MAX_SCORE := 20


static func is_valid(ability: StringName) -> bool:
	return ability in ALL


## Modificador = arredondamento para baixo de (valor - 10) / 2.
static func modifier(score: int) -> int:
	return floori((score - 10) / 2.0)


static func format_modifier(value: int) -> String:
	return "+%d" % value if value >= 0 else "%d" % value
