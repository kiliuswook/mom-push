class_name Hud
extends CanvasLayer

## 전투 중 화면. 플레이어가 매 순간 알아야 하는 것은 넷이다.
##   1) 지금 쏠 수 있는가 (구동 상태)
##   2) 킬러가 몇 명 남았는가
##   3) 수배 단계가 어디까지 올라갔는가
##   4) 지금까지 무엇을 배웠는가 (Tab)

const DRIVE_TEXT := {
	Enums.Drive.STOPPED: "정지 — 정밀 조준 가능",
	Enums.Drive.SELF: "직접 굴리는 중 — 사격 불가",
	Enums.Drive.COAST: "관성 롤 — 사격 가능",
	Enums.Drive.PUSHED: "엄마가 미는 중 — 고속 이동 / 사격 가능",
	Enums.Drive.CARRIED: "들려서 이동 중 — 사격 불가",
}

const WANTED_COLORS := {
	Enums.Wanted.CLEAR: Color(0.65, 0.72, 0.68),
	Enums.Wanted.ALERT: Color(1.0, 0.88, 0.45),
	Enums.Wanted.POLICE: Color(0.55, 0.75, 1.0),
	Enums.Wanted.SWAT: Color(0.75, 0.55, 1.0),
	Enums.Wanted.HELI: Color(1.0, 0.55, 0.35),
	Enums.Wanted.JET: Color(1.0, 0.25, 0.25),
}

var player: WheelchairPlayer = null

var _root: Control
var _crosshair: Crosshair
var _loop_label: Label
var _progress_label: Label
var _known_label: Label
var _wanted_label: Label
var _drive_label: Label
var _hp_bar: ProgressBar
var _ammo_label: Label
var _zone_label: Label
var _toast_box: VBoxContainer
var _damage_flash: ColorRect
var _escape_bar: ProgressBar
var _codex: PanelContainer
var _codex_list: VBoxContainer
var _help: Label

var _zone_timer: float = 0.0
var _font: Font


static func create(target: WheelchairPlayer) -> Hud:
	var h := Hud.new()
	h.set_script(load("res://scripts/ui/hud.gd"))
	h.name = "Hud"
	h.player = target
	return h


func _ready() -> void:
	layer = 5
	_font = load("res://assets/fonts/NotoSansKR.ttf")
	_build()
	_connect_events()
	_refresh_static()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		var theme := Theme.new()
		theme.default_font = _font
		theme.default_font_size = 18
		_root.theme = theme
	add_child(_root)

	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.7, 0.05, 0.05, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_damage_flash)

	_crosshair = Crosshair.create()
	_root.add_child(_crosshair)

	# 좌상단 — 루프 상태
	var left := VBoxContainer.new()
	left.position = Vector2(26.0, 20.0)
	left.add_theme_constant_override("separation", 2)
	_root.add_child(left)
	_loop_label = _make_label(left, "LOOP 1", 30, Color(1.0, 0.95, 0.85))
	_progress_label = _make_label(left, "킬러 0 / 6", 20, Color(0.85, 0.95, 1.0))
	_known_label = _make_label(left, "파악한 정체 0", 17, Color(0.75, 0.85, 0.8))

	# 우상단 — 수배 단계
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-320.0, 20.0)
	right.custom_minimum_size = Vector2(290.0, 0.0)
	right.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(right)
	_wanted_label = _make_label(right, "수배: 이상 없음", 22, WANTED_COLORS[Enums.Wanted.CLEAR])
	_wanted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 하단 중앙 — 구동 상태
	_drive_label = Label.new()
	_drive_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_drive_label.position = Vector2(-320.0, -96.0)
	_drive_label.custom_minimum_size = Vector2(640.0, 0.0)
	_drive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drive_label.add_theme_font_size_override("font_size", 20)
	_style_label(_drive_label)
	_root.add_child(_drive_label)

	# 좌하단 — 체력
	_hp_bar = ProgressBar.new()
	_hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hp_bar.position = Vector2(26.0, -62.0)
	_hp_bar.custom_minimum_size = Vector2(280.0, 22.0)
	_hp_bar.max_value = Balance.PLAYER_MAX_HP
	_hp_bar.value = Balance.PLAYER_MAX_HP
	_hp_bar.show_percentage = false
	_style_bar(_hp_bar, Color(0.85, 0.30, 0.32))
	_root.add_child(_hp_bar)
	var hp_caption := Label.new()
	hp_caption.text = "체력"
	hp_caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_caption.position = Vector2(26.0, -88.0)
	hp_caption.add_theme_font_size_override("font_size", 16)
	_style_label(hp_caption)
	_root.add_child(hp_caption)

	# 우하단 — 탄약
	_ammo_label = Label.new()
	_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.position = Vector2(-260.0, -70.0)
	_ammo_label.custom_minimum_size = Vector2(230.0, 0.0)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.add_theme_font_size_override("font_size", 30)
	_style_label(_ammo_label)
	_root.add_child(_ammo_label)

	# 구역 배너
	_zone_label = Label.new()
	_zone_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_zone_label.position = Vector2(-300.0, 86.0)
	_zone_label.custom_minimum_size = Vector2(600.0, 0.0)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.add_theme_font_size_override("font_size", 34)
	_zone_label.modulate.a = 0.0
	_style_label(_zone_label)
	_root.add_child(_zone_label)

	# 토스트
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.position = Vector2(-340.0, 132.0)
	_toast_box.custom_minimum_size = Vector2(680.0, 0.0)
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toast_box)

	# 탈출 게이지
	_escape_bar = ProgressBar.new()
	_escape_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_escape_bar.position = Vector2(-180.0, -140.0)
	_escape_bar.custom_minimum_size = Vector2(360.0, 16.0)
	_escape_bar.max_value = 1.0
	_escape_bar.show_percentage = false
	_escape_bar.visible = false
	_style_bar(_escape_bar, Color(0.35, 0.90, 0.55))
	_root.add_child(_escape_bar)

	_build_codex()
	_build_help()


