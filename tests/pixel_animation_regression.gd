extends SceneTree
## Verify animation uses real outcomes and never feeds back into simulation.
const Visual = preload("res://scripts/visuals/character_visual.gd")
const Trace = preload("res://tests/step_parity.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ",message)
	else:
		failures += 1
		push_error(message)

func _run() -> void:
	# Reproduce the developer cache failure: old imports used 48x64 cells.
	# Source recovery must produce the current grid and reuse its texture.
	var stale := ImageTexture.create_from_image(Image.create(2304,1152,false,Image.FORMAT_RGBA8))
	var repaired := Visual.atlas_texture(stale,Vector2i(1536,760),"res://assets/pixel_art/player-azure-body.png")
	check(repaired != null and repaired.get_size()==Vector2(1536,760),"Outdated body import recovers the current atlas grid")
	check(Visual.atlas_texture(stale,Vector2i(1536,760),"res://assets/pixel_art/player-azure-body.png")==repaired,"Recovered atlas is cached instead of rebuilt each frame")
	check(Visual.atlas_texture(Visual.SHEETS[&"player"][0],Vector2i(1536,760))==Visual.SHEETS[&"player"][0],"Correctly imported atlas keeps the original texture")
	var stale_effects := ImageTexture.create_from_image(Image.create(3072,640,false,Image.FORMAT_RGBA8))
	var repaired_effects := Visual.atlas_texture(stale_effects,Vector2i(1536,352),"res://assets/pixel_art/effects.png")
	check(repaired_effects != null and repaired_effects.get_size()==Vector2(1536,352),"Outdated effect import recovers the current atlas grid")
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.pause_on_focus_loss = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var actor = game.player
	actor.controller.set_scripted_command(Vector2.ZERO,false)
	actor.position = Vector2(650,1410)
	var v: CharacterVisual = actor.character_visual
	v.reset(actor.position)
	for dir in range(8):
		var heading := Vector2.from_angle(dir * PI / 4.0)
		actor.position += heading * 4.0
		actor.step_presentation(MatchSession.STEP,true)
		check(v.direction == dir and v.moving,"Actual movement selects facing %d" % dir)
	var direction: int = v.direction
	var walk_phase: float = v.walk_phase
	actor.step_presentation(MatchSession.STEP,true)
	check(not v.moving and v.leg_frame == 0 and v.direction==direction and v.walk_phase==walk_phase,"Stationary actor stops steps and retains facing")
	v._face(Vector2.from_angle(PI/8.0),true)
	var boundary: int = v.direction
	v._face(Vector2.from_angle(PI/8.0+0.02))
	v._face(Vector2.from_angle(PI/8.0-0.02))
	check(v.direction==boundary,"Facing hysteresis suppresses diagonal flicker")
	actor.position += Vector2(700,0)
	actor.step_presentation(MatchSession.STEP,true)
	check(not v.moving,"Teleport does not look like walking")
	var obstacle: Rect2 = game.navigation.obstacles[0]
	actor.position = Vector2(obstacle.position.x-actor.body_radius-1,obstacle.get_center().y)
	v.reset(actor.position)
	actor.apply_input({"direction":Vector2.RIGHT,"delta":MatchSession.STEP})
	actor.step_presentation(MatchSession.STEP,true)
	check(not v.moving,"Walking intention against a wall does not animate steps")
	actor.position = Vector2(650,1410)
	v.reset(actor.position)
	var foe = game.commanders[2]
	foe.position = actor.position + Vector2.RIGHT*65
	foe.cancel_action()
	foe.health = foe.max_health
	actor.cooldown=0
	actor.attack(foe)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"windup" and foe.health==foe.max_health,"Commander poses anticipate existing light-strike timing")
	actor.step_gameplay(game.balance.commander_strike_windup+0.01)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"attack" and foe.health<foe.max_health,"Sword impact begins at actual strike resolution")
	v.reset(actor.position)
	actor.cooldown=0
	actor.attack(foe)
	foe.position+=Vector2.RIGHT*200
	actor.step_gameplay(game.balance.commander_strike_windup+0.01)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"attack" and actor.cooldown>0,"Missed light strike still visibly follows through")
	actor.cancel_action()
	actor.cooldown=0
	actor.activate_ability(&"heavy",Vector2.UP)
	actor.step_gameplay(0.3)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"heavy" and v.direction==6,"Heavy preparation retains committed facing")
	actor.step_gameplay(0.31)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"attack" and v.heavy_attack and actor.action_state==&"recovery","Missed heavy resolves into swing and recovery")
	v.step(actor,0.3)
	check(v.action==&"recovery","Heavy follow-through ends in exposed recovery pose")
	actor.cancel_action()
	actor.activate_ability(&"guard",Vector2.RIGHT)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"guard" and v.direction==0,"Shield faces the protected direction")
	actor.take_damage(20,2,0,actor.position+Vector2.RIGHT*30)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"guard_hit","Front-facing guarded hit triggers shield recoil")
	v.block_remaining=0
	actor.take_damage(20,2,0,actor.position-Vector2.RIGHT*30)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"guard" and v.block_remaining==0,"Rear hit does not falsely show a successful block")
	actor.cancel_action()
	actor.activate_ability(&"dash",Vector2.DOWN)
	actor.step_gameplay(0.05)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"dash" and v.direction==2,"Dash uses committed lean and facing")
	actor.apply_stun(0.5)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"stun" and not v.moving and v.attack_remaining==0,"Stun cancels committed animation without stale strikes")
	actor.stun_remaining=0
	actor.stun_immunity=0
	actor.cancel_action()
	actor.position=actor.team.base_position
	actor.health=50
	actor.heal_cooldown=0
	actor.interact()
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action==&"heal","Base restoration selects healing pose")
	actor.take_damage(1,2)
	actor.step_presentation(MatchSession.STEP,true)
	check(v.action!=&"heal","Damage interruption clears healing pose")
	game.teams[0].money=10000
	game.purchase(1,&"ranged",false,1)
	var archer = game.entities.get_child(game.entities.get_child_count()-1)
	archer.position=Vector2(650,1410)
	archer.practice_unit=true
	archer.character_visual.reset(archer.position)
	foe.position=archer.position+Vector2.RIGHT*130
	foe.stun_remaining=0
	archer.cooldown=0
	archer.target=foe
	var projectile_count: int = get_nodes_in_group("projectiles").size()
	archer.attack(foe)
	archer.step_presentation(MatchSession.STEP,true)
	check(archer.character_visual.action==&"attack" and get_nodes_in_group("projectiles").size()==projectile_count+1,"Archer release and real projectile launch remain simultaneous")
	archer.character_visual.attack_remaining=0
	archer.cooldown=0.15
	archer.step_presentation(MatchSession.STEP,true)
	check(archer.character_visual.action==&"bow_ready","Archer prepares during existing cooldown without delaying firing")
	for role in [&"melee", &"tank"]:
		game.purchase(1,role,false,1)
		var unit = game.entities.get_child(game.entities.get_child_count()-1)
		unit.position=Vector2(650,1410)
		unit.practice_unit=true
		unit.character_visual.reset(unit.position)
		foe.position=unit.position+Vector2.RIGHT*40
		var health_before: float = foe.health
		unit.attack(foe)
		unit.step_presentation(MatchSession.STEP,true)
		check(unit.character_visual.action==&"attack" and foe.health<health_before,"%s impact preserves instant damage timing" % role)
		unit.position+=Vector2.DOWN*3
		unit.step_presentation(MatchSession.STEP,true)
		check(unit.character_visual.action==&"attack" and unit.character_visual.moving,"%s movement continues under upper-body attack" % role)
	var worker = null
	for candidate in game.session.actors_in_order:
		if candidate.kind==&"worker":
			worker=candidate
			break
	var tree = game.get_node("Trees").get_child(0)
	worker.tree=tree
	worker.position=tree.position+Vector2.LEFT*35
	worker.threat=null
	worker.state=worker.State.GATHER
	worker.character_visual.reset(worker.position)
	worker.step_presentation(MatchSession.STEP,true)
	check(worker.character_visual.action==&"gather" and worker.character_visual.direction==0,"Worker chops toward the actual tree")
	worker.state=worker.State.RETURN
	worker.carried=3
	worker.position+=Vector2.LEFT*2
	worker.step_presentation(MatchSession.STEP,true)
	check(worker.character_visual.action==&"carry" and worker.character_visual.moving,"Loaded worker walks with visible resources")
	worker.threat=foe
	worker.position+=Vector2.LEFT*2
	worker.step_presentation(MatchSession.STEP,true)
	check(worker.character_visual.action==&"flee_carry","Fleeing workers keep their carried bundle visible")
	worker.threat=null
	worker.carried=0
	worker.deposit_flash=0.6
	worker.step_presentation(MatchSession.STEP,true)
	check(worker.character_visual.action==&"deposit","Completed deposit selects empty-handed handoff feedback")
	worker.deposit_flash=0
	worker.state=worker.State.FIND_TREE
	worker.step_presentation(MatchSession.STEP,true)
	check(worker.character_visual.action==&"idle" and not worker.character_visual.moving,"Worker waiting for a resource does not chop or step")
	actor.presentation_visible = false
	actor.cancel_action()
	actor.healing = false
	v.reset(actor.position)
	actor.ability_cooldowns[&"guard"] = 0.0
	check(actor.activate_ability(&"guard",Vector2.UP),"Offscreen guard test activates a fresh action")
	v.step(actor,MatchSession.STEP,false)
	check(v.action==&"idle" and v.direction==6,"Offscreen sampling keeps facing without rebuilding pose")
	v.step(actor,MatchSession.STEP,true)
	check(v.action==&"guard" and v.direction==6,"Re-entry immediately refreshes the current committed pose")
	# Sampling a pose must not change any authoritative gameplay fields.
	var before: Dictionary = Trace.snapshot(game)
	for index in range(60):
		actor.step_presentation(MatchSession.STEP,true)
	check(Trace.snapshot(game)==before,"Repeated presentation sampling cannot mutate gameplay")
	actor.take_damage(999999,2)
	check(not actor.alive and not actor.visible,"Commander death still removes targetability and hides body immediately")
	var remnant = null
	for child in game.get_children():
		if child.get_script()==load("res://scripts/visuals/character_remnant.gd"):
			remnant=child
	check(remnant!=null and not remnant.is_in_group("combatants"),"Death remnant is independent of combat registry")
	actor.respawn_remaining=0.01
	actor.step_gameplay(MatchSession.STEP)
	actor.step_presentation(MatchSession.STEP,true)
	check(actor.alive and v.action==&"spawn" and v.attack_remaining==0 and v.block_remaining==0,"Respawn clears old actions and resets pose")
	actor.controller.set_scripted_command(Vector2.ZERO,false)
	game.session.step()
	var elapsed_before: float = v.elapsed
	game.session.pause()
	game.session.step()
	check(v.elapsed==elapsed_before,"Session pause freezes character animation")
	var remnant_age: float = remnant.age
	remnant._process(1.0)
	check(remnant.age>=remnant_age,"Remnant samples session time")
	remnant_age=remnant.age
	remnant._process(1.0)
	check(remnant.age==remnant_age,"Paused session freezes death remnant")
	game.session.resume()
	game.session.finish()
	game.session.step()
	check(v.elapsed==elapsed_before,"Match completion freezes character animation")
	game.free()
	await process_frame
	await physics_frame
	await physics_frame
	var audio = root.get_node("AudioFeedback")
	audio.stop_all()
	audio.queue_free()
	await create_timer(0.5).timeout
	print("PIXEL ANIMATION REGRESSION failures=",failures)
	quit(1 if failures else 0)
