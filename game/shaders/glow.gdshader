shader_type spatial;
render_mode unshaded;

// 光る物(弾・かけら・パーティクル)用。COLOR をそのまま HDR で出してブルームさせる。
uniform float boost = 2.2;
uniform vec4 base : source_color = vec4(1.0);

void fragment() {
	ALBEDO = COLOR.rgb * base.rgb * boost;
}
