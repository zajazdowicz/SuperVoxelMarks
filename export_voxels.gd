extends Node

## Attach to any Node in a scene, run the scene, it exports and quits.

func _ready() -> void:
	var result := {}

	for id in range(63):
		if id == 20:
			continue
		var blocks: Array[Dictionary] = TrackPieces.get_piece(id)
		if blocks.is_empty():
			continue

		var block_list := []
		for b in blocks:
			var p: Vector3i = b.pos
			block_list.append([p.x, p.y, p.z, int(b.type)])

		result[str(id)] = block_list

	var json_str := JSON.stringify(result)
	var file := FileAccess.open("res://pieces_voxels.json", FileAccess.WRITE)
	file.store_string(json_str)
	print("Exported %d pieces (%d bytes)" % [result.size(), json_str.length()])
	get_tree().quit()
