class_name ActionHint
extends Control

## 조준선 위에 뜨는 상태 기호. 이 게임의 핵심 규칙 하나를 계속 그림으로 말한다.
##
##   지금 쏠 수 있는가? 없다면 무엇을 해야 하는가?
##
## 문장으로 쓰면 아무도 안 읽는다. 상태가 바뀌는 순간 그림이 바뀌면 읽지 않아도 알게 된다.

const ICON := 44.0
const GAP := 14.0

var player: WheelchairPlayer = null

var _font: Font
var _blocked_flash: float = 0.0
var _stuck: float = 0.0
var _pulse: float = 0.0


static func create(target: WheelchairPlayer, font: Font) -> ActionHint:
	var h := ActionHint.new()
	h.set_script(load("res://scripts/ui/action_hint.gd"))
	h.name = "ActionHint"
	h.player = target
	h._font = font
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.custom_minimum_size = Vector2(560.0, 120.0)
	return h


func _ready() -> void:
	EventBus.loop_started.connect(func(_i: int) -> void: _stuck = 0.0)


func _process(delta: float) -> void:
	if player == null:
		return
	# 기호 중심이 조준선 바로 위 78px 에 오도록 놓는다. 너무 멀면 시선이 안 닿는다.
	var vp := get_viewport_rect().size
	size = custom_minimum_size
	position = Vector2(vp.x * 0.5 - size.x * 0.5, vp.y * 0.5 - size.y * 0.5 - 78.0)

	_pulse = fmod(_pulse + delta * 2.6, TAU)
	_blocked_flash = maxf(0.0, _blocked_flash - delta)

	# 굴리려는데 못 나아가고 있다 — 턱이나 계단에 걸린 것이다.
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.drive == Enums.Drive.SELF and speed < 0.4:
		_stuck = minf(_stuck + delta, 3.0)
	else:
		_stuck = maxf(0.0, _stuck - delta * 2.0)

	# 못 쏘는 상태에서 방아쇠를 당겼다 — 대안을 보여줄 순간.
	if player.input_enabled and Input.is_action_just_pressed("fire") and player.current_spread() < 0.0:
		_blocked_flash = 2.2

	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var green := Color(0.45, 1.0, 0.58, 0.98)
	var amber := Color(1.0, 0.82, 0.38, 0.98)
	var red := Color(1.0, 0.42, 0.36, 1.0)
	var mid := size * 0.5

	# 밝은 배경에서도 기호가 죽지 않도록 뒤에 어두운 판을 깐다.
	var icons := 1 if player.drive == Enums.Drive.STOPPED else 2
	var plate := ICON * float(icons) + GAP * float(icons - 1) + 26.0
	draw_rect(
		Rect2(mid.x - plate * 0.5, mid.y - ICON * 0.5 - 11.0, plate, ICON + 22.0),
		Color(0.04, 0.05, 0.07, 0.5),
		true
	)

	match player.drive:
		Enums.Drive.STOPPED:
			_row([_icon_gun(green)], mid, 1.0)
		Enums.Drive.COAST:
			_row([_icon_wheel(amber), _icon_gun(green)], mid, 1.0)
		Enums.Drive.PUSHED:
			_row([_icon_mom(green), _icon_gun(green)], mid, 1.0)
		Enums.Drive.CARRIED:
			_row([_icon_stairs(amber), _icon_gun_blocked(red)], mid, 1.0)
		Enums.Drive.SELF:
			_row([_icon_wheel(amber), _icon_gun_blocked(red)], mid, 1.0)

	# 대안 제시: 손을 떼고 멈추거나(정지 기호), 엄마를 부르거나(Shift + 미는 그림).
	var show_alt := _blocked_flash > 0.0 or _stuck > 0.8
	if show_alt and player.drive != Enums.Drive.PUSHED:
		var alpha := 0.55 + 0.45 * sin(_pulse)
		_draw_alternative(Color(0.65, 0.92, 1.0, alpha))


## 아이콘을 가로로 가운데 정렬해서 그린다.
func _row(icons: Array, center: Vector2, scale: float) -> void:
	var total := ICON * scale * float(icons.size()) + GAP * float(icons.size() - 1)
	var x := center.x - total * 0.5 + ICON * scale * 0.5
	for icon: Callable in icons:
		icon.call(Vector2(x, center.y), ICON * scale)
		x += ICON * scale + GAP


func _icon_wheel(color: Color) -> Callable:
	return func(at: Vector2, s: float) -> void: Pictogram.wheel(self, at, s, color)


func _icon_gun(color: Color) -> Callable:
	return func(at: Vector2, s: float) -> void: Pictogram.gun(self, at, s, color)


func _icon_gun_blocked(color: Color) -> Callable:
	return (
		func(at: Vector2, s: float) -> void:
			Pictogram.gun(self, at, s, Color(color.r, color.g, color.b, 0.45))
			Pictogram.forbid(self, at, s, color)
	)


func _icon_mom(color: Color) -> Callable:
	return func(at: Vector2, s: float) -> void: Pictogram.mom_push(self, at, s, color)


func _icon_stairs(color: Color) -> Callable:
	return func(at: Vector2, s: float) -> void: Pictogram.stairs(self, at, s, color)


## "이렇게 하면 된다" 줄. Shift 키캡 + 미는 그림.
func _draw_alternative(color: Color) -> void:
	var y := size.y * 0.5 + ICON * 0.85
	var cap_h := 30.0
	var cap_w := _font.get_string_size("Shift", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + cap_h * 0.55
	var total := cap_w + 10.0 + 26.0 + 10.0 + ICON
	var x := size.x * 0.5 - total * 0.5
	Pictogram.keycap(self, _font, Vector2(x, y - cap_h * 0.5), "Shift", cap_h, color)
	x += cap_w + 10.0
	# 더하기 기호
	draw_line(Vector2(x + 5.0, y), Vector2(x + 21.0, y), color, 3.0, true)
	draw_line(Vector2(x + 13.0, y - 8.0), Vector2(x + 13.0, y + 8.0), color, 3.0, true)
	x += 26.0 + 10.0 + ICON * 0.5
	Pictogram.mom_push(self, Vector2(x, y), ICON, color)
