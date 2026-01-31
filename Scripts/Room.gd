extends Area3D
class_name Room

## Room Trigger Area - Detects when player/NPCs enter this room
## Place this on an Area3D node that covers the room's boundaries

@export var room_name: String = "Living Room" ## Name of this room (used by AI)
@export_multiline var room_description: String = "A cozy living room with a fireplace" ## Description for AI context

# Track who's currently in this room
var entities_in_room: Array = []

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("Room trigger initialized: ", room_name)

func _on_body_entered(body: Node3D):
	# Check if it's the player
	if body.is_in_group("player"):
		RoomManager.set_player_room(room_name)
		entities_in_room.append(body)
		print("Player entered: ", room_name)
	
	# Check if it's an NPC
	elif body.has_method("get") and body.get("npc_name"):
		var npc_name = body.npc_name
		RoomManager.set_npc_room(npc_name, room_name)
		entities_in_room.append(body)
		print(npc_name, " entered: ", room_name)

func _on_body_exited(body: Node3D):
	if entities_in_room.has(body):
		entities_in_room.erase(body)
	
	# Don't set "unknown" on exit because another room will immediately
	# set the new location. This prevents flickering between rooms.

func get_room_name() -> String:
	return room_name

func get_room_description() -> String:
	return room_description

func is_player_here() -> bool:
	return RoomManager.get_player_room() == room_name

func get_npcs_here() -> Array:
	return RoomManager.get_npcs_in_room(room_name)
