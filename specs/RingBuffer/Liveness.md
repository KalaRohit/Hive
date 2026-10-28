# RingBuffer liveness checks

[RingBufferLiveness.tla](RingBufferLiveness.tla) uses the operations from the [concurrent model](RingBufferConcurrent.tla).
It permits continued operation and includes checks for eventual progress.

## Properties

| Property | Required result |
| --- | --- |
| `EventualDelivery` | Each reader eventually receives each accepted item intended for it. |
| `SpaceRecovery` | A full buffer eventually has space for another item. |
| `CallCompletion` | Each started read or write call eventually finishes. |
| `ContinuedBatches` | New test batches occur repeatedly throughout the run. |

Discarded writes do not require delivery.
An empty read counts as a completed call.
These properties set no limit on elapsed time or operation count.
They do not establish a real-time deadline or a wait-free implementation.

## Scheduling assumptions

The model uses weak fairness.
A continuously enabled action must eventually occur.

- Each active writer call eventually receives another operation step.
- Each active reader call eventually receives another operation step.
- Each reader listed in `PollingReaders` continues to request reads.
- The producer continues to request writes when the test permits them.
- Test bookkeeping eventually starts the next batch when the current batch is complete.

These assumptions describe the caller and scheduler.
They are not guarantees from the buffer.
Call completion needs operation-step fairness.
Delivery and space recovery also need continued polling from every reader.

A stopped reader can keep the buffer full under `DiscardWrite`.
The buffer does not remove that reader or overwrite its unread items.

## Continued operation

All readers exist before the first concurrent call.
One thread owns the writer. One consuming thread owns each reader ID.
Capacity and counter modulus must be powers of two.
Capacity must be smaller than the counter modulus.

Each batch permits two write attempts in the supplied configuration.
Attempts include discarded writes.
Readers can make unlimited read calls, including empty reads.
`MaxReads` is zero because this model does not use the safety model's read-call budget.

A batch ends only after all accepted items have reached all readers and the writer call has finished.
An empty read can remain active across this boundary.
The model then clears the test history and reuses test item IDs.
It keeps the actual buffer, reader counters, and writer counter unchanged.
This permits counter wrap and infinitely many batches in a finite state space.
It does not reinitialize the Zig buffer.

`ContinuedBatches` ensures that a passing run cannot stop after one batch.
The read and write operations do not assume the delivery properties.
TLC must establish those properties from the operations and scheduling assumptions.

## Results

TLC `2026.10.28.014557` completed the main configuration without a property violation.
It explored 9,071 different states.
The main configuration uses two slots, counter modulus 4, two readers, and one data value.
It includes all four temporal properties and the concurrent safety checks.

The diagnostic configurations remove one scheduling assumption:

| Configuration | Missing assumption | Expected failure |
| --- | --- | --- |
| `RingBufferLivenessStoppedReader.cfg` | Reader 2 can stop polling. | `EventualDelivery` |
| `RingBufferLivenessNoSpaceRecovery.cfg` | Reader 2 can stop polling. | `SpaceRecovery` |
| `RingBufferLivenessNoFairness.cfg` | The scheduler can stop an active call. | `CallCompletion` |

These failures show why the assumptions are necessary.
They are not failures under the supported scheduling conditions.

## Run

1. Open PowerShell in `specs/RingBuffer`.
2. Set `$tlaJar` to the location of `tla2tools.jar`.
3. Run the main configuration.

```powershell
java -Xmx1g -cp $tlaJar tlc2.TLC -config RingBufferLiveness.cfg RingBufferLiveness.tla
```

4. Run the diagnostic configurations separately.

```powershell
java -Xmx1g -cp $tlaJar tlc2.TLC -config RingBufferLivenessStoppedReader.cfg RingBufferLiveness.tla
java -Xmx1g -cp $tlaJar tlc2.TLC -config RingBufferLivenessNoSpaceRecovery.cfg RingBufferLiveness.tla
java -Xmx1g -cp $tlaJar tlc2.TLC -config RingBufferLivenessNoFairness.cfg RingBufferLiveness.tla
```

The diagnostic runs must report temporal property violations.
In VS Code, open `RingBufferLiveness.tla` before selecting a configuration.

## Limits

The result applies to the specified state sizes and repeated batch workload.
It does not prove progress for every buffer size or every possible writer workload.
Test IDs are reused only between drained batches.
The original bounded safety runs retain their separate item-history checks.
The model uses sequential consistency and indivisible item access.
It does not prove correctness under all hardware memory-ordering behavior.
Allocation failure, concurrent reader creation, and deinitialization are outside this model.
