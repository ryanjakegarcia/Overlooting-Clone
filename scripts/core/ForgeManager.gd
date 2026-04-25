class_name ForgeManager
extends RefCounted

const _Item = preload("res://scripts/core/Item.gd")

# Returns Array of groups, each group = Array of 3 items with same rarity.
# Items not part of any group are excluded.
static func find_forge_groups(items: Array) -> Array:
	var by_rarity: Dictionary = {}
	for item in items:
		var r: int = item.rarity
		if not by_rarity.has(r):
			by_rarity[r] = []
		by_rarity[r].append(item)

	var groups: Array = []
	for r in by_rarity:
		var pool: Array = by_rarity[r]
		var i := 0
		while i + 2 < pool.size():
			groups.append([pool[i], pool[i + 1], pool[i + 2]])
			i += 3
	return groups

# Returns the new Item. Caller must remove the 3 group items from state.
static func execute_forge(group: Array, item_defs: Array) -> Object:
	if group.size() < 3 or item_defs.is_empty():
		return null

	var input_rarity: int = group[0].rarity
	var output_rarity: int = mini(input_rarity + 1, 4)

	# Majority set tag wins; ties or all-generic → no tag filter
	var tag_counts: Dictionary = {}
	for item in group:
		var tag: String = str(item.set_tag)
		if tag != "":
			if not tag_counts.has(tag):
				tag_counts[tag] = 0
			tag_counts[tag] += 1

	var best_tag := ""
	var best_count := 0
	for tag in tag_counts:
		if tag_counts[tag] > best_count:
			best_count = tag_counts[tag]
			best_tag = tag

	var pool: Array = []
	if best_tag != "":
		for d in item_defs:
			if d.get("set_tag", "") == best_tag:
				pool.append(d)
	if pool.is_empty():
		pool = item_defs.duplicate()

	var def: Dictionary = pool[randi() % pool.size()]
	var out = _Item.new()
	out.init_from_definition(def, output_rarity)
	return out
