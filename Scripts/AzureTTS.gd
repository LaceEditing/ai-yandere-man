extends Node
class_name AzureTTS

## Azure TTS - High-quality neural text-to-speech with emotional styles
## Requires Azure Cognitive Services Speech API key
## Documentation: https://learn.microsoft.com/en-us/azure/ai-services/speech-service/

signal synthesis_started()
signal synthesis_completed(audio_stream: AudioStreamWAV)
signal synthesis_failed(error: String)

# Azure Configuration
var api_key: String = ""
var region: String = "eastus"  # Azure region (eastus, westus2, etc.)

# Voice settings
var voice_name: String = "en-US-GuyNeural"  # Default male voice
var voice_style: String = ""  # Emotion style (cheerful, angry, sad, etc.)
var voice_style_degree: float = 1.0  # Style intensity 0.01-2.0
var voice_rate: float = 1.0  # Speed multiplier (0.5-2.0)
var voice_pitch: String = "0%"  # Pitch adjustment (-50% to +50%)

# State
var is_synthesizing: bool = false
var _http_request: HTTPRequest = null
var _pending_audio: AudioStreamWAV = null

# Available Azure Neural Voices with emotion/style support
const AZURE_VOICES: Dictionary = {
	# American English - Female
	"en-US-JennyNeural": {
		"desc": "American Female - Jenny (Expressive)",
		"styles": ["assistant", "chat", "cheerful", "customerservice", "newscast", "angry", "sad", "excited", "friendly", "terrified", "shouting", "unfriendly", "whispering", "hopeful"]
	},
	"en-US-AriaNeural": {
		"desc": "American Female - Aria (Expressive)",
		"styles": ["chat", "customerservice", "narration-professional", "newscast-casual", "newscast-formal", "cheerful", "empathetic", "angry", "sad", "excited", "friendly", "terrified", "shouting", "unfriendly", "whispering", "hopeful"]
	},
	"en-US-SaraNeural": {
		"desc": "American Female - Sara",
		"styles": ["angry", "cheerful", "excited", "friendly", "hopeful", "sad", "shouting", "terrified", "unfriendly", "whispering"]
	},
	# American English - Male
	"en-US-GuyNeural": {
		"desc": "American Male - Guy (Expressive)",
		"styles": ["newscast", "angry", "cheerful", "sad", "excited", "friendly", "terrified", "shouting", "unfriendly", "whispering", "hopeful"]
	},
	"en-US-DavisNeural": {
		"desc": "American Male - Davis (Expressive)",
		"styles": ["chat", "angry", "cheerful", "excited", "friendly", "hopeful", "sad", "shouting", "terrified", "unfriendly", "whispering"]
	},
	"en-US-TonyNeural": {
		"desc": "American Male - Tony",
		"styles": ["angry", "cheerful", "excited", "friendly", "hopeful", "sad", "shouting", "terrified", "unfriendly", "whispering"]
	},
	"en-US-JasonNeural": {
		"desc": "American Male - Jason",
		"styles": ["angry", "cheerful", "excited", "friendly", "hopeful", "sad", "shouting", "terrified", "unfriendly", "whispering"]
	},
	# British English
	"en-GB-SoniaNeural": {
		"desc": "British Female - Sonia",
		"styles": ["cheerful", "sad"]
	},
	"en-GB-RyanNeural": {
		"desc": "British Male - Ryan",
		"styles": ["chat", "cheerful"]
	},
	# Additional voices without specific emotion styles
	"en-US-MichelleNeural": {"desc": "American Female - Michelle", "styles": []},
	"en-US-BrandonNeural": {"desc": "American Male - Brandon", "styles": []},
	"en-US-ChristopherNeural": {"desc": "American Male - Christopher", "styles": []},
	"en-US-EricNeural": {"desc": "American Male - Eric", "styles": []},
	"en-US-JacobNeural": {"desc": "American Male - Jacob", "styles": []},
}

# Map game emotions to Azure voice styles
const EMOTION_TO_STYLE: Dictionary = {
	# Core emotions
	"happy": "cheerful",
	"angry": "angry",
	"sad": "sad",
	"fearful": "terrified",
	"disgusted": "unfriendly",
	"surprised": "excited",
	"flirty": "friendly",
	"tired": "sad",  # Lower energy, closest match
	"hostility": "shouting",
	"trust": "friendly",
	# Voice style emotions (direct Azure style mapping)
	"shouting": "shouting",
	"whispering": "whispering",
	"hopeful": "hopeful",
	"excited": "excited",
}


