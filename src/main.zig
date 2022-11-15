const std = @import("std");
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/extensions/Xfixes.h");
});
const assert = std.debug.assert;
const log = std.log;
const linux = std.os.linux;

const Args = struct {
    once: bool,
    sel: Sel,
    const Sel = enum { clipboard, primary, secondary };
};

const ArgErr = error{
    UnknownSelection,
    MissingSelection,
    UnknownArg,
};

fn parseArgs() ArgErr!Args {
    var once: bool = false;
    var sel: Args.Sel = .clipboard;
    var iter = std.process.ArgIteratorPosix.init();
    assert(iter.skip());
    while (iter.next()) |a| {
        if (std.mem.eql(u8, a, "-1")) {
            once = true;
        } else if (std.mem.eql(u8, a, "-s")) {
            if (iter.next()) |s| {
                sel = switch (s[0]) {
                    'c' => .clipboard,
                    'p' => .primary,
                    's' => .secondary,
                    else => return ArgErr.UnknownSelection,
                };
            } else return ArgErr.MissingSelection;
        } else return ArgErr.UnknownArg;
    }
    return Args{ .once = once, .sel = sel };
}

var terminated = false;
fn handleSIGINT(_: c_int) callconv(.C) void {
    if (terminated) linux.exit(1);
    terminated = true;
}

pub fn main() !u8 {
    const disp = c.XOpenDisplay(null).?;
    defer assert(c.XCloseDisplay(disp) == 0);

    const args = parseArgs() catch |err| {
        log.err("{s}", .{@errorName(err)});
        return 1;
    };

    const root = c.DefaultRootWindow(disp);
    const sel = switch (args.sel) {
        .clipboard => c.XInternAtom(disp, "CLIPBOARD", 0),
        .primary => c.XA_PRIMARY,
        .secondary => c.XA_SECONDARY,
    };
    c.XFixesSelectSelectionInput(disp, root, sel, c.XFixesSetSelectionOwnerNotifyMask);

    var e: c.XEvent = undefined;

    const stdout = std.io.getStdOut();
    if (args.once) {
        const next_rc = c.XNextEvent(disp, &e);
        log.debug("next_rc={d}; event={any}", .{ next_rc, e });
        try stdout.writeAll("\n");
        return 0;
    }

    try std.os.sigaction(linux.SIG.INT, &.{
        .handler = .{ .handler = handleSIGINT },
        .mask = linux.empty_sigset,
        .flags = 0,
    }, null);

    while (!terminated) {
        assert(c.XNextEvent(disp, &e) == 0);
        // todo: ensure got the right event
        // switch (e) {
        //     .xselectionclear => log.debug("e: xselectionclear", .{}),
        //     .xselectionrequest => log.debug("e: xselectionclear", .{}),
        //     .xselection => log.debug("e: xselectionclear", .{}),
        //     else => |ee| log.debug("e: {any}", .{ee}),
        // }
        try stdout.writeAll("\n");
    }
    return 0;
}