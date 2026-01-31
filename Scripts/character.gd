extends CharacterBody3D

# Movement settings
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

# Physics
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# References - add these as child nodes
@onready var head = $Head
@onready var camera = $Head/Camera3D

# Cached autoload references
var ai_settings_menu: CanvasLayer = null

func _ready():
	# Capture mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	add_to_group("player")
	
	# Ensure gravity has a default if not set
	if gravity == 0.0:
		gravity = 9.8
	
	# Cache the AISettingsMenu reference if it exists
	ai_settings_menu = get_node_or_null("/root/AISettingsMenu")

func _is_menu_open() -> bool:
	# Check if settings menu is open
	if ai_settings_menu and ai_settings_menu.visible:
		return true
	
	# Check if dialogue input is open (typing mode)
	if DialogueUI and DialogueUI.has_method("is_input_open") and DialogueUI.is_input_open():
		return true
	
	return false

func _input(event):
	# Only block input if settings menu is open or typing in dialogue
	if _is_menu_open():
		return
	
	# Press Tab to open AI Settings
	if event.is_action_pressed("OpenMenu"):
		if ai_settings_menu and ai_settings_menu.has_method("show_menu"):
			ai_settings_menu.show_menu()
		get_viewport().set_input_as_handled()
		return
	
	# Press Enter to talk to the NPC (just opens input, doesn't lock player)
	if event.is_action_pressed("StartTalking"):
		attempt_dialogue()
		get_viewport().set_input_as_handled()
		return
	
	# Mouse look (disabled when typing in dialogue input)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -deg_to_rad(89), deg_to_rad(89))

func _physics_process(delta: float):
	# Pause movement if settings menu is open OR typing in dialogue input
	# But ONLY horizontal movement - gravity still applies!
	var movement_blocked = _is_menu_open()
	
	# Add gravity (always applies, even when blocked)
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump (only if not blocked)
	if not movement_blocked and Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction (only if not blocked)
	var input_dir: Vector2 = Vector2.ZERO
	if not movement_blocked:
		input_dir = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	
	# Calculate movement direction relative to where player is looking
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply speed (sprint if shift is held)
	var speed: float = walk_speed
	if not movement_blocked and Input.is_action_pressed("Sprint"):
		speed = sprint_speed
	
	# Move (or stop horizontal movement if blocked)
	if direction and not movement_blocked:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# Stop horizontal movement, but keep Y velocity (gravity/jump)
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	
func attempt_dialogue():
	# Don't start new dialogue if AI is busy responding
	if DialogueUI and DialogueUI.has_method("is_busy") and DialogueUI.is_busy():
		print("AI is still responding, please wait...")
		return
	
	# Don't start new dialogue if conversation is still active (text still visible)
	if DialogueUI and DialogueUI.has_method("has_active_conversation") and DialogueUI.has_active_conversation():
		print("Please wait for current conversation to close...")
		return
	
	# Get the NPC in the scene
	var npc = NPCManager.get_current_npc()
	
	if npc:
		npc.start_conversation()
	else:
		print("No NPC found in scene")

func _unhandled_input(event):
	# Press ESC to free mouse cursor (for menus)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
