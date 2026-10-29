/*
 * APTEEN (Manjeshwar & Agrawal, 2002) pour TOSSIM - TP RCSF
 * Auteur : KOBENDE Pegdwende Evrard
 *
 * Parametres communs du scenario impose et du modele radio de premier ordre.
 */
#ifndef APTEEN_H
#define APTEEN_H

#include "topo.h"   /* genere par gen_topo.py : NUM_SENSORS, POS_X[], POS_Y[] */

enum { AM_APTEEN = 0x42 };
enum { K_ADV = 1, K_JOIN = 2, K_SCHED = 3, K_DATA = 4 };

#define BS_ID     0
#define NO_CH     0xFFFF

/* MODE : 0 = APTEEN (seuils + count time), 1 = TEEN (seuils seuls),
 *        2 = LEACH (envoi a chaque round, pas de seuil) */
#ifndef MODE
#define MODE 0
#endif

#define MAX_MEMBERS 48
#define MAX_RETRY   3

/* Temps en "ms binaires" (1/1024 s) du timer TMilli de TinyOS */
#define ROUND_MS        3072   /* 3 s par round                       */
#define ADV_WIN          102   /* fenetre aleatoire d'emission des ADV */
#define JOIN_START       307   /* debut des JOIN-REQ                  */
#define JOIN_WIN         768   /* fenetre aleatoire des JOIN-REQ      */
#define SCHED_MIN       1126   /* le CH n'envoie pas le TDMA avant    */
#define SCHED_QUIET      154   /* silence requis apres le dernier JOIN */
#define SCHED_POLL        51
#define SCHED_DEADLINE  1536   /* au plus tard, le CH envoie le TDMA  */
#define STEADY_START    1843   /* debut de la trame TDMA (phase stable) */
#define SLOT_MS           10
#define CP_MS            154   /* periode de contention (CSMA) en debut de trame */
#define SCHED_JITTER      82   /* gigue avant la diffusion du TDMA */

/* Election LEACH */
#define P_CH   0.05
#define EPOCH  20               /* 1 / P_CH */

/* Modele radio de premier ordre (valeurs imposees) */
#define E_INIT     0.5
#define E_ELEC     50e-9        /* J/bit         */
#define E_FS       10e-12       /* J/bit/m^2     */
#define E_MP       0.0013e-12   /* J/bit/m^4     */
#define E_DA       5e-9         /* J/bit/signal (agregation) */
#define D0         87.7         /* sqrt(E_FS/E_MP) */
#define DATA_BITS  4000
#define CTRL_BITS  200
#define D_BCAST    141.4        /* portee d'un broadcast : demi-diagonale */

/* Attributs APTEEN diffuses par le CH */
#define HT_DEFAULT 50           /* seuil dur  (unite du capteur) */
#define ST_DEFAULT 2            /* seuil doux                    */
#define CT_DEFAULT 5            /* count time (en rounds)        */

typedef nx_struct apteen_msg {
  nx_uint8_t  kind;
  nx_uint16_t round;
  nx_uint16_t count;            /* DATA : lectures agregees ; SCHED : nb membres */
  nx_uint8_t  ht;
  nx_uint8_t  st;
  nx_uint8_t  ct;
  nx_uint16_t ids[MAX_MEMBERS]; /* SCHED : ordre des slots TDMA */
} apteen_msg_t;

#endif
