class_name CombatUI
extends Control

const _Enemy        = preload("res://scripts/core/Enemy.gd")
const _CombatEngine = preload("res://scripts/core/CombatEngine.gd")

signal combat_closed

const C_BG        := Color(0.07, 0.08, 0.10)
const C_PANEL_BG  := Color(0.11, 0.12, 0.15)
const C_BORDER    := Color(0.28, 0.30, 0.36)
const C_HP_FILL   := Color(0.22, 0.72, 0.28)
const C_HP_LOW    := Color(0.82, 0.28, 0.22)
const C_BARRIER   := Color(0.28, 0.55, 0.90)

var _engine = null

# Enemy UI refs: enemy -> { panel, hp_fill, hp_lbl, intent_lbl, status_lbl, hp_fill_style }
var _enemy_ui: Dictionary = {}
var _selected_enemy = null

# Hero UI refs
var _hero_hp_fill_style: StyleBoxFlat = null
var _hero_hp_lbl: Label = null
var _hero_barrier_lbl: Label = null
var _hero_poison_lbl: Label = null

# Buttons
var _atk_btn: Button = null
var _def_btn: Button = null
var _pot_btns: Array = []

# Combat log
var _log_lbl: RichTextLabel = null

# Enemy panels container (for floating numbers)
var _enemy_row: HBoxContainer = null
var _phase_lbl: Label = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _init() -> void:
	hide()
	z_index = 5
	mouse_filter = Control.MOUSE_FILTER_STOP

func open(engine) -> void:
	_engine = engine
	_enemy_ui.clear()
	for c in get_children():
		c.queue_free()
	_build()
	_connect_engine()
	show()
	_engine.start()

func close() -> void:
	_engine = null
	hide()
	combat_closed.emit()

# ── Build ──────────────────────────────────────────────────────────────────────

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_enemy_area())
	root.add_child(_build_hero_area())
	root.add_child(_build_log_area())

func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 36)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.09, 0.10, 0.13)
	bs.border_color = C_BORDER
	bs.set_border_width_all(1)
	bar.add_theme_stylebox_override("panel", bs)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	bar.add_child(hb)

	_phase_lbl = Label.new()
	_phase_lbl.text = "YOUR TURN"
	_phase_lbl.add_theme_font_size_override("font_size", 14)
	_phase_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.55))
	_phase_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_phase_lbl)

	var flee := Button.new()
	flee.text = "Flee (test)"
	flee.pressed.connect(close)
	hb.add_child(flee)

	return bar

func _build_enemy_area() -> Control:
	var container := PanelContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.09, 0.10, 0.12)
	cs.border_color = C_BORDER
	cs.set_border_width_all(1)
	container.add_theme_stylebox_override("panel", cs)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(center)

	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 20)
	center.add_child(_enemy_row)

	for enemy in _engine.get_all_enemies():
		_add_enemy_panel(enemy)

	return container

