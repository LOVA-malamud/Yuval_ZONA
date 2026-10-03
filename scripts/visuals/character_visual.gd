class_name CharacterVisual
extends RefCounted
## Presentation-only pose sampler. Gameplay timers remain authoritative.
const CELL := Vector2(32, 40)
const ANCHOR := Vector2(16, 31)
const FRAMES := 6
const ACTIONS: Array[StringName] = [&"idle", &"attack", &"heavy", &"guard", &"guard_hit", &"dash", &"recovery", &"stun", &"heal", &"gather", &"carry", &"flee", &"deposit", &"death", &"spawn", &"bow_ready", &"windup", &"walk", &"flee_carry"]
const EFFECTS: Array[StringName] = [&"slash", &"heavy", &"block", &"dash", &"woodchip", &"heal", &"stun", &"death", &"deposit", &"spawn", &"arrow"]
const FX = preload("res://assets/pixel_art/effects.png")
const SHADOW = preload("res://assets/pixel_art/shadow.png")
const SHEETS := {
	&"player": [preload("res://assets/pixel_art/player-azure-body.png"), preload("res://assets/pixel_art/player-azure-legs.png"), preload("res://assets/pixel_art/player-ember-body.png"), preload("res://assets/pixel_art/player-ember-legs.png")],
	&"melee": [preload("res://assets/pixel_art/melee-azure-body.png"), preload("res://assets/pixel_art/melee-azure-legs.png"), preload("res://assets/pixel_art/melee-ember-body.png"), preload("res://assets/pixel_art/melee-ember-legs.png")],
	&"ranged": [preload("res://assets/pixel_art/ranged-azure-body.png"), preload("res://assets/pixel_art/ranged-azure-legs.png"), preload("res://assets/pixel_art/ranged-ember-body.png"), preload("res://assets/pixel_art/ranged-ember-legs.png")],
	&"tank": [preload("res://assets/pixel_art/tank-azure-body.png"), preload("res://assets/pixel_art/tank-azure-legs.png"), preload("res://assets/pixel_art/tank-ember-body.png"), preload("res://assets/pixel_art/tank-ember-legs.png")],
	&"worker": [preload("res://assets/pixel_art/worker-azure-body.png"), preload("res://assets/pixel_art/worker-azure-legs.png"), preload("res://assets/pixel_art/worker-ember-body.png"), preload("res://assets/pixel_art/worker-ember-legs.png")],
}
static var repaired_atlases: Dictionary = {}

static func atlas_texture(texture: Texture2D, expected: Vector2i, source_path: String = "") -> Texture2D:
	if Vector2i(texture.get_size()) == expected:
		return texture
	var path := texture.resource_path if source_path.is_empty() else source_path
	if repaired_atlases.has(path):
		return repaired_atlases[path]
	# Running source directly does not invoke Godot's editor importer. Recover
	# from old local imports rather than slicing the wrong grid into fragments.
	var source := Image.new()
	var loaded := source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else ERR_FILE_NOT_FOUND
	if loaded == OK and Vector2i(source.get_size()) == expected:
		var repaired := ImageTexture.create_from_image(source)
		repaired_atlases[path] = repaired
		push_warning("Recovered outdated pixel atlas import: %s. Run python3 tools/run_game.py to refresh imports." % path)
		return repaired
	push_error("Pixel atlas size mismatch: %s; expected %s, got %s. Reimport the project before running." % [path, expected, texture.get_size()])
	return null

var previous_position := Vector2.ZERO
var initialized := false
var facing := Vector2.DOWN
var direction: int = 2
var moving := false
var walk_phase := 0.0
var elapsed := 0.0
var action: StringName = &"idle"
var frame: int = 0
var leg_frame: int = 0
var attack_remaining := 0.0
var attack_duration := 0.22
var attack_heading := Vector2.RIGHT
var heavy_attack := false
var block_remaining := 0.0
var spawn_remaining := 0.0
var worker_chop_frame := -1

func reset(point: Vector2, spawning: bool = false) -> void:
	previous_position = point
	initialized = true
	moving = false
	walk_phase = 0.0
	elapsed = 0.0
	attack_remaining = 0.0
	block_remaining = 0.0
	spawn_remaining = 0.3 if spawning else 0.0
	worker_chop_frame = -1
	action = &"spawn" if spawning else &"idle"
	frame = 0
	leg_frame = 0
	facing = Vector2.DOWN
	direction = 2

func note_attack(heading: Vector2, duration: float = 0.22, heavy: bool = false) -> void:
	attack_heading = heading.normalized() if heading.length_squared() > 0.001 else facing
	attack_duration = maxf(0.1, duration)
	attack_remaining = attack_duration
	heavy_attack = heavy

func note_block() -> void:
	block_remaining = 0.14

