extends Button

@export var swarm_manager_path: NodePath = ^"../SwarmManager"

@onready var swarm_manager: SwarmManager = get_node_or_null(swarm_manager_path) as SwarmManager

# Connects this button to the runtime drone spawn action.
func _ready() -> void:
	pressed.connect(on_pressed)
	if swarm_manager == null:
		push_warning("AddDroneButton could not find the SwarmManager.")

# Adds one drone through the swarm manager.
func on_pressed() -> void:
	if swarm_manager != null:
		swarm_manager.add_next_drone()
