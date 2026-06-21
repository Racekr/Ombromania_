# ===== GameManager.gd (MODIFIÉ pour les chemins d'images) =====
extends Node

enum GamePhase { DAY, VOTE, NIGHT }
var current_phase: GamePhase = GamePhase.DAY
var day_number: int = 1

var player_roles: Dictionary = {}
var player_decks: Dictionary = {}
var player_hands: Dictionary = {}
var player_mana: Dictionary = {}
var player_max_mana: Dictionary = {}

var all_roles: Array[RoleData] = []

func _ready():
	load_all_roles()

func load_all_roles():
	"""Charge les 12 rôles avec leurs cartes"""
	for i in range(1, 13):
		var role = RoleData.new()
		role.role_id = i
		role.role_name = "Rôle %d" % i
		
		# Créer 12 cartes pour ce rôle
		for j in range(1, 13):
			var card = CardData.new()
			card.card_id = "role_%d_card_%d" % [i, j]
			card.card_name = "Carte %d-%d" % [i, j]
			card.mana_cost = randi() % 5 + 1
			card.damage = randi() % 20 + 5
			card.description = "Inflige %d dégâts" % card.damage
			
			# 🔥 Chemin de l'image de la carte
			# Tu peux nommer tes images : role_1_card_1.png, role_1_card_2.png, etc.
			card.image_path = "res://assets/cards/role_%d/card_%d.png" % [i, j]
			
			role.role_cards.append(card)
		
		all_roles.append(role)
	
	print("✅ %d rôles chargés avec leurs cartes" % all_roles.size())

func assign_roles(players: Array):
	"""Attribue aléatoirement les rôles aux joueurs"""
	var available_roles = range(1, 13)
	available_roles.shuffle()
	
	for i in range(players.size()):
		var pseudo = players[i]
		var role_id = available_roles[i % 12]
		
		player_roles[pseudo] = role_id
		
		if pseudo == Globals.pseudo:
			Globals.role = role_id
			print("Mon rôle est :", Globals.role)
		
		var role = get_role_data(role_id)
		player_max_mana[pseudo] = role.starting_mana
		player_mana[pseudo] = role.starting_mana
		
		player_decks[pseudo] = []
		for card in role.role_cards:
			player_decks[pseudo].append(card)
		
		player_decks[pseudo].shuffle()
		
		player_hands[pseudo] = []
		for j in range(4):
			draw_card(pseudo)
		
		print("🎭 %s → Rôle %d (%d cartes en main)" % [pseudo, role_id, player_hands[pseudo].size()])

func get_role_data(role_id: int) -> RoleData:
	for role in all_roles:
		if role.role_id == role_id:
			return role
	return null

func draw_card(pseudo: String):
	if not player_decks.has(pseudo) or player_decks[pseudo].is_empty():
		print("⚠️ %s n'a plus de cartes à piocher" % pseudo)
		return
	
	var card = player_decks[pseudo].pop_front()
	player_hands[pseudo].append(card)
	print("🎴 %s pioche : %s" % [pseudo, card.card_name])

func start_new_day():
	day_number += 1
	current_phase = GamePhase.DAY
	
	for pseudo in player_hands.keys():
		draw_card(pseudo)
		player_mana[pseudo] = min(player_max_mana[pseudo] + 1, 10)
		player_max_mana[pseudo] = min(player_max_mana[pseudo] + 1, 10)
	
	print("🌅 Jour %d commence !" % day_number)

func can_play_card(pseudo: String, card: CardData) -> bool:
	if not player_mana.has(pseudo):
		return false
	return player_mana[pseudo] >= card.mana_cost

func play_card(pseudo: String, card: CardData):
	if not can_play_card(pseudo, card):
		print("⚠️ Pas assez de mana !")
		return false
	
	player_hands[pseudo].erase(card)
	player_mana[pseudo] -= card.mana_cost
	
	print("✨ %s joue '%s' (mana: %d/%d)" % [pseudo, card.card_name, player_mana[pseudo], player_max_mana[pseudo]])
	return true
