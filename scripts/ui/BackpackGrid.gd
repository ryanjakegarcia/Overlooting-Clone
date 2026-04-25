class_name BackpackGrid
extends Control

const CELL_SIZE := 64
const COLS      := 5
const ROWS      := 6
const PAD       := 3

const C_EMPTY    := Color(0.12, 0.13, 0.16)
const C_HOVER    := Color(0.22, 0.24, 0.30)
const C_OCCUPIED := Color(0.08, 0.09, 0.11)
const C_BORDER   := Color(0.28, 0.30, 0.36)

# _state is a RunState instance (untyped — no cross-file class dep)
var _state = null
var _cell_styles: Array = []   # [col][row] -> StyleBoxFlat
var _item_panels: Dictionary = {}  # item -> Panel

signal item_left_clicked(item)
signal item_right_clicked(item, screen_pos)

# ── Setup ──────────────────────────────────────────────────────────────────────

func setup(state) -> void:
	_state = state
	_state.backpack_changed.connect(_sync)
	_build_grid()

func _build_grid() -> void:
	custom_minimum_size = Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)
	_cell_styles = []
	for c in range(COLS):
		var col_styles: Array = []
		for r in range(ROWS):
			var style := _make_style(C_EMPTY)
			var cell := Panel.new()
			cell.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			cell.size     = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_stylebox_override("panel", style)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.mouse_entered.connect(_on_hover.bind(c, r, true))
			cell.mouse_exited.connect(_on_hover.bind(c, r, false))
			add_child(cell)
			col_styles.append(style)
		_cell_styles.append(col_styles)

static func _make_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = C_BORDER
	s.set_border_width_all(1)
	return s

# ── Hover ──────────────────────────────────────────────────────────────────────

func _on_hover(col: int, row: int, entered: bool) -> void:
	if _state == null:
		return
	var item = _state.backpack[col][row]
	if item != null:
		var tint: Color = item.get_rarity_color().darkened(0.45) if entered else C_OCCUPIED
		for raw in item.get_shape_cells():
			var offset: Vector2i = raw
			var tc: int = item.grid_col + offset.x
			var tr: int = item.grid_row + offset.y
			if tc >= 0 and tc < COLS and tr >= 0 and tr < ROWS:
				_cell_styles[tc][tr].bg_color = tint
	else:
		_cell_styles[col][row].bg_color = C_HOVER if entered else C_EMPTY

# ── Sync ───────────────────────────────────────────────────────────────────────

func _sync() -> void:
	if _state == null:
		return
	for c in range(COLS):
		for r in range(ROWS):
			_cell_styles[c][r].bg_color = C_OCCUPIED if _state.backpack[c][r] != null else C_EMPTY
	for item in _item_panels:
		if is_instance_valid(_item_panels[item]):
			_item_panels[item].queue_free()
	_item_panels.clear()
	var seen := {}
	for c in range(COLS):
		for r in range(ROWS):
			var item = _state.backpack[c][r]
			if item != null and not seen.has(item):
				seen[item] = true
				_make_item_panel(item)

func _make_item_panel(item) -> void:
	var shape: Array = item.get_shape_cells()
	var max_dc := 0
	var max_dr := 0
	for raw in shape:
		var offset: Vector2i = raw
		if offset.x > max_dc: max_dc = offset.x
		if offset.y > max_dr: max_dr = offset.y

	var panel := Panel.new()
	panel.position = Vector2(item.grid_col * CELL_SIZE + PAD, item.grid_row * CELL_SIZE + PAD)
	panel.size     = Vector2((max_dc + 1) * CELL_SIZE - PAD * 2, (max_dr + 1) * CELL_SIZE - PAD * 2)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 1

	var style := StyleBoxFlat.new()
	style.bg_color = item.get_rarity_color()
	style.set_corner_radius_all(5)
	style.border_color = item.get_rarity_color().lightened(0.35)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = item.display_name
	lbl.add_theme_color_override("font_color", Color(0.05, 0.04, 0.04))
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(lbl)

	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton) or not ev.pressed:
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			item_left_clicked.emit(item)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			item_right_clicked.emit(item, get_global_mouse_position())
	)

	add_child(panel)
	_item_panels[item] = panel
