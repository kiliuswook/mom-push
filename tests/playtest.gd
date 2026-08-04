extends Node3D

## 조작감 계측. "느낌"을 숫자로 바꿔서 튜닝 전후를 비교한다.
##   godot --headless --path . tests/playtest.tscn
##
## 특히 중요한 지표는 F — 마우스를 돌리고 전진했을 때 실제로 그 방향으로
## 가기까지 걸리는 시간이다. 이게 길면 "회전이 답답하다"로 체감된다.

## 계측용 빈 직선 구간 (병원 앞 도로).
const TEST_SPOT := Vector3(0.0, 0.4, 20.0)

var _player: WheelchairPlayer
var _mom: Mom
var _main: Node3D


func _ready() -> void:
	await get_tree().process_frame
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	for i: int in 20:
		await get_tree().physics_frame
	_player = _main.get("player")
	_mom = _main.get("mom")
	_player.input_enabled = true
	# 계측 중에 킬러에게 죽으면 루프가 끝나면서 트리가 멈춰 모든 수치가 0 이 된다.
	for node: Node in get_tree().get_nodes_in_group("npc"):
		node.queue_free()
	await get_tree().physics_frame

	print("\n=========== 조작감 계측 ===========")
	await _measure_turn_in_place()
	await _measure_acceleration()
	await _measure_coast()
	await _measure_steer_latency()
	await _measure_brake()
	await _measure_push_delta()
	print("===================================\n")
	get_tree().quit(0)


# --- 계측 -------------------------------------------------------------------


func _measure_turn_in_place() -> void:
	await _reset()
	var start := _player.chair_yaw
	var t := 0.0
	Input.action_press("move_left")
	while absf(angle_difference(start, _player.chair_yaw)) < PI - 0.05 and t < 8.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_left")
	print("A. 제자리 180도 회전 (A키)          : %.2f 초" % t)


func _measure_acceleration() -> void:
	await _reset()
	await _hold_for("move_forward", 1.0)
	var self_speed := _speed()
	Input.action_release("move_forward")

	await _reset()
	Input.action_press("call_mom")
	await _wait(0.6)
	await _hold_for("move_forward", 1.0)
	var push_speed := _speed()
	Input.action_release("move_forward")
	Input.action_release("call_mom")
	print("B. 1초 후 속도 — 자력                : %.2f m/s" % self_speed)
	print("C. 1초 후 속도 — 엄마 밀기           : %.2f m/s  (%.1f배)" % [push_speed, push_speed / maxf(self_speed, 0.01)])


func _measure_coast() -> void:
	await _reset()
	await _hold_for("move_forward", 2.5)
	Input.action_release("move_forward")
	var from := _player.global_position
	var t := 0.0
	while _speed() > Balance.STOP_THRESHOLD and t < 12.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	print("D. 자력 관성 활주                    : %.2f 초 / %.1f m" % [t, from.distance_to(_player.global_position)])

	await _reset()
	Input.action_press("call_mom")
	await _wait(0.6)
	await _hold_for("move_forward", 2.5)
	Input.action_release("move_forward")
	var from2 := _player.global_position
	var t2 := 0.0
	while _speed() > Balance.STOP_THRESHOLD and t2 < 15.0:
		await get_tree().physics_frame
		t2 += get_physics_process_delta_time()
	Input.action_release("call_mom")
	print("E. 밀기 관성 활주                    : %.2f 초 / %.1f m" % [t2, from2.distance_to(_player.global_position)])


## 마우스로 90도 돌아본 뒤 전진 — 실제로 그 방향으로 가기까지.
func _measure_steer_latency() -> void:
	for pushed: bool in [false, true]:
		await _reset()
		if pushed:
			Input.action_press("call_mom")
			await _wait(0.6)
		_player.look_yaw = _player.chair_yaw + PI * 0.5
		var t := 0.0
		Input.action_press("move_forward")
		while absf(angle_difference(_player.chair_yaw, _player.look_yaw)) > 0.12 and t < 8.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		Input.action_release("move_forward")
		Input.action_release("call_mom")
		print(
			"F. 시야 90도 전환 후 추종 %s: %.2f 초"
			% ["(밀기)  " if pushed else "(자력)  ", t]
		)


func _measure_brake() -> void:
	await _reset()
	Input.action_press("call_mom")
	await _wait(0.6)
	await _hold_for("move_forward", 2.5)
	Input.action_release("move_forward")
	var from := _player.global_position
	var t := 0.0
	Input.action_press("brake")
	while _speed() > Balance.STOP_THRESHOLD and t < 8.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("brake")
	Input.action_release("call_mom")
	print("G. 급정지 (Ctrl, 밀기 중)            : %.2f 초 / %.1f m" % [t, from.distance_to(_player.global_position)])


## 엄마 밀기가 실제로 무엇을 바꾸는지 항목별로 나열한다.
func _measure_push_delta() -> void:
	print("H. 엄마 밀기가 바꾸는 것")
	print("   - 최고 속도   : %.1f -> %.1f m/s" % [Balance.SELF_MAX_SPEED, Balance.PUSH_MAX_SPEED])
	print("   - 가속        : %.1f -> %.1f m/s^2" % [Balance.SELF_ACCEL, Balance.PUSH_ACCEL])
	print("   - 제자리 회전 : %.1f -> %.1f rad/s" % [Balance.TURN_SPEED_PIVOT, Balance.TURN_SPEED_PUSH_PIVOT])
	print("   - 고속 회전   : %.1f -> %.1f rad/s" % [Balance.TURN_SPEED_ROLLING, Balance.TURN_SPEED_PUSH_ROLLING])
	print("   - 사격        : 불가 -> 가능")
	print("   - 점프/턱넘기 : 불가 -> 가능")
	await _reset()
	Input.action_press("call_mom")
	await _wait(0.8)
	await _hold_for("move_forward", 1.2)
	print("   - 시야각(FOV) : %.1f -> %.1f (속도감)" % [Balance.FOV_BASE, _player.camera.fov])
	print("   - 첫 밀침     : +%.1f m/s 순간 추진" % Balance.PUSH_LURCH)
	print("   - 발걸음 리듬 : %.1f Hz, 속도 ±%.0f%%" % [Balance.PUSH_STRIDE_HZ, Balance.PUSH_STRIDE_SURGE * 100.0])
	Input.action_release("move_forward")
	Input.action_release("call_mom")


# --- 보조 -------------------------------------------------------------------


func _speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _reset() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "call_mom", "brake"]:
		Input.action_release(action)
	# 병원 안은 벽이 가까워 활주 거리를 못 잰다. 도로의 빈 직선 구간에서 잰다.
	_player.reset_for_loop(TEST_SPOT)
	_mom.reset_for_loop(TEST_SPOT + Vector3(0.0, 0.0, -1.2))
	await _wait(0.35)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _hold_for(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
