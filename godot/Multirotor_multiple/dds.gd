extends Node

const COMMAND_KEEP_ALIVE: int = 0x80
const COMMAND_SUBSCRIBE: int = 0x81
const COMMAND_PUBLISH: int = 0x82

const DDS_TYPE_UNKNOWN: int = 0
const DDS_TYPE_INT: int = 1
const DDS_TYPE_FLOAT: int = 2

@export var server_port: int = 4444

var udp_server: UDPServer
var peers: Array[PacketPeerUDP] = []
var subscribers: Dictionary = {}
var published_variables: Dictionary = {}
var subscribed_values: Dictionary = {}


class DDSVariable:
	var name: String
	var value_type: int = DDS_TYPE_UNKNOWN
	var peers: Array[PacketPeerUDP] = []
	var packet: PackedByteArray = PackedByteArray()
	var value_offset: int = 0

	func _init(variable_name: String) -> void:
		name = variable_name

	func add_peer(peer: PacketPeerUDP) -> void:
		if peer not in peers:
			peers.append(peer)

	func remove_peer(peer: PacketPeerUDP) -> void:
		peers.erase(peer)

	func set_value(new_type: int, value) -> void:
		if new_type != value_type:
			value_type = new_type
			_prepare_packet()

		if value_type == DDS_TYPE_INT:
			packet.encode_s32(value_offset, int(value))
		elif value_type == DDS_TYPE_FLOAT:
			packet.encode_float(value_offset, float(value))

	func publish() -> void:
		for peer: PacketPeerUDP in peers:
			peer.put_packet(packet)

	func _prepare_packet() -> void:
		var encoded_name: PackedByteArray = name.to_ascii_buffer()
		packet.resize(encoded_name.size() + 7)
		packet.encode_u8(0, COMMAND_PUBLISH)
		packet.encode_u8(1, value_type)
		packet.encode_u8(2, encoded_name.size())
		for index: int in range(encoded_name.size()):
			packet.encode_u8(index + 3, encoded_name[index])
		value_offset = encoded_name.size() + 3


class Subscription:
	var variables: Dictionary = {}


func _ready() -> void:
	udp_server = UDPServer.new()
	var error: Error = udp_server.listen(server_port)
	if error != OK:
		push_error("DDS could not listen on UDP port %d." % server_port)


func _process(_delta: float) -> void:
	udp_server.poll()
	while udp_server.is_connection_available():
		peers.append(udp_server.take_connection())

	for peer: PacketPeerUDP in peers.duplicate():
		_process_packets(peer)


func publish(name: String, value_type: int, value) -> void:
	var variable: DDSVariable = published_variables.get(name) as DDSVariable
	if variable == null:
		return
	variable.set_value(value_type, value)
	variable.publish()


func subscribe(name: String) -> void:
	if not subscribed_values.has(name):
		subscribed_values[name] = 0.0


func read(name: String):
	return subscribed_values.get(name, 0.0)


func clear(name: String) -> void:
	subscribed_values[name] = 0.0


func _process_packets(peer: PacketPeerUDP) -> void:
	while peer.get_available_packet_count() > 0:
		var packet: PackedByteArray = peer.get_packet()
		if packet.is_empty():
			continue

		var subscription: Subscription = _subscription_for(peer)
		match packet.decode_u8(0):
			COMMAND_KEEP_ALIVE:
				pass
			COMMAND_SUBSCRIBE:
				_subscribe_remote(peer, subscription, packet)
			COMMAND_PUBLISH:
				_read_remote_value(packet)


func _subscription_for(peer: PacketPeerUDP) -> Subscription:
	var subscription: Subscription = subscribers.get(peer) as Subscription
	if subscription == null:
		subscription = Subscription.new()
		subscribers[peer] = subscription
	return subscription


func _subscribe_remote(peer: PacketPeerUDP, subscription: Subscription, packet: PackedByteArray) -> void:
	for variable: DDSVariable in subscription.variables.values():
		variable.remove_peer(peer)
	subscription.variables.clear()

	var variable_count: int = packet.decode_u8(1)
	var offset: int = 2
	for _index: int in range(variable_count):
		var name_length: int = packet.decode_u8(offset)
		var name: String = packet.slice(offset + 1, offset + name_length + 1).get_string_from_utf8()
		var variable: DDSVariable = published_variables.get(name) as DDSVariable
		if variable == null:
			variable = DDSVariable.new(name)
			published_variables[name] = variable
		variable.add_peer(peer)
		subscription.variables[name] = variable
		offset += name_length + 1


func _read_remote_value(packet: PackedByteArray) -> void:
	var value_type: int = packet.decode_u8(1)
	var name_length: int = packet.decode_u8(2)
	var name: String = packet.slice(3, name_length + 3).get_string_from_utf8()
	var value_offset: int = name_length + 3

	if value_type == DDS_TYPE_INT:
		subscribed_values[name] = packet.decode_s32(value_offset)
	elif value_type == DDS_TYPE_FLOAT:
		subscribed_values[name] = packet.decode_float(value_offset)
