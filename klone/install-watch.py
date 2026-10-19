#!/usr/bin/env python3
"""Install and launch Klone on the paired Watch, after user enables Developer Mode."""
import json,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
app=root/'app/build/sym/Release-watchos/ChumsWatch.app'
if not app.is_dir():raise SystemExit('Run klone/build-iphone.sh first (includes the Watch).')
with tempfile.TemporaryDirectory() as d:
 out=Path(d)/'devices.json'
 subprocess.run(['xcrun','devicectl','list','devices','--json-output',str(out)],check=True,stdout=subprocess.DEVNULL)
 watches=[x for x in json.loads(out.read_text())['result']['devices'] if x.get('hardwareProperties',{}).get('platform')=='watchOS' and x.get('connectionProperties',{}).get('pairingState')=='paired']
 if len(watches)!=1:raise SystemExit('Keep one paired Watch unlocked near the iPhone, then retry.')
 watch=watches[0]
 if watch.get('deviceProperties',{}).get('developerModeStatus')!='enabled':
  raise SystemExit('Watch Developer Mode is not enabled yet: Settings > Privacy & Security > Developer Mode; restart and confirm on the Watch.')
 device=watch['identifier']
 subprocess.run(['xcrun','devicectl','device','install','app','--timeout','60','--device',device,str(app)],check=True)
 subprocess.run(['xcrun','devicectl','device','process','launch','--timeout','30','--device',device,'com.harry.klonechums.watchkitapp'],check=True)
