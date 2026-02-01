extends Node
class_name NPCActionController

## Handles NPC animations, movement, and head tracking
## This is the bridge between AI decisions and physical actions

signal action_started(action_name: String)
signal action_completed(action_name: String)
signal navigation_complete()

@export var npc_body: CharacterBody3D
@export var animation_player: AnimationPlayer
@export var navigation_agent: NavigationAgent3D
@export var skeleton: Skeleton3D
@export var head_bone_name: String = "Head"  # Adjust to match your rig
@export var neck_bone_name: String = "Neck"  # Optional for smoother tracking

# Movement settings
@export var walk_speed: float = 2.0
@export var turn_speed: float = 5.0

# Head tracking settings
@export var enable_head_tracking: bool = true
@export var head_track_speed: float = 3.0
@export var max_head_angle: float = 80.0  # Max degrees head can turn

# Current state
var current_animation: String = "idle"
var is_moving: bool = false
var look_target: Vector3 = Vector3.ZERO
var has_look_target: bool = false

# Bone indices (cached for performance)
var head_bone_idx: int = -1
var neck_bone_idx: int = -1

# Available animations (configure these based on your model)
var available_animations: Dictionary = {
	"idle": "StandingIdle",
	"walk": "Walking",
	"sit": "SittingIdle",
	"dance": "Dance1",
	"macarena": "Macarena",
	"chickendance": "ChickenDance",
	"tennadance": "TennaDance",
	"breakdance1": "Breakdancing1",
	"tpose": "TPose",
}

func _ready():
	# Cache bone indices
	if skeleton and enable_head_tracking:
		head_bone_idx = skeleton.find_bone(head_bone_name)
		neck_bone_idx = skeleton.find_bone(neck_bone_name)
		
		if head_bone_idx == -1:
			push_warning("Head bone not found: ", head_bone_name)
			enable_head_tracking = false
	
	# Setup navigation
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.target_reached.connect(_on_navigation_complete)

func _physics_process(delta):
	# Handle movement
	if is_moving and navigation_agent and not navigation_agent.is_navigation_finished():
		var next_position = navigation_agent.get_next_path_position()
		var direction = (next_position - npc_body.global_position).normalized()
		
		# Rotate NPC to face direction
		var target_rotation = atan2(direction.x, direction.z)
		npc_body.rotation.y = lerp_angle(npc_body.rotation.y, target_rotation, turn_speed * delta)
		
		# Move
		var velocity = direction * walk_speed
		navigation_agent.set_velocity(velocity)
	
	# Handle head tracking
	if enable_head_tracking and has_look_target and head_bone_idx != -1:
		_update_head_tracking(delta)

func _on_velocity_computed(safe_velocity: Vector3):
	if npc_body:
		npc_body.velocity = safe_velocity
		npc_body.move_and_slide()

func _on_navigation_complete():
	stop_moving()
	navigation_complete.emit()

# ============ ANIMATION CONTROL ============

## Play an animation by name (maps to LLM-friendly names)
func play_animation(anim_name: String) -> bool:
	if not animation_player:
		push_warning("No AnimationPlayer assigned")
		return false
	
	var actual_anim = available_animations.get(anim_name.to_lower(), "")
	
	if actual_anim == "":
		push_warning("Animation not found: ", anim_name)
		return false
	
	if not animation_player.has_animation(actual_anim):
		push_warning("AnimationPlayer doesn't have animation: ", actual_anim)
		return false
	
	current_animation = anim_name
	animation_player.play(actual_anim)
	action_started.emit(anim_name)
	
	# Auto-emit completion when animation finishes
	await animation_player.animation_finished
	action_completed.emit(anim_name)
	
	return true

## Get list of available animations for LLM context
func get_available_animations() -> Array:
	return available_animations.keys()

# ============ NAVIGATION CONTROL ============

## Move to a specific position
func move_to_position(target_pos: Vector3) -> void:
	if not navigation_agent:
		push_warning("No NavigationAgent3D assigned")
		return
	
	navigation_agent.target_position = target_pos
	is_moving = true
	
	# Auto-play walk animation
	if current_animation != "walk":
		play_animation("walk")

