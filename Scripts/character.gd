extends CharacterBody3D

# Movement settings
@export var walk_speed = 5.0
@export var sprint_speed = 8.0
@export var jump_velocity = 4.5
@export var mouse_sensitivity = 0.002

# Physics
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# References - add these as child nodes
@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready():
	# Capture mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	add_to_group("player")

func _input(event):
	# Don't process mouse look if dialogue is open
	if DialogueUI and DialogueUI.visible:
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

func _physics_process(delta):
	# Don't process movement during dialogue
	if DialogueUI and DialogueUI.visible:
		velocity = Vector3.ZERO
		return
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	
	# Calculate movement direction relative to where player is looking
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply speed (sprint if shift is held)
	var speed = sprint_speed if Input.is_action_pressed("Sprint") else walk_speed
	
	# Move
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
func attempt_dialogue():
	# Don't start new dialogue if already talking
	if DialogueUI and DialogueUI.visible:
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
