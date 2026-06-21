
		U-Boot boot loader for the ADLINK LEC-iMX6
		==========================================

Documentation Overview
----------------------
 - README_Yocto.txt describes the Yocto Linux distribution and how to build and
   install a cusomized one.
 - README_NetInst.txt is about the Debian installer, doubling as a
   diagnose/rescue system and available on every module via "run boot_rom".
 * README_U-Boot.txt (THIS FILE) goes into much more detail about the U-Boot
   bootloader than the previous two documents do.
 - README_Linux.txt describes the Linux kernel both Yocto and Debian are built
   on. For custom carriers the Device Tree and .config need adapting.
 - README_Cross.txt introduces the cross toolchain for building anything other
   than Yocto if you don't like compiling on the i.MX6 directly.

Introduction
------------
The LEC-iMX6 features an 8 MB primary and a 4 MB fail-safe SPI flash, the first
384 KB of each are hosting the U-Boot boot loader. Similar to the BIOS of a
conventional PC U-Boot initializes the hardware and then is responsible for
loading the operating system.

However U-Boot has no "BIOS Setup" menu, and in fact doesn't show anything on a
display (if present) at all, instead it provides a command line interface on the
first serial (RS232) port. This is quite powerful for its small size, it can
read/write most interfaces of the i.MX6 and even download files via Ethernet. It
also provides a simple scripting language with a set of environment variables,
which can be stored back in SPI flash and allow a customized configuration of
the board more potent than any "BIOS Setup".

U-Boot also launches a Linux kernel zImage or any uImage directly, no additional
'GRUB' or similar is needed. Consequently, to 'install' or clone a Linux
distribution all you need to do is unzip or copy all its files to a partition.

Compiling U-Boot
----------------
Normal users should never need to build (or customize) U-Boot, the LEC-iMX6
usually ships with the boot loader preinstalled. Just skip to the "Using
U-Boot" chapter.

To rebuild U-Boot yourself just copy all files to any Linux system:
build_uboot*.sh, uboot-imx-rel_imx_*.tar.xz and uboot_LEC-iMX6_*.tar.xz. Then
run build_uboot*.sh ("chmod a+x" if needed). Do not unpack the '*.tar.xz's.

The script will tell you in detail if you lack any tools needed (e.g. the
(cross) compiler) or if it can't find the source packages above. Just fix it and
re-run the script.

The result will be four U-Boot binaries lying in the current directory:
u-boot_LEC-iMX6q*.imx is for the Quad/Dual variants and u-boot_LEC-iMX6s*.imx
must be used on the Solo/DualLite. The '-1G' or '-2G' refers to the 1 GB or 2 GB
RAM option. Please double check to use the correct binary.

Customizing
-----------
On the first run the script will populate its working dir build_uboot*/. To
customize U-Boot just modify its contents and re-run the script. If the
directory already exists the script won't recreate it and only recompile
everything.

The most interesting files are the following: boards.cfg and
include/configs/lec-imx6*.h contain all variables configuring U-Boot to be built
fitting the LEC-iMX6, board/adlink/lec-imx6/lec-imx6*.c implement additional
code to initialize specific hardware and board/adlink/lec-imx6/DDR3_*.cfg
provides mainly timing values for the RAM controller.

Updating U-Boot
---------------
U-Boot can be run from a number of devices: on-module SPI, on-module eMMC,
LEC-Base SD slot (SMARC 'SDIO') or SATA, as selected by the SMARC signals
BOOT_SEL0-2#. (Note that these three signals on the other hand have no influence
on where U-Boot then continues to boot the OS from, which is defined by U-Boot's
environment variables instead.)

No matter what device U-Boot resides on it must be written to raw offset 0x400
and may extend up to 0x5DFFF (=375 KB max.) on this device. The variables are
always stored at offsets 0x5E000-5FFFF (=8 KB) in SPI flash unless explicitly
changed in the source code, because U-Boot was intended to be loaded from SPI.

Therefore we first describe the usual case of updating U-Boot in SPI flash:

(1) Copy u-boot_LEC-iMX6*.imx to a USB drive formatted with FAT/FAT32 or
ext2/3/4. It may be a thumb drive or some card in an USB card reader, whatever,
as long as it's not formatted with Windows' NTFS or exFAT. Use
u-boot_LEC-iMX6q*.imx for Quad/Dual CPUs, u-boot_LEC-iMX6s*.imx is for
Solo/DualLite. The '-1G' or '-2G' after the 'q'/'s' refers to the amount of RAM
populated on the board, 1 GB or 2 GB. With the wrong file the hardware doesn't
boot at all, it won't even respond on RS232, so please double check.

