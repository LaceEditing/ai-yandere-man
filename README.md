# MaleYanderAI - AI-Powered NPC Dialogue System

## 🎮 Project Overview

**MaleYanderAI** is a Godot 4.6 game project featuring AI-powered NPCs with dynamic, conversational dialogue. Unlike traditional dialogue trees with pre-written responses, NPCs use local Large Language Models (LLMs) to generate realistic, contextually-aware responses in real-time.

### Core Concept
Players can walk around a 3D environment and talk to NPCs that respond intelligently using AI. Each NPC has its own personality, background, goals, and knowledge, leading to unique and natural conversations.

### Key Features
- ✅ **Local AI Processing** - All AI runs on your computer (no internet required)
- ✅ **Conversation Memory** - NPCs remember what you've discussed
- ✅ **Dynamic Responses** - Every conversation is unique and contextual
- ✅ **Character Consistency** - NPCs stay in-character with defined personalities
- ✅ **Realistic Dialogue** - Natural speech patterns without robotic lists or formatting
- ✅ **Configurable Memory** - Control how much NPCs remember and for how long
- ✅ **Response Filtering** - Removes unwanted AI artifacts like *(smiles)* or [action]

---

## 🧠 What is NobodyWho?

**NobodyWho** is a Godot extension (GDExtension) that enables running Large Language Models (LLMs) directly within Godot games using GGUF format models.

### How NobodyWho Works

1. **GGUF Models**: Uses quantized (compressed) AI models in GGUF format
   - These are the same models used by llama.cpp, Ollama, LM Studio
   - Quantization makes large models small enough to run on consumer hardware
   - Example: A 70B parameter model can be compressed to ~4GB

2. **Local Inference**: Runs entirely on your computer
   - No API calls or internet required
   - Complete privacy - nothing sent to cloud
   - Uses your GPU/CPU for processing

3. **Godot Integration**: Provides nodes you can use in scenes
   - `NobodyWhoModel` - Loads and manages the AI model
   - `NobodyWhoChat` - Handles conversation with the model
   - Works through GDScript like any other Godot node

### Why GGUF?
- **Portable**: Single file contains entire model
- **Efficient**: Quantized for smaller size and faster inference
- **Compatible**: Works across platforms (Windows, Linux, Mac)
- **Free**: No API costs or rate limits

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Game Architecture                       │
└─────────────────────────────────────────────────────────────┘

Player (Character)
    ↓ [Press Enter]
    ↓
NPCManager ← Finds available NPC
    ↓
NPCBase (NPC Script)
    ↓
┌───────────────────────────────┐
│  ChatNode (NobodyWhoChat)    │ ← Manages conversation
│      ↓                        │
│  AIManager (Autoload)         │ ← References the model
│      ↓                        │
│  LLMModel (NobodyWhoModel)    │ ← Loads GGUF file
└───────────────────────────────┘
    ↓
Generates Response (token by token)
    ↓
DialogueUI ← Displays conversation
    ↓
Player sees response and can reply
```

---

## 📁 Project Structure & File Breakdown

### Core Systems (Autoloads)

These are globally accessible singletons loaded at game start.

#### 1. **AIManager.gd** (Autoload)
**Purpose**: Central manager for the AI model. Loads the GGUF model file and makes it available to all NPCs.

**Key Components**:
```gdscript
@onready var llm_model = $LLMModel  # Reference to NobodyWhoModel node
@export_file("*.gguf") var model_path: String  # Path to AI model file
```

**What it does**:
- Loads the GGUF model from `res://AIModels/qwen2.5-0.5b-instruct-q4_k_m.gguf`
- Provides `AIManager.llm_model` that NPCs connect to
- Initializes on game start
- Single model shared by all NPCs (efficient!)

**Why it's important**: Without this, NPCs can't access the AI model.

---

#### 2. **WorldLore.gd** (Autoload)
**Purpose**: Stores shared world context that all NPCs can reference in their responses.

