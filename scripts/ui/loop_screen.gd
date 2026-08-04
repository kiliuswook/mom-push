class_name LoopScreen
extends CanvasLayer

## 루프와 루프 사이의 화면.
##
## 문서 6절: "죽음은 단순한 실패가 아니라 정보 획득 수단이다."
## 그래서 이 화면의 주인공은 사망 원인이 아니라 "이번 루프에서 무엇을 알게 되었는가"다.

signal continue_pressed

var _root: Control
var _title: Label
var _reason: Label
var _body: VBoxContainer
var _prompt: Label
var _shown: bool = false
var _known_before: int = 0


static func create() -> LoopScreen:
	var s := LoopScreen.new()
	s.set_script(load("res://scripts/ui/loop_screen.gd"))
	s.name = "LoopScreen"
	return s


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.loop_started.connect(func(_i: int) -> void: _known_before = GameState.known_count())
	_known_before = GameState.known_count()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var font: Font = load("res://assets/fonts/NotoSansKR.ttf")
	if font != null:
		var theme := Theme.new()
		theme.default_font = font
		theme.default_font_size = 20
		_root.theme = theme
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.06, 0.9)
	_root.add_child(bg)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.position = Vector2(-440.0, -300.0)
	column.custom_minimum_size = Vector2(880.0, 600.0)
	column.add_theme_constant_override("separation", 14)
	_root.add_child(column)

	_title = _label(column, "", 54, Color(1.0, 0.92, 0.75))
	_reason = _label(column, "", 24, Color(1.0, 0.6, 0.5))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	column.add_child(_body)
	_prompt = _label(column, "", 22, Color(0.75, 0.9, 1.0))


func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(880.0, 0.0)
	parent.add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if not _shown:
		return
	var go: bool = false
	if event is InputEventKey:
		var key := event as InputEventKey
		go = key.pressed and not key.echo
	elif event is InputEventMouseButton:
		go = (event as InputEventMouseButton).pressed
	elif event is InputEventJoypadButton:
		go = (event as InputEventJoypadButton).pressed
	if go:
		_shown = false
		visible = false
		get_viewport().set_input_as_handled()
		continue_pressed.emit()


## 루프가 끝났다. 이번 루프에서 새로 알게 된 것을 강조해서 보여준다.
func show_result(reason: Enums.LoopEnd, info: Dictionary) -> void:
	for child: Node in _body.get_children():
		child.queue_free()

	var cleared := reason == Enums.LoopEnd.ESCAPED
	if cleared:
		_title.text = "탈출 성공"
		_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		_reason.text = (
			"LOOP %d 만에 킬러 %d 명을 전부 제거하고 마을을 빠져나갔다."
			% [GameState.loop_index, GameState.total_killers()]
		)
	else:
		_title.text = "LOOP %d 종료" % GameState.loop_index
		_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
		_reason.text = LoopManager.reason_text(reason, info)

	var gained := GameState.known_count() - _known_before
	_label(
		_body,
		(
			"이번 루프에서 새로 알아낸 정체: %d 명   ·   누적 %d / %d"
			% [maxi(0, gained), GameState.known_count(), GameState.total_killers()]
		),
		22,
		Color(0.7, 0.95, 1.0)
	)
	if GameState.civilians_down_this_loop > 0:
		_label(
			_body,
			"민간인 %d 명을 죽였다. 수배가 올라간 이유다." % GameState.civilians_down_this_loop,
			20,
			Color(1.0, 0.5, 0.45)
		)

	var entries := GameState.knowledge_entries()
	if entries.is_empty():
		_label(_body, "아직 아무 정체도 모른다. 다음 루프에서는 무기를 꺼내는 순간을 노려봐라.", 20, Color(0.8, 0.8, 0.85))
	else:
		_label(_body, "— 파악한 킬러 —", 22, Color(1.0, 0.88, 0.6))
		for entry: Dictionary in entries:
			_label(
				_body,
				(
					"  · [%s] %s = %s\n      %s"
					% [entry["zone_name"], entry["disguise"], entry["killer_name"], entry["tell"]]
				),
				19,
				Color(0.9, 0.9, 0.92)
			)

	if cleared:
		_prompt.text = "아무 키나 누르면 새로운 배치로 다시 시작한다."
	else:
		_prompt.text = "아무 키나 누르면 병원에서 다시 깨어난다."

	visible = true
	_shown = true
