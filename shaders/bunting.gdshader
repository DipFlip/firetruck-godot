shader_type spatial;
render_mode cull_disabled;
varying float phase;
void vertex() {
 phase=INSTANCE_CUSTOM.x;
 float free_edge=UV.y*UV.y;
 VERTEX.z+=sin(TIME*2.1+phase+UV.y*3.8)*free_edge*.15;
 VERTEX.x+=sin(TIME*1.3+phase*1.7)*free_edge*.025;
 NORMAL=normalize(vec3(0.0,-cos(TIME*2.1+phase+UV.y*3.8)*UV.y*.20,1.0));
}
void fragment() {
 ALBEDO=COLOR.rgb;
 ROUGHNESS=.88;
 SPECULAR=.22;
}
