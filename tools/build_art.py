"""Original bevelled miniature art. Blender background export, Godot coordinates in helpers."""
import bpy, math, random, os
from mathutils import Vector
OUT=os.path.abspath('assets/models')
random.seed(24)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
M={}
def mat(hex,rough=.65,metal=0):
    key=(hex,rough,metal)
    if key in M:return M[key]
    c=tuple(int(hex[i:i+2],16)/255 for i in (0,2,4))
    # glTF expects linear base colors, so convert art palette from sRGB.
    c=tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in c)
    m=bpy.data.materials.new(hex);m.diffuse_color=(*c,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1)
    bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    M[key]=m;return m
def g(p):return (p[0],-p[2],p[1])
def finish(o,name,color,bevel=0):
    o.name=name;o.data.materials.append(mat(color))
    if bevel:
        mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=3
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in o.data.polygons:poly.use_smooth=True
    return o
def box(name,p,s,c,bevel=.05):
    bpy.ops.mesh.primitive_cube_add(size=1,location=g(p));o=bpy.context.object
    o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,c,min(bevel,min(s)*.28))
def ball(name,p,s,c):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,radius=.5,location=g(p));o=bpy.context.object
    o.scale=(s[0],s[2],s[1]);return finish(o,name,c)
def cyl(name,p,r,h,c,axis='Y'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=h,location=g(p));o=bpy.context.object
    if axis=='X':o.rotation_euler.y=math.pi/2
    if axis=='Z':o.rotation_euler.x=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,c,.035)
def text(name,words,p,size,c,rot=(math.pi/2,0,0)):
    bpy.ops.object.text_add(location=g(p));o=bpy.context.object;o.name=name
    o.data.body=words;o.data.align_x='CENTER';o.data.align_y='CENTER';o.data.size=size;o.data.extrude=.006;o.rotation_euler=rot
    o.data.materials.append(mat(c));bpy.ops.object.convert(target='MESH');return bpy.context.object
def export(name):
    bpy.ops.object.select_all(action='SELECT')
    meshes=[o for o in bpy.context.selected_objects if o.type=='MESH']
    if meshes:
        bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',use_selection=True,export_yup=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

# Shared rounded unit cube for props authored in Godot.
box('RoundedCube',(0,0,0),(1,1,1),'ffffff',.075);export('rounded_cube')
# Truck. More compact cab, rounded fenders, ivory roof, warm red enamel.
red='ca5147';dark='293f49';ivory='f6e8c9';silver='b5c1b9';glass='558b99'
box('Chassis',(0,.0,0),(1.85,.35,4.35),dark)
box('TankBody',(0,.85,.55),(1.88,1.35,2.8),red,.16)
box('Cab',(0,1,-1.30),(1.98,1.75,1.6),red,.22)
box('CabRoof',(0,1.9,-1.3),(2.08,.18,1.7),ivory,.08)
box('Windshield',(0,1.45,-2.104),(1.68,.67,.045),glass,.1)
box('WindowDivider',(0,1.45,-2.14),(.075,.73,.045),ivory,.015)
box('Hood',(0,.8,-2.08),(1.89,.2,.24),red)
box('Bumper',(0,.27,-2.22),(2.12,.25,.3),silver,.08)
box('Grille',(0,.6,-2.204),(.78,.3,.04),dark)
for y in [.51,.6,.69]:box('GrilleSlat',(0,y,-2.233),(.7,.025,.025),silver,.005)
for x in [-1,1]:
    box('CabWindow',(x,1.45,-1.26),(.04,.65,1.0),glass,.1)
    box('DoorTrim',(x,1,-1.3),(.045,.08,1.2),ivory,.01)
    box('DoorHandle',(x*1.025,1.0,-.88),(.05,.08,.21),silver,.02)
    box('Step',(x,.2,-.7),(.38,.15,.7),silver,.04)
    box('ReflectiveStripe',(x*.948,.72,.6),(.04,.16,2.68),ivory,.01)
    for z in [-.15,.68,1.52]:
        box('EquipmentDoor',(x*.956,1.13,z),(.05,.62,.66),'82999b',.025)
        for y in [.93,1.06,1.19,1.32]:box('RollerSlat',(x*.99,y,z),(.02,.015,.60),'c1c9bd',.005)
        box('CompartmentLatch',(x*.99,.87,z),(.06,.08,.2),ivory,.02)
    box('MirrorStem',(x*1.12,1.46,-1.86),(.33,.06,.08),dark,.02)
    box('Mirror',(x*1.28,1.46,-1.86),(.13,.3,.22),dark,.04)
    cyl('Headlight',(x*.68,.72,-2.23),.19,.045,'ffe8a6','Z')
    cyl('LampRim',(x*.68,.72,-2.20),.22,.04,ivory,'Z')
    box('RearLamp',(x*.7,.63,2.0),(.25,.25,.08),'eb8d62')
    box('LightbarLens',(x*.58,2.06,-1.4),(.48,.18,.35),'82d9de',.07)
