class_name WheelchairPlayer
extends CharacterBody3D

## 병원에서 깨어난 전설의 킬러. 휠체어에 앉아 있다.
##
## 문서 8절의 상태표를 그대로 규칙으로 삼는다.
##   직접 조작 중  -> 이동 O / 사격 X
##   관성 롤 중    -> 자동 이동 / 사격 O
##   완전 정지     -> 정밀 조준 / 사격 O
##   엄마가 미는 중 -> 고속 이동 / 사격 O
## 즉 사격을 막는 것은 "속도"가 아니라 "직접 굴리는 입력"이다.
## 도망치려면 굴려야 하고, 죽이려면 손을 떼거나 엄마에게 맡겨야 한다.

const RAY_MASK := Build.LAYER_WORLD | Build.LAYER_NPC

var drive: Enums.Drive = Enums.Drive.STOPPED
var hp: float = Balance.PLAYER_MAX_HP
var alive: bool = true

var chair_yaw: float = 0.0
var look_yaw: float = 0.0
var look_pitch: float = 0.0

var aiming: bool = false
var aim_settle: float = 0.0
var fire_cooldown: float = 0.0
var reload_timer: float = 0.0
var in_mag: int = Balance.MAG_SIZE

var on_rail: bool = false
var rail_dir: Vector3 = Vector3.ZERO
var carry_target_y: float = 0.0

var mom: Node3D = null
## 입력을 받아들이는가. 마우스 캡처가 풀리거나 루프 화면이 뜨면 꺼진다.
var input_enabled: bool = true

var _recoil_pitch: float = 0.0
var _input_drive: float = 0.0
var _input_turn: float = 0.0
var _muzzle_timer: float = 0.0
var _hit_flash: float = 0.0

var pivot: Node3D
var camera: Camera3D
var muzzle_flash: MeshInstance3D
var chair_body: Node3D


## 씬 파일 대신 코드로 조립한다. 모든 지오메트리가 프리미티브라 이 편이 검증하기 쉽다.
static func create() -> WheelchairPlayer:
	var p := WheelchairPlayer.new()
	p.set_script(load("res://scripts/player/wheelchair_player.gd"))
	p.name = "Player"
	return p


func _ready() -> void:
	collision_layer = Build.LAYER_PLAYER
	collision_mask = Build.LAYER_WORLD
	floor_max_angle = deg_to_rad(38.0)
	floor_snap_length = 0.4
	_build_nodes()
	chair_yaw = rotation.y
	look_yaw = chair_yaw
	_emit_ammo()


