extends CharacterBody3D

## Enhanced NPC with mood system, expressive TTS, and AUTO-GENERATED GREETINGS
## Generates unique greeting on spawn using AI based on character context

# ============ ENUMS ============

enum Mood {
	NEUTRAL,
	HAPPY,
	ANGRY,
	SAD,
	FEARFUL,
	DISGUSTED,
	SURPRISED,
	FLIRTY,
	SARCASTIC,
	TIRED,
}

enum VoicePreset {
	# American Female
	AF_BELLA,
	AF_NICOLE,
	AF_SARAH,
	AF_SKY,
	# American Male
	AM_ADAM,
	AM_MICHAEL,
	# British Female
	BF_EMMA,
	BF_ISABELLA,
	# British Male
	BM_GEORGE,
	BM_LEWIS,
	# European
	EF_DORA,
}

# ============ EXPORTS ============

# NPC Identity
@export var npc_name: String = "Shopkeeper"
@export var npc_location: String = "market"

# NPC Character Profile
@export_group("Character")
@export_multiline var npc_personality: String = "Grumpy but fair shopkeeper"
@export_multiline var npc_background: String = "Former adventurer, now runs a general goods shop"
@export_multiline var npc_goals: String = "Make money, retire comfortably"
@export_multiline var npc_knowledge: String = "Knows about adventuring gear, local gossip"
@export_multiline var npc_appearance: String = "A tall figure wearing a brown apron"
@export_multiline var player_appearance: String = "The player is a green humanoid figure"

# Mood System
@export_group("Mood System")
@export var default_mood: Mood = Mood.NEUTRAL
@export var enable_dynamic_mood: bool = true ## AI can change mood based on conversation
@export var mood_decay_time: float = 120.0 ## Seconds before mood returns to default

# Conversation settings
@export_group("Dialogue Settings")
@export var max_response_length: String = "1-2 sentences"
@export var greeting: String = "Aye, what can I do for ye?" ## Fallback greeting (used if generation fails)
@export var generate_greeting_on_start: bool = true ## Generate unique greeting using AI

# Memory settings
@export_group("Memory Settings")
@export var enable_memory: bool = true
@export_range(1, 50, 1) var max_history_turns: int = 10
@export var enable_forgetting: bool = true
@export_range(10.0, 300.0, 5.0, "suffix:seconds") var forget_delay: float = 60.0

# Vision settings
@export_group("Vision Settings")
@export var enable_vision: bool = false
@export_range(0.0, 10.0, 0.1, "suffix:seconds") var vision_capture_interval: float = 2.0
@export_range(128, 1024, 64) var vision_resolution: int = 512

# Voice settings
@export_group("Voice Settings")
@export var enable_voice: bool = true
@export var speak_greeting: bool = true ## Auto-speak the generated greeting (requires enable_voice)
@export var voice_preset: VoicePreset = VoicePreset.AM_ADAM
@export_range(0.5, 1.5, 0.05) var voice_speed: float = 1.0 ## Base speed (lower = faster)
@export_range(-20.0, 6.0, 0.5, "suffix:dB") var voice_volume_db: float = 0.0
@export var mood_affects_voice: bool = true ## Mood changes voice speed/tone

# Text cleaning settings
@export_group("Response Filtering")
@export var remove_action_markers: bool = true
@export var remove_asterisks: bool = true
@export var remove_parentheses: bool = true
@export var remove_brackets: bool = true

# ============ INTERNAL STATE ============

# References
@onready var chat_node = $ChatNode
@onready var vision_viewport: SubViewport = $AnimeBoy/Camera3D/SubViewport
@onready var npc_camera: Camera3D = $AnimeBoy/Camera3D

# State
var is_talking = false
var current_response = ""
var conversation_history: Array = []
var forget_timer: Timer
var mood_decay_timer: Timer
var system_prompt: String = ""

# Greeting generation state
var generated_greeting: String = ""
var greeting_generated: bool = false
var is_generating_greeting: bool = false

