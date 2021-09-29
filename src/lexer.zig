// portions of this file were taken from/influenced by Zig's lexer
// which is licenced under the MIT license (Copyright (c) 2015-2021, Zig contributors)
// https://github.com/ziglang/zig/blob/master/lib/std/zig/tokenizer.zig
const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.ComptimeStringMap(Tag, .{
        .{ "and", .insn_and },
        .{ "add", .insn_add },
        .{ "lda", .insn_lda },
        .{ "sta", .insn_sta },
        .{ "bun", .insn_bun },
        .{ "bsa", .insn_bsa },
        .{ "isz", .insn_isz },
        .{ "cla", .insn_cla },
        .{ "cle", .insn_cle },
        .{ "cma", .insn_cma },
        .{ "cme", .insn_cme },
        .{ "cir", .insn_cir },
        .{ "cil", .insn_cil },
        .{ "inc", .insn_inc },
        .{ "spa", .insn_spa },
        .{ "sna", .insn_sna },
        .{ "sza", .insn_sza },
        .{ "sze", .insn_sze },
        .{ "hlt", .insn_hlt },
        .{ "inp", .insn_inp },
        .{ "out", .insn_out },
        .{ "ski", .insn_ski },
        .{ "sko", .insn_sko },
        .{ "ion", .insn_ion },
        .{ "iof", .insn_iof },
        .{ "org", .keyword_org },
        .{ "dat", .keyword_dat },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        invalid,
        identifier,
        label,
        l_bracket,
        r_bracket,
        number,
        eof,
        insn_and,
        insn_add,
        insn_lda,
        insn_sta,
        insn_bun,
        insn_bsa,
        insn_isz,
        insn_cla,
        insn_cle,
        insn_cma,
        insn_cme,
        insn_cir,
        insn_cil,
        insn_inc,
        insn_spa,
        insn_sna,
        insn_sza,
        insn_sze,
        insn_hlt,
        insn_inp,
        insn_out,
        insn_ski,
        insn_sko,
        insn_ion,
        insn_iof,
        keyword_dat,
        keyword_org,

        pub fn isDirective(self: *@This()) bool {
            return switch (self.*) {
                .invalid, .identifier, .label, .l_bracket, .r_bracket, .number, .eof => false,
                else => true,
            };
        }
    };

    pub fn isDirective(self: *@This()) bool {
        return self.tag.isDirective();
    }

};

