# GameManager.gd
# This script is designed to be an AutoLoad (Singleton).
# It persists across scene changes and manages the core game loop, state, and player interaction.

extends Node

## --- EXPORTED VARIABLES (Configurable from the Project Settings -> AutoLoad tab) ---
# NOTE: To edit these, you must open the script directly. You can no longer see them in the Inspector.
# If you prefer to see them in the Inspector, you can create a "Config" scene with this script and
# configure it there, but for a game jam, editing them here is faster.

# The "perfect" corridor scene with no anomalies.
@export var normal_scene: PackedScene = preload("res://scenes/normal_hallway.tscn")

# The tutorial hallway scene to show on first run
@export var tutorial_scene: PackedScene = preload("res://scenes/tutorial_hallway.tscn")

# An array to hold all your anomaly scenes.
@export var anomaly_scenes: Array[PackedScene] = [
    preload("res://scenes/two_lockers_hallway.tscn"),
    preload("res://scenes/no_sound_hallway.tscn"),
    preload("res://scenes/small_chairs_hallway.tscn")
]

# The path to your "You Win!" screen.
@export var win_scene_path: String = "res://scenes/win_screen.tscn"

# How many correct loops in a row are needed to win.
@export var loops_to_win: int = 8

# The probability (from 0.0 to 1.0) of an anomaly spawning.
# 0.5 means a 50% chance.
@export var anomaly_chance: float = 0.5


## --- INTERNAL VARIABLES ---

# The player node. It will be null until the player registers itself.
var player: CharacterBody3D = null

# Track the previously shown anomaly scene to prevent repeats
var previous_anomaly_scene: PackedScene = null

var current_loop_instance: Node = null
var current_loop_is_anomalous: bool = false
var current_loop_counter: int = 0
var is_handling_choice: bool = false
var tutorial_shown: bool = false


# Called once when the AutoLoad is initialized at the start of the game.
func _ready():
    # The GameManager is now ready, but it doesn't know about the player yet.
    # It will wait for the player to call the register_player() function.
    print("GameManager (AutoLoad) is ready and waiting for the player.")


# This function MUST be called by the player from its own _ready() function.
func register_player(player_node: CharacterBody3D):
    if is_instance_valid(self.player):
        print("Warning: A player is already registered. Ignoring new registration.")
        return

    self.player = player_node
    print("Player registered successfully with GameManager.")

    # On demande à Godot de démarrer la boucle plus tard, quand tout sera prêt.
    start_new_loop.call_deferred()


# This is the main function that sets up each loop.
func start_new_loop():
    # Safety check: Do nothing if the player hasn't been registered yet.
    if not is_instance_valid(player):
        print("Error: Tried to start a loop, but no player is registered.")
        return

    # 1. Clean up the previous corridor if it exists.
    if is_instance_valid(current_loop_instance):
        current_loop_instance.queue_free()

    # 2. Decide which scene to load
    var scene_to_load: PackedScene

    # Show tutorial on first loop if not shown already
    if not tutorial_shown:
        scene_to_load = tutorial_scene
        tutorial_shown = true
        current_loop_is_anomalous = false
    else:
        # Original logic for normal/anomaly scenes
        if current_loop_counter == 0:
            current_loop_is_anomalous = false
        else:
            current_loop_is_anomalous = randf() < anomaly_chance

        if current_loop_is_anomalous:
            # Don't pick the same anomaly twice in a row
            if previous_anomaly_scene != null and anomaly_scenes.size() > 1:
                var available_anomalies = []
                for scene in anomaly_scenes:
                    if scene != previous_anomaly_scene:
                        available_anomalies.append(scene)
                scene_to_load = available_anomalies.pick_random()
                previous_anomaly_scene = scene_to_load
            else:
                scene_to_load = anomaly_scenes.pick_random()
                previous_anomaly_scene = scene_to_load
        else:
            scene_to_load = normal_scene

    # 3. Instantiate the chosen scene and add it as a child of the current scene's root.
    # This makes sure the corridor is added to the "Main" scene, not to the GameManager itself.
    current_loop_instance = scene_to_load.instantiate()
    get_tree().root.add_child(current_loop_instance)

    # 4. Connect the triggers of the NEW corridor to our choice handlers.
    var forward_trigger = current_loop_instance.get_node("Triggers/ForwardTrigger")
    var backward_trigger = current_loop_instance.get_node("Triggers/BackwardTrigger")

    forward_trigger.body_entered.connect(_on_forward_trigger_entered)
    backward_trigger.body_entered.connect(_on_backward_trigger_entered)

    # 5. Teleport the player to the start of the new corridor.
    var spawn_point = current_loop_instance.get_node("Triggers/SpawnPoint")
    player.global_transform = spawn_point.global_transform
    player.sync_rotation()

    var level_text_hint = current_loop_instance.get_node("Props/Door/LevelTextHint")
    level_text_hint.text = str(current_loop_counter) + "01"


# Called by the ForwardTrigger's signal.
func _on_forward_trigger_entered(body: Node3D):
    if body == player:
        handle_player_choice(true)

# Called by the BackwardTrigger's signal.
func _on_backward_trigger_entered(body: Node3D):
    if body == player:
        handle_player_choice(false)


# This function checks if the player's choice was correct.
func handle_player_choice(went_forward: bool):
    # This flag now acts as a "lock" to prevent this function from running
    # multiple times in quick succession.
    if is_handling_choice: return
    is_handling_choice = true

    # Disconnect the signals immediately as a safety measure.
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

        # Check for win condition
        if current_loop_counter >= loops_to_win:
            print("YOU WIN!")
            get_tree().change_scene_to_file(win_scene_path)
        else:
            start_new_loop()
    else:
        current_loop_counter = 0
        print("Incorrect! Streak reset to 0.")
        start_new_loop()

    # Wait for a fraction of a second. This gives the engine time to process
    # the scene change and ignore any stray, queued signals from the old trigger.
    await get_tree().create_timer(0.2).timeout

    # Now that the cooldown is over, unlock the handler for the next loop.
    is_handling_choice = false
