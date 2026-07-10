extends OptionButton

const FORMATION_NAMES: Array[String] = ["NONE", "LINE", "TRIANGLE", "SQUARE", "CIRCLE"]

@onready var swarm_manager: SwarmManager = $"../SwarmManager"


func _ready() -> void:
	for formation_id: int in range(FORMATION_NAMES.size()):
		add_item(FORMATION_NAMES[formation_id], formation_id)
	select(swarm_manager.formation_id)
	item_selected.connect(swarm_manager.set_formation_id)
