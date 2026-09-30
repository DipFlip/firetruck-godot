shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.48,0.6,0.41,1.0);
uniform float grain_scale = 9.0;
uniform float variation = 0.05;
uniform bool meadow = false;
uniform bool cut_pool = false;
uniform vec4 pool_hole = vec4(0.0);
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){if(cut_pool && world.x>pool_hole.x && world.z>pool_hole.y && world.x<pool_hole.z && world.z<pool_hole.w){discard;}float n=noise(world.xz*grain_scale);float wide=noise(world.xz*.24);ALBEDO=base_color.rgb*(1.0+(n-.5)*variation+(wide-.5)*variation*.7);if(meadow){
 float patch=noise(world.xz*.42+vec2(6.0));
 ALBEDO=mix(ALBEDO,ALBEDO*vec3(.87,1.08,.91),smoothstep(.40,.70,patch)*.5);
 vec2 cell=floor(world.xz*5.0);vec2 blade=fract(world.xz*5.0)-.5;
 float tuft=(1.0-smoothstep(.025,.09,abs(blade.x+blade.y*.25)))*(1.0-smoothstep(.12,.38,abs(blade.y)));
 ALBEDO*=1.0-tuft*step(.83,hash(cell))*.12;
 }ROUGHNESS=.94;}
