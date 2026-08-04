class_name EscapeZone
extends Area3D

## 탈출 지점 (문서 4절).
##
## 모든 킬러를 제거했다면 잠깐 머무는 것만으로 엔딩이다.
## 하지만 한 명이라도 남아 있으면 남은 킬러 전원이 이 지점을 둘러싸고 등장한다.
## "탈출 지점으로 달리는 게임이 아니라, 도착하기 전에 모든 위협을 제거하는 게임이다."

var _hold: float = 0.0
var _ambush_fired: bool = false
var _player_inside: bool = false


static func create(pos: Vector3, radius: float) -> EscapeZone:
	var z := EscapeZone.new()
	z.set_script(load("res://scripts/world/escape_zone.gd"))
	z.name = "EscapeZone"
	z.collision_layer = Build.LAYER_TRIGGER
	z.collision_mask = Build.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 6.0
	cs.shape = shape
	z.add_child(cs)
	z.position = pos
	return z


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	set_process(true)


func _on_entered(body: Node3D) -> void:
	if body is WheelchairPlayer:
		_player_inside = true


func _on_exited(body: Node3D) -> void:
	if body is WheelchairPlayer:
		_player_inside = false
		_hold = 0.0
		EventBus.escape_progress.emit(0.0)


func _process(delta: float) -> void:
	if not _player_inside or not GameState.loop_active:
		return

	if not GameState.all_killers_down():
		if not _ambush_fired:
			_ambush_fired = true
			_spring_ambush()
		return

	_hold += delta
	EventBus.escape_progress.emit(clampf(_hold / Balance.ESCAPE_HOLD_TIME, 0.0, 1.0))
	if _hold >= Balance.ESCAPE_HOLD_TIME:
		LoopManager.end_loop(Enums.LoopEnd.ESCAPED, {"loop": GameState.loop_index})


func _spring_ambush() -> void:
	var remaining := GameState.remaining_killer_slots()
	EventBus.escape_ambush_triggered.emit(remaining.size())
	EventBus.notify(
		"남은 킬러 %d 명이 탈출 지점을 둘러쌌다!" % remaining.size(), Color(1.0, 0.25, 0.25)
	)
	var index := 0
	for node: Node in get_tree().get_nodes_in_group("npc"):
		var npc := node as Npc
		if npc == null or not remaining.has(npc.slot_id):
			continue
		var angle := TAU * (float(index) / float(maxi(1, remaining.size())))
		npc.ambush_at(global_position, angle, Balance.ESCAPE_AMBUSH_RADIUS)
		index += 1


## 루프 리셋 시 매복 상태도 되감는다.
func rearm() -> void:
	_ambush_fired = false
	_hold = 0.0
	_player_inside = false
