extends Control

const FIREBASE_API_KEY := "AIzaSyC8X-dYt9IqLOKsjsVZUoTG6EpC2uhT8rw"
const URL_BASE := "https://firestore.googleapis.com/v1/projects/ombromania-e0b48/databases/(default)/documents"

# --- Nodes principaux ---
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var player_list: VBoxContainer = $CenterContainer/VBoxContainer/ScrollContainer/PlayersList
@onready var title_label: Label = $CenterContainer/VBoxContainer/Label
@onready var refresh_timer: Timer = $RefreshTimer
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton

@onready var info_popup := AcceptDialog.new()
@onready var confirm_popup := ConfirmationDialog.new()

# --- Variables lobby ---
var creator_id: String = "UID_DU_CREATEUR" # À remplacer par la logique réelle
var local_player_id: String = "" # UID du joueur courant (récupéré après connexion)
var id_token: String = ""
var uid: String = ""
var lobby_name: String = Globals.lobby_name
var last_action: String = ""
var is_requesting: bool = false
var pending_exit_pseudo: String = ""
var lobby_exists: bool = true

func _ready() -> void:
	# Bouton invisible par défaut
	start_button.visible = false
	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)

	title_label.text = "👥 Joueurs dans : " + lobby_name

	# --- Popups ---
	add_child(info_popup)
	info_popup.dialog_text = "Le créateur a quitté le lobby."
	info_popup.ok_button_text = "OK"
	info_popup.visible = false
	info_popup.confirmed.connect(_on_info_popup_closed)

	add_child(confirm_popup)
	confirm_popup.dialog_text = "Êtes-vous sûr de vouloir supprimer ce lobby ?"
	confirm_popup.ok_button_text = "Oui"
	confirm_popup.cancel_button_text = "Non"
	confirm_popup.confirmed.connect(_on_confirm_popup_yes)

	# --- Timer refresh ---
	refresh_timer.wait_time = 3.0
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_on_refresh_timer_timeout)

	# Connexion anonyme
	anonymous_signin()

# --- Connexion anonyme ---
func anonymous_signin() -> void:
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % FIREBASE_API_KEY
	var body := {"returnSecureToken": true}
	var headers := ["Content-Type: application/json"]

	if not http_request.request_completed.is_connected(_on_http_request_completed):
		http_request.request_completed.connect(_on_http_request_completed)

	is_requesting = true
	last_action = "anonymous_signin"
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

# --- HTTPRequest terminé ---
func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_requesting = false
	var data = {}
	if body.size() > 0:
		data = JSON.parse_string(body.get_string_from_utf8())

	if response_code == 404 and lobby_exists:
		lobby_exists = false
		show_info_popup()
		return

	match last_action:
		"anonymous_signin":
			if data.has("idToken"):
				id_token = data["idToken"]
				local_player_id = data["localId"]
				uid = local_player_id
				print("✅ Connecté anonymement :", uid)
				get_lobby_data()
			else:
				print("❌ Échec connexion anonyme :", data)

		"get_lobby_players":
			if data.has("fields"):
				# --- 🔥 Lire creator_id depuis Firestore ---
				if data["fields"].has("creator_id"):
					creator_id = data["fields"]["creator_id"]["stringValue"]
					print("👑 Créateur du lobby :", creator_id)
					start_button.visible = true
				else:
					print("⚠️ Aucun creator_id trouvé dans ce lobby.")

				# --- Charger les joueurs ---
				if data["fields"].has("id_player"):
					var players_dict = data["fields"]["id_player"]["mapValue"]["fields"]
					display_players(players_dict)
				else:
					display_players({})
			else:
				display_players({})

		"exit_lobby_get":
			_handle_exit_lobby_response(data)

		"exit_lobby_patch":
			get_tree().change_scene_to_file("res://Scènes/Menu.tscn")

		"delete_lobby":
			get_tree().change_scene_to_file("res://Scènes/Menu.tscn")

