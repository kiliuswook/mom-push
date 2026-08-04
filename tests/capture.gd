extends Node3D

## 개발용 스크린샷 캡처. 구역별로 한 장씩 찍고 종료한다.
##   godot --path . tests/capture.tscn -- <출력_폴더>

const F := PI  # 루트 진행 방향(+Z)을 보는 yaw

const SHOTS := [
	{"name": "1_hospital", "pos": Vector3(0.0, 0.3, 0.0), "yaw": F, "pitch": 0.0},
	{"name": "2_road", "pos": Vector3(0.0, 0.3, 20.0), "yaw": F, "pitch": -0.05},
	{"name": "3_shops", "pos": Vector3(0.0, 0.3, 52.0), "yaw": F, "pitch": 0.0},
	{"name": "4_houses", "pos": Vector3(0.0, 0.3, 90.0), "yaw": F + 0.55, "pitch": 0.42},
	{"name": "5_stairs", "pos": Vector3(2.0, 0.3, 86.0), "yaw": F - 0.30, "pitch": 0.30},
	{"name": "6_plaza", "pos": Vector3(0.0, 0.3, 118.0), "yaw": F, "pitch": 0.02},
	{"name": "7_escape", "pos": Vector3(0.0, 0.3, 142.0), "yaw": F, "pitch": 0.05},
	{"name": "8_rooftop", "pos": Vector3(11.0, 9.7, 100.0), "yaw": F + 1.9, "pitch": -0.28},
]

var _out_dir: String = "."


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i: int in 40:
		await get_tree().physics_frame
	var player: WheelchairPlayer = main.get("player")
	for shot: Dictionary in SHOTS:
		player.global_position = shot["pos"]
		player.chair_yaw = shot["yaw"]
		player.look_yaw = shot["yaw"]
		player.look_pitch = shot["pitch"]
		player.velocity = Vector3.ZERO
		for i: int in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [_out_dir, String(shot["name"])]
		image.save_png(path)
		print("saved %s" % path)
	get_tree().quit(0)
