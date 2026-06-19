# Memory Subsystem with DMA Controller

An ASIC-style reusable SystemVerilog IP repository implementing a memory controller subsystem with internal single-port SRAM, address decoder, memory arbiter, and word-based DMA copy engine. 

Designed for tapeout-readiness with comprehensive verification (linting, synthesis checking, procedural assertions, and corner-case sweeps).

---

## Features

- **64KB Single-Port SRAM**: Word-aligned static RAM controller with registered read/write ports, 1-cycle latency, and procedural mutual exclusion assertions.
- **Priority Memory Arbiter**: Multiplexes accesses between host commands and the internal DMA engine. The DMA controller has request priority, stalling host requests safely.
- **State-driven DMA Engine**: Fully programmable DMA FSM supporting memory-to-memory copies with a single-cycle completion interrupt (`dma_irq`).
- **ASIC Compilation Safety**: Employs ``ifdef SYNTHESIS` guards to bypass behavioral simulation memory arrays during logic synthesis, avoiding gate counts explosion.
- **Verilator & Yosys Clean**: 100% warning-free Verilator lint compilation and zero-issue Yosys logic synthesis mapping.

---

## Directory Structure

```text
├── rtl/
│   ├── top/
│   │   └── memory_subsystem_top.sv  # Subsystem wrapper top level
│   ├── decoder/
│   │   └── address_decoder.sv       # Combinatorial address decoder
│   ├── dma/
│   │   ├── dma_pkg.sv               # DMA package and type definitions
│   │   ├── dma_regs.sv              # Configuration registers
│   │   ├── dma_fsm.sv               # Main DMA transaction state machine
│   │   └── dma_controller.sv        # Top wrapper of the DMA module
│   └── memory/
│       ├── sram_controller.sv       # 64KB RAM controller
│       └── memory_arbiter.sv        # Priority bus arbiter
│
├── tb/
│   ├── tb_address_decoder.sv        # Unit test for decoder
│   ├── tb_sram_controller.sv        # Unit test for SRAM RAM controller
│   ├── tb_dma_controller.sv         # Unit test for DMA controller block
│   └── tb_memory_subsystem.sv       # Top-level integration & corner cases test
│
├── docs/
│   ├── memory_map.md                # Subsystem memory maps
│   ├── dma_register_map.md          # Offsets and bit definitions
│   └── architecture.md              # Block diagrams, assertions and synthesis
│
├── scripts/
│   ├── sim.bat                      # Verification suite runner script
│   └── synth.tcl                    # Yosys synthesis script
│
├── .gitignore                       # Ignored build & waveform patterns
└── README.md                        # Documentation overview
```

---

## Build & Verification Instructions

### 1. Functional Simulation & Corner Cases
To compile and run all unit tests and the comprehensive integration sweep (dumping waveforms to `temp/sim_subsystem.vcd`), run:

```cmd
.\scripts\sim.bat
```

### 2. Verilator Linting
To run a strict, compiler-level linting check using Verilator, run:

```cmd
set VERILATOR_ROOT=C:\oss-cad-suite\share\verilator
verilator_bin.exe --lint-only -Wall rtl/decoder/address_decoder.sv rtl/memory/sram_controller.sv rtl/memory/memory_arbiter.sv rtl/dma/dma_pkg.sv rtl/dma/dma_regs.sv rtl/dma/dma_fsm.sv rtl/dma/dma_controller.sv rtl/top/memory_subsystem_top.sv
```

### 3. Yosys Logic Synthesis
To verify the design is fully synthesizable without latches or combinational loops, run:

```cmd
yosys -s scripts/synth.tcl
```

---

## Verification Summary

| Verification Phase | Metric / Details | Status |
| :--- | :--- | :---: |
| **Unit Tests** | Decoder, SRAM Controller, DMA Register File | **PASSED** |
| **Integration Test** | Top-level host interface reads/writes and DMA copies | **PASSED** |
| **ASIC Corner Cases** | Size = 0, Size = 1, Max size (1024), Same SRC/DST, Mid-transfer Reset | **PASSED** |
| **Verilator Linter** | Strict `-Wall` compilation check | **CLEAN** |
| **Yosys Synthesis** | Cell count statistics, checks for latches and loops | **CLEAN** |
| **Procedural Assertions** | SRAM read-write collision, DMA FSM status correctness | **PASSED** |
| **Waveform dump** | Waveforms generated at `temp/sim_subsystem.vcd` | **DUMPED** |