# --- Affichage des joueurs ---
func display_players(players_dict: Dictionary) -> void:
	for child in player_list.get_children():
		child.queue_free()

	if players_dict.size() == 0:
		var label := Label.new()
		label.text = "⚠️ Aucun joueur trouvé dans ce lobby."
		player_list.add_child(label)
		return

	for pseudo in players_dict.keys():
		if players_dict[pseudo].has("integerValue"):
			var slot = int(players_dict[pseudo]["integerValue"])
			if slot > 0:
				var label := Label.new()
				label.text = "%s (slot %d)" % [pseudo, slot]
				player_list.add_child(label)

# --- Récupérer les joueurs ---
func get_lobby_data() -> void:
	if is_requesting:
		return
	is_requesting = true
	last_action = "get_lobby_players"
	var url := "%s/lobbys/%s" % [URL_BASE, lobby_name]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]
	http_request.request(url, headers, HTTPClient.METHOD_GET)

# --- Timer refresh ---
func _on_refresh_timer_timeout() -> void:
	if not is_requesting:
		get_lobby_data()

# --- Quitter le lobby ---
func _on_quit_button_pressed() -> void:
	if id_token == "" or lobby_name == "" or Globals.pseudo == "":
		return

	pending_exit_pseudo = Globals.pseudo
	last_action = "exit_lobby_get"

	if is_requesting:
		return

	var url := "%s/lobbys/%s" % [URL_BASE, lobby_name]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]
	is_requesting = true
	http_request.request(url, headers, HTTPClient.METHOD_GET)

# --- Traite le départ ---
func _handle_exit_lobby_response(data: Dictionary) -> void:
	if not data.has("fields") or not data["fields"].has("id_player"):
		get_tree().change_scene_to_file("res://Scènes/Join.tscn")
		return

	var players = data["fields"]["id_player"]["mapValue"]["fields"]
	var current_admin = ""
	for pseudo in players.keys():
		if players[pseudo].has("integerValue") and int(players[pseudo]["integerValue"]) == 1:
			current_admin = pseudo
			break

	if pending_exit_pseudo == current_admin:
		confirm_popup.popup_centered()
	else:
		var patch_body := {
			"fields": {
				"id_player": {
					"mapValue": {
						"fields": {
							pending_exit_pseudo: {"nullValue": null}
						}
					}
				}
			}
		}
		var patch_url := "%s/lobbys/%s?updateMask.fieldPaths=id_player.%s" % [URL_BASE, lobby_name, pending_exit_pseudo]
		var patch_headers := [
			"Content-Type: application/json",
			"Authorization: Bearer " + id_token
		]
		last_action = "exit_lobby_patch"
		is_requesting = true
		http_request.request(patch_url, patch_headers, HTTPClient.METHOD_PATCH, JSON.stringify(patch_body))
		print("🗑️ Joueur retiré :", pending_exit_pseudo)

# --- Confirmation du créateur ---
func _on_confirm_popup_yes() -> void:
	_delete_lobby()

# --- Supprimer le lobby ---
func _delete_lobby() -> void:
	if is_requesting:
		http_request.cancel_request()
		is_requesting = false
		await get_tree().create_timer(0.1).timeout

	last_action = "delete_lobby"
	var url := "%s/lobbys/%s" % [URL_BASE, lobby_name]
	var headers := ["Authorization: Bearer " + id_token]
	is_requesting = true
	var err = http_request.request(url, headers, HTTPClient.METHOD_DELETE)

	if err != OK:
		print("❌ Erreur lors de la suppression :", err)
	else:
		print("🗑️ Suppression du lobby :", lobby_name)

# --- Popup info ---
func show_info_popup() -> void:
	info_popup.visible = true
	info_popup.popup_centered()

func _on_info_popup_closed() -> void:
	get_tree().change_scene_to_file("res://Scènes/Menu.tscn")

# --- Lancer la partie ---
func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scènes/InGame.tscn")
