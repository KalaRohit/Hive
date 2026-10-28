# Concurrent RingBuffer model

[RingBufferConcurrent.tla](RingBufferConcurrent.tla) describes steps inside read and write calls.
TLC can select a step from a different call after each step.
The model follows the current [Zig code](../../src/ringbuffer.zig).

## Supported use

One thread owns all writes. Write calls must not overlap.
Multiple readers can read concurrently with the writer.
Each reader ID belongs to one consuming thread.
The shared-reader configurations test use outside this contract.

Capacity must be a positive power of two, such as 2, 4, 8, or 128.
Capacity must be smaller than the counter modulus.
The counter modulus must also be a power of two, as for an unsigned Zig counter.
Thus, capacity divides the counter modulus without a remainder.
Slot order stays correct when the counter wraps.

`SupportedCapacity` states this requirement in the TLA+ model.
The normal configuration includes this check.
The capacity-3 configuration omits it to demonstrate the FIFO failure outside the supported contract.

An OS event bridge fits this contract when one thread publishes all events.
The model does not establish which threads call the OS event handlers.

## Operations

A writer loads its counter, reads each reader counter, stores the item, and stores its new counter.
A full buffer discards the write before the item store.

A reader loads its counter and then loads the writer counter.
Equal counters cause an empty read.
Otherwise, the reader gets the item before it stores its new counter.

Reader creation occurs only when all read and write calls have finished.
New readers start at the current writer counter.
The model can create readers before or after writes.
The concurrent model does not include deinitialization.

## Item checks

Each write call receives a unique test ID.
Two items can have the same value and different IDs.
The test IDs do not change the decisions in the Zig algorithm.

The model records successful writes when the writer stores its new counter.
This record defines the expected FIFO order.
Discarded writes do not enter this record.
Each reader starts with the first successful write after its creation.

| Check | Required condition |
| --- | --- |
| `FIFOOrder` | Each successful read returns the next expected item and its value. |
| `NoRepeatedDelivery` | One reader never receives the same item ID twice. |
| `NoOldData` | A returned item never precedes the next expected item in the write record. |
| `NoUninitializedRead` | Each returned item has received a write. |
| `TypeOK` | All model fields have permitted types and ranges. |
| `SupportedCapacity` | Capacity and counter modulus are powers of two. Capacity is smaller than the counter modulus. |

Different readers can receive the same item. This is permitted.
Repeated delivery means that the same reader receives that item again.
Old data includes items written before a reader was created.
These checks have some overlap, but each reports a separate condition.

## Results from 2026-10-28

TLC version `2026.10.28.014557` produced these results:

| Configuration | Calls and bounds | Result |
| --- | --- | --- |
| `RingBufferConcurrent.cfg` | One writer, two reader IDs, one thread per reader ID. Five write calls and ten read calls. | Pass: 1,017,500 different states. |
| `RingBufferSharedReader.cfg` | Two threads use one reader ID. One write call and two read calls. | Fail: `NoRepeatedDelivery`. The final state also violates `NoOldData` and `FIFOOrder`. |
| `RingBufferOldData.cfg` | The same shared reader case, with a separate old-data check. | Fail: `NoOldData`. |
| `RingBufferUnevenCapacity.cfg` | One writer and one reader. Capacity 3, counter modulus 4. Five write calls and five read calls. | Fail: `FIFOOrder`. |

The other configurations use capacity 2 and counter modulus 4.
All configurations use one data value. Unique test IDs keep separate items distinct.
The write and read limits include discarded writes and empty reads.

### One shared reader ID

Both calls can load the same reader counter before either call advances it.
Both calls can then return the same item.
The second return is repeated delivery and old data.
`RingBufferOldData.cfg` selects the old-data check separately.

### Capacity and counter wrap

With capacity 3, counter 3 selects slot zero.
After counter wrap, counter zero also selects slot zero.
A new write can replace an unread item.
The reader can then receive item 5 when it expects item 4.

The capacity-3 example uses a counter modulus of 4.
The counter values are 0, 1, 2, and 3.
The counter then wraps to zero.

The slot sequence is:

| Counter | Slot at capacity 3 | Slot at capacity 4 |
| ---: | ---: | ---: |
| 0 | 0 | 0 |
| 1 | 1 | 1 |
| 2 | 2 | 2 |
| 3 | 0 | 3 |
| 0 after wrap | 0 | 0 |

At capacity 3, counter 3 and the next counter value, 0, both select slot 0.
A new write can overwrite the unread item in that slot.
The capacity-3 model finds this FIFO error.

At capacity 4, the counter uses each slot once before it wraps.
Counter 3 selects slot 3. The next counter value, 0, selects slot 0.
The slot sequence stays in order across counter wrap.

This works because 4 divides the counter modulus, 4.
Capacity 3 does not divide the modulus, 4.
The real Zig counter has modulus `2^usize_bits`.
Capacity 100 does not divide that modulus.
The model uses modulus 4 to make counter wrap easy to reach.

## Limits

The model uses sequential consistency.
Each counter load sees the most recent store in the model's step order.
Each item load or store occurs in one step.
The model does not represent partial item access or weaker memory ordering.
These results do not prove that the Zig code has no data races.

Reader creation does not overlap other calls.
Memory allocation succeeds, and reader IDs are valid.
No operation occurs after memory release.
The bounded safety model does not include checks for eventual progress.
The separate [liveness model](Liveness.md) includes those checks with explicit scheduling assumptions.

The one-writer result applies to the stated call limits and model sizes.
It does not prove FIFO correctness for all executions or all capacities.
The concurrent FIFO check uses writer-counter stores as the publication order.
It does not search for every possible order of overlapping calls to prove linearizability.

## Run the checks

1. Open PowerShell in `specs/RingBuffer`.
2. Set `$tlaJar` to the location of `tla2tools.jar`.
3. Run the passing configuration.

```powershell
java -cp $tlaJar tlc2.TLC -config RingBufferConcurrent.cfg RingBufferConcurrent.tla
```

4. Run each failure configuration separately.

```powershell
java -cp $tlaJar tlc2.TLC -config RingBufferSharedReader.cfg RingBufferConcurrent.tla
java -cp $tlaJar tlc2.TLC -config RingBufferOldData.cfg RingBufferConcurrent.tla
java -cp $tlaJar tlc2.TLC -config RingBufferUnevenCapacity.cfg RingBufferConcurrent.tla
```

TLC stops at the first failed check.
The failure configurations intentionally produce counterexamples.
In VS Code, open `RingBufferConcurrent.tla` before selecting a non-default configuration.
