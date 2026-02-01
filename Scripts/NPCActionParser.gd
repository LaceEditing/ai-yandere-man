extends Node
class_name NPCActionParser

## Parses LLM responses for embedded action commands

signal action_detected(action_dict: Dictionary)

# Regex patterns for detecting actions in text
var action_patterns: Dictionary = {
	# [walk_to:Kitchen] or [move_to:Player]
	"movement": r"\[(?:walk_to|move_to):([^\]]+)\]",
	
	# [animate:sit] or [play:dance]
	"animation": r"\[(?:animate|play):([^\]]+)\]",
	
	# [look_at:Player] or [look:bookshelf]
	"look": r"\[look(?:_at)?:([^\]]+)\]",
	
	# [stop_looking], [stop_moving], or [stop_animation]  # UPDATED
	"stop": r"\[(stop_(?:looking|moving|animation))\]"
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
## UPDATED - Reflects all available animations and new stop_animation command
static func get_action_system_prompt() -> String:
	return """
# PHYSICAL ACTIONS

You can perform actions by embedding special tags in your responses. These tags will be hidden from the player but will trigger animations and movement.

## Available Action Tags:

1. **Movement**:
   - [walk_to:LocationName] - Walk to a location (Kitchen, Player, Bedroom, etc.)
   - [stop_moving] - Stop walking immediately
   
2. **Animations**:
   - [animate:idle] - Stand idle (default stance)
   - [animate:walk] - Walking animation (auto-triggers when moving)
   - [animate:sit] - Sit down
   - [animate:dance] - Dance (Dance1)
   - [animate:wave] - Wave gesture
   - [animate:talk] - Talking gesture/animation
   - [animate:macarena] - Macarena dance
   - [animate:chickendance] - Chicken dance
   - [animate:tennadance] - Tenna dance
   - [animate:breakdance1] - Breakdancing
   - [animate:tpose] - T-pose
   - [stop_animation] - Stop current animation and return to idle
   
3. **Head Tracking**:
   - [look_at:Player] - Look at the player
   - [look_at:ObjectName] - Look at a specific object/location
   - [stop_looking] - Return head to neutral position

## Important Notes:
- Animations can now be INTERRUPTED - you can start a new animation any time
- Use [stop_animation] to immediately return to idle stance
- Multiple tags can be used in one response
- Actions execute in the order they appear
- Tags are HIDDEN from the player (they only see your words)

## Usage Examples:

Player: "Could you come over here?"
You: "Of course! On my way. [walk_to:Player] [look_at:Player]"

Player: "Stop dancing and sit down."
You: "Alright, alright! [stop_animation] [animate:sit]"

Player: "What's in the kitchen?"
You: "Let me check. [walk_to:Kitchen] Hmm, not much here."

Player: "Wave at me!"
You: "Hey there! [animate:wave] [look_at:Player]"

Player: "Dance for me!"
You: "You got it! [animate:dance]"

Player: "Actually, do the macarena instead"
You: "Oh, switching it up! [animate:macarena]"

Player: "Nevermind, just stop"
You: "Okay, back to normal. [stop_animation]"

## Rules:
- Use actions naturally when they make sense
- Don't overuse - not every response needs an action
- You can interrupt your own animations now
- Movement and head tracking can happen simultaneously
- Walking automatically triggers the walk animation
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
