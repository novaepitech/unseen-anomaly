# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

class_name ProtoController
extends CharacterBody3D

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 4.5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

# --- NOUVELLE VARIABLE ---
## Est-on dans un événement cinématique qui bloque les contrôles ?
var is_in_cinematic : bool = false

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
    check_input_mappings()
    look_rotation.y = rotation.y
    look_rotation.x = head.rotation.x
    GameManager.register_player(self)

    # Immediately capture the mouse when the player is ready.
    capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
    # --- MISE À JOUR ---
    # Si on est en cinématique, on ignore tous les inputs.
    if is_in_cinematic:
        return

    # Mouse capturing
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        capture_mouse()
    if Input.is_key_pressed(KEY_ESCAPE):
        release_mouse()

    # Look around
    if mouse_captured and event is InputEventMouseMotion:
        rotate_look(event.relative)

    # Toggle freefly mode
    if can_freefly and Input.is_action_just_pressed(input_freefly):
        if not freeflying:
            enable_freefly()
        else:
            disable_freefly()

func _physics_process(delta: float) -> void:
    # --- MISE À JOUR ---
    # Si on est en cinématique, on bloque tout mouvement physique.
    if is_in_cinematic:
        # On s'assure que le joueur s'arrête net.
        velocity = Vector3.ZERO
        move_and_slide()
        return

    # If freeflying, handle freefly and nothing else
    if can_freefly and freeflying:
        var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
        var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
        motion *= freefly_speed * delta
        move_and_collide(motion)
        return

    # Apply gravity to velocity
    if has_gravity:
        if not is_on_floor():
            velocity += get_gravity() * delta

    # Apply jumping
    if can_jump:
        if Input.is_action_just_pressed(input_jump) and is_on_floor():
            velocity.y = jump_velocity

    # Modify speed based on sprinting
    if can_sprint and Input.is_action_pressed(input_sprint):
        move_speed = sprint_speed
    else:
        move_speed = base_speed

    # Apply desired movement to velocity
    if can_move:
        var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
        var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
        if move_dir:
            velocity.x = move_dir.x * move_speed
            velocity.z = move_dir.z * move_speed
        else:
            velocity.x = move_toward(velocity.x, 0, move_speed)
            velocity.z = move_toward(velocity.z, 0, move_speed)
    else:
        # On annule la vélocité si le mouvement n'est pas permis.
        velocity.x = 0
        velocity.z = 0 # On conserve la vélocité y pour la gravité/saut.

    # Use velocity to actually move
    move_and_slide()


## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
    look_rotation.x -= rot_input.y * look_speed
    look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
    look_rotation.y -= rot_input.x * look_speed
    transform.basis = Basis()
    rotate_y(look_rotation.y)
    head.transform.basis = Basis()
    head.rotate_x(look_rotation.x)


# --- NOUVELLES FONCTIONS CINÉMATIQUES ---

## Démarre un événement cinématique, bloquant tous les contrôles du joueur.
func start_cinematic():
    is_in_cinematic = true

## Termine un événement cinématique, rendant le contrôle au joueur.
func end_cinematic():
    is_in_cinematic = false
    # On s'assure que la souris est recapturée à la fin de la cinématique.
    capture_mouse()

## Force la caméra à regarder une position dans le monde.
## Retourne le Tween pour pouvoir attendre la fin de l'animation avec "await".
func force_look_at(target_position: Vector3, duration: float) -> Tween:
    # On calcule la direction vers la cible depuis la tête du joueur.
    var direction_to_target = head.global_position.direction_to(target_position)

    # On calcule les angles de lacet (yaw) et de tangage (pitch) nécessaires.
    # Lacet (rotation Y) : atan2 est parfait pour ça.
    var target_yaw = atan2(-direction_to_target.x, -direction_to_target.z)
    # Tangage (rotation X) : asin sur la composante Y.
    var target_pitch = asin(direction_to_target.y)

    # On crée un Tween pour une rotation douce mais rapide.
    var tween = create_tween()
    tween.set_parallel(true) # On veut que les rotations Y et X se fassent en même temps.
    tween.set_trans(Tween.TRANS_QUINT) # Une transition douce au début et à la fin.
    tween.set_ease(Tween.EASE_OUT)

    # On anime la rotation Y du corps du joueur.
    tween.tween_property(self, "rotation:y", target_yaw, duration)
    # On anime la rotation X de la tête du joueur.
    tween.tween_property(head, "rotation:x", target_pitch, duration)

    # IMPORTANT: Une fois la rotation terminée, on doit synchroniser nos variables internes.
    tween.finished.connect(sync_rotation)

    return tween

## Call this after teleporting to sync internal rotation with the node's transform.
func sync_rotation():
    # The body's Y rotation (left/right look)
    look_rotation.y = self.rotation.y
    # The head's X rotation (up/down look)
    look_rotation.x = head.rotation.x


func enable_freefly():
    collider.disabled = true
    freeflying = true
    velocity = Vector3.ZERO

func disable_freefly():
    collider.disabled = false
    freeflying = false


func capture_mouse():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    mouse_captured = true


func release_mouse():
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    mouse_captured = false


## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
    if can_move and not InputMap.has_action(input_left):
        push_error("Movement disabled. No InputAction found for input_left: " + input_left)
        can_move = false
    if can_move and not InputMap.has_action(input_right):
        push_error("Movement disabled. No InputAction found for input_right: " + input_right)
        can_move = false
    if can_move and not InputMap.has_action(input_forward):
        push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
        can_move = false
    if can_move and not InputMap.has_action(input_back):
        push_error("Movement disabled. No InputAction found for input_back: " + input_back)
        can_move = false
    if can_jump and not InputMap.has_action(input_jump):
        push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
        can_jump = false
    if can_sprint and not InputMap.has_action(input_sprint):
        push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
        can_sprint = false
    if can_freefly and not InputMap.has_action(input_freefly):
        push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
        can_freefly = false
