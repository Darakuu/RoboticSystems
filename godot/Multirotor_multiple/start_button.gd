extends Button


func _ready() -> void:
	pressed.connect(_publish_start)


func _publish_start() -> void:
	DDS.publish("start", DDS.DDS_TYPE_INT, 1)
