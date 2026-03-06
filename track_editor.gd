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
var _eraser_mode := false
var _eraser_button: Button

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
}


func _ready() -> void:
	_create_piece_toolbar()
	_update_cursor()
	_update_ui()
	_refresh_track_list()
	help_label.text = "Strzalki=rusz | 1-7=segment | R=obroc | ENTER=postaw | X=gumka | T=testuj | PgUp/Dn=wys"

	# Load track if coming back from test
	if TrackData.current_track != "":
		track_name_edit.text = TrackData.current_track
		_load_track(TrackData.current_track)


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
		piece_label.text = "%s | Rot: %s | H: %d" % [TrackPieces.PIECE_NAMES[current_piece], rot_label, current_height]
	_highlight_piece_button()


func _create_piece_toolbar() -> void:
	var ui: CanvasLayer = $"../UI"

	# Bottom panel
	var panel := PanelContainer.new()
	panel.name = "PieceToolbar"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	# Anchor to bottom center
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -60.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	panel.add_child(hbox)

	for i in range(TrackPieces.PIECE_NAMES.size()):
		var btn := Button.new()
		btn.text = "%d: %s" % [i + 1, TrackPieces.PIECE_NAMES[i]]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var piece_idx: int = i
		btn.pressed.connect(func(): _select_piece(piece_idx))
		hbox.add_child(btn)
		_piece_buttons.append(btn)

	# Eraser button
	_eraser_button = Button.new()
	_eraser_button.text = "X: Gumka"
	_eraser_button.custom_minimum_size = Vector2(0, 40)
	_eraser_button.focus_mode = Control.FOCUS_NONE
	_eraser_button.pressed.connect(func(): _eraser_mode = true; _update_ui(); _update_preview())
	hbox.add_child(_eraser_button)


func _highlight_piece_button() -> void:
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.3, 0.3, 0.1, 0.8)
	active_style.border_color = Color(1.0, 0.8, 0.0)
	active_style.border_width_bottom = 3
	active_style.content_margin_left = 8.0
	active_style.content_margin_right = 8.0
	active_style.content_margin_top = 4.0
	active_style.content_margin_bottom = 4.0

	var eraser_style := StyleBoxFlat.new()
	eraser_style.bg_color = Color(0.4, 0.1, 0.1, 0.8)
	eraser_style.border_color = Color(1.0, 0.2, 0.2)
	eraser_style.border_width_bottom = 3
	eraser_style.content_margin_left = 8.0
	eraser_style.content_margin_right = 8.0
	eraser_style.content_margin_top = 4.0
	eraser_style.content_margin_bottom = 4.0

	for i in range(_piece_buttons.size()):
		var btn := _piece_buttons[i]
		if not _eraser_mode and i == current_piece:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.2))
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_stylebox_override("hover", active_style)
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")

	# Eraser button highlight
	if _eraser_mode:
		_eraser_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_eraser_button.add_theme_color_override("font_hover_color", Color(1.0, 0.3, 0.3))
		_eraser_button.add_theme_stylebox_override("normal", eraser_style)
		_eraser_button.add_theme_stylebox_override("hover", eraser_style)
	else:
		_eraser_button.remove_theme_color_override("font_color")
		_eraser_button.remove_theme_color_override("font_hover_color")
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


func _place_piece() -> void:
	var piece := TrackPieces.get_piece(current_piece)
	var rotated := TrackPieces.rotate_piece(piece, current_rotation)
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	var offset := Vector3i(cursor_grid.x * GRID, current_height, cursor_grid.y * GRID)
	for block in rotated:
		tool.set_voxel(offset + block.pos, block.type)

	# Spawn ramp collision if needed
	if current_piece == 3 or current_piece == 4:
		RampSpawner.spawn_ramp(self, cursor_grid, current_piece, current_rotation, current_height)

	# Remove existing piece at this grid position
	placed_pieces = placed_pieces.filter(func(p): return p.grid != cursor_grid)
	placed_pieces.append({
		"grid": cursor_grid,
		"piece": current_piece,
		"rotation": current_rotation,
		"base_height": current_height,
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
	var half := GRID / 2

	for x in range(-half - 2, half + 3):
		for z in range(-half - 2, half + 3):
			for y in range(0, bh + 10):
				if y == 0:
					tool.set_voxel(offset + Vector3i(x, y, z), TrackPieces.GRASS)
				else:
					tool.set_voxel(offset + Vector3i(x, y, z), TrackPieces.AIR)

	# Remove ramp collision if exists
	var ramp_name := "RampCollision_%d_%d" % [cursor_grid.x, cursor_grid.y]
	var existing := get_node_or_null(ramp_name)
	if existing:
		existing.queue_free()

	current_height = bh
	placed_pieces = placed_pieces.filter(func(p): return p.grid != cursor_grid)
	_auto_save()


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
	await get_tree().create_timer(1.5).timeout
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	for p in placed_pieces:
		var piece := TrackPieces.get_piece(p.piece)
		var rotated := TrackPieces.rotate_piece(piece, p.rotation)
		var bh: int = p.get("base_height", 0)
		var offset := Vector3i(p.grid.x * GRID, bh, p.grid.y * GRID)
		for block in rotated:
			tool.set_voxel(offset + block.pos, block.type)
		# Spawn ramp collision
		if p.piece == 3 or p.piece == 4:
			RampSpawner.spawn_ramp(self, p.grid, p.piece, p.rotation, bh)


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
	if current_piece == 3:  # ramp up
		current_height += TrackPieces.RAMP_HEIGHT
	elif current_piece == 4:  # ramp down
		current_height = maxi(0, current_height - TrackPieces.RAMP_HEIGHT)

	var ports := TrackPieces.get_ports(current_piece)
	var rotated_ports := TrackPieces.rotate_ports(ports, current_rotation)

	if rotated_ports.size() < 2:
		return

	# Second port is the "exit" (first is entry)
	var exit_port: Dictionary = rotated_ports[1]
	var next_grid: Vector2i = cursor_grid + Vector2i(exit_port.dir)

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
