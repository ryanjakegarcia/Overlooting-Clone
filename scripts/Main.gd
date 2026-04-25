extends Control

# Preload every custom class so .new() and static calls work without the
# editor's class-name cache (global_script_class_cache.cfg).
const _RunState     = preload("res://scripts/core/RunState.gd")
const _Item         = preload("res://scripts/core/Item.gd")
const _BackpackGrid = preload("res://scripts/ui/BackpackGrid.gd")
const _EquipPanel   = preload("res://scripts/ui/EquipPanel.gd")
const _StatsPanel   = preload("res://scripts/ui/StatsPanel.gd")
const _SetHUD       = preload("res://scripts/ui/SetTrackerHUD.gd")

var _state        = null   # RunState
var _item_defs: Array = []
var _set_defs: Array  = []

var _grid         = null   # BackpackGrid
var _equip        = null   # EquipPanel
var _stats        = null   # StatsPanel
var _set_hud      = null   # SetTrackerHUD
var _free_lbl: Label = null
var _discard_dialog: ConfirmationDialog = null
var _pending_discard = null  # Item

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_data()
	_init_state()
	_build_ui()
	_seed_items()

func _load_data() -> void:
	_item_defs = _load_json("res://data/items.json")
	_set_defs  = _load_json("res://data/sets.json")

static func _load_json(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s" % path)
		return []
	var result = JSON.parse_string(f.get_as_text())
	f.close()
	return result if result is Array else []

func _init_state() -> void:
	_state = _RunState.new()
	_state.hero_stats.base_max_hp    = 100.0
	_state.hero_stats.base_damage    = 10.0
	_state.hero_stats.base_crit_chance = 0.05
	_state.hero_stats.reset_to_base()

# ── UI Construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 10)
	margin.add_child(vroot)

	# Header
	var title_lbl := Label.new()
	title_lbl.text = "IRONHAVEN  —  Day 2 Testbed"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.55))
	vroot.add_child(title_lbl)

	# Set tracker HUD
	_set_hud = _SetHUD.new()
	_set_hud.setup(_state)
	vroot.add_child(_set_hud)

	vroot.add_child(HSeparator.new())

	# Main columns
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vroot.add_child(cols)

	cols.add_child(_build_backpack_col())
	cols.add_child(_build_equip_col())
	cols.add_child(_build_stats_col())
	cols.add_child(_build_controls_col())

	# Discard dialog
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "Discard Item"
	_discard_dialog.confirmed.connect(_on_discard_confirmed)
	add_child(_discard_dialog)

func _build_backpack_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(_section_lbl("BACKPACK  5 × 6"))

	_grid = _BackpackGrid.new()
	_grid.setup(_state)
	_grid.item_left_clicked.connect(_on_item_left_clicked)
	_grid.item_right_clicked.connect(_on_item_right_clicked)
	col.add_child(_grid)

	_free_lbl = Label.new()
	_free_lbl.add_theme_font_size_override("font_size", 11)
	_free_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	col.add_child(_free_lbl)
	_state.backpack_changed.connect(_refresh_free_label)
	_refresh_free_label()

	return col

func _build_equip_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(270, 0)
	col.add_child(_section_lbl("EQUIPPED"))

	_equip = _EquipPanel.new()
	_equip.setup(_state)
	_equip.slot_clicked.connect(_on_equip_slot_clicked)
	col.add_child(_equip)

	var hint := Label.new()
	hint.text = "Left-click item → equip to slot\nRight-click item → discard\nLeft-click slot → unequip"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.40, 0.40, 0.44))
	col.add_child(hint)

	return col

func _build_stats_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(210, 0)
	_stats = _StatsPanel.new()
	_stats.setup(_state)
	col.add_child(_stats)
	return col

func _build_controls_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(200, 0)
	col.add_child(_section_lbl("TEST CONTROLS"))

	var b1 := _btn("Add Small Item (1×1)")
	b1.pressed.connect(func() -> void: _add_item("small"))
	col.add_child(b1)

	var b2 := _btn("Add Weapon (1×2 slim)")
	b2.pressed.connect(func() -> void: _add_item("slim"))
	col.add_child(b2)

	var b3 := _btn("Add Rare Item")
	b3.pressed.connect(func() -> void: _add_item("small", 3))
	col.add_child(b3)

	var b4 := _btn("Add Epic Item")
	b4.pressed.connect(func() -> void: _add_item("small", 4))
	col.add_child(b4)

	col.add_child(HSeparator.new())

	var b5 := _btn("Add Beast Set Piece")
	b5.pressed.connect(func() -> void: _add_set_item("beast"))
	col.add_child(b5)

	var b6 := _btn("Add Rogue Set Piece")
	b6.pressed.connect(func() -> void: _add_set_item("rogue"))
	col.add_child(b6)

	var b7 := _btn("Add Royal Set Piece")
	b7.pressed.connect(func() -> void: _add_set_item("royal"))
	col.add_child(b7)

	col.add_child(HSeparator.new())

	var b8 := _btn("Clear Backpack")
	b8.pressed.connect(_clear_backpack)
	col.add_child(b8)

	return col

