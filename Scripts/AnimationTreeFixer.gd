extends Node

## ANIMATION TREE COMPREHENSIVE FIXER
## Fixes both the transition settings AND resets the tree
## 
## INSTRUCTIONS:
## 1. Add this script to your NPCBase node (as a child node is fine too)
## 2. In Inspector, drag your AnimationTree node to the export variable
## 3. Run the game ONCE
## 4. Check console for "✅ All fixed!"
## 5. Stop the game and SAVE YOUR SCENE
## 6. Remove this script
## 7. Done!

@export var animation_tree: AnimationTree

func _ready():
	if not animation_tree:
		push_error("❌ AnimationTree not assigned! Drag it into the Inspector.")
		return
	
	print("\n🔧 FIXING ANIMATION TREE...")
	fix_all_transitions()
	await get_tree().process_frame
	reset_tree()
	print("✅ All fixed! Now SAVE YOUR SCENE and remove this script.\n")

func fix_all_transitions():
	var state_machine: AnimationNodeStateMachine = animation_tree.tree_root
	
	if not state_machine:
		push_error("❌ No state machine found!")
		return
	
	print("📊 Fixing ", state_machine.get_transition_count(), " transitions...")
	
	for i in range(state_machine.get_transition_count()):
		var from = state_machine.get_transition_from(i)
		var to = state_machine.get_transition_to(i)
		var transition = state_machine.get_transition(i)
		
		# DEFAULT: Immediate switch, auto advance
		transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		transition.xfade_time = 0.4
		
		# SPECIAL CASES
		if (from == "Idle" and to == "Walk") or (from == "Walk" and to == "Idle"):
			transition.xfade_time = 0.25  # Fast response for walking
		elif from == "Start":
			transition.xfade_time = 0.0  # Instant start
		elif to == "Idle" and from != "Walk":
			# Going back to idle from actions - let them finish
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
			transition.xfade_time = 0.5
		
		print("  ✓ ", from, " → ", to)
	
	print("✅ Transitions fixed")

func reset_tree():
	print("🔄 Resetting AnimationTree...")
	
	# Force reset
	animation_tree.active = false
	await get_tree().process_frame
	animation_tree.active = true
	await get_tree().process_frame
	
	# Start at Idle
	var state_machine = animation_tree.get("parameters/playback")
	if state_machine:
		state_machine.start("Idle")
		print("✅ Set to Idle state")
		print("📌 Current state: ", state_machine.get_current_node())
	
	print("✅ AnimationTree reset complete")
