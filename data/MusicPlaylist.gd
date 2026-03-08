extends Resource
class_name MusicPlaylist
## Holds a set of music tracks with optional weights and rules.

@export var tracks: Array[AudioStream] = []
@export var weights: Array[float] = [] # Optional; same length as tracks, or empty to treat all equal
@export var main_theme: AudioStream
@export var avoid_immediate_repeat: bool = true
## Tracks that require low sanity (≤ 60) to play. Indices of tracks in the tracks array.
@export var low_sanity_tracks: Array[int] = []

## Pick a random track index, optionally avoiding the last index.
## @param last_index: Previously played track index to avoid
## @param current_sanity: Current player sanity (0-100)
## @return: Selected track index
func pick_random_index(last_index: int, current_sanity: int = 100) -> int:
	var count: int = tracks.size()
	if count == 0:
		return -1

	# Validate weights
	var use_weights: bool = weights.size() == count
	var total: float = 0.0
	if use_weights:
		for i in weights.size():
			if weights[i] < 0.0:
				weights[i] = 0.0
			total += weights[i]
		if total <= 0.0:
			use_weights = false # fallback to uniform

	# Build candidate list, filtering by sanity and avoiding repeat
	var candidates: Array[int] = []
	for i in count:
		if avoid_immediate_repeat and i == last_index and count > 1:
			continue
		# Filter out low sanity tracks if sanity is above threshold
		if current_sanity > GameConstants.SANITY_THRESHOLD_MEDIUM and low_sanity_tracks.has(i):
			continue
		candidates.append(i)
	
	# Safety check: if no candidates available (all filtered), return -1
	if candidates.is_empty():
		return -1

	# Uniform selection
	if not use_weights:
		var idx: int = randi() % candidates.size()
		return candidates[idx]

	# Weighted selection (re-normalized over candidates)
	var ctotal: float = 0.0
	var cweights: Array[float] = []
	for i in candidates.size():
		var track_idx: int = candidates[i]
		var w: float = weights[track_idx]
		ctotal += w
		cweights.append(w)

	if ctotal <= 0.0:
		var uidx: int = randi() % candidates.size()
		return candidates[uidx]

	var roll: float = randf() * ctotal
	var accum: float = 0.0
	for i in candidates.size():
		accum += cweights[i]
		if roll <= accum:
			return candidates[i]

	return candidates.back()
