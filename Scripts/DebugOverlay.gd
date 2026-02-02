extends CanvasLayer
class_name DebugOverlay

## Debug Overlay - Press F3 to toggle
## Shows: Conversation history, mood tracking, vision preview, room status, voice status

@export var toggle_key: Key = KEY_F3

# UI Elements
var panel: PanelContainer
var scroll_container: ScrollContainer
var vbox: VBoxContainer

# Sections
var header_label: Label
var separator1: HSeparator

var mood_section: VBoxContainer
var mood_label: Label
var mood_influences_label: Label

var separator2: HSeparator

var patience_section: VBoxContainer
var patience_label: Label
var patience_info_label: Label

var separator2a: HSeparator

var hostility_section: VBoxContainer
var hostility_label: Label
var hostility_info_label: Label

var separator2b: HSeparator

var goal_section: VBoxContainer
var goal_label: Label
var goal_info_label: Label

var separator2c: HSeparator

var conversation_section: VBoxContainer
var conversation_label: Label
var conversation_text: RichTextLabel

var separator3: HSeparator

var vision_section: VBoxContainer
var vision_label: Label
var vision_preview: TextureRect
var vision_status_label: Label

var separator4: HSeparator

var room_section: VBoxContainer
var room_label: Label
var room_info_label: Label

var separator5: HSeparator

var voice_section: VBoxContainer
var voice_label: Label
var voice_status_label: Label

var separator6: HSeparator

var ai_section: VBoxContainer
var ai_label: Label
var ai_status_label: Label

# State
var overlay_visible: bool = false
var current_npc: Node = null
var update_timer: Timer

func _ready():
	layer = 100  # Above everything
	_build_ui()
	hide_overlay()
	
	# Update timer
	update_timer = Timer.new()
	update_timer.wait_time = 0.5  # Update twice per second
	update_timer.timeout.connect(_update_display)
	add_child(update_timer)
	update_timer.start()

