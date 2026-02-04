extends Node
class_name NPCActionController

signal action_started(action_name: String)
signal action_completed(action_name: String)
signal navigation_complete()

@export var npc_body: CharacterBody3D
@export var animation_player: AnimationPlayer
@export var animation_tree: AnimationTree
@export var navigation_agent: NavigationAgent3D
@export var skeleton: Skeleton3D
@export var head_bone_name: String = "mixamorig_Head"
@export var look_at_modifier_3d: LookAtModifier3D


# Movement settings
@export var walk_speed: float = 2.0
@export var turn_speed: float = 5.0

# Turn-to-face player settings
@export_group("Turn To Face Player")
@export var enable_turn_to_player: bool = true  ## Automatically turn to face player
@export_range(45.0, 120.0, 5.0, "suffix:degrees") var head_angle_threshold: float = 70.0  ## Turn body if player is beyond this angle
@export_range(0.1, 10.0, 0.1) var face_player_turn_speed: float = 3.0  ## Speed when turning to player
@export var use_turn_animations: bool = true  ## Use turn-in-place animations if available

# Head tracking settings - DISABLED BY DEFAULT until we fix it
@export var enable_head_tracking: bool = false  # SET TO FALSE - TOO BUGGY
@export var head_track_speed: float = 3.0

# Animation settings
@export var enable_walk_speed_scaling: bool = true
@export var min_speed_scale: float = 0.5
@export var max_speed_scale: float = 2.0
@export var blend_transition_speed: float = 5.0  ## How fast animations blend (higher = faster)
@export var movement_blend_speed: float = 8.0  ## How fast idle/walk blends with movement
var blend_params := {}

# Current state
var current_animation: String = "idle"
var is_moving: bool = false
var is_truly_idle: bool = true  # Track if we're actually standing still
var is_crouching: bool = false  # Track crouch state for transitions
var desired_velocity: Vector3 = Vector3.ZERO
var using_animation_tree: bool = false
var current_movement_speed: float = 0.0  # Actual movement speed for blend

# Blend state tracking
var current_blend_values: Dictionary = {}  # Current blend amounts
var target_blend_values: Dictionary = {}   # Target blend amounts

# Head tracking
var look_target_node: Node3D = null
var is_looking: bool = false

# Bone indices
var head_bone_idx: int = -1

# Animation state
var is_animation_playing: bool = false

# Turn-to-face state
var is_turning_to_player: bool = false
var player_node: Node3D = null
var is_in_conversation: bool = false
var current_turn_animation: String = ""
var has_turn_animations: bool = false
var is_forced_running: bool = false  # Force run animation (e.g., during hostile chase)

# Anim blend map - maps action names to AnimationTree blend node names
const AVAILABLE_ANIMATIONS: Dictionary = {
	"idle": "Idle",
	"walk": "Walk",
	"run": "Running",
	"crouch": "Crouching",
	"crouchwalk": "CrouchWalking",
	"sit": "Sit",
	"dance": "Dance",
	"macarena": "DanceMacarena",
	"chicken": "DanceChicken",
	"tenna": "DanceTenna",
	"break": "DanceBreak",
	"turnleft": "TurnLeft",
	"turnright": "TurnRight"
}

# Crouch state - for managing crouch transitions
const CROUCH_ANIMS := ["crouch", "crouchwalk"]
const STANDING_ANIMS := ["idle", "walk", "run", "sit", "dance", "macarena", "chicken", "tenna", "break"]

const ANIM_LENGTH := {
	"idle": 0.0,
	"walk": 0.0,
	"run": 0.0,
	"crouch": 0.0,
	"crouchwalk": 0.0,
	"sit": 0.0,
	"dance": 3.0,
	"macarena": 4.0,
	"chicken": 4.0,
	"tenna": 4.0,
	"break": 5.0
}


const HEAD_TRACK_ALLOWED_ANIMS := ["idle", "walk", "run", "crouch", "crouchwalk", "sit"]

