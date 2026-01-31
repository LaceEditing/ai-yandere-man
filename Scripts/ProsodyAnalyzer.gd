extends Node
class_name ProsodyAnalyzer

## Prosody Analyzer - Intelligently adds emphasis and prosody to text
## Analyzes sentence structure, part-of-speech patterns, and context
## to make TTS output more natural and expressive

# Word importance weights
const IMPORTANT_VERBS = ["hate", "love", "need", "want", "kill", "save", "destroy", "create"]
const EMOTION_WORDS = ["angry", "sad", "happy", "scared", "excited", "nervous", "confident"]
const INTENSIFIERS = ["very", "really", "so", "extremely", "absolutely", "totally", "completely"]

# Punctuation patterns for emphasis
const EMPHASIS_WORDS = ["no", "yes", "never", "always", "everything", "nothing", "everyone", "nobody"]

## Main function: Analyze and enhance text with prosody markers
static func enhance_text(text: String, mood: int = -1, personality_traits: Dictionary = {}) -> String:
	var result = text
	
	# Step 1: Identify sentence boundaries and structure
	var sentences = _split_into_sentences(result)
	var enhanced_sentences: Array = []
	
	for sentence in sentences:
		var enhanced = _enhance_sentence(sentence, mood, personality_traits)
		enhanced_sentences.append(enhanced)
	
	result = " ".join(enhanced_sentences)
	
	# Step 2: Add mood-specific markers
	if mood >= 0:
		result = _add_mood_markers(result, mood)
	
	# Step 3: Balance prosody (don't over-do it)
	result = _balance_prosody(result)
	
	return result

## Split text into sentences
static func _split_into_sentences(text: String) -> Array:
	var sentences: Array = []
	var current = ""
	
	for i in range(text.length()):
		var char = text[i]
		current += char
		
		# Check for sentence end
		if char in [".", "!", "?"]:
			# Make sure it's not an abbreviation
			if i < text.length() - 1:
				var next_char = text[i + 1]
				if next_char == " " or next_char == "\n":
					sentences.append(current.strip_edges())
					current = ""
			else:
				sentences.append(current.strip_edges())
				current = ""
	
	# Add remaining text
	if not current.is_empty():
		sentences.append(current.strip_edges())
	
	return sentences

## Enhance a single sentence with prosody
static func _enhance_sentence(sentence: String, mood: int, personality_traits: Dictionary) -> String:
	var result = sentence
	
	# Analyze sentence structure
	var is_question = sentence.ends_with("?")
	var is_exclamation = sentence.ends_with("!")
	var words = sentence.split(" ")
	
	# Emphasis on important words
	result = _add_word_emphasis(result, words, mood, personality_traits)
	
	# Add pauses for dramatic effect
	result = _add_strategic_pauses(result, is_question, is_exclamation, mood)
	
	# Adjust punctuation for emotion
	result = _adjust_punctuation(result, mood)
	
	return result

## Add emphasis to important words
static func _add_word_emphasis(text: String, words: Array, mood: int, personality_traits: Dictionary) -> String:
	var result = text
	
	# Find important words and emphasize them
	for word in words:
		var clean_word = word.to_lower().strip_edges().trim_suffix(",").trim_suffix(".").trim_suffix("!").trim_suffix("?")
		
		# Check if word should be emphasized
		var should_emphasize = false
		var emphasis_level = 1  # 1 = normal, 2 = strong, 3 = very strong
		
		# Emotion words - always emphasize
		if clean_word in EMOTION_WORDS:
			should_emphasize = true
			emphasis_level = 2
		
		# Important verbs - moderate emphasis
		elif clean_word in IMPORTANT_VERBS:
			should_emphasize = true
			emphasis_level = 2
		
		# Intensifiers - light emphasis
		elif clean_word in INTENSIFIERS:
			should_emphasize = true
			emphasis_level = 1
		
		# Emphasis words (no, yes, never, etc)
		elif clean_word in EMPHASIS_WORDS:
			should_emphasize = true
			emphasis_level = 3
		
		# Mood-specific emphasis
		if mood >= 0:
			if mood == 2:  # ANGRY
				if clean_word in ["you", "me", "now", "stop", "don't"]:
					should_emphasize = true
					emphasis_level = 3
			elif mood == 1:  # HAPPY
				if clean_word in ["great", "wonderful", "amazing", "perfect", "love"]:
					should_emphasize = true
					emphasis_level = 2
			elif mood == 3:  # SAD
				if clean_word in ["sorry", "miss", "lost", "gone", "wish"]:
					should_emphasize = true
					emphasis_level = 2
		
		# Apply emphasis
		if should_emphasize:
			var original_word = _find_word_in_text(result, word)
			if not original_word.is_empty():
				var emphasized = _emphasize_word(original_word, emphasis_level)
				result = result.replace(original_word, emphasized)
	
	return result