**Key Components**:
```gdscript
const WORLD_LORE = """..."""  # Global world information
const LOCATIONS = {...}        # Location-specific details
func get_location_lore(location: String) -> String
```

**What it does**:
- Defines the game world (Kansas City, Missouri in 2026)
- Provides location descriptions (market, tavern, temple, etc.)
- NPCs automatically include this in their system prompts
- Ensures consistency across all NPC knowledge

**Example**:
```gdscript
# All NPCs know this:
"WORLD: The same as our real-world"
"CURRENT YEAR: 2026"
"LOCATION: The ominous town of Kansas City, Missouri"
```

---

#### 3. **NPCManager.gd** (Autoload)
**Purpose**: Tracks which NPCs exist in the current scene.

**Key Components**:
```gdscript
var active_npcs: Array = []
func register_npc(npc: Node)
func unregister_npc(npc: Node)
func get_current_npc() -> Node
```

**What it does**:
- NPCs register themselves when they spawn
- NPCs unregister when removed from scene
- Player can query for available NPCs
- Currently returns first NPC (simplified for single-NPC scenes)

**Why it's needed**: Player needs to know which NPC to talk to.

---

#### 4. **DialogueUI.gd** (Autoload - CanvasLayer)
**Purpose**: Manages the dialogue UI that appears when talking to NPCs.

**Key Components**:
```gdscript
var current_npc: Node = null          # NPC currently talking to
var is_generating: bool = false       # Is AI generating response?
var conversation_history: String = "" # Full conversation for display
```

**UI Elements**:
- `NPCNameLabel` - Shows NPC's name
- `DialogueText` - Shows conversation history
- `PlayerInput` - Text box for player's messages
- `SendButton` - Submit message
- `CloseButton` - End conversation

**What it does**:
1. Opens when NPC starts conversation
2. Connects to NPC's signals (`dialogue_updated`, `dialogue_finished`)
3. Displays AI responses as they generate (token streaming)
4. Lets player type and send messages
5. Shows full conversation history
6. Closes and re-captures mouse when done

**Signal Flow**:
```
NPC emits dialogue_updated(token) 
  → DialogueUI updates text display
  → Shows response as it's being generated

NPC emits dialogue_finished(full_response)
  → DialogueUI re-enables input
  → Player can type next message
```

---

### NPC System

#### 5. **NPCBase.gd** (NPC Script)
**Purpose**: The brain of each NPC. Handles personality, memory, conversation, and response filtering.

**Export Variables** (Configurable in Godot Inspector):

**Identity**:
```gdscript
@export var npc_name: String = "Shopkeeper"
@export var npc_location: String = "market"
```

**Character Profile**:
```gdscript
@export_multiline var npc_personality: String
@export_multiline var npc_background: String
@export_multiline var npc_goals: String
@export_multiline var npc_knowledge: String
```

**Dialogue Settings**:
```gdscript
@export var max_response_length: String = "1-2 sentences"
@export var greeting: String = "Aye, what can I do for ye?"
```

**Memory Settings**:
```gdscript
@export var enable_memory: bool = true
@export_range(1, 50, 1) var max_history_turns: int = 10
@export var enable_forgetting: bool = true
@export_range(10.0, 300.0, 5.0) var forget_delay: float = 60.0
```

**Response Filtering**:
```gdscript
@export var remove_action_markers: bool = true
@export var remove_asterisks: bool = true
@export var remove_parentheses: bool = true
@export var remove_brackets: bool = true
```

**How It Works**:

1. **Initialization** (`_ready()`):
   ```gdscript
   - Gets ChatNode child
   - Connects ChatNode to AIManager.llm_model
   - Builds system prompt with character info
   - Starts AI worker thread
   - Registers with NPCManager
   ```

2. **System Prompt Building** (`build_system_prompt()`):
   - Creates detailed instructions for the AI
   - Includes character personality, background, goals
   - Adds world lore and location info
   - Provides examples of good vs bad dialogue
   - Configures memory behavior
   - Result: A comprehensive prompt that shapes NPC behavior