func _build_nodes() -> void:
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.35
	cs.shape = capsule
	cs.position = Vector3(0.0, 0.68, 0.0)
	add_child(cs)

	chair_body = Node3D.new()
	chair_body.name = "ChairVisual"
	add_child(chair_body)
	var frame := Color(0.22, 0.24, 0.28)
	var seat := Color(0.16, 0.17, 0.20)
	# 정면은 -Z (Godot 규약). 등받이와 손잡이는 +Z 쪽, 다리와 앞바퀴는 -Z 쪽.
	Build.box(chair_body, Vector3(0.62, 0.10, 0.60), Vector3(0.0, 0.52, 0.0), seat, false)
	Build.box(chair_body, Vector3(0.62, 0.62, 0.10), Vector3(0.0, 0.82, 0.28), seat, false)
	Build.cylinder(chair_body, 0.34, 0.06, Vector3(-0.40, 0.34, 0.0), frame, false, Vector3(0.0, 0.0, PI * 0.5))
	Build.cylinder(chair_body, 0.34, 0.06, Vector3(0.40, 0.34, 0.0), frame, false, Vector3(0.0, 0.0, PI * 0.5))
	Build.cylinder(chair_body, 0.12, 0.05, Vector3(-0.26, 0.12, -0.42), frame, false, Vector3(0.0, 0.0, PI * 0.5))
	Build.cylinder(chair_body, 0.12, 0.05, Vector3(0.26, 0.12, -0.42), frame, false, Vector3(0.0, 0.0, PI * 0.5))
	# 무릎 담요와 다리 — 1인칭에서 아래를 보면 보인다.
	Build.box(chair_body, Vector3(0.52, 0.16, 0.50), Vector3(0.0, 0.62, -0.28), Color(0.42, 0.24, 0.26), false)
	# 손잡이 (엄마가 잡는 곳)
	Build.cylinder(chair_body, 0.04, 0.30, Vector3(-0.30, 1.05, 0.34), frame, false, Vector3(0.0, 0.0, PI * 0.5))
	Build.cylinder(chair_body, 0.04, 0.30, Vector3(0.30, 1.05, 0.34), frame, false, Vector3(0.0, 0.0, PI * 0.5))

	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0.0, Balance.CAMERA_HEIGHT, 0.0)
	add_child(pivot)

	camera = Camera3D.new()
	camera.fov = 74.0
	camera.near = 0.05
	camera.current = true
	pivot.add_child(camera)

	var gun := Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0.24, -0.20, -0.62)
	gun.rotation.y = deg_to_rad(-4.0)
	camera.add_child(gun)
	var steel := Color(0.30, 0.31, 0.35)
	_metal(Build.box(gun, Vector3(0.05, 0.12, 0.08), Vector3(0.0, -0.07, 0.05), Color(0.17, 0.16, 0.18), false))
	_metal(Build.box(gun, Vector3(0.045, 0.06, 0.24), Vector3(0.0, 0.01, -0.08), steel, false))
	_metal(Build.box(gun, Vector3(0.03, 0.03, 0.10), Vector3(0.0, -0.03, -0.10), steel.darkened(0.2), false))

	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.01, -0.21)
	gun.add_child(muzzle)

	muzzle_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.07
	flash_mesh.height = 0.14
	muzzle_flash.mesh = flash_mesh
	muzzle_flash.material_override = Build.emissive(Color(1.0, 0.85, 0.45), 6.0)
	muzzle_flash.visible = false
	muzzle.add_child(muzzle_flash)


## 총기는 금속으로 보여야 한다 (문서 13절: "반동과 충격이 잘 느껴져야 함").
func _metal(node: Node3D) -> void:
	for child: Node in node.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			mat.metallic = 0.75
			mat.roughness = 0.35


func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		look_yaw -= mm.relative.x * Balance.MOUSE_SENSITIVITY
		look_pitch = clampf(
			look_pitch - mm.relative.y * Balance.MOUSE_SENSITIVITY,
			-Balance.PITCH_LIMIT,
			Balance.PITCH_LIMIT
		)


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_read_input()
	_update_drive_state(delta)
	_apply_motion(delta)
	_update_weapon(delta)
	_update_view(delta)


# --- 입력 -------------------------------------------------------------------


func _read_input() -> void:
	if not input_enabled:
		_input_drive = 0.0
		_input_turn = 0.0
		return
	_input_drive = Input.get_axis("move_back", "move_forward")
	_input_turn = Input.get_axis("move_right", "move_left")


func _mom_pushing() -> bool:
	return mom != null and mom.has_method("is_gripping") and mom.is_gripping()


func _mom_carrying() -> bool:
	return mom != null and mom.has_method("is_carrying") and mom.is_carrying()


# --- 구동 상태 ---------------------------------------------------------------


func _update_drive_state(_delta: float) -> void:
	var previous := drive
	var planar := Vector2(velocity.x, velocity.z).length()
	if _mom_carrying():
		drive = Enums.Drive.CARRIED
	elif _mom_pushing():
		drive = Enums.Drive.PUSHED
	elif absf(_input_drive) > 0.05:
		drive = Enums.Drive.SELF
	elif planar > Balance.STOP_THRESHOLD:
		drive = Enums.Drive.COAST
	else:
		drive = Enums.Drive.STOPPED
	if drive != previous:
		EventBus.drive_changed.emit(drive)
		if drive != Enums.Drive.STOPPED:
			aim_settle = 0.0


