class_name TrackGenerator
## Generates random closed-loop tracks using the grid piece system.

const P_STRAIGHT := 0
const P_TURN_R := 1
const P_TURN_L := 2
const P_RAMP_UP := 3
const P_RAMP_DOWN := 4
const P_START := 5
const P_CHICANE := 6
const P_BOOST := 7
const P_CHECKPOINT := 8
const P_ICE := 9
const P_DIRT := 10

# 0=N(+Z), 1=E(+X), 2=S(-Z), 3=W(-X)
static var DIR_VECS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

const VARIETY_PIECES := [P_STRAIGHT, P_STRAIGHT, P_CHICANE, P_BOOST, P_ICE, P_DIRT]


static func generate(length: int = 20, track_name: String = "generated") -> Array[Dictionary]:
	# Try multiple times to get a closed loop
	for _attempt in range(10):
		var result := _try_generate(length)
		if not result.is_empty():
			TrackData.save_track(track_name, result)
			TrackData.current_track = track_name
			return result
	# Fallback: simple oval
	var fallback := _generate_oval()
	TrackData.save_track(track_name, fallback)
	TrackData.current_track = track_name
	return fallback


static func _try_generate(length: int) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	var occupied := {}
	var pos := Vector2i(0, 0)
	var dir := 0  # facing North
	var height := 0

	# Place start
	occupied[pos] = true
	pieces.append(_make(pos, P_START, dir, height))
	pos += DIR_VECS[dir]

	# Build middle section
	var target := length - 1
	var placed := 0
	var ramp_debt := 0  # >0 means we need to come down

	while placed < target:
		# Must come down from ramp before turning
		if ramp_debt > 0:
			pieces.append(_make(pos, P_RAMP_DOWN, dir, height))
			occupied[pos] = true
			height = maxi(0, height - TrackPieces.RAMP_HEIGHT)
			ramp_debt -= 1
			pos += DIR_VECS[dir]
			placed += 1
			continue

		# Near end: try to close loop
		if placed >= target - 8:
			var closing := _try_close(pos, dir, Vector2i(0, 0), occupied, height)
			if not closing.is_empty():
				pieces.append_array(closing)
				return pieces

		# Pick next piece
		var action := _pick_piece(pos, dir, occupied, placed, target, height)
		if action.is_empty():
			return []  # stuck, retry

		var piece_id: int = action.piece
		var new_dir: int = action.dir

		# Checkpoint every ~6 pieces
		if piece_id == P_STRAIGHT and placed > 0 and placed % 6 == 0 and height == 0:
			piece_id = P_CHECKPOINT

		# Ramp tracking
		if piece_id == P_RAMP_UP:
			height += TrackPieces.RAMP_HEIGHT
			ramp_debt += 1

		pieces.append(_make(pos, piece_id, dir if piece_id <= P_STRAIGHT else (dir if piece_id >= P_RAMP_UP else dir), height if piece_id != P_RAMP_UP else height - TrackPieces.RAMP_HEIGHT))

		# Fix: ramp_up base_height is before going up
		if piece_id == P_RAMP_UP:
			pieces[-1]["base_height"] = height - TrackPieces.RAMP_HEIGHT

		occupied[pos] = true
		dir = new_dir
		pos += DIR_VECS[dir]
		placed += 1

	return []  # couldn't close


static func _pick_piece(pos: Vector2i, dir: int, occupied: Dictionary, placed: int, total: int, height: int) -> Dictionary:
	var check: Vector2i

	if height > 0:
		check = pos + DIR_VECS[dir]
		if not occupied.has(check):
			return {"piece": VARIETY_PIECES[randi() % VARIETY_PIECES.size()], "dir": dir}
		return {}

	# Ramp chance (flat only, not near end)
	if randf() < 0.06 and placed < total - 6:
		check = pos + DIR_VECS[dir]
		if not occupied.has(check) and not occupied.has(check + DIR_VECS[dir]):
			return {"piece": P_RAMP_UP, "dir": dir}

	var roll := randf()
	if roll < 0.25:
		var rd := (dir + 1) % 4
		check = pos + DIR_VECS[rd]
		if not occupied.has(check):
			return {"piece": P_TURN_R, "dir": rd}
	elif roll < 0.50:
		var ld := (dir + 3) % 4
		check = pos + DIR_VECS[ld]
		if not occupied.has(check):
			return {"piece": P_TURN_L, "dir": ld}

	# Straight
	check = pos + DIR_VECS[dir]
	if not occupied.has(check):
		return {"piece": VARIETY_PIECES[randi() % VARIETY_PIECES.size()], "dir": dir}

	# Blocked ahead, try any turn
	for td: int in [1, 3]:
		var nd: int = (dir + td) % 4
		check = pos + DIR_VECS[nd]
		if not occupied.has(check):
			return {"piece": P_TURN_R if td == 1 else P_TURN_L, "dir": nd}

	return {}  # completely stuck


