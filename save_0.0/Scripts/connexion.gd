extends Control

const FIREBASE_API_KEY := "AIzaSyC8X-dYt9IqLOKsjsVZUoTG6EpC2uhT8rw"
var url_base := "https://firestore.googleapis.com/v1/projects/ombromania-e0b48/databases/(default)/documents"

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var pseudo_field: LineEdit = $CenterContainer/VBoxContainer/VBoxContainer/ID/Id
@onready var password_field: LineEdit = $CenterContainer/VBoxContainer/VBoxContainer/Password/Password
@onready var title: Label = $Ombromania

var last_action: String = ""
var last_id_token: String = ""
var last_uid: String = ""
var pending_pseudo: String = ""
var pending_password: String = ""

# --- Cycle de polices ---
@export var fonts: Array[FontFile] = []
var current_font_index := 0
var font_timer: Timer

func _ready() -> void:
	# Connexion aux boutons
	$CenterContainer/VBoxContainer/HBoxContainer/Login_Button.pressed.connect(_on_login_pressed)
	$CenterContainer/VBoxContainer/HBoxContainer/Register_Button.pressed.connect(_on_register_pressed)
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	# Démarrage du cycle de polices
	if fonts.size() > 0:
		_start_font_cycle()

# --- Boutons ---
func _on_login_pressed() -> void:
	var pseudo := pseudo_field.text.strip_edges()
	var password := password_field.text
	if pseudo.is_empty() or password.is_empty():
		push_error("Pseudo et mot de passe requis")
		return
	login_with_pseudo(pseudo, password)

func _on_register_pressed() -> void:
	var pseudo := pseudo_field.text.strip_edges()
	var password := password_field.text
	if pseudo.is_empty() or password.is_empty():
		push_error("Pseudo et mot de passe requis")
		return
	pending_pseudo = pseudo
	pending_password = password
	anonymous_signin()

# --- Firebase / HTTP ---
func anonymous_signin() -> void:
	last_action = "anonymous_signup"
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % FIREBASE_API_KEY
	var body := {"returnSecureToken": true}
	var headers := ["Content-Type: application/json"]
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func check_and_store_pseudo(uid: String, id_token: String, pseudo: String, password: String) -> void:
	last_id_token = id_token
	last_uid = uid
	pending_pseudo = pseudo
	pending_password = password
	last_action = "check_pseudo"
	var url := "%s/users" % url_base
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + id_token]
	http_request.request(url, headers, HTTPClient.METHOD_GET, "")

func store_user_firestore(uid: String, id_token: String, pseudo: String, password: String) -> void:
	var password_hash := hash_password(password)
	var url := "%s/users?documentId=%s" % [url_base, uid]
	var body := {
		"fields": {
			"pseudo": {"stringValue": pseudo},
			"password": {"stringValue": password_hash},
			"created_at": {"timestampValue": _now_rfc3339()}
		}
	}
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + id_token]
	last_action = "store_user"
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func hash_password(password: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(password.to_utf8_buffer())
	var digest := context.finish()
	return digest.hex_encode()

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text := body.get_string_from_utf8()
	var data = {}
	if not body_text.is_empty():
		var json := JSON.new()
		if json.parse(body_text) == OK:
			data = json.get_data()

	match last_action:
		"anonymous_signup":
			if response_code in [200,201] and data.has("idToken"):
				check_and_store_pseudo(data["localId"], data["idToken"], pending_pseudo, pending_password)
		"login":
			var found := false
			if response_code in [200,201] and data.has("documents"):
				for doc in data["documents"]:
					var fields = doc.get("fields", {})
					if fields.has("pseudo") and fields.has("password"):
						if fields["pseudo"]["stringValue"] == pending_pseudo:
							if fields["password"]["stringValue"] == hash_password(pending_password):
								Globals.pseudo = pending_pseudo
								found = true
								break
			if found:
				call_deferred("_change_to_menu")
		"check_pseudo":
			var pseudo_exists = false
			if response_code in [200,201] and data.has("documents"):
				for doc in data["documents"]:
					if doc.has("fields") and doc["fields"].has("pseudo"):
						if doc["fields"]["pseudo"]["stringValue"] == pending_pseudo:
							pseudo_exists = true
							break
			if not pseudo_exists:
				Globals.pseudo = pending_pseudo
				store_user_firestore(last_uid, last_id_token, pending_pseudo, pending_password)
		"store_user":
			if response_code in [200,201]:
				get_tree().change_scene_to_file("res://Scènes/Menu.tscn")

func _change_to_menu() -> void:
	get_tree().change_scene_to_file("res://Scènes/Menu.tscn")

func login_with_pseudo(pseudo: String, password: String) -> void:
	pending_pseudo = pseudo
	pending_password = password
	last_action = "login"
	var url := "%s/users?mask.fieldPaths=pseudo&mask.fieldPaths=password" % url_base
	var headers := ["Content-Type: application/json"]
	http_request.request(url, headers, HTTPClient.METHOD_GET, "")

func _now_rfc3339() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [t.year,t.month,t.day,t.hour,t.minute,t.second]

# --- Cycle de polices ---
func _start_font_cycle() -> void:
	font_timer = Timer.new()
	font_timer.wait_time = 0.3
	font_timer.one_shot = false
	font_timer.autostart = true
	add_child(font_timer)
	font_timer.timeout.connect(_on_font_timer_timeout)
	_apply_font()

func _on_font_timer_timeout() -> void:
	_next_font()

func _next_font() -> void:
	current_font_index = (current_font_index + 1) % fonts.size()
	_apply_font()

func _apply_font() -> void:
	title.add_theme_font_override("font", fonts[current_font_index])

func _on_id_text_submitted(new_text: String) -> void:
	_on_login_pressed()

func _on_password_text_submitted(new_text: String) -> void:
	_on_login_pressed()
