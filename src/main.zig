const std = @import("std");
const clap = @import("clap");
const Lexer = @import("lexer.zig").Lexer;

const debug = std.debug;
const io = std.io;

pub fn main() anyerror!void {
    const params = comptime [_]clap.Param(clap.Help) {
        clap.parseParam("-h, --help             Display help and exit.          ") catch unreachable,
        clap.parseParam("-o, --output <FILE>    The file to write the output to.") catch unreachable,
        clap.parseParam("<FILE>                 The file to assemble.") catch unreachable,
    };
    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();

    //const allocator = &arena.allocator;

    var diag = clap.Diagnostic{};
    var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag }) catch |err| {
        // Report useful error and exit
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer args.deinit();

    //const input_name = for (args.positionals()) |pos| break pos else unreachable;
    //const output_name = if (args.option("--output")) |o| o else "out";

    //const input_file = try std.fs.cwd().openFile(input_name, .{ .read = true });
    //defer input_file.close();

    //const output_file = try std.fs.cwd().openFile(output_name, .{ .write = true });
    //defer output_file.close();

    //var input_reader = input_file.reader();
    //const buffer = try input_reader.readAllAlloc(allocator, std.math.maxInt(usize));

    const source = @embedFile("../test.asm");

    var lexer = Lexer.init(source);

    while (true) {
        const tok = lexer.next();
        lexer.dump(&tok);
        if (tok.tag == .invalid or tok.tag == .eof)
            break;
    }

    //debug.warn("OUTFILE: {s}\n", .{output_name});

    //std.log.info("All your codebase are belong to us.", .{});
}
