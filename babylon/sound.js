// Every sound is synthesized with Web Audio: engine, blades, weed eater, grass rustle and a finish chime.
// Nothing starts until the first key or tap, because browsers block audio before a user gesture.
export function createSound() {
  let ctx,master,engine,rumble,engineGain,blade,bladeGain,trimmer,trimmerGain,rustleGain,cutLevel=0;
  function noise(filterType,frequency,q) {
    const buffer=ctx.createBuffer(1,ctx.sampleRate*2,ctx.sampleRate),data=buffer.getChannelData(0);
    for(let i=0;i<data.length;i++)data[i]=Math.random()*2-1;
    const source=ctx.createBufferSource(),filter=ctx.createBiquadFilter(),gain=ctx.createGain();
    source.buffer=buffer;source.loop=true;filter.type=filterType;filter.frequency.value=frequency;filter.Q.value=q;gain.gain.value=0;
    source.connect(filter);filter.connect(gain);gain.connect(master);source.start();
    return {filter,gain};
  }
  function tone(type,frequency,filterFrequency) {
    const osc=ctx.createOscillator(),filter=ctx.createBiquadFilter(),gain=ctx.createGain();
    osc.type=type;osc.frequency.value=frequency;filter.type='lowpass';filter.frequency.value=filterFrequency;gain.gain.value=0;
    osc.connect(filter);filter.connect(gain);gain.connect(master);osc.start();
    return {osc,filter,gain};
  }
  function start() {
    if(!ctx){try{
      ctx=new AudioContext();master=ctx.createGain();master.gain.value=0;master.connect(ctx.destination);
      // Engine: a low sawtooth for the firing pulses plus a square an octave down for body.
      ({osc:engine,gain:engineGain}=tone('sawtooth',45,520));
      rumble=ctx.createOscillator();rumble.type='square';rumble.frequency.value=22;
      const rumbleGain=ctx.createGain();rumbleGain.gain.value=.35;rumble.connect(rumbleGain);rumbleGain.connect(engineGain);rumble.start();
      ({gain:bladeGain,filter:blade}=noise('bandpass',900,1.2));
      ({osc:trimmer,gain:trimmerGain}=tone('sawtooth',190,2400));
      ({gain:rustleGain}=noise('bandpass',3800,.7));
    }catch{ctx=null;}}
    if(ctx?.state==='suspended')ctx.resume().catch(()=>{});
  }
  function update(dt,{muted,silent,onMower,blades,speed,cut}) {
    if(!ctx)return;
    const now=ctx.currentTime,set=(param,value,time=.08)=>param.setTargetAtTime(value,now,time);
    set(master.gain,muted||silent?0:1,.05);
    cutLevel=Math.max(cutLevel*Math.exp(-6*dt),Math.min(1,cut/12));
    const pitch=onMower?45+speed*9:38;
    set(engine.frequency,pitch);set(rumble.frequency,pitch/2);
    set(engineGain.gain,onMower?.022+speed*.003:.008);
    set(bladeGain.gain,onMower&&blades?.03+cutLevel*.03:0);set(blade.frequency,700+speed*90);
    set(trimmerGain.gain,onMower?0:.012+cutLevel*.01);set(trimmer.frequency,onMower?190:185+cutLevel*40);
    set(rustleGain.gain,cutLevel*.05,.04);
  }
  function chime() {
    if(!ctx)return;
    [523.25,659.25,783.99,1046.5].forEach((f,i)=>{
      const osc=ctx.createOscillator(),gain=ctx.createGain(),t=ctx.currentTime+i*.14;
      osc.type='sine';osc.frequency.value=f;gain.gain.setValueAtTime(0,t);gain.gain.linearRampToValueAtTime(.08,t+.02);gain.gain.exponentialRampToValueAtTime(.0001,t+.9);
      osc.connect(gain);gain.connect(ctx.destination);osc.start(t);osc.stop(t+1);
    });
  }
  return {start,update,chime};
}
