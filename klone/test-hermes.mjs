import { test } from 'node:test'
import assert from 'node:assert/strict'
import http from 'node:http'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { HermesRunner } from './hermes.mjs'
const wait = async fn => { const until=Date.now()+5000; while(Date.now()<until) { if(await fn()) return; await new Promise(r=>setTimeout(r,15)) }; throw new Error('timed out') }
async function fixture() {
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'klone-test-'))
 const state={status:'running',posts:[],requests:[],answerFailures:0,submitted:0}
 const server=http.createServer(async(req,res)=>{
  let body='';for await(const b of req) body+=b
  state.requests.push(req.url)
  if(req.headers.authorization!=='Bearer fixture'){res.writeHead(401);return res.end('{}')}
  const send=(code,data)=>{res.writeHead(code,{'Content-Type':'application/json'});res.end(JSON.stringify(data))}
  if(req.url==='/v1/capabilities')return send(200,{features:{run_submission:true,runs_idempotency:{durable:true},run_approval_response:true}})
  if(req.url.includes('/messages'))return send(200,{data:[]})
  if(req.url.endsWith('/events'))return send(200,{})
  if(req.url==='/v1/runs') {state.submitted++;state.posts.push({key:req.headers['idempotency-key'],body:JSON.parse(body)});if(state.submitFailure){state.submitFailure=false;return send(503,{})};return send(200,{run_id:'run-1'})}
  if(req.url.endsWith('/approval')) {
   if(state.answerFailures-- > 0)return send(503,{})
   state.decision=JSON.parse(body);state.status='running';return send(200,{resolved:1})
  }
  return send(200,{status:state.status,output:'Réponse complète. Deuxième phrase conservée.',approval:state.status==='waiting_for_approval'?{request_id:'ask-1',command:'printf test'}:null})
 })
 await new Promise(r=>server.listen(0,'127.0.0.1',r))
 const calls=[]
 const hub={dir,hermes:{endpoint:`http://127.0.0.1:${server.address().port}`,token:'fixture',sessionID:'test-session',pollMs:10},
 log(){},join(x){return {...x}},hook(s,e,f){calls.push(['hook',e,f])},history(){},reply(s,t,k){calls.push(['reply',t,k])},ask(s,a){calls.push(['ask',a])},closeApproval(id){calls.push(['close',id])}}
 const agent={id:'noodle',cwd:dir}
 const create=()=>new HermesRunner(agent,hub)
 return {dir,state,calls,create,async close(){await new Promise(r=>server.close(r));fs.rmSync(dir,{recursive:true,force:true})}}
}
test('durable request, exact approval, rejected decision retained, complete reply',async()=>{
 const f=await fixture();const r=f.create()
 try {
  await r.start();r.deliver({type:'order',said:'bonjour',device:'phone'})
  assert.ok(fs.existsSync(r.file));assert.equal(fs.statSync(r.file).mode & 0o777,0o600)
  assert.throws(()=>r.deliver({type:'order',said:'duplicate'}),/déjà/)
  await wait(()=>f.state.posts.length)
  assert.equal(f.state.posts[0].body.input,'bonjour');assert.equal(f.state.posts[0].body.session_id,'test-session')
  f.state.status='waiting_for_approval';await wait(()=>r.currentApproval==='ask-1')
  await assert.rejects(r.deliver({type:'verdict',requestId:'stale',behavior:'allow'}),/plus active/)
  f.state.answerFailures=1
  await assert.rejects(r.deliver({type:'verdict',requestId:'ask-1',behavior:'allow'}),/503/)
  assert.equal(r.currentApproval,'ask-1')
  await r.deliver({type:'verdict',requestId:'ask-1',behavior:'deny'})
  assert.deepEqual(f.state.decision,{request_id:'ask-1',choice:'deny'})
  f.state.status='completed';await wait(()=>!r.active)
  assert.equal(f.state.submitted,1);assert.equal(fs.existsSync(r.file),false)
  assert.ok(f.calls.some(c=>c[0]==='reply'&&c[1].includes('Deuxième phrase')))
 } finally {r.stop();await f.close()}
})
test('restart resumes persisted run without submitting another task',async()=>{
 const f=await fixture();const r=f.create();let resumed
 try {
  await r.start();r.deliver({type:'order',said:'test',device:'phone'})
  await wait(()=>r.active?.runID);r.stop();await new Promise(r=>setTimeout(r,30))
  resumed=f.create();await resumed.start();f.state.status='completed';await wait(()=>!resumed.active)
  assert.equal(f.state.submitted,1)
 } finally {r.stop();resumed?.stop();await f.close()}
})
test('uncertain submission retries the same idempotency key',async()=>{
 const f=await fixture();const r=f.create()
 try {
  await r.start();f.state.submitFailure=true;r.deliver({type:'order',said:'test',device:'phone'})
  await wait(()=>f.state.submitted===2)
  assert.equal(f.state.posts[0].key,f.state.posts[1].key)
  f.state.status='completed';await wait(()=>!r.active)
 } finally {r.stop();await f.close()}
})
test('attachments refused before a Hermes task is created',async()=>{
 const f=await fixture();const r=f.create()
 try {await r.start();assert.throws(()=>r.deliver({type:'order',said:'file',files:['/private/file']}),/pièces jointes/);assert.equal(f.state.submitted,0)}finally{r.stop();await f.close()}
})
