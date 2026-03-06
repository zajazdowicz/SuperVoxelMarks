class_name TrackPieces

const SEGMENT_SIZE := 12
const HALF := SEGMENT_SIZE / 2  # 6
# Range: -HALF to HALF inclusive (13 voxels). 1 voxel overlap with neighbors = no gaps.
const LO := -HALF
const HI := HALF  # inclusive

const AIR := 0
const ASPHALT := 1
const GRASS := 2
const WALL := 3
const CURB := 4
const SAND := 5
const RAMP_N := 6
const RAMP_E := 7
const RAMP_S := 8
const RAMP_W := 9
const RAMP_SURFACE := 10  # Looks like asphalt but NO voxel collision (for smooth ramps)
const BOOST := 11
const ICE := 12
const DIRT := 13

const ROAD_W := 4  # road -4..+4, walls at +-5

const PIECE_NAMES := [
	"Prosta",
	"Zakret prawo",
	"Zakret lewo",
	"Rampa gora",
	"Rampa dol",
	"Start/Meta",
	"Szykana",
	"Boost",
	"Checkpoint",
	"Lod",
	"Ziemia",
]

static func get_ports(index: int) -> Array[Dictionary]:
	match index:
		0: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
		1: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "E", "dir": Vector2i(1, 0)}]
		2: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "W", "dir": Vector2i(-1, 0)}]
		3: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
		4: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
		5: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
		6: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
		7: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
		8: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
		9: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
		10: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
	return []

static func rotate_ports(ports: Array[Dictionary], rotations: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sides := ["S", "W", "N", "E"]
	var dirs := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
	for port in ports:
		var side_idx := sides.find(port.side)
		var new_idx := (side_idx + rotations) % 4
		result.append({"side": sides[new_idx], "dir": dirs[new_idx]})
	return result

static func get_piece(index: int) -> Array[Dictionary]:
	match index:
		0: return _straight()
		1: return _turn_right()
		2: return _turn_left()
		3: return _ramp_up()
		4: return _ramp_down()
		5: return _start_finish()
		6: return _chicane()
		7: return _boost_pad()
		8: return _checkpoint()
		9: return _ice_section()
		10: return _dirt_section()
	return []

static func rotate_piece(piece: Array[Dictionary], rotations: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for block in piece:
		var p: Vector3i = block.pos
		var rx := p.x
		var rz := p.z
		var block_type: int = block.type
		for _r in range(rotations % 4):
			var tmp := rx
			rx = -rz
			rz = tmp
			if block_type >= RAMP_N and block_type <= RAMP_W:
				block_type = RAMP_N + ((block_type - RAMP_N + 1) % 4)
		result.append({"pos": Vector3i(rx, p.y, rz), "type": block_type})
	return result


# === STRAIGHT (S -> N) ===
static func _straight() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				if absi(x) == ROAD_W and z % 3 == 0:
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === TURN RIGHT (S -> E): L-shape ===
static func _turn_right() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			# Vertical leg (entry from S): road at x=-4..4, full z range up to z=4
			var on_vert_road := absi(x) <= ROAD_W and z <= ROAD_W
			# Horizontal leg (exit to E): road at z=-4..4, from x=-4 to right edge
			var on_horiz_road := absi(z) <= ROAD_W and x >= -ROAD_W
			# Combined road area
			var on_road := on_vert_road or on_horiz_road

			if on_road:
				blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			else:
				# Wall if adjacent to road
				var is_wall := false
				# Check all 4 neighbors
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx: int = x + d.x
					var nz: int = z + d.y
					var nr_vert := absi(nx) <= ROAD_W and nz <= ROAD_W
					var nr_horiz := absi(nz) <= ROAD_W and nx >= -ROAD_W
					if nr_vert or nr_horiz:
						is_wall = true
						break
				if is_wall:
					blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
					blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === TURN LEFT (S -> W): L-shape mirrored ===
static func _turn_left() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			# Vertical leg (entry from S): road at x=-4..4, z up to z=4
			var on_vert_road := absi(x) <= ROAD_W and z <= ROAD_W
			# Horizontal leg (exit to W): road at z=-4..4, from x=+4 to left edge
			var on_horiz_road := absi(z) <= ROAD_W and x <= ROAD_W
			var on_road := on_vert_road or on_horiz_road

			if on_road:
				blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			else:
				var is_wall := false
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx: int = x + d.x
					var nz: int = z + d.y
					var nr_vert := absi(nx) <= ROAD_W and nz <= ROAD_W
					var nr_horiz := absi(nz) <= ROAD_W and nx <= ROAD_W
					if nr_vert or nr_horiz:
						is_wall = true
						break
				if is_wall:
					blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
					blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === RAMP UP (visual only - collision handled by ramp_spawner) ===
# Rise: 2 blocks over segment length
const RAMP_HEIGHT := 6

static func _ramp_up() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(SEGMENT_SIZE)
		var height := int(progress * float(RAMP_HEIGHT))
		for x in range(LO, HI + 1):
			# Road area: clear to AIR (collision from RampSpawner only)
			if absi(x) <= ROAD_W:
				for h in range(0, height + 1):
					blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
			elif absi(x) == ROAD_W + 1:
				for h in range(0, height + 3):
					blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


# === RAMP DOWN ===
static func _ramp_down() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(SEGMENT_SIZE)
		var height := int((1.0 - progress) * float(RAMP_HEIGHT))
		for x in range(LO, HI + 1):
			# Road area: clear to AIR (collision from RampSpawner only)
			if absi(x) <= ROAD_W:
				for h in range(0, height + 1):
					blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
			elif absi(x) == ROAD_W + 1:
				for h in range(0, height + 3):
					blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


# === START / FINISH ===
static func _start_finish() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				if z >= -1 and z <= 0:
					var checker := (x + z) % 2 == 0
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB if checker else ASPHALT})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === CHICANE ===
static func _chicane() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(SEGMENT_SIZE)
		var offset: float = sin(progress * PI * 2.0) * 2.0
		for x in range(LO, HI + 1):
			var local_x: float = float(x) - offset
			if absf(local_x) <= float(ROAD_W):
				blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absf(local_x) <= float(ROAD_W) + 1.5:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === BOOST PAD ===
static func _boost_pad() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				if absi(x) <= 2:
					blocks.append({"pos": Vector3i(x, 0, z), "type": BOOST})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === CHECKPOINT ===
static func _checkpoint() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				# Checkpoint stripes at z=-1..0
				if z >= -1 and z <= 0:
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
				# Tall gate posts at checkpoint line
				if z >= -1 and z <= 0:
					blocks.append({"pos": Vector3i(x, 2, z), "type": WALL})
					blocks.append({"pos": Vector3i(x, 3, z), "type": WALL})
	return blocks


# === ICE SECTION ===
static func _ice_section() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				blocks.append({"pos": Vector3i(x, 0, z), "type": ICE})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === DIRT SECTION ===
static func _dirt_section() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				blocks.append({"pos": Vector3i(x, 0, z), "type": DIRT})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks
