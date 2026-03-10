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
const WALL_RIDE := 14  # visual marker for wall ride surface

const ROAD_W := 4  # road -4..+4, walls at +-5
const WALL_RIDE_HEIGHT := 9  # height clearance for wall ride voxel clearing
const WALL_RIDE_BANK_DEG := 60.0  # bank angle in degrees
const PIECE_NAMES := [
	"Prosta",        # 0
	"Zakret prawo",  # 1
	"Zakret lewo",   # 2
	"Rampa gora",    # 3
	"Rampa dol",     # 4
	"Start/Meta",    # 5
	"Szykana",       # 6
	"Boost",         # 7
	"Checkpoint",    # 8
	"Lod",           # 9
	"Ziemia",        # 10
	"Meta (Sprint)", # 11
	"Wall Ride wejscie",  # 12
	"Wall Ride prosta",   # 13
	"Wall Ride wyjscie",  # 14
	"Loop wjazd",    # 15 — 0° → 90°
	"Loop gora",     # 16 — 90° → 180°
	"Loop zjazd",    # 17 — 180° → 270°
	"Loop wyjazd",   # 18 — 270° → 360°
]

static func get_ports(index: int) -> Array[Dictionary]:
	# All standard pieces: S→N
	if index >= 0 and index <= 18 and index != 1 and index != 2:
		return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
	match index:
		1: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "E", "dir": Vector2i(1, 0)}]
		2: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "W", "dir": Vector2i(-1, 0)}]
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
		11: return _finish_line()
		12: return _wall_ride_entry()
		13: return _wall_ride_straight()
		14: return _wall_ride_exit()
		15, 16, 17, 18: return _loop_quarter(index)
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


# === FINISH LINE (Sprint mode) ===
static func _finish_line() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				if z >= -1 and z <= 0:
					var checker := (x + z) % 2 == 0
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB if checker else ASPHALT})
				elif z >= 1 and z <= 2:
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
				if z >= -1 and z <= 0:
					blocks.append({"pos": Vector3i(x, 2, z), "type": WALL})
					blocks.append({"pos": Vector3i(x, 3, z), "type": WALL})
	return blocks


# === WALL RIDE ENTRY (flat → banked 60°) ===
# Collision handled by ramp_spawner. Voxels cleared to AIR.
# At 60° bank, right edge rises ~8 units, so clear up to WALL_RIDE_HEIGHT + 2.
static func _wall_ride_entry() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W + 1:
				for h in range(0, WALL_RIDE_HEIGHT + 3):
					blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
	return blocks


# === WALL RIDE STRAIGHT (tilted surface, car drives on wall) ===
static func _wall_ride_straight() -> Array[Dictionary]:
	return _wall_ride_entry()


# === WALL RIDE EXIT (tilted → flat) ===
static func _wall_ride_exit() -> Array[Dictionary]:
	return _wall_ride_entry()


# === LOOP QUARTER: barrel roll split into 4 pieces (90° each) ===
# hw = ROAD_W + 0.5 = 4.5. Max height at 180° = ground + 2*hw = 10.
# Quarters 1,2 (90°-270°) need more clearance than 0,3.
static func _loop_quarter(piece_id: int) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var quarter := piece_id - 15  # 0..3
	# Quarters 0,3 (entry/exit): max ~10. Quarters 1,2 (top): max ~12.
	var total_h := 12 if (quarter == 1 or quarter == 2) else 11
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W + 1:
				for h in range(0, total_h):
					blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
	return blocks
