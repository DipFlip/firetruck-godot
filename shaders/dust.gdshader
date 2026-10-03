shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Dust motes drifting through window light. Each instance wraps inside a box
// that follows the view, so a few hundred specks always fill the shot.
uniform vec3 centre = vec3(0.0);
uniform vec3 box_size = vec3(60.0,24.0,60.0);
uniform float strength = 1.0;
uniform vec4 tint : source_color = vec4(1.0,0.97,0.9,1.0);
varying float glow;
varying vec2 speck;
float hash(float p){return fract(sin(p*12.9898+4.1)*43758.5453);}
void vertex(){
 float id=float(INSTANCE_ID);
 float a=hash(id),b=hash(id+17.0),c=hash(id+41.0);
 vec3 base=MODEL_MATRIX[3].xyz;
 // Slow lazy wandering with a very gentle settle, like real airborne dust.
 vec3 drift=vec3(sin(TIME*(.05+a*.06)+a*40.0)*2.2+TIME*.10,
  sin(TIME*(.07+b*.05)+b*20.0)*.9-TIME*(.03+c*.05),
  cos(TIME*(.04+c*.06)+c*30.0)*2.2+TIME*.04);
 vec3 local=mod(base+drift-centre+box_size*.5,box_size)-box_size*.5;
 vec3 edge=abs(local)/(box_size*.5);
 float fade=1.0-smoothstep(.72,1.0,max(edge.x,max(edge.y,edge.z)));
 // Specks tumble, so each one glints now and then as it catches the sun.
 float twinkle=.5+.5*sin(TIME*(.6+b*1.4)+a*31.0);
 glow=fade*(.25+.75*twinkle*twinkle*twinkle)*strength;
 vec3 world=centre+local;
 vec3 right=INV_VIEW_MATRIX[0].xyz;
 vec3 up=INV_VIEW_MATRIX[1].xyz;
 float radius=mix(.035,.09,c*c);
 world+=(right*VERTEX.x+up*VERTEX.y)*radius*2.0;
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.0);
 speck=UV;
}
void fragment(){
 float d=length(speck-.5)*2.0;
 ALBEDO=tint.rgb;
 ALPHA=(1.0-smoothstep(.1,1.0,d))*glow*.3;
}
