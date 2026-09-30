shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
instance uniform float opacity=0.3;
void fragment() {
 float r=length(UV-vec2(.5))*2.0;
 float ring=smoothstep(.70,.83,r)*(1.0-smoothstep(.89,1.0,r));
 ALBEDO=vec3(.68,.87,.86);
 ALPHA=ring*opacity;
}
