extends Node3D

# @onready ensures that nodes are available before access.

@onready var lights_container = $Props/Lights
@onready var lights_out_trigger = $LightsOutTrigger

func _ready():
    # Connect the trigger's signal to our function to turn off the lights.
    # We use .bind(true) to pass an argument and ensure the function is called only once,
    # by disabling the trigger after the first use.
    lights_out_trigger.body_entered.connect(_on_player_entered.bind(true))


func _on_player_entered(body, disable_after_use: bool):
    # Ensure the body is the player. A "class_name Player" in the player script is recommended.
    if body is CharacterBody3D: # Replace with your player class if needed.

        # Iterate through all nodes in the lights container.
        for node in lights_container.get_children():
            # Ensure the node is a light before trying to turn it off.
            if node is not AudioStreamPlayer3D:
                node.visible = false # Turn off the light.
            else:
                node.stop()
            $Props/Lights/LightsOutSound.play()

        # If requested, disable the trigger after use to prevent the lights from turning "on again"
        # or the code from re-executing if the player moves back and forth in the area.
        if disable_after_use:
            lights_out_trigger.get_node("CollisionShape3D").disabled = true
