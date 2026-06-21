# i.MX6 Direct Linux Launcher

This starter kit builds a minimal launcher for i.MX6 boards that boots Linux
without full U-Boot.

Boot flow:

1. i.MX6 ROM reads the i.MX boot image.
2. ROM executes the DCD table to initialize DDR.
3. ROM copies the bundled image into DDR.
4. ROM jumps to the launcher entry point.
5. The launcher enters the embedded Linux zImage with the required ARM boot
   registers.

This design keeps the ROM happy while removing the full U-Boot stage.

## What This Kit Contains

- `src/start.S`: ARMv7 launcher stub.
- `linker.ld`: fixed memory layout for launcher and zImage.
- `Makefile`: converts `zImage` into an ELF section, links the
  launcher, then wraps the result as an i.MX boot image.
- `imximage.cfg.example`: template showing where to reuse the board's current
  DCD settings.

## Required Inputs

Bring these files from your offline build machine:

- A working `zImage` for your board.
- The exact i.MX6 DCD config used by the board's current `u-boot.imx`.
- The `mkimage` tool from a U-Boot build.
- An ARM cross toolchain.

This starter assumes your `zImage` is already self-contained with appended DTB
and built-in initramfs/rootfs, matching the path you already validated in
U-Boot with `bootz 0x12000000`.

The launcher now also builds a minimal ATAG list in low RAM and passes its
address in `r2`, because that more closely matches old U-Boot `bootz` behavior
when no external FDT argument is provided.

Do not invent a new DCD first. Copy the board's existing DDR initialization from
the current boot image source tree.

## Default Memory Layout

The defaults in this kit assume:

- DDR base: `0x10000000`
- DDR size: `0x20000000`
- ROM image load base: `0x12000000`
- 4 KiB reserved before the launcher for IVT/DCD/header space
- Launcher entry: `0x12001000`

That layout is chosen so:

- The embedded `zImage` remains in the first 128 MiB of RAM.

## Directory Layout Expected By The Makefile

Place your board files here:

- `images/zImage`
- `images/imximage.cfg`

The build outputs go into `build/`.

## Build Steps

1. Copy `imximage.cfg.example` to `images/imximage.cfg`.
2. Replace the placeholder DCD lines with the exact DCD settings from the board
   that already boots.
3. Put your validated `zImage` in `images/`.
4. Adjust the addresses in `Makefile` if the defaults do not match your board.
5. Run `make`.

For debug isolation, you can also build phase-specific images:

- `IMMEDIATE_HANG=1`: branch to `hang` immediately after reset entry.
- `COPY_ZIMAGE_TO_RUNTIME=1`: copy the embedded `zImage` to
  `KERNEL_RUNTIME_ADDR` before jumping. Use this when U-Boot already proved the
  same `zImage` boots from a known RAM address.

Expected outputs:

- `build/direct-linux.elf`
- `build/direct-linux.bin`
- `build/linux-direct.imx`

For U-Boot `go` testing, do not use the ROM-wrapped image as your first proof.
Build a headerless launcher by setting `HEADER_RESERVE=0`, load
`build/direct-linux.bin` to the same address as `IMAGE_LOAD_BASE`, and run `go`
to that exact address. Keep the nonzero header reserve only for the final ROM
boot image path.

## First Bring-Up Sequence

Use this exact sequence to isolate failures.

### Step 1: Prove ROM -> launcher

Build with `IMMEDIATE_HANG=1` so the launcher loops forever before touching the
DTB or kernel. If your board has a UART register map you trust, you can add a
single byte write for visible proof.

Example:

```sh
make clean
make IMAGE_LOAD_BASE=0x177fb020 HEADER_RESERVE=0x4fe0 IMMEDIATE_HANG=1
```

Result you want:

- The board no longer reaches U-Boot.
- The board consistently reaches the launcher.

### Step 2: Jump into zImage

Rebuild with `IMMEDIATE_HANG=0` so the launcher disables MMU/cache state,
passes `r0 = 0`, `r1 = 0xffffffff`, `r2 = ATAGS_ADDR`, and branches into the
embedded `zImage`.

If you are validating from U-Boot first, use a headerless build like this:

```sh
make clean
make IMAGE_LOAD_BASE=0x14000000 HEADER_RESERVE=0 KERNEL_RUNTIME_ADDR=0x12000000 COPY_ZIMAGE_TO_RUNTIME=1 RAM_BASE=0x10000000 RAM_SIZE=0x20000000
```

