class_name Mom
extends CharacterBody3D

## 엄마. 뒤에서 휠체어를 밀어주는 사람.
##
## 문서 9절의 P2 역할: 밀기 / 급정지 / 점프 / 계단 이동 / 위험 지역 돌파.
## 싱글 플레이에서는 AUTO 모드로 동작해 P1 의 입력을 그대로 받아 밀어준다.
## Enter (또는 게임패드 START) 로 MANUAL 모드가 되면 두 번째 플레이어가 직접 조작한다.
##
## 설계상 엄마는 암살자들의 표적이 아니다 — 그들이 노리는 것은 휠체어에 앉은 킬러뿐이다.
## 덕분에 P2 는 죽음 관리 대신 이동/돌파에만 집중할 수 있다.

enum State { FOLLOW, GRIP, CARRY }

var manual: bool = false
var state: State = State.FOLLOW
var player: WheelchairPlayer = null

var _carry_from: Vector3 = Vector3.ZERO
var _carry_to: Vector3 = Vector3.ZERO
var _carry_t: float = 0.0
var _jump_latch: bool = false
var _visual: Node3D
var _label: Label3D


static func create() -> Mom:
	var m := Mom.new()
	m.set_script(load("res://scripts/player/mom.gd"))
	m.name = "Mom"
	return m


func _ready() -> void:
	collision_layer = Build.LAYER_PLAYER
	collision_mask = Build.LAYER_WORLD
	floor_max_angle = deg_to_rad(50.0)
	_build_visual()


func _build_visual() -> void:
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.6
	cs.shape = capsule
	cs.position = Vector3(0.0, 0.8, 0.0)
	add_child(cs)

	_visual = Node3D.new()
	add_child(_visual)
	var coat := Color(0.72, 0.36, 0.44)
	var skin := Color(0.92, 0.78, 0.68)
	Build.box(_visual, Vector3(0.52, 0.80, 0.32), Vector3(0.0, 1.02, 0.0), coat, false)
	Build.box(_visual, Vector3(0.42, 0.46, 0.28), Vector3(0.0, 0.40, 0.0), Color(0.30, 0.30, 0.36), false)
	Build.cylinder(_visual, 0.17, 0.30, Vector3(0.0, 1.60, 0.0), skin, false)
	Build.box(_visual, Vector3(0.38, 0.16, 0.30), Vector3(0.0, 1.74, 0.0), Color(0.45, 0.36, 0.32), false)
	# 뻗은 팔 — 손잡이를 잡고 있다는 신호.
	Build.box(_visual, Vector3(0.12, 0.12, 0.55), Vector3(-0.28, 1.10, 0.30), skin, false)
	Build.box(_visual, Vector3(0.12, 0.12, 0.55), Vector3(0.28, 1.10, 0.30), skin, false)

	_label = Build.label(self, "엄마", Vector3(0.0, 2.15, 0.0), 0.28, Color(1.0, 0.85, 0.9))


func _physics_process(delta: float) -> void:
	if player == null or not player.alive:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("mom_join"):
		manual = not manual
		EventBus.mom_mode_changed.emit(manual)
		EventBus.notify(
			"엄마: %s" % ("2P 직접 조작" if manual else "자동 (P1 입력 공유)"), Color(1.0, 0.8, 0.85)
		)

	if Input.is_action_just_pressed("mom_lift"):
		_toggle_carry()

	match state:
		State.FOLLOW:
			_process_follow(delta)
		State.GRIP:
			_process_grip(delta)
		State.CARRY:
			_process_carry(delta)


# --- 상태 -------------------------------------------------------------------


func _process_follow(delta: float) -> void:
	var target := _handle_position()
	var to_target := target - global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 22.0) * delta
	else:
		velocity.y = 0.0
	if flat.length() > 0.25:
		var speed := Balance.MOM_FOLLOW_SPEED
		velocity.x = flat.normalized().x * speed
		velocity.z = flat.normalized().z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	_face(flat)

	var wants_grip := Input.is_action_pressed("call_mom") or (manual and Input.is_action_pressed("mom_push"))
	if wants_grip and global_position.distance_to(target) <= Balance.MOM_GRAB_RANGE:
		state = State.GRIP
		EventBus.mom_grip_changed.emit(true)
		EventBus.notify("엄마가 손잡이를 잡았다 — 밀기 시작", Color(1.0, 0.82, 0.88))


