extends CanvasLayer

# UI References
@onready var npc_name_label = $PanelContainer/MarginContainer/VBoxContainer/NPCNameLabel
@onready var dialogue_text = $PanelContainer/MarginContainer/VBoxContainer/DialogueText
@onready var player_input = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PlayerInput
@onready var send_button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PlayerInput/SendButton
@onready var close_button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

# Current NPC we're talking to
var current_npc: Node = null
var is_generating: bool = false
var conversation_history: String = ""

func _ready():
	hide()
	player_input.text_submitted.connect(_on_send_message)

func _input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		close_dialogue()
		get_viewport().set_input_as_handled()

func show_dialogue(npc: Node):
	if current_npc:
		disconnect_npc_signals()
	
	current_npc = npc
	npc_name_label.text = npc.npc_name
	conversation_history = ""
	dialogue_text.text = ""
	
	npc.dialogue_updated.connect(_on_dialogue_updated)
	npc.dialogue_finished.connect(_on_dialogue_finished)
	
	show()
	player_input.editable = false  # Disable until first response
	player_input.grab_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_dialogue():
	if current_npc:
		disconnect_npc_signals()
		if current_npc.has_method("end_conversation"):
			current_npc.end_conversation()
		current_npc = null
	
	hide()
	player_input.text = ""
	conversation_history = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func disconnect_npc_signals():
	if current_npc:
		if current_npc.dialogue_updated.is_connected(_on_dialogue_updated):
			current_npc.dialogue_updated.disconnect(_on_dialogue_updated)
		if current_npc.dialogue_finished.is_connected(_on_dialogue_finished):
			current_npc.dialogue_finished.disconnect(_on_dialogue_finished)

func _on_send_message(_message: String):
	var message = player_input.text.strip_edges()
	
	if not message or not current_npc or is_generating:
		return
	
	# Add player message to history
	conversation_history += "\n\n[You]: " + message
	
	# Clear input and update display
	player_input.text = ""
	dialogue_text.text = conversation_history + "\n\n[" + current_npc.npc_name + "]: "
	
	# Disable input while generating
	is_generating = true
	player_input.editable = false
	
	# Send to NPC
	current_npc.talk_to_npc(message)

func _on_dialogue_updated(text: String):
	# Display the accumulated response
	dialogue_text.text = conversation_history + "\n\n[" + current_npc.npc_name + "]: " + text

func _on_dialogue_finished(text: String):
	# Add complete response to history
	conversation_history += "\n\n[" + current_npc.npc_name + "]: " + text
	dialogue_text.text = conversation_history
	
	# Re-enable input
	is_generating = false
	player_input.editable = true
	player_input.grab_focus()
