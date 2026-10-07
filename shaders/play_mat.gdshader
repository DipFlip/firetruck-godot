shader_type spatial;
render_mode diffuse_burley;
uniform float roll = 0.0;
uniform bool race = false;
uniform bool printed_toys = true;
uniform vec4 felt_color : source_color = vec4(.37647,.6,.345098,1.0);
uniform sampler2D maple_print : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D race_print : source_color, filter_linear_mipmap, repeat_disable;
varying vec2 printed;
varying float backing;
// A continuous, thick felt sheet winds from its loose printed lip into an
// open spiral. The edge faces are the cross-section of the real sheet, rather
// than decorative rings on a filled cylinder. Evenly spaced wraps keep the
// felt thickness readable around a small, open centre.
vec3 centreline(vec3 p) {
 if(roll<.0001) return vec3(p.x,0.0,p.z);
 float spread=160.0*(1.0-roll)+12.0*roll;
 float front=80.0-spread;
 float wound=160.0-spread;
 float into=front-p.z;
 vec3 sheet=vec3(p.x,0.0,p.z);
 if(into<=0.0) {
  float s=clamp((80.0-p.z)/spread,0.0,1.0);
  float wave=sin(s*3.141593);
  // The free lip is already visible at the beginning. A travelling, asymmetric
  // billow lifts the fabric as it is thrown out, then settles it onto the floor.
  sheet.y=wave*wave*(sin((1.0-roll)*3.141593)*10.0
    +roll*1.3)*(1.0+.16*sin(p.x*.055+s*9.0));
 } else {
  float pitch=1.5/6.283185;
  float core=2.35+.22*sin(p.x*.043)+.09*sin(p.x*.113);
  float outer=sqrt(core*core+2.0*pitch*wound);
  float radius=sqrt(max(core*core,outer*outer-2.0*pitch*into));
  float theta=(outer-radius)/pitch;
  float loosen=smoothstep(0.0,14.0,into);
  // Slightly flattened and uneven wraps, with a softly telescoped open end.
  float turn=theta+.045*sin(p.x*.063)*loosen;
  float ripple=.13*sin(theta*2.0+p.x*.09)*loosen;
  sheet.z=front-(radius+ripple)*sin(turn)*1.06;
  sheet.y=(outer-(radius+ripple)*cos(turn))*.86;
 }
 return sheet;
}
void vertex() {
 printed=VERTEX.xz;
 backing=step(NORMAL.y,.5);
 if(roll>.0001) {
  vec3 p=VERTEX;
  vec3 centre=centreline(p);
  vec3 dx=normalize(centreline(p+vec3(.025,0.0,0.0))-centre);
  vec3 dz=normalize(centreline(p+vec3(0.0,0.0,.025))-centre);
  vec3 cloth_normal=normalize(cross(dz,dx));
  VERTEX=centre+cloth_normal*p.y;
  NORMAL=normalize(dx*NORMAL.x+cloth_normal*NORMAL.y+dz*NORMAL.z);
 }
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void fragment() {
 vec2 p=printed;
 vec3 ink=vec3(.53,.66,.45);
 if(printed_toys) {
  if(race) ink=texture(race_print,(p+vec2(80.0))/160.0).rgb;
  else ink=texture(maple_print,(p+vec2(80.0))/160.0).rgb;
 } else {
  ink=mix(ink,vec3(.57,.69,.47),smoothstep(-80.0,80.0,p.y));
  float picnic=step(35.0,p.x)*step(p.x,70.0)*step(30.0,p.y)*step(p.y,74.0);
  ink=mix(ink,vec3(.70,.75,.53),picnic*.65);
 }
 float border=smoothstep(77.5,78.0,max(abs(p.x),abs(p.y)));
 ink=mix(ink,vec3(.78,.46,.33),border);
 if(backing>.5) ink=vec3(.69,.66,.57);
 vec2 yarn=p*42.0;
 vec2 filtered=sin(yarn)/(1.0+fwidth(yarn)*fwidth(yarn));
 float weave=(filtered.x+filtered.y)*.5;
 if(!printed_toys && backing<.5 && border<.5) {
  ink=felt_color.rgb;
  float grain=noise(p*9.0)-.5;
  float wide=noise(p*.24)-.5;
  float nap=noise(vec2(p.x*9.0,p.y*46.0))-.5;
  float patch=noise(p*.38+vec2(6.0))-.5;
  ink*=1.0+weave*.13+nap*.16+patch*.08+grain*.05+wide*.0225;
  NORMAL_MAP=vec3(.5+filtered.x*.05,.5+filtered.y*.05,1.0);
  SPECULAR=.12;
 }
 // The print already contains the offline scene's lighting. Retain a little
 // cloth lighting during the toss without lighting the photograph twice.
 if(backing>.5) {
  ink*=1.0+(noise(p*13.0)-.5)*.12+weave*.1;
  NORMAL_MAP=vec3(.5+filtered.x*.08,.5+filtered.y*.08,1.0);
 }
 vec3 fabric=ink*(.975+.025*weave);
 float print_light=printed_toys && backing<.5 ? mix(.15,.65,roll) : 1.0;
 ALBEDO=fabric*print_light;
 EMISSION=printed_toys && backing<.5 ? fabric*(1.0-print_light) : vec3(0.0);
 SPECULAR=.1;
 ROUGHNESS=.94;
}
