import test from 'node:test';
import assert from 'node:assert/strict';
import { historyAction } from '../assets/backend/gui_history.mjs';
import { routePiOutput, WorkspaceAdapter } from '../assets/backend/workspace_rpc.mjs';
import { WorkspaceManager } from '../assets/backend/workspace_manager.mjs';

test('production channel router forwards all history commands only to their owning session', async () => {
  const output = [], routed = [];
  const manager = new WorkspaceManager({}, () => {}, line => output.push(JSON.parse(line)));
  for (const id of ['a', 'b']) {
    manager.channels.set(id, {
      id, ready: Promise.resolve(), status: 'ready', sessionFile: `${id}.jsonl`,
      adapter: { handle: async request => { routed.push([id, request]); } },
    });
  }
  const commands = ['gui_history_entry', 'gui_history_navigate', 'gui_history_label', 'gui_history_fork', 'gui_history_clone'];
  for (const type of commands) {
    await manager.handle({ type: 'gui_channel', channel: 'a', message: { id: 'same-id', type } });
  }
  assert.deepEqual(routed.map(([id, request]) => [id, request.type]), commands.map(type => ['a', type]));
  assert.equal(output.length, 0);
  for (const [channel, type] of [['a', 'gui_history_unknown'], ['control', 'gui_history_entry']]) {
    await manager.handle({ type: 'gui_channel', channel, message: { id: 'rejected', type } });
    assert.equal(output.at(-1).message.error, 'UNKNOWN_COMMAND');
  }
  assert.equal(routed.length, commands.length);
});

test('public bridge checks session, leaf and idle before invoking native navigation', async () => {
  const calls = [];
  const entry = {type:'message',id:'user',parentId:null,message:{role:'user',content:[{type:'text',text:'prompt'},{type:'image',data:'abc',mimeType:'image/png'}]}};
  let idle = true, leaf = 'answer';
  const ctx = {
    sessionManager:{getSessionId:()=> 's',getLeafId:()=>leaf,getEntry:id=>id==='user'?entry:undefined},
    isIdle:()=>idle,hasPendingMessages:()=>false,
    navigateTree:async(id,options)=>{calls.push([id,options]);return{cancelled:false};},
  };
  const request = {sessionId:'s',leafId:'answer',entryId:'user',operation:'navigate',summarize:true,customInstructions:'focus',replaceInstructions:true};
  await assert.rejects(historyAction({...request,sessionId:'other'},ctx,{}),{code:'HISTORY_STALE'});
  await assert.rejects(historyAction({...request,leafId:'other'},ctx,{}),{code:'HISTORY_STALE'});
  idle=false;
  await assert.rejects(historyAction(request,ctx,{}),{code:'HISTORY_BUSY'});
  assert.equal(calls.length,0); idle=true;
  const result = await historyAction(request,ctx,{});
  assert.equal(result.editorText,'prompt'); assert.equal(result.images.length,1);
  assert.deepEqual(calls[0],['user',{summarize:true,customInstructions:'focus',replaceInstructions:true}]);
  ctx.navigateTree=async()=>({cancelled:true});
  assert.deepEqual(await historyAction(request,ctx,{}),{cancelled:true});
  const labels=[];
  await historyAction({...request,operation:'label',label:'  '},ctx,{setLabel:(...a)=>labels.push(a)});
  assert.deepEqual(labels,[['user',undefined]]);
  leaf='changed';
  assert.deepEqual(await historyAction({...request,operation:'entry'},ctx,{}),{entry});
});

test('reserved status transport is consumed without exposing data as badges, other extension UI stays intact', async () => {
  const output=[], pending=new Map();
  const result=new Promise((resolve,reject)=>pending.set('adapter-history-1',{resolve,reject}));
  const envelope={type:'response',id:'adapter-history-1',command:'gui_history_bridge',success:true,data:{entry:{id:'a'}}};
  routePiOutput(JSON.stringify({type:'extension_ui_request',method:'setStatus',statusKey:'pi-gui-history:adapter-history-1',statusText:'broken'}),pending,(...args)=>output.push(args));
  assert.equal(pending.size,1);
  routePiOutput(JSON.stringify({type:'extension_ui_request',method:'setStatus',statusKey:'pi-gui-history:adapter-history-1',statusText:JSON.stringify(envelope)}),pending,(...args)=>output.push(args));
  assert.deepEqual(await result,envelope.data); assert.equal(output.length,0); assert.equal(pending.size,0);
  const ordinary=JSON.stringify({type:'extension_ui_request',method:'setStatus',statusKey:'plugin',statusText:'visible'});
  routePiOutput(ordinary,pending,(...args)=>output.push(args));
  assert.equal(output[0][0],ordinary);
  routePiOutput(JSON.stringify({type:'extension_ui_request',method:'setStatus',statusKey:'pi-gui-history:reset',statusText:'reset'}),pending,(...args)=>output.push(args));
  assert.equal(output[1][1].type,'gui_history_session_reset');
});

test('abort during adapter preflight prevents a not-yet-dispatched navigation', async () => {
  let release;
  const state = new Promise(resolve => { release = resolve; });
  const replies = [], sent = [];
  const adapter = new WorkspaceAdapter({current:'/unused',invalidateSessions(){}},()=>{},line=>replies.push(JSON.parse(line)));
  adapter.pi = {
    request: () => state,
    send: request => sent.push(request.type),
    history: () => { throw new Error('Must not navigate after preflight cancellation'); },
  };
  const operation = adapter.handle({id:'history',type:'gui_history_navigate',sessionId:'s',leafId:'leaf',entryId:'user'});
  await adapter.handle({id:'stop',type:'abort'});
  release({sessionId:'s',isStreaming:false,isCompacting:false,pendingMessageCount:0});
  await operation;
  assert.deepEqual(sent,['abort']);
  assert.equal(replies.find(r=>r.id==='history').error,'HISTORY_CANCELLED');
  assert.equal(adapter.historyMutating,false);
});
