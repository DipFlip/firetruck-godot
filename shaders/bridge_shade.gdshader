shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 ALBEDO=vec3(.055,.10,.085);
 ALPHA=.36*smoothstep(.25,1.8,UV.x)*(1.0-smoothstep(6.8,10.0,abs(UV.y)));
}
