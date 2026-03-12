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
const WATER := 15
const COBBLESTONE := 16
const TURBO := 17      # stronger boost (x2.0)
const SLOWDOWN := 18   # speed trap

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
	"Petla",         # 19 — full 360° vertical loop (spans 2 cells)
	"(petla cell2)", # 20 — reserved (second cell occupied by piece 19)
	"Platforma",     # 21 — flat road at height with pillars underneath
	"Lacznik gora",  # 22 — smooth transition before ramp up (anti-lip)
	"Lacznik dol",   # 23 — smooth transition after ramp down (anti-lip)
	"Lagodny prawo", # 24 — gentle 90° turn right (large radius arc)
	"Lagodny lewo",  # 25 — gentle 90° turn left (large radius arc)
	"Esowka prawo",  # 26 — S-curve shifting road right
	"Esowka lewo",   # 27 — S-curve shifting road left
	"Banked prawo",  # 28 — banked turn 30° right
	"Banked lewo",   # 29 — banked turn 30° left
	"Rampa lagodna gora",  # 30 — half-height ramp up (h=3)
	"Rampa lagodna dol",   # 31 — half-height ramp down (h=3)
	"Most",                # 32 — bridge with pillars at ends only
	"Tunel",               # 33 — road with walls and roof
	"Rampa zakret prawo",  # 34 — ramp turn S→E, +6 height
	"Rampa zakret lewo",   # 35 — ramp turn S→W, +6 height
	"Piasek",              # 36 — sand section
	"Woda",                # 37 — shallow water section
	"Bruk",                # 38 — cobblestone section
	"Skok",                # 39 — jump pad (mini ramp)
	"Turbo",               # 40 — turbo boost (x2.0)
	"Spowolnienie",        # 41 — slowdown trap
]

const HALF_RAMP_HEIGHT := 3

static func get_ports(index: int) -> Array[Dictionary]:
	# Turns: S→E or S→W
	match index:
		1, 24, 28, 34: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "E", "dir": Vector2i(1, 0)}]
		2, 25, 29, 35: return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "W", "dir": Vector2i(-1, 0)}]
	# All other standard pieces: S→N
	if index >= 0 and index <= 41:
		return [{"side": "S", "dir": Vector2i(0, -1)}, {"side": "N", "dir": Vector2i(0, 1)}]
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
		19: return _vloop_full()
		20: return []  # marker only — piece 19 covers both cells
		21: return _platform()
		22: return _transition_up()
		23: return _transition_down()
		24: return _gentle_turn_right()
		25: return _gentle_turn_left()
		26: return _s_curve(2.0)
		27: return _s_curve(-2.0)
		28: return _banked_turn_right()
		29: return _banked_turn_left()
		30: return _ramp_generic(HALF_RAMP_HEIGHT, true)
		31: return _ramp_generic(HALF_RAMP_HEIGHT, false)
		32: return _bridge()
		33: return _tunnel()
		34: return _ramp_turn_clear(float(HI), float(LO), PI / 2.0, PI)
		35: return _ramp_turn_clear(float(LO), float(LO), 0.0, PI / 2.0)
		36: return _sand_section()
		37: return _water_section()
		38: return _cobblestone_section()
		39: return _jump_pad()
		40: return _turbo_pad()
		41: return _slowdown_section()
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
			# Road: clear to AIR so ConvexPolygon is sole collision.
			# Skip BOTH boundaries (z=LO and z=HI) to preserve neighbor voxels.
			if absi(x) <= ROAD_W:
				if z > LO and z < HI:
					for h in range(0, height + 1):
						blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
			elif absi(x) == ROAD_W + 1:
				# Walls: cap at surface height +1 on boundaries to avoid lip
				var wall_top := height + 3
				if z == LO or z == HI:
					wall_top = height + 1
				for h in range(0, wall_top):
					blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


# === RAMP DOWN ===
static func _ramp_down() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(SEGMENT_SIZE)
		var height := int((1.0 - progress) * float(RAMP_HEIGHT))
		for x in range(LO, HI + 1):
			# Road: clear to AIR so ConvexPolygon is sole collision.
			# Skip BOTH boundaries (z=LO and z=HI) to preserve neighbor voxels.
			if absi(x) <= ROAD_W:
				if z > LO and z < HI:
					for h in range(0, height + 1):
						blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
			elif absi(x) == ROAD_W + 1:
				# Walls: cap at surface height +1 on boundaries to avoid lip
				var wall_top := height + 3
				if z == LO or z == HI:
					wall_top = height + 1
				for h in range(0, wall_top):
					blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


