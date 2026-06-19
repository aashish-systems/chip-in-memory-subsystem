# Memory Subsystem Architecture

This document describes the hardware design, component interfaces, register configurations, synthesis statistics, and verification assertions for the Memory Subsystem.

## Block Diagram

```text
                     Host Interface (CPU / Testbench Master)
                                      |
                               +------v------+
                               | Memory Ctrl |
                               +------+------+
                                      |
                       +--------------+--------------+
                       |                             |
                +------v-------+             +-------v------+
                | Addr Decoder |             | DMA Register |
                +------+-------+             +-------+------+
                       |                             |
               +-------+-------+                     |
               |               |                     |
        +------v-----+   +-----v------+              |
        | Memory Arb |   |   Future   |              |
        +---+-----+--+   | Extensions |              |
            |     |      +------------+              |
      +-----v--+  |                                  |
      | Internal  |                                  |
      |  SRAM    |                                   |
      +--------+  |                                  |
            +-----v---------------+                  |
            | DMA Controller FSM  <------------------+
            +---------------------+
```

---

## Component Description & Block Ownership

| Block / Module | Description | File Path |
| :--- | :--- | :--- |
| **Top Wrapper** | Connects internal components and exposes the simple Host interface. | [`memory_subsystem_top.sv`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/top/memory_subsystem_top.sv) |
| **Address Decoder** | Performs combinatorial address range decoding. | [`address_decoder.sv`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/decoder/address_decoder.sv) |
| **SRAM Controller** | 64KB single-port RAM (16,384 words × 32 bits) with 1-cycle latency. Contains synthesis memory arrays bypass guards. | [`sram_controller.sv`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/memory/sram_controller.sv) |
| **Memory Arbiter** | Priority-based arbiter granting SRAM access. DMA has higher priority. | [`memory_arbiter.sv`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/memory/memory_arbiter.sv) |
| **DMA Controller** | Top wrapper containing the DMA Register block and state machine FSM. | [`dma_controller.sv`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/dma/dma_controller.sv) |
| **DMA Register File**| Holds configuration registers for source, destination, size, and status. | [`dma_regs.sv`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/dma/dma_regs.sv) |
| **DMA FSM** | Implements the transfer sequence from read requests to write responses. | [`dma_fsm.sv`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/dma/dma_fsm.sv) |

---

## Memory Map

Decoding is performed combinatorially based on the upper bits of the address:

- **SRAM**: `0x0000_0000` to `0x0000_FFFF` (Address bits `[31:16] == 16'h0000`)
- **DMA Registers**: `0x1000_0000` to `0x1000_00FF` (Address bits `[31:24] == 8'h10`)

---

## DMA Configuration Registers

The registers are word-aligned and accessed at base offset `0x1000_0000`:

1. **`SRC_ADDR`** (`0x00`) - R/W: Source address in SRAM.
2. **`DST_ADDR`** (`0x04`) - R/W: Destination address in SRAM.
3. **`SIZE`** (`0x08`) - R/W: Number of 32-bit words to copy.
4. **`CONTROL`** (`0x0C`) - R/W:
   - `Bit 0` (START): Pulse with `1` to begin transaction.
5. **`STATUS`** (`0x10`) - RO:
   - `Bit 0` (BUSY): `1` if FSM is currently transferring.
   - `Bit 1` (DONE): Sticky flag showing that the transfer finished. Cleared on next `START`.

---

## RTL Assertions (Verification Constraints)

To prevent bugs during integration and simulation, design assertions are embedded directly within the RTL:

### 1. SRAM Controller Concurrent Access Check
Procedural assertion guarding the single-port interface from simultaneous read and write enables:
```systemverilog
always @(posedge clk) begin
    if (rd_en && wr_en) begin
        $display("[ASSERT FAIL] sram_controller: read and write cannot be active simultaneously!");
        $fatal(1);
    end
end
```

### 2. DMA FSM Status Correctness Checks
Procedural assertions validating state-to-output correctness:
- **Done Assert**: In `DMA_DONE` state, the `done` status bit must be high.
- **Busy Assert**: In all states other than `DMA_IDLE` and `DMA_DONE`, the `busy` status bit must be high.
```systemverilog
always @(posedge clk) begin
    if (rst_n) begin
        if (state == dma_pkg::DMA_DONE && !done) begin
            $display("[ASSERT FAIL] dma_fsm: done must be asserted in DMA_DONE state!");
            $fatal(1);
        end
        if ((state != dma_pkg::DMA_IDLE && state != dma_pkg::DMA_DONE) && !busy) begin
            $display("[ASSERT FAIL] dma_fsm: busy must be active when state is not IDLE or DONE!");
            $fatal(1);
        end
    end
end
```

---

## Synthesis Strategy & Results (Yosys)

### Synthesis Guarding
To prevent the synthesis tool from trying to compile 524,288 flip-flops representing the behavior-mode 64KB SRAM array, a conditional compilation pragma ``ifdef SYNTHESIS` is used. During synthesis, the memory array is replaced by a single-register latency bypass loopback. During simulation, the full 64KB behavioral model remains active.

### Yosys Synthesis Results
Executing the synthesis script [`scripts/synth.tcl`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/scripts/synth.tcl) yields a successful compilation and netlist generation with **0 problems** reported.

Cell distribution:
- **Top level cells**: 102
- **Arbiter cells**: 131
- **Decoder cells**: 17
- **DMA Registers cells**: 313
- **DMA FSM cells**: 817
- **SRAM controller cells (stubbed)**: 32
- **Total cells**: 1,416 cells
  - Gates: `$_AND_`, `$_NAND_`, `$_NOR_`, `$_OR_`, `$_XOR_`, `$_MUX_`
  - Registers: 198 DFF instances (`$_DFFE_PN0P_`, `$_DFF_PN0_`, `$_DFFE_PP_`)
