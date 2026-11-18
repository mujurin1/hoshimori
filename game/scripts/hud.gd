class_name Hud
extends CanvasLayer
## 画面表示ぜんぶ:タイトル、プレイ中のHUD、レベルアップ、ポーズ、結果。

var main: Node
var font_m: Font
var font_b: Font
var font_x: Font
var root: Control

var play_box: Control
var xp_fill: ColorRect
var lv_label: Label
var timer_label: Label
var kills_label: Label
var hp_fill: ColorRect
var hp_label: Label
var mini_hp: Control
var mini_hp_fill: ColorRect
var mini_dash_fill: ColorRect
var chips: HBoxContainer
var chips_sig := ""
var banner_label: Label
var banner_tw: Tween
var boss_box: Control
var boss_fill: ColorRect
var boss_name: Label
var hurt_rect: ColorRect
var hurt_tw: Tween

var title_box: Control
var title_prompt: Label
var title_best: Label
var title_diff: Label
var boss_arrow: Label
var lvl_box: Control
var lvl_cards: HBoxContainer
var cards: Array[Panel] = []
var card_ids: Array[String] = []
var sel := 0
var pause_box: Control
var over_box: Control
var over_title: Label
var over_stats: Label
var over_note: Label
var t := 0.0


func _ready() -> void:
	font_m = load("res://fonts/MPLUSRounded1c-Medium.ttf")
	font_b = load("res://fonts/MPLUSRounded1c-Bold.ttf")
	font_x = load("res://fonts/MPLUSRounded1c-ExtraBold.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_play()
	_build_title()
	_build_levelup()
	_build_pause()
	_build_over()


# ---------------------------------------------------------------- 部品
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


# ---------------------------------------------------------------- プレイ中
func _build_play() -> void:
	play_box = _full(Control.new())
	root.add_child(play_box)

	hurt_rect = ColorRect.new()
	_full(hurt_rect)
	hurt_rect.color = Color(1.0, 0.1, 0.15, 0.0)
	play_box.add_child(hurt_rect)

	# 経験値バー(画面上端いっぱい)
	var xp_bg := Panel.new()
	xp_bg.add_theme_stylebox_override("panel", _box(Color(0.03, 0.05, 0.14, 0.75), 0))
	xp_bg.anchor_right = 1.0
	xp_bg.offset_bottom = 22.0
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(xp_bg)
	xp_fill = ColorRect.new()
	xp_fill.color = Color("5ee0ff")
	xp_fill.anchor_bottom = 1.0
	xp_fill.anchor_right = 0.0
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bg.add_child(xp_fill)
	lv_label = _label("Lv 1", 30, Color("fff3b0"), font_x)
	lv_label.position = Vector2(18, 26)
	play_box.add_child(lv_label)

	# HP(左上)
	hp_fill = _bar(play_box, Vector2(20, 78), Vector2(300, 22), Color(0.05, 0.05, 0.12, 0.8), Color("ff5d73"), 11)
	hp_label = _label("100 / 100", 18, Color.WHITE, font_b, 5)
	hp_label.position = Vector2(30, 76)
	play_box.add_child(hp_label)

	# 時間(上中央)
	timer_label = _centered(_label("夜明けまで 8:00", 38, Color("e7f0ff"), font_x))
	timer_label.anchor_left = 0.5
	timer_label.anchor_right = 0.5
	timer_label.offset_left = -400.0
	timer_label.offset_right = 400.0
	timer_label.offset_top = 28.0
	play_box.add_child(timer_label)

	# ボスHP
	boss_box = Control.new()
	boss_box.anchor_left = 0.5
	boss_box.anchor_right = 0.5
	boss_box.offset_top = 92.0
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(boss_box)
	boss_fill = _bar(boss_box, Vector2(-330, 30), Vector2(660, 18), Color(0.05, 0.03, 0.1, 0.85), Color("c77dff"), 9)
	boss_name = _centered(_label("", 22, Color("f3d9ff"), font_b, 6))
	boss_name.position = Vector2(-330, -2)
	boss_name.size = Vector2(660, 30)
	boss_box.add_child(boss_name)
	boss_box.visible = false

	# 倒した数(右上)
	kills_label = _label("たおした数 0", 28, Color("e7f0ff"), font_b)
	kills_label.anchor_left = 1.0
	kills_label.anchor_right = 1.0
	kills_label.offset_left = -420.0
	kills_label.offset_right = -22.0
	kills_label.offset_top = 30.0
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	play_box.add_child(kills_label)

	# 持っている力(左下)
	chips = HBoxContainer.new()
	chips.anchor_top = 1.0
	chips.anchor_bottom = 1.0
	chips.offset_left = 20.0
	chips.offset_top = -92.0
	chips.offset_bottom = -20.0
	chips.add_theme_constant_override("separation", 8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(chips)

	# 操作ヒント(右下)
	var hint := _label("移動: WASD / 矢印   ダッシュ: スペース   ポーズ: Esc", 18, Color(0.85, 0.9, 1.0, 0.75), font_m, 5)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -640.0
	hint.offset_right = -20.0
	hint.offset_top = -44.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	play_box.add_child(hint)

	# キャラの足もとの小さなHPとダッシュ
	mini_hp = Control.new()
	mini_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(mini_hp)
	mini_hp_fill = _bar(mini_hp, Vector2(-44, 0), Vector2(88, 9), Color(0.05, 0.05, 0.12, 0.75), Color("ff5d73"), 4)
	mini_dash_fill = _bar(mini_hp, Vector2(-44, 12), Vector2(88, 5), Color(0.05, 0.05, 0.12, 0.6), Color("8fe9ff"), 2)

	# ボスの方向
	boss_arrow = _centered(_label("▲", 54, Color("ff8fd0"), font_x, 12))
	boss_arrow.size = Vector2(80, 80)
	boss_arrow.pivot_offset = Vector2(40, 40)
	boss_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_arrow.visible = false
	play_box.add_child(boss_arrow)

	# お知らせ
	banner_label = _centered(_label("", 46, Color.WHITE, font_x, 12))
	banner_label.anchor_left = 0.0
	banner_label.anchor_right = 1.0
	banner_label.anchor_top = 0.22
	banner_label.anchor_bottom = 0.22
	banner_label.offset_bottom = 70.0
	banner_label.modulate.a = 0.0
	play_box.add_child(banner_label)


func banner(text: String, color: Color, dur := 2.6) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	if banner_tw != null:
		banner_tw.kill()
	banner_label.modulate.a = 0.0
	banner_label.pivot_offset = banner_label.size * 0.5
	banner_label.scale = Vector2(1.25, 1.25)
	banner_tw = create_tween()
	banner_tw.set_parallel(true)
	banner_tw.tween_property(banner_label, "modulate:a", 1.0, 0.2)
	banner_tw.tween_property(banner_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tw.chain().tween_interval(dur)
	banner_tw.chain().tween_property(banner_label, "modulate:a", 0.0, 0.5)


func flash_hurt() -> void:
	if hurt_tw != null:
		hurt_tw.kill()
	hurt_rect.color.a = 0.2
	hurt_tw = create_tween()
	hurt_tw.tween_property(hurt_rect, "color:a", 0.0, 0.45)


func update_play(g: Game) -> void:
	xp_fill.anchor_right = clampf(g.xp / g.xp_next, 0.0, 1.0)
	lv_label.text = "Lv %d" % g.level
	var hpk := clampf(g.p_hp / g.p_max_hp, 0.0, 1.0)
	hp_fill.anchor_right = hpk
	hp_label.text = "%d / %d" % [int(ceil(g.p_hp)), int(g.p_max_hp)]
	mini_hp_fill.anchor_right = hpk
	mini_dash_fill.anchor_right = 1.0 - clampf(g.dash_cd / Game.DASH_CD, 0.0, 1.0)
	mini_dash_fill.color = Color("8fe9ff") if g.dash_cd <= 0.0 else Color(0.5, 0.6, 0.7)
	var sp := g.cam.unproject_position(g.p_dir * (Game.R - 0.3))
	mini_hp.position = sp + Vector2(0, 14)
	mini_hp.visible = g.alive
	var remain := maxf(Game.NIGHT_LEN - g.elapsed, 0.0)
	if g.victory:
		timer_label.text = "夜明け"
	elif remain > 0.0:
		timer_label.text = "夜明けまで %d:%02d" % [int(remain) / 60, int(remain) % 60]
	else:
		timer_label.text = "ヨルノヌシをたおせ!"
	kills_label.text = "たおした数 %d" % g.kills
	if g.bosses.is_empty():
		boss_box.visible = false
	else:
		boss_box.visible = true
		var hp := 0.0
		var mx := 0.0
		for b in g.bosses:
			hp += maxf(b.hp, 0.0)
			mx += b.max_hp
		boss_fill.anchor_right = clampf(hp / mx, 0.0, 1.0)
		boss_name.text = "夜の主 ヨルノヌシ" if g.bosses[0].kind == "nushi" else "オオモヤ"
	# 画面の外にいるボスを矢印で示す
	var show_arrow := false
	if not g.bosses.is_empty() and g.alive:
		var b := g.bosses[0]
		var tb := g.tangent_to(g.p_dir, b.dir)
		if b.pos.distance_to(g.p_dir * Game.R) > 14.0 and tb != Vector3.ZERO:
			var right := g.cam_fwd.cross(g.p_dir).normalized()
			var v2 := Vector2(tb.dot(right), -tb.dot(g.cam_fwd)).normalized()
			var vs := get_viewport().get_visible_rect().size
			boss_arrow.position = vs * 0.5 + Vector2(v2.x * vs.x * 0.36, v2.y * vs.y * 0.34) - Vector2(40, 40)
			boss_arrow.rotation = v2.angle() + PI * 0.5
			boss_arrow.modulate.a = 0.75 + 0.25 * sin(t * 8.0)
			show_arrow = true
	boss_arrow.visible = show_arrow
	_update_chips(g)


func _update_chips(g: Game) -> void:
	var sig := ""
	var ids := g.weapons.owned()
	for id in ids:
		sig += "%s%d," % [id, g.weapons.level(id)]
	if sig == chips_sig:
		return
	chips_sig = sig
	for c in chips.get_children():
		c.queue_free()
	for id in ids:
		var d: Dictionary = Weapons.DEFS[id]
		var col: Color = d.color
		var p := Panel.new()
		p.custom_minimum_size = Vector2(64, 72)
		p.add_theme_stylebox_override("panel", _box(Color(0.06, 0.08, 0.2, 0.82), 14, 3, col))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := _centered(_label(d.icon, 30, col, font_x, 6))
		ic.position = Vector2(0, 2)
		ic.size = Vector2(64, 44)
		p.add_child(ic)
		var lvl := g.weapons.level(id)
		var txt := "MAX" if lvl >= int(d.max) else "Lv%d" % lvl
		var ll := _centered(_label(txt, 15, Color.WHITE, font_b, 4))
		ll.position = Vector2(0, 46)
		ll.size = Vector2(64, 22)
		p.add_child(ll)
		chips.add_child(p)


# ---------------------------------------------------------------- タイトル
func _build_title() -> void:
	title_box = _full(Control.new())
	root.add_child(title_box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.05, 0.0)
	_full(shade)
	title_box.add_child(shade)

	var logo := _centered(_label("ほしもり", 170, Color("ffe89a"), font_x, 28))
	logo.add_theme_color_override("font_outline_color", Color("2b2f77"))
	logo.add_theme_constant_override("shadow_offset_y", 8)
	logo.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.1, 0.6))
	logo.anchor_right = 1.0
	logo.anchor_top = 0.06
	logo.anchor_bottom = 0.06
	logo.offset_bottom = 230.0
	title_box.add_child(logo)
	var sub := _centered(_label("小さな星で、夜明けまで生きのびろ", 34, Color("dbe7ff"), font_b, 10))
	sub.anchor_right = 1.0
	sub.anchor_top = 0.06
	sub.anchor_bottom = 0.06
	sub.offset_top = 232.0
	sub.offset_bottom = 290.0
	title_box.add_child(sub)

	title_prompt = _centered(_label("スペース / Enter でスタート", 44, Color.WHITE, font_x, 12))
	title_prompt.anchor_right = 1.0
	title_prompt.anchor_top = 0.74
	title_prompt.anchor_bottom = 0.74
	title_prompt.offset_bottom = 60.0
	title_box.add_child(title_prompt)
	var help := _centered(_label("移動: WASD / 矢印キー     ダッシュ: スペース     攻撃は自動\nポーズ: Esc     全画面切替: F11     音を消す: M     ゲームパッド対応", 22, Color(0.85, 0.9, 1.0, 0.9), font_m, 6))
	help.anchor_right = 1.0
	help.anchor_top = 0.74
	help.anchor_bottom = 0.74
	help.offset_top = 74.0
	help.offset_bottom = 150.0
	title_box.add_child(help)
	title_diff = _centered(_label("", 30, Color("ffe89a"), font_x, 8))
	title_diff.anchor_right = 1.0
	title_diff.anchor_top = 0.74
	title_diff.anchor_bottom = 0.74
	title_diff.offset_top = -62.0
	title_diff.offset_bottom = -14.0
	title_box.add_child(title_diff)
	title_best = _centered(_label("", 24, Color("ffe89a"), font_b, 6))
	title_best.anchor_right = 1.0
	title_best.anchor_top = 1.0
	title_best.anchor_bottom = 1.0
	title_best.offset_top = -60.0
	title_best.offset_bottom = -20.0
	title_box.add_child(title_best)


func set_diff(d: int) -> void:
	title_diff.text = "むずかしさ   ←  %s  →" % ["やさしい", "ふつう", "むずかしい"][d]
	title_diff.add_theme_color_override("font_color", [Color("b9fbc0"), Color("ffe89a"), Color("ff9e9e")][d])


func set_best(best: Dictionary) -> void:
	if best.is_empty() or int(best.get("runs", 0)) == 0:
		title_best.text = ""
		return
	var tm := int(best.get("time", 0))
	var s := "これまでの記録   いちばん長く生きた時間 %d:%02d   たおした数 %d" % [tm / 60, tm % 60, int(best.get("kills", 0))]
	if int(best.get("wins", 0)) > 0:
		s += "   夜明けを見た回数 %d" % int(best.get("wins", 0))
	title_best.text = s


# ---------------------------------------------------------------- レベルアップ
func _build_levelup() -> void:
	lvl_box = _full(Control.new())
	root.add_child(lvl_box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.08, 0.6)
	_full(shade)
	lvl_box.add_child(shade)
	var v := _center_col(lvl_box, 26)
	var head := _centered(_label("レベルアップ!", 70, Color("ffe89a"), font_x, 16))
	v.add_child(head)
	var sub := _centered(_label("あたらしい力をひとつ選ぼう", 28, Color("dbe7ff"), font_b, 8))
	v.add_child(sub)
	lvl_cards = HBoxContainer.new()
	lvl_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	lvl_cards.add_theme_constant_override("separation", 34)
	v.add_child(lvl_cards)
	var hint := _centered(_label("← → でえらぶ   スペース / Enter で決定   1 2 3 キーやクリックでも選べる", 22, Color(0.85, 0.9, 1.0, 0.9), font_m, 6))
	v.add_child(hint)


func show_levelup(infos: Array) -> void:
	for c in lvl_cards.get_children():
		c.queue_free()
	cards.clear()
	card_ids.clear()
	for i in infos.size():
		var info: Dictionary = infos[i]
		var col: Color = info.color
		var card := Panel.new()
		card.custom_minimum_size = Vector2(340, 440)
		card.pivot_offset = Vector2(170, 220)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_entered.connect(_on_card_hover.bind(i))
		card.gui_input.connect(_on_card_input.bind(i))
		var key := _centered(_label(str(i + 1), 22, Color(0.8, 0.85, 1.0, 0.8), font_b, 4))
		key.position = Vector2(16, 10)
		card.add_child(key)
		var icon := Panel.new()
		icon.add_theme_stylebox_override("panel", _box(col, 65))
		icon.position = Vector2(105, 34)
		icon.size = Vector2(130, 130)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var ch := _centered(_label(info.icon, 76, Color("1c2148"), font_x, 0))
		ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ch.size = Vector2(130, 130)
		icon.add_child(ch)
		var nm := _centered(_label(info.name, 36, Color.WHITE, font_x, 8))
		nm.position = Vector2(0, 178)
		nm.size = Vector2(340, 50)
		card.add_child(nm)
		var lt := ""
		var lc := Color("ffe066")
		if info.id == "feast":
			lt = "おやつ"
		elif info.is_new:
			lt = "NEW!"
		elif int(info.to) >= int(info.max):
			lt = "Lv %d → MAX" % int(info.from)
			lc = Color("ffb3c1")
		else:
			lt = "Lv %d → %d" % [int(info.from), int(info.to)]
			lc = Color("a5d8ff")
		var ll := _centered(_label(lt, 26, lc, font_x, 6))
		ll.position = Vector2(0, 230)
		ll.size = Vector2(340, 38)
		card.add_child(ll)
		var ds := _centered(_label(info.desc, 24, Color("e3ebff"), font_b, 4))
		ds.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		ds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ds.position = Vector2(26, 276)
		ds.size = Vector2(288, 140)
		card.add_child(ds)
		lvl_cards.add_child(card)
		cards.append(card)
		card_ids.append(info.id)
		card.scale = Vector2(0.6, 0.6)
		card.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2.ONE, 0.28).set_delay(0.06 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(0.06 * i)
	sel = mini(1, infos.size() - 1)
	_style_cards()
	lvl_box.visible = true


func _style_cards() -> void:
	for i in cards.size():
		var on := i == sel
		var col: Color = Weapons.DEFS[card_ids[i]].color
		cards[i].add_theme_stylebox_override("panel", _box(
			Color(0.13, 0.16, 0.36, 0.97) if on else Color(0.07, 0.09, 0.22, 0.94), 26,
			6 if on else 3, col if on else Color(col.r, col.g, col.b, 0.35)))
		cards[i].z_index = 1 if on else 0


func move_sel(d: int) -> void:
	if cards.is_empty():
		return
	sel = posmod(sel + d, cards.size())
	_style_cards()
	Sfx.play("hover", -3.0)
	var tw := create_tween()
	tw.tween_property(cards[sel], "scale", Vector2(1.06, 1.06), 0.07)
	tw.tween_property(cards[sel], "scale", Vector2.ONE, 0.1)


func _on_card_hover(i: int) -> void:
	if i != sel and i < cards.size():
		sel = i
		_style_cards()
		Sfx.play("hover", -8.0)


func _on_card_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		main.pick(i)


# ---------------------------------------------------------------- ポーズ
func _build_pause() -> void:
	pause_box = _full(Control.new())
	root.add_child(pause_box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.08, 0.65)
	_full(shade)
	pause_box.add_child(shade)
	var v := _center_col(pause_box, 22)
	v.add_child(_centered(_label("ひとやすみ", 80, Color("ffe89a"), font_x, 16)))
	v.add_child(_centered(_label("Esc / P : つづける\nR : はじめからやりなおす\nT : タイトルにもどる", 30, Color("e3ebff"), font_b, 8)))


# ---------------------------------------------------------------- 結果
func _build_over() -> void:
	over_box = _full(Control.new())
	root.add_child(over_box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.08, 0.55)
	_full(shade)
	over_box.add_child(shade)
	var v := _center_col(over_box, 20)
	over_title = _centered(_label("", 96, Color("ffe89a"), font_x, 20))
	v.add_child(over_title)
	over_note = _centered(_label("", 30, Color("ffd6a5"), font_b, 8))
	v.add_child(over_note)
	over_stats = _centered(_label("", 36, Color("e3ebff"), font_b, 8))
	v.add_child(over_stats)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	v.add_child(sp)
	v.add_child(_centered(_label("スペース / Enter : もういちど     Esc : タイトルへ", 30, Color.WHITE, font_x, 8)))


func show_over(victory: bool, g: Game, new_record: bool) -> void:
	if victory:
		over_title.text = "夜が明けた!"
		over_title.add_theme_color_override("font_color", Color("ffe89a"))
		over_note.text = "星は守られた。おつかれさま!"
	else:
		over_title.text = "力つきた…"
		over_title.add_theme_color_override("font_color", Color("b9c6ff"))
		var remain := maxf(Game.NIGHT_LEN - g.elapsed, 0.0)
		if remain <= 0.0:
			over_note.text = "夜明けは目の前だった…!"
		else:
			over_note.text = "夜明けまで、あと %d:%02d" % [int(remain) / 60, int(remain) % 60]
	if new_record:
		over_note.text += "   ★ 新記録!"
	var tm := int(g.elapsed)
	over_stats.text = "生きのびた時間   %d:%02d\nたおした数   %d\nレベル   %d" % [tm / 60, tm % 60, g.kills, g.level]
	over_box.visible = true
	over_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(over_box, "modulate:a", 1.0, 0.5)


# ---------------------------------------------------------------- 切り替え
func show_state(title: bool, play: bool, lvl: bool, pause: bool, over: bool) -> void:
	title_box.visible = title
	play_box.visible = play
	lvl_box.visible = lvl
	pause_box.visible = pause
	over_box.visible = over


func _process(dt: float) -> void:
	t += dt
	if title_box.visible:
		title_prompt.modulate.a = 0.65 + 0.35 * sin(t * 3.0)
