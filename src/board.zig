const std = @import("std");
const BoardPiece = @import("pieces.zig");

pub const PieceError = error{
    OutOfBounds,
};

pub const Piece = struct {
    one:   [6]Piece,
    two:   [6]Piece,
    three: [6]Piece,
    four:  [6]Piece,
    five:  [6]Piece,
    six:   [6]Piece,

    pub fn playPiece(
        self: *@This(), 
        at: usize,
        piece: BoardPiece.PieceType
    ) PieceError!void {
        _ = self;
        _ = at;
    }
};
