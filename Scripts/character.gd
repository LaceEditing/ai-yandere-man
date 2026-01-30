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
	# Check if dialogue is open
	if DialogueUI and DialogueUI.visible:
		return true
	# Check if settings menu is open
	if ai_settings_menu and ai_settings_menu.visible:
		return true
	return false

func _input(event):
	# Don't process input if any menu is open
	if _is_menu_open():
		return
	
	# Press Tab to open AI Settings
	if event.is_action_pressed("OpenMenu"):
		if ai_settings_menu and ai_settings_menu.has_method("show_menu"):
			ai_settings_menu.show_menu()
		get_viewport().set_input_as_handled()
		return
	
	# Press Enter to talk to the NPC
	if event.is_action_pressed("StartTalking"):
		attempt_dialogue()
		get_viewport().set_input_as_handled()
		return
	
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -deg_to_rad(89), deg_to_rad(89))

func _physics_process(delta: float):
	# Don't process movement during menus
	if _is_menu_open():
		velocity = Vector3.ZERO
		return
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir: Vector2 = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	
	# Calculate movement direction relative to where player is looking
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply speed (sprint if shift is held)
	var speed: float = walk_speed
	if Input.is_action_pressed("Sprint"):
		speed = sprint_speed
	
	# Move
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	
func attempt_dialogue():
	# Don't start new dialogue if any menu is open
	if _is_menu_open():
		return
	
	# Get the NPC in the scene
	var npc = NPCManager.get_current_npc()
	
	if npc:
		npc.start_conversation()
	else:
		print("No NPC found in scene")

func _unhandled_input(event):
	# Press ESC to free mouse cursor
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
