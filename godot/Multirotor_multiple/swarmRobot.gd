class_name SwarmRobot
extends Node3D

@export var drone_id: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Returns the drone id for the given name.
func topic(droneName: String) -> String:
	return "D%d_%s" % [drone_id, droneName]
