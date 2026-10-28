------------------------ MODULE RingBufferLiveness ------------------------
EXTENDS RingBufferConcurrent

CONSTANT PollingReaders
ASSUME /\ ThreadsPerReader = 1
       /\ SupportedCapacity
       /\ PollingReaders \subseteq Readers
       /\ MaxWrites > 0

(* Create all readers before concurrent use. Readers stay active. *)
LiveInit == s = [InitialState EXCEPT !.registered = ReaderCount]

(* Readers can poll without a call limit. The reads field stays zero.
   Successful reads remain bounded by the writes in each batch. *)
Poll(p) ==
    /\ s.rpc[p] = "Idle"
    /\ s' = [s EXCEPT !.rpc[p] = "Load", !.event = "StartRead"]

WriterStep(w) == LoadWriter(w) \/ ScanReader(w)
                 \/ StorePayload(w) \/ PublishWriter(w)
ReaderStep(p) == LoadReader(p) \/ CheckWriter(p)
                 \/ FetchPayload(p) \/ ReturnRead(p)
RequestWrite == \E w \in Writers, v \in Values : StartWrite(w, v)

(* Reuse test IDs only after all accepted items have been delivered.
   Empty reads can remain active because they hold no pending item.
   Keep the real counters and buffer unchanged, including counter wrap.
   This test boundary does not reinitialize the Zig buffer. *)
NextBatch ==
    /\ \A w \in Writers : s.wpc[w] = "Idle"
    /\ \A p \in Workers : s.rpc[p] \in {"Idle", "Load", "Check"}
    /\ s.writes = MaxWrites
    /\ \A r \in Readers : /\ s.expected[r] = Len(s.history) + 1
                           /\ s.readers[r] = s.writer
    /\ s' = [s EXCEPT !.writes = 0, !.history = <<>>,
                      !.expected = [r \in Readers |-> 1],
                      !.delivered = [r \in Readers |-> {}],
                      !.event = "NextBatch"]

LiveNext == \/ RequestWrite
            \/ \E w \in Writers : WriterStep(w)
            \/ \E p \in Workers : Poll(p) \/ ReaderStep(p)
            \/ NextBatch

LiveBehavior == LiveInit /\ [][LiveNext]_vars

(* Weak fairness means a continuously enabled action eventually occurs.
   Step fairness permits each started call to finish.
   Poll fairness represents a reader that continues to request reads. *)
FairSpec ==
    /\ LiveBehavior
    /\ WF_vars(RequestWrite)
    /\ \A w \in Writers : WF_vars(WriterStep(w))
    /\ \A p \in Workers : WF_vars(ReaderStep(p))
    /\ \A p \in PollingReaders : WF_vars(Poll(p))
    /\ WF_vars(NextBatch)

Needs(r, id) == \E i \in s.expected[r]..Len(s.history) : s.history[i].id = id

EventualDelivery ==
    \A r \in Readers, id \in 1..MaxWrites :
        Needs(r, id) ~> (id \in s.delivered[r])

SpaceAvailable ==
    \A r \in Readers :
        (s.writer - s.readers[r] + CounterModulus) % CounterModulus < Capacity

SpaceRecovery == (~SpaceAvailable) ~> SpaceAvailable

CallCompletion ==
    /\ \A w \in Writers : (s.wpc[w] # "Idle") ~> (s.wpc[w] = "Idle")
    /\ \A p \in Workers : (s.rpc[p] # "Idle") ~> (s.rpc[p] = "Idle")

(* This extra check prevents a passing result from only draining one batch. *)
ContinuedBatches == []<>(s.event = "NextBatch")
=============================================================================