pub const Lexer = struct {
    buffer: [:0]const u8,
    index: usize,

    const Self = @This();

    pub fn dump(self: *Self, token: *const Token) void {
        std.debug.warn("{s} \"{s}\"\n", .{ @tagName(token.tag), self.buffer[token.loc.start..token.loc.end] });
    }

    pub fn init(buffer: [:0]const u8) Self {
        return Lexer {
            .buffer = buffer,
            .index = 0,
        };
    }

    pub fn getSlice(self: *const Self, token: *const Token) []const u8 {
        return self.buffer[token.loc.start..token.loc.end];
    }

    const State = enum {
        start,
        identifier,
        num_maybe_neg,
        num_zero,
        num_maybe_bin,
        num_bin,
        num_maybe_hex,
        num_hex,
        num_oct,
        num_dec,
        comment,
    };

    pub fn next(self: *Self) Token {
        // start at the begining
        var state: State = .start;
        // default result
        var result = Token {
            .tag = .eof,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };
        // keep looping until the state machine decides we're done and breaks
        while (true) : (self.index += 1) {
            // the character we're looking at
            const c = self.buffer[self.index];
            // switch on the current state
            switch (state) {
                // and then switch on the char for each state
                .start => switch (c) {
                    0 => break, // end of file
                    ' ', '\n', '\t', '\r' => {
                        result.loc.start += 1; // move past whitespace
                    },
                    '-' => {
                        state = .num_maybe_neg;
                    },
                    '0' => {
                        state = .num_zero;
                    },
                    '1'...'9' => {
                        state = .num_dec;
                    },
                    'a'...'z', 'A'...'Z' => {
                        // no idea if this is an identifier, an instruction,
                        // a keyword, or a label at this point.
                        state = .identifier;
                    },
                    '[' => {
                        result.tag = .l_bracket;
                        self.index += 1; // not sure why we'd do this here...
                        break;
                    },
                    ']' => {
                        result.tag = .r_bracket;
                        self.index += 1;
                        break;
                    },
                    ';' => {
                        state = .comment;
                    },
                    else => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        self.index += 1;
                        return result;
                    },
                },
                .num_maybe_neg => switch (c) {
                    '0' => {
                        state = .num_zero;
                    },
                    '1'...'9' => {
                        state = .num_dec;
                    },
                    else => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        return result;
                    },
                },
                .num_zero => switch (c) {
                    '0'...'7' => {
                        state = .num_oct;
                    },
                    'b' => {
                        state = .num_maybe_bin;
                    },
                    'x' => {
                        state = .num_maybe_hex;
                    },
                    '8'...'9', 'a', 'c'...'w', 'y'...'z', 'A'...'Z', '_' => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        return result;
                    },
                    else => {
                        result.tag = .number;
                        break;
                    },
                },
                .num_oct => switch (c) {
                    '0'...'7' => {}, // continue
                    '8'...'9', 'a'...'z', 'A'...'Z', '_' => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        return result;
                    },
                    else => {
                        result.tag = .number;
                        break;
                    },
                },
                .num_maybe_bin => switch (c) {
                    '0', '1' => {
                        state = .num_bin;
                    },
                    else => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        return result;
                    }
                },
                .num_bin => switch (c) {
                    '0', '1' => {}, // continue
                    '2'...'9', 'a'...'z', 'A'...'Z', '_' => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        return result;
                    },
                    else => {
                        result.tag = .number;
                        break;
                    },
                },
                .num_maybe_hex => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        state = .num_hex;
                    },
                    else => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        return result;
                    }
                },
                .num_hex => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {}, // continue
                    'g'...'z', 'G'...'Z', '_' => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        return result;
                    },
                    else => {
                        result.tag = .number;
                        break;
                    },
                },
                .num_dec => switch (c) {
                    '0'...'9' => {}, // continue
                    'a'...'z', 'A'...'Z', '_' => {
                        result.tag = .invalid;
                        result.loc.end = self.index;
                        return result;
                    },
                    else => {
                        result.tag = .number;
                        break;
                    },
                },
                .identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '0'...'9', '_' => {},
                    ':' => {
                        result.tag = .label;
                        self.index += 1;
                        break;
                    },
                    else => {
                        if (Token.getKeyword(self.buffer[result.loc.start..self.index])) |ident| {
                            result.tag = ident;
                        } else {
                            result.tag = .identifier;
                        }
                        break;
                    },
                },
                .comment => switch (c) {
                    '\n' => {
                        result.loc.start = self.index + 1;
                        state = .start;
                    },
                    else => {},
                },
            }
        }

        if (result.tag == .eof) {
            result.loc.start = self.index;
        }

        result.loc.end = self.index;
        return result;
    }
};

test "lexer - label" {
    try testLex("label1: ident", &.{.label, .identifier});
}

test "lexer - numbers" {
    try testLex("-i", &.{ .invalid, .identifier });
    try testLex("0xx", &.{ .invalid, .identifier });
    try testLex("0b12", &.{ .invalid, .number });
    try testLex("08", &.{ .invalid, .number });
    try testLex("-", &.{ .invalid });
    try testLex("0x", &.{ .invalid });
    try testLex("0b", &.{ .invalid });
    try testLex("0", &.{ .number });
}

test "lexer - keywords" {
    try testLex("dat guy", &.{ .keyword_dat, .identifier });
}

// taken verbatim from the Zig standard library source
fn testLex(source: [:0]const u8, expected_tokens: []const Token.Tag) !void {
    var lexer = Lexer.init(source);
    for (expected_tokens) |expected_token_id| {
        const token = lexer.next();
        if (token.tag != expected_token_id) {
            std.debug.panic("expected {s}, found {s}\n", .{
                @tagName(expected_token_id), @tagName(token.tag),
            });
        }
    }
    const last_token = lexer.next();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
}
