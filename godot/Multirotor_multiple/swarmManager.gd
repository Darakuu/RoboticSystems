class_name SwarmManager
extends Node3D

@export var drone_count : int = 4
@export var spawn_spacing: float = 1.0
@export var robot_scene: PackedScene # So that we can instantiate new drones via code.

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
