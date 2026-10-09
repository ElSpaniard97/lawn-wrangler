// Babylon is imported module by module so the web build only ships what the game uses.
import { Color3, Color4 } from '@babylonjs/core/Maths/math.color.js';
import { Vector3, Quaternion, Matrix } from '@babylonjs/core/Maths/math.vector.js';
import { Mesh } from '@babylonjs/core/Meshes/mesh.js';
import { MeshBuilder } from '@babylonjs/core/Meshes/meshBuilder.js';
import { VertexData } from '@babylonjs/core/Meshes/mesh.vertexData.js';
import { TransformNode } from '@babylonjs/core/Meshes/transformNode.js';
import { StandardMaterial } from '@babylonjs/core/Materials/standardMaterial.js';
import { DynamicTexture } from '@babylonjs/core/Materials/Textures/dynamicTexture.js';
import { MaterialPluginBase } from '@babylonjs/core/Materials/materialPluginBase.js';
import '@babylonjs/core/Meshes/thinInstanceMesh.js';
import { BLOCKED } from './lawn.js';

// All artwork is generated locally. No downloads, paid assets or image CDN.
export function buildGraphics(scene, shadows, lawn) {
  let seed = 7429;
  const random = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
  const materials = {};
  function material(name, hex, shine = 0) {
    const m = new StandardMaterial(name, scene);
    m.diffuseColor = Color3.FromHexString(hex);
    m.specularColor = new Color3(shine, shine, shine);
    m.specularPower = 64;
    materials[name] = m;
    return m;
  }
  function textured(name, base, kind) {
    const m = material(name, '#ffffff');
    const t = new DynamicTexture(name, 512, scene, true);
    const c = t.getContext();
    c.fillStyle = base; c.fillRect(0, 0, 512, 512);
    for (let i = 0; i < 16000; i++) {
      const x = random() * 512, y = random() * 512;
      c.fillStyle = random() > .5 ? '#ffffff0d' : '#00000018';
      c.fillRect(x, y, kind === 'wood' ? 1 : 2, kind === 'wood' ? 12 + random() * 60 : 2);
    }
    if (kind === 'siding') for (let y = 0; y < 512; y += 32) {
      c.fillStyle = '#00000028'; c.fillRect(0, y, 512, 2);
      c.fillStyle = '#ffffff70'; c.fillRect(0, y + 2, 512, 2);
    }
    if (kind === 'roof' || kind === 'pavers') for (let y = 0; y < 512; y += 32) {
      c.fillStyle = '#00000040'; c.fillRect(0, y, 512, 2);
      for (let x = (y / 32 % 2) * 32; x < 512; x += 64) c.fillRect(x, y, 2, 32);
    }
    t.update(); m.diffuseTexture = t;
    return m;
  }
  const orange = material('powder-coated orange', '#f07b16', .3);
  const plastic = material('mower plastic', '#252b2a', .12);
  const rubber = material('tire rubber', '#161c19');
  const steel = material('brushed metal', '#858f89', .55);
  const black = material('seat upholstery', '#171d1d', .05);
  const white = material('white trim', '#eee9df', .05);
  const siding = textured('clapboard', '#d9d4bf', 'siding');
  const cedar = textured('cedar grain', '#a68b62', 'wood');
  const bark = textured('bark', '#75634c', 'wood');
  const roofing = textured('shingles', '#52585a', 'roof');
  const stone = textured('pavers', '#b8b5a8', 'pavers');
  const mulch = textured('mulch', '#584837', 'wood');
  const lawnBase = textured('lawn texture', '#628532', 'noise');
  const glass = material('window glass', '#517b8e', .6);
  const shirt = textured('cotton shirt', '#414a50', 'noise');
  const jeans = material('denim', '#3a5770');
  const skin = material('skin', '#c99d79', .08);
  const green = material('leaf green', '#6a8c33'); green.backFaceCulling = false;
  const pink = material('pink petals', '#d56c9e');
  const cream = material('white petals', '#fff3cf');

  function finish(mesh, m, parent, cast = true) {
    mesh.material = m; if (parent) mesh.parent = parent;
    mesh.receiveShadows = true;
    if (cast) shadows.addShadowCaster(mesh);
    return mesh;
  }
  function box(name, w, h, d, x, y, z, m, parent, cast = true) {
    const o = MeshBuilder.CreateBox(name, { width: w, height: h, depth: d }, scene);
    o.position.set(x, y, z); return finish(o, m, parent, cast);
  }
  function sphere(name, sx, sy, sz, x, y, z, m, parent, cast = true) {
    const o = MeshBuilder.CreateSphere(name, { diameter: 1, segments: 12 }, scene);
    o.scaling.set(sx, sy, sz); o.position.set(x, y, z);
    return finish(o, m, parent, cast);
  }
  function cylinder(name, diameter, height, x, y, z, m, parent, top = diameter) {
    const o = MeshBuilder.CreateCylinder(name, { diameterBottom: diameter, diameterTop: top, height, tessellation: 20 }, scene);
    o.position.set(x, y, z); return finish(o, m, parent);
  }
  function rod(name, a, b, diameter, m, parent) {
    const from = new Vector3(...a), to = new Vector3(...b), direction = to.subtract(from);
    const o = cylinder(name, diameter, direction.length(), ...from.add(to).scale(.5).asArray(), m, parent);
    o.rotationQuaternion = Quaternion.FromUnitVectorsToRef(Vector3.Up(), direction.normalize(), new Quaternion());
    return o;
  }
  function foliage(name, points, scale = .2, cast = false) {
    const o = MeshBuilder.CreateSphere(name, { diameter: 1, segments: 6 }, scene);
    o.material = green;
    const buffer = new Float32Array(points.length * 16), colors = new Float32Array(points.length * 4);
    points.forEach(([x,y,z], i) => {
      const s = scale * (.65 + random() * .7);
      Matrix.Compose(new Vector3(s * 1.6, s * .16, s), Quaternion.RotationYawPitchRoll(random()*6.28,random()*3,random()*3),new Vector3(x,y,z)).copyToArray(buffer,i*16);
      const tint=.65+random()*.45;colors.set([tint,tint,.75+random()*.25,1],i*4);
    });
    o.thinInstanceSetBuffer('matrix',buffer,16);o.thinInstanceSetBuffer('color',colors,4);
    o.thinInstanceRefreshBoundingInfo();o.receiveShadows=true;
    if(cast)shadows.addShadowCaster(o);
    return o;
  }

  // Residential yard: siding, trim, porch, pergola, planted borders.
  box('outer ground',100,.15,100,0,-.18,0,lawnBase,null,false);
  box('house siding',8,4.6,14,-17,2.3,-4,siding);
  box('foundation',8.1,.45,14.1,-17,.22,-4,stone);
  for (const x of [-19.2,-14.8]) {
    const roof=box('pitched roof',5.4,.22,15.2,x,5.05,-4,roofing);
    roof.rotation.z=x<-17?.42:-.42;
  }
  box('fascia',.15,.28,15.1,-12.9,4.4,-4,white);
  box('gutter',.14,.12,14.9,-12.78,4.48,-4,steel);
  for (const z of [-10.7,2.7]) cylinder('downpipe',.08,4.3,-12.75,2.15,z,white);
  for (const z of [-8.6,-3.7,.6]) {
    box('window frame',.12,1.65,1.55,-12.93,2.85,z,white);
    box('window glass',.13,1.42,1.3,-12.84,2.85,z,glass);
    box('window mullion',.15,1.43,.04,-12.75,2.85,z,white);
    box('window sash',.15,.05,1.35,-12.75,2.85,z,white);
    box('window sill',.3,.12,1.75,-12.7,2.05,z,white);
  }
  box('porch floor',3.2,.27,10,-11.2,.135,-4,stone);
  box('porch step',.5,.12,5.5,-9.35,.06,-4,stone);
  for (const z of [-8.6,.6]) {
    box('porch column',.22,3.3,.22,-9.85,1.85,z,cedar);
    box('stone column base',.48,.65,.48,-9.85,.55,z,stone);
  }
  const porchRoof=box('porch canopy',3.55,.18,10.5,-11.3,3.75,-4,roofing);porchRoof.rotation.z=-.12;
  box('porch beam',.22,.28,10,-9.75,3.4,-4,cedar);
  box('door frame',.12,2.6,1.3,-12.91,1.55,-4.2,white);
  box('door',.14,2.4,1.1,-12.8,1.5,-4.2,glass);
  sphere('door handle',.07,.07,.07,-12.68,1.45,-3.83,steel);
  box('gas can',.3,.45,.25,-9,.3,-4,material('gas can red','#c3462b',.1));

  for (let z=-15.6;z<=15.6;z+=.32) box('fence board',.12,2.1,.3,12.65,1.05,z,cedar);
  for (const z of [-15.7,15.7]) {
    for(let x=-12.5;x<=12.5;x+=.32)box('fence board',.3,2.1,.12,x,1.05,z,cedar);
    for(let x=-12.5;x<=12.5;x+=2.5)box('fence post',.18,2.25,.18,x,1.125,z,cedar);
    for(const y of [.5,1.55])box('fence rail',25,.12,.12,0,y,z-.13,cedar);
  }
  for(let z=-15;z<=15;z+=2.5)box('fence post',.2,2.25,.2,12.65,1.125,z,cedar);
  for(const y of [.5,1.55])box('fence rail',.12,.12,31,12.5,y,0,cedar);
  box('patio',8,.1,4,4,.04,12,stone);
  for(const x of [1,7])for(const z of [10.4,13.6])box('pergola post',.18,3,.18,x,1.5,z,cedar);
  for(const z of [10.4,13.6])box('pergola beam',6.8,.2,.18,4,3,z,cedar);
  for(let x=.6;x<7.5;x+=.5)box('pergola slat',.12,.16,4,x,3.13,12,cedar);
  cylinder('patio table',1.3,.08,4,.8,12,plastic);
  cylinder('table leg',.12,.8,4,.4,12,steel);
  for(const x of [2.7,5.3]) {
    box('chair seat',.55,.09,.55,x,.55,12,plastic);
    box('chair back',.55,.65,.07,x,.85,12.3,plastic);
    for(const dx of [-.2,.2])for(const dz of [-.2,.2])rod('chair leg',[x+dx,0,12+dz],[x+dx,.55,12+dz],.04,steel);
  }

  const treeSpecs=[[10,8],[10,-10],[-11,9]];
  for(const [x,z] of treeSpecs) {
    cylinder('tree trunk',.42,4.2,x,2.1,z,bark,null,.22);
    for(let i=0;i<7;i++) {
      const angle=i*6.28/7;
      rod('tree branch',[x,2.4,z],[x+Math.cos(angle)*1.8,4.5+random(),z+Math.sin(angle)*1.8],.13,bark);
    }
    const leaves=[];
    for(let i=0;i<1600;i++) {
      const az=random()*6.28,v=random()*2-1,r=Math.cbrt(random()),horizontal=Math.sqrt(1-v*v)*r;
      leaves.push([x+Math.cos(az)*horizontal*2.6,5+v*r*1.8,z+Math.sin(az)*horizontal*2.6]);
    }
    foliage('tree canopy',leaves,.23,true);
    cylinder('tree mulch ring',1.35,.045,x,.03,z,mulch);
    const ring=MeshBuilder.CreateTorus('stone ring',{diameter:1.4,thickness:.12,tessellation:28},scene);ring.position.set(x,.075,z);finish(ring,stone);
  }
  for (let side of [-1,1]) for(let i=0;i<10;i++) {
    const x=side*12.25,z=-14+i*2.9;
    box('border mulch',.65,.04,2.65,x,.02,z,mulch,null,false);
    for(let dz=-1.15;dz<1.2;dz+=.35)box('border stone',.15,.12,.32,x-side*.38,.06,z+dz,stone);
    const leaves=[];
    for(let j=0;j<100;j++){const a=random()*6.28,r=Math.sqrt(random())*.48;leaves.push([x+Math.cos(a)*r,.25+random()*.6,z+Math.sin(a)*r]);}
    foliage('border shrubs',leaves,.16);
    for(let j=0;j<12;j++) {
      const fx=x+(random()-.5)*.4,fz=z+(random()-.5)*1.9,fy=.35+random()*.25;
      rod('flower stem',[fx,.02,fz],[fx,fy,fz],.015,green);
      sphere('flower',.12,.07,.12,fx,fy,fz,i%2?pink:cream,null,false);
    }
  }
  // Distant roofs peek above the fence without cluttering the playable lawn.
  for(const x of [-8,8]) {
    box('neighbor house',7,4,6,x,2,22,siding);
    for(const dx of [-1.8,1.8]){const r=box('neighbor roof',4.4,.18,7,x+dx,4.55,22,roofing);r.rotation.z=dx<0?.4:-.4;}
  }

  // Detailed zero-turn mower, facing +Z to match the simulation.
  const mower=new TransformNode('mower',scene),wheels=[];
  box('cutting deck',1.75,.17,.95,0,.23,.48,orange,mower);
  box('deck skirt',1.78,.06,.98,0,.15,.48,plastic,mower);
  for(const x of [-.5,0,.5])cylinder('spindle cover',.19,.05,x,.34,.5,plastic,mower);
  const chute=box('discharge chute',.38,.12,.5,.99,.22,.5,plastic,mower);chute.rotation.z=-.2;
  for(const x of [-.4,.4])box('frame rail',.08,.14,1.55,x,.38,-.05,orange,mower);
  box('rear bumper',1.05,.22,.14,0,.37,-.94,orange,mower);
  box('body pan',.78,.22,.72,0,.53,.05,plastic,mower);
  box('foot platform',.8,.05,.42,0,.47,.64,steel,mower);
  for(let z=.49;z<.82;z+=.06)box('footplate grooves',.73,.01,.015,0,.502,z,plastic,mower);
  box('seat cushion',.61,.13,.53,0,.81,-.07,black,mower);
  const back=box('high-back seat',.61,.64,.13,0,1.11,-.36,black,mower);back.rotation.x=.1;
  for(const x of [-.27,.27])sphere('seat bolster',.13,.52,.16,x,1.08,-.29,black,mower);
  for(const x of [-.72,.72]) {
    box('fender',.42,.1,.78,x,.72,-.48,plastic,mower);
    box('control tower',.22,.36,.3,x*.65,.76,.06,plastic,mower);
    cylinder('cup holder',.1,.035,x*.65,.96,.03,black,mower);
    rod('lap bar',[x*.65,.87,.16],[x*.65,1.14,.32],.035,steel,mower);
    rod('bar grip',[x*.65,1.14,.32],[x*.2,1.14,.34],.045,black,mower);
    box('fuel tank',.25,.22,.34,x*.67,.78,-.65,plastic,mower);
    cylinder('fuel cap',.09,.045,x*.67,.915,-.66,orange,mower);
  }
  box('engine block',.68,.34,.46,0,.65,-.68,plastic,mower);
  cylinder('engine fan housing',.51,.12,0,.9,-.67,black,mower);
  cylinder('fan grille',.42,.025,0,.975,-.67,steel,mower);
  for(let x=-.17;x<=.17;x+=.055)for(let z=-.82;z<-.5;z+=.055)cylinder('fan hole',.025,.03,x,.995,z,black,mower);
  for(let x=-.28;x<=.28;x+=.045)box('cooling fins',.02,.23,.015,x,.68,-.923,steel,mower);
  const exhaust=cylinder('muffler',.14,.45,0,.45,-.98,steel,mower);exhaust.rotation.z=Math.PI/2;
  for(const [x,z,r,w] of [[-.73,-.48,.36,.31],[.73,-.48,.36,.31],[-.57,.86,.15,.14],[.57,.86,.15,.14]]) {
    const pivot=new TransformNode('wheel pivot',scene);pivot.parent=mower;pivot.position.set(x,r,z);pivot.rotation.z=Math.PI/2;wheels.push({pivot,r});
    cylinder('tire',r*2,w,0,0,0,rubber,pivot);
    cylinder('wheel hub',r*.95,w+.015,0,0,0,steel,pivot);
    cylinder('hub center',r*.34,w+.035,0,0,0,plastic,pivot);
    if(r>.2)for(let i=0;i<22;i++)for(const side of [-1,1]) {
      const a=i*6.28/22,lug=box('tire tread',.07,w*.48,.035,Math.cos(a)*r,side*w*.24,Math.sin(a)*r,rubber,pivot);
      lug.rotation.y=-a;lug.rotation.x=side*.3;
    }
    else rod('caster fork',[x,.2,z],[x,.48,z],.07,orange,mower);
  }
  function person(name,parent,seated) {
    const p=new TransformNode(name,scene);if(parent)p.parent=parent;
    const hip=seated?.99:.93,torso=seated?1.31:1.25;
    sphere('person torso',.57,.7,.32,0,torso,-.04,shirt,p);
    sphere('neck',.13,.15,.13,0,torso+.38,0,skin,p);
    sphere('head',.29,.34,.28,0,torso+.57,0,skin,p);
    sphere('cap',.32,.16,.31,0,torso+.72,-.02,plastic,p);
    box('cap brim',.31,.035,.21,0,torso+.66,.18,plastic,p);
    const headset=MeshBuilder.CreateTorus('headset band',{diameter:.36,thickness:.027,tessellation:20},scene);headset.parent=p;headset.position.set(0,torso+.6,0);headset.rotation.x=Math.PI/2;finish(headset,black,p);
    for(const side of [-1,1]) {
      sphere('ear protector',.085,.16,.13,side*.17,torso+.57,0,orange,p);
      const elbow=[side*.36,torso-.17,.13],hand=[side*.23,torso-.25,seated?.38:.32];
      rod('sleeve',[side*.23,torso+.15,0],elbow,.2,shirt,p);
      rod('forearm',elbow,hand,.135,skin,p);sphere('hand',.13,.14,.12,...hand,skin,p);
      const knee=[side*.22,seated?.69:.52,seated?.38:.05];
      rod('jeans thigh',[side*.18,hip,0],knee,.23,jeans,p);
      rod('jeans calf',knee,[side*.22,.29,seated?.58:.02],.18,jeans,p);
      sphere('work shoe',.22,.14,.36,side*.22,seated?.5:.1,seated?.66:.12,black,p);
    }
    // A small blade motif on the back of the shirt, inspired by the reference.
    for(let i=-1;i<=1;i++)rod('shirt emblem',[i*.035,torso-.04,-.205],[i*.07,torso+.17,-.205],.018,white,p);
    return p;
  }
  const driver=person('driver',mower,true),walker=person('walker',null,false);
  rod('trimmer shaft',[.22,1.08,.28],[.22,.12,1],.035,steel,walker);
  cylinder('trimmer guard',.32,.06,.22,.12,1,plastic,walker);
  box('trimmer motor',.2,.22,.24,.22,.95,-.08,orange,walker);

  // Each thin instance is a tapered, curved ribbon, rather than a spike.
  const blade=new Mesh('curved grass',scene),data=new VertexData();
  data.positions=[];data.uvs=[];data.indices=[];
  for(let level=0;level<5;level++) {
    const t=level/4,width=.025*(1-t)+.001,bend=.12*t*t;
    data.positions.push(-width+bend,t*.58,0,width+bend,t*.58,0);
    data.uvs.push(0,t,1,t);
    if(level<4){const i=level*2;data.indices.push(i,i+1,i+2,i+1,i+3,i+2);}
  }
  data.normals=[];VertexData.ComputeNormals(data.positions,data.indices,data.normals);data.applyToMesh(blade);
  const grassMat=material('living grass','#ffffff');grassMat.backFaceCulling=false;grassMat.specularColor=new Color3(.03,.035,.01);grassMat.emissiveColor=new Color3(.045,.055,.015);
  const gradient=new DynamicTexture('blade gradient',{width:32,height:256},scene,false),g=gradient.getContext(),gr=g.createLinearGradient(0,0,0,256);
  gr.addColorStop(0,'#3f5b20');gr.addColorStop(.4,'#799b36');gr.addColorStop(1,'#b3cb60');g.fillStyle=gr;g.fillRect(0,0,32,256);gradient.update();grassMat.diffuseTexture=gradient;blade.material=grassMat;blade.receiveShadows=true;
  class GrassWind extends MaterialPluginBase {
    constructor(m){super(m,'GrassWind',200,{GRASS_WIND:true});this.time=0;this._enable(true);}
    prepareDefines(defines){defines.GRASS_WIND=true;}
    getClassName(){return 'GrassWind';}
    getUniforms(){return {ubo:[{name:'grassTime',size:1,type:'float'}],vertex:'uniform float grassTime;'};}
    bindForSubMesh(buffer){buffer.updateFloat('grassTime',this.time);}
    getCustomCode(type){return type==='vertex'?{CUSTOM_VERTEX_UPDATE_POSITION:`
      #ifdef GRASS_WIND
      positionUpdated.x += sin(grassTime * 1.6 + world3.x * .7 + world3.z * .9) * positionUpdated.y * positionUpdated.y * .15;
      #endif
    `}:null;}
  }
  const wind=new GrassWind(grassMat),perCell=18,count=lawn.cells.length*perCell;
  let quality='high';
  const matrices=new Float32Array(count*16),colors=new Float32Array(count*4),samples=[];
  for(let id=0;id<lawn.cells.length;id++)for(let j=0;j<perCell;j++) {
    const center=lawn.center(id),x=center.x+(random()-.5)*lawn.cell,z=center.z+(random()-.5)*lawn.cell,h=.65+random()*.65,angle=random()*6.28;
    samples.push({x,z,h,angle,width:.65+random()*.7});const tint=.7+random()*.4;colors.set([tint,.85+random()*.15,.7+random()*.3,1],(id*perCell+j)*4);
  }
  blade.thinInstanceSetBuffer('matrix',matrices,16,false);blade.thinInstanceSetBuffer('color',colors,4);
  function refreshGrass(ids) {
    for(const id of ids)for(let j=0;j<perCell;j++) {
      const index=id*perCell+j,s=samples[index],state=lawn.cells[id],h=state===BLOCKED||(quality==='medium'&&j%2)?0:state===0?s.h:.055;
      Matrix.Compose(new Vector3(s.width,h,1),Quaternion.RotationAxis(Vector3.Up(),s.angle),new Vector3(s.x,.018,s.z)).copyToArray(matrices,index*16);
    }
    blade.thinInstanceBufferUpdated('matrix');
  }
  refreshGrass(Array.from({length:lawn.cells.length},(_,i)=>i));blade.thinInstanceRefreshBoundingInfo();
  // Merge static scenery by material to keep the richer yard affordable to draw.
  const groups=new Map();
  for(const mesh of [...scene.meshes])if(mesh!==blade&&!mesh.parent&&!mesh.thinInstanceCount){
    const group=groups.get(mesh.material)||[];group.push(mesh);groups.set(mesh.material,group);
  }
  for(const meshes of groups.values())if(meshes.length>1){
    for(const mesh of meshes){mesh.computeWorldMatrix(true);shadows.removeShadowCaster(mesh);}
    const merged=Mesh.MergeMeshes(meshes,true,true);if(merged){merged.receiveShadows=true;shadows.addShadowCaster(merged);}
  }
  const skyTexture=new DynamicTexture('summer sky',{width:2048,height:1024},scene,false),skyContext=skyTexture.getContext();
  const skyGradient=skyContext.createLinearGradient(0,0,0,1024);skyGradient.addColorStop(0,'#dbe5d9');skyGradient.addColorStop(.5,'#86bddc');skyGradient.addColorStop(1,'#3682c4');skyContext.fillStyle=skyGradient;skyContext.fillRect(0,0,2048,1024);
  for(let i=0;i<35;i++){const x=random()*2048,y=550+random()*250;for(let j=0;j<10;j++){skyContext.fillStyle='#ffffff20';skyContext.beginPath();skyContext.ellipse(x+(random()-.5)*150,y+(random()-.5)*35,30+random()*65,10+random()*24,0,0,6.28);skyContext.fill();}}
  skyTexture.update();const sky=MeshBuilder.CreateSphere('sky dome',{diameter:160,segments:32,sideOrientation:Mesh.BACKSIDE},scene),skyMaterial=material('sky material','#000000');skyMaterial.disableLighting=true;skyMaterial.emissiveColor=Color3.Black();skyMaterial.emissiveTexture=skyTexture;sky.material=skyMaterial;sky.isPickable=false;sky.infiniteDistance=true;
  return {mower,driver,walker,blade,refreshGrass,lawnBase,update(dt,speed){wind.time+=dt;for(const {pivot,r} of wheels)pivot.rotation.y-=speed*dt/r;},setQuality(q){quality=q;refreshGrass(Array.from({length:lawn.cells.length},(_,i)=>i));}};
}
