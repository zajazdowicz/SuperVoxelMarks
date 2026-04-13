extends Node
## API client for RC Trick Mania X backend.
## Autoload singleton — handles player registration, score submission, leaderboard, ghosts.

const API_BASE := "https://srv101355.seohost.com.pl/api/svmarks"
const AUTH_BASE := "https://srv101355.seohost.com.pl/api/auth"

var player_id := ""
var player_name := ""
var player_nationality := "PL"
var auth_token := ""

var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_load_player()


# === PLAYER ===

func _load_player() -> void:
	var path := "user://player.cfg"
	if FileAccess.file_exists(path):
		var cfg := ConfigFile.new()
		cfg.load(path)
		player_id = cfg.get_value("player", "id", "")
		player_name = cfg.get_value("player", "name", "")
		player_nationality = cfg.get_value("player", "nationality", "PL")
		auth_token = cfg.get_value("player", "auth_token", "")


func _save_player() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "id", player_id)
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "nationality", player_nationality)
	cfg.set_value("player", "auth_token", auth_token)
	cfg.save("user://player.cfg")


func is_registered() -> bool:
	return player_id != ""


func register(p_name: String, p_nationality: String, callback: Callable, p_password: String = "") -> void:
	if player_id == "":
		player_id = _generate_id()
	player_name = p_name
	player_nationality = p_nationality
	_save_player()

	var data := {
		"player_id": player_id,
		"name": player_name,
		"nationality": player_nationality,
	}
	if p_password != "":
		data["password"] = p_password

	var body := JSON.stringify(data)

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		if code == 200:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.get("login", false):
				# Reserved name login — switch to existing account
				player_id = str(json["id"])
				player_name = str(json["name"])
				auth_token = str(json.get("token", ""))
				if json.has("nationality"):
					player_nationality = str(json["nationality"])
				_save_player()
				print("API: Logged in as admin: %s (%s)" % [player_name, player_id])
			else:
				print("API: Player registered: %s" % player_name)
			callback.call(true)
		elif code == 403:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.get("error", "") == "reserved_name":
				# Name is reserved — need password
				print("API: Name reserved, password required")
				callback.call(false, "reserved")
			else:
				print("API: Registration forbidden: %d" % code)
				callback.call(false)
		else:
			print("API: Registration failed: %d" % code)
			callback.call(false)
		req.queue_free()
	)
	req.request(API_BASE + "/player", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _generate_id() -> String:
	var chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var id := ""
	for i in range(8):
		id += chars[randi() % chars.length()]
	return id


# === SCORES ===

func submit_score(track_id: int, lap_time_ms: int, ghost_frames: Array, callback: Callable) -> void:
	if not is_registered():
		callback.call(false, {})
		return

	# Compress ghost to base64
	var ghost_b64 := ""
	if not ghost_frames.is_empty():
		var ghost_bytes := _pack_ghost(ghost_frames)
		var compressed := ghost_bytes.compress(FileAccess.COMPRESSION_GZIP)
		ghost_b64 = Marshalls.raw_to_base64(compressed)

	var body := JSON.stringify({
		"player_id": player_id,
		"track_id": track_id,
		"lap_time_ms": lap_time_ms,
		"ghost_data": ghost_b64,
	})

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		var success: bool = code == 200
		var data: Dictionary = {}
		if success:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json:
				data = json
			print("API: Score submitted — rank #%s" % str(data.get("rank", "?")))
		else:
			print("API: Score submit failed: %d" % code)
		callback.call(success, data)
		req.queue_free()
	)
	req.request(API_BASE + "/score", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _pack_ghost(frames: Array) -> PackedByteArray:
	# Format v2: [frame_count:u16, per frame: t,px,py,pz,ry as float32 = 20 bytes]
	var buf := PackedByteArray()
	buf.resize(2 + frames.size() * 20)
	buf.encode_u16(0, frames.size())
	var offset := 2
	for f in frames:
		buf.encode_float(offset, f.get("t", 0.0)); offset += 4
		buf.encode_float(offset, f.get("px", 0.0)); offset += 4
		buf.encode_float(offset, f.get("py", 0.0)); offset += 4
		buf.encode_float(offset, f.get("pz", 0.0)); offset += 4
		buf.encode_float(offset, f.get("ry", 0.0)); offset += 4
	return buf


func _unpack_ghost(data: PackedByteArray) -> Array:
	if data.size() < 2:
		return []
	var count: int = data.decode_u16(0)
	var frames := []
	var offset := 2

	# Detect format: v2 = 20 bytes/frame (t,px,py,pz,ry), v1 = 24 bytes/frame (px,py,pz,rx,ry,rz)
	var expected_v2 := 2 + count * 20
	var expected_v1 := 2 + count * 24
	var is_v2 := absi(data.size() - expected_v2) < absi(data.size() - expected_v1)

	if is_v2:
		for i in range(count):
			if offset + 20 > data.size():
				break
			frames.append({
				"t": data.decode_float(offset),
				"px": data.decode_float(offset + 4),
				"py": data.decode_float(offset + 8),
				"pz": data.decode_float(offset + 12),
				"ry": data.decode_float(offset + 16),
			})
			offset += 20
	else:
		# Legacy v1: no time field, reconstruct from frame index
		for i in range(count):
			if offset + 24 > data.size():
				break
			frames.append({
				"t": float(i) * 0.05,
				"px": data.decode_float(offset),
				"py": data.decode_float(offset + 4),
				"pz": data.decode_float(offset + 8),
				"ry": data.decode_float(offset + 16),
			})
			offset += 24
	return frames


# === LEADERBOARD ===

func get_leaderboard(track_id: int, callback: Callable) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		var data: Dictionary = {}
		if code == 200:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json:
				data = json
		callback.call(data)
		req.queue_free()
	)
	req.request(API_BASE + "/leaderboard/%d" % track_id)


