class_name HintPanel
extends Control

## 좌하단 조작 안내. 문장 대신 [키캡] + [그림] 한 줄씩.
##
## 초반 루프에는 전부 보이고, 손에 익을 때쯤 스스로 옅어진다.
## 읽는 물건이 아니라 곁눈질로 확인하는 물건이라 문장을 넣지 않는다.

const ROW_HEIGHT := 38.0
const ICON := 30.0
const PAD := 12.0
const ICON_X := 168.0
const WIDTH := 210.0

var _font: Font
var _alpha: float = 1.0
var _rows: Array[Dictionary] = []


static func create(font: Font) -> HintPanel:
	var p := HintPanel.new()
	p.set_script(load("res://scripts/ui/hint_panel.gd"))
	p.name = "HintPanel"
	p._font = font
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(WIDTH, ROW_HEIGHT * 8.0 + PAD * 2.0)
	return p


func _ready() -> void:
	size = custom_minimum_size
	_rows = [
		{"caps": ["W", "A", "S", "D"], "icon": "wheel"},
		{"caps": ["Shift", "W"], "icon": "mom"},
		{"caps": ["LMB"], "icon": "gun"},
		{"caps": ["RMB"], "icon": "eye"},
		{"caps": ["Ctrl"], "icon": "brake"},
		{"caps": ["Space"], "icon": "jump"},
		{"caps": ["P"], "icon": "stairs"},
		{"caps": ["Tab"], "icon": "codex"},
	]
	EventBus.loop_started.connect(_on_loop_started)


func _on_loop_started(index: int) -> void:
	# 3루프쯤이면 조작은 몸이 기억한다. 그 뒤로는 배경처럼 흐려진다.
	_alpha = 1.0 if index <= 3 else 0.32
	queue_redraw()


func _draw() -> void:
	# 밝은 바닥 위에서도 읽히도록 어두운 판을 깔아준다.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.07, 0.55 * _alpha), true)
	var color := Color(1.0, 1.0, 1.0, _alpha)
	var y := PAD
	for row: Dictionary in _rows:
		var x := PAD
		for cap: String in row["caps"]:
			var label := cap
			if cap == "LMB" or cap == "RMB":
				Pictogram.mouse(
					self,
					Vector2(x + 13.0, y + ROW_HEIGHT * 0.5),
					28.0,
					0 if cap == "LMB" else 1,
					color
				)
				x += 32.0
				continue
			x += Pictogram.keycap(self, _font, Vector2(x, y + 5.0), label, 28.0, color) + 5.0
		var icon_at := Vector2(ICON_X, y + ROW_HEIGHT * 0.5)
		match String(row["icon"]):
			"wheel":
				Pictogram.wheel(self, icon_at, ICON, color)
			"mom":
				Pictogram.mom_push(self, icon_at, ICON, color)
			"gun":
				Pictogram.gun(self, icon_at, ICON, color)
			"eye":
				Pictogram.eye(self, icon_at, ICON, color)
			"brake":
				Pictogram.brake(self, icon_at, ICON, color)
			"jump":
				Pictogram.jump(self, icon_at, ICON, color)
			"stairs":
				Pictogram.stairs(self, icon_at, ICON, color)
			"codex":
				Pictogram.codex(self, icon_at, ICON, color)
		y += ROW_HEIGHT
