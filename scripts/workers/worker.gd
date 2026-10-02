extends CombatEntity
## Shared by both teams. Resource removal is atomic on the main game thread.

enum State { FIND_TREE, WALK_TO_TREE, GATHER, RETURN }

var state: State = State.FIND_TREE
var tree: TreeResource
var carried: int = 0
var gather_progress: float = 0.0
var retry_timer: float = 0.0
var danger_timer: float = 0.0
var danger_point := Vector2.INF
var scan_timer: float = 0.0
var threat: CombatEntity
var deposit_flash: float = 0.0


func _ready() -> void:
	category = &"worker"
	super._ready()
	kind = &"worker"
	body_radius = 9.0
	max_health = team.get_stat(&"worker_health")
	health = max_health


func step_gameplay(delta: float) -> void:
	if not alive:
		return
	tick(delta)
	move_speed = team.get_stat(&"worker_speed")
	danger_timer = maxf(0.0, danger_timer - delta)
	deposit_flash = maxf(0.0, deposit_flash - delta)
	scan_timer -= delta
	if scan_timer <= 0:
		scan_timer = 0.6
		threat = closest_enemy(190.0)
	if valid_enemy(threat):
		danger_timer = 12.0
		danger_point = threat.position
		state = State.RETURN if carried > 0 else State.FIND_TREE
		retry_timer = 2.0
		var refuge: Vector2 = team.base_position + threat.position.direction_to(team.base_position) * 110
		travel_toward(refuge, delta)
		return
	var capacity: int = int(team.get_stat(&"worker_capacity"))
	match state:
		State.FIND_TREE:
			retry_timer -= delta
			if retry_timer <= 0.0:
				_find_tree()
				retry_timer = 1.0
		State.WALK_TO_TREE:
			if not is_instance_valid(tree) or not tree.available():
				state = State.RETURN if carried > 0 else State.FIND_TREE
			elif global_position.distance_to(tree.global_position) <= 42.0:
				state = State.GATHER
			else:
				travel_toward(tree.global_position, delta)
		State.GATHER:
			if not is_instance_valid(tree) or not tree.available():
				state = State.RETURN if carried > 0 else State.FIND_TREE
				return
			gather_progress += team.get_stat(&"worker_gather") * delta
			var requested: int = mini(int(gather_progress), capacity - carried)
			if requested > 0:
				carried += tree.harvest(requested)
				gather_progress -= float(requested)
			if carried >= capacity or not tree.available():
				state = State.RETURN
		State.RETURN:
			if global_position.distance_to(team.base_position) <= 70.0:
				team.add_resources(carried, carried)
				if game.coordination != null:
					game.coordination.deposit(team.team_id, carried)
				deposit_flash = 0.6
				game.spawn_effect(position, Color("dfbe73"), "deposit")
				if team == game.player.team:
					game.play_sound(&"deposit", global_position)
				carried = 0
				gather_progress = 0.0
				state = State.FIND_TREE
			else:
				travel_toward(team.base_position, delta)


func _find_tree() -> void:
	var best_distance: float = INF
	tree = null
	for node in game.get_node("Trees").get_children():
		var candidate := node as TreeResource
		if not candidate.available() or (danger_timer > 0 and candidate.position.distance_to(danger_point) < 340):
			continue
		# Prefer safe, short trips near this team's storage, even after respawning.
		var distance: float = team.base_position.distance_to(candidate.global_position)
		for worker in game.session.actors.values():
			if is_instance_valid(worker) and worker.alive and worker != self and worker.kind == &"worker" and worker.tree == candidate:
				distance += 100.0
		if distance < best_distance:
			best_distance = distance
			tree = candidate
	if tree != null:
		state = State.WALK_TO_TREE
	elif carried > 0:
		state = State.RETURN


func _draw() -> void:
	super._draw()
	if state in [State.WALK_TO_TREE,State.RETURN]:
		var step: float = sin(visual_time*10)*3
		draw_line(Vector2(-5,13),Vector2(-5,19+step),Color("182d2b"),4)
		draw_line(Vector2(5,13),Vector2(5,19-step),Color("182d2b"),4)
	if carried > 0:
		for i in range(3):
			draw_line(Vector2(-8, 7+i*4), Vector2(8, 7+i*4), Color("ca9d60"), 4)
	if state == State.GATHER:
		var swing: float = sin(visual_time * 9.0)
		draw_line(Vector2(12,0),Vector2(24+swing*7,-16+absf(swing)*10),Color("d9e2cf"),3)
		if swing > 0.75:
			draw_circle(Vector2(29,-6),2,Color("e7bf74"))
