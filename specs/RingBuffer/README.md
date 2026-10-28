# RingBuffer model

[RingBuffer.tla](RingBuffer.tla) describes complete calls to [ringbuffer.zig](../../src/ringbuffer.zig).
[RingBufferConcurrent.tla](RingBufferConcurrent.tla) describes steps within concurrent read and write calls.
See [Concurrent.md](Concurrent.md) for FIFO, repeated delivery, and old data checks.
See [Liveness.md](Liveness.md) for delivery, space recovery, and call completion checks.
The model includes the read corrections from 2026-10-28.
A full buffer discards new writes.
One thread owns all writes. Write calls must not overlap.
Multiple readers can receive events. Each reader ID has one consuming thread.

## Technical terms

| Term | Meaning |
| --- | --- |
| Slot | One storage location in the buffer. |
| Capacity | The number of slots in the buffer. |
| Counter | A number that identifies the next read or write position. |
| Counter modulus | The maximum counter value plus one. |
| Counter wrap | A counter change from its maximum value to zero. |
| State | The values of all model variables at one step. |
| FIFO | First in, first out. Items leave in the order in which they entered. |

## Operations

The original model completes one method call before it starts another call.
The following sections describe that original model.

| Method | Model operation |
| --- | --- |
| `init` | Make empty slots. Set the writer counter to zero. Start with no readers. |
| `createReader` | Add a reader at the writer counter. Return a reader ID. The first ID is zero. |
| `read` with equal counters | Return `null`. Keep the reader counter unchanged. |
| `read` with different counters | Get the slot value. Increase the reader counter by one. Use counter wrap at the maximum value. |
| `write` with a full buffer | Discard the new value. Keep the slots and counters unchanged. |
| `write` with space available | Store the value. Increase the writer counter by one. Use counter wrap at the maximum value. |
| `deinit` | Stop further use of the buffer. |

The model calculates each reader's distance from the writer with wrapping subtraction.
A distance equal to or greater than capacity causes the writer to discard the new value.
With no readers, each write succeeds.

The `result` variable records the last operation.
A `ReadEmpty` result means that the read returned `null`.
An `Unwritten` value in a `Read` result identifies a read from an unwritten slot.
`Unwritten` is a model marker, not a Zig value.

## Safety checks

[RingBuffer.cfg](RingBuffer.cfg) selects these checks:

| Check | Required condition |
| --- | --- |
| `TypeOK` | All model variables have the correct types and permitted ranges. |
| `NoUninitializedRead` | A successful read returns a value from a slot that has received a write. |
| `NoReadOverflow` | Each reader counter stays in the permitted range. |
| `ReaderDistanceBound` | Each reader's distance from the writer is no greater than capacity. |

`TypeOK` also includes the counter range check.
The model uses counter wrap because the Zig code uses `+%`.
It no longer includes an arithmetic overflow trap.

The two other configuration files select separate checks:

- `RingBufferUninitializedRead.cfg` selects the check for reads from unwritten slots.
- `RingBufferReadOverflow.cfg` selects the reader counter range check.

## Conditions and limits

These conditions apply:

- Memory allocation succeeds.
- Reader IDs are valid.
- Reader creation and all other calls occur one at a time.
- Callers do not change the buffer fields directly.
- Callers do not use the buffer after `deinit`.
- Capacity is greater than zero and less than `CounterModulus`.
- Capacity and `CounterModulus` are powers of two.

The supplied configurations use capacity 2 and counter modulus 4.
The default configuration permits two readers and two data values.
The counter modulus represents `2^usize_bits`.

The results apply only to these model sizes and conditions.
Capacity 100 is outside the supported contract.
The separate capacity-3 model demonstrates why this restriction is necessary.

The original model does not include these checks:

- Concurrent calls or memory ordering between threads.
- Correct FIFO order, repeated delivery, or reads of old data.
- Allocation failure, invalid reader IDs, or use after `deinit`.
- Whether a permitted operation eventually occurs.

The model has no separate item IDs or expected FIFO history.
TLC does not do a deadlock check because `deinit` intentionally stops execution.

The Zig test named "multi-reader single-writer ... no overflow" starts multiple writers and creates no readers.
That test is outside the single-writer contract.

## Run the checks

1. Install Java and `tla2tools.jar`.
2. Open PowerShell in `specs/RingBuffer`.
3. Set `$tlaJar` to the location of your JAR file.
4. Run the three commands.

```powershell
$tlaJar = 'C:\path\to\tla2tools.jar'
java -cp $tlaJar tlc2.TLC -config RingBuffer.cfg RingBuffer.tla
java -cp $tlaJar tlc2.TLC -config RingBufferUninitializedRead.cfg RingBuffer.tla
java -cp $tlaJar tlc2.TLC -config RingBufferReadOverflow.cfg RingBuffer.tla
```

All three checks must complete without a property violation.
Old trace files can show failures from an earlier model.
Run the commands again to get current results.
Git ignores the generated TLC output and trace exploration files.

## Results from 2026-10-28

TLC version `2026.10.28.014557` completed all three configurations without a property violation.

| Configuration | Different states |
| --- | ---: |
| `RingBuffer.cfg` | 967 |
| `RingBufferUninitializedRead.cfg` | 61 |
| `RingBufferReadOverflow.cfg` | 61 |

These results apply to the original model.
The concurrent model has separate [results and limits](Concurrent.md).
