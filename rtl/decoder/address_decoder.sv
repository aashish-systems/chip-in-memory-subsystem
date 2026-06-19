// Address Decoder Module for Memory Subsystem
// Decodes address ranges to select SRAM or DMA Controller.

`timescale 1ns/1ps

module address_decoder (
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] addr,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic        sram_sel,
    output logic        dma_sel
);

    always @(*) begin
        sram_sel = 1'b0;
        dma_sel  = 1'b0;

        // SRAM Range: 0x0000_0000 to 0x0000_FFFF (Upper 16 bits are 0x0000)
        if (addr[31:16] == 16'h0000) begin
            sram_sel = 1'b1;
        end
        // DMA Range: 0x1000_0000 to 0x1000_00FF (Upper 8 bits are 0x10)
        else if (addr[31:24] == 8'h10) begin
            dma_sel = 1'b1;
        end
    end

endmodule
