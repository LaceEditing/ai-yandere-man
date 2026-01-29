extends Node

# Track all NPCs in the scene, should only be one lol
var active_npcs: Array = []

func register_npc(npc: Node):
	if not active_npcs.has(npc):
		active_npcs.append(npc)
		print("Registered NPC: ", npc.npc_name)

func unregister_npc(npc: Node):
	active_npcs.erase(npc)
	print("Unregistered NPC: ", npc.npc_name if npc else "unknown")

# Get the current scene's NPC ref
func get_current_npc() -> Node:
	if active_npcs.size() > 0:
		return active_npcs[0]
	return null
