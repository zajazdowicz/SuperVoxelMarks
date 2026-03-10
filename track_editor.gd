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
var _eraser_button: Button
var _pieces_row: HBoxContainer

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
}


func _ready() -> void:
	_create_piece_toolbar()
	_create_top_buttons()
	_update_cursor()
	_update_ui()
	_refresh_track_list()
	help_label.text = "Strzalki=rusz | 1-9=segment | R=obroc | ENTER=postaw | X=gumka | T=testuj | PgUp/Dn=wys"

	# Load track only if coming back from test (not from menu)
	if TrackData.current_track != "" and TrackData.current_track != "_new_":
		track_name_edit.text = TrackData.current_track
		_load_track(TrackData.current_track)
	else:
		TrackData.current_track = ""
		track_name_edit.text = "nowa_trasa"


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
	"Podstawowe": [0, 1, 2, 5, 8, 11],
	"Specjalne": [6, 7, 9, 10],
	"Rampy": [3, 4],
	"Wall Ride": [12, 13, 14],
	"Loop": [15, 16, 17, 18],
}

func _create_piece_toolbar() -> void:
	var ui: CanvasLayer = $"../UI"

	# Bottom panel
	var panel := PanelContainer.new()
	panel.name = "PieceToolbar"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	# Anchor to bottom
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -90.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Category tabs
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 2)
	vbox.add_child(tab_row)

	_pieces_row = HBoxContainer.new()
	_pieces_row.name = "PiecesRow"
	_pieces_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pieces_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_pieces_row)

	var cat_keys := PIECE_CATEGORIES.keys()
	for ci in range(cat_keys.size()):
		var cat_name: String = cat_keys[ci]
		var cat_btn := Button.new()
		cat_btn.text = cat_name
		cat_btn.custom_minimum_size = Vector2(0, 30)
		cat_btn.focus_mode = Control.FOCUS_NONE
		var idx: int = ci
		cat_btn.pressed.connect(func(): _show_category(idx))
		tab_row.add_child(cat_btn)

	# Eraser button in tabs row
	_eraser_button = Button.new()
	_eraser_button.text = "X: Gumka"
	_eraser_button.custom_minimum_size = Vector2(0, 30)
	_eraser_button.focus_mode = Control.FOCUS_NONE
	_eraser_button.pressed.connect(func(): _eraser_mode = true; _update_ui(); _update_preview())
	tab_row.add_child(_eraser_button)

	# Show first category by default
	_show_category(0)


func _show_category(cat_index: int) -> void:
	var cat_keys := PIECE_CATEGORIES.keys()
	if cat_index < 0 or cat_index >= cat_keys.size():
		return

	if not _pieces_row:
		return

	# Clear old buttons
	for child in _pieces_row.get_children():
		_pieces_row.remove_child(child)
		child.queue_free()
	_piece_buttons.clear()
	_piece_button_ids.clear()
	_eraser_mode = false

	var cat_name: String = cat_keys[cat_index]
	var piece_ids: Array = PIECE_CATEGORIES[cat_name]

	for pid in piece_ids:
		var btn := Button.new()
		btn.text = TrackPieces.PIECE_NAMES[pid]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var piece_idx: int = pid
		btn.pressed.connect(func(): _select_piece(piece_idx))
		_pieces_row.add_child(btn)
		_piece_buttons.append(btn)
		_piece_button_ids.append(pid)

	_eraser_mode = false
	_update_ui()
	_update_preview()


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
		var btn_piece_id: int = _piece_button_ids[i] if i < _piece_button_ids.size() else -1
		if not _eraser_mode and btn_piece_id == current_piece:
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

	# Special pieces (wall ride, loop) — show shape preview
	if current_piece >= 12:
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

	# Ramp down: place at lower height so top matches current road level
	var place_height := current_height
	if current_piece == 4:  # ramp down
		place_height = maxi(0, current_height - TrackPieces.RAMP_HEIGHT)

	var offset := Vector3i(cursor_grid.x * GRID, place_height, cursor_grid.y * GRID)
	for block in rotated:
		tool.set_voxel(offset + block.pos, block.type)

	# Spawn collision shapes for special pieces
	if current_piece == 3 or current_piece == 4:
		RampSpawner.spawn_ramp(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece >= 12 and current_piece <= 14:
		RampSpawner.spawn_wall_ride(self, cursor_grid, current_piece, current_rotation, place_height)
	elif current_piece >= 15 and current_piece <= 18:
		RampSpawner.spawn_loop(self, cursor_grid, current_piece, current_rotation, place_height)

	# Remove existing piece at this grid position
	placed_pieces = placed_pieces.filter(func(p): return p.grid != cursor_grid)
	placed_pieces.append({
		"grid": cursor_grid,
		"piece": current_piece,
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
	for prefix in ["RampCollision", "WallRide", "Loop"]:
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
	for p in placed_pieces:
		var piece := TrackPieces.get_piece(p.piece)
		var rotated := TrackPieces.rotate_piece(piece, p.rotation)
		var bh: int = p.get("base_height", 0)
		var offset := Vector3i(p.grid.x * GRID, bh, p.grid.y * GRID)
		for block in rotated:
			tool.set_voxel(offset + block.pos, block.type)
		# Spawn collision for special pieces
		if p.piece == 3 or p.piece == 4:
			RampSpawner.spawn_ramp(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece >= 12 and p.piece <= 14:
			RampSpawner.spawn_wall_ride(self, p.grid, p.piece, p.rotation, bh)
		elif p.piece >= 15 and p.piece <= 18:
			RampSpawner.spawn_loop(self, p.grid, p.piece, p.rotation, bh)


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
