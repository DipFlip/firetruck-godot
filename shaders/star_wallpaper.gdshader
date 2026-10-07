shader_type spatial;
render_mode diffuse_burley;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 grid=UV*vec2(40.0,12.0);
 vec2 cell=floor(grid);
 vec2 p=fract(grid)-vec2(.5);
 float turn=hash(cell)*6.283185;
 float angle=atan(p.y,p.x)+turn;
 float sector=abs(mod(angle+3.141593/5.0,6.283185/5.0)-3.141593/5.0);
 float radius=.095/(cos(sector)+2.2*sin(sector));
 float star=1.0-smoothstep(radius-.009,radius+.009,length(p));
 vec3 paper=vec3(.39,.54,.64);
 vec3 ink=mix(vec3(.91,.77,.48),vec3(.79,.86,.85),step(.55,hash(cell+vec2(2.0))));
 ALBEDO=mix(paper,ink,star);
 ROUGHNESS=.95;
 SPECULAR=.12;
}
