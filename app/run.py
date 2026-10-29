#!/usr/bin/env python2
"""Pilote TOSSIM : charge la topologie, construit le canal radio et lance la simulation.

Usage : python2 run.py <rounds> <fichier_log> [graine_canal]

Canal : affaiblissement log-distance PL(d) = 40 + 10 n log10(d) avec n = 2
(espace libre, coherent avec le terme epsilon_fs du modele de premier ordre),
plus un shadowing gaussien sigma = 4 dB ; puissance d'emission 0 dBm.
Bruit : modele CPM de TOSSIM alimente par la trace meyer-heavy.
"""
import math
import os
import random
import sys
import time

from TOSSIM import Tossim

ROUND_S = 3.0
rounds = int(sys.argv[1])
logname = sys.argv[2]
random.seed(int(sys.argv[3]) if len(sys.argv) > 3 else 7)

pos = []
for line in open("topo.csv"):
    i, x, y = line.strip().split(",")
    pos.append((float(x), float(y)))
n = len(pos)

t = Tossim([])
log = open(logname, "w")
t.addChannel("Apteen", log)
t.addChannel("Energy", log)
if os.environ.get("TRACE"):
    t.addChannel("Trace", log)

radio = t.radio()
for i in range(n):
    for j in range(n):
        if i == j:
            continue
        d = max(1.0, math.hypot(pos[i][0] - pos[j][0], pos[i][1] - pos[j][1]))
        radio.add(i, j, -40.0 - 20.0 * math.log10(d) + random.gauss(0, 4))

noise = os.path.join(os.environ["TOSROOT"], "tos/lib/tossim/noise/meyer-heavy.txt")
trace = [int(l) for l in open(noise).readlines()[:1000] if l.strip()]
for i in range(n):
    m = t.getNode(i)
    for v in trace:
        m.addNoiseTraceReading(v)
    m.createNoiseModel()
    m.bootAtTime(t.ticksPerSecond())  # meme instant : horloges alignees

end = t.ticksPerSecond() * (1 + ROUND_S * (rounds + 1))
start = time.time()
while t.time() < end:
    if t.runNextEvent() == 0:
        break
log.close()
sys.stderr.write("%d noeuds, %d rounds simules en %.1f s reelles\n" % (n - 1, rounds, time.time() - start))