Then load `build/direct-linux.bin` to `0x14000000` and run `go 0x14000000`.

Result you want:

- Kernel decompressor banner or early kernel output on the serial console.

If U-Boot already boots the same `zImage` from `0x12000000`, prefer this build
first:

```sh
make clean
make \
  IMAGE_LOAD_BASE=0x177fb020 \
  HEADER_RESERVE=0x4fe0 \
  COPY_ZIMAGE_TO_RUNTIME=1 \
  KERNEL_RUNTIME_ADDR=0x12000000
```

That path makes the launcher copy the kernel to the same runtime address that
already works under U-Boot, then jump with `r2 = 0`.

### Step 3: Boot root filesystem

Keep bootargs, appended DTB, and the built-in rootfs in the `zImage`, matching
the successful U-Boot validation path.

## How To Choose Addresses

There are two addresses that matter.

### 1. `IMAGE_LOAD_BASE`

This is where the ROM will place the boot image in DDR. Keep it:

- inside DDR
- above the area used by the kernel decompressor as much as practical
- below the first 128 MiB from RAM start if you want to execute zImage in place

`0x12000000` is usually a reasonable starting point on boards with DDR at
`0x10000000`.

### 2. `ENTRY_ADDR`

This must point to the launcher start, not the zImage start.

The linker script reserves `0x1000` bytes for the i.MX header area, so the
default is:

- `ENTRY_ADDR = IMAGE_LOAD_BASE + 0x1000`

### 3. `KERNEL_RUNTIME_ADDR`

If `COPY_ZIMAGE_TO_RUNTIME=1`, the launcher copies the embedded `zImage` here
before jumping. Set this to the same address that U-Boot already proved works,
which for your validation path is `0x12000000`.

### 4. `RAM_BASE` and `RAM_SIZE`

The launcher builds a minimal ATAG list with one memory bank. Set these to the
same DDR base and size your working U-Boot passes to Linux. If you are unsure,
use the values from `bdinfo` in U-Boot.

## Linux Entry Conditions This Launcher Satisfies

Before branching to the zImage, the launcher:

- disables IRQ and FIQ
- clears MMU enable
- clears data cache enable
- clears instruction cache enable
- sets `r0 = 0`
- sets `r1 = 0xffffffff` for DT-only boot
- builds a minimal ATAG list and passes its address in `r2`

If your kernel still expects a legacy machine ID instead of DT-only boot,
replace `MACHINE_TYPE` in the Makefile with the correct `MACH_TYPE_*` value.

## Getting The DCD

Use the exact DCD or plugin-equivalent source that already boots your hardware.

Typical places in a U-Boot tree are board-specific i.MX image config files such
as:

- `board/<vendor>/<board>/imximage.cfg`
- `board/<vendor>/<board>/mx6*.cfg`

If your current image uses plugin mode instead of DCD mode, keep that in mind.
This starter kit assumes the simpler DCD path first.

## If The Board Uses HAB Secure Boot

If secure boot fuses are closed, this direct image must be signed exactly like a
normal i.MX boot image. In that case, first prove the concept on an open board.

## Common Failure Modes

### No boot at all

- Wrong image placement on SD/eMMC.
- Wrong IVT offset in `imximage.cfg`.
- Wrong DCD values.
- Wrong `ENTRY_ADDR`.

### Launcher runs but Linux does not start

- Wrong `KERNEL_RUNTIME_ADDR` when using `COPY_ZIMAGE_TO_RUNTIME=1`.
- Wrong `RAM_BASE` or `RAM_SIZE` in the generated ATAG list.
- Appended DTB path works in U-Boot but still depends on boot data in `r2`.
- Bootargs missing or wrong rootfs path.
- Kernel not built as `zImage`.

### Kernel starts but crashes early

- Wrong clocks or DRAM timing still dependent on U-Boot side effects.
- A peripheral DMA engine is active too early.
- Incorrect machine type for a non-DT-only kernel.

## Suggested Debug Method

When you first try this on hardware, change only one variable at a time in this
order:

1. Boot image formatting.
2. DDR DCD.
3. Launcher entry address.
4. DTB relocation address.
5. Kernel bootargs.

That order minimizes guesswork.

## Next Optimization Step

Once this works, the next speed optimization is usually not more bootloader
removal. It is kernel-side work:

- reduce driver probe cost
- build in only required subsystems
- quiet long timeout paths
- optimize root filesystem mount path

The launch stage is usually only one part of total boot time.