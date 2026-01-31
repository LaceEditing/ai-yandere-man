extends CanvasLayer

## Minimal Dialogue UI - AI2U Style
## Text appears on screen as AI responds, player can move freely

# UI References
@onready var npc_text_container = $NPCTextContainer
@onready var npc_name_label = $NPCTextContainer/VBoxContainer/NPCNameLabel
@onready var npc_dialogue_label = $NPCTextContainer/VBoxContainer/DialogueLabel

@onready var input_prompt = $InputPrompt
@onready var input_field = $InputPrompt/InputField

# Current NPC we're talking to
var current_npc: Node = null
var is_generating: bool = false

# Typing effect
var current_text: String = ""
var display_text: String = ""
var typing_speed: float = 0.02  # Seconds per character
var typing_timer: float = 0.0
var is_typing: bool = false

# Auto-hide timer
var auto_hide_delay: float = 3.0  # Seconds before text fades
var hide_timer: Timer = null

# Voice input
var voice_recorder: VoiceRecorder = null
var is_recording: bool = false
var stt_provider = null

# Check if input is currently open (for movement blocking)
func is_input_open() -> bool:
	return input_prompt.visible

# Check if AI is busy generating or typing (prevent interruption)
func is_busy() -> bool:
	return is_generating or is_typing

# Check if conversation is still active (includes waiting for auto-close)
func has_active_conversation() -> bool:
	return current_npc != null

func _ready():
	# Don't hide the entire layer, just hide the UI elements
	# hide()  ← This was hiding everything!
	
	# Setup voice recorder
	voice_recorder = VoiceRecorder.new()
	add_child(voice_recorder)
	voice_recorder.recording_started.connect(_on_recording_started)
	voice_recorder.recording_stopped.connect(_on_recording_stopped)
	voice_recorder.recording_error.connect(_on_recording_error)
	
	# Setup auto-hide timer
	hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(hide_timer)
	
	# Start with UI elements hidden
	input_prompt.hide()
	npc_text_container.hide()

func _input(event):
	# Check if input field is open
	if input_prompt.visible:
		# Submit message with Enter (using SendMessage action)
		if event.is_action_pressed("SendMessage"):
			_submit_message()
			get_viewport().set_input_as_handled()
			return
		
		# Cancel with ESC
		if event.is_action_pressed("ui_cancel"):
			_close_input()
			get_viewport().set_input_as_handled()
			return
		
		# Push-to-talk with V key
		# ONLY handle if we're actually starting/stopping recording
		# Otherwise let V type normally
		if event.is_action_pressed("push_to_talk") and not is_recording:
			# Only start recording if field is empty
			if input_field.text.is_empty():
				_start_voice_recording()
				get_viewport().set_input_as_handled()  # Prevent "v" from being typed
			# If field has text, don't handle - let "v" be typed normally
		elif event.is_action_released("push_to_talk") and is_recording:
			_stop_voice_recording()
			get_viewport().set_input_as_handled()

func _process(delta):
	# Typing effect
	if is_typing:
		typing_timer += delta
		
		# Add characters based on typing speed
		var chars_to_add = int(typing_timer / typing_speed)
		if chars_to_add > 0:
			typing_timer = 0.0
			
			var target_length = min(display_text.length() + chars_to_add, current_text.length())
			display_text = current_text.substr(0, target_length)
			npc_dialogue_label.text = display_text
			
			# Check if done typing
			if display_text.length() >= current_text.length():
				is_typing = false
				_start_auto_hide_timer()

func show_dialogue(npc: Node):
	# Don't show new input if AI is still responding
	if is_generating or is_typing:
		print("DialogueUI: AI is busy, ignoring new dialogue request")
		return
	
	if current_npc:
		disconnect_npc_signals()
	
	current_npc = npc
	npc_name_label.text = npc.npc_name
	
	# Connect to NPC signals
	npc.dialogue_updated.connect(_on_dialogue_updated)
	npc.dialogue_finished.connect(_on_dialogue_finished)
	
	# Get STT provider from AIManager
	stt_provider = AIManager.get_stt_provider()
	if stt_provider:
		stt_provider.transcription_received.connect(_on_transcription_received)
		stt_provider.transcription_failed.connect(_on_transcription_failed)
	
	# Show input prompt
	_show_input()

