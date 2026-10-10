// Sketchfab models (CC-BY 4.0; authors credited on the credits page and in ASSET_LICENSES.md).
// The procedural stand-ins in graphics.js show until each model loads, and stay if one fails.
import { LoadAssetContainerAsync } from '@babylonjs/core/Loading/sceneLoader.js';
import { TransformNode } from '@babylonjs/core/Meshes/transformNode.js';
import { Vector3, Quaternion } from '@babylonjs/core/Maths/math.vector.js';
import { Color3 } from '@babylonjs/core/Maths/math.color.js';
import '@babylonjs/loaders/glTF/glTFFileLoader.js';
import '@babylonjs/loaders/glTF/2.0/glTFLoader.js';
import '@babylonjs/loaders/glTF/2.0/Extensions/EXT_texture_webp.js';
import { trees } from './lawn.js';

const files={
  tractor:new URL('./models/tractor.glb',import.meta.url).href,
  landscaper:new URL('./models/landscaper.glb',import.meta.url).href,
  trimmer:new URL('./models/trimmer.glb',import.meta.url).href,
  house:new URL('./models/house.glb',import.meta.url).href,
  oak:new URL('./models/oak.glb',import.meta.url).href,
};
const load=name=>LoadAssetContainerAsync(files[name],scene0).catch(error=>{console.warn(`Model ${name} did not load`,error);return null;});
let scene0;
const refresh=node=>{node.computeWorldMatrix(true);for(const child of node.getDescendants(false))child.computeWorldMatrix(true);};

export async function loadModels(scene,shadows,visuals){
  scene0=scene;
  const [tractor,landscaper,trimmer,house,oak]=await Promise.all(['tractor','landscaper','trimmer','house','oak'].map(load));
  // Wrap a model so it can be turned, scaled to a size along one axis, and set on the ground.
  function fit(nodes,name,{size,axis='y',turn=Quaternion.Identity(),ground=true,center=true}){
    const holder=new TransformNode(name,scene),inner=new TransformNode(name+' model',scene);inner.parent=holder;inner.rotationQuaternion=turn;
    for(const node of nodes)node.parent=inner;
    for(const mesh of inner.getChildMeshes()){mesh.receiveShadows=true;shadows.addShadowCaster(mesh);mesh.isPickable=false;}
    refresh(holder);let {min,max}=inner.getHierarchyBoundingVectors(true);const extent=max.subtract(min),scale=size/(axis==='longest'?Math.max(extent.x,extent.y,extent.z):extent[axis]);inner.scaling.setAll(scale);
    refresh(holder);({min,max}=inner.getHierarchyBoundingVectors(true));
    inner.position.set(center?-(min.x+max.x)/2:0,ground?-min.y:0,center?-(min.z+max.z)/2:0);refresh(holder);
    return holder;
  }
  // Each model is set up on its own, so one that fails leaves its stand-in and the others still load.
  const attempt=(name,container,setup)=>{if(!container)return;try{setup();}catch(error){console.warn(`Model ${name} could not be placed`,error);}};
  const take=(container,name)=>{const copy=container.instantiateModelsToScene(n=>n,false,{doNotInstantiate:true});return copy;};

  attempt('tractor',tractor,()=>{
    // The tractor faces +z like the game; its tyre pairs were split by axle so each pair rolls.
    const copy=take(tractor),model=fit(copy.rootNodes,'tractor',{size:2.25,axis:'z'});
    copy.animationGroups.forEach(g=>g.stop());
    for(const child of visuals.mower.getChildren())if(child!==visuals.seat)child.setEnabled(false);
    model.parent=visuals.mower;
    const axles=['front','rear'].map(side=>{
      const meshes=model.getChildMeshes().filter(m=>m.name.includes(side+' wheels'));
      for(const mesh of meshes){const b=mesh.getBoundingInfo().boundingBox;mesh.setPivotPoint(b.center);}
      const b=meshes[0].getBoundingInfo().boundingBox,r=(b.maximumWorld.y-b.minimumWorld.y)/2;
      return {meshes,r};
    });
    visuals.seat.position.set(0,.62,-.42);
    visuals.hooks.push((dt,{onMower,forward=0})=>{if(onMower)for(const {meshes,r} of axles)for(const mesh of meshes)mesh.rotation.x+=forward/r;});
  });
  attempt('landscaper',landscaper,()=>{
    // One copy rides the tractor in a seated pose; the other walks with the weed eater.
    const driver=take(landscaper),walker=take(landscaper);
    const rider=fit(driver.rootNodes,'seated landscaper',{size:1.78,ground:false,center:false}),stroller=fit(walker.rootNodes,'walking landscaper',{size:1.78});
    driver.animationGroups.forEach(g=>g.stop());
    const bones=copy=>{const map={};for(const node of copy.rootNodes[0].getDescendants(false))if(node.name.startsWith('mixamorig:'))map[node.name.replace(/^mixamorig:|_\d+$/g,'')]=node;return map;};
    const seatBones=bones(driver),walkBones=bones(walker);
    seatPose(seatBones);
    for(const child of visuals.driver.getChildren())child.setEnabled(false);
    rider.parent=visuals.driver;refresh(visuals.mower);
    // Place the seated hips on the seat.
    const hips=seatBones.Hips.getAbsolutePosition(),seatAt=visuals.seat.getAbsolutePosition();rider.position.addInPlace(seatAt.subtract(hips).add(new Vector3(0,.08,0)));
    for(const mesh of visuals.walker.getChildMeshes())if(!visuals.line.getChildMeshes().includes(mesh))mesh.setEnabled(false);
    stroller.parent=visuals.walker;
    const walk=walker.animationGroups.find(g=>g.name==='walk');walk?.start(true,1);
    let pace=0;
    visuals.hooks.push((dt,{onMower,forward=0})=>{if(onMower||!walk||!dt)return;const speed=Math.abs(forward)/dt;pace+=(Math.min(speed/1.6,1.4)-pace)*Math.min(1,dt*8);walk.speedRatio=pace<.05?0:pace;});
    // Arms hold the weed eater out front instead of swinging with the walk.
    scene.onAfterAnimationsObservable.add(()=>{if(visuals.walker.isEnabled())holdPose(walkBones);});
    visuals.landscaperBones={seatBones,walkBones};
  });
  attempt('trimmer',trimmer,()=>{
    const copy=take(trimmer),dir=new Vector3(0,-.96,.72).normalize();
    const model=fit(copy.rootNodes,'string trimmer',{size:1.5,axis:'longest',turn:Quaternion.FromUnitVectorsToRef(new Vector3(-1,0,0),dir,new Quaternion()),ground:false});
    model.position.set(.22,.6,.64);model.parent=visuals.arms;
    // The download is untextured white: the shaft (the longest part) stays metal grey, the rest is painted orange and black.
    const parts=model.getChildMeshes().filter(m=>m.material).map(m=>({m,size:m.getBoundingInfo().boundingBox.extendSizeWorld.length()})).sort((a,b)=>b.size-a.size);
    parts.forEach(({m},i)=>{const mat=m.material.clone('trimmer '+i);mat.albedoColor=i===0?new Color3(.55,.57,.58):i%2?new Color3(.85,.33,.06):new Color3(.08,.08,.08);mat.metallic=i===0?.8:0;mat.roughness=i===0?.35:.55;m.material=mat;});
    visuals.line.parent=visuals.arms;
  });
  attempt('house',house,()=>{
    // The house's front porch faces -x in the download, so it is turned to face the lawn.
    // The download also sits a few degrees off square; find the turn that makes its footprint smallest.
    const copy=take(house),probe=new TransformNode('square test',scene);for(const n of copy.rootNodes)n.parent=probe;
    let yaw=0,area=Infinity;for(let d=-30;d<=30;d+=.5){probe.rotation.y=d*Math.PI/180;refresh(probe);const {min,max}=probe.getHierarchyBoundingVectors(true),a=(max.x-min.x)*(max.z-min.z);if(a<area){area=a;yaw=probe.rotation.y;}}
    for(const n of copy.rootNodes)n.parent=null;probe.dispose();
    const model=fit(copy.rootNodes,'house',{size:10,axis:'x',turn:Quaternion.RotationAxis(Vector3.Up(),Math.PI+yaw),ground:false});
    const {max}=model.getHierarchyBoundingVectors(true);model.position.set(-12.75-max.x,0,-5.9);
    visuals.procHouse.setEnabled(false);
  });
  attempt('oak',oak,()=>{
    // Three oaks share the download; each yard tree takes the next one, stood upright.
    trees.forEach(([x,z],i)=>{
      const copy=take(oak),pick=copy.rootNodes[0].getDescendants(false).filter(n=>/^oak \d/.test(n.name));
      pick.forEach((n,k)=>{if(k!==i%pick.length)n.setEnabled(false);});
      const keep=pick[i%pick.length],model=fit([keep],'oak tree',{size:8.5,turn:upright(keep)});model.position.set(x,0,z);model.rotation.y=i*2.1;
    });
    visuals.procTrees.setEnabled(false);
  });
}