func _build_codex() -> void:
	_codex = PanelContainer.new()
	_codex.set_anchors_preset(Control.PRESET_CENTER)
	_codex.position = Vector2(-380.0, -260.0)
	_codex.custom_minimum_size = Vector2(760.0, 520.0)
	_codex.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.93)
	style.border_color = Color(0.9, 0.75, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	_codex.add_theme_stylebox_override("panel", style)
	_root.add_child(_codex)

	var scroll := ScrollContainer.new()
	_codex.add_child(scroll)
	_codex_list = VBoxContainer.new()
	_codex_list.custom_minimum_size = Vector2(700.0, 0.0)
	_codex_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_codex_list)


func _build_help() -> void:
	_help = Label.new()
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.position = Vector2(26.0, -300.0)
	_help.add_theme_font_size_override("font_size", 16)
	_help.text = """[조작]
 WASD 굴리기 (굴리는 중에는 사격 불가)
 마우스 시점 / 우클릭 조준 / 좌클릭 사격 / R 재장전
 Shift  엄마! 밀어! (고속 이동 + 사격 가능)
 Ctrl   급정지          Space  휠체어 점프
 P      엄마가 들어올리기 (계단)
 Tab    지금까지 파악한 킬러      G 루프 되감기
 Enter  엄마를 2P 가 직접 조작 (IJKL / 게임패드)"""
	_style_label(_help)
	_root.add_child(_help)


func _make_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_style_label(l)
	parent.add_child(l)
	return l


func _style_bar(bar: ProgressBar, fill: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.08, 0.75)
	bg.border_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_border_width_all(2)
	bar.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	bar.add_theme_stylebox_override("fill", fg)


