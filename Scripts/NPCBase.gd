extends CharacterBody3D

## Enhanced NPC with mood system, expressive TTS, AUTO-GENERATED GREETINGS, and ACTIONS
## Generates unique greeting on spawn using AI based on character context
## Can now perform animations, navigation, and head tracking via LLM commands

# ============ ENUMS ============

# Emotions are now 0-100 intensity values (see Emotion System group)

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

enum TTSProvider {
	LOCAL_KOKORO,  ## Local Kokoro TTS (free, offline)
	AZURE,         ## Azure Cognitive Services (cloud, expressive)
}

enum AzureVoice {
	# American Female - Expressive
	JENNY,
	ARIA,
	SARA,
	# American Male - Expressive
	GUY,
	DAVIS,
	TONY,
	JASON,
	# British
	SONIA_UK,
	RYAN_UK,
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
@export var player_name: String = "" ## The player's name (leave empty for generic "the player")
@export_multiline var player_appearance: String = "The player is a green humanoid figure"

# Emotion System (0-100 intensity for each emotion)
@export_group("Emotion System")
@export_range(0, 100, 1) var happy: int = 0 ## Cheerfulness, joy
@export_range(0, 100, 1) var angry: int = 0 ## Irritation, rage
@export_range(0, 100, 1) var sad: int = 0 ## Melancholy, sadness
@export_range(0, 100, 1) var fearful: int = 0 ## Anxiety, fear
@export_range(0, 100, 1) var disgusted: int = 0 ## Repulsion, distaste
@export_range(0, 100, 1) var surprised: int = 0 ## Shock, amazement
@export_range(0, 100, 1) var flirty: int = 0 ## Playfulness, attraction
@export_range(0, 100, 1) var tired: int = 0 ## Exhaustion, fatigue
@export_range(0, 100, 1) var trust: int = 50 ## Trust/comfort with player (affects patience)
@export_range(0, 100, 1) var hostility: int = 0 ## Hostility level - attacks at 100 (low trust increases gain)
@export var enable_dynamic_emotions: bool = true ## AI can change emotions based on conversation
@export var enable_emotion_decay: bool = true ## Emotions gradually return to baseline (disable to keep emotions permanent)
@export var emotion_decay_rate: float = 5.0 ## Points per second emotions decay toward baseline
@export var emotion_decay_time: float = 120.0 ## Seconds before emotions return to baseline

# Patience system
@export_group("Patience System")
@export var enable_patience: bool = true ## React to being ignored during conversation
@export_range(5.0, 60.0, 1.0, "suffix:seconds") var base_patience_time: float = 15.0 ## Base time before reacting to silence
@export_range(0.0, 2.0, 0.1) var trust_patience_multiplier: float = 1.5 ## How much trust extends patience (multiplier)

# Hostility system
@export_group("Hostility System")
@export var enable_hostility: bool = true ## Can become hostile and attack player
@export_range(5, 50, 5) var attack_damage: int = 25 ## Damage per attack
@export_range(1.0, 5.0, 0.5, "suffix:seconds") var attack_cooldown: float = 2.0 ## Time between attacks
@export_range(1.0, 10.0, 0.5, "suffix:meters") var attack_range: float = 3.0 ## Max distance to attack
@export var require_same_room_for_attack: bool = true ## Must be in same room to attack

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
@export var tts_provider: TTSProvider = TTSProvider.LOCAL_KOKORO ## TTS engine to use
@export_range(0.5, 1.5, 0.05) var voice_speed: float = 1.0 ## Base speed (lower = faster)
@export_range(-20.0, 6.0, 0.5, "suffix:dB") var voice_volume_db: float = 0.0
@export var mood_affects_voice: bool = true ## Mood changes voice speed/tone

@export_subgroup("Kokoro (Local TTS)")
@export var voice_preset: VoicePreset = VoicePreset.AM_ADAM ## Voice for local Kokoro TTS

@export_subgroup("Azure (Cloud TTS)")
@export var azure_voice: AzureVoice = AzureVoice.GUY ## Voice for Azure cloud TTS
@export var use_azure_emotion_styles: bool = true ## Use Azure's expressive styles based on emotions

@export_subgroup("RVC Voice Cloning")
@export var enable_rvc: bool = false ## Post-process TTS through RVC voice conversion
@export_file("*.pth") var rvc_model_path: String = "" ## Drag .pth model file here
@export_file("*.index") var rvc_index_path: String = "" ## Drag .index file here (optional but recommended)
@export_range(-12, 12, 1) var rvc_pitch_shift: int = 0 ## Pitch shift in semitones
@export_enum("crepe-tiny:Fast", "crepe:Balanced", "rmvpe:Quality") var rvc_quality: String = "crepe-tiny" ## Speed vs quality trade-off
@export_range(64, 512, 64) var rvc_hop_length: int = 256 ## Higher = faster, lower = more precise pitch tracking
@export var rvc_use_gpu: bool = true ## Use GPU acceleration if available (requires CUDA-enabled PyTorch)
@export_range(-1, 8, 1) var rvc_cuda_device: int = -1 ## GPU device index (-1 = auto-detect best compatible)

# Text cleaning settings
@export_group("Response Filtering")
@export var remove_action_markers: bool = true
@export var remove_asterisks: bool = true
@export var remove_parentheses: bool = true
@export var remove_brackets: bool = true

# Action System settings
@export_group("Action System")
@export var enable_actions: bool = true ## Enable LLM-controlled actions (animations, movement, head tracking)
@export var auto_look_at_player: bool = true ## Automatically look at player when talking

# Autonomous Behavior settings
@export_group("Autonomous Behavior")
@export var enable_autonomous_behavior: bool = false ## Let NPC decide actions on its own
@export_range(5.0, 120.0, 5.0, "suffix:seconds") var autonomous_decision_interval: float = 30.0 ## How often NPC makes autonomous decisions
@export var autonomous_only_when_idle: bool = true ## Only make autonomous decisions when not in conversation
@export_range(0.0, 1.0, 0.05) var spontaneous_action_chance: float = 0.2 ## Probability of spontaneous actions during conversation (0.2 = 20%)
@export_multiline var npc_current_goal: String = "" ## Current objective - influences behavior and dialogue. Leave empty for no specific goal.

# ============ INTERNAL STATE ============

# References
@onready var chat_node = $ChatNode
@onready var action_controller: NPCActionController = $ActionController
@onready var action_parser: NPCActionParser = $ActionParser

# Vision references (set dynamically in _setup_vision)
var vision_viewport: SubViewport = null
var npc_camera: Camera3D = null
@export var look_at_modifier_3d: LookAtModifier3D
@export var nav_agent: NavigationAgent3D
@export var non_ai_vision: Area3D

var SPEED = 1
var nav_target: Vector3

# State
var is_talking = false
var current_response = ""
var conversation_history: Array = []
var forget_timer: Timer
var system_prompt: String = ""

# Greeting generation state
var generated_greeting: String = ""
var greeting_generated: bool = false
var is_generating_greeting: bool = false

# Current emotions (dynamic values that change)
var current_emotions: Dictionary = {
	"happy": 0,
	"angry": 0,
	"sad": 0,
	"fearful": 0,
	"disgusted": 0,
	"surprised": 0,
	"flirty": 0,
	"tired": 0,
	"trust": 50
}

# Baseline emotions (from Inspector, what emotions decay toward)
var baseline_emotions: Dictionary = {}

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
var azure_tts: AzureTTS = null
var rvc_processor: RVCProcessor = null
var voice_player: AudioStreamPlayer3D = null
var is_speaking: bool = false
var _pending_rvc_audio: AudioStreamWAV = null  # Audio waiting for RVC processing

# Action system state
var pending_actions: Array = []
var is_executing_action: bool = false

# Autonomous behavior state
var autonomous_timer: Timer = null
var is_making_autonomous_decision: bool = false
var is_autonomous_text: bool = false  # Track if current dialogue is from autonomous action
var is_patience_response: bool = false  # Track if current dialogue is from patience timeout

# Patience system state
var patience_timer: Timer = null
var is_waiting_for_response: bool = false

# Hostility system state
var is_hostile: bool = false
var can_attack: bool = true
var attack_timer: Timer = null
var player_ref: Node3D = null
var is_chasing: bool = false

# ============ SIGNALS ============

signal dialogue_updated(text: String)
signal dialogue_finished(text: String)
signal voice_started()
signal voice_finished()
signal emotions_changed(emotions: Dictionary)
signal greeting_generation_complete(greeting_text: String)
signal action_executed(action_name: String)

# ============ EMOTION DESCRIPTORS ============

const EMOTION_DESCRIPTORS: Dictionary = {
	"happy": "cheerful and upbeat",
	"angry": "irritated and aggressive",
	"sad": "melancholic and downcast",
	"fearful": "nervous and anxious",
	"disgusted": "repulsed and dismissive",
	"surprised": "shocked and bewildered",
	"flirty": "playful and suggestive",
	"tired": "exhausted and sluggish",
	"trust": "trusting and comfortable",
	"hostility": "hostile and dangerous",
	# Voice style emotions (for Azure TTS expressive styles)
	"shouting": "yelling loudly",
	"whispering": "speaking very quietly",
	"hopeful": "optimistic and expectant",
	"excited": "energetic and thrilled"
}

const EMOTION_SPEECH_STYLES: Dictionary = {
	"happy": "Speak with enthusiasm! Use upbeat language!",
	"angry": "Speak curtly. Short sentences. Show irritation.",
	"sad": "Speak slowly... with pauses... trailing off sometimes...",
	"fearful": "Speak nervously - quick, stuttering, uncertain...",
	"disgusted": "Speak with disdain. Show your contempt.",
	"surprised": "What?! Speak with shock! Express disbelief!",
	"flirty": "Speak playfully~ with a teasing tone~",
	"tired": "Speak... slowly... like everything... is an effort...",
	"trust": "Speak warmly and openly, like to a friend.",
	"hostility": "Speak with menace and threat. Use intimidating language.",
	# Voice style emotions (for Azure TTS)
	"shouting": "SPEAK LOUDLY! YELL! RAISE YOUR VOICE!",
	"whispering": "speak very quietly... almost inaudible... secrets...",
	"hopeful": "Speak with optimism and anticipation!",
	"excited": "Speak with HIGH ENERGY! Fast and thrilled!"
}

# Voice ID mapping (Kokoro)
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

# Azure voice name mapping
const AZURE_VOICE_NAMES: Dictionary = {
	AzureVoice.JENNY: "en-US-JennyNeural",
	AzureVoice.ARIA: "en-US-AriaNeural",
	AzureVoice.SARA: "en-US-SaraNeural",
	AzureVoice.GUY: "en-US-GuyNeural",
	AzureVoice.DAVIS: "en-US-DavisNeural",
	AzureVoice.TONY: "en-US-TonyNeural",
	AzureVoice.JASON: "en-US-JasonNeural",
	AzureVoice.SONIA_UK: "en-GB-SoniaNeural",
	AzureVoice.RYAN_UK: "en-GB-RyanNeural",
}

# ============ LIFECYCLE ============

func _ready():
	# Initialize emotions from Inspector values
	_initialize_emotions()
	
