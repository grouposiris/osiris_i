.section .data
base_address: .word 0x10000000        # Base address for saving register values

.section .text
.global _start

_start:
    # Load the base address where register values will be stored
    la t0, base_address               # Load address of base_address
    lw t1, 0(t0)                      # Load base_address value into t1

    # Initialize loop counter
    li t2, 0                          # t2 is the loop counter (0-31 for registers x0 to x31)

save_loop:
    # Calculate memory address to store the register
    slli t3, t2, 2                    # t3 = t2 * 4 (each register occupies 4 bytes)
    add t4, t1, t3                    # t4 = base_address + (t2 * 4)

    # Save register value to memory
    sw x0, 0(t4)                      # Use 'x0', 'x1', ... 'x31' in consecutive steps

    # Increment loop counter
    addi t2, t2, 1                    # t2 = t2 + 1
    bne t2, 32, save_loop             # Repeat until all 32 registers are saved

    # Exit
    li a7, 10                         # Load ecall number for exit
    ecall                             # Make system call to exit


@ ---------------------------
.section .data
base_address: .word 0x10000000        # Base address for saving register values

.section .text
.global _start

_start:
    # Load the base address where register values will be stored
    la t0, base_address               # Load address of base_address into t0
    lw t1, 0(t0)                      # Load base_address value into t1

    # Initialize loop counter for registers x0 to x15
    li t2, 0                          # t2 is the loop counter (0-15 for registers x0 to x15)

save_loop:
    # Calculate memory address to store the register
    slli t3, t2, 2                    # t3 = t2 * 4 (each register occupies 4 bytes)
    add t4, t1, t3                    # t4 = base_address + (t2 * 4)

    # Save register value to memory (adjust each iteration manually to save x0 to x15)
   
@ sw x0, 0(x0)	00000023
@ sw x1, 4(x0)	001000a3
@ sw x2, 8(x0)	00200123
@ sw x3, 12(x0)	003001a3
@ sw x4, 16(x0)	00400223
@ sw x5, 20(x0)	005002a3
@ sw x6, 24(x0)	00600323
@ sw x7, 28(x0)	007003a3
@ sw x8, 32(x0)	00800423
@ sw x9, 36(x0)	009004a3
@ sw x10, 40(x0)	00a00523
@ sw x11, 44(x0)	00b005a3
@ sw x12, 48(x0)	00c00623
@ sw x13, 52(x0)	00d006a3
@ sw x14, 56(x0)	00e00723
@ sw x15, 60(x0)	00f007a3