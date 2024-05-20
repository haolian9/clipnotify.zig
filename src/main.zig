const std = @import("std");
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/extensions/Xfixes.h");
});
const assert = std.debug.assert;
const log = std.log;
const posix = std.posix;

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
    if (terminated) posix.exit(1);
    terminated = true;
}

fn nextEvent(disp: *c.Display, e: *c.XEvent) bool {
    if (terminated) return false;

    assert(c.XNextEvent(disp, e) == 0);
    // see /usr/include/X11/X.h
    // it just happened to be 87, assert and let it crash!
    assert(e.type == 87);
    return true;
}

pub fn main() !u8 {
    const args = parseArgs() catch |err| {
        log.err("{s}", .{@errorName(err)});
        return 1;
    };

    try posix.sigaction(posix.SIG.INT, &.{
        .handler = .{ .handler = handleSIGINT },
        .mask = posix.empty_sigset,
        .flags = 0,
    }, null);

    const disp = c.XOpenDisplay(null).?;
    defer assert(c.XCloseDisplay(disp) == 0);

    {
        const root = c.DefaultRootWindow(disp);
        const sel = switch (args.sel) {
            .clipboard => c.XInternAtom(disp, "CLIPBOARD", 0),
            .primary => c.XA_PRIMARY,
            .secondary => c.XA_SECONDARY,
        };
        c.XFixesSelectSelectionInput(disp, root, sel, c.XFixesSetSelectionOwnerNotifyMask);
    }

    var e: c.XEvent = undefined;

    if (args.once) {
        _ = nextEvent(disp, &e);
    } else {
        const stdout = std.io.getStdOut();
        while (nextEvent(disp, &e)) try stdout.writeAll("\n");
    }

    return 0;
}
