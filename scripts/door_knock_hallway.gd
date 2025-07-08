extends Node3D

# @onready ensures that nodes are available before access.

@onready var knock_sound_trigger = $KnockSoundTrigger

func _ready():
    # Connect the trigger's signal to our function.
    # We use .bind(true) to pass an argument and ensure the function is called only once,
    # by disabling the trigger after the first use.
    knock_sound_trigger.body_entered.connect(_on_player_entered.bind(true))


func _on_player_entered(body, disable_after_use: bool):
    # Ensure the body is the player. A "class_name Player" in the player script is recommended.
    if body is CharacterBody3D: # Replace with your player class if needed.

        $Props/Door/KnockSound.play()

        # If requested, disable the trigger after use to prevent the sound from playing again
        # or the code from re-executing if the player re-enters the area.
        if disable_after_use:
            knock_sound_trigger.get_node("CollisionShape3D").disabled = true