func _match_animation_name(input: String) -> String:
	"""Fuzzy match animation names to handle variations"""
	var normalized = input.to_lower().strip_edges()
	
	# Direct match
	if AVAILABLE_ANIMATIONS.has(normalized):
		return normalized
	
	# Try partial matches
	if "break" in normalized or "breakdance" in normalized:
		return "break"
	if "macarena" in normalized:
		return "macarena"
	if "chicken" in normalized:
		return "chicken"
	if "tenna" in normalized:
		return "tenna"
	if "crouchwalk" in normalized or "crouch_walk" in normalized or "sneakwalk" in normalized:
		return "crouchwalk"
	if "crouch" in normalized or "sneak" in normalized or "duck" in normalized:
		return "crouch"
	if "run" in normalized or "sprint" in normalized or "jog" in normalized:
		return "run"
	if "dance" in normalized:
		return "dance"
	if "sit" in normalized:
		return "sit"
	if "walk" in normalized:
		return "walk"
	if "idle" in normalized or "stand" in normalized:
		return "idle"
	
	return ""  # No match

func _ready():
	# Detect if we should use AnimationTree or AnimationPlayer
	if animation_tree:
		animation_tree.active = true
		using_animation_tree = true
		print("[NPCActionController] Using AnimationTree for blend-based animations")
		
		for key in AVAILABLE_ANIMATIONS.values():
			blend_params[key] = "parameters/%s/blend_amount" % key
		
		# Debug: Print what parameters are available
		_debug_print_animation_tree_params()
		
		# Set Walk as default (used for both idle and walking)
		_set_active_blend("Walk", 1.0)
	elif animation_player:
		using_animation_tree = false
		print("[NPCActionController] Using AnimationPlayer for direct animations")
	else:
		push_error("[NPCActionController] No AnimationTree or AnimationPlayer found!")
	
	# Setup navigation
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.target_reached.connect(_on_navigation_complete)
	
	# Initialize blend state tracking
	if using_animation_tree:
		for blend_node in blend_params.keys():
			current_blend_values[blend_node] = 0.0
			target_blend_values[blend_node] = 0.0
		# Set Idle as default
		target_blend_values["Idle"] = 1.0
		is_truly_idle = true
		
		# Check if turn animations are available
		if animation_tree.get("parameters/TurnLeft/blend_amount") != null and animation_tree.get("parameters/TurnRight/blend_amount") != null:
			has_turn_animations = true
			print("[NPCActionController] Turn animations detected and enabled")
		else:
			has_turn_animations = false
			print("[NPCActionController] Turn animations not found - using rotation only")
	
	# Get player reference
	player_node = get_tree().get_first_node_in_group("player")

func _process(delta):
	# Smoothly interpolate blend amounts for AnimationTree
	if using_animation_tree and animation_tree:
		for blend_node in blend_params.keys():
			var current = current_blend_values.get(blend_node, 0.0)
			var target = target_blend_values.get(blend_node, 0.0)
			
			# Lerp towards target
			var new_value = lerp(current, target, blend_transition_speed * delta)
			current_blend_values[blend_node] = new_value
			
			# Apply to AnimationTree
			var param_path = blend_params[blend_node]
			if animation_tree.get(param_path) != null:
				animation_tree.set(param_path, new_value)

func _debug_print_animation_tree_params():
	"""Debug helper to see what parameters actually exist in the AnimationTree"""
	if not animation_tree:
		return
	
	print("[NPCActionController] === AnimationTree Parameters ===")
	for anim_name in AVAILABLE_ANIMATIONS.values():
		var param_path = "parameters/%s/blend_amount" % anim_name
		# Try to get the parameter - will return null if it doesn't exist
		var param_value = animation_tree.get(param_path)
		if param_value != null:
			print("[NPCActionController]   ✓ ", param_path, " EXISTS (current: ", param_value, ")")
		else:
			print("[NPCActionController]   ✗ ", param_path, " NOT FOUND")
	print("[NPCActionController] =================================")

