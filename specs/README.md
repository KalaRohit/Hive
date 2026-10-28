# What are specs

Creating low-effort/early prototypes of ideas modeled in TLA+ to verify that invariants hold,
and verify whether two different implementations are logically 1-1 if doing migrations.

## Ring buffer

[RingBuffer.tla](RingBuffer/RingBuffer.tla) models the serialized API behavior currently
implemented in `../src/ringbuffer.zig`. See [RingBuffer/README.md](RingBuffer/README.md) for
the source mapping, assumptions, TLC commands, and checked properties.

[RingBufferConcurrent.tla](RingBuffer/RingBufferConcurrent.tla) describes concurrent read and write calls.
It includes FIFO, repeated delivery, and old data checks.
See [Concurrent.md](RingBuffer/Concurrent.md) for the results and limits.

[RingBufferLiveness.tla](RingBuffer/RingBufferLiveness.tla) includes checks for eventual progress.
See [Liveness.md](RingBuffer/Liveness.md) for the required scheduling assumptions.

## UI layout

[Layouting](Layouting/README.md) models sizing, word wrapping, height calculation, and draw order.
It includes [pseudocode](Layouting/Pseudocode.md) and [Clay attribution](Layouting/NOTICE.md).
