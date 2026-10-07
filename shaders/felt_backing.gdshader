shader_type spatial;
render_mode diffuse_burley;
varying vec3 cloth;
void vertex() { cloth=VERTEX; }
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.3)))*43758.5453); }
void fragment() {
 vec2 yarn=cloth.xy*75.0;
 vec2 weave=sin(yarn)/(1.0+fwidth(yarn)*fwidth(yarn));
 float fleck=hash(floor(cloth*55.0))-.5;
 ALBEDO=vec3(.63,.51,.34)*(1.0+(weave.x+weave.y)*.045+fleck*.1);
 NORMAL_MAP=vec3(.5+weave.x*.04,.5+weave.y*.04,1.0);
 ROUGHNESS=.98;
 SPECULAR=.1;
}
