extends Node

# Global lore that all NPCs can reference
const WORLD_LORE = """
WORLD: The same as our real-world
CURRENT YEAR: 2026.
CURRENT SITUATION: The world is identical to the real-world, because it is the real-world.
CURRENCY: Dollars.
LOCATION: The ominous town of Kansas City, Missouri - a desolate and scary area, home to many dangers such as Taylor Swift.
"""

# Location-specific info
const LOCATIONS = {
	"market": "The bustling Kansas City Market. Merchants sell wares, adventurers seek supplies.",
	"tavern": "The Rusty Glizzy Tavern. Locals gather for ale and gossip.",
	"temple": "The Temple of the Big Spiral Staircase. A peaceful place of worship.",
	"forbidden realm": "Overland Park, the scariest place in the entire city.",
}

# Get lore for a specific location
func get_location_lore(location: String) -> String:
	if location in LOCATIONS:
		return LOCATIONS[location]
	return ""
