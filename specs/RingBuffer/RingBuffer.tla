---------------------------- MODULE RingBuffer ----------------------------
EXTENDS Integers, Sequences, FiniteSets

(* Serialized API model of ../../src/ringbuffer.zig as of 2026-10-28.
   Each action is one complete method call, not one atomic CPU instruction.
   See README.md for assumptions and checked properties. *)
CONSTANTS Capacity, CounterModulus, MaxReaders, Values, Unwritten

ASSUME /\ Capacity \in Nat \ {0}
       /\ CounterModulus \in Nat \ {0, 1}
       /\ Capacity < CounterModulus
       /\ MaxReaders \in Nat
       /\ IsFiniteSet(Values) /\ Values # {}
       /\ Unwritten \notin Values

Slots == 0..(Capacity - 1)
Counters == 0..(CounterModulus - 1)

(* This bounded exponent search also permits finite TLC evaluation. *)
IsPowerOfTwo(n) == \E k \in 0..n : n = 2^k
SupportedCapacity == /\ IsPowerOfTwo(Capacity)
                     /\ IsPowerOfTwo(CounterModulus)
                     /\ Capacity < CounterModulus

VARIABLES container, writer, readers, status, result
vars == <<container, writer, readers, status, result>>

Event(kind, id, value) == [kind |-> kind, id |-> id, value |-> value]

(* Successful init: allocated memory is uninitialized, not zero-filled.
   Unwritten is a diagnostic marker, not a possible Zig value of T. *)
Init == /\ container = [s \in Slots |-> Unwritten]
        /\ writer = 0
        /\ readers = <<>>
        /\ status = "Live"
        /\ result = Event("Init", 0, Unwritten)

(* TLA+ sequences are 1-based; public reader IDs remain 0-based. *)
ReaderIDs == 0..(Len(readers) - 1)
Distance(r) == (writer - readers[r + 1] + CounterModulus) % CounterModulus
SlowReaderExists == \E r \in ReaderIDs : Distance(r) >= Capacity

CreateReader ==
    /\ status = "Live"
    /\ Len(readers) < MaxReaders
    /\ readers' = Append(readers, writer)
    /\ result' = Event("CreateReader", Len(readers), Unwritten)
    /\ UNCHANGED <<container, writer, status>>

Read(r) ==
    /\ status = "Live"
    /\ r \in ReaderIDs
    /\ readers[r + 1] # writer
    /\ result' = Event("Read", r, container[readers[r + 1] % Capacity])
    /\ readers' = [readers EXCEPT ![r + 1] = (@ + 1) % CounterModulus]
    /\ UNCHANGED <<container, writer, status>>

(* Returning null does not advance the reader. ReadEmpty distinguishes null
   from an actual payload or an uninitialized-memory diagnostic. *)
ReadEmpty(r) ==
    /\ status = "Live"
    /\ r \in ReaderIDs
    /\ readers[r + 1] = writer
    /\ result' = Event("ReadEmpty", r, Unwritten)
    /\ UNCHANGED <<container, writer, readers, status>>

Write(v) ==
    /\ status = "Live"
    /\ v \in Values
    /\ IF SlowReaderExists
          THEN /\ result' = Event("DiscardWrite", 0, v)
               /\ UNCHANGED <<container, writer>>
          ELSE /\ container' = [container EXCEPT ![writer % Capacity] = v]
               /\ writer' = (writer + 1) % CounterModulus
               /\ result' = Event("Write", 0, v)
    /\ UNCHANGED <<readers, status>>

(* Full buffers discard the incoming write without changing any cursor.
   No readers means SlowReaderExists is FALSE and every write succeeds. *)

Deinit ==
    /\ status = "Live"
    /\ status' = "Deinitialized"
    /\ result' = Event("Deinit", 0, Unwritten)
    /\ UNCHANGED <<container, writer, readers>>

Next == \/ CreateReader
        \/ \E r \in ReaderIDs : Read(r) \/ ReadEmpty(r)
        \/ \E v \in Values : Write(v)
        \/ Deinit

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ container \in [Slots -> Values \cup {Unwritten}]
    /\ writer \in Counters
    /\ readers \in Seq(Counters)
    /\ Len(readers) <= MaxReaders
    /\ status \in {"Live", "Deinitialized"}
    /\ result \in [kind : {"Init", "CreateReader", "Read", "ReadEmpty",
                           "Write", "DiscardWrite", "Deinit"},
                   id : 0..MaxReaders, value : Values \cup {Unwritten}]

(* Regression checks. NoReadOverflow now checks the numeric range;
   the source's wrapping addition no longer has a checked-overflow trap. *)
NoUninitializedRead == result.kind = "Read" => result.value # Unwritten
NoReadOverflow == readers \in Seq(Counters)
ReaderDistanceBound == \A r \in ReaderIDs : Distance(r) <= Capacity
=============================================================================
