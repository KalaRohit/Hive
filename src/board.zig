const std = @import("std");

pub const PieceError = error{
    OutOfBounds,
};

pub const Piece = struct {
    one:   []Piece,
    two:   []Piece,
    three: []Piece,
    four:  []Piece,
    five:  []Piece,
    six:   []Piece,

    pub fn play_piece(self: *@This(), at: usize) PieceError!void {
        if (at > 5) return PieceError.OutOfBounds;
    }
};
