extends Node

## Central AI Manager - handles both local (NobodyWho) and cloud (Groq) inference
## All NPCs connect through this manager for unified AI access

enum Provider {
	LOCAL,  # NobodyWho local GGUF models
	GROQ    # Groq cloud API
}

# Current provider setting
var current_provider: Provider = Provider.LOCAL

# Reference to local model (NobodyWho)
@onready var llm_model = $LLMModel

# Reference to Groq provider
@onready var groq_provider = $GroqProvider

# Reference to Groq Whisper STT provider (uses same API key as groq_provider)
@onready var groq_whisper_stt = $GroqWhisperSTT

# Path to local GGUF model file
@export_file("*.gguf") var model_path: String = "res://AIModels/qwen2.5-0.5b-instruct-q4_k_m.gguf"

# Settings persistence
const SETTINGS_PATH = "user://ai_settings.cfg"

# Signals for settings changes
signal provider_changed(provider: Provider)
signal settings_loaded()

func _ready():
	# Create Groq provider if it doesn't exist
	if not has_node("GroqProvider"):
		var groq = GroqProvider.new()
		groq.name = "GroqProvider"
		add_child(groq)
		groq_provider = groq
	
	# Create Groq Whisper STT provider if it doesn't exist
	if not has_node("GroqWhisperSTT"):
		var whisper = GroqWhisperSTT.new()
		whisper.name = "GroqWhisperSTT"
		add_child(whisper)
		groq_whisper_stt = whisper
	
	# Load saved settings
	load_settings()
	
	# Set the local model path
	if llm_model and model_path:
		llm_model.model_path = model_path
		print("AI Manager initialized with local model: ", model_path)
	
	print("AI Manager ready. Current provider: ", get_provider_name())

# ============ Provider Management ============

func set_provider(provider: Provider):
	current_provider = provider
	save_settings()
	provider_changed.emit(provider)
	print("AI Provider changed to: ", get_provider_name())

func get_provider() -> Provider:
	return current_provider

func get_provider_name() -> String:
	match current_provider:
		Provider.LOCAL:
			return "Local (NobodyWho)"
		Provider.GROQ:
			return "Groq API"
	return "Unknown"

func is_local() -> bool:
	return current_provider == Provider.LOCAL

func is_groq() -> bool:
	return current_provider == Provider.GROQ

# ============ Groq Configuration ============

func set_groq_api_key(key: String):
	if groq_provider:
		groq_provider.set_api_key(key)
	# Also set for Groq Whisper STT (shared API key!)
	if groq_whisper_stt:
		groq_whisper_stt.set_api_key(key)
	save_settings()

func get_groq_api_key() -> String:
	if groq_provider:
		return groq_provider.api_key
	return ""

func set_groq_model(model: String):
	if groq_provider:
		groq_provider.set_model(model)
		save_settings()

func get_groq_model() -> String:
	if groq_provider:
		return groq_provider.current_model
	return ""

func get_available_groq_models() -> Dictionary:
	return GroqProvider.get_available_models()

# ============ Voice Input Configuration ============

func set_whisper_model(model: String):
	if groq_whisper_stt:
		groq_whisper_stt.set_model(model)
		save_settings()

func get_whisper_model() -> String:
	if groq_whisper_stt:
		return groq_whisper_stt.current_model
	return "whisper-large-v3-turbo"

# ============ Local Model Configuration ============

func set_local_model_path(path: String):
	model_path = path
	if llm_model:
		llm_model.model_path = path
	save_settings()

func get_local_model_path() -> String:
	return model_path

# ============ Unified Interface for NPCs ============

## Get the appropriate provider for NPCs to use
func get_chat_provider():
	if current_provider == Provider.GROQ:
		return groq_provider
	return null  # NPCs will use their ChatNode for local

## Get the STT provider for voice input
func get_stt_provider():
	return groq_whisper_stt

## Check if we should use local NobodyWho chat nodes
func should_use_local_chat() -> bool:
	return current_provider == Provider.LOCAL

## Check if API is properly configured
func is_provider_ready() -> bool:
	match current_provider:
		Provider.LOCAL:
			return llm_model != null
		Provider.GROQ:
			return groq_provider != null and not groq_provider.api_key.is_empty()
	return false

func get_provider_status() -> String:
	match current_provider:
		Provider.LOCAL:
			if llm_model:
				return "Ready - Local model loaded"
			return "Error - Local model not loaded"
		Provider.GROQ:
			if not groq_provider:
				return "Error - Groq provider not initialized"
			if groq_provider.api_key.is_empty():
				return "Not configured - API key required"
			return "Ready - Groq API configured"
	return "Unknown status"

## Check if voice input is configured
func is_voice_input_ready() -> bool:
	if not groq_whisper_stt:
		return false
	return not groq_whisper_stt.api_key.is_empty()

func get_voice_input_status() -> String:
	if not groq_whisper_stt:
		return "Not available"
	if groq_whisper_stt.api_key.is_empty():
		return "Not configured - Groq API key required"
	return "Ready - Groq Whisper Turbo"

# ============ Settings Persistence ============

func save_settings():
	var config = ConfigFile.new()
	
	# Provider settings
	config.set_value("ai", "provider", current_provider)
	config.set_value("ai", "local_model_path", model_path)
	
	# Groq settings (shared by both LLM and STT)
	if groq_provider:
		config.set_value("groq", "api_key", groq_provider.api_key)
		config.set_value("groq", "model", groq_provider.current_model)
	
	# Whisper model preference
	if groq_whisper_stt:
		config.set_value("groq", "whisper_model", groq_whisper_stt.current_model)
	
	var error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Failed to save AI settings: ", error)
	else:
		print("AI settings saved")

func load_settings():
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_PATH)
	
	if error != OK:
		print("No saved AI settings found, using defaults")
		return
	
	# Provider settings
	current_provider = config.get_value("ai", "provider", Provider.LOCAL)
	model_path = config.get_value("ai", "local_model_path", model_path)
	
	# Apply local model path
	if llm_model:
		llm_model.model_path = model_path
	
	# Groq settings
	if groq_provider:
		var api_key = config.get_value("groq", "api_key", "")
		var groq_model = config.get_value("groq", "model", "llama-3.1-8b-instant")
		groq_provider.set_api_key(api_key)
		groq_provider.set_model(groq_model)
		
		# Share API key with Groq Whisper STT
		if groq_whisper_stt:
			groq_whisper_stt.set_api_key(api_key)
	
	# Whisper model preference
	if groq_whisper_stt:
		var whisper_model = config.get_value("groq", "whisper_model", "whisper-large-v3-turbo")
		groq_whisper_stt.set_model(whisper_model)
	
	print("AI settings loaded. Provider: ", get_provider_name())
	settings_loaded.emit()

func reset_to_defaults():
	current_provider = Provider.LOCAL
	model_path = "res://AIModels/qwen2.5-0.5b-instruct-q4_k_m.gguf"
	if groq_provider:
		groq_provider.set_api_key("")
		groq_provider.set_model("llama-3.1-8b-instant")
	if groq_whisper_stt:
		groq_whisper_stt.set_api_key("")
		groq_whisper_stt.set_model("whisper-large-v3-turbo")
	save_settings()
	print("AI settings reset to defaults")
