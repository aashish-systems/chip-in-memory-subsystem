# Yosys Synthesis Script for Memory Subsystem

# Read design files in a single compilation unit
read_verilog -sv rtl/dma/dma_pkg.sv rtl/decoder/address_decoder.sv rtl/memory/sram_controller.sv rtl/memory/memory_arbiter.sv rtl/dma/dma_regs.sv rtl/dma/dma_fsm.sv rtl/dma/dma_controller.sv rtl/top/memory_subsystem_top.sv rtl/axi/axi_lite_slave.sv

# Elaborate design hierarchy
hierarchy -check -top memory_subsystem_top

# Run synthesis
synth -top memory_subsystem_top

# Report design statistics
stat