func _physics_process(delta):
	# Get gravity from project settings
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	
	# Calculate actual movement speed from body velocity (horizontal only for animation)
	if npc_body:
		var horizontal_velocity = Vector3(npc_body.velocity.x, 0, npc_body.velocity.z)
		var target_speed = horizontal_velocity.length()
		
		# Smooth the speed value
		current_movement_speed = lerp(current_movement_speed, target_speed, movement_blend_speed * delta)
		
		# Always update movement blend when using movement animations
		if using_animation_tree and (current_animation == "idle" or current_animation == "walk" or current_animation == "run"):
			_update_movement_blend()
	
	# Turn to face player when idle/in conversation (but not during special animations or movement)
	if enable_turn_to_player and not is_moving and current_animation in HEAD_TRACK_ALLOWED_ANIMS:
		_update_turn_to_player(delta)
	
	# Movement
	if is_moving and navigation_agent:
		if navigation_agent.is_navigation_finished():
			_on_navigation_complete()
		else:
			var next_position = navigation_agent.get_next_path_position()
			var direction = (next_position - npc_body.global_position)
			
			# Use horizontal direction for movement, let gravity handle Y
			direction.y = 0
			if direction.length() > 0.01:
				direction = direction.normalized()
			
			var target_rotation = atan2(-direction.x, -direction.z)
			npc_body.rotation.y = lerp_angle(npc_body.rotation.y, target_rotation, turn_speed * delta)
			
			# Set horizontal velocity
			desired_velocity = direction * walk_speed
			navigation_agent.set_velocity(desired_velocity)
			
			# Apply horizontal movement + gravity
			npc_body.velocity.x = desired_velocity.x
			npc_body.velocity.z = desired_velocity.z
			if not npc_body.is_on_floor():
				npc_body.velocity.y -= gravity * delta
			else:
				npc_body.velocity.y = 0
			
			npc_body.move_and_slide()
	else:
		desired_velocity = Vector3.ZERO
		if npc_body:
			# Still apply gravity when not moving
			npc_body.velocity.x = 0
			npc_body.velocity.z = 0
			if not npc_body.is_on_floor():
				npc_body.velocity.y -= gravity * delta
			else:
				npc_body.velocity.y = 0
			npc_body.move_and_slide()

func _on_velocity_computed(safe_velocity: Vector3):
	desired_velocity = safe_velocity

func get_movement_velocity() -> Vector3:
	return desired_velocity

func _on_navigation_complete():
	if not is_moving:
		return
	stop_moving()
	navigation_complete.emit()


## ============ TURN TO FACE PLAYER ============

func set_conversation_state(talking: bool):
	"""Called by NPCBase when conversation starts/ends"""
	is_in_conversation = talking

func _update_turn_to_player(delta: float):
	"""Turn body to face player when they're to the side/behind"""
	if not player_node or is_moving:
		return
	
	var angle = _get_angle_to_player()
	var abs_angle = abs(angle)
	
	# Start turning if beyond threshold, keep turning until nearly facing (within 5°)
	var should_turn = is_turning_to_player or abs_angle > deg_to_rad(head_angle_threshold)
	var close_enough = abs_angle < deg_to_rad(5.0)
	
	if should_turn and not close_enough:
		# Add subtle walk blend for foot shuffle during turn
		if using_animation_tree and animation_tree:
			target_blend_values["Idle"] = 0.87  # Keep mostly idle
			target_blend_values["Walk"] = 0.13  # Add subtle walk for feet
			# Turn off everything else
			for blend_name in blend_params.keys():
				if blend_name != "Idle" and blend_name != "Walk":
					target_blend_values[blend_name] = 0.0
			
			# Blend into walk faster during turn
			current_blend_values["Walk"] = lerp(current_blend_values["Walk"], target_blend_values["Walk"], blend_transition_speed * 2.5 * delta)
			current_blend_values["Idle"] = lerp(current_blend_values["Idle"], target_blend_values["Idle"], blend_transition_speed * 2.5 * delta)
		
		_turn_toward_player(delta)
		if not is_turning_to_player:
			print("[NPCActionController] Player at ", rad_to_deg(abs_angle), "° - turning with subtle foot shuffle")
			is_turning_to_player = true
	else:
		if is_turning_to_player and close_enough:
			print("[NPCActionController] Turn complete (within 5°)")
			# Return to full idle quickly
			if using_animation_tree:
				target_blend_values["Idle"] = 1.0
				target_blend_values["Walk"] = 0.0
				# Force faster blend back to idle
				current_blend_values["Walk"] = lerp(current_blend_values["Walk"], 0.0, blend_transition_speed * 2.0 * delta)
		is_turning_to_player = false

func _get_angle_to_player() -> float:
	"""Get angle from NPC forward to player (positive = right, negative = left)"""
	if not player_node or not npc_body:
		return 0.0
	
	var to_player = (player_node.global_position - npc_body.global_position).normalized()
	to_player.y = 0  # Ignore vertical
	
	var forward = -npc_body.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	# Get signed angle
	var dot = forward.dot(to_player)
	var cross = forward.cross(to_player).y
	return atan2(cross, dot)