static func _try_close(pos: Vector2i, dir: int, start: Vector2i, occupied: Dictionary, height: int) -> Array[Dictionary]:
	# BFS-like approach to find path back to start (entering from south = dir 0)
	# Simple: try direct routing with max ~8 pieces
	var result: Array[Dictionary] = []
	var cur := pos
	var cur_dir := dir
	var cur_h := height
	var visited := {}

	for _step in range(12):
		visited[cur] = true

		# Come down first
		if cur_h > 0:
			result.append(_make(cur, P_RAMP_DOWN, cur_dir, maxi(0, cur_h - TrackPieces.RAMP_HEIGHT)))
			cur_h = maxi(0, cur_h - TrackPieces.RAMP_HEIGHT)
			cur += DIR_VECS[cur_dir]
			continue

		# Check: are we one step south of start, heading north?
		if cur + DIR_VECS[cur_dir] == start and cur_dir == 0:
			result.append(_make(cur, P_STRAIGHT, cur_dir, 0))
			return result

		# Find which direction gets us closer to one-south-of-start heading north
		var target := start - DIR_VECS[0]  # one south of start
		var diff := target - cur

		# Already at target, need to face north
		if diff == Vector2i.ZERO:
			if cur_dir == 0:
				result.append(_make(cur, P_STRAIGHT, 0, 0))
				return result
			# Turn toward north
			var td := _turn_delta(cur_dir, 0)
			var piece := P_TURN_R if td == 1 else P_TURN_L
			result.append(_make(cur, piece, cur_dir, 0))
			cur_dir = (cur_dir + td) % 4
			cur += DIR_VECS[cur_dir]
			continue

		# Pick best free direction toward target
		var best_dir := -1
		var best_dist := 999.0
		for d in range(4):
			var npos: Vector2i = cur + DIR_VECS[d]
			if visited.has(npos) or (occupied.has(npos) and npos != start):
				continue
			var dist := Vector2(target - npos).length()
			if dist < best_dist:
				best_dist = dist
				best_dir = d

		if best_dir < 0:
			return []  # can't close

		if best_dir == cur_dir:
			result.append(_make(cur, P_STRAIGHT, cur_dir, 0))
		else:
			var td := _turn_delta(cur_dir, best_dir)
			if td == 1 or td == 3:
				var piece := P_TURN_R if td == 1 else P_TURN_L
				result.append(_make(cur, piece, cur_dir, 0))
				cur_dir = best_dir
			else:
				# 180 degree - do two rights
				var piece := P_TURN_R
				result.append(_make(cur, piece, cur_dir, 0))
				cur_dir = (cur_dir + 1) % 4
				cur += DIR_VECS[cur_dir]
				visited[cur] = true
				# Check if new direction works
				var td2 := _turn_delta(cur_dir, best_dir)
				if td2 == 1:
					result.append(_make(cur, P_TURN_R, cur_dir, 0))
				else:
					result.append(_make(cur, P_TURN_L, cur_dir, 0))
				cur_dir = best_dir

		cur += DIR_VECS[cur_dir]

	return []  # couldn't close in time


static func _turn_delta(from: int, to: int) -> int:
	return (to - from + 4) % 4


static func _make(grid: Vector2i, piece: int, dir: int, height: int) -> Dictionary:
	return {"grid": grid, "piece": piece, "rotation": dir, "base_height": height}


static func _generate_oval() -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	# Simple: Start, 3 straights, right turn, 3 straights, right turn, 3 straights, right turn, 3 straights, right turn → closed
	var pos := Vector2i(0, 0)
	var dir := 0

	pieces.append(_make(pos, P_START, dir, 0))
	pos += DIR_VECS[dir]

	for side in range(4):
		var leg_len := 3 if side % 2 == 0 else 2
		for _i in range(leg_len):
			var p := P_BOOST if _i == 1 and side == 2 else P_STRAIGHT
			pieces.append(_make(pos, p, dir, 0))
			pos += DIR_VECS[dir]
		if side < 3:
			pieces.append(_make(pos, P_TURN_R, dir, 0))
			dir = (dir + 1) % 4
			pos += DIR_VECS[dir]
		else:
			# Last turn back to start
			pieces.append(_make(pos, P_TURN_R, dir, 0))
			dir = (dir + 1) % 4
			pos += DIR_VECS[dir]
			# Final straight to close
			pieces.append(_make(pos, P_STRAIGHT, dir, 0))

	return pieces
