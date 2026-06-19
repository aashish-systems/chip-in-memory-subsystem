// DMA Registers Module
// Manages the Register File for configuring and monitoring DMA transfers.

`timescale 1ns/1ps

module dma_regs (
    input  logic        clk,
    input  logic        rst_n,

    // Register Interface
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] addr,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [31:0] wdata,
    input  logic        wr_en,
    input  logic        rd_en,
    output logic [31:0] rdata,

    // Outputs to DMA FSM/Data Path
    output logic [31:0] src_addr,
    output logic [31:0] dst_addr,
    output logic [31:0] size,
    output logic        start,

    // Inputs from DMA FSM/Data Path
    input  logic        busy,
    input  logic        done
);

    // Register storage
    logic [31:0] r_src_addr;
    logic [31:0] r_dst_addr;
    logic [31:0] r_size;

    assign src_addr = r_src_addr;
    assign dst_addr = r_dst_addr;
    assign size     = r_size;

    // Register Write Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_src_addr <= 32'h0;
            r_dst_addr <= 32'h0;
            r_size     <= 32'h0;
            start      <= 1'b0;
        end else begin
            // Single-cycle start pulse
            start <= 1'b0;

            if (wr_en) begin
                case (addr[7:0])
                    8'h00: r_src_addr <= wdata;
                    8'h04: r_dst_addr <= wdata;
                    8'h08: r_size     <= wdata;
                    8'h0C: begin
                        if (wdata[0]) begin
                            start <= 1'b1;
                        end
                    end
                    default: ; // Do nothing for read-only or invalid offsets
                endcase
            end
        end
    end

    // Combinatorial Register Read Logic
    always @(*) begin
        rdata = 32'h0;
        if (rd_en) begin
            case (addr[7:0])
                8'h00: rdata = r_src_addr;
                8'h04: rdata = r_dst_addr;
                8'h08: rdata = r_size;
                8'h0C: rdata = 32'h0; // CONTROL reads back as 0 (start is self-clearing)
                8'h10: rdata = {30'b0, done, busy};
                default: rdata = 32'h0;
            endcase
        end
    end

endmodule
