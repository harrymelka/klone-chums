#!/usr/bin/env python3
"""Install the separate signed app on the available paired iPhone, then launch it."""
import json,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
app=root/'app/build/sym/Release-iphoneos/Chums.app'
if not app.is_dir():raise SystemExit('Run klone/build-iphone.sh first.')
with tempfile.TemporaryDirectory() as d:
 out=Path(d)/'devices.json'
 subprocess.run(['xcrun','devicectl','list','devices','--json-output',str(out)],check=True,stdout=subprocess.DEVNULL)
 devices=json.loads(out.read_text())['result']['devices']
 phones=[x for x in devices if x.get('hardwareProperties',{}).get('platform')=='iOS' and x.get('connectionProperties',{}).get('pairingState')=='paired' and x.get('connectionProperties',{}).get('tunnelState')!='unavailable']
 if len(phones)!=1:raise SystemExit('Connect one paired iPhone and unlock it, then retry.')
 device=phones[0]['identifier']
 subprocess.run(['xcrun','devicectl','device','install','app','--device',device,str(app)],check=True)
 subprocess.run(['xcrun','devicectl','device','process','launch','--device',device,'com.harry.klonechums'],check=True)