# Current mood
var current_mood: Mood = Mood.NEUTRAL

# Groq-specific state
var groq_provider = null
var using_groq: bool = false

# Vision state
var last_vision_capture_time: float = 0.0
var cached_vision_base64: String = ""

# Room/location state
var current_room: String = "unknown"

# Voice state
var kokoro_tts: KokoroTTS = null
var voice_player: AudioStreamPlayer3D = null
var is_speaking: bool = false

# ============ SIGNALS ============

signal dialogue_updated(text: String)
signal dialogue_finished(text: String)
signal voice_started()
signal voice_finished()
signal mood_changed(old_mood: Mood, new_mood: Mood)
signal greeting_generation_complete(greeting_text: String)

# ============ MOOD DESCRIPTIONS ============

const MOOD_DESCRIPTIONS: Dictionary = {
	Mood.NEUTRAL: "calm and composed",
	Mood.HAPPY: "cheerful and upbeat",
	Mood.ANGRY: "irritated and aggressive",
	Mood.SAD: "melancholic and downcast",
	Mood.FEARFUL: "nervous and anxious",
	Mood.DISGUSTED: "repulsed and dismissive",
	Mood.SURPRISED: "shocked and bewildered",
	Mood.FLIRTY: "playful and suggestive",
	Mood.SARCASTIC: "dry and mocking",
	Mood.TIRED: "exhausted and sluggish",
}

const MOOD_SPEECH_STYLES: Dictionary = {
	Mood.NEUTRAL: "Speak in a normal, conversational tone.",
	Mood.HAPPY: "Speak with enthusiasm! Use upbeat language and occasional exclamations!",
	Mood.ANGRY: "Speak curtly. Short sentences. Show irritation.",
	Mood.SAD: "Speak slowly... with pauses... trailing off sometimes...",
	Mood.FEARFUL: "Speak nervously - quick, stuttering, uncertain...",
	Mood.DISGUSTED: "Speak with disdain. Ugh. Show your contempt.",
	Mood.SURPRISED: "What?! Speak with shock! Express disbelief!",
	Mood.FLIRTY: "Speak playfully~ with a teasing tone~",
	Mood.SARCASTIC: "Oh, speak with *such* enthusiasm. Really. Wow.",
	Mood.TIRED: "Speak... slowly... like everything... is an effort...",
}

# Voice ID mapping
const VOICE_PRESET_IDS: Dictionary = {
	VoicePreset.AF_BELLA: 0,
	VoicePreset.AF_NICOLE: 1,
	VoicePreset.AF_SARAH: 2,
	VoicePreset.AF_SKY: 3,
	VoicePreset.AM_ADAM: 4,
	VoicePreset.AM_MICHAEL: 5,
	VoicePreset.BF_EMMA: 6,
	VoicePreset.BF_ISABELLA: 7,
	VoicePreset.BM_GEORGE: 8,
	VoicePreset.BM_LEWIS: 9,
	VoicePreset.EF_DORA: 10,
}

# ============ LIFECYCLE ============

func _ready():
	current_mood = default_mood
	
	_detect_initial_room()
	
	if enable_vision:
		_setup_vision()
	
	if enable_voice:
		_setup_voice()
	
	system_prompt = build_system_prompt()
	_setup_provider()
	AIManager.provider_changed.connect(_on_provider_changed)
	
	# Forget timer
	if enable_forgetting:
		forget_timer = Timer.new()
		forget_timer.one_shot = true
		forget_timer.timeout.connect(reset_conversation)
		add_child(forget_timer)
	
	# Mood decay timer
	if enable_dynamic_mood and mood_decay_time > 0:
		mood_decay_timer = Timer.new()
		mood_decay_timer.one_shot = true
		mood_decay_timer.timeout.connect(_on_mood_decay)
		add_child(mood_decay_timer)
	
	# Continuous vision capture timer
	if enable_vision and vision_capture_interval > 0:
		var vision_timer = Timer.new()
		vision_timer.name = "VisionTimer"
		vision_timer.wait_time = vision_capture_interval
		vision_timer.timeout.connect(_on_vision_timer_timeout)
		add_child(vision_timer)
		vision_timer.start()
		print("[", npc_name, "] Continuous vision capture enabled (every %.1fs)" % vision_capture_interval)
	
	NPCManager.register_npc(self)
	
	print(npc_name, " ready! Mood: ", Mood.keys()[current_mood], ", Voice: ", VoicePreset.keys()[voice_preset])
	
	# Generate greeting AFTER everything is set up
	if generate_greeting_on_start:
		_generate_initial_greeting()