func _turn_toward_player(delta: float):
	"""Smoothly rotate body to face player"""
	if not player_node or not npc_body:
		return
	
	var direction = (player_node.global_position - npc_body.global_position)
	direction.y = 0
	
	if direction.length() < 0.01:
		return
	
	direction = direction.normalized()
	var target_rotation = atan2(-direction.x, -direction.z)
	npc_body.rotation.y = lerp_angle(npc_body.rotation.y, target_rotation, face_player_turn_speed * delta)

# ============ ANIMATION CONTROL ============

func play_animation(anim_name: String) -> bool:
	if using_animation_tree and animation_tree:
		return _play_animation_with_tree(anim_name)
	elif animation_player:
		return _play_animation_with_player(anim_name)
	return false


func _validate_crouch_transition(target_key: String) -> String:
	"""Validate and potentially modify animation based on crouch state.
	Returns the animation to actually play (may differ from requested)."""
	
	var target_is_crouch = target_key in CROUCH_ANIMS
	var target_is_standing = target_key in STANDING_ANIMS
	
	# Rule 1: Can only crouchwalk if already crouching
	if target_key == "crouchwalk" and not is_crouching:
		print("[NPCActionController] 🚫 Can't crouchwalk - not crouching. Crouching first.")
		return "crouch"  # Crouch first instead
	
	# Rule 2: Must go to crouch idle before standing
	if is_crouching and target_is_standing and target_key != "idle":
		# If crouching and trying to do standing anim (walk, run, dance, etc.)
		# First need to stand up (go to idle)
		print("[NPCActionController] 🚫 Can't ", target_key, " while crouching. Standing up first.")
		return "idle"  # Stand up first
	
	# Rule 3: Transition from crouchwalk should go to crouch idle, not standing
	if current_animation == "crouchwalk" and target_is_standing:
		print("[NPCActionController] 🚫 Transitioning from crouchwalk to crouch first.")
		return "crouch"
	
	return target_key  # No modification needed


func _play_animation_with_tree(anim_name: String) -> bool:
	var key := _match_animation_name(anim_name)
	
	if key == "":
		push_error("[NPCActionController] ❌ Unknown animation: '", anim_name, "' (available: ", AVAILABLE_ANIMATIONS.keys(), ")")
		return false
	
	if not AVAILABLE_ANIMATIONS.has(key):
		push_error("[NPCActionController] ❌ Animation '", key, "' not in mapping")
		return false
	
	# Validate crouch state transitions
	var validated_key = _validate_crouch_transition(key)
	if validated_key != key:
		print("[NPCActionController] 📍 Animation redirected: ", key, " -> ", validated_key)
		key = validated_key
	
	if is_animation_playing and current_animation != key:
		action_completed.emit(current_animation)
	
	current_animation = key  # Use the matched key
	is_animation_playing = true
	
	# Update crouch state
	is_crouching = key in CROUCH_ANIMS
	
	# Track if we're truly idle (for walk blend control)
	is_truly_idle = (key == "idle" or key == "crouch")
	
	# Head tracking
	look_at_modifier_3d.active = key in HEAD_TRACK_ALLOWED_ANIMS
	
	# For idle/walk/run, let the movement system handle blending (unless forced running)
	if key == "idle" or key == "walk" or (key == "run" and not is_forced_running):
		# Don't force a specific blend - let _update_movement_blend handle it
		# But do turn off other animations
		for blend_name in blend_params.keys():
			if blend_name != "Idle" and blend_name != "Walk" and blend_name != "Running":
				target_blend_values[blend_name] = 0.0
		print("[NPCActionController] 🎬 Movement mode: '", key, "' (speed-controlled blend)")
	elif key == "run" and is_forced_running:
		# Force running animation (hostile chase)
		target_blend_values["Idle"] = 0.0
		target_blend_values["Walk"] = 0.0
		target_blend_values["Running"] = 1.0
		# Turn off other animations
		for blend_name in blend_params.keys():
			if blend_name != "Running":
				target_blend_values[blend_name] = 0.0
		print("[NPCActionController] 🎬 FORCED RUN MODE (hostile chase)")
	elif key == "turnleft" or key == "turnright":
		# Turn animations: keep idle active for upper body, blend turn for lower body
		var blend_node = AVAILABLE_ANIMATIONS[key]
		print("[NPCActionController] 🎬 Playing turn: '", key, "' (blended with idle)")
		for blend_name in blend_params.keys():
			if blend_name == "Idle":
				target_blend_values[blend_name] = 0.5  # Keep idle at 50% for upper body
			elif blend_name == blend_node:
				target_blend_values[blend_name] = 0.5  # Turn animation at 50%
			else:
				target_blend_values[blend_name] = 0.0
	else:
		# For other animations, set the appropriate blend node
		var blend_node = AVAILABLE_ANIMATIONS[key]
		print("[NPCActionController] 🎬 Playing: '", anim_name, "' -> '", key, "' -> blend: ", blend_node, " (crouching: ", is_crouching, ")")
		_set_active_blend(blend_node)
	
	action_started.emit(key)
	_wait_for_animation_finish(key)
	return true

