import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

universe = os.environ['PLAYTEST_UNIVERSE_ID']
place = os.environ['PLAYTEST_PLACE_ID']
if (universe, place) != ('10773779271', '117297879536602'):
    sys.exit('Publication blocked: target must match the approved Ido Playtest experience and place')
key = os.environ['ROBLOX_API_KEY']
assert key, 'Missing Playtest credential'
url = f'https://apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType=Published'
request = urllib.request.Request(url, data=Path(sys.argv[1]).read_bytes(), headers={'x-api-key': key, 'Content-Type': 'application/octet-stream'}, method='POST')
try:
    with urllib.request.urlopen(request, timeout=120) as response:
        result = json.load(response)
except urllib.error.HTTPError as error:
    sys.exit(f'Roblox publication failed: HTTP {error.code}. No automatic retry.')
print(f"Published Playtest version {result['versionNumber']}")