func _on_vision_timer_timeout():
	"""Continuously capture vision even when not in conversation."""
	if enable_vision and vision_viewport:
		await _capture_vision()


func _exit_tree():
	NPCManager.unregister_npc(self)
	_disconnect_groq_signals()

# ============ GREETING GENERATION ============

func _generate_initial_greeting():
	"""Generate a unique greeting using AI based on NPC context."""
	if greeting_generated or is_generating_greeting:
		return
	
	is_generating_greeting = true
	print("[", npc_name, "] Generating initial greeting...")
	
	# Build greeting generation prompt
	var greeting_prompt = _build_greeting_prompt()
	
	# Temporarily connect to response handlers for greeting generation
	if using_groq:
		# For Groq, we'll use a one-shot connection
		if groq_provider:
			groq_provider.response_finished.connect(_on_greeting_generated, CONNECT_ONE_SHOT)
			groq_provider.request_failed.connect(_on_greeting_failed, CONNECT_ONE_SHOT)
			
			# Send greeting generation request
			groq_provider.set_system_prompt("You are a creative writer. Generate realistic NPC dialogue.")
			groq_provider.ask(greeting_prompt, [])
	else:
		# For local, we'll use a one-shot connection
		if chat_node:
			chat_node.response_finished.connect(_on_greeting_generated, CONNECT_ONE_SHOT)
			
			# Send greeting generation request
			chat_node.system_prompt = "You are a creative writer. Generate realistic NPC dialogue."
			chat_node.ask(greeting_prompt)


func _build_greeting_prompt() -> String:
	"""Build the prompt for greeting generation."""
	var prompt = """Generate a SHORT greeting (1-2 sentences maximum) for this NPC to say when first meeting the player.

# CHARACTER INFO:
Name: {name}
Personality: {personality}
Background: {background}
Current Mood: {mood}
Location: {location}

# RULES:
1. Stay in character
2. Make it natural and conversational
3. NO action descriptions like *smiles* or (waves)
4. 1-2 sentences ONLY
5. Speak as the character would based on their personality
6. Consider their current mood

Generate ONLY the greeting text, nothing else:"""
	
	return prompt.format({
		"name": npc_name,
		"personality": npc_personality,
		"background": npc_background,
		"mood": get_mood_description(),
		"location": npc_location
	})


func _on_greeting_generated(greeting_text: String):
	"""Called when AI finishes generating the greeting."""
	is_generating_greeting = false
	
	# Clean the generated greeting
	var cleaned = greeting_text.strip_edges()
	
	# Remove any remaining action markers
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	
	# Remove mood tags if present
	cleaned = _strip_mood_tags(cleaned)
	
	# Fallback if something went wrong
	if cleaned.is_empty() or cleaned.length() > 200:
		print("[", npc_name, "] Generated greeting invalid, using fallback")
		generated_greeting = greeting
	else:
		generated_greeting = cleaned
		print("[", npc_name, "] Generated greeting: ", generated_greeting)
	
	greeting_generated = true
	greeting_generation_complete.emit(generated_greeting)
	
	# Automatically display the greeting as if NPC initiated conversation
	_auto_display_greeting()


func _on_greeting_failed(error: String):
	"""Called if greeting generation fails."""
	is_generating_greeting = false
	print("[", npc_name, "] Greeting generation failed: ", error, " - using fallback")
	generated_greeting = greeting
	greeting_generated = true
	greeting_generation_complete.emit(generated_greeting)
	
	# Still auto-display even with fallback greeting
	_auto_display_greeting()


