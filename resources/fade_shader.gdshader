shader_type canvas_item;

uniform float u_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = vec4(tex_color.rgb, tex_color.a * u_alpha);
}