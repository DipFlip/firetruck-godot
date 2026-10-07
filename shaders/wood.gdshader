shader_type spatial;
render_mode diffuse_burley;
uniform vec4 timber : source_color = vec4(0.72,0.49,0.28,1.0);
uniform bool floorboards = true;
// Painted pieces keep a faint grain under a glossier coat of colour.
uniform bool painted = false;
// Bent arches: fibres follow the curve around this local-space centre (y,z).
uniform bool bent = false;
uniform vec2 bend_centre = vec2(1.9,0.0);
uniform bool cut_pool = false;
uniform vec4 pool_hole = vec4(0.0);
uniform float grain_seed = 0.37;
uniform vec3 rest_dimensions = vec3(0.0);
varying vec3 world;
varying vec3 wood_position;
varying vec3 dimensions;
varying float piece_seed;
float hash(float p){return fract(sin(p*127.1+31.7)*43758.5453);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 float a=hash(i.x+i.y*137.0),b=hash(i.x+1.0+i.y*137.0);
 float c=hash(i.x+(i.y+1.0)*137.0),d=hash(i.x+1.0+(i.y+1.0)*137.0);
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 dimensions=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 if(INSTANCE_CUSTOM.x>0.0) dimensions=INSTANCE_CUSTOM.xyz;
 else if(rest_dimensions.x>0.0) dimensions=rest_dimensions;
 wood_position=VERTEX*dimensions;
 piece_seed=INSTANCE_CUSTOM.x>0.0 ? INSTANCE_CUSTOM.w : grain_seed;
}
void fragment(){
 if(cut_pool && world.x>pool_hole.x && world.z>pool_hole.y && world.x<pool_hole.z && world.z<pool_hole.w){discard;}
 float seed=piece_seed;
 float seam=0.0;
 // along: distance down the fibres. across: position in the log's cross-section.
 float along;
 vec2 across;
 if(floorboards){
  float row=floor((world.z+4.0)/10.0);
  float length_board=30.0+hash(row+91.0)*23.0;
  float stagger=hash(row)*length_board;
  float board=floor((world.x+stagger)/length_board);
  seed=hash(row*37.0+board*73.0);
  vec2 cell=vec2(mod(world.x+stagger,length_board),mod(world.z+4.0,10.0));
  vec2 edge=min(cell,vec2(length_board,10.0)-cell);
  seam=(1.0-smoothstep(.02,.09,min(edge.x,edge.y)))*.22;
  along=cell.x;
  across=vec2(cell.y,0.0);
 }else if(bent){
  vec2 radial=wood_position.yz-bend_centre;
  along=atan(radial.x,radial.y)*length(radial);
  across=vec2(wood_position.x,length(radial));
 }else if(dimensions.z>dimensions.x){
  along=wood_position.z;
  across=wood_position.xy;
 }else{
  along=wood_position.x;
  across=wood_position.zy;
 }
 // Each piece is cut from its own log: the pith sits off to one side at a
 // random depth, so neighbouring pieces never share a continuous figure.
 float h1=hash(seed*813.0),h2=hash(seed*291.0+7.0),h3=hash(seed*57.0+3.0);
 float ring_scale=floorboards ? 1.25 : 2.4+h3*1.2;
 vec2 pith=vec2((h1-.5)*(floorboards ? 14.0 : 5.0),-(floorboards ? 9.0 : 2.2)-h2*(floorboards ? 14.0 : 4.0));
 along+=seed*317.0;
 // Rings drift slowly along the fibres, giving the arched cathedral figure.
 float drift=(noise(vec2(along*.09,seed*41.0))-.5)*2.6+(noise(vec2(along*.37,seed*13.0+across.x*.4))-.5)*.45;
 float radius=length(across-pith)+drift*.42;
 float rings=radius*ring_scale;
 float t=fract(rings);
 // Wide pale earlywood followed by a narrow, soft-edged darker latewood band.
 float late=smoothstep(.62,.86,t)*(1.0-smoothstep(.93,1.0,t));
 float filter=clamp(1.0-fwidth(rings)*1.4,0.0,1.0);
 float strength=(painted ? .07 : floorboards ? .13 : .18)*(.75+.5*hash(floor(rings)+seed*9.0));
 float shade=1.0-late*strength*filter-(1.0-filter)*strength*.28;
 // Fine broken fibres and soft colour mottling.
 float fibre_coord=radius*31.0;
 float fibres=noise(vec2(along*1.3,fibre_coord));
 shade+=(fibres-.5)*(painted ? .025 : .07)*clamp(1.0-fwidth(fibre_coord)*.8,0.0,1.0);
 shade+=(noise(vec2(along*.05,radius*.6)+seed*29.0)-.5)*(painted ? .03 : floorboards ? .05 : .08);
 shade+=(seed-.5)*(painted ? .05 : .14);
 shade-=seam;
 // Only a gentle falloff towards the far floor, away from the window.
 if(floorboards){shade*=mix(1.0,.9,smoothstep(100.0,220.0,length(world.xz)));}
 vec3 colour=timber.rgb;
 // Latewood is slightly warmer and redder, as in real beech and maple.
 if(!painted){colour=mix(colour,colour*vec3(1.0,.86,.72),late*filter*.55);}
 ALBEDO=colour*shade;
 ROUGHNESS=painted ? .36 : floorboards ? .70 : .55+late*.12;
 SPECULAR=painted ? .42 : .26;
}