func _auto_display_greeting():
	"""Automatically display the greeting in DialogueUI as if NPC initiated conversation."""
	# Mark as talking
	is_talking = true
	current_response = generated_greeting
	
	# Add to conversation history
	if enable_memory:
		conversation_history.append({"role": "assistant", "content": generated_greeting})
	
	# Show DialogueUI WITHOUT opening input (just show NPC text)
	DialogueUI.show_dialogue(self, false)  # false = don't show input
	
	# Emit as dialogue_updated first to trigger typewriter effect
	dialogue_updated.emit(generated_greeting)
	
	# Then emit finished to mark completion
	dialogue_finished.emit(generated_greeting)
	
	# Speak the greeting if both voice and auto-speak are enabled
	if enable_voice and speak_greeting:
		_speak(generated_greeting)
	
	print("[", npc_name, "] Auto-displayed greeting: ", generated_greeting)


# ============ MOOD SYSTEM ============

func set_mood(new_mood: Mood):
	if new_mood == current_mood:
		return
	
	var old_mood = current_mood
	current_mood = new_mood
	
	print("[", npc_name, "] Mood: ", Mood.keys()[old_mood], " -> ", Mood.keys()[new_mood])
	mood_changed.emit(old_mood, new_mood)
	
	# Restart mood decay timer
	if mood_decay_timer and new_mood != default_mood:
		mood_decay_timer.start(mood_decay_time)


func get_mood() -> Mood:
	return current_mood


func get_mood_name() -> String:
	return Mood.keys()[current_mood]


func get_mood_description() -> String:
	return MOOD_DESCRIPTIONS.get(current_mood, "neutral")


func _on_mood_decay():
	if current_mood != default_mood:
		set_mood(default_mood)


## Parse AI response for mood indicators and update mood
func _detect_mood_from_response(response: String):
	if not enable_dynamic_mood:
		return
	
	var lower_response = response.to_lower()
	
	# Simple keyword detection - AI could also explicitly set mood
	if "[mood:angry]" in lower_response or "[angry]" in lower_response:
		set_mood(Mood.ANGRY)
	elif "[mood:happy]" in lower_response or "[happy]" in lower_response:
		set_mood(Mood.HAPPY)
	elif "[mood:sad]" in lower_response or "[sad]" in lower_response:
		set_mood(Mood.SAD)
	elif "[mood:fear]" in lower_response or "[scared]" in lower_response:
		set_mood(Mood.FEARFUL)
	elif "[mood:surprise]" in lower_response or "[surprised]" in lower_response:
		set_mood(Mood.SURPRISED)
	elif "[mood:disgust]" in lower_response or "[disgusted]" in lower_response:
		set_mood(Mood.DISGUSTED)
	elif "[mood:flirty]" in lower_response or "[flirt]" in lower_response:
		set_mood(Mood.FLIRTY)
	elif "[mood:sarcastic]" in lower_response or "[sarcasm]" in lower_response:
		set_mood(Mood.SARCASTIC)
	elif "[mood:tired]" in lower_response or "[exhausted]" in lower_response:
		set_mood(Mood.TIRED)
	elif "[mood:neutral]" in lower_response or "[calm]" in lower_response:
		set_mood(Mood.NEUTRAL)
	else:
		# Infer from punctuation/keywords
		var exclamation_count = response.count("!")
		var question_count = response.count("?")
		var ellipsis_count = response.count("...")
		
		if exclamation_count >= 3 and ("hate" in lower_response or "damn" in lower_response or "hell" in lower_response):
			set_mood(Mood.ANGRY)
		elif exclamation_count >= 2 and ("great" in lower_response or "wonderful" in lower_response or "love" in lower_response):
			set_mood(Mood.HAPPY)
		elif ellipsis_count >= 2 and ("sorry" in lower_response or "miss" in lower_response or "wish" in lower_response):
			set_mood(Mood.SAD)


