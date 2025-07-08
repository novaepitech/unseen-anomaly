# anomaly_flying_chair.gd
extends Node3D

# --- REFERENCES ---
# On a besoin de références à la chaise, au trigger, et maintenant à un son.
@onready var flying_chair: RigidBody3D = $Props/Chairs/Chair2
@onready var chair_trigger: Area3D = $ThrownChairTrigger
# IMPORTANT : Ajoutez un nœud AudioStreamPlayer3D comme enfant de la chaise
# et assignez-lui un son de "lancement" ou de "cri".
@onready var throw_sound: AudioStreamPlayer3D = $Props/Chairs/Chair2/ThrowSound


func _ready():
    # On connecte le signal, comme pour l'anomalie des lumières.
    chair_trigger.body_entered.connect(_on_player_entered.bind(true))


# On a modifié la fonction pour qu'elle devienne "async" pour pouvoir attendre un peu.
func _on_player_entered(body, disable_after_use: bool):
    # On vérifie que c'est le joueur.
    if body is CharacterBody3D:

        # On désactive le trigger IMMÉDIATEMENT pour éviter les déclenchements multiples.
        if disable_after_use:
            chair_trigger.get_node("CollisionShape3D").disabled = true

        # --- JUMPSCARE TIMING ---
        # On attend un très court instant (ex: 0.2s) avant de lancer la chaise.
        # Ce petit délai crée une tension : "Est-ce que quelque chose va se passer ?" -> BAM!
        await get_tree().create_timer(0.2).timeout

        # On passe le "body" (le joueur) à la fonction pour savoir où il est.
        throw_chair_at_player(body)


func throw_chair_at_player(player: CharacterBody3D):
    # --- C'EST ICI QUE LA MAGIE OPÈRE (VERSION JUMPSCARE) ---

    # 1. On calcule la direction vers le joueur.
    # C'est la position du joueur MOINS la position de la chaise.
    var player_position = player.global_position
    var chair_position = flying_chair.global_position

    # Pour viser le "visage" et non les pieds, on ajoute un peu de hauteur à la cible.
    var target_position = player_position + Vector3(0, 2.5, 0)

    # On normalise le vecteur pour n'avoir que la direction, pas la distance.
    var direction = (target_position - chair_position).normalized()

    # 2. On définit la force du lancer.
    # C'est la variable la plus importante à ajuster. Augmentez-la pour un lancer plus violent.
    var throw_strength = 30.0 # Ancienne force était un Vector3, maintenant c'est une magnitude.

    # On combine la direction et la force pour obtenir l'impulsion finale.
    var impulse = direction * throw_strength

    # 3. On applique la force et la rotation.

    # On joue un son violent juste au moment du lancer.
    if throw_sound:
        throw_sound.play()

    # apply_central_impulse applique une "poussée" instantanée et violente.
    flying_chair.apply_central_impulse(impulse)

    # On garde une rotation chaotique, mais on peut l'augmenter pour plus de violence.
    var rotation_force = Vector3(5, 10, 3)
    flying_chair.apply_torque_impulse(rotation_force)
