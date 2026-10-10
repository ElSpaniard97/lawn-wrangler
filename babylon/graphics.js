// Babylon is imported module by module so the web build only ships what the game uses.
import { Color3, Color4 } from '@babylonjs/core/Maths/math.color.js';
import { Vector3, Quaternion, Matrix } from '@babylonjs/core/Maths/math.vector.js';
import { Mesh } from '@babylonjs/core/Meshes/mesh.js';
import { MeshBuilder } from '@babylonjs/core/Meshes/meshBuilder.js';
import { VertexData } from '@babylonjs/core/Meshes/mesh.vertexData.js';
import { TransformNode } from '@babylonjs/core/Meshes/transformNode.js';
import { StandardMaterial } from '@babylonjs/core/Materials/standardMaterial.js';
import { DynamicTexture } from '@babylonjs/core/Materials/Textures/dynamicTexture.js';
import { Texture } from '@babylonjs/core/Materials/Textures/texture.js';
import { MaterialPluginBase } from '@babylonjs/core/Materials/materialPluginBase.js';
import { FresnelParameters } from '@babylonjs/core/Materials/fresnelParameters.js';
import { RenderTargetTexture } from '@babylonjs/core/Materials/Textures/renderTargetTexture.js';
import { ReflectionProbe } from '@babylonjs/core/Probes/reflectionProbe.js';
import '@babylonjs/core/Meshes/thinInstanceMesh.js';
import { BLOCKED, YARD, trees } from './lawn.js';