func cancel_attack() -> void:
	attack_remaining = 0.0
	block_remaining = 0.0

func _face(heading: Vector2, committed: bool = false) -> void:
	if heading.length_squared() < 0.001 or not heading.is_finite():
		return
	var chosen: int = posmod(int(round(heading.angle() / (PI / 4.0))), 8)
	# Six degrees of hysteresis prevent flickering at diagonal boundaries.
	if committed or absf(Vector2.from_angle(direction * PI / 4.0).angle_to(heading)) > PI / 8.0 + deg_to_rad(6.0):
		direction = chosen
	facing = heading.normalized()

func step(actor, delta: float, sample_pose: bool = true) -> bool:
	if not initialized:
		reset(actor.global_position)
	var old_action := action
	var old_frame := frame
	var old_leg := leg_frame
	var old_direction := direction
	var old_moving := moving
	elapsed += delta
	attack_remaining = maxf(0.0, attack_remaining - delta)
	block_remaining = maxf(0.0, block_remaining - delta)
	spawn_remaining = maxf(0.0, spawn_remaining - delta)
	var motion: Vector2 = actor.global_position - previous_position
	previous_position = actor.global_position
	var ability: StringName = actor.action_state if actor.kind == &"player" else &"ready"
	# Teleports and initial placement do not produce a burst of walking frames.
	moving = motion.length_squared() > 0.01 and (motion.length() < maxf(24.0, actor.move_speed * delta * 4.0) or ability == &"dash")
	if moving:
		_face(motion)
		walk_phase += motion.length() / 32.0 * FRAMES
	leg_frame = int(walk_phase) % FRAMES if moving else 0
	if not sample_pose:
		# Preserve time/motion/facing cheaply while offscreen; resolve the current
		# pose on re-entry rather than rebuilding invisible local draw commands.
		if ability in [&"heavy", &"guard", &"dash"]:
			_face(actor.facing,true)
		elif attack_remaining > 0.0:
			_face(attack_heading,true)
		return false
	action = &"walk" if moving else &"idle"
	frame = leg_frame if moving else int(elapsed * 2.0 + actor.match_id) % FRAMES
	if actor.stun_remaining > 0.0:
		action = &"stun"
		frame = int(elapsed * 8.0) % FRAMES
		attack_remaining = 0.0
		moving = false
		leg_frame = 0
	elif ability in [&"heavy", &"guard", &"dash"]:
		_face(actor.facing, true)
		action = &"guard_hit" if ability == &"guard" and block_remaining > 0.0 else ability
		if ability == &"heavy":
			frame = _progress_frame(1.0 - actor.action_remaining / actor._tuning("heavy_windup", 0.6))
		elif action == &"guard_hit":
			frame = _progress_frame(1.0 - block_remaining / 0.14)
		else:
			frame = int(elapsed * 8.0) % FRAMES if ability == &"dash" else 0
	elif actor.kind == &"player" and actor.strike_remaining > 0.0:
		if actor.valid_enemy(actor.strike_target):
			_face(actor.global_position.direction_to(actor.strike_target.global_position), true)
		action = &"windup"
		frame = _progress_frame(1.0 - actor.strike_remaining / actor.game.balance.commander_strike_windup)
	elif attack_remaining > 0.0:
		_face(attack_heading, true)
		action = &"attack"
		frame = _progress_frame(1.0 - attack_remaining / attack_duration)
	elif ability == &"recovery":
		action = &"recovery"
		frame = int(elapsed * 8.0) % FRAMES
	elif actor.kind == &"player" and actor.healing:
		action = &"heal"
		frame = int(elapsed * 6.0) % FRAMES
	elif actor.kind == &"worker":
		_worker_pose(actor)
	elif actor.tactical_role == &"ranged" and actor.cooldown > 0.0 and actor.cooldown < 0.3 and actor.valid_enemy(actor.get("target")) and actor.edge_distance(actor.get("target")) <= actor.attack_range:
		_face(actor.global_position.direction_to(actor.get("target").global_position), true)
		action = &"bow_ready"
		frame = _progress_frame(1.0 - actor.cooldown / 0.3)
	elif spawn_remaining > 0.0:
		action = &"spawn"
		frame = _progress_frame(1.0 - spawn_remaining / 0.3)
	if spawn_remaining > 0.0 and action in [&"idle", &"walk", &"carry"]:
		action = &"spawn"
		frame = _progress_frame(1.0 - spawn_remaining / 0.3)
	return old_action != action or old_frame != frame or old_leg != leg_frame or old_direction != direction or old_moving != moving

