// DMA Finite State Machine Module
// Manages the state transitions and control signals for the DMA transfer.

`timescale 1ns/1ps

import dma_pkg::*;

module dma_fsm (
    input  logic        clk,
    input  logic        rst_n,

    // Register Inputs
    input  logic        start,
    input  logic [31:0] src_addr,
    input  logic [31:0] dst_addr,
    input  logic [31:0] size,

    // Status Outputs
    output logic        busy,
    output logic        done,

    // Memory Master Port
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic        mem_rd_en,
    output logic        mem_wr_en,
    input  logic [31:0] mem_rdata,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic        mem_ready
    /* verilator lint_on UNUSEDSIGNAL */
);

    dma_pkg::dma_state_t state, next_state;
    logic [31:0] transfer_count;
    logic [31:0] buffer;

    // State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= dma_pkg::DMA_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always_comb begin
        next_state = state;

        case (state)
            dma_pkg::DMA_IDLE: begin
                if (start) begin
                    if (size == 32'h0) begin
                        next_state = dma_pkg::DMA_DONE;
                    end else begin
                        next_state = dma_pkg::DMA_READ_REQ;
                    end
                end
            end

            dma_pkg::DMA_READ_REQ: begin
                next_state = dma_pkg::DMA_READ_DATA;
            end

            dma_pkg::DMA_READ_DATA: begin
                next_state = dma_pkg::DMA_WRITE_REQ;
            end

            dma_pkg::DMA_WRITE_REQ: begin
                next_state = dma_pkg::DMA_WRITE_RESP;
            end

            dma_pkg::DMA_WRITE_RESP: begin
                if (transfer_count == size - 1) begin
                    next_state = dma_pkg::DMA_DONE;
                end else begin
                    next_state = dma_pkg::DMA_READ_REQ;
                end
            end

            dma_pkg::DMA_DONE: begin
                next_state = dma_pkg::DMA_IDLE;
            end

            default: next_state = dma_pkg::DMA_IDLE;
        endcase
    end

    // Busy & Done Outputs
    assign busy = (state != dma_pkg::DMA_IDLE) && (state != dma_pkg::DMA_DONE);
    assign done = (state == dma_pkg::DMA_DONE);

    // Transfer Counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transfer_count <= 32'h0;
        end else if (state == dma_pkg::DMA_IDLE) begin
            transfer_count <= 32'h0;
        end else if (state == dma_pkg::DMA_WRITE_RESP) begin
            if (transfer_count == size - 1) begin
                transfer_count <= 32'h0;
            end else begin
                transfer_count <= transfer_count + 1;
            end
        end
    end

    // Temporary Data Buffer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer <= 32'h0;
        end else if (state == dma_pkg::DMA_READ_DATA) begin
            buffer <= mem_rdata;
        end
    end

    // Memory Master Output Address and Control Routing
    always_comb begin
        mem_addr   = 32'h0;
        mem_wdata  = 32'h0;
        mem_rd_en  = 1'b0;
        mem_wr_en  = 1'b0;

        if (state == dma_pkg::DMA_READ_REQ) begin
            mem_addr  = src_addr + (transfer_count << 2);
            mem_rd_en = 1'b1;
        end else if (state == dma_pkg::DMA_WRITE_REQ) begin
            mem_addr  = dst_addr + (transfer_count << 2);
            mem_wr_en = 1'b1;
            mem_wdata = buffer;
        end
    end

`ifndef SYNTHESIS
    // Synchronous procedural assertions for simulation checking
    always @(posedge clk) begin
        if (rst_n) begin
            // Assertion: Done status matches DONE state
            if (state == dma_pkg::DMA_DONE && !done) begin
                $display("[ASSERT FAIL] dma_fsm: done must be asserted in DMA_DONE state!");
                $fatal(1);
            end
            // Assertion: Busy is active in all states except IDLE and DONE
            if ((state != dma_pkg::DMA_IDLE && state != dma_pkg::DMA_DONE) && !busy) begin
                $display("[ASSERT FAIL] dma_fsm: busy must be active when state is not IDLE or DONE!");
                $fatal(1);
            end
        end
    end
`endif

endmodule