# --- 이동 -------------------------------------------------------------------


func _apply_motion(delta: float) -> void:
	if drive == Enums.Drive.CARRIED:
		_apply_carry(delta)
		return

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 22.0) * delta

	var push_input := Vector2.ZERO
	if drive == Enums.Drive.PUSHED and mom.has_method("get_push_input"):
		push_input = mom.get_push_input()

	var turn_rate := Balance.TURN_SPEED_SELF
	var forward_input := _input_drive
	var turn_input := _input_turn
	if drive == Enums.Drive.PUSHED:
		turn_rate = Balance.TURN_SPEED_PUSH
		forward_input = push_input.y
		turn_input = push_input.x

	# 조향: 직접 굴릴 때는 A/D 로만, 밀릴 때는 엄마가 시야 방향으로 끌고 간다.
	if not on_rail:
		chair_yaw += turn_input * turn_rate * delta
		if absf(forward_input) > 0.05:
			var steer_assist := angle_difference(chair_yaw, look_yaw)
			chair_yaw += clampf(steer_assist, -turn_rate * delta, turn_rate * delta)

	# Godot 규약상 노드의 정면은 -Z 다. 카메라와 축을 맞춘다.
	var forward := Vector3(-sin(chair_yaw), 0.0, -cos(chair_yaw))
	var planar := Vector3(velocity.x, 0.0, velocity.z)

	if on_rail:
		# 난간 타기 — 마찰이 사라지고 레일 방향으로 미끄러진다 (문서 10절).
		var along := rail_dir * maxf(planar.dot(rail_dir), 4.5)
		planar = planar.lerp(along, 1.0 - exp(-6.0 * delta))
		chair_yaw = atan2(-rail_dir.x, -rail_dir.z)
	else:
		var accel := Balance.SELF_ACCEL
		var max_speed := Balance.SELF_MAX_SPEED
		if drive == Enums.Drive.PUSHED:
			accel = Balance.PUSH_ACCEL
			max_speed = Balance.PUSH_MAX_SPEED
		var control := 1.0 if is_on_floor() else Balance.AIR_CONTROL
		if absf(forward_input) > 0.05:
			planar += forward * forward_input * accel * control * delta
			if planar.length() > max_speed:
				planar = planar.normalized() * max_speed
		else:
			# 관성 롤. 굴러가는 동안에도 사격은 가능하다.
			planar = planar.move_toward(Vector3.ZERO, Balance.ROLL_FRICTION * delta)

	if _braking():
		planar = planar.move_toward(Vector3.ZERO, Balance.BRAKE_DECEL * delta)

	velocity.x = planar.x
	velocity.z = planar.z

	if _jump_requested() and is_on_floor():
		velocity.y = Balance.JUMP_VELOCITY
		EventBus.mom_action.emit("휠체어 점프!")

	var before := global_position
	move_and_slide()
	if drive == Enums.Drive.PUSHED and is_on_floor():
		_try_step_up(delta, before)


## 급정지. 플레이어의 Ctrl 또는 엄마의 급정지 버튼.
func _braking() -> bool:
	if input_enabled and Input.is_action_pressed("brake"):
		return true
	return mom != null and mom.has_method("wants_brake") and mom.wants_brake()


func _jump_requested() -> bool:
	if not _mom_pushing():
		return false
	return mom.has_method("wants_jump") and mom.wants_jump()


## 밀리는 중에는 도로 턱 정도는 알아서 넘는다.
func _try_step_up(delta: float, _before: Vector3) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.001:
		return
	if not test_move(global_transform, motion):
		return
	var lifted := global_transform.translated(Vector3.UP * Balance.STEP_HEIGHT)
	if test_move(lifted, motion):
		return
	global_position.y += Balance.STEP_HEIGHT
	velocity.y = maxf(velocity.y, 0.0)


