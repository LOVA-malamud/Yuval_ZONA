class_name DeploymentPolicy
extends RefCounted
## Team-wide rolling history includes manual orders and emergency deployments.
var window_size: int = 30
var tolerance: int = 2
var histories: Dictionary = {}

func counts(team_id: int) -> Array[int]:
	var result: Array[int] = [0, 0, 0]
	for lane in histories.get(team_id, []):
		result[lane] += 1
	return result

func choose_lane(team_id: int, random: RandomNumberGenerator) -> int:
	var totals := counts(team_id)
	var history: Array = histories.get(team_id, [])
	if history.size() >= maxi(1, window_size):
		totals[int(history[0])] -= 1
	var minimum: int = mini(totals[0], mini(totals[1], totals[2]))
	var candidates: Array[int] = []
	for lane in range(3):
		var projected: Array[int] = totals.duplicate()
		projected[lane] += 1
		if projected.max() - projected.min() <= tolerance:
			candidates.append(lane)
	# An explicit order may have already exceeded tolerance, or tolerance zero
	# may be impossible for this window length. Repair via minimum counts.
	if candidates.is_empty():
		for lane in range(3):
			if totals[lane] == minimum:
				candidates.append(lane)
	return candidates[random.randi_range(0, candidates.size() - 1)]

func record_deployment(team_id: int, lane: int) -> void:
	if lane < 0 or lane > 2:
		return
	if not histories.has(team_id):
		histories[team_id] = []
	histories[team_id].append(lane)
	while histories[team_id].size() > maxi(1, window_size):
		histories[team_id].pop_front()
