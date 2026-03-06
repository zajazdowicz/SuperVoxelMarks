class_name SurfaceData
## Surface properties per voxel block type.
## Affects car grip, speed and friction.

# {grip, speed_mult, friction}
const SURFACES := {
	TrackPieces.ASPHALT:      {"grip": 1.0,  "speed_mult": 1.0, "friction": 8.0},
	TrackPieces.CURB:         {"grip": 0.9,  "speed_mult": 1.0, "friction": 8.0},
	TrackPieces.GRASS:        {"grip": 0.5,  "speed_mult": 0.7, "friction": 12.0},
	TrackPieces.SAND:         {"grip": 0.4,  "speed_mult": 0.6, "friction": 15.0},
	TrackPieces.BOOST:        {"grip": 1.0,  "speed_mult": 1.0, "friction": 4.0, "is_boost": true},
	TrackPieces.ICE:          {"grip": 0.15, "speed_mult": 1.0, "friction": 2.0},
	TrackPieces.DIRT:         {"grip": 0.7,  "speed_mult": 0.8, "friction": 10.0},
}

const DEFAULT := {"grip": 1.0, "speed_mult": 1.0, "friction": 8.0}


static func get_surface(block_type: int) -> Dictionary:
	if SURFACES.has(block_type):
		return SURFACES[block_type]
	return DEFAULT
