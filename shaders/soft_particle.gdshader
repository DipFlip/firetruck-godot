shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.68,0.59,0.43,1.0);
instance uniform float opacity = 0.4;
void fragment() {
 float r=length(UV-vec2(0.5))*2.0;
 ALBEDO=tint.rgb;
 ALPHA=pow(max(0.0,1.0-r*r),2.0)*opacity;
}