func _ready():
	_setup_http_request()
	_load_settings()


func _setup_http_request():
	_http_request = HTTPRequest.new()
	_http_request.name = "AzureHTTPRequest"
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)


func _load_settings():
	"""Load API key and region from settings file."""
	var config = ConfigFile.new()
	var err = config.load("user://ai_settings.cfg")
	if err == OK:
		api_key = config.get_value("tts", "azure_api_key", "")
		region = config.get_value("tts", "azure_region", "eastus")


func save_settings():
	"""Save API key and region to settings file."""
	var config = ConfigFile.new()
	config.load("user://ai_settings.cfg")  # Load existing to preserve other settings
	config.set_value("tts", "azure_api_key", api_key)
	config.set_value("tts", "azure_region", region)
	config.save("user://ai_settings.cfg")


func is_available() -> bool:
	"""Check if Azure TTS is configured and ready."""
	return not api_key.is_empty() and not region.is_empty()


func is_busy() -> bool:
	"""Check if currently synthesizing."""
	return is_synthesizing


func get_status() -> String:
	"""Get human-readable status."""
	if api_key.is_empty():
		return "Azure TTS - No API key configured"
	if is_synthesizing:
		return "Synthesizing..."
	return "Ready (Azure)"


func get_voice_description(voice: String) -> String:
	"""Get human-readable voice description."""
	if voice in AZURE_VOICES:
		return AZURE_VOICES[voice].desc
	return voice


func get_available_voices() -> Dictionary:
	"""Get all available Azure voices."""
	return AZURE_VOICES


func get_voice_styles(voice: String) -> Array:
	"""Get available emotion styles for a voice."""
	if voice in AZURE_VOICES:
		return AZURE_VOICES[voice].styles
	return []


func has_style_support(voice: String) -> bool:
	"""Check if voice supports emotional styles."""
	return voice in AZURE_VOICES and AZURE_VOICES[voice].styles.size() > 0


func set_voice(voice: String):
	"""Set the voice to use."""
	voice_name = voice


func set_style(style: String, degree: float = 1.0):
	"""Set emotional style and intensity."""
	voice_style = style
	voice_style_degree = clampf(degree, 0.01, 2.0)


func set_style_from_emotion(emotion_name: String, intensity: int = 50):
	"""Convert game emotion to Azure style."""
	if emotion_name in EMOTION_TO_STYLE:
		voice_style = EMOTION_TO_STYLE[emotion_name]
		# Map 0-100 intensity to 0.5-2.0 degree
		voice_style_degree = remap(float(intensity), 0.0, 100.0, 0.5, 2.0)
	else:
		voice_style = ""
		voice_style_degree = 1.0


func set_style_from_emotions(emotions: Dictionary):
	"""Auto-set style based on dominant emotion from multi-emotion dict."""
	var max_intensity = 30  # Minimum threshold
	var dominant_emotion = ""
	
	for emotion in emotions:
		if emotions[emotion] > max_intensity:
			max_intensity = emotions[emotion]
			dominant_emotion = emotion
	
	if dominant_emotion:
		set_style_from_emotion(dominant_emotion, max_intensity)
	else:
		voice_style = ""
		voice_style_degree = 1.0


func set_rate(rate: float):
	"""Set speech rate (0.5-2.0, 1.0 = normal)."""
	voice_rate = clampf(rate, 0.5, 2.0)


func set_pitch(pitch_percent: int):
	"""Set pitch adjustment (-50 to +50 percent)."""
	pitch_percent = clampi(pitch_percent, -50, 50)
	voice_pitch = "%d%%" % pitch_percent if pitch_percent >= 0 else "%d%%" % pitch_percent