func _build_ui():
	# Main panel
	panel = PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_right = -20
	panel.offset_bottom = -20
	add_child(panel)
	
	# Scroll container
	scroll_container = ScrollContainer.new()
	panel.add_child(scroll_container)
	
	# Main VBox
	vbox = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 10)
	scroll_container.add_child(vbox)
	
	# Header
	header_label = Label.new()
	header_label.text = "DEBUG OVERLAY (F3 to toggle)"
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.add_theme_color_override("font_color", Color(1, 1, 0))
	vbox.add_child(header_label)
	
	# Debug controls info
	var controls_label = Label.new()
	controls_label.text = "Controls: [H/Shift+H] Hostility +10/-10 | [T/Shift+T] Trust +10/-10 | [R] Reset Emotions"
	controls_label.add_theme_font_size_override("font_size", 12)
	controls_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(controls_label)
	
	separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Mood Section
	mood_section = VBoxContainer.new()
	vbox.add_child(mood_section)
	
	mood_label = Label.new()
	mood_label.text = "EMOTION TRACKING"
	mood_label.add_theme_font_size_override("font_size", 16)
	mood_label.add_theme_color_override("font_color", Color(0.5, 1, 1))
	mood_section.add_child(mood_label)
	
	mood_influences_label = Label.new()
	mood_influences_label.text = "No NPC active"
	mood_influences_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mood_section.add_child(mood_influences_label)
	
	separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Patience/Trust Section
	patience_section = VBoxContainer.new()
	vbox.add_child(patience_section)
	
	patience_label = Label.new()
	patience_label.text = "⏱️ PATIENCE SYSTEM"
	patience_label.add_theme_font_size_override("font_size", 16)
	patience_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	patience_section.add_child(patience_label)
	
	patience_info_label = Label.new()
	patience_info_label.text = "Not in conversation"
	patience_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	patience_section.add_child(patience_info_label)
	
	separator2a = HSeparator.new()
	vbox.add_child(separator2a)
	
	# Hostility Section
	hostility_section = VBoxContainer.new()
	vbox.add_child(hostility_section)
	
	hostility_label = Label.new()
	hostility_label.text = "🗡️ HOSTILITY STATUS"
	hostility_label.add_theme_font_size_override("font_size", 16)
	hostility_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red color
	hostility_section.add_child(hostility_label)
	
	hostility_info_label = Label.new()
	hostility_info_label.text = "Checking..."
	hostility_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hostility_section.add_child(hostility_info_label)
	
	separator2b = HSeparator.new()
	vbox.add_child(separator2b)
	
	# Goal Section
	goal_section = VBoxContainer.new()
	vbox.add_child(goal_section)
	
	goal_label = Label.new()
	goal_label.text = "🎯 CURRENT GOAL"
	goal_label.add_theme_font_size_override("font_size", 16)
	goal_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))  # Gold color
	goal_section.add_child(goal_label)
	
	goal_info_label = Label.new()
	goal_info_label.text = "No goal set"
	goal_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_section.add_child(goal_info_label)
	
	separator2c = HSeparator.new()
	vbox.add_child(separator2c)
	
	# Conversation Section
	conversation_section = VBoxContainer.new()
	vbox.add_child(conversation_section)
	
	conversation_label = Label.new()
	conversation_label.text = "CONVERSATION HISTORY (Last 5)"
	conversation_label.add_theme_font_size_override("font_size", 16)
	conversation_label.add_theme_color_override("font_color", Color(0.5, 1, 1))
	conversation_section.add_child(conversation_label)
	
	conversation_text = RichTextLabel.new()
	conversation_text.custom_minimum_size = Vector2(0, 200)
	conversation_text.bbcode_enabled = true
	conversation_text.scroll_following = true
	conversation_section.add_child(conversation_text)
	
	separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Vision Section
	vision_section = VBoxContainer.new()
	vbox.add_child(vision_section)
	
	vision_label = Label.new()
	vision_label.text = "VISION SYSTEM"
	vision_label.add_theme_font_size_override("font_size", 16)
	vision_label.add_theme_color_override("font_color", Color(0.5, 1, 1))
	vision_section.add_child(vision_label)
	
	vision_preview = TextureRect.new()
	vision_preview.custom_minimum_size = Vector2(256, 256)
	vision_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	vision_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	vision_section.add_child(vision_preview)
	
	vision_status_label = Label.new()
	vision_status_label.text = "Vision disabled"
	vision_section.add_child(vision_status_label)
	
	separator4 = HSeparator.new()
	vbox.add_child(separator4)
	
	# Room Section
	room_section = VBoxContainer.new()
	vbox.add_child(room_section)
	
	room_label = Label.new()
	room_label.text = "ROOM TRACKING"
	room_label.add_theme_font_size_override("font_size", 16)
	room_label.add_theme_color_override("font_color", Color(0.5, 1, 1))
	room_section.add_child(room_label)
	
	room_info_label = Label.new()
	room_info_label.text = "No data"
	room_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_section.add_child(room_info_label)
	
	separator5 = HSeparator.new()
	vbox.add_child(separator5)
	
	# Voice Section
	voice_section = VBoxContainer.new()
	vbox.add_child(voice_section)
	
	voice_label = Label.new()
	voice_label.text = "VOICE SYSTEM"
	voice_label.add_theme_font_size_override("font_size", 16)
	voice_label.add_theme_color_override("font_color", Color(0.5, 1, 1))
	voice_section.add_child(voice_label)
	
	voice_status_label = Label.new()
	voice_status_label.text = "No NPC active"
	voice_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	voice_section.add_child(voice_status_label)
	
	separator6 = HSeparator.new()
	vbox.add_child(separator6)
	
	# AI Section
	ai_section = VBoxContainer.new()
	vbox.add_child(ai_section)
	
	ai_label = Label.new()
	ai_label.text = "AI PROVIDER STATUS"
	ai_label.add_theme_font_size_override("font_size", 16)
	ai_label.add_theme_color_override("font_color", Color(0.5, 1, 1))
	ai_section.add_child(ai_label)
	
	ai_status_label = Label.new()
	ai_status_label.text = "Loading..."
	ai_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_section.add_child(ai_status_label)

func _input(event):
	if event is InputEventKey and event.pressed:
		# Toggle overlay
		if event.keycode == toggle_key:
			toggle_overlay()
			get_viewport().set_input_as_handled()
			return
		
		# Debug emotion controls (only when overlay is visible)
		if overlay_visible and current_npc:
			_handle_debug_keys(event)
			get_viewport().set_input_as_handled()

func toggle_overlay():
	overlay_visible = !overlay_visible
	if overlay_visible:
		show_overlay()
	else:
		hide_overlay()