// Models are generated locally; scenery uses the photo textures shared with the Godot
// edition (listed in ASSET_LICENSES.md). Vite bundles them, so nothing loads from a CDN.
export const photos={
  grass:new URL('../godot/textures/grass.jpg',import.meta.url).href,
  wood:new URL('../godot/textures/wood.jpg',import.meta.url).href,
  siding:new URL('../godot/textures/siding_white.jpg',import.meta.url).href,
  shingles:new URL('../godot/textures/shingles.jpg',import.meta.url).href,
  stone:new URL('../godot/textures/stone.jpg',import.meta.url).href,
  mulch:new URL('../godot/textures/mulch.jpg',import.meta.url).href,
  pavers:new URL('../godot/textures/pavers.jpg',import.meta.url).href,
  leaves:new URL('../godot/textures/leaves.jpg',import.meta.url).href,
  lawn:new URL('./textures/lawn_detail.jpg',import.meta.url).href,
  // Cut from Zeke's second texture sheet (2026-10-09); only the browser edition uses these.
  sidingGray:new URL('./textures/siding_gray.jpg',import.meta.url).href,
  stoneAccent:new URL('./textures/stone_accent.jpg',import.meta.url).href,
  gravel:new URL('./textures/gravel.jpg',import.meta.url).href,
  window:new URL('./textures/window.jpg',import.meta.url).href,
  door:new URL('./textures/front_door.jpg',import.meta.url).href,
};
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
  // Photo materials repeat every `tile` metres; UVs are projected from world space before merging.
  const tiles=new Map();
  function photo(name,file,tile,tint='#ffffff') {
    const m=material(name,tint),t=new Texture(photos[file],scene);
    m.diffuseTexture=t;tiles.set(m,tile);return m;
  }
  function worldUVs(mesh,tile) {
    const p=mesh.getVerticesData('position'),n=mesh.getVerticesData('normal');if(!p||!n)return;
    const world=mesh.computeWorldMatrix(true),uv=new Float32Array(p.length/3*2),v=new Vector3(),w=new Vector3();
    for(let i=0;i<p.length/3;i++) {
      Vector3.TransformCoordinatesFromFloatsToRef(p[i*3],p[i*3+1],p[i*3+2],world,v);
      Vector3.TransformNormalFromFloatsToRef(n[i*3],n[i*3+1],n[i*3+2],world,w);
      const ax=Math.abs(w.x),ay=Math.abs(w.y),az=Math.abs(w.z),[a,b]=ay>=ax&&ay>=az?[v.x,v.z]:ax>=az?[v.z,v.y]:[v.x,v.y];
      uv[i*2]=a/tile;uv[i*2+1]=b/tile;
    }
    mesh.setVerticesData('uv',uv);
  }
  const orange = material('powder-coated orange', '#e2560c', .35);
  const plastic = material('mower plastic', '#252b2a', .12);
  const rubber = material('tire rubber', '#161c19');
  const steel = material('brushed metal', '#858f89', .55);
  const black = material('seat upholstery', '#171d1d', .05);
  const white = material('white trim', '#eee9df', .05);
  const siding = photo('clapboard','siding',2);
  const cedar = photo('cedar boards','wood',1);
  const bark = photo('bark','wood',.8,'#8a7c70');
  const roofing = photo('shingles','shingles',2);
  const stone = photo('pavers','pavers',1.5);
  const edging = photo('edging stone','stone',.8);
  const mulch = photo('mulch','mulch',.8);
  const lawnBase = photo('lawn texture','lawn',1.6,'#b4bea4');
  const sidingGray = photo('gray clapboard','sidingGray',2);
  const stoneAccent = photo('stone veneer','stoneAccent',1.2);
  const gravel = photo('river rock','gravel',.9);
  // Windows and the front door are single photos on planes, not tiled.
  function picture(name,file,shine=.2){const m=material(name,'#ffffff',shine);m.diffuseTexture=new Texture(photos[file],scene);return m;}
  const windowPhoto = picture('window photo','window',.5),doorPhoto = picture('door photo','door',.3);
  const shirt = textured('cotton shirt', '#414a50', 'noise');
  const jeans = material('denim', '#3a5770');
  const skin = material('skin', '#c99d79', .08);

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
  // A picture plane facing +x, -z or +z (yaw), e.g. a window photo on a wall.
  function pane(name,w,h,x,y,z,yaw,m){const o=MeshBuilder.CreatePlane(name,{width:w,height:h},scene);o.position.set(x,y,z);o.rotation.y=yaw;return finish(o,m,null,false);}
  // A gable end: a triangle of wall under the roof, facing both ways.
  function gable(name,w,rise,x,y,z,m,alongX=true){
    const o=new Mesh(name,scene),d=new VertexData(),p=alongX?[-w/2,0,0,w/2,0,0,0,rise,0]:[0,0,-w/2,0,0,w/2,0,rise,0];
    d.positions=[...p,...p];d.indices=[0,1,2,3,5,4];d.normals=[];VertexData.ComputeNormals(d.positions,d.indices,d.normals);d.uvs=[0,0,1,0,.5,1,0,0,1,0,.5,1];d.applyToMesh(o);
    o.position.set(x,y,z);return finish(o,m);
  }
  function rod(name, a, b, diameter, m, parent) {
    const from = new Vector3(...a), to = new Vector3(...b), direction = to.subtract(from);
    const o = cylinder(name, diameter, direction.length(), ...from.add(to).scale(.5).asArray(), m, parent);
    o.rotationQuaternion = Quaternion.FromUnitVectorsToRef(Vector3.Up(), direction.normalize(), new Quaternion());
    return o;
  }
  // Cutout foliage: leaf clusters and flowering plants are painted onto transparent textures,
  // then shown on crossed cards so shrubs, flowers and tree canopies read as leaves, not blobs.
  function painted(name,size,paint){
    const t=new DynamicTexture(name,size,scene,true),c=t.getContext();c.clearRect(0,0,size,size);paint(c,size);t.hasAlpha=true;t.update();
    const m=material(name,'#ffffff');m.diffuseTexture=t;m.backFaceCulling=false;m.specularColor=new Color3(.05,.06,.03);return m;
  }
  function leaf(c,x,y,len,angle,color){c.save();c.translate(x,y);c.rotate(angle);c.fillStyle=color;c.beginPath();c.moveTo(0,0);c.quadraticCurveTo(len*.5,-len*.32,len,0);c.quadraticCurveTo(len*.5,len*.32,0,0);c.fill();c.restore();}
  const leafColors=(light)=>{const h=78+random()*34,l=light*(22+random()*24);return `hsl(${h},${38+random()*25}%,${l}%)`;};
  const leafCards=painted('leaf cluster',256,(c,n)=>{
    for(let i=0;i<900;i++){const a=random()*6.28,r=Math.sqrt(random())*n*.44,x=n/2+Math.cos(a)*r,y=n/2+Math.sin(a)*r*.9,depth=1-r/(n*.44);
      leaf(c,x,y,10+random()*12,random()*6.28,leafColors(.8+(1-depth)*.5+(y<n/2?.25:0)));}
  });
  const flowerCards=painted('flowering plant',256,(c,n)=>{
    for(let i=0;i<420;i++){const x=n*.12+random()*n*.76,y=n*.35+random()*n*.62;leaf(c,x,y,9+random()*10,-Math.PI/2+(random()-.5)*2.4,leafColors(.75+random()*.3));}
    const petals=['#e2669c','#f5b3cf','#fff2d2','#f4d35e','#b07ad6'];
    for(let i=0;i<34;i++){
      const x=n*.15+random()*n*.7,y=n*.12+random()*n*.5,r=5+random()*5,color=petals[Math.floor(random()*petals.length)];
      c.strokeStyle='#4f7a2a';c.lineWidth=2;c.beginPath();c.moveTo(x,y);c.lineTo(x+(random()-.5)*8,n*.95);c.stroke();
      for(let k=0;k<5;k++){const a=k*1.2566+random()*.3;c.fillStyle=color;c.beginPath();c.ellipse(x+Math.cos(a)*r*.7,y+Math.sin(a)*r*.7,r*.7,r*.45,a,0,6.28);c.fill();}
      c.fillStyle='#f0c23a';c.beginPath();c.arc(x,y,r*.32,0,6.28);c.fill();
    }
  });
  // A card is three upright planes crossed at 60 degrees; normals point up so both sides light evenly.
  function cardMesh(name,m){
    const o=new Mesh(name,scene),d=new VertexData();d.positions=[];d.indices=[];d.uvs=[];d.normals=[];
    for(let k=0;k<3;k++){const a=k*Math.PI/3,cx=Math.cos(a)*.5,cz=Math.sin(a)*.5,i=k*4;
      d.positions.push(-cx,0,-cz,cx,0,cz,cx,1,cz,-cx,1,-cz);
      d.uvs.push(0,0,1,0,1,1,0,1);d.normals.push(0,1,0,0,1,0,0,1,0,0,1,0);d.indices.push(i,i+1,i+2,i,i+2,i+3);}
    d.applyToMesh(o);o.material=m;o.receiveShadows=true;return o;
  }
  function cards(name,m,list,cast=false){
    const o=cardMesh(name,m),buffer=new Float32Array(list.length*16),colors=new Float32Array(list.length*4);
    list.forEach(({x,y,z,size,yaw=random()*6.28,tilt=0,tint=1},i)=>{
      Matrix.Compose(new Vector3(size,size,size),Quaternion.RotationYawPitchRoll(yaw,tilt,0),new Vector3(x,y,z)).copyToArray(buffer,i*16);colors.set([tint,tint,tint*(.9+random()*.15),1],i*4);
    });
    o.thinInstanceSetBuffer('matrix',buffer,16);o.thinInstanceSetBuffer('color',colors,4);o.thinInstanceRefreshBoundingInfo();
    if(cast)shadows.addShadowCaster(o);return o;
  }
  // A dog-ear fence picket: a flat board with its two top corners clipped, extruded to thickness.
  function picket(name,w,h,t,x,y,z,yaw,m){
    const ear=w*.3,outline=[[-w/2,0],[w/2,0],[w/2,h-ear],[w/2-ear,h],[-w/2+ear,h],[-w/2,h-ear]],o=new Mesh(name,scene),d=new VertexData();
    d.positions=[];d.indices=[];
    for(const side of [-1,1]){const base=d.positions.length/3;for(const [px,py] of outline)d.positions.push(px,py,side*t/2);for(let i=1;i<outline.length-1;i++)side>0?d.indices.push(base,base+i,base+i+1):d.indices.push(base,base+i+1,base+i);}
    for(let i=0;i<outline.length;i++){const [ax,ay]=outline[i],[bx,by]=outline[(i+1)%outline.length],base=d.positions.length/3;d.positions.push(ax,ay,-t/2,bx,by,-t/2,bx,by,t/2,ax,ay,t/2);d.indices.push(base,base+2,base+1,base,base+3,base+2);}
    d.normals=[];VertexData.ComputeNormals(d.positions,d.indices,d.normals);d.applyToMesh(o);
    o.position.set(x,y,z);o.rotation.y=yaw;return finish(o,m);
  }

  // Residential yard: siding, trim, porch, pergola, planted borders.
  // The house and patio are modelled at fixed spots and shifted into place, so they follow YARD.
  function shifted(dx,dz,build){const first=scene.meshes.length;build();for(const m of scene.meshes.slice(first)){m.position.x+=dx;m.position.z+=dz;}}
  const HX=YARD.halfX,HZ=YARD.halfZ;
  box('outer ground',100,.15,100,0,-.18,0,lawnBase,null,false);
  // The house and porch, and each tree's trunk and crown, are grouped so loaded models can stand in for them.
  const procHouse=new TransformNode('procedural house',scene),procTrees=new TransformNode('procedural trees',scene),houseStart=scene.meshes.length;
  shifted(12-HX,0,()=>{
  box('house siding',8,4.6,14,-17,2.3,-4,siding);
  box('foundation',8.1,.45,14.1,-17,.22,-4,stoneAccent);
  for(const z of [-11,3])gable('gable end',8,1.45,-17,4.6,z,siding);
  box('chimney',.9,3.4,.9,-19,5.1,1.6,stoneAccent);box('chimney cap',1.05,.12,1.05,-19,6.85,1.6,edging);
  for(const x of [-19,-15])for(const [z,yaw] of [[3.02,Math.PI],[-11.02,0]]){box('window trim',1.5,1.65,.06,x,2.85,z,white);pane('window',1.3,1.42,x,2.85,z+(yaw?.04:-.04),yaw,windowPhoto);}
  for (const x of [-19.2,-14.8]) {
    const roof=box('pitched roof',5.4,.22,15.2,x,5.05,-4,roofing);
    roof.rotation.z=x<-17?.42:-.42;
  }
  box('fascia',.15,.28,15.1,-12.9,4.4,-4,white);
  box('gutter',.14,.12,14.9,-12.78,4.48,-4,steel);
  for (const z of [-10.7,2.7]) cylinder('downpipe',.08,4.3,-12.75,2.15,z,white);
  for (const z of [-8.6,-3.7,.6]) {
    box('window frame',.12,1.65,1.55,-12.93,2.85,z,white);
    pane('window',1.3,1.42,-12.86,2.85,z,-Math.PI/2,windowPhoto);
    box('window sill',.3,.12,1.75,-12.7,2.05,z,white);
  }
  box('porch floor',3.2,.27,10,-11.2,.135,-4,cedar);
  box('porch step',.5,.12,5.5,-9.35,.06,-4,stone);
  for (const z of [-8.6,.6]) {
    box('porch column',.22,3.3,.22,-9.85,1.85,z,cedar);
    box('stone column base',.5,.75,.5,-9.85,.5,z,stoneAccent);box('column cap',.58,.06,.58,-9.85,.9,z,edging);
  }
  const porchRoof=box('porch canopy',3.55,.18,10.5,-11.3,3.75,-4,roofing);porchRoof.rotation.z=-.12;
  box('porch beam',.22,.28,10,-9.75,3.4,-4,cedar);
  box('door frame',.12,2.6,1.3,-12.91,1.55,-4.2,white);
  pane('front door',1.1,2.4,-12.84,1.5,-4.2,-Math.PI/2,doorPhoto);
  box('gas can',.3,.45,.25,-9,.3,-4,material('gas can red','#c3462b',.1));
  });
  for(const mesh of scene.meshes.slice(houseStart))if(mesh.name!=='gas can'){if(tiles.has(mesh.material))worldUVs(mesh,tiles.get(mesh.material));mesh.setParent(procHouse);}

  for (let z=-HZ-.6;z<=HZ+.6;z+=.32) picket('fence board',.3,2.1,.03,HX+.72,0,z,Math.PI/2,cedar);
  for (const z of [-HZ-.7,HZ+.7]) {
    for(let x=-HX-.5;x<=HX+.5;x+=.32)picket('fence board',.3,2.1,.03,x,0,z+Math.sign(z)*.05,0,cedar);
    for(let x=-HX-.5;x<=HX+.5;x+=2.5)box('fence post',.18,2.25,.18,x,1.125,z,cedar);
    for(const y of [.5,1.55])box('fence rail',HX*2+1,.12,.12,0,y,z-Math.sign(z)*.13,cedar);
  }
  for(let z=-HZ;z<=HZ;z+=2.5)box('fence post',.2,2.25,.2,HX+.65,1.125,z,cedar);
  for(const y of [.5,1.55])box('fence rail',.12,.12,HZ*2+1,HX+.5,y,0,cedar);
  shifted(1,HZ-15,()=>{
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
  });

  for(const [x,z] of trees) {
    const treeStart=scene.meshes.length;
    cylinder('tree trunk',.42,4.2,x,2.1,z,bark,null,.22);
    for(let i=0;i<7;i++) {
      const angle=i*6.28/7;
      rod('tree branch',[x,2.4,z],[x+Math.cos(angle)*1.8,4.5+random(),z+Math.sin(angle)*1.8],.13,bark);
    }
    // Leaf cards fill the crown; the ones underneath and inside are darker, as if shaded.
    const crown=[];
    for(const [bx,by,bz,br] of [[0,5.2,0,1.9],[1.2,4.7,.4,1.3],[-1.1,4.8,-.5,1.3],[.3,4.6,-1.2,1.2],[-.4,4.5,1.2,1.2],[.1,6.3,.1,1.2]])
      for(let i=0;i<70;i++){const az=random()*6.28,v=random()*2-1,r=Math.cbrt(random()),hz=Math.sqrt(1-v*v)*r;
        crown.push({x:x+bx+Math.cos(az)*hz*br,y:by+v*r*br*.85-.55,z:z+bz+Math.sin(az)*hz*br,size:.95+random()*.5,tilt:(random()-.5)*.6,tint:.62+r*.32+v*.14});}
    cards('tree canopy',leafCards,crown,true);
    for(const mesh of scene.meshes.slice(treeStart)){if(tiles.has(mesh.material))worldUVs(mesh,tiles.get(mesh.material));mesh.setParent(procTrees);}
    cylinder('tree mulch ring',1.35,.045,x,.03,z,mulch);
    const ring=MeshBuilder.CreateTorus('stone ring',{diameter:1.4,thickness:.12,tessellation:28},scene);ring.position.set(x,.075,z);finish(ring,edging);
  }
  const shrubs=[],flowers=[];
  for (let side of [-1,1]) for(let i=0;i<12;i++) {
    const x=side*(HX+.25),z=-HZ+1.5+i*3;
    // River rock along the house side, bark mulch along the fence.
    box('border bed',.65,.04,2.65,x,.02,z,side<0?gravel:mulch,null,false);
    for(let dz=-1.15;dz<1.2;dz+=.35)box('border stone',.15,.12,.32,x-side*.38,.06,z+dz,edging);
    for(let j=0;j<7;j++){const a=random()*6.28,r=Math.sqrt(random())*.25;shrubs.push({x:x+Math.cos(a)*r,y:-.05,z:z+(j-3)*.36+(random()-.5)*.15,size:.55+random()*.35,tint:.8+random()*.3});}
    for(let j=0;j<5;j++)flowers.push({x:x+(random()-.5)*.35,y:0,z:z+(random()-.5)*2.2,size:.45+random()*.25,tint:.95+random()*.1});
  }
  cards('border shrubs',leafCards,shrubs,true);cards('border flowers',flowerCards,flowers);
  // A ring of distant shade trees closes off the horizon, like the tree line in the reference.
  const distantLeaves=material('distant leaves','#93ad6a');distantLeaves.diffuseTexture=new Texture(photos.leaves,scene);distantLeaves.diffuseTexture.uScale=3;distantLeaves.diffuseTexture.vScale=2;
  for(let i=0;i<44;i++){
    const a=i/44*6.28+random()*.08,r=46+random()*12,x=Math.cos(a)*r,z=Math.sin(a)*r,h=6+random()*5;
    cylinder('distant trunk',.6,h*.5,x,h*.25,z,bark);
    for(let j=0;j<3;j++)sphere('distant crown',h*.55+random()*2,h*.45+random()*1.5,h*.55+random()*2,x+(random()-.5)*2.5,h*.62+random()*1.5,z+(random()-.5)*2.5,distantLeaves,null,false);
  }
  // Distant roofs peek above the fence without cluttering the playable lawn.
  for(const x of [-9,9]) {
    box('neighbor house',7,4,6,x,2,HZ+7,x<0?sidingGray:siding);
    gable('neighbor gable',7,1.3,x,4,HZ+3.98,x<0?sidingGray:siding);
    for(const dx of [-1.6,1.6]){box('neighbor window trim',1.2,1.35,.05,x+dx,2.2,HZ+3.97,white);pane('neighbor window',1.05,1.2,x+dx,2.2,HZ+3.94,0,windowPhoto);}
    for(const dx of [-1.8,1.8]){const r=box('neighbor roof',4.4,.18,7,x+dx,4.55,HZ+7,roofing);r.rotation.z=dx<0?.4:-.4;}
  }

  // Detailed zero-turn mower modelled on the reference: orange frame and deck, black body,
  // rounded fenders over big treaded tyres, high-back seat, lap bars and a fan-cooled engine.
  // It faces +Z to match the simulation; the chase camera sees the engine end.
  const mower=new TransformNode('mower',scene),wheels=[];
  const gloss=material('gloss black','#1d2122',.35);gloss.specularPower=40;
  const chrome=material('chrome','#c8cfd2',.9);chrome.specularPower=96;
  const decal=material('deck decal','#f4efe2',.1);
  // A rounded slab: two crossed boxes with cylinders on the corners.
  function slab(name,w,h,d,r,x,y,z,m,parent){
    box(name,w-2*r,h,d,x,y,z,m,parent);box(name,w,h,d-2*r,x,y,z,m,parent);
    for(const sx of [-1,1])for(const sz of [-1,1])cylinder(name,r*2,h,x+sx*(w/2-r),y,z+sz*(d/2-r),m,parent);
  }
  function lathe(name,profile,m,parent,tessellation=32){
    const o=MeshBuilder.CreateLathe(name,{shape:profile.map(([r,y])=>new Vector3(r,y,0)),tessellation,closed:true},scene);
    return finish(o,m,parent);
  }
  // Cutting deck: orange with a rolled front edge, black spindle covers and a side chute.
  slab('cutting deck',1.8,.16,.92,.2,0,.24,.5,orange,mower);
  slab('deck lip',1.84,.05,.96,.22,0,.15,.5,gloss,mower);
  for(const x of [-.5,0,.5]){cylinder('spindle cover',.24,.06,x,.34,.52,gloss,mower);cylinder('spindle cap',.08,.04,x,.38,.52,chrome,mower);}
  const chute=box('discharge chute',.3,.1,.4,1.0,.22,.5,gloss,mower);chute.rotation.z=-.25;
  box('deck stripe',1.5,.005,.06,0,.322,.2,decal,mower);
  // Orange tube frame: side rails, rear bumper loop and engine guard.
  for(const x of [-.42,.42]){rod('frame rail',[x,.36,-.92],[x,.36,.86],.09,orange,mower);rod('frame riser',[x,.36,.62],[x,.52,.72],.08,orange,mower);}
  rod('rear bumper',[-.5,.42,-1.02],[.5,.42,-1.02],.09,orange,mower);
  for(const x of [-.5,.5])rod('bumper corner',[x,.42,-1.02],[x*.84,.36,-.88],.09,orange,mower);
  for(const x of [-.36,.36])rod('engine guard',[x,.42,-1.02],[x,.86,-.98],.06,orange,mower);
  rod('guard top',[-.36,.86,-.98],[.36,.86,-.98],.06,orange,mower);
  // Body, foot plate and the front casters' cross bar.
  slab('body pan',.86,.22,.86,.12,0,.55,-.02,gloss,mower);
  slab('foot platform',.82,.05,.44,.06,0,.5,.66,steel,mower);
  for(let z=.5;z<.84;z+=.055)box('footplate tread',.72,.012,.018,0,.53,z,gloss,mower);
  rod('caster bar',[-.62,.52,.86],[.62,.52,.86],.1,orange,mower);
  // Rounded fenders over the drive tyres, with cup holders and fuel tanks on top.
  for(const x of [-.73,.73]){
    // Half a hollow cylinder, turned so its axis runs along the axle and the arc covers the top.
    const fender=MeshBuilder.CreateCylinder('fender',{diameter:.9,height:.4,arc:.5,tessellation:28,cap:Mesh.NO_CAP,sideOrientation:Mesh.DOUBLESIDE},scene);
    fender.position.set(x,.36,-.48);fender.rotationQuaternion=Quaternion.RotationAxis(Vector3.Right(),Math.PI/2).multiply(Quaternion.RotationAxis(Vector3.Forward(),Math.PI/2));finish(fender,gloss,mower);
    box('fender lip',.4,.03,.04,x,.37,-.03,gloss,mower);
    slab('fuel tank',.26,.14,.34,.06,x*.88,.84,-.62,gloss,mower);
    cylinder('fuel cap',.09,.04,x*.88,.93,-.6,orange,mower);
    slab('control tower',.18,.3,.28,.06,x*.66,.72,.08,gloss,mower);
    cylinder('cup holder',.11,.06,x*.66,.9,.06,gloss,mower);cylinder('cup holder rim',.12,.012,x*.66,.93,.06,steel,mower);
    // Lap bars: up from the tower, forward, then a grip reaching inward.
    rod('lap bar',[x*.66,.86,.16],[x*.66,1.12,.24],.04,gloss,mower);
    rod('lap bar',[x*.66,1.12,.24],[x*.66,1.15,.36],.04,gloss,mower);
    rod('bar grip',[x*.66,1.15,.36],[x*.18,1.15,.38],.05,rubber,mower);
  }
  // High-back seat with a rounded cushion, side bolsters and armrests.
  slab('seat base',.62,.08,.52,.08,0,.72,-.08,gloss,mower);
  slab('seat cushion',.58,.1,.48,.12,0,.81,-.07,black,mower);
  const back=new TransformNode('seat back',scene);back.parent=mower;back.position.set(0,1.1,-.34);back.rotation.x=.12;
  slab('seat back',.56,.6,.12,.055,0,0,0,black,back);slab('seat back shell',.6,.64,.05,.024,0,-.01,-.08,gloss,back);
  for(const x of [-.27,.27])sphere('seat bolster',.12,.5,.16,x,0,.04,black,back);
  for(const x of [-.36,.36])slab('armrest',.08,.06,.34,.03,x,.98,-.12,black,mower);
  // Engine: black shroud, round fan grille with rings, air filter and a chrome muffler.
  slab('engine block',.72,.34,.48,.08,0,.66,-.72,gloss,mower);
  slab('engine deck',.82,.05,.6,.05,0,.48,-.72,orange,mower);
  cylinder('fan housing',.52,.14,0,.9,-.7,gloss,mower);
  cylinder('fan grille',.44,.02,0,.975,-.7,steel,mower);
  for(const d of [.12,.22,.32]){const ring=MeshBuilder.CreateTorus('grille ring',{diameter:d,thickness:.018,tessellation:24},scene);ring.position.set(0,.985,-.7);finish(ring,gloss,mower);}
  for(let i=0;i<8;i++){const a=i*Math.PI/8,spoke=box('grille spoke',.4,.012,.018,0,.986,-.7,gloss,mower);spoke.rotation.y=a;}
  cylinder('fan hub',.08,.03,0,.995,-.7,chrome,mower);
  cylinder('air filter',.2,.12,.24,.92,-.52,gloss,mower);
  for(let x=-.3;x<=.3;x+=.04)box('cooling fins',.018,.24,.02,x,.66,-.97,steel,mower);
  const exhaust=cylinder('muffler',.15,.5,0,.5,-.99,chrome,mower);exhaust.rotation.z=Math.PI/2;
  cylinder('tail pipe',.05,.1,.26,.5,-1.06,chrome,mower).rotation.x=Math.PI/2;
  // Tyres are lathed with rounded shoulders, chevron treads and grey rims.
  const tyre=(r,w)=>[[r*.55,-w/2],[r*.86,-w/2],[r*.96,-w*.44],[r,-w*.3],[r,w*.3],[r*.96,w*.44],[r*.86,w/2],[r*.55,w/2]];
  for(const [x,z,r,w] of [[-.73,-.48,.36,.32],[.73,-.48,.36,.32],[-.58,.86,.15,.13],[.58,.86,.15,.13]]) {
    const pivot=new TransformNode('wheel pivot',scene);pivot.parent=mower;pivot.position.set(x,r,z);pivot.rotation.z=Math.PI/2;wheels.push({pivot,r,x});
    lathe('tyre',tyre(r,w),rubber,pivot);
    cylinder('rim',r*1.12,w*.86,0,0,0,steel,pivot);
    cylinder('hub',r*.42,w*.92,0,0,0,gloss,pivot);
    for(let i=0;i<5;i++){const a=i*6.28/5;cylinder('lug nut',.03,w*.95,Math.cos(a)*r*.3,0,Math.sin(a)*r*.3,chrome,pivot);}
    if(r>.2)for(let i=0;i<26;i++)for(const side of [-1,1]) {
      const a=i*6.28/26,lug=box('tyre tread',.075,w*.42,.03,Math.cos(a)*r,side*w*.2,Math.sin(a)*r,rubber,pivot);
      lug.rotation.y=-a;lug.rotation.x=side*.45;
    }
    else {rod('caster fork',[x,.18,z-.02],[x,.52,z-.02],.07,gloss,mower);cylinder('caster pivot',.12,.08,x,.54,z-.02,orange,mower);}
  }
  // The landscaper: gray tee with a grass logo, jeans, work boots, cap and ear protection.
  const logoTexture=new DynamicTexture('shirt logo',{width:128,height:128},scene,false),lc=logoTexture.getContext();
  lc.clearRect(0,0,128,128);lc.fillStyle='#e9e6dc';
  for(const [x,lean,h] of [[64,0,70],[48,-14,56],[80,14,56],[36,-26,40],[92,26,40]]){lc.beginPath();lc.moveTo(x-6,104);lc.quadraticCurveTo(x+lean*.3,104-h*.6,x+lean,104-h);lc.quadraticCurveTo(x+lean*.2+3,104-h*.5,x+6,104);lc.fill();}
  logoTexture.hasAlpha=true;logoTexture.update();
  const logo=material('shirt logo',"#ffffff");logo.diffuseTexture=logoTexture;logo.useAlphaFromDiffuseTexture=true;logo.backFaceCulling=false;
  const shirtGray=material('heather tee','#6b7178',.04);shirtGray.diffuseTexture=shirt.diffuseTexture;
  const capFabric=material('cap fabric','#3c3f3a',.05),muff=material('ear muff','#e46b1c',.25);
  function limb(name,a,b,radius,m,parent){
    const from=new Vector3(...a),to=new Vector3(...b),dir=to.subtract(from),length=dir.length();
    const o=MeshBuilder.CreateCapsule(name,{radius,height:length+radius*2,tessellation:14,subdivisions:2},scene);
    o.position=from.add(to).scale(.5);o.rotationQuaternion=Quaternion.FromUnitVectorsToRef(Vector3.Up(),dir.normalize(),new Quaternion());
    return finish(o,m,parent);
  }
  function person(name,parent,seated) {
    const p=new TransformNode(name,scene);if(parent)p.parent=parent;
    // The upper body twists on its own node and each leg swings from a hip pivot.
    const body=new TransformNode(name+' upper body',scene);body.parent=p;p.body=body;p.legs=[];
    const hip=seated?.98:.94,chest=hip+.5,neck=chest+.07,head=neck+.13;
    // Torso: lathed from waist to shoulders, then flattened front to back.
    const torso=lathe('torso',[[0,0],[.16,0],[.17,.08],[.18,.25],[.205,.4],[.215,.46],[.19,.52],[.09,.56],[0,.57]],shirtGray,body,24);
    torso.position.set(0,hip-.02,seated?-.06:0);torso.scaling.z=.62;if(seated)torso.rotation.x=-.08;
    lathe('belt',[[0,0],[.165,0],[.17,.05],[0,.05]],black,p,20).position.set(0,hip-.04,seated?-.06:0);
    const logoPlane=MeshBuilder.CreatePlane('shirt logo',{size:.24},scene);logoPlane.position.set(0,chest-.06,(seated?-.06:0)-.15);logoPlane.rotation.x=seated?-.08:0;finish(logoPlane,logo,body,false);
    limb('neck',[0,chest+.02,seated?-.07:0],[0,neck+.04,seated?-.06:0],.055,skin,body);
    const h=sphere('head',.21,.25,.23,0,head,seated?-.05:0,skin,body);
    for(const side of [-1,1])sphere('ear',.04,.07,.03,side*.105,head,seated?-.05:0,skin,body);
    sphere('nose',.04,.05,.05,0,head-.01,(seated?-.05:0)+.11,skin,body);
    // Cap: hemisphere crown and a curved brim facing forward, worn over the headset band.
    const crown=MeshBuilder.CreateSphere('cap crown',{diameter:.235,segments:14,slice:.55},scene);crown.position.set(0,head+.03,seated?-.05:0);crown.scaling.y=.85;finish(crown,capFabric,body);
    const brim=MeshBuilder.CreateCylinder('cap brim',{diameter:.24,height:.012,arc:.5,tessellation:20},scene);brim.position.set(0,head+.04,(seated?-.05:0)+.09);brim.rotation.y=-Math.PI/2;brim.rotation.x=.12;finish(brim,capFabric,body);
    const band=MeshBuilder.CreateTorus('headset band',{diameter:.25,thickness:.02,tessellation:20},scene);band.parent=body;band.position.set(0,head+.03,seated?-.05:0);band.rotation.z=Math.PI/2;finish(band,black,body);
    for(const side of [-1,1]){const cup=cylinder('ear muff',.11,.06,side*.125,head,seated?-.05:0,muff,body);cup.rotation.z=Math.PI/2;const pad=cylinder('muff pad',.1,.03,side*.1,head,seated?-.05:0,black,body);pad.rotation.z=Math.PI/2;}
    for(const side of [-1,1]) {
      const shoulder=[side*.19,chest-.04,seated?-.06:0],elbow=seated?[side*.25,chest-.27,.1]:[side*.24,chest-.3,.06],hand=seated?[side*.18,1.15,.37]:[side*.2,hip-.08,.28];
      sphere('shoulder',.15,.13,.14,...shoulder,shirtGray,body);
      limb('sleeve',shoulder,[shoulder[0]+(elbow[0]-shoulder[0])*.45,shoulder[1]+(elbow[1]-shoulder[1])*.45,shoulder[2]+(elbow[2]-shoulder[2])*.45],.062,shirtGray,body);
      limb('upper arm',shoulder,elbow,.05,skin,body);limb('forearm',elbow,hand,.045,skin,body);
      sphere('hand',.09,.07,.11,...hand,skin,body);
      const knee=seated?[side*.14,hip+.02,.42]:[side*.11,.5,.05],ankle=seated?[side*.15,.6,.62]:[side*.11,.1,.02];
      const leg=new TransformNode('leg',scene),top=[side*.1,hip,seated?-.02:0],at=v=>v.map((c,i)=>c-top[i]);leg.parent=p;leg.position.set(...top);p.legs.push(leg);
      limb('thigh',[0,0,0],at(knee),.085,jeans,leg);
      limb('shin',at(knee),at(ankle),.065,jeans,leg);
      slab('work boot',.12,.1,.24,.05,...at([ankle[0],ankle[1]-.05,ankle[2]+.06]),black,leg);
    }
    return p;
  }
  // The driver sits on a node at seat height so they can lean into turns.
  const seat=new TransformNode('driver seat',scene);seat.parent=mower;seat.position.set(0,.98,-.02);
  const driver=person('driver',seat,true),walker=person('walker',null,false),arms=walker.body;driver.position.set(0,-.98,.02);
  rod('trimmer shaft',[.22,1.08,.28],[.22,.12,1],.035,steel,arms);
  cylinder('trimmer guard',.32,.06,.22,.12,1,gloss,arms);
  slab('trimmer motor',.2,.22,.24,.05,.22,.95,-.08,orange,arms);
  rod('trimmer handle',[.08,.88,.5],[.36,.88,.5],.04,black,arms);
  const line=new TransformNode('trimmer line',scene),nylon=material('trimmer line','#e8e070');line.parent=arms;line.position.set(.22,.08,1);
  box('trimmer line',.34,.006,.008,0,0,0,nylon,line,false);box('trimmer line',.008,.006,.34,0,0,0,nylon,line,false);
  cylinder('trimmer spool',.07,.04,0,.015,0,black,line);
  // Bake each rigid group into one mesh per material so the detailed models stay cheap to draw.
  function bake(node){
    const groups=new Map();
    for(const mesh of node.getChildMeshes(true)){if(mesh.material===logo||mesh.thinInstanceCount)continue;const g=groups.get(mesh.material)||[];g.push(mesh);groups.set(mesh.material,g);}
    for(const meshes of groups.values())if(meshes.length>1){
      for(const mesh of meshes){mesh.computeWorldMatrix(true);shadows.removeShadowCaster(mesh);}
      const merged=Mesh.MergeMeshes(meshes,true,true);if(merged){merged.setParent(node);merged.receiveShadows=true;shadows.addShadowCaster(merged);}
    }
  }
  mower.computeWorldMatrix(true);
  for(const node of [mower,back,driver,driver.body,...driver.legs,walker,arms,...walker.legs,line,procHouse,procTrees,...wheels.map(w=>w.pivot)])bake(node);

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
    const center=lawn.center(id),x=center.x+(random()-.5)*lawn.cell,z=center.z+(random()-.5)*lawn.cell,h=.5+random()*.45,angle=random()*6.28;
    samples.push({x,z,h,angle,width:.65+random()*.7});const tint=.7+random()*.4;colors.set([tint,.85+random()*.15,.7+random()*.3,1],(id*perCell+j)*4);
  }
  // Missed grass glows yellow-green while Find grass is on; cut cells keep their natural tint.
  const baseColors=colors.slice(),glow=[1.45,1.4,.55,1];let highlight=false;
  function tint(id){for(let j=0;j<perCell;j++){const i=(id*perCell+j)*4;if(highlight&&lawn.cells[id]===0)colors.set(glow,i);else colors.set(baseColors.subarray(i,i+4),i);}}
  blade.thinInstanceSetBuffer('matrix',matrices,16,false);blade.thinInstanceSetBuffer('color',colors,4,false);
  // Close to the player, a second pool of blades thickens the lawn; it follows the player around.
  const near=new Mesh('near grass',scene),nearPer=22,nearRadius=7,span=Math.ceil(nearRadius/lawn.cell),nearMax=(span*2+1)**2*nearPer;
  data.applyToMesh(near);near.material=grassMat;near.receiveShadows=true;near.alwaysSelectAsActiveMesh=true;near.isPickable=false;
  const nearMatrices=new Float32Array(nearMax*16),nearColors=new Float32Array(nearMax*4),nearSlots=new Map(),hash=n=>{n=Math.imul(n^n>>>16,0x45d9f3b);n=Math.imul(n^n>>>16,0x45d9f3b);return ((n^n>>>16)>>>0)/4294967296;};
  near.thinInstanceSetBuffer('matrix',nearMatrices,16,false);near.thinInstanceSetBuffer('color',nearColors,4,false);
  let nearX=1e9,nearZ=1e9;
  function nearCell(id,slot){
    const center=lawn.center(id),state=lawn.cells[id];
    for(let j=0;j<nearPer;j++){const k=id*nearPer+j,r=(n)=>hash(k*4+n),h=state===BLOCKED?0:state===0?.42+r(1)*.45:.05,i=slot+j;
      Matrix.Compose(new Vector3(.55+r(2)*.5,h,1),Quaternion.RotationAxis(Vector3.Up(),r(3)*6.28),new Vector3(center.x+(r(0)-.5)*lawn.cell,.018,center.z+(hash(k*4+7)-.5)*lawn.cell)).copyToArray(nearMatrices,i*16);
      const tint=.7+r(2)*.4;nearColors.set(highlight&&state===0?glow:[tint,.85+r(3)*.15,.7+r(1)*.3,1],i*4);}
  }
  function placeNear(x,z){
    nearX=x;nearZ=z;nearSlots.clear();let slot=0;const col=Math.floor((x+lawn.width/2)/lawn.cell),row=Math.floor((z+lawn.depth/2)/lawn.cell);
    for(let r=row-span;r<=row+span;r++)for(let c=col-span;c<=col+span;c++){
      if(r<0||c<0||r>=lawn.rows||c>=lawn.cols)continue;const id=r*lawn.cols+c,p=lawn.center(id);if(Math.hypot(p.x-x,p.z-z)>nearRadius)continue;
      nearSlots.set(id,slot);nearCell(id,slot);slot+=nearPer;
    }
    near.thinInstanceCount=slot;near.thinInstanceBufferUpdated('matrix');near.thinInstanceBufferUpdated('color');
  }
  function refreshGrass(ids) {
    let nearChanged=false;for(const id of ids)if(nearSlots.has(id)){nearCell(id,nearSlots.get(id));nearChanged=true;}
    if(nearChanged){near.thinInstanceBufferUpdated('matrix');near.thinInstanceBufferUpdated('color');}
    for(const id of ids)for(let j=0;j<perCell;j++) {
      const index=id*perCell+j,s=samples[index],state=lawn.cells[id],h=state===BLOCKED||(quality==='medium'&&j%2)?0:state===0?s.h:.055;
      Matrix.Compose(new Vector3(s.width,h,1),Quaternion.RotationAxis(Vector3.Up(),s.angle),new Vector3(s.x,.018,s.z)).copyToArray(matrices,index*16);
    }
    blade.thinInstanceBufferUpdated('matrix');
    if(highlight){for(const id of ids)tint(id);blade.thinInstanceBufferUpdated('color');}
  }
  refreshGrass(Array.from({length:lawn.cells.length},(_,i)=>i));blade.thinInstanceRefreshBoundingInfo();
  // Clippings: a small pool of thin-instanced flecks thrown from the chute or trimmer head.
  const clip=MeshBuilder.CreateBox('clipping',{width:.08,height:.012,depth:.035},scene),clipMat=material('clippings','#a6c45a');clipMat.emissiveColor=new Color3(.12,.16,.04);clip.material=clipMat;clip.isPickable=false;clip.alwaysSelectAsActiveMesh=true;
  const flecks=400,clipBuffer=new Float32Array(flecks*16),parts=Array.from({length:flecks},()=>({life:0,x:0,y:0,z:0,vx:0,vy:0,vz:0,spin:0}));let nextFleck=0,flying=false;
  clip.thinInstanceSetBuffer('matrix',clipBuffer,16,false);
  const fleckScale=new Vector3(),fleckRot=new Quaternion(),fleckPos=new Vector3(),fleckMatrix=new Matrix();
  function spray(x,z,yaw,n,onMower) {
    if(quality==='low')return;
    const c=Math.cos(yaw),s=Math.sin(yaw),[lx,lz]=onMower?[1.05,.5]:[.22,1];
    for(let k=0;k<n;k++){
      const p=parts[nextFleck];nextFleck=(nextFleck+1)%flecks;
      const a=random()*6.28,out=onMower?2+random()*1.6:.8+random()*1.2;
      p.x=x+c*lx+s*lz;p.z=z-s*lx+c*lz;p.y=onMower?.4:.15;
      p.vx=onMower?c*out+(random()-.5)*.8:Math.cos(a)*out;p.vz=onMower?-s*out+(random()-.5)*.8:Math.sin(a)*out;p.vy=onMower?1.6+random()*1.4:.9+random()*1.1;
      p.life=.7+random()*.6;p.spin=random()*6.28;flying=true;
    }
  }
  function updateClippings(dt) {
    if(!flying)return;flying=false;
    parts.forEach((p,i)=>{
      if(p.life>0){p.life-=dt;p.vy-=6*dt;p.x+=p.vx*dt;p.y+=p.vy*dt;p.z+=p.vz*dt;p.spin+=dt*9;if(p.y<.02){p.y=.02;p.vx*=.5;p.vz*=.5;p.vy=0;}flying=true;}
      const size=p.life>0?Math.min(1,p.life*3):0;fleckScale.set(size,size,size);
      Quaternion.RotationYawPitchRollToRef(p.spin,p.spin*.7,0,fleckRot);fleckPos.set(p.x,p.y,p.z);
      Matrix.ComposeToRef(fleckScale,fleckRot,fleckPos,fleckMatrix);fleckMatrix.copyToArray(clipBuffer,i*16);
    });
    clip.thinInstanceBufferUpdated('matrix');
  }
  // Merge static scenery by material to keep the richer yard affordable to draw.
  const groups=new Map();
  for(const mesh of [...scene.meshes])if(mesh!==blade&&!mesh.parent&&!mesh.thinInstanceCount){
    const group=groups.get(mesh.material)||[];group.push(mesh);groups.set(mesh.material,group);
  }
  for(const [m,meshes] of groups)if(tiles.has(m))for(const mesh of meshes)worldUVs(mesh,tiles.get(m));
  for(const meshes of groups.values())if(meshes.length>1){
    for(const mesh of meshes){mesh.computeWorldMatrix(true);shadows.removeShadowCaster(mesh);}
    const merged=Mesh.MergeMeshes(meshes,true,true);if(merged){merged.receiveShadows=true;shadows.addShadowCaster(merged);}
  }
  // Sky: a painted gradient with soft clouds from tileable noise, so it wraps the dome with no seams or mirroring.
  // Clouds thin out toward the zenith and the lower half fades to horizon haze behind the tree line.
  const skyTexture=new DynamicTexture('painted sky',{width:1024,height:256},scene,true),sc=skyTexture.getContext(),pixels=sc.createImageData(1024,256),lattice=[];
  for(let i=0;i<64*16;i++)lattice.push(random());
  const smooth=t=>t*t*(3-2*t),cloudNoise=(u,v,period)=>{const x=u*period,y=v*period/4,x0=Math.floor(x),y0=Math.floor(y),fx=smooth(x-x0),fy=smooth(y-y0),at=(i,j)=>lattice[((j%16+16)%16)*64+((i%period+period)%period)];return (at(x0,y0)*(1-fx)+at(x0+1,y0)*fx)*(1-fy)+(at(x0,y0+1)*(1-fx)+at(x0+1,y0+1)*fx)*fy;};
  // Row 0 of the canvas is the horizon and the last row is the zenith.
  for(let py=0;py<256;py++)for(let px=0;px<1024;px++){
    const u=px/1024,e=py/255;let n=0,amp=.5;for(const period of [4,8,16,32,64]){n+=cloudNoise(u,e*2.5,period)*amp;amp/=2;}
    const cover=Math.max(0,Math.min(1,(n-.5)*5))*Math.min(1,e*7)*(1-e*.4),haze=Math.pow(1-e,2.5);
    const sky=[96+haze*104,152+haze*68,222+haze*16],shade=Math.max(0,n-.6)*1.6,cloud=[250-shade*60,250-shade*55,252-shade*45],i=(py*1024+px)*4;
    for(let k=0;k<3;k++)pixels.data[i+k]=sky[k]*(1-cover)+cloud[k]*cover;pixels.data[i+3]=255;
  }
  sc.putImageData(pixels,0,0);skyTexture.update();skyTexture.wrapV=Texture.CLAMP_ADDRESSMODE;
  const sky=MeshBuilder.CreateSphere('sky dome',{diameter:160,segments:32,sideOrientation:Mesh.BACKSIDE},scene),skyMaterial=material('sky material','#000000');
  const skyPositions=sky.getVerticesData('position'),skyUVs=[];
  for(let i=0;i<skyPositions.length;i+=3){const [x,y,z]=[skyPositions[i],skyPositions[i+1],skyPositions[i+2]],elevation=Math.atan2(y,Math.hypot(x,z));skyUVs.push(Math.atan2(z,x)/Math.PI/2+.5,Math.max(0,1-elevation/(Math.PI/2)));}
  sky.setVerticesData('uv',skyUVs);skyMaterial.disableLighting=true;skyMaterial.emissiveColor=Color3.Black();skyMaterial.emissiveTexture=skyTexture;sky.material=skyMaterial;sky.isPickable=false;sky.infiniteDistance=true;
  // Reflections: one snapshot of the yard and sky from mower height, shown on paint, chrome and glass,
  // strongest at grazing angles like real gloss.
  const probe=new ReflectionProbe('yard reflections',256,scene);probe.position.set(0,1.2,-8);probe.refreshRate=RenderTargetTexture.REFRESHRATE_RENDER_ONCE;
  const shiny=[[orange,.04,.2],[gloss,.06,.25],[plastic,.03,.15],[chrome,.5,.75],[steel,.15,.3],[windowPhoto,.12,.5]];
  // Shiny surfaces stay out of the snapshot, since a texture can't be drawn into itself.
  for(const mesh of scene.meshes)if((!mesh.parent||mesh.parent===procHouse||mesh.parent===procTrees)&&mesh!==blade&&mesh.name!=='clipping'&&!shiny.some(([m])=>m===mesh.material))probe.renderList.push(mesh);
  for(const [m,face,edge] of shiny){
    m.reflectionTexture=probe.cubeTexture;const f=new FresnelParameters();f.bias=0;f.power=2.5;f.leftColor=new Color3(edge,edge,edge);f.rightColor=new Color3(face,face,face);m.reflectionFresnelParameters=f;
  }
  // Wheels roll by the distance each one actually travels, so the outside wheel turns faster in a curve.
  // The driver leans against the turn; the walker's legs stride and the trimmer sweeps while it spins.
  let lean=0,stride=0,sweep=0,sweepSize=0;const hooks=[];
  function animate(dt,{onMower=true,forward=0,turn=0,cutting=false}){
    if(!dt)return;
    if(onMower){
      for(const w of wheels)w.pivot.rotation.x+=(forward-turn*w.x)/w.r;
      const target=Math.max(-.12,Math.min(.12,turn/dt*Math.abs(forward/dt)*.04));lean+=(target-lean)*(1-Math.exp(-6*dt));
      seat.rotation.z=lean;seat.position.y=.98+Math.sin(wind.time*38)*.004*Math.min(Math.abs(forward/dt),1);
    }else{
      const moving=Math.min(1,(Math.abs(forward)+Math.abs(turn)*.3)/dt/1.5);stride+=forward*4.6+Math.abs(turn)*1.2;
      walker.legs.forEach((leg,i)=>{leg.rotation.x+=((i?1:-1)*Math.sin(stride)*.42*moving-leg.rotation.x)*(1-Math.exp(-12*dt));});
      walker.position.y=Math.abs(Math.cos(stride))*.025*moving;
      sweepSize+=((cutting||moving>.1?.32:.12)-sweepSize)*(1-Math.exp(-4*dt));sweep+=dt*3.2;arms.rotation.y=Math.sin(sweep)*sweepSize;
      line.rotation.y+=dt*47;
    }
  }
  return {mower,driver,walker,seat,arms,line,procHouse,procTrees,probe,hooks,blade,refreshGrass,lawnBase,spray,setHighlight(on){if(on===highlight)return;highlight=on;for(let id=0;id<lawn.cells.length;id++)tint(id);blade.thinInstanceBufferUpdated('color');if(nearX<1e9)placeNear(nearX,nearZ);},update(dt,motion={}){wind.time+=dt;updateClippings(dt);animate(dt,motion);for(const hook of hooks)hook(dt,motion);if(quality==='high'&&motion.x!==undefined&&Math.hypot(motion.x-nearX,motion.z-nearZ)>1.2)placeNear(motion.x,motion.z);},setQuality(q){quality=q;near.setEnabled(q==='high');refreshGrass(Array.from({length:lawn.cells.length},(_,i)=>i));}};
}