static func _ramp_generic(ramp_h: int, is_up: bool) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(SEGMENT_SIZE)
		var height: int
		if is_up:
			height = int(progress * float(ramp_h))
		else:
			height = int((1.0 - progress) * float(ramp_h))
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				if z > LO and z < HI:
					for h in range(0, height + 1):
						blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
			elif absi(x) == ROAD_W + 1:
				var wall_top := height + 3
				if z == LO or z == HI:
					wall_top = height + 1
				for h in range(0, wall_top):
					blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


# === START / FINISH ===
# Checkerboard line at z=-1..0, arrow pointing north (driving direction).
static func _start_finish() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	# Arrow pattern: chevron pointing north at z=2..5
	# Shape:  z=5: x=0         (tip)
	#         z=4: x=-1..1
	#         z=3: x=-2..2
	#         z=2: x=-3..3     (base)
	var arrow := {}
	for az in range(2, 6):
		var width := 5 - az  # z=2→3, z=3→2, z=4→1, z=5→0
		for ax in range(-width, width + 1):
			arrow[Vector2i(ax, az)] = true

	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				if z >= -1 and z <= 0:
					var checker := (x + z) % 2 == 0
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB if checker else ASPHALT})
				elif arrow.has(Vector2i(x, z)):
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
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


# === VERTICAL LOOP: dual-lane circle, spans 2 grid cells ===
# Road widens for 2 lanes (offset ±5). Circle R=10, top at y=21.
# Wider clearing needed: x from -10 to +10 to fit both lanes.
# ConvexPolygon handles all collision — voxels cleared to AIR.
static func _vloop_full() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var loop_top := 24  # clearance height: 2*R + hw + margin = 2*10 + 4.5 + ~0
	var x_clear := ROAD_W + 6  # 10 — wide enough for both offset lanes
	# Spans 2 grid cells: z from LO to HI + SEGMENT_SIZE
	for z in range(LO, HI + SEGMENT_SIZE + 1):
		for x in range(-x_clear, x_clear + 1):
			# Keep ASPHALT at y=0 as base, clear AIR above for full loop
			blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			for h in range(1, loop_top):
				blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
	return blocks


# === PLATFORM: flat road with support pillars underneath ===
# When placed at base_height > 0, pillars extend downward via negative y offsets.
# In world space: voxel at (x, base_height + y_offset, z). Negative y_offset
# reaches below base_height toward ground level.
static func _platform() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				# Road surface
				if absi(x) == ROAD_W and z % 3 == 0:
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				# Barriers at road level
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
				# Support pillars downward (at segment edges + every 4 voxels)
				if z == LO or z == HI or z % 4 == 0:
					for h in range(1, RAMP_HEIGHT * 2 + 1):
						blocks.append({"pos": Vector3i(x, -h, z), "type": WALL})
	return blocks


static func _bridge() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				# Road surface
				if absi(x) == ROAD_W and z % 3 == 0:
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				# Barriers at road level
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
				# Pillars only at segment start and end (z=LO, z=HI)
				if z == LO or z == HI:
					for h in range(1, RAMP_HEIGHT * 2 + 1):
						blocks.append({"pos": Vector3i(x, -h, z), "type": WALL})
	return blocks


const TUNNEL_HEIGHT := 4  # inner clearance (road to ceiling)

static func _tunnel() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				# Road surface
				if absi(x) == ROAD_W and z % 3 == 0:
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
				# Roof
				blocks.append({"pos": Vector3i(x, TUNNEL_HEIGHT + 1, z), "type": WALL})
			elif absi(x) == ROAD_W + 1:
				# Side walls from floor to roof
				for h in range(0, TUNNEL_HEIGHT + 2):
					blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


