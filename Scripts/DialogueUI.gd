extends CanvasLayer

## Enhanced Dialogue UI - AI2U Style with Voice Sync + Auto Scaling
## Fixes: Voice cutoff, typewriter sync with audio, auto-scales to screen resolution
## NOW: Supports auto-greetings without opening input field

# UI References
@onready var npc_text_container = $NPCTextContainer
@onready var npc_name_label = $NPCTextContainer/VBoxContainer/NPCNameLabel
@onready var npc_dialogue_label = $NPCTextContainer/VBoxContainer/DialogueLabel

@onready var input_prompt = $InputPrompt
@onready var input_field = $InputPrompt/InputField

# Current NPC we're talking to
var current_npc: Node = null
var is_generating: bool = false

# Typing effect with voice sync
var current_text: String = ""
var display_text: String = ""
@export_range(0.01, 0.1, 0.01, "suffix:seconds") var typing_speed: float = 0.02  ## Speed of typewriter effect (per character)
var typing_timer: float = 0.0
var is_typing: bool = false
var waiting_for_voice: bool = false  # Wait for TTS to start

# Auto-hide timer
@export_range(1.0, 10.0, 0.5, "suffix:seconds") var auto_hide_delay: float = 3.0  ## Time before dialogue text fades
var hide_timer: Timer = null

# Voice input
var voice_recorder: VoiceRecorder = null
var is_recording: bool = false
var stt_provider = null

# UI Scaling
var current_scale_factor: float = 1.0
var base_font_size: int = 18

## INSPECTOR ADJUSTABLE SETTINGS ##
@export_category("UI Scaling")
@export var enable_auto_scaling: bool = true  ## Auto-scale based on screen resolution
@export_range(0.5, 3.0, 0.1) var manual_scale_override: float = 1.5  ## Manual scale (used if auto disabled)
@export var apply_scale_on_ready: bool = true  ## Apply scaling when game starts

# Check if input is currently open (for movement blocking)
func is_input_open() -> bool:
	return input_prompt.visible

# Check if AI is busy generating or typing (prevent interruption)
func is_busy() -> bool:
	return is_generating or is_typing or waiting_for_voice

# Check if conversation is still active (includes waiting for auto-close)
func has_active_conversation() -> bool:
	return current_npc != null

func _ready():
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
	
	# Apply UI scaling based on settings
	if apply_scale_on_ready:
		if enable_auto_scaling:
			_apply_dynamic_scaling()
		else:
			_apply_scale(manual_scale_override)

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
		if event.is_action_pressed("push_to_talk") and not is_recording:
			# Only start recording if field is empty
			if input_field.text.is_empty():
				_start_voice_recording()
				get_viewport().set_input_as_handled()
		elif event.is_action_released("push_to_talk") and is_recording:
			_stop_voice_recording()
			get_viewport().set_input_as_handled()

func _process(delta):
	# Typing effect (starts when voice starts, or immediately if no voice)
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
				# NEW: Start timer immediately when typing finishes
				# Voice can keep playing in background
				_start_auto_hide_timer()

func show_dialogue(npc: Node, show_input: bool = true):
	# Don't show new input if AI is still responding
	if is_generating or is_typing or waiting_for_voice:
		print("DialogueUI: AI is busy, ignoring new dialogue request")
		return
	
	if current_npc:
		disconnect_npc_signals()
	
	current_npc = npc
	npc_name_label.text = npc.npc_name
	
	# Connect to NPC signals
	npc.dialogue_updated.connect(_on_dialogue_updated)
	npc.dialogue_finished.connect(_on_dialogue_finished)
	
	# NEW: Connect to voice signals for proper synchronization
	if npc.has_signal("voice_started"):
		npc.voice_started.connect(_on_npc_voice_started)
	if npc.has_signal("voice_finished"):
		npc.voice_finished.connect(_on_npc_voice_finished)
	
	# Get STT provider from AIManager
	stt_provider = AIManager.get_stt_provider()
	if stt_provider:
		stt_provider.transcription_received.connect(_on_transcription_received)
		stt_provider.transcription_failed.connect(_on_transcription_failed)
	
	# Show input prompt only if requested (for player-initiated conversations)
	if show_input:
		_show_input()

