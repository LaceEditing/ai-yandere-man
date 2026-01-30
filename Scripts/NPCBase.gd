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

# Text cleaning settings
@export_group("Response Filtering")
@export var remove_action_markers: bool = true ## Remove asterisks, parentheses, and brackets like *(smiles)* or (laughs) from responses.

@export var remove_asterisks: bool = true ## Remove *action* formatting.

@export var remove_parentheses: bool = true ## Remove (action) formatting.

@export var remove_brackets: bool = true ## Remove [action] formatting.

# References
@onready var chat_node = $ChatNode

# State
var is_talking = false
var current_response = ""
var conversation_history: Array = []
var forget_timer: Timer
var system_prompt: String = ""

# Groq-specific state
var groq_provider = null
var using_groq: bool = false

signal dialogue_updated(text: String)
signal dialogue_finished(text: String)

func _ready():
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

func _setup_groq():
	# Setup for Groq API
	groq_provider = AIManager.get_chat_provider()
	
	if groq_provider:
		_connect_groq_signals()
		print(npc_name, " using Groq API")
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

	if enable_memory:
		prompt += """
11. REMEMBER what has been said in this conversation
12. Stay CONSISTENT with information you've already shared
13. Reference past topics naturally when relevant
14. Don't repeat yourself unless asked"""

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

	if enable_memory:
		prompt += """
# MEMORY EXAMPLES:
GOOD: Player asks "What's your name?" → You answer "Marcus" → Later player says "Hey Marcus" → You respond naturally
BAD: Player asks "What's your name?" → You answer "Marcus" → Later you introduce yourself again as if meeting for first time

GOOD: You tell player "I used to adventure" → Player asks "What happened?" → You build on that story
BAD: You tell player "I used to adventure" → Later you contradict yourself saying you never left town
"""

	prompt += """
Remember: 
- ONLY dialogue that would come out of your mouth
- NO actions in parentheses, brackets, or asterisks
- Express everything through spoken words
- Short, natural, in-character"""

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
		"world_lore": WorldLore.WORLD_LORE,
		"location_lore": WorldLore.get_location_lore(npc_location)
	})

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
	chat_node.ask(message)

func _send_to_groq(message: String):
	if not groq_provider:
		dialogue_finished.emit("[Error: Groq provider not available]")
		return
	
	# Set the system prompt
	groq_provider.set_system_prompt(system_prompt)
	
	# Send with conversation history
	var history_to_send = conversation_history.duplicate()
	# Remove the last message since we're sending it separately
	if history_to_send.size() > 0:
		history_to_send.pop_back()
	
	groq_provider.ask(message, history_to_send)

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