	_detect_initial_room()
	
	if enable_vision:
		_setup_vision()
	
	if enable_voice:
		_setup_voice()
	
	# Setup action system BEFORE building system prompt
	if enable_actions:
		_setup_actions()
	
	system_prompt = build_system_prompt()
	_setup_provider()
	AIManager.provider_changed.connect(_on_provider_changed)
	
	# Forget timer
	if enable_forgetting:
		forget_timer = Timer.new()
		forget_timer.one_shot = true
		forget_timer.timeout.connect(reset_conversation)
		add_child(forget_timer)
	
	# Emotion decay timer (processes gradual decay)
	if enable_dynamic_emotions:
		var emotion_timer = Timer.new()
		emotion_timer.name = "EmotionDecayTimer"
		emotion_timer.wait_time = 1.0  # Update every second
		emotion_timer.timeout.connect(_process_emotion_decay)
		add_child(emotion_timer)
		emotion_timer.start()
	
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
	
	print(npc_name, " ready! Emotions: ", _get_dominant_emotions(), ", Voice: ", VoicePreset.keys()[voice_preset], ", Actions: ", enable_actions)
	
	# Setup autonomous behavior
	if enable_autonomous_behavior:
		_setup_autonomous_behavior()
	
	# Setup patience timer
	if enable_patience:
		patience_timer = get_node_or_null("Patience_Timer")
		if patience_timer:
			patience_timer.one_shot = true
			patience_timer.timeout.connect(_on_patience_timeout)
			print("[DEBUG] [", npc_name, "] Patience timer found and connected! (base: ", base_patience_time, "s)")
		else:
			push_warning("[", npc_name, "] Patience enabled but no Patience_Timer node found!")
	else:
		print("[DEBUG] [", npc_name, "] Patience system disabled (enable_patience = false)")
	
	# Setup hostility system
	if enable_hostility:
		attack_timer = Timer.new()
		attack_timer.name = "AttackTimer"
		attack_timer.one_shot = true
		add_child(attack_timer)
		
		# Try to find player
		player_ref = get_tree().get_first_node_in_group("player")
		if player_ref:
			print("[", npc_name, "] Hostility system enabled (Attacks at 100 hostility)")
		else:
			push_warning("[", npc_name, "] Hostility enabled but player not found in 'player' group!")
	
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

# ============ ACTION SYSTEM SETUP ============

func _setup_actions():
	"""Setup the action controller and parser for LLM-controlled actions."""
	if not action_controller:
		push_warning("[", npc_name, "] ActionController not found! Add an ActionController node to the NPC.")
		enable_actions = false
		return
	
	if not action_parser:
		push_warning("[", npc_name, "] ActionParser not found! Add an ActionParser node to the NPC.")
		enable_actions = false
		return
	
	# Connect action parser signals
	action_parser.action_detected.connect(_on_action_detected)
	
	# Connect action controller signals
	if action_controller.has_signal("action_completed"):
		action_controller.action_completed.connect(_on_action_completed)
	
	print("[", npc_name, "] Action system initialized")


func _on_action_detected(action_dict: Dictionary):
	"""Called when the action parser detects an action in LLM response."""
	if not enable_actions:
		return
	
	print("[", npc_name, "] 🎬 Action detected: ", action_dict)
	
	# Queue the action for execution
	pending_actions.append(action_dict)
	
	# Start executing if not already doing so
	if not is_executing_action:
		_execute_next_action()


func _execute_next_action():
	"""Execute the next action in the queue."""
	if pending_actions.is_empty():
		is_executing_action = false
		return
	
	is_executing_action = true
	var action = pending_actions.pop_front()
	
	print("[", npc_name, "] ▶️  Executing: ", action)
	
	if action_controller:
		var success = action_controller.execute_action(action)
		
		if success:
			action_executed.emit(action.get("action", "unknown"))
		else:
			push_warning("[", npc_name, "] Action failed: ", action)
	
	# Execute next action
	_execute_next_action()


func _on_action_completed(action_name: String):
	"""Called when an action completes."""
	print("[", npc_name, "] ✅ Action completed: ", action_name)

# ============ AUTONOMOUS BEHAVIOR ============

func _setup_autonomous_behavior():
	"""Initialize autonomous behavior system."""
	if not enable_autonomous_behavior:
		return
	
	autonomous_timer = Timer.new()
	autonomous_timer.name = "AutonomousTimer"
	autonomous_timer.wait_time = autonomous_decision_interval
	autonomous_timer.timeout.connect(_on_autonomous_timer_timeout)
	add_child(autonomous_timer)
	autonomous_timer.start()
	
	print("[", npc_name, "] Autonomous behavior enabled (every ", autonomous_decision_interval, "s)")
	
	if not npc_current_goal.is_empty():
		print("[", npc_name, "] 🎯 Current goal: ", npc_current_goal)


func _on_autonomous_timer_timeout():
	"""Timer callback to make autonomous decisions."""
	if not enable_autonomous_behavior:
		return
	
	# Skip if already busy
	if is_making_autonomous_decision:
		return
	
	# Skip if currently speaking (don't interrupt audio)
	if is_speaking:
		print("[", npc_name, "] ⏸️  Skipping autonomous decision - currently speaking")
		return
	
