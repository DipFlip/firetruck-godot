shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec2 p=world.xz;float lines=sin(p.x*3.0+sin(p.y*2.5+TIME*.7))*sin(p.y*3.3+cos(p.x*2.0-TIME*.5));float caustic=smoothstep(.54,.86,lines);ALBEDO=mix(vec3(.12,.48,.52),vec3(.49,.78,.74),caustic*.5);ROUGHNESS=.23;SPECULAR=.7;}
