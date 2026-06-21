extends Control

@onready var titre_label: Label = $PseudoContrainer/TitreLabel
@onready var commande_input: LineEdit = $VBoxContainer/Commande_LineEdit

func _ready() -> void:
	titre_label.text = Globals.get_titre()
	Globals.titre_changed.connect(self._on_titre_changed)
	if Globals.pseudo == "admin":
		$VBoxContainer/Commande_LineEdit.visible = true
	else:
		$VBoxContainer/Commande_LineEdit.visible = false
	commande_input.text_submitted.connect(_on_commande_entered)
	$PseudoContrainer/PseudoLabel.text = Globals.pseudo
	$PseudoContrainer/TitreLabel.text = Globals.titre

func _on_commande_entered(command_text: String) -> void:
	print("Commande entrée :", command_text)
	match command_text.to_lower():
		"settitre expert":
			Globals.set_titre("Expert")
			print("Titre changé en Expert")
		"settitre novice":
			Globals.set_titre("Novice")
			print("Titre changé en Novice")
		_:
			print("Commande inconnue")
	commande_input.text = ""

func _on_titre_changed(new_titre: String) -> void:
	titre_label.text = new_titre

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_create_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scènes/custome_game.tscn")

func _on_join_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scènes/join.tscn")
