shader_type spatial;
render_mode diffuse_burley;
uniform vec4 rubber : source_color = vec4(0.16,0.28,0.34,1.0);
uniform vec4 water : source_color = vec4(0.50,0.82,0.88,1.0);
uniform float path_offset = 0.0;
uniform float path_length = 1.0;
uniform float flow_time = 0.0;
void fragment() {
 float distance_along = path_offset + (1.0-UV.y)*path_length;
 float wave = pow(0.5+0.5*cos((distance_along-flow_time*2.8)*7.4),8.0);
 ALBEDO = mix(rubber.rgb,water.rgb,wave*.85);
 ROUGHNESS = .38;
 SPECULAR = .4;
}