## Remove mood tags from response before displaying
func _strip_mood_tags(text: String) -> String:
	var result = text
	# Remove [mood:X] and [X] style tags
	var mood_regex = RegEx.new()
	mood_regex.compile("\\[mood:\\w+\\]|\\[(?:angry|happy|sad|scared|surprised|disgusted|flirty|sarcasm|tired|neutral|calm)\\]")
	result = mood_regex.sub(result, "", true)
	return result.strip_edges()

# ============ VOICE SETUP ============

func _setup_voice():
	kokoro_tts = KokoroTTS.new()
	add_child(kokoro_tts)
	
	# Configure voice
	kokoro_tts.voice_id = VOICE_PRESET_IDS.get(voice_preset, 0)
	kokoro_tts.speed = voice_speed
	
	# Connect signals
	kokoro_tts.synthesis_completed.connect(_on_voice_ready)
	kokoro_tts.synthesis_failed.connect(_on_voice_failed)
	
	# Use existing AudioStreamPlayer3D or create new one
	voice_player = get_node_or_null("AudioStreamPlayer3D")
	if not voice_player:
		voice_player = AudioStreamPlayer3D.new()
		voice_player.name = "VoicePlayer"
		add_child(voice_player)
	
	# Configure audio
	voice_player.volume_db = voice_volume_db
	voice_player.max_distance = 50.0
	voice_player.unit_size = 10.0
	voice_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	if not voice_player.finished.is_connected(_on_voice_done):
		voice_player.finished.connect(_on_voice_done)
	
	if kokoro_tts.is_available():
		print("[", npc_name, "] Voice: ", kokoro_tts.get_voice_description(kokoro_tts.voice_id))


func _get_mood_adjusted_speed() -> float:
	if not mood_affects_voice:
		return voice_speed
	
	# Adjust speed based on mood
	match current_mood:
		Mood.HAPPY:
			return voice_speed * 0.9  # Slightly faster
		Mood.ANGRY:
			return voice_speed * 0.85  # Faster, more urgent
		Mood.SAD:
			return voice_speed * 1.2  # Slower
		Mood.FEARFUL:
			return voice_speed * 0.8  # Fast, nervous
		Mood.TIRED:
			return voice_speed * 1.3  # Very slow
		Mood.SURPRISED:
			return voice_speed * 0.85  # Quick reaction
		Mood.SARCASTIC:
			return voice_speed * 1.1  # Drawn out
		_:
			return voice_speed


## Add Kokoro-compatible markers based on mood (ENHANCED with ProsodyAnalyzer)
func _add_mood_markers(text: String) -> String:
	if not mood_affects_voice:
		return text
	
	# Use ProsodyAnalyzer for intelligent enhancement
	var enhanced = ProsodyAnalyzer.enhance_text(
		text,
		current_mood,
		{"personality": npc_personality}  # Optional personality traits
	)
	
	return enhanced

# ============ VISION SETUP ============

func _detect_initial_room():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	var shape = SphereShape3D.new()
	shape.radius = 0.1
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 0
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_shape(query, 10)
	
	for result in results:
		var area = result.collider
		if area is Area3D and area.has_method("get_room_name"):
			current_room = area.get_room_name()
			RoomManager.set_npc_room(npc_name, current_room)
			return


func _setup_vision():
	vision_viewport = get_node_or_null("AnimeBoy/Camera3D/SubViewport")
	
	if not vision_viewport:
		vision_viewport = SubViewport.new()
		vision_viewport.name = "VisionViewport"
		vision_viewport.size = Vector2i(vision_resolution, vision_resolution)
		vision_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vision_viewport)
	else:
		vision_viewport.size = Vector2i(vision_resolution, vision_resolution)
	
	npc_camera = get_node_or_null("AnimeBoy/Camera3D")
	
	if npc_camera:
		var viewport_camera = Camera3D.new()
		viewport_camera.fov = npc_camera.fov
		viewport_camera.transform = npc_camera.transform
		vision_viewport.add_child(viewport_camera)
	else:
		push_warning(npc_name, " vision enabled but no camera found")
		enable_vision = false


