// Klone's Hermes adapter. No CLI process, local soul, or model credentials.
import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'
const clean = text => String(text ?? '').replace(/^\s*\[\[aura:[^\n]*\]\]\s*/, '').trim()
const pause = ms => new Promise(r => setTimeout(r, ms))
export class HermesRunner {
  constructor(agent, hub) {
    this.a = agent; this.hub = hub; this.cfg = hub.hermes; this.stopped = false
    this.file = path.join(hub.dir, 'hermes-pending.json'); this.active = null; this.currentApproval = null
  }
  async json(route, body, key) {
    const headers = { Authorization: `Bearer ${this.cfg.token}`, 'X-Hermes-Session-Key': 'klone-chums' }
    if (body) headers['Content-Type'] = 'application/json'
    if (key) headers['Idempotency-Key'] = key
    let res
    try { res = await fetch(this.cfg.endpoint.replace(/\/$/, '') + '/' + route, {
      method: body ? 'POST' : 'GET', headers, body: body && JSON.stringify(body), signal: AbortSignal.timeout(20_000), redirect: 'error' }) }
    catch { throw Object.assign(new Error('Hermès est injoignable. La tâche sera reprise sans nouvel envoi.'), { retry: true }) }
    if (!res.ok) throw Object.assign(new Error(`Hermès a refusé la requête (${res.status}).`), { status: res.status, retry: res.status >= 500 })
    return res.json()
  }
  persist() {
    const temp = this.file + '.tmp'
    fs.writeFileSync(temp, JSON.stringify(this.active), { mode: 0o600 }); fs.renameSync(temp, this.file)
  }
  start() {
    this.ready = (async () => {
      while (!this.stopped) {
        try { await this.initialize(); return }
        catch (e) {
          this.hub.log('Hermes initialization:', e.message)
          if (this.s) this.hub.hook(this.s, 'StopFailure', { error: e.message })
          if (!e.retry) return
          await pause(2000)
        }
      }
    })()
    return this.ready
  }
  async initialize() {
    const c = await this.json('v1/capabilities')
    if (!c.features?.run_submission || !c.features?.runs_idempotency?.durable || !c.features?.run_approval_response)
      throw new Error('Hermès ne fournit pas les tâches persistantes et autorisations nécessaires.')
    this.s = this.hub.join({ id: `hermes-${this.a.id}`, name: this.a.id, cwd: this.a.cwd, driver: this })
    this.hub.hook(this.s, 'SessionStart', { source: 'resume' })
    await this.history()
    if (fs.existsSync(this.file)) {
      const saved = JSON.parse(fs.readFileSync(this.file, 'utf8'))
      if (saved.endpoint !== this.cfg.endpoint || saved.session !== this.cfg.sessionID) throw new Error('La connexion ne correspond pas à la tâche en attente.')
      saved.restored = true; this.active = saved; this.work()
    }
  }
  async history() {
    let data
    try { data = await this.json(`api/sessions/${encodeURIComponent(this.cfg.sessionID)}/messages?limit=100&order=latest&inline_images=false`) }
    catch (e) { if (e.status === 404) return; throw e }
    const rows = (data.data ?? []).filter(x => ['user', 'assistant'].includes(x.role) && !x.tool_calls?.length && x.display_kind !== 'commentary')
      .map(x => ({ id: `hermes-${x.id}`, text: clean(typeof x.content === 'string' ? x.content : (x.content ?? []).filter(p => ['text','output_text'].includes(p.type)).map(p => p.text).join('\n')),
        kind: x.role === 'user' ? 'echo' : 'done', at: (x.timestamp ?? Date.now()/1000) * 1000 })).filter(x => x.text)
    this.historyLines = rows
    this.hub.history?.(this.a.id, rows)
  }
  deliver(item) {
    if (item.type === 'verdict') return this.decide(item)
    if (item.type !== 'order') return
    if (this.active) throw Object.assign(new Error('Hermès traite déjà une demande. Attends sa réponse avant un nouvel envoi.'), { status: 409 })
    if (item.files?.length) throw Object.assign(new Error('Les pièces jointes Hermès seront intégrées à la prochaine étape. Envoie du texte ou un message vocal.'), { status: 400 })
    this.active = { endpoint: this.cfg.endpoint, session: this.cfg.sessionID, requestID: item.requestID || `klone-${crypto.randomUUID()}`,
      input: item.said, device: item.device ?? 'phone', createdAt: Date.now(), runID: null }
    this.persist(); this.work()
  }
  work() {
    this.loop().catch(e => { this.hub.hook(this.s, 'StopFailure', { error: e.message }) })
  }
  async loop() {
    const turn = this.active
    this.s.replyTo = turn.device; this.hub.hook(this.s, 'UserPromptSubmit')
    let events = null
    while (!this.stopped && this.active === turn) {
      try {
        if (!turn.runID) {
          if (Date.now() - turn.createdAt >= 23 * 3600_000) throw new Error('Reprise trop ancienne : vérifie l’historique Hermès avant un nouvel envoi.')
          const r = await this.json('v1/runs', { input: turn.input, session_id: turn.session,
            instructions: 'Réponds en français. Tu conserves ta personnalité, ta mémoire et tes outils Hermès. Le client est Klone Chums, sur iPhone ou Apple Watch. Réponds clairement et brièvement par défaut, sans balise technique aura ni outil chums_reply.' }, turn.requestID)
          if (!r.run_id) throw new Error('Réponse Hermès incompatible.')
          turn.runID = r.run_id; this.persist()
        }
        if (!events) { events = new AbortController(); this.events(turn.runID, events.signal).catch(() => {}) }
        const r = await this.json(`v1/runs/${encodeURIComponent(turn.runID)}`)
        if (r.status === 'waiting_for_approval' && r.approval) this.showApproval(r.approval)
        else if (this.currentApproval) { this.hub.closeApproval(this.currentApproval); this.currentApproval = null }
        if (['completed','failed','cancelled','interrupted'].includes(r.status)) {
          events.abort()
          if (this.currentApproval) this.hub.closeApproval(this.currentApproval)
          this.currentApproval = null
          if (r.status === 'completed') {
            const text = clean(r.output)
            if (text && !turn.delivered && !(turn.restored && this.historyLines?.at(-1)?.text === text)) { this.hub.reply(this.s, text, 'done'); turn.delivered = true; this.persist() }
            this.hub.hook(this.s, 'Stop')
          } else this.hub.reply(this.s, r.status === 'cancelled' ? 'La demande a été arrêtée.' : 'Hermès n’a pas terminé cette demande. Consulte son historique avant de relancer une action.', 'blocked')
          this.active = null; fs.rmSync(this.file, { force: true }); return
        }
      } catch (e) {
        if (!e.retry) { events?.abort(); throw e }
        this.hub.hook(this.s, 'StopFailure', { error: 'Connexion Hermès interrompue, reprise en cours…' })
        await pause(2000)
      }
      await pause(this.cfg.pollMs ?? 1000)
    }
    events?.abort()
  }
  showApproval(a) {
    if (!a.request_id || a.request_id === this.currentApproval) return
    if (this.currentApproval) this.hub.closeApproval(this.currentApproval)
    this.currentApproval = a.request_id
    this.hub.ask(this.s, { requestId: a.request_id, tool: 'Hermès', description: a.command ?? a.description ?? 'Hermès demande ton autorisation.', input: {} })
  }
  async decide(item) {
    if (!this.active?.runID || item.requestId !== this.currentApproval) throw Object.assign(new Error('Cette autorisation n’est plus active.'), { status: 409 })
    await this.json(`v1/runs/${encodeURIComponent(this.active.runID)}/approval`, { request_id: item.requestId, choice: item.behavior === 'allow' ? 'once' : 'deny' })
    this.currentApproval = null
  }
  async events(id, signal) {
    const r = await fetch(`${this.cfg.endpoint}/v1/runs/${encodeURIComponent(id)}/events`, { headers: { Authorization: `Bearer ${this.cfg.token}`, Accept: 'text/event-stream' }, signal, redirect: 'error' })
    if (!r.ok) return
    let pending = ''; const decoder = new TextDecoder()
    for await (const chunk of r.body) {
      pending += decoder.decode(chunk, { stream: true })
      const lines = pending.split('\n'); pending = lines.pop()
      for (const line of lines) {
        if (!line.startsWith('data:')) continue
        let e; try { e = JSON.parse(line.slice(5)) } catch { continue }
        if (e.event === 'tool.started') this.hub.hook(this.s, 'PreToolUse', { tool: e.tool ?? 'Hermès', input: {} })
        if (e.event === 'tool.completed') this.hub.hook(this.s, 'PostToolUse', { result: JSON.stringify({ is_error: !!e.error }) })
        if (e.event === 'approval.request') this.showApproval(e)
        if (e.event === 'approval.responded' && this.currentApproval === e.request_id) { this.hub.closeApproval(this.currentApproval); this.currentApproval = null }
      }
    }
  }
  stop() { this.stopped = true }
}
