#!/usr/bin/env python
"""Genere topo.h (positions compilees dans les noeuds) et topo.csv (lu par run.py).

Usage : python gen_topo.py <N> [graine]
Noeud 0 = station de base en (100, 250) ; noeuds 1..N aleatoires sur 200 x 200 m.
"""
import random
import sys

n = int(sys.argv[1])
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
random.seed(seed)

pos = [(100.0, 250.0)]
for _ in range(n):
    pos.append((random.uniform(0, 200), random.uniform(0, 200)))

with open("topo.h", "w") as f:
    f.write("#ifndef TOPO_H\n#define TOPO_H\n")
    f.write("#define NUM_SENSORS %d\n" % n)
    f.write("static const double POS_X[%d] = {%s};\n" % (n + 1, ", ".join("%.3f" % p[0] for p in pos)))
    f.write("static const double POS_Y[%d] = {%s};\n" % (n + 1, ", ".join("%.3f" % p[1] for p in pos)))
    f.write("#endif\n")

with open("topo.csv", "w") as f:
    for i, (x, y) in enumerate(pos):
        f.write("%d,%.3f,%.3f\n" % (i, x, y))