func _build_hero_area() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 200)
	var ps := StyleBoxFlat.new()
	ps.bg_color = C_PANEL_BG
	ps.border_color = C_BORDER
	ps.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", ps)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	# Portrait placeholder
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(80, 120)
	var port_style := StyleBoxFlat.new()
	port_style.bg_color = Color(0.25, 0.22, 0.18)
	port_style.border_color = Color(0.55, 0.48, 0.30)
	port_style.set_border_width_all(2)
	port_style.set_corner_radius_all(4)
	portrait.add_theme_stylebox_override("panel", port_style)
	var port_lbl := Label.new()
	port_lbl.text = "MAX"
	port_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	port_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	port_lbl.add_theme_font_size_override("font_size", 11)
	portrait.add_child(port_lbl)
	hbox.add_child(portrait)

	# Hero stats
	var stats_col := VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 5)
	stats_col.custom_minimum_size = Vector2(200, 0)
	stats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(stats_col)

	var name_lbl := Label.new()
	name_lbl.text = "Maximilian"
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.62))
	stats_col.add_child(name_lbl)

	_hero_hp_lbl = Label.new()
	_hero_hp_lbl.add_theme_font_size_override("font_size", 12)
	stats_col.add_child(_hero_hp_lbl)
	stats_col.add_child(_make_hp_bar(true))

	_hero_barrier_lbl = Label.new()
	_hero_barrier_lbl.add_theme_font_size_override("font_size", 11)
	_hero_barrier_lbl.add_theme_color_override("font_color", C_BARRIER)
	stats_col.add_child(_hero_barrier_lbl)

	_hero_poison_lbl = Label.new()
	_hero_poison_lbl.add_theme_font_size_override("font_size", 11)
	_hero_poison_lbl.add_theme_color_override("font_color", Color(0.30, 0.80, 0.30))
	_hero_poison_lbl.hide()
	stats_col.add_child(_hero_poison_lbl)

	_refresh_hero_display()

	# Action buttons
	var action_col := VBoxContainer.new()
	action_col.add_theme_constant_override("separation", 4)
	action_col.custom_minimum_size = Vector2(150, 0)
	action_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(action_col)

	_atk_btn = Button.new()
	_atk_btn.text = "⚔  Attack"
	_atk_btn.custom_minimum_size = Vector2(140, 32)
	_atk_btn.pressed.connect(_on_attack_pressed)
	action_col.add_child(_atk_btn)

	_def_btn = Button.new()
	_def_btn.text = "🛡  Defend"
	_def_btn.custom_minimum_size = Vector2(140, 32)
	_def_btn.pressed.connect(_on_defend_pressed)
	action_col.add_child(_def_btn)

	action_col.add_child(HSeparator.new())

	# Potion buttons
	_pot_btns.clear()
	for i in range(2):
		var pb := Button.new()
		pb.custom_minimum_size = Vector2(140, 28)
		var slot_idx: int = i
		pb.pressed.connect(func() -> void: _on_potion_pressed(slot_idx))
		action_col.add_child(pb)
		_pot_btns.append(pb)

	_refresh_potion_buttons()

	return panel

func _build_log_area() -> Control:
	var container := Panel.new()
	container.custom_minimum_size = Vector2(0, 80)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.07, 0.08, 0.09)
	cs.border_color = C_BORDER
	cs.set_border_width_all(1)
	container.add_theme_stylebox_override("panel", cs)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("margin_left", 8)
	container.add_child(scroll)

	_log_lbl = RichTextLabel.new()
	_log_lbl.fit_content = true
	_log_lbl.bbcode_enabled = true
	_log_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_lbl.add_theme_font_size_override("normal_font_size", 11)
	scroll.add_child(_log_lbl)

	return container

# ── Enemy Panels ───────────────────────────────────────────────────────────────

