extends Control

# Preload every custom class so .new() and static calls work without the
# editor's class-name cache (global_script_class_cache.cfg).
const _RunState       = preload("res://scripts/core/RunState.gd")
const _Item           = preload("res://scripts/core/Item.gd")
const _BackpackGrid   = preload("res://scripts/ui/BackpackGrid.gd")
const _EquipPanel     = preload("res://scripts/ui/EquipPanel.gd")
const _StatsPanel     = preload("res://scripts/ui/StatsPanel.gd")
const _SetHUD         = preload("res://scripts/ui/SetTrackerHUD.gd")
const _ItemGenerator  = preload("res://scripts/core/ItemGenerator.gd")
const _ChestUI        = preload("res://scripts/ui/ChestUI.gd")
const _ForgeManager   = preload("res://scripts/core/ForgeManager.gd")
const _BrokerOverlay  = preload("res://scripts/ui/BrokerOverlay.gd")
const _Enemy          = preload("res://scripts/core/Enemy.gd")
const _CombatEngine   = preload("res://scripts/core/CombatEngine.gd")
const _CombatUI       = preload("res://scripts/ui/CombatUI.gd")

var _state        = null   # RunState
var _item_defs: Array = []
var _set_defs: Array  = []
var _enemy_defs: Array = []

var _grid         = null   # BackpackGrid
var _equip        = null   # EquipPanel
var _stats        = null   # StatsPanel
var _set_hud      = null   # SetTrackerHUD
var _free_lbl: Label = null
var _discard_dialog: ConfirmationDialog = null
var _pending_discard = null  # Item
var _generator    = null   # ItemGenerator
var _chest_ui     = null   # ChestUI
var _broker_overlay = null  # BrokerOverlay
var _combat_engine = null  # CombatEngine
var _combat_ui     = null  # CombatUI
var _forge_mode: bool = false
var _forge_groups: Array = []
var _forge_pending_group: Array = []
var _forge_btn: Button = null
var _forge_cancel_btn: Button = null
var _forge_dialog: ConfirmationDialog = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_data()
	_init_state()
	_build_ui()
	_seed_items()

func _load_data() -> void:
	_item_defs   = _load_json("res://data/items.json")
	_set_defs    = _load_json("res://data/sets.json")
	_enemy_defs  = _load_json("res://data/enemies.json")

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
	_generator = _ItemGenerator.new(_item_defs)

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

	# Forge dialog
	_forge_dialog = ConfirmationDialog.new()
	_forge_dialog.title = "Forge Items"
	_forge_dialog.confirmed.connect(_on_forge_confirmed)
	_forge_dialog.canceled.connect(func() -> void: _forge_pending_group = [])
	add_child(_forge_dialog)

	# Broker overlay
	_broker_overlay = _BrokerOverlay.new()
	add_child(_broker_overlay)

	# Chest UI
	_chest_ui = _ChestUI.new()
	_chest_ui.item_picked.connect(_on_chest_item_picked)
	add_child(_chest_ui)

	# Combat UI — added last, highest z-index
	_combat_ui = _CombatUI.new()
	_combat_ui.combat_closed.connect(_on_combat_closed)
	add_child(_combat_ui)

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
	_state.backpack_changed.connect(_refresh_forge_button)
	_state.equip_changed.connect(_refresh_set_bonuses)
	_refresh_free_label()
	_refresh_set_bonuses()

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
	hint.text = "Drag item in grid to move\nDrag item onto slot to equip\nLeft-click item → equip\nRight-click item → discard\nLeft-click slot → unequip\nForge: 3 same-rarity → 1 higher"
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

	var b0 := _btn("Open Chest (depth 1)")
	b0.pressed.connect(func() -> void: _open_chest(1))
	col.add_child(b0)

	_forge_btn = _btn("Forge (need 3 same rarity)")
	_forge_btn.pressed.connect(_enter_forge_mode)
	_forge_btn.disabled = true
	col.add_child(_forge_btn)

	_forge_cancel_btn = _btn("Cancel Forge")
	_forge_cancel_btn.pressed.connect(_exit_forge_mode)
	_forge_cancel_btn.hide()
	col.add_child(_forge_cancel_btn)

	col.add_child(HSeparator.new())

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

	col.add_child(HSeparator.new())

	var bc1 := _btn("Fight: Wolf")
	bc1.pressed.connect(func() -> void: _start_combat(["wolf"]))
	col.add_child(bc1)

	var bc2 := _btn("Fight: Wolf + Spider")
	bc2.pressed.connect(func() -> void: _start_combat(["wolf", "spider"]))
	col.add_child(bc2)

	var bc3 := _btn("Fight: Treant")
	bc3.pressed.connect(func() -> void: _start_combat(["treant"]))
	col.add_child(bc3)

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
	if free == 0:
		_free_lbl.text = "0 / %d cells free  ⚠ BROKER ON NEXT CHEST" % total
		_free_lbl.add_theme_color_override("font_color", Color(0.92, 0.28, 0.22))
	elif free <= 2:
		_free_lbl.text = "%d / %d cells free  ⚠ Broker warning" % [free, total]
		_free_lbl.add_theme_color_override("font_color", Color(0.92, 0.65, 0.20))
	else:
		_free_lbl.text = "%d / %d cells free" % [free, total]
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

# ── Forge ──────────────────────────────────────────────────────────────────────

func _refresh_forge_button() -> void:
	if _forge_mode:
		return
	var groups: Array = _ForgeManager.find_forge_groups(_state.get_all_backpack_items())
	if _forge_btn != null:
		_forge_btn.disabled = groups.is_empty()

func _enter_forge_mode() -> void:
	_forge_groups = _ForgeManager.find_forge_groups(_state.get_all_backpack_items())
	if _forge_groups.is_empty():
		_show_toast("Need 3 items of same rarity to forge")
		return
	_forge_mode = true
	_forge_btn.hide()
	_forge_cancel_btn.show()
	var eligible: Array = []
	for group in _forge_groups:
		for item in group:
			eligible.append(item)
	_grid.set_forge_highlights(eligible)

func _exit_forge_mode() -> void:
	_forge_mode = false
	_forge_pending_group = []
	_forge_groups = []
	_grid.clear_forge_highlights()
	_forge_btn.show()
	_forge_cancel_btn.hide()
	_refresh_forge_button()

func _on_forge_item_selected(item) -> void:
	for group in _forge_groups:
		if item in group:
			_forge_pending_group = group
			var next_rarity: int = mini(item.rarity + 1, 4)
			var next_name: String = ["", "Common", "Uncommon", "Rare", "Epic"][next_rarity]
			var names: String = ""
			for i in range(group.size()):
				if i > 0:
					names += "\n"
				names += "• " + group[i].display_name + " (%s)" % group[i].get_rarity_name()
			_forge_dialog.dialog_text = "Forge these 3 items:\n%s\n\n→ 1 %s item?" % [names, next_name]
			_forge_dialog.popup_centered()
			return

func _on_forge_confirmed() -> void:
	if _forge_pending_group.size() < 3:
		return
	for item in _forge_pending_group:
		_state.remove_item_from_backpack(item)
	var result = _ForgeManager.execute_forge(_forge_pending_group, _item_defs)
	_forge_pending_group = []
	_exit_forge_mode()
	if result == null:
		return
	if not _state.add_to_backpack(result):
		_show_toast("No space for forge result!")

# ── Chest ──────────────────────────────────────────────────────────────────────

func _open_chest(depth: int = 1) -> void:
	if _state.get_free_cell_count() == 0:
		_broker_overlay.open(_state, _grid)
		await _broker_overlay.resolved
	var items: Array = _generator.generate_chest(depth)
	if items.is_empty():
		return
	_chest_ui.open(items)

func _start_combat(enemy_ids: Array) -> void:
	# Seed potions for test if empty
	if _state.potions.is_empty():
		_state.potions = [
			{"type": "health"},
			{"type": "wound_vial"},
		]
	var enemies: Array = []
	for eid in enemy_ids:
		for def in _enemy_defs:
			if def.get("id", "") == eid:
				var e = _Enemy.new()
				e.init_from_definition(def)
				enemies.append(e)
				break
	if enemies.is_empty():
		return
	_combat_engine = _CombatEngine.new(_state, enemies, _enemy_defs)
	_combat_engine.combat_won.connect(_on_combat_won)
	_combat_engine.combat_lost.connect(_on_combat_lost)
	_combat_ui.open(_combat_engine)

func _on_combat_won() -> void:
	_state.areas_cleared += 1
	await get_tree().create_timer(0.8).timeout
	_combat_ui.close()
	_show_toast("Victory!")
	_open_chest(maxi(1, _state.areas_cleared))

func _on_combat_lost() -> void:
	await get_tree().create_timer(1.0).timeout
	_combat_ui.close()
	_show_toast("Defeated... (no lose screen yet)")

func _on_combat_closed() -> void:
	_combat_engine = null

func _on_chest_item_picked(item) -> void:
	if not _state.add_to_backpack(item):
		_show_toast("No space for %s!" % item.display_name)
		_chest_ui.open([item])  # re-open with just this item so player isn't stuck

# ── Event Handlers ─────────────────────────────────────────────────────────────

func _on_item_left_clicked(item) -> void:
	if _forge_mode:
		_on_forge_item_selected(item)
		return
	var slot := str(item.type)
	if not _state.equip_slots.has(slot):
		return
	var prev = _state.equip_item(item, slot)
	if prev != null:
		if not _state.add_to_backpack(prev):
			_state.equip_item(prev, slot)
			_show_toast("No backpack space — unequip first")

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