# === TRANSITION UP: smooth entry to ramp (anti-lip) ===
# Collision handled by ramp_spawner. Voxels cleared to AIR.
# A short curved surface that gently lifts the car into the ramp slope.
const TRANSITION_HEIGHT := 2  # slight rise over the segment
static func _transition_up() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(SEGMENT_SIZE)
		var height := int(progress * float(TRANSITION_HEIGHT))
		for x in range(LO, HI + 1):
			# Skip HIGH end (z=HI), clear LOW end (z=LO)
			if absi(x) <= ROAD_W:
				if z < HI:
					for h in range(0, height + 1):
						blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
			elif absi(x) == ROAD_W + 1:
				for h in range(0, height + 3):
					blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


# === TRANSITION DOWN: smooth exit from ramp (anti-lip) ===
static func _transition_down() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(SEGMENT_SIZE)
		var height := int((1.0 - progress) * float(TRANSITION_HEIGHT))
		for x in range(LO, HI + 1):
			# Skip HIGH end (z=LO), clear LOW end (z=HI)
			if absi(x) <= ROAD_W:
				if z > LO:
					for h in range(0, height + 1):
						blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
			elif absi(x) == ROAD_W + 1:
				for h in range(0, height + 3):
					blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


# === GENTLE TURN RIGHT (S -> E): large radius arc ===
# Arc center at (HI, LO) = (6, -6), radius = HALF = 6.
# Road band: inner_r = 2, outer_r = 10. Angular range: PI/2 to PI.
static func _gentle_turn_right() -> Array[Dictionary]:
	return _gentle_turn(float(HI), float(LO), PI / 2.0, PI)


# === GENTLE TURN LEFT (S -> W): large radius arc, mirrored ===
# Arc center at (LO, LO) = (-6, -6), radius = HALF = 6.
# Road band: inner_r = 2, outer_r = 10. Angular range: 0 to PI/2.
static func _gentle_turn_left() -> Array[Dictionary]:
	return _gentle_turn(float(LO), float(LO), 0.0, PI / 2.0)


static func _gentle_turn(cx: float, cz: float, angle_min: float, angle_max: float) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var r := float(HALF)
	var inner_r := r - float(ROAD_W)   # 2.0
	var outer_r := r + float(ROAD_W)   # 10.0

	# Pre-compute road mask for wall adjacency check
	var road_mask := {}
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if _is_on_gentle_arc(float(x), float(z), cx, cz, inner_r, outer_r, angle_min, angle_max):
				road_mask[Vector2i(x, z)] = true

	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if road_mask.has(Vector2i(x, z)):
				# Curb at edges: check if near inner/outer radius
				var dx := float(x) + 0.5 - cx
				var dz := float(z) + 0.5 - cz
				var dist := sqrt(dx * dx + dz * dz)
				var near_edge := dist < inner_r + 1.0 or dist > outer_r - 1.0
				if near_edge and (x + z) % 3 == 0:
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			else:
				# Skip walls at grid boundaries — neighbor piece handles its own walls.
				# This prevents walls from one piece blocking the road of an adjacent piece.
				if x == LO or x == HI or z == LO or z == HI:
					continue
				# Wall if adjacent to road
				var is_wall := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if road_mask.has(Vector2i(x + d.x, z + d.y)):
						is_wall = true
						break
				if is_wall:
					blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
					blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


static func _is_on_gentle_arc(x: float, z: float, cx: float, cz: float,
		inner_r: float, outer_r: float, angle_min: float, angle_max: float) -> bool:
	var dx := x + 0.5 - cx
	var dz := z + 0.5 - cz
	var dist := sqrt(dx * dx + dz * dz)
	if dist < inner_r or dist > outer_r:
		return false
	var angle := atan2(dz, dx)
	if angle < 0.0:
		angle += 2.0 * PI
	return angle >= angle_min - 0.1 and angle <= angle_max + 0.1


static func _s_curve(shift: float) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	# Pre-compute road mask
	var road_mask := {}
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(HI - LO)
		var road_center := shift * (1.0 - cos(progress * PI)) / 2.0
		for x in range(LO, HI + 1):
			var dist := absf(float(x) + 0.5 - road_center)
			if dist <= float(ROAD_W) + 0.5:
				road_mask[Vector2i(x, z)] = true
	for z in range(LO, HI + 1):
		var progress := float(z - LO) / float(HI - LO)
		var road_center := shift * (1.0 - cos(progress * PI)) / 2.0
		for x in range(LO, HI + 1):
			if road_mask.has(Vector2i(x, z)):
				var dist := absf(float(x) + 0.5 - road_center)
				if dist >= float(ROAD_W) - 0.5:
					blocks.append({"pos": Vector3i(x, 0, z), "type": CURB})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			else:
				# Wall if adjacent to road (skip z boundaries only)
				if z > LO and z < HI:
					var is_wall := false
					for dx in [-1, 0, 1]:
						for dz in [-1, 0, 1]:
							if road_mask.has(Vector2i(x + dx, z + dz)):
								is_wall = true
								break
						if is_wall:
							break
					if is_wall:
						blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
						blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