func _add_enemy_panel(enemy) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(160, 200)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var ps := StyleBoxFlat.new()
	ps.bg_color = C_PANEL_BG
	ps.border_color = C_BORDER
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", ps)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.set_offset(SIDE_LEFT,   8)
	vb.set_offset(SIDE_TOP,    8)
	vb.set_offset(SIDE_RIGHT,  -8)
	vb.set_offset(SIDE_BOTTOM, -8)
	panel.add_child(vb)

	# Enemy sprite placeholder
	var sprite_rect := Panel.new()
	sprite_rect.custom_minimum_size = Vector2(0, 80)
	sprite_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sr_style := StyleBoxFlat.new()
	sr_style.bg_color = Color(0.18, 0.14, 0.12)
	sr_style.set_corner_radius_all(3)
	sprite_rect.add_theme_stylebox_override("panel", sr_style)
	var sprite_lbl := Label.new()
	sprite_lbl.text = enemy.display_name[0]
	sprite_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sprite_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sprite_lbl.add_theme_font_size_override("font_size", 28)
	sprite_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	sprite_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_rect.add_child(sprite_lbl)
	vb.add_child(sprite_rect)

	var name_lbl := Label.new()
	name_lbl.text = enemy.display_name
	if enemy.is_boss:
		name_lbl.add_theme_color_override("font_color", Color(0.90, 0.45, 0.20))
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_lbl)

	# HP bar
	var hp_bg := Panel.new()
	hp_bg.custom_minimum_size = Vector2(0, 12)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hp_bg_style := StyleBoxFlat.new()
	hp_bg_style.bg_color = Color(0.15, 0.10, 0.10)
	hp_bg_style.set_corner_radius_all(3)
	hp_bg.add_theme_stylebox_override("panel", hp_bg_style)

	var hp_fill := Panel.new()
	hp_fill.set_anchor(SIDE_TOP, 0); hp_fill.set_anchor(SIDE_BOTTOM, 1)
	hp_fill.set_anchor(SIDE_LEFT, 0); hp_fill.set_anchor(SIDE_RIGHT, 0)
	hp_fill.set_offset(SIDE_RIGHT, 144)
	var hp_fill_style := StyleBoxFlat.new()
	hp_fill_style.bg_color = C_HP_FILL
	hp_fill_style.set_corner_radius_all(3)
	hp_fill.add_theme_stylebox_override("panel", hp_fill_style)
	hp_bg.add_child(hp_fill)
	vb.add_child(hp_bg)

	var hp_lbl := Label.new()
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	vb.add_child(hp_lbl)

	var intent_lbl := Label.new()
	intent_lbl.add_theme_font_size_override("font_size", 11)
	intent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(intent_lbl)

	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_color_override("font_color", Color(0.35, 0.80, 0.35))
	vb.add_child(status_lbl)

	# Click to select target
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			if not enemy.is_dead():
				_select_enemy(enemy)
	)
	panel.mouse_entered.connect(func() -> void:
		if not enemy.is_dead() and _selected_enemy != enemy:
			ps.border_color = Color(0.55, 0.52, 0.40)
	)
	panel.mouse_exited.connect(func() -> void:
		if _selected_enemy != enemy:
			ps.border_color = C_BORDER
	)

	_enemy_ui[enemy] = {
		"panel": panel, "panel_style": ps,
		"hp_fill": hp_fill, "hp_fill_style": hp_fill_style,
		"hp_lbl": hp_lbl, "intent_lbl": intent_lbl, "status_lbl": status_lbl,
	}

	_enemy_row.add_child(panel)
	_refresh_enemy_display(enemy)

	# Auto-select first living enemy
	if _selected_enemy == null or _selected_enemy.is_dead():
		_select_enemy(enemy)

func _select_enemy(enemy) -> void:
	# Clear old selection border
	if _selected_enemy != null and _enemy_ui.has(_selected_enemy):
		var old_style: StyleBoxFlat = _enemy_ui[_selected_enemy]["panel_style"]
		old_style.border_color = C_BORDER
		old_style.set_border_width_all(2)
	_selected_enemy = enemy
	if _enemy_ui.has(enemy):
		var new_style: StyleBoxFlat = _enemy_ui[enemy]["panel_style"]
		new_style.border_color = Color(0.85, 0.78, 0.30)
		new_style.set_border_width_all(3)

func _refresh_enemy_display(enemy) -> void:
	if not _enemy_ui.has(enemy):
		return
	var ui: Dictionary = _enemy_ui[enemy]
	var pct: float = enemy.get_hp_percent()
	var fill: Panel = ui["hp_fill"]
	var fill_style: StyleBoxFlat = ui["hp_fill_style"]
	fill_style.bg_color = C_HP_LOW.lerp(C_HP_FILL, pct)
	fill.set_offset(SIDE_RIGHT, pct * 144.0)

	var hp_lbl: Label = ui["hp_lbl"]
	hp_lbl.text = "%.0f / %.0f" % [enemy.hp, enemy.max_hp]

	var intent = enemy.current_intent
	var intent_lbl: Label = ui["intent_lbl"]
	if enemy.is_dead():
		intent_lbl.text = "— dead —"
		intent_lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.44))
	elif intent != null:
		var color: Color
		match intent.type:
			_Enemy.IntentType.ATTACK:        color = Color(0.90, 0.35, 0.30)
			_Enemy.IntentType.DEFEND:        color = Color(0.35, 0.55, 0.90)
			_Enemy.IntentType.CHARGE:        color = Color(0.95, 0.60, 0.20)
			_Enemy.IntentType.POISON_ATTACK: color = Color(0.35, 0.80, 0.35)
			_Enemy.IntentType.SUMMON:        color = Color(0.80, 0.80, 0.30)
			_:                              color = Color.WHITE
		intent_lbl.text = intent.label
		intent_lbl.add_theme_color_override("font_color", color)

	var status_lbl: Label = ui["status_lbl"]
	var statuses: Array = []
	if enemy.poison_stacks > 0:
		statuses.append("☠ Poison x%d" % enemy.poison_stacks)
	if enemy.wound_stacks > 0:
		statuses.append("🩸 Wound x%d" % enemy.wound_stacks)
	if enemy.is_charging:
		statuses.append("⚡ CHARGING")
	status_lbl.text = "\n".join(statuses)

