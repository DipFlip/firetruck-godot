shader_type spatial;
render_mode diffuse_burley;
uniform bool use_palette = false;
uniform vec4 shirt : source_color = vec4(.92549,.70196,.32941,1.0);
uniform vec4 skin : source_color = vec4(.87451,.67451,.50588,1.0);
uniform vec4 hair : source_color = vec4(.6,.32157,.23137,1.0);
uniform vec4 nose : source_color = vec4(.88455,.70055,.54541,1.0);
uniform vec4 seam : source_color = vec4(.77741,.58965,.27671,1.0);
vec3 linear_colour(vec3 c) {
 return mix(c/12.92,pow((c+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),c));
}
void fragment() {
 vec3 colour=OUTPUT_IS_SRGB ? COLOR.rgb : linear_colour(COLOR.rgb);
 if(use_palette) {
  if(UV.x<.5) colour=shirt.rgb;
  else if(UV.x<1.5) colour=skin.rgb;
  else if(UV.x<2.5) colour=hair.rgb;
  else if(UV.x>3.5 && UV.x<4.5) colour=nose.rgb;
  else if(UV.x>4.5) colour=seam.rgb;
 }
 ALBEDO=colour;
 ROUGHNESS=.42;
 SPECULAR=.378;
 CLEARCOAT=.252;
 CLEARCOAT_ROUGHNESS=.30;
}
