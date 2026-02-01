extends Node
class_name NPCActionController

## ULTRA-SAFE VERSION - Minimal bone manipulation to avoid skeleton corruption

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

# Head tracking settings - DISABLED BY DEFAULT until we fix it
@export var enable_head_tracking: bool = false  # SET TO FALSE - TOO BUGGY
@export var head_track_speed: float = 3.0

# Animation settings
@export var enable_walk_speed_scaling: bool = true
@export var min_speed_scale: float = 0.5
@export var max_speed_scale: float = 2.0

# Current state
var current_animation: String = "idle"
var is_moving: bool = false
var desired_velocity: Vector3 = Vector3.ZERO
var using_animation_tree: bool = false

# Head tracking (DISABLED)
var look_target_node: Node3D = null
var is_looking: bool = false

# Bone indices
var head_bone_idx: int = -1

# Animation state
var is_animation_playing: bool = false

# Available animations
var available_animations: Dictionary = {
	"idle": "Idle",
	"walk": "Walk",
	"sit": "Sit",
	"dance": "Dance",
	"breakdance": "Breakdance",
	"breakdance1": "Breakdance",
	"chickendance": "ChickenDance",
	"macarena": "Macarena",
	"tennadance": "TennaDance",
}

func _ready():
	# Cache bone index (but don't use it for now)
	if skeleton:
		head_bone_idx = skeleton.find_bone(head_bone_name)
		if head_bone_idx != -1:
			print("[NPCActionController] Head bone found (tracking DISABLED due to bugs)")
	
	# Setup navigation
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.target_reached.connect(_on_navigation_complete)
	
	# Setup AnimationTree
	if animation_tree:
		animation_tree.active = true
		using_animation_tree = true
		
		var state_machine = animation_tree.get("parameters/playback")
		if state_machine:
			state_machine.travel("Idle")
			current_animation = "idle"
		
		print("[NPCActionController] Using AnimationTree (with blending)")
	elif animation_player:
		using_animation_tree = false
		print("[NPCActionController] Using AnimationPlayer (no blending)")

func _physics_process(delta):
	# Movement
	if is_moving and navigation_agent:
		if navigation_agent.is_navigation_finished():
			_on_navigation_complete()
		else:
			var next_position = navigation_agent.get_next_path_position()
			var direction = (next_position - npc_body.global_position).normalized()
			
			var target_rotation = atan2(-direction.x, -direction.z)
			npc_body.rotation.y = lerp_angle(npc_body.rotation.y, target_rotation, turn_speed * delta)
			
			desired_velocity = direction * walk_speed
			navigation_agent.set_velocity(desired_velocity)
			
			if enable_walk_speed_scaling:
				_update_walk_animation_speed(desired_velocity.length())
	else:
		desired_velocity = Vector3.ZERO
		if enable_walk_speed_scaling:
			_update_walk_animation_speed(0.0)

func _on_velocity_computed(safe_velocity: Vector3):
	desired_velocity = safe_velocity

func get_movement_velocity() -> Vector3:
	return desired_velocity

func _on_navigation_complete():
	if not is_moving:
		return
	stop_moving()
	navigation_complete.emit()

# ============ ANIMATION CONTROL ============

func play_animation(anim_name: String) -> bool:
	if using_animation_tree and animation_tree:
		return _play_animation_with_tree(anim_name)
	elif animation_player:
		return _play_animation_with_player(anim_name)
	return false

func _play_animation_with_tree(anim_name: String) -> bool:
	var state_machine = animation_tree.get("parameters/playback")
	if not state_machine:
		return false
	
	var actual_anim = available_animations.get(anim_name.to_lower(), "")
	if actual_anim == "":
		return false
	
	if is_animation_playing and current_animation != anim_name:
		action_completed.emit(current_animation)
	
	current_animation = anim_name
	is_animation_playing = true
	
	# Disable the LookAtModifier3D's "SkeletonModifier3D"'s "Active" parameter
	if anim_name != "idle" or anim_name != "sitting" or anim_name != "walking":
		look_at_modifier_3d.active = false
	else:
		look_at_modifier_3d.active = true
		
	state_machine.travel(actual_anim)
	action_started.emit(anim_name)
	
	_wait_for_animation_finish(anim_name)
	return true

func _play_animation_with_player(anim_name: String) -> bool:
	var actual_anim = available_animations.get(anim_name.to_lower(), "")
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

func _wait_for_animation_finish(anim_name: String):
	if using_animation_tree:
		await get_tree().create_timer(2.0).timeout
	else:
		await animation_player.animation_finished
	
	if current_animation == anim_name:
		action_completed.emit(anim_name)
		is_animation_playing = false

func stop_animation():
	if is_animation_playing:
		action_completed.emit(current_animation)
		is_animation_playing = false
	play_animation("idle")
	# Supposed to re-enable the "Active" parameter of SkeletonModifier3D but probably not working
	look_at_modifier_3d.active = true

func get_available_animations() -> Array:
	return available_animations.keys()

func _update_walk_animation_speed(current_speed: float):
	if current_animation != "walk":
		return
	
	var speed_scale = 1.0
	if walk_speed > 0:
		speed_scale = current_speed / walk_speed
		speed_scale = clamp(speed_scale, min_speed_scale, max_speed_scale)
	
	if using_animation_tree and animation_tree:
		animation_tree.set("parameters/Walking/scale", speed_scale)
	elif animation_player:
		animation_player.speed_scale = speed_scale

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
	
	if current_animation != "walk":
		play_animation("walk")

func move_to_location(location_name: String) -> bool:
	print("[NPCActionController] 🔍 Looking for location: '", location_name, "'")
	
	var target = get_tree().root.find_child(location_name, true, false)
	
	if not target:
		push_error("[NPCActionController] ❌ Location NOT FOUND: '", location_name, "'")
		print("[NPCActionController] Available room nodes:")
		_debug_print_room_nodes()
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
	
	if current_animation == "walk":
		play_animation("idle")

# ============ HEAD TRACKING (DISABLED) ============

## Look at a node - DISABLED, just prints warning
func look_at_node(target_node: Node3D) -> void:
	print("[NPCActionController] Head tracking is disabled (causes visual bugs)")
	print("[NPCActionController] Bone manipulation needs more work")

## Look at a position - DISABLED
func look_at_position(world_pos: Vector3) -> void:
	print("[NPCActionController] Head tracking is disabled (causes visual bugs)")

## Stop looking - DISABLED
func stop_looking() -> void:
	print("[NPCActionController] Head tracking is disabled")

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
		state += "Currently walking. "
	else:
		state += "Standing still. "
	state += "Playing animation: " + current_animation + ". "
	return state

func get_available_actions_description() -> String:
	return """
Available Actions:
- walk_to(target): Walk to a location
- play_animation(name): Play animation (%s)
- stop_moving(): Stop walking
- stop_animation(): Stop current animation
(Note: Head tracking currently disabled due to technical issues)
""" % [", ".join(get_available_animations())]