## Move to a named location (looks up in scene)
func move_to_location(location_name: String) -> bool:
	var target = get_tree().root.find_child(location_name, true, false)
	
	if not target:
		push_warning("Location not found: ", location_name)
		return false
	
	if target is Node3D:
		move_to_position(target.global_position)
		return true
	
	return false

## Stop moving and return to idle
func stop_moving() -> void:
	is_moving = false
	
	if current_animation == "walk":
		play_animation("idle")

# ============ HEAD TRACKING ============

## Look at a specific world position
func look_at_position(world_pos: Vector3) -> void:
	look_target = world_pos
	has_look_target = true

## Look at a node (player, object, etc)
func look_at_node(target_node: Node3D) -> void:
	if target_node:
		look_at_position(target_node.global_position)

## Stop looking at target (return to neutral)
func stop_looking() -> void:
	has_look_target = false

func _update_head_tracking(delta: float) -> void:
	if not skeleton or head_bone_idx == -1:
		return
	
	# Get head bone's global transform
	var head_global = skeleton.global_transform * skeleton.get_bone_global_pose(head_bone_idx)
	var head_pos = head_global.origin
	
	# Calculate direction to target
	var to_target = (look_target - head_pos).normalized()
	
	# Convert to local space of the head bone
	var head_local_transform = skeleton.get_bone_pose(head_bone_idx)
	var forward = -head_local_transform.basis.z  # Assuming -Z is forward
	
	# Calculate angle to target
	var angle = forward.signed_angle_to(to_target, Vector3.UP)
	angle = clamp(angle, deg_to_rad(-max_head_angle), deg_to_rad(max_head_angle))
	
	# Apply rotation smoothly
	var target_rotation = Quaternion(Vector3.UP, angle)
	var current_rotation = head_local_transform.basis.get_rotation_quaternion()
	var new_rotation = current_rotation.slerp(target_rotation, head_track_speed * delta)
	
	# Set the bone rotation
	head_local_transform.basis = Basis(new_rotation)
	skeleton.set_bone_pose(head_bone_idx, head_local_transform)

# ============ LLM ACTION PARSING ============

## Parse and execute an action from LLM output
## Expected format: {"action": "walk", "target": "Kitchen", "animation": "idle"}
func execute_action(action_dict: Dictionary) -> bool:
	var action_type = action_dict.get("action", "")
	
	match action_type:
		"walk_to", "move_to":
			var target = action_dict.get("target", "")
			if target == "":
				return false
			
			# Try to find as named location first
			if move_to_location(target):
				return true
			
			# Try to parse as Vector3
			if target is Vector3:
				move_to_position(target)
				return true
			
			return false
		
		"animate", "play_animation":
			var anim = action_dict.get("animation", action_dict.get("name", ""))
			return await play_animation(anim)
		
		"look_at":
			var target = action_dict.get("target", null)
			
			if target is String:
				var node = get_tree().root.find_child(target, true, false)
				if node and node is Node3D:
					look_at_node(node)
					return true
			elif target is Node3D:
				look_at_node(target)
				return true
			elif target is Vector3:
				look_at_position(target)
				return true
			
			return false
		
		"stop_looking":
			stop_looking()
			return true
		
		"stop_moving":
			stop_moving()
			return true
		
		_:
			push_warning("Unknown action: ", action_type)
			return false

# ============ UTILITY FUNCTIONS ============

## Get current state for LLM context
func get_state_description() -> String:
	var state = ""
	
	if is_moving:
		state += "Currently walking. "
	else:
		state += "Standing still. "
	
	state += "Playing animation: " + current_animation + ". "
	
	if has_look_target:
		state += "Looking at something. "
	
	return state

## Get available actions for LLM system prompt
func get_available_actions_description() -> String:
	return """
Available Actions:
- walk_to(target): Walk to a location (e.g., "Kitchen", "Player")
- play_animation(name): Play animation (%s)
- look_at(target): Look at something (e.g., "Player", position)
- stop_looking(): Return head to neutral
- stop_moving(): Stop walking
""" % [", ".join(get_available_animations())]