func _show_input():
	input_prompt.show()
	input_field.text = ""
	input_field.grab_focus()
	
	# Don't capture mouse - keep it captured for gameplay
	# Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_input():
	input_prompt.hide()
	input_field.text = ""
	
	# Keep mouse captured for first-person movement
	# Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _submit_message():
	var message = input_field.text.strip_edges()
	
	if message.is_empty() or not current_npc or is_generating:
		return
	
	# Send to NPC
	is_generating = true
	current_npc.talk_to_npc(message)
	
	# Close input and release player
	_close_input()

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
	
	input_prompt.hide()
	npc_text_container.hide()
	is_generating = false
	is_typing = false
	
	if hide_timer:
		hide_timer.stop()

func disconnect_npc_signals():
	if current_npc:
		if current_npc.dialogue_updated.is_connected(_on_dialogue_updated):
			current_npc.dialogue_updated.disconnect(_on_dialogue_updated)
		if current_npc.dialogue_finished.is_connected(_on_dialogue_finished):
			current_npc.dialogue_finished.disconnect(_on_dialogue_finished)

func _on_dialogue_updated(text: String):
	# Don't show NPC text if input is open (player is typing)
	if input_prompt.visible:
		return
	
	# Show NPC text container
	if not npc_text_container.visible:
		npc_text_container.show()
	
	# Update current text for typing effect
	current_text = text
	
	# If not already typing, start
	if not is_typing:
		display_text = ""
		is_typing = true
		typing_timer = 0.0
		
		# Stop auto-hide timer while typing
		if hide_timer:
			hide_timer.stop()

func _on_dialogue_finished(text: String):
	# Don't show NPC response if input is open (suppress greeting)
	if input_prompt.visible:
		return
	
	# Final text update
	current_text = text
	
	if not is_typing:
		# Display immediately if not already typing
		display_text = text
		npc_dialogue_label.text = display_text
		_start_auto_hide_timer()
	# Otherwise typing effect will finish and trigger auto-hide
	
	# Re-enable input
	is_generating = false
	
	# Don't show input - conversation will end after auto-hide timer
	# For next conversation, player presses Enter again

func _start_auto_hide_timer():
	# Don't start auto-hide if input is open (player is typing)
	if input_prompt.visible:
		return
	
	if hide_timer:
		hide_timer.start(auto_hide_delay)

func _on_hide_timer_timeout():
	# After text fades, close the entire conversation
	# Player returns to normal gameplay
	close_dialogue()

# ============ Voice Input Handlers ============

func _start_voice_recording():
	if is_generating or not current_npc:
		return
	
	# Check if voice input is configured
	if not AIManager.is_voice_input_ready():
		_show_error("Voice input not configured. Please set up Groq API in settings.")
		return
	
	voice_recorder.start_recording()

func _stop_voice_recording():
	voice_recorder.stop_recording()

func _on_recording_started():
	is_recording = true
	input_field.placeholder_text = "🎙️ Recording... (release V to stop)"
	print("Recording started")

func _on_recording_stopped(audio_data: PackedByteArray):
	is_recording = false
	input_field.placeholder_text = "Transcribing..."
	print("Recording stopped, sending to STT API...")
	
	# Send to STT API
	if stt_provider:
		stt_provider.transcribe_audio(audio_data)
	else:
		_on_transcription_failed("STT provider not available")

func _on_recording_error(error: String):
	is_recording = false
	input_field.placeholder_text = "Type your message..."
	_show_error(error)

func _on_transcription_received(text: String):
	input_field.placeholder_text = "Type your message..."
	print("Transcription received: ", text)
	
	# Put the transcribed text in the input box
	if text.strip_edges().length() > 0:
		input_field.text = text
		input_field.grab_focus()
	else:
		_show_error("No speech detected")

func _on_transcription_failed(error: String):
	input_field.placeholder_text = "Type your message..."
	_show_error("Transcription failed: " + error)

func _show_error(message: String):
	print("Voice error: ", message)
	# Could show error in UI if desired
