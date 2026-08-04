class_name StairLift
extends Node3D

## 계단 구간 표식. 휠체어는 계단을 스스로 오를 수 없으므로 (문서 8절/10절)
## 엄마가 들어올려야 한다. 아래/위 지점만 들고 있고 실제 이동은 Mom 이 수행한다.

@export var bottom: Vector3 = Vector3.ZERO
@export var top: Vector3 = Vector3.ZERO


static func create(bottom_point: Vector3, top_point: Vector3) -> StairLift:
	var s := StairLift.new()
	s.set_script(load("res://scripts/world/stair_lift.gd"))
	s.bottom = bottom_point
	s.top = top_point
	s.name = "StairLift"
	return s


func _ready() -> void:
	add_to_group("stair_lift")
	# 글자 대신 키캡과 계단 모양으로 알린다.
	Build.key_prompt(self, "P", bottom + Vector3(0.0, 1.7, 0.6))


func bottom_point() -> Vector3:
	return bottom


func top_point() -> Vector3:
	return top