func synthesize(text: String):
	"""Synthesize text to speech using Azure (async)."""
	if is_synthesizing:
		synthesis_failed.emit("Already synthesizing")
		return
	
	if text.strip_edges().is_empty():
		synthesis_failed.emit("No text provided")
		return
	
	if not is_available():
		synthesis_failed.emit("Azure TTS not configured - missing API key")
		return
	
	is_synthesizing = true
	synthesis_started.emit()
	
	# Build SSML
	var ssml = _build_ssml(text)
	
	# Make request to Azure
	var url = "https://%s.tts.speech.microsoft.com/cognitiveservices/v1" % region
	var headers = [
		"Ocp-Apim-Subscription-Key: %s" % api_key,
		"Content-Type: application/ssml+xml",
		"X-Microsoft-OutputFormat: riff-24khz-16bit-mono-pcm",
		"User-Agent: GodotGame"
	]
	
	var error = _http_request.request(url, headers, HTTPClient.METHOD_POST, ssml)
	if error != OK:
		is_synthesizing = false
		synthesis_failed.emit("Failed to send request: " + str(error))


func _build_ssml(text: String) -> String:
	"""Build SSML markup for Azure TTS."""
	var ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
	ssml += 'xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="en-US">'
	
	ssml += '<voice name="%s">' % voice_name
	
	# Add emotional style if supported and set
	if voice_style and has_style_support(voice_name) and voice_style in get_voice_styles(voice_name):
		ssml += '<mstts:express-as style="%s" styledegree="%.2f">' % [voice_style, voice_style_degree]
	
	# Add prosody (rate/pitch)
	var rate_str = "%.0f%%" % ((voice_rate - 1.0) * 100)
	if voice_rate >= 1.0:
		rate_str = "+%.0f%%" % ((voice_rate - 1.0) * 100)
	
	ssml += '<prosody rate="%s" pitch="%s">' % [rate_str, voice_pitch]
	
	# Escape text for XML
	var escaped_text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;").replace("'", "&apos;")
	ssml += escaped_text
	
	ssml += '</prosody>'
	
	if voice_style and has_style_support(voice_name) and voice_style in get_voice_styles(voice_name):
		ssml += '</mstts:express-as>'
	
	ssml += '</voice></speak>'
	
	return ssml


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle Azure API response."""
	is_synthesizing = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		synthesis_failed.emit("HTTP request failed: " + str(result))
		return
	
	if response_code != 200:
		var error_msg = "Azure API error %d" % response_code
		if body.size() > 0:
			error_msg += ": " + body.get_string_from_utf8()
		synthesis_failed.emit(error_msg)
		return
	
	# Parse WAV from response
	var audio = _parse_wav(body)
	if audio:
		synthesis_completed.emit(audio)
	else:
		synthesis_failed.emit("Failed to parse audio response")


func _parse_wav(data: PackedByteArray) -> AudioStreamWAV:
	"""Parse WAV data from Azure response."""
	if data.size() < 44:  # WAV header is 44 bytes
		return null
	
	# Verify RIFF header
	if data[0] != 0x52 or data[1] != 0x49 or data[2] != 0x46 or data[3] != 0x46:
		push_error("Invalid WAV: not RIFF")
		return null
	
	# Read WAV format info from header
	var channels = data[22] | (data[23] << 8)
	var sample_rate = data[24] | (data[25] << 8) | (data[26] << 16) | (data[27] << 24)
	var bits_per_sample = data[34] | (data[35] << 8)
	
	# Find data chunk
	var data_start = 12
	while data_start < data.size() - 8:
		var chunk_id = data.slice(data_start, data_start + 4).get_string_from_ascii()
		var chunk_size = data[data_start + 4] | (data[data_start + 5] << 8) | (data[data_start + 6] << 16) | (data[data_start + 7] << 24)
		
		if chunk_id == "data":
			data_start += 8
			break
		data_start += 8 + chunk_size
	
	if data_start >= data.size():
		push_error("Invalid WAV: no data chunk")
		return null
	
	# Create AudioStreamWAV
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = sample_rate
	audio.stereo = channels == 2
	audio.data = data.slice(data_start)
	
	return audio


# ============ CONVENIENCE METHODS ============

func speak(text: String, emotion: String = "", intensity: int = 50):
	"""Convenience method: set emotion and synthesize in one call."""
	if emotion:
		set_style_from_emotion(emotion, intensity)
	synthesize(text)


func speak_with_emotions(text: String, emotions: Dictionary):
	"""Convenience method: auto-detect dominant emotion and speak."""
	set_style_from_emotions(emotions)
	synthesize(text)