// The oak download lies on its side; try each quarter turn and keep the one with the bark lowest under the leaves.
function upright(tree){
  const holder=new TransformNode('upright test',scene0);tree.parent=holder;let best,score=-Infinity;
  for(const [axis,angle] of [[Vector3.Forward(),Math.PI/2],[Vector3.Forward(),-Math.PI/2],[Vector3.Right(),Math.PI/2],[Vector3.Right(),-Math.PI/2],[Vector3.Up(),0]]){
    const q=Quaternion.RotationAxis(axis,angle);holder.rotationQuaternion=q;refresh(holder);
    const y=m=>{const b=m.getBoundingInfo().boundingBox;return (b.minimumWorld.y+b.maximumWorld.y)/2;},meshes=tree.getChildMeshes(),bark=meshes.find(m=>!m.material?.needAlphaTesting?.()&&m.material?.transparencyMode!==1)||meshes[0];
    const leaves=meshes.filter(m=>m!==bark),gap=leaves.reduce((t,m)=>t+y(m),0)/Math.max(1,leaves.length)-y(bark);
    if(gap>score){score=gap;best=q;}
  }
  tree.parent=null;holder.dispose();return best;
}
// Bone poses are applied on top of each bone's rest rotation, as turns about the bone's own axes.
function turn(bone,x=0,y=0,z=0){bone.metadata??={};const rest=bone.metadata.rest??=(bone.rotationQuaternion||Quaternion.FromEulerVector(bone.rotation)).clone();bone.rotationQuaternion=rest.multiply(Quaternion.RotationYawPitchRoll(y,x,z));}
function seatPose(b){
  for(const side of ['Left','Right']){turn(b[side+'UpLeg'],-1.45);turn(b[side+'Leg'],1.5);}
  for(const [side,s] of [['Left',1],['Right',-1]]){turn(b[side+'Arm'],-.35,0,s*.25);turn(b[side+'ForeArm'],-1.1);}
}
function holdPose(b){
  for(const [side,s] of [['Left',1],['Right',-1]]){turn(b[side+'Arm'],-.5,0,s*.2);turn(b[side+'ForeArm'],-.8);}
}
