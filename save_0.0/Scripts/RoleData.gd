# ===== RoleData.gd (Nouveau fichier - Resource) =====
extends Resource
class_name RoleData

@export var role_id: int = 1
@export var role_name: String = "Rôle 1"
@export var role_cards: Array[CardData] = []  # Les 12 cartes du rôle
@export var starting_mana: int = 3
@export var max_mana: int = 10
