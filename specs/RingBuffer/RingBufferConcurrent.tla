---------------------- MODULE RingBufferConcurrent ----------------------
EXTENDS Integers, Sequences, FiniteSets

(* Each action represents one source operation. Payload access is indivisible.
   The model uses sequential consistency. See README.md for memory limits. *)
CONSTANTS Capacity, CounterModulus, ReaderCount,
          ThreadsPerReader, MaxWrites, MaxReads, Values

ASSUME /\ Capacity \in Nat \ {0}
       /\ CounterModulus \in Nat
       /\ CounterModulus > Capacity
       /\ ReaderCount \in Nat \ {0}
       /\ ThreadsPerReader \in Nat \ {0}
       /\ MaxWrites \in Nat
       /\ MaxReads \in Nat
       /\ IsFiniteSet(Values) /\ Values # {}

Readers == 1..ReaderCount
(* One thread owns all writes. Write calls cannot overlap. *)
Writers == {1}
Workers == 1..(ReaderCount * ThreadsPerReader)
Slots == 0..(Capacity - 1)
Counters == 0..(CounterModulus - 1)
(* Diagnostic models can omit this check to exercise unsupported capacities. *)
IsPowerOfTwo(n) == \E k \in 0..n : n = 2^k
SupportedCapacity == /\ IsPowerOfTwo(Capacity)
                     /\ IsPowerOfTwo(CounterModulus)
                     /\ Capacity < CounterModulus
ReaderOf(p) == ((p - 1) % ReaderCount) + 1
Empty == [id |-> 0, value |-> CHOOSE v \in Values : TRUE]
Items == [id : 0..MaxWrites, value : Values]

VARIABLE s
vars == <<s>>

InitialState == [
    buffer |-> [i \in Slots |-> Empty], writer |-> 0,
    readers |-> [r \in Readers |-> 0], registered |-> 0,
    wpc |-> [w \in Writers |-> "Idle"],
    wseq |-> [w \in Writers |-> 0],
    scan |-> [w \in Writers |-> 1],
    item |-> [w \in Writers |-> Empty],
    rpc |-> [p \in Workers |-> "Idle"],
    rseq |-> [p \in Workers |-> 0],
    observed |-> [p \in Workers |-> Empty],
    history |-> <<>>, expected |-> [r \in Readers |-> 1],
    delivered |-> [r \in Readers |-> {}],
    writes |-> 0, reads |-> 0,
    initializedOK |-> TRUE, fifoOK |-> TRUE,
    duplicateOK |-> TRUE, staleOK |-> TRUE,
    event |-> "Init"]

Init == s = InitialState

Idle == /\ \A w \in Writers : s.wpc[w] = "Idle"
        /\ \A p \in Workers : s.rpc[p] = "Idle"

(* Register readers only when all calls have finished. IDs remain fixed. *)
RegisterReader ==
    /\ Idle
    /\ s.registered < ReaderCount
    /\ LET r == s.registered + 1
       IN s' = [s EXCEPT !.registered = r,
                         !.readers[r] = s.writer,
                         !.expected[r] = Len(s.history) + 1,
                         !.event = "CreateReader"]

(* Assign a unique test ID to each write call, even for equal values. *)
StartWrite(w, v) ==
    /\ s.wpc[w] = "Idle"
    /\ s.writes < MaxWrites
    /\ s' = [s EXCEPT !.writes = @ + 1,
                      !.item[w] = [id |-> s.writes + 1, value |-> v],
                      !.wpc[w] = "Load", !.event = "StartWrite"]

LoadWriter(w) ==
    /\ s.wpc[w] = "Load"
    /\ s' = [s EXCEPT !.wseq[w] = s.writer, !.scan[w] = 1,
                      !.wpc[w] = "Scan", !.event = "LoadWriter"]

ScanReader(w) ==
    /\ s.wpc[w] = "Scan"
    /\ IF s.scan[w] > s.registered
          THEN s' = [s EXCEPT !.wpc[w] = "Store", !.event = "ScanDone"]
          ELSE IF (s.wseq[w] - s.readers[s.scan[w]] + CounterModulus)
                    % CounterModulus >= Capacity
               THEN s' = [s EXCEPT !.wpc[w] = "Idle", !.event = "DiscardWrite"]
               ELSE s' = [s EXCEPT !.scan[w] = @ + 1, !.event = "ScanReader"]

StorePayload(w) ==
    /\ s.wpc[w] = "Store"
    /\ s' = [s EXCEPT !.buffer[s.wseq[w] % Capacity] = s.item[w],
                      !.wpc[w] = "Publish", !.event = "StorePayload"]