box('LightbarBase',(0,1.98,-1.4),(1.6,.10,.4),dark)
box('RoofDeck',(0,1.57,.55),(1.82,.10,2.7),ivory)
for x in [-.62,.62]:box('LadderRail',(x,1.78,.85),(.085,.1,2.0),silver,.025)
for z in range(8):box('LadderRung',(0,1.78,-.07+z*.26),(1.24,.065,.06),silver,.02)
# Side hose reel and brass valves.
cyl('HoseReel',(1.0,1.15,.58),.26,.1,'384f56','X')
cyl('HoseReelHub',(1.08,1.15,.58),.1,.04,'d9b879','X')
text('TruckNumber','04',(0,1.08,2.011),.45,ivory)
# Wheel wells: shallow arches trimmed from the lower body edge give tires room
# to travel while the body leans, with a thick rounded fender lip over each.
WELL=.62;WHEEL_Y=-.25
cutters=[]
for x in [-1,1]:
    for z in [-1.3,.85,1.65]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=WELL,depth=.5,location=g((x*1.0,WHEEL_Y,z)))
        c=bpy.context.object;c.rotation_euler=(0,math.pi/2,0)
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=False);cutters.append(c)
bpy.ops.object.select_all(action='DESELECT')
for c in cutters:c.select_set(True)
bpy.context.view_layer.objects.active=cutters[0];bpy.ops.object.join();cutter=bpy.context.object
for o in list(bpy.context.scene.objects):
    if o.type!='MESH' or o==cutter or o.name.split('.')[0] not in ('TankBody','Cab','Step'):continue
    mod=o.modifiers.new('Wheel well','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;mod.solver='EXACT'
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.data.objects.remove(cutter,do_unlink=True)
def fender(points,x):
    cu=bpy.data.curves.new('FenderCurve','CURVE');cu.dimensions='3D'
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for i,p in enumerate(points):sp.points[i].co=(*g((0,p[0],p[1])),1)
    cu.bevel_depth=.085;cu.bevel_resolution=5;cu.use_fill_caps=True
    o=bpy.data.objects.new('Fender',cu);bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.convert(target='MESH');o=bpy.context.object
    # Wide across the tire tread, round in section.
    o.scale=(2.6,1,1);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.location=(x,0,0);bpy.ops.object.transform_apply(location=True,rotation=False,scale=False)
    return finish(o,'Fender',red)
R=WELL+.06
def arc(zc,a,b,n=14):return [(WHEEL_Y+R*math.sin(a+(b-a)*i/n),zc+R*math.cos(a+(b-a)*i/n)) for i in range(n+1)]
# Lips stop where the arc meets the body's lower edge.
low=math.asin((-.16-WHEEL_Y)/R)
for x in [-1,1]:
    fender(arc(-1.3,low,math.pi-low,22),x*.86)
    # One continuous lip over the rear tandem.
    top=arc(1.65,low,math.pi/2,10)+arc(.85,math.pi/2,math.pi-low,10)
    fender(top,x*.86)
# Export the actual roof ladder separately, hinged at its rear end.
ladder_parts=[o for o in bpy.context.scene.objects if o.name.startswith(('LadderRail','LadderRung'))]
bpy.ops.object.select_all(action='DESELECT')
for o in ladder_parts:o.select_set(True)
bpy.context.view_layer.objects.active=ladder_parts[0];bpy.ops.object.join()
ladder=bpy.context.object;ladder.name='RoofLadderSection'
bpy.context.scene.cursor.location=g((0,1.78,1.85))
bpy.ops.object.origin_set(type='ORIGIN_CURSOR');ladder.location=(0,0,0)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'roof_ladder.glb'),export_format='GLB',use_selection=True,export_yup=True)
bpy.ops.object.delete(use_global=False)
export('engine_body')
if os.environ.get('ART_ONLY')=='truck':raise SystemExit
# Wheel built around the actual X axle. Visible lug nuts make rotation readable.
cyl('Tire',(0,0,0),.48,.32,dark,'X')
cyl('Sidewall',(.17,0,0),.385,.02,'1e3038','X')
cyl('Rim',(.19,0,0),.285,.045,'d8ddce','X')
cyl('Hub',(.23,0,0),.11,.06,'758f95','X')
for i in range(6):
    a=i*math.tau/6;cyl('Lug',(.223,math.sin(a)*.18,math.cos(a)*.18),.028,.035,'536d74','X')
