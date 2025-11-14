# Lygos
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://brainmade.org/white-logo.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://brainmade.org/black-logo.svg">
  <img align="right" width="128" height="40" alt="Brainmade mark". src="https://brainmade.org/black-logo.svg">
</picture>

![GitHub License](https://img.shields.io/github/license/Lygaen/lygos?style=for-the-badge)
![Zig](https://img.shields.io/badge/Zig-%23F7A41D.svg?style=for-the-badge&logo=zig&logoColor=white)

An `x86_64` OS made with ❤️ in Zig ! All my questions were answered by going through the useful [wiki.osdev.org](https://wiki.osdev.org/Expanded_Main_Page) or the [osdev.wiki](https://osdev.wiki/wiki/Expanded_Main_Page).

Note that this is simply a fun education project and should, in no way, be considered serious and used for any other things than research / education purposes.

## Run & Build
First of all, clone the repository :
```sh
git clone https://github.com/Lygaen/lygos
cd lygos
```

You can then **build the project**, generating an `.iso` file, **make sure to have [xorriso](https://www.gnu.org/software/xorriso/) on PATH** :
```sh
zig build
```

If you want to run the app on [QEMU](https://www.qemu.org/), **make sure to have `qemu-system-x86_64` on PATH** :
```sh
zig build run
```

If you want to debug the kernel with QEMU, run the following :
```sh
zig build run -Ddebug-qemu
```

Which will open a gdb-compatible server on port `1234`, which you can connect to using you favorite debugger.

If you are using GDB, you can use the provided `.gdbinit` file to automatically connect and set breakpoints :
```sh
gdb -x .gdbinit
```


## Tips
### Enable GDB auto-load
This is simply to be able to run `gdb` instead of `gdb -x .gdbinit`.

Once we're in the directory, *if you want to debug the project*, you must allow to run the `.gdbinit` provided by the project in the directory. Add the following line to your `gdbinit` config file :
```sh
add-auto-load-safe-path DIRECTORY_WHERE_CLONE/lygos
```

#### Where is my gdbinit file ?

The searched locations for `gdbinit` config file are the following :

* `$XDG_CONFIG_HOME/gdb/gdbinit` (Windows / Linux)
* `$HOME/.config/gdb/gdbinit` (Windows / Linux)
* `$HOME/Library/Preferences/gdb/gdbinit` (Mac Os)
* `$HOME/.gdbinit`

Simply creating a file statisfying one of the above locations for your platforms containing the said line will allow gdb to run the `.gdbinit` file.

If you installed the `gdbinit` config file correctly, all you must do is simply run `gdb` in an another instance / window :
```sh
gdb
```

## Bootloader
The library, for the time being, depends on [Limine](https://codeberg.org/Limine/Limine) for the bootloader of the OS. When time comes, I will replace Limine with my own bootloader, written in Zig as well.

However, to not waste time on this, I will simpy use limine as a bootloader, letting the framebuffers and such to it.
All of limine's logic is self-contained in `src/limine.zig`. The entrypoint is in `src/kernel.zig`.