	# Skip if in conversation (if setting is enabled)
	if autonomous_only_when_idle and is_talking:
		return
	
	_make_autonomous_decision()


func _make_autonomous_decision():
	"""Ask the AI to decide what to do next."""
	if is_making_autonomous_decision:
		return
	
	is_making_autonomous_decision = true
	print("[", npc_name, "] 🤔 Making autonomous decision...")
	
	var decision_prompt = _build_autonomous_decision_prompt()
	
	# Use the appropriate provider
	if using_groq:
		await _request_autonomous_decision_groq(decision_prompt)
	else:
		await _request_autonomous_decision_local(decision_prompt)
	
	is_making_autonomous_decision = false


func _build_autonomous_decision_prompt() -> String:
	"""Build prompt for autonomous decision-making with rich context."""
	var prompt = ""
	
	# === IDENTITY & STATE ===
	prompt += "# WHO YOU ARE:\n"
	prompt += "Name: %s\n" % npc_name
	prompt += "Personality: %s\n" % npc_personality
	prompt += "Background: %s\n" % npc_background
	prompt += "Life Goals: %s\n" % npc_goals
	prompt += "Feeling: %s\n" % get_emotion_description()
	
	# === CURRENT GOAL (if set in inspector) ===
	if not npc_current_goal.is_empty():
		prompt += "\n# YOUR CURRENT GOAL:\n"
		prompt += "🎯 %s\n" % npc_current_goal
		prompt += "→ Consider actions that work toward this goal!\n"
	
	# === CURRENT SITUATION ===
	prompt += "\n# YOUR CURRENT SITUATION:\n"
	prompt += "You are in: %s\n" % current_room
	
	# Get available OTHER rooms (excluding current)
	var all_rooms = RoomManager.get_available_room_names()
	var other_rooms = RoomManager.get_other_rooms(current_room)
	
	if all_rooms.size() == 0:
		# NO ROOMS DEFINED - disable all movement
		prompt += "⚠️ MOVEMENT DISABLED: No navigable locations exist in this scene.\n"
		prompt += "DO NOT use [walk_to:...] commands - they will fail!\n"
	elif other_rooms.size() > 0:
		prompt += "Other locations you can go to: %s\n" % ", ".join(other_rooms)
	else:
		prompt += "There are no other rooms to walk to (you're in the only room).\n"
	
	# Current physical state
	if action_controller:
		prompt += action_controller.get_state_description() + "\n"
	
	# === PLAYER INFO ===
	prompt += "\n# THE PLAYER:\n"
	if not player_appearance.is_empty():
		prompt += "Appearance: %s\n" % player_appearance
	
	if RoomManager:
		var player_room = RoomManager.get_player_room()
		if player_room == current_room:
			prompt += "Location: HERE (same room as you)\n"
			prompt += "→ You could interact with them if you want.\n"
		else:
			prompt += "Location: %s (different room)\n" % player_room
			prompt += "→ They can't hear you unless you go there.\n"
	
	# === DECISION FRAMEWORK ===
	prompt += "\n# WHAT YOU CAN DO:\n"
	prompt += "1. NOTHING (stay idle) → respond with empty text\n"
	prompt += "2. GO SOMEWHERE → [walk_to:RoomName] (pick from available locations ONLY)\n"
	prompt += "3. DO AN ANIMATION → [animate:sit], [animate:dance], [animate:idle]\n"
	prompt += "4. SAY SOMETHING ALOUD → VERY RARE - only if someone is present AND you have urgent reason to speak\n"
	
	prompt += "\n# CRITICAL RULES:\n"
	prompt += "• You are ALREADY in %s - do NOT walk_to:%s (that's where you are!)\n" % [current_room, current_room]
	prompt += "• NEVER use [animate:walk] - walking animation plays AUTOMATICALLY when moving\n"
	prompt += "• NEVER narrate ('I see...', 'I notice...', 'I think...')\n"
	prompt += "• NEVER describe your reasoning - just DO or stay silent\n"
	prompt += "• DO NOT SPEAK unless someone is in the same room AND you have urgent reason to talk\n"
	prompt += "• Most people go about their day SILENTLY - speaking to yourself is weird\n"
	prompt += "• STRONG PREFERENCE: Choose physical actions (movement/animation) over speech\n"
	prompt += "• When in doubt, do NOTHING or perform a simple action\n"
	
	prompt += "\n# EXAMPLES:\n"
	prompt += "Doing nothing: (empty response)\n"
	prompt += "Movement: [walk_to:Kitchen]\n"
	prompt += "Animation: [animate:sit]\n"
	prompt += "Combined: [walk_to:Kitchen] [animate:sit]\n"
	prompt += "Speaking (RARE): Hey! You there?\n"
	
	prompt += "\n# BAD (NEVER DO):\n"
	prompt += "❌ 'I see the player.' (narration)\n"
	prompt += "❌ 'I should go to the kitchen.' (meta-thought)\n"
	prompt += "❌ 'I wonder what's happening.' (internal monologue)\n"
	prompt += "❌ 'Hmm...' or 'Let me think...' (speaking to empty room)\n"
	prompt += "❌ '[walk_to:%s]' (you're already here!)\n" % current_room
	prompt += "❌ '[animate:walk]' (walk is automatic, never use it)\n"
	
	prompt += "\nYour response (PREFER: empty, action, or movement - AVOID: speech):"
	
	return prompt


func _request_autonomous_decision_groq(prompt: String):
	"""Request autonomous decision from Groq API."""
	if not groq_provider:
		return
	
	# Mark as autonomous so _process_response won't restart patience timer
	is_autonomous_text = true
	
	# Build message history with system prompt and current request
	var messages = []
	if not system_prompt.is_empty():
		messages.append({"role": "system", "content": system_prompt})
	messages.append({"role": "user", "content": prompt})
	
	# Use ask() method with history
	groq_provider.ask(prompt, messages)
	
	# Wait for response via signal
	var response = await groq_provider.response_finished
	
	# Reset flag after response
	is_autonomous_text = false
	
	if response != "":
		_process_autonomous_decision(response)


func _request_autonomous_decision_local(prompt: String):
	"""Request autonomous decision from local model."""
	if not chat_node:
		return
	
	# Mark as autonomous so _process_response won't restart patience timer
	is_autonomous_text = true
	
	# Create a simple one-shot prompt
	var full_prompt = system_prompt + "\n\nUser: " + prompt + "\nAssistant:"
	
	# Send to local model
	var response = await chat_node.send_prompt(full_prompt)
	
	# Reset flag after response
	is_autonomous_text = false
	
	if response != "":
		_process_autonomous_decision(response)


func _process_autonomous_decision(response: String):
	"""Process the AI's autonomous decision."""
	print("[", npc_name, "] Autonomous decision: ", response)
	
	# Parse for any actions
	var clean_text = response
	if action_parser and enable_actions:
		var parsed = action_parser.parse_response(response)
		clean_text = parsed.text  # Get text without action tags
		
		if parsed.actions.size() > 0:
			print("[", npc_name, "] 🎬 Detected ", parsed.actions.size(), " autonomous action(s)")
			
			# Validate and filter actions
			var valid_actions = []
			for action in parsed.actions:
				if _validate_autonomous_action(action):
					valid_actions.append(action)
				else:
					print("[", npc_name, "] ⚠️ Filtered invalid action: ", action)
			
			# Queue the valid actions
			for action in valid_actions:
				pending_actions.append(action)
			
			# Start executing if not already
			if not is_executing_action and valid_actions.size() > 0:
				_execute_next_action()
	
	# Display the text (without action tags) in DialogueUI
	if clean_text.strip_edges() != "":
		_display_autonomous_text(clean_text)


func _validate_autonomous_action(action: Dictionary) -> bool:
	"""Validate an autonomous action to prevent nonsensical behavior."""
	var action_type = action.get("action", "")
	
	# Block standalone walk animation (walk animation should only play when actually moving)
	if action_type == "play_animation":
		var anim = action.get("animation", "").to_lower().strip_edges()
		# Block any variation of walk animation
		if "walk" in anim:
			print("[", npc_name, "] 🚫 Blocked standalone walk animation: '", anim, "' (should only play when moving)")
			return false
	