3. **Conversation Flow**:
   ```
   Player: start_conversation()
     ↓
   NPC: Shows greeting → dialogue_finished
     ↓
   Player: Types message
     ↓
   DialogueUI: talk_to_npc(message)
     ↓
   NPC: Sends to chat_node.ask(message)
     ↓
   ChatNode: Queries AI model
     ↓
   AI Model: Generates response token by token
     ↓
   NPC: _on_response_token(token) → dialogue_updated
     ↓
   DialogueUI: Updates display with streaming text
     ↓
   AI Model: Finishes
     ↓
   NPC: _on_response_complete(full) → dialogue_finished
     ↓
   Player: Can reply again
   ```

4. **Memory Management**:
   - Stores conversation as array of `{role, content}` objects
   - Trims old messages when exceeds `max_history_turns * 2`
   - Resets memory after `forget_delay` seconds when dialogue closes
   - Optional: Can disable forgetting for persistent NPCs

5. **Response Filtering** (`clean_response()`):
   - Uses RegEx to remove unwanted patterns:
     - `*action*` → removed
     - `(thought)` → removed
     - `[gesture]` → removed
   - Cleans up spacing and punctuation
   - Ensures clean, natural dialogue

**Signals**:
- `dialogue_updated(text: String)` - Emitted as response generates
- `dialogue_finished(text: String)` - Emitted when response complete

---

### Player System

#### 6. **character.gd** (Player Controller)
**Purpose**: First-person player controller with movement and NPC interaction.

**Movement System**:
```gdscript
walk_speed = 5.0
sprint_speed = 8.0
jump_velocity = 4.5
mouse_sensitivity = 0.002
```

**Controls**:
- **WASD** - Move
- **Shift** - Sprint
- **Space** - Jump
- **Mouse** - Look around
- **Enter** - Talk to NPC
- **ESC** - Free mouse cursor

**Key Functions**:

1. **Mouse Look** (`_input()`):
   - Rotates body left/right (yaw)
   - Rotates head up/down (pitch)
   - Clamped to prevent over-rotation
   - Disabled during dialogue

2. **Movement** (`_physics_process()`):
   - Gets input direction from WASD
   - Transforms to world space (relative to camera)
   - Applies gravity
   - Handles jumping
   - Pauses during dialogue

3. **NPC Interaction** (`attempt_dialogue()`):
   - Queries NPCManager for current NPC
   - Calls NPC's `start_conversation()`
   - NPC handles the rest

**Node Structure**:
```
Character (CharacterBody3D)
  └─ Head (Node3D)
      └─ Camera3D
```

---

## 🔄 Complete Interaction Flow

### Step-by-Step: Player Talks to NPC

1. **Game Start**:
   ```
   - AIManager loads GGUF model
   - WorldLore defines world context
   - NPCManager initializes empty
   - DialogueUI hides itself
   ```

2. **Scene Loads**:
   ```
   - Character spawns
   - NPC spawns, runs _ready():
     - Connects to AIManager.llm_model
     - Builds system prompt
     - Starts AI worker
     - Registers with NPCManager
   ```

3. **Player Approaches NPC**:
   ```
   - Player presses Enter
   - character.gd calls attempt_dialogue()
   - NPCManager.get_current_npc() returns NPC
   - Calls npc.start_conversation()
   ```

4. **Conversation Starts**:
   ```
   - NPC calls DialogueUI.show_dialogue(self)
   - DialogueUI connects to NPC signals
   - NPC emits greeting → dialogue_finished
   - DialogueUI displays greeting
   ```

5. **Player Types Message**:
   ```
   - Player types in text box
   - Presses Enter or clicks Send
   - DialogueUI calls npc.talk_to_npc(message)
   ```

6. **AI Generates Response**:
   ```
   - NPC adds message to conversation_history
   - Calls chat_node.ask(message)
   - ChatNode sends to AI model
   - AI starts generating response
   ```

