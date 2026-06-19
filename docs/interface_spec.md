# Memory Subsystem SoC Integration Interface Specification

This document defines the interface and protocol contracts for the **Memory Subsystem**. It serves as the frozen specification contract for the CPU and Accelerator teams.

---

## 1. System Topology

```text
                  +-----------------------------------+
                  |           RV32IM CPU              | (AXI Master)
                  +-----------------+-----------------+
                                    |
                           AXI-Lite Interconnect
                                    |
                  +-----------------v-----------------+
                  |       Memory Subsystem            | (AXI Slave)
                  |  +-----------------------------+  |
                  |  |      AXI-Lite Slave Wrapper |  |
                  |  +--------------+--------------+  |
                  |                 | (Simple Bus)  |
                  |  +--------------v--------------+  |
                  |  |      Memory Controller      |  |
                  |  +-----+-----------------+-----+  |
                  |        |                 |        |
                  |  +-----v-----+     +-----v-----+  |
                  |  |    SRAM   |     |    DMA    |  |
                  |  +-----------+     +-----------+  |
                  +-----------------+-----------------+
                                    |
                                    v (dma_irq)
                              IRQ Controller
```

---

## 2. Global Memory Map

The system utilizes a 32-bit flat memory-mapped architecture. All hardware blocks in the SoC share this global address space:

| Range Start | Range End | Size | Target Module | Access Rights | Description |
| :--- | :--- | :---: | :--- | :---: | :--- |
| `0x0000_0000` | `0x0000_FFFF` | 64 KB | SRAM | R/W | Local scratchpad static RAM |
| `0x1000_0000` | `0x1000_00FF` | 256 B | DMA Registers | R/W / RO | DMA configuration registers |
| `0x2000_0000` | `0x2000_00FF` | 256 B | Accelerator | R/W / RO | Custom hardware accelerator |
| `0x3000_0000` | `0x3000_00FF` | 256 B | UART | R/W / RO | Serial communication peripheral |
| `0x4000_0000` | `0x4000_00FF` | 256 B | Timer | R/W / RO | System timer peripheral |

---

## 3. SRAM Specifications

- **Total Capacity**: 64 KB (65,536 bytes)
- **Organization**: 16,384 words × 32 bits (single-port SRAM)
- **Addressing**: Byte-addressed, word-aligned (bits `[1:0]` of address are ignored for word reads/writes; indexing uses `addr[15:2]`).
- **Read Latency**: 1 clock cycle (registered output).

---

## 4. DMA Configuration Register File

The DMA controller occupies base address `0x1000_0000`. All registers are 32 bits wide:

| Offset | Register Name | Access | Reset Value | Description |
| :--- | :--- | :---: | :---: | :--- |
| `0x00` | `SRC_ADDR` | R/W | `0x0000_0000` | Start address of the source memory block |
| `0x04` | `DST_ADDR` | R/W | `0x0000_0000` | Start address of the destination memory block |
| `0x08` | `SIZE` | R/W | `0x0000_0000` | Transfer size in 32-bit words |
| `0x0C` | `CONTROL` | R/W | `0x0000_0000` | Write `1` to Bit 0 (`START`) to trigger copy |
| `0x10` | `STATUS` | RO | `0x0000_0000` | Bit 0: `BUSY` (1 = active), Bit 1: `DONE` (1 = finished) |

---

## 5. AXI-Lite Slave Interface

The memory subsystem interfaces with the system interconnect via a standard 32-bit AXI-Lite Slave interface.

### Port Definitions

| Signal Name | Width | Direction | Description |
| :--- | :---: | :---: | :--- |
| `clk` | 1 | Input | Global Clock |
| `rst_n` | 1 | Input | Global Reset (Active-low, asynchronous) |
| **Write Address Channel** | | | |
| `s_axi_awaddr` | 32 | Input | Write address bus |
| `s_axi_awvalid` | 1 | Input | Write address valid |
| `s_axi_awready` | 1 | Output | Write address ready handshake |
| **Write Data Channel** | | | |
| `s_axi_wdata` | 32 | Input | Write data bus |
| `s_axi_wvalid` | 1 | Input | Write data valid |
| `s_axi_wready` | 1 | Output | Write data ready handshake |
| **Write Response Channel** | | | |
| `s_axi_bresp` | 2 | Output | Write response status (always `2'b00` - OKAY) |
| `s_axi_bvalid` | 1 | Output | Write response valid |
| `s_axi_bready` | 1 | Input | Write response ready handshake |
| **Read Address Channel** | | | |
| `s_axi_araddr` | 32 | Input | Read address bus |
| `s_axi_arvalid` | 1 | Input | Read address valid |
| `s_axi_arready` | 1 | Output | Read address ready handshake |
| **Read Data Channel** | | | |
| `s_axi_rdata` | 32 | Output | Read data bus |
| `s_axi_rresp` | 2 | Output | Read response status (always `2'b00` - OKAY) |
| `s_axi_rvalid` | 1 | Output | Read data valid |
| `s_axi_rready` | 1 | Input | Read data ready handshake |

---

## 6. Interrupt Output Specification

The subsystem provides an interrupt output to signal completion of transfers to the system IRQ controller:

- **Signal Name**: `dma_irq`
- **Output Type**: Active-high single-cycle pulse
- **Assert Condition**: Emitted at the rising clock edge when the DMA transitions to the `DMA_DONE` state.
- **Interrupt Clearing**: The interrupt is self-clearing. The sticky `DONE` bit in the status register is cleared when the CPU initiates a new DMA transfer (writing `1` to `CONTROL[0]`).
