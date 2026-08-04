extends Node3D

## 진입점. 액터를 만들고 루프 수명 주기를 배선한다.
##
## 씬 파일은 이것 하나뿐이고 나머지는 전부 코드로 조립된다.
## 프리미티브만 쓰는 프로토타입이라 이 편이 검증과 리뷰가 쉽다.

var player: WheelchairPlayer
var mom: Mom
var town: Town
var hud: Hud
var loop_screen: LoopScreen

var _last_reason: Enums.LoopEnd = Enums.LoopEnd.KILLED
## 사용자가 Esc 로 조작을 놓았는가. OS 마우스 상태를 조회하지 않고 직접 들고 있어야
## 헤드리스 테스트에서도 같은 코드 경로가 돈다.
var _input_released: bool = false


func _ready() -> void:
	randomize()

	player = WheelchairPlayer.create()
	add_child(player)
	player.add_to_group("blast_target")
	player.reset_for_loop(Town.START_POSITION)

	town = Town.create(player)
	add_child(town)

	mom = Mom.create()
	add_child(mom)
	mom.player = player
	# 엄마는 뒤에 선다. 플레이어가 +Z 를 보므로 뒤는 -Z.
	mom.global_position = Town.START_POSITION + Vector3(0.0, 0.0, -1.2)
	player.mom = mom
	_set_input_released(false)

	hud = Hud.create(player)
	add_child(hud)

	loop_screen = LoopScreen.create()
	add_child(loop_screen)
	loop_screen.continue_pressed.connect(_on_continue_pressed)

	EventBus.loop_ending.connect(_on_loop_ending)
	EventBus.loop_reset_requested.connect(_on_loop_reset_requested)
	EventBus.weapon_fired.connect(_on_weapon_fired)

	town.spawn_npcs()
	LoopManager.begin_loop()


func _process(_delta: float) -> void:
	player.input_enabled = not _input_released


func _set_input_released(released: bool) -> void:
	_input_released = released
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE if released else Input.MOUSE_MODE_CAPTURED
	)


func _unhandled_input(event: InputEvent) -> void:
	# 브라우저는 사용자 제스처 없이 포인터 락을 허용하지 않는다.
	# 웹에서는 _ready 의 캡처 요청이 조용히 무시되므로 첫 클릭으로 다시 잡는다.
	# (Esc 로 락이 풀렸을 때도 같은 경로로 복구된다.)
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if not _input_released and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.is_action_just_pressed("toggle_mouse"):
		_set_input_released(not _input_released)
	if Input.is_action_just_pressed("give_up") and GameState.loop_active:
		LoopManager.end_loop(Enums.LoopEnd.GAVE_UP, {})


func _on_weapon_fired(_spread: float, alarming: bool) -> void:
	# 총성은 주변 민간인에게 들린다 (문서 7절).
	# 연습 과녁을 맞힌 총성은 예외 — 배우는 행위가 벌이 되면 안 된다.
	if alarming:
		town.broadcast_gunshot(player.global_position)


func _on_loop_ending(reason: Enums.LoopEnd, _info: Dictionary) -> void:
	_last_reason = reason
	_set_input_released(true)


func _on_loop_reset_requested() -> void:
	loop_screen.show_result(_last_reason, LoopManager.end_info)
	get_tree().paused = true


func _on_continue_pressed() -> void:
	get_tree().paused = false
	if _last_reason == Enums.LoopEnd.ESCAPED:
		# 클리어하면 새 배치로 다시 시작한다. 학습한 지식은 초기화된다.
		GameState.start_new_run()
		LoopManager.begin_loop()
	else:
		LoopManager.advance_loop()
	town.reset_for_loop()
	player.reset_for_loop(Town.START_POSITION)
	mom.reset_for_loop(Town.START_POSITION + Vector3(0.0, 0.0, -1.2))
	_set_input_released(false)
