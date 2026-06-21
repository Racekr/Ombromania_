extends Node

var pseudo: String = ""
var _titre: String = "Novice"
var id_player: bool = 1
signal titre_changed(new_value)
var lobby_name: String = ""
var pending_pseudo: String = ""
var pending_lobby: String = ""
var pending_exit_pseudo: String =""
var pending_new_creator: String = ""
var local_player_id: String = ""
var role: int = 0
var titre: String = ""

func _ready() -> void:
	titre = _titre  # initialise titre

func set_titre(value: String) -> void:
	_titre = value
	emit_signal("titre_changed", value)

func get_titre() -> String:
	return _titre
