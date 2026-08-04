extends Node3D

## 월드 키캡용. 항상 카메라를 향하고 위아래로 살짝 떠다닌다.
## 정적인 표지판은 배경으로 묻히지만 움직이는 것은 눈에 들어온다.

var _base_y: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_t += delta * 2.2
	position.y = _base_y + sin(_t) * 0.10
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length() < 0.01:
		return
	rotation.y = atan2(to_cam.x, to_cam.z)
