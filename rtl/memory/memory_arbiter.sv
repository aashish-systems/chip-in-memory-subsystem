// Memory Arbiter Module
// Arbitrates access to the SRAM between the External Master (CPU) and the DMA Controller.
// DMA gets higher priority when it is active.

`timescale 1ns/1ps

module memory_arbiter (
    input  logic        dma_active, // DMA is active and requests access

    // External Master Port (e.g. CPU)
    input  logic [31:0] ext_addr,
    input  logic [31:0] ext_wdata,
    input  logic        ext_rd_en,
    input  logic        ext_wr_en,
    output logic [31:0] ext_rdata,
    output logic        ext_ready,

    // DMA Master Port
    input  logic [31:0] dma_addr,
    input  logic [31:0] dma_wdata,
    input  logic        dma_rd_en,
    input  logic        dma_wr_en,
    output logic [31:0] dma_rdata,
    output logic        dma_ready,

    // SRAM Controller Interface
    output logic [31:0] sram_addr,
    output logic [31:0] sram_wdata,
    output logic        sram_rd_en,
    output logic        sram_wr_en,
    input  logic [31:0] sram_rdata
);

    always_comb begin
        if (dma_active) begin
            // Route DMA signals to SRAM
            sram_addr   = dma_addr;
            sram_wdata  = dma_wdata;
            sram_rd_en  = dma_rd_en;
            sram_wr_en  = dma_wr_en;

            // Connect read data to DMA
            dma_rdata   = sram_rdata;
            ext_rdata   = 32'h0;

            // Control handshakes
            dma_ready   = 1'b1;
            ext_ready   = 1'b0; // Stall external requests while DMA is active
        end else begin
            // Route External CPU signals to SRAM
            sram_addr   = ext_addr;
            sram_wdata  = ext_wdata;
            sram_rd_en  = ext_rd_en;
            sram_wr_en  = ext_wr_en;

            // Connect read data to External CPU
            ext_rdata   = sram_rdata;
            dma_rdata   = 32'h0;

            // Control handshakes
            dma_ready   = 1'b0;
            ext_ready   = 1'b1; // Ready for external CPU transactions
        end
    end

endmodule
