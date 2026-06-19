// AXI-Lite Slave Wrapper Module
// Translates AXI-Lite read and write channel transactions into the simplified memory subsystem interface.
// Incorporates robust channel registers and serialization to avoid backend collisions.

`timescale 1ns/1ps

module axi_lite_slave (
    input  logic        clk,
    input  logic        rst_n,

    // Write Address Channel
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    // Write Data Channel
    input  logic [31:0] s_axi_wdata,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    // Write Response Channel
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    // Read Address Channel
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    // Read Data Channel
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // Backend Simple Memory Interface
    output logic [31:0] addr,
    output logic [31:0] wdata,
    output logic        read_en,
    output logic        write_en,
    input  logic [31:0] rdata,
    input  logic        ready
);

    // ------------------------------------------------
    // Write Channel State and Registers
    // ------------------------------------------------
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_WAIT_READY,
        WR_RESP
    } wr_state_t;

    wr_state_t wr_state;
    logic [31:0] awaddr_reg;
    logic [31:0] wdata_reg;
    logic        awvalid_captured;
    logic        wvalid_captured;

    // ------------------------------------------------
    // Read Channel State and Registers
    // ------------------------------------------------
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_WAIT_READY,
        RD_RESP
    } rd_state_t;

    rd_state_t rd_state;
    logic [31:0] araddr_reg;

    // ------------------------------------------------
    // Backend Interface Address & Data Routing
    // ------------------------------------------------
    assign addr = (wr_state == WR_WAIT_READY) ? awaddr_reg :
                  (rd_state == RD_WAIT_READY) ? araddr_reg  : 32'h0;
    assign wdata = wdata_reg;

    // ------------------------------------------------
    // Write Transaction FSM
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state         <= WR_IDLE;
            awaddr_reg       <= 32'h0;
            wdata_reg        <= 32'h0;
            awvalid_captured <= 1'b0;
            wvalid_captured  <= 1'b0;
            s_axi_awready    <= 1'b0;
            s_axi_wready     <= 1'b0;
            s_axi_bvalid     <= 1'b0;
            s_axi_bresp      <= 2'b00;
            write_en         <= 1'b0;
        end else begin
            // Ready pulses default to 0
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    // Capture awaddr as it arrives
                    if (s_axi_awvalid && !awvalid_captured) begin
                        awaddr_reg       <= s_axi_awaddr;
                        awvalid_captured <= 1'b1;
                    end

                    // Capture wdata as it arrives
                    if (s_axi_wvalid && !wvalid_captured) begin
                        wdata_reg       <= s_axi_wdata;
                        wvalid_captured <= 1'b1;
                    end

                    // Initiate transaction when both are available (or arriving now)
                    if ((s_axi_awvalid || awvalid_captured) && (s_axi_wvalid || wvalid_captured)) begin
                        if (s_axi_awvalid && !awvalid_captured) awaddr_reg <= s_axi_awaddr;
                        if (s_axi_wvalid && !wvalid_captured)  wdata_reg  <= s_axi_wdata;

                        write_en <= 1'b1;
                        wr_state <= WR_WAIT_READY;
                    end
                end

                WR_WAIT_READY: begin
                    if (ready) begin
                        write_en         <= 1'b0;
                        s_axi_awready    <= 1'b1; // Handshake complete
                        s_axi_wready     <= 1'b1;
                        awvalid_captured <= 1'b0;
                        wvalid_captured  <= 1'b0;
                        s_axi_bvalid     <= 1'b1;
                        s_axi_bresp      <= 2'b00; // OKAY
                        wr_state         <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // ------------------------------------------------
    // Read Transaction FSM (Serialized after writes)
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state      <= RD_IDLE;
            araddr_reg    <= 32'h0;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'h0;
            s_axi_rresp   <= 2'b00;
            read_en       <= 1'b0;
        end else begin
            s_axi_arready <= 1'b0;

            case (rd_state)
                RD_IDLE: begin
                    // Stalls reads if a write transaction is currently utilizing the backend
                    if (s_axi_arvalid && (wr_state == WR_IDLE) && !write_en) begin
                        araddr_reg    <= s_axi_araddr;
                        read_en       <= 1'b1;
                        rd_state      <= RD_WAIT_READY;
                    end
                end

                RD_WAIT_READY: begin
                    if (ready) begin
                        read_en       <= 1'b0;
                        s_axi_arready <= 1'b1; // Consume address input
                        s_axi_rdata   <= rdata; // Sample read data from backend
                        s_axi_rvalid  <= 1'b1;
                        s_axi_rresp   <= 2'b00; // OKAY
                        rd_state      <= RD_RESP;
                    end
                end

                RD_RESP: begin
                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state     <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
