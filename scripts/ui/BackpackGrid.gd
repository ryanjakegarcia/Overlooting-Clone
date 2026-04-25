class_name BackpackGrid
extends Control

const _ItemView = preload("res://scripts/ui/BackpackItemView.gd")

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

var _drag_item = null
var _preview_cells: Array = []
var _preview_valid: bool = false
var _item_styles: Dictionary = {}   # item -> StyleBoxFlat
var _broker_row: int = -1

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
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_clear_drop_preview()
	for c in range(COLS):
		for r in range(ROWS):
			_cell_styles[c][r].bg_color = C_OCCUPIED if _state.backpack[c][r] != null else C_EMPTY
	for item in _item_panels:
		if is_instance_valid(_item_panels[item]):
			_item_panels[item].queue_free()
	_item_panels.clear()
	_item_styles.clear()
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

	var panel = _ItemView.new()
	panel.position = Vector2(item.grid_col * CELL_SIZE + PAD, item.grid_row * CELL_SIZE + PAD)
	panel.size     = Vector2((max_dc + 1) * CELL_SIZE - PAD * 2, (max_dr + 1) * CELL_SIZE - PAD * 2)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 1
	panel.bind_data(item, self)

	var style := StyleBoxFlat.new()
	style.bg_color = item.get_rarity_color()
	style.set_corner_radius_all(5)
	style.border_color = item.get_rarity_color().lightened(0.35)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	_item_styles[item] = style

	var lbl := Label.new()
	lbl.text = item.display_name
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", Color(0.05, 0.04, 0.04))
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(lbl)

	panel.left_clicked.connect(func(clicked_item) -> void:
		item_left_clicked.emit(clicked_item)
	)
	panel.right_clicked.connect(func(clicked_item, screen_pos) -> void:
		item_right_clicked.emit(clicked_item, screen_pos)
	)

	add_child(panel)
	_item_panels[item] = panel

# ── Drag & Drop ───────────────────────────────────────────────────────────────

func begin_drag(item) -> void:
	_drag_item = item
	_clear_drop_preview()

func end_drag(succeeded: bool) -> void:
	if not succeeded and _drag_item != null:
		_flash_invalid_preview(_drag_item, _drag_item.grid_col, _drag_item.grid_row)
	_drag_item = null
	_clear_drop_preview()

func _can_drop_data(at_position: Vector2, data) -> bool:
	if _state == null or typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("kind", "") != "backpack_item":
		return false
	var item = data.get("item", null)
	if item == null:
		return false

	var anchor := _anchor_from_position(at_position)
	var valid: bool = _state.can_place_item(item, anchor.x, anchor.y, item)
	_paint_drop_preview(item, anchor.x, anchor.y, valid)
	return valid

func _drop_data(at_position: Vector2, data) -> void:
	if _state == null or typeof(data) != TYPE_DICTIONARY:
		return
	if data.get("kind", "") != "backpack_item":
		return
	var item = data.get("item", null)
	if item == null:
		return

	var anchor := _anchor_from_position(at_position)
	if not _state.can_place_item(item, anchor.x, anchor.y, item):
		_flash_invalid_preview(item, anchor.x, anchor.y)
		return

	if item.is_in_backpack():
		_state.remove_item_from_backpack(item)
	_state.place_item(item, anchor.x, anchor.y)

func _anchor_from_position(at_position: Vector2) -> Vector2i:
	var col := roundi((at_position.x - CELL_SIZE * 0.5) / CELL_SIZE)
	var row := roundi((at_position.y - CELL_SIZE * 0.5) / CELL_SIZE)
	return Vector2i(col, row)

func _paint_drop_preview(item, col: int, row: int, valid: bool) -> void:
	_clear_drop_preview()
	_preview_valid = valid
	for raw in item.get_shape_cells():
		var offset: Vector2i = raw
		var tc := col + offset.x
		var tr := row + offset.y
		if tc < 0 or tc >= COLS or tr < 0 or tr >= ROWS:
			continue
		_preview_cells.append(Vector2i(tc, tr))
		_cell_styles[tc][tr].bg_color = Color(0.20, 0.62, 0.30) if valid else Color(0.72, 0.24, 0.22)

func _clear_drop_preview() -> void:
	if _state == null:
		_preview_cells.clear()
		return
	for cell in _preview_cells:
		var c: int = cell.x
		var r: int = cell.y
		if c < 0 or c >= COLS or r < 0 or r >= ROWS:
			continue
		_cell_styles[c][r].bg_color = C_OCCUPIED if _state.backpack[c][r] != null else C_EMPTY
	_preview_cells.clear()

func _flash_invalid_preview(item, col: int, row: int) -> void:
	var cells: Array = []
	for raw in item.get_shape_cells():
		var offset: Vector2i = raw
		var tc := col + offset.x
		var tr := row + offset.y
		if tc < 0 or tc >= COLS or tr < 0 or tr >= ROWS:
			continue
		cells.append(Vector2i(tc, tr))
		_cell_styles[tc][tr].bg_color = Color(0.78, 0.18, 0.18)
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void:
		for cell in cells:
			var c: int = cell.x
			var r: int = cell.y
			_cell_styles[c][r].bg_color = C_OCCUPIED if _state.backpack[c][r] != null else C_EMPTY
	)

# ── Forge Highlights ──────────────────────────────────────────────────────────

func set_forge_highlights(eligible_items: Array) -> void:
	var eligible: Dictionary = {}
	for item in eligible_items:
		eligible[item] = true
	for item in _item_styles:
		var style: StyleBoxFlat = _item_styles[item]
		if eligible.has(item):
			style.bg_color     = item.get_rarity_color()
			style.border_color = Color(1.0, 0.85, 0.20)
			style.set_border_width_all(3)
		else:
			style.bg_color     = item.get_rarity_color().darkened(0.5)
			style.border_color = item.get_rarity_color().darkened(0.3)
			style.set_border_width_all(1)

func clear_forge_highlights() -> void:
	for item in _item_styles:
		var style: StyleBoxFlat = _item_styles[item]
		style.bg_color     = item.get_rarity_color()
		style.border_color = item.get_rarity_color().lightened(0.35)
		style.set_border_width_all(2)

# ── Broker Highlights ─────────────────────────────────────────────────────────

func highlight_broker_row(row: int) -> void:
	_broker_row = row
	for c in range(COLS):
		_cell_styles[c][row].bg_color = Color(0.70, 0.10, 0.10)

func clear_broker_highlight() -> void:
	if _broker_row < 0 or _state == null:
		_broker_row = -1
		return
	for c in range(COLS):
		var r: int = _broker_row
		_cell_styles[c][r].bg_color = C_OCCUPIED if _state.backpack[c][r] != null else C_EMPTY
	_broker_row = -1
