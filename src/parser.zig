const std = @import("std");
const lex = @import("lexer.zig");
const Lexer = lex.Lexer;
const LexToken = lex.Token;

const Allocator = std.mem.Allocator;

const Label = []const u8;

const Constant = u16;
const Reference = struct {
    symbol: Label,
    indirect: bool,
};
const RefOrConst = union(enum) {
    reference: Reference,
    constant: Constant,
};

const OrgDirective = struct {
    location: Constant,
};

const Instruction = union(enum) {
    insn_and: RefOrConst,
    insn_add: RefOrConst,
    insn_lda: RefOrConst,
    insn_sta: RefOrConst,
    insn_bun: RefOrConst,
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
    keyword_dat: RefOrConst,
    keyword_org: Constant,
    unimpl,
};

const Line = struct {
    label: ?Label,
    instruction: Instruction,
};

pub const Parser = struct {
    lexer: *Lexer,
    _next_tok: LexToken,

    const Self = @This();

    const Error = error {
        UnexpectedToken,
        InvalidToken,
        Unimplemented,
        EOF,
    };

    fn peekTok(self: *Self) LexToken {
        return self._next_tok;
    }

    fn nextTok(self: *Self) LexToken {
        // these two lines run in the opposite order, nice
        defer self._next_tok = self.lexer.next();
        return self._next_tok;
    }

    fn exactTok(self: *Self, tag: LexToken.Tag) !void {
        if (self.nextTok().tag != tag)
            return Error.UnexpectedToken;
    }

    pub fn init(lexer: *Lexer) Self {
        return Self {
            .lexer = lexer,
            ._next_tok = lexer.next(),
        };
    }

    fn parseLabel(self: *Self) !Label {
        if (self.peekTok().tag == .label) {
            const tok = self.nextTok();
            return self.lexer.buffer[tok.loc.start..tok.loc.end - 1];
        }
        return Error.UnexpectedToken;
    }

    fn parseIdentifier(self: *Self) !Label {
        if (self.peekTok().tag != .identifier)
            return Error.UnexpectedToken;
        return self.lexer.getSlice(&self.nextTok());
    }

    fn parseIndirectRef(self: *Self) !Reference {
        if (self.peekTok().tag != .l_bracket)
            return Error.UnexpectedToken;
        self.exactTok(.l_bracket) catch unreachable;
        const res = Reference {
            .symbol = try self.parseIdentifier(),
            .indirect = true,
        };
        try self.exactTok(.r_bracket);
        return res;
    }

    fn parseReference(self: *Self) !Reference {
        switch (self.peekTok().tag) {
            .l_bracket => {
                return try self.parseIndirectRef();
            },
            .identifier => {
                return Reference {
                    .symbol = try self.parseIdentifier(),
                    .indirect = false,
                };
            },
            else => {
                return Error.UnexpectedToken;
            }
        }
    }

    fn parseConstant(self: *Self) !Constant {
        if (self.peekTok().tag == .number)
            return std.fmt.parseInt(Constant, self.lexer.getSlice(&self.nextTok()), 0);
        return Error.UnexpectedToken;
    }

    fn parseRefOrConst(self: *Self) !RefOrConst {
        switch (self.peekTok().tag) {
            .number => {
                return RefOrConst {
                    .constant = try self.parseConstant(),
                };
            },
            .l_bracket, .identifier => {
                return RefOrConst {
                    .reference = try self.parseReference(),
                };
            },
            else => { return Error.UnexpectedToken; },
        }
    }

    fn parseInstruction(self: *Self) !Instruction {
        if (self.peekTok().isDirective()) {
            return switch (self.nextTok().tag) {
                .keyword_dat => Instruction {
                    .keyword_dat = try self.parseRefOrConst(),
                },
                else => .unimpl,
            };
        }
        return Error.UnexpectedToken;
    }

    fn parseLine(self: *Self) !Line {
        if (self.peekTok().tag == .eof)
            return Error.EOF;
        if (self.peekTok().tag == .invalid)
            return Error.InvalidToken;
        return Line {
            .label = self.parseLabel() catch null,
            .instruction = try self.parseInstruction(),
        };
    }

    pub fn parse(self: *Self, allocator: *Allocator) !void {
        //var list = std.ArrayList(Line).initCapacity(30);
        _ = allocator;
        while (self.parseLine()) |line| {
            std.log.debug("Label: {s}, Instruction: {s}\n", .{ line.label, @tagName(line.instruction) });
        } else |err| {
            std.log.debug("Completed due to {s}\n", .{ @errorName(err) });
            if (err != Error.EOF)
                return err;
        }
    }

};

test "parser - token peeking" {
    var lexer = Lexer.init("label: directive");
    var parser = Parser.init(&lexer);
    try std.testing.expectEqual(LexToken.Tag.label, parser.peekTok().tag);
    try std.testing.expectEqual(LexToken.Tag.label, parser.nextTok().tag);
    try std.testing.expectEqual(LexToken.Tag.identifier, parser.nextTok().tag);
    try std.testing.expectEqual(LexToken.Tag.eof, parser.peekTok().tag);
}

test "parser - parse simple" {
    var lexer = Lexer.init("label: dat 0x1234\ndat [label]\n");
    var parser = Parser.init(&lexer);
    try parser.parse(std.testing.allocator);
}
