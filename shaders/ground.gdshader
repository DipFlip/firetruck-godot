shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.38,0.6,0.34,1.0);
uniform float grain_scale = 9.0;
uniform float variation = 0.05;
uniform bool meadow = false;
uniform bool cut_pool = false;
uniform vec4 pool_hole = vec4(0.0);
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 if(cut_pool && world.x>pool_hole.x && world.z>pool_hole.y && world.x<pool_hole.z && world.z<pool_hole.w){discard;}
 float grain=noise(world.xz*grain_scale);
 float wide=noise(world.xz*.24);
 ALBEDO=base_color.rgb*(1.0+(grain-.5)*variation+(wide-.5)*variation*.45);
 if(meadow){
  // Dense crossed yarns, with filtered ridges rather than grass blades.
  vec2 yarn=world.xz*42.0;
  vec2 weave=sin(yarn)/(1.0+fwidth(yarn)*fwidth(yarn));
  float nap=noise(vec2(world.x*9.0,world.z*46.0))-.5;
  float patch=noise(world.xz*.38+vec2(6.0))-.5;
  ALBEDO*=1.0+(weave.x+weave.y)*.065+nap*.16+patch*.08;
  NORMAL_MAP=vec3(.5+weave.x*.05,.5+weave.y*.05,1.0);
  ROUGHNESS=.98;
  SPECULAR=.12;
 }else{
  // Slightly stippled, charcoal rubber play-mat roads.
  NORMAL_MAP=vec3(.5+(grain-.5)*.018,.5+(wide-.5)*.018,1.0);
  ROUGHNESS=.78;
  SPECULAR=.22;
 }
}
