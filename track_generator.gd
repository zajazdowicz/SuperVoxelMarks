class_name TrackGenerator
## Generates random closed-loop tracks using the grid piece system.
## Supports seed-based deterministic generation for daily tracks.

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
const P_GENTLE_R := 24
const P_GENTLE_L := 25
const P_HALF_RAMP_UP := 30
const P_HALF_RAMP_DOWN := 31
const P_BRIDGE := 32
const P_TUNNEL := 33
const P_SAND := 36
const P_COBBLESTONE := 38
const P_TURBO := 40
const P_SLOWDOWN := 41

# 0=N(+Z), 1=E(+X), 2=S(-Z), 3=W(-X)
static var DIR_VECS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

const MIN_ELEVATED := 2   # minimum flat pieces before coming down
const MAX_ELEVATED := 5   # maximum flat pieces before forcing down

enum Difficulty { EASY, MEDIUM, HARD }


static func generate(length: int = 20, track_name: String = "generated", seed_val: int = 0) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	if seed_val == 0:
		seed_val = randi()
	rng.seed = seed_val

	for _attempt in range(20):
		var result := _try_generate(length, Difficulty.MEDIUM, rng)
		if not result.is_empty():
			TrackData.save_track(track_name, result)
			TrackData.current_track = track_name
			return result
	var fallback := _generate_oval()
	TrackData.save_track(track_name, fallback)
	TrackData.current_track = track_name
	return fallback


static func generate_daily(date_string: String, track_name: String = "daily") -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = date_string.hash()
	var length: int = 18 + (rng.randi() % 11)

	for _attempt in range(25):
		var result := _try_generate(length, Difficulty.MEDIUM, rng)
		if not result.is_empty():
			TrackData.save_track(track_name, result)
			TrackData.current_track = track_name
			return result
	var fallback := _generate_oval()
	TrackData.save_track(track_name, fallback)
	TrackData.current_track = track_name
	return fallback


