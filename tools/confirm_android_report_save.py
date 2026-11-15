#!/usr/bin/env python3
"""Complete only Smart-Cycle's native Save dialog on an Android test emulator.

Run alongside simulation_report_device_test.dart. The PDF is saved to Downloads
and copied to build/simulation-report-review; no physical device is accepted.
"""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('--device', default='emulator-5554')
args = parser.parse_args()
if not args.device.startswith('emulator-'):
    raise SystemExit('Este ayudante solo admite emuladores de pruebas.')
adb = shutil.which('adb') or str(Path.home() / 'Library/Android/sdk/platform-tools/adb')
output = Path('build/simulation-report-review')
output.mkdir(parents=True, exist_ok=True)

def command(*items, check=True):
    return subprocess.run([adb, '-s', args.device, *items], capture_output=True, check=check)

def reports():
    result = command('shell', "find /sdcard/Download -maxdepth 1 -name 'TerraCrop-SmartCycle-*.pdf'", check=False)
    return set(result.stdout.decode().splitlines())

previous = reports()
deadline = time.monotonic() + 240
while time.monotonic() < deadline:
    top = command('shell', 'dumpsys', 'activity', 'activities').stdout.decode()
    if not any('ResumedActivity' in line and 'documentsui' in line for line in top.splitlines()):
        time.sleep(1)
        continue
    command('shell', 'uiautomator', 'dump', '/sdcard/terracrop-save-ui.xml', check=False)
    xml = command('shell', 'cat', '/sdcard/terracrop-save-ui.xml', check=False).stdout
    try:
        nodes = list(ET.fromstring(xml).iter('node'))
    except ET.ParseError:
        time.sleep(1)
        continue
    buttons = [node for node in nodes if node.get('text', '').lower() in ('save', 'guardar') and node.get('clickable') == 'true']
    if not buttons:
        time.sleep(1)
        continue
    # Confirm this is our generated PDF, rather than another native dialog.
    if not any('TerraCrop-SmartCycle-' in node.get('text', '') for node in nodes):
        time.sleep(1)
        continue
    (output / 'native-save-dialog.xml').write_bytes(xml)
    (output / 'native-save-dialog.png').write_bytes(command('exec-out', 'screencap', '-p').stdout)
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', buttons[-1].get('bounds', '')))
    command('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
    print('Selector nativo: Guardar pulsado.', flush=True)
    for _ in range(30):
        new = reports() - previous
        if new:
            source = sorted(new)[-1]
            target = output / 'native-saved.pdf'
            command('pull', source, str(target))
            if target.read_bytes().startswith(b'%PDF-'):
                print(f'PDF real recuperado: {target} ({target.stat().st_size} bytes).', flush=True)
                raise SystemExit(0)
        time.sleep(1)
    raise SystemExit('El PDF no apareció en Downloads.')
raise SystemExit('No apareció el selector de guardado de Smart-Cycle.')
