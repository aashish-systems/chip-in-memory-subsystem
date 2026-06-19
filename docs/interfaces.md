# Memory Subsystem Interface Specifications

This document defines the interface specifications and protocol contracts for the Memory Subsystem modules.

---

## 1. Address Decoder

The Address Decoder module combinatorially decodes the host address to assert block select lines.

### Port List

| Port Name | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `addr` | Input | 32 bits | Host transaction address |
| `sram_sel` | Output | 1 bit | Active high when `addr` is within `0x0000_0000` - `0x0000_FFFF` |
| `dma_sel` | Output | 1 bit | Active high when `addr` is within `0x1000_0000` - `0x1000_00FF` |

---

## 2. SRAM Controller

The SRAM Controller exposes a synchronous, single-port memory interface with a 1-cycle read latency.

### Port List

| Port Name | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 bit | Clock source |
| `rd_en` | Input | 1 bit | Active high read enable |
| `wr_en` | Input | 1 bit | Active high write enable |
| `addr` | Input | 32 bits | Byte address (word-aligned using `addr[15:2]`) |
| `wdata` | Input | 32 bits | Write data |
| `rdata` | Output | 32 bits | Registered read data (valid 1 cycle after `rd_en`) |

---

## 3. DMA Controller

The DMA Controller registers configuration values and drives block-copy operations inside the SRAM.

### External Configuration Slave Interface

| Port Name | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `reg_addr` | Input | 32 bits | Register address offset (`addr[7:0]`) |
| `reg_wdata` | Input | 32 bits | Configuration write data |
| `reg_wr_en` | Input | 1 bit | Write enable |
| `reg_rd_en` | Input | 1 bit | Read enable |
| `reg_rdata` | Output | 32 bits | Combinatorial read data |

### Internal Memory Master Interface

These ports connect to the Memory Arbiter to request transfers on the SRAM bus.

| Port Name | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `mem_addr` | Output | 32 bits | Memory transaction target address |
| `mem_wdata` | Output | 32 bits | Memory write data |
| `mem_rd_en` | Output | 1 bit | Memory read enable |
| `mem_wr_en` | Output | 1 bit | Memory write enable |
| `mem_rdata` | Input | 32 bits | Read data from SRAM |
| `mem_ready` | Input | 1 bit | SRAM interface ready flag (waived in FSM) |

### Status & Interrupt Ports

| Port Name | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `dma_active` | Output | 1 bit | Asserted when the DMA FSM is actively copying |
| `dma_irq` | Output | 1 bit | Active-high single-cycle pulse when transfer completes |

---

## 4. Top-Level Subsystem Simple Interface

The [`memory_subsystem_top`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/top/memory_subsystem_top.sv) module aggregates all components. In Milestone 1, it exposes this simplified Host interface.

### Port List

| Port Name | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 bit | System clock |
| `rst_n` | Input | 1 bit | System reset (active low, asynchronous) |
| `addr` | Input | 32 bits | Transaction address |
| `wdata` | Input | 32 bits | Write data |
| `read_en` | Input | 1 bit | Read request enable |
| `write_en` | Input | 1 bit | Write request enable |
| `rdata` | Output | 32 bits | Read response data |
| `ready` | Output | 1 bit | Ready handshake (stalls host if DMA is active) |
| `dma_irq` | Output | 1 bit | Transfer complete interrupt |
