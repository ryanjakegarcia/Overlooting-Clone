class_name StatsPanel
extends VBoxContainer

# _state is a RunState instance (untyped)
var _state = null
var _val_labels: Dictionary = {}

const STAT_ROWS := [
	["hp",          "HP"],
	["damage",      "Damage"],
	["armor",       "Armor"],
	["barrier",     "Barrier"],
	["crit_chance", "Crit"],
	["swiftness",   "Swiftness"],
	["rage_stacks", "Rage"],
]

const C_LABEL := Color(0.62, 0.60, 0.54)
const C_VALUE := Color(0.92, 0.86, 0.60)
const C_TITLE := Color(0.80, 0.75, 0.50)

func setup(state) -> void:
	_state = state
	_state.hero_stats.changed.connect(_sync)
	_build()
	_sync()

func _build() -> void:
	add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "HERO STATS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C_TITLE)
	add_child(title)

	add_child(HSeparator.new())

	for entry in STAT_ROWS:
		var key: String = entry[0]
		var row := HBoxContainer.new()

		var name_lbl := Label.new()
		name_lbl.text = entry[1] + ":"
		name_lbl.custom_minimum_size = Vector2(90, 0)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", C_LABEL)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", C_VALUE)
		row.add_child(val_lbl)

		add_child(row)
		_val_labels[key] = val_lbl

	add_child(HSeparator.new())

	var set_title := Label.new()
	set_title.text = "SET BONUSES"
	set_title.add_theme_font_size_override("font_size", 14)
	set_title.add_theme_color_override("font_color", C_TITLE)
	add_child(set_title)

	for bonus_key in ["beast_t1", "beast_t2", "rogue_t1", "rogue_t2", "royal_t1", "royal_t2"]:
		var bonus_lbl := Label.new()
		bonus_lbl.add_theme_font_size_override("font_size", 11)
		bonus_lbl.visible = false
		add_child(bonus_lbl)
		_val_labels[bonus_key] = bonus_lbl

func _sync() -> void:
	if _state == null:
		return
	var h = _state.hero_stats
	_set_val("hp",          "%.0f / %.0f" % [h.hp, h.max_hp])
	_set_val("damage",      "%.1f" % h.damage)
	_set_val("armor",       "%.1f" % h.armor)
	_set_val("barrier",     "%.0f / %.0f" % [h.barrier, h.max_barrier])
	_set_val("crit_chance", "%d%%" % roundi(h.crit_chance * 100.0))
	_set_val("swiftness",   "%d%%" % roundi(h.swiftness * 100.0))
	_set_val("rage_stacks", "%d" % h.rage_stacks)

	_sync_bonus("beast_t1", h.beast_t1, "Beast T1 — +15% dmg at Rage≥5")
	_sync_bonus("beast_t2", h.beast_t2, "Beast T2 — Rage persists")
	_sync_bonus("rogue_t1", h.rogue_t1, "Rogue T1 — +10% Crit")
	_sync_bonus("rogue_t2", h.rogue_t2, "Rogue T2 — 35% double-strike")
	_sync_bonus("royal_t1", h.royal_t1, "Royal T1 — Poison on hit")
	_sync_bonus("royal_t2", h.royal_t2, "Royal T2 — ×2 Wound stacks")

func _set_val(key: String, value: String) -> void:
	if _val_labels.has(key):
		(_val_labels[key] as Label).text = value

func _sync_bonus(key: String, active: bool, text: String) -> void:
	if not _val_labels.has(key):
		return
	var lbl: Label = _val_labels[key]
	lbl.visible = active
	if active:
		lbl.text = "✓ " + text
		lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
