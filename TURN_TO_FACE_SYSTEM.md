# Turn-to-Face Player System

## Overview
This system makes NPCs realistically turn to face the player when:
- Conversation starts
- Player walks behind them during conversation
- NPC is idle and player is nearby (optional)

## How It Works

### 1. **Angle Detection**
The system constantly measures the angle between:
- NPC's forward direction (-Z axis in Godot)
- Direction to player

If angle exceeds `turn_threshold_angle` (default: 90°), NPC will turn.

### 2. **Two Rotation Methods**

#### **Method A: Smooth Code-Based Rotation (DEFAULT)**
- Uses `lerp_angle()` for smooth interpolation
- No animation required
- Adjustable speed via `face_player_turn_speed`
- Best for quick implementation
- **Current setting**: Enabled by default

#### **Method B: Turn-In-Place Animations**
- Uses actual turn animations (quarter-turn, half-turn, 180°)
- More realistic for AI2U-style games
- Requires animation assets
- Enable via `use_turn_animation = true`

### 3. **Configuration Options**

Located in NPCActionController Inspector under "Turn To Face Player" group:

```gdscript
enable_turn_to_player: bool = true
  → Master toggle for entire system

turn_on_conversation_start: bool = true
  → Turn when dialogue begins

turn_during_conversation: bool = true
  → Keep facing player while talking

turn_when_idle: bool = false
  → Turn even when not in conversation

turn_threshold_angle: float = 90.0 (degrees)
  → How far behind player can be before NPC turns
  → 90° = directly at sides
  → 135° = mostly behind
  → 180° = directly behind

face_player_turn_speed: float = 3.0
  → Speed of smooth rotation (higher = faster)
  → Only used if NOT using turn animations

use_turn_animation: bool = false
  → Use animation instead of smooth rotation

turn_animation_name: String = "turn_180"
  → Name of turn animation to play
```

## Finding Turn-In-Place Animations

### **Option 1: Mixamo (Current Character Source)**
Your NPCs use Mixamo models, so this is easiest:

1. Go to https://www.mixamo.com
2. Select your character
3. Search for:
   - **"Turn 180"** - Full turnaround
   - **"Turn 90 Left/Right"** - Quarter turns
   - **"Shuffling"** - Shuffle-step turning
   - **"Pivot"** - Quick pivot turns
   - **"Turn On Spot"** - Generic turn
4. Download as FBX for Godot
5. Import to your project
6. Add to AnimationPlayer/AnimationTree
7. Set `turn_animation_name` to match

### **Option 2: Free Animation Packs**
- **Quaternius**: https://quaternius.com/packs.html
- **Kenney Character Assets**: https://kenney.nl/assets/animated-characters
- **Sketchfab** (filter by free + downloadable)

### **Option 3: Create Your Own**
Use Blender to:
1. Import your character
2. Rotate root bone 90° or 180° over 0.5-1 second
3. Add foot shuffle keyframes for realism
4. Export as FBX

### **Option 4: Godot Animation Mixer**
You can blend existing animations:
- Use "idle" + "walk" at 0.3 speed
- Rotate character while blending

## Implementation Details

### **Code Flow:**
```
NPCBase.start_conversation()
  ↓
NPCActionController.set_conversation_state(true)
  ↓
NPCActionController._update_turn_to_player() (called in _physics_process)
  ↓
Check angle → If > threshold → _turn_toward_player()
  ↓
Either: Smooth rotation OR Play turn animation
```

### **Functions Added:**

**In NPCActionController.gd:**
- `set_conversation_state(talking: bool)` - Call when convo starts/ends
- `_update_turn_to_player(delta)` - Main update loop
- `_get_angle_to_player() -> float` - Returns unsigned angle (0-180°)
- `_get_signed_angle_to_player() -> float` - Returns signed angle (-180 to 180°)
- `_turn_toward_player(delta)` - Executes the turn
- `_find_player() -> Node3D` - Locates player node
- `force_face_player()` - Instant snap to face player (no smooth turn)

### **Integration with NPCBase:**
The system auto-connects when:
- `NPCBase.start_conversation()` is called
- `NPCBase.end_conversation()` is called

## Animation Setup (If Using Method B)

### **Step 1: Add Animation to AnimationPlayer**
1. Select NPC in scene
2. Find AnimationPlayer node
3. Animation → Import → Select your turn FBX
4. Rename to "turn_180" (or whatever you set in export)

