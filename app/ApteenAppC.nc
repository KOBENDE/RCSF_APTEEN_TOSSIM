#include "Apteen.h"

configuration ApteenAppC {}
implementation {
  components MainC, ApteenC, ActiveMessageC, RandomC;
  components new AMSenderC(AM_APTEEN);
  components new AMReceiverC(AM_APTEEN);
  components new TimerMilliC() as RoundTimer;
  components new TimerMilliC() as AdvTimer;
  components new TimerMilliC() as JoinTimer;
  components new TimerMilliC() as SchedTimer;
  components new TimerMilliC() as SlotTimer;
  components new TimerMilliC() as ChTimer;
  components new TimerMilliC() as RetryTimer;

  ApteenC.Boot -> MainC;
  ApteenC.AMControl -> ActiveMessageC;
  ApteenC.AMSend -> AMSenderC;
  ApteenC.Receive -> AMReceiverC;
  ApteenC.AMPacket -> AMSenderC;
  ApteenC.Packet -> AMSenderC;
  ApteenC.Acks -> AMSenderC;
  ApteenC.Random -> RandomC;
  ApteenC.RoundTimer -> RoundTimer;
  ApteenC.AdvTimer -> AdvTimer;
  ApteenC.JoinTimer -> JoinTimer;
  ApteenC.SchedTimer -> SchedTimer;
  ApteenC.SlotTimer -> SlotTimer;
  ApteenC.ChTimer -> ChTimer;
  ApteenC.RetryTimer -> RetryTimer;
}
