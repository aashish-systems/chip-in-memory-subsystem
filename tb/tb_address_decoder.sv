// Address Decoder Testbench

`timescale 1ns/1ps

module tb_address_decoder;

    logic [31:0] addr;
    logic        sram_sel;
    logic        dma_sel;
    logic        failed;

    // Instantiate Unit Under Test (UUT)
    address_decoder uut (
        .addr     (addr),
        .sram_sel (sram_sel),
        .dma_sel  (dma_sel)
    );

    initial begin
        failed = 1'b0;
        $display("Starting Address Decoder Testbench...");

        // Test Case 1: SRAM range address 0x0000_0020
        addr = 32'h0000_0020;
        #10;
        if (sram_sel !== 1'b1 || dma_sel !== 1'b0) begin
            $display("[FAIL] TestCase 1 (0x0000_0020): sram_sel=%b, dma_sel=%b (Expected: 1, 0)", sram_sel, dma_sel);
            failed = 1'b1;
        end else begin
            $display("[PASS] TestCase 1 (0x0000_0020) SRAM decode");
        end

        // Test Case 2: DMA range address 0x1000_0004
        addr = 32'h1000_0004;
        #10;
        if (sram_sel !== 1'b0 || dma_sel !== 1'b1) begin
            $display("[FAIL] TestCase 2 (0x1000_0004): sram_sel=%b, dma_sel=%b (Expected: 0, 1)", sram_sel, dma_sel);
            failed = 1'b1;
        end else begin
            $display("[PASS] TestCase 2 (0x1000_0004) DMA decode");
        end

        // Test Case 3: Out-of-bounds address 0x2000_0000
        addr = 32'h2000_0000;
        #10;
        if (sram_sel !== 1'b0 || dma_sel !== 1'b0) begin
            $display("[FAIL] TestCase 3 (0x2000_0000): sram_sel=%b, dma_sel=%b (Expected: 0, 0)", sram_sel, dma_sel);
            failed = 1'b1;
        end else begin
            $display("[PASS] TestCase 3 (0x2000_0000) Unmapped decode");
        end

        // Final Report
        if (failed) begin
            $display("--- ADDRESS DECODER TB: FAILED ---");
            $finish_and_return(1);
        end else begin
            $display("--- ADDRESS DECODER TB: PASSED ---");
            $finish_and_return(0);
        end
    end

endmodule
