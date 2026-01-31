extends CharacterBody3D

# NPC Identity
@export var npc_name: String = "Shopkeeper"
@export var npc_location: String = "market"

# NPC Character Profile
@export_group("Character")
@export_multiline var npc_personality: String = "Grumpy but fair shopkeeper"
@export_multiline var npc_background: String = "Former adventurer, now runs a general goods shop"
@export_multiline var npc_goals: String = "Make money, retire comfortably"
@export_multiline var npc_knowledge: String = "Knows about adventuring gear, local gossip"
@export_multiline var npc_appearance: String = "A tall figure wearing a brown apron" ## What this NPC looks like (for self-awareness)
@export_multiline var player_appearance: String = "The player is a green humanoid figure" ## What the player looks like (helps NPC recognize them)

# Conversation settings
@export_group("Dialogue Settings")
@export var max_response_length: String = "1-2 sentences"
@export var greeting: String = "Aye, what can I do for ye?"

# Memory settings
@export_group("Memory Settings")
@export var enable_memory: bool = true ## Enable conversation memory. If disabled, NPC won't remember previous messages.

@export_range(1, 50, 1) var max_history_turns: int = 10 ## Maximum number of back-and-forth exchanges to remember. Higher = better memory but slower responses.

@export var enable_forgetting: bool = true ## Enable automatic memory reset when dialogue closes. If disabled, NPC will remember forever.

@export_range(10.0, 300.0, 5.0, "suffix:seconds") var forget_delay: float = 60.0 ## How long (in seconds) after dialogue closes before NPC forgets the conversation.

# Vision settings
@export_group("Vision Settings")
@export var enable_vision: bool = false ## Enable NPC vision (requires vision-capable Groq model like Llama 4 Maverick/Scout)
@export_range(0.0, 10.0, 0.1, "suffix:seconds") var vision_capture_interval: float = 2.0 ## How often to capture vision (0 = every message, higher = cached)
@export_range(128, 1024, 64) var vision_resolution: int = 512 ## Resolution for vision capture (lower = faster, higher = more detail)

# Text cleaning settings
@export_group("Response Filtering")
@export var remove_action_markers: bool = true ## Remove asterisks, parentheses, and brackets like *(smiles)* or (laughs) from responses.

@export var remove_asterisks: bool = true ## Remove *action* formatting.

@export var remove_parentheses: bool = true ## Remove (action) formatting.

@export var remove_brackets: bool = true ## Remove [action] formatting.

# References
@onready var chat_node = $ChatNode
@onready var vision_viewport: SubViewport = null
@onready var npc_camera: Camera3D = null

# State
var is_talking = false
var current_response = ""
var conversation_history: Array = []
var forget_timer: Timer
var system_prompt: String = ""

# Groq-specific state
var groq_provider = null
var using_groq: bool = false

# Vision state
var last_vision_capture_time: float = 0.0
var cached_vision_base64: String = ""

# Room/location state
var current_room: String = "unknown"

signal dialogue_updated(text: String)
signal dialogue_finished(text: String)

func _ready():
	# Detect which room the NPC starts in
	_detect_initial_room()
	
	# Setup vision if enabled
	if enable_vision:
		_setup_vision()
	
	# Build system prompt first (needed for both providers)
	system_prompt = build_system_prompt()
	
	# Setup based on current provider
	_setup_provider()
	
	# Listen for provider changes
	AIManager.provider_changed.connect(_on_provider_changed)
	
	# Create forget timer
	if enable_forgetting:
		forget_timer = Timer.new()
		forget_timer.one_shot = true
		forget_timer.timeout.connect(reset_conversation)
		add_child(forget_timer)
	
	# Register with NPCManager for global access
	NPCManager.register_npc(self)
	
	print(npc_name, " is ready! Provider: ", AIManager.get_provider_name())
	if enable_vision and vision_viewport:
		print(npc_name, " vision enabled at ", vision_resolution, "x", vision_resolution)
	if current_room != "unknown":
		print(npc_name, " starting in room: ", current_room)

