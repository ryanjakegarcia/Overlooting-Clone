class_name Enemy
extends RefCounted

enum IntentType {
	ATTACK,
	DEFEND,
	CHARGE,       # telegraphs a big attack next turn
	POISON_ATTACK,
	SUMMON,
}

class Intent:
	var type: IntentType
	var value: int
	var label: String
	var poison_stacks: int = 0
	var summon_id: String = ""

	func _init(t: IntentType, v: int, l: String) -> void:
		type = t; value = v; label = l

var id: String = ""
var display_name: String = ""
var max_hp: float = 0.0
var hp: float = 0.0
var base_damage: float = 0.0
var armor: float = 0.0
var is_boss: bool = false

# Loaded from JSON — cycled in order, wraps around
var intent_pool: Array = []
var intent_index: int = 0
var current_intent: Intent = null

# Charged state — when true, next turn's attack is the charged value
var is_charging: bool = false
var charge_value: int = 0

# Status stacks
var poison_stacks: int = 0
var wound_stacks: int = 0

# Boss-specific
var phase2_hp_threshold: float = 0.0  # 0 = no phase 2
var in_phase2: bool = false
var phase2_death_aoe: int = 0         # damage dealt to hero on death (sapling)

signal died(enemy)

func init_from_definition(def: Dictionary) -> void:
	id           = def.get("id", "")
	display_name = def.get("name", "Enemy")
	max_hp       = float(def.get("hp", 20))
	hp           = max_hp
	base_damage  = float(def.get("damage", 8))
	armor        = float(def.get("armor", 0))
	is_boss      = def.get("is_boss", false)
	phase2_hp_threshold = float(def.get("phase2_hp_threshold", 0.0))
	phase2_death_aoe    = int(def.get("phase2_death_aoe", 0))

	for entry in def.get("intents", []):
		var type_str: String = entry.get("type", "attack")
		var t: IntentType
		match type_str:
			"attack":        t = IntentType.ATTACK
			"defend":        t = IntentType.DEFEND
			"charge":        t = IntentType.CHARGE
			"poison_attack": t = IntentType.POISON_ATTACK
			"summon":        t = IntentType.SUMMON
			_:               t = IntentType.ATTACK
		var intent := Intent.new(t, int(entry.get("value", base_damage)), entry.get("label", ""))
		intent.poison_stacks = int(entry.get("poison_stacks", 0))
		intent.summon_id = entry.get("summon_id", "")
		intent_pool.append(intent)

	advance_intent()

func advance_intent() -> void:
	if intent_pool.is_empty():
		current_intent = Intent.new(IntentType.ATTACK, int(base_damage), "Attack")
		return
	current_intent = intent_pool[intent_index % intent_pool.size()]
	intent_index += 1

# Returns float damage actually dealt to enemy (post armor + wound)
func take_damage(raw: float) -> float:
	var after_armor := maxf(0.0, raw - armor)
	var amplified := after_armor * (1.0 + wound_stacks * 0.07)
	hp = maxf(0.0, hp - amplified)

	if phase2_hp_threshold > 0.0 and not in_phase2:
		if hp / max_hp <= phase2_hp_threshold:
			in_phase2 = true

	if hp <= 0.0:
		died.emit(self)
	return amplified

# Ticks poison at start of this enemy's turn. Returns damage dealt.
func tick_poison() -> float:
	if poison_stacks <= 0:
		return 0.0
	var dmg := float(poison_stacks) * 2.0
	hp = maxf(0.0, hp - dmg)
	if hp <= 0.0:
		died.emit(self)
	return dmg

func add_status(type: String, stacks: int) -> void:
	match type:
		"poison": poison_stacks += stacks
		"wound":  wound_stacks  += stacks

func get_hp_percent() -> float:
	if max_hp <= 0.0: return 0.0
	return hp / max_hp

func is_dead() -> bool:
	return hp <= 0.0
