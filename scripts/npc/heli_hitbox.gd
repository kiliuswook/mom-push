extends StaticBody3D

## 헬기의 피격 판정용 바디. 총알을 받아 본체로 넘긴다.

var owner_heli: Helicopter = null


func take_bullet(damage: float, point: Vector3) -> void:
	if owner_heli != null and is_instance_valid(owner_heli):
		owner_heli.take_bullet(damage, point)
