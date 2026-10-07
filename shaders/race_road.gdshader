shader_type spatial;
render_mode cull_disabled;
uniform bool curb = false;
uniform float start_distance = 36.0;
void fragment() {
 float stripe = (1.0-smoothstep(.09,.17,abs(UV.y)))*step(.45,fract(UV.x/6.0));
 vec3 asphalt = vec3(.42,.50,.52);
 vec3 cream = vec3(.96,.88,.67);
 if(curb) {
  ALBEDO=mix(cream,vec3(.80,.32,.26),step(.5,fract(UV.x/4.0)));
 } else {
  ALBEDO=mix(asphalt,cream,stripe);
  float edge=(1.0-smoothstep(.05,.13,abs(abs(UV.y)-6.1)));
  ALBEDO=mix(ALBEDO,cream,edge);
  if(abs(UV.x-start_distance)<1.5) ALBEDO=mix(cream,vec3(.18,.25,.28),mod(floor(UV.x*1.2)+floor(UV.y*1.2),2.0));
 }
 ROUGHNESS=.85;
}