static func _try_generate(length: int, difficulty: Difficulty, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	var occupied := {}
	var pos := Vector2i(0, 0)
	var dir := 0
	var height := 0
	var elevated_count := 0    # how many pieces placed since going up
	var straights_in_row := 0
	var has_checkpoint := false

	# Place start
	occupied[pos] = true
	pieces.append(_make(pos, P_START, dir, 0))
	pos += DIR_VECS[dir]

	var target := length - 1
	var placed := 0

	while placed < target:
		# --- ELEVATED: force down after enough flat pieces ---
		if height > 0:
			elevated_count += 1

			# Must come down before closing
			var must_descend := elevated_count > MAX_ELEVATED or placed >= target - 6
			var can_descend := elevated_count >= MIN_ELEVATED

			if must_descend or (can_descend and rng.randf() < 0.35):
				# Come down
				if height >= TrackPieces.RAMP_HEIGHT:
					pieces.append(_make(pos, P_RAMP_DOWN, dir, height - TrackPieces.RAMP_HEIGHT))
					height -= TrackPieces.RAMP_HEIGHT
				else:
					pieces.append(_make(pos, P_HALF_RAMP_DOWN, dir, maxi(0, height - TrackPieces.HALF_RAMP_HEIGHT)))
					height = maxi(0, height - TrackPieces.HALF_RAMP_HEIGHT)
				occupied[pos] = true
				pos += DIR_VECS[dir]
				placed += 1
				if height == 0:
					elevated_count = 0
				continue

			# Stay elevated: place flat piece
			var check := pos + DIR_VECS[dir]
			if occupied.has(check):
				# Blocked while elevated — must descend immediately
				if height >= TrackPieces.RAMP_HEIGHT:
					pieces.append(_make(pos, P_RAMP_DOWN, dir, height - TrackPieces.RAMP_HEIGHT))
					height -= TrackPieces.RAMP_HEIGHT
				else:
					pieces.append(_make(pos, P_HALF_RAMP_DOWN, dir, maxi(0, height - TrackPieces.HALF_RAMP_HEIGHT)))
					height = maxi(0, height - TrackPieces.HALF_RAMP_HEIGHT)
				occupied[pos] = true
				pos += DIR_VECS[dir]
				placed += 1
				if height == 0:
					elevated_count = 0
				continue

			# Pick elevated piece
			var r := rng.randf()
			var elev_piece: int
			if r < 0.15:
				elev_piece = P_BOOST
			elif r < 0.25:
				elev_piece = P_BRIDGE
			elif r < 0.30:
				elev_piece = P_TUNNEL
			else:
				elev_piece = P_STRAIGHT
			pieces.append(_make(pos, elev_piece, dir, height))
			occupied[pos] = true
			pos += DIR_VECS[dir]
			placed += 1
			continue

		# --- GROUND LEVEL ---

		# Near end: try to close loop
		if placed >= target - 8:
			var closing := _try_close(pos, dir, Vector2i(0, 0), occupied)
			if not closing.is_empty():
				pieces.append_array(closing)
				return pieces

		# Force checkpoint if none yet and past piece 3
		if not has_checkpoint and placed >= 3:
			var check := pos + DIR_VECS[dir]
			if not occupied.has(check):
				pieces.append(_make(pos, P_CHECKPOINT, dir, 0))
				occupied[pos] = true
				pos += DIR_VECS[dir]
				placed += 1
				has_checkpoint = true
				straights_in_row = 0
				continue

		# Ramp chance (not near end, not too many in a row)
		if not (straights_in_row >= 4) and placed < target - 10 and rng.randf() < 0.08:
			var check := pos + DIR_VECS[dir]
			var check2 := check + DIR_VECS[dir]
			if not occupied.has(check) and not occupied.has(check2):
				var use_half := rng.randf() < 0.4
				var ramp_piece: int = P_HALF_RAMP_UP if use_half else P_RAMP_UP
				var ramp_h: int = TrackPieces.HALF_RAMP_HEIGHT if use_half else TrackPieces.RAMP_HEIGHT
				pieces.append(_make(pos, ramp_piece, dir, 0))
				occupied[pos] = true
				height += ramp_h
				elevated_count = 0
				pos += DIR_VECS[dir]
				placed += 1
				straights_in_row = 0
				continue

		# Turn or straight
		var force_turn := straights_in_row >= 3
		var turn_prob: float = 0.90 if force_turn else 0.40
		var roll := rng.randf()

		if roll < turn_prob:
			# Try turn
			var use_gentle := rng.randf() < 0.3
			var go_right := rng.randf() < 0.5
			var turned := false

			for attempt in range(2):
				var try_right: bool = go_right if attempt == 0 else not go_right
				var td: int = 1 if try_right else 3
				var nd: int = (dir + td) % 4
				var check := pos + DIR_VECS[nd]
				if not occupied.has(check):
					var p: int
					if try_right:
						p = P_GENTLE_R if use_gentle else P_TURN_R
					else:
						p = P_GENTLE_L if use_gentle else P_TURN_L
					pieces.append(_make(pos, p, dir, 0))
					occupied[pos] = true
					dir = nd
					pos += DIR_VECS[dir]
					placed += 1
					straights_in_row = 0
					turned = true
					break

			if not turned:
				# Both turns blocked — try straight
				var check := pos + DIR_VECS[dir]
				if occupied.has(check):
					return []  # stuck
				var sp := _pick_straight(difficulty, rng)
				pieces.append(_make(pos, sp, dir, 0))
				occupied[pos] = true
				pos += DIR_VECS[dir]
				placed += 1
				straights_in_row += 1
			continue

		# Straight with variety
		var check := pos + DIR_VECS[dir]
		if occupied.has(check):
			# Blocked — try any turn
			var escaped := false
			for td: int in [1, 3]:
				var nd: int = (dir + td) % 4
				var tc := pos + DIR_VECS[nd]
				if not occupied.has(tc):
					var p := P_TURN_R if td == 1 else P_TURN_L
					pieces.append(_make(pos, p, dir, 0))
					occupied[pos] = true
					dir = nd
					pos += DIR_VECS[dir]
					placed += 1
					straights_in_row = 0
					escaped = true
					break
			if not escaped:
				return []  # completely stuck
			continue

		var sp := _pick_straight(difficulty, rng)
		# Periodic checkpoints
		if sp == P_STRAIGHT and placed > 0 and placed % 5 == 0:
			sp = P_CHECKPOINT
			has_checkpoint = true
		pieces.append(_make(pos, sp, dir, 0))
		occupied[pos] = true
		pos += DIR_VECS[dir]
		placed += 1
		straights_in_row += 1

	return []  # couldn't close


static func _pick_straight(difficulty: Difficulty, rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	match difficulty:
		Difficulty.EASY:
			if r < 0.70: return P_STRAIGHT
			if r < 0.85: return P_BOOST
			return P_COBBLESTONE
		Difficulty.MEDIUM:
			if r < 0.45: return P_STRAIGHT
			if r < 0.55: return P_CHICANE
			if r < 0.65: return P_BOOST
			if r < 0.72: return P_ICE
			if r < 0.79: return P_DIRT
			if r < 0.86: return P_COBBLESTONE
			return P_TURBO
		_:
			if r < 0.25: return P_STRAIGHT
			if r < 0.35: return P_ICE
			if r < 0.45: return P_DIRT
			if r < 0.55: return P_SAND
			if r < 0.65: return P_TURBO
			if r < 0.75: return P_SLOWDOWN
			return P_BOOST
	return P_STRAIGHT


static func _try_close(pos: Vector2i, dir: int, start: Vector2i, occupied: Dictionary) -> Array[Dictionary]:
	# Path back to start on flat ground. Entry from south = dir 0.
	var result: Array[Dictionary] = []
	var cur := pos
	var cur_dir := dir
	var visited := {}

	for _step in range(14):
		visited[cur] = true

		# Are we one step south of start, heading north?
		if cur + DIR_VECS[cur_dir] == start and cur_dir == 0:
			result.append(_make(cur, P_STRAIGHT, cur_dir, 0))
			return result

		var target := start - DIR_VECS[0]  # one cell south of start
		var diff := target - cur

		# At target, face north
		if diff == Vector2i.ZERO:
			if cur_dir == 0:
				result.append(_make(cur, P_STRAIGHT, 0, 0))
				return result
			var td := _turn_delta(cur_dir, 0)
			var piece := P_TURN_R if td == 1 else P_TURN_L
			result.append(_make(cur, piece, cur_dir, 0))
			cur_dir = (cur_dir + td) % 4
			cur += DIR_VECS[cur_dir]
			continue

		# Best free direction toward target
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
			return []

		if best_dir == cur_dir:
			result.append(_make(cur, P_STRAIGHT, cur_dir, 0))
		else:
			var td := _turn_delta(cur_dir, best_dir)
			if td == 1 or td == 3:
				result.append(_make(cur, P_TURN_R if td == 1 else P_TURN_L, cur_dir, 0))
				cur_dir = best_dir
			else:
				# 180° — two right turns
				result.append(_make(cur, P_TURN_R, cur_dir, 0))
				cur_dir = (cur_dir + 1) % 4
				cur += DIR_VECS[cur_dir]
				visited[cur] = true
				var td2 := _turn_delta(cur_dir, best_dir)
				result.append(_make(cur, P_TURN_R if td2 == 1 else P_TURN_L, cur_dir, 0))
				cur_dir = best_dir

		cur += DIR_VECS[cur_dir]

	return []


static func _turn_delta(from: int, to: int) -> int:
	return (to - from + 4) % 4


static func _make(grid: Vector2i, piece: int, dir: int, height: int) -> Dictionary:
	return {"grid": grid, "piece": piece, "rotation": dir, "base_height": height}


static func _generate_oval() -> Array[Dictionary]:
	# Rectangular loop: Start at (0,0) facing N.
	# N leg (3) + turn E + E leg (2) + turn S + S leg (3) + turn W + W leg (2) + turn N → back
	# Grid trace:
	#   Start(0,0) → N: (0,1)(0,2)(0,3) → TurnR(0,4) → E: (1,4)(2,4) → TurnR(3,4)
	#   → S: (3,3)(3,2)(3,1) → TurnR(3,0) → W: (2,0)(1,0) → TurnR(0,0)... NO! overlaps start
	# Fix: add extra straight before last turn so it ends at (0,-1) heading N into start
	# Adjusted: W leg goes to (1,0) then turn at (1,0) → N at (1,-1) → straight to... no.
	#
	# Simplest fix: asymmetric — make side 3 one cell longer to avoid (0,0)
	# Start(0,0)→N leg 4→TurnR(0,4)→E leg 3→TurnR(3,4)→S leg 4→TurnR(3,0)→W leg 2→last cell (1,0)
	# Nope, still doesn't close.
	#
	# Let's just hardcode a known-good loop:
	var pieces: Array[Dictionary] = []
	# Trace: Start(0,0)→N3→TurnR(0,4)→E3→TurnR(4,4)→S5→TurnR(4,-2)→W4→TurnR(0,-2)→N1(0,-1)
	var pos := Vector2i(0, 0)
	var dir := 0

	pieces.append(_make(pos, P_START, dir, 0))
	pos += DIR_VECS[dir]  # (0,1)

	# N: 3 straights (0,1)(0,2)(0,3) then turn at (0,4)
	pieces.append(_make(pos, P_CHECKPOINT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_TURN_R, dir, 0))
	dir = 1; pos += DIR_VECS[dir]  # (1,4)

	# E: 3 straights (1,4)(2,4)(3,4) then turn at (4,4)
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_BOOST, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_TURN_R, dir, 0))
	dir = 2; pos += DIR_VECS[dir]  # (4,3)

	# S: 5 straights (4,3)(4,2)(4,1)(4,0)(4,-1) then turn at (4,-2)
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_TURN_R, dir, 0))
	dir = 3; pos += DIR_VECS[dir]  # (3,-2)

	# W: 3 straights (3,-2)(2,-2)(1,-2) then turn at (0,-2)
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_TURBO, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_STRAIGHT, dir, 0)); pos += DIR_VECS[dir]
	pieces.append(_make(pos, P_TURN_R, dir, 0))
	dir = 0; pos += DIR_VECS[dir]  # (0,-1)

	# N: final straight at (0,-1) heading N into start (0,0)
	pieces.append(_make(pos, P_STRAIGHT, dir, 0))

	return pieces


# === PRESETS ===

static func generate_oval(track_name: String = "owal") -> Array[Dictionary]:
	var result := _generate_oval()
	TrackData.save_track(track_name, result)
	TrackData.current_track = track_name
	return result
