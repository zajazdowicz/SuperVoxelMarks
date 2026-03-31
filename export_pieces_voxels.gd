@tool
extends EditorScript

## Run from Editor > Script > Run to export all piece voxel data to pieces_voxels.json

func _run() -> void:
	var result := {}

	for id in range(63):
		if id == 20:
			continue  # marker only
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
	print("Exported %d pieces to pieces_voxels.json" % result.size())
