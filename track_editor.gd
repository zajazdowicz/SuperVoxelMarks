extends Node3D
## Grid-based track editor. Place/remove/rotate track segments.

const GRID := TrackPieces.SEGMENT_SIZE

@onready var terrain: VoxelTerrain = $"../VoxelTerrain"
@onready var cursor_mesh: MeshInstance3D = $CursorMesh
@onready var piece_label: Label = $"../UI/PieceLabel"
@onready var help_label: Label = $"../UI/HelpLabel"
@onready var track_name_edit: LineEdit = $"../UI/TopBar/TrackName"
@onready var track_list: ItemList = $"../UI/TopBar/TrackList"

var cursor_grid := Vector2i(0, 0)
var current_piece := 0
var current_rotation := 0
var current_height := 0
var placed_pieces: Array[Dictionary] = []
var _preview_node: Node3D
var _piece_buttons: Array[Button] = []
var _piece_button_ids: Array[int] = []
var _eraser_mode := false
var _qp_down := false  # QP arc direction: false=UP, true=DOWN (toggle with F)
var _eraser_button: Button
var _pieces_grid: GridContainer
var _active_category := 0
var _cat_buttons: Array[Button] = []
var _thumbnail_cache: Dictionary = {}  # piece_id -> ImageTexture

var _preview_colors := {
	TrackPieces.ASPHALT: Color(0.25, 0.25, 0.28, 0.6),
	TrackPieces.GRASS: Color(0.2, 0.55, 0.15, 0.6),
	TrackPieces.WALL: Color(0.75, 0.2, 0.15, 0.6),
	TrackPieces.CURB: Color(0.9, 0.9, 0.9, 0.6),
	TrackPieces.SAND: Color(0.76, 0.7, 0.5, 0.6),
	TrackPieces.RAMP_N: Color(0.3, 0.3, 0.33, 0.6),
	TrackPieces.RAMP_E: Color(0.3, 0.3, 0.33, 0.6),
	TrackPieces.RAMP_S: Color(0.3, 0.3, 0.33, 0.6),
	TrackPieces.RAMP_W: Color(0.3, 0.3, 0.33, 0.6),
	TrackPieces.RAMP_SURFACE: Color(0.25, 0.25, 0.28, 0.6),
	TrackPieces.BOOST: Color(0.1, 0.8, 0.9, 0.6),
	TrackPieces.ICE: Color(0.7, 0.85, 0.95, 0.6),
	TrackPieces.DIRT: Color(0.45, 0.3, 0.15, 0.6),
	TrackPieces.WALL_RIDE: Color(0.4, 0.3, 0.5, 0.6),
	TrackPieces.WATER: Color(0.2, 0.4, 0.8, 0.6),
	TrackPieces.COBBLESTONE: Color(0.5, 0.45, 0.4, 0.6),
	TrackPieces.TURBO: Color(1.0, 0.6, 0.0, 0.6),
	TrackPieces.SLOWDOWN: Color(0.6, 0.1, 0.1, 0.6),
}


func _ready() -> void:
	_create_piece_toolbar()
	_create_top_buttons()
	_update_cursor()
	_update_ui()
	_refresh_track_list()
	help_label.text = "Strzalki=rusz | Q/E=klocek | R=obroc | ENTER=postaw | X=gumka | T=testuj | PgUp/Dn=wys"

	# Load track only if coming back from test (not from menu)
	if TrackData.current_track != "" and TrackData.current_track != "_new_":
		track_name_edit.text = TrackData.current_track
		_load_track(TrackData.current_track)
	else:
		TrackData.current_track = ""
		track_name_edit.text = "nowa_trasa"

	# Generate thumbnails and refresh toolbar
	_generate_all_thumbnails()


func _unhandled_input(event: InputEvent) -> void:
	# Don't capture keys when typing track name
	if track_name_edit.has_focus():
		return

	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_UP:
			cursor_grid.y -= 1
			_update_cursor()
		KEY_DOWN:
			cursor_grid.y += 1
			_update_cursor()
		KEY_LEFT:
			cursor_grid.x -= 1
			_update_cursor()
		KEY_RIGHT:
			cursor_grid.x += 1
			_update_cursor()
		KEY_Q:
			current_piece = (current_piece - 1 + TrackPieces.PIECE_NAMES.size()) % TrackPieces.PIECE_NAMES.size()
			_update_ui()
			_update_preview()
		KEY_E:
			current_piece = (current_piece + 1) % TrackPieces.PIECE_NAMES.size()
			_update_ui()
			_update_preview()
		KEY_R:
			current_rotation = (current_rotation + 1) % 4
			_update_ui()
			_update_preview()
		KEY_X:
			_eraser_mode = not _eraser_mode
			_update_ui()
			_update_preview()
		KEY_ENTER:
			if _eraser_mode:
				_remove_piece()
			else:
				_place_piece()
		KEY_DELETE, KEY_BACKSPACE:
			_remove_piece()
		KEY_F:
			_qp_down = not _qp_down
			_update_ui()
			_update_preview()
		KEY_T:
			_test_track()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			var num: int = event.keycode - KEY_1
			if num < TrackPieces.PIECE_NAMES.size():
				current_piece = num
				_update_ui()
				_update_preview()
		KEY_PAGEUP:
			current_height += 1
			_update_cursor()
			_update_ui()
		KEY_PAGEDOWN:
			current_height = maxi(0, current_height - 1)
			_update_cursor()
			_update_ui()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://menu.tscn")


func _update_cursor() -> void:
	cursor_mesh.global_position = Vector3(cursor_grid.x * GRID, current_height + 0.5, cursor_grid.y * GRID)
	_update_preview()


func _update_ui() -> void:
	var rot_label: String = ["N", "E", "S", "W"][current_rotation]
	if _eraser_mode:
		piece_label.text = "GUMKA (X=wylacz) | H: %d" % current_height
	else:
		var down_label := " | DOWN" if _qp_down else ""
		piece_label.text = "%s | Rot: %s | H: %d%s" % [TrackPieces.PIECE_NAMES[current_piece], rot_label, current_height, down_label]
	_highlight_piece_button()


func _create_top_buttons() -> void:
	var topbar: HBoxContainer = $"../UI/TopBar"

	var save_btn := Button.new()
	save_btn.text = "ZAPISZ"
	save_btn.custom_minimum_size = Vector2(80, 30)
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(_on_save_pressed)
	topbar.add_child(save_btn)

	var new_btn := Button.new()
	new_btn.text = "NOWA"
	new_btn.custom_minimum_size = Vector2(70, 30)
	new_btn.focus_mode = Control.FOCUS_NONE
	new_btn.pressed.connect(_on_new_pressed)
	topbar.add_child(new_btn)

	var test_btn := Button.new()
	test_btn.text = "TESTUJ (T)"
	test_btn.custom_minimum_size = Vector2(90, 30)
	test_btn.focus_mode = Control.FOCUS_NONE
	test_btn.pressed.connect(_test_track)
	topbar.add_child(test_btn)


