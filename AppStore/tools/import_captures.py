#!/usr/bin/env python3
"""Import named XCTest attachments without changing the original screen pixels."""
import argparse,json,re,shutil
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('attachments',type=Path)
p.add_argument('--kit',type=Path,default=Path(__file__).resolve().parents[1])
p.add_argument('--group',choices=['iphone','ipad-13'],default='iphone')
p.add_argument('--xcresult',required=True)
a=p.parse_args();out=a.kit/'screenshots/raw'/a.group;out.mkdir(parents=True,exist_ok=True);records=[]
for suite in json.loads((a.attachments/'manifest.json').read_text()):
    for item in suite['attachments']:
        match=re.match(r'store-(.+?)_\d_',item['suggestedHumanReadableName'])
        if not match:continue
        target=out/(match[1]+'.png');shutil.copy2(a.attachments/item['exportedFileName'],target)
        records.append(dict(file=str(target.relative_to(a.kit)),device=item['deviceName'],device_id=item['deviceId'],timestamp=item['timestamp'],xcresult=a.xcresult,test='testAppStoreScreenshots',fictional_data=True))
if not records:raise SystemExit('No store-* screenshot attachments found')
report=a.kit/'reports'/('capture-ipad.json' if a.group=='ipad-13' else 'capture-iphone.json');report.parent.mkdir(exist_ok=True);report.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print(f'Imported {len(records)} screenshots to {out}')
