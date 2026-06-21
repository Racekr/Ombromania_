# ===== InGame.gd (MODIFIÉ) =====
extends Control
const FIREBASE_API_KEY := "AIzaSyC8X-dYt9IqLOKsjsVZUoTG6EpC2uhT8rw"
const URL_BASE := "https://firestore.googleapis.com/v1/projects/ombromania-e0b48/databases/(default)/documents"

@onready var hand = $Hand
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var player1_container: CenterContainer = $Player1
@onready var other_players_container: HBoxContainer = $HBoxContainer
@onready var phase_label: Label = $PhaseLabel
@onready var mana_label: Label = $Player1/HBoxContainer/ManaLabel
@onready var day_label: Label = $DayLabel
@onready var card_sound = $Card_select
@export var card_scene: PackedScene

var id_token: String = ""
var uid: String = ""
var lobby_name: String = Globals.lobby_name
var last_action: String = ""

var http_queue: Array = []
var is_http_busy: bool = false

var players_bars: Dictionary = {}
var players_health: Dictionary = {}

var is_selecting_target: bool = false
var card_instances: Array = []

func _ready() -> void:
	print("Test : ", hand)
	await get_tree().process_frame
	setup_local_player()
	anonymous_signin()
	
	# Attendre que tous les joueurs soient connectés
	await wait_for_players(1)
	initialize_game()

func wait_for_players(min_players: int):
	while players_health.size() < min_players:
		await get_tree().process_frame

func initialize_game():
	"""Initialise la partie (attribution des rôles, distribution des cartes)"""
	print("DEBUG players_health = ", players_health)
	print("DEBUG keys = ", players_health.keys())
	var players = players_health.keys()
	
	if players.is_empty():
		print("⚠️ Aucun joueur connecté")
		return
	
	# Attribuer les rôles
	GameManager.assign_roles(players)
	
	save_roles_to_lobby(GameManager.player_roles)
	
	# Piocher carte
	print("Début pioche carte")
	randomize()
	generate_hand()
	
	update_ui()
	
		
	print("🎮 Partie initialisée avec %d joueurs" % players.size())

func save_roles_to_lobby(roles: Dictionary):

	var role_fields = {}

	for pseudo in roles.keys():
		role_fields[pseudo] = {
			"integerValue": roles[pseudo]
		}

	var body = {
		"fields": {
			"player_roles": {
				"mapValue": {
					"fields": role_fields
				}
			}
		}
	}


	var url := "%s/lobbys/%s?updateMask.fieldPaths=player_roles" % [
		URL_BASE,
		lobby_name
	]


	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]


	queue_http_request(
		url,
		headers,
		HTTPClient.METHOD_PATCH,
		JSON.stringify(body)
	)


	print("✅ Rôles envoyés dans le lobby")

func generate_hand():
	var numbers = [1,2,3,4,5,6,7,8,9,10,11,12]
	numbers.shuffle()
	for i in range(4):
		var value = numbers[i]
		print("nombre : ", value)
		show_card(value)

func show_card(value):
	var card = TextureButton.new()

	var image = load("res://assests/cards/role_" + str(Globals.role) + "/card_" + str(value) + ".png")
	card.texture_normal = image

	card.custom_minimum_size = Vector2(120, 180)
	card.ignore_texture_size = true
	card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	var base_position = Vector2(0, 0)
	card.mouse_entered.connect(func():
		card.z_index = 100
		card_sound.play()

		var tween = create_tween()
		tween.tween_property(card, "scale", Vector2(1.7, 1.7), 0.1)
		tween.tween_property(card, "position:y", base_position.y - 150, 0.1)
	)

	card.mouse_exited.connect(func():
		card.z_index = 0

		var tween = create_tween()
		tween.tween_property(card, "scale", Vector2(1, 1), 0.1)
		tween.tween_property(card, "position:y", base_position.y, 0.1)
		)
	
	card.pressed.connect(func():
		play_card(value)
	)

	hand.add_child(card)

	print("carte affichée")
	
func play_card(value):
	print("Carte jouée : ", value)

func update_ui():
	"""Met à jour l'interface (phase, mana, jour)"""
	var pseudo = Globals.pseudo
	
	if day_label:
		day_label.text = "Jour %d" % GameManager.day_number
	
	if phase_label:
		match GameManager.current_phase:
			GameManager.GamePhase.DAY:
				phase_label.text = "☀️ JOUR"
			GameManager.GamePhase.VOTE:
				phase_label.text = "🗳️ VOTE"
			GameManager.GamePhase.NIGHT:
				phase_label.text = "🌙 NUIT"
	
	if mana_label and GameManager.player_mana.has(pseudo):
		mana_label.text = "💎 Mana: %d/%d" % [GameManager.player_mana[pseudo], GameManager.player_max_mana[pseudo]]