func _detect_initial_room():
	# Check which room area the NPC is currently inside
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create a small sphere at NPC's position
	var shape = SphereShape3D.new()
	shape.radius = 0.1
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 0  # We'll check manually
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_shape(query, 10)
	
	# Look for Room areas
	for result in results:
		var area = result.collider
		if area is Area3D and area.has_method("get_room_name"):
			current_room = area.get_room_name()
			RoomManager.set_npc_room(npc_name, current_room)
			return
	
	# If no room found, try by checking parent nodes
	var parent = get_parent()
	while parent:
		if parent is Area3D and parent.has_method("get_room_name"):
			current_room = parent.get_room_name()
			RoomManager.set_npc_room(npc_name, current_room)
			return
		parent = parent.get_parent()
	
	# No room detected
	print(npc_name, " warning: Could not detect starting room")


func _setup_vision():
	# Find or create the vision viewport
	vision_viewport = get_node_or_null("VisionViewport")
	
	if not vision_viewport:
		# Create viewport programmatically if it doesn't exist
		vision_viewport = SubViewport.new()
		vision_viewport.name = "VisionViewport"
		vision_viewport.size = Vector2i(vision_resolution, vision_resolution)
		vision_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vision_viewport)
	else:
		# Update existing viewport size
		vision_viewport.size = Vector2i(vision_resolution, vision_resolution)
	
	# Find the NPC's camera
	npc_camera = get_node_or_null("CameraHead/Camera3D")
	
	if npc_camera:
		# Clone camera settings to viewport
		var viewport_camera = Camera3D.new()
		viewport_camera.fov = npc_camera.fov
		viewport_camera.transform = npc_camera.transform
		
		# Optional: Set cull mask to hide NPC's own body (if it has visual layer set)
		# viewport_camera.cull_mask = npc_camera.cull_mask
		
		vision_viewport.add_child(viewport_camera)
		
		# Make the viewport camera follow the NPC camera
		npc_camera.tree_exited.connect(func(): 
			if viewport_camera:
				viewport_camera.queue_free()
		)
		
		print(npc_name, " vision camera configured")
		if player_appearance and "green" in player_appearance.to_lower():
			print(npc_name, " knows player looks like: ", player_appearance)
	else:
		push_warning(npc_name, " vision enabled but no camera found at CameraHead/Camera3D")
		enable_vision = false

func _process(_delta):
	# Update vision viewport camera to match NPC camera
	if enable_vision and vision_viewport and npc_camera:
		var viewport_camera = vision_viewport.get_child(0) as Camera3D
		if viewport_camera:
			viewport_camera.global_transform = npc_camera.global_transform

func _setup_provider():
	using_groq = AIManager.is_groq()
	
	if using_groq:
		_setup_groq()
	else:
		_setup_local()

func _setup_local():
	# Setup for NobodyWho local model
	if chat_node:
		chat_node.model_node = AIManager.llm_model
		chat_node.system_prompt = system_prompt
		
		# Disconnect Groq signals if connected
		if groq_provider:
			_disconnect_groq_signals()
		
		# Connect local signals
		if not chat_node.response_updated.is_connected(_on_response_token):
			chat_node.response_updated.connect(_on_response_token)
		if not chat_node.response_finished.is_connected(_on_response_complete):
			chat_node.response_finished.connect(_on_response_complete)
		
		# Start worker
		chat_node.start_worker()
		
		print(npc_name, " using local NobodyWho model")
		
		if enable_vision:
			push_warning(npc_name, " vision is only supported with Groq provider")

func _setup_groq():
	# Setup for Groq API
	groq_provider = AIManager.get_chat_provider()
	
	if groq_provider:
		_connect_groq_signals()
		print(npc_name, " using Groq API")
		
		if enable_vision:
			# Check if current model supports vision
			var current_model = AIManager.get_groq_model()
			var vision_models = ["meta-llama/llama-4-maverick-17b-128e-instruct", "meta-llama/llama-4-scout-17b-16e-instruct"]
			if current_model not in vision_models:
				push_warning(npc_name, " vision enabled but current model (", current_model, ") may not support vision. Use Llama 4 Maverick or Scout.")
	else:
		push_error("Groq provider not available!")

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
	print(npc_name, " switching provider...")
	_setup_provider()

func _exit_tree():
	# Unregister when removed
	NPCManager.unregister_npc(self)
	
	# Disconnect Groq signals
	_disconnect_groq_signals()

