shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
varying vec3 wall_normal;
void vertex() {
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 wall_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec2 p=abs(wall_normal.y)>.6 ? world.xz : (abs(wall_normal.x)>.6 ? world.zy : world.xy);
 vec2 tile=fract(p*2.8);
 float grout=1.0-smoothstep(.025,.065,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
 float alternate=mod(floor(p.x*2.8)+floor(p.y*2.8),2.0);
 ALBEDO=mix(mix(vec3(.44,.72,.79),vec3(.55,.80,.85),alternate*.35),vec3(.85,.94,.96),grout*.7);
 ROUGHNESS=.48;
}
