extends Node
## UIStyle — central palette + widget factories + micro-animations.
## Autoload as "UIStyle". Call UIStyle.primary_button("GRAJ") etc.

# --- Brand palette ---
const BG_DARK      := Color("0a0f1a")
const BG_PANEL     := Color("141b2a")
const BG_PANEL_HI  := Color("1c2538")
const BORDER_DIM   := Color("2a3447")
const TEXT_PRIMARY := Color("f2f4fa")
const TEXT_MUTED   := Color("8891a6")
const ORANGE       := Color("ff6b35")
const ORANGE_HI    := Color("ff8659")
const PURPLE       := Color("8b5cf6")
const PURPLE_HI    := Color("a78bfa")
const CYAN         := Color("22d3ee")
const GREEN        := Color("22c55e")
const RED          := Color("ef4444")
const GOLD         := Color("fbbf24")

# --- Fonts ---
const FONT_HEADLINE := preload("res://assets/fonts/RussoOne-Regular.ttf")
const FONT_BODY     := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
const FONT_BOLD     := preload("res://assets/fonts/Rajdhani-Bold.ttf")

# --- Sound ---
var _click_player: AudioStreamPlayer
var _click_stream: AudioStream


func _ready() -> void:
	_click_player = AudioStreamPlayer.new()
	_click_player.volume_db = -8.0
	_click_player.bus = "Master"
	add_child(_click_player)
	_click_stream = _make_click_stream()
	_install_default_theme()


func _install_default_theme() -> void:
	var theme := Theme.new()
	theme.default_font = FONT_BODY
	theme.default_font_size = 20
	# Make default Button use Rajdhani too
	theme.set_font("font", "Button", FONT_BOLD)
	theme.set_font("font", "Label", FONT_BODY)
	theme.set_font("font", "LineEdit", FONT_BODY)
	theme.set_font("font", "RichTextLabel", FONT_BODY)
	get_tree().root.theme = theme


func _make_click_stream() -> AudioStream:
	# Short synthetic click — procedural WAV, 80Hz pop
	var sr := 22050
	var dur := 0.06
	var n := int(sr * dur)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(sr)
		var env := exp(-t * 40.0)
		var sample := sin(t * TAU * 1200.0) * 0.35 * env
		var s16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		if s16 < 0:
			s16 += 65536
		buf[i * 2] = s16 & 0xff
		buf[i * 2 + 1] = (s16 >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.data = buf
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sr
	stream.stereo = false
	return stream


func play_click() -> void:
	Audio.on_ui_click()


# =========================================================================
# BUTTON FACTORIES
# =========================================================================

func primary_button(text: String, color: Color = ORANGE) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 96)
	btn.add_theme_font_override("font", FONT_HEADLINE)
	btn.add_theme_font_size_override("font_size", 38)
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	_apply_button_style(btn, color, color.lightened(0.12), color.darkened(0.2))
	attach_press_feedback(btn)
	return btn


func pill_button(text: String, color: Color = PURPLE) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_override("font", FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	_apply_button_style(btn, color, color.lightened(0.12), color.darkened(0.2), 32)
	attach_press_feedback(btn)
	return btn


func ghost_button(text: String, color: Color = TEXT_MUTED) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_override("font", FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.0)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = color
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", _with_bg(sb, color, 0.15))
	btn.add_theme_stylebox_override("pressed", _with_bg(sb, color, 0.25))
	btn.add_theme_stylebox_override("focus", sb)
	attach_press_feedback(btn)
	return btn


func _apply_button_style(btn: Button, bg: Color, hi: Color, lo: Color, radius: int = 18) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_bottom = 4
	sb.border_color = lo
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(bg.r, bg.g, bg.b, 0.4)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)

	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = hi
	sb_hover.shadow_size = 16

	var sb_press := sb.duplicate() as StyleBoxFlat
	sb_press.bg_color = lo
	sb_press.border_width_bottom = 0
	sb_press.shadow_size = 4

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_press)
	btn.add_theme_stylebox_override("focus", sb_hover)
	btn.add_theme_stylebox_override("disabled", sb_press)


func _with_bg(sb: StyleBoxFlat, c: Color, alpha: float) -> StyleBoxFlat:
	var d := sb.duplicate() as StyleBoxFlat
	d.bg_color = Color(c.r, c.g, c.b, alpha)
	return d


# =========================================================================
# PANELS / INPUTS / LABELS
# =========================================================================

func panel_style(bg: Color = BG_PANEL, radius: int = 20) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = BORDER_DIM
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	return sb


func panel(bg: Color = BG_PANEL, radius: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, radius))
	return p


func headline(text: String, size: int = 48, color: Color = TEXT_PRIMARY) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT_HEADLINE)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func body_label(text: String, size: int = 22, color: Color = TEXT_PRIMARY) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT_BODY)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func line_edit(placeholder: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.add_theme_font_override("font", FONT_BODY)
	le.add_theme_font_size_override("font_size", 28)
	le.add_theme_color_override("font_color", TEXT_PRIMARY)
	le.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	le.add_theme_color_override("caret_color", ORANGE)
	le.custom_minimum_size = Vector2(0, 56)

	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL_HI
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_bottom = 2
	sb.border_color = BORDER_DIM
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	le.add_theme_stylebox_override("normal", sb)

	var sb_focus := sb.duplicate() as StyleBoxFlat
	sb_focus.border_color = ORANGE
	sb_focus.border_width_bottom = 3
	le.add_theme_stylebox_override("focus", sb_focus)
	return le


# =========================================================================
# MICRO-ANIMATIONS
# =========================================================================

func attach_press_feedback(ctrl: Control) -> void:
	ctrl.pivot_offset = Vector2.ZERO
	if ctrl is BaseButton:
		var btn := ctrl as BaseButton
		btn.button_down.connect(func():
			_scale_tween(ctrl, Vector2(0.96, 0.96), 0.08)
			play_click()
		)
		btn.button_up.connect(func():
			_scale_tween(ctrl, Vector2(1.0, 1.0), 0.12)
		)
		btn.mouse_entered.connect(func():
			_scale_tween(ctrl, Vector2(1.03, 1.03), 0.12)
			Audio.on_ui_hover()
		)
		btn.mouse_exited.connect(func():
			_scale_tween(ctrl, Vector2(1.0, 1.0), 0.12)
		)


func _scale_tween(ctrl: Control, target: Vector2, dur: float) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(ctrl, "scale", target, dur)


func slide_in(ctrl: Control, dir: Vector2 = Vector2.DOWN, dist: float = 40.0, delay: float = 0.0, dur: float = 0.35) -> void:
	var start := -dir * dist
	ctrl.modulate.a = 0.0
	ctrl.position += start
	var tw := ctrl.create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ctrl, "position", ctrl.position - start, dur).set_delay(delay)
	tw.tween_property(ctrl, "modulate:a", 1.0, dur).set_delay(delay)


func pulse(ctrl: Control, scale: float = 1.08, dur: float = 0.6) -> void:
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween()
	tw.set_loops()
	tw.tween_property(ctrl, "scale", Vector2(scale, scale), dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ctrl, "scale", Vector2(1.0, 1.0), dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
