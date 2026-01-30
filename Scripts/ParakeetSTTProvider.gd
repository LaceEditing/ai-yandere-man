extends Node
class_name ParakeetSTTProvider

## Parakeet Speech-to-Text Provider - NVIDIA NIM API Only
## Handles communication with NVIDIA's Parakeet TDT API for voice transcription

signal transcription_received(text: String)
signal transcription_failed(error: String)

# API Configuration
var api_key: String = ""
const NVIDIA_NIM_ENDPOINT = "https://integrate.api.nvidia.com/v1/audio/transcriptions"

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
	print("Parakeet API key configured")

## Transcribe audio data (WAV format bytes)
func transcribe_audio(audio_data: PackedByteArray):
	if is_transcribing:
		transcription_failed.emit("Transcription already in progress")
		return
	
	if api_key.is_empty():
		transcription_failed.emit("API key required for NVIDIA NIM. Please configure in settings (Tab key).")
		return
	
	is_transcribing = true
	print("Sending audio to NVIDIA Parakeet API (", audio_data.size(), " bytes)...")
	
	# Prepare multipart form data
	var boundary = "----GodotFormBoundary" + str(Time.get_ticks_msec())
	var body = _create_multipart_body(audio_data, boundary)
	
	# Prepare headers
	var headers: PackedStringArray = [
		"Content-Type: multipart/form-data; boundary=" + boundary,
		"Authorization: Bearer " + api_key
	]
	
	# Send request using request_raw for binary data
	var error = http_request.request_raw(NVIDIA_NIM_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		is_transcribing = false
		transcription_failed.emit("Failed to send request: " + str(error))

func _create_multipart_body(audio_data: PackedByteArray, boundary: String) -> PackedByteArray:
	var body = PackedByteArray()
	
	# Start boundary
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	
	# File header
	body.append_array("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".to_utf8_buffer())
	body.append_array("Content-Type: audio/wav\r\n\r\n".to_utf8_buffer())
	
	# Audio data
	body.append_array(audio_data)
	
	# End boundary
	body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())
	
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
		var error_msg = "API error (code " + str(response_code) + "): " + error_body
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
	
	# NVIDIA NIM format: { "text": "..." }
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
	return "Ready - NVIDIA NIM configured"
