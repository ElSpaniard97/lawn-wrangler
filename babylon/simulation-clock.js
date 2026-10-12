const STEP = 1 / 60;
const MAX_STEPS = 8;
const snapshot = game => ({mower:{...game.mower},walker:{...game.walker}});

/** Rendering may vary; rules always advance in 60 Hz ticks.
 * Catch up at most eight ticks per frame. Excess whole ticks are discarded,
 * not charged to the run timer, so long stalls cannot cause a huge jump.
 */
export class SimulationClock {
  constructor(game) { this.game=game; this.reset(); }
  sync() { this.accumulator=0; this.previous=snapshot(this.game); }
  reset() { this.droppedTime=0; this.sync(); }
  advance(frameSeconds, input={}) {
    const changed=new Set(), events=[];
    if(this.game.paused||this.game.finished) { this.game.measuredSpeed=0; this.sync(); return {changed:[],events,simulated:0}; }
    if(!Number.isFinite(frameSeconds)||frameSeconds<=0) return {changed:[],events,simulated:0};
    this.accumulator+=frameSeconds;
    let steps=0;
    while(this.accumulator+1e-10>=STEP && steps<MAX_STEPS) {
      this.previous=snapshot(this.game);
      for(const id of this.game.step(STEP,input)) changed.add(id);
      events.push(...this.game.events);
      this.accumulator=Math.max(0,this.accumulator-STEP);
      steps++;
      if(this.game.finished) { this.sync(); break; }
    }
    if(this.accumulator+1e-10>=STEP) {
      const wholeTicks=Math.floor((this.accumulator+1e-10)/STEP)*STEP;
      this.droppedTime+=wholeTicks;
      this.accumulator=Math.max(0,this.accumulator-wholeTicks);
    }
    return {changed:[...changed],events,simulated:steps*STEP};
  }
  presentation() {
    const alpha=this.accumulator/STEP, current=snapshot(this.game), result={};
    for(const name of ['mower','walker']) {
      const from=this.previous[name],to=current[name];
      result[name]={x:from.x+(to.x-from.x)*alpha,z:from.z+(to.z-from.z)*alpha,yaw:from.yaw+(to.yaw-from.yaw)*alpha};
    }
    return result;
  }
}