func build_system_prompt() -> String:
	var prompt = """You are {name}, an NPC in an immersive game.

# CRITICAL RULES - FOLLOW EXACTLY:
1. Keep responses SHORT: {max_length} maximum
2. Speak naturally like a real person - NO lists, NO explanations
3. Stay in character - you are NOT an AI assistant
4. NEVER say "How can I help you" or "Is there anything else"
5. React to what the player says, don't just provide information
6. Use natural dialogue fillers: "Hmm", "Well", "So", etc.
7. SPEAK ONLY - No action descriptions whatsoever
8. BANNED: *smiles*, (laughs), [grins], *nods*, (sighs), or ANY similar formatting
9. Express emotion through WORDS ONLY: Say "Hah!" or "Hmph" instead of (laughs) or (scoffs)
10. If you want to convey an action, describe it in plain speech: "I'm shaking my head" NOT (shakes head)"""

	if enable_vision:
		prompt += """
11. You are seeing through YOUR OWN EYES in a 3D game world
12. This is your natural field of view - you're not being "shown" things, you're just looking around
13. You can see the environment, objects, and the player character in front of you
14. {player_appearance}
15. React naturally to what you observe - if the player is right in front of you, you're talking face-to-face
16. Mention what you see ONLY when it's relevant to the conversation or something notable happens
17. Understand spatial context: things close to you are nearby, things far away are distant
18. You're experiencing this world in real-time through your perspective
19. You know which room you and the player are in - mention it naturally if relevant (e.g., "Why are you in the kitchen?")"""

	if enable_memory:
		prompt += """
20. REMEMBER what has been said in this conversation
21. Stay CONSISTENT with information you've already shared
22. Reference past topics naturally when relevant
23. Don't repeat yourself unless asked
24. CRITICAL: Track who says what! If YOU said something, don't later attribute it to the player
25. Example: If YOU said "I need coffee", don't later say "You wanted coffee" - that was YOUR statement"""

	prompt += """

# YOUR CHARACTER:
Name: {name}
Appearance: {npc_appearance}
Personality: {personality}
Background: {background}
Goals: {goals}
Knowledge: {knowledge}

# WORLD CONTEXT:
{world_lore}
Location: {location_lore}

# SPATIAL CONTEXT:
{spatial_context}

# DIALOGUE STYLE EXAMPLES:
GOOD: "Aye, got plenty of healing potions. 5 gold each."
BAD: "Welcome! I have many items available for purchase. Here is what I offer: healing potions (5 gold each)..."
VERY BAD: "*smiles* Welcome! (gestures to shelves)"

GOOD: "Northern mountains? Hah! Wouldn't go there if you paid me."
BAD: "(laughs nervously) The northern mountains? I wouldn't go there..."
VERY BAD: "*scratches beard* Northern mountains, eh?"

GOOD: "That's nonsense. I don't believe a word of it."
BAD: "(frowns) That's nonsense..."
VERY BAD: "*crosses arms* That's nonsense."

GOOD: "Listen here - I'm telling you the truth."
BAD: "(leans forward) Listen here..."
"""

	if enable_vision:
		prompt += """
# VISION EXAMPLES:
GOOD: You see the player walking toward you → "Hey, come over here."
BAD: You see the player → "What's this green thing you're showing me?"

GOOD: Player is standing in front of you → "What do you want?" or "Yes?" (natural conversation)
BAD: Player is standing in front of you → "I see you've brought me a green capsule to look at"

GOOD: Player moves behind you → "Hey! Get back where I can see you!"
BAD: Player moves → "Thank you for showing me this movement"

GOOD: You see a sword on the ground → "Someone left a weapon lying around..."
BAD: You see a sword → "You're showing me a sword for some reason"

GOOD: Player holds weapon in your face → "Whoa! Put that away!"
BAD: Player holds weapon → "Interesting weapon you've brought to show me"

# ROOM AWARENESS EXAMPLES:
GOOD: Player in same room → Talk normally, no need to mention room unless relevant
GOOD: Player in different room → "Why did you go to the kitchen?" or "I heard you in the bedroom..."
GOOD: Player just moved → "What were you doing in there?" or "Looking for something in the kitchen?"
BAD: Player in same room → "I see you're in the living room with me" (too obvious, don't state the obvious)
BAD: Constantly mentioning rooms → "We're in living room. You're in living room too." (annoying)

REMEMBER: You're seeing through your own eyes. The player is the person you're talking to. Don't act like things are being presented to you - you're just looking at your surroundings naturally.
"""

	if enable_memory:
		prompt += """
# MEMORY EXAMPLES:
GOOD: Player asks "What's your name?" → You answer "Marcus" → Later player says "Hey Marcus" → You respond naturally
BAD: Player asks "What's your name?" → You answer "Marcus" → Later you introduce yourself again as if meeting for first time

GOOD: You tell player "I used to adventure" → Player asks "What happened?" → You build on that story
BAD: You tell player "I used to adventure" → Later you contradict yourself saying you never left town

GOOD: YOU say "I need some coffee" → Later reference it as "I mentioned needing coffee" or "Like I said, I need coffee"
BAD: YOU say "I need some coffee" → Later say "You wanted coffee" (that was YOUR statement, not the player's!)

GOOD: PLAYER says "I'm looking for a key" → Later say "You mentioned looking for a key"
BAD: PLAYER says "I'm looking for a key" → Later say "I was looking for a key" (that was the PLAYER, not you!)
"""

	prompt += """
Remember: 
- ONLY dialogue that would come out of your mouth
- NO actions in parentheses, brackets, or asterisks
- Express everything through spoken words
- Short, natural, in-character"""

	if enable_vision:
		prompt += """
- React to what you see when appropriate
- Don't narrate your vision constantly"""

	if enable_memory:
		prompt += """
- Stay consistent with what you've said before
- If player references something you said earlier, acknowledge it"""

	prompt += """

Always end conversations naturally - don't keep offering help or asking a follow-up question.

You are {name} so speak as {name} normally would in the context of the conversation."""

	return prompt.format({
		"name": npc_name,
		"max_length": max_response_length,
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
	
	# Get NPC's current room
	var npc_room = RoomManager.get_npc_room(npc_name)
	if npc_room != "unknown":
		context += "You are currently in: " + npc_room + "\n"
	else:
		context += "Your location is unknown.\n"
	
	# Get player's current room
	var player_room = RoomManager.get_player_room()
	
	if player_room != "unknown":
		if player_room == npc_room:
			context += "The player is here with you in the same room.\n"
		else:
			context += "The player is currently in: " + player_room
			
			# Add distance/relationship context if possible
			if npc_room != "unknown":
				context += " (you are in: " + npc_room + ")\n"
			else:
				context += "\n"
	else:
		context += "The player's location is unknown.\n"
	
	# Check if player just changed rooms
	if RoomManager.player_just_changed_rooms():
		var prev_room = RoomManager.get_player_previous_room()
		context += "The player just moved from " + prev_room + " to " + player_room + ".\n"
	
	# Add other NPCs in same room
	if npc_room != "unknown":
		var npcs_here = RoomManager.get_npcs_in_room(npc_room)
		if npcs_here.size() > 1:  # More than just this NPC
			var other_npcs = []
			for other_npc in npcs_here:
				if other_npc != npc_name:
					other_npcs.append(other_npc)
			
			if other_npcs.size() > 0:
				context += "Other characters nearby: " + ", ".join(other_npcs) + "\n"
	
	if context.is_empty():
		context = "Location information not available.\n"
	
	return context

func start_conversation():
	is_talking = true
	current_response = ""
	
	# Stop forget timer if dialogue is reopening
	if enable_forgetting and forget_timer:
		forget_timer.stop()
	
	DialogueUI.show_dialogue(self)
	
	if enable_memory and not conversation_history.is_empty():
		dialogue_finished.emit("")
	else:
		if enable_memory:
			conversation_history.append({"role": "assistant", "content": greeting})
		current_response = greeting
		dialogue_finished.emit(greeting)

func end_conversation():
	is_talking = false
	
	# Start forget timer when dialogue closes
	if enable_forgetting and forget_timer:
		forget_timer.start(forget_delay)

func talk_to_npc(message: String):
	print("Player said: ", message)
	
	if enable_memory:
		conversation_history.append({"role": "user", "content": message})
		trim_conversation_history()
	
	current_response = ""
	
	# Route to appropriate provider
	if using_groq:
		_send_to_groq(message)
	else:
		_send_to_local(message)

func _send_to_local(message: String):
	if enable_vision:
		print(npc_name, " warning: Vision not supported with local provider")
	chat_node.ask(message)

func _send_to_groq(message: String):
	if not groq_provider:
		dialogue_finished.emit("[Error: Groq provider not available]")
		return
	
	# Rebuild system prompt with fresh spatial context (player may have moved!)
	var fresh_system_prompt = build_system_prompt()
	groq_provider.set_system_prompt(fresh_system_prompt)
	
	# Check if we should capture vision
	var vision_base64 = ""
	if enable_vision and _should_capture_vision():
		vision_base64 = await _capture_vision()
	
	# Send with conversation history and optional vision
	var history_to_send = conversation_history.duplicate()
	# Remove the last message since we're sending it separately
	if history_to_send.size() > 0:
		history_to_send.pop_back()
	
	groq_provider.ask(message, history_to_send, vision_base64)

# ============ Vision Capture ============

func _should_capture_vision() -> bool:
	if not enable_vision or not vision_viewport:
		return false
	
	# If interval is 0, always capture
	if vision_capture_interval == 0.0:
		return true
	
	# Check if enough time has passed
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_vision_capture_time >= vision_capture_interval:
		return true
	
	return false

func _capture_vision() -> String:
	if not vision_viewport:
		return ""
	
	# Update capture time
	last_vision_capture_time = Time.get_ticks_msec() / 1000.0
	
	# Wait for render to complete
	await RenderingServer.frame_post_draw
	
	# Get the viewport texture
	var viewport_texture = vision_viewport.get_texture()
	var image = viewport_texture.get_image()
	
	if not image:
		push_warning(npc_name, " failed to capture vision image")
		return ""
	
	# Convert to PNG bytes
	var png_bytes = image.save_png_to_buffer()
	
	# Encode to base64
	var base64_string = Marshalls.raw_to_base64(png_bytes)
	
	cached_vision_base64 = base64_string
	print(npc_name, " captured vision (", png_bytes.size(), " bytes, base64: ", base64_string.length(), " chars)")
	
	return base64_string

# ============ Local Model Callbacks ============

func _on_response_token(token: String):
	current_response += token
	var cleaned = current_response
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	dialogue_updated.emit(cleaned)

func _on_response_complete(full_response: String):
	var cleaned = full_response
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	
	if enable_memory:
		conversation_history.append({"role": "assistant", "content": cleaned})
		trim_conversation_history()
	
	print(npc_name, ": ", cleaned)
	current_response = cleaned
	dialogue_finished.emit(cleaned)

# ============ Groq API Callbacks ============

func _on_groq_response_updated(text: String):
	current_response = text
	var cleaned = text
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	dialogue_updated.emit(cleaned)

func _on_groq_response_finished(full_response: String):
	var cleaned = full_response
	if remove_action_markers:
		cleaned = clean_response(cleaned)
	
	if enable_memory:
		conversation_history.append({"role": "assistant", "content": cleaned})
		trim_conversation_history()
	
	print(npc_name, " (Groq): ", cleaned)
	current_response = cleaned
	dialogue_finished.emit(cleaned)

func _on_groq_request_failed(error: String):
	print("Groq request failed: ", error)
	dialogue_finished.emit("[Error: " + error + "]")

# ============ Memory Management ============

func trim_conversation_history():
	if not enable_memory:
		return
		
	var max_messages = max_history_turns * 2
	if conversation_history.size() > max_messages:
		var to_remove = conversation_history.size() - max_messages
		for i in range(to_remove):
			conversation_history.pop_front()
		print("Trimmed conversation history to ", conversation_history.size(), " messages")

func get_conversation_summary() -> String:
	var summary = ""
	for entry in conversation_history:
		if entry.role == "user":
			summary += "[Player]: " + entry.content + "\n"
		else:
			summary += "[" + npc_name + "]: " + entry.content + "\n"
	return summary

func reset_conversation():
	conversation_history.clear()
	print(npc_name, " forgot the conversation")

# ============ Response Cleaning ============

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
	cleaned = cleaned.replace(" :", ":")
	cleaned = cleaned.replace(" ;", ";")
	
	return cleaned
