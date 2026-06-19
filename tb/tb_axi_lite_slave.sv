// AXI-Lite Slave Wrapper Testbench

`timescale 1ns/1ps

module tb_axi_lite_slave;

    logic        clk;
    logic        rst_n;

    // Write Address Channel
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awvalid;
    logic        s_axi_awready;

    // Write Data Channel
    logic [31:0] s_axi_wdata;
    logic        s_axi_wvalid;
    logic        s_axi_wready;

    // Write Response Channel
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready;

    // Read Address Channel
    logic [31:0] s_axi_araddr;
    logic        s_axi_arvalid;
    logic        s_axi_arready;

    // Read Data Channel
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic        s_axi_rready;

    // Backend Interface
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        read_en;
    logic        write_en;
    logic [31:0] rdata;
    logic        ready;

    logic        failed;

    // Instantiate Unit Under Test (UUT)
    axi_lite_slave uut (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .addr          (addr),
        .wdata         (wdata),
        .read_en       (read_en),
        .write_en      (write_en),
        .rdata         (rdata),
        .ready         (ready)
    );

    // Clock generator (50MHz)
    initial clk = 0;
    always #10 clk = ~clk;

    // Simple Mock Backend Memory/Register Map
    logic [31:0] mock_reg;

    // Mock Backend Ready and latency emulation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready    <= 1'b0;
            rdata    <= 32'h0;
            mock_reg <= 32'h0;
        end else begin
            ready <= 1'b0;

            if (write_en) begin
                mock_reg <= wdata;
                ready    <= 1'b1; // Write completes in 1 cycle
            end

            if (read_en) begin
                rdata    <= mock_reg;
                ready    <= 1'b1; // Read completes in 1 cycle
            end
        end
    end

    // AXI Write Task
    task axi_write(input [31:0] awaddr, input [31:0] wval);
        begin
            s_axi_awaddr  = awaddr;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = wval;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b1;

            @(posedge clk);
            #1;
            while (!(s_axi_awready && s_axi_wready)) begin
                @(posedge clk);
                #1;
            end
            s_axi_awvalid = 1'b0;
            s_axi_wvalid  = 1'b0;

            // Wait for response valid
            while (!s_axi_bvalid) begin
                @(posedge clk);
                #1;
            end
            @(posedge clk);
            #1;
            s_axi_bready  = 1'b0;
        end
    endtask

    // AXI Read Task
    task axi_read(input [31:0] araddr, output [31:0] rval);
        begin
            s_axi_araddr  = araddr;
            s_axi_arvalid = 1'b1;
            s_axi_rready  = 1'b1;

            @(posedge clk);
            #1;
            while (!s_axi_arready) begin
                @(posedge clk);
                #1;
            end
            s_axi_arvalid = 1'b0;

            // Wait for read response
            while (!s_axi_rvalid) begin
                @(posedge clk);
                #1;
            end
            rval          = s_axi_rdata;
            @(posedge clk);
            #1;
            s_axi_rready  = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("temp/sim_axi_lite_slave.vcd");
        $dumpvars(0, tb_axi_lite_slave);

        failed        = 1'b0;
        rst_n         = 1'b0;
        s_axi_awaddr  = 32'h0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = 32'h0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = 32'h0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        // Reset
        #40;
        rst_n = 1'b1;
        #20;

        $display("Starting AXI-Lite Slave Wrapper Testbench...");

        // Test 1: Write to Register
        $display("[INFO] Running AXI-Lite Write: Address = 0x4, Data = 0xCAFEF00D...");
        axi_write(32'h0000_0004, 32'hCAFEF00D);

        // Verify write through mock reg
        if (mock_reg !== 32'hCAFEF00D) begin
            $display("[FAIL] Test 1: Write did not update register! Got 0x%h", mock_reg);
            failed = 1'b1;
        end else begin
            $display("[PASS] Test 1: Write updated mock register successfully.");
        end

        // Test 2: Read from Register
        $display("[INFO] Running AXI-Lite Read: Address = 0x4...");
        begin
            logic [31:0] rval;
            axi_read(32'h0000_0004, rval);
            if (rval !== 32'hCAFEF00D) begin
                $display("[FAIL] Test 2: Read mismatch! Got 0x%h, Expected 0xCAFEF00D", rval);
                failed = 1'b1;
            end else begin
                $display("[PASS] Test 2: Read matched 0x%h.", rval);
            end
        end

        // Final Report
        if (failed) begin
            $display("--- AXI-LITE SLAVE TB: FAILED ---");
            $finish_and_return(1);
        end else begin
            $display("--- AXI-LITE SLAVE TB: PASSED ---");
            $finish_and_return(0);
        end
    end

endmodule
