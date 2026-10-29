/*
 * APTEEN pour TOSSIM.
 *
 * Round = phase de setup (election LEACH, ADV, JOIN-REQ, diffusion du TDMA
 * avec les attributs HT/ST/CT) puis une trame TDMA de phase stable.
 * Un membre emet dans son slot si :
 *   - la valeur mesuree depasse le seuil dur HT et a varie d'au moins ST
 *     depuis la derniere emission (partie reactive, heritee de TEEN), ou
 *   - CT rounds se sont ecoules depuis sa derniere emission (partie periodique).
 * Le CH agrege les lectures recues et envoie un seul paquet a la station de base.
 *
 * L'energie est decomptee avec le modele radio de premier ordre ; la
 * connectivite, les collisions et les pertes sont celles de TOSSIM.
 */
#include <math.h>
#include "Apteen.h"

module ApteenC {
  uses {
    interface Boot;
    interface SplitControl as AMControl;
    interface AMSend;
    interface Receive;
    interface AMPacket;
    interface Packet;
    interface PacketAcknowledgements as Acks;
    interface Random;
    interface Timer<TMilli> as RoundTimer;
    interface Timer<TMilli> as AdvTimer;
    interface Timer<TMilli> as JoinTimer;
    interface Timer<TMilli> as SchedTimer;
    interface Timer<TMilli> as SlotTimer;
    interface Timer<TMilli> as ChTimer;
    interface Timer<TMilli> as RetryTimer;
  }
}
implementation {
  message_t pkt;
  bool busy;
  double energy;
  bool dead;
  uint16_t round;
  uint32_t tRound;
  int32_t lastChRound;

  bool isCH;
  uint16_t myCH;
  double bestD;
  bool scheduled;
  uint8_t mySlot;

  uint16_t members[MAX_MEMBERS];
  uint8_t nMembers;
  uint32_t lastJoin;
  bool schedSent;
  bool schedArmed;
  uint16_t agg;
  uint8_t chPhase;

  /* emission en attente d'acquittement */
  bool pendingAck;
  uint16_t pendingDest;
  uint8_t pendingKind;
  uint8_t pendingLen;
  double pendingE;
  uint8_t retries;

  /* etat TEEN/APTEEN */
  uint8_t ht, st, ct;
  double lastSent;
  bool everSent;
  uint16_t lastTxRound;

  /* detection des doublons (retransmissions dont l'ACK a ete perdu) :
   * au plus un paquet de donnees par source et par round */
  uint16_t lastDataRound[NUM_SENSORS + 1];

  double now_s() { return sim_time() / (double)sim_ticks_per_sec(); }

  double dist(uint16_t a, uint16_t b) {
    double dx = POS_X[a] - POS_X[b];
    double dy = POS_Y[a] - POS_Y[b];
    return sqrt(dx * dx + dy * dy);
  }

  double etx(uint32_t bits, double d) {
    if (d < D0) return bits * E_ELEC + bits * E_FS * d * d;
    return bits * E_ELEC + bits * E_MP * d * d * d * d;
  }

  double erx(uint32_t bits) { return bits * E_ELEC; }

  task void stopAll() {
    call AdvTimer.stop();
    call JoinTimer.stop();
    call SchedTimer.stop();
    call SlotTimer.stop();
    call ChTimer.stop();
    call RetryTimer.stop();
    call AMControl.stop();
  }

  void spend(double e) {
    if (dead || TOS_NODE_ID == BS_ID) return;
    energy -= e;
    if (energy <= 0) {
      energy = 0;
      dead = TRUE;
      dbg("Apteen", "DEAD %u %u %.4f\n", round, TOS_NODE_ID, now_s());
      post stopAll();
    }
  }

  bool isCtrl(uint8_t kind) { return kind != K_DATA; }

  /* Taille utile : en-tete seul, sauf le TDMA qui porte la liste des membres */
  uint8_t msgLen(uint8_t kind, uint16_t count) {
    uint8_t hdr = sizeof(apteen_msg_t) - MAX_MEMBERS * sizeof(nx_uint16_t);
    return kind == K_SCHED ? hdr + count * sizeof(nx_uint16_t) : hdr;
  }

  /* Prepare l'en-tete et emet ; le contenu de ids[] est rempli par l'appelant. */
  error_t sendMsg(uint16_t dest, uint8_t kind, uint16_t count, double e, bool ack) {
    apteen_msg_t* m;
    if (dead || busy) return FAIL;
    m = (apteen_msg_t*)call Packet.getPayload(&pkt, sizeof(apteen_msg_t));
    m->kind = kind;
    m->round = round;
    m->count = count;
    m->ht = ht;
    m->st = st;
    m->ct = ct;
    if (ack) call Acks.requestAck(&pkt);
    else call Acks.noAck(&pkt);
    pendingLen = msgLen(kind, count);
    if (call AMSend.send(dest, &pkt, pendingLen) != SUCCESS) return FAIL;
    busy = TRUE;
    pendingAck = ack;
    pendingDest = dest;
    pendingKind = kind;
    pendingE = e;
    retries = 0;
    if (isCtrl(kind)) dbg("Apteen", "CTRL %u %u\n", round, kind);
    spend(e);
    return SUCCESS;
  }

  double sense() {
    double x = POS_X[TOS_NODE_ID];
    double y = POS_Y[TOS_NODE_ID];
    double noise = ((int32_t)(call Random.rand16() % 601) - 300) / 100.0;
    return 45.0 + 15.0 * sin(2.0 * M_PI * round / 100.0 + x / 40.0) * cos(y / 60.0) + noise;
  }

  bool shouldSend(double v) {
#if MODE == 2
    return TRUE;
#else
    if (v >= ht && (!everSent || fabs(v - lastSent) >= st)) return TRUE;
#if MODE == 0
    if (round - lastTxRound >= ct) return TRUE;
#endif
    return FALSE;
#endif
  }

  void markSent(double v) {
    lastSent = v;
    everSent = TRUE;
    lastTxRound = round;
  }

  event void Boot.booted() {
    busy = FALSE;
    energy = E_INIT;
    dead = FALSE;
    round = 0;
    lastChRound = -1000;
    myCH = NO_CH;
    ht = HT_DEFAULT;
    st = ST_DEFAULT;
    ct = CT_DEFAULT;
    everSent = FALSE;
    lastTxRound = 0;
    memset(lastDataRound, 0, sizeof(lastDataRound));
    call AMControl.start();
    call RoundTimer.startPeriodicAt(0, ROUND_MS);
  }

  event void AMControl.startDone(error_t err) {
    if (err != SUCCESS && !dead) call AMControl.start();
  }

  event void AMControl.stopDone(error_t err) {}

  event void RoundTimer.fired() {
    uint16_t epochStart;
    round++;
    if (TOS_NODE_ID == BS_ID) return;
    dbg("Energy", "E %u %u %.9f\n", round, TOS_NODE_ID, energy);
    if (dead) return;

    tRound = call RoundTimer.getNow();
    isCH = FALSE;
    myCH = NO_CH;
    bestD = 1e9;
    scheduled = FALSE;
    nMembers = 0;
    schedSent = FALSE;
    schedArmed = FALSE;
    agg = 0;
    lastJoin = tRound;

    /* Election LEACH : T(n) = p / (1 - p (r mod 1/p)) pour les noeuds de G */
    epochStart = round - ((round - 1) % EPOCH);
    if (lastChRound < epochStart) {
      double T = P_CH / (1.0 - P_CH * ((round - 1) % EPOCH));
      double rnd = (call Random.rand32() % 1000000) / 1000000.0;
      if (rnd < T) {
        isCH = TRUE;
        lastChRound = round;
      }
    }

    if (isCH) {
      dbg("Apteen", "CH %u %u\n", round, TOS_NODE_ID);
      call AdvTimer.startOneShotAt(tRound, call Random.rand16() % ADV_WIN);
      call SchedTimer.startPeriodicAt(tRound + SCHED_MIN - SCHED_POLL, SCHED_POLL);
      chPhase = 0;
      call ChTimer.startOneShotAt(tRound, STEADY_START);
    } else {
      call JoinTimer.startOneShotAt(tRound, JOIN_START + call Random.rand16() % JOIN_WIN);
      /* par defaut (aucun TDMA recu) : emission en CSMA pendant la periode de contention */
      call SlotTimer.startOneShotAt(tRound, STEADY_START + call Random.rand16() % (CP_MS - 20));
    }
  }

  event void AdvTimer.fired() {
    if (sendMsg(AM_BROADCAST_ADDR, K_ADV, 0, etx(CTRL_BITS, D_BCAST), FALSE) != SUCCESS)
      call AdvTimer.startOneShot(5);
  }

  event void JoinTimer.fired() {
    if (myCH == NO_CH) return;
    if (sendMsg(myCH, K_JOIN, 0, etx(CTRL_BITS, dist(TOS_NODE_ID, myCH)), TRUE) != SUCCESS)
      call JoinTimer.startOneShot(5 + call Random.rand16() % 20);
  }

  event void SchedTimer.fired() {
    uint32_t now = call SchedTimer.getNow();
    apteen_msg_t* m;
    uint8_t i;
    if (schedSent) { call SchedTimer.stop(); return; }
    if (!schedArmed) {
      if (now - lastJoin < SCHED_QUIET && now - tRound < SCHED_DEADLINE) return;
      /* gigue : evite que tous les CH diffusent leur TDMA au meme instant */
      schedArmed = TRUE;
      call SchedTimer.startOneShot(call Random.rand16() % SCHED_JITTER);
      return;
    }
    m = (apteen_msg_t*)call Packet.getPayload(&pkt, sizeof(apteen_msg_t));
    if (busy) { call SchedTimer.startOneShot(3); return; }
    for (i = 0; i < nMembers; i++) m->ids[i] = members[i];
    if (sendMsg(AM_BROADCAST_ADDR, K_SCHED, nMembers, etx(CTRL_BITS, D_BCAST), FALSE) == SUCCESS) {
      schedSent = TRUE;
      call SchedTimer.stop();
    }
  }

  /* Noeud membre : mesure et emission eventuelle.
   * GEN ... 1 = slot TDMA, 3 = membre sans slot (CSMA vers son CH),
   * 0 = orphelin sans CH (CSMA direct vers la BS). */
  event void SlotTimer.fired() {
    double v = sense();
    if (!shouldSend(v)) return;
    if (scheduled) {
      if (sendMsg(myCH, K_DATA, 1, etx(DATA_BITS, dist(TOS_NODE_ID, myCH)), FALSE) == SUCCESS) {
        markSent(v);
        dbg("Apteen", "GEN %u %u 1\n", round, TOS_NODE_ID);
      }
    } else if (myCH != NO_CH) {
      if (sendMsg(myCH, K_DATA, 1, etx(DATA_BITS, dist(TOS_NODE_ID, myCH)), TRUE) == SUCCESS) {
        markSent(v);
        dbg("Apteen", "GEN %u %u 3\n", round, TOS_NODE_ID);
      }
    } else {
      if (sendMsg(BS_ID, K_DATA, 1, etx(DATA_BITS, dist(TOS_NODE_ID, BS_ID)), TRUE) == SUCCESS) {
        markSent(v);
        dbg("Apteen", "GEN %u %u 0\n", round, TOS_NODE_ID);
      }
    }
  }

  /* Cluster head : phase 0 = sa propre mesure en debut de trame,
   *                phase 1 = envoi agrege a la BS en fin de trame. */
  event void ChTimer.fired() {
    if (chPhase == 0) {
      double v = sense();
      if (shouldSend(v)) {
        agg++;
        markSent(v);
        dbg("Apteen", "GEN %u %u 2\n", round, TOS_NODE_ID);
      }
      chPhase = 1;
      call ChTimer.startOneShotAt(tRound, STEADY_START + CP_MS + (nMembers + 1) * SLOT_MS);
    } else if (agg > 0) {
      double e = etx(DATA_BITS, dist(TOS_NODE_ID, BS_ID)) + E_DA * DATA_BITS * agg;
      if (sendMsg(BS_ID, K_DATA, agg, e, TRUE) != SUCCESS)
        call ChTimer.startOneShot(3);
    }
  }

  event void RetryTimer.fired() {
    if (dead) return;
    if (call AMSend.send(pendingDest, &pkt, pendingLen) == SUCCESS) {
      busy = TRUE;
      if (isCtrl(pendingKind)) dbg("Apteen", "CTRL %u %u\n", round, pendingKind);
      spend(pendingE);
    } else {
      call RetryTimer.startOneShot(5);
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    busy = FALSE;
    if (dead) return;
    if (pendingAck && !call Acks.wasAcked(msg) && retries < MAX_RETRY) {
      retries++;
      call Acks.requestAck(&pkt);
      call RetryTimer.startOneShot(5 + call Random.rand16() % 20);
      return;
    }
    if (pendingKind == K_SCHED)
      dbg("Apteen", "SETUP %u %u %.4f %u\n", round, TOS_NODE_ID,
          (call SchedTimer.getNow() - tRound) / 1024.0, nMembers);
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    apteen_msg_t* m = (apteen_msg_t*)payload;
    uint16_t src = call AMPacket.source(msg);
    uint8_t i;

    if (dead) return msg;
    if (TOS_NODE_ID == BS_ID) {
      if (m->kind == K_DATA && lastDataRound[src] != m->round) {
        lastDataRound[src] = m->round;
        dbg("Apteen", "RECV %u %u %u\n", m->round, src, m->count);
      }
      return msg;
    }
    if (m->round != round) return msg;

    switch (m->kind) {
      case K_ADV:
        spend(erx(CTRL_BITS));
        if (!isCH) {
          double d = dist(TOS_NODE_ID, src);
          if (d < bestD) { bestD = d; myCH = src; }
        }
        break;
      case K_JOIN:
        spend(erx(CTRL_BITS));
        if (isCH && !schedSent) {
          for (i = 0; i < nMembers; i++) if (members[i] == src) break;
          if (i == nMembers && nMembers < MAX_MEMBERS) members[nMembers++] = src;
          lastJoin = call RoundTimer.getNow();
        }
        break;
      case K_SCHED:
        spend(erx(CTRL_BITS));
        if (!isCH && src == myCH) {
          ht = m->ht; st = m->st; ct = m->ct;
          for (i = 0; i < m->count && i < MAX_MEMBERS; i++) {
            if (m->ids[i] == TOS_NODE_ID) {
              scheduled = TRUE;
              mySlot = i;
              call SlotTimer.startOneShotAt(tRound, STEADY_START + CP_MS + mySlot * SLOT_MS);
              break;
            }
          }
        }
        break;
      case K_DATA:
        if (isCH) {
          spend(erx(DATA_BITS));
          if (lastDataRound[src] != m->round) {
            lastDataRound[src] = m->round;
            agg += m->count;
          }
        }
        break;
    }
    return msg;
  }
}
