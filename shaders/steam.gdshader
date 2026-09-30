shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
instance uniform float opacity=0.5;
void fragment() {
 vec2 p=UV*2.0-1.0;
 float edge=length(p)*(1.0+.1*sin(atan(p.y,p.x)*6.0+TIME*2.0));
 float cloud=1.0-smoothstep(.22,1.0,edge);
 ALBEDO=vec3(.88,.96,1.0);
 ALPHA=cloud*opacity;
}