## Find exact word in text (preserving case and punctuation)
static func _find_word_in_text(text: String, word: String) -> String:
	var pattern = word.strip_edges()
	var text_lower = text.to_lower()
	var pattern_lower = pattern.to_lower()
	
	var index = text_lower.find(pattern_lower)
	if index >= 0:
		return text.substr(index, pattern.length())
	
	return ""

## Emphasize a word based on level
static func _emphasize_word(word: String, level: int) -> String:
	match level:
		1:
			# Light emphasis - italicize or slightly louder
			return word.to_upper() if word.length() <= 3 else word
		2:
			# Medium emphasis - ALL CAPS for short words
			if word.length() <= 5:
				return word.to_upper()
			else:
				return word.capitalize()
		3:
			# Strong emphasis - ALL CAPS
			return word.to_upper()
		_:
			return word

## Add strategic pauses (ellipses) for dramatic effect
static func _add_strategic_pauses(text: String, is_question: bool, is_exclamation: bool, mood: int) -> String:
	var result = text
	
	# Don't add pauses to very short sentences
	if text.length() < 15:
		return result
	
	# Sad or tired mood - add pauses
	if mood == 3 or mood == 9:  # SAD or TIRED
		# Add pause before last word or phrase
		var words = text.split(" ")
		if words.size() >= 4:
			var last_word = words[words.size() - 1]
			var second_last = words[words.size() - 2]
			
			# Add pause before final clause
			result = result.replace(" " + second_last + " " + last_word, "... " + second_last + " " + last_word)
	
	# Fearful mood - add pauses for hesitation
	elif mood == 4:  # FEARFUL
		# Add pauses between phrases
		result = result.replace(", ", "... ")
	
	# Sarcastic mood - dramatic pause before punchline
	elif mood == 8:  # SARCASTIC
		var words = text.split(" ")
		if words.size() >= 5:
			var mid_point = int(words.size() / 2)
			words[mid_point] = "... " + words[mid_point]
			result = " ".join(words)
	
	return result

## Adjust punctuation based on mood
static func _adjust_punctuation(text: String, mood: int) -> String:
	var result = text
	
	match mood:
		1:  # HAPPY
			# Add exclamation points for enthusiasm
			if not result.ends_with("!") and not result.ends_with("?"):
				if randf() > 0.6:
					result = result.trim_suffix(".") + "!"
		
		2:  # ANGRY
			# Make everything more punchy
			result = result.replace(", ", "! ")
			if not result.ends_with("!"):
				result = result.trim_suffix(".") + "!"
		
		3:  # SAD
			# Add ellipses for trailing off
			if result.ends_with("."):
				result = result.trim_suffix(".") + "..."
		
		6:  # SURPRISED
			# Add exclamation points
			if not result.ends_with("!") and not result.ends_with("?"):
				result = result.trim_suffix(".") + "!"
	
	return result

## Add mood-specific global markers
static func _add_mood_markers(text: String, mood: int) -> String:
	var result = text
	
	match mood:
		2:  # ANGRY
			# Sharper delivery - remove softeners
			result = result.replace("maybe ", "")
			result = result.replace("perhaps ", "")
			result = result.replace("I think ", "")
			result = result.replace("kind of ", "")
		
		1:  # HAPPY
			# Upbeat delivery - add some energy words
			# (only if they fit naturally)
			pass
		
		3:  # SAD
			# Slower delivery - already handled by pauses
			pass
		
		7:  # FLIRTY
			# Add playful tone markers (tildes work in some TTS)
			# This is subtle and won't break Kokoro
			pass
		
		8:  # SARCASTIC
			# Already handled by strategic pauses
			pass
	
	return result