func _on_save_pressed() -> void:
	var tname := track_name_edit.text.strip_edges()
	if tname == "":
		track_name_edit.text = "nowa_trasa"
		tname = "nowa_trasa"
	TrackData.save_track(tname, placed_pieces)
	TrackData.current_track = tname
	_refresh_track_list()
	print("Track saved: %s (%d pieces)" % [tname, placed_pieces.size()])


func _on_new_pressed() -> void:
	# Clear everything and reload scene
	TrackData.current_track = "_new_"
	get_tree().reload_current_scene()


const PIECE_CATEGORIES := {
	"Podstawowe": [0, 1, 2, 24, 25, 26, 27, 5, 8, 11],
	"Specjalne": [6, 7, 9, 10, 39, 40, 41],
	"Nawierzchnie": [36, 37, 38],
	"Rampy": [3, 4, 30, 31, 34, 35, 21, 32, 33, 22, 23],
	"Banked": [28, 29],
	"Wall Ride": [12, 13, 14],
	#"Loop": [15, 16, 17, 18],      # DISABLED — barrel roll broken
	"Petla": [19],
	"Slopes": [42, 43, 44, 45, 46, 47],
	"QP": [48, 49, 50, 51, 52, 53],
	"Przeszkody": [54, 55, 56],
	"Slope Turn": [57, 58, 59, 60],
}

func _create_piece_toolbar() -> void:
	var ui: CanvasLayer = $"../UI"

	# Bottom panel
	var panel := PanelContainer.new()
	panel.name = "PieceToolbar"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.92)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	# Anchor to bottom
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -280.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Category tabs in ScrollContainer
	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size = Vector2(0, 56)
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(tab_scroll)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(tab_row)

	var cat_keys := PIECE_CATEGORIES.keys()
	for ci in range(cat_keys.size()):
		var cat_name: String = cat_keys[ci]
		var cat_btn := Button.new()
		cat_btn.text = cat_name
		cat_btn.custom_minimum_size = Vector2(0, 50)
		cat_btn.add_theme_font_size_override("font_size", 24)
		cat_btn.focus_mode = Control.FOCUS_NONE
		var idx: int = ci
		cat_btn.pressed.connect(func(): _show_category(idx))
		tab_row.add_child(cat_btn)
		_cat_buttons.append(cat_btn)

	# Eraser button in tabs row
	_eraser_button = Button.new()
	_eraser_button.text = "X Gumka"
	_eraser_button.custom_minimum_size = Vector2(0, 50)
	_eraser_button.add_theme_font_size_override("font_size", 24)
	_eraser_button.focus_mode = Control.FOCUS_NONE
	_eraser_button.pressed.connect(func(): _eraser_mode = true; _update_ui(); _update_preview())
	tab_row.add_child(_eraser_button)

	# Piece grid in ScrollContainer
	var piece_scroll := ScrollContainer.new()
	piece_scroll.custom_minimum_size = Vector2(0, 180)
	piece_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	piece_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(piece_scroll)

	_pieces_grid = GridContainer.new()
	_pieces_grid.name = "PiecesGrid"
	_pieces_grid.columns = 20  # enough for any category, wraps won't happen
	_pieces_grid.add_theme_constant_override("h_separation", 4)
	_pieces_grid.add_theme_constant_override("v_separation", 2)
	piece_scroll.add_child(_pieces_grid)

	# Show first category by default
	_show_category(0)


func _show_category(cat_index: int) -> void:
	var cat_keys := PIECE_CATEGORIES.keys()
	if cat_index < 0 or cat_index >= cat_keys.size():
		return
	if not _pieces_grid:
		return

	_active_category = cat_index

	# Clear old buttons
	for child in _pieces_grid.get_children():
		_pieces_grid.remove_child(child)
		child.queue_free()
	_piece_buttons.clear()
	_piece_button_ids.clear()
	_eraser_mode = false

	# Highlight active category tab
	_highlight_cat_tabs()

	var cat_name: String = cat_keys[cat_index]
	var piece_ids: Array = PIECE_CATEGORIES[cat_name]

	for pid in piece_ids:
		var btn := _create_thumbnail_button(pid)
		_pieces_grid.add_child(btn)
		_piece_buttons.append(btn)
		_piece_button_ids.append(pid)

	_update_ui()
	_update_preview()


func _create_thumbnail_button(piece_id: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 150)
	btn.focus_mode = Control.FOCUS_NONE
	var piece_idx: int = piece_id
	btn.pressed.connect(func(): _select_piece(piece_idx))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	# Thumbnail image
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(100, 100)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _thumbnail_cache.has(piece_id):
		tex_rect.texture = _thumbnail_cache[piece_id]
	vb.add_child(tex_rect)

	# Short label
	var lbl := Label.new()
	lbl.text = _short_name(piece_id)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)

	return btn


func _short_name(piece_id: int) -> String:
	# Shortened names for toolbar display
	var full: String = TrackPieces.PIECE_NAMES[piece_id]
	var shorts := {
		0: "Prosta", 1: "Zakret P", 2: "Zakret L",
		3: "Rampa+", 4: "Rampa-", 5: "Start",
		6: "Szykana", 7: "Boost", 8: "Check",
		9: "Lod", 10: "Ziemia", 11: "Sprint",
		12: "WR wej", 13: "WR prosta", 14: "WR wyj",
		19: "Petla",
		21: "Platforma", 22: "Lacz+", 23: "Lacz-",
		24: "Lagodny P", 25: "Lagodny L",
		26: "Esowka P", 27: "Esowka L",
		28: "Bank P", 29: "Bank L",
		30: "Rampa+ pol", 31: "Rampa- pol",
		32: "Most", 33: "Tunel",
		34: "Rampa-Z P", 35: "Rampa-Z L",
		36: "Piasek", 37: "Woda", 38: "Bruk",
		39: "Skok", 40: "Turbo", 41: "Slow",
		42: "15°", 43: "30°", 44: "45°",
		45: "60°", 46: "75°", 47: "90°",
		48: "0-30°", 49: "30-60°", 50: "60-90°",
		51: "90-120°", 52: "120-150°", 53: "150-180°",
	}
	return shorts.get(piece_id, full)


func _highlight_cat_tabs() -> void:
	var active_tab_style := StyleBoxFlat.new()
	active_tab_style.bg_color = Color(0.2, 0.25, 0.4, 0.9)
	active_tab_style.border_color = Color(0.4, 0.6, 1.0)
	active_tab_style.border_width_bottom = 2
	active_tab_style.content_margin_left = 6.0
	active_tab_style.content_margin_right = 6.0
	active_tab_style.content_margin_top = 4.0
	active_tab_style.content_margin_bottom = 4.0

	for i in range(_cat_buttons.size()):
		if i == _active_category:
			_cat_buttons[i].add_theme_stylebox_override("normal", active_tab_style)
			_cat_buttons[i].add_theme_stylebox_override("hover", active_tab_style)
			_cat_buttons[i].add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		else:
			_cat_buttons[i].remove_theme_stylebox_override("normal")
			_cat_buttons[i].remove_theme_stylebox_override("hover")
			_cat_buttons[i].remove_theme_color_override("font_color")


