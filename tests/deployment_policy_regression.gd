extends SceneTree

func _initialize() -> void:
	var policy := preload("res://scripts/ai/deployment_policy.gd").new()
	var random := RandomNumberGenerator.new()
	random.seed = 72
	for index in range(120):
		policy.record_deployment(1, policy.choose_lane(1, random))
		var totals := policy.counts(1)
		assert(totals.max() - totals.min() <= 2, "Autonomous deployments must balance shared rolling history")
	assert(policy.histories[1].size() == 30)
	assert(policy.counts(2) == [0, 0, 0], "Teams have independent history")
	for index in range(30):
		policy.record_deployment(1, 0)
	assert(policy.counts(1) == [30, 0, 0], "Overrides are recorded")
	for index in range(30):
		var lane := policy.choose_lane(1, random)
		if index == 0:
			assert(lane != 0, "Balance after emergency/manual concentration")
		policy.record_deployment(1, lane)
	var totals := policy.counts(1)
	assert(totals.max() - totals.min() <= 2)
	var first := preload("res://scripts/ai/deployment_policy.gd").new()
	var second := preload("res://scripts/ai/deployment_policy.gd").new()
	var other := RandomNumberGenerator.new()
	random.seed = 19
	other.seed = 19
	for index in range(60):
		var lane := first.choose_lane(1, random)
		assert(lane == second.choose_lane(1, other), "Seeded tie breaks reproduce")
		first.record_deployment(1, lane)
		second.record_deployment(1, lane)
	var loose := preload("res://scripts/ai/deployment_policy.gd").new()
	loose.tolerance = 6
	random.seed = 29
	var saw_loose: bool = false
	for index in range(120):
		loose.record_deployment(1, loose.choose_lane(1, random))
		var spread: int = loose.counts(1).max() - loose.counts(1).min()
		assert(spread <= 6)
		saw_loose = saw_loose or spread > 2
	assert(saw_loose, "Tolerance changes permitted deployment spread")
	print("Deployment policy regression passed")
	quit()