## Balance prosody - don't overdo emphasis
static func _balance_prosody(text: String) -> String:
	var result = text
	
	# Count emphasis markers
	var caps_count = 0
	var ellipsis_count = 0
	var exclamation_count = 0
	
	for char in text:
		if char.to_upper() == char and char != " ":
			caps_count += 1
		if char == "!":
			exclamation_count += 1
	
	ellipsis_count = text.count("...")
	
	# If too much emphasis, tone it down
	var words = text.split(" ")
	var total_chars = text.length()
	
	# More than 30% caps? Reduce some
	if caps_count > total_chars * 0.3:
		result = _reduce_caps(result)
	
	# More than 3 ellipses in short text? Remove some
	if ellipsis_count > 3 and words.size() < 15:
		result = _reduce_ellipses(result)
	
	# More than 3 exclamation points? Calm down
	if exclamation_count > 3:
		result = _reduce_exclamations(result)
	
	return result

static func _reduce_caps(text: String) -> String:
	var result = text
	var words = text.split(" ")
	var reduced_words: Array = []
	var caps_seen = 0
	
	for word in words:
		if word == word.to_upper() and word.length() > 3:
			caps_seen += 1
			# Keep first and last, reduce middle ones
			if caps_seen % 2 == 0:
				reduced_words.append(word.capitalize())
			else:
				reduced_words.append(word)
		else:
			reduced_words.append(word)
	
	return " ".join(reduced_words)

static func _reduce_ellipses(text: String) -> String:
	var result = text
	var count = 0
	
	while "..." in result and count < 10:  # Safety limit
		var idx = result.find("...")
		if count % 2 == 0:  # Remove every other one
			result = result.substr(0, idx) + " " + result.substr(idx + 3)
		else:
			break  # Keep this one
		count += 1
	
	return result

static func _reduce_exclamations(text: String) -> String:
	var result = text
	var sentences = result.split(". ")
	var reduced: Array = []
	
	for i in range(sentences.size()):
		var sentence = sentences[i]
		# Keep first and last exclamation, tone down middle ones
		if i != 0 and i != sentences.size() - 1:
			sentence = sentence.replace("!", ".")
		reduced.append(sentence)
	
	return ". ".join(reduced)

## Analyze text for emotion words (for mood detection)
static func detect_emotion_keywords(text: String) -> Dictionary:
	var emotions = {
		"angry": 0,
		"happy": 0,
		"sad": 0,
		"fearful": 0,
		"surprised": 0
	}
	
	var text_lower = text.to_lower()
	
	# Angry keywords
	if text_lower.contains("hate") or text_lower.contains("damn") or text_lower.contains("hell"):
		emotions.angry += 1
	if text_lower.contains("furious") or text_lower.contains("angry"):
		emotions.angry += 2
	
	# Happy keywords
	if text_lower.contains("love") or text_lower.contains("great") or text_lower.contains("wonderful"):
		emotions.happy += 1
	if text_lower.contains("happy") or text_lower.contains("joy"):
		emotions.happy += 2
	
	# Sad keywords
	if text_lower.contains("sorry") or text_lower.contains("miss") or text_lower.contains("lost"):
		emotions.sad += 1
	if text_lower.contains("sad") or text_lower.contains("cry"):
		emotions.sad += 2
	
	# Fear keywords
	if text_lower.contains("scared") or text_lower.contains("afraid") or text_lower.contains("worry"):
		emotions.fearful += 1
	if text_lower.contains("terrified") or text_lower.contains("panic"):
		emotions.fearful += 2
	
	# Surprise keywords
	if text_lower.contains("what") or text_lower.contains("wow") or text_lower.contains("oh"):
		emotions.surprised += 1
	
	return emotions

## Get suggested mood based on text analysis
static func suggest_mood_from_text(text: String) -> int:
	var emotions = detect_emotion_keywords(text)
	
	# Find dominant emotion
	var max_score = 0
	var dominant_emotion = "neutral"
	
	for emotion in emotions:
		if emotions[emotion] > max_score:
			max_score = emotions[emotion]
			dominant_emotion = emotion
	
	# Map to mood enum (assuming NPCBase.Mood enum)
	match dominant_emotion:
		"angry":
			return 2  # ANGRY
		"happy":
			return 1  # HAPPY
		"sad":
			return 3  # SAD
		"fearful":
			return 4  # FEARFUL
		"surprised":
			return 6  # SURPRISED
		_:
			return 0  # NEUTRAL