# --- Thumbnail generation (2D pixel rendering — no SubViewport) ---

const THUMB_SIZE := 64
const THUMB_BG := Color(0.15, 0.15, 0.18, 1.0)
const THUMB_VOXEL_COLORS := {
	TrackPieces.ASPHALT: Color(0.35, 0.35, 0.4),
	TrackPieces.GRASS: Color(0.25, 0.6, 0.2),
	TrackPieces.WALL: Color(0.8, 0.25, 0.15),
	TrackPieces.CURB: Color(0.85, 0.85, 0.85),
	TrackPieces.SAND: Color(0.8, 0.7, 0.4),
	TrackPieces.RAMP_N: Color(0.45, 0.45, 0.55),
	TrackPieces.RAMP_E: Color(0.45, 0.45, 0.55),
	TrackPieces.RAMP_S: Color(0.45, 0.45, 0.55),
	TrackPieces.RAMP_W: Color(0.45, 0.45, 0.55),
	TrackPieces.RAMP_SURFACE: Color(0.4, 0.4, 0.45),
	TrackPieces.BOOST: Color(0.1, 0.85, 0.95),
	TrackPieces.ICE: Color(0.7, 0.85, 0.95),
	TrackPieces.DIRT: Color(0.55, 0.35, 0.15),
	TrackPieces.WALL_RIDE: Color(0.55, 0.35, 0.65),
	TrackPieces.WATER: Color(0.25, 0.45, 0.85),
	TrackPieces.COBBLESTONE: Color(0.55, 0.5, 0.45),
	TrackPieces.TURBO: Color(1.0, 0.6, 0.0),
	TrackPieces.SLOWDOWN: Color(0.7, 0.15, 0.15),
}

func _generate_all_thumbnails() -> void:
	for pid in range(TrackPieces.PIECE_NAMES.size()):
		if pid == 20:
			continue
		if pid >= 15 and pid <= 18:
			continue
		_thumbnail_cache[pid] = _render_piece_thumbnail(pid)
	_show_category(_active_category)


func _render_piece_thumbnail(piece_id: int) -> ImageTexture:
	var piece := TrackPieces.get_piece(piece_id)
	if piece.is_empty():
		return _make_placeholder_thumbnail(piece_id)

	# Collect non-AIR blocks, find top per XZ column
	var top_blocks := {}  # Vector2i -> {pos, type}
	for block in piece:
		if block.type == TrackPieces.AIR:
			continue
		var key := Vector2i(block.pos.x, block.pos.z)
		if not top_blocks.has(key) or block.pos.y > top_blocks[key].pos.y:
			top_blocks[key] = block

	if top_blocks.is_empty():
		return _make_placeholder_thumbnail(piece_id)

	# Find XZ bounds
	var min_x := 999
	var max_x := -999
	var min_z := 999
	var max_z := -999
	var min_y := 999
	var max_y := -999
	for block in top_blocks.values():
		min_x = mini(min_x, block.pos.x)
		max_x = maxi(max_x, block.pos.x)
		min_z = mini(min_z, block.pos.z)
		max_z = maxi(max_z, block.pos.z)
		min_y = mini(min_y, block.pos.y)
		max_y = maxi(max_y, block.pos.y)

	var range_x := max_x - min_x + 1
	var range_z := max_z - min_z + 1
	var range_y := max_y - min_y + 1

	# Map voxel XZ to pixel coords with 2px padding
	var pad := 2
	var usable := THUMB_SIZE - pad * 2
	var scale_val: float = float(usable) / float(maxi(range_x, range_z))
	scale_val = minf(scale_val, 5.0)  # max 5px per voxel

	var img := Image.create(THUMB_SIZE, THUMB_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(THUMB_BG)

	# Center the drawing
	var draw_w := int(range_x * scale_val)
	var draw_h := int(range_z * scale_val)
	var ox := (THUMB_SIZE - draw_w) / 2
	var oy := (THUMB_SIZE - draw_h) / 2

	for block in top_blocks.values():
		var color: Color = THUMB_VOXEL_COLORS.get(block.type, Color(0.5, 0.5, 0.5))
		# Height-based brightness: higher = lighter
		if range_y > 0:
			var hf: float = float(block.pos.y - min_y) / float(maxi(range_y, 1))
			color = color.lightened(hf * 0.3)

		var px := ox + int((block.pos.x - min_x) * scale_val)
		var py := oy + int((block.pos.z - min_z) * scale_val)
		var pw := maxi(1, int(scale_val))
		var ph := maxi(1, int(scale_val))

		for dy in range(ph):
			for dx in range(pw):
				var fx := px + dx
				var fy := py + dy
				if fx >= 0 and fx < THUMB_SIZE and fy >= 0 and fy < THUMB_SIZE:
					img.set_pixel(fx, fy, color)

	# Draw direction arrow (north = up = -z) in center
	_draw_thumb_arrow(img, THUMB_SIZE / 2, oy + 2, Color(0.0, 1.0, 0.3, 0.8))

	return ImageTexture.create_from_image(img)


func _draw_thumb_arrow(img: Image, cx: int, tip_y: int, color: Color) -> void:
	# Small arrow pointing up (direction indicator)
	var arrow_len := 8
	for i in range(arrow_len):
		var y := tip_y + i
		if y >= 0 and y < THUMB_SIZE and cx >= 0 and cx < THUMB_SIZE:
			img.set_pixel(cx, y, color)
	# Arrowhead
	for d in range(1, 4):
		var y := tip_y + d
		if y >= 0 and y < THUMB_SIZE:
			if cx - d >= 0:
				img.set_pixel(cx - d, y, color)
			if cx + d < THUMB_SIZE:
				img.set_pixel(cx + d, y, color)


func _make_placeholder_thumbnail(piece_id: int) -> ImageTexture:
	var img := Image.create(THUMB_SIZE, THUMB_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(THUMB_BG)
	var color := Color(0.3, 0.25, 0.5)
	if piece_id == 19:
		color = Color(0.2, 0.5, 0.7)
	elif piece_id >= 12 and piece_id <= 14:
		color = Color(0.55, 0.35, 0.65)
	elif piece_id == 28 or piece_id == 29:
		color = Color(0.4, 0.5, 0.3)
	elif piece_id == 34 or piece_id == 35:
		color = Color(0.5, 0.4, 0.3)
	elif piece_id == 22 or piece_id == 23:
		color = Color(0.4, 0.4, 0.45)
	elif piece_id == 39:
		color = Color(0.6, 0.4, 0.2)

	# Filled rounded rect
	var m := 6
	for y in range(m, THUMB_SIZE - m):
		for x in range(m, THUMB_SIZE - m):
			img.set_pixel(x, y, color)

	# Direction arrow
	_draw_thumb_arrow(img, THUMB_SIZE / 2, 10, color.lightened(0.5))

	return ImageTexture.create_from_image(img)


func _highlight_piece_button() -> void:
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.25, 0.25, 0.1, 0.9)
	active_style.border_color = Color(1.0, 0.8, 0.0)
	active_style.set_border_width_all(2)
	active_style.content_margin_left = 4.0
	active_style.content_margin_right = 4.0
	active_style.content_margin_top = 2.0
	active_style.content_margin_bottom = 2.0

	var eraser_style := StyleBoxFlat.new()
	eraser_style.bg_color = Color(0.4, 0.1, 0.1, 0.8)
	eraser_style.border_color = Color(1.0, 0.2, 0.2)
	eraser_style.set_border_width_all(2)
	eraser_style.content_margin_left = 6.0
	eraser_style.content_margin_right = 6.0
	eraser_style.content_margin_top = 4.0
	eraser_style.content_margin_bottom = 4.0

	for i in range(_piece_buttons.size()):
		var btn := _piece_buttons[i]
		var btn_piece_id: int = _piece_button_ids[i] if i < _piece_button_ids.size() else -1
		if not _eraser_mode and btn_piece_id == current_piece:
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_stylebox_override("hover", active_style)
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")

	# Eraser button highlight
	if _eraser_mode:
		_eraser_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_eraser_button.add_theme_stylebox_override("normal", eraser_style)
		_eraser_button.add_theme_stylebox_override("hover", eraser_style)
	else:
		_eraser_button.remove_theme_color_override("font_color")
		_eraser_button.remove_theme_stylebox_override("normal")
		_eraser_button.remove_theme_stylebox_override("hover")


func _select_piece(index: int) -> void:
	_eraser_mode = false
	current_piece = index
	_update_ui()
	_update_preview()


func _update_preview() -> void:
	if _preview_node:
		_preview_node.queue_free()
		_preview_node = null

	if _eraser_mode:
		return

	# Special pieces (wall ride, loop, transition) — show shape preview
	# Voxel-only pieces (platforma, gentle turns) use normal voxel preview
	var shape_pieces := [12, 13, 14, 15, 16, 17, 18, 19, 22, 23, 28, 29, 34, 35, 39, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 57, 58, 59, 60]
	if current_piece in shape_pieces:
		_update_shape_preview()
		return

	var piece := TrackPieces.get_piece(current_piece)
	var rotated := TrackPieces.rotate_piece(piece, current_rotation)
	if rotated.is_empty():
		return

	var container := Node3D.new()
	container.name = "Preview"
	cursor_mesh.add_child(container)

	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.0, 1.0)

	# Only show top block per column for cleaner preview
	var top_blocks := {}
	for block in rotated:
		if block.type == TrackPieces.AIR:
			continue
		var key := Vector2i(block.pos.x, block.pos.z)
		if not top_blocks.has(key) or block.pos.y > top_blocks[key].pos.y:
			top_blocks[key] = block

	var materials := {}
	for type_id in _preview_colors:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = _preview_colors[type_id]
		mat.no_depth_test = true
		materials[type_id] = mat

	for block in top_blocks.values():
		var mi := MeshInstance3D.new()
		mi.mesh = box_mesh
		mi.position = Vector3(block.pos.x, block.pos.y + 0.5, block.pos.z)
		if materials.has(block.type):
			mi.material_override = materials[block.type]
		container.add_child(mi)

	_preview_node = container


