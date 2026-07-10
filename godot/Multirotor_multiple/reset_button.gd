extends Button

@onready var swarm_manager: SwarmManager = $"../SwarmManager"


func _ready() -> void:
	pressed.connect(swarm_manager.reset_all)
