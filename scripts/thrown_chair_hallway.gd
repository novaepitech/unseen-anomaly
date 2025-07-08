
extends Node3D

# --- References ---
@onready var flying_chair: RigidBody3D = $Props/Chairs/Chair2
@onready var chair_trigger: Area3D = $ThrownChairTrigger
@onready var throw_sound: AudioStreamPlayer3D = $Props/Chairs/Chair2/ThrowSound


func _ready():
	# Connect the trigger's signal to our orchestration function, binding to disable it after first use.
	chair_trigger.body_entered.connect(_orchestrate_cinematic.bind(true))


## Orchestrates the cinematic micro-event. Asynchronous to control timing with `await`.
func _orchestrate_cinematic(body, disable_after_use: bool):
	# Ensure the event was triggered by the player.
	if not body is ProtoController:
		return

	var player: ProtoController = body

	# Disable the trigger immediately to prevent multiple activations.
	if disable_after_use:
		chair_trigger.get_node("CollisionShape3D").disabled = true

	# STEP 1: Block player controls.
	player.start_cinematic()

	# STEP 2: Force player view towards the chair.
	var look_tween = player.force_look_at(flying_chair.global_position, 0.2)
	await look_tween.finished

	# Add a short pause for tension.
	await get_tree().create_timer(0.3).timeout

	# STEP 3: Trigger the event.
	throw_chair_violently(player)

	# STEP 4: Return control to the player after a short delay.
	await get_tree().create_timer(1.5).timeout

	player.end_cinematic()


## Handles the violent throwing of the chair.
func throw_chair_violently(player: ProtoController):
	# 1. Calculate direction: target the player's "Head" node (camera position).
	var target_position = player.head.global_position
	var direction = flying_chair.global_position.direction_to(target_position)

	# 2. Define throw strength (adjust for desired effect).
	var throw_strength = 35.0
	var impulse = direction * throw_strength

	# 3. Apply force and play sound.
	if throw_sound:
		throw_sound.play()

	# Apply an instant and violent impulse.
	flying_chair.apply_central_impulse(impulse)

	# Apply chaotic rotation for a spinning effect.
	var rotation_force = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * 15.0
	flying_chair.apply_torque_impulse(rotation_force)