func _worker_pose(actor) -> void:
	if actor.valid_enemy(actor.threat) and moving:
		action = &"flee_carry" if actor.carried > 0 else &"flee"
		frame = leg_frame
	elif actor.state == actor.State.GATHER and is_instance_valid(actor.tree) and actor.tree.available():
		_face(actor.global_position.direction_to(actor.tree.global_position), true)
		action = &"gather"
		frame = int(elapsed * 9.0) % FRAMES
	elif actor.deposit_flash > 0.0 and actor.carried == 0:
		action = &"deposit"
		frame = _progress_frame(1.0 - actor.deposit_flash / 0.6)
	elif actor.carried > 0:
		action = &"carry"
		frame = leg_frame if moving else 0

static func _progress_frame(progress: float) -> int:
	return clampi(int(progress * FRAMES), 0, FRAMES - 1)

func paint(canvas: CanvasItem, role: StringName, team_id: int, hit_flash: float) -> void:
	var color := Color.WHITE.lerp(Color(1.8, 1.8, 1.6), clampf(hit_flash / 0.16, 0.0, 1.0))
	if action == &"spawn":
		color.a = 0.4 + 0.6 * frame / (FRAMES-1)
	paint_pose(canvas, role, team_id, action, direction, frame, moving, leg_frame, Vector2.ZERO, 1.0, color)
	if action == &"attack":
		paint_effect(canvas, &"heavy" if heavy_attack else &"slash", direction, frame, Vector2(0,-10))
	elif action == &"guard_hit":
		paint_effect(canvas, &"block", direction, frame, facing * 15.0 + Vector2(0,-10))
	elif action == &"dash":
		paint_effect(canvas, &"dash", direction, int(elapsed * 24.0) % FRAMES, Vector2(0,2))
	elif action == &"gather" and frame in [2,3]:
		paint_effect(canvas, &"woodchip", direction, frame, facing * 16.0 + Vector2(0,-8))
	elif action == &"heal":
		paint_effect(canvas, &"heal", direction, frame, Vector2(0,-10))
	elif action == &"stun":
		paint_effect(canvas, &"stun", direction, frame, Vector2(0,-46))
	elif action == &"deposit":
		paint_effect(canvas, &"deposit", direction, frame, Vector2(0,-18))
	elif action == &"spawn":
		paint_effect(canvas, &"spawn", direction, frame, Vector2(0,-10))

static func paint_pose(canvas: CanvasItem, role: StringName, team_id: int, pose: StringName = &"idle", facing_index: int = 1, pose_frame: int = 0, walking: bool = false, walk_frame: int = 0, origin := Vector2.ZERO, scale: float = 1.0, color := Color.WHITE) -> void:
	if not SHEETS.has(role):
		return
	var sheets: Array = SHEETS[role]
	var offset: int = 0 if team_id == 1 else 2
	var body := atlas_texture(sheets[offset], Vector2i(int(CELL.x)*FRAMES*8, int(CELL.y)*ACTIONS.size()))
	var legs := atlas_texture(sheets[offset+1], Vector2i(int(CELL.x)*FRAMES*8, int(CELL.y)*3))
	if body == null or legs == null:
		return
	var column: int = posmod(facing_index, 8) * FRAMES + clampi(pose_frame, 0, FRAMES-1)
	var row: int = maxi(0, ACTIONS.find(pose))
	var pixel_scale: float = scale * 2.0
	var destination := Rect2(origin - ANCHOR * pixel_scale, CELL * pixel_scale)
	canvas.draw_texture_rect(SHADOW, Rect2(origin + Vector2(-24,-5)*scale, Vector2(48,24)*scale), false, Color(1,1,1,color.a))
	# Legs render below armor/cape and stay independent of the upper action.
	var leg_column: int = posmod(facing_index, 8) * FRAMES + clampi(walk_frame, 0, FRAMES-1)
	if pose != &"death":
		canvas.draw_texture_rect_region(legs, destination, Rect2(Vector2(leg_column * CELL.x, CELL.y if walking else CELL.y*2 if pose in [&"heavy", &"guard", &"guard_hit"] else 0.0), CELL), color)
	var shoulder_bob := Vector2(0, -1 if walking and walk_frame in [1,4] else 0)
	canvas.draw_texture_rect_region(body, Rect2(destination.position + shoulder_bob*scale, destination.size), Rect2(Vector2(column * CELL.x, row * CELL.y), CELL), color)

static func paint_effect(canvas: CanvasItem, effect: StringName, facing_index: int, pose_frame: int, origin: Vector2) -> void:
	var row: int = EFFECTS.find(effect)
	if row < 0:
		return
	var effects := atlas_texture(FX, Vector2i(32*FRAMES*8, 32*EFFECTS.size()))
	if effects == null:
		return
	var column: int = posmod(facing_index,8) * FRAMES + clampi(pose_frame,0,FRAMES-1)
	canvas.draw_texture_rect_region(effects, Rect2((origin/2.0).round()*2.0-Vector2(32,32),Vector2(64,64)), Rect2(Vector2(column*32,row*32),Vector2(32,32)))
