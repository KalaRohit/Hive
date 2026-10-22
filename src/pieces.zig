const std = @import("std");

pub const PieceType = enum(usize) {
    QUEEN = 0,
    SPIDER,
    BEETLE,
    GRASSHOPPER,
    ANT
    // TODO:: Expansion pieces maybe...
};

pub const PieceCount = [_]u32{ 1, 2, 2, 3, 3 };

test "piece counts are correct" {
    try std.testing.expectEqual(1, PieceCount[@intFromEnum(PieceType.QUEEN)]);
    try std.testing.expectEqual(2, PieceCount[@intFromEnum(PieceType.SPIDER)]);
    try std.testing.expectEqual(2, PieceCount[@intFromEnum(PieceType.BEETLE)]);
    try std.testing.expectEqual(3, PieceCount[@intFromEnum(PieceType.GRASSHOPPER)]);
    try std.testing.expectEqual(3, PieceCount[@intFromEnum(PieceType.ANT)]);
}
