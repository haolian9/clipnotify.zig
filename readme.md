
zig port of https://github.com/cdown/clipnotify

## options
* -1: once or keep watching; default `false`
* -s: which selection: clipboard, primary, secondary; default `clipboard`

## build
* linux: libX11, libxfixes
* zig 0.12
* `zig build -Doptimize=ReleaseSafe`

## refs
* https://tronche.com/gui/x/xlib/events/types.html
