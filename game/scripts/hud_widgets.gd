class_name HudWidgets
extends CanvasLayer
## 画面表示の土台:フォント、全体の親、ラベルや枠やバーを作る小さな部品。
## HudPlay(プレイ中)→ HudScreens(タイトル・レベルアップ・ポーズ・結果)→ Hud の順に継ぐ。

var main: Node
var font_m: Font
var font_b: Font
var font_x: Font
var root: Control
var t := 0.0


func _label(text: String, size: int, color := Color.WHITE, font: Font = null, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else font_b)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.12, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(color: Color, radius := 12, border := 0, border_color := Color.WHITE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.anti_aliasing = true
	return sb


func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 背景つきのバー。返り値は中身(anchor_right を 0..1 で動かす)。
func _bar(parent: Control, pos: Vector2, size: Vector2, bg: Color, fill: Color, radius := 6) -> ColorRect:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _box(bg, radius))
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	parent.add_child(p)
	var f := ColorRect.new()
	f.color = fill
	f.anchor_right = 1.0
	f.anchor_bottom = 1.0
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(f)
	return f


func _center_col(parent: Control, sep := 14) -> VBoxContainer:
	var cc := CenterContainer.new()
	_full(cc)
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(v)
	return v


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