func _make_hp_bar(is_hero: bool) -> Control:
	var hp_bg := Panel.new()
	hp_bg.custom_minimum_size = Vector2(0, 14)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.12, 0.08, 0.08)
	bg_s.set_corner_radius_all(4)
	hp_bg.add_theme_stylebox_override("panel", bg_s)

	var fill := Panel.new()
	fill.set_anchor(SIDE_TOP, 0); fill.set_anchor(SIDE_BOTTOM, 1)
	fill.set_anchor(SIDE_LEFT, 0); fill.set_anchor(SIDE_RIGHT, 1)
	_hero_hp_fill_style = StyleBoxFlat.new()
	_hero_hp_fill_style.bg_color = C_HP_FILL
	_hero_hp_fill_style.set_corner_radius_all(4)
	fill.add_theme_stylebox_override("panel", _hero_hp_fill_style)
	hp_bg.add_child(fill)

	return hp_bg

# ── Hero Display ───────────────────────────────────────────────────────────────

func _refresh_hero_display() -> void:
	if _engine == null:
		return
	var hero = _engine._hero
	if hero == null or _hero_hp_lbl == null:
		return

	var pct: float = hero.hp / hero.max_hp if hero.max_hp > 0.0 else 0.0
	pct = clampf(pct, 0.0, 1.0)
	if _hero_hp_fill_style != null:
		_hero_hp_fill_style.bg_color = C_HP_LOW.lerp(C_HP_FILL, pct)

	_hero_hp_lbl.text = "HP  %.0f / %.0f" % [hero.hp, hero.max_hp]
	_hero_hp_lbl.add_theme_color_override("font_color",
		C_HP_LOW if pct < 0.30 else Color(0.85, 0.82, 0.72))

	if _hero_barrier_lbl != null:
		if hero.barrier > 0.0:
			_hero_barrier_lbl.text = "🛡 Barrier  %.0f" % hero.barrier
			_hero_barrier_lbl.show()
		else:
			_hero_barrier_lbl.hide()

	if _hero_poison_lbl != null:
		if hero.poison_stacks > 0:
			_hero_poison_lbl.text = "☠ Poisoned x%d" % hero.poison_stacks
			_hero_poison_lbl.show()
		else:
			_hero_poison_lbl.hide()

func _refresh_potion_buttons() -> void:
	if _engine == null:
		return
	var potions: Array = _engine._run_state.potions
	for i in range(_pot_btns.size()):
		var btn: Button = _pot_btns[i]
		if i >= potions.size() or potions[i].is_empty():
			btn.text = "— no potion —"
			btn.disabled = true
		else:
			match potions[i].get("type", ""):
				"health":    btn.text = "🧪 Health Potion"
				"wound_vial": btn.text = "🧪 Wound Vial"
				_:           btn.text = "🧪 Potion"
			btn.disabled = false

func _set_actions_enabled(enabled: bool) -> void:
	if _atk_btn:  _atk_btn.disabled  = not enabled
	if _def_btn:  _def_btn.disabled  = not enabled
	for btn in _pot_btns:
		var b: Button = btn
		if enabled:
			_refresh_potion_buttons()
		else:
			b.disabled = true

# ── Engine Signal Handlers ─────────────────────────────────────────────────────

func _connect_engine() -> void:
	_engine.phase_changed.connect(_on_phase_changed)
	_engine.damage_dealt.connect(_on_damage_dealt)
	_engine.hero_damaged.connect(_on_hero_damaged)
	_engine.hero_healed.connect(_on_hero_healed)
	_engine.status_applied.connect(_on_status_applied)
	_engine.enemy_died.connect(_on_enemy_died)
	_engine.enemy_added.connect(_on_enemy_added)
	_engine.log_added.connect(_on_log_added)
	if not _engine._hero.changed.is_connected(_refresh_hero_display):
		_engine._hero.changed.connect(_refresh_hero_display)

