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

func get_all_locations() -> Dictionary:
	return {
		"player": player_current_room,
		"npcs": npc_locations
	}

func print_all_locations():
	print("=== Room Locations ===")
	print("Player: ", player_current_room)
	for npc_name in npc_locations:
		print(npc_name, ": ", npc_locations[npc_name])
	print("=====================")
