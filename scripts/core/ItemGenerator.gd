class_name ItemGenerator
extends RefCounted

const _Item = preload("res://scripts/core/Item.gd")

# Base rarity weights: [common, uncommon, rare, epic] (indices 0-3 = rarities 1-4)
const BASE_W := [55, 25, 12, 8]

var _defs: Array = []

func _init(item_defs: Array) -> void:
	_defs = item_defs

func generate_item(depth: int = 1) -> Object:
	if _defs.is_empty():
		return null
	var def: Dictionary = _defs[randi() % _defs.size()]
	var item = _Item.new()
	item.init_from_definition(def, _roll_rarity(depth))
	return item

func generate_chest(depth: int = 1) -> Array:
	var results: Array = []
	var used_ids: Dictionary = {}
	var attempts := 0
	while results.size() < 3 and attempts < 50:
		attempts += 1
		var item = generate_item(depth)
		if item != null and not used_ids.has(item.id):
			used_ids[item.id] = true
			results.append(item)
	return results

func _roll_rarity(depth: int) -> int:
	# Each depth level past 1 shifts 2% out of Common into Rare + Epic
	var w := BASE_W.duplicate()
	var shift := mini(depth - 1, 4)
	w[0] = maxi(w[0] - shift * 2, 10)
	w[2] += shift
	w[3] += shift
	var total: int = w[0] + w[1] + w[2] + w[3]
	var roll: int = randi() % total
	var cum := 0
	for i in range(w.size()):
		cum += w[i]
		if roll < cum:
			return i + 1
	return 1
