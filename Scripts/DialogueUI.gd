extends CanvasLayer

# UI References
@onready var npc_name_label = $PanelContainer/MarginContainer/VBoxContainer/NPCNameLabel
@onready var dialogue_text = $PanelContainer/MarginContainer/VBoxContainer/DialogueText
@onready var player_input = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PlayerInput
@onready var send_button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SendButton
@onready var mic_button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MicButton
@onready var close_button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

# Current NPC we're talking to
var current_npc: Node = null
var is_generating: bool = false
var conversation_history: String = ""

# Voice input
var voice_recorder: VoiceRecorder = null
var is_recording: bool = false
var stt_provider = null
var is_push_to_talk_active: bool = false

func _ready():
	hide()
	player_input.text_submitted.connect(_on_send_message)
	
	# Setup voice recorder
	voice_recorder = VoiceRecorder.new()
	add_child(voice_recorder)
	voice_recorder.recording_started.connect(_on_recording_started)
	voice_recorder.recording_stopped.connect(_on_recording_stopped)
	voice_recorder.recording_error.connect(_on_recording_error)
	
	# Setup mic button
	if mic_button:
		mic_button.pressed.connect(_on_mic_button_pressed)
		_update_mic_button_state()

func _input(event):
	if not visible:
		return
	
	# Close on ESC
	if event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
		return
	
	# Push-to-talk with V key (only when NOT focused on text input)
	if event is InputEventKey and event.keycode == KEY_V:
		if not player_input.has_focus():
			if event.pressed and not event.echo and not is_recording:
				player_input.text = ""
				_start_voice_recording()
				get_viewport().set_input_as_handled()
			elif not event.pressed and is_recording:
				_stop_voice_recording()
				get_viewport().set_input_as_handled()
	
	# Send message with Enter (works even when not focused)
	if event.is_action_pressed("SendMessage"):
		if player_input.text.strip_edges().length() > 0 and not is_generating:
			_send_text_message(player_input.text.strip_edges())
			get_viewport().set_input_as_handled()
	
	# Click anywhere to unfocus text input
	if event is InputEventMouseButton and event.pressed:
		if player_input.has_focus():
			var mouse_pos = player_input.get_local_mouse_position()
			var input_rect = Rect2(Vector2.ZERO, player_input.size)
			if not input_rect.has_point(mouse_pos):
				player_input.release_focus()

func show_dialogue(npc: Node):
	if current_npc:
		disconnect_npc_signals()
	
	current_npc = npc
	npc_name_label.text = npc.npc_name
	conversation_history = ""
	dialogue_text.text = ""
	
	npc.dialogue_updated.connect(_on_dialogue_updated)
	npc.dialogue_finished.connect(_on_dialogue_finished)
	
	# Get STT provider from AIManager
	stt_provider = AIManager.get_stt_provider()
	if stt_provider:
		stt_provider.transcription_received.connect(_on_transcription_received)
		stt_provider.transcription_failed.connect(_on_transcription_failed)
	
	show()
	player_input.editable = false  # Disable until first response
	player_input.grab_focus()
	_update_mic_button_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_dialogue():
	if current_npc:
		disconnect_npc_signals()
		if current_npc.has_method("end_conversation"):
			current_npc.end_conversation()
		current_npc = null
	
	# Disconnect STT signals
	if stt_provider:
		if stt_provider.transcription_received.is_connected(_on_transcription_received):
			stt_provider.transcription_received.disconnect(_on_transcription_received)
		if stt_provider.transcription_failed.is_connected(_on_transcription_failed):
			stt_provider.transcription_failed.disconnect(_on_transcription_failed)
		stt_provider = null
	
	# Stop recording if active
	if is_recording:
		_stop_voice_recording()
	
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
	
	_send_text_message(message)

func _send_text_message(message: String):
	# Add player message to history
	conversation_history += "\n\n[You]: " + message
	
	# Clear input and update display
	player_input.text = ""
	dialogue_text.text = conversation_history + "\n\n[" + current_npc.npc_name + "]: "
	
	# Disable input while generating
	is_generating = true
	player_input.editable = false
	_update_mic_button_state()
	
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
	_update_mic_button_state()

# ============ Voice Input Handlers ============

func _on_mic_button_pressed():
	if is_recording:
		_stop_voice_recording()
	else:
		_start_voice_recording()

func _start_voice_recording():
	if is_generating or not current_npc:
		return
	
	# Check if voice input is configured
	if not AIManager.is_voice_input_ready():
		_show_voice_error("Voice input not configured. Please set up Parakeet API in settings.")
		return
	
	voice_recorder.start_recording()

func _stop_voice_recording():
	voice_recorder.stop_recording()

func _on_recording_started():
	is_recording = true
	_update_mic_button_state()
	player_input.placeholder_text = "🎙️ Recording... (click mic to stop)"
	print("Recording started")

func _on_recording_stopped(audio_data: PackedByteArray):
	is_recording = false
	_update_mic_button_state()
	player_input.placeholder_text = "Transcribing..."
	print("Recording stopped, sending to STT API...")
	
	# Send to Parakeet API
	if stt_provider:
		stt_provider.transcribe_audio(audio_data)
	else:
		_on_transcription_failed("STT provider not available")

func _on_recording_error(error: String):
	is_recording = false
	_update_mic_button_state()
	_show_voice_error(error)

func _on_transcription_received(text: String):
	player_input.placeholder_text = "Type your reply..."
	print("Transcription received: ", text)
	
	# Put the transcribed text in the input box (don't auto-send)
	if text.strip_edges().length() > 0:
		player_input.text = text
		player_input.grab_focus()  # Focus the input so user can edit if needed
	else:
		_show_voice_error("No speech detected")

func _on_transcription_failed(error: String):
	player_input.placeholder_text = "Type your reply..."
	_show_voice_error("Transcription failed: " + error)

func _show_voice_error(message: String):
	conversation_history += "\n\n[System]: " + message
	dialogue_text.text = conversation_history
	print("Voice error: ", message)

func _update_mic_button_state():
	if not mic_button:
		return
	
	if is_recording:
		mic_button.text = "Stop (V)"
		mic_button.modulate = Color.RED
	else:
		mic_button.text = "Voice (V)"
		mic_button.modulate = Color.WHITE
	
	# Disable mic during AI generation
	mic_button.disabled = is_generating
