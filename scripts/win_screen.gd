extends Control

@onready var title_label = $VBoxContainer/TitleLabel
@onready var subtitle_label = $VBoxContainer/SubtitleLabel
@onready var restart_button = $VBoxContainer/ButtonsBox/RestartButton
@onready var quit_button = $VBoxContainer/ButtonsBox/QuitButton
@onready var animation_player = $AnimationPlayer

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    # On connecte les signaux des boutons à nos fonctions.
    restart_button.pressed.connect(_on_restart_button_pressed)
    quit_button.pressed.connect(_on_quit_button_pressed)

    # On cache les éléments au début pour les faire apparaître avec l'animation.
    title_label.modulate.a = 0
    subtitle_label.modulate.a = 0
    restart_button.modulate.a = 0
    quit_button.modulate.a = 0

    # On joue l'animation de "fade in".
    # Vous devez créer cette animation dans l'éditeur.
    animation_player.play("fade_in")

# Fonction appelée quand le bouton "Rejouer" est pressé.
func _on_restart_button_pressed():
    # Mettez ici le chemin vers votre scène de jeu principale.
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    # Réinitialise l'état du jeu via le GameManager avant de redémarrer la scène.
    GameManager.reset_game_state()
    get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Fonction appelée quand le bouton "Quitter" est pressé.
func _on_quit_button_pressed():
    get_tree().quit()
