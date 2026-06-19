// SRAM Controller Testbench

`timescale 1ns/1ps

module tb_sram_controller;

    logic        clk;
    logic        rd_en;
    logic        wr_en;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        failed;

    // Instantiate UUT
    sram_controller uut (
        .clk   (clk),
        .rd_en (rd_en),
        .wr_en (wr_en),
        .addr  (addr),
        .wdata (wdata),
        .rdata (rdata)
    );

    // Clock generator (50MHz, 20ns period)
    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        failed = 1'b0;
        rd_en  = 1'b0;
        wr_en  = 1'b0;
        addr   = 32'h0;
        wdata  = 32'h0;

        // Reset phase / wait
        @(posedge clk);
        #1;

        $display("Starting SRAM Controller Testbench...");

        // Test Case 1: Write 0xDEADBEEF to address 0x0000_0010
        wr_en = 1'b1;
        addr  = 32'h0000_0010;
        wdata = 32'hDEADBEEF;
        @(posedge clk);
        #1;
        wr_en = 1'b0;
        $display("[INFO] Wrote 0xDEADBEEF to addr 0x0000_0010");

        // Wait a cycle
        @(posedge clk);
        #1;

        // Test Case 2: Read address 0x0000_0010 and expect 0xDEADBEEF
        rd_en = 1'b1;
        addr  = 32'h0000_0010;
        @(posedge clk);
        #1;
        rd_en = 1'b0;
        
        if (rdata !== 32'hDEADBEEF) begin
            $display("[FAIL] Read mismatch: Expected 0xDEADBEEF, Got 0x%h", rdata);
            failed = 1'b1;
        end else begin
            $display("[PASS] Read matched 0x%h", rdata);
        end

        // Final Report
        if (failed) begin
            $display("--- SRAM CONTROLLER TB: FAILED ---");
            $finish_and_return(1);
        end else begin
            $display("--- SRAM CONTROLLER TB: PASSED ---");
            $finish_and_return(0);
        end
    end

endmodule