func _process_grip(_delta: float) -> void:
	var hold := Input.is_action_pressed("call_mom") or (manual and Input.is_action_pressed("mom_push"))
	var target := _handle_position()
	global_position = target
	velocity = Vector3.ZERO
	_face(player.global_position - global_position)
	if not hold or global_position.distance_to(player.global_position) > Balance.MOM_LOSE_RANGE:
		state = State.FOLLOW
		EventBus.mom_grip_changed.emit(false)


func _process_carry(delta: float) -> void:
	var span := _carry_from.distance_to(_carry_to)
	if span < 0.05:
		_end_carry()
		return
	_carry_t = clampf(_carry_t + (Balance.CARRY_CLIMB_SPEED / span) * delta, 0.0, 1.0)
	var point := _carry_from.lerp(_carry_to, _carry_t)
	global_position = point - _carry_forward() * 0.8
	velocity = Vector3.ZERO
	_face(_carry_forward())
	if _carry_t >= 1.0:
		_end_carry()


func _toggle_carry() -> void:
	if state == State.CARRY:
		_end_carry()
		return
	var lift := _nearest_lift()
	if lift == null:
		EventBus.notify("여기서는 들어올릴 곳이 없다", Color(0.85, 0.85, 0.9))
		return
	var bottom: Vector3 = lift.bottom_point()
	var top: Vector3 = lift.top_point()
	var at_bottom := player.global_position.distance_to(bottom) <= player.global_position.distance_to(top)
	_carry_from = player.global_position
	_carry_to = top if at_bottom else bottom
	_carry_t = 0.0
	state = State.CARRY
	EventBus.mom_action.emit("엄마가 휠체어를 들었다 — 계단 이동")


func _end_carry() -> void:
	state = State.GRIP if Input.is_action_pressed("call_mom") else State.FOLLOW
	EventBus.mom_grip_changed.emit(state == State.GRIP)


func _nearest_lift() -> Node:
	var best: Node = null
	var best_dist := 6.0
	for node: Node in get_tree().get_nodes_in_group("stair_lift"):
		var lift := node as Node3D
		if lift == null:
			continue
		var d: float = minf(
			player.global_position.distance_to(lift.bottom_point()),
			player.global_position.distance_to(lift.top_point())
		)
		if d < best_dist:
			best_dist = d
			best = lift
	return best


# --- 플레이어가 물어보는 것들 -------------------------------------------------


func is_gripping() -> bool:
	return state == State.GRIP


func is_carrying() -> bool:
	return state == State.CARRY


func get_carry_position() -> Vector3:
	return _carry_from.lerp(_carry_to, _carry_t)


## x = 조향, y = 전진. AUTO 모드에서는 P1 입력을 그대로 되돌려준다.
func get_push_input() -> Vector2:
	if manual:
		return Vector2(
			Input.get_axis("mom_right", "mom_left"), Input.get_axis("mom_back", "mom_forward")
		)
	if player == null or not player.input_enabled:
		return Vector2.ZERO
	return Vector2(Input.get_axis("move_right", "move_left"), Input.get_axis("move_back", "move_forward"))


func wants_brake() -> bool:
	return Input.is_action_pressed("mom_brake")


func wants_jump() -> bool:
	var pressed := Input.is_action_just_pressed("mom_jump")
	if pressed:
		_jump_latch = true
	if _jump_latch:
		_jump_latch = false
		return true
	return false


# --- 보조 -------------------------------------------------------------------


## 손잡이 위치. 휠체어 뒤쪽.
func _handle_position() -> Vector3:
	return player.global_position + player.back_direction() * 0.95


func _carry_forward() -> Vector3:
	var d := _carry_to - _carry_from
	d.y = 0.0
	if d.length() < 0.01:
		return Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	return d.normalized()


## 루프 리셋. 조작 모드(수동/자동)는 유지한다.
func reset_for_loop(spawn: Vector3) -> void:
	state = State.FOLLOW
	velocity = Vector3.ZERO
	global_position = spawn
	_carry_t = 0.0
	_jump_latch = false
	EventBus.mom_grip_changed.emit(false)


func _face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 0.25)