(2) Attach the drive to the i.MX6 board and enter the (old) U-Boot's RS232
command line (null-modem cable on port 1, 115200-8-N-1, see below).

(3) Locate u-boot_LEC-iMX6*.imx:

U-Boot> usb start

May sometimes issue warnings, especially with multi-card readers, but should
report a number of "Storage Devices found".

U-Boot> fatls usb 0:1 /
or
U-Boot> ext2ls usb 0:1 /

Use 'fatls' for FAT16/FAT32, 'ext2ls' for ext2/3/4. This should list the drive's
contents, including u-boot_LEC-iMX6*.imx. If it doesn't the 0:1 is likely wrong.
The number before the ':' is the USB drive number. '0' stands for the 1st USB
drive found, may need to be increased if several USB devices are attached.
Multi-Card readers often register several devices, try different numbers until
you find the right one: 0:1, 1:1, 2:1, ... The number after the colon is the
partition number. Increase to 2,3,4 if your USB drive has several partitions.

If you get a listing of your drive's contents you found the right numbers. We'll
assume "0:1" for now.

(4) Load u-boot_LEC-iMX6*.imx into RAM:

U-Boot> fatload usb 0:1 12000000 /u-boot_LEC-iMX6*.imx
or
U-Boot> ext2load usb 0:1 12000000 /u-boot_LEC-iMX6*.imx

Should return "2***** bytes read in *** ms (***.* KiB/s)". (Of course you may
address a subdirectory instead of just "/", or load the data from MMC, SATA,
Ethernet, ...) Never continue to step (5) unless the new U-Boot binary was
loaded correctly!

(5) Write from RAM into SPI flash:

U-Boot> sf probe
U-Boot> sf erase 0 60000; sf write 12000000 400 $filesize

Do type "$filesize" verbatim, 'filesize' is a U-Boot variable set by fatload or
ext2load.

This procedure overwrites only the currently active flash, i.e. usually the
primary one. As long as the 'fail-safe' flash contains a working
(factory-default) U-Boot it's probably best left alone.

Advanced installing
-------------------
As said above it's also possible to write U-Boot to a number of other devices
instead. Just replace step (5) above with one of the following, afterwards don't
forget to set SMARC BOOT_SEL*# accordingly. (Hint: The 1 KB gap before U-Boot
begins leaves enough space for a partition table, i.e. you can partition and use
eMMC, SD or SATA devices normally as long as you leave at least 376 KB unused
before the first partition begins.)

(5b) Write to on-module eMMC:

U-Boot> mmc dev 0
U-Boot> mmc write 12000000 2 2EE

(5c) Write to card in SD slot on ADLINK LEC-Base (=SMARC SDIO):

U-Boot> mmc dev 1
U-Boot> mmc write 12000000 2 2EE

(5d) Write to SATA drive:

U-Boot> dcache off; sata init
U-Boot> sata write 12000000 2 2EE

Alternatively updating/installing U-Boot can be achieved from within Linux; as
root do:

# dd bs=1k seek=1 if=/path/to/u-boot_LEC-iMX6*.imx of=/dev/target

Replace "target" with mmcblk0, mmcblk1 or sda for on-module eMMC, SD slot or
SATA drive respectively; the last two device names will of course be different
if you're writing U-Boot externally, e.g. on a host PC where you compiled your
own U-Boot.

Updating U-Boot in SPI flash from Linux would work in the same way (mtdblock0),
however you'd have to lift the write protection from within U-Boot first. But if
you're there anyway you can just perform the update directly as described above.

Another way to flash U-Boot to SPI is to connect an external SPI flasher (e.g.
DediProg SF100) to the service connector (CN2, "ADLINK DB40"). Again write the
image to offset 0x400.

Using U-Boot
------------
To access U-Boot's command line connect a host PC with a terminal program (e.g.
Minicom, Tera Term) set to 115200-8-N-1 (=115200 baud, 8 data bits, no parity, 1
stop bit) via a null-modem cable to the LEC-iMX6's RS232 port 1. Interrupt
automatic boot by pressing [Enter].