7. **Response Streams**:
   ```
   - AI generates token by token
   - ChatNode emits response_updated(token)
   - NPC receives, cleans, emits dialogue_updated(token)
   - DialogueUI updates display in real-time
   ```

8. **Response Complete**:
   ```
   - AI finishes
   - ChatNode emits response_finished(full_response)
   - NPC cleans, saves to history, emits dialogue_finished
   - DialogueUI re-enables input
   - Player can reply again
   ```

9. **Conversation Ends**:
   ```
   - Player presses ESC or Close button
   - DialogueUI calls npc.end_conversation()
   - NPC starts forget_timer (if enabled)
   - DialogueUI hides, re-captures mouse
   - Player can move again
   ```

10. **Memory Reset** (Optional):
    ```
    - After forget_delay seconds
    - forget_timer triggers reset_conversation()
    - NPC forgets entire conversation
    - Next talk will be like meeting for first time
    ```

---

## 🎯 What This System Accomplishes

### Game Design Goals

1. **Immersive NPCs**: Characters feel alive and reactive
2. **Replayability**: Every conversation is unique
3. **Emergent Gameplay**: Player-NPC relationships develop naturally
4. **No Dialogue Trees**: No pre-scripted responses to manage
5. **Scalable**: Add new NPCs by just configuring exports

### Technical Achievements

1. **Local AI**: No internet or API costs required
2. **Performant**: Runs on consumer hardware
3. **Modular**: Easy to add/remove NPCs
4. **Memory-Efficient**: Shares one model across all NPCs
5. **Streaming Responses**: Shows text as it generates (better UX)

### Prompt Engineering Excellence

The `build_system_prompt()` function is sophisticated:
- **Clear Instructions**: AI knows exactly what to do
- **Character Consistency**: Personality/background embedded
- **Style Examples**: Shows good vs bad responses
- **Banned Patterns**: Prevents AI from breaking immersion
- **Context Injection**: World lore and location info included
- **Memory Instructions**: Teaches AI to remember conversations

---

## 🎮 How to Use

### Setting Up a New NPC

1. **Add NPC to Scene**:
   - Instance `npc_base.tscn` in your main scene
   - Position where you want the NPC

2. **Configure in Inspector**:
   ```
   NPC Name: "Merchant Tom"
   NPC Location: "market"
   
   Personality: "Greedy but friendly merchant"
   Background: "Runs the general store for 20 years"
   Goals: "Make profit, avoid trouble"
   Knowledge: "Knows prices, local rumors, trade routes"
   
   Max Response Length: "2-3 sentences"
   Greeting: "Welcome to my shop!"
   
   Enable Memory: ✓
   Max History Turns: 10
   Enable Forgetting: ✓
   Forget Delay: 60 seconds
   ```

3. **Done!** NPC will use these settings automatically.

### Model Requirements

**Current Model**: `qwen2.5-0.5b-instruct-q4_k_m.gguf`
- Size: ~350MB
- Speed: Fast on most hardware
- Quality: Good for dialogue

**Where to Get Models**:
- HuggingFace (search for GGUF)
- TheBloke (popular quantizer)
- Ollama (can export to GGUF)

**Recommended Models**:
- **Fast**: qwen2.5-0.5b (current), phi-3-mini
- **Balanced**: llama-3-8b, mistral-7b
- **Quality**: llama-3-70b (requires powerful PC)

---

## 🔧 Configuration Options

### Per-NPC Settings

**Memory Configuration**:
- `enable_memory: true` - NPC remembers conversation
- `max_history_turns: 10` - Remembers last 10 exchanges
- `enable_forgetting: true` - Resets memory after delay
- `forget_delay: 60` - Forgets after 60 seconds

**Response Control**:
- `max_response_length: "1-2 sentences"` - Suggested length
- `greeting: "Hello there!"` - First thing NPC says
- `remove_action_markers: true` - Cleans AI artifacts

### Global Settings

**Input Actions** (Project Settings):
- `StartTalking` = Enter key
- `Move_Forward` = W key
- `Move_Backward` = S key
- `Move_Left` = A key
- `Move_Right` = D key
- `Sprint` = Shift key
- `Interact` = Right Mouse Button

---

## 🐛 Common Issues & Solutions

### "AI Manager initialized with model: res://AIModels/..."
✅ **Normal** - Model loaded successfully

### "No NPC found in scene"
❌ **Problem**: No NPC in scene or not registered
✅ **Solution**: Check NPC has NPCBase.gd script and is in scene

### Slow Responses
❌ **Problem**: Model too large for your hardware
✅ **Solutions**:
- Use smaller model (0.5b instead of 7b)
- Use more aggressive quantization (Q4 instead of Q8)
- Reduce max_tokens in model settings

### NPC Says Same Thing
❌ **Problem**: Memory disabled or conversation not saved
✅ **Solution**: Enable `enable_memory: true` in NPC settings

### Responses Have *(actions)* or [thoughts]
❌ **Problem**: Response filtering disabled
✅ **Solution**: Enable `remove_action_markers: true`

---

## 📊 System Requirements

### Minimum
- **OS**: Windows 10/11, Linux, macOS
- **Godot**: 4.6+
- **RAM**: 8GB
- **Storage**: 500MB (for small models)
- **CPU**: Any x64 processor
- **GPU**: Optional (CPU inference works)

### Recommended
- **RAM**: 16GB+
- **GPU**: NVIDIA RTX series or AMD with Vulkan support
- **Storage**: 5GB+ (for larger models)

---

## 🚀 Future Expansion Ideas

### Easy Additions
- [ ] More NPCs with different personalities
- [ ] Location-based knowledge (NPCs know more about their area)
- [ ] Reputation system (NPCs remember if you were nice/mean)
- [ ] Item trading dialogue
- [ ] Quest giving through conversation

### Advanced Features
- [ ] Multi-NPC conversations (NPCs talk to each other)
- [ ] Emotional states affecting responses
- [ ] Voice synthesis (TTS)
- [ ] Shared memory (NPCs gossip about player)
- [ ] Dynamic relationship system

---

## 📚 Technical Notes

### Why This Architecture?

1. **Autoload Pattern**: 
   - Singletons for global systems (AIManager, WorldLore, etc.)
   - Easy access from any script
   - Persistent across scenes

2. **Signal-Based Communication**:
   - Loose coupling between systems
   - Easy to add features without breaking things
   - Clear data flow

3. **NobodyWhoChat Per-NPC**:
   - Each NPC has own chat instance
   - Manages own conversation context
   - Isolated state (one NPC's convo doesn't affect another)

4. **Shared Model**:
   - Single `NobodyWhoModel` in AIManager
   - All NPCs connect to same model
   - Memory-efficient (only one model loaded)

### Performance Characteristics

**Model Loading**: ~2-5 seconds at startup
**First Response**: ~3-10 seconds (model warm-up)
**Subsequent Responses**: ~1-5 seconds (depends on model size)
**Memory Usage**: ~1-4GB RAM (depends on model)

---

## 🎓 Learning Resources

### Understanding LLMs
- **llama.cpp**: The underlying inference engine
- **GGUF Format**: Quantization and model format
- **Prompt Engineering**: Crafting effective system prompts

### Godot Concepts Used
- **Autoloads**: Global singleton pattern
- **Signals**: Event-driven architecture
- **Export Variables**: Inspector configuration
- **CharacterBody3D**: 3D character controllers
- **CanvasLayer**: UI overlay system

---

## 📝 Credits

**Project**: MaleYanderAI  
**Engine**: Godot 4.6  
**AI Extension**: NobodyWho (GDExtension)  
**Model**: Qwen 2.5 0.5B Instruct (Quantized)  
**Inference**: llama.cpp  

---
