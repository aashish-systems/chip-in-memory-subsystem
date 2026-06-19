// Memory Subsystem Top-Level Wrapper
// Integrates the Address Decoder, SRAM Controller, Memory Arbiter, and DMA Controller.
// Uses a simple bus interface for the CPU port.

`timescale 1ns/1ps

module memory_subsystem_top (
    input  logic         clk,
    input  logic         rst_n,

    // Simple Host Interface (CPU or Testbench Master)
    input  logic [31:0]  addr,
    input  logic [31:0]  wdata,
    input  logic         read_en,
    input  logic         write_en,
    output logic [31:0]  rdata,
    output logic         ready,

    // Interrupt output
    output logic         dma_irq
);

    // Decoding Select lines
    logic sram_sel;
    logic dma_sel;

    // Arbiter <-> External CPU connections
    logic [31:0] ext_rdata;
    logic        ext_ready;

    // Arbiter <-> DMA Master connections
    logic [31:0] dma_mem_addr;
    logic [31:0] dma_mem_wdata;
    logic        dma_mem_rd_en;
    logic        dma_mem_wr_en;
    logic [31:0] dma_mem_rdata;
    logic        dma_mem_ready;
    logic        dma_active;

    // Arbiter <-> SRAM Controller connections
    logic [31:0] sram_addr;
    logic [31:0] sram_wdata;
    logic        sram_rd_en;
    logic        sram_wr_en;
    logic [31:0] sram_rdata;

    // DMA register read data
    logic [31:0] reg_rdata;

    // 1. Address Decoder
    address_decoder u_decoder (
        .addr     (addr),
        .sram_sel (sram_sel),
        .dma_sel  (dma_sel)
    );

    // 2. Memory Arbiter
    memory_arbiter u_arbiter (
        .dma_active (dma_active),
        
        // Host (CPU) Interface to SRAM
        .ext_addr   (addr),
        .ext_wdata  (wdata),
        .ext_rd_en  (read_en && sram_sel),
        .ext_wr_en  (write_en && sram_sel),
        .ext_rdata  (ext_rdata),
        .ext_ready  (ext_ready),

        // DMA Interface to SRAM
        .dma_addr   (dma_mem_addr),
        .dma_wdata  (dma_mem_wdata),
        .dma_rd_en  (dma_mem_rd_en),
        .dma_wr_en  (dma_mem_wr_en),
        .dma_rdata  (dma_mem_rdata),
        .dma_ready  (dma_mem_ready),

        // Connections to SRAM Controller
        .sram_addr  (sram_addr),
        .sram_wdata (sram_wdata),
        .sram_rd_en (sram_rd_en),
        .sram_wr_en (sram_wr_en),
        .sram_rdata (sram_rdata)
    );

    // 3. SRAM Controller
    sram_controller u_sram (
        .clk   (clk),
        .rd_en (sram_rd_en),
        .wr_en (sram_wr_en),
        .addr  (sram_addr),
        .wdata (sram_wdata),
        .rdata (sram_rdata)
    );

    // 4. DMA Controller
    dma_controller u_dma (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Configuration slave port
        .reg_addr   (addr),
        .reg_wdata  (wdata),
        .reg_wr_en  (write_en && dma_sel),
        .reg_rd_en  (read_en && dma_sel),
        .reg_rdata  (reg_rdata),

        // Memory master port
        .mem_addr   (dma_mem_addr),
        .mem_wdata  (dma_mem_wdata),
        .mem_rd_en  (dma_mem_rd_en),
        .mem_wr_en  (dma_mem_wr_en),
        .mem_rdata  (dma_mem_rdata),
        .mem_ready  (dma_mem_ready),

        // Status & IRQ
        .dma_active (dma_active),
        .dma_irq    (dma_irq)
    );

    // 5. Host Response Routing
    always_comb begin
        if (dma_sel) begin
            rdata = reg_rdata;
            ready = 1'b1; // Register access is instant (combinatorial read response)
        end else if (sram_sel) begin
            rdata = ext_rdata;
            ready = ext_ready;
        end else begin
            rdata = 32'h0;
            ready = 1'b1; // Default ready for unmapped transactions
        end
    end

endmodule
