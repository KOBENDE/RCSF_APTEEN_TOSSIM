#!/usr/bin/env python3
"""Extrait les metriques des journaux TOSSIM et produit les coordonnees pgfplots.

Usage : python3 analyze.py   (depuis tossim_apteen/, apres run_all.sh)
"""
import os
import re
from collections import defaultdict

RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
LINE = re.compile(r"DEBUG \(\d+\): (\w+) (.*)")


def parse(name, max_round=None):
    energy = defaultdict(float)      # round -> energie residuelle totale
    alive = defaultdict(int)         # round -> noeuds vivants
    setup = defaultdict(float)       # round -> instant de formation du dernier cluster
    ctrl = defaultdict(int)          # round -> messages de controle emis
    gen = defaultdict(int)
    gen_kind = defaultdict(int)
    recv = defaultdict(int)
    chs = defaultdict(int)
    for raw in open(os.path.join(RES, name)):
        m = LINE.search(raw)
        if not m:
            continue
        tag, f = m.group(1), m.group(2).split()
        r = int(f[0])
        if max_round and r > max_round:
            continue
        if tag == "E":
            e = float(f[2])
            energy[r] += e
            alive[r] += e > 0
        elif tag == "SETUP":
            setup[r] = max(setup[r], float(f[2]))
        elif tag == "CTRL":
            ctrl[r] += 1
        elif tag == "GEN":
            gen[r] += 1
            gen_kind[f[2]] += 1
        elif tag == "RECV":
            recv[r] += int(f[2])
        elif tag == "CH":
            chs[r] += 1
    return dict(energy=energy, alive=alive, setup=setup, ctrl=ctrl, gen=gen,
                gen_kind=gen_kind, recv=recv, chs=chs)


def first_round(alive, n, cond):
    for r in sorted(alive):
        if cond(alive[r], n):
            return r
    return None


def mean(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else float("nan")


out = []
curves = {}
for proto in ("apteen", "teen", "leach"):
    fn = "%s_100.log" % proto
    if not os.path.exists(os.path.join(RES, fn)):
        continue
    d = parse(fn)
    n = d["alive"][1]
    e0 = d["energy"][1]
    rounds = sorted(d["energy"])
    fnd = first_round(d["alive"], n, lambda a, n: a < n)
    hnd = first_round(d["alive"], n, lambda a, n: a <= n / 2)
    lnd = first_round(d["alive"], n, lambda a, n: a == 0)
    g, rc = sum(d["gen"].values()), sum(d["recv"].values())
    out.append("== %s (100 noeuds) ==" % proto.upper())
    out.append("E initiale %.2f J ; E residuelle round %d : %.3f J" % (e0, rounds[-1], d["energy"][rounds[-1]]))
    out.append("FND %s  HND %s  LND %s" % (fnd, hnd, lnd))
    out.append("PDR %.4f (%d recues / %d emises) ; types GEN %s" % (rc / g, rc, g, dict(d["gen_kind"])))
    out.append("Ctrl/round (rounds 1-100) %.1f ; setup moyen %.3f s" % (
        mean(d["ctrl"][r] for r in range(1, 101)), mean(d["setup"][r] for r in range(1, 101) if r in d["setup"])))
    out.append("Donnees emises/round (1-100) %.1f ; CH/round %.2f" % (
        mean(d["gen"][r] for r in range(1, 101)), mean(d["chs"][r] for r in range(1, 101))))
    for r0 in (1, 250, 500, 750):
        gg = sum(d["gen"][r] for r in range(r0, r0 + 250))
        rr = sum(d["recv"][r] for r in range(r0, r0 + 250))
        out.append("  PDR rounds %d-%d : %s" % (r0, r0 + 249, "%.3f" % (rr / gg) if gg else "-"))
    pts = [(0, e0)] + [(r, d["energy"][r]) for r in rounds if r % 10 == 0]
    curves[proto] = pts
    curves[proto + "_alive"] = [(0, n)] + [(r, d["alive"][r]) for r in rounds if r % 10 == 0]

out.append("== Passage a l'echelle (rounds 1-100) ==")
out.append("N  setup_moy(s)  setup_max(s)  ctrl/round  ctrl/noeud/round  PDR  orphelins%")
for n, fn in ((50, "apteen_50.log"), (100, "apteen_100.log"), (300, "apteen_300.log")):
    if not os.path.exists(os.path.join(RES, fn)):
        continue
    d = parse(fn, max_round=100)
    st = [d["setup"][r] for r in range(1, 101) if r in d["setup"]]
    c = mean(d["ctrl"][r] for r in range(1, 101))
    g, rc = sum(d["gen"].values()), sum(d["recv"].values())
    orph = 100.0 * (d["gen_kind"].get("0", 0)) / g if g else 0
    out.append("%3d  %.3f  %.3f  %.1f  %.2f  %.3f  %.1f" % (n, mean(st), max(st), c, c / n, rc / g, orph))

txt = "\n".join(out)
print(txt)
open(os.path.join(RES, "summary.txt"), "w").write(txt + "\n")

with open(os.path.join(RES, "pgf_coords.txt"), "w") as f:
    for k, pts in curves.items():
        f.write("%% %s\n" % k)
        f.write(" ".join("(%d,%.3f)" % p for p in pts) + "\n")
