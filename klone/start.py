#!/usr/bin/env python3
"""Start an isolated local hub without launchd or changing login services."""
import json,os,subprocess,sys,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1];local=root/'.local';config=local/'server/config.json'
if not config.exists():subprocess.run([sys.executable,str(root/'klone/prepare.py')],check=True)
cfg=json.loads(config.read_text())
try:
 req=urllib.request.Request('http://127.0.0.1:'+str(cfg['port'])+'/v1/ping',headers={'Authorization':'Bearer '+cfg['watchToken']})
 with urllib.request.urlopen(req,timeout=2) as r:
  if r.status==200:print('Klone hub already running.');sys.exit(0)
except Exception:pass
env=dict(os.environ,CHUMS_CONFIG_DIR=str(local/'server'))
node=Path.home()/'.nvm/versions/node/v24.22.0/bin/node'
with open(local/'hub.log','ab') as log:
 p=subprocess.Popen([str(node) if node.exists() else 'node',str(root/'hub/hub.mjs')],cwd=root,env=env,stdout=log,stderr=log,start_new_session=True)
(local/'hub.pid').write_text(str(p.pid))
print('Klone hub started locally. Log: .local/hub.log')
