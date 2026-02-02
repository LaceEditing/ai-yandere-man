# MaleYanderAI Copilot Instructions

## Project Overview
This is a Godot 4.6 game featuring AI-powered NPCs with dynamic dialogue. NPCs use local LLMs (via NobodyWho GDExtension) or cloud APIs (Groq) to generate contextual responses. The project includes TTS/STT, multi-dimensional emotion systems, NPC actions, and spatial awareness.

## Architecture

### Core System Flow
```
Player → NPCManager → NPCBase → ChatNode (NobodyWhoChat)
                                     ↓
                                AIManager (Autoload) → LLMModel (GGUF)
                                     ↓
                                DialogueUI (displays response)
```

### Autoloads (Global Singletons)
Located in [project.godot](project.godot#L21-L29):
- **AIManager**: Central AI model manager, supports local (NobodyWho) and cloud (Groq) providers
- **DialogueUI**: UI for conversations, handles typewriter effects synced with TTS
- **WorldLore**: Global lore and location descriptions
- **NPCManager**: Tracks NPCs, handles player interaction triggers
- **RoomManager**: Spatial awareness system for location-based context
- **AISettingsMenu/UISettingsMenu**: Runtime configuration panels

### Key Components

**NPCBase.gd** ([Scripts/NPCBase.gd](Scripts/NPCBase.gd))
- The heart of NPC behavior - handles personality, emotions, memory, and actions
- Auto-generates unique greetings on spawn using AI (see `generate_greeting_on_start`)
- Integrates KokoroTTS for voice synthesis with prosody/emotion modulation
- Uses action parser to extract embedded commands from LLM responses: `[walk_to:Kitchen]`, `[animate:sit]`, `[look_at:Player]`

**NPCActionParser.gd** ([Scripts/NPCActionParser.gd](Scripts/NPCActionParser.gd))
- Regex-based parser extracting action tags from LLM text
- Returns `{text: "clean_dialogue", actions: [{action: "walk_to", target: "Kitchen"}]}`
- Available actions: movement, animations (idle/walk/sit/dance/macarena/chicken/tenna/break), look_at, stop commands

**AIManager.gd** ([Scripts/AIManager.gd](Scripts/AIManager.gd))
- Enum-based provider switching: `Provider.LOCAL` (NobodyWho) or `Provider.GROQ`
- Loads GGUF models from [AIModels/](AIModels/) directory (currently using qwen2.5-0.5b)
- Shares single model instance across all NPCs for efficiency

**DialogueUI.gd** ([Scripts/DialogueUI.gd](Scripts/DialogueUI.gd))
- AI2U-style dialogue display with auto-scaling based on screen resolution
- Supports auto-greetings without opening input field
- Voice sync: typewriter effect waits for TTS to start before displaying text
- Push-to-talk with 'V' key for voice input (uses VoiceRecorder + STT)

**RoomManager.gd** ([Scripts/RoomManager.gd](Scripts/RoomManager.gd))
- Tracks player and NPC locations across named rooms
- Provides spatial queries: `is_player_in_same_room_as_npc()`, `get_npcs_in_room()`
- Used by NPCs for context beyond vision (e.g., "Player just entered from Kitchen")

## Development Patterns

### NPC System Prompt Construction
NPCs build system prompts dynamically from exported properties:
```gdscript
@export var npc_name: String
@export_multiline var npc_personality: String
@export_multiline var npc_background: String
@export_multiline var npc_goals: String
```
Plus world lore, room context, conversation memory, and action system instructions.

### Provider-Aware Code
Always check `AIManager.current_provider` when implementing AI features:
```gdscript
if AIManager.is_local():
    # Use chat_node (NobodyWhoChat) for local inference
else:
    # Use AIManager.groq_provider for cloud API
```

### Memory Management
NPCs track conversation history with configurable limits:
- `max_history_turns`: How many turns to remember (default: 10)
- `enable_forgetting`: Auto-clear memory after `forget_delay` seconds
- History format: `[{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]`

### Multi-Dimensional Emotion System
NPCs have 8 independent emotion intensities (0-100 each), allowing complex emotional states:
```gdscript
@export_range(0, 100) var happy: int = 0
@export_range(0, 100) var angry: int = 0
@export_range(0, 100) var sad: int = 0
@export_range(0, 100) var fearful: int = 0
@export_range(0, 100) var disgusted: int = 0
@export_range(0, 100) var surprised: int = 0
@export_range(0, 100) var flirty: int = 0
@export_range(0, 100) var tired: int = 0
```

**Key Features:**
- **Emotion Tags**: AI outputs `[happy:75] [angry:30]` to set multiple emotions
- **Gradual Decay**: Emotions decay toward baseline over time (`emotion_decay_rate`)
- **Voice Modulation**: Voice speed adjusts based on dominant emotions
- **Dynamic Descriptions**: `get_emotion_description()` returns "quite cheerful and slightly irritated"

**API:**
```gdscript
set_emotion("happy", 80)  # Set specific emotion
adjust_emotion("angry", 20)  # Relative adjustment
_get_dominant_emotions(20)  # Get emotions above threshold
```

### TTS Integration (KokoroTTS)
Located at [Scripts/Kokorotts.gd](Scripts/Kokorotts.gd):
- Auto-detects bundled `sherpa-onnx-cli.exe` and model files relative to game executable
- 11 English voices (AM_ADAM, AF_SARAH, etc.) + 53 multilingual voices
- Emotion intensities affect voice speed (happy/angry/fearful = faster, sad/tired = slower)
- Synthesizes to AudioStreamWAV via threaded subprocess calls

### Action System Workflow
1. LLM generates response with embedded tags: `"Sure! [animate:sit] Let me sit down."`
2. NPCActionParser extracts actions: `{text: "Sure! Let me sit down.", actions: [{action: "play_animation", animation: "sit"}]}`
3. NPCActionController executes: animation changes, navigation triggers, head tracking
4. Clean text displayed to player

### Autonomous Behavior System
NPCs can make independent decisions without player input:
- Toggle with `enable_autonomous_behavior` export
- Configurable interval via `autonomous_decision_interval` (default: 30s)
- AI considers personality, emotions, location, and current state
- Can autonomously walk to rooms, play animations, or stay idle
- Optional `autonomous_only_when_idle` prevents interrupting conversations
- Uses same action parser/controller as player-triggered actions

### Spontaneous Conversational Actions
NPCs can randomly decide to do things during normal conversations:
- Controlled by `spontaneous_action_chance` (0.0-1.0, default: 0.2 = 20%)
- Examples: "Oh! I left something in the kitchen [walk_to:Kitchen]", "Hang on [animate:sit] my feet hurt"
- Adds realism - NPCs don't stand perfectly still like robots
- Probability-based hint added to system prompt during conversations

### Response Filtering
NPCs remove unwanted AI artifacts before display (configurable):
- Action markers: `*smiles*`, `(laughs)`, `[OOC: note]`
- Uses regex patterns in NPCBase's `_clean_response()` method

### Animation System
Uses AnimationTree with smooth blend transitions:
- Available animations: idle, walk, sit, dance, macarena, chicken, tenna, break
- Located in [Scripts/NPCActionController.gd](Scripts/NPCActionController.gd)
- **Critical**: `using_animation_tree` flag auto-detects AnimationTree vs AnimationPlayer in `_ready()`
- **Blending**: Uses `_process()` to lerp blend amounts from current → target over time (controlled by `blend_transition_speed`)
- Blend parameters must match AnimationTree node structure: `parameters/{AnimationName}/blend_amount`
- Note: "idle" and "walk" both use the "Walk" blend node (idle = Walk at 0 speed)
- Debug with `_debug_print_animation_tree_params()` to verify parameter paths
- Head tracking (LookAtModifier3D) enabled only for idle/walk/sit (currently disabled due to bugs)

## File Organization
- **Scripts/**: All GDScript files (use PascalCase for class_names)
- **Scenes/**: .tscn scene files (npc_base.tscn is template)
- **AIModels/**: GGUF model files (*.gguf)
- **addons/nobodywho/**: NobodyWho GDExtension (external dependency)
- **tts/kokoro-en-v0_19/**: Kokoro TTS model and espeak-ng-data
- **Shaders/cel/**: Cel-shading materials (anime aesthetic)

## Key Conventions

### Exported Properties for NPCs
Always use `@export` with descriptive groups for designer-facing properties:
```gdscript
@export_group("Character")
@export_multiline var npc_personality: String
```

### Signal-Driven UI
Use signals for AI events, not direct calls:
```gdscript
signal response_updated(token: String)
signal response_finished(full_response: String)
```

### Persistent Settings
Settings saved to `user://` directory using ConfigFile:
- AI settings: `user://ai_settings.cfg` (provider, API keys, model paths)
- UI settings: `user://ui_settings.cfg` (volumes, scaling)

### Scene References
Use `@onready` for child node references, `get_node_or_null()` for autoloads:
```gdscript
@onready var chat_node = $ChatNode
var npc_manager = get_node_or_null("/root/NPCManager")
```

## Testing & Debugging

### Running the Game
Press F5 in Godot Editor or use "Run Project" button. Main scene: [Scenes/main.tscn](Scenes/main.tscn)

### Debug Overlay
[Scripts/DebugOverlay.gd](Scripts/DebugOverlay.gd) shows real-time stats (toggle with F3):
- Current provider, model loaded
- NPC status, room locations
- FPS, memory usage

### Testing NPCs
1. Create new NPC: Instance [Scenes/npc_base.tscn](Scenes/npc_base.tscn)
2. Configure exports in Inspector (name, personality, voice)
3. Place in world, ensure NavigationRegion3D exists
4. Press Enter near NPC to initiate dialogue

### STT/Voice Testing
- Push 'V' to record voice input (uses Groq Whisper STT if provider=GROQ)
- Requires Groq API key set in AISettingsMenu (Tab key)

## Current TODOs (from TODO.txt)
- Auto-generate greetings when game starts (partially implemented)
- Player/NPC character naming UI at startup
- Dynamic NPC navigation based on conversation context
- Interactable 3D objects in rooms
- Win/lose conditions
- Improve AI output to sound less robotic

## External Dependencies
- **NobodyWho**: GDExtension for running GGUF models ([addons/nobodywho/](addons/nobodywho/))
- **Groq API**: Cloud inference alternative (requires API key)
- **sherpa-onnx-cli**: External executable for Kokoro TTS synthesis
- **Mixamo**: Character models/animations ([Models/AnimeBaseMan/](Models/AnimeBaseMan/))

## Common Tasks

### Adding a New Voice Preset
1. Add enum value to `NPCBase.VoicePreset`
2. Map to Kokoro voice ID in `_voice_preset_to_id()`
3. Update voice settings UI if needed

### Adding New NPC Action
1. Define regex pattern in `NPCActionParser.action_patterns`
2. Handle in `_build_action_dict()` 
3. Implement execution in `NPCActionController`
4. Update `get_action_system_prompt()` to document for LLM

### Switching AI Providers
Runtime: Press Tab → AI Settings → Select provider
Code: `AIManager.set_provider(AIManager.Provider.GROQ)`

### Adding New Animation
1. Import animation to AnimationPlayer
2. Add to `NPCActionController.AVAILABLE_ANIMATIONS` dict
3. Configure blend node in AnimationTree
4. Update `ANIM_LENGTH` if timed animation
