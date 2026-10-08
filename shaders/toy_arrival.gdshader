shader_type spatial;
render_mode diffuse_burley;
uniform vec4 paint : source_color = vec4(1.0);
uniform bool vertex_paint = true;
uniform bool vertex_srgb = true;
uniform float roughness = .38;
uniform float metal = 0.0;
uniform float specular = .42;
uniform float clearcoat = .28;
uniform float progress = 0.0;
uniform vec2 hero = vec2(-49.0,-22.0);
uniform bool print_mode = false;
uniform bool race_scene = false;
varying float present;
float seed_for(vec2 p,float kind) {
 // Nearest-grid hashing tolerates the GPU mesh UV compression error.
 float h=mod(floor(p.x*8.0+.5)*73.0+floor(p.y*8.0+.5)*151.0,997.0);
 return mod(h*h*13.0+h*71.0+kind*83.0,997.0)/997.0;
}
mat3 tumble(float x,float z) {
 float cx=cos(x),sx=sin(x),cz=cos(z),sz=sin(z);
 return mat3(vec3(cz,sz,0.0),vec3(-sz*cx,cz*cx,sx),vec3(sz*sx,-cz*sx,cx));
}
void vertex() {
 vec3 pivot=vec3(UV2.x,0.0,UV2.y);
 float kind=floor(COLOR.a*4.0+.5);
 // Scatter births throughout the whole mat, independently of the tour.
 float seed=seed_for(UV2,kind);
 float delay=.28+sqrt(seed)*.54;
 float distance=length(UV2-hero);
 bool food_court=UV2.x>=40.0 && UV2.x<=78.0 && UV2.y>=10.0 && UV2.y<=70.0;
 bool east_audience=length(UV2-vec2(73.0,-22.0))<12.0;
 if(race_scene) {
  delay=.14+sqrt(seed)*.68;
  if(length(UV2-vec2(0.0,-54.0))<12.0) delay=.015+seed*.025;
  else if(food_court) delay=((kind==2.0 ? 9.85 : 10.1+seed*.9)-1.85)/19.65;
  else if(east_audience) delay=(7.2+seed*.55-1.85)/19.65;
  else if(length(UV2-vec2(-71.0,42.0))<12.0) delay=.688550+seed*.021628;
 } else {
  if(kind==2.0 && distance<8.0) delay=.015;
  else if(kind==3.0 && distance<20.0) delay=.045+seed*.015;
 }
 bool featured=!race_scene && (kind==2.0 && distance<8.0 || kind==3.0 && distance<20.0);
 float span=featured ? .07 : (kind==2.0 || kind==4.0 ? .155 : .12);
 if(race_scene && food_court) span=(kind==2.0 ? 1.6 : 1.15)/19.65;
 else if(race_scene && east_audience) span=1.35/19.65;
 float t=clamp((progress-delay)/span,0.0,1.0);
 present=kind==1.0 ? step(.00001,progress) : step(.00001,t);
 if(print_mode) { VERTEX.y*=.001; present=1.0; }
 // Pending triangles collapse at their pivot; settled toys keep their
 // original geometry. Neither needs the ballistic trigonometry below.
 else if(present<.5) { VERTEX=pivot; }
 else if(t>=1.0 || kind==1.0) { }
 else if(kind==2.0) {
  float height=max(.001,smoothstep(0.0,.88,t)+sin(t*3.141593)*.065);
  VERTEX.y*=height;
  NORMAL=normalize(NORMAL/vec3(1.0,height,1.0));
 } else if(kind==4.0) {
  float scale=max(.001,smoothstep(0.0,1.0,t));
  VERTEX=pivot+(VERTEX-pivot)*scale;
 } else if(kind==3.0) {
  float impact=clamp((t-.68)/.32,0.0,1.0);
  float fall=max(0.0,1.0-pow(t/.68,2.0));
  float bounce=sin(impact*6.283185)*exp(-impact*3.0)*.7;
  float tilt=(1.0-smoothstep(0.0,.68,t))*.65+sin(impact*9.424778)*(1.0-impact)*.16;
  mat3 rotation=tumble(tilt*(seed-.5),tilt*(seed>.5 ? 1.0 : -1.0));
  VERTEX=pivot+rotation*(VERTEX-pivot)+vec3(0.0,19.0*fall+abs(bounce),0.0);
  NORMAL=rotation*NORMAL;
 }
}
vec3 linear_colour(vec3 c) {
 return mix(c/12.92,pow((c+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),c));
}
void fragment() {
 if(present<.5) discard;
 ALBEDO=paint.rgb*(vertex_paint ? (vertex_srgb && !OUTPUT_IS_SRGB ? linear_colour(COLOR.rgb) : COLOR.rgb) : vec3(1.0));
 ROUGHNESS=roughness;
 METALLIC=metal;
 SPECULAR=specular;
 CLEARCOAT=clearcoat;
 CLEARCOAT_ROUGHNESS=.30;
}