func _update_shape_preview() -> void:
	var container := Node3D.new()
	container.name = "Preview"
	cursor_mesh.add_child(container)

	var hw: float = float(TrackPieces.ROAD_W) + 0.5
	var hl: float = float(TrackPieces.HALF)
	var ground: float = 1.0
	var rot_angle: float = -float(current_rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	if current_piece >= 12 and current_piece <= 14:
		# Wall ride preview — road rotates around left edge by 60°
		var bank_rad: float = deg_to_rad(TrackPieces.WALL_RIDE_BANK_DEG)
		var road_w: float = 2.0 * hw
		var is_entry := current_piece == 12
		var is_exit := current_piece == 14
		var segs := 4

		for seg in range(segs):
			var t0: float = float(seg) / float(segs)
			var t1: float = float(seg + 1) / float(segs)
			var bf0: float
			var bf1: float
			if is_entry:
				bf0 = t0; bf1 = t1
			elif is_exit:
				bf0 = 1.0 - t0; bf1 = 1.0 - t1
			else:
				bf0 = 1.0; bf1 = 1.0

			var angle0 := bank_rad * bf0
			var angle1 := bank_rad * bf1
			var z0 := lerpf(-hl, hl, t0)
			var z1 := lerpf(-hl, hl, t1)
			var p0l := basis_rot * Vector3(-hw, ground, z0)
			var p0r := basis_rot * Vector3(-hw + road_w * cos(angle0), ground + road_w * sin(angle0), z0)
			var p1l := basis_rot * Vector3(-hw, ground, z1)
			var p1r := basis_rot * Vector3(-hw + road_w * cos(angle1), ground + road_w * sin(angle1), z1)
			var n := (p1l - p0l).cross(p0r - p0l).normalized()
			RampSpawner._add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

	elif current_piece >= 15 and current_piece <= 18:
		# Loop quarter preview — barrel roll geometry matching ramp_spawner
		var quarter := current_piece - 15
		var angle_start: float = float(quarter) * PI / 2.0
		var angle_end: float = float(quarter + 1) * PI / 2.0
		var segs := 8
		for seg in range(segs):
			var t0: float = float(seg) / float(segs)
			var t1: float = float(seg + 1) / float(segs)
			var z0 := lerpf(-hl, hl, t0)
			var z1 := lerpf(-hl, hl, t1)
			var a0 := lerpf(angle_start, angle_end, t0)
			var a1 := lerpf(angle_start, angle_end, t1)
			var cy0 := ground + hw * (1.0 - cos(a0))
			var cy1 := ground + hw * (1.0 - cos(a1))
			var p0l := basis_rot * Vector3(-hw * cos(a0), cy0 - hw * sin(a0), z0)
			var p0r := basis_rot * Vector3(hw * cos(a0), cy0 + hw * sin(a0), z0)
			var p1l := basis_rot * Vector3(-hw * cos(a1), cy1 - hw * sin(a1), z1)
			var p1r := basis_rot * Vector3(hw * cos(a1), cy1 + hw * sin(a1), z1)
			var n := (p1l - p0l).cross(p0r - p0l).normalized()
			RampSpawner._add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

	elif current_piece == 19:
		# Vertical loop preview — dual-lane circle with X offset
		var R: float = RampSpawner.VLOOP_R
		var cy_loop: float = ground + R
		var cz_loop: float = float(TrackPieces.HALF)
		var loffset: float = RampSpawner.VLOOP_OFFSET
		# Entry taper — road widens
		for seg in range(4):
			var t0: float = float(seg) / 4.0
			var t1: float = float(seg + 1) / 4.0
			var z0_t := lerpf(-hl, cz_loop, t0)
			var z1_t := lerpf(-hl, cz_loop, t1)
			var hw0_t := lerpf(hw, loffset + hw, t0)
			var hw1_t := lerpf(hw, loffset + hw, t1)
			var p0l_t := basis_rot * Vector3(-hw0_t, ground, z0_t)
			var p0r_t := basis_rot * Vector3(hw0_t, ground, z0_t)
			var p1l_t := basis_rot * Vector3(-hw1_t, ground, z1_t)
			var p1r_t := basis_rot * Vector3(hw1_t, ground, z1_t)
			RampSpawner._add_quad(verts, normals, indices, p0l_t, p0r_t, p1r_t, p1l_t, Vector3.UP)
		# Circle
		var segs := 16
		for seg in range(segs):
			var a0: float = TAU * float(seg) / float(segs)
			var a1: float = TAU * float(seg + 1) / float(segs)
			var y0_l := cy_loop - R * cos(a0)
			var z0_l := cz_loop + R * sin(a0)
			var y1_l := cy_loop - R * cos(a1)
			var z1_l := cz_loop + R * sin(a1)
			var xc0_l := loffset * (1.0 - a0 / PI)
			var xc1_l := loffset * (1.0 - a1 / PI)
			var p0l := basis_rot * Vector3(xc0_l - hw, y0_l, z0_l)
			var p0r := basis_rot * Vector3(xc0_l + hw, y0_l, z0_l)
			var p1l := basis_rot * Vector3(xc1_l - hw, y1_l, z1_l)
			var p1r := basis_rot * Vector3(xc1_l + hw, y1_l, z1_l)
			var n := (p1l - p0l).cross(p0r - p0l).normalized()
			RampSpawner._add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)
		# Exit taper — road narrows
		var z_exit: float = float(TrackPieces.HALF) + float(TrackPieces.SEGMENT_SIZE)
		for seg in range(4):
			var t0: float = float(seg) / 4.0
			var t1: float = float(seg + 1) / 4.0
			var z0_e := lerpf(cz_loop, z_exit, t0)
			var z1_e := lerpf(cz_loop, z_exit, t1)
			var hw0_e := lerpf(loffset + hw, hw, t0)
			var hw1_e := lerpf(loffset + hw, hw, t1)
			var p0l_e := basis_rot * Vector3(-hw0_e, ground, z0_e)
			var p0r_e := basis_rot * Vector3(hw0_e, ground, z0_e)
			var p1l_e := basis_rot * Vector3(-hw1_e, ground, z1_e)
			var p1r_e := basis_rot * Vector3(hw1_e, ground, z1_e)
			RampSpawner._add_quad(verts, normals, indices, p0l_e, p0r_e, p1r_e, p1l_e, Vector3.UP)

	elif current_piece == 22 or current_piece == 23:
		# Transition preview — sine curve
		var is_up := current_piece == 22
		var segs := 4
		for seg in range(segs):
			var t0: float = float(seg) / float(segs)
			var t1: float = float(seg + 1) / float(segs)
			var z0 := lerpf(-hl, hl, t0)
			var z1 := lerpf(-hl, hl, t1)
			var h0: float
			var h1: float
			if is_up:
				h0 = sin(t0 * PI / 2.0) * RampSpawner.TRANSITION_H
				h1 = sin(t1 * PI / 2.0) * RampSpawner.TRANSITION_H
			else:
				h0 = sin((1.0 - t0) * PI / 2.0) * RampSpawner.TRANSITION_H
				h1 = sin((1.0 - t1) * PI / 2.0) * RampSpawner.TRANSITION_H
			var p0l := basis_rot * Vector3(-hw, ground + h0, z0)
			var p0r := basis_rot * Vector3(hw, ground + h0, z0)
			var p1l := basis_rot * Vector3(-hw, ground + h1, z1)
			var p1r := basis_rot * Vector3(hw, ground + h1, z1)
			var n := (p1l - p0l).cross(p0r - p0l).normalized()
			RampSpawner._add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

	elif current_piece == 28 or current_piece == 29:
		# Banked turn preview — tilted arc
		var is_right := current_piece == 28
		var bank_rad2 := deg_to_rad(RampSpawner.BANKED_ANGLE)
		var r2 := float(TrackPieces.HALF)
		var inner_r2 := r2 - float(TrackPieces.ROAD_W)
		var outer_r2 := r2 + float(TrackPieces.ROAD_W)
		var road_w2 := outer_r2 - inner_r2
		var bank_h2 := road_w2 * sin(bank_rad2)
		var cx2: float
		var cz2: float
		var as2: float
		var ae2: float
		if is_right:
			cx2 = float(TrackPieces.HALF); cz2 = float(-TrackPieces.HALF)
			as2 = PI; ae2 = PI / 2.0
		else:
			cx2 = float(-TrackPieces.HALF); cz2 = float(-TrackPieces.HALF)
			as2 = 0.0; ae2 = PI / 2.0
		var segs2 := 8
		for seg2 in range(segs2):
			var t0b: float = float(seg2) / float(segs2)
			var t1b: float = float(seg2 + 1) / float(segs2)
			var th0 := lerpf(as2, ae2, t0b)
			var th1 := lerpf(as2, ae2, t1b)
			var bf0b: float = sin(t0b * PI)
			var bf1b: float = sin(t1b * PI)
			var pi0b := basis_rot * Vector3(cx2 + inner_r2 * cos(th0), ground, cz2 + inner_r2 * sin(th0))
			var po0b := basis_rot * Vector3(cx2 + outer_r2 * cos(th0), ground + bank_h2 * bf0b, cz2 + outer_r2 * sin(th0))
			var pi1b := basis_rot * Vector3(cx2 + inner_r2 * cos(th1), ground, cz2 + inner_r2 * sin(th1))
			var po1b := basis_rot * Vector3(cx2 + outer_r2 * cos(th1), ground + bank_h2 * bf1b, cz2 + outer_r2 * sin(th1))
			var nb := (pi1b - pi0b).cross(po0b - pi0b).normalized()
			RampSpawner._add_quad(verts, normals, indices, pi0b, po0b, po1b, pi1b, nb)

	elif current_piece == 34 or current_piece == 35:
		# Ramp turn preview — arc with rising height
		var is_right3 := current_piece == 34
		var r3 := float(TrackPieces.HALF)
		var inner_r3 := r3 - float(TrackPieces.ROAD_W)
		var outer_r3 := r3 + float(TrackPieces.ROAD_W)
		var rh3 := float(TrackPieces.RAMP_HEIGHT)
		var cx3: float; var cz3: float; var as3: float; var ae3: float
		if is_right3:
			cx3 = float(TrackPieces.HALF); cz3 = float(-TrackPieces.HALF)
			as3 = PI; ae3 = PI / 2.0
		else:
			cx3 = float(-TrackPieces.HALF); cz3 = float(-TrackPieces.HALF)
			as3 = 0.0; ae3 = PI / 2.0
		for seg3 in range(8):
			var t03: float = float(seg3) / 8.0
			var t13: float = float(seg3 + 1) / 8.0
			var th03 := lerpf(as3, ae3, t03)
			var th13 := lerpf(as3, ae3, t13)
			var y03: float = ground + rh3 * t03
			var y13: float = ground + rh3 * t13
			var pi03 := basis_rot * Vector3(cx3 + inner_r3 * cos(th03), y03, cz3 + inner_r3 * sin(th03))
			var po03 := basis_rot * Vector3(cx3 + outer_r3 * cos(th03), y03, cz3 + outer_r3 * sin(th03))
			var pi13 := basis_rot * Vector3(cx3 + inner_r3 * cos(th13), y13, cz3 + inner_r3 * sin(th13))
			var po13 := basis_rot * Vector3(cx3 + outer_r3 * cos(th13), y13, cz3 + outer_r3 * sin(th13))
			var n3 := (pi13 - pi03).cross(po03 - pi03).normalized()
			RampSpawner._add_quad(verts, normals, indices, pi03, po03, po13, pi13, n3)

	elif current_piece >= 57 and current_piece <= 60:
		# Slope turn preview — arc with rising height
		var is_right_st := current_piece == 57 or current_piece == 59
		var r_st := float(TrackPieces.HALF)
		var inner_st := r_st - float(TrackPieces.ROAD_W)
		var outer_st := r_st + float(TrackPieces.ROAD_W)
		var h_st: float = float(RampSpawner.SLOPE_TURN_DELTAS.get(current_piece, 2))
		var cx_st: float; var cz_st: float; var as_st: float; var ae_st: float
		if is_right_st:
			cx_st = float(TrackPieces.HALF); cz_st = float(-TrackPieces.HALF)
			as_st = PI; ae_st = PI / 2.0
		else:
			cx_st = float(-TrackPieces.HALF); cz_st = float(-TrackPieces.HALF)
			as_st = 0.0; ae_st = PI / 2.0
		for seg_st in range(8):
			var t0_st: float = float(seg_st) / 8.0
			var t1_st: float = float(seg_st + 1) / 8.0
			var th0_st := lerpf(as_st, ae_st, t0_st)
			var th1_st := lerpf(as_st, ae_st, t1_st)
			var y0_st: float = ground + h_st * t0_st
			var y1_st: float = ground + h_st * t1_st
			var pi0_st := basis_rot * Vector3(cx_st + inner_st * cos(th0_st), y0_st, cz_st + inner_st * sin(th0_st))
			var po0_st := basis_rot * Vector3(cx_st + outer_st * cos(th0_st), y0_st, cz_st + outer_st * sin(th0_st))
			var pi1_st := basis_rot * Vector3(cx_st + inner_st * cos(th1_st), y1_st, cz_st + inner_st * sin(th1_st))
			var po1_st := basis_rot * Vector3(cx_st + outer_st * cos(th1_st), y1_st, cz_st + outer_st * sin(th1_st))
			var n_st := (pi1_st - pi0_st).cross(po0_st - pi0_st).normalized()
			RampSpawner._add_quad(verts, normals, indices, pi0_st, po0_st, po1_st, pi1_st, n_st)

	elif current_piece == 39:
		# Jump pad preview — half-segment ramp
		var jump_h := float(TrackPieces.JUMP_HEIGHT)
		var segs4 := 3
		for seg4 in range(segs4):
			var t04: float = float(seg4) / float(segs4)
			var t14: float = float(seg4 + 1) / float(segs4)
			var z04 := lerpf(0.0, hl, t04)
			var z14 := lerpf(0.0, hl, t14)
			var y04: float = lerpf(ground, ground + jump_h, t04)
			var y14: float = lerpf(ground, ground + jump_h, t14)
			var p04l := basis_rot * Vector3(-hw, y04, z04)
			var p04r := basis_rot * Vector3(hw, y04, z04)
			var p14l := basis_rot * Vector3(-hw, y14, z14)
			var p14r := basis_rot * Vector3(hw, y14, z14)
			var n4 := (p14l - p04l).cross(p04r - p04l).normalized()
			RampSpawner._add_quad(verts, normals, indices, p04l, p04r, p14r, p14l, n4)

	elif current_piece >= 42 and current_piece <= 47:
		# Slope preview — tilted road
		var angle_deg5: float = TrackPieces.SLOPE_ANGLES.get(current_piece, 45.0)
		var angle_rad5 := deg_to_rad(angle_deg5)
		var seg_len5: float = float(TrackPieces.SEGMENT_SIZE)
		var run5: float = cos(angle_rad5) * seg_len5
		var rise5: float = sin(angle_rad5) * seg_len5
		var segs5 := 4
		for seg5 in range(segs5):
			var t05: float = float(seg5) / float(segs5)
			var t15: float = float(seg5 + 1) / float(segs5)
			var z05 := lerpf(-hl, -hl + run5, t05)
			var z15 := lerpf(-hl, -hl + run5, t15)
			var y05: float = ground + rise5 * t05
			var y15: float = ground + rise5 * t15
			var p05l := basis_rot * Vector3(-hw, y05, z05)
			var p05r := basis_rot * Vector3(hw, y05, z05)
			var p15l := basis_rot * Vector3(-hw, y15, z15)
			var p15r := basis_rot * Vector3(hw, y15, z15)
			var n5 := (p15l - p05l).cross(p05r - p05l).normalized()
			RampSpawner._add_quad(verts, normals, indices, p05l, p05r, p15r, p15l, n5)

	elif current_piece >= 48 and current_piece <= 53:
		# Quarter-pipe preview — curved arc
		var qp_angles: Array = TrackPieces.QP_ANGLES.get(current_piece, [0.0, 30.0])
		var qp_from: float = deg_to_rad(qp_angles[0])
		var qp_to: float = deg_to_rad(qp_angles[1])
		var qp_R: float = float(TrackPieces.SEGMENT_SIZE)
		var qp_pivot_y: float = ground + qp_R * cos(qp_from)
		var qp_pivot_z: float = -hl - qp_R * sin(qp_from)
		var qp_segs := 6
		for seg6 in range(qp_segs):
			var t06: float = float(seg6) / float(qp_segs)
			var t16: float = float(seg6 + 1) / float(qp_segs)
			var a06: float = lerpf(qp_from, qp_to, t06)
			var a16: float = lerpf(qp_from, qp_to, t16)
			var y06: float = qp_pivot_y - qp_R * cos(a06)
			var z06: float = qp_pivot_z + qp_R * sin(a06)
			var y16: float = qp_pivot_y - qp_R * cos(a16)
			var z16: float = qp_pivot_z + qp_R * sin(a16)
			var p06l := basis_rot * Vector3(-hw, y06, z06)
			var p06r := basis_rot * Vector3(hw, y06, z06)
			var p16l := basis_rot * Vector3(-hw, y16, z16)
			var p16r := basis_rot * Vector3(hw, y16, z16)
			var n6 := (p16l - p06l).cross(p06r - p06l).normalized()
			RampSpawner._add_quad(verts, normals, indices, p06l, p06r, p16r, p16l, n6)

	if verts.is_empty():
		container.queue_free()
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.4, 0.7, 0.5)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mi.material_override = mat
	container.add_child(mi)

	# Arrow showing direction
	var arrow := MeshInstance3D.new()
	var arrow_mesh := BoxMesh.new()
	arrow_mesh.size = Vector3(0.5, 0.3, 2.0)
	arrow.mesh = arrow_mesh
	arrow.position = basis_rot * Vector3(0, ground + 1.0, 2.0)
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arrow_mat.albedo_color = Color(0.0, 1.0, 0.3, 0.6)
	arrow_mat.no_depth_test = true
	arrow.material_override = arrow_mat
	container.add_child(arrow)

	_preview_node = container