const BANKED_ANGLE_DEG := 30.0

static func _banked_turn_right() -> Array[Dictionary]:
	return _banked_turn_clear(float(HI), float(LO), PI / 2.0, PI)

static func _banked_turn_left() -> Array[Dictionary]:
	return _banked_turn_clear(float(LO), float(LO), 0.0, PI / 2.0)

static func _banked_turn_clear(cx: float, cz: float, angle_min: float, angle_max: float) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var r := float(HALF)
	var inner_r := r - float(ROAD_W)       # 2.0 — exact road inner edge
	var outer_r := r + float(ROAD_W)       # 10.0 — exact road outer edge
	var bank_h := int(ceil((outer_r - inner_r) * sin(deg_to_rad(BANKED_ANGLE_DEG)))) + 2
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if _is_on_gentle_arc(float(x), float(z), cx, cz, inner_r, outer_r, angle_min, angle_max):
				for h in range(0, bank_h):
					blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
	return blocks


static func _ramp_turn_clear(cx: float, cz: float, angle_min: float, angle_max: float) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var r := float(HALF)
	var inner_r := r - float(ROAD_W)
	var outer_r := r + float(ROAD_W)
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if _is_on_gentle_arc(float(x), float(z), cx, cz, inner_r, outer_r, angle_min, angle_max):
				# Height depends on arc progress — compute angle of this voxel
				var dx := float(x) + 0.5 - cx
				var dz := float(z) + 0.5 - cz
				var angle := atan2(dz, dx)
				if angle < 0.0:
					angle += 2.0 * PI
				var progress := (angle - angle_min) / (angle_max - angle_min)
				progress = clampf(progress, 0.0, 1.0)
				var local_h := int(ceil(progress * float(RAMP_HEIGHT))) + 2
				for h in range(0, local_h):
					blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
	return blocks


# === SAND SECTION ===
static func _sand_section() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				blocks.append({"pos": Vector3i(x, 0, z), "type": SAND})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === WATER SECTION ===
static func _water_section() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WATER})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === COBBLESTONE SECTION ===
static func _cobblestone_section() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				blocks.append({"pos": Vector3i(x, 0, z), "type": COBBLESTONE})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === JUMP PAD: flat road with mini ramp at the end ===
# Collision for the ramp part handled by ramp_spawner.
const JUMP_HEIGHT := 3
static func _jump_pad() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				if z >= 0:
					# Ramp zone: clear to AIR for ConvexPolygon
					if z > 0 and z < HI:
						for h in range(0, JUMP_HEIGHT + 1):
							blocks.append({"pos": Vector3i(x, h, z), "type": AIR})
				else:
					# Flat road before the ramp
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
				if z >= 0:
					for h in range(2, JUMP_HEIGHT + 2):
						blocks.append({"pos": Vector3i(x, h, z), "type": WALL})
	return blocks


# === TURBO PAD (stronger boost) ===
static func _turbo_pad() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				if absi(x) <= 2:
					blocks.append({"pos": Vector3i(x, 0, z), "type": TURBO})
				else:
					blocks.append({"pos": Vector3i(x, 0, z), "type": ASPHALT})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks


# === SLOWDOWN SECTION ===
static func _slowdown_section() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for z in range(LO, HI + 1):
		for x in range(LO, HI + 1):
			if absi(x) <= ROAD_W:
				blocks.append({"pos": Vector3i(x, 0, z), "type": SLOWDOWN})
			elif absi(x) == ROAD_W + 1:
				blocks.append({"pos": Vector3i(x, 0, z), "type": WALL})
				blocks.append({"pos": Vector3i(x, 1, z), "type": WALL})
	return blocks
