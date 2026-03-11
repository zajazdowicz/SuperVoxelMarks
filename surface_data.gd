class_name SurfaceData
## Surface properties per voxel block type.
## Affects car grip, speed and friction.

# {grip, speed_mult, friction}
const SURFACES := {
	TrackPieces.ASPHALT:      {"grip": 1.0,  "speed_mult": 1.0, "friction": 8.0, "is_road": true},
	TrackPieces.CURB:         {"grip": 0.9,  "speed_mult": 1.0, "friction": 8.0, "is_road": true},
	TrackPieces.GRASS:        {"grip": 0.5,  "speed_mult": 0.7, "friction": 12.0},
	TrackPieces.SAND:         {"grip": 0.4,  "speed_mult": 0.6, "friction": 15.0, "is_road": true},
	TrackPieces.BOOST:        {"grip": 1.0,  "speed_mult": 1.0, "friction": 4.0, "is_boost": true, "is_road": true},
	TrackPieces.ICE:          {"grip": 0.15, "speed_mult": 1.0, "friction": 2.0, "is_road": true},
	TrackPieces.DIRT:         {"grip": 0.7,  "speed_mult": 0.8, "friction": 10.0, "is_road": true},
	TrackPieces.WATER:        {"grip": 0.5,  "speed_mult": 0.5, "friction": 12.0, "is_road": true},
	TrackPieces.COBBLESTONE:  {"grip": 0.8,  "speed_mult": 0.85, "friction": 9.0, "is_road": true},
	TrackPieces.TURBO:        {"grip": 1.0,  "speed_mult": 1.0, "friction": 4.0, "is_boost": true, "boost_mult": 2.0, "boost_dur": 1.5, "is_road": true},
	TrackPieces.SLOWDOWN:     {"grip": 0.8,  "speed_mult": 0.4, "friction": 20.0, "is_road": true},
}

const DEFAULT := {"grip": 1.0, "speed_mult": 1.0, "friction": 8.0, "is_road": true}


static func get_surface(block_type: int) -> Dictionary:
	if SURFACES.has(block_type):
		return SURFACES[block_type]
	return DEFAULT
