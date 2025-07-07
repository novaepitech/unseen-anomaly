extends Node3D

# On utilise @onready pour s'assurer que les noeuds existent avant d'y accéder.
# Le signe "$" est un raccourci pour get_node().

@onready var lights_container = $Props/Lights
@onready var lights_out_trigger = $LightsOutTrigger

func _ready():
    # On connecte le signal du trigger à notre fonction qui va éteindre les lumières.
    # On s'assure de n'appeler la fonction qu'une seule fois avec .bind(true).
    # Le .bind(true) permet de passer une information supplémentaire à la fonction connectée.
    # Ici, on l'utilise pour désactiver le trigger après le premier passage.
    lights_out_trigger.body_entered.connect(_on_player_entered.bind(true))


func _on_player_entered(body, disable_after_use: bool):
    # On vérifie que c'est bien le joueur. On suppose que le joueur a un script ou un nom spécifique.
    # Le plus propre est de lui donner une "class_name" dans son script, ex: "class_name Player"
    if body is CharacterBody3D: # Remplacez par votre classe de joueur si besoin.
        
        # On parcourt toutes les lumières dans le conteneur "Lumieres".
        for node in lights_container.get_children():
            # On vérifie que le noeud est bien une lumière avant d'essayer de l'éteindre.
            if node is not AudioStreamPlayer3D:
                node.visible = false # On éteint la lumière.
            else:
                node.stop()
            $Props/Lights/LightsOutSound.play()

        # Si on a demandé de désactiver le trigger après usage, on le fait.
        # Cela empêche les lumières de se "rallumer" ou le code de s'exécuter à nouveau
        # si le joueur fait des allers-retours dans la zone.
        if disable_after_use:
            lights_out_trigger.get_node("CollisionShape3D").disabled = true
