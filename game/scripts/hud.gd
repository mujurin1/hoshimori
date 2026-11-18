class_name Hud
extends HudScreens
## 画面表示ぜんぶ:タイトル、プレイ中のHUD、レベルアップ、ポーズ、結果。各画面の中身は HudPlay と HudScreens にある。


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
