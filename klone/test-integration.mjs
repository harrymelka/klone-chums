import {test} from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import http from 'node:http'
import {spawn} from 'node:child_process'
const sleep=ms=>new Promise(r=>setTimeout(r,ms))
const until=async fn=>{const end=Date.now()+6000;while(Date.now()<end){try{const r=await fn();if(r)return r}catch{}await sleep(30)}throw Error('timed out')}
const port=async()=>{const s=http.createServer();await new Promise(r=>s.listen(0,'127.0.0.1',r));const p=s.address().port;await new Promise(r=>s.close(r));return p}
test('phone HTTP route, shared history, exact asynchronous approval and full reply',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'klone-http-'));let hub,status='running',rejectOnce=true,submitted=0,submittedBody,whisperText='Bonjour, ceci est un brouillon vocal.'
 const hermes=http.createServer(async(req,res)=>{
  let body='';for await(const c of req)body+=c
  const send=(code,v)=>{res.writeHead(code,{'Content-Type':'application/json'});res.end(JSON.stringify(v))}
  if(req.url==='/v1/capabilities')return send(200,{features:{run_submission:true,runs_idempotency:{durable:true},run_approval_response:true}})
  if(req.url.includes('/messages'))return send(200,{data:[{id:'old-1',role:'user',content:'Ancien échange',timestamp:1},{id:'old-2',role:'assistant',content:'Réponse précédente',timestamp:2}]})
  if(req.url.endsWith('/events'))return send(200,{})
  if(req.url==='/stt')return send(200,{text:whisperText})
  if(req.url==='/v1/runs'){submittedBody=JSON.parse(body);submitted++;return send(200,{run_id:'one'})}
  if(req.url.endsWith('/approval')){assert.deepEqual(JSON.parse(body),{request_id:'exact',choice:'deny'});if(rejectOnce){rejectOnce=false;return send(503,{})};status='completed';return send(200,{resolved:1})}
  send(200,{status,approval:status==='waiting_for_approval'?{request_id:'exact',command:'action précise'}:null,output:'Voici une réponse complète. Elle conserve toutes ses phrases sur iPhone.'})
 })
 await new Promise(r=>hermes.listen(0,'127.0.0.1',r))
 const p=await port(),publicPort=await port()
 fs.writeFileSync(path.join(dir,'config.json'),JSON.stringify({port:p,publicPort,token:'local',watchToken:'phone',hermes:{endpoint:`http://127.0.0.1:${hermes.address().port}`,token:'fixture',sessionID:'shared',pollMs:20},stt:{endpoint:`http://127.0.0.1:${hermes.address().port}/stt`}}))
 fs.writeFileSync(path.join(dir,'agents.json'),JSON.stringify([{id:'noodle',name:'Hermès',runtime:'hermes',character:'noodle',cwd:dir}]))
 hub=spawn(process.execPath,['hub/hub.mjs'],{cwd:path.resolve(import.meta.dirname,'..'),env:{...process.env,CHUMS_CONFIG_DIR:dir,CHUMS_NO_WHISPER:'1'},stdio:'ignore'})
 const call=async(route,body)=>{const r=await fetch(`http://127.0.0.1:${publicPort}${route}`,{method:body?'POST':'GET',headers:{Authorization:'Bearer phone','Content-Type':'application/json'},body:body&&JSON.stringify(body)});return {status:r.status,body:await r.json()}}
 const state=async()=>(await call('/v1/state?since=0')).body
 try{
  await until(async()=>(await state()).agents?.[0]?.status==='idle')
  assert.ok((await state()).spoken.some(x=>x.text==='Réponse précédente'))
  const before=await state()
  const wav=Buffer.alloc(44+16000);wav.write('RIFF',0);wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(16000,24);wav.writeUInt32LE(32000,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(16000,40)
  let preview=await fetch(`http://127.0.0.1:${publicPort}/v1/transcribe`,{method:'POST',headers:{Authorization:'Bearer phone','Content-Type':'audio/m4a'},body:wav})
  assert.equal(preview.status,200);assert.equal((await preview.json()).transcript,'Bonjour, ceci est un brouillon vocal.')
  assert.equal(submitted,0);assert.deepEqual((await state()).spoken,before.spoken)
  whisperText=''
  preview=await fetch(`http://127.0.0.1:${publicPort}/v1/transcribe`,{method:'POST',headers:{Authorization:'Bearer phone'},body:wav})
  assert.equal(preview.status,422);assert.equal(submitted,0)
  preview=await fetch(`http://127.0.0.1:${publicPort}/v1/transcribe`,{method:'POST',headers:{Authorization:'Bearer phone'},body:Buffer.alloc(0)})
  assert.equal(preview.status,400);assert.equal(submitted,0)
  const bytes=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/zfkAAAAASUVORK5CYII=','base64')
  const uploaded=await fetch(`http://127.0.0.1:${publicPort}/v1/upload?name=photo.png`,{method:'POST',headers:{Authorization:'Bearer phone'},body:bytes})
  assert.equal(uploaded.status,200);const photo=await uploaded.json()
  assert.equal((await call('/v1/say',{agent:'noodle',device:'phone',text:'Photo perdue',files:['/missing']})).status,400)
  const result=await call('/v1/say',{agent:'noodle',device:'phone',files:[photo.path],text:'Une demande écrite intégrale sur iPhone avec assez de mots pour dépasser la limite de quatorze mots du texte utilisateur original.'})
  assert.equal(result.status,200);assert.equal(result.body.kind,'order');await until(()=>submitted===1)
  assert.equal(submittedBody.input[0].content[1].image_url.url,'data:image/png;base64,'+bytes.toString('base64'))
  assert.equal(submittedBody.session_id,'shared')
  status='waiting_for_approval';await until(async()=>(await state()).approvals.length===1)
  assert.equal((await call('/v1/verdict',{requestId:'stale',behavior:'deny'})).status,409)
  assert.equal((await call('/v1/verdict',{requestId:'exact',behavior:'deny'})).status,503)
  assert.equal((await state()).approvals.length,1)
  assert.equal((await call('/v1/verdict',{requestId:'exact',behavior:'deny'})).status,200)
  await until(async()=>(await state()).spoken.some(x=>x.text.includes('toutes ses phrases')))
  const s=await state();assert.equal(s.approvals.length,0);assert.equal(submitted,1)
  assert.equal(s.spoken.filter(x=>x.text.includes('toutes ses phrases')).length,1)
  assert.ok(s.spoken.some(x=>x.kind==='echo'&&x.text.endsWith('original.')))
 }finally{hub.kill();await new Promise(r=>hub.on('exit',r));await new Promise(r=>hermes.close(r));fs.rmSync(dir,{recursive:true,force:true})}
})