func _set_active_blend(active: String, value := 1.0):
	if not animation_tree or not using_animation_tree:
		return
	
	# Set all target blend amounts to 0
	for blend_name in blend_params.keys():
		target_blend_values[blend_name] = 0.0
	
	# Set active animation target to specified value
	if blend_params.has(active):
		target_blend_values[active] = value
		print("[NPCActionController] 🎯 Target blend: ", active, " = ", value)
	else:
		push_error("[NPCActionController] ✗ No blend node for: ", active)


func _play_animation_with_player(anim_name: String) -> bool:
	var actual_anim = AVAILABLE_ANIMATIONS.get(anim_name.to_lower(), "")
	if actual_anim == "" or not animation_player.has_animation(actual_anim):
		return false
	
	if is_animation_playing and current_animation != anim_name:
		action_completed.emit(current_animation)
	
	current_animation = anim_name
	is_animation_playing = true
	animation_player.play(actual_anim)
	action_started.emit(anim_name)
	_wait_for_animation_finish(anim_name)
	return true

func _wait_for_animation_finish(anim_name: String) -> void:
	var key: String = anim_name.to_lower()
	
	# Looping / persistent animations never "finish"
	if not ANIM_LENGTH.has(key):
		return
	
	var duration: float = ANIM_LENGTH[key]
	if duration <= 0.0:
		return
	
	# Wait for the gameplay-defined duration
	await get_tree().create_timer(duration).timeout
	
	# Make sure we didn't switch animations mid-wait
	if current_animation != anim_name:
		return
	
	is_animation_playing = false
	action_completed.emit(anim_name)


func stop_animation():
	if is_animation_playing:
		action_completed.emit(current_animation)
		is_animation_playing = false
	
	play_animation("idle")
	look_at_modifier_3d.active = true

func get_available_animations() -> Array:
	return AVAILABLE_ANIMATIONS.keys()


func _update_movement_blend():
	"""Update walk/idle/run blend based on actual movement speed.
	This creates smooth transitions between standing, walking, and running."""
	if not animation_tree or not using_animation_tree:
		return
	
	# Don't override forced running state
	if is_forced_running:
		return
	
	# Use fixed thresholds for animation states (not relative to walk_speed)
	# This way changing walk_speed doesn't affect which animation plays
	var speed = current_movement_speed
	
	# Determine animation state based on absolute speed
	if speed > 2.8:  # Running (fast movement) - lowered from 3.0
		# Transition to running
		target_blend_values["Idle"] = 0.0
		target_blend_values["Walk"] = 0.0
		target_blend_values["Running"] = 1.0
		current_animation = "run"
		is_truly_idle = false
	elif speed > 0.2:  # Walking (slow to medium movement)
		# Blend between idle and walk based on speed
		var walk_blend = clamp(speed / 2.0, 0.0, 1.0)
		target_blend_values["Idle"] = 1.0 - walk_blend
		target_blend_values["Walk"] = walk_blend
		target_blend_values["Running"] = 0.0
		current_animation = "walk"
		is_truly_idle = false
	else:  # Idle (stationary)
		target_blend_values["Idle"] = 1.0
		target_blend_values["Walk"] = 0.0
		target_blend_values["Running"] = 0.0
		current_animation = "idle"
		is_truly_idle = true


# ============ NAVIGATION ============

