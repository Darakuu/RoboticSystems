extends OptionButton

@export var swarm_manager_path: NodePath = ^"../SwarmManager"

@onready var swarm_manager: SwarmManager = get_node_or_null(swarm_manager_path) as SwarmManager

# Populates the formation choices and publishes the initial selection.
func _ready() -> void:
	_build_items()
	item_selected.connect(on_item_selected)

	if swarm_manager == null:
		push_warning("FormationSelector could not find the SwarmManager.")
		return

	_select_formation_id(swarm_manager.formation_id)
	swarm_manager.set_formation_id(get_selected_id())

# Sends the selected formation enum to the swarm manager.
func on_item_selected(index: int) -> void:
	if swarm_manager != null:
		swarm_manager.set_formation_id(get_item_id(index))

# Adds the visible formation names with their canonical DDS ids.
func _build_items() -> void:
	clear()
	add_item("NONE", SwarmManager.Formation.NONE)
	add_item("LINE", SwarmManager.Formation.LINE)
	add_item("TRIANGLE", SwarmManager.Formation.TRIANGLE)
	add_item("SQUARE", SwarmManager.Formation.SQUARE)
	add_item("CIRCLE", SwarmManager.Formation.CIRCLE)

# Selects the UI item that matches a formation id.
func _select_formation_id(selected_formation_id: int) -> void:
	for index: int in range(item_count):
		if get_item_id(index) == selected_formation_id:
			select(index)
			return

	select(0)
