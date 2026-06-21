extends Control

const FIREBASE_API_KEY := "AIzaSyC8X-dYt9IqLOKsjsVZUoTG6EpC2uhT8rw"
const URL_BASE := "https://firestore.googleapis.com/v1/projects/ombromania-e0b48/databases/(default)/documents"

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var lobby_list: VBoxContainer = $CenterContainer/VBoxContainer/ScrollContainer/LobbyList

var id_token: String = ""
var uid: String = ""
var last_action: String = ""

# Petite extension pratique pour nettoyer un conteneur
func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _ready() -> void:
	anonymous_signin()


# --- Étape 1 : connexion anonyme ---
func anonymous_signin() -> void:
	last_action = "anonymous_signin"
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % FIREBASE_API_KEY
	var body := {"returnSecureToken": true}
	var headers := ["Content-Type: application/json"]

	if not http_request.request_completed.is_connected(_on_http_request_completed):
		http_request.request_completed.connect(_on_http_request_completed)

	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


# --- Étape 2 : gestion de la réponse Firebase / Firestore ---
func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response = {}
	if body.size() > 0:
		response = JSON.parse_string(body.get_string_from_utf8())

	if response_code != 200:
		print("❌ Erreur HTTP :", response_code, "→", response)
		return

	match last_action:
		"anonymous_signin":
			id_token = response["idToken"]
			uid = response["localId"]
			print("✅ Connecté anonymement :", uid)
			get_all_lobbys()
		"join_lobby":
			print("✅ Joueur ajouté au lobby avec succès :", response)
			get_tree().change_scene_to_file("res://Scènes/lobby_view.tscn")

		"get_lobbys":
			print("📩 Réponse Firestore :", response)
			if response.has("documents"):
				display_lobbys(response["documents"])
			else:
				print("⚠️ Aucun lobby trouvé.")
				display_lobbys([])

		"check_lobby_slots":
			var pseudo = Globals.pending_pseudo
			var lobby_name = Globals.pending_lobby
			if not response.has("fields") or not response["fields"].has("id_player"):
				print("⚠️ Lobby vide ou sans structure valide. On commence à 2.")
				_add_player_to_lobby(lobby_name, pseudo, id_token, 2)
				return

			var players = response["fields"]["id_player"]["mapValue"]["fields"]
			var used_numbers := []
			for key in players.keys():
				var value = players[key]
				if value.has("integerValue"):
					used_numbers.append(int(value["integerValue"]))

			var slot := 2
			while slot <= 12 and slot in used_numbers:
				slot += 1

			if slot > 12:
				print("🚫 Lobby full")
				var popup := AcceptDialog.new()
				popup.dialog_text = "⚠️ Le lobby est plein (12 joueurs max)."
				add_child(popup)
				popup.popup_centered()
				return

			print("✅ Slot trouvé :", slot)
			_add_player_to_lobby(lobby_name, pseudo, id_token, slot)



# --- Étape 3 : Récupération des lobbys ---
func get_all_lobbys() -> void:
	last_action = "get_lobbys"
	var url := "%s/lobbys/" % URL_BASE  # 🔹 slash final obligatoire
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]
	http_request.request(url, headers, HTTPClient.METHOD_GET)
	


# --- Étape 4 : Affichage des lobbys dans le ScrollContainer ---
func display_lobbys(docs: Array) -> void:
	clear_children(lobby_list)
	
	if docs.is_empty():
		var label := Label.new()
		label.text = "Aucun lobby disponible."
		lobby_list.add_child(label)
		return

	print("📜 Lobbys trouvés :", docs.size())
	print("📜 Nombre de lobbys trouvés :", docs.size())
	print("🧩 Exemple d’un doc :", docs[0] if docs.size() > 0 else "aucun")

	for doc in docs:
		var lobby_name_str = doc["name"].split("/")[-1]
		var btn := Button.new()
		btn.text = lobby_name_str
		btn.custom_minimum_size = Vector2(0, 48)
		btn.pressed.connect(func(): _on_lobby_button_pressed(lobby_name_str))
		lobby_list.add_child(btn)

# --- Étape 5 : Quand on clique sur un lobby ---
# --- Étape 5 : Quand on clique sur un lobby ---
func _on_lobby_button_pressed(lobby_name: String) -> void:
	print("🎯 Lobby sélectionné :", lobby_name)
	Globals.lobby_name = lobby_name

	var pseudo = ""
	if "pseudo" in Globals:
		pseudo = Globals.pseudo
	if pseudo.is_empty():
		pseudo = "Anonyme"

	print("👤 Tentative de connexion au lobby :", lobby_name, "avec pseudo :", pseudo)

	# Étape 1 : récupérer le contenu actuel du lobby pour voir les slots pris
	last_action = "check_lobby_slots"
	var url := "%s/lobbys/%s" % [URL_BASE, lobby_name]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]
	
	# On stocke temporairement pour réutiliser dans la réponse
	Globals.pending_pseudo = pseudo
	Globals.pending_lobby = lobby_name
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

@warning_ignore("shadowed_variable")
func _add_player_to_lobby(lobby_name: String, pseudo: String, id_token: String, player_number: int) -> void:
	last_action = "join_lobby"  # ✅ Empêche de relancer la vérif de slots ensuite

	var url := "%s/lobbys/%s?updateMask.fieldPaths=id_player.%s" % [URL_BASE, lobby_name, pseudo]

	var body := {
		"fields": {
			"id_player": {
				"mapValue": {
					"fields": {
						pseudo: {"integerValue": player_number}
					}
				}
			}
		}
	}

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]

	http_request.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	print("✅ Ajout du joueur :", pseudo, "→", player_number)


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scènes/Menu.tscn")
