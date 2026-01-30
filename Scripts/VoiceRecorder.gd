extends Node
class_name VoiceRecorder

## Voice Recorder - Captures microphone input and converts to WAV format
## Uses Godot 4's AudioStreamRecord and AudioEffectRecord

signal recording_started()
signal recording_stopped(audio_data: PackedByteArray)
signal recording_error(error: String)

# Recording state
var is_recording: bool = false
var recording_effect: AudioEffectRecord = null
var audio_stream_player: AudioStreamPlayer = null

# Audio settings (Parakeet expects 16kHz mono)
const TARGET_SAMPLE_RATE = 16000
const CHANNELS = 1

func _ready():
	_setup_recording()

func _setup_recording():
	# Create an AudioStreamPlayer for microphone input
	audio_stream_player = AudioStreamPlayer.new()
	audio_stream_player.name = "MicrophonePlayer"
	audio_stream_player.bus = "Record"
	add_child(audio_stream_player)
	
	# Create the Record bus if it doesn't exist
	var record_bus_idx = AudioServer.get_bus_index("Record")
	if record_bus_idx == -1:
		record_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(record_bus_idx)
		AudioServer.set_bus_name(record_bus_idx, "Record")
	
	# Add AudioEffectRecord to the bus
	recording_effect = AudioEffectRecord.new()
	AudioServer.add_bus_effect(record_bus_idx, recording_effect)
	
	# Setup microphone input
	var mic_stream = AudioStreamMicrophone.new()
	audio_stream_player.stream = mic_stream
	
	print("Voice recorder initialized")

func start_recording():
	if is_recording:
		print("Already recording")
		return
	
	if recording_effect == null:
		recording_error.emit("Recording effect not initialized")
		return
	
	# Check if microphone is available
	var input_devices = AudioServer.get_input_device_list()
	if input_devices.size() == 0:
		recording_error.emit("No microphone detected")
		return
	
	# Clear any previous recording
	if recording_effect.get_recording():
		recording_effect.get_recording().data.clear()
	
	# Start recording
	recording_effect.set_recording_active(true)
	audio_stream_player.play()
	is_recording = true
	recording_started.emit()
	print("Recording started...")

func stop_recording():
	if not is_recording:
		print("Not currently recording")
		return
	
	# Stop playback and recording
	audio_stream_player.stop()
	recording_effect.set_recording_active(false)
	is_recording = false
	
	# Get the recorded audio
	var recording: AudioStreamWAV = recording_effect.get_recording()
	
	if recording == null or recording.data.size() == 0:
		recording_error.emit("No audio data captured")
		return
	
	print("Recording stopped. Format: ", recording.format, ", Mix rate: ", recording.mix_rate, ", Stereo: ", recording.stereo)
	
	# Convert to WAV format
	var wav_data = _convert_to_wav(recording)
	
	if wav_data.size() > 0:
		print("WAV data size: ", wav_data.size(), " bytes")
		recording_stopped.emit(wav_data)
	else:
		recording_error.emit("Failed to convert audio to WAV")

func _convert_to_wav(audio_stream: AudioStreamWAV) -> PackedByteArray:
	var audio_data = audio_stream.data
	var sample_rate = audio_stream.mix_rate
	var is_stereo = audio_stream.stereo
	var format = audio_stream.format
	
	# Convert to target format if needed
	var processed_data = audio_data
	var final_sample_rate = sample_rate
	var final_channels = 2 if is_stereo else 1
	
	# Convert stereo to mono if needed
	if is_stereo and CHANNELS == 1:
		processed_data = _stereo_to_mono(processed_data, format)
		final_channels = 1
	
	# Resample if needed
	if sample_rate != TARGET_SAMPLE_RATE:
		processed_data = _resample_audio(processed_data, sample_rate, TARGET_SAMPLE_RATE, format)
		final_sample_rate = TARGET_SAMPLE_RATE
	
	# Ensure 16-bit format
	if format != AudioStreamWAV.FORMAT_16_BITS:
		processed_data = _convert_to_16bit(processed_data, format)
	
	# Create WAV file
	var wav_file = PackedByteArray()
	
	# Calculate sizes
	var data_size = processed_data.size()
	var file_size = 36 + data_size
	
	# RIFF header
	wav_file.append_array("RIFF".to_ascii_buffer())
	wav_file.append_array(_int32_to_bytes(file_size))
	wav_file.append_array("WAVE".to_ascii_buffer())
	
	# fmt chunk
	wav_file.append_array("fmt ".to_ascii_buffer())
	wav_file.append_array(_int32_to_bytes(16))  # fmt chunk size
	wav_file.append_array(_int16_to_bytes(1))   # PCM format
	wav_file.append_array(_int16_to_bytes(final_channels))
	wav_file.append_array(_int32_to_bytes(final_sample_rate))
	wav_file.append_array(_int32_to_bytes(final_sample_rate * final_channels * 2))  # byte rate
	wav_file.append_array(_int16_to_bytes(final_channels * 2))  # block align
	wav_file.append_array(_int16_to_bytes(16))  # bits per sample
	
	# data chunk
	wav_file.append_array("data".to_ascii_buffer())
	wav_file.append_array(_int32_to_bytes(data_size))
	wav_file.append_array(processed_data)
	
	return wav_file

