const std = @import("std");

pub fn build(b: *std.Build) void {
    var disabled_features = std.Target.Cpu.Feature.Set.empty;
    var enabled_features = std.Target.Cpu.Feature.Set.empty;

    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.mmx));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse2));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx2));
    enabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.soft_float));

    const kernel_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .ofmt = .elf,
        .cpu_features_add = enabled_features,
        .cpu_features_sub = disabled_features,
    });
    const optimize = b.standardOptimizeOption(.{});

    { // Kernel
        const kernel_mod = b.createModule(.{
            .root_source_file = b.path("src/kernel.zig"),
            .target = kernel_target,
            .optimize = optimize,

            .code_model = .kernel,
            .red_zone = false,
            .stack_check = false,
            .stack_protector = false,
            .pic = false,
            .link_libc = false,
        });

        const kernel_exe = b.addExecutable(.{
            .name = "kernel",
            .root_module = kernel_mod,
            .use_llvm = true,
            .use_lld = true,
            .linkage = .static,
        });
        kernel_exe.setLinkerScript(b.path("src/kernel.ld"));

        kernel_exe.link_z_max_page_size = 0x1000;
        kernel_exe.link_gc_sections = true;
        kernel_exe.lto = .none;
        kernel_exe.link_function_sections = true;
        kernel_exe.link_data_sections = true;

        genIso(b, kernel_exe);
    }

    qemuStep(b);
}

fn genIso(b: *std.Build, kernel_exe: *std.Build.Step.Compile) void {
    const limine = b.dependency("limine", .{});

    // Install needed files in /boot/ directory
    const limine_conf = b.addInstallFile(b.path("./limine.conf"), "./boot/limine/limine.conf");
    var i_step = &limine_conf.step;

    i_step.dependOn(&b.addInstallArtifact(kernel_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = "./boot/",
            },
        },
    }).step);

    i_step.dependOn(&b.addInstallFile(limine.path("limine-bios.sys"), "./boot/limine/limine-bios.sys").step);

    const limine_bios_cd = b.addInstallFile(limine.path("limine-bios-cd.bin"), "./boot/limine/limine-bios-cd.bin");
    i_step.dependOn(&limine_bios_cd.step);

    const limine_uefi_cd = b.addInstallFile(limine.path("limine-uefi-cd.bin"), "./boot/limine/limine-uefi-cd.bin");
    i_step.dependOn(&limine_uefi_cd.step);

    i_step.dependOn(&b.addInstallFile(limine.path("BOOTX64.EFI"), "./EFI/BOOT/BOOTX64.EFI").step);
    i_step.dependOn(&b.addInstallFile(limine.path("BOOTIA32.EFI"), "./EFI/BOOT/BOOTIA32.EFI").step);

    var xorriso_step: *std.Build.Step = undefined;
    {
        const xorriso_cmd = b.addSystemCommand(&.{
            "xorriso",
            "-report_about",
            "WARNING",
            "-as",
            "mkisofs",
            "-R",
            "-r",
            "-J",
            "-b",
            "boot/limine/limine-bios-cd.bin",
            "-no-emul-boot",
            "-boot-load-size",
            "4",
            "-boot-info-table",
            "-hfsplus",
            "-apm-block-size",
            "2048",
            "-m",
            "*.iso",
            "--efi-boot",
            "boot/limine/limine-uefi-cd.bin",
            "-efi-boot-part",
            "--efi-boot-image",
            "--protective-msdos-label",
        });

        xorriso_cmd.addDirectoryArg(.{
            .cwd_relative = b.install_prefix,
        });

        xorriso_cmd.addArgs(&.{
            "-o",
            b.pathJoin(&.{ b.install_prefix, "kernel.iso" }),
        });
        xorriso_cmd.step.dependOn(i_step);
        xorriso_step = &xorriso_cmd.step;
    }

    {
        const limine_mod = b.addModule("limine", .{
            .target = b.graph.host,
            .link_libc = true,
        });
        limine_mod.addCSourceFile(.{
            .file = limine.path("limine.c"),
        });

        const limine_exe = b.addExecutable(.{
            .name = "limine",
            .root_module = limine_mod,
        });

        const limine_run = b.addRunArtifact(limine_exe);
        limine_run.addArgs(&.{ "bios-install", b.pathJoin(&.{ b.install_prefix, "kernel.iso" }) });
        limine_run.step.dependOn(xorriso_step);

        b.getInstallStep().dependOn(&limine_run.step);
    }
}

fn qemuStep(b: *std.Build) void {
    const OVMF_dep = b.dependency("ovmf", .{});
    const ovmf_file = OVMF_dep.path("ovmf-code-x86_64.fd");

    const qemu_run = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-M",
        "q35",
        "-serial", // COM1 bound for logging
        "mon:stdio",
        "-drive",
    });

    qemu_run.addPrefixedFileArg("if=pflash,readonly=on,unit=0,format=raw,file=", ovmf_file);
    qemu_run.addArgs(&.{
        "-cdrom",
        b.pathJoin(&.{ b.install_prefix, "kernel.iso" }),
    });

    if (b.option(bool, "debug-qemu", "Enable debugging for qemu using -s -S") orelse false) {
        qemu_run.addArgs(&.{ "-s", "-S" });
    }

    qemu_run.step.dependOn(b.getInstallStep());
    const qemu_step = b.step("qemu", "Run the kernel via QEMU");
    qemu_step.dependOn(&qemu_run.step);
}
