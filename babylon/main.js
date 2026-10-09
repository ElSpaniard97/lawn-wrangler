// Babylon is imported module by module so the web build only ships what the game uses.
import {Engine} from '@babylonjs/core/Engines/engine.js';
import {Scene} from '@babylonjs/core/scene.js';
import {Vector3} from '@babylonjs/core/Maths/math.vector.js';
import {Color3,Color4} from '@babylonjs/core/Maths/math.color.js';
import {MeshBuilder} from '@babylonjs/core/Meshes/meshBuilder.js';
import {StandardMaterial} from '@babylonjs/core/Materials/standardMaterial.js';
import {DynamicTexture} from '@babylonjs/core/Materials/Textures/dynamicTexture.js';
import {HemisphericLight} from '@babylonjs/core/Lights/hemisphericLight.js';
import {DirectionalLight} from '@babylonjs/core/Lights/directionalLight.js';
import {ShadowGenerator} from '@babylonjs/core/Lights/Shadows/shadowGenerator.js';
import '@babylonjs/core/Lights/Shadows/shadowGeneratorSceneComponent.js';
import {ArcRotateCamera} from '@babylonjs/core/Cameras/arcRotateCamera.js';
import './style.css';
import {Game, BLOCKED, YARD} from './lawn.js';
import {buildGraphics,photos} from './graphics.js';
import {Texture} from '@babylonjs/core/Materials/Textures/texture.js';
import {createSound} from './sound.js';
let storage;try{storage=window.localStorage;}catch{}
// Phones and tablets start on Low until the player picks a quality.
let coarse=false;try{coarse=matchMedia('(pointer: coarse)').matches;}catch{}
const game=new Game(storage,coarse?'low':'high');
const $=id=>document.getElementById(id),engine=new Engine($('game'),true,{preserveDrawingBuffer:true}),scene=new Scene(engine);
scene.clearColor=new Color4(.64,.81,.91,1);scene.fogMode=Scene.FOGMODE_EXP2;scene.fogDensity=.003;scene.fogColor=new Color3(.64,.81,.91);
const ambient=new HemisphericLight('sky',new Vector3(0,1,0),scene);ambient.intensity=.8;ambient.groundColor=new Color3(.25,.31,.15);
const sun=new DirectionalLight('sun',new Vector3(-.65,-1,.5),scene);sun.position=new Vector3(20,35,-20);sun.intensity=1.35;sun.diffuse=new Color3(1,.96,.88);
// A little extra contrast and exposure for the bright summer look of the reference art.
scene.imageProcessingConfiguration.contrast=1.18;scene.imageProcessingConfiguration.exposure=1.06;
const shadows=new ShadowGenerator(2048,sun);shadows.usePercentageCloserFiltering=true;shadows.filteringQuality=ShadowGenerator.QUALITY_MEDIUM;shadows.bias=.0005;shadows.normalBias=.035;shadows.darkness=.22;
const lawn=game.lawn;
const visuals=buildGraphics(scene,shadows,lawn);
const {mower,driver,walker,blade,refreshGrass}=visuals;
const camera=new ArcRotateCamera('chase',-Math.PI/2,1.29,5.7,new Vector3(0,1,0),scene);
camera.minZ=.08;camera.fov=1.05;
// The key guide folds away once the player gets going; C or Keys brings it back, and pausing shows it.
let keys=new Set(),touch={throttle:0,steer:0},showPerf=false,helpOpen=true,helpAutoFolded=false,lastGlow=false;
const time=v=>v?`${Math.floor(v/60)}:${String(Math.floor(v%60)).padStart(2,'0')}`:'—';
function action(code){if(code==='KeyR')reset();else if(code==='KeyP'||code==='Escape'){if(!game.finished)game.paused=!game.paused;keys.clear();touch={throttle:0,steer:0};}else if(!game.paused&&!game.finished){if(code==='Space')game.mount();if(code==='KeyB')game.blades=!game.blades;if(code==='KeyH')game.highlight=!game.highlight;}if(code==='KeyM'){game.settings.muted=!game.settings.muted;game.saveSettings();}if(code==='KeyQ'){game.settings.quality=['low','medium','high'][(['low','medium','high'].indexOf(game.settings.quality)+1)%3];applyQuality();game.saveSettings();}if(code==='F3')showPerf=!showPerf;if(code==='KeyC'){helpOpen=!helpOpen;helpAutoFolded=true;}}
window.addEventListener('keydown',e=>{if(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Space','F3'].includes(e.code))e.preventDefault();keys.add(e.code);audioStart();if(!e.repeat)action(e.code);});window.addEventListener('keyup',e=>keys.delete(e.code));window.addEventListener('blur',()=>{keys.clear();touch={throttle:0,steer:0};game.paused=true;});document.addEventListener('visibilitychange',()=>{if(document.hidden){keys.clear();game.paused=true;}});
$('pause').onclick=()=>action('KeyP');$('reset').onclick=reset;for(const [id,code] of [['mount','Space'],['blades','KeyB'],['highlight','KeyH'],['quality','KeyQ'],['sound','KeyM'],['keys','KeyC']])$(id).onclick=()=>{audioStart();action(code);};
for(const button of document.querySelectorAll('[data-drive]')){button.addEventListener('pointerdown',e=>{e.preventDefault();button.setPointerCapture(e.pointerId);audioStart();const [axis,value]=button.dataset.drive.split(':');touch[axis]=Number(value);});for(const event of ['pointerup','pointercancel','lostpointercapture'])button.addEventListener(event,()=>{touch[button.dataset.drive.split(':')[0]]=0;});}
function applyQuality(){const q=game.settings.quality;engine.setHardwareScalingLevel(q==='low'?1.8:q==='medium'?1.3:1);scene.shadowsEnabled=q!=='low';blade.setEnabled(q!=='low');visuals.setQuality(q);$('quality').textContent='Quality: '+q;}
applyQuality();
function reset(){game.reset();keys.clear();touch={throttle:0,steer:0};refreshGrass(Array.from({length:lawn.cells.length},(_,i)=>i));paintMap();}

// DynamicTexture stays GPU-resident; only update the small cut map after cutting.
const cutTexture=new DynamicTexture('cut map',{width:512,height:512},scene,false);cutTexture.hasAlpha=false;const cutMaterial=new StandardMaterial('directional lawn',scene);// The lawn is the grass photo, darkened per cell by the cut map to draw stripes and tall grass.
const lawnPhoto=new Texture(photos.lawn,scene);lawnPhoto.uScale=lawn.width/1.6;lawnPhoto.vScale=lawn.depth/1.6;cutMaterial.diffuseTexture=lawnPhoto;cutMaterial.diffuseColor=new Color3(1.05,1.05,1.05);cutMaterial.lightmapTexture=cutTexture;cutMaterial.useLightmapAsShadowmap=true;cutMaterial.specularColor=Color3.Black();const cutGround=MeshBuilder.CreateGround('directional ground',{width:lawn.width,height:lawn.depth},scene);cutGround.position.y=.015;cutGround.material=cutMaterial;cutGround.receiveShadows=true;
function paintMap(ids=Array.from({length:lawn.cells.length},(_,i)=>i)){
  const ctx=cutTexture.getContext(),size=cutTexture.getSize(),w=size.width/lawn.cols,h=size.height/lawn.rows;
  for(const id of ids){const x=id%lawn.cols*w,y=Math.floor(id/lawn.cols)*h,state=lawn.cells[id];
    ctx.fillStyle=state===0&&lastGlow?'#ffff9a':['#9aa888','#ffffff','#b7c4a2','#a08c6a'][state];ctx.fillRect(x,y,w+.01,h+.01);
  }
  cutTexture.update();
}paintMap();
const minimap=$('map'),mc=minimap.getContext('2d');function drawMap(){mc.fillStyle='#243323';mc.fillRect(0,0,160,200);for(let id=0;id<lawn.cells.length;id++){const state=lawn.cells[id];mc.fillStyle=state===BLOCKED?'#8c8879':state===0?(game.highlight||lawn.progress>.95?'#dded79':'#4b7132'):state===1?'#9ab955':'#799d45';mc.fillRect(id%lawn.cols*160/lawn.cols,Math.floor(id/lawn.cols)*200/lawn.rows,160/lawn.cols+.2,200/lawn.rows+.2);}const a=game.actor;mc.save();mc.translate((a.x+YARD.halfX)/lawn.width*160,(a.z+YARD.halfZ)/lawn.depth*200);mc.rotate(-a.yaw);mc.fillStyle='white';mc.beginPath();mc.moveTo(0,7);mc.lineTo(-5,-5);mc.lineTo(5,-5);mc.closePath();mc.fill();mc.restore();}
const sound=createSound(),audioStart=sound.start;let wasFinished=false;
let previousButtons=[];function gamepadInput(){const pad=Array.from(navigator.getGamepads?.()||[]).find(Boolean);if(!pad)return {throttle:0,steer:0};const mapping={0:'Space',1:'KeyB',2:'KeyH',3:'KeyM',9:'KeyP'};for(const [i,code] of Object.entries(mapping)){const pressed=pad.buttons[i]?.pressed;if(pressed&&!previousButtons[i]){audioStart();action(code);}previousButtons[i]=pressed;}const dead=v=>Math.abs(v||0)>.15?v:0;return {throttle:(pad.buttons[7]?.value||0)-(pad.buttons[6]?.value||0)-dead(pad.axes[1]),steer:dead(pad.axes[0])};}
let hudTick=0;engine.runRenderLoop(()=>{const dt=Math.min(engine.getDeltaTime()/1000,.05),pad=gamepadInput();const throttle=(keys.has('KeyW')||keys.has('ArrowUp')?1:0)-(keys.has('KeyS')||keys.has('ArrowDown')?1:0)+touch.throttle+pad.throttle,steer=(keys.has('KeyD')||keys.has('ArrowRight')?1:0)-(keys.has('KeyA')||keys.has('ArrowLeft')?1:0)+touch.steer+pad.steer;const before={x:game.actor.x,z:game.actor.z,yaw:game.actor.yaw};const changed=game.step(dt,{throttle,steer});if(changed.length){refreshGrass(changed);paintMap(changed);const a=game.actor;visuals.spray(a.x,a.z,a.yaw,Math.min(changed.length*2,24),game.onMower);}const glow=game.highlight||lawn.progress>.95;if(glow!==lastGlow){lastGlow=glow;visuals.setHighlight(glow);paintMap();}mower.position.set(game.mower.x,0,game.mower.z);mower.rotation.y=game.mower.yaw;driver.setEnabled(game.onMower);walker.setEnabled(!game.onMower);walker.position.set(game.walker.x,0,game.walker.z);walker.rotation.y=game.walker.yaw;{const a=game.actor,forward=(a.x-before.x)*Math.sin(a.yaw)+(a.z-before.z)*Math.cos(a.yaw);visuals.update(game.paused||game.finished?0:dt,{onMower:game.onMower,forward,turn:a.yaw-before.yaw,cutting:changed.length>0});}
const a=game.actor,target=new Vector3(a.x,.8,a.z);camera.setTarget(Vector3.Lerp(camera.target,target,1-Math.exp(-5*dt)));camera.alpha=-Math.PI/2-a.yaw;camera.beta=1.2;let distance=game.onMower?6:4.8;for(let r=2;r<distance;r+=.25){const cx=a.x-Math.sin(a.yaw)*r*Math.sin(1.2),cz=a.z-Math.cos(a.yaw)*r*Math.sin(1.2);if(Math.abs(cx)>YARD.halfX+.5||Math.abs(cz)>YARD.halfZ+.5){distance=r;break;}}camera.radius=distance;
sound.update(dt,{muted:game.settings.muted,silent:game.paused||game.finished,onMower:game.onMower,blades:game.blades,speed:game.measuredSpeed,cut:changed.length});if(game.finished&&!wasFinished&&!game.settings.muted)sound.chime();wasFinished=game.finished;
hudTick+=dt;if(hudTick>.15){hudTick=0;const objectives=game.lawn.objectives(),names=['Cut the front yard','Cut the side yard','Cut the back yard','Trim around objects'];$('objectives').replaceChildren(...names.map((name,i)=>{const el=document.createElement('div');const check=document.createElement('span');check.className='check'+(objectives[i]>=.97?' done':'');check.textContent=objectives[i]>=.97?'✓':'';el.append(check,document.createTextNode(name));el.title=Math.floor(objectives[i]*100)+'% complete';return el;}));$('percent').textContent=Math.floor(lawn.progress*100)+'%';$('fill').style.width=lawn.progress*100+'%';$('speed').textContent=(game.measuredSpeed*2.237).toFixed(1);$('blade').textContent=game.onMower?(game.blades?'BLADES ON':'BLADES OFF'):'WEED EATER';$('status').textContent=game.finished?game.message:game.paused?'Paused · P or Resume to continue':game.fuel<.2?'Low fuel · stop by the red can':game.onMower?'Mow the open lawn. Hop off for edges.':'Trim the edges. Space near mower to ride.';$('pause').textContent=game.paused?'Resume':'Pause';$('mount').textContent=game.onMower?'Hop off':'Hop on';$('fuel').textContent=Math.round(game.fuel*100)+'% fuel';$('fuel-level').style.height=(game.fuel*100)+'%';$('timer').textContent=time(game.elapsed);$('best').textContent='Best '+time(game.best);$('sound').textContent=game.settings.muted?'Sound off':'Sound on';if(!helpAutoFolded&&game.measuredSpeed>.2){helpOpen=false;helpAutoFolded=true;}const folded=!helpOpen&&!game.paused;$('controls').classList.toggle('folded',folded);$('keys').textContent=folded?'Keys':'Hide keys';$('fps').textContent=showPerf?Math.round(engine.getFps())+' FPS · '+game.settings.quality:'';drawMap();}scene.render();});window.addEventListener('resize',()=>engine.resize());
