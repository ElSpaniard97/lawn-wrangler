import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Game} from '../lawn.js';
import {SimulationClock} from '../simulation-clock.js';
function drive(fps) {
  const game=new Game(), clock=new SimulationClock(game);
  for(let i=0;i<fps*4;i++)clock.advance(1/fps,{throttle:1,steer:.2});
  return {mower:game.mower,speed:game.speed,fuel:game.fuel,time:game.elapsed,stats:game.stats,cells:Array.from(game.lawn.cells)};
}
test('identical timed inputs produce identical movement, fuel, cuts and time at 15, 30, 60 and 144 FPS',()=>{
  const expected=drive(60);
  for(const fps of [15,30,144])assert.deepEqual(drive(fps),expected);
});
test('pause discards partial backlog and resume does not catch up paused time',()=>{
  const game=new Game(),clock=new SimulationClock(game);clock.advance(.01,{throttle:1});game.paused=true;clock.advance(10,{throttle:1});game.paused=false;clock.advance(.01,{throttle:1});assert.equal(game.elapsed,0);clock.advance(.01,{throttle:1});assert.equal(game.elapsed,1/60);
});
test('long stalls are bounded and discarded time is explicit',()=>{
  const game=new Game(),clock=new SimulationClock(game),result=clock.advance(2,{throttle:1});assert.ok(Math.abs(result.simulated-8/60)<1e-10);assert.ok(Math.abs(game.elapsed-8/60)<1e-10);assert.ok(Math.abs(clock.droppedTime-(2-8/60))<1e-10);assert.ok(clock.accumulator<1/60);
});
test('events from early ticks are retained once and absent on frames without ticks',()=>{
  const game={mower:{x:0,z:0,yaw:0},walker:{x:0,z:0,yaw:0},events:[],paused:false,finished:false,ticks:0,step(){this.events=this.ticks++===0?['bump']:[];return [7];}};
  const clock=new SimulationClock(game);assert.deepEqual(clock.advance(1/30).events,['bump']);assert.deepEqual(clock.advance(.001).events,[]);assert.deepEqual(clock.advance(1/30).changed,[7]);
});
test('interpolation stays between ticks; syncing after a mount or reset removes old poses',()=>{
  const game=new Game(),clock=new SimulationClock(game);clock.advance(1/40,{throttle:1});const pose=clock.presentation();assert.ok(pose.mower.z>=-8&&pose.mower.z<=game.mower.z);game.mower.x=10;clock.sync();assert.equal(clock.presentation().mower.x,10);game.reset();clock.reset();assert.equal(clock.presentation().mower.x,0);
});
test('finish is processed once and stops subsequent catch-up ticks',()=>{
  const game=new Game(),clock=new SimulationClock(game);game.lawn.mow(0,0,100);const result=clock.advance(.1);assert.deepEqual(result.events,['finish']);assert.equal(game.elapsed,1/60);assert.deepEqual(clock.advance(.1).events,[]);
});
