shader_type spatial;
render_mode cull_disabled;
uniform float ripple_time = 0.0;
void fragment() {
 float radius=length((UV-vec2(.5))*vec2(1.0,1.25));
 float wave=sin(radius*58.0-ripple_time*6.0)*.5+.5;
 ALBEDO=mix(vec3(.33,.45,.44),vec3(.48,.62,.62),wave*.22);
 ROUGHNESS=.37;
 SPECULAR=.25;
}
