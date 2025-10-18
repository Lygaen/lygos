target remote localhost:1234
define hook-quit
    set confirm off
end
symbol-file zig-out/boot/kernel
br kernel._start
br kernel.panicHandler
c