func _show_input():
	input_prompt.show()
	input_field.text = ""
	input_field.grab_focus()

func _close_input():
	input_prompt.hide()
	input_field.text = ""

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
	
	# NEW: Don't stop voice - let it finish naturally in background
	# Voice will only be interrupted when new voice starts
	
	input_prompt.hide()
	npc_text_container.hide()
	is_generating = false
	is_typing = false
	waiting_for_voice = false
	
	if hide_timer:
		hide_timer.stop()

func disconnect_npc_signals():
	if current_npc:
		if current_npc.dialogue_updated.is_connected(_on_dialogue_updated):
			current_npc.dialogue_updated.disconnect(_on_dialogue_updated)
		if current_npc.dialogue_finished.is_connected(_on_dialogue_finished):
			current_npc.dialogue_finished.disconnect(_on_dialogue_finished)
		# NEW: Disconnect voice signals
		if current_npc.has_signal("voice_started") and current_npc.voice_started.is_connected(_on_npc_voice_started):
			current_npc.voice_started.disconnect(_on_npc_voice_started)
		if current_npc.has_signal("voice_finished") and current_npc.voice_finished.is_connected(_on_npc_voice_finished):
			current_npc.voice_finished.disconnect(_on_npc_voice_finished)

func _on_dialogue_updated(text: String):
	# Don't show NPC text if input is open (player is typing)
	if input_prompt.visible:
		return
	
	# Show NPC text container
	if not npc_text_container.visible:
		npc_text_container.show()
	
	# Update current text for typing effect
	current_text = text
	
	# Don't start typing yet - wait for voice to start (if voice is enabled)
	if not is_typing and not waiting_for_voice:
		if current_npc and current_npc.has_method("is_currently_speaking"):
			# Check if NPC will speak this
			if current_npc.enable_voice and not current_text.begins_with("[Error"):
				# Wait for voice to start
				waiting_for_voice = true
				display_text = ""
				npc_dialogue_label.text = "..."  # Show waiting indicator
				if hide_timer:
					hide_timer.stop()
			else:
				# No voice, start typing immediately
				_start_typewriter()
		else:
			# No voice capability, start typing immediately
			_start_typewriter()

func _on_dialogue_finished(text: String):
	# Don't show NPC response if input is open (suppress greeting)
	if input_prompt.visible:
		return
	
	# Show NPC text container if not visible
	if not npc_text_container.visible:
		npc_text_container.show()
	
	# Final text update
	current_text = text
	is_generating = false
	
	# If already typing or waiting for voice, let those systems handle completion
	if is_typing or waiting_for_voice:
		return
	
	# Not typing and not waiting - display immediately and start timer
	display_text = text
	npc_dialogue_label.text = display_text
	_start_auto_hide_timer()

# NEW: Voice synchronization handlers
func _on_npc_voice_started():
	"""Called when NPC starts speaking - begin typewriter effect."""
	if waiting_for_voice:
		waiting_for_voice = false
		_start_typewriter()

func _on_npc_voice_finished():
	"""Called when NPC finishes speaking - voice complete (timer already running)."""
	# Voice finished, but we don't need to do anything
	# Timer already started when typewriter finished
	# Player might already be typing their next message
	pass

func _start_typewriter():
	"""Start the typewriter effect."""
	display_text = ""
	is_typing = true
	typing_timer = 0.0
	npc_dialogue_label.text = ""
	
	if hide_timer:
		hide_timer.stop()

func _start_auto_hide_timer():
	"""Start the countdown to hide the dialogue (only when safe)."""
	# Don't start if input is open
	if input_prompt.visible:
		return
	
	# Don't start if still waiting for voice to start
	if waiting_for_voice:
		return
	
	# NEW: Start timer even if voice is still playing
	# Voice will continue in background
	if hide_timer:
		hide_timer.start(auto_hide_delay)

func _on_hide_timer_timeout():
	"""After text fades, close the entire conversation."""
	# Hide UI but DON'T stop voice - let it finish naturally
	npc_text_container.hide()
	
	# If no conversation is active anymore, fully close
	if not current_npc or not is_generating:
		close_dialogue()

# ============================================
# UI SCALING SYSTEM
# ============================================

func _apply_dynamic_scaling():
	"""
	Automatically scale UI based on screen resolution.
	Base resolution: 1920x1080
	Scales between 1.0x (HD) and 2.0x (4K+)
	"""
	var viewport_size = get_viewport().get_visible_rect().size
	var base_width = 1920.0  # Reference resolution
	var scale_factor = viewport_size.x / base_width
	
	# Clamp between 1.0 and 2.0 for reasonable sizes
	scale_factor = clamp(scale_factor, 1.0, 2.0)
	current_scale_factor = scale_factor
	
	print("[DialogueUI] Viewport size: ", viewport_size)
	print("[DialogueUI] Scale factor: ", scale_factor)
	
	_apply_scale(scale_factor)

func _apply_scale(scale_factor: float):
	"""Apply a specific scale factor to all UI elements."""
	# Scale font sizes
	var scaled_font_size = int(base_font_size * scale_factor)
	
	# Apply scaled font size to labels
	if npc_dialogue_label:
		npc_dialogue_label.add_theme_font_size_override("font_size", scaled_font_size)
	
	if npc_name_label:
		npc_name_label.add_theme_font_size_override("font_size", int(scaled_font_size * 0.85))  # Slightly smaller
	
	if input_field:
		input_field.add_theme_font_size_override("font_size", scaled_font_size)
	
	# Scale minimum sizes
	if npc_dialogue_label:
		var base_min_size = Vector2(600, 80)
		npc_dialogue_label.custom_minimum_size = base_min_size * scale_factor
	
	# Scale container margins
	if npc_text_container:
		var base_margin = 20.0
		var scaled_margin = base_margin * scale_factor
		npc_text_container.offset_left = scaled_margin
		npc_text_container.offset_right = -scaled_margin
		npc_text_container.offset_bottom = -scaled_margin
		
		var base_height = 120.0
		var scaled_height = base_height * scale_factor
		npc_text_container.offset_top = -scaled_height
	
	# Scale input prompt
	if input_prompt:
		var base_input_width = 250.0
		var scaled_input_width = base_input_width * scale_factor
		input_prompt.offset_left = -scaled_input_width
		input_prompt.offset_right = scaled_input_width
		
		var base_input_height = 60.0
		var scaled_input_height = base_input_height * scale_factor
		input_prompt.offset_top = -scaled_input_height
	
	print("[DialogueUI] UI scaled: font_size=", scaled_font_size, "px, factor=", scale_factor)

func set_manual_scale(scale: float):
	"""
	Manually set UI scale factor.
	1.0 = default (18px), 1.5 = 50% larger (27px), 2.0 = double size (36px)
	Call this from settings menu or console.
	"""
	scale = clamp(scale, 0.5, 3.0)
	current_scale_factor = scale
	enable_auto_scaling = false  # Disable auto-scaling when manual is used
	
	_apply_scale(scale)
	print("[DialogueUI] Manual scale applied: ", scale)

func reset_to_auto_scaling():
	"""Re-enable automatic scaling based on screen resolution."""
	enable_auto_scaling = true
	_apply_dynamic_scaling()
	print("[DialogueUI] Auto-scaling re-enabled")

func get_current_scale() -> float:
	"""Get the current scale factor being used."""
	return current_scale_factor

# ============================================
# VOICE INPUT HANDLERS
# ============================================

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
