const std = @import("std");

pub const StrategyOnOverflow = enum {
    DiscardWrite,
};

/// Create a fixed size RingBuffer type. The buffer is
/// allocated on the heap once on init.
///
/// 0 -> [ 0, 0, 0, 0 ] -> jump to 0
///
///           ^ writer
///
///        ^ reader
pub fn RingBuffer(T: type, comptime size: usize) type {
    comptime {
        if (size == 0)              @compileError("RingBuffer requires size to be > 0, however, we got 0");
        if (size & (size - 1) != 0) @compileError("RingBuffer requires a power of 2 to prevent incorrect wrapping");
    }
    return struct {
        container:        []T,
        readers:          std.ArrayList(std.atomic.Value(usize)) = .empty,
        writer:           std.atomic.Value(usize)                = .init(0),
        overflowStrategy: StrategyOnOverflow                     = .DiscardWrite,
        capacity:         usize                                  = size,

        /// We want to prevent stack overflows on large ring buffers,
        /// which is why we are allocating on the heap, however, if
        /// @sizeOf is sufficiently small, maybe we retain in stack?
        pub fn init(allocator: std.mem.Allocator) !@This() {
            return @This(){
                .container = try allocator.alloc(T, size),
            };
        }

        /// Returns a usize which you can use with
        /// read() to read back values and increment
        /// reader pointers.
        ///
        /// Note that general access of container should
        /// be entirely avoided, as that is not an
        /// intended way for reading data.
        pub fn createReader(self: *@This(), allocator: std.mem.Allocator,) !usize {
            const rVal = self.readers.items.len;
            // We start at where the writer currently is...
            try self.readers.append(allocator, std.atomic.Value(usize).init(
                self.writer.load(.acquire),
            ));

            return rVal;
        }

        /// Read into the buffer, returning null if we are advancing past the writer.
        pub fn read(self: *@This(), sequence: usize) ?T {
            const seqItem   = self.readers.items[sequence].load(.acquire);

            if (seqItem == self.writer.load(.acquire)) {
                return null;
            }
            const value = self.container[seqItem % self.container.len];
            self.readers.items[sequence].store(seqItem +% 1, .release);

            return value;
        }


        pub fn write(self: *@This(), val: T) void {
            const writeVal:      usize = self.writer.load(.acquire);
            const writePosition: usize = writeVal % self.container.len;

            for (self.readers.items) | *reader | {
                // Case of a slow reader...
                if (writeVal -% reader.load(.acquire) >= self.container.len) {
                    switch (self.overflowStrategy) {
                        .DiscardWrite    => return,
                    }
                }
            }

            self.container[writePosition] = val;
            self.writer.store(writeVal +% 1, .release);
        }

        /// Free the container, as we all as invalidate the readers and writers
        /// for the RingBuffer.
        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.readers.deinit(allocator);
            allocator.free(self.container);
        }
    };
}

test "RingBuffer: sample usage" {
    var buff: RingBuffer(f32, 128) = try .init(std.testing.allocator);
    defer buff.deinit(std.testing.allocator);


    const i = try buff.createReader(std.testing.allocator);
    buff.write(120);

    const value = buff.read(i);

    try std.testing.expectEqual(120, value);

    const j = try buff.createReader(std.testing.allocator);
    buff.write(133);
    const jValue = buff.read(j);
    try std.testing.expect(jValue == 133);
}

test "RingBuffer: readers do not read uninit values" {
    var buff: RingBuffer(f32, 128) = try .init(std.testing.allocator);
    defer buff.deinit(std.testing.allocator);

    const i = try buff.createReader(std.testing.allocator);
    const value = buff.read(i);

    try std.testing.expectEqual(null, value);
}   

test "RingBuffer: fill buffer" {
    var buff: RingBuffer(f32, 128) = try .init(std.testing.allocator);
    defer buff.deinit(std.testing.allocator);

    const readerValue = try buff.createReader(std.testing.allocator);

    for (0..buff.capacity) |idx| {
        buff.write(@floatFromInt(idx));
    }

    for (0..buff.capacity) |idx| {
        const value = buff.read(readerValue);
        try std.testing.expectEqual(@as(f32, @floatFromInt(idx)), value);
    }
}

test "RingBuffer: multi-reader single-writer read in order no overflow" {
    const allocator: std.mem.Allocator = std.testing.allocator;
    var threaded: std.Io.Threaded      = .init(allocator, .{});
    defer threaded.deinit();

    const io = threaded.io();

    var buff: RingBuffer(f32, 128) = try .init(std.testing.allocator);
    defer buff.deinit(std.testing.allocator);

    var group = std.Io.Group.init;

    for (0..5) |taskId| {
        try group.concurrent(io, dummyReadFn, .{ taskId, &buff });
    }
    try group.await(io);
}

fn dummyReadFn(threadId: usize, buffer: *RingBuffer(f32, 128)) void {
    for (1..5) |idx| {
        buffer.write(
            @floatFromInt(20 * threadId + idx)
        );
    }
}

test "RingBuffer: multi-reader single-writer read in order overflow" {

}
