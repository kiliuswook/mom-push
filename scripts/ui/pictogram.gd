class_name Pictogram
extends RefCounted

## 문장 대신 쓰는 그림 기호. 전부 코드로 그린다.
##
## 규칙 설명을 글로 하면 아무도 읽지 않는다. 특히 "굴리는 중에는 사격 불가" 같은
## 상태 규칙은 그 상태일 때 그림 하나로 보여주는 편이 훨씬 빠르다.
## 여기 있는 함수들은 전부 (그릴 대상, 중심, 크기, 색) 만 받는다.


## 바퀴 — 이동 / 직접 굴리기
static func wheel(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var r := size * 0.5
	ci.draw_arc(at, r, 0.0, TAU, 24, color, size * 0.10, true)
	ci.draw_circle(at, size * 0.08, color)
	for i: int in 6:
		var a := TAU * float(i) / 6.0
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(at + dir * size * 0.11, at + dir * r * 0.88, color, size * 0.055, true)


## 권총 — 사격
static func gun(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	# 총열은 길게 오른쪽으로, 손잡이는 왼쪽 뒤로 기울여야 작게 그려도 총으로 읽힌다.
	var s := size / 32.0
	var body := PackedVector2Array(
		[
			Vector2(-13, -7), Vector2(16, -7), Vector2(16, -2), Vector2(-2, -2),
			Vector2(1, 12), Vector2(-8, 12), Vector2(-10, -2), Vector2(-13, -2),
		]
	)
	var pts := PackedVector2Array()
	for p: Vector2 in body:
		pts.append(at + p * s)
	ci.draw_colored_polygon(pts, color)
	# 방아쇠울 — 총이라는 신호를 하나 더 준다.
	ci.draw_arc(at + Vector2(-4, 2) * s, 4.5 * s, 0.0, PI, 10, color, 1.6 * s, true)


## 금지 사선 — 다른 기호 위에 겹쳐 쓴다
static func forbid(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var r := size * 0.62
	ci.draw_arc(at, r, 0.0, TAU, 24, color, size * 0.09, true)
	var d := Vector2(0.707, -0.707) * r
	ci.draw_line(at - d, at + d, color, size * 0.09, true)


## 엄마가 휠체어를 미는 그림 — 코옵 이동
static func mom_push(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var s := size / 32.0
	var o := at + Vector2(-2.0, 0.0) * s
	# 휠체어 (앞쪽)
	ci.draw_arc(o + Vector2(6, 8) * s, 6.0 * s, 0.0, TAU, 16, color, 1.8 * s, true)
	ci.draw_line(o + Vector2(2, 2) * s, o + Vector2(11, 2) * s, color, 2.0 * s, true)
	ci.draw_line(o + Vector2(2, 2) * s, o + Vector2(2, -6) * s, color, 2.0 * s, true)
	ci.draw_circle(o + Vector2(4, -10) * s, 3.2 * s, color)
	# 미는 사람 (뒤쪽)
	ci.draw_circle(o + Vector2(-11, -10) * s, 3.4 * s, color)
	ci.draw_line(o + Vector2(-11, -6) * s, o + Vector2(-11, 4) * s, color, 2.2 * s, true)
	ci.draw_line(o + Vector2(-11, -4) * s, o + Vector2(-2, -3) * s, color, 2.0 * s, true)
	ci.draw_line(o + Vector2(-11, 4) * s, o + Vector2(-15, 12) * s, color, 2.0 * s, true)
	ci.draw_line(o + Vector2(-11, 4) * s, o + Vector2(-7, 12) * s, color, 2.0 * s, true)


## 계단
static func stairs(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var s := size / 32.0
	var o := at + Vector2(-13, 12) * s
	var w := 8.0 * s
	for i: int in 3:
		var x := o.x + float(i) * w
		var y := o.y - float(i) * w
		ci.draw_line(Vector2(x, y), Vector2(x, y - w), color, 2.2 * s, true)
		ci.draw_line(Vector2(x, y - w), Vector2(x + w, y - w), color, 2.2 * s, true)


## 정지 표지 — 급정지
static func brake(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		pts.append(at + Vector2(cos(a), sin(a)) * size * 0.55)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, size * 0.09, true)
	ci.draw_line(at + Vector2(-size * 0.22, 0.0), at + Vector2(size * 0.22, 0.0), color, size * 0.11, true)


## 위로 튀는 화살표 — 점프
static func jump(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var s := size / 32.0
	ci.draw_line(at + Vector2(0, 12) * s, at + Vector2(0, -8) * s, color, 2.6 * s, true)
	var head := PackedVector2Array(
		[at + Vector2(0, -14) * s, at + Vector2(-7, -5) * s, at + Vector2(7, -5) * s]
	)
	ci.draw_colored_polygon(head, color)
	ci.draw_line(at + Vector2(-9, 14) * s, at + Vector2(9, 14) * s, color, 2.2 * s, true)


## 펼친 수첩 — 기록 / 코덱스
static func codex(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var s := size / 32.0
	ci.draw_line(at + Vector2(0, -11) * s, at + Vector2(0, 11) * s, color, 2.0 * s, true)
	for side: int in [-1, 1]:
		var x := float(side)
		ci.draw_polyline(
			PackedVector2Array(
				[
					at + Vector2(0, -11) * s,
					at + Vector2(13 * x, -8) * s,
					at + Vector2(13 * x, 11) * s,
					at + Vector2(0, 11) * s,
				]
			),
			color,
			2.0 * s,
			true
		)
		for i: int in 2:
			var y := (-2.0 + float(i) * 5.0) * s
			ci.draw_line(at + Vector2(3 * x, y), at + Vector2(10 * x, y), color, 1.4 * s, true)


## 회전 화살표 — 재장전
static func reload(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var r := size * 0.42
	ci.draw_arc(at, r, deg_to_rad(40.0), deg_to_rad(320.0), 20, color, size * 0.11, true)
	var tip := at + Vector2(cos(deg_to_rad(40.0)), sin(deg_to_rad(40.0))) * r
	ci.draw_colored_polygon(
		PackedVector2Array(
			[tip + Vector2(size * 0.16, 0.0), tip + Vector2(-size * 0.10, size * 0.13), tip + Vector2(-size * 0.02, -size * 0.16)]
		),
		color
	)


## 눈 — 관찰 / 판별
static func eye(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var s := size / 32.0
	ci.draw_polyline(
		PackedVector2Array(
			[
				at + Vector2(-15, 0) * s, at + Vector2(-7, -8) * s, at + Vector2(7, -8) * s,
				at + Vector2(15, 0) * s, at + Vector2(7, 8) * s, at + Vector2(-7, 8) * s,
				at + Vector2(-15, 0) * s,
			]
		),
		color,
		2.0 * s,
		true
	)
	ci.draw_circle(at, 4.5 * s, color)


## 키캡. 문장이 아니라 "누를 물건"으로 읽히게 그린다.
static func keycap(
	ci: CanvasItem, font: Font, at: Vector2, label: String, height: float, color: Color
) -> float:
	var font_size := int(height * 0.46)
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := maxf(height, text_width + height * 0.55)
	var rect := Rect2(at, Vector2(width, height))
	ci.draw_rect(rect, Color(color.r, color.g, color.b, 0.14), true)
	ci.draw_rect(rect, color, false, maxf(1.5, height * 0.06))
	var baseline := at + Vector2(
		(width - text_width) * 0.5, height * 0.5 + float(font_size) * 0.36
	)
	ci.draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return width


## 마우스. 강조할 버튼만 채운다. (0 = 좌클릭, 1 = 우클릭)
static func mouse(ci: CanvasItem, at: Vector2, size: float, button: int, color: Color) -> void:
	var w := size * 0.62
	var h := size
	var rect := Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_rect(rect, color, false, maxf(1.5, size * 0.07))
	ci.draw_line(
		Vector2(rect.position.x, rect.position.y + h * 0.42),
		Vector2(rect.position.x + w, rect.position.y + h * 0.42),
		color,
		maxf(1.5, size * 0.07),
		true
	)
	ci.draw_line(
		Vector2(rect.position.x + w * 0.5, rect.position.y),
		Vector2(rect.position.x + w * 0.5, rect.position.y + h * 0.42),
		color,
		maxf(1.5, size * 0.07),
		true
	)
	var fill := Rect2(
		rect.position + Vector2(w * 0.5 * float(button), 0.0), Vector2(w * 0.5, h * 0.42)
	)
	ci.draw_rect(fill, color, true)
