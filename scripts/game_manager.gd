# GameManager.gd
# This script is designed to be an AutoLoad (Singleton).
# It persists across scene changes and manages the core game loop, state, and player interaction.

extends Node

## --- CONFIGURATION (Set your scenes here by dragging them from the FileSystem) ---

@export var tutorial_scene: PackedScene = preload("res://scenes/tutorial_hallway.tscn")
@export var normal_scene: PackedScene = preload("res://scenes/normal_hallway.tscn")

@export var anomaly_scenes: Array[PackedScene] = [
	preload("res://scenes/two_lockers_hallway.tscn"),
	preload("res://scenes/no_sound_hallway.tscn"),
	preload("res://scenes/small_chairs_hallway.tscn"),
	preload("res://scenes/two_chairs_hallway.tscn"),
	preload("res://scenes/five_chairs_hallway.tscn"),
	preload("res://scenes/lights_out_hallway.tscn"),
	preload("res://scenes/door_knock_hallway.tscn"),
	preload("res://scenes/thrown_chair_hallway.tscn"),
]

@export var win_scene_path: String = "res://scenes/win_screen.tscn"
@export var loops_to_win: int = 8
@export var anomaly_chance: float = 0.6


## --- INTERNAL VARIABLES ---

var player: CharacterBody3D = null
var current_loop_instance: Node = null
var current_loop_is_anomalous: bool = false
var current_loop_counter: int = 0
var is_handling_choice: bool = false
var tutorial_shown: bool = false
var normal_loops_in_a_row: int = 0

# NEW: Tracks all anomalies seen in the current playthrough to prevent any repeats.
var seen_anomalies: Array[PackedScene] = []


# Resets the game state variables to their initial values.
func reset_game_state():
	current_loop_counter = 0
	seen_anomalies.clear() # NEW: Clear the list of seen anomalies
	normal_loops_in_a_row = 0
	is_handling_choice = false
	print("GameManager state reset.")

# Called once when the AutoLoad is initialized at the start of the game.
func _ready():
	print("GameManager (AutoLoad) is ready and waiting for the player.")


# This function MUST be called by the player from its own _ready() function.
func register_player(player_node: CharacterBody3D):
	if is_instance_valid(self.player):
		print("Warning: A player is already registered. Ignoring new registration.")
		return

	self.player = player_node
	print("Player registered successfully with GameManager.")
	start_new_loop.call_deferred()


# This is the main function that sets up each loop.
func start_new_loop():
	if not is_instance_valid(player):
		print("Error: Tried to start a loop, but no player is registered.")
		return

	if is_instance_valid(current_loop_instance):
		current_loop_instance.queue_free()

	var scene_to_load: PackedScene

	if not tutorial_shown:
		scene_to_load = tutorial_scene
		tutorial_shown = true
		current_loop_is_anomalous = false
	else:
		if current_loop_counter == 0:
			current_loop_is_anomalous = false
		else:
			current_loop_is_anomalous = normal_loops_in_a_row >= 2 or randf() < anomaly_chance

		if current_loop_is_anomalous:
			normal_loops_in_a_row = 0
		else:
			normal_loops_in_a_row += 1

		if current_loop_is_anomalous:
			# --- NEW: Improved Anomaly Selection Logic ---
			# 1. Create a list of anomalies the player has NOT yet seen.
			var available_anomalies = []
			for scene in anomaly_scenes:
				if not scene in seen_anomalies:
					available_anomalies.append(scene)

			# 2. If all anomalies have been seen, reset the list to allow repeats.
			if available_anomalies.is_empty():
				print("All unique anomalies shown. Resetting pool.")
				seen_anomalies.clear()
				available_anomalies = anomaly_scenes.duplicate()

			# 3. Pick a random anomaly from the available (unseen) ones.
			scene_to_load = available_anomalies.pick_random()

			# 4. Add the chosen anomaly to our list of seen anomalies for this playthrough.
			seen_anomalies.append(scene_to_load)
		else:
			scene_to_load = normal_scene

	current_loop_instance = scene_to_load.instantiate()
	get_tree().root.add_child(current_loop_instance)

	var forward_trigger = current_loop_instance.get_node("Triggers/ForwardTrigger")
	var backward_trigger = current_loop_instance.get_node("Triggers/BackwardTrigger")

	forward_trigger.body_entered.connect(_on_forward_trigger_entered)
	backward_trigger.body_entered.connect(_on_backward_trigger_entered)

	var spawn_point = current_loop_instance.get_node("Triggers/SpawnPoint")
	teleport_player_to_spawn(spawn_point)

	var level_text_hint = current_loop_instance.get_node("LevelTextHint")
	level_text_hint.text = "Floor " + str(current_loop_counter)


func teleport_player_to_spawn(spawn_point: Node3D):
	var spawn_transform = spawn_point.global_transform
	player.global_position = spawn_transform.origin
	player.rotation.y = spawn_transform.basis.get_euler().y
	player.head.rotation.x = 0.0
	await get_tree().process_frame
	player.sync_rotation()


func _on_forward_trigger_entered(body: Node3D):
	if body == player:
		handle_player_choice(true)

func _on_backward_trigger_entered(body: Node3D):
	if body == player:
		handle_player_choice(false)


func handle_player_choice(went_forward: bool):
	if is_handling_choice: return
	is_handling_choice = true

	if is_instance_valid(current_loop_instance):
		var forward_trigger = current_loop_instance.get_node("Triggers/ForwardTrigger")
		var backward_trigger = current_loop_instance.get_node("Triggers/BackwardTrigger")
		if forward_trigger.is_connected("body_entered", _on_forward_trigger_entered):
			forward_trigger.body_entered.disconnect(_on_forward_trigger_entered)
		if backward_trigger.is_connected("body_entered", _on_backward_trigger_entered):
			backward_trigger.body_entered.disconnect(_on_backward_trigger_entered)

	var is_choice_correct = (went_forward and not current_loop_is_anomalous) or \
		(not went_forward and current_loop_is_anomalous)

	if is_choice_correct:
		current_loop_counter += 1
		print("Correct! Streak: %d / %d" % [current_loop_counter, loops_to_win])

		if current_loop_counter >= loops_to_win:
			print("YOU WIN!")
			get_tree().change_scene_to_file(win_scene_path)
		else:
			start_new_loop()
	else:
		current_loop_counter = 0
		normal_loops_in_a_row = 0
		seen_anomalies.clear() # NEW: Reset seen anomalies on incorrect choice.
		print("Incorrect! Streak reset to 0.")
		start_new_loop()

	await get_tree().create_timer(0.2).timeout
	is_handling_choice = false
