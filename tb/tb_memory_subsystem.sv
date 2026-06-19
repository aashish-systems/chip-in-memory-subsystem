// Integration Testbench for the Memory Subsystem
// Includes waveform generation and tests for corner cases:
// 1. Nominal 4-word transfer
// 2. Size = 0 transfer
// 3. Size = 1 transfer
// 4. Max transfer (Size = 1024 words)
// 5. Same Source and Destination address
// 6. Reset assertion mid-transfer

`timescale 1ns/1ps

module tb_memory_subsystem;

    logic         clk;
    logic         rst_n;

    // Simple Host Interface (CPU interface)
    logic [31:0]  addr;
    logic [31:0]  wdata;
    logic         read_en;
    logic         write_en;
    logic [31:0]  rdata;
    logic         ready;

    // Interrupt
    logic         dma_irq;

    logic         failed;

    // Instantiate Subsystem
    memory_subsystem_top uut (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (addr),
        .wdata    (wdata),
        .read_en  (read_en),
        .write_en (write_en),
        .rdata    (rdata),
        .ready    (ready),
        .dma_irq  (dma_irq)
    );

    // Clock generator (50MHz, 20ns period)
    initial clk = 0;
    always #10 clk = ~clk;

    // Task to write a 32-bit word
    task cpu_write(input [31:0] waddr, input [31:0] data);
        begin
            addr     = waddr;
            wdata    = data;
            write_en = 1'b1;
            read_en  = 1'b0;
            @(posedge clk);
            #1;
            // Wait if not ready
            while (!ready) begin
                @(posedge clk);
                #1;
            end
            write_en = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    // Task to read a 32-bit word
    task cpu_read(input [31:0] raddr, output [31:0] data);
        begin
            addr     = raddr;
            write_en = 1'b0;
            read_en  = 1'b1;
            @(posedge clk);
            #1;
            // Wait if not ready
            while (!ready) begin
                @(posedge clk);
                #1;
            end
            data     = rdata;
            read_en  = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    // Helper to monitor IRQ or timeout
    task wait_for_irq(input integer max_cycles);
        integer cycles;
        begin
            cycles = 0;
            @(posedge clk);
            while (!dma_irq && cycles < max_cycles) begin
                cycles = cycles + 1;
                @(posedge clk);
            end
            if (cycles >= max_cycles) begin
                $display("[FAIL] Timeout waiting for DMA interrupt!");
                failed = 1'b1;
            end
        end
    endtask

    initial begin
        // Waveform Dump Setup
        $dumpfile("temp/sim_subsystem.vcd");
        $dumpvars(0, tb_memory_subsystem);

        failed   = 1'b0;
        rst_n    = 1'b0;
        addr     = 32'h0;
        wdata    = 32'h0;
        read_en  = 1'b0;
        write_en = 1'b0;

        // Reset phase
        #40;
        rst_n = 1'b1;
        #20;

        $display("==================================================");
        $display("Starting Memory Subsystem ASIC Corner Case Tests");
        $display("==================================================");

        // ------------------------------------------------
        // TEST CASE 1: Nominal 4-Word Transfer
        // ------------------------------------------------
        $display("\n--- [TEST 1] Nominal 4-Word Transfer ---");
        $display("[INFO] Initializing source memory with 1, 2, 3, 4...");
        cpu_write(32'h0000_0000, 32'd1);
        cpu_write(32'h0000_0004, 32'd2);
        cpu_write(32'h0000_0008, 32'd3);
        cpu_write(32'h0000_000C, 32'd4);

        $display("[INFO] Configuring DMA: SRC=0x0, DST=0x100, SIZE=4...");
        cpu_write(32'h1000_0000, 32'h0000_0000); // SRC
        cpu_write(32'h1000_0004, 32'h0000_0100); // DST
        cpu_write(32'h1000_0008, 32'd4);         // SIZE
        cpu_write(32'h1000_000C, 32'h0000_0001); // START

        wait_for_irq(100);

        // Verify copy
        begin
            logic [31:0] v0, v1, v2, v3;
            cpu_read(32'h0000_0100, v0);
            cpu_read(32'h0000_0104, v1);
            cpu_read(32'h0000_0108, v2);
            cpu_read(32'h0000_010C, v3);
            if (v0 !== 32'd1 || v1 !== 32'd2 || v2 !== 32'd3 || v3 !== 32'd4) begin
                $display("[FAIL] Test 1: Data mismatch in SRAM!");
                failed = 1'b1;
            end else begin
                $display("[PASS] Test 1: Data verified successfully.");
            end
        end

        // ------------------------------------------------
        // TEST CASE 2: SIZE = 0 (Expected: no transfer, immediate DONE)
        // ------------------------------------------------
        $display("\n--- [TEST 2] Size = 0 Corner Case ---");
        // Clear status register sticky done bit by restarting or reading it
        $display("[INFO] Configuring DMA: SRC=0x0, DST=0x140, SIZE=0...");
        cpu_write(32'h1000_0000, 32'h0000_0000); // SRC
        cpu_write(32'h1000_0004, 32'h0000_0140); // DST
        cpu_write(32'h1000_0008, 32'd0);         // SIZE (0 words)
        cpu_write(32'h1000_000C, 32'h0000_0001); // START

        // Wait a few cycles to check FSM transitions
        repeat(5) @(posedge clk);

        // Verify STATUS done is set, busy is 0, and no data was written to 0x140
        begin
            logic [31:0] status, data_at_dst;
            cpu_read(32'h1000_0010, status); // read status
            cpu_read(32'h0000_0140, data_at_dst);
            
            if (status[0] !== 1'b0 || status[1] !== 1'b1) begin
                $display("[FAIL] Test 2: Status register invalid! BUSY=%b, DONE=%b (Expected: 0, 1)", status[0], status[1]);
                failed = 1'b1;
            end else if (data_at_dst !== 32'h0) begin
                $display("[FAIL] Test 2: Data written when SIZE=0! Got 0x%h", data_at_dst);
                failed = 1'b1;
            end else begin
                $display("[PASS] Test 2: Size=0 transfer handled correctly.");
            end
        end

        // ------------------------------------------------
        // TEST CASE 3: SIZE = 1 (Single word transfer)
        // ------------------------------------------------
        $display("\n--- [TEST 3] Size = 1 Corner Case ---");
        $display("[INFO] Configuring DMA: SRC=0x4, DST=0x150, SIZE=1...");
        cpu_write(32'h1000_0000, 32'h0000_0004); // SRC (data is 2)
        cpu_write(32'h1000_0004, 32'h0000_0150); // DST
        cpu_write(32'h1000_0008, 32'd1);         // SIZE
        cpu_write(32'h1000_000C, 32'h0000_0001); // START

        wait_for_irq(50);

        // Verify only one word was copied, and adjacent memory remains 0
        begin
            logic [31:0] v_dst, v_adj;
            cpu_read(32'h0000_0150, v_dst);
            cpu_read(32'h0000_0154, v_adj);
            if (v_dst !== 32'd2) begin
                $display("[FAIL] Test 3: Destination data mismatch! Got %d, Expected 2", v_dst);
                failed = 1'b1;
            end else if (v_adj !== 32'd0) begin
                $display("[FAIL] Test 3: Adjacent memory corrupted! Got %d, Expected 0", v_adj);
                failed = 1'b1;
            end else begin
                $display("[PASS] Test 3: Single word transfer succeeded.");
            end
        end

        // ------------------------------------------------
        // TEST CASE 4: Max Transfer (SIZE = 1024 words = 4KB)
        // ------------------------------------------------
        $display("\n--- [TEST 4] Max Transfer (Size = 1024) ---");
        $display("[INFO] Initializing SRAM with 1024 sequential words...");
        for (integer i = 0; i < 1024; i = i + 1) begin
            cpu_write(i * 4, i + 1); // SRAM[i] = i+1
        end

        $display("[INFO] Configuring DMA: SRC=0x0, DST=0x1000, SIZE=1024...");
        cpu_write(32'h1000_0000, 32'h0000_0000); // SRC
        cpu_write(32'h1000_0004, 32'h0000_1000); // DST (Word offset 1024)
        cpu_write(32'h1000_0008, 32'd1024);      // SIZE
        cpu_write(32'h1000_000C, 32'h0000_0001); // START

        // Wait with a larger cycle limit (1024 transfers * ~4 cycles = 4096 cycles max)
        wait_for_irq(5000);

        $display("[INFO] Verifying 1024 copied words...");
        begin
            integer err_count;
            logic [31:0] rval;
            err_count = 0;
            for (integer i = 0; i < 1024; i = i + 1) begin
                cpu_read(32'h0000_1000 + (i * 4), rval);
                if (rval !== (i + 1)) begin
                    err_count = err_count + 1;
                    if (err_count <= 5) begin
                        $display("[FAIL] Test 4: Mismatch at word %0d. Got %0d, Expected %0d", i, rval, i + 1);
                    end
                end
            end
            if (err_count > 0) begin
                $display("[FAIL] Test 4: Total mismatches: %d", err_count);
                failed = 1'b1;
            end else begin
                $display("[PASS] Test 4: All 1024 words copied successfully.");
            end
        end

        // ------------------------------------------------
        // TEST CASE 5: Same Source and Destination Address
        // ------------------------------------------------
        $display("\n--- [TEST 5] Same Source/Destination Corner Case ---");
        // SRAM[0x200] is at word offset 128
        $display("[INFO] Setting SRAM[0x200] = 0xAA55AA55...");
        cpu_write(32'h0000_0200, 32'hAA55AA55);
        $display("[INFO] Configuring DMA: SRC=0x200, DST=0x200, SIZE=4...");
        cpu_write(32'h1000_0000, 32'h0000_0200); // SRC
        cpu_write(32'h1000_0004, 32'h0000_0200); // DST
        cpu_write(32'h1000_0008, 32'd4);         // SIZE
        cpu_write(32'h1000_000C, 32'h0000_0001); // START

        wait_for_irq(100);

        // Verify data intact
        begin
            logic [31:0] rval;
            cpu_read(32'h0000_0200, rval);
            if (rval !== 32'hAA55AA55) begin
                $display("[FAIL] Test 5: Destination data corrupted! Got 0x%h, Expected 0xAA55AA55", rval);
                failed = 1'b1;
            end else begin
                $display("[PASS] Test 5: Same SRC/DST transfer succeeded without issue.");
            end
        end

        // ------------------------------------------------
        // TEST CASE 6: Reset Assertion During Transfer
        // ------------------------------------------------
        $display("\n--- [TEST 6] Reset Mid-Transfer Corner Case ---");
        $display("[INFO] Configuring DMA for 8 words: SRC=0x0, DST=0x300...");
        cpu_write(32'h1000_0000, 32'h0000_0000); // SRC
        cpu_write(32'h1000_0004, 32'h0000_0300); // DST
        cpu_write(32'h1000_0008, 32'd8);         // SIZE
        cpu_write(32'h1000_000C, 32'h0000_0001); // START

        // Wait 5 clock cycles (midway through read/write sequence)
        repeat(5) @(posedge clk);
        #1;
        $display("[INFO] Asserting reset active-low mid-transfer...");
        rst_n = 1'b0;
        repeat(2) @(posedge clk);
        #1;
        rst_n = 1'b1;
        $display("[INFO] Reset released. Verifying registers are back to default/idle...");

        // Verify that FSM returned to IDLE (busy=0, done=0 in status register)
        // and configuration registers are cleared
        begin
            logic [31:0] status, src, dst, size;
            cpu_read(32'h1000_0010, status);
            cpu_read(32'h1000_0000, src);
            cpu_read(32'h1000_0004, dst);
            cpu_read(32'h1000_0008, size);

            if (status[0] !== 1'b0 || status[1] !== 1'b0) begin
                $display("[FAIL] Test 6: Status register not reset! BUSY=%b, DONE=%b (Expected: 0, 0)", status[0], status[1]);
                failed = 1'b1;
            end else if (src !== 32'h0 || dst !== 32'h0 || size !== 32'h0) begin
                $display("[FAIL] Test 6: Configuration registers not reset! SRC=0x%h, DST=0x%h, SIZE=%d", src, dst, size);
                failed = 1'b1;
            end else begin
                $display("[PASS] Test 6: Reset mid-transfer safely aborted and initialized all blocks.");
            end
        end

        $display("\n==================================================");
        if (failed) begin
            $display("ASIC CORNER CASE TESTS: FAILED!");
            $display("==================================================");
            $finish_and_return(1);
        end else begin
            $display("ALL ASIC CORNER CASE TESTS: PASSED!");
            $display("==================================================");
            $finish_and_return(0);
        end
    end

endmodule
