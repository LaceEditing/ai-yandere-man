extends Node
class_name NPCActionParser

## Parses LLM responses for embedded action commands
## Allows the AI to naturally trigger animations and movement

signal action_detected(action_dict: Dictionary)

# Regex patterns for detecting actions in text
var action_patterns: Dictionary = {
	# [walk_to:Kitchen] or [move_to:Player]
	"movement": r"\[(?:walk_to|move_to):([^\]]+)\]",
	
	# [animate:sit] or [play:dance]
	"animation": r"\[(?:animate|play):([^\]]+)\]",
	
	# [look_at:Player] or [look:bookshelf]
	"look": r"\[look(?:_at)?:([^\]]+)\]",
	
	# [stop_looking] or [stop_moving]
	"stop": r"\[(stop_(?:looking|moving))\]"
}

# Compiled regex (cached for performance)
var compiled_patterns: Dictionary = {}

func _ready():
	# Compile all regex patterns
	for key in action_patterns:
		var regex = RegEx.new()
		regex.compile(action_patterns[key])
		compiled_patterns[key] = regex

## Parse text for action commands and return clean text + actions
func parse_response(text: String) -> Dictionary:
	var clean_text = text
	var actions: Array = []
	
	# Check each pattern type
	for pattern_name in compiled_patterns:
		var regex: RegEx = compiled_patterns[pattern_name]
		var matches = regex.search_all(text)
		
		for match in matches:
			# Remove the action tag from text
			clean_text = clean_text.replace(match.get_string(), "")
			
			# Extract action data
			var action_dict = _build_action_dict(pattern_name, match)
			if action_dict:
				actions.append(action_dict)
				action_detected.emit(action_dict)
	
	return {
		"text": clean_text.strip_edges(),
		"actions": actions
	}

func _build_action_dict(pattern_type: String, regex_match: RegExMatch) -> Dictionary:
	match pattern_type:
		"movement":
			return {
				"action": "walk_to",
				"target": regex_match.get_string(1).strip_edges()
			}
		
		"animation":
			return {
				"action": "play_animation",
				"animation": regex_match.get_string(1).strip_edges()
			}
		
		"look":
			return {
				"action": "look_at",
				"target": regex_match.get_string(1).strip_edges()
			}
		
		"stop":
			var stop_type = regex_match.get_string(1).strip_edges()
			return {
				"action": stop_type
			}
	
	return {}

## Generate context for LLM about available actions
static func get_action_system_prompt() -> String:
	return """
# PHYSICAL ACTIONS

You can perform actions by embedding special tags in your responses. These tags will be hidden from the player but will trigger animations and movement.

## Available Action Tags:

1. **Movement**:
   - [walk_to:LocationName] - Walk to a location (Kitchen, Player, Bedroom, etc.)
   - [stop_moving] - Stop walking
   
2. **Animations**:
   - [animate:idle] - Stand idle
   - [animate:walk] - Walking animation (auto-triggers when moving)
   - [animate:sit] - Sit down
   - [animate:dance] - Dance
   - [animate:wave] - Wave
   - [animate:talk] - Talking gesture
   
3. **Head Tracking**:
   - [look_at:Player] - Look at the player
   - [look_at:ObjectName] - Look at a specific object/location
   - [stop_looking] - Return head to neutral

## Usage Examples:

Player: "Could you come over here?"
You: "Of course! On my way. [walk_to:Player] [look_at:Player]"

Player: "What's in the kitchen?"
You: "Let me check. [walk_to:Kitchen] Hmm, not much here."

Player: "Dance for me!"
You: "Alright, here goes! [animate:dance]"

Player: "Sit down and relax"
You: "Don't mind if I do. [animate:sit] [stop_looking]"

## Rules:
- Tags are HIDDEN from the player (they only see your words)
- You can use multiple tags in one response
- Actions execute in the order they appear
- Movement is automatic - you don't need to say "I'm walking to..."
- Use actions naturally when they make sense for the conversation
- Don't overuse - not every response needs an action
"""

## Check if a location exists in the scene
static func is_valid_location(location_name: String, scene_root: Node) -> bool:
	var node = scene_root.find_child(location_name, true, false)
	return node != null

## Get list of valid locations in current scene
static func get_scene_locations(scene_root: Node) -> Array:
	var locations: Array = []
	
	# Find all Area3D nodes with Room script
	for child in scene_root.get_children():
		if child is Area3D and child.has_method("get_room_name"):
			locations.append(child.get_room_name())
	
	return locations
