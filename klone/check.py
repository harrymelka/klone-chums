#!/usr/bin/env python3
"""Read-only Klone-specific checks. No model call and no tokens printed."""
import json,subprocess,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1];p=root/'.local/server/config.json'
if not p.exists():raise SystemExit('Run python3 klone/prepare.py first.')
c=json.loads(p.read_text())
def check(label,url,token):
 try:
  req=urllib.request.Request(url,headers={'Authorization':'Bearer '+token})
  with urllib.request.urlopen(req,timeout=5) as r:
   data=json.load(r)
  print('PASS',label);return data
 except Exception as e:print('PENDING',label,type(e).__name__);return None
s=check('Klone hub','http://127.0.0.1:'+str(c['port'])+'/v1/state',c['watchToken'])
if s:print('Companion:',', '.join(a['runtime']+' / '+a['status'] for a in s['agents']))
check('Hermes capabilities',c['hermes']['endpoint']+'/v1/capabilities',c['hermes']['token'])
check('French voice',c['tts']['endpoint'].replace('/audio/speech','/aura/voice'),c['hermes']['token'])
if c.get('publicURL'):check('Private iPhone/Watch route',c['publicURL']+'/v1/ping',c['watchToken'])
r=subprocess.run(['docker','exec',c['stt'].get('container','binome'),'python','-c','import faster_whisper; print("PASS Whisper installed in existing Hermes container")'],capture_output=True,text=True)
print(r.stdout.strip() if r.returncode==0 else 'PENDING Docker / local Whisper')
