shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
instance uniform float opacity = 0.3;
void fragment(){vec2 p=UV*2.0-1.0;float r=length(p*(1.0+0.09*sin(atan(p.y,p.x)*5.0+TIME)));float cloud=1.0-smoothstep(.22,1.0,r);ALBEDO=mix(vec3(.48,.48,.43),vec3(.68,.66,.57),UV.y);ALPHA=cloud*cloud*opacity;}
