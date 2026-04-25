class_name Item
extends Resource

# Shapes: "small" = 1×1, "slim" = 1×2 vertical
const SHAPE_CELLS := {
	"small": [Vector2i(0, 0)],
	"slim":  [Vector2i(0, 0), Vector2i(0, 1)],
}

const RARITY_NAMES := ["", "Common", "Uncommon", "Rare", "Epic"]
const RARITY_COLORS := [
	Color.WHITE,
	Color(0.70, 0.70, 0.70),  # Common   — grey
	Color(0.30, 0.80, 0.30),  # Uncommon — green
	Color(0.30, 0.55, 0.95),  # Rare     — blue
	Color(0.72, 0.33, 0.95),  # Epic     — purple
]

# Rarity multipliers applied to base_stats at generation time
const RARITY_MULTIPLIERS := {
	1: 1.0,   # Common
	2: 1.4,   # Uncommon
	3: 2.0,   # Rare
	4: 3.0,   # Epic
}

@export var id: String = ""
@export var display_name: String = ""
@export var type: String = ""      # "weapon" | "helm" | "chest" | "boots" | "ring"
@export var shape: String = "small"
@export var set_tag: String = ""   # "" = no set
@export var rarity: int = 1        # 1–4

# Flat stats contributed when equipped
@export var damage: float = 0.0
@export var hp_bonus: float = 0.0
@export var armor: float = 0.0
@export var barrier: float = 0.0
@export var crit_chance: float = 0.0
@export var swiftness: float = 0.0

# Grid placement state (–1 = not in backpack)
var grid_col: int = -1
var grid_row: int = -1
var is_equipped: bool = false

func get_shape_cells() -> Array:
	return SHAPE_CELLS.get(shape, SHAPE_CELLS["small"])

func get_rarity_name() -> String:
	return RARITY_NAMES[clamp(rarity, 1, 4)]

func get_rarity_color() -> Color:
	return RARITY_COLORS[clamp(rarity, 1, 4)]

func get_stats_dict() -> Dictionary:
	var d := {}
	if damage > 0.0:      d["Damage"] = damage
	if hp_bonus > 0.0:    d["HP"] = hp_bonus
	if armor > 0.0:       d["Armor"] = armor
	if barrier > 0.0:     d["Barrier"] = barrier
	if crit_chance > 0.0: d["Crit"] = "%d%%" % roundi(crit_chance * 100)
	if swiftness > 0.0:   d["Swift"] = "%d%%" % roundi(swiftness * 100)
	return d

func is_in_backpack() -> bool:
	return grid_col >= 0 and not is_equipped

func init_from_definition(def: Dictionary, target_rarity: int) -> void:
	id           = def.get("id", "")
	display_name = def.get("name", "Unknown")
	type         = def.get("type", "")
	shape        = def.get("shape", "small")
	set_tag      = def.get("set_tag", "")
	rarity       = clamp(target_rarity, 1, 4)

	var mult: float = RARITY_MULTIPLIERS.get(rarity, 1.0)
	var base: Dictionary = def.get("base_stats", {})

	damage      = roundf(base.get("damage",      0.0) * mult)
	hp_bonus    = roundf(base.get("hp_bonus",    0.0) * mult)
	armor       = roundf(base.get("armor",       0.0) * mult)
	barrier     = roundf(base.get("barrier",     0.0) * mult)
	crit_chance = snappedf(base.get("crit_chance", 0.0) * mult, 0.01)
	swiftness   = snappedf(base.get("swiftness",   0.0) * mult, 0.01)
