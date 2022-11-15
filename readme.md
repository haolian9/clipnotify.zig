
zig port of https://github.com/cdown/clipnotify's `clipnotify -l -s clipboard`

## options
* -1: once or keep watching; default `false`
* -s: which selection: clipboard, primary, secondary; default `clipboard`

## build
* linux: libX11, libxfixes
* zig 0.10
* `zig build -Drelease-safe`
