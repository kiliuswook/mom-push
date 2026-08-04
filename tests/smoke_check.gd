extends Node3D

## 헤드리스 통합 점검. `--headless` 로 실행하면 결과를 찍고 종료 코드로 성공/실패를 알린다.
##   godot --headless --path . tests/smoke_check.tscn

var _pass: int = 0
var _fail: int = 0
var _main: Node3D


func _ready() -> void:
	await get_tree().process_frame
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	for i: int in 30:
		await get_tree().physics_frame
	await _run()
	print("\n=== 스모크 점검: %d 통과 / %d 실패 ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass += 1
		print("  [OK]   %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s" % label)


func _run() -> void:
	var player: WheelchairPlayer = _main.get("player")
	var mom: Mom = _main.get("mom")
	var town: Town = _main.get("town")

	print("\n-- 부트스트랩 --")
	_check("플레이어 생성", player != null and player.alive)
	_check("엄마 생성", mom != null)
	_check("마을 생성", town != null)
	_check("카메라 활성", player != null and player.camera != null and player.camera.current)

	print("\n-- 킬러 배치 (시드 %d) --" % GameState.run_seed)
	_check("킬러 6명 배치", GameState.total_killers() == Balance.KILLER_SLOT_COUNT)
	var npcs := get_tree().get_nodes_in_group("npc")
	_check("NPC %d 명 스폰" % NpcCatalog.SLOTS.size(), npcs.size() == NpcCatalog.SLOTS.size())
	var types: Array = GameState.assignments.values()
	_check("킬러 타입이 전부 다름", types.size() == _unique_count(types))
	for slot_id: String in GameState.assignments.keys():
		print(
			"    · %s = %s"
			% [slot_id, NpcCatalog.killer_name(GameState.assignments[slot_id])]
		)

	print("\n-- 루프 시작 유예 --")
	_check("루프 시작 직후 유예 적용", LoopManager.grace_active())
	_check("유예 중에는 아무도 정체를 드러내지 않음", GameState.known_count() == 0)

	print("\n-- 지형 --")
	_check("시작 지점 지면 y=0", _ground_height(Vector3(0.0, 3.0, 0.0)) < 0.05)
	_check("상점가 지면 존재", _ground_height(Vector3(0.0, 3.0, 66.0)) < 0.05)
	_check("광장 지면 존재", _ground_height(Vector3(8.0, 3.0, 138.0)) < 0.05)
	_check("광장 분수 엄폐물", absf(_ground_height(Vector3(0.0, 3.0, 131.0)) - 0.8) < 0.1)
	_check("옥상 지면 y≈9.4", absf(_ground_height(Vector3(14.0, 12.0, 106.0)) - 9.4) < 0.2)
	_check("발코니 지면 y≈6.4", absf(_ground_height(Vector3(-11.6, 9.0, 96.0)) - 6.4) < 0.2)
	_check("계단 리프트 등록", get_tree().get_nodes_in_group("stair_lift").size() == 1)

	print("\n-- 이동/사격 제약 (문서 8절) --")
	_check("초기 상태 = 정지", player.drive == Enums.Drive.STOPPED)
	_check("정지 상태 사격 가능", player.current_spread() >= 0.0)
	player.drive = Enums.Drive.SELF
	_check("직접 굴리는 중 사격 불가", player.current_spread() < 0.0)
	player.drive = Enums.Drive.COAST
	_check("관성 롤 중 사격 가능", player.current_spread() >= 0.0)
	player.drive = Enums.Drive.PUSHED
	_check("엄마가 미는 중 사격 가능", player.current_spread() >= 0.0)
	player.drive = Enums.Drive.CARRIED
	_check("들려 있는 중 사격 불가", player.current_spread() < 0.0)
	player.drive = Enums.Drive.STOPPED

	print("\n-- 실제 이동 (물리 시뮬레이션) --")
	player.reset_for_loop(Town.START_POSITION)
	player.input_enabled = true
	await _hold("move_forward", 45)
	var self_travel := player.global_position.z - Town.START_POSITION.z
	var self_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check("직접 굴려서 앞으로 전진 (%.2fm)" % self_travel, self_travel > 0.6)
	_check("자체 추진 속도가 제한됨 (%.2f m/s)" % self_speed, self_speed <= Balance.SELF_MAX_SPEED + 0.2)
	_check("굴리는 동안 상태 = SELF", player.drive == Enums.Drive.SELF)

	await _hold("", 40)
	_check("입력을 떼면 관성 롤 또는 정지", player.drive != Enums.Drive.SELF)

	player.reset_for_loop(Town.START_POSITION)
	mom.reset_for_loop(Town.START_POSITION + Vector3(0.0, 0.0, -1.2))
	Input.action_press("call_mom")
	await _wait(25)
	_check("엄마가 손잡이를 잡음", mom.is_gripping())
	await _hold("move_forward", 60, false)
	var push_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check("밀리는 중 상태 = PUSHED", player.drive == Enums.Drive.PUSHED)
	_check(
		"밀기가 자체 추진보다 빠름 (%.2f > %.2f)" % [push_speed, Balance.SELF_MAX_SPEED],
		push_speed > Balance.SELF_MAX_SPEED + 0.5
	)
	_check("밀리는 중에도 사격 가능", player.current_spread() >= 0.0)
	Input.action_release("call_mom")
	Input.action_release("move_forward")
	await _wait(5)

	player.reset_for_loop(Town.START_POSITION)
	mom.reset_for_loop(Town.START_POSITION + Vector3(0.0, 0.0, -1.2))
	await _wait(3)

	print("\n-- 비언어 안내 --")
	var boards := get_tree().get_nodes_in_group("target_board")
	_check("병원에 연습 과녁 3개", boards.size() == 3)
	var wanted_before := GameState.wanted
	if boards.size() > 0:
		var board := boards[0] as TargetBoard
		board.take_bullet(10.0, board.global_position)
		await _wait(2)
		_check("과녁 사격은 수배를 올리지 않음", GameState.wanted == wanted_before)
	var guide := town.find_child("GuidePath", false, false)
	_check("바닥 유도 화살표 생성", guide != null)
	var prompts := 0
	for node: Node in get_tree().get_nodes_in_group("stair_lift"):
		prompts += node.get_child_count()
	_check("계단에 키캡 안내 배치", prompts > 0)
	_check("시작 시 시간 배율 정상", is_equal_approx(Engine.time_scale, 1.0))

	print("\n-- 한국어 조사 --")
	_check("받침 있음 -> 이", Josa.subject("청소부") == "청소부가" and Josa.subject("피자 배달분") == "피자 배달분이")
	_check("받침 없음 -> 가", Josa.subject("운전자") == "운전자가")
	_check("영문 약어 SWAT -> 이", Josa.subject("SWAT") == "SWAT이")
	_check("을/를", Josa.object("킬러") == "킬러를" and Josa.object("경찰") == "경찰을")

	print("\n-- 차량 킬러 도로 구속 --")
	var vehicle: Npc = null
	for id: String in NpcCatalog.VEHICLE_SLOTS:
		var v := _find_npc(id)
		if v != null:
			vehicle = v
			break
	_check("차량 NPC 존재", vehicle != null)
	if vehicle != null:
		vehicle.global_position = Vector3(0.0, 0.4, 2.0)  # 병원 로비로 강제 이동
		await _wait(4)
		var inside_road := (
			absf(vehicle.global_position.x) <= Balance.ROAD_HALF_WIDTH + 0.01
			and vehicle.global_position.z >= Balance.ROAD_Z_MIN - 0.01
			and vehicle.global_position.z <= Balance.ROAD_Z_MAX + 0.01
		)
		_check("병원으로 밀어넣어도 도로로 되돌아옴 (z=%.1f)" % vehicle.global_position.z, inside_road)
		vehicle.ambush_at(Vector3(0.0, 0.4, 152.0), 0.0, 8.0)
		await _wait(4)
		_check("탈출 지점 매복 때는 도로 구속 해제", vehicle.global_position.z > 140.0)

	print("\n-- 킬러 판별 / 지식 --")
	# 유예가 끝난 뒤라 근처 킬러는 이미 정체를 드러냈을 수 있다. 아직 모르는 쪽을 고른다.
	var killer_slot: String = ""
	for id: String in GameState.assignments.keys():
		if not GameState.is_known(id):
			killer_slot = id
			break
	_check("아직 정체를 모르는 킬러가 남아 있음", killer_slot != "")
	var killer := _find_npc(killer_slot)
	_check("킬러 NPC 조회", killer != null)
	if killer != null:
		var down_before := GameState.killers_down.size()
		killer.take_bullet(Balance.NPC_MAX_HP + 1.0, killer.global_position)
		await get_tree().physics_frame
		_check("킬러 처치 시 진행도 증가", GameState.killers_down.size() == down_before + 1)
		_check("킬러 처치 시 지식 획득", GameState.is_known(killer_slot))
		_check("수배 단계는 그대로", GameState.wanted == Enums.Wanted.CLEAR)

	print("\n-- 민간인 오인 사격 -> 수배 (문서 7절) --")
	var civilian := _find_civilian()
	_check("민간인 NPC 조회", civilian != null)
	if civilian != null:
		civilian.take_bullet(Balance.NPC_MAX_HP + 1.0, civilian.global_position)
		await get_tree().physics_frame
		_check("민간인 사살 -> 경찰 출동", GameState.wanted == Enums.Wanted.POLICE)
		LoopManager.report_kill(Enums.NpcKind.POLICE)
		_check("경찰 사살 -> SWAT", GameState.wanted == Enums.Wanted.SWAT)
		LoopManager.report_kill(Enums.NpcKind.SWAT)
		_check("SWAT 사살 -> 헬기", GameState.wanted == Enums.Wanted.HELI)
		LoopManager.report_heli_destroyed()
		_check("헬기 격추 -> 전투기", GameState.wanted == Enums.Wanted.JET)
		_check("전투기 카운트다운 시작", LoopManager.jet_time_left() > 0.0)

	print("\n-- 탈출 판정 (문서 4절) --")
	_check("킬러가 남아 있음", not GameState.all_killers_down())
	for slot_id: String in GameState.assignments.keys():
		GameState.register_killer_down(slot_id)
	_check("전원 제거 시 탈출 가능", GameState.all_killers_down())

	print("\n-- 타임루프 --")
	var known_before := GameState.known_count()
	var seed_before := GameState.run_seed
	var assignments_before := GameState.assignments.duplicate()
	LoopManager.end_loop(Enums.LoopEnd.KILLED, {"cause": "테스트"})
	_check("루프 종료 처리", not GameState.loop_active)
	LoopManager.advance_loop()
	town.reset_for_loop()
	player.reset_for_loop(Town.START_POSITION)
	await get_tree().physics_frame
	_check("루프 인덱스 증가", GameState.loop_index == 2)
	_check("지식은 유지", GameState.known_count() == known_before)
	_check("배치 시드 유지", GameState.run_seed == seed_before)
	_check("킬러 배치 유지", GameState.assignments == assignments_before)
	_check("처치 기록은 초기화", GameState.killers_down.is_empty())
	_check("수배 단계 초기화", GameState.wanted == Enums.Wanted.CLEAR)
	_check("NPC 재스폰", get_tree().get_nodes_in_group("npc").size() == NpcCatalog.SLOTS.size())
	_check("플레이어 부활", player.alive and is_equal_approx(player.hp, Balance.PLAYER_MAX_HP))

	print("\n-- 새 판 --")
	GameState.start_new_run(12345)
	_check("새 판에서 지식 초기화", GameState.known_count() == 0)
	_check("새 판에서도 킬러 6명", GameState.total_killers() == Balance.KILLER_SLOT_COUNT)
	GameState.start_new_run(12345)
	var repeat := GameState.assignments.duplicate()
	GameState.start_new_run(12345)
	_check("같은 시드 = 같은 배치 (결정론)", GameState.assignments == repeat)


# --- 보조 -------------------------------------------------------------------


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


## 액션을 누른 채로 N 프레임 진행한다. release=false 면 계속 누르고 있는다.
func _hold(action: String, frames: int, release: bool = true) -> void:
	if action != "":
		Input.action_press(action)
	await _wait(frames)
	if action != "" and release:
		Input.action_release(action)


func _unique_count(values: Array) -> int:
	var seen: Array = []
	for v: Variant in values:
		if not seen.has(v):
			seen.append(v)
	return seen.size()


func _ground_height(from: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, Build.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -999.0
	var point: Vector3 = hit["position"]
	return point.y


func _find_npc(slot_id: String) -> Npc:
	for node: Node in get_tree().get_nodes_in_group("npc"):
		var npc := node as Npc
		if npc != null and npc.slot_id == slot_id:
			return npc
	return null


func _find_civilian() -> Npc:
	for node: Node in get_tree().get_nodes_in_group("npc"):
		var npc := node as Npc
		if npc != null and npc.kind == Enums.NpcKind.CIVILIAN:
			return npc
	return null
