// DMA Controller Testbench

`timescale 1ns/1ps

module tb_dma_controller;

    logic        clk;
    logic        rst_n;

    // Slave Port (Configuration)
    logic [31:0] reg_addr;
    logic [31:0] reg_wdata;
    logic        reg_wr_en;
    logic        reg_rd_en;
    logic [31:0] reg_rdata;

    // Master Port (Memory access)
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic        mem_rd_en;
    logic        mem_wr_en;
    logic [31:0] mem_rdata;
    logic        mem_ready;

    // Interrupt / Active
    logic        dma_active;
    logic        dma_irq;

    logic        failed;

    // Instantiate Unit Under Test (UUT)
    dma_controller uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .reg_addr   (reg_addr),
        .reg_wdata  (reg_wdata),
        .reg_wr_en  (reg_wr_en),
        .reg_rd_en  (reg_rd_en),
        .reg_rdata  (reg_rdata),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_rd_en  (mem_rd_en),
        .mem_wr_en  (mem_wr_en),
        .mem_rdata  (mem_rdata),
        .mem_ready  (mem_ready),
        .dma_active (dma_active),
        .dma_irq    (dma_irq)
    );

    // Clock generator (50MHz)
    initial clk = 0;
    always #10 clk = ~clk;

    // Simple Mock Memory model
    logic [31:0] mock_mem [0:15];
    integer i;

    // Mock Memory logic
    always_ff @(posedge clk) begin
        if (mem_rd_en) begin
            // Simply read from mock memory index
            mem_rdata <= mock_mem[mem_addr[5:2]];
        end
        if (mem_wr_en) begin
            // Simply write to mock memory index
            mock_mem[mem_addr[5:2]] <= mem_wdata;
        end
    end

    // Always ready in this simple testbench
    assign mem_ready = 1'b1;

    initial begin
        failed = 1'b0;
        rst_n  = 1'b0;
        reg_addr = 32'h0;
        reg_wdata = 32'h0;
        reg_wr_en = 1'b0;
        reg_rd_en = 1'b0;

        // Initialize mock memory
        for (i = 0; i < 16; i = i + 1) begin
            mock_mem[i] = i + 1; // 1, 2, 3, ...
        end

        // Reset
        #40;
        rst_n = 1'b1;
        #20;

        $display("Starting DMA Controller Testbench...");

        // 1. Verify Register Writes & Reads
        // Write SRC_ADDR = 0x0000_0000 (Index 0 in mock memory)
        reg_addr  = 32'h1000_0000;
        reg_wdata = 32'h0000_0000;
        reg_wr_en = 1'b1;
        @(posedge clk); #1;
        reg_wr_en = 1'b0;

        // Write DST_ADDR = 0x0000_0020 (Index 8 in mock memory)
        reg_addr  = 32'h1000_0004;
        reg_wdata = 32'h0000_0020;
        reg_wr_en = 1'b1;
        @(posedge clk); #1;
        reg_wr_en = 1'b0;

        // Write SIZE = 4 (Transfer 4 words)
        reg_addr  = 32'h1000_0008;
        reg_wdata = 32'h0000_0004;
        reg_wr_en = 1'b1;
        @(posedge clk); #1;
        reg_wr_en = 1'b0;

        // Read and verify registers
        reg_rd_en = 1'b1;
        reg_addr  = 32'h1000_0000;
        #1;
        if (reg_rdata !== 32'h0000_0000) begin
            $display("[FAIL] Reg SRC_ADDR mismatch: Got 0x%h, Expected 0x0", reg_rdata);
            failed = 1'b1;
        end
        
        reg_addr  = 32'h1000_0004;
        #1;
        if (reg_rdata !== 32'h0000_0020) begin
            $display("[FAIL] Reg DST_ADDR mismatch: Got 0x%h, Expected 0x20", reg_rdata);
            failed = 1'b1;
        end

        reg_addr  = 32'h1000_0008;
        #1;
        if (reg_rdata !== 32'h0000_0004) begin
            $display("[FAIL] Reg SIZE mismatch: Got 0x%h, Expected 4", reg_rdata);
            failed = 1'b1;
        end
        reg_rd_en = 1'b0;

        // 2. Trigger DMA transfer by writing to CONTROL
        reg_addr  = 32'h1000_000C;
        reg_wdata = 32'h0000_0001; // START = 1
        reg_wr_en = 1'b1;
        @(posedge clk); #1;
        reg_wr_en = 1'b0;

        // Wait for IRQ
        fork : dma_wait
            begin
                // Timeout after 200 cycles
                repeat (200) @(posedge clk);
                $display("[FAIL] DMA transfer timed out!");
                failed = 1'b1;
                disable dma_wait;
            end
            begin
                // Wait for interrupt
                @(posedge clk);
                while (!dma_irq) begin
                    @(posedge clk);
                end
                $display("[INFO] DMA interrupt received!");
                disable dma_wait;
            end
        join

        // 3. Verify copied memory content
        // SRC indices 0..3 (data: 1..4) should have been copied to DST indices 8..11
        #10;
        if (mock_mem[8] !== 32'd1 || mock_mem[9] !== 32'd2 || mock_mem[10] !== 32'd3 || mock_mem[11] !== 32'd4) begin
            $display("[FAIL] Memory copy check failed!");
            $display("mock_mem[8]  = %d (Expected: 1)", mock_mem[8]);
            $display("mock_mem[9]  = %d (Expected: 2)", mock_mem[9]);
            $display("mock_mem[10] = %d (Expected: 3)", mock_mem[10]);
            $display("mock_mem[11] = %d (Expected: 4)", mock_mem[11]);
            failed = 1'b1;
        end else begin
            $display("[PASS] Memory copy succeeded!");
        end

        // Check STATUS register done bit
        reg_rd_en = 1'b1;
        reg_addr  = 32'h1000_0010;
        #1;
        if (reg_rdata[1] !== 1'b1) begin
            $display("[FAIL] STATUS register DONE bit not set!");
            failed = 1'b1;
        end else begin
            $display("[PASS] STATUS register DONE bit is set");
        end
        reg_rd_en = 1'b0;

        // Final Report
        if (failed) begin
            $display("--- DMA CONTROLLER TB: FAILED ---");
            $finish_and_return(1);
        end else begin
            $display("--- DMA CONTROLLER TB: PASSED ---");
            $finish_and_return(0);
        end
    end

endmodule
