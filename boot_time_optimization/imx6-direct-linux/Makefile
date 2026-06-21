#CROSS_COMPILE ?= arm-linux-gnueabihf-
export CROSS_COMPILE=/media/bsp/13313ca3-5e12-437a-858a-ab8400dd8066/imx6/ARM_CorssCompiler/gcc-linaro-arm-linux-gnueabihf-4.9-2014.07_linux/bin/arm-linux-gnueabihf-
#MKIMAGE ?= mkimage
export MKIMAGE=/media/bsp/13313ca3-5e12-437a-858a-ab8400dd8066/imx6/fast_boot/build_uboot_8/tools/mkimage


export CROSS_COMPILE
export MKIMAGE

DEBUG_UART_BASE ?= 0
DEBUG_UART ?= 0
SKIP_DCACHE_CLEAN ?= 0
PL310_BASE ?= 0x00a02000
DISABLE_PL310 ?= 1
RAM_BASE ?= 0x10000000
RAM_SIZE ?= 0x80000000
ENTRY_ADDR ?= 0x12000000
KERNEL_RUNTIME_ADDR ?= 0x12000000
MACHINE_TYPE ?= 0x00000f8c
IMMEDIATE_HANG ?= 0
COPY_ZIMAGE_TO_RUNTIME ?= 0

CC := $(CROSS_COMPILE)gcc
LD := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy

IMAGES_DIR := images
BUILD_DIR := build
LINKER_SCRIPT := $(BUILD_DIR)/linker.ld

CPPFLAGS := \
	-DDEBUG_UART_BASE=$(DEBUG_UART_BASE) \
	-DDEBUG_UART=$(DEBUG_UART) \
	-DSKIP_DCACHE_CLEAN=$(SKIP_DCACHE_CLEAN) \
	-DPL310_BASE=$(PL310_BASE) \
	-DDISABLE_PL310=$(DISABLE_PL310) \
	-DRAM_BASE=$(RAM_BASE) \
	-DRAM_SIZE=$(RAM_SIZE) \
	-DKERNEL_RUNTIME_ADDR=$(KERNEL_RUNTIME_ADDR) \
	-DMACHINE_TYPE=$(MACHINE_TYPE) \
	-DIMMEDIATE_HANG=$(IMMEDIATE_HANG) \
	-DCOPY_ZIMAGE_TO_RUNTIME=$(COPY_ZIMAGE_TO_RUNTIME)
ASFLAGS := -march=armv7-a -mcpu=cortex-a9 -marm -ffreestanding -fno-pic -nostdlib $(CPPFLAGS)

ZIMAGE := $(IMAGES_DIR)/zImage
IMX_CFG := $(IMAGES_DIR)/imximage.cfg

START_OBJ := $(BUILD_DIR)/start.o
ZIMAGE_OBJ := $(BUILD_DIR)/zImage.o
ELF := $(BUILD_DIR)/direct-linux.elf
BIN := $(BUILD_DIR)/direct-linux.bin
IMX := $(BUILD_DIR)/linux-direct.imx

.PHONY: all clean

all: $(IMX)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(LINKER_SCRIPT): linker.ld | $(BUILD_DIR)
	sed 's|@ENTRY_ADDR@|$(ENTRY_ADDR)|g' $< > $@

$(START_OBJ): src/start.S | $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(ZIMAGE_OBJ): $(ZIMAGE) | $(BUILD_DIR)
	$(OBJCOPY) -I binary -O elf32-littlearm -B arm \
		--rename-section .data=.image_zimage,alloc,load,readonly,data,contents \
		$< $@

$(ELF): $(START_OBJ) $(ZIMAGE_OBJ) $(LINKER_SCRIPT)
	$(LD) -T $(LINKER_SCRIPT) -o $@ $(START_OBJ) $(ZIMAGE_OBJ)

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(IMX): $(BIN) $(IMX_CFG)
	$(MKIMAGE) -T imximage -n $(IMX_CFG) -e $(ENTRY_ADDR) -d $(BIN) $@

clean:
	rm -rf $(BUILD_DIR)