	# Check walk_to actions
	if action_type == "walk_to":
		var target = action.get("target", "").strip_edges()
		
		# Block invalid targets like "Player" - NPCs can't walk TO a player
		if target.to_lower() == "player":
			print("[", npc_name, "] 🚫 Blocked walk_to 'Player' - use look_at instead")
			return false
		
		# Get available rooms first
		var available_rooms = RoomManager.get_available_room_names()
		
		# If no rooms are defined in the scene, block ALL walk_to commands
		if available_rooms.size() == 0:
			print("[", npc_name, "] 🚫 Blocked walk_to '", target, "' - no Room nodes defined in scene!")
			print("[", npc_name, "] 💡 Hint: Add Room (Area3D) nodes to the scene and add them to the 'rooms' group")
			return false
		
		# Don't walk to current room (fuzzy match)
		if target.to_lower() == current_room.to_lower() or current_room.to_lower().begins_with(target.to_lower()):
			print("[", npc_name, "] 🚫 Blocked walk_to current room: ", target)
			return false
		
		# Check if target is a valid room (with fuzzy matching)
		var target_valid = false
		var target_lower = target.to_lower()
		for room in available_rooms:
			var room_lower = room.to_lower()
			# Exact match or partial match (e.g., "Storage" matches "Storage Room")
			if room_lower == target_lower or room_lower.begins_with(target_lower) or target_lower in room_lower:
				target_valid = true
				break
		
		if not target_valid:
			print("[", npc_name, "] 🚫 Unknown room target: '", target, "' (available: ", available_rooms, ")")
			return false
	
	return true


func _display_autonomous_text(text: String):
	"""Display autonomous decision text in DialogueUI without affecting patience timer."""
	current_response = text
	
	# Mark this as autonomous text so patience timer won't restart
	is_autonomous_text = true
	
	# Show DialogueUI WITHOUT opening input (just show NPC text)
	DialogueUI.show_dialogue(self, false)  # false = don't show input
	
	# Emit as dialogue_updated to trigger typewriter effect
	dialogue_updated.emit(text)
	
	# Then emit finished to mark completion
	dialogue_finished.emit(text)
	
	# Reset flag
	is_autonomous_text = false
	
	# Speak the text if voice is enabled
	if enable_voice:
		_speak(text)
	
	print("[", npc_name, "] 🗨️  Auto-displayed: \"", text, "\" (patience unaffected)")


# ============ GOAL SYSTEM ============

func get_current_goal() -> String:
	"""Get the current goal (for debug display)."""
	return npc_current_goal


func set_current_goal(new_goal: String):
	"""Change the NPC's current goal at runtime."""
	npc_current_goal = new_goal
	print("[", npc_name, "] 🎯 Goal changed to: ", npc_current_goal)


func clear_goal():
	"""Clear the current goal."""
	npc_current_goal = ""
	print("[", npc_name, "] 🎯 Goal cleared")


# ============ PATIENCE SYSTEM ============

func _start_patience_timer():
	"""Start or restart the patience timer with emotion-adjusted duration."""
	if not patience_timer or not enable_patience:
		print("[DEBUG] [", npc_name, "] _start_patience_timer failed - patience_timer=", patience_timer != null, ", enable_patience=", enable_patience)
		return
	
	# Calculate patience duration based on trust and emotions
	var patience_duration = _calculate_patience_duration()
	
	patience_timer.wait_time = patience_duration
	patience_timer.start()
	
	print("[DEBUG] [", npc_name, "] ⏱️  Patience timer STARTED with ", patience_duration, "s (is_talking=", is_talking, ", is_waiting=", is_waiting_for_response, ")")


func _calculate_patience_duration() -> float:
	"""Calculate how long NPC waits before reacting to silence."""
	var duration = base_patience_time
	
	# Trust increases patience (0-100 trust → 0.5x to trust_patience_multiplier)
	var trust_factor = lerp(0.5, trust_patience_multiplier, current_emotions.get("trust", 50) / 100.0)
	duration *= trust_factor
	
	# Angry/impatient reduces patience
	var anger = current_emotions.get("angry", 0)
	if anger > 30:
		duration *= lerp(1.0, 0.5, (anger - 30) / 70.0)  # 30-100 angry → 1.0x to 0.5x
	
	# Happy/content increases patience slightly
	var happiness = current_emotions.get("happy", 0)
	if happiness > 50:
		duration *= lerp(1.0, 1.2, (happiness - 50) / 50.0)  # 50-100 happy → 1.0x to 1.2x
	
	# Tired reduces patience
	var tiredness = current_emotions.get("tired", 0)
	if tiredness > 40:
		duration *= lerp(1.0, 0.7, (tiredness - 40) / 60.0)  # 40-100 tired → 1.0x to 0.7x
	
	return clamp(duration, 3.0, 120.0)  # Min 3s, max 2 minutes


func _on_patience_timeout():
	"""Called when player hasn't responded - NPC reacts to being ignored."""
	print("[DEBUG] [", npc_name, "] ⏰ _on_patience_timeout FIRED! is_waiting=", is_waiting_for_response, ", is_talking=", is_talking)
	
	# Only check if we're waiting for response - is_talking is false after dialogue closes, which is fine!
	if not is_waiting_for_response:
		print("[DEBUG] [", npc_name, "] Patience timeout BLOCKED - not waiting for response")
		return
	
	print("[DEBUG] [", npc_name, "] ⏰ Patience expired - generating ignore response")
	
	# Being ignored damages trust and happiness
	adjust_emotion("trust", -5)
	adjust_emotion("happy", -5)
	print("[", npc_name, "] 💔 Feeling ignored - trust and happiness decreased")
	
	# Make sure DialogueUI will display this response
	# Force-connect if not already connected (happens after close_dialogue)
	if DialogueUI:
		# Ensure DialogueUI is tracking this NPC
		if not DialogueUI.current_npc:
			# Re-establish connection temporarily for this response
			DialogueUI.current_npc = self
			if not dialogue_finished.is_connected(DialogueUI._on_dialogue_finished):
				dialogue_finished.connect(DialogueUI._on_dialogue_finished)
			if not dialogue_updated.is_connected(DialogueUI._on_dialogue_updated):
				dialogue_updated.connect(DialogueUI._on_dialogue_updated)
			# Connect voice signals for proper sync
			if not voice_started.is_connected(DialogueUI._on_npc_voice_started):
				voice_started.connect(DialogueUI._on_npc_voice_started)
			if not voice_finished.is_connected(DialogueUI._on_npc_voice_finished):
				voice_finished.connect(DialogueUI._on_npc_voice_finished)
	
	# Build a prompt that makes the AI react to silence
	var player_ref = player_name if not player_name.is_empty() else "the player"
	var silence_prompt = "%s hasn't said anything to you in a while. Are they ignoring you? React naturally based on your personality and emotions." % player_ref
	
	# Add to memory as a system observation
	if enable_memory:
		conversation_history.append({"role": "system", "content": "[%s is silent and hasn't responded]" % player_ref})
	
	# Treat this like a message being sent (so dialogue system handles it properly)
	current_response = ""
	system_prompt = build_system_prompt()
	
	# Mark this as a patience-triggered response so timer won't restart automatically
	is_patience_response = true
	
	# Send the prompt as if player had sent a message
	if using_groq:
		_send_to_groq(silence_prompt)
	else:
		_send_to_local(silence_prompt)
	
	# Note: Don't restart timer here - let it restart when AI finishes responding
	# This prevents spamming if AI is slow to respond


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
	
	# Remove emotion tags if present
	cleaned = _strip_emotion_tags(cleaned)
	
