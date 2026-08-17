# Software Integration Guide

This document provides a comprehensive guide and complete C code examples for integrating and using the RISC-V Platform-Level Interrupt Controller (PLIC) in software.

##  PLIC Software Flow

1. **Initialization**: Configure interrupt priorities, enable specific sources for the target context (e.g., Machine mode), and set the priority threshold.

2. **Trigger**: An external peripheral asserts its interrupt line. The PLIC gateway latches the request and the arbiter evaluates it against the context threshold.

3. **Claim**: The core's trap handler reads the Claim register. This returns the highest priority pending interrupt ID and atomically clears its pending bit in the arbiter.

4. **Service**: The software executes the specific Interrupt Service Routine (ISR) for the claimed ID.

5. **Complete**: After servicing, the software writes the interrupt ID back to the Claim/Complete register. This signals the PLIC to re-arm the interrupt gateway .

---

## Memory Map Definitions

The following C macros provide direct access to the PLIC registers.

```c
// Update this base address to match your SoC's memory map
#define PLIC_BASE_ADDR      0x0C000000 

// Register Offsets and Macros
#define PLIC_PRIORITY(src)      (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x000004 + 4 * (src)))
#define PLIC_PENDING(word)      (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x001000 + 4 * (word)))
#define PLIC_ENABLE(ctx, word)  (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x002000 + 0x80 * (ctx) + 4 * (word)))
#define PLIC_THRESHOLD(ctx)     (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x200000 + 0x1000 * (ctx)))
#define PLIC_CLAIM_COMPLETE(ctx)(*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x200000 + 0x1000 * (ctx) + 0x04))
```

> `Note`: The ENABLE registers are grouped in 32-bit words. Bit N of word W corresponds to interrupt source (W * 32) + N.

---

# Complete Bare Metal C Example

Below is a complete, runnable example demonstrating PLIC initialization, trap setup, and the external interrupt handler for a RISC-V core running in Machine Mode (M-mode).


```c
#include <stdint.h>

// CSR Macros
#define read_csr(reg) ({ unsigned long __tmp; \
    __asm__ volatile ("csrr %0, " #reg : "=r"(__tmp)); __tmp; })
#define write_csr(reg, val) ({ \
    __asm__ volatile ("csrw " #reg ", %0" :: "rK"(val)); })

#define MSTATUS_MIE  (1 << 3)  // Machine Interrupt Enable
#define MIE_MEIE     (1 << 11) // Machine External Interrupt Enable

// --- PLIC Configuration Parameters ---
#define NUM_SOURCES 16
#define TARGET_CTX  0  // Context 0 (Machine Mode)

#define PLIC_BASE_ADDR      0x0C000000 // Example base address, update per SoC map

// Register Access Macros
#define PLIC_PRIORITY(src)       (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x000004 + 4 * (src)))
#define PLIC_PENDING(word)       (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x001000 + 4 * (word)))
#define PLIC_ENABLE(ctx, word)   (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x002000 + 0x80 * (ctx) + 4 * (word)))
#define PLIC_THRESHOLD(ctx)      (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x200000 + 0x1000 * (ctx)))
#define PLIC_CLAIM_COMPLETE(ctx) (*(volatile uint32_t *)(PLIC_BASE_ADDR + 0x200000 + 0x1000 * (ctx) + 0x04))

void plic_init(void) {
    // 1. Set priorities for sources 1 through 15.
    // Source 0 is reserved and hardwired to 0 in hardware.
    // We assign priority 1 to all valid sources.
    for (int i = 1; i < NUM_SOURCES; i++) {
        PLIC_PRIORITY(i) = 1; 
    }

    // 2. Set the priority threshold for Context 0 to 0.
    // This allows all interrupts with priority > 0 to pass.
    PLIC_THRESHOLD(TARGET_CTX) = 0;

    // 3. Enable sources 1 through 15 for Context 0.
    // Word 0 covers sources 0-31. 
    // 0x0000FFFE sets bits 1 through 15 high, and bit 0 low.
    PLIC_ENABLE(TARGET_CTX, 0) = 0x0000FFFE; 
}

void enable_external_interrupts(void) {
    // Enable Machine External Interrupt in MIE CSR
    uint32_t mie = read_csr(mie);
    mie |= MIE_MEIE;
    write_csr(mie, mie);

    // Enable Global Interrupts in MSTATUS CSR
    uint32_t mstatus = read_csr(mstatus);
    mstatus |= MSTATUS_MIE;
    write_csr(mstatus, mstatus);
}

void handle_external_interrupt(void) {
    // 1. CLAIM: Read the highest priority pending interrupt ID
    uint32_t claim_id = PLIC_CLAIM_COMPLETE(TARGET_CTX);

    // 2. Check for spurious interrupt
    if (claim_id == 0) {
        return; 
    }

    // 3. SERVICE: Handle the specific device interrupt
    switch (claim_id) {
        case 1:
            // Handle Device 1 (e.g., UART RX)
            // uart_handle_rx();
            break;
            
        case 2:
            // Handle Device 2 (e.g., GPIO Button)
            // gpio_clear_interrupt();
            break;
            
        default:
            // Unknown or unhandled source
            break;
    }

    // 4. COMPLETE: Write the ID back to signal completion
    // This re-arms edge-sensitive gateways and allows the next interrupt.
    PLIC_CLAIM_COMPLETE(TARGET_CTX) = claim_id;
}

int main(void) {
    // Initialize hardware
    plic_init();
    enable_external_interrupts();

    .
    .
    .
    .
    .

    return 0;
}
```