func show_overlay():
	panel.show()
	overlay_visible = true
	_update_display()

func hide_overlay():
	panel.hide()
	overlay_visible = false

func _handle_debug_keys(event: InputEventKey):
	"""Handle debug hotkeys for testing emotions"""
	if not current_npc or not "current_emotions" in current_npc:
		return
	
	var shift_pressed = event.shift_pressed
	var amount = -10 if shift_pressed else 10
	
	match event.keycode:
		KEY_H:  # Hostility
			if current_npc.has_method("adjust_emotion"):
				current_npc.adjust_emotion("hostility", amount)
				print("[Debug] Hostility %+d -> %d" % [amount, current_npc.current_emotions.get("hostility", 0)])
		KEY_T:  # Trust
			if current_npc.has_method("adjust_emotion"):
				current_npc.adjust_emotion("trust", amount)
				print("[Debug] Trust %+d -> %d" % [amount, current_npc.current_emotions.get("trust", 0)])
		KEY_A:  # Anger
			if current_npc.has_method("adjust_emotion"):
				current_npc.adjust_emotion("angry", amount)
				print("[Debug] Anger %+d -> %d" % [amount, current_npc.current_emotions.get("angry", 0)])
		KEY_R:  # Reset all emotions
			if not shift_pressed and current_npc.has_method("reset_conversation"):
				current_npc.reset_conversation()
				print("[Debug] Emotions reset to baseline")

func _update_display():
	if not overlay_visible:
		return
	
	# Get current NPC
	current_npc = NPCManager.get_current_npc()
	
	_update_mood_section()
	_update_patience_section()
	_update_hostility_section()
	_update_goal_section()
	_update_conversation_section()
	_update_vision_section()
	_update_room_section()
	_update_voice_section()
	_update_ai_section()

func _update_mood_section():
	if not current_npc:
		mood_influences_label.text = "No NPC active"
		return
	
	var mood_text = ""
	
	# Emotion description (natural language)
	if current_npc.has_method("get_emotion_description"):
		var emotion_desc = current_npc.get_emotion_description()
		mood_text += "Feeling: %s\n\n" % emotion_desc
	
	# Individual emotion intensities
	if "current_emotions" in current_npc:
		mood_text += "Emotion Intensities:\n"
		var emotions = current_npc.current_emotions
		
		# Show hostility first with danger indicator
		if "hostility" in emotions:
			var hostility_val = emotions["hostility"]
			var hostility_bar_length = int(hostility_val / 10)
			var hostility_bar = "█".repeat(hostility_bar_length) + "░".repeat(10 - hostility_bar_length)
			mood_text += "  ⚔️ Hostility: [%s] %d%%\n" % [hostility_bar, hostility_val]
		
		# Show trust second
		if "trust" in emotions:
			var trust_val = emotions["trust"]
			var trust_bar_length = int(trust_val / 10)
			var trust_bar = "█".repeat(trust_bar_length) + "░".repeat(10 - trust_bar_length)
			mood_text += "  🤝 Trust: [%s] %d%%\n" % [trust_bar, trust_val]
		
		for emotion_name in emotions:
			if emotion_name == "trust" or emotion_name == "hostility":  # Skip, already shown
				continue
			var intensity = emotions[emotion_name]
			if intensity > 0:
				# Visual bar representation
				var bar_length = int(intensity / 10)
				var bar = "█".repeat(bar_length) + "░".repeat(10 - bar_length)
				mood_text += "  %s: [%s] %d%%\n" % [emotion_name.capitalize(), bar, intensity]
			else:
				mood_text += "  %s: [░░░░░░░░░░] 0%%\n" % emotion_name.capitalize()
	
	# Emotion decay info
	if "emotion_decay_rate" in current_npc:
		mood_text += "\nDecay Rate: %.1f/sec" % current_npc.emotion_decay_rate
	
	if "enable_dynamic_emotions" in current_npc:
		mood_text += "  |  Dynamic: %s" % ("ON" if current_npc.enable_dynamic_emotions else "OFF")
	
	# Show decay enabled status
	if "enable_emotion_decay" in current_npc:
		mood_text += "  |  Decay: %s" % ("ON" if current_npc.enable_emotion_decay else "OFF")
	
	mood_influences_label.text = mood_text


func _update_patience_section():
	if not patience_info_label:
		return
	
	if not current_npc:
		patience_info_label.text = "No NPC active"
		return
	
	var patience_text = ""
	
	# Check if patience system is enabled
	if "enable_patience" in current_npc and current_npc.enable_patience:
		if "patience_timer" in current_npc and current_npc.patience_timer:
			var timer = current_npc.patience_timer
			var time_left = timer.time_left
			var wait_time = timer.wait_time
			
			if timer.is_stopped():
				patience_text = "⏸️ Timer stopped (not in conversation)\n"
				if "base_patience_time" in current_npc:
					patience_text += "Base: %.1fs" % current_npc.base_patience_time
			else:
				# Progress bar
				var progress = time_left / wait_time if wait_time > 0 else 0
				var bar_length = int(progress * 20)
				var bar = "█".repeat(bar_length) + "░".repeat(20 - bar_length)
				
				patience_text = "⏳ Time until ignore response:\n"
				patience_text += "[%s] %.1fs / %.1fs\n" % [bar, time_left, wait_time]
				
				# Color code based on urgency
				if time_left < 3:
					patience_text += "🔴 Almost out of patience!\n"
				elif time_left < 6:
					patience_text += "🟡 Getting impatient...\n"
				else:
					patience_text += "🟢 Waiting patiently\n"
				
				# Show base time info
				if "base_patience_time" in current_npc:
					patience_text += "Base: %.1fs" % current_npc.base_patience_time
				
				# Show trust multiplier
				if "trust_patience_multiplier" in current_npc and "current_emotions" in current_npc:
					var trust = current_npc.current_emotions.get("trust", 0)
					var multiplier = 1.0 + (trust / 100.0) * (current_npc.trust_patience_multiplier - 1.0)
					patience_text += " × %.2fx (trust)" % multiplier
		else:
			patience_text = "❌ Patience timer not found\n"
			if "base_patience_time" in current_npc:
				patience_text += "Base: %.1fs" % current_npc.base_patience_time
	else:
		patience_text = "❌ Patience system disabled"
	
	patience_info_label.text = patience_text


func _update_hostility_section():
	if not hostility_info_label:
		return
	
	if not current_npc:
		hostility_info_label.text = "No NPC active"
		return
	
	var hostility_text = ""
	
	# Check if hostility system is enabled
	if "enable_hostility" in current_npc and current_npc.enable_hostility:
		var is_hostile = current_npc.is_hostile if "is_hostile" in current_npc else false
		var hostility_val = current_npc.current_emotions.get("hostility", 0)
		var trust = current_npc.current_emotions.get("trust", 0)
		var can_attack = current_npc.can_attack if "can_attack" in current_npc else false
		
		# Status indicator
		if is_hostile:
			hostility_text = "⚠️ **HOSTILE** - ACTIVELY DANGEROUS!\n\n"
		else:
			hostility_text = "✅ Peaceful\n\n"
		
		# Hostility meter (main trigger)
		var hostility_progress = float(hostility_val) / 100.0
		var hostility_bar_filled = int(hostility_progress * 20)
		var hostility_bar = "█".repeat(hostility_bar_filled) + "░".repeat(20 - hostility_bar_filled)
		
		# Color code based on danger level
		var danger_indicator = ""
		if hostility_val >= 100:
			danger_indicator = "💀 ATTACKING!"
		elif hostility_val >= 75:
			danger_indicator = "🔴 CRITICAL"
		elif hostility_val >= 50:
			danger_indicator = "🟠 HIGH"
		elif hostility_val >= 25:
			danger_indicator = "🟡 ELEVATED"
		else:
			danger_indicator = "🟢 LOW"
		
		hostility_text += "⚔️ Hostility: [%s] %d%% %s\n" % [hostility_bar, hostility_val, danger_indicator]
		hostility_text += "   Attacks at: 100%%\n\n"
		
		# Trust (affects hostility gain rate)
		var trust_progress = float(trust) / 100.0
		var trust_bar_filled = int(trust_progress * 20)
		var trust_bar = "█".repeat(trust_bar_filled) + "░".repeat(20 - trust_bar_filled)
		hostility_text += "🤝 Trust: [%s] %d%%\n" % [trust_bar, trust]
		hostility_text += "   (Low trust = faster hostility gain)\n"
		
		# Attack status
		hostility_text += "\n🗡️ Attack Status: %s\n" % ("READY" if can_attack else "COOLDOWN")
		
		# Attack range
		if "attack_range" in current_npc and "player_ref" in current_npc:
			var player = current_npc.player_ref
			if player:
				var distance = current_npc.global_position.distance_to(player.global_position)
				var in_range = distance <= current_npc.attack_range
				hostility_text += "📏 Distance: %.1fm / %.1fm %s\n" % [distance, current_npc.attack_range, "✓" if in_range else "✗"]
		
		# Attack damage
		if "attack_damage" in current_npc:
			hostility_text += "💥 Damage: %d per hit\n" % current_npc.attack_damage
	else:
		hostility_text = "❌ Hostility system disabled"
	
	hostility_info_label.text = hostility_text


func _update_goal_section():
	if not current_npc:
		goal_info_label.text = "No NPC active"
		return
	
	# Get current goal from inspector property
	if current_npc.has_method("get_current_goal"):
		var goal = current_npc.get_current_goal()
		if goal.is_empty():
			goal_info_label.text = "No goal set\n(Set in Inspector: npc_current_goal)"
		else:
			goal_info_label.text = goal
	elif "npc_current_goal" in current_npc:
		var goal = current_npc.npc_current_goal
		if goal.is_empty():
			goal_info_label.text = "No goal set\n(Set in Inspector: npc_current_goal)"
		else:
			goal_info_label.text = goal
	else:
		goal_info_label.text = "Goal property not found"

func _update_conversation_section():
	if not current_npc or not "conversation_history" in current_npc:
		conversation_text.text = "No conversation active"
		return
	
	var history = current_npc.conversation_history
	if history.is_empty():
		conversation_text.text = "No messages yet"
		return
	
	# Show last 5 messages
	var start_idx = max(0, history.size() - 5)
	var display = ""
	
	for i in range(start_idx, history.size()):
		var entry = history[i]
		var role = entry.get("role", "unknown")
		var content = entry.get("content", "")
		
		if role == "user":
			display += "[color=lime][b]PLAYER:[/b][/color] %s\n\n" % content
		elif role == "assistant":
			display += "[color=cyan][b]%s:[/b][/color] %s\n\n" % [current_npc.npc_name, content]
		else:
			display += "[color=yellow][b]%s:[/b][/color] %s\n\n" % [role.to_upper(), content]
	
	conversation_text.text = display

func _update_vision_section():
	if not current_npc:
		vision_status_label.text = "No NPC active"
		vision_preview.texture = null
		return
	
	if not "enable_vision" in current_npc or not current_npc.enable_vision:
		vision_status_label.text = "Vision disabled for this NPC"
		vision_preview.texture = null
		return
	
	# Update preview image
	if "vision_viewport" in current_npc and current_npc.vision_viewport:
		var viewport_texture = current_npc.vision_viewport.get_texture()
		vision_preview.texture = viewport_texture
		
		# Fixed: Check property existence first
		var resolution = 512
		if "vision_resolution" in current_npc:
			resolution = current_npc.vision_resolution
		
		var interval = 2.0
		if "vision_capture_interval" in current_npc:
			interval = current_npc.vision_capture_interval
		
		vision_status_label.text = "Vision enabled: %dx%d @ %.1fs intervals" % [resolution, resolution, interval]
		
		# Show last capture time
		if "last_vision_capture_time" in current_npc:
			var time_since = (Time.get_ticks_msec() / 1000.0) - current_npc.last_vision_capture_time
			vision_status_label.text += "\nLast capture: %.1fs ago" % time_since
	else:
		vision_status_label.text = "Vision enabled but viewport not initialized"
		vision_preview.texture = null

