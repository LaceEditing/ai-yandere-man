extends Node
class_name GroqWhisperSTT

## Groq Whisper Speech-to-Text Provider
## Uses Groq's Whisper Large V3 Turbo for fast, accurate transcription
## Same API key as Groq LLM!

signal transcription_received(text: String)
signal transcription_failed(error: String)

# API Configuration
var api_key: String = ""
const GROQ_STT_ENDPOINT = "https://api.groq.com/openai/v1/audio/transcriptions"

# Models available
const MODEL_TURBO = "whisper-large-v3-turbo"  # Faster, $0.04/hour
const MODEL_V3 = "whisper-large-v3"           # More accurate

var current_model: String = MODEL_TURBO  # Default to turbo for speed

# Request state
var http_request: HTTPRequest = null
var is_transcribing: bool = false

func _ready():
	http_request = HTTPRequest.new()
	http_request.timeout = 30.0
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func set_api_key(key: String):
	api_key = key
	print("Groq Whisper API key configured")

func set_model(model: String):
	if model in [MODEL_TURBO, MODEL_V3]:
		current_model = model
		print("Groq Whisper model set to: ", model)

## Transcribe audio data (WAV format bytes)
func transcribe_audio(audio_data: PackedByteArray):
	if is_transcribing:
		transcription_failed.emit("Transcription already in progress")
		return
	
	if api_key.is_empty():
		transcription_failed.emit("Groq API key required. Please configure in settings (Tab key).")
		return
	
	is_transcribing = true
	print("Sending audio to Groq Whisper (", audio_data.size(), " bytes)...")
	
	# Prepare multipart form data
	var boundary = "----GodotFormBoundary" + str(Time.get_ticks_msec())
	var body = _create_multipart_body(audio_data, boundary)
	
	# Prepare headers
	var headers: PackedStringArray = [
		"Content-Type: multipart/form-data; boundary=" + boundary,
		"Authorization: Bearer " + api_key
	]
	
	# Send request using request_raw for binary data
	var error = http_request.request_raw(GROQ_STT_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		is_transcribing = false
		transcription_failed.emit("Failed to send request: " + str(error))

func _create_multipart_body(audio_data: PackedByteArray, boundary: String) -> PackedByteArray:
	var body = PackedByteArray()
	
	# File field
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".to_utf8_buffer())
	body.append_array("Content-Type: audio/wav\r\n\r\n".to_utf8_buffer())
	body.append_array(audio_data)
	body.append_array("\r\n".to_utf8_buffer())
	
	# Model field
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"model\"\r\n\r\n".to_utf8_buffer())
	body.append_array(current_model.to_utf8_buffer())
	body.append_array("\r\n".to_utf8_buffer())
	
	# End boundary
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())
	
	return body

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	is_transcribing = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "HTTP request failed: " + str(result)
		print(error_msg)
		transcription_failed.emit(error_msg)
		return
	
	if response_code != 200:
		var error_body = body.get_string_from_utf8()
		var error_msg = "Groq API error (code " + str(response_code) + "): " + error_body
		print(error_msg)
		transcription_failed.emit(error_msg)
		return
	
	# Parse response
	var json_string = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		transcription_failed.emit("Failed to parse response JSON")
		return
	
	var data = json.get_data()
	
	# Groq Whisper response format: { "text": "..." }
	if data.has("text"):
		var transcription = data.text
		print("Transcription received: ", transcription)
		transcription_received.emit(transcription)
	else:
		transcription_failed.emit("No transcription in response")

func is_busy() -> bool:
	return is_transcribing

func get_status() -> String:
	if api_key.is_empty():
		return "Not configured - API key required"
	return "Ready - Groq Whisper " + ("Turbo" if current_model == MODEL_TURBO else "V3")
