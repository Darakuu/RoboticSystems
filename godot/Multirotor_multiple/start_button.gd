extends Button

# Connects this button to the global DDS start signal.
func _ready() -> void:
	pressed.connect(on_start)

# Publishes the controller start signal.
func on_start() -> void:
	DDS.publish("start", DDS.DDS_TYPE_INT, 1)