The variable "bootcmd" contains the command(s) to perform when U-Boot
auto-boots. The default content is "run boot_emmc", which means to execute the
commands which are stored in another variable, "boot_emmc". Suitable variables
for other boot devices are predefined. You can run their contents directly to
boot from a device just once, without changing the auto-boot device. (E.g. "run
boot_rom" launches the built-in Debian installer/rescue system once.) If you
installed Linux somewhere else you may change bootcmd to contain "run boot_sd",
"run boot_sdmmc", "run boot_usb", "run boot_sata" or "run boot_net" to auto-boot
it every time:

U-Boot> edit bootcmd
(change as appropriate)
U-Boot> save

"save" (or "saveenv" in full) writes all variable values to SPI flash, otherwise
changes you make will only persist until the next board reset. Sometimes the
boot_... variables themselves need editing, too. For example you may want to
boot from the third of several USB devices:

U-Boot> edit boot_usb
(change "usb 0:1" to "usb 2:1" and "sda1" to "sdc1")

This is often the case with USB multi-card readers, which get a device assigned
to every slot, and the one you're using may not be scanned first. In such cases
try "usb start" and then "ext2ls usb 0:1", "1:1", "2:1", ... to find the right
one. "usb 2:1" addresses the U-Boot device the Linux kernel and the DTB file are
loaded from into RAM. "sdc1" isn't actually used by U-Boot; it is passed as root
device parameter to Linux, together with the strings following it. It can often
be guessed correctly from U-Boot's device number, otherwise Linux boot will
stop, failing to mount root, and the correct name can be concluded from the
kernel messages.

Another example, if you made two partitions on the eMMC and wanted to boot from
the second, you could

U-Boot> edit boot_emmc
(change "mmc 0:1" to "mmc 0:2 and "mmcblk0p1" to "mmcblk0p2")

Or, alternatively, copy the contents of "boot_emmc" to a new boot_* variable of
your own to make it easier switching between the two:

U-Boot> set boot_emmc_p2 $boot_emmc
(annoyingly, the copy loses any ', " or \; do fix them in the next step)
U-Boot> edit boot_emmc_p2
(change the copy as before)
U-Boot> edit bootcmd
(run boot_emmc or boot_emmc_p2)

At the end don't forget to

U-Boot> save

More sophisticated scenarios are easily possible: For example edit bootcmd to
"run boot_emmc; run boot_usb" to first try one boot device, and on failure fall
through to the second. With "run boot_usb; boot" or "run boot_usb; reset" you
could force indefinite retries. You can run custom initializations before
booting, like "run our_i2c_init; run boot_emmc" (using some new variable to
store the desired i2c commands). And you can use 'if's to depend on some
arbitrary condition, e.g. if some device is present, some GPIO is set or some
network server responds. For example "if mmc dev 1; then BOOTARGS='mmcblk1p1
ro'; else BOOTARGS='mmcblk0p1 ro'; fi" might boot from eMMC normally, but switch
Linux' 'root' parameter to the SD slot if a card is present. Or "usb start;
LOAD='ext2load usb 0:1'; dcache off; if sata init; then BOOTARGS='sdb1 ro'; else
BOOTARGS='sda1 ro'; fi; run boot" can boot from USB, automatically compensating
for the fact that Linux's name for the 1st USB drive changes from sda to sdb
if a SATA disk is present.

Note that pulling the SMARC signal TEST# low overrides 'bootcmd' and runs
'boot_rom' to launch the built-in Debian installer/rescue system. Pulling SMARC
FORCE_RECOV# low loads all variables with their defaults and then runs
'boot_usb'. This behavior was implemented to comply with the SMARC specification
and can be changed in the U-Boot sources.

U-Boot> env default -fa

loads the (compiled in) default environment. You still need to "save" to make it
permanent.

U-Boot> pri

or, in full, "printenv" lists all environment variables. (Like, for example
'params', which contains additional command line parameters passed to the Linux
kernel and per default causes redirecting the Linux kernel's messages to the
first serial port.)

U-Boot> help

lists all available U-Boot commands, and "help some_command" gives details about
how a specific command is used. Note that almost all numeric parameters to
commands are interpreted as hex, even without a "0x" prefix. Unfortunately
U-Boot is often ambiguous here. We can't discuss all commands in detail, but
will attempt to highlight a few:

'mmc', 'sata', 'usb' and 'sf' allow detecting, reading and writing
(u)SD(HC)/(e)MMC cards/devices, SATA drives, USB storage devices (e.g. thumb
drives, card readers) and SPI flashes respectively. The commands cannot
interpret file system structures, they only read/write raw data from/to given
sectors or offsets. This means sector number 0 will target the device's
partition table, so be cautious. The parameter 'addr' always refers to the
memory (RAM) address the data is copied to/from. See the chapter "Advanced
installing" above for examples regarding 'mmc' and 'sata'. Do not use 'sf
erase/write/update' unless you know what you're doing! Offsets 0x400-5DFFF
contain U-Boot itself and must not be overwritten except when updating!

On the other hand 'fatls', 'fatload', 'ext2ls' and 'ext2load' are higher-level
commands, which do interpret FAT16/32 or ext2/3/4 file systems and allow reading
files (instead of raw sectors) into RAM. Writing is not supported. The first
parameter 'interface' can be 'mmc', 'sata' or 'usb', followed by
'device:partition', counting from 0:1. See 'Updating U-Boot' (3) and (4) above
for examples.

Similarly 'ls' and 'fsload' read files from a JFFS2 or cramfs found on the last
7808 KB of SPI flash (0x60000-7FFFFF) which aren't needed by U-Boot itself.
Usually a simple "ls" will reveal the Debian installer/rescue system.

All memory can be examined and modified with 'md', 'cmp', 'cp', 'mm', 'mw' and
'nm'. This can be files/data loaded into RAM (0x10000000-FFFFFFFF) or
memory-mapped I/O (0x0-FFFFFFF). Note that the ARM architecture does not allow
unaligned memory access, therefore a (32 bit) "md 10000001" will fail badly.

If you loaded a Flattened Device Tree Binary (*.dtb) file into RAM you can
decode and modify it with the 'fdt' command. As device trees are supposed to
describe the entire SoC and board hardware in detail, they can become quite
complex. If curious try "fsload $fdtaddr $fdtfile; fdt addr $fdtaddr; fdt
print". 'fdt' can be utilized for small changes e.g. disable a device for
testing.

Once a (Linux) kernel uImage or zImage has been loaded into RAM together with a
*.dtb file it can be launched with 'bootm' or 'bootz'. If trying to boot
something else than Linux the low-level 'go' might be useful.

'dhcp', 'ping', 'tftpboot' and 'nfs' auto-configure, test, and load files via
Ethernet. They set or use the environment variables 'ethaddr', 'ipaddr',
'netmask', 'gatewayip', 'dnsip', 'hostname', 'serverip' and 'rootpath'.

'i2c' and 'mdio'/'mii' allow communicating on the respective auxiliary busses.
With the aid of 'i2c' commands saved in an environment variable U-Boot might
send an initialization sequence for a custom carrier board before booting the
OS. Or, if you blundered during an update and are running U-Boot only from the
backup flash (blue LED blinking; enforceable via dip switch) the line

U-Boot> i2c dev 2; i2c mw 28 1F01.2 0; sf probe

switches back to the primary chip (8 MB size reported, blue LED stops blinking),
allowing you to restore U-Boot there.

U-Boot also implements a primitive Bourne shell-like syntax with
'if'/'elif'/'else'/'fi', 'while'/'until'/'for'/'do'/'done', 'test', 'expr',
'true', 'false', 'source', 'exit', '&&', '||' and '$?' to allow more complex
tasks. Strangely this adds a set of 'local' variables which are distinct from
all environment variables discussed above: they are set with "varname=value"
(' ' and ';' must be quoted) instead of "set varname value" (only ';' needs
quoting), they are listed with "showvar" instead of "printenv" and are always
volatile instead of being "save"d to SPI flash. Both are evaluated with $varname
or ${varname}, with environment vars taking priority over locals. We'd recommend
using capital letters for local vars to reduce confusion.

'echo', 'sleep', 'reset' and a few unmentioned commands are left as an exercise
to the reader.

Document History
----------------
2015-12-19 JR	With Thumb binary size is only 2***** now.
2015-08-17 JR	Add SATA detection as another 'if' example.
2015-06-15 JR	U-Boot version 4 no longer needs an 'if' for boot_sdmmc so we
		can no longer refer to it as an example. Also make note about
		switching back to primary chip a bit clearer.
2015-03-18 JR	Mention I2C command switching from backup to primary SPI flash.
2015-02-27 JR	Add Documentation Overview; mention boot_net; explain more
		sophisticated boot scenarios.
2015-01-27 JR	U-Boot version 3 (based on Freescale's "imx_3.10.53_1.1.0_GA")
		replaced 'itest' with 'expr'.
2014-11-24 JR	U-Boot version 2 introduced variants with 1 / 2 GB RAM and
		renamed the 'console' variable to 'params'; also minor
		clarifications.
2014-08-16 JR	Initial release written for version 1 (based on Freescale's
		U-Boot "imx_3.10.31_1.1.0_alpha").