# ── Helpers ────────────────────────────────────────────────────────────────────

static func _section_lbl(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.73, 0.50))
	return lbl

static func _btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	return b

func _refresh_free_label() -> void:
	var free: int = _state.get_free_cell_count()
	var total: int = 5 * 6
	_free_lbl.text = "%d / %d cells free" % [free, total]
	if free <= 2:
		_free_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	else:
		_free_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))

# ── Item Generation ────────────────────────────────────────────────────────────

func _add_item(shape: String, rarity: int = -1) -> void:
	if _item_defs.is_empty():
		return
	var pool: Array = _item_defs.filter(func(d: Dictionary) -> bool: return d.get("shape") == shape)
	if pool.is_empty():
		return
	var def: Dictionary = pool[randi() % pool.size()]
	var r: int = rarity if rarity > 0 else randi_range(1, 2)
	var item = _Item.new()
	item.init_from_definition(def, r)
	if not _state.add_to_backpack(item):
		_show_toast("Backpack full!")

func _add_set_item(set_tag: String) -> void:
	if _item_defs.is_empty():
		return
	var pool: Array = _item_defs.filter(func(d: Dictionary) -> bool: return d.get("set_tag") == set_tag)
	if pool.is_empty():
		return
	var def: Dictionary = pool[randi() % pool.size()]
	var item = _Item.new()
	item.init_from_definition(def, randi_range(1, 3))
	if not _state.add_to_backpack(item):
		_show_toast("Backpack full!")

func _seed_items() -> void:
	for _i in range(3):
		_add_item("small")
	_add_item("slim")

func _clear_backpack() -> void:
	for item in _state.get_all_backpack_items():
		_state.remove_item_from_backpack(item)

# ── Event Handlers ─────────────────────────────────────────────────────────────

func _on_item_left_clicked(item) -> void:
	var slot: String = str(item.type)
	if slot not in ["weapon", "helm", "chest", "boots", "ring"]:
		return
	var prev = _state.equip_item(item, slot)
	if prev != null:
		_state.add_to_backpack(prev)
	_refresh_set_bonuses()

func _on_item_right_clicked(item, _screen_pos) -> void:
	_pending_discard = item
	_discard_dialog.dialog_text = "Discard %s (%s)?" % [item.display_name, item.get_rarity_name()]
	_discard_dialog.popup_centered()

func _on_discard_confirmed() -> void:
	if _pending_discard == null:
		return
	_state.remove_item_from_backpack(_pending_discard)
	_pending_discard = null

func _on_equip_slot_clicked(slot) -> void:
	var slot_str: String = str(slot)
	if _state.equip_slots[slot_str] == null:
		return
	var returned = _state.unequip_item(slot_str)
	if returned != null and returned.grid_col == -1:
		_show_toast("No backpack space for %s" % returned.display_name)
	_refresh_set_bonuses()

# ── Set Bonus Application ──────────────────────────────────────────────────────

func _refresh_set_bonuses() -> void:
	var h = _state.hero_stats
	var counts := { "beast": 0, "rogue": 0, "royal": 0 }
	for item in _state.get_all_equipped_items():
		var tag: String = str(item.set_tag)
		if counts.has(tag):
			counts[tag] += 1

	h.beast_t1 = counts["beast"] >= 3
	h.beast_t2 = counts["beast"] >= 5
	h.royal_t1 = counts["royal"] >= 3
	h.royal_t2 = counts["royal"] >= 5
	h.rogue_t2 = counts["rogue"] >= 5

	# Rogue T1 directly mutates crit_chance — apply delta, not absolute
	var rogue_t1_was: bool = h.rogue_t1
	var rogue_t1_now: bool = counts["rogue"] >= 3
	if rogue_t1_now != rogue_t1_was:
		h.crit_chance += 0.10 if rogue_t1_now else -0.10
	h.rogue_t1 = rogue_t1_now

	h.changed.emit()

# ── Toast ──────────────────────────────────────────────────────────────────────

func _show_toast(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3))
	lbl.position = Vector2(get_viewport().size) / 2.0 - Vector2(100, 20)
	lbl.z_index = 100
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tween.tween_callback(lbl.queue_free)
