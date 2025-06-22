# anomaly_flying_chair.gd
extends Node3D

# On a besoin de références à la chaise et au trigger.
# Assurez-vous que le nom "FlyingChair" correspond bien au nom de votre chaise RigidBody3D.
@onready var flying_chair: RigidBody3D = $Props/Chairs/Chair4
@onready var chair_trigger: Area3D = $ThrownChairTrigger

func _ready():
    # On connecte le signal, comme pour l'anomalie des lumières.
    chair_trigger.body_entered.connect(_on_player_entered.bind(true))


func _on_player_entered(body, disable_after_use: bool):
    # On vérifie que c'est le joueur.
    if body is CharacterBody3D:
        
        # On applique les forces à la chaise.
        throw_chair()
        
        # On désactive le trigger pour que ça ne se produise qu'une fois.
        if disable_after_use:
            chair_trigger.get_node("CollisionShape3D").disabled = true


func throw_chair():
    # --- C'EST ICI QUE LA MAGIE OPÈRE ---

    # 1. La force qui pousse la chaise vers le haut et en avant.
    # Vector3(X, Y, Z)
    # X: force latérale
    # Y: force verticale (vers le haut)
    # Z: force en avant/arrière (négatif pour "en avant" dans Godot)
    var upward_force = Vector3(8, 10, -5) # Pousse vers le haut et un peu en avant.
    
    # apply_central_impulse applique une "poussée" instantanée au centre de l'objet.
    flying_chair.apply_central_impulse(upward_force)

    # 2. La force qui fait tourner la chaise sur elle-même.
    # C'est le "torque" (couple).
    # Vector3(X, Y, Z) représente l'axe de rotation.
    # Vector3(1, 0, 0) -> rotation "cul par-dessus tête"
    # Vector3(0, 1, 0) -> rotation "toupie"
    # Vector3(0, 0, 1) -> rotation "roue de hamster"
    var rotation_force = Vector3(2, 5, 1) # Un mélange pour une rotation chaotique.
    
    # apply_torque_impulse applique une "poussée rotative" instantanée.
    flying_chair.apply_torque_impulse(rotation_force)
    