func _update_room_section():
	var room_text = ""
	
	# Player location
	var player_room = RoomManager.get_player_room()
	room_text += "Player Room: %s\n" % player_room
	
	if RoomManager.player_just_changed_rooms():
		var prev_room = RoomManager.get_player_previous_room()
		room_text += "Just moved from: %s\n" % prev_room
	
	# NPC location
	if current_npc and "npc_name" in current_npc:
		var npc_room = RoomManager.get_npc_room(current_npc.npc_name)
		room_text += "NPC Room: %s\n" % npc_room
		
		if RoomManager.is_player_in_same_room_as_npc(current_npc.npc_name):
			room_text += "Player and NPC are in the same room\n"
		else:
			room_text += "Player and NPC are in different rooms\n"
	
	# All locations
	var all_locations = RoomManager.get_all_locations()
	room_text += "\nAll NPCs:\n"
	
	# Fixed: Proper dictionary access
	if all_locations.has("npcs"):
		var npcs = all_locations["npcs"]
		for npc_name in npcs:
			var npc_room = npcs[npc_name]
			room_text += "  • %s: %s\n" % [npc_name, npc_room]
	else:
		room_text += "  No NPCs registered\n"
	
	room_info_label.text = room_text

func _update_voice_section():
	if not current_npc:
		voice_status_label.text = "No NPC active"
		return
	
	var voice_text = ""
	
	# Voice enabled?
	if "enable_voice" in current_npc:
		if current_npc.enable_voice:
			voice_text += "Voice: ENABLED\n"
			
			# Voice preset
			if "voice_preset" in current_npc:
				var preset_name = current_npc.VoicePreset.keys()[current_npc.voice_preset]
				voice_text += "Preset: %s\n" % preset_name
			
			# Speaking status
			if current_npc.has_method("is_currently_speaking"):
				if current_npc.is_currently_speaking():
					voice_text += "Currently speaking...\n"
				else:
					voice_text += "Idle\n"
			
			# Voice speed
			if "voice_speed" in current_npc:
				voice_text += "Base Speed: %.2f\n" % current_npc.voice_speed
				
				# Mood-adjusted speed
				if current_npc.has_method("_get_mood_adjusted_speed"):
					var adjusted = current_npc._get_mood_adjusted_speed()
					if adjusted != current_npc.voice_speed:
						voice_text += "Mood-Adjusted Speed: %.2f\n" % adjusted
			
			# Volume
			if "voice_volume_db" in current_npc:
				voice_text += "Volume: %.1f dB\n" % current_npc.voice_volume_db
			
			# TTS engine status
			if "kokoro_tts" in current_npc and current_npc.kokoro_tts:
				if current_npc.kokoro_tts.has_method("get_status"):
					voice_text += "TTS: %s\n" % current_npc.kokoro_tts.get_status()
				if current_npc.kokoro_tts.has_method("is_busy"):
					if current_npc.kokoro_tts.is_busy():
						voice_text += "TTS synthesizing...\n"
		else:
			voice_text += "Voice: DISABLED\n"
	else:
		voice_text += "Voice system not available\n"
	
	voice_status_label.text = voice_text

func _update_ai_section():
	var ai_text = ""
	
	# Provider
	ai_text += "Provider: %s\n" % AIManager.get_provider_name()
	ai_text += "Status: %s\n\n" % AIManager.get_provider_status()
	
	# Groq settings (if using Groq)
	if AIManager.is_groq():
		ai_text += "Groq Model: %s\n" % AIManager.get_groq_model()
		var api_key = AIManager.get_groq_api_key()
		if api_key.is_empty():
			ai_text += "API Key: Not set\n"
		else:
			ai_text += "API Key: Configured\n"
	
	# Local model (if using local)
	if AIManager.is_local():
		ai_text += "Model: %s\n" % AIManager.get_local_model_path().get_file()
	
	ai_text += "\nVoice Input: %s\n" % AIManager.get_voice_input_status()
	
	# NPC-specific AI info
	if current_npc:
		ai_text += "\nNPC Settings:\n"
		
		if "max_response_length" in current_npc:
			ai_text += "  • Max Response: %s\n" % current_npc.max_response_length
		
		if "max_history_turns" in current_npc:
			ai_text += "  • Max History: %d turns\n" % current_npc.max_history_turns
		
		if "enable_memory" in current_npc:
			var mem_status = "ON" if current_npc.enable_memory else "OFF"
			ai_text += "  • Memory: %s\n" % mem_status
		
		# Fixed: Check property exists before accessing
		if "enable_forgetting" in current_npc and current_npc.enable_forgetting:
			var delay = 60.0
			if "forget_delay" in current_npc:
				delay = current_npc.forget_delay
			ai_text += "  • Forgetting: ON (%.0fs delay)\n" % delay
	
	ai_status_label.text = ai_text