	# Parse and remove action tags (greeting shouldn't have actions, but just in case)
	if enable_actions and action_parser:
		var parsed = action_parser.parse_response(cleaned)
		cleaned = parsed["text"]
	
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


# ============ EMOTION SYSTEM ============

func _initialize_emotions():
	"""Copy Inspector emotion values to current and baseline"""
	baseline_emotions = {
		"happy": happy,
		"angry": angry,
		"sad": sad,
		"fearful": fearful,
		"disgusted": disgusted,
		"surprised": surprised,
		"flirty": flirty,
		"tired": tired,
		"trust": trust,
		"hostility": hostility,
		# Voice style emotions (no Inspector export, always start at 0)
		"shouting": 0,
		"whispering": 0,
		"hopeful": 0,
		"excited": 0
	}
	current_emotions = baseline_emotions.duplicate()
	print("[", npc_name, "] Emotions initialized: ", _get_dominant_emotions())


func set_emotion(emotion_name: String, intensity: int):
	"""Set a specific emotion intensity (0-100)"""
	if not current_emotions.has(emotion_name):
		push_warning("Unknown emotion: ", emotion_name)
		return
	
	intensity = clamp(intensity, 0, 100)
	var old_value = current_emotions[emotion_name]
	current_emotions[emotion_name] = intensity
	
	if old_value != intensity:
		print("[", npc_name, "] ", emotion_name.capitalize(), ": ", old_value, " -> ", intensity)
		emotions_changed.emit(current_emotions.duplicate())


func adjust_emotion(emotion_name: String, delta: int):
	"""Adjust emotion by delta amount"""
	if not current_emotions.has(emotion_name):
		return
	
	var new_value = clamp(current_emotions[emotion_name] + delta, 0, 100)
	set_emotion(emotion_name, new_value)


func _process_emotion_decay(delta: float = 1.0):
	"""Gradually decay emotions toward baseline"""
	if not enable_emotion_decay:
		return  # Decay disabled, emotions stay permanent
	
	var changed = false
	
	for emotion in current_emotions.keys():
		var current = current_emotions[emotion]
		var baseline = baseline_emotions[emotion]
		
		if current != baseline:
			var decay_amount = emotion_decay_rate * delta
			
			if current > baseline:
				current_emotions[emotion] = max(current - decay_amount, baseline)
				changed = true
			elif current < baseline:
				current_emotions[emotion] = min(current + decay_amount, baseline)
				changed = true
	
	if changed:
		emotions_changed.emit(current_emotions.duplicate())


func _get_dominant_emotions(threshold: int = 20) -> Array:
	"""Get list of emotions above threshold"""
	var dominant = []
	for emotion in current_emotions.keys():
		if current_emotions[emotion] >= threshold:
			dominant.append({
				"name": emotion,
				"intensity": current_emotions[emotion]
			})
	
	# Sort by intensity
	dominant.sort_custom(func(a, b): return a.intensity > b.intensity)
	return dominant


func get_emotion_description() -> String:
	"""Build natural language description of current emotions"""
	var dominant = _get_dominant_emotions(20)
	
	if dominant.is_empty():
		return "calm and neutral"
	
	var parts = []
	for em in dominant:
		var intensity_word = ""
		if em.intensity >= 80:
			intensity_word = "very "
		elif em.intensity >= 50:
			intensity_word = "quite "
		elif em.intensity >= 20:
			intensity_word = "slightly "
		
		parts.append(intensity_word + EMOTION_DESCRIPTORS[em.name])
	
	if parts.size() == 1:
		return parts[0]
	elif parts.size() == 2:
		return parts[0] + " and " + parts[1]
	else:
		return ", ".join(parts.slice(0, -1)) + ", and " + parts[-1]


func _detect_emotions_from_response(response: String):
	"""Parse AI response for emotion tags and update emotions"""
	if not enable_dynamic_emotions:
		print("[", npc_name, "] 💭 Dynamic emotions disabled, skipping detection")
		return
	
	# Parse emotion tags: [emotion:happy:75] or [happy:50] (case-insensitive)
	var emotion_regex = RegEx.new()
	emotion_regex.compile("(?i)\\[(?:emotion:)?(\\w+):(\\d+)\\]")
	
	var matches = emotion_regex.search_all(response)
	
	if matches.is_empty():
		print("[", npc_name, "] 💭 No emotion tags found in response")
	else:
		print("[", npc_name, "] 💭 Found ", matches.size(), " emotion tag(s) in response")
	
	for match in matches:
		var emotion_name = match.get_string(1).to_lower()
		var raw_intensity = match.get_string(2).to_int()
		
		# Dampen emotion changes to prevent wild swings (reduce by 40%)
		var intensity = int(raw_intensity * 0.6)
		
		if current_emotions.has(emotion_name):
			print("[", npc_name, "] 💭 Setting emotion: ", emotion_name, " = ", intensity, " (AI wanted ", raw_intensity, ", dampened to ", intensity, ")")
			set_emotion(emotion_name, intensity)
		else:
			print("[", npc_name, "] ⚠️ Unknown emotion: ", emotion_name, " (valid: ", current_emotions.keys(), ")")


func _strip_emotion_tags(text: String) -> String:
	"""Remove emotion tags from response (case-insensitive)"""
	var result = text
	var emotion_regex = RegEx.new()
	emotion_regex.compile("(?i)\\[(?:emotion:)?(\\w+):(\\d+)\\]")
	result = emotion_regex.sub(result, "", true)
	return result.strip_edges()


# Legacy mood functions for backwards compatibility
func get_mood_description() -> String:
	return get_emotion_description()

# ============ VOICE SETUP ============

func _setup_voice():
	# Setup audio player first (shared by both TTS providers)
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
	
	# Setup TTS provider based on selection
	match tts_provider:
		TTSProvider.AZURE:
			_setup_azure_tts()
		TTSProvider.LOCAL_KOKORO, _:
			_setup_kokoro_tts()
	
	# Setup RVC if enabled
	if enable_rvc:
		_setup_rvc()


func _setup_kokoro_tts():
	"""Setup local Kokoro TTS."""
	kokoro_tts = KokoroTTS.new()
	add_child(kokoro_tts)
	
	# Configure voice
	kokoro_tts.voice_id = VOICE_PRESET_IDS.get(voice_preset, 0)
	kokoro_tts.speed = voice_speed
	
	# Connect signals - route through RVC if enabled, otherwise direct to voice ready
	if enable_rvc:
		kokoro_tts.synthesis_completed.connect(_on_tts_ready_for_rvc)
	else:
		kokoro_tts.synthesis_completed.connect(_on_voice_ready)
	kokoro_tts.synthesis_failed.connect(_on_voice_failed)
	
	if kokoro_tts.is_available():
		print("[", npc_name, "] Voice (Kokoro): ", kokoro_tts.get_voice_description(kokoro_tts.voice_id))
	else:
		print("[", npc_name, "] Warning: Kokoro TTS not available")


func _setup_azure_tts():
	"""Setup Azure cloud TTS with expressive voices."""
	azure_tts = AzureTTS.new()
	add_child(azure_tts)
	
	# Configure voice
	var voice_name = AZURE_VOICE_NAMES.get(azure_voice, "en-US-GuyNeural")
	azure_tts.set_voice(voice_name)
	azure_tts.set_rate(voice_speed)
	
	# Connect signals - route through RVC if enabled, otherwise direct to voice ready
	if enable_rvc:
		azure_tts.synthesis_completed.connect(_on_tts_ready_for_rvc)
	else:
		azure_tts.synthesis_completed.connect(_on_voice_ready)
	azure_tts.synthesis_failed.connect(_on_voice_failed)
	
	if azure_tts.is_available():
		print("[", npc_name, "] Voice (Azure): ", azure_tts.get_voice_description(voice_name))
	else:
		print("[", npc_name, "] Warning: Azure TTS not configured - set API key in AI Settings")


func _setup_rvc():
	"""Setup RVC voice conversion post-processor."""
	rvc_processor = RVCProcessor.new()
	add_child(rvc_processor)
	
	# Configure RVC settings
	rvc_processor.pitch_shift = rvc_pitch_shift
	rvc_processor.f0_method = rvc_quality  # "crepe-tiny", "crepe", or "rmvpe"
	rvc_processor.hop_length = rvc_hop_length
	rvc_processor.use_gpu = rvc_use_gpu
	rvc_processor.cuda_device = rvc_cuda_device
	
	# Set model paths directly if specified (drag-and-drop from Inspector)
	if not rvc_model_path.is_empty():
		var global_pth = ProjectSettings.globalize_path(rvc_model_path)
		var global_idx = ""
		if not rvc_index_path.is_empty():
			global_idx = ProjectSettings.globalize_path(rvc_index_path)
		rvc_processor.set_model_paths(global_pth, global_idx)
	
