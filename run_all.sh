#!/bin/bash
# Lance toutes les simulations du TP dans le conteneur TOSSIM.
# Usage (depuis tossim_apteen/) :
#   docker run --rm -v "$PWD":/work -w /work tossim:2.1.2 bash run_all.sh
set -e
cd /work/app
build() {  # build <N> <MODE>
  python gen_topo.py "$1" 1
  rm -rf simbuild _TOSSIMmodule.so
  make micaz sim MODE="$2" > /dev/null 2>&1
}
# Scenario principal : 100 noeuds, 1000 rounds (APTEEN, puis TEEN et LEACH comme references)
build 100 0; python2 run.py 1000 ../results/apteen_100.log
build 100 1; python2 run.py 1000 ../results/teen_100.log
build 100 2; python2 run.py 1000 ../results/leach_100.log
# Passage a l'echelle : 50 et 300 noeuds, 100 rounds (100 noeuds : 100 premiers rounds du run principal)
build 50 0;  python2 run.py 100 ../results/apteen_50.log
build 300 0; python2 run.py 100 ../results/apteen_300.log
