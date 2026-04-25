class_name RunState
extends RefCounted

const GRID_COLS    := 5
const GRID_ROWS    := 6
const POTION_SLOTS := 2
const EQUIP_SLOTS  := ["weapon", "helm", "chest", "boots", "ring"]

# Preload so .new() works without the editor's class-name cache
const _HeroStats = preload("res://scripts/core/HeroStats.gd")

var hero_stats = _HeroStats.new()

# 2D array [col][row] of Item or null
var backpack: Array = []

var equip_slots: Dictionary = {
	"weapon": null,
	"helm":   null,
	"chest":  null,
	"boots":  null,
	"ring":   null,
}

var potions: Array = []

var biome_id: String = "rotwood_forest"
var area_index: int = 0
var skill_tree_tier1_taken: bool = false
var skill_tree_tier2_taken: bool = false
var skill_nodes_taken: Array = []
var sparks: int = 0

var total_damage_dealt: float = 0.0
var total_kills: int = 0
var areas_cleared: int = 0

signal backpack_changed
signal equip_changed

func _init() -> void:
	_reset_backpack()
	hero_stats.reset_to_base()

func _reset_backpack() -> void:
	backpack = []
	for _c in range(GRID_COLS):
		var col: Array = []
		col.resize(GRID_ROWS)
		col.fill(null)
		backpack.append(col)

# ── Grid Queries ──────────────────────────────────────────────────────────────

func get_free_cell_count() -> int:
	var count := 0
	for c in range(GRID_COLS):
		for r in range(GRID_ROWS):
			if backpack[c][r] == null:
				count += 1
	return count

# item: Item instance (untyped)
func can_place_item(item, col: int, row: int) -> bool:
	for raw in item.get_shape_cells():
		var offset: Vector2i = raw
		var tc := col + offset.x
		var tr := row + offset.y
		if tc < 0 or tc >= GRID_COLS or tr < 0 or tr >= GRID_ROWS:
			return false
		if backpack[tc][tr] != null:
			return false
	return true

func find_first_open_cell(item) -> Vector2i:
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if can_place_item(item, c, r):
				return Vector2i(c, r)
	return Vector2i(-1, -1)

# ── Grid Mutations ────────────────────────────────────────────────────────────

func place_item(item, col: int, row: int) -> bool:
	if not can_place_item(item, col, row):
		return false
	for raw in item.get_shape_cells():
		var offset: Vector2i = raw
		backpack[col + offset.x][row + offset.y] = item
	item.grid_col = col
	item.grid_row = row
	backpack_changed.emit()
	return true

func remove_item_from_backpack(item) -> void:
	for c in range(GRID_COLS):
		for r in range(GRID_ROWS):
			if backpack[c][r] == item:
				backpack[c][r] = null
	item.grid_col = -1
	item.grid_row = -1
	backpack_changed.emit()

func add_to_backpack(item) -> bool:
	var cell := find_first_open_cell(item)
	if cell.x == -1:
		return false
	return place_item(item, cell.x, cell.y)

func steal_row(row_index: int) -> Array:
	var seen := {}
	var stolen: Array = []
	for c in range(GRID_COLS):
		var item = backpack[c][row_index]
		if item != null and not seen.has(item):
			seen[item] = true
			stolen.append(item)
	for item in stolen:
		remove_item_from_backpack(item)
	return stolen

# ── Equip Mutations ───────────────────────────────────────────────────────────

func equip_item(item, slot: String):
	if not equip_slots.has(slot):
		return null
	var prev = equip_slots[slot]
	if prev != null:
		hero_stats.remove_item(prev)
		prev.is_equipped = false
	equip_slots[slot] = item
	if item != null:
		if item.is_in_backpack():
			remove_item_from_backpack(item)
		hero_stats.apply_item(item)
		item.is_equipped = true
	equip_changed.emit()
	return prev

func unequip_item(slot: String):
	var item = equip_slots[slot]
	if item == null:
		return null
	hero_stats.remove_item(item)
	item.is_equipped = false
	equip_slots[slot] = null
	if not add_to_backpack(item):
		item.grid_col = -1
	equip_changed.emit()
	return item

# ── Read Helpers ──────────────────────────────────────────────────────────────

func get_all_backpack_items() -> Array:
	var seen := {}
	var items: Array = []
	for c in range(GRID_COLS):
		for r in range(GRID_ROWS):
			var item = backpack[c][r]
			if item != null and not seen.has(item):
				seen[item] = true
				items.append(item)
	return items

func get_all_equipped_items() -> Array:
	var items: Array = []
	for slot in EQUIP_SLOTS:
		if equip_slots[slot] != null:
			items.append(equip_slots[slot])
	return items

# ── Skill Node Application ────────────────────────────────────────────────────

func apply_skill_node(node_def: Dictionary) -> void:
	var effect: Dictionary = node_def.get("effect", {})
	match effect.get("type", ""):
		"stat":
			var stat: String = effect.get("stat", "")
			var value: float = float(effect.get("value", 0.0))
			match stat:
				"max_hp":
					hero_stats.max_hp += value
					hero_stats.hp += value
				"damage":      hero_stats.damage += value
				"crit_chance": hero_stats.crit_chance += value
				"armor":       hero_stats.armor += value
		"on_kill":
			if effect.get("effect") == "rage":
				hero_stats.on_kill_rage += int(effect.get("value", 0))
		"defend_bonus":
			if effect.get("stat") == "barrier":
				hero_stats.defend_bonus_barrier += float(effect.get("value", 0.0))
	skill_nodes_taken.append(node_def.get("id", ""))
	hero_stats.changed.emit()
