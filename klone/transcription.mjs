// Reuse the installed Hermes local Whisper backend, in one persistent worker.
import { spawn } from 'node:child_process'
import { createInterface } from 'node:readline'
import crypto from 'node:crypto'
const workerCode = String.raw`
import sys,json,base64,tempfile,os,contextlib
with contextlib.redirect_stdout(sys.stderr):
 from tools.transcription_tools import transcribe_audio_local_fallback
for line in sys.stdin:
 try:
  job=json.loads(line)
  with tempfile.NamedTemporaryFile(suffix='.wav',delete=False) as f:
   f.write(base64.b64decode(job['audio'],validate=True)); filename=f.name
  try:
   with contextlib.redirect_stdout(sys.stderr): result=transcribe_audio_local_fallback(filename)
  finally: os.unlink(filename)
  print(json.dumps({'id':job['id'],'result':result}),flush=True)
 except Exception:
  print(json.dumps({'id':job.get('id'),'result':{'success':False,'error':'Whisper local indisponible'}}),flush=True)
`
export class SharedWhisper {
  constructor(config = {}) { this.config = config; this.pending = new Map() }
  start() {
    if (this.child) return
    this.child = spawn('docker', ['exec', '-i', this.config.container ?? 'binome', 'python', '-u', '-c', workerCode], { stdio: ['pipe','pipe','pipe'] })
    this.child.stderr.resume()
    createInterface({ input: this.child.stdout }).on('line', line => {
      let r; try { r = JSON.parse(line) } catch { return }
      const job = this.pending.get(r.id); if (!job) return
      this.pending.delete(r.id); clearTimeout(job.timer)
      const result = r.result
      if (result?.success === false || result?.error) job.reject(new Error('Whisper local n’a pas pu transcrire cet enregistrement.'))
      else { const text = result?.transcript ?? result?.transcription ?? result?.text ?? ''; text.trim() ? job.resolve(text) : job.reject(new Error('Aucune parole reconnue. Réessaie en parlant un peu plus longtemps.')) }
    })
    const failed = () => { this.child = null; for (const p of this.pending.values()) { clearTimeout(p.timer); p.reject(new Error('Whisper local indisponible.')) }; this.pending.clear() }
    this.child.on('error', failed); this.child.on('exit', failed)
  }
  async transcribe(wav) {
    if (this.pending.size) throw Object.assign(new Error('Une transcription est déjà en cours. Réessaie dans un instant.'), { status: 429 })
    if (this.config.endpoint) {
      const form = new FormData(); form.append('file', new Blob([wav], { type: 'audio/wav' }), 'utterance.wav'); form.append('language', 'fr'); form.append('model', this.config.model ?? 'whisper-1')
      const r = await fetch(this.config.endpoint, { method:'POST', body: form, headers: this.config.token ? { Authorization: `Bearer ${this.config.token}` } : {}, signal: AbortSignal.timeout(120_000), redirect:'error' })
      if (!r.ok) throw new Error(`Whisper partagé indisponible (${r.status}).`)
      return (await r.json()).text ?? ''
    }
    this.start()
    const id = crypto.randomUUID()
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.child?.kill(); reject(new Error('La transcription a dépassé deux minutes.')) }, 120_000)
      this.pending.set(id, { resolve, reject, timer })
      this.child.stdin.write(JSON.stringify({ id, audio: wav.toString('base64') }) + '\n', e => { if(e) { clearTimeout(timer);this.pending.delete(id);reject(new Error('Whisper local indisponible.')) } })
    })
  }
  stop() { this.child?.kill() }
}
