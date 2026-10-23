#!/usr/bin/env python3
# hdesk.py CDIR OUTDIR SCRIPT [hatari args] - drive the GEM desktop in Hatari through --cmd-fifo:
# boots an STE 4 MB with TOS 1.62 (ISTE_ROM), C: = CDIR; add --fast-forward on (host sleeps then
# cover more emulated time). The mouse is moved with TOS's keyboard emulation (Alt+arrows 8 px,
# Shift+Alt+arrows 1 px; Alt+Insert = left click), which also reaches the game kernel's handler.
# The desktop starts with the pointer at 160,100 (low res); screenshots are 832x552 with the
# screen at x 96 + 2x, y 58 + 2y.
# SCRIPT lines: sleep S (host seconds) | shot NAME | raw <fifo command> | alt DIR N (alt+arrow N times) | dbl | key SC | quit
import os, sys, time, subprocess, tempfile
cdir, outdir, script = sys.argv[1:4]
extra = sys.argv[4:]
os.makedirs(outdir, exist_ok=True)
tmp = tempfile.mkdtemp()
fifo = os.path.join(tmp, "fifo")
env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
log = open(os.path.join(outdir, "hatari.log"), "w")
p = subprocess.Popen(["hatari", "--machine", "ste", "--memsize", "4096", "--tos", os.environ.get("ISTE_ROM", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rom", "tos162us.img")),
    "--harddrive", cdir, "--gemdos-drive", "c", "--drive-a", "false", "--drive-b", "false",
    "--sound", "off", "--statusbar", "off", "--confirm-quit", "false", "--cmd-fifo", fifo] + extra,
    env=env, stdout=log, stderr=log, stdin=subprocess.PIPE)
for i in range(100):
    if os.path.exists(fifo): break
    time.sleep(0.1)
f = open(fifo, "w")
def send(s):
    f.write(s + "\n"); f.flush(); time.sleep(0.15)
ARROW = {"up": 72, "down": 80, "left": 75, "right": 77}
for line in open(script):
    line = line.strip()
    if not line or line.startswith("#"): continue
    c, *a = line.split(None, 1); a = a[0] if a else ""
    if c == "sleep": time.sleep(float(a))
    elif c == "shot": send("hatari-debug screenshot " + os.path.join(os.path.abspath(outdir), a + ".png")); time.sleep(0.5)
    elif c == "raw": send(a)
    elif c == "alt":
        d, n = a.split(); send("hatari-event keydown 56")
        for _ in range(int(n)): send("hatari-event keypress %d" % ARROW[d])
        send("hatari-event keyup 56")
    elif c == "salt":  # shift+alt: 1 pixel steps
        d, n = a.split(); send("hatari-event keydown 56"); send("hatari-event keydown 42")
        for _ in range(int(n)): send("hatari-event keypress %d" % ARROW[d])
        send("hatari-event keyup 42"); send("hatari-event keyup 56")
    elif c == "dbl": send("hatari-event doubleclick")
    elif c == "click":  # alt+insert = left click
        send("hatari-event keydown 56"); send("hatari-event keydown 82"); time.sleep(0.1); send("hatari-event keyup 82"); send("hatari-event keyup 56")
    elif c == "key": send("hatari-event keypress " + a)
    elif c == "quit": break
p.kill(); p.wait()
