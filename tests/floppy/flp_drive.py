#!/usr/bin/env python3
"""flp_drive.py DISKDIR VBLS OUT.png [hatari args] (Phase 8): boot DISKDIR/IRONSEED1.ST (FLP_START=n:
another disk) with C: = hatari/c, answer every "FLP-PROMPT n NAME" of an -DFLPNF build (NatFeats on
Hatari's stderr) by inserting disk n (S: the save disk = the last image) through --cmd-fifo and
pressing space; at VBLS a screenshot, disk 1 back in (the save disk's image is written) and quit.
Log: /tmp/flp.log."""
import os, sys, time, subprocess, tempfile, glob, re
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D, V, OUT = sys.argv[1], int(sys.argv[2]), os.path.abspath(sys.argv[3])
extra = sys.argv[4:]
disks = sorted(glob.glob(D + '/IRONSEED*.ST'), key=lambda f: int(re.search(r'(\d+)\.ST', f).group(1)))
save = disks[-1]
T = tempfile.mkdtemp()
open(T + '/start.ini', 'w').write('b VBL = %d :quiet :file %s/hit.ini\n' % (V, T))
open(T + '/hit.ini', 'w').write('screenshot %s\nsetopt --disk-a %s\nquit\n' % (OUT, disks[0]))
for f in (OUT, '/tmp/flp.fifo'):
    if os.path.exists(f): os.remove(f)
log = open('/tmp/flp.log', 'w')
env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy')
p = subprocess.Popen(['hatari', '--machine', 'ste', '--memsize', '4096', '--tos', R + '/rom/tos162us.img',
    '--harddrive', R + '/hatari/c', '--gemdos-drive', 'c', '--disk-a', disks[int(os.environ.get('FLP_START', '1')) - 1], '--fast-forward', 'on',
    '--sound', 'off', '--statusbar', 'off', '--confirm-quit', 'false', '--natfeats', 'yes',
    '--cmd-fifo', '/tmp/flp.fifo', '--parse', T + '/start.ini'] + extra,
    stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.PIPE, env=env)
pos = 0; t0 = time.time(); n = 0
def cmd(s):
    with open('/tmp/flp.fifo', 'w') as f: f.write(s + '\n')
while time.time() - t0 < V / 40 + 600:
    time.sleep(0.3)
    if os.path.exists(OUT) and os.path.getsize(OUT) > 0:
        time.sleep(1); break
    txt = open('/tmp/flp.log', errors='replace').read()
    for m in re.finditer(r'FLP-PROMPT (\w)', txt[pos:]):
        k = m.group(1)
        img = save if k == 'S' else (disks[int(k) - 1] if k.isdigit() else None)
        n += 1
        print('%6.1fs prompt %s -> %s  %s' % (time.time() - t0, k, os.path.basename(img) if img else '?', txt[pos+m.end():].split(chr(10))[0].strip()), flush=True)
        if img:
            cmd('hatari-option --disk-a ' + img)
            time.sleep(0.5)
        cmd('hatari-event keypress 57')
        time.sleep(0.3)
    pos = len(txt)
for i in range(20):                             # (hit.ini: another disk in, then quit: the save
    if p.poll() is not None: break              # disk's image is written back)
    time.sleep(0.5)
p.kill(); p.wait()
print('screenshot' if os.path.exists(OUT) else 'NO SCREENSHOT', OUT, '%d prompts, %.0fs' % (n, time.time() - t0))