func _place_piece() -> void:
	var piece := TrackPieces.get_piece(current_piece)
	var rotated := TrackPieces.rotate_piece(piece, current_rotation)
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	# Ramp/transition down: place at lower height so top matches current road level
	var place_height := current_height
	if current_piece == 4:  # ramp down
		place_height = maxi(0, current_height - TrackPieces.RAMP_HEIGHT)
	elif current_piece == 31:  # half ramp down
		place_height = maxi(0, current_height - TrackPieces.HALF_RAMP_HEIGHT)
	elif current_piece == 23:  # transition down
		place_height = maxi(0, current_height - TrackPieces.TRANSITION_HEIGHT)
	elif _qp_down and current_piece >= 48 and current_piece <= 53:
		# DOWN QP: base_height at the LOW end, car enters from HIGH (current_height)
		var qp_delta: int = TrackPieces.QP_DELTAS[current_piece]
		place_height = maxi(0, current_height - qp_delta)

	var offset := Vector3i(cursor_grid.x * GRID, place_height, cursor_grid.y * GRID)
	for block in rotated:
		tool.set_voxel(offset + block.pos, block.type)

	# Spawn collision shapes for special pieces
	if current_piece in [3, 4, 30, 31]:
		RampSpawner.spawn_ramp(self, cursor_grid, current_piece, current_rotation, place_height)
		# Clear HIGH-end boundary voxels (neighbor may have placed ASPHALT there)
		var is_up2: bool = current_piece == 3 or current_piece == 30
		var high_z2: int = TrackPieces.HI if is_up2 else TrackPieces.LO
		var rh2: int = TrackPieces.RAMP_HEIGHT if (current_piece == 3 or current_piece == 4) else TrackPieces.HALF_RAMP_HEIGHT
		for x2 in range(-TrackPieces.ROAD_W, TrackPieces.ROAD_W + 1):
			var rx2 := x2
			var rz2 := high_z2
			for _r in range(current_rotation % 4):
				var tmp2 := rx2
				rx2 = -rz2
				rz2 = tmp2
			for h2 in range(0, rh2 + 1):
				tool.set_voxel(offset + Vector3i(rx2, h2, rz2), TrackPieces.AIR)
	elif current_piece >= 12 and current_piece <= 14:
		RampSpawner.spawn_wall_ride(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece >= 15 and current_piece <= 18:
		RampSpawner.spawn_loop(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece == 19:
		RampSpawner.spawn_vloop(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece == 22 or current_piece == 23:
		RampSpawner.spawn_transition(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece == 28 or current_piece == 29:
		RampSpawner.spawn_banked_turn(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece == 34 or current_piece == 35:
		RampSpawner.spawn_ramp_turn(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece == 39:
		RampSpawner.spawn_jump_pad(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece >= 42 and current_piece <= 47:
		RampSpawner.spawn_slope(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece >= 48 and current_piece <= 53:
		RampSpawner.spawn_quarter_pipe(self, cursor_grid, current_piece, current_rotation, place_height, _qp_down)
	elif current_piece >= 57 and current_piece <= 60:
		RampSpawner.spawn_slope_turn(self, cursor_grid, current_piece, current_rotation, place_height)

	# Remove existing piece at this grid position
	placed_pieces = placed_pieces.filter(func(p): return p.grid != cursor_grid)
	var piece_data := {
		"grid": cursor_grid,
		"piece": current_piece,
		"rotation": current_rotation,
		"base_height": place_height,
	}
	if _qp_down and current_piece >= 48 and current_piece <= 53:
		piece_data["down"] = true
	placed_pieces.append(piece_data)

	# Full loop (piece 19) occupies 2 cells — register the second cell
	if current_piece == 19:
		var ports := TrackPieces.get_ports(current_piece)
		var rp := TrackPieces.rotate_ports(ports, current_rotation)
		var cell2: Vector2i = cursor_grid + Vector2i(rp[1].dir)
		placed_pieces = placed_pieces.filter(func(p): return p.grid != cell2)
		placed_pieces.append({
			"grid": cell2,
			"piece": 20,  # marker for second cell
			"rotation": current_rotation,
			"base_height": place_height,
		})

	_auto_save()
	_snap_to_next_port()


func _remove_piece() -> void:
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	# Find base_height of piece at cursor
	var bh := 0
	for p in placed_pieces:
		if p.grid == cursor_grid:
			bh = p.get("base_height", 0)
			break

	var offset := Vector3i(cursor_grid.x * GRID, 0, cursor_grid.y * GRID)
	var half := TrackPieces.HALF

	# Clear only this segment's range (LO..HI = -HALF..+HALF), no overflow
	for x in range(-half, half + 1):
		for z in range(-half, half + 1):
			for y in range(0, bh + 20):
				if y == 0:
					tool.set_voxel(offset + Vector3i(x, y, z), TrackPieces.GRASS)
				else:
					tool.set_voxel(offset + Vector3i(x, y, z), TrackPieces.AIR)

	# Remove collision shapes if exist (ramp, wall ride, loop)
	for prefix in ["RampCollision", "WallRide", "Loop", "VLoop", "Slope", "ZeroGZone"]:
		var node_name := "%s_%d_%d" % [prefix, cursor_grid.x, cursor_grid.y]
		var existing := get_node_or_null(node_name)
		if existing:
			existing.queue_free()

	current_height = bh
	placed_pieces = placed_pieces.filter(func(p): return p.grid != cursor_grid)

	# Re-draw neighbors that share the overlap edge
	_redraw_neighbors(cursor_grid, tool)
	_auto_save()


func _redraw_neighbors(removed_grid: Vector2i, tool: VoxelTool) -> void:
	# After erasing, re-place voxels of adjacent segments so their shared
	# overlap edge (1 voxel) is restored.
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d in dirs:
		var neighbor_grid: Vector2i = removed_grid + d
		for p in placed_pieces:
			if p.grid == neighbor_grid:
				var piece := TrackPieces.get_piece(p.piece)
				var rotated := TrackPieces.rotate_piece(piece, p.rotation)
				var nbh: int = p.get("base_height", 0)
				var n_offset := Vector3i(neighbor_grid.x * GRID, nbh, neighbor_grid.y * GRID)
				for block in rotated:
					tool.set_voxel(n_offset + block.pos, block.type)
				break


func _auto_save() -> void:
	var name := track_name_edit.text.strip_edges()
	if name == "":
		return
	TrackData.save_track(name, placed_pieces)


func _test_track() -> void:
	var name := track_name_edit.text.strip_edges()
	if name == "":
		track_name_edit.text = "test"
		name = "test"
	TrackData.save_track(name, placed_pieces)
	TrackData.current_track = name
	get_tree().change_scene_to_file("res://race.tscn")


func _load_track(track_name: String) -> void:
	placed_pieces = TrackData.load_track(track_name)
	# Rebuild all pieces on terrain
	await get_tree().create_timer(0.5).timeout
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	# Sort by base_height — higher pieces built last so their voxels win
	var sorted := placed_pieces.duplicate()
	sorted.sort_custom(func(a, b): return a.get("base_height", 0) < b.get("base_height", 0))
	for p in sorted:
		var piece := TrackPieces.get_piece(p.piece)
		var rotated := TrackPieces.rotate_piece(piece, p.rotation)
		var bh: int = p.get("base_height", 0)
		var offset := Vector3i(p.grid.x * GRID, bh, p.grid.y * GRID)
		for block in rotated:
			tool.set_voxel(offset + block.pos, block.type)
		# Spawn collision for special pieces
		if p.piece in [3, 4, 30, 31]:
			RampSpawner.spawn_ramp(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece >= 12 and p.piece <= 14:
			RampSpawner.spawn_wall_ride(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece >= 15 and p.piece <= 18:
			RampSpawner.spawn_loop(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece == 19:
			RampSpawner.spawn_vloop(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece == 22 or p.piece == 23:
			RampSpawner.spawn_transition(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece == 28 or p.piece == 29:
			RampSpawner.spawn_banked_turn(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece == 34 or p.piece == 35:
			RampSpawner.spawn_ramp_turn(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece == 39:
			RampSpawner.spawn_jump_pad(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece >= 42 and p.piece <= 47:
			RampSpawner.spawn_slope(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece >= 48 and p.piece <= 53:
			var qp_down: bool = p.get("down", false)
			RampSpawner.spawn_quarter_pipe(self, p.grid, p.piece, p.rotation, bh, qp_down)
		elif p.piece >= 57 and p.piece <= 60:
			RampSpawner.spawn_slope_turn(self, p.grid, p.piece, p.rotation, bh)
	# Second pass: clear boundary voxels at ramp HIGH end
	for p in placed_pieces:
		if p.piece not in [3, 4, 30, 31]:
			continue
		var bh2: int = p.get("base_height", 0)
		var offset2 := Vector3i(p.grid.x * GRID, bh2, p.grid.y * GRID)
		var is_up3: bool = p.piece == 3 or p.piece == 30
		var high_z: int = TrackPieces.HI if is_up3 else TrackPieces.LO
		var rh3: int = TrackPieces.RAMP_HEIGHT if (p.piece == 3 or p.piece == 4) else TrackPieces.HALF_RAMP_HEIGHT
		for x2 in range(-TrackPieces.ROAD_W, TrackPieces.ROAD_W + 1):
			var rx := x2
			var rz := high_z
			for _r in range(p.rotation % 4):
				var tmp := rx
				rx = -rz
				rz = tmp
			for h2 in range(0, rh3 + 1):
				tool.set_voxel(offset2 + Vector3i(rx, h2, rz), TrackPieces.AIR)


func _refresh_track_list() -> void:
	track_list.clear()
	for name in TrackData.get_track_names():
		track_list.add_item(name)


func _on_track_list_item_selected(index: int) -> void:
	var name := track_list.get_item_text(index)
	track_name_edit.text = name
	TrackData.current_track = name
	get_tree().change_scene_to_file("res://editor.tscn")


func _snap_to_next_port() -> void:
	# After placing a piece, move cursor to the "forward" port
	# so user can seamlessly continue building the track

	# Adjust height based on piece type
	# Ramp up: next piece starts at higher level
	# Ramp down: place_height already adjusted in _place_piece, no change needed here
	if current_piece == 3:  # ramp up
		current_height += TrackPieces.RAMP_HEIGHT
	elif current_piece == 30:  # half ramp up
		current_height += TrackPieces.HALF_RAMP_HEIGHT
	elif current_piece == 34 or current_piece == 35:  # ramp turn up
		current_height += TrackPieces.RAMP_HEIGHT
	elif current_piece == 4:  # ramp down
		current_height = maxi(0, current_height - TrackPieces.RAMP_HEIGHT)
	elif current_piece == 31:  # half ramp down
		current_height = maxi(0, current_height - TrackPieces.HALF_RAMP_HEIGHT)
	elif current_piece == 22:  # transition up
		current_height += TrackPieces.TRANSITION_HEIGHT
	elif current_piece == 23:  # transition down
		current_height = maxi(0, current_height - TrackPieces.TRANSITION_HEIGHT)
	elif current_piece >= 42 and current_piece <= 47:  # slopes
		var angle_rad := deg_to_rad(TrackPieces.SLOPE_ANGLES[current_piece])
		var rise: int = ceili(sin(angle_rad) * float(TrackPieces.SEGMENT_SIZE))
		current_height += rise
	elif current_piece >= 48 and current_piece <= 53:  # quarter-pipes
		var delta: int = TrackPieces.QP_DELTAS[current_piece]
		if _qp_down:
			current_height = maxi(0, current_height - delta)
		else:
			current_height += delta
	elif current_piece >= 57 and current_piece <= 60:  # slope turns
		var st_delta: int = RampSpawner.SLOPE_TURN_DELTAS.get(current_piece, 2)
		current_height += st_delta

	var ports := TrackPieces.get_ports(current_piece)
	var rotated_ports := TrackPieces.rotate_ports(ports, current_rotation)

	if rotated_ports.size() < 2:
		return

	# Second port is the "exit" (first is entry)
	var exit_port: Dictionary = rotated_ports[1]
	var step: int = 2 if current_piece == 19 else 1  # loop spans 2 cells
	var next_grid: Vector2i = cursor_grid + Vector2i(exit_port.dir) * step

	# Check if there's already a piece at the next position
	var occupied := false
	for p in placed_pieces:
		if p.grid == next_grid:
			occupied = true
			break

	if not occupied:
		cursor_grid = next_grid
		# Auto-rotate next piece to match entry direction
		# Exit port direction tells us which side the next piece should enter from
		# If we exit N (+Z), next piece enters from S (-Z) = default rotation 0
		# If we exit E (+X), next piece enters from W (-X) = rotation 1
		# If we exit S (-Z), next piece enters from N (+Z) = rotation 2
		# If we exit W (-X), next piece enters from E (+X) = rotation 3
		var dir: Vector2i = Vector2i(exit_port.dir)
		if dir == Vector2i(0, 1):    # exit N
			current_rotation = 0
		elif dir == Vector2i(1, 0):  # exit E
			current_rotation = 1
		elif dir == Vector2i(0, -1): # exit S
			current_rotation = 2
		elif dir == Vector2i(-1, 0): # exit W
			current_rotation = 3
		_update_cursor()
		_update_ui()