func _stereo_to_mono(stereo_data: PackedByteArray, format: int) -> PackedByteArray:
	var mono_data = PackedByteArray()
	var bytes_per_sample = 2 if format == AudioStreamWAV.FORMAT_16_BITS else 1
	var samples = int(stereo_data.size() / (bytes_per_sample * 2))
	
	mono_data.resize(samples * bytes_per_sample)
	
	for i in range(samples):
		var left_idx = i * bytes_per_sample * 2
		var right_idx = left_idx + bytes_per_sample
		var out_idx = i * bytes_per_sample
		
		if format == AudioStreamWAV.FORMAT_16_BITS:
			var left = _read_int16(stereo_data, left_idx)
			var right = _read_int16(stereo_data, right_idx)
			var avg = int((left + right) / 2)
			_write_int16(mono_data, out_idx, avg)
		else:
			var left = stereo_data[left_idx] - 128
			var right = stereo_data[right_idx] - 128
			mono_data[out_idx] = int((left + right) / 2) + 128
	
	return mono_data

func _resample_audio(data: PackedByteArray, from_rate: int, to_rate: int, format: int) -> PackedByteArray:
	var bytes_per_sample = 2 if format == AudioStreamWAV.FORMAT_16_BITS else 1
	var input_samples = int(data.size() / bytes_per_sample)
	var output_samples = int(float(input_samples) * float(to_rate) / float(from_rate))
	var ratio = float(from_rate) / float(to_rate)
	
	var output = PackedByteArray()
	output.resize(output_samples * bytes_per_sample)
	
	for i in range(output_samples):
		var src_pos = float(i) * ratio
		var src_idx = int(src_pos)
		
		if src_idx >= input_samples - 1:
			src_idx = input_samples - 2
		
		# Linear interpolation
		var frac = src_pos - float(src_idx)
		
		if format == AudioStreamWAV.FORMAT_16_BITS:
			var sample1 = _read_int16(data, src_idx * 2)
			var sample2 = _read_int16(data, (src_idx + 1) * 2)
			var interpolated = int(float(sample1) * (1.0 - frac) + float(sample2) * frac)
			_write_int16(output, i * 2, interpolated)
		else:
			var sample1 = int(data[src_idx]) - 128
			var sample2 = int(data[src_idx + 1]) - 128
			var interpolated = int(float(sample1) * (1.0 - frac) + float(sample2) * frac)
			output[i] = interpolated + 128
	
	return output

func _convert_to_16bit(data: PackedByteArray, from_format: int) -> PackedByteArray:
	if from_format == AudioStreamWAV.FORMAT_16_BITS:
		return data
	
	var output = PackedByteArray()
	output.resize(data.size() * 2)
	
	for i in range(data.size()):
		var sample_8bit = int(data[i]) - 128
		var sample_16bit = sample_8bit * 256
		_write_int16(output, i * 2, sample_16bit)
	
	return output

func _read_int16(data: PackedByteArray, offset: int) -> int:
	var value = data[offset] | (data[offset + 1] << 8)
	if value & 0x8000:
		value = value - 0x10000
	return value

func _write_int16(data: PackedByteArray, offset: int, value: int):
	data[offset] = value & 0xFF
	data[offset + 1] = (value >> 8) & 0xFF

func _int16_to_bytes(value: int) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.resize(2)
	bytes[0] = value & 0xFF
	bytes[1] = (value >> 8) & 0xFF
	return bytes

func _int32_to_bytes(value: int) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.resize(4)
	bytes[0] = value & 0xFF
	bytes[1] = (value >> 8) & 0xFF
	bytes[2] = (value >> 16) & 0xFF
	bytes[3] = (value >> 24) & 0xFF
	return bytes

func is_busy() -> bool:
	return is_recording

func get_recording_duration() -> float:
	if recording_effect and is_recording:
		var recording = recording_effect.get_recording()
		if recording:
			return recording.get_length()
	return 0.0
