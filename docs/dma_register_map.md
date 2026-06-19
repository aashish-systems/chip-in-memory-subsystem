# DMA Register Map

The DMA Controller registers are mapped to base address `0x1000_0000`.

| Offset | Name | Access Type | Width | Reset Value | Description |
| :--- | :--- | :---: | :---: | :---: | :--- |
| `0x00` | `SRC_ADDR` | R/W | 32 bits | `0x0000_0000` | Source memory address for DMA transfer |
| `0x04` | `DST_ADDR` | R/W | 32 bits | `0x0000_0000` | Destination memory address for DMA transfer |
| `0x08` | `SIZE` | R/W | 32 bits | `0x0000_0000` | Transfer size in 32-bit words |
| `0x0C` | `CONTROL` | R/W | 32 bits | `0x0000_0000` | Control register (see details below) |
| `0x10` | `STATUS` | RO | 32 bits | `0x0000_0000` | Status register (see details below) |

## Register Bit Definitions

### CONTROL Register (`0x0C`)

- **Bit 0: START (R/W)**
  - Write `1` to start the DMA transfer.
  - Automatically clears once the transfer begins.
- **Bits 31-1**: Reserved.

### STATUS Register (`0x10`)

- **Bit 0: BUSY (RO)**
  - `1`: DMA transfer is currently in progress.
  - `0`: DMA is idle.
- **Bit 1: DONE (RO)**
  - `1`: DMA transfer completed successfully.
  - `0`: DMA transfer has not completed or has been restarted.
  - Note: This bit is cleared when a new transfer is started (by setting the `START` bit in the CONTROL register).
- **Bits 31-2**: Reserved.
