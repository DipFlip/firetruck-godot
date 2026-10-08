shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.23,0.27,0.23,1.0);
instance uniform float opacity = 1.0;
instance uniform vec3 start_left = vec3(-1.0,0.0,-1.0);
instance uniform vec3 start_right = vec3(1.0,0.0,-1.0);
instance uniform vec3 end_left = vec3(-1.0,0.0,1.0);
instance uniform vec3 end_right = vec3(1.0,0.0,1.0);
instance uniform vec2 end_opacity = vec2(0.25);
void vertex() {
 VERTEX=mix(mix(start_left,start_right,UV.x),mix(end_left,end_right,UV.x),UV.y);
}
void fragment() {
 ALBEDO=tint.rgb;
 float edge=smoothstep(0.0,0.16,UV.x)*smoothstep(0.0,0.16,1.0-UV.x);
 ALPHA=opacity*mix(end_opacity.x,end_opacity.y,UV.y)*edge;
}
