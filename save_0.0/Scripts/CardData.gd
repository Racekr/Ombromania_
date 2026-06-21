# ===== CardData.gd (Nouveau fichier - Resource) =====
extends Resource
class_name CardData

@export var card_id: String = ""
@export var card_name: String = ""
@export var description: String = ""
@export var mana_cost: int = 1
@export var damage: int = 0
@export var heal: int = 0
@export var image_path: String = ""
@export var card_type: String = "attack"  # attack, heal, special
@export var can_target_self: bool = false
@export var can_target_others: bool = true
