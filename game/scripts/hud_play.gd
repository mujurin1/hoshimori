class_name HudPlay
extends HudWidgets
## プレイ中の表示:経験値・レベル・HP・タイマー・倒した数・ボスのHPと方向・持っている力・お知らせ。

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
var boss_arrow: Label


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
