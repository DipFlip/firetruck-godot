shader_type spatial;
render_mode unshaded;
varying float height;
void vertex(){height=VERTEX.y+.5;float tip=max(0.0,height);VERTEX.x+=sin(TIME*7.0+MODEL_MATRIX[3].x*5.0+height*4.0)*tip*.15;VERTEX.xz*=1.0-tip*.52;}
void fragment(){vec3 yellow=vec3(1.0,.77,.23);vec3 orange=vec3(1.0,.24,.045);ALBEDO=mix(yellow,orange,smoothstep(.05,.9,height));EMISSION=ALBEDO*.55;ROUGHNESS=1.0;}
