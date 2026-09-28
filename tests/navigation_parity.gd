extends SceneTree
## Exact parity against the previous segment/rectangle implementation, including edges.

func _initialize() -> void:
	var navigation := RouteMap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 248791
	var corpus: Array = []
	for i in range(12000):
		var start := Vector2(rng.randf_range(-40, 4640), rng.randf_range(-40, 2640))
		var finish := Vector2(rng.randf_range(-40, 4640), rng.randf_range(-40, 2640))
		if i % 2 == 0:
			finish = start + Vector2(rng.randf_range(-180, 180), rng.randf_range(-180, 180))
		corpus.append([start, finish, [0.0, 9.0, 14.0, 28.0, 36.0][i % 5]])
	for obstacle in RouteMap.OBSTACLES:
		for radius in [0.0, 9.0, 14.0, 28.0, 36.0]:
			var box: Rect2 = obstacle.grow(radius)
			var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y), box.get_center()]
			for point in corners:
				for offset in [Vector2.ZERO, Vector2(0.001, 0.001), Vector2(-0.001, -0.001), Vector2(1000, 0), Vector2(0, 1000), Vector2(-1000, 0), Vector2(0, -1000)]:
					corpus.append([point, point + offset, radius])
					corpus.append([point + offset, point, radius])
	var expected: Array[bool] = []
	var before := Time.get_ticks_usec()
	for sample in corpus:
		expected.append(_previous_clear_line(sample[0], sample[1], sample[2]))
	var previous_us := Time.get_ticks_usec() - before
	var failures: int = 0
	before = Time.get_ticks_usec()
	for i in range(corpus.size()):
		var sample: Array = corpus[i]
		if navigation.clear_line(sample[0], sample[1], sample[2]) != expected[i]:
			push_error("Line-of-sight parity failure: %s" % str(sample))
			failures += 1
	var current_us := Time.get_ticks_usec() - before
	print("NAVIGATION PARITY cases=", corpus.size(), " failures=", failures, " previous_us=", previous_us, " current_us=", current_us)
	quit(1 if failures else 0)

func _previous_clear_line(start: Vector2, finish: Vector2, radius: float) -> bool:
	for obstacle in RouteMap.OBSTACLES:
		var box: Rect2 = obstacle.grow(radius)
		if box.has_point(start) or box.has_point(finish):
			return false
		var corners := [box.position, box.position + Vector2(box.size.x, 0), box.end, box.position + Vector2(0, box.size.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(start, finish, corners[i], corners[(i + 1) % 4]) != null:
				return false
	return true