# === GHOSTS ===

func get_ghosts(track_id: int, callback: Callable) -> void:
	var url := API_BASE + "/ghosts/%d" % track_id
	if is_registered():
		url += "?player_id=%s" % player_id

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		var ghosts: Array = []
		if code == 200:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("ghosts"):
				for g in json.ghosts:
					var ghost_b64: String = g.get("ghost_data", "")
					if ghost_b64 != "":
						var compressed := Marshalls.base64_to_raw(ghost_b64)
						var decompressed := compressed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
						var frames := _unpack_ghost(decompressed)
						ghosts.append({
							"type": g.get("type", ""),
							"player_name": g.get("player_name", ""),
							"player_nationality": g.get("player_nationality", ""),
							"lap_time_ms": g.get("lap_time_ms", 0),
							"frames": frames,
						})
		callback.call(ghosts)
		req.queue_free()
	)
	req.request(url)


# === TRACKS ===

func publish_track(track_name: String, track_json: Array, author_time_ms: int, callback: Callable) -> void:
	if not is_registered():
		callback.call(false, {})
		return

	var body := JSON.stringify({
		"player_id": player_id,
		"name": track_name,
		"track_json": track_json,
		"author_time_ms": author_time_ms,
	})

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		var success: bool = code == 201
		var data: Dictionary = {}
		if success:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json:
				data = json
			print("API: Track published: %s (id=%s)" % [track_name, str(data.get("id", "?"))])
		callback.call(success, data)
		req.queue_free()
	)
	req.request(API_BASE + "/tracks", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func get_track_list(callback: Callable) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		var tracks: Array = []
		if code == 200:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json is Array:
				tracks = json
		callback.call(tracks)
		req.queue_free()
	)
	req.request(API_BASE + "/tracks")


# === AUTH / LINK CODE ===

func has_auth() -> bool:
	return auth_token != ""


func ensure_auth(callback: Callable) -> void:
	if has_auth():
		callback.call(true)
		return
	# Auto-register with password based on player_id
	var password := player_id  # simple: use player_id as password
	var body := JSON.stringify({
		"player_id": player_id,
		"name": player_name,
		"password": password,
		"nationality": player_nationality,
	})
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		if code == 201 or code == 200:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("token"):
				auth_token = json["token"]
				_save_player()
				callback.call(true)
				req.queue_free()
				return
		# If register fails (already registered), try login
		if code == 409:
			_login_for_token(password, callback)
			req.queue_free()
			return
		callback.call(false)
		req.queue_free()
	)
	req.request(AUTH_BASE + "/register", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _login_for_token(password: String, callback: Callable) -> void:
	var body := JSON.stringify({
		"player_id": player_id,
		"password": password,
	})
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		if code == 200:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("token"):
				auth_token = json["token"]
				_save_player()
				callback.call(true)
				req.queue_free()
				return
		callback.call(false)
		req.queue_free()
	)
	req.request(AUTH_BASE + "/login", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func generate_link_code(callback: Callable) -> void:
	if not has_auth():
		callback.call(false, "")
		return
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, headers, body_bytes):
		if code == 200:
			var json: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("code"):
				callback.call(true, json["code"])
				req.queue_free()
				return
		callback.call(false, "")
		req.queue_free()
	)
	req.request(AUTH_BASE + "/link-code", ["Content-Type: application/json", "Authorization: Bearer " + auth_token], HTTPClient.METHOD_POST, "{}")
