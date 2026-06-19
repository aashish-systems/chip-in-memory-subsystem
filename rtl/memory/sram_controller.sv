// SRAM Controller Module
// Implements 64KB (16384 words x 32 bits) single-port SRAM with 1-cycle latency.

`timescale 1ns/1ps

module sram_controller (
    input  logic        clk,
    input  logic        rd_en,
    input  logic        wr_en,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] addr,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);

`ifdef SYNTHESIS
    // Synthesis Stub: Avoids generating 512K register gates in synthesis tools.
    // Models a simple register bypass to represent latency and timing interface.
    logic [31:0] rdata_reg;
    always_ff @(posedge clk) begin
        if (rd_en) begin
            rdata_reg <= wdata;
        end
    end
    assign rdata = rdata_reg;
`else
    // 16384 words of 32 bits each (64KB total memory)
    logic [31:0] mem [0:16383];

    // Initialize memory to zero to avoid X-state propagation during simulation
    integer i;
    initial begin
        for (i = 0; i < 16384; i = i + 1) begin
            mem[i] = 32'h0;
        end
    end

    // Synchronous Write: Word-aligned indexing using addr[15:2]
    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[addr[15:2]] <= wdata;
        end
    end

    // Synchronous Read: Word-aligned indexing using addr[15:2]
    always_ff @(posedge clk) begin
        if (rd_en) begin
            rdata <= mem[addr[15:2]];
        end
    end

    // Assertion: Single-port SRAM cannot perform read and write simultaneously
    always @(posedge clk) begin
        if (rd_en && wr_en) begin
            $display("[ASSERT FAIL] sram_controller: read and write cannot be active simultaneously!");
            $fatal(1);
        end
    end
`endif

endmodule