for i in range(20):
    a=i*math.tau/20
    o=box('Tread',(0,math.sin(a)*.474,math.cos(a)*.474),(.27,.04,.085),'344952',.01)
    o.rotation_euler.x=-a
export('wheel')
# Cottage and shop roofs have overlapping tile courses, eaves, gutters and chimneys.
def building(kind,wall,roof):
    box('Foundation',(0,.18,0),(8.35,.36,6.4),'d4c9aa',.08)
    box('Plaster',(0,2.55,0),(8,4.8,6),wall,.13)
    box('LowerPlinth',(0,.52,0),(8.15,.28,6.14),'e4d7bb',.04)
    for x in [-3.87,3.87]:box('CornerStone',(x,2.6,3.035),(.2,4.6,.09),'f4e7ca',.02)
    # Pitched roof, ridge parallel to X.
    pitch=math.atan2(1.7,3.7)
    for side in [-1,1]:
        o=box('RoofBase',(0,5.60,side*1.75),(8.85,.18,4.05),roof,.05);o.rotation_euler.x=side*pitch
        for row in range(8):
            z=side*(.24+row*.46);y=6.59-abs(z)*math.tan(pitch)
            for col in range(13):
                x=-4.16+col*.69+(.16 if row%2 else 0)
                o=box('RoofTile',(x,y,z),(.68,.11,.57),roof if (row+col)%4 else ('b87961' if roof=='a96350' else '708c8c'),.035)
                o.rotation_euler.x=side*pitch
    cyl('Ridge',(0,6.5,0),.13,8.9,roof,'X')
    for side in [-1,1]:box('Gutter',(0,4.85,side*3.63),(8.9,.16,.16),'f2e4c9',.04)
    # Triangular gable ends: two bevelled slopes form a readable frame.
    for x in [-4.05,4.05]:
        for side in [-1,1]:
            o=box('GableTrim',(x,5.65,side*1.75),(.13,.14,4.0),'f2e4c9',.025);o.rotation_euler.x=side*pitch
    box('Chimney',(2.6,6.2,-1.3),(.7,1.7,.75),'b7846a',.06)
    box('ChimneyCap',(2.6,7.06,-1.3),(.92,.18,.95),'eadcc2',.04)
    for y in [5.8,6.12,6.44,6.76]:box('BrickJoint',(2.6,y,-.91),(.72,.027,.015),'d0a88a',.005)
    for x in [-2.6,2.6]:
        box('WindowFrame',(x,2.65,3.045),(1.9,1.9,.15),'f6e9ca',.04)
        box('WindowGlass',(x,2.65,3.14),(1.6,1.58,.08),'426f7b',.03)
        box('WindowMullion',(x,2.65,3.20),(.06,1.6,.04),'f6e9ca',.01)
        box('WindowMullion',(x,2.65,3.21),(1.6,.06,.04),'f6e9ca',.01)
        for side in [-1,1]:
            box('Shutter',(x+side*1.13,2.65,3.14),(.32,1.78,.15),'69938c',.03)
            for y in range(7):box('ShutterSlat',(x+side*1.13,1.95+y*.22,3.23),(.29,.06,.03),'496f6f',.01)
        box('FlowerBox',(x,1.58,3.35),(2.05,.38,.55),'ae7855',.05)
        for i in range(6):
            ball('Plant',(x-.82+i*.32,1.87,3.38),(.44,.42,.43),'78986b')
            ball('Flower',(x-.82+i*.32,2.02,3.41),(.16,.17,.15),'e7ba70' if i%2 else 'cf8480')
    box('DoorFrame',(0,1.5,3.07),(1.72,2.8,.2),'f1e1bc',.08)
    box('Door',(0,1.43,3.2),(1.42,2.57,.1),'4d7772',.08)
    box('DoorGlass',(0,1.88,3.27),(1.05,.92,.03),'82a8a4',.06)
    ball('BrassKnob',(.5,1.1,3.3),(.1,.1,.1),'d9b578')
    box('Doorstep',(0,.23,3.65),(2.2,.25,1),'cfbea0',.06)
    if kind=='bakery':
        for i in range(12):
            x=-3.8+i*.69
            o=box('AwningStripe',(x,3.87,3.75),(.69,.11,1.45),'e5b471' if i%2 else 'fff0ce',.025);o.rotation_euler.x=-.2
            box('AwningScallop',(x,3.68,4.42),(.68,.27,.09),'e5b471' if i%2 else 'fff0ce',.08)
        box('ShopSign',(0,4.44,3.15),(5.5,.55,.17),'4d7069',.06)
        text('SignLetters','SUNRISE BAKERY',(0,4.43,3.255),.32,'fff1ce')
    else:
        box('AddressPlate',(.9,2.75,3.18),(.4,.25,.04),'efddb6',.02)
    # Side windows make all viewpoints designed, not just the front.
    for x in [-4.06,4.06]:
        for z in [-1.45,1.2]:
            box('SideFrame',(x,2.6,z),(.13,1.8,1.55),'f2e5c9',.04)
            box('SideGlass',(x*1.017,2.6,z),(.04,1.48,1.25),'5f8790',.025)
            box('SideMullion',(x*1.025,2.6,z),(.04,1.5,.065),'f2e5c9',.01)

