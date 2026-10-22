const std = @import("std");
const Board = @import("board.zig");
const PieceNamespace = @import("pieces.zig");

pub const Player = enum { WHITE, BLACK };

current_player: Player = .WHITE,
root_piece: Board.Piece,