func _on_phase_changed(phase: int) -> void:
	var is_player: bool = (phase == _CombatEngine.Phase.PLAYER_TURN)
	_set_actions_enabled(is_player)
	if _phase_lbl:
		if phase == _CombatEngine.Phase.PLAYER_TURN:
			_phase_lbl.text = "YOUR TURN"
			_phase_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.55))
		elif phase == _CombatEngine.Phase.ENEMY_TURN:
			_phase_lbl.text = "ENEMY TURN"
			_phase_lbl.add_theme_color_override("font_color", Color(0.90, 0.40, 0.30))
		else:
			_phase_lbl.text = "DONE"
	for enemy in _enemy_ui:
		_refresh_enemy_display(enemy)

func _on_damage_dealt(target, amount: float, is_crit: bool, _dtype: String) -> void:
	_refresh_enemy_display(target)
	if _enemy_ui.has(target):
		var panel: Panel = _enemy_ui[target]["panel"]
		var color: Color = Color(1.0, 0.85, 0.20) if is_crit else Color(1.0, 0.95, 0.80)
		_spawn_float(panel, "%.0f%s" % [amount, " CRIT!" if is_crit else ""], color)

func _on_hero_damaged(amount: float, dtype: String) -> void:
	_refresh_hero_display()
	var color: Color = Color(0.35, 0.80, 0.35) if dtype == "poison" else Color(0.95, 0.35, 0.30)
	var text: String = "-%.0f%s" % [amount, " ☠" if dtype == "poison" else ""]
	# Spawn float on hero area (approximate center)
	if _enemy_row != null:
		_spawn_float_at_pos(Vector2(100, 50), text, color)

func _on_hero_healed(amount: float) -> void:
	_refresh_hero_display()

func _on_status_applied(target, stype: String, stacks: int) -> void:
	if target != null:
		_refresh_enemy_display(target)
	else:
		_refresh_hero_display()

func _on_enemy_died(enemy) -> void:
	_refresh_enemy_display(enemy)
	if _enemy_ui.has(enemy):
		var ps: StyleBoxFlat = _enemy_ui[enemy]["panel_style"]
		ps.bg_color = Color(0.08, 0.08, 0.09)
		ps.border_color = Color(0.25, 0.25, 0.27)
	# Re-select if dead enemy was selected
	if _selected_enemy == enemy:
		_selected_enemy = null
		var living: Array = _engine.get_living_enemies()
		if not living.is_empty():
			_select_enemy(living[0])

func _on_enemy_added(enemy) -> void:
	_add_enemy_panel(enemy)

func _on_log_added(text: String) -> void:
	if _log_lbl:
		_log_lbl.append_text(text + "\n")
		# Auto-scroll to bottom
		await get_tree().process_frame
		var scroll: ScrollContainer = _log_lbl.get_parent() as ScrollContainer
		if scroll:
			scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# ── Action Buttons ─────────────────────────────────────────────────────────────

func _on_attack_pressed() -> void:
	if _engine == null:
		return
	var living: Array = _engine.get_living_enemies()
	var idx := 0
	if _selected_enemy != null:
		var found: int = living.find(_selected_enemy)
		if found >= 0:
			idx = found
	_engine.player_attack(idx)

func _on_defend_pressed() -> void:
	if _engine != null:
		_engine.player_defend()

func _on_potion_pressed(slot_idx: int) -> void:
	if _engine == null:
		return
	var living: Array = _engine.get_living_enemies()
	var target_idx := 0
	if _selected_enemy != null:
		var found: int = living.find(_selected_enemy)
		if found >= 0:
			target_idx = found
	_engine.player_use_potion(slot_idx, target_idx)
	_refresh_potion_buttons()

# ── Floating Damage Numbers ────────────────────────────────────────────────────

func _spawn_float(relative_to: Control, text: String, color: Color) -> void:
	if not is_instance_valid(relative_to):
		return
	var pos: Vector2 = relative_to.global_position + Vector2(
		relative_to.size.x * 0.5 - 20.0,
		relative_to.size.y * 0.2
	)
	_spawn_float_at_pos(pos, text, color)

func _spawn_float_at_pos(global_pos: Vector2, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.global_position = global_pos
	lbl.z_index = 20
	add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 55.0, 0.9)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.tween_callback(lbl.queue_free).set_delay(0.9)
