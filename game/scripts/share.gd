class_name Share
extends Node
## 結果の共有:X の投稿画面を開く / 端末の共有 / クリップボードへのコピー。
## 結果は finished(result) で返す。result は opened / shared / copied / cancel / blocked / failed。

signal finished(result: String)

const URL := "https://mujurin1.github.io/hoshimori/"
const TAG := "ほしもり"

# ブラウザは利用者の操作のイベント処理の中からでないと、新しいタブ・navigator.share・クリップボードを止める。
# Godot の入力はフレームのループで遅れて届くので、押した時に予約だけして、DOM の keyup / pointerup / touchend の中で実行する。
# 予約した時点で何も押されていなければ、操作はもう終わっているのでその場で実行する(操作の直後数秒は許される)。
const JS_HELPER := """
(function () {
	if (window.hoshiShare) return;
	var held = new Set();
	var job = null;
	var timer = 0;
	function down(e) { held.add(e.type === 'keydown' ? 'k' + e.code : 'p' + (e.pointerId === undefined ? 't' : e.pointerId)); }
	function up(e) {
		held.delete(e.type === 'keyup' ? 'k' + e.code : 'p' + (e.pointerId === undefined ? 't' : e.pointerId));
		if (job) { var j = job; job = null; clearTimeout(timer); j(); }
	}
	window.addEventListener('keydown', down, true);
	window.addEventListener('pointerdown', down, true);
	window.addEventListener('keyup', up, true);
	window.addEventListener('pointerup', up, true);
	window.addEventListener('touchend', up, true);
	window.addEventListener('blur', function () { held.clear(); }, true);
	var cb = null;
	function done(r) { if (cb) cb(r); }
	function legacyCopy(s) {
		var ta = document.createElement('textarea');
		ta.value = s;
		ta.style.position = 'fixed';
		ta.style.opacity = '0';
		document.body.appendChild(ta);
		ta.select();
		var ok = false;
		try { ok = document.execCommand('copy'); } catch (e) {}
		ta.remove();
		var c = document.getElementById('canvas');
		if (c) c.focus();
		return ok;
	}
	function copy(s) {
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(s).then(function () { done('copied'); }, function () { done(legacyCopy(s) ? 'copied' : 'failed'); });
		} else {
			done(legacyCopy(s) ? 'copied' : 'failed');
		}
	}
	function exec(kind, a) {
		if (kind === 'x') {
			var w = window.open(a.intent, '_blank');
			if (w) { w.opener = null; done('opened'); } else { done('blocked'); }
		} else if (kind === 'share' && navigator.share) {
			// url を渡すと、本文の URL と合わせて共有先で二重になる
			navigator.share({ text: a.text }).then(function () { done('shared'); }, function (e) {
				done(e && e.name === 'AbortError' ? 'cancel' : 'failed');
			});
		} else {
			copy(a.text);
		}
	}
	window.hoshiShare = {
		canShare: function () { return !!navigator.share; },
		setCallback: function (f) { cb = f; },
		run: function (kind, a, wait) {
			if (wait && held.size > 0) {
				clearTimeout(timer);
				job = function () { exec(kind, a); };
				timer = setTimeout(function () { job = null; }, 4000);
			} else {
				exec(kind, a);
			}
		}
	};
})();
"""

var web := OS.has_feature("web")
var _js_cb: JavaScriptObject


func _ready() -> void:
	if web:
		JavaScriptBridge.eval(JS_HELPER, true)
		_js_cb = JavaScriptBridge.create_callback(_on_js)
		JavaScriptBridge.get_interface("hoshiShare").setCallback(_js_cb)


## ブラウザで navigator.share が使えるか。使えない時、2 つ目のボタンはコピーになる。
func can_share() -> bool:
	return web and bool(JavaScriptBridge.eval("window.hoshiShare.canShare()", true))


## X・navigator.share・コピーで同じ 4 行(本文 2 行 + タグ + URL)。
static func full_text(text: String) -> String:
	return "%s\n#%s\n%s" % [text, TAG, URL]


# url= と hashtags= を使うと、X が URL の後ろにタグを付けて行の順番が崩れる。全部 text に入れる
static func intent_url(text: String) -> String:
	return "https://twitter.com/intent/tweet?text=%s" % full_text(text).uri_encode()


## kind は "x" か "share"。wait はキーやマウスで押した時に true(離した時の DOM イベントの中で実行する)。
func run(kind: String, text: String, wait: bool) -> void:
	if web:
		var a := {"intent": intent_url(text), "text": full_text(text)}
		JavaScriptBridge.eval("window.hoshiShare.run(%s, %s, %s)" % [JSON.stringify(kind), JSON.stringify(a), "true" if wait else "false"], true)
	elif kind == "x":
		finished.emit("opened" if OS.shell_open(intent_url(text)) == OK else "failed")
	else:
		DisplayServer.clipboard_set(full_text(text))
		finished.emit("copied")


func _on_js(args: Array) -> void:
	finished.emit(str(args[0]) if args.size() > 0 else "failed")