func _process(_delta):
	if enable_vision and vision_viewport and npc_camera:
		var viewport_camera = vision_viewport.get_child(0) as Camera3D
		if viewport_camera:
			viewport_camera.global_transform = npc_camera.global_transform

# ============ AI PROVIDER SETUP ============

func _setup_provider():
	using_groq = AIManager.is_groq()
	
	if using_groq:
		_setup_groq()
	else:
		_setup_local()


func _setup_local():
	if chat_node:
		chat_node.model_node = AIManager.llm_model
		chat_node.system_prompt = system_prompt
		
		if groq_provider:
			_disconnect_groq_signals()
		
		if not chat_node.response_updated.is_connected(_on_response_token):
			chat_node.response_updated.connect(_on_response_token)
		if not chat_node.response_finished.is_connected(_on_response_complete):
			chat_node.response_finished.connect(_on_response_complete)
		
		chat_node.start_worker()


func _setup_groq():
	groq_provider = AIManager.get_chat_provider()
	
	if groq_provider:
		_connect_groq_signals()


func _connect_groq_signals():
	if groq_provider:
		if not groq_provider.response_updated.is_connected(_on_groq_response_updated):
			groq_provider.response_updated.connect(_on_groq_response_updated)
		if not groq_provider.response_finished.is_connected(_on_groq_response_finished):
			groq_provider.response_finished.connect(_on_groq_response_finished)
		if not groq_provider.request_failed.is_connected(_on_groq_request_failed):
			groq_provider.request_failed.connect(_on_groq_request_failed)


func _disconnect_groq_signals():
	if groq_provider:
		if groq_provider.response_updated.is_connected(_on_groq_response_updated):
			groq_provider.response_updated.disconnect(_on_groq_response_updated)
		if groq_provider.response_finished.is_connected(_on_groq_response_finished):
			groq_provider.response_finished.disconnect(_on_groq_response_finished)
		if groq_provider.request_failed.is_connected(_on_groq_request_failed):
			groq_provider.request_failed.disconnect(_on_groq_request_failed)


func _on_provider_changed(_provider):
	_setup_provider()

# ============ SYSTEM PROMPT ============

func build_system_prompt() -> String:
	var prompt = """You are {name}, an NPC in an immersive game.

# CRITICAL RULES:
1. Keep responses SHORT: {max_length} maximum
2. Speak naturally - NO lists, NO explanations
3. Stay in character - you are NOT an AI assistant
4. NEVER say "How can I help you"
5. React to what the player says
6. SPEAK ONLY - No action descriptions
7. BANNED: *smiles*, (laughs), [grins], *nods* or ANY similar formatting
8. Express emotion through WORDS: Say "Hah!" not (laughs)

# MOOD SYSTEM:
Your current mood is: {mood_name} ({mood_desc})
{mood_style}

You CAN change your mood during conversation by including a mood tag like [mood:angry] or [mood:happy] at the END of your response (it will be hidden from the player).
Available moods: angry, happy, sad, scared, surprised, disgusted, flirty, sarcasm, tired, neutral

Example with mood change:
Player: "Your shop is garbage!"
You: "Excuse me?! Get out of my shop! [mood:angry]"
"""

	if enable_vision:
		prompt += """
# VISION:
You see through YOUR OWN EYES in real-time.
{player_appearance}
React naturally to what you observe.
"""

	if enable_memory:
		prompt += """
# MEMORY:
Remember what has been said. Stay consistent. Track who says what.
"""

	prompt += """
# YOUR CHARACTER:
Name: {name}
Personality: {personality}
Background: {background}
Goals: {goals}
Knowledge: {knowledge}

# WORLD CONTEXT:
{world_lore}
Location: {location_lore}

# SPATIAL CONTEXT:
{spatial_context}

Speak naturally as {name} would. Your mood affects HOW you say things."""

	return prompt.format({
		"name": npc_name,
		"max_length": max_response_length,
		"mood_name": Mood.keys()[current_mood],
		"mood_desc": get_mood_description(),
		"mood_style": MOOD_SPEECH_STYLES.get(current_mood, ""),
		"personality": npc_personality,
		"background": npc_background,
		"goals": npc_goals,
		"knowledge": npc_knowledge,
		"npc_appearance": npc_appearance,
		"player_appearance": player_appearance,
		"world_lore": WorldLore.WORLD_LORE,
		"location_lore": WorldLore.get_location_lore(npc_location),
		"spatial_context": _build_spatial_context()
	})


