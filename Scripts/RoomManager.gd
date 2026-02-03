extends Node

## Global Room Manager - Tracks which room the player and NPCs are in
## Used by NPCs to understand spatial context beyond just vision

# Current locations
var player_current_room: String = "unknown"
var player_previous_room: String = "unknown"

# Track all NPCs and their rooms
var npc_locations: Dictionary = {}  # {npc_name: room_name}

# Room enter/exit events
signal player_entered_room(room_name: String)
signal player_exited_room(room_name: String)
signal npc_entered_room(npc_name: String, room_name: String)
signal npc_exited_room(npc_name: String, room_name: String)

func _ready():
	print("RoomManager initialized")

# ============ Player Location Tracking ============

func set_player_room(room_name: String):
	if room_name == player_current_room:
		return  # Already in this room
	
	player_previous_room = player_current_room
	player_current_room = room_name
	
	print("Player entered room: ", room_name)
	
	# Emit signals
	if player_previous_room != "unknown":
		player_exited_room.emit(player_previous_room)
	
	player_entered_room.emit(room_name)

func get_player_room() -> String:
	return player_current_room

func get_player_previous_room() -> String:
	return player_previous_room

func player_just_changed_rooms() -> bool:
	return player_previous_room != "unknown" and player_previous_room != player_current_room

# ============ NPC Location Tracking ============

func set_npc_room(npc_name: String, room_name: String):
	var previous_room = npc_locations.get(npc_name, "unknown")
	
	if room_name == previous_room:
		return  # Already in this room
	
	npc_locations[npc_name] = room_name
	
	print(npc_name, " is in room: ", room_name)
	
	# Emit signals
	if previous_room != "unknown":
		npc_exited_room.emit(npc_name, previous_room)
	
	npc_entered_room.emit(npc_name, room_name)

func get_npc_room(npc_name: String) -> String:
	return npc_locations.get(npc_name, "unknown")

func remove_npc(npc_name: String):
	npc_locations.erase(npc_name)

# ============ Spatial Queries ============

func is_player_in_same_room_as_npc(npc_name: String) -> bool:
	var npc_room = get_npc_room(npc_name)
	return npc_room != "unknown" and npc_room == player_current_room

func get_npcs_in_room(room_name: String) -> Array:
	var npcs_in_room: Array = []
	for npc_name in npc_locations:
		if npc_locations[npc_name] == room_name:
			npcs_in_room.append(npc_name)
	return npcs_in_room

func get_npcs_in_same_room_as_player() -> Array:
	return get_npcs_in_room(player_current_room)

# ============ Spatial Descriptions ============

func get_player_location_description() -> String:
	if player_current_room == "unknown":
		return "The player's location is unknown"
	
	var desc = "The player is currently in: " + player_current_room
	
	if player_just_changed_rooms():
		desc += " (just came from: " + player_previous_room + ")"
	
	return desc

func get_npc_location_description(npc_name: String) -> String:
	var npc_room = get_npc_room(npc_name)
	
	if npc_room == "unknown":
		return "You are in an unknown location"
	
	var desc = "You are currently in: " + npc_room
	
	# Check if player is in same room
	if is_player_in_same_room_as_npc(npc_name):
		desc += " (the player is here with you)"
	elif player_current_room != "unknown":
		desc += " (the player is in: " + player_current_room + ")"
	
	return desc

# ============ Debug Info ============

func get_room_node(room_display_name: String) -> Node3D:
	"""Find a room node by its display name (the room_name property).
	   Supports fuzzy matching - will match partial names like 'Storage' -> 'Storage Room'."""
	# Get all Room nodes in the scene tree
	var all_rooms = get_tree().get_nodes_in_group("rooms")
	var search_name = room_display_name.to_lower().strip_edges()
	
	# First try exact match (case-insensitive)
	for room in all_rooms:
		if room is Room and room.get_room_name().to_lower() == search_name:
			return room
	
	# Try partial match - if search term is contained in room name
	# e.g., "Storage" matches "Storage Room", "Kitchen" matches "Kitchen"
	for room in all_rooms:
		if room is Room:
			var room_name_lower = room.get_room_name().to_lower()
			# Check if search term is at the start of room name (e.g., "storage" in "storage room")
			if room_name_lower.begins_with(search_name):
				print("[RoomManager] 🔄 Fuzzy matched '", room_display_name, "' -> '", room.get_room_name(), "'")
				return room
			# Check if room name starts with search term
			if search_name in room_name_lower:
				print("[RoomManager] 🔄 Fuzzy matched '", room_display_name, "' -> '", room.get_room_name(), "'")
				return room
	
	# Not found - print debug info
	print("[RoomManager] ⚠️ Could not find room: '", room_display_name, "'")
	print("[RoomManager] Available rooms:")
	for room in all_rooms:
		if room is Room:
			print("  - '", room.get_room_name(), "'")
	
	return null

func get_all_locations() -> Dictionary:
	return {
		"player": player_current_room,
		"npcs": npc_locations
	}


func get_available_room_names() -> Array:
	"""Get list of all available room names in the scene."""
	var room_names: Array = []
	var all_rooms = get_tree().get_nodes_in_group("rooms")
	
	for room in all_rooms:
		if room is Room:
			room_names.append(room.get_room_name())
	
	return room_names


func get_other_rooms(exclude_room: String) -> Array:
	"""Get all rooms except the specified one."""
	var all_rooms = get_available_room_names()
	return all_rooms.filter(func(r): return r != exclude_room)


func print_all_locations():
	print("=== Room Locations ===")
	print("Player: ", player_current_room)
	for npc_name in npc_locations:
		print(npc_name, ": ", npc_locations[npc_name])
	print("=====================")
