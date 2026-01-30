extends Node
class_name GroqProvider

## Handles communication with Groq API for cloud-based LLM inference
## Only includes models that support function/tool calling
## Updated: January 2025

signal response_updated(token: String)
signal response_finished(full_response: String)
signal request_failed(error: String)

# API Configuration
var api_key: String = ""
var api_endpoint: String = "https://api.groq.com/openai/v1/chat/completions"

# ============ PRODUCTION MODELS (Tool Calling Supported) ============
const PRODUCTION_MODELS: Dictionary = {
	"llama-3.3-70b-versatile": {
		"name": "Llama 3.3 70B Versatile",
		"description": "High quality, 131K context, tool use supported",
		"speed": "280 t/s",
		"category": "production"
	},
	"llama-3.1-8b-instant": {
		"name": "Llama 3.1 8B Instant", 
		"description": "Very fast, 131K context, tool use supported",
		"speed": "560 t/s",
		"category": "production"
	},
	"openai/gpt-oss-120b": {
		"name": "GPT-OSS 120B",
		"description": "OpenAI flagship, parallel tool use, reasoning",
		"speed": "500 t/s",
		"category": "production"
	},
	"openai/gpt-oss-20b": {
		"name": "GPT-OSS 20B",
		"description": "Fast OpenAI model, tool use supported",
		"speed": "1000 t/s",
		"category": "production"
	},
}

# ============ PREVIEW MODELS (Tool Calling Supported) ============
const PREVIEW_MODELS: Dictionary = {
	"meta-llama/llama-4-maverick-17b-128e-instruct": {
		"name": "Llama 4 Maverick 17B",
		"description": "Llama 4, vision + tool use, 131K context",
		"speed": "600 t/s",
		"category": "preview"
	},
	"meta-llama/llama-4-scout-17b-16e-instruct": {
		"name": "Llama 4 Scout 17B",
		"description": "Fast Llama 4, vision + tool use",
		"speed": "750 t/s",
		"category": "preview"
	},
	"qwen/qwen3-32b": {
		"name": "Qwen3 32B",
		"description": "Alibaba Qwen3, tool use, 131K context",
		"speed": "400 t/s",
		"category": "preview"
	},
	"moonshotai/kimi-k2-instruct-0905": {
		"name": "Kimi K2",
		"description": "Moonshot AI, tool use, 262K context (largest!)",
		"speed": "200 t/s",
		"category": "preview"
	},
}

# Combined dictionary for easy lookup
var AVAILABLE_MODELS: Dictionary = {}

var current_model: String = "llama-3.1-8b-instant"

# Request state
var http_request: HTTPRequest = null
var is_requesting: bool = false
var current_response: String = ""
var system_prompt: String = ""
var conversation_history: Array = []

func _ready():
	# Build combined model dictionary
	AVAILABLE_MODELS.merge(PRODUCTION_MODELS)
	AVAILABLE_MODELS.merge(PREVIEW_MODELS)
	
	http_request = HTTPRequest.new()
	http_request.timeout = 60.0
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func set_api_key(key: String):
	api_key = key

func set_model(model: String):
	if model in AVAILABLE_MODELS:
		current_model = model
		print("Groq model set to: ", model)
	else:
		push_warning("Unknown Groq model: ", model, ". Using default.")

func set_system_prompt(prompt: String):
	system_prompt = prompt

func clear_history():
	conversation_history.clear()

func ask(message: String, history: Array = []):
	if api_key.is_empty():
		request_failed.emit("Groq API key not set. Please configure in settings.")
		return
	
	if is_requesting:
		request_failed.emit("Request already in progress")
		return
	
	is_requesting = true
	current_response = ""
	
	# Build messages array
	var messages: Array = []
	
	# Add system prompt
	if not system_prompt.is_empty():
		messages.append({
			"role": "system",
			"content": system_prompt
		})
	
	# Add conversation history
	for entry in history:
		messages.append(entry)
	
	# Add current message
	messages.append({
		"role": "user",
		"content": message
	})
	
	# Build request body
	var body: Dictionary = {
		"model": current_model,
		"messages": messages,
		"max_tokens": 512,
		"temperature": 0.8,
		"stream": false
	}
	
	var json_body: String = JSON.stringify(body)
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	print("Sending request to Groq API with model: ", current_model)
	var error: int = http_request.request(api_endpoint, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		is_requesting = false
		request_failed.emit("Failed to send HTTP request: " + str(error))

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	is_requesting = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg: String = "HTTP request failed with result: " + str(result)
		print(error_msg)
		request_failed.emit(error_msg)
		return
	
	if response_code != 200:
		var error_body: String = body.get_string_from_utf8()
		var error_msg: String = "Groq API error (code " + str(response_code) + "): " + error_body
		print(error_msg)
		request_failed.emit(error_msg)
		return
	
	# Parse response
	var json_string: String = body.get_string_from_utf8()
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(json_string)
	
	if parse_result != OK:
		request_failed.emit("Failed to parse JSON response")
		return
	
	var data: Dictionary = json.get_data()
	
	if data.has("choices") and data.choices.size() > 0:
		var message: Dictionary = data.choices[0].message
		if message.has("content"):
			current_response = message.content
			response_updated.emit(current_response)
			response_finished.emit(current_response)
			print("Groq response received: ", current_response.substr(0, 50), "...")
	else:
		request_failed.emit("Unexpected response format from Groq API")

func is_busy() -> bool:
	return is_requesting

# ============ Static Accessors ============

static func get_production_models() -> Dictionary:
	return PRODUCTION_MODELS

static func get_preview_models() -> Dictionary:
	return PREVIEW_MODELS

static func get_all_models() -> Dictionary:
	var all_models: Dictionary = {}
	all_models.merge(PRODUCTION_MODELS)
	all_models.merge(PREVIEW_MODELS)
	return all_models

# For backward compatibility
static func get_available_models() -> Dictionary:
	return get_all_models()

# Get display name for a model
static func get_model_display_name(model_id: String) -> String:
	var all_models = get_all_models()
	if model_id in all_models:
		var info: Dictionary = all_models[model_id]
		var category_prefix: String = ""
		if info.category == "preview":
			category_prefix = "[Preview] "
		return category_prefix + info.name + " - " + info.speed
	return model_id