func _build_spatial_context() -> String:
	var context = ""
	
	var npc_room = RoomManager.get_npc_room(npc_name)
	if npc_room != "unknown":
		context += "You are in: " + npc_room + "\n"
	
	var player_room = RoomManager.get_player_room()
	if player_room != "unknown":
		if player_room == npc_room:
			context += "The player is here with you.\n"
		else:
			context += "The player is in: " + player_room + "\n"
	
	if RoomManager.player_just_changed_rooms():
		var prev_room = RoomManager.get_player_previous_room()
		context += "The player just moved from " + prev_room + ".\n"
	
	if context.is_empty():
		context = "Location unknown.\n"
	
	return context

# ============ CONVERSATION ============

func start_conversation():
	"""Called when player presses Enter to talk to NPC."""
	is_talking = true
	
	if enable_forgetting and forget_timer:
		forget_timer.stop()
	
	# Show DialogueUI
	DialogueUI.show_dialogue(self)
	
	# If greeting was already auto-displayed, don't show it again
	# Just open the input field for player to type
	if greeting_generated:
		# Greeting already shown, just emit empty to open input
		dialogue_finished.emit("")
	else:
		# No greeting generated yet (shouldn't happen if generate_greeting_on_start is true)
		# Use fallback greeting
		var greeting_to_use = greeting
		
		if enable_memory:
			conversation_history.append({"role": "assistant", "content": greeting_to_use})
		
		current_response = greeting_to_use
		dialogue_finished.emit(greeting_to_use)
		
		if speak_greeting:
			_speak(greeting_to_use)


func end_conversation():
	is_talking = false
	
	if enable_forgetting and forget_timer:
		forget_timer.start(forget_delay)


func talk_to_npc(message: String):
	if enable_memory:
		conversation_history.append({"role": "user", "content": message})
		trim_conversation_history()
	
	current_response = ""
	
	# Rebuild system prompt with current mood
	system_prompt = build_system_prompt()
	
	if using_groq:
		_send_to_groq(message)
	else:
		_send_to_local(message)


func _send_to_local(message: String):
	chat_node.system_prompt = system_prompt
	chat_node.ask(message)


func _send_to_groq(message: String):
	if not groq_provider:
		dialogue_finished.emit("[Error: Groq provider not available]")
		return
	
	groq_provider.set_system_prompt(system_prompt)
	
	var vision_base64 = ""
	if enable_vision and _should_capture_vision():
		vision_base64 = await _capture_vision()
	
	var history_to_send = conversation_history.duplicate()
	if history_to_send.size() > 0:
		history_to_send.pop_back()
	
	groq_provider.ask(message, history_to_send, vision_base64)


func _should_capture_vision() -> bool:
	if not enable_vision or not vision_viewport:
		return false
	
	if vision_capture_interval == 0.0:
		return true
	
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_vision_capture_time >= vision_capture_interval


func _capture_vision() -> String:
	if not vision_viewport:
		return ""
	
	last_vision_capture_time = Time.get_ticks_msec() / 1000.0
	await RenderingServer.frame_post_draw
	
	var viewport_texture = vision_viewport.get_texture()
	var image = viewport_texture.get_image()
	
	if not image:
		return ""
	
	var png_bytes = image.save_png_to_buffer()
	cached_vision_base64 = Marshalls.raw_to_base64(png_bytes)
	
	return cached_vision_base64

# ============ RESPONSE CALLBACKS ============

