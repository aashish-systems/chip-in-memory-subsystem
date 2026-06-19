# Memory Subsystem Integration Guide

This guide provides the necessary address maps, register interfaces, and bare-metal C driver examples required by the CPU team to integrate and write software for the Memory Subsystem.

---

## 1. Subsystem Base Addresses

All accesses are mapped through the global AXI interconnect:
- **SRAM Base**: `0x0000_0000` (Size: 64 KB, Range: `0x0000_0000` to `0x0000_FFFF`)
- **DMA Registers Base**: `0x1000_0000` (Size: 256 B, Range: `0x1000_0000` to `0x1000_00FF`)

---

## 2. DMA Register Map

The configuration registers are word-aligned and accessed at the offsets defined below:

| Offset | Register Name | Mode | Reset Value | Description |
| :--- | :--- | :---: | :---: | :--- |
| `0x00` | `DMA_SRC` | R/W | `0x0000_0000` | Source memory start address (byte-aligned) |
| `0x04` | `DMA_DST` | R/W | `0x0000_0000` | Destination memory start address (byte-aligned) |
| `0x08` | `DMA_SIZE` | R/W | `0x0000_0000` | Transfer block size in **32-bit words** |
| `0x0C` | `DMA_CTRL` | R/W | `0x0000_0000` | Control register. Bit 0: `START` (Write 1 to trigger) |
| `0x10` | `DMA_STATUS` | RO | `0x0000_0000` | Status register. Bit 0: `BUSY` (1 = active), Bit 1: `DONE` (1 = finished) |

### Control & Status Bitmasks
- **`START_MASK`**: `0x0000_0001` (Write to offset `0x0C` to initiate transfer)
- **`BUSY_MASK`**: `0x0000_0001` (Read from offset `0x10`, bit 0)
- **`DONE_MASK`**: `0x0000_0002` (Read from offset `0x10`, bit 1)

---

## 3. Interrupts
- **Signal Line**: `dma_irq`
- **Behavior**: Active-high single-cycle pulse generated automatically when the transfer finishes.
- **Clearing**: The `DMA_STATUS` register's `DONE` bit is sticky and remains set until the next DMA transaction is triggered (by writing `1` to `DMA_CTRL[0]`), which automatically resets the flag.

---

## 4. Software Bring-up Drivers (C Code)

Below is the C-header and driver block to initialize and run a DMA transfer in your bare-metal test suites.

### Header Definition (`dma.h`)
```c
#ifndef DMA_H
#define DMA_H

// Memory Mapped Registers offsets
#define DMA_REG_BASE    0x10000000

#define DMA_SRC         (*(volatile unsigned int*)(DMA_REG_BASE + 0x00))
#define DMA_DST         (*(volatile unsigned int*)(DMA_REG_BASE + 0x04))
#define DMA_SIZE        (*(volatile unsigned int*)(DMA_REG_BASE + 0x08))
#define DMA_CTRL        (*(volatile unsigned int*)(DMA_REG_BASE + 0x0C))
#define DMA_STATUS      (*(volatile unsigned int*)(DMA_REG_BASE + 0x10))

// Status bits
#define DMA_BUSY_BIT    (1 << 0)
#define DMA_DONE_BIT    (1 << 1)

#endif // DMA_H
```

### Transfer Driver Implementation
```c
#include "dma.h"

/**
 * Trigger an offloaded block copy inside the SRAM memory
 * @param src_addr  Source address in SRAM (e.g. 0x00000000)
 * @param dst_addr  Destination address in SRAM (e.g. 0x00000100)
 * @param num_words Number of 32-bit words to copy
 */
void sram_dma_copy(unsigned int src_addr, unsigned int dst_addr, unsigned int num_words) {
    // 1. Program transaction registers
    DMA_SRC  = src_addr;
    DMA_DST  = dst_addr;
    DMA_SIZE = num_words;

    // 2. Trigger the DMA engine by setting the START bit in control register
    DMA_CTRL = 1;
}

/**
 * Block the CPU execution thread until the current DMA transfer finishes (Polling method)
 */
void dma_wait_for_completion(void) {
    // Poll the busy status bit until it clears
    while (DMA_STATUS & DMA_BUSY_BIT) {
        // NOP or sleep
    }
}
```
