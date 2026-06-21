#ifndef PL310_BASE
#define PL310_BASE 0x00a02000
#endif

#ifndef DISABLE_PL310
#define DISABLE_PL310 1
#endif

#ifndef DEBUG_UART_BASE
#define DEBUG_UART_BASE 0
#endif

#ifndef DEBUG_UART
#define DEBUG_UART 0
#endif

#ifndef SKIP_DCACHE_CLEAN
#define SKIP_DCACHE_CLEAN 0
#endif

#ifndef RAM_BASE
#define RAM_BASE 0x10000000
#endif

#ifndef RAM_SIZE
#define RAM_SIZE 0x80000000
#endif

#ifndef ATAGS_ADDR
#define ATAGS_ADDR (RAM_BASE + 0x100)
#endif

#ifndef KERNEL_RUNTIME_ADDR
#define KERNEL_RUNTIME_ADDR 0x12000000
#endif

#ifndef MACHINE_TYPE
#define MACHINE_TYPE 0x00000f8c
#endif

#ifndef IMMEDIATE_HANG
#define IMMEDIATE_HANG 0
#endif

#ifndef COPY_ZIMAGE_TO_RUNTIME
#define COPY_ZIMAGE_TO_RUNTIME 0
#endif

    .syntax unified
    .arch armv7-a
    .arm

    .section .text.start, "ax"
    .globl _start
_start:
    cpsid   if
    mrs     r0, cpsr
    bic     r0, r0, #0x1f
    orr     r0, r0, #0xd3
    msr     cpsr_c, r0

#if DEBUG_UART
    mov     r0, #'A'
    bl      uart_putc
#endif

#if IMMEDIATE_HANG
    b       hang
#endif

    bl      cleanup_before_linux

#if DEBUG_UART
    mov     r0, #'B'
    bl      uart_putc
#endif

#if COPY_ZIMAGE_TO_RUNTIME
    bl      relocate_zimage

#if DEBUG_UART
    mov     r0, #'C'
    bl      uart_putc
#endif
#endif

    bl      build_atags

#if DEBUG_UART
    mov     r0, #'D'
    bl      uart_putc
#endif

    mov     r0, #0
    ldr     r1, =MACHINE_TYPE
    ldr     r2, =ATAGS_ADDR

#if COPY_ZIMAGE_TO_RUNTIME
    ldr     r3, =KERNEL_RUNTIME_ADDR
#else
    ldr     r3, =__image_zimage_start
#endif

#if DEBUG_UART
    mov     r0, #'J'
    bl      uart_putc
#endif
    bx      r3

#if DEBUG_UART
uart_putc:
    ldr     r1, =DEBUG_UART_BASE
    cmp     r1, #0
    beq     2f
1:
    ldr     r2, [r1, #0xb4]
    tst     r2, #(1 << 4)
    bne     1b
    str     r0, [r1, #0x40]
    dsb
2:
    bx      lr
#endif

cleanup_before_linux:
    push    {lr}

#if DEBUG_UART
    mov     r0, #'1'
    bl      uart_putc
#endif

#if !SKIP_DCACHE_CLEAN
    bl      clean_invalidate_dcache_all
#endif

#if DEBUG_UART
    mov     r0, #'2'
    bl      uart_putc
#endif

    mov     r0, #0
    mcr     p15, 0, r0, c8, c7, 0
    mcr     p15, 0, r0, c7, c5, 0
    dsb
    isb

#if DEBUG_UART
    mov     r0, #'3'
    bl      uart_putc
#endif

    mrc     p15, 0, r0, c1, c0, 0
    bic     r0, r0, #(1 << 12)
    bic     r0, r0, #(1 << 11)
    bic     r0, r0, #(1 << 2)
    bic     r0, r0, #(1 << 0)
    mcr     p15, 0, r0, c1, c0, 0

#if DEBUG_UART
    mov     r0, #'4'
    bl      uart_putc
#endif

#if DISABLE_PL310
    bl      disable_pl310
#if DEBUG_UART
    mov     r0, #'5'
    bl      uart_putc
#endif
#endif

    mov     r0, #0
    mcr     p15, 0, r0, c8, c7, 0
    mcr     p15, 0, r0, c7, c5, 0
    isb
    dsb

#if DEBUG_UART
    mov     r0, #'6'
    bl      uart_putc
#endif
    pop     {lr}
    bx      lr

clean_invalidate_dcache_all:
    stmfd   sp!, {r4-r5, r7, r9-r11, lr}
    bl      __clean_invalidate_dcache_all
    ldmfd   sp!, {r4-r5, r7, r9-r11, lr}
    bx      lr

__clean_invalidate_dcache_all:
    dmb
    mrc     p15, 1, r0, c0, c0, 1
    mov     r3, r0, lsr #23
    ands    r3, r3, #7 << 1
    beq     5f

    mov     r10, #0

1:
    add     r2, r10, r10, lsr #1
    mov     r1, r0, lsr r2
    and     r1, r1, #7
    cmp     r1, #2
    blt     4f

    mcr     p15, 2, r10, c0, c0, 0
    isb
    mrc     p15, 1, r1, c0, c0, 0

    and     r2, r1, #7
    add     r2, r2, #4

    ldr     r4, =0x3ff
    ands    r4, r4, r1, lsr #3
    clz     r5, r4

    ldr     r7, =0x7fff
    ands    r7, r7, r1, lsr #13

2:
    mov     r9, r7

3:
    orr     r11, r10, r4, lsl r5
    orr     r11, r11, r9, lsl r2
    mcr     p15, 0, r11, c7, c14, 2
    subs    r9, r9, #1
    bge     3b
    subs    r4, r4, #1
    bge     2b

4:
    add     r10, r10, #2
    cmp     r3, r10
    bgt     1b

5:
    mov     r10, #0
    mcr     p15, 2, r10, c0, c0, 0
    dsb     st
    isb
    bx      lr

disable_pl310:
    ldr     r0, =PL310_BASE
    ldr     r1, =0xffff
    str     r1, [r0, #0x7fc]
1:
    ldr     r2, [r0, #0x7fc]
    cmp     r2, #0
    bne     1b

    mov     r1, #0
    str     r1, [r0, #0x730]
    str     r1, [r0, #0x100]
    dsb
    isb
    bx      lr

#if COPY_ZIMAGE_TO_RUNTIME
relocate_zimage:
    ldr     r0, =__image_zimage_start
    ldr     r1, =KERNEL_RUNTIME_ADDR
    ldr     r2, =__image_zimage_end

3:
    cmp     r0, r2
    bhs     4f
    ldrb    r3, [r0], #1
    strb    r3, [r1], #1
    b       3b

4:
    bx      lr
#endif

build_atags:
    ldr     r0, =ATAGS_ADDR

    @ ATAG_CORE
    mov     r1, #5
    str     r1, [r0], #4
    ldr     r1, =0x54410001
    str     r1, [r0], #4
    mov     r1, #0
    str     r1, [r0], #4
    str     r1, [r0], #4
    str     r1, [r0], #4

    @ ATAG_MEM
    mov     r1, #4
    str     r1, [r0], #4
    ldr     r1, =0x54410002
    str     r1, [r0], #4
    ldr     r1, =RAM_SIZE
    str     r1, [r0], #4
    ldr     r1, =RAM_BASE
    str     r1, [r0], #4

    @ ATAG_NONE
    mov     r1, #0
    str     r1, [r0], #4
    str     r1, [r0], #4
    dsb
    bx      lr

#if IMMEDIATE_HANG
    .globl hang
hang:
    b       hang
#endif