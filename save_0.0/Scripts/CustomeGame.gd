# ===== 1. CustomGame.gd (MODIFIÉ) =====
extends Control

const FIREBASE_API_KEY := "AIzaSyC8X-dYt9IqLOKsjsVZUoTG6EpC2uhT8rw"
const URL_BASE := "https://firestore.googleapis.com/v1/projects/ombromania-e0b48/databases/(default)/documents"

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var join_button: Button = $CenterContainer/VBoxContainer/Button  # Ton bouton "Rejoindre"

var id_token: String = ""
var uid: String = ""
var lobby_name: String = ""
var id_player: int = 1
var lobby_created: bool = false
var last_action: String = ""

func _ready() -> void:
	randomize()
	lobby_name = "lobby_" + str(randi() % 1000000)
	
	# Désactiver le bouton au départ
	if join_button:
		join_button.disabled = true
		join_button.text = "Création du lobby..."
	
	anonymous_signin()

func anonymous_signin() -> void:
	last_action = "anonymous_signin"
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % FIREBASE_API_KEY
	var body := {"returnSecureToken": true}
	var headers := ["Content-Type: application/json"]
	http_request.request_completed.connect(_on_http_request_completed)
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

@warning_ignore("unused_parameter")
func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response = {}
	if body.size() > 0:
		response = JSON.parse_string(body.get_string_from_utf8())
	
	match last_action:
		"anonymous_signin":
			if response.has("idToken"):
				id_token = response["idToken"]
				uid = response["localId"]
				print("✅ Connexion anonyme réussie :", uid)
				create_lobby_firestore()
			else:
				print("❌ Erreur connexion :", response)
				if join_button:
					join_button.text = "Erreur de connexion"
		
		"create_lobby":
			if response_code == 200 and response.has("name"):
				print("✅ Lobby créé avec succès :", response["name"])
				lobby_created = true
				
				# Activer le bouton
				if join_button:
					join_button.disabled = false
					join_button.text = "Rejoindre le lobby"
			else:
				print("❌ Erreur création lobby :", response_code, response)
				if join_button:
					join_button.text = "Erreur - Réessayer"
					join_button.disabled = false

func create_lobby_firestore() -> void:
	last_action = "create_lobby"
	var url := "%s/lobbys?documentId=%s" % [URL_BASE, lobby_name]
	var pseudo = Globals.pseudo
	
	# 🔥 Créer avec health bars dès le début
	var body := {
		"fields": {
			"creator_id": {"stringValue": uid},
			"id_player": {
				"mapValue": {
					"fields": {
						pseudo: {"integerValue": id_player}
					}
				}
			},
			"players_health": {
				"mapValue": {
					"fields": {
						pseudo: {"integerValue": 100}
					}
				}
			}
		}
	}
	
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	print("🎮 Création du lobby :", lobby_name, "avec", pseudo, "et health bars")

func _on_button_pressed() -> void:
	if not lobby_created:
		print("⚠️ Lobby pas encore créé, veuillez patienter...")
		return
	
	Globals.lobby_name = lobby_name
	get_tree().change_scene_to_file("res://Scènes/lobby_view.tscn")
