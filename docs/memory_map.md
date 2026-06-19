# Memory Map

This document defines the physical address spaces mapped in the Memory Subsystem.

| Base Address | End Address | Size | Device Name | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x0000_0000` | `0x0000_FFFF` | 64 KB | SRAM | Internal Single-Port Static RAM (16,384 words × 32 bits) |
| `0x1000_0000` | `0x1000_00FF` | 256 B | DMA | DMA Engine configuration registers |
| `0x2000_0000` | `0x2000_00FF` | 256 B | Accelerator | Reserved for Accelerator Registers (future) |
| `0x3000_0000` | `0x3000_00FF` | 256 B | UART | Reserved for UART registers (future) |
| `0x4000_0000` | `0x4000_00FF` | 256 B | Timer | Reserved for Timer registers (future) |

## Address Decoding Behavior

- Transactions matching the prefix `0x0000` (upper 16 bits) are routed to the SRAM.
- Transactions matching the prefix `0x10` (upper 8 bits) are routed to the DMA Controller registers.
- All other transactions are unmapped.
