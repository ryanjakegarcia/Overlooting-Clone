class_name HeroStats
extends RefCounted

# Hero base values (set once from hero definition, never modified)
var base_max_hp: float    = 100.0
var base_damage: float    = 10.0
var base_crit_chance: float = 0.05

# Live stats (base + gear + set bonuses + skill nodes)
var max_hp: float      = 100.0
var hp: float          = 100.0
var damage: float      = 10.0
var armor: float       = 0.0
var max_barrier: float = 0.0
var barrier: float     = 0.0
var guard: float       = 0.0
var crit_chance: float = 0.05
var swiftness: float   = 0.0

# In-combat trackers
var rage_stacks: int = 0
var poison_stacks: int = 0

# Active set bonus flags (set by Main/_refresh_set_bonuses)
var beast_t1: bool = false
var beast_t2: bool = false
var rogue_t1: bool = false
var rogue_t2: bool = false
var royal_t1: bool = false
var royal_t2: bool = false

# Skill node modifiers
var defend_bonus_barrier: float = 0.0
var on_kill_rage: int = 0

signal changed

func reset_to_base() -> void:
	max_hp      = base_max_hp
	hp          = base_max_hp
	damage      = base_damage
	armor       = 0.0
	max_barrier = 0.0
	barrier     = 0.0
	guard       = 0.0
	crit_chance = base_crit_chance
	swiftness   = 0.0
	rage_stacks = 0
	poison_stacks = 0
	beast_t1 = false; beast_t2 = false
	rogue_t1 = false; rogue_t2 = false
	royal_t1 = false; royal_t2 = false
	defend_bonus_barrier = 0.0
	on_kill_rage = 0

# item is an Item instance (untyped to avoid cross-file class dep)
func apply_item(item) -> void:
	damage      += item.damage
	max_hp      += item.hp_bonus
	hp          += item.hp_bonus
	armor       += item.armor
	max_barrier += item.barrier
	crit_chance += item.crit_chance
	swiftness   += item.swiftness
	changed.emit()

func remove_item(item) -> void:
	damage      -= item.damage
	max_hp      -= item.hp_bonus
	hp           = minf(hp, max_hp)
	armor       -= item.armor
	max_barrier -= item.barrier
	crit_chance -= item.crit_chance
	swiftness   -= item.swiftness
	changed.emit()

func take_hit_piercing(raw_damage: float) -> float:
	var absorbed := minf(barrier, raw_damage)
	barrier -= absorbed
	var remaining := maxf(0.0, raw_damage - absorbed)
	hp = maxf(0.0, hp - remaining)
	changed.emit()
	return absorbed + remaining

func take_hit(raw_damage: float) -> float:
	var absorbed := minf(barrier, raw_damage)
	barrier -= absorbed
	var after_armor := maxf(0.0, raw_damage - absorbed - armor)
	hp = maxf(0.0, hp - after_armor)
	changed.emit()
	return absorbed + after_armor

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	changed.emit()

func add_rage(amount: int = 1) -> void:
	rage_stacks += amount

func get_attack_damage() -> float:
	var dmg := damage
	if beast_t1 and rage_stacks >= 5:
		dmg *= 1.15
	dmg += rage_stacks * 1.5
	if not beast_t2:
		rage_stacks = 0
	return dmg

func roll_crit() -> bool:
	return randf() < crit_chance

func roll_swiftness() -> bool:
	return swiftness > 0.0 and randf() < swiftness

func refresh_barrier_on_area_enter() -> void:
	barrier = minf(max_barrier, barrier + guard)
	changed.emit()

func is_dead() -> bool:
	return hp <= 0.0