func move_to_position(target_pos: Vector3) -> void:
	if not navigation_agent:
		push_error("[NPCActionController] ❌ No NavigationAgent assigned!")
		return
	
	print("[NPCActionController] 🎯 Setting navigation target: ", target_pos)
	print("[NPCActionController] 📍 Current position: ", npc_body.global_position)
	print("[NPCActionController] 📏 Distance: ", npc_body.global_position.distance_to(target_pos), " units")
	
	navigation_agent.target_position = target_pos
	is_moving = true
	
	# Wait a frame for navigation to compute path
	await get_tree().process_frame
	
	# Check if path is reachable
	if navigation_agent.is_navigation_finished():
		push_warning("[NPCActionController] ⚠️  Navigation FAILED - can't reach target!")
		push_warning("[NPCActionController] → NavigationRegion3D may not cover this area")
		push_warning("[NPCActionController] → Check that navigation mesh (blue overlay) reaches the target")
	else:
		var path = navigation_agent.get_current_navigation_path()
		print("[NPCActionController] ✅ Navigation path valid (", path.size(), " waypoints)")
	
	# Set to walk mode - the movement blend will handle animation based on speed
	current_animation = "walk"
	is_truly_idle = false
	# Turn off any other animations so walk/idle can blend
	for name in blend_params.keys():
		if name != "Idle" and name != "Walk":
			target_blend_values[name] = 0.0


func move_to_location(location_name: String) -> bool:
	print("[NPCActionController] 🔍 Looking for location: '", location_name, "'")
	
	# First check if any rooms exist at all
	var available_rooms = RoomManager.get_available_room_names()
	if available_rooms.size() == 0:
		push_warning("[NPCActionController] ⚠️ No Room nodes in scene! Cannot navigate to '", location_name, "'")
		push_warning("[NPCActionController] 💡 To fix: Add Area3D nodes with Room.gd script and add to 'rooms' group")
		return false
	
	var target = RoomManager.get_room_node(location_name)
	
	if not target:
		push_warning("[NPCActionController] ❌ Location NOT FOUND: '", location_name, "' (available: ", available_rooms, ")")
		return false
	
	if not target is Node3D:
		push_error("[NPCActionController] ❌ Found '", location_name, "' but it's not a Node3D: ", target.get_class())
		return false
	
	print("[NPCActionController] ✅ Found '", location_name, "' at position: ", target.global_position)
	move_to_position(target.global_position)
	return true


# DEBUG: Print available room nodes
func _debug_print_room_nodes():
	var rooms = ["Kitchen", "Living Room", "Master Bedroom", "Hallway", "LivingRoom", "MasterBedroom"]
	for room_name in rooms:
		var node = get_tree().root.find_child(room_name, true, false)
		if node:
			print("  ✓ '", room_name, "' exists (", node.get_class(), ")")
		else:
			print("  ✗ '", room_name, "' NOT FOUND")

func stop_moving() -> void:
	is_moving = false
	desired_velocity = Vector3.ZERO
	if npc_body:
		npc_body.velocity = Vector3.ZERO
	
	# Set to idle mode - the movement blend will handle the smooth transition
	# since current_movement_speed will naturally decay to 0
	if current_animation == "walk":
		current_animation = "idle"
		is_truly_idle = true
		# Explicitly re-enable head tracking after walking
		look_at_modifier_3d.active = true
	
	print("[NPCActionController] 🛑 Stopped moving (blend will smooth to idle)")

# ============ ACTION EXECUTION ============

func execute_action(action_dict: Dictionary) -> bool:
	var action_type = action_dict.get("action", "")
	
	match action_type:
		"walk_to", "move_to":
			var target = action_dict.get("target", "")
			if target == "":
				return false
			if move_to_location(target):
				return true
			if target is Vector3:
				move_to_position(target)
				return true
			return false
		
		"animate", "play_animation":
			var anim = action_dict.get("animation", action_dict.get("name", ""))
			return play_animation(anim)
		
		"look_at":
			# Just acknowledge but don't do anything
			print("[NPCActionController] Look_at requested but head tracking is disabled")
			return true  # Return true so it doesn't fail
		
		"stop_looking":
			return true
		
		"stop_moving":
			stop_moving()
			return true
		
		"stop_animation":
			stop_animation()
			return true
		
		_:
			return false

func get_state_description() -> String:
	var state = ""
	if is_moving:
		if is_crouching:
			state += "Currently crouch-walking. "
		else:
			state += "Currently walking. "
	else:
		if is_crouching:
			state += "Crouching. "
		else:
			state += "Standing. "
	state += "Animation: " + current_animation + ". "
	return state


func is_currently_crouching() -> bool:
	return is_crouching


func get_available_actions_description() -> String:
	return """
Available Actions:
- walk_to(target): Walk to a location
- play_animation(name): Play animation (%s)
- stop_moving(): Stop walking
- stop_animation(): Stop current animation
(Note: Head tracking currently disabled due to technical issues)
""" % [", ".join(get_available_animations())]