func _on_response_token(token: String):
	current_response += token
	var cleaned = current_response
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	cleaned = _strip_mood_tags(cleaned)
	dialogue_updated.emit(cleaned)


func _on_response_complete(full_response: String):
	_process_response(full_response)


func _on_groq_response_updated(text: String):
	current_response = text
	var cleaned = text
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	cleaned = _strip_mood_tags(cleaned)
	dialogue_updated.emit(cleaned)


func _on_groq_response_finished(full_response: String):
	_process_response(full_response)


func _on_groq_request_failed(error: String):
	dialogue_finished.emit("[Error: " + error + "]")


func _process_response(full_response: String):
	# Detect and apply mood from response
	_detect_mood_from_response(full_response)
	
	# Clean response
	var cleaned = full_response
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	cleaned = _strip_mood_tags(cleaned)
	
	if enable_memory:
		conversation_history.append({"role": "assistant", "content": cleaned})
		trim_conversation_history()
	
	current_response = cleaned
	dialogue_finished.emit(cleaned)
	
	# Speak with mood-affected voice
	_speak(cleaned)

# ============ VOICE SYNTHESIS ============

func _speak(text: String):
	if not enable_voice or not kokoro_tts:
		return
	
	if text.begins_with("[Error"):
		return
	
	if text.strip_edges().is_empty():
		return
	
	if not kokoro_tts.is_available():
		return
	
	# Stop previous voice only when NEW audio is ready to play
	if voice_player and voice_player.playing:
		voice_player.stop()
		is_speaking = false
		print("[", npc_name, "] Interrupted previous speech - new audio ready")
	
	if kokoro_tts.is_busy():
		return
	
	# Apply voice settings
	kokoro_tts.voice_id = VOICE_PRESET_IDS.get(voice_preset, 0)
	kokoro_tts.speed = _get_mood_adjusted_speed()
	
	# Add mood markers to text
	var tts_text = _add_mood_markers(text)
	
	kokoro_tts.synthesize(tts_text)


func _on_voice_ready(audio: AudioStreamWAV):
	if not voice_player:
		return
	
	voice_player.stream = audio
	voice_player.play()
	is_speaking = true
	voice_started.emit()


func _on_voice_failed(error: String):
	print("[", npc_name, "] Voice error: ", error)
	is_speaking = false


func _on_voice_done():
	is_speaking = false
	voice_finished.emit()


func is_currently_speaking() -> bool:
	return is_speaking


func stop_speaking():
	"""Manual stop - only use if absolutely necessary"""
	if voice_player and voice_player.playing:
		voice_player.stop()
		is_speaking = false

# ============ MEMORY ============

func trim_conversation_history():
	if not enable_memory:
		return
		
	var max_messages = max_history_turns * 2
	if conversation_history.size() > max_messages:
		var to_remove = conversation_history.size() - max_messages
		for i in range(to_remove):
			conversation_history.pop_front()


func reset_conversation():
	conversation_history.clear()
	set_mood(default_mood)


# ============ RESPONSE CLEANING ============

func clean_response(text: String) -> String:
	var cleaned = text
	
	if remove_parentheses:
		var regex_parens = RegEx.new()
		regex_parens.compile("\\([^)]*\\)")
		cleaned = regex_parens.sub(cleaned, "", true)
	
	if remove_asterisks:
		var regex_asterisks = RegEx.new()
		regex_asterisks.compile("\\*[^*]*\\*")
		cleaned = regex_asterisks.sub(cleaned, "", true)
	
	if remove_brackets:
		var regex_brackets = RegEx.new()
		regex_brackets.compile("\\[[^\\]]*\\]")
		cleaned = regex_brackets.sub(cleaned, "", true)
	
	cleaned = cleaned.strip_edges()
	while "  " in cleaned:
		cleaned = cleaned.replace("  ", " ")
	
	cleaned = cleaned.replace(" .", ".")
	cleaned = cleaned.replace(" ,", ",")
	cleaned = cleaned.replace(" !", "!")
	cleaned = cleaned.replace(" ?", "?")
	
	return cleaned
