# RCSF_APTEEN_TOSSIM

Implémentation de l'algorithme de clustering **APTEEN** (Manjeshwar & Agrawal, 2002) dans le simulateur **TOSSIM** (TinyOS), réalisée dans le cadre du TP *Réseaux de Capteurs Sans Fil* (Master 2025-2026, Université Joseph Ki-Zerbo / IBAM).

Auteur : KOBENDE Pêgdwendé Evrard

## Scénario

- 100 nœuds aléatoires sur 200 × 200 m, station de base en (100, 250)
- Énergie initiale 0,5 J par nœud, 1000 rounds
- Modèle radio de premier ordre : Eelec = 50 nJ/bit, εfs = 10 pJ/bit/m², εmp = 0,0013 pJ/bit/m⁴
- Attributs APTEEN : seuil dur HT = 50, seuil doux ST = 2, compteur de temps CT = 5 rounds

Le même code se compile en trois variantes (`MODE`) pour servir de références :

| MODE | Variante | Règle d'émission |
|------|----------|------------------|
| 0 | APTEEN | seuils HT/ST + émission forcée tous les CT rounds |
| 1 | TEEN | seuils HT/ST seuls |
| 2 | LEACH | émission à chaque round |

## Contenu

```
app/ApteenC.nc      module nesC : élection LEACH, ADV, JOIN-REQ, TDMA, règles APTEEN, énergie
app/ApteenAppC.nc   câblage des composants TinyOS
app/Apteen.h        paramètres du scénario, du modèle radio et du protocole
app/gen_topo.py     génère la topologie (topo.h compilé dans les nœuds, topo.csv pour le canal)
app/run.py          pilote TOSSIM : canal log-distance + shadowing, bruit CPM (meyer-heavy)
docker/Dockerfile   environnement TinyOS + nesC 1.4 + TOSSIM (Ubuntu 16.04)
run_all.sh          lance toutes les simulations du TP
analyze.py          extrait les métriques et les coordonnées des courbes
results/            journaux bruts des simulations, summary.txt, pgf_coords.txt
```

## Reproduire les résultats

```bash
# 1. Construire l'environnement TOSSIM (une seule fois)
docker build -t tossim:2.1.2 docker/

# 2. Lancer les simulations (environ 10 minutes)
docker run --rm -v "$PWD":/work -w /work tossim:2.1.2 bash run_all.sh

# 3. Calculer les métriques
python3 analyze.py
```

`run_all.sh` produit :
- `apteen_100.log`, `teen_100.log`, `leach_100.log` : 100 nœuds, 1000 rounds ;
- `apteen_50.log`, `apteen_300.log` : passage à l'échelle, 100 rounds.

## Résultats principaux (100 nœuds, 1000 rounds)

| Métrique | APTEEN | TEEN | LEACH |
|----------|--------|------|-------|
| Premier nœud mort (FND) | round 105 | round 149 | round 25 |
| Moitié des nœuds morts (HND) | round 764 | > 1000 | round 281 |
| Énergie résiduelle au round 1000 | 2,46 J | 12,54 J | 0 J |
| Taux de livraison | 85,4 % | 88,5 % | 73,5 % |

Le détail figure dans `results/summary.txt`.