building('bakery','e5c896','a96350');export('bakery')
building('cottage','85a99c','607f83');export('cottage')
building('cottage','cd9a87','a96350');export('peach_house')
# Station: rounded bay arch, brickwork, decorative watch tower.
box('Station',(0,2.7,0),(8,5.4,6),'b96b55',.12)
box('Cornice',(0,5.45,0),(8.6,.3,6.6),'efdfbc',.06)
box('Roof',(0,5.7,0),(8.3,.22,6.3),'596e73',.05)
box('GarageFrame',(0,2.0,3.09),(5.65,3.95,.2),'f0dfba',.12)
box('GarageDoor',(0,1.94,3.22),(5.22,3.58,.12),'547c79',.1)
for y in range(10):box('GarageSlat',(0,.35+y*.35,3.30),(5.1,.035,.03),'93aaa0',.01)
for x in [-1.7,0,1.7]:box('GarageWindow',(x,2.95,3.35),(1.4,.45,.04),'a8c8bf',.04)
for x in [-3.5,3.5]:
    box('BayPillar',(x,2.65,3.05),(.4,5.1,.28),'dca47d',.04)
    cyl('WallLamp',(x,3.3,3.38),.16,.3,'ffe9b0')
box('Sign',(0,4.52,3.15),(5.8,.68,.2),'764a43',.08)
text('StationSign','MAPLE BAY  •  FIRE & RESCUE',(0,4.5,3.28),.28,'f8e9c8')
box('Tower',(-2.4,6.45,-1.3),(2.5,2.0,2.7),'c98766',.08)
box('TowerRoof',(-2.4,7.53,-1.3),(3,.22,3.2),'546d72',.05)
for x in [-3,-1.8]:box('TowerVent',(x,6.7,.07),(.55,.9,.06),'3e5961',.15)
export('station')
# Trees: layered irregular crowns, branching trunks, restrained color variation.
for variant in range(2):
    cyl('Trunk',(0,1.5,0),.24,3,'977251')
    for i in range(5):
        a=i*2.4; p=(math.sin(a)*.65,2.8+i*.12,math.cos(a)*.6)
        o=cyl('Branch',p,.1,1.5,'977251');o.rotation_euler.y=math.sin(a)*.5;o.rotation_euler.x=math.cos(a)*.5
    colors=['648963','78986b','8faa72','779669'] if variant==0 else ['afae68','c2b77d','9ea566','b6b574']
    for i in range(16):
        a=i*2.4;r=1.1 if i<11 else .55
        ball('Crown',(math.sin(a)*r,3.35+(i%4)*.48,math.cos(a)*r),(2.0+random.random()*.7,1.6+random.random()*.8,2+random.random()*.7),colors[i%len(colors)])
    export('tree_'+str(variant))
print('ART KIT EXPORTED')
