extends Button

@export var debug_overlay_path: NodePath = ^"../BoidsDebugOverlay"

@onready var debug_overlay: Node = get_node_or_null(debug_overlay_path)

# Connects this button to the Boids debug text toggle.
func _ready() -> void:
	pressed.connect(on_pressed)
	_refresh_label(true)
	if debug_overlay == null:
		push_warning("BoidsDebugTextToggleButton could not find the Boids debug overlay.")

# Toggles only the floating per-drone debug text.
func on_pressed() -> void:
	if debug_overlay == null:
		return

	var is_visible: bool = bool(debug_overlay.call("toggle_debug_text_visible"))
	_refresh_label(is_visible)

# Shows whether pressing the button will enable or disable debug text.
func _refresh_label(is_visible: bool) -> void:
	text = "Hide Text" if is_visible else "Show Text"