func _style_label(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("outline_size", 6)


# --- 이벤트 -----------------------------------------------------------------


func _connect_events() -> void:
	EventBus.drive_changed.connect(_on_drive_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.aim_changed.connect(_on_aim_changed)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.wanted_changed.connect(_on_wanted_changed)
	EventBus.killer_progress_changed.connect(_on_progress_changed)
	EventBus.knowledge_gained.connect(_on_knowledge_gained)
	EventBus.zone_entered.connect(_on_zone_entered)
	EventBus.escape_progress.connect(_on_escape_progress)
	EventBus.toast.connect(_on_toast)
	EventBus.loop_started.connect(_on_loop_started)
	EventBus.jet_countdown_started.connect(_on_jet_countdown)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("codex"):
		_codex.visible = not _codex.visible
		if _codex.visible:
			_refresh_codex()
	if player != null:
		_hp_bar.value = player.hp
		_hp_bar.modulate = Color(1.0, 0.4, 0.4) if player.hp < 35.0 else Color(0.85, 0.95, 0.9)
		var spread := player.current_spread()
		_crosshair.blocked = spread < 0.0
		_crosshair.can_fire = player.can_fire()
		_crosshair.spread_px = 6.0 + maxf(spread, 0.0) * 13.0
	if _zone_timer > 0.0:
		_zone_timer -= delta
		_zone_label.modulate.a = clampf(_zone_timer, 0.0, 1.0)
	_damage_flash.color.a = maxf(0.0, _damage_flash.color.a - delta * 1.4)
	if GameState.wanted == Enums.Wanted.JET:
		_wanted_label.text = "전투기 요격까지 %.1f초" % LoopManager.jet_time_left()


func _on_drive_changed(drive: Enums.Drive) -> void:
	_drive_label.text = String(DRIVE_TEXT.get(drive, ""))
	var blocked := drive == Enums.Drive.SELF or drive == Enums.Drive.CARRIED
	_drive_label.add_theme_color_override(
		"font_color", Color(1.0, 0.55, 0.4) if blocked else Color(0.7, 1.0, 0.75)
	)


func _on_ammo_changed(in_mag: int, mag_size: int, reloading: bool) -> void:
	_ammo_label.text = "재장전…" if reloading else "%d / %d" % [in_mag, mag_size]
	_ammo_label.add_theme_color_override(
		"font_color", Color(1.0, 0.7, 0.35) if (reloading or in_mag == 0) else Color(0.95, 0.95, 0.9)
	)


func _on_aim_changed(_aiming: bool, _settle: float, _can_fire: bool) -> void:
	pass


func _on_player_damaged(_amount: float, _hp: float, _from: Vector3) -> void:
	_damage_flash.color.a = 0.42


func _on_wanted_changed(level: Enums.Wanted, reason: String) -> void:
	_wanted_label.text = "수배: %s" % LoopManager.wanted_label()
	_wanted_label.add_theme_color_override("font_color", WANTED_COLORS.get(level, Color.WHITE))
	if level > Enums.Wanted.CLEAR:
		_on_toast("[수배 %d] %s — %s" % [level, LoopManager.wanted_label(), reason], WANTED_COLORS[level])


func _on_progress_changed(down: int, total: int) -> void:
	_progress_label.text = "킬러 %d / %d" % [down, total]


func _on_knowledge_gained(_slot_id: String, note: String) -> void:
	_known_label.text = "파악한 정체 %d" % GameState.known_count()
	_on_toast("기억했다 — %s" % note, Color(0.65, 0.9, 1.0))


func _on_zone_entered(zone: Enums.Zone) -> void:
	_zone_label.text = NpcCatalog.zone_name(zone)
	_zone_timer = 2.4


func _on_escape_progress(ratio: float) -> void:
	_escape_bar.visible = ratio > 0.001
	_escape_bar.value = ratio


func _on_loop_started(index: int) -> void:
	_loop_label.text = "LOOP %d" % index
	_progress_label.text = "킬러 0 / %d" % GameState.total_killers()
	_known_label.text = "파악한 정체 %d" % GameState.known_count()
	_wanted_label.text = "수배: 이상 없음"
	_wanted_label.add_theme_color_override("font_color", WANTED_COLORS[Enums.Wanted.CLEAR])
	_escape_bar.visible = false
	_help.visible = index <= 2
	for child: Node in _toast_box.get_children():
		child.queue_free()


func _on_jet_countdown(_seconds: float) -> void:
	_damage_flash.color = Color(0.8, 0.1, 0.1, 0.5)


func _on_toast(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(l)
	_toast_box.add_child(l)
	if _toast_box.get_child_count() > 5:
		_toast_box.get_child(0).queue_free()
	var tween := l.create_tween()
	tween.tween_interval(3.4)
	tween.tween_property(l, "modulate:a", 0.0, 0.7)
	tween.tween_callback(l.queue_free)


func _refresh_static() -> void:
	_on_loop_started(GameState.loop_index)
	_on_ammo_changed(Balance.MAG_SIZE, Balance.MAG_SIZE, false)
	_on_drive_changed(Enums.Drive.STOPPED)


# --- 코덱스 -----------------------------------------------------------------


func _refresh_codex() -> void:
	for child: Node in _codex_list.get_children():
		child.queue_free()
	var title := _make_label(
		_codex_list,
		"루프 기록 — 파악한 킬러 %d / %d" % [GameState.known_count(), GameState.total_killers()],
		26,
		Color(1.0, 0.9, 0.6)
	)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var entries := GameState.knowledge_entries()
	if entries.is_empty():
		_make_label(
			_codex_list,
			"아직 아무것도 모른다.\n한 번 죽어보거나, 누군가 무기를 꺼내는 순간을 목격해야 한다.",
			19,
			Color(0.8, 0.8, 0.85)
		)
		return
	for entry: Dictionary in entries:
		var status := "처치 완료" if entry["down"] else "생존 중"
		var color := Color(0.55, 1.0, 0.6) if entry["down"] else Color(1.0, 0.62, 0.5)
		var line := _make_label(
			_codex_list,
			(
				"[%s] %s = %s  (%s)\n    단서: %s\n    알게 된 경로: %s · LOOP %d"
				% [
					entry["zone_name"],
					entry["disguise"],
					entry["killer_name"],
					status,
					entry["tell"],
					entry["cause"],
					entry["loop"],
				]
			),
			19,
			color
		)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
