shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.23,0.27,0.23,1.0);
instance uniform float opacity = 0.25;
void fragment() {
 ALBEDO=tint.rgb;
 float edge=smoothstep(0.0,0.16,UV.x)*smoothstep(0.0,0.16,1.0-UV.x);
 ALPHA=opacity*edge;
}