### **Step 2: Configure AnimationTree (Optional)**
If using blend-based system:
1. Add "Turn180" blend node to AnimationTree
2. Add to `AVAILABLE_ANIMATIONS` dict in NPCActionController.gd:
   ```gdscript
   "turn_180": "Turn180"
   ```

### **Step 3: Set Export Variables**
On each NPC instance:
- `use_turn_animation` = **true**
- `turn_animation_name` = **"turn_180"**

## Tips for Realistic Turning

### **Smooth Rotation Settings (Method A):**
- **Fast turn** (snappy, arcade-y): `face_player_turn_speed = 8.0`
- **Normal turn** (balanced): `face_player_turn_speed = 3.0` ← DEFAULT
- **Slow turn** (heavy/realistic): `face_player_turn_speed = 1.5`

### **Angle Threshold Settings:**
- **45°** - NPC turns if player is slightly to the side (very attentive)
- **90°** - NPC turns if player is at sides or behind (RECOMMENDED)
- **135°** - NPC only turns if player is mostly behind
- **180°** - NPC only turns if player is DIRECTLY behind (rare)

### **Behavior Recommendations:**

**For AI2U-style Yandere game:**
- `turn_on_conversation_start = true` ✓ Always face player when talking
- `turn_during_conversation = true` ✓ Track player movement
- `turn_when_idle = false` ✗ Don't track when not talking (less creepy)
- `turn_threshold_angle = 90°` Standard responsiveness

**For paranoid/suspicious NPC:**
- `turn_when_idle = true` Always facing player
- `turn_threshold_angle = 45°` Very sensitive
- `face_player_turn_speed = 6.0` Quick reactions

**For casual/relaxed NPC:**
- `turn_threshold_angle = 135°` Only turns if really behind
- `face_player_turn_speed = 2.0` Slow, lazy turns

## Combining with Head Tracking

You already have `LookAtModifier3D` for head tracking (currently disabled due to bugs).

**When both are working:**
1. **Small angles (< 45°)**: Only head turns
2. **Medium angles (45-90°)**: Head + slight body adjustment
3. **Large angles (> 90°)**: Full body turn + head reset

To implement this later, modify `_update_turn_to_player()`:
```gdscript
var angle = _get_angle_to_player()
if angle < 45.0 and enable_head_tracking:
    # Just use head tracking, don't turn body
    return
elif angle > turn_threshold_angle:
    # Turn full body
    is_turning_to_player = true
```

## Debugging

Add this to your DebugOverlay to monitor turning:
```gdscript
var angle_to_player = npc.action_controller._get_angle_to_player()
var is_turning = npc.action_controller.is_turning_to_player
debug_text += "Angle to player: %.1f°\n" % angle_to_player
debug_text += "Turning: %s\n" % is_turning
```

## Performance Notes

- System only updates when NPC is NOT navigating (prevents conflicts)
- Player node is cached after first lookup
- Angle calculations use fast dot product (not expensive)
- Runs in `_physics_process()` at fixed timestep (60 FPS)

## Future Enhancements

### **Multiple Turn Animations:**
Instead of one `turn_180`, use:
- `turn_left_90`, `turn_right_90`
- `turn_left_180`, `turn_right_180`

Then in `_turn_toward_player()`:
```gdscript
var signed_angle = _get_signed_angle_to_player()
if signed_angle > 90:
    play_animation("turn_right_180")
elif signed_angle > 45:
    play_animation("turn_right_90")
elif signed_angle < -90:
    play_animation("turn_left_180")
elif signed_angle < -45:
    play_animation("turn_left_90")
```

### **Turn During Speech:**
Wait for TTS phrase to finish before turning (less jarring):
```gdscript
if is_speaking:
    return  # Don't turn while talking
```

### **Procedural Foot Shuffling:**
Use IK to shuffle feet during code-based rotation for extra realism.

## Testing Checklist

- [ ] NPC faces player when conversation starts
- [ ] NPC tracks player if they walk behind during talk
- [ ] Turn speed feels natural (not too slow/fast)
- [ ] No jitter when player is close to threshold angle
- [ ] Works with multiple NPCs simultaneously
- [ ] Doesn't interfere with navigation (move_to_location)
- [ ] Doesn't conflict with other animations (sit, dance, etc.)

## Conclusion

You now have a complete turn-to-face system that works out of the box with smooth rotation. To add more realism, simply:

1. Download turn animations from Mixamo
2. Import to your project
3. Set `use_turn_animation = true` on your NPCs
4. Profit!

The smooth rotation method (default) is already quite natural-looking for most scenarios. Turn animations are the "cherry on top" for AAA polish.
