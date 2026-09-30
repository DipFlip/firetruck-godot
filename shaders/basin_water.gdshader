shader_type spatial;
render_mode diffuse_burley, depth_draw_always;
uniform float depth=0.0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz;
 float bands=sin(p.x*5.0+sin(p.y*3.5+TIME*1.3))*sin(p.y*5.4+cos(p.x*3.0-TIME));
 float caustic=smoothstep(.48,.90,bands);
 ALBEDO=mix(vec3(.08,.53,.69),vec3(.60,.91,.94),caustic*.60);
 ALPHA=mix(.48,.83,depth);
 ROUGHNESS=.19;
 SPECULAR=.65;
}