## 엄마가 휠체어를 들고 계단을 오르는 중 (문서 10절).
func _apply_carry(delta: float) -> void:
	velocity = Vector3.ZERO
	if mom == null:
		return
	var target: Vector3 = mom.get_carry_position() if mom.has_method("get_carry_position") else global_position
	var to_target := target - global_position
	var horizontal := Vector3(to_target.x, 0.0, to_target.z)
	var step := horizontal.limit_length(Balance.CARRY_CLIMB_SPEED * delta)
	global_position += step
	global_position.y = move_toward(global_position.y, target.y, Balance.CARRY_LIFT_RATE * delta)


# --- 시야 -------------------------------------------------------------------


func _update_view(delta: float) -> void:
	rotation.y = chair_yaw
	chair_body.rotation.y = 0.0
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, 9.0 * delta)
	pivot.rotation.y = angle_difference(chair_yaw, look_yaw)
	pivot.rotation.x = look_pitch + deg_to_rad(_recoil_pitch)
	var target_fov := 52.0 if (aiming and drive == Enums.Drive.STOPPED) else 74.0
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-9.0 * delta))
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
		muzzle_flash.visible = true
	else:
		muzzle_flash.visible = false
	if _hit_flash > 0.0:
		_hit_flash -= delta


# --- 무기 -------------------------------------------------------------------


func can_fire() -> bool:
	var spread: float = Balance.SPREAD_BY_DRIVE.get(drive, -1.0)
	return spread >= 0.0 and in_mag > 0 and reload_timer <= 0.0 and fire_cooldown <= 0.0


func current_spread() -> float:
	var spread: float = Balance.SPREAD_BY_DRIVE.get(drive, -1.0)
	if spread < 0.0:
		return -1.0
	if drive == Enums.Drive.STOPPED and aiming:
		var settle := clampf(aim_settle / Balance.AIM_SETTLE_TIME, 0.0, 1.0)
		spread = lerpf(spread * 3.0, spread * 0.35, settle)
	return spread


func _update_weapon(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			in_mag = Balance.MAG_SIZE
			_emit_ammo()

	if not input_enabled:
		return

	aiming = Input.is_action_pressed("aim")
	if drive == Enums.Drive.STOPPED:
		aim_settle = minf(aim_settle + delta, Balance.AIM_SETTLE_TIME)
	else:
		aim_settle = 0.0
	EventBus.aim_changed.emit(aiming, aim_settle / Balance.AIM_SETTLE_TIME, can_fire())

	if Input.is_action_just_pressed("reload") and in_mag < Balance.MAG_SIZE and reload_timer <= 0.0:
		reload_timer = Balance.RELOAD_TIME
		_emit_ammo()
	if Input.is_action_just_pressed("fire"):
		_try_fire()


func _try_fire() -> void:
	if reload_timer > 0.0:
		return
	if in_mag <= 0:
		reload_timer = Balance.RELOAD_TIME
		_emit_ammo()
		return
	var spread := current_spread()
	if spread < 0.0:
		EventBus.notify("굴리는 중에는 쏠 수 없다 — 멈추거나 엄마를 불러라", Color(1.0, 0.72, 0.3))
		return
	if fire_cooldown > 0.0:
		return

	in_mag -= 1
	fire_cooldown = Balance.FIRE_COOLDOWN
	_muzzle_timer = 0.05
	_recoil_pitch = Balance.RECOIL_PITCH
	_emit_ammo()

	# 정지 상태에서 쏘면 반동으로 뒤로 조금 밀린다 (병맛 물리).
	if drive == Enums.Drive.STOPPED:
		velocity += back_direction() * Balance.RECOIL_PUSHBACK

	# 연습 과녁을 맞힌 총성은 주민을 놀라게 하지 않는다.
	# 튜토리얼이 수배 단계를 올리면 배우는 행위 자체가 벌이 된다.
	var alarming := _cast_bullet(spread)
	EventBus.weapon_fired.emit(spread, alarming)


## 총알을 쏜다. 주변에 알람이 되어야 하면 true.
func _cast_bullet(spread_deg: float) -> bool:
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	if spread_deg > 0.0:
		var rad := deg_to_rad(spread_deg)
		dir = dir.rotated(camera.global_transform.basis.y, randf_range(-rad, rad))
		dir = dir.rotated(camera.global_transform.basis.x, randf_range(-rad, rad))
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + dir * Balance.WEAPON_RANGE, RAY_MASK
	)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		LoopManager.report_threat("빗나간 총성")
		return true
	var collider: Object = hit["collider"]
	var point: Vector3 = hit["position"]
	if collider is TargetBoard:
		(collider as TargetBoard).take_bullet(Balance.BULLET_DAMAGE, point)
		return false
	if collider != null and collider.has_method("take_bullet"):
		var body := collider as Node3D
		var head: bool = body != null and point.y - body.global_position.y > 1.45
		collider.take_bullet(Balance.BULLET_DAMAGE * (Balance.HEADSHOT_MULT if head else 1.0), point)
		return true
	LoopManager.report_threat("빗나간 총성")
	return true