	# Connect signals
	rvc_processor.conversion_completed.connect(_on_voice_ready)
	rvc_processor.conversion_failed.connect(_on_rvc_failed)
	
	if rvc_processor.is_available():
		var model_name = rvc_model_path.get_file().get_basename() if not rvc_model_path.is_empty() else "none"
		print("[", npc_name, "] Voice (RVC): ", model_name, " (pitch: ", rvc_pitch_shift, ", quality: ", rvc_quality, ")")
	elif rvc_model_path.is_empty():
		print("[", npc_name, "] RVC enabled but no model selected")
	else:
		print("[", npc_name, "] Warning: RVC not available")


func _get_mood_adjusted_speed() -> float:
	if not mood_affects_voice:
		return voice_speed
	
	# Adjust speed based on dominant emotions
	# Higher intensity = stronger effect
	var speed_modifier = 1.0
	
	# Speed-increasing emotions
	if current_emotions["happy"] >= 30:
		speed_modifier -= 0.05 * (current_emotions["happy"] / 100.0)  # Up to 5% faster
	if current_emotions["angry"] >= 30:
		speed_modifier -= 0.1 * (current_emotions["angry"] / 100.0)  # Up to 10% faster
	if current_emotions["fearful"] >= 30:
		speed_modifier -= 0.15 * (current_emotions["fearful"] / 100.0)  # Up to 15% faster, nervous
	if current_emotions["surprised"] >= 30:
		speed_modifier -= 0.1 * (current_emotions["surprised"] / 100.0)  # Up to 10% faster
	
	# Speed-decreasing emotions
	if current_emotions["sad"] >= 30:
		speed_modifier += 0.15 * (current_emotions["sad"] / 100.0)  # Up to 15% slower
	if current_emotions["tired"] >= 30:
		speed_modifier += 0.2 * (current_emotions["tired"] / 100.0)  # Up to 20% slower
	
	# Clamp final modifier to reasonable range (0.7x to 1.3x base speed)
	speed_modifier = clamp(speed_modifier, 0.7, 1.3)
	
	return voice_speed * speed_modifier


## Add Kokoro-compatible markers based on emotions (ENHANCED with ProsodyAnalyzer)
func _add_mood_markers(text: String) -> String:
	if not mood_affects_voice:
		return text
	
	# Get dominant emotion for prosody
	var dominant = _get_dominant_emotions(30)
	var dominant_mood = -1  # -1 = neutral
	
	# Map dominant emotion to prosody mode (for backwards compat with ProsodyAnalyzer)
	if dominant.size() > 0:
		var top_emotion = dominant[0]["name"]
		match top_emotion:
			"happy": dominant_mood = 1
			"angry": dominant_mood = 2
			"sad": dominant_mood = 3
			"fearful": dominant_mood = 4
			"disgusted": dominant_mood = 5
			"surprised": dominant_mood = 6
			"flirty": dominant_mood = 7
			"tired": dominant_mood = 8
	