func get_clicked_player(click_pos: Vector2) -> String:
	for pseudo in players_bars.keys():
		var container = players_bars[pseudo]["container"]
		var rect = container.get_global_rect()
		if rect.has_point(click_pos):
			return pseudo
	return ""

func highlight_valid_targets(enable: bool):
	for pseudo in players_bars.keys():
		var container = players_bars[pseudo]["container"]
		container.modulate = Color(1.2, 1.2, 1.0) if enable else Color.WHITE

# ===== Code health bars et Firestore (inchangé) =====
# (Tout le code précédent pour setup_local_player, add_other_player, etc.)

func setup_local_player():
	var pseudo = Globals.pseudo
	if not player1_container:
		return
	
	var hbox = player1_container.get_child(0) as HBoxContainer
	if hbox:
		var label = hbox.get_child(0) as Label
		var progress = hbox.get_child(1) as ProgressBar
		
		if label and progress:
			label.text = pseudo
			progress.min_value = 0
			progress.max_value = 100
			progress.value = 100
			progress.show_percentage = false
			
			var health_label = Label.new()
			health_label.text = "100/100"
			health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			health_label.offset_left = 0
			health_label.offset_top = 0
			health_label.offset_right = 0
			health_label.offset_bottom = 0
			health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			health_label.add_theme_color_override("font_color", Color.WHITE)
			health_label.add_theme_color_override("font_outline_color", Color.BLACK)
			health_label.add_theme_constant_override("outline_size", 2)
			progress.add_child(health_label)
			
			var style_fill = StyleBoxFlat.new()
			style_fill.bg_color = Color.GREEN
			style_fill.corner_radius_top_left = 8
			style_fill.corner_radius_top_right = 8
			style_fill.corner_radius_bottom_left = 8
			style_fill.corner_radius_bottom_right = 8
			style_fill.border_width_left = 2
			style_fill.border_width_right = 2
			style_fill.border_width_top = 2
			style_fill.border_width_bottom = 2
			style_fill.border_color = Color.BLACK
			progress.add_theme_stylebox_override("fill", style_fill)
			
			var style_bg = StyleBoxFlat.new()
			style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			style_bg.corner_radius_top_left = 8
			style_bg.corner_radius_top_right = 8
			style_bg.corner_radius_bottom_left = 8
			style_bg.corner_radius_bottom_right = 8
			style_bg.border_width_left = 2
			style_bg.border_width_right = 2
			style_bg.border_width_top = 2
			style_bg.border_width_bottom = 2
			style_bg.border_color = Color.BLACK
			progress.add_theme_stylebox_override("background", style_bg)
			
			players_bars[pseudo] = {
				"label": label,
				"progress": progress,
				"container": player1_container,
				"style_fill": style_fill,
				"health_label": health_label
			}
			players_health[pseudo] = 100
			update_health_bar_visual(pseudo)

func add_other_player(pseudo: String, initial_health: int = 100):
	if pseudo in players_bars or pseudo == Globals.pseudo:
		return
	
	var center_container = CenterContainer.new()
	var hbox = HBoxContainer.new()
	var label = Label.new()
	var progress = ProgressBar.new()
	
	label.text = pseudo
	progress.min_value = 0
	progress.max_value = 100
	progress.value = initial_health
	progress.custom_minimum_size = Vector2(150, 30)
	progress.show_percentage = false
	
	var health_label = Label.new()
	health_label.text = str(initial_health) + "/100"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_label.offset_left = 0
	health_label.offset_top = 0
	health_label.offset_right = 0
	health_label.offset_bottom = 0
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_label.add_theme_color_override("font_outline_color", Color.BLACK)
	health_label.add_theme_constant_override("outline_size", 2)
	progress.add_child(health_label)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color.GREEN
	style_fill.corner_radius_top_left = 8
	style_fill.corner_radius_top_right = 8
	style_fill.corner_radius_bottom_left = 8
	style_fill.corner_radius_bottom_right = 8
	style_fill.border_width_left = 2
	style_fill.border_width_right = 2
	style_fill.border_width_top = 2
	style_fill.border_width_bottom = 2
	style_fill.border_color = Color.BLACK
	progress.add_theme_stylebox_override("fill", style_fill)
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_bg.corner_radius_top_left = 8
	style_bg.corner_radius_top_right = 8
	style_bg.corner_radius_bottom_left = 8
	style_bg.corner_radius_bottom_right = 8
	style_bg.border_width_left = 2
	style_bg.border_width_right = 2
	style_bg.border_width_top = 2
	style_bg.border_width_bottom = 2
	style_bg.border_color = Color.BLACK
	progress.add_theme_stylebox_override("background", style_bg)
	
	hbox.add_child(label)
	hbox.add_child(progress)
	center_container.add_child(hbox)
	other_players_container.add_child(center_container)
	
	players_bars[pseudo] = {
		"label": label,
		"progress": progress,
		"container": center_container,
		"style_fill": style_fill,
		"health_label": health_label
	}
	players_health[pseudo] = initial_health
	update_health_bar_visual(pseudo)