func _emit_ammo() -> void:
	EventBus.ammo_changed.emit(in_mag, Balance.MAG_SIZE, reload_timer > 0.0)


# --- 피격 -------------------------------------------------------------------


func take_damage(amount: float, from_position: Vector3, cause: String, slot_id: String) -> void:
	if not alive:
		return
	hp = maxf(0.0, hp - amount)
	_hit_flash = 0.35
	EventBus.player_damaged.emit(amount, hp, from_position)
	if hp <= 0.0:
		die(cause, slot_id)


func die(cause: String, slot_id: String) -> void:
	if not alive:
		return
	alive = false
	# 죽음이 곧 정보다. 나를 죽인 자의 정체가 다음 루프로 넘어간다.
	if slot_id != "" and GameState.is_killer(slot_id):
		GameState.learn(slot_id, "이 루프에서 나를 죽였다")
	EventBus.player_died.emit(cause, slot_id)
	LoopManager.end_loop(Enums.LoopEnd.KILLED, {"cause": cause, "slot_id": slot_id})


# --- 레일 -------------------------------------------------------------------


func enter_rail(direction: Vector3) -> void:
	on_rail = true
	rail_dir = direction.normalized()
	EventBus.mom_action.emit("난간 타기!")


func exit_rail() -> void:
	on_rail = false


func eye_position() -> Vector3:
	return camera.global_position


## 루프를 되감는다. 병원에서 다시 깨어난 상태.
func reset_for_loop(spawn: Vector3) -> void:
	alive = true
	hp = Balance.PLAYER_MAX_HP
	velocity = Vector3.ZERO
	global_position = spawn
	chair_yaw = Balance.SPAWN_YAW
	look_yaw = Balance.SPAWN_YAW
	look_pitch = 0.0
	drive = Enums.Drive.STOPPED
	on_rail = false
	aim_settle = 0.0
	fire_cooldown = 0.0
	reload_timer = 0.0
	in_mag = Balance.MAG_SIZE
	_recoil_pitch = 0.0
	_emit_ammo()
	EventBus.drive_changed.emit(drive)


## 휠체어의 정면 / 후면 (수평 성분만). 엄마와 러너가 뒤를 계산할 때 쓴다.
func forward_direction() -> Vector3:
	return Vector3(-sin(chair_yaw), 0.0, -cos(chair_yaw))


func back_direction() -> Vector3:
	return Vector3(sin(chair_yaw), 0.0, cos(chair_yaw))