	# Use ProsodyAnalyzer for intelligent enhancement
	var enhanced = ProsodyAnalyzer.enhance_text(
		text,
		dominant_mood,
		{"personality": npc_personality, "emotions": current_emotions}  # Pass full emotion data
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
	# Try new path first (camera attached to head bone), then fall back to old path
	npc_camera = get_node_or_null("AnimeBoy/Armature/Skeleton3D/HeadCameraAttachment/Camera3D")
	if not npc_camera:
		npc_camera = get_node_or_null("AnimeBoy/Camera3D")
	
	if not npc_camera:
		push_warning(npc_name, " vision enabled but no camera found")
		enable_vision = false
		return
	
	# Get or create SubViewport under the camera
	vision_viewport = npc_camera.get_node_or_null("SubViewport")
	
	if not vision_viewport:
		vision_viewport = SubViewport.new()
		vision_viewport.name = "SubViewport"
		npc_camera.add_child(vision_viewport)
	
	# Configure viewport
	vision_viewport.size = Vector2i(vision_resolution, vision_resolution)
	vision_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Ensure viewport has a camera inside to render the scene
	var viewport_camera = vision_viewport.get_node_or_null("ViewportCamera")
	if not viewport_camera:
		# Check if there's any camera child
		for child in vision_viewport.get_children():
			if child is Camera3D:
				viewport_camera = child
				break
	
	if not viewport_camera:
		viewport_camera = Camera3D.new()
		viewport_camera.name = "ViewportCamera"
		vision_viewport.add_child(viewport_camera)
	
	viewport_camera.fov = npc_camera.fov
	print("[", npc_name, "] 📷 Vision system ready - camera at: ", npc_camera.get_path())


func _process(_delta):
	# Check hostility
	if enable_hostility:
		_check_hostility()
		
		# Continuously chase player when hostile
		if is_hostile and is_chasing and player_ref:
			_update_chase_target()
	
	if enable_vision and vision_viewport and npc_camera:
		var viewport_camera: Camera3D = null
		for child in vision_viewport.get_children():
			if child is Camera3D:
				viewport_camera = child
				break
		if viewport_camera:
			viewport_camera.global_transform = npc_camera.global_transform


func _physics_process(delta):
	# Apply gravity (if not on floor)
	if not is_on_floor():
		velocity.y -= 9.8 * delta  # Gravity
	
	# Get movement velocity from ActionController
	if enable_actions and action_controller:
		var movement_velocity = action_controller.get_movement_velocity()
		velocity.x = movement_velocity.x
		velocity.z = movement_velocity.z
	move_and_slide()

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

# EMOTION SYSTEM (USE THIS!):
Your current emotions: {emotion_desc}
{emotion_style}

IMPORTANT: Express emotions using tags! Format: [emotion_name:intensity] where intensity is 0-100
Available emotions: happy, angry, sad, fearful, disgusted, surprised, flirty, tired, trust
Voice style tags: shouting, whispering, hopeful, excited (for HOW you speak)

USE EMOTION TAGS in your responses! Examples:
- Happy response: "That's wonderful! [happy:80]"
- Angry response: "You're getting on my nerves! [angry:75]"
- Mixed emotions: "Oh... I see. [sad:50] [surprised:40]"
- Flirty: "Well aren't you charming? [flirty:60] [happy:30]"
- Tired: "*yawn* ...what? [tired:70]"
- Trust: "I'm glad we're talking. [trust:65] [happy:40]"
- SHOUTING: "HEY! GET BACK HERE! [shouting:90] [angry:80]"
- Whispering: "Psst... come closer... [whispering:80]"
- Hopeful: "Maybe things will work out! [hopeful:70] [happy:50]"
- Excited: "OH WOW! This is amazing! [excited:90] [happy:85]"

Examples:
Player: "Your shop is garbage!"
You: "Excuse me?! Get out! [angry:85] [disgusted:60] [trust:-20]"

Player: "You're amazing!"
You: "Aw, thank you! [happy:80] [flirty:40] [trust:70]"

Player: "HELP! SOMEONE'S CHASING ME!"
You: "QUICK! HIDE BEHIND THE COUNTER! [shouting:85] [fearful:60]"

Player: "I have a secret to tell you..."
You: "Oh? Tell me... I won't say a word... [whispering:70] [flirty:40]"
{spontaneous_hint}
"""

	# Add action system instructions if enabled
	if enable_actions and action_parser:
		prompt += """
# PHYSICAL ACTIONS:
{action_instructions}

IMPORTANT: You can spontaneously decide to do things! If you're in the middle of a conversation and suddenly
remember something, want to go somewhere, or feel like doing something - just do it! Be natural and unpredictable.
Examples:
- "Oh! I just remembered I left something in the kitchen. [walk_to:Kitchen]"
- "You know what, I'm feeling good! [animate:dance] What were you saying?"
- "Hang on... [animate:sit] My feet are killing me. Continue."
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
Life Goals: {goals}
Knowledge: {knowledge}
{current_goal_section}
# THE PLAYER:
{player_description}

# WORLD CONTEXT:
{world_lore}
Location: {location_lore}

# SPATIAL CONTEXT:
{spatial_context}

Speak naturally as {name} would. Your emotions affect HOW you say things."""

	var dominant_emotions = _get_dominant_emotions(20)
	var emotion_style_parts = []
	for em in dominant_emotions:
		if EMOTION_SPEECH_STYLES.has(em.name):
			emotion_style_parts.append(EMOTION_SPEECH_STYLES[em.name])
	
	# Build current goal section if goal is set
	var goal_section = ""
	if not npc_current_goal.is_empty():
		goal_section = """
Current Objective: {current_goal}
→ This is what you're focused on right now. It may subtly influence your responses and priorities.
""".format({"current_goal": npc_current_goal})
	
	var format_map = {
		"name": npc_name,
		"max_length": max_response_length,
		"emotion_desc": get_emotion_description(),
		"emotion_style": " ".join(emotion_style_parts) if emotion_style_parts.size() > 0 else "Speak in a natural, conversational tone.",
		"personality": npc_personality,
		"background": npc_background,
		"goals": npc_goals,
		"knowledge": npc_knowledge,
		"npc_appearance": npc_appearance,
		"player_appearance": player_appearance,
		"player_description": _get_player_description(),
		"world_lore": WorldLore.WORLD_LORE,
		"location_lore": WorldLore.get_location_lore(npc_location),
		"spatial_context": _build_spatial_context(),
		"action_instructions": "",  # Will be filled if actions enabled
		"spontaneous_hint": _get_spontaneous_hint(),
		"current_goal_section": goal_section
	}
	
	# Add action instructions if enabled
	if enable_actions and action_parser:
		format_map["action_instructions"] = NPCActionParser.get_action_system_prompt()
	
	return prompt.format(format_map)


func _build_spatial_context() -> String:
	var context = ""
	
	# Determine how to refer to the player
	var player_ref = player_name if not player_name.is_empty() else "The player"
	
	var npc_room = RoomManager.get_npc_room(npc_name)
	if npc_room != "unknown":
		context += "You are in: " + npc_room + "\n"
	
	var player_room = RoomManager.get_player_room()
	if player_room != "unknown":
		if player_room == npc_room:
			context += player_ref + " is here with you.\n"
		else:
			context += player_ref + " is in: " + player_room + "\n"
	
	if RoomManager.player_just_changed_rooms():
		var prev_room = RoomManager.get_player_previous_room()
		context += player_ref + " just moved from " + prev_room + ".\n"
	
	if context.is_empty():
		context = "Location unknown.\n"
	
	return context

func _get_player_description() -> String:
	"""Build a clear description of who the player is."""
	var desc = ""
	
	# Determine how to refer to the player
	var player_ref = "the player"
	if not player_name.is_empty():
		player_ref = player_name
		desc = "You are talking to %s." % player_name
		if not player_appearance.is_empty():
			desc += " %s\n" % player_appearance
		else:
			desc += "\n"
		desc += "Address them by name when appropriate.\n"
	else:
		if not player_appearance.is_empty():
			desc = "You are interacting with the PLAYER. %s\n" % player_appearance
		else:
			desc = "You are interacting with the PLAYER.\n"
		desc += "When you see or refer to the player, recognize them as THE PLAYER - the person you're talking to.\n"
		desc += "Don't call them 'someone' or 'a person' - you know who they are."
	
	return desc

func _get_spontaneous_hint() -> String:
	"""Get hint about spontaneous actions based on probability."""
	if not enable_actions or spontaneous_action_chance <= 0.0:
		return ""
	
	# Roll dice to determine if we encourage spontaneous behavior this conversation
	var roll = randf()
	if roll < spontaneous_action_chance:
		return """
	
# SPONTANEOUS ACTIONS:
During conversation, you can naturally do things:
- Remember something and walk away: "Oh! I left the stove on. [walk_to:Kitchen]"
- React physically: "Ugh, I'm exhausted. [animate:sit]"
- Natural movements: *shifts position* [animate:idle]

Keep it NATURAL - don't narrate what you're doing, just DO it."""
	
	return ""

# ============ CONVERSATION ============

func start_conversation():
	"""Called when player presses Enter to talk to NPC."""
	is_talking = true
	print("[DEBUG] [", npc_name, "] start_conversation called, is_talking = true")
	
	if enable_forgetting and forget_timer:
		forget_timer.stop()
	
	# Start patience timer
	if enable_patience and patience_timer:
		is_waiting_for_response = true
		print("[DEBUG] [", npc_name, "] Starting patience timer, is_waiting_for_response = true")
		_start_patience_timer()
	else:
		print("[DEBUG] [", npc_name, "] Patience NOT starting - enable_patience=", enable_patience, ", patience_timer=", patience_timer != null)
	
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
	
	# DON'T stop patience timer - it should keep running if NPC is waiting for response!
	# Timer only stops when:
	# 1. Player responds (in talk_to_npc)
	# 2. Patience timeout triggers (in _on_patience_timeout)
	# 3. Player truly ends conversation (not implemented yet)	
	if enable_forgetting and forget_timer:
		forget_timer.start(forget_delay)


func talk_to_npc(message: String):
	# Stop patience timer - player is responding!
	if enable_patience and patience_timer:
		print("[DEBUG] [", npc_name, "] Player responded, STOPPING patience timer")
		is_waiting_for_response = false
		patience_timer.stop()
	
	if enable_memory:
		conversation_history.append({"role": "user", "content": message})
		trim_conversation_history()
	
	current_response = ""
	
	# Rebuild system prompt with current mood and state
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
	cleaned = _strip_emotion_tags(cleaned)
	
	# Don't strip action tags during streaming (we'll do it at the end)
	dialogue_updated.emit(cleaned)


func _on_response_complete(full_response: String):
	_process_response(full_response)


func _on_groq_response_updated(text: String):
	current_response = text
	var cleaned = text
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	cleaned = _strip_emotion_tags(cleaned)
	
	# Don't strip action tags during streaming
	dialogue_updated.emit(cleaned)


func _on_groq_response_finished(full_response: String):
	_process_response(full_response)


func _on_groq_request_failed(error: String):
	dialogue_finished.emit("[Error: " + error + "]")


func _process_response(full_response: String):
	# Detect and apply emotions from response
	_detect_emotions_from_response(full_response)
	
	# Parse for actions BEFORE cleaning
	var parsed_text = full_response
	var detected_actions = []
	
	if enable_actions and action_parser:
		var parsed = action_parser.parse_response(full_response)
		parsed_text = parsed["text"]
		detected_actions = parsed["actions"]
		
		print("[", npc_name, "] 📝 Response text: ", parsed_text)
		print("[", npc_name, "] 🎬 Detected ", detected_actions.size(), " action(s)")
	
	# Clean response
	var cleaned = parsed_text
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	cleaned = _strip_emotion_tags(cleaned)
	
	if enable_memory:
		conversation_history.append({"role": "assistant", "content": cleaned})
		trim_conversation_history()
	
	current_response = cleaned
	dialogue_finished.emit(cleaned)
	
	# Restart patience timer after NPC responds - UNLESS this is autonomous text
	# Autonomous text = NPC doing their own thing, shouldn't interrupt patience tracking
	# Patience response = NPC reacting to being ignored, should restart waiting for player
	# Normal response = NPC replying to player, should restart waiting for player
	if enable_patience and patience_timer:
		if is_autonomous_text:
			print("[DEBUG] [", npc_name, "] Autonomous text - patience timer NOT restarted")
			# Don't touch the patience timer - let it keep running
		else:
			# Normal or patience response - restart timer waiting for player
			is_waiting_for_response = true
			is_patience_response = false  # Reset flag
			print("[DEBUG] [", npc_name, "] NPC finished speaking, RESTARTING patience timer (waiting for player)")
			_start_patience_timer()
	
	# Speak with mood-affected voice
	_speak(cleaned)

# ============ VOICE SYNTHESIS ============

func _speak(text: String):
	if not enable_voice:
		return
	
	if text.begins_with("[Error"):
		return
	
	if text.strip_edges().is_empty():
		return
	
	# Check which TTS is available based on provider
	var tts_available = false
	var tts_busy = false
	
	match tts_provider:
		TTSProvider.AZURE:
			tts_available = azure_tts and azure_tts.is_available()
			tts_busy = azure_tts and azure_tts.is_busy()
		TTSProvider.LOCAL_KOKORO, _:
			tts_available = kokoro_tts and kokoro_tts.is_available()
			tts_busy = kokoro_tts and kokoro_tts.is_busy()
	
	if not tts_available:
		return
	
	# Stop previous voice only when NEW audio is ready to play
	if voice_player and voice_player.playing:
		voice_player.stop()
		is_speaking = false
		print("[", npc_name, "] Interrupted previous speech - new audio ready")
	
	if tts_busy:
		return
	
	# Synthesize with the appropriate provider
	match tts_provider:
		TTSProvider.AZURE:
			_speak_azure(text)
		TTSProvider.LOCAL_KOKORO, _:
			_speak_kokoro(text)


func _speak_kokoro(text: String):
	"""Synthesize with local Kokoro TTS."""
	kokoro_tts.voice_id = VOICE_PRESET_IDS.get(voice_preset, 0)
	kokoro_tts.speed = _get_mood_adjusted_speed()
	
	# Add mood markers to text
	var tts_text = _add_mood_markers(text)
	kokoro_tts.synthesize(tts_text)


func _speak_azure(text: String):
	"""Synthesize with Azure TTS using emotion styles."""
	var voice_name = AZURE_VOICE_NAMES.get(azure_voice, "en-US-GuyNeural")
	azure_tts.set_voice(voice_name)
	azure_tts.set_rate(_get_mood_adjusted_speed())
	
	# Apply emotion styles if enabled
	if use_azure_emotion_styles and mood_affects_voice:
		azure_tts.set_style_from_emotions(current_emotions)
	else:
		azure_tts.voice_style = ""
	
	azure_tts.synthesize(text)


func _on_voice_ready(audio: AudioStreamWAV):
	if not voice_player:
		return
	
	voice_player.stream = audio
	voice_player.play()
	is_speaking = true
	voice_started.emit()


func _on_tts_ready_for_rvc(audio: AudioStreamWAV):
	"""TTS completed - now send through RVC for voice conversion."""
	if not rvc_processor or not rvc_processor.is_available():
		# RVC not available, play original audio
		_on_voice_ready(audio)
		return
	
	print("[", npc_name, "] Sending TTS audio to RVC for conversion...")
	rvc_processor.convert(audio)


func _on_rvc_failed(error: String):
	"""RVC conversion failed - play original TTS audio if available."""
	print("[", npc_name, "] RVC error: ", error)
	# If we have pending audio from TTS, play it instead
	if _pending_rvc_audio:
		_on_voice_ready(_pending_rvc_audio)
		_pending_rvc_audio = null
	else:
		is_speaking = false


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
	
	# Reset emotions to baseline
	for emotion in current_emotions.keys():
		current_emotions[emotion] = baseline_emotions[emotion]
	emotions_changed.emit(current_emotions.duplicate())
	
	# Stop any ongoing actions
	if enable_actions and action_controller:
		pending_actions.clear()
		is_executing_action = false
		action_controller.stop_looking()
		action_controller.stop_moving()

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

# ============ Navigation Agent ============

func update_target_location(target: Vector3):
	"""Legacy function - kept for compatibility. Use action_controller instead."""
	nav_target = target
	if nav_agent:
		nav_agent.set_target_position(target)


# ============ PUBLIC ACTION API ============

## Manually trigger an animation
func play_animation(anim_name: String) -> bool:
	if enable_actions and action_controller:
		return action_controller.play_animation(anim_name)
	return false


## Manually move to a position
func move_to(target_pos: Vector3):
	if enable_actions and action_controller:
		action_controller.move_to_position(target_pos)


## Manually look at a target
func look_at_target(target):
	if enable_actions and action_controller:
		if target is Node3D:
			action_controller.look_at_node(target)
		elif target is Vector3:
			action_controller.look_at_position(target)


## Get current action state for debugging
func get_action_state() -> String:
	if enable_actions and action_controller:
		return action_controller.get_state_description()
	return "Actions disabled"

# ============ HOSTILITY / ATTACK SYSTEM ============

func _check_hostility():
	"""Check if NPC should become hostile and attack."""
	if not enable_hostility or not player_ref:
		return
	
	# Check if hostility has reached attack threshold
	var hostility_level = current_emotions.get("hostility", 0)
	
	var should_be_hostile = hostility_level >= 100
	
	# State change
	if should_be_hostile and not is_hostile:
		_become_hostile()
	elif not should_be_hostile and is_hostile:
		_become_peaceful()
	
	# Attempt attack if hostile
	if is_hostile and can_attack:
		_try_attack()


func _become_hostile():
	"""Transition to hostile state."""
	is_hostile = true
	print("[", npc_name, "] 😡 BECAME HOSTILE! (Hostility: ", current_emotions.get("hostility", 0), ")")
	
	# Start chasing player
	if player_ref and action_controller:
		_start_chasing_player()
	
	# Visual/audio feedback could go here
	# e.g., change shader tint, play hostile sound


func _become_peaceful():
	"""Return to peaceful state."""
	is_hostile = false
	print("[", npc_name, "] 😌 Calmed down... (Hostility: ", current_emotions.get("hostility", 0), ")")
	
	# Stop chasing
	if action_controller:
		_stop_chasing_player()


func _try_attack():
	"""Attempt to attack player if in range."""
	if not can_attack or not player_ref:
		return
	
	# Check if player is in same room (if required)
	if require_same_room_for_attack:
		var room_mgr = get_node_or_null("/root/RoomManager")
		if room_mgr and not room_mgr.is_player_in_same_room_as_npc(npc_name):
			return  # Player not in same room, can't attack
	
	# Check distance
	var distance = global_position.distance_to(player_ref.global_position)
	if distance > attack_range:
		# Too far, keep chasing
		if is_hostile:
			_update_chase_target()
		return
	
	# Execute attack
	_execute_attack()

func _start_chasing_player():
	"""Begin pursuing the player."""
	if not player_ref or not action_controller:
		return
	
	is_chasing = true
	print("[", npc_name, "] 🏃 Chasing player!")
	
	# Increase movement speed for chase (slower for now)
	if "walk_speed" in action_controller:
		action_controller.walk_speed = 2.5  # Slightly faster than normal walk (was 4.0)
	
	_update_chase_target()

func _update_chase_target():
	"""Update navigation to player's current position."""
	if not player_ref or not action_controller or not is_hostile:
		return
	
	# Navigate to player's position
	var player_pos = player_ref.global_position
	action_controller.move_to_position(player_pos)
	# Run animation will trigger automatically based on movement speed

func _stop_chasing_player():
	"""Stop pursuing the player."""
	if not action_controller:
		return
	
	is_chasing = false
	print("[", npc_name, "] ⏹️ Stopped chasing")
	
	# Reset movement speed
	if "walk_speed" in action_controller:
		action_controller.walk_speed = 2.0  # Normal walking speed
	
	# Stop movement
	if action_controller.has_method("stop_movement"):
		action_controller.stop_movement()
	
	# Return to idle
	if action_controller.has_method("play_animation"):
		action_controller.play_animation("idle")


func _execute_attack():
	"""Deal damage to player."""
	can_attack = false
	
	print("[", npc_name, "] 🗡️ ATTACKING PLAYER! (", attack_damage, " damage)")
	
	# Get player health component (try multiple locations)
	var player_health = player_ref.get_node_or_null("PlayerHealth")
	if not player_health:
		# Try as direct child of player
		for child in player_ref.get_children():
			if child is PlayerHealth or child.get_class() == "PlayerHealth":
				player_health = child
				break
	
	if player_health and player_health.has_method("take_damage"):
		player_health.take_damage(attack_damage, self)
	else:
		push_warning("[", npc_name, "] Failed to deal damage - PlayerHealth not found on player!")
	
	# Visual feedback (could add attack animation here)
	
	# Start cooldown
	attack_timer.start(attack_cooldown)
	await attack_timer.timeout
	can_attack = true

## Headtracking
func _on_timer_timeout() -> void:
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
	var bodies = non_ai_vision.get_overlapping_bodies()
	if player in bodies:
		look_at_modifier_3d.target_node = player.get_child(0).get_child(0).get_path()
	else:
		look_at_modifier_3d.target_node = ""