(* History records successful writes at the writer counter store. *)
PublishWriter(w) ==
    /\ s.wpc[w] = "Publish"
    /\ s' = [s EXCEPT !.writer = (s.wseq[w] + 1) % CounterModulus,
                      !.history = Append(@, s.item[w]),
                      !.wpc[w] = "Idle", !.event = "PublishWriter"]

StartRead(p) ==
    /\ ReaderOf(p) <= s.registered
    /\ s.rpc[p] = "Idle"
    /\ s.reads < MaxReads
    /\ s' = [s EXCEPT !.reads = @ + 1, !.rpc[p] = "Load",
                      !.event = "StartRead"]

LoadReader(p) ==
    /\ s.rpc[p] = "Load"
    /\ s' = [s EXCEPT !.rseq[p] = s.readers[ReaderOf(p)],
                      !.rpc[p] = "Check", !.event = "LoadReader"]

CheckWriter(p) ==
    /\ s.rpc[p] = "Check"
    /\ IF s.rseq[p] = s.writer
          THEN s' = [s EXCEPT !.rpc[p] = "Idle", !.event = "ReadEmpty"]
          ELSE s' = [s EXCEPT !.rpc[p] = "Fetch", !.event = "ReadAvailable"]

FetchPayload(p) ==
    /\ s.rpc[p] = "Fetch"
    /\ s' = [s EXCEPT !.observed[p] = s.buffer[s.rseq[p] % Capacity],
                      !.rpc[p] = "Advance", !.event = "FetchPayload"]

(* Test data does not control source operations. It records violations.
   An old item precedes the next expected item in publication history.
   This includes items written before a reader was created. *)
ReturnRead(p) ==
    /\ s.rpc[p] = "Advance"
    /\ LET r == ReaderOf(p)
           got == s.observed[p]
           n == s.expected[r]
           correct == IF n <= Len(s.history) THEN got = s.history[n] ELSE FALSE
           old == \E i \in 1..(n - 1) :
                      IF i <= Len(s.history) THEN s.history[i].id = got.id ELSE FALSE
       IN s' = [s EXCEPT
           !.readers[r] = (s.rseq[p] + 1) % CounterModulus,
           !.rpc[p] = "Idle",
           !.initializedOK = @ /\ got.id # 0,
           !.fifoOK = @ /\ correct,
           !.duplicateOK = @ /\ got.id \notin s.delivered[r],
           !.staleOK = @ /\ ~old,
           !.delivered[r] = @ \cup {got.id},
           !.expected[r] = @ + 1,
           !.event = "ReturnRead"]

Next == \/ RegisterReader
        \/ \E w \in Writers, v \in Values : StartWrite(w, v)
        \/ \E w \in Writers : LoadWriter(w) \/ ScanReader(w)
                               \/ StorePayload(w) \/ PublishWriter(w)
        \/ \E p \in Workers : StartRead(p) \/ LoadReader(p)
                               \/ CheckWriter(p) \/ FetchPayload(p) \/ ReturnRead(p)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ s.buffer \in [Slots -> Items]
    /\ s.writer \in Counters
    /\ s.readers \in [Readers -> Counters]
    /\ s.registered \in 0..ReaderCount
    /\ s.wpc \in [Writers -> {"Idle", "Load", "Scan", "Store", "Publish"}]
    /\ s.wseq \in [Writers -> Counters]
    /\ s.scan \in [Writers -> 1..(ReaderCount + 1)]
    /\ s.item \in [Writers -> Items]
    /\ s.rpc \in [Workers -> {"Idle", "Load", "Check", "Fetch", "Advance"}]
    /\ s.rseq \in [Workers -> Counters]
    /\ s.observed \in [Workers -> Items]
    /\ s.history \in Seq(Items)
    /\ Len(s.history) <= MaxWrites
    /\ s.expected \in [Readers -> 1..(MaxWrites + MaxReads + 1)]
    /\ s.delivered \in [Readers -> SUBSET (0..MaxWrites)]
    /\ s.writes \in 0..MaxWrites
    /\ s.reads \in 0..MaxReads
    /\ s.initializedOK \in BOOLEAN /\ s.fifoOK \in BOOLEAN
    /\ s.duplicateOK \in BOOLEAN /\ s.staleOK \in BOOLEAN
    /\ s.event \in {"Init", "CreateReader", "StartWrite", "LoadWriter",
                     "ScanDone", "DiscardWrite", "ScanReader", "StorePayload",
                     "PublishWriter", "StartRead", "LoadReader", "ReadEmpty",
                     "ReadAvailable", "FetchPayload", "ReturnRead", "NextBatch"}

NoUninitializedRead == s.initializedOK
FIFOOrder == s.fifoOK
NoRepeatedDelivery == s.duplicateOK
NoOldData == s.staleOK
=============================================================================
