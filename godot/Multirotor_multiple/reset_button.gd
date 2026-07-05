extends Button

@onready var swarm_manager: SwarmManager = $"/root/World/SwarmManager" as SwarmManager

# Connects this button to the swarm reset action.
func _ready() -> void:
	pressed.connect(on_pressed)

# Resets all active drones through the swarm manager.
func on_pressed() -> void:
	if swarm_manager != null:
		swarm_manager.reset_all()