func update_player_health(pseudo: String, new_health: int):
	if not pseudo in players_bars:
		if pseudo != Globals.pseudo:
			add_other_player(pseudo, new_health)
		return
	
	players_health[pseudo] = new_health
	var progress = players_bars[pseudo]["progress"]
	progress.value = new_health
	update_health_bar_visual(pseudo)

func update_health_bar_visual(pseudo: String):
	if not pseudo in players_bars:
		return
	
	var style_fill = players_bars[pseudo]["style_fill"]
	var health_label = players_bars[pseudo]["health_label"]
	var health = players_health[pseudo]
	var health_percent = float(health) / 100.0
	
	health_label.text = str(health) + "/100"
	
	if health_percent > 0.5:
		style_fill.bg_color = Color.GREEN
	elif health_percent > 0.25:
		style_fill.bg_color = Color.YELLOW
	else:
		style_fill.bg_color = Color.RED

func damage_player(pseudo: String, amount: int):
	if pseudo in players_health:
		var new_health = max(0, players_health[pseudo] - amount)
		update_player_health_firestore(pseudo, new_health)

func heal_player(pseudo: String, amount: int):
	if pseudo in players_health:
		var new_health = min(100, players_health[pseudo] + amount)
		update_player_health_firestore(pseudo, new_health)

func anonymous_signin() -> void:
	last_action = "anonymous_signin"
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % FIREBASE_API_KEY
	var body := {"returnSecureToken": true}
	var headers := ["Content-Type: application/json"]
	http_request.request_completed.connect(_on_http_request_completed)
	queue_http_request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_http_busy = false
	var response = {}
	if body.size() > 0:
		response = JSON.parse_string(body.get_string_from_utf8())
	
	match last_action:
		"anonymous_signin":
			if response.has("idToken"):
				id_token = response["idToken"]
				uid = response["localId"]
				print("✅ Connexion anonyme réussie")
				listen_lobby_changes()
		"update_health":
			if response_code == 200:
				print("✅ Vie synchronisée")
		"get_lobby":
			handle_lobby_data(response)
	
	process_next_http_request()

func queue_http_request(url: String, headers: PackedStringArray, method: int, body: String = ""):
	http_queue.append({"url": url, "headers": headers, "method": method, "body": body})
	if not is_http_busy:
		process_next_http_request()

func process_next_http_request():
	if http_queue.is_empty():
		return
	if is_http_busy:
		return
	
	is_http_busy = true
	var request_data = http_queue.pop_front()
	var error = http_request.request(request_data["url"], request_data["headers"], request_data["method"], request_data["body"])
	
	if error != OK:
		is_http_busy = false
		process_next_http_request()

func update_player_health_firestore(pseudo: String, new_health: int):
	last_action = "update_health"
	update_player_health(pseudo, new_health)
	
	var all_health = {}
	for p in players_health.keys():
		all_health[p] = players_health[p]
	
	var health_fields = {}
	for p in all_health.keys():
		health_fields[p] = {"integerValue": all_health[p]}
	
	var url := "%s/lobbys/%s?updateMask.fieldPaths=players_health" % [URL_BASE, lobby_name]
	var body := {"fields": {"players_health": {"mapValue": {"fields": health_fields}}}}
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + id_token]
	queue_http_request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

func listen_lobby_changes():
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_poll_lobby)
	timer.start(2.0)

func _poll_lobby():
	last_action = "get_lobby"
	var url := "%s/lobbys/%s" % [URL_BASE, lobby_name]
	var headers := ["Authorization: Bearer " + id_token]
	queue_http_request(url, headers, HTTPClient.METHOD_GET)

func handle_lobby_data(response):
	if not response.has("fields"):
		return
	
	var fields = response["fields"]
	if fields.has("players_health") and fields["players_health"].has("mapValue"):
		var health_map = fields["players_health"]["mapValue"]["fields"]
		for pseudo in health_map.keys():
			var health = int(health_map[pseudo]["integerValue"])
			if not pseudo in players_health:
				if pseudo != Globals.pseudo:
					add_other_player(pseudo, health)
				else:
					players_health[pseudo] = health